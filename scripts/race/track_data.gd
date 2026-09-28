class_name TrackData
extends RefCounted
## Runtime representation of a track: an arc-length sampled closed centerline plus the
## terrain heightmap around it. Provides all spatial queries used by physics, AI, race
## logic and the world builder. Pure data (no nodes) so it can be built on a worker thread.

enum Surface { ASPHALT, SHOULDER, OFFROAD }

const DS := 2.0 ## centerline sample spacing, meters
const GRID_CELL := 5.0 ## heightmap cell size, meters
const MARGIN := 380.0 ## heightmap margin around the track bounds
const LOOKUP_CELL := 40.0
const MAX_GRADE := 0.095

var id := ""
var layout: Dictionary = {}
var style: TerrainStyle

var points := PackedVector3Array() ## centerline samples (with road height)
var tangents := PackedVector3Array() ## horizontal unit tangents
var rights := PackedVector3Array() ## horizontal unit right vectors
var dists := PackedFloat32Array() ## cumulative distance at each sample
var curvature := PackedFloat32Array() ## signed curvature (1/m), + = right turn
var tunnel := PackedByteArray() ## 1 where the sample is inside a tunnel
var length := 0.0
var count := 0
var half_width := 5.5
var shoulder := 2.5
var wall := 26.0

# Heightmap
var hm_origin := Vector2.ZERO
var hm_w := 0
var hm_h := 0
var heights := PackedFloat32Array()
var road_dist := PackedFloat32Array() ## per cell: distance to the centerline (capped)

var _lookup: Dictionary = {}
## How strongly the terrain is shifted toward the road elevation at large scale.
var correction_strength := 1.0
## Distance from the centerline where the terrain blend back to natural ends.
var blend_radius := 48.0


static func build(p_layout: Dictionary, with_terrain := true) -> TrackData:
	var t := TrackData.new()
	t._build(p_layout, with_terrain)
	return t


func _build(p_layout: Dictionary, with_terrain: bool) -> void:
	layout = p_layout
	id = layout["id"]
	half_width = layout.get("half_width", 5.5)
	shoulder = layout.get("shoulder", 2.5)
	wall = layout.get("wall", 26.0)
	style = TerrainStyle.new(layout.get("style", "flat"), layout.get("seed", 1))
	correction_strength = layout.get("terrain_correction", 1.0)
	blend_radius = layout.get("blend_radius", 48.0)
	_sample_spline(layout["points"])
	_smooth_heights()
	_compute_frames()
	_mark_tunnels(layout.get("tunnels", []))
	_build_lookup()
	if with_terrain:
		_build_heightmap()


# --- Spline sampling ---------------------------------------------------------

static func catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _sample_spline(ctrl: PackedVector3Array) -> void:
	var n := ctrl.size()
	var dense := PackedVector3Array()
	var sub := 120
	for i in n:
		var p0 := ctrl[(i - 1 + n) % n]
		var p1 := ctrl[i]
		var p2 := ctrl[(i + 1) % n]
		var p3 := ctrl[(i + 2) % n]
		for k in sub:
			dense.append(catmull_rom(p0, p1, p2, p3, float(k) / sub))
	# Cumulative horizontal arc length over the dense polyline.
	var m := dense.size()
	var cum := PackedFloat32Array()
	cum.resize(m + 1)
	cum[0] = 0.0
	for i in m:
		var a := dense[i]
		var b := dense[(i + 1) % m]
		cum[i + 1] = cum[i] + Vector2(b.x - a.x, b.z - a.z).length()
	length = cum[m]
	count = int(floor(length / DS))
	var step := length / count
	points.resize(count)
	dists.resize(count)
	var j := 0
	for i in count:
		var s := i * step
		while j < m - 1 and cum[j + 1] < s:
			j += 1
		var seg := cum[j + 1] - cum[j]
		var f := 0.0 if seg <= 0.0 else (s - cum[j]) / seg
		points[i] = dense[j].lerp(dense[(j + 1) % m], f)
		dists[i] = s


func _smooth_heights() -> void:
	var y := PackedFloat32Array()
	y.resize(count)
	for i in count:
		y[i] = points[i].y
	var step := length / count
	# Alternate grade limiting and smoothing so the elevation stays drivable and flowing.
	for it in 6:
		var max_dy := MAX_GRADE * step
		for pass_i in 2:
			for i in count * 2:
				var a := i % count
				var b := (i + 1) % count
				y[b] = clampf(y[b], y[a] - max_dy, y[a] + max_dy)
			for i in range(count * 2, 0, -1):
				var a := i % count
				var b := (i - 1 + count) % count
				y[b] = clampf(y[b], y[a] - max_dy, y[a] + max_dy)
		var r := 12
		var sm := PackedFloat32Array()
		sm.resize(count)
		var acc := 0.0
		for k in range(-r, r + 1):
			acc += y[(k + count) % count]
		for i in count:
			sm[i] = acc / (2 * r + 1)
			acc += y[(i + r + 1) % count] - y[(i - r + count) % count]
		y = sm
	for i in count:
		points[i].y = y[i]


func _compute_frames() -> void:
	tangents.resize(count)
	rights.resize(count)
	curvature.resize(count)
	for i in count:
		var a := points[(i - 1 + count) % count]
		var b := points[(i + 1) % count]
		var t := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
		tangents[i] = t
		rights[i] = Vector3(-t.z, 0.0, t.x)
	for i in count:
		var ta := tangents[(i - 2 + count) % count]
		var tb := tangents[(i + 2) % count]
		var cross_y := ta.x * tb.z - ta.z * tb.x
		var ang := asin(clampf(cross_y, -1.0, 1.0))
		curvature[i] = ang / (4.0 * DS)
	# Light smoothing of curvature.
	var c2 := curvature.duplicate()
	for i in count:
		var s := 0.0
		for k in range(-3, 4):
			s += c2[(i + k + count) % count]
		curvature[i] = s / 7.0


func _mark_tunnels(ranges: Array) -> void:
	tunnel.resize(count)
	tunnel.fill(0)
	for r in ranges:
		var i0 := int(float(r[0]) * count)
		var i1 := int(float(r[1]) * count)
		for i in range(i0, i1 + 1):
			tunnel[i % count] = 1


# --- Lookup ------------------------------------------------------------------

func _cell_key(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / LOOKUP_CELL), floori(z / LOOKUP_CELL))


func _build_lookup() -> void:
	_lookup.clear()
	for i in count:
		var k := _cell_key(points[i].x, points[i].z)
		if not _lookup.has(k):
			_lookup[k] = PackedInt32Array()
		var arr: PackedInt32Array = _lookup[k]
		arr.append(i)
		_lookup[k] = arr


## Index of the nearest centerline sample. With a valid hint only a local window is
## searched (fast path used every physics tick); falls back to the global grid search.
func closest_index(pos: Vector3, hint := -1) -> int:
	if hint >= 0 and hint < count:
		var best := hint
		var best_d := INF
		for k in range(-40, 41):
			var i := (hint + k + count) % count
			var p := points[i]
			var d := (p.x - pos.x) * (p.x - pos.x) + (p.z - pos.z) * (p.z - pos.z)
			if d < best_d:
				best_d = d
				best = i
		# Accept when within the corridor and vertically plausible.
		if best_d < (wall + 20.0) * (wall + 20.0) and absf(points[best].y - pos.y) < 20.0:
			return best
	return _closest_global(pos)


func _closest_global(pos: Vector3) -> int:
	var c := _cell_key(pos.x, pos.z)
	var best := 0
	var best_d := INF
	var found := false
	for radius in [1, 3, 8]:
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				var k := Vector2i(c.x + dx, c.y + dz)
				if not _lookup.has(k):
					continue
				for i in _lookup[k]:
					var p := points[i]
					# Weight vertical separation so stacked sections resolve properly.
					var d := (p.x - pos.x) * (p.x - pos.x) + (p.z - pos.z) * (p.z - pos.z) + 4.0 * (p.y - pos.y) * (p.y - pos.y)
					if d < best_d:
						best_d = d
						best = i
						found = true
		if found:
			return best
	# Brute force fallback (far outside the track).
	for i in count:
		var p := points[i]
		var d := (p.x - pos.x) * (p.x - pos.x) + (p.z - pos.z) * (p.z - pos.z)
		if d < best_d:
			best_d = d
			best = i
	return best


## Projects a world position onto the track. Returns index, distance along the lap,
## signed lateral offset (+ = right of travel direction) and the interpolated center.
func project(pos: Vector3, hint := -1) -> Dictionary:
	var i := closest_index(pos, hint)
	var p := points[i]
	var t := tangents[i]
	var rel := Vector3(pos.x - p.x, 0.0, pos.z - p.z)
	var along := rel.dot(t)
	# Refine between neighbouring samples.
	var j := (i + 1) % count if along >= 0.0 else (i - 1 + count) % count
	var q := points[j]
	var seg := Vector3(q.x - p.x, 0.0, q.z - p.z)
	var seg_len := seg.length()
	var f := 0.0
	if seg_len > 0.001:
		f = clampf(rel.dot(seg) / (seg_len * seg_len), 0.0, 1.0)
	var center := p.lerp(q, f)
	var right := rights[i].lerp(rights[j], f).normalized()
	var lateral := Vector3(pos.x - center.x, 0.0, pos.z - center.z).dot(right)
	var d := dists[i] + clampf(along, -DS, DS)
	d = fposmod(d, length)
	return {"index": i, "dist": d, "lateral": lateral, "center": center, "tangent": tangents[i].lerp(tangents[j], f).normalized(), "right": right}


func index_at_distance(d: float) -> int:
	d = fposmod(d, length)
	return clampi(int(d / (length / count)), 0, count - 1)


func point_at_distance(d: float) -> Vector3:
	d = fposmod(d, length)
	var step := length / count
	var i := int(d / step) % count
	var f := (d - i * step) / step
	return points[i].lerp(points[(i + 1) % count], f)


func tangent_at_distance(d: float) -> Vector3:
	var i := index_at_distance(d)
	return tangents[i]


func right_at_distance(d: float) -> Vector3:
	var i := index_at_distance(d)
	return rights[i]


## Transform on the road at lap distance `d` and lateral offset, facing travel direction.
func transform_at(d: float, lateral := 0.0) -> Transform3D:
	var p := point_at_distance(d)
	var t := tangent_at_distance(d)
	var r := right_at_distance(d)
	var origin := p + r * lateral
	var basis := Basis(r, Vector3.UP, -t)
	return Transform3D(basis, origin)


## Lap-distance difference b - a wrapped into [-length/2, length/2].
func wrap_delta(a: float, b: float) -> float:
	var d := b - a
	if d > length * 0.5:
		d -= length
	elif d < -length * 0.5:
		d += length
	return d


func surface_for_lateral(lateral: float) -> int:
	var a := absf(lateral)
	if a <= half_width:
		return Surface.ASPHALT
	if a <= half_width + shoulder:
		return Surface.SHOULDER
	return Surface.OFFROAD


func wall_limit(index: int) -> float:
	if tunnel.size() > 0 and tunnel[index] == 1:
		return half_width + 0.6
	return wall


## Ground height and surface under a world position. `proj` may be passed in when the
## caller already projected the position this frame.
func ground(pos: Vector3, proj: Dictionary) -> Dictionary:
	var lateral: float = proj["lateral"]
	var surf := surface_for_lateral(lateral)
	var road_h: float = proj["center"].y
	var h := road_h
	if surf == Surface.OFFROAD and not heights.is_empty():
		var th := terrain_height(pos.x, pos.z)
		# Keep continuity with the road edge.
		var edge := half_width + shoulder
		var k := clampf((absf(lateral) - edge) / 3.0, 0.0, 1.0)
		h = lerpf(road_h, th, k)
	elif surf == Surface.SHOULDER:
		h = road_h - 0.03
	return {"height": h, "surface": surf}


# --- Heightmap ---------------------------------------------------------------

func bounds() -> Rect2:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in points:
		mn.x = minf(mn.x, p.x)
		mn.y = minf(mn.y, p.z)
		mx.x = maxf(mx.x, p.x)
		mx.y = maxf(mx.y, p.z)
	return Rect2(mn, mx - mn)


func _build_heightmap() -> void:
	var b := bounds().grow(MARGIN)
	hm_origin = b.position
	hm_w = int(ceil(b.size.x / GRID_CELL)) + 1
	hm_h = int(ceil(b.size.y / GRID_CELL)) + 1
	var n := hm_w * hm_h
	heights.resize(n)
	road_dist.resize(n)
	var road_h := PackedFloat32Array()
	var tun_h := PackedFloat32Array()
	road_h.resize(n)
	tun_h.resize(n)
	road_dist.fill(1.0e6)
	tun_h.fill(-1.0e6)
	for zi in hm_h:
		var z := hm_origin.y + zi * GRID_CELL
		var row := zi * hm_w
		for xi in hm_w:
			heights[row + xi] = style.height(hm_origin.x + xi * GRID_CELL, z)
	_apply_correction_field()
	# Stamp the road corridor: nearest centerline distance and road height per cell.
	var radius := blend_radius
	var rc := int(ceil(maxf(radius, 48.0) / GRID_CELL))
	for i in count:
		var p := points[i]
		var cx := int(round((p.x - hm_origin.x) / GRID_CELL))
		var cz := int(round((p.z - hm_origin.y) / GRID_CELL))
		var is_tunnel := tunnel[i] == 1
		for dz in range(-rc, rc + 1):
			var zi := cz + dz
			if zi < 0 or zi >= hm_h:
				continue
			var wz := hm_origin.y + zi * GRID_CELL - p.z
			for dx in range(-rc, rc + 1):
				var xi := cx + dx
				if xi < 0 or xi >= hm_w:
					continue
				var wx := hm_origin.x + xi * GRID_CELL - p.x
				var d := sqrt(wx * wx + wz * wz)
				var idx := zi * hm_w + xi
				if is_tunnel:
					# Hills over tunnels: never lower than road + cover.
					var cover := p.y + 16.0 - maxf(d - 10.0, 0.0) * 0.35
					tun_h[idx] = maxf(tun_h[idx], cover)
					continue
				if d < road_dist[idx]:
					road_dist[idx] = d
					road_h[idx] = p.y
	var flat := half_width + shoulder + 1.0
	for idx in n:
		var d := road_dist[idx]
		if d < radius:
			var k := clampf((d - flat) / (radius - flat), 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			heights[idx] = lerpf(road_h[idx] - 0.25, heights[idx], k)
		if tun_h[idx] > heights[idx] and d > half_width + 1.0:
			heights[idx] = tun_h[idx]


## Shifts the natural terrain so that, at large scale, it follows the road elevation.
## Offsets measured at the road are spread with a Gaussian kernel on a coarse grid and
## faded out before the heightmap edge (so it still meets the far terrain).
func _apply_correction_field() -> void:
	var coarse := 40.0
	var cw := int(ceil((hm_w - 1) * GRID_CELL / coarse)) + 1
	var ch := int(ceil((hm_h - 1) * GRID_CELL / coarse)) + 1
	var sx := PackedFloat32Array()
	var sz := PackedFloat32Array()
	var sd := PackedFloat32Array()
	for i in range(0, count, 6):
		var p := points[i]
		sx.append(p.x)
		sz.append(p.z)
		sd.append(p.y - style.height(p.x, p.z))
	var field := PackedFloat32Array()
	field.resize(cw * ch)
	var sigma2 := 2.0 * 90.0 * 90.0
	var n := sx.size()
	for cz in ch:
		var z := hm_origin.y + cz * coarse
		for cx in cw:
			var x := hm_origin.x + cx * coarse
			var wsum := 0.0
			var acc := 0.0
			var dmin := INF
			for k in n:
				var dx := sx[k] - x
				var dz := sz[k] - z
				var d2 := dx * dx + dz * dz
				dmin = minf(dmin, d2)
				if d2 < 360000.0:
					var w := exp(-d2 / sigma2)
					wsum += w
					acc += w * sd[k]
			var v := 0.0
			if wsum > 1e-6:
				v = acc / wsum
			var dm := sqrt(dmin)
			var fade := 1.0 - clampf((dm - 140.0) / (MARGIN - 60.0 - 140.0), 0.0, 1.0)
			field[cz * cw + cx] = v * fade * fade * (3.0 - 2.0 * fade) * correction_strength
	var ratio := GRID_CELL / coarse
	for zi in hm_h:
		var fz := zi * ratio
		var z0 := mini(int(fz), ch - 2)
		var tz := fz - z0
		for xi in hm_w:
			var fx := xi * ratio
			var x0 := mini(int(fx), cw - 2)
			var tx := fx - x0
			var a := field[z0 * cw + x0]
			var b := field[z0 * cw + x0 + 1]
			var c := field[(z0 + 1) * cw + x0]
			var d := field[(z0 + 1) * cw + x0 + 1]
			heights[zi * hm_w + xi] += lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


func terrain_height(x: float, z: float) -> float:
	if heights.is_empty():
		return 0.0
	var fx := (x - hm_origin.x) / GRID_CELL
	var fz := (z - hm_origin.y) / GRID_CELL
	if fx < 0.0 or fz < 0.0 or fx >= hm_w - 1 or fz >= hm_h - 1:
		return style.height(x, z)
	var xi := int(fx)
	var zi := int(fz)
	var tx := fx - xi
	var tz := fz - zi
	var i := zi * hm_w + xi
	var h00 := heights[i]
	var h10 := heights[i + 1]
	var h01 := heights[i + hm_w]
	var h11 := heights[i + hm_w + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func terrain_road_distance(x: float, z: float) -> float:
	if road_dist.is_empty():
		return 1.0e6
	var xi := clampi(int(round((x - hm_origin.x) / GRID_CELL)), 0, hm_w - 1)
	var zi := clampi(int(round((z - hm_origin.y) / GRID_CELL)), 0, hm_h - 1)
	return road_dist[zi * hm_w + xi]


## Starting grid slot transform. Slot 0 is pole position; rows of two, staggered.
func grid_transform(slot: int) -> Transform3D:
	var row := slot / 2
	var side := -1.0 if slot % 2 == 0 else 1.0
	var d := -10.0 - row * 9.0 - (4.5 if slot % 2 == 1 else 0.0)
	return transform_at(d, side * 2.4)

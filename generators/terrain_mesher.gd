class_name TerrainMesher
extends RefCounted
## Converts a TrackData heightmap into chunked mesh arrays, plus a coarse far-terrain ring
## for the horizon. Produces plain arrays so it can run on a worker thread.

const CHUNK := 48 ## cells per chunk side


## Returns an Array of {"arrays": Array, "center": Vector3} dictionaries.
static func build_core_chunks(t: TrackData) -> Array:
	var out := []
	var cell := TrackData.GRID_CELL
	var salt := t.style.style == "deadsea"
	for cz in range(0, t.hm_h - 1, CHUNK):
		for cx in range(0, t.hm_w - 1, CHUNK):
			var w := mini(CHUNK, t.hm_w - 1 - cx)
			var h := mini(CHUNK, t.hm_h - 1 - cz)
			var verts := PackedVector3Array()
			var norms := PackedVector3Array()
			var cols := PackedColorArray()
			var idx := PackedInt32Array()
			verts.resize((w + 1) * (h + 1))
			norms.resize(verts.size())
			cols.resize(verts.size())
			var vi := 0
			for z in h + 1:
				var gz := cz + z
				for x in w + 1:
					var gx := cx + x
					var i := gz * t.hm_w + gx
					var hy := t.heights[i]
					var wx := t.hm_origin.x + gx * cell
					var wz := t.hm_origin.y + gz * cell
					verts[vi] = Vector3(wx, hy, wz)
					var hl := t.heights[gz * t.hm_w + maxi(gx - 1, 0)]
					var hr := t.heights[gz * t.hm_w + mini(gx + 1, t.hm_w - 1)]
					var hd := t.heights[maxi(gz - 1, 0) * t.hm_w + gx]
					var hu := t.heights[mini(gz + 1, t.hm_h - 1) * t.hm_w + gx]
					norms[vi] = Vector3(hl - hr, 2.0 * cell, hd - hu).normalized()
					var rd := t.road_dist[i]
					var verge := 1.0 - clampf((rd - t.half_width - t.shoulder) / 14.0, 0.0, 1.0)
					var salt_mask := 0.0
					if salt:
						salt_mask = _salt_mask(t, wx, wz, hy)
					cols[vi] = Color(verge * 0.85, salt_mask, 0.0)
					vi += 1
			for z in h:
				for x in w:
					var a := z * (w + 1) + x
					var b := a + 1
					var c := a + (w + 1)
					var d := c + 1
					# Godot front faces are clockwise when seen from above.
					idx.append_array([a, b, d, a, d, c])
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_NORMAL] = norms
			arrays[Mesh.ARRAY_COLOR] = cols
			arrays[Mesh.ARRAY_INDEX] = idx
			var center := Vector3(t.hm_origin.x + (cx + w * 0.5) * cell, 0.0, t.hm_origin.y + (cz + h * 0.5) * cell)
			out.append({"arrays": arrays, "center": center})
	return out


static func _salt_mask(t: TrackData, x: float, z: float, h: float) -> float:
	# Salt crusts on the low flats near the sea, stronger to the south (evaporation ponds).
	if h > 1.0:
		return 0.0
	# Patchy crusts: cellular-ish pattern from interfering waves, strongest by the water.
	var n := sin(x * 0.021 + sin(z * 0.013) * 2.0) * sin(z * 0.017 + sin(x * 0.009) * 2.0)
	var shore_k := clampf((x - 40.0) / 120.0, 0.0, 1.0)
	var low := clampf((1.0 - h) / 4.0, 0.0, 1.0)
	return clampf((n * 1.8 - 0.2) * low * (0.3 + shore_k), 0.0, 0.95)


## Coarse terrain covering a large square around the track. Inside the core heightmap
## area it is pushed down so it never pokes through the detailed terrain.
static func build_far(t: TrackData, extent := 9000.0, steps := 150) -> Array:
	var b := t.bounds()
	var center := b.get_center()
	var core := Rect2(t.hm_origin, Vector2((t.hm_w - 1) * TrackData.GRID_CELL, (t.hm_h - 1) * TrackData.GRID_CELL)).grow(-TrackData.GRID_CELL * 2.0)
	var cell := extent * 2.0 / steps
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var n := steps + 1
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for z in n:
		for x in n:
			var wx := center.x - extent + x * cell
			var wz := center.y - extent + z * cell
			var hy := t.style.height(wx, wz)
			if core.has_point(Vector2(wx, wz)):
				hy -= 60.0
			hs[z * n + x] = hy
	for z in n:
		for x in n:
			var wx := center.x - extent + x * cell
			var wz := center.y - extent + z * cell
			var hy := hs[z * n + x]
			verts.append(Vector3(wx, hy, wz))
			var hl := hs[z * n + maxi(x - 1, 0)]
			var hr := hs[z * n + mini(x + 1, n - 1)]
			var hd := hs[maxi(z - 1, 0) * n + x]
			var hu := hs[mini(z + 1, n - 1) * n + x]
			norms.append(Vector3(hl - hr, 2.0 * cell, hd - hu).normalized())
			var salt := 0.0
			if t.style.style == "deadsea":
				salt = _salt_mask(t, wx, wz, hy)
			cols.append(Color(0.0, salt, 0.0))
	for z in steps:
		for x in steps:
			var a := z * n + x
			var bb := a + 1
			var c := a + n
			var d := c + 1
			idx.append_array([a, bb, d, a, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	return arrays

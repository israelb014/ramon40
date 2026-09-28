class_name MeshBuilder
extends RefCounted
## Procedural mesh construction helper. Geometry is accumulated into named surfaces
## (e.g. "paint", "metal", "rubber") so each can get its own material, then committed
## to an ArrayMesh. Supports flat (faceted, low-poly look) and smooth shading.

var flat := true
## When true, ring surfaces face inward (used for tunnels seen from inside).
var invert_faces := false
var _surfaces: Dictionary = {} # name -> {verts, norms, cols, uvs, idx}
var _order: Array[String] = []
var _cur := ""


func _init(p_flat := true) -> void:
	flat = p_flat
	surface("default")


func surface(name: String) -> MeshBuilder:
	if not _surfaces.has(name):
		_surfaces[name] = {
			"verts": PackedVector3Array(), "norms": PackedVector3Array(),
			"cols": PackedColorArray(), "uvs": PackedVector2Array(), "idx": PackedInt32Array(),
		}
		_order.append(name)
	_cur = name
	return self


func surface_names() -> Array[String]:
	var out: Array[String] = []
	for n in _order:
		if not _surfaces[n]["idx"].is_empty():
			out.append(n)
	return out


func vertex_count() -> int:
	var c := 0
	for n in _order:
		c += _surfaces[n]["verts"].size()
	return c


# --- Low level ---------------------------------------------------------------

func add_vertex(p: Vector3, n: Vector3, c: Color, uv := Vector2.ZERO) -> int:
	var s: Dictionary = _surfaces[_cur]
	s["verts"].append(p)
	s["norms"].append(n)
	s["cols"].append(c)
	s["uvs"].append(uv)
	return s["verts"].size() - 1


func add_index(i: int) -> void:
	_surfaces[_cur]["idx"].append(i)


## Triangle with counter-clockwise winding as seen from the front (Godot convention is
## clockwise front faces, handled at commit by reversing).
func add_triangle(a: Vector3, b: Vector3, c: Vector3, col: Color, uva := Vector2.ZERO, uvb := Vector2.ZERO, uvc := Vector2.ZERO) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	var i0 := add_vertex(a, n, col, uva)
	var i1 := add_vertex(b, n, col, uvb)
	var i2 := add_vertex(c, n, col, uvc)
	add_index(i0)
	add_index(i1)
	add_index(i2)


## Triangle whose winding is chosen so its normal faces `dir`.
func add_triangle_facing(a: Vector3, b: Vector3, c: Vector3, col: Color, dir: Vector3) -> void:
	if (b - a).cross(c - a).dot(dir) >= 0.0:
		add_triangle(a, b, c, col)
	else:
		add_triangle(a, c, b, col)


func add_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	add_triangle(a, b, c, col, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1))
	add_triangle(a, c, d, col, Vector2(0, 0), Vector2(1, 1), Vector2(0, 1))


## Adds a grid of rings (each ring a closed loop of the same vertex count) as a tube.
## Smooth normals are computed from the grid when `flat` is false.
func add_rings(rings: Array, col: Color, closed_loop := true, cap_start := false, cap_end := false) -> void:
	var rc := rings.size()
	if rc < 2:
		return
	rings = _orient_rings(rings)
	if invert_faces:
		var flipped := []
		for ring in rings:
			var rv := PackedVector3Array(ring)
			rv.reverse()
			flipped.append(rv)
		rings = flipped
	var vc: int = rings[0].size()
	var seg_count := vc if closed_loop else vc - 1
	if flat:
		for r in rc - 1:
			var a: PackedVector3Array = rings[r]
			var b: PackedVector3Array = rings[r + 1]
			for k in seg_count:
				var k2 := (k + 1) % vc
				add_quad(a[k], a[k2], b[k2], b[k], col)
	else:
		var base: int = _surfaces[_cur]["verts"].size()
		for r in rc:
			var ring: PackedVector3Array = rings[r]
			var prev: PackedVector3Array = rings[maxi(r - 1, 0)]
			var next: PackedVector3Array = rings[mini(r + 1, rc - 1)]
			for k in vc:
				var kp := (k - 1 + vc) % vc if closed_loop else maxi(k - 1, 0)
				var kn := (k + 1) % vc if closed_loop else mini(k + 1, vc - 1)
				var along := next[k] - prev[k]
				var around := ring[kn] - ring[kp]
				var n := around.cross(along)
				if n.length_squared() < 1e-12:
					n = Vector3.UP
				add_vertex(ring[k], n.normalized(), col, Vector2(float(k) / vc, float(r) / (rc - 1)))
		for r in rc - 1:
			for k in seg_count:
				var k2 := (k + 1) % vc
				var i00 := base + r * vc + k
				var i01 := base + r * vc + k2
				var i10 := base + (r + 1) * vc + k
				var i11 := base + (r + 1) * vc + k2
				add_index(i00); add_index(i01); add_index(i11)
				add_index(i00); add_index(i11); add_index(i10)
	if cap_start:
		_cap(rings[0], _centroid(rings[1]), col)
	if cap_end:
		_cap(rings[rc - 1], _centroid(rings[rc - 2]), col)


static func _centroid(ring: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for p in ring:
		c += p
	return c / maxi(ring.size(), 1)


## Makes ring winding produce outward-facing quads (away from each ring's centroid).
static func _orient_rings(rings: Array) -> Array:
	var vc: int = rings[0].size()
	if vc < 2:
		return rings
	for r in rings.size() - 1:
		var a: PackedVector3Array = rings[r]
		var b: PackedVector3Array = rings[r + 1]
		for k in vc - 1:
			var n := (a[k + 1] - a[k]).cross(b[k + 1] - a[k])
			if n.length_squared() < 1e-10:
				n = (a[k + 1] - a[k]).cross(b[k] - a[k])
				if n.length_squared() < 1e-10:
					n = (b[k + 1] - b[k]).cross(b[k] - a[k])
					if n.length_squared() < 1e-10:
						continue
			var ca := _centroid(a)
			var cb := _centroid(b)
			var f := (a[k] + a[k + 1] + b[k] + b[k + 1]) * 0.25 - (ca + cb) * 0.5
			if f.length_squared() < 1e-10:
				continue
			if n.dot(f) >= 0.0:
				return rings
			var out := []
			for ring in rings:
				var rv := PackedVector3Array(ring)
				rv.reverse()
				out.append(rv)
			return out
	return rings


func _cap(ring: PackedVector3Array, inner: Vector3, col: Color) -> void:
	var c := _centroid(ring)
	var out_dir := c - inner
	for k in ring.size():
		var a := ring[k]
		var b := ring[(k + 1) % ring.size()]
		var n := (a - c).cross(b - c)
		if n.dot(out_dir) >= 0.0:
			add_triangle(c, a, b, col)
		else:
			add_triangle(c, b, a, col)


# --- Primitives --------------------------------------------------------------

func add_box(xf: Transform3D, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	var c := [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	for i in 8:
		c[i] = xf * c[i]
	var was_flat := flat
	flat = true
	add_quad(c[4], c[5], c[6], c[7], col) # +z
	add_quad(c[1], c[0], c[3], c[2], col) # -z
	add_quad(c[5], c[1], c[2], c[6], col) # +x
	add_quad(c[0], c[4], c[7], c[3], col) # -x
	add_quad(c[7], c[6], c[2], c[3], col) # +y
	add_quad(c[0], c[1], c[5], c[4], col) # -y
	flat = was_flat


## Box with chamfered (beveled) vertical edges, good for panels and signs.
func add_bevel_box(xf: Transform3D, size: Vector3, bevel: float, col: Color) -> void:
	var h := size * 0.5
	var b := minf(bevel, minf(h.x, h.z) * 0.9)
	var outline := [
		Vector2(-h.x + b, -h.z), Vector2(h.x - b, -h.z), Vector2(h.x, -h.z + b), Vector2(h.x, h.z - b),
		Vector2(h.x - b, h.z), Vector2(-h.x + b, h.z), Vector2(-h.x, h.z - b), Vector2(-h.x, -h.z + b),
	]
	var bottom := PackedVector3Array()
	var top := PackedVector3Array()
	for p in outline:
		bottom.append(xf * Vector3(p.x, -h.y, p.y))
		top.append(xf * Vector3(p.x, h.y, p.y))
	var was_flat := flat
	flat = true
	add_rings([bottom, top], col, true, true, true)
	flat = was_flat


## Cylinder / cone frustum along local +Y from y=0 to y=height.
func add_cylinder(xf: Transform3D, r0: float, r1: float, height: float, segments: int, col: Color, caps := true) -> void:
	var bottom := PackedVector3Array()
	var top := PackedVector3Array()
	for i in segments:
		var a := TAU * float(i) / segments
		var d := Vector3(cos(a), 0.0, -sin(a))
		bottom.append(xf * (d * r0))
		top.append(xf * (d * r1 + Vector3(0, height, 0)))
	add_rings([bottom, top], col, true, caps, caps)


## Cylinder between two world points.
func add_tube(a: Vector3, b: Vector3, r0: float, r1: float, segments: int, col: Color, caps := true) -> void:
	var dir := b - a
	var h := dir.length()
	if h < 1e-5:
		return
	add_cylinder(Transform3D(basis_from_y(dir / h), a), r0, r1, h, segments, col, caps)


static func basis_from_y(y: Vector3) -> Basis:
	var ref := Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


## Surface of revolution around local Y. profile: Array of Vector2(radius, y).
func add_lathe(xf: Transform3D, profile: Array, segments: int, col: Color, cap_ends := false) -> void:
	var rings := []
	for p in profile:
		var ring := PackedVector3Array()
		for i in segments:
			var a := TAU * float(i) / segments
			ring.append(xf * Vector3(cos(a) * p.x, p.y, -sin(a) * p.x))
		rings.append(ring)
	add_rings(rings, col, true, cap_ends, cap_ends)


## UV sphere (use a scaled transform for ellipsoids).
func add_sphere(xf: Transform3D, radius: float, rings_n: int, segments: int, col: Color) -> void:
	var profile := []
	for r in rings_n + 1:
		var t := PI * float(r) / rings_n
		profile.append(Vector2(maxf(sin(t) * radius, 0.0005), -cos(t) * radius))
	add_lathe(xf, profile, segments, col, false)


## Torus in the local XY plane... axis along local X (like a wheel rolling along -Z).
func add_torus(xf: Transform3D, major: float, minor: float, seg_major: int, seg_minor: int, col: Color, minor_scale := Vector2.ONE) -> void:
	var rings := []
	for i in seg_major + 1:
		var a := TAU * float(i) / seg_major
		var center := Vector3(0.0, cos(a) * major, sin(a) * major)
		var radial := Vector3(0.0, cos(a), sin(a))
		var ring := PackedVector3Array()
		for j in seg_minor:
			var b := TAU * float(j) / seg_minor
			var p := center + radial * cos(b) * minor * minor_scale.y + Vector3.RIGHT * sin(b) * minor * minor_scale.x
			ring.append(xf * p)
		rings.append(ring)
	add_rings(rings, col, true)


## Loft through a list of cross-sections. Each section: {"z": float, "w": half width,
## "h": half height, "y": center height, "round": 0..1 (0 = box, 1 = ellipse)}.
## The loft runs along local -Z (forward).
func add_loft(xf: Transform3D, sections: Array, segments: int, col: Color, cap_start := true, cap_end := true) -> void:
	var rings := []
	for s in sections:
		var ring := PackedVector3Array()
		var rnd: float = s.get("round", 1.0)
		var top_scale: float = s.get("top", 1.0)
		for i in segments:
			var a := TAU * float(i) / segments
			var cx := cos(a)
			var cy := sin(a)
			# Superellipse blend between ellipse and rounded box.
			var e := lerpf(0.25, 1.0, rnd)
			var px := signf(cx) * pow(absf(cx), e)
			var py := signf(cy) * pow(absf(cy), e)
			var w: float = s["w"] * (top_scale if py > 0.0 else 1.0)
			ring.append(xf * Vector3(px * w, s["y"] + py * s["h"], s["z"]))
		rings.append(ring)
	add_rings(rings, col, true, cap_start, cap_end)


## Flat extrusion of a 2D polygon (in local XY) along local X by `thickness`.
func add_extrusion(xf: Transform3D, poly: PackedVector2Array, thickness: float, col: Color) -> void:
	var a := PackedVector3Array()
	var b := PackedVector3Array()
	for p in poly:
		a.append(xf * Vector3(-thickness * 0.5, p.y, p.x))
		b.append(xf * Vector3(thickness * 0.5, p.y, p.x))
	var was_flat := flat
	flat = true
	add_rings([a, b], col, true, false, false)
	var tris := Geometry2D.triangulate_polygon(poly)
	var xdir := xf.basis.x
	for t in range(0, tris.size(), 3):
		var p0 := poly[tris[t]]
		var p1 := poly[tris[t + 1]]
		var p2 := poly[tris[t + 2]]
		add_triangle_facing(xf * Vector3(thickness * 0.5, p0.y, p0.x), xf * Vector3(thickness * 0.5, p1.y, p1.x), xf * Vector3(thickness * 0.5, p2.y, p2.x), col, xdir)
		add_triangle_facing(xf * Vector3(-thickness * 0.5, p0.y, p0.x), xf * Vector3(-thickness * 0.5, p1.y, p1.x), xf * Vector3(-thickness * 0.5, p2.y, p2.x), col, -xdir)
	flat = was_flat


# --- Output ------------------------------------------------------------------

## Builds the mesh arrays for one surface (thread-safe).
func surface_arrays(name: String) -> Array:
	var s: Dictionary = _surfaces[name]
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = s["verts"]
	arrays[Mesh.ARRAY_NORMAL] = s["norms"]
	arrays[Mesh.ARRAY_COLOR] = s["cols"]
	arrays[Mesh.ARRAY_TEX_UV] = s["uvs"]
	# Our triangles are CCW; Godot front faces are CW.
	var idx: PackedInt32Array = s["idx"]
	var rev := PackedInt32Array()
	rev.resize(idx.size())
	for i in range(0, idx.size(), 3):
		rev[i] = idx[i]
		rev[i + 1] = idx[i + 2]
		rev[i + 2] = idx[i + 1]
	arrays[Mesh.ARRAY_INDEX] = rev
	return arrays


## Commits all non-empty surfaces. `materials` maps surface name -> Material.
func commit(materials: Dictionary = {}, mesh: ArrayMesh = null) -> ArrayMesh:
	if mesh == null:
		mesh = ArrayMesh.new()
	for name in surface_names():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays(name))
		var si := mesh.get_surface_count() - 1
		mesh.surface_set_name(si, name)
		if materials.has(name):
			mesh.surface_set_material(si, materials[name])
	return mesh

class_name PropMeshes
extends RefCounted
## Procedural low-poly prop meshes. All colors are vertex colors so one shared material
## covers everything; emissive parts use a "lamp" surface.

static var _cache: Dictionary = {}


static func vertex_material(rough := 0.9) -> StandardMaterial3D:
	var key := "vmat_%f" % rough
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	_cache[key] = m
	return m


static func foliage_material() -> StandardMaterial3D:
	if _cache.has("foliage"):
		return _cache["foliage"]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.backlight_enabled = true
	m.backlight = Color(0.25, 0.3, 0.1)
	_cache["foliage"] = m
	return m


static func lamp_material(color := Color(1.0, 0.82, 0.55), energy := 4.0) -> StandardMaterial3D:
	var key := "lamp_%s_%f" % [color.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cache[key] = m
	return m


static func reflector_material() -> StandardMaterial3D:
	if _cache.has("reflector"):
		return _cache["reflector"]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.emission_enabled = true
	m.emission = Color(1.0, 0.45, 0.1)
	m.emission_energy_multiplier = 0.6
	m.roughness = 0.3
	_cache["reflector"] = m
	return m


static func _commit(mb: MeshBuilder) -> ArrayMesh:
	return mb.commit({
		"default": vertex_material(),
		"foliage": foliage_material(),
		"lamp": lamp_material(),
		"reflector": reflector_material(),
	})


# --- Rocks -------------------------------------------------------------------

static func rock(seed_value: int, base: Color, size := 1.0, flatness := 0.7) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mb := MeshBuilder.new(true)
	var rings_n := 5
	var segs := 7
	var rings := []
	var noise := []
	for s in segs:
		noise.append(rng.randf_range(0.75, 1.25))
	for r in rings_n + 1:
		var t := PI * float(r) / rings_n
		var ring := PackedVector3Array()
		for s in segs:
			var a := TAU * float(s) / segs
			var k: float = noise[s] * rng.randf_range(0.85, 1.15)
			var rad := sin(t) * size * k
			ring.append(Vector3(cos(a) * rad, -cos(t) * size * flatness * rng.randf_range(0.9, 1.1), sin(a) * rad))
		rings.append(ring)
	var col := base * rng.randf_range(0.85, 1.1)
	col.a = 1.0
	mb.add_rings(rings, col, true)
	return _commit(mb)


# --- Trees -------------------------------------------------------------------

## Acacia (Vachellia tortilis): short split trunk and a flat umbrella canopy.
static func acacia(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mb := MeshBuilder.new(true)
	var bark := Color(0.30, 0.22, 0.16)
	var trunk_top := Vector3(rng.randf_range(-0.2, 0.2), 1.3, rng.randf_range(-0.2, 0.2))
	mb.add_tube(Vector3.ZERO, trunk_top, 0.16, 0.12, 6, bark)
	var canopy_h := rng.randf_range(3.0, 3.8)
	var branches := rng.randi_range(3, 4)
	var tips := []
	for b in branches:
		var a := TAU * b / branches + rng.randf_range(-0.4, 0.4)
		var r := rng.randf_range(1.2, 2.2)
		var tip := Vector3(cos(a) * r, canopy_h - rng.randf_range(0.0, 0.4), sin(a) * r)
		mb.add_tube(trunk_top, tip, 0.1, 0.05, 5, bark)
		tips.append(tip)
	mb.surface("foliage")
	var green := Color(0.36, 0.42, 0.18)
	for tip in tips:
		var s := rng.randf_range(1.4, 2.1)
		var xf := Transform3D(Basis().scaled(Vector3(s, 0.32, s)), tip + Vector3(0, 0.25, 0))
		mb.add_sphere(xf, 1.0, 3, 7, green * rng.randf_range(0.85, 1.1))
	var xf2 := Transform3D(Basis().scaled(Vector3(2.4, 0.35, 2.2)), Vector3(0, canopy_h + 0.35, 0))
	mb.add_sphere(xf2, 1.0, 3, 8, green * 1.05)
	return _commit(mb)


## Date palm: curved ringed trunk with a crown of arching fronds.
static func palm(seed_value: int, height := 9.0) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mb := MeshBuilder.new(true)
	var bark := Color(0.42, 0.33, 0.24)
	var lean := Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-1.0, 1.0)) * 0.08
	var prev := Vector3.ZERO
	var segs := 7
	for s in range(1, segs + 1):
		var t := float(s) / segs
		var p := Vector3(lean.x * t * t * height, t * height, lean.z * t * t * height)
		var c := bark * (0.9 if s % 2 == 0 else 1.05)
		mb.add_tube(prev, p, 0.28 - t * 0.06, 0.26 - t * 0.06, 6, c)
		prev = p
	var top := prev
	mb.surface("foliage")
	var fronds := rng.randi_range(9, 12)
	for f in fronds:
		var a := TAU * f / fronds + rng.randf_range(-0.2, 0.2)
		var dir := Vector3(cos(a), 0, sin(a))
		var side := dir.cross(Vector3.UP).normalized()
		var length := rng.randf_range(3.4, 4.4)
		var droop := rng.randf_range(0.6, 1.4)
		var col := Color(0.30, 0.44, 0.16) * rng.randf_range(0.85, 1.15)
		var pts := []
		for k in 6:
			var t := float(k) / 5.0
			pts.append(top + dir * length * t + Vector3.UP * (sin(t * PI * 0.8) * 0.9 - t * t * droop * 1.8))
		for k in 5:
			var w0 := 0.55 * sin(PI * (k / 5.0) * 0.9 + 0.2)
			var w1 := 0.55 * sin(PI * ((k + 1) / 5.0) * 0.9 + 0.2)
			var p0: Vector3 = pts[k]
			var p1: Vector3 = pts[k + 1]
			# V-shaped frond cross-section.
			var dn := Vector3.DOWN * 0.12
			mb.add_quad(p0, p1, p1 + side * w1 + dn, p0 + side * w0 + dn, col)
			mb.add_quad(p0 - side * w0 + dn, p1 - side * w1 + dn, p1, p0, col * 0.9)
	# Date clusters.
	mb.surface("default")
	for d in 3:
		var a := rng.randf() * TAU
		mb.add_sphere(Transform3D(Basis().scaled(Vector3(1, 1.3, 1)), top + Vector3(cos(a) * 0.35, -0.5, sin(a) * 0.35)), 0.22, 3, 5, Color(0.72, 0.42, 0.12))
	return _commit(mb)


## Aleppo pine for the Jerusalem hills: leaning trunk with irregular foliage clumps.
static func pine(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mb := MeshBuilder.new(true)
	var bark := Color(0.27, 0.20, 0.16)
	var h := rng.randf_range(7.0, 11.0)
	var top := Vector3(rng.randf_range(-0.8, 0.8), h, rng.randf_range(-0.8, 0.8))
	mb.add_tube(Vector3.ZERO, top, 0.28, 0.12, 6, bark)
	mb.surface("foliage")
	var green := Color(0.16, 0.27, 0.13)
	var clumps := rng.randi_range(4, 6)
	for c in clumps:
		var t := rng.randf_range(0.45, 1.0)
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.6, 2.2) * (1.2 - t)
		var center := top * t + Vector3(cos(a) * r, 0.3, sin(a) * r)
		var s := rng.randf_range(1.4, 2.4) * (1.25 - t * 0.4)
		mb.add_sphere(Transform3D(Basis().scaled(Vector3(s, s * 0.6, s)), center), 1.0, 3, 6, green * rng.randf_range(0.8, 1.2))
	return _commit(mb)


## Italian cypress: tall narrow flame shape.
static func cypress(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mb := MeshBuilder.new(true)
	mb.add_tube(Vector3.ZERO, Vector3(0, 1.0, 0), 0.18, 0.15, 5, Color(0.25, 0.18, 0.14))
	mb.surface("foliage")
	var h := rng.randf_range(7.0, 10.0)
	var prof := []
	for k in 8:
		var t := float(k) / 7.0
		prof.append(Vector2(maxf(sin(pow(t, 0.7) * PI) * 1.0 * (1.0 - t * 0.35), 0.02), 0.6 + t * h))
	mb.add_lathe(Transform3D(), prof, 7, Color(0.12, 0.22, 0.12) * rng.randf_range(0.9, 1.1), true)
	return _commit(mb)


## Desert shrub / Mediterranean bush.
static func bush(seed_value: int, col: Color) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mb := MeshBuilder.new(true)
	mb.surface("foliage")
	for k in rng.randi_range(2, 4):
		var s := rng.randf_range(0.4, 0.8)
		mb.add_sphere(Transform3D(Basis().scaled(Vector3(s, s * 0.7, s)), Vector3(rng.randf_range(-0.5, 0.5), s * 0.45, rng.randf_range(-0.5, 0.5))), 1.0, 3, 5, col * rng.randf_range(0.85, 1.15))
	return _commit(mb)


# --- Road furniture ----------------------------------------------------------

## Roadside delineator post: white post, black band, amber reflector facing traffic (-Z).
static func reflector_post() -> ArrayMesh:
	var mb := MeshBuilder.new(true)
	mb.add_box(Transform3D(Basis(), Vector3(0, 0.5, 0)), Vector3(0.12, 1.0, 0.12), Color(0.93, 0.93, 0.9))
	mb.add_box(Transform3D(Basis(), Vector3(0, 0.82, 0)), Vector3(0.125, 0.14, 0.125), Color(0.05, 0.05, 0.05))
	mb.surface("reflector")
	mb.add_box(Transform3D(Basis(), Vector3(0, 0.82, -0.066)), Vector3(0.07, 0.1, 0.01), Color(1.0, 0.55, 0.1))
	mb.add_box(Transform3D(Basis(), Vector3(0, 0.82, 0.066)), Vector3(0.07, 0.1, 0.01), Color(0.95, 0.95, 0.95))
	return _commit(mb)


## Street light: pole with an arm reaching over the road (+X), emissive lamp head.
static func streetlight() -> ArrayMesh:
	var mb := MeshBuilder.new(true)
	var grey := Color(0.45, 0.46, 0.48)
	mb.add_cylinder(Transform3D(), 0.12, 0.08, 8.5, 8, grey)
	mb.add_tube(Vector3(0, 8.3, 0), Vector3(1.8, 8.7, 0), 0.06, 0.05, 6, grey)
	mb.add_box(Transform3D(Basis(), Vector3(2.1, 8.65, 0)), Vector3(0.8, 0.18, 0.32), Color(0.3, 0.3, 0.32))
	mb.surface("lamp")
	mb.add_box(Transform3D(Basis(), Vector3(2.1, 8.54, 0)), Vector3(0.6, 0.05, 0.22), Color(1, 0.85, 0.6))
	return _commit(mb)


## Low stone terrace wall block (Jerusalem limestone), 4 m long along local Z.
static func stone_wall(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mb := MeshBuilder.new(true)
	var z := -2.0
	while z < 2.0:
		var l := rng.randf_range(0.5, 0.9)
		l = minf(l, 2.0 - z)
		for row in 2:
			var h := rng.randf_range(0.36, 0.46)
			var c := Color(0.80, 0.74, 0.62) * rng.randf_range(0.82, 1.08)
			c.a = 1.0
			var off := 0.0 if row == 0 else rng.randf_range(-0.15, 0.15)
			mb.add_box(Transform3D(Basis(), Vector3(rng.randf_range(-0.03, 0.03), 0.2 + row * 0.42, clampf(z + l * 0.5 + off, -1.8, 1.8))), Vector3(0.55, h, l * 0.96), c)
		z += l
	return _commit(mb)


## Concrete jersey barrier segment, 3 m long along local Z.
static func barrier() -> ArrayMesh:
	var mb := MeshBuilder.new(true)
	var poly := PackedVector2Array([Vector2(-0.3, 0), Vector2(0.3, 0), Vector2(0.28, 0.08), Vector2(0.12, 0.3), Vector2(0.08, 0.8), Vector2(-0.08, 0.8), Vector2(-0.12, 0.3), Vector2(-0.28, 0.08)])
	# Extrusion runs along local X; rotate so it runs along Z.
	var xf := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)
	mb.add_extrusion(xf, poly, 3.0, Color(0.78, 0.77, 0.74))
	return _commit(mb)

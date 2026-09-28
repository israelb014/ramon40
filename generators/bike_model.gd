class_name BikeModel
extends RefCounted
## Procedural motorcycle models. Origin on the ground midway between the tire contact
## patches, forward = -Z, up = +Y. Returns a node hierarchy ready for animation:
##
##   BikeModel (Node3D)
##     Lean (Node3D)                roll around the ground contact line
##       Pitch (Node3D)             wheelie / stoppie
##         Body (MeshInstance3D)
##         RearWheel (Node3D) -> Mesh
##         Steer (Node3D)           rotates around the steering axis
##           Fork (MeshInstance3D), FrontWheel (Node3D) -> Mesh, BarL, BarR (Marker3D)
##         Seat, PegL, PegR, Exhaust, Headlight, Taillight (Marker3D)

const WHEELBASE := {"sport": 1.40, "naked": 1.42, "supermoto": 1.48, "cafe": 1.45}

static var _mat_cache: Dictionary = {}


static func materials(paint: Color, accent: Color, bike_id: String) -> Dictionary:
	var m := {}
	var p := StandardMaterial3D.new()
	p.albedo_color = paint
	p.metallic = 0.35
	p.roughness = 0.28
	p.clearcoat_enabled = true
	p.clearcoat = 0.8
	p.clearcoat_roughness = 0.1
	m["paint"] = p
	var a := StandardMaterial3D.new()
	a.albedo_color = accent
	a.metallic = 0.2
	a.roughness = 0.35
	m["accent"] = a
	m["black"] = _std("black", Color(0.05, 0.05, 0.055), 0.0, 0.55)
	m["rubber"] = _std("rubber", Color(0.035, 0.035, 0.035), 0.0, 0.92)
	m["metal"] = _std("metal", Color(0.55, 0.56, 0.58), 0.85, 0.35)
	m["chrome"] = _std("chrome", Color(0.9, 0.9, 0.92), 1.0, 0.12)
	m["engine"] = _std("engine", Color(0.22, 0.22, 0.24), 0.7, 0.45)
	m["seat"] = _std("seat", Color(0.07, 0.06, 0.06), 0.0, 0.7)
	m["frame"] = _std("frame_" + bike_id, _frame_color(bike_id), 0.6, 0.35)
	m["glass"] = _std("glass", Color(0.12, 0.14, 0.18, 0.55), 0.2, 0.05)
	m["glass"].transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var lf := StandardMaterial3D.new()
	lf.albedo_color = Color(1, 1, 0.95)
	lf.emission_enabled = true
	lf.emission = Color(1.0, 0.95, 0.85)
	lf.emission_energy_multiplier = 3.0
	m["light_front"] = lf
	var lr := StandardMaterial3D.new()
	lr.albedo_color = Color(0.8, 0.05, 0.03)
	lr.emission_enabled = true
	lr.emission = Color(1.0, 0.05, 0.02)
	lr.emission_energy_multiplier = 2.0
	m["light_rear"] = lr
	return m


static func _frame_color(bike_id: String) -> Color:
	match bike_id:
		"naked":
			return Color(0.75, 0.12, 0.08)
		"supermoto":
			return Color(0.2, 0.2, 0.22)
		"cafe":
			return Color(0.06, 0.06, 0.06)
	return Color(0.3, 0.3, 0.32)


static func _std(key: String, c: Color, metal: float, rough: float) -> StandardMaterial3D:
	if _mat_cache.has(key):
		return _mat_cache[key]
	var s := StandardMaterial3D.new()
	s.albedo_color = c
	s.metallic = metal
	s.roughness = rough
	_mat_cache[key] = s
	return s


static func build(bike_id: String, paint: Color, accent: Color) -> Node3D:
	var mats := materials(paint, accent, bike_id)
	var wb: float = WHEELBASE.get(bike_id, 1.42)
	var root := Node3D.new()
	root.name = "BikeModel"
	root.set_meta("bike_id", bike_id)
	root.set_meta("wheelbase", wb)
	var lean := Node3D.new()
	lean.name = "Lean"
	root.add_child(lean)
	var pitch := Node3D.new()
	pitch.name = "Pitch"
	lean.add_child(pitch)

	var r_wheel := 0.31 if bike_id != "supermoto" else 0.33
	var front_axle := Vector3(0, r_wheel, -wb * 0.5)
	var rear_axle := Vector3(0, r_wheel, wb * 0.5)
	root.set_meta("wheel_radius", r_wheel)

	var geo := {}
	match bike_id:
		"sport":
			geo = _sport(wb, r_wheel)
		"supermoto":
			geo = _supermoto(wb, r_wheel)
		"cafe":
			geo = _cafe(wb, r_wheel)
		_:
			geo = _naked(wb, r_wheel)

	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = (geo["body"] as MeshBuilder).commit(mats)
	pitch.add_child(body)

	# Rear wheel.
	var rw := Node3D.new()
	rw.name = "RearWheel"
	rw.position = rear_axle
	pitch.add_child(rw)
	var rwm := MeshInstance3D.new()
	rwm.name = "Mesh"
	rwm.mesh = _wheel(bike_id, r_wheel, true).commit(mats)
	rw.add_child(rwm)

	# Steering assembly.
	var head: Vector3 = geo["head"]
	var axis := (head - front_axle).normalized()
	var steer_basis := Basis(Vector3.RIGHT, axis, Vector3.RIGHT.cross(axis).normalized())
	var steer_xf := Transform3D(steer_basis, head)
	var steer := Node3D.new()
	steer.name = "Steer"
	steer.transform = steer_xf
	steer.set_meta("base_basis", steer_basis)
	pitch.add_child(steer)
	var inv := steer_xf.affine_inverse()
	var fork := MeshInstance3D.new()
	fork.name = "Fork"
	fork.mesh = (geo["front"] as MeshBuilder).commit(mats)
	fork.transform = inv
	steer.add_child(fork)
	var fw := Node3D.new()
	fw.name = "FrontWheel"
	fw.transform = Transform3D(inv.basis, inv * front_axle)
	steer.add_child(fw)
	var fwm := MeshInstance3D.new()
	fwm.name = "Mesh"
	fwm.mesh = _wheel(bike_id, r_wheel, false).commit(mats)
	fw.add_child(fwm)
	for side in ["L", "R"]:
		var bar := Marker3D.new()
		bar.name = "Bar" + side
		var bp: Vector3 = geo["bar"]
		bar.position = inv * Vector3(bp.x * (-1.0 if side == "L" else 1.0), bp.y, bp.z)
		steer.add_child(bar)

	for key in ["seat", "exhaust", "headlight", "taillight"]:
		var mk := Marker3D.new()
		mk.name = key.capitalize()
		mk.position = geo[key]
		pitch.add_child(mk)
	for side in ["L", "R"]:
		var peg := Marker3D.new()
		peg.name = "Peg" + side
		var pp: Vector3 = geo["peg"]
		peg.position = Vector3(pp.x * (-1.0 if side == "L" else 1.0), pp.y, pp.z)
		pitch.add_child(peg)
	root.set_meta("rider_style", geo.get("rider", "sport"))
	return root


# --- Shared parts ------------------------------------------------------------

static func _wheel(bike_id: String, r: float, rear: bool) -> MeshBuilder:
	var mb := MeshBuilder.new(false)
	var width := 0.075 if not rear else 0.095
	if bike_id == "cafe":
		width = 0.06 if not rear else 0.07
	var minor := width
	var major := r - minor
	var tire_xf := Transform3D()
	mb.surface("rubber")
	mb.add_torus(tire_xf, major, minor, 28, 8, Color.WHITE, Vector2(1.0, 0.85))
	if bike_id == "supermoto":
		# Knobby tread blocks.
		mb.flat = true
		for i in 36:
			var a := TAU * i / 36.0
			var p := Vector3(((i % 2) - 0.5) * minor * 0.7, cos(a) * (r - 0.012), sin(a) * (r - 0.012))
			mb.add_box(Transform3D(Basis(Vector3.RIGHT, -a), p), Vector3(minor * 0.6, 0.018, 0.032), Color.WHITE)
		mb.flat = false
	var rim_r := major - minor * 0.55
	var spoked := bike_id == "cafe" or bike_id == "supermoto"
	var rim_surface := "chrome" if bike_id == "cafe" else ("metal" if spoked else "black")
	mb.surface(rim_surface)
	mb.add_torus(Transform3D(), rim_r, 0.018, 28, 5, Color.WHITE, Vector2(2.2, 1.0))
	mb.surface("metal")
	# Hub.
	mb.add_cylinder(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-0.06, 0, 0)), 0.05, 0.05, 0.12, 10, Color.WHITE)
	if spoked:
		mb.flat = true
		for i in 24:
			var a := TAU * i / 24.0
			var side := -0.045 if i % 2 == 0 else 0.045
			var outer := Vector3(0, cos(a + 0.12) * rim_r, sin(a + 0.12) * rim_r)
			mb.add_tube(Vector3(side, 0, 0), outer, 0.0045, 0.0045, 3, Color.WHITE, false)
		mb.flat = false
	else:
		mb.surface("black" if bike_id == "sport" else "accent")
		mb.flat = true
		for i in 5:
			var a := TAU * i / 5.0
			var tip := Vector3(0, cos(a) * rim_r, sin(a) * rim_r)
			var mid := Vector3(0, cos(a + 0.35) * rim_r * 0.55, sin(a + 0.35) * rim_r * 0.55)
			mb.add_tube(Vector3.ZERO, mid, 0.022, 0.018, 5, Color.WHITE, false)
			mb.add_tube(mid, tip, 0.018, 0.014, 5, Color.WHITE, false)
		mb.flat = false
	# Brake disc(s).
	mb.surface("metal")
	var discs := [-0.07, 0.07] if (not rear and bike_id != "cafe" and bike_id != "supermoto") else [0.06]
	for dx in discs:
		var dr := 0.15 if not rear else 0.11
		if bike_id == "supermoto" and not rear:
			dr = 0.16
		mb.add_cylinder(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(dx - 0.004, 0, 0)), dr, dr, 0.008, 20, Color.WHITE)
	return mb


## Telescopic fork, fender, bars, headlight etc. built in bike space.
static func _fork(mb: MeshBuilder, head: Vector3, axle: Vector3, spread: float, r_top: float, r_bot: float, surface_top := "metal", surface_bot := "black") -> void:
	var dir := (axle - head).normalized()
	for sx in [-spread, spread]:
		var top := head + Vector3(sx, 0.02, 0) - dir * 0.05
		var mid := head.lerp(axle, 0.5) + Vector3(sx, 0, 0)
		var bot := axle + Vector3(sx, 0, 0) - dir * 0.02
		mb.surface(surface_top)
		mb.add_tube(top, mid, r_top, r_top, 10, Color.WHITE)
		mb.surface(surface_bot)
		mb.add_tube(mid - dir * 0.05, bot, r_bot, r_bot * 0.9, 10, Color.WHITE)
	mb.surface("black")
	# Triple clamps.
	mb.add_box(Transform3D(_axis_basis(dir), head + dir * 0.02), Vector3(spread * 2.0 + 0.09, 0.04, 0.09), Color.WHITE)
	mb.add_box(Transform3D(_axis_basis(dir), head + dir * 0.16), Vector3(spread * 2.0 + 0.09, 0.05, 0.09), Color.WHITE)


static func _axis_basis(dir: Vector3) -> Basis:
	var y := -dir
	var x := Vector3.RIGHT
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


static func _handlebar(mb: MeshBuilder, center: Vector3, half: float, rise: float, sweep: float, surface := "black") -> Vector3:
	mb.surface(surface)
	var left := center + Vector3(-half, rise, sweep)
	var right := center + Vector3(half, rise, sweep)
	mb.add_tube(center + Vector3(-0.05, 0, 0), left, 0.013, 0.013, 6, Color.WHITE)
	mb.add_tube(center + Vector3(0.05, 0, 0), right, 0.013, 0.013, 6, Color.WHITE)
	mb.add_tube(center + Vector3(-0.05, 0, 0), center + Vector3(0.05, 0, 0), 0.016, 0.016, 6, Color.WHITE)
	mb.surface("rubber")
	for p in [left, right]:
		var outward := Vector3(signf(p.x), 0, 0)
		mb.add_tube(p - outward * 0.11, p + outward * 0.01, 0.019, 0.019, 8, Color.WHITE)
	# Levers and mirrors stems.
	mb.surface("metal")
	for p in [left, right]:
		mb.add_tube(p - Vector3(signf(p.x) * 0.06, 0, 0), p + Vector3(-signf(p.x) * 0.04, -0.01, -0.12), 0.006, 0.006, 4, Color.WHITE)
	return right + Vector3(-0.05, 0, 0)


static func _round_headlight(mb: MeshBuilder, pos: Vector3, radius: float, bucket_surface := "chrome") -> void:
	mb.surface(bucket_surface)
	var prof := [Vector2(radius * 0.3, 0.1), Vector2(radius * 0.85, 0.07), Vector2(radius, 0.0), Vector2(radius * 1.02, -0.01)]
	mb.add_lathe(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), pos), prof, 16, Color.WHITE, true)
	mb.surface("light_front")
	mb.add_cylinder(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), pos + Vector3(0, 0, -0.005)), radius * 0.9, radius * 0.75, 0.02, 16, Color.WHITE)


static func _exhaust_can(mb: MeshBuilder, a: Vector3, b: Vector3, r: float, surface := "metal", tip_surface := "black") -> void:
	mb.surface(surface)
	mb.add_tube(a, b, r, r * 0.9, 14, Color.WHITE)
	mb.surface(tip_surface)
	var dir := (b - a).normalized()
	mb.add_tube(b, b + dir * 0.03, r * 0.6, r * 0.6, 12, Color.WHITE)


# --- Sport -------------------------------------------------------------------

static func _sport(wb: float, rw: float) -> Dictionary:
	var body := MeshBuilder.new(false)
	var front := MeshBuilder.new(false)
	var fz := -wb * 0.5
	var rz := wb * 0.5
	var head := Vector3(0, 0.98, fz + 0.30)
	# Frame spars (twin beam).
	body.surface("frame")
	for sx in [-0.14, 0.14]:
		body.add_tube(head + Vector3(sx * 0.5, -0.02, 0.04), Vector3(sx, 0.72, -0.05), 0.035, 0.04, 8, Color.WHITE)
		body.add_tube(Vector3(sx, 0.72, -0.05), Vector3(sx, 0.48, 0.12), 0.04, 0.04, 8, Color.WHITE)
	# Swingarm to the rear axle.
	body.surface("black")
	for sx in [-0.1, 0.1]:
		body.add_tube(Vector3(sx, 0.45, 0.1), Vector3(sx, rw, rz), 0.03, 0.022, 8, Color.WHITE)
	# Engine block.
	body.surface("engine")
	body.flat = true
	body.add_bevel_box(Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0, 0.44, -0.18)), Vector3(0.34, 0.34, 0.36), 0.06, Color.WHITE)
	body.add_bevel_box(Transform3D(Basis(), Vector3(0, 0.32, 0.02)), Vector3(0.32, 0.18, 0.3), 0.05, Color.WHITE)
	body.flat = false
	# Main fairing: pointed nose -> side panels -> belly.
	body.surface("paint")
	body.flat = true
	body.add_loft(Transform3D(), [
		{"z": fz - 0.04, "y": 0.8, "w": 0.04, "h": 0.05, "round": 0.8},
		{"z": fz + 0.08, "y": 0.83, "w": 0.13, "h": 0.12, "round": 0.55},
		{"z": fz + 0.26, "y": 0.8, "w": 0.2, "h": 0.2, "round": 0.45},
		{"z": fz + 0.5, "y": 0.66, "w": 0.22, "h": 0.25, "round": 0.4},
		{"z": fz + 0.76, "y": 0.5, "w": 0.19, "h": 0.24, "round": 0.4},
		{"z": fz + 0.9, "y": 0.44, "w": 0.12, "h": 0.16, "round": 0.6},
	], 12, Color.WHITE, true, true)
	body.flat = false
	# Belly pan in accent.
	body.surface("accent")
	body.add_loft(Transform3D(), [
		{"z": fz + 0.38, "y": 0.3, "w": 0.22, "h": 0.07, "round": 0.6},
		{"z": fz + 0.7, "y": 0.24, "w": 0.2, "h": 0.07, "round": 0.6},
		{"z": fz + 0.9, "y": 0.28, "w": 0.12, "h": 0.05, "round": 0.8},
	], 12, Color.WHITE)
	# Tank.
	body.surface("paint")
	body.add_loft(Transform3D(), [
		{"z": -0.34, "y": 0.96, "w": 0.13, "h": 0.07, "round": 0.9},
		{"z": -0.2, "y": 0.99, "w": 0.19, "h": 0.1, "round": 0.85},
		{"z": 0.0, "y": 0.95, "w": 0.18, "h": 0.09, "round": 0.85},
		{"z": 0.1, "y": 0.9, "w": 0.13, "h": 0.05, "round": 0.9},
	], 14, Color.WHITE)
	# Seat and tail.
	body.surface("seat")
	body.add_loft(Transform3D(), [
		{"z": 0.08, "y": 0.9, "w": 0.13, "h": 0.035, "round": 0.8},
		{"z": 0.3, "y": 0.92, "w": 0.12, "h": 0.035, "round": 0.8},
	], 12, Color.WHITE)
	body.surface("paint")
	body.add_loft(Transform3D(), [
		{"z": 0.05, "y": 0.82, "w": 0.16, "h": 0.08, "round": 0.7},
		{"z": 0.34, "y": 0.87, "w": 0.13, "h": 0.07, "round": 0.7},
		{"z": 0.6, "y": 0.96, "w": 0.07, "h": 0.045, "round": 0.8},
		{"z": 0.7, "y": 0.98, "w": 0.04, "h": 0.03, "round": 1.0},
	], 12, Color.WHITE)
	body.surface("light_rear")
	body.add_box(Transform3D(Basis(Vector3.RIGHT, 0.4), Vector3(0, 0.99, 0.69)), Vector3(0.09, 0.03, 0.05), Color.WHITE)
	# Rear hugger / license bracket.
	body.surface("black")
	body.add_tube(Vector3(0, 0.84, 0.6), Vector3(0, 0.62, 0.86), 0.02, 0.02, 6, Color.WHITE)
	body.add_box(Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0, 0.6, 0.88)), Vector3(0.18, 0.12, 0.01), Color.WHITE)
	# Rear shock + subframe.
	body.surface("accent")
	body.add_tube(Vector3(0, 0.44, 0.2), Vector3(0, 0.72, 0.12), 0.03, 0.03, 8, Color.WHITE)
	# Underbelly exhaust with side can.
	_exhaust_can(body, Vector3(0.1, 0.3, 0.26), Vector3(0.14, 0.52, 0.6), 0.055, "metal", "black")
	body.surface("metal")
	body.add_tube(Vector3(0, 0.26, -0.1), Vector3(0.1, 0.3, 0.26), 0.028, 0.028, 8, Color.WHITE)
	# Rear-set pegs.
	body.surface("metal")
	for sx in [-0.17, 0.17]:
		body.add_tube(Vector3(sx * 0.6, 0.42, 0.2), Vector3(sx, 0.4, 0.22), 0.012, 0.012, 5, Color.WHITE)

	# Front assembly.
	var axle := Vector3(0, rw, fz)
	_fork(front, head, axle, 0.1, 0.028, 0.036, "chrome", "accent")
	front.surface("paint")
	front.add_loft(Transform3D(), [
		{"z": fz - 0.18, "y": rw + 0.12, "w": 0.05, "h": 0.025, "round": 1.0},
		{"z": fz, "y": rw + 0.19, "w": 0.075, "h": 0.03, "round": 0.9},
		{"z": fz + 0.17, "y": rw + 0.14, "w": 0.07, "h": 0.025, "round": 1.0},
	], 10, Color.WHITE)
	var bar := _handlebar(front, head + Vector3(0, -0.06, 0.03), 0.3, -0.03, 0.06)
	# Screen and headlights ride on the fairing (body), but the dash moves with the bars.
	front.surface("black")
	front.add_box(Transform3D(Basis(Vector3.RIGHT, -0.9), head + Vector3(0, 0.06, -0.08)), Vector3(0.16, 0.1, 0.02), Color.WHITE)
	# Windscreen (on body), sloping up from the nose toward the rider.
	body.surface("glass")
	body.add_loft(Transform3D(), [
		{"z": fz + 0.1, "y": 0.955, "w": 0.1, "h": 0.01, "round": 1.0},
		{"z": fz + 0.24, "y": 1.04, "w": 0.13, "h": 0.01, "round": 1.0},
		{"z": fz + 0.3, "y": 1.06, "w": 0.12, "h": 0.01, "round": 1.0},
	], 10, Color.WHITE)
	body.surface("light_front")
	for sx in [-0.1, 0.1]:
		body.add_box(Transform3D(Basis(Vector3.UP, -sx * 2.0), Vector3(sx, 0.84, fz + 0.03)), Vector3(0.09, 0.035, 0.03), Color.WHITE)
	return {"body": body, "front": front, "head": head, "bar": bar, "seat": Vector3(0, 0.93, 0.18),
		"peg": Vector3(0.17, 0.4, 0.22), "exhaust": Vector3(0.15, 0.54, 0.64),
		"headlight": Vector3(0, 0.84, fz - 0.02), "taillight": Vector3(0, 0.99, 0.7), "rider": "sport"}


# --- Naked -------------------------------------------------------------------

static func _naked(wb: float, rw: float) -> Dictionary:
	var body := MeshBuilder.new(false)
	var front := MeshBuilder.new(false)
	var fz := -wb * 0.5
	var rz := wb * 0.5
	var head := Vector3(0, 1.0, fz + 0.32)
	# Trellis frame in the frame color.
	body.surface("frame")
	var nodes := [head + Vector3(0, -0.04, 0.04), Vector3(0, 0.82, -0.02), Vector3(0, 0.46, 0.1), Vector3(0, 0.7, -0.26), Vector3(0, 0.5, -0.2)]
	for sx in [-0.15, 0.15]:
		var pts := []
		for n in nodes:
			pts.append(Vector3(sx if n.z < 0.2 else sx * 0.8, n.y, n.z))
		body.add_tube(nodes[0], pts[1], 0.022, 0.022, 6, Color.WHITE)
		body.add_tube(pts[1], pts[2], 0.022, 0.022, 6, Color.WHITE)
		body.add_tube(nodes[0], pts[3], 0.022, 0.022, 6, Color.WHITE)
		body.add_tube(pts[3], pts[1], 0.018, 0.018, 6, Color.WHITE)
		body.add_tube(pts[3], pts[4], 0.018, 0.018, 6, Color.WHITE)
		body.add_tube(pts[4], pts[2], 0.018, 0.018, 6, Color.WHITE)
		# Subframe.
		body.add_tube(pts[1], Vector3(sx * 0.6, 0.9, 0.5), 0.016, 0.016, 6, Color.WHITE)
		body.add_tube(pts[2], Vector3(sx * 0.6, 0.9, 0.5), 0.016, 0.016, 6, Color.WHITE)
	# Single-sided-look swingarm.
	body.surface("metal")
	for sx in [-0.11, 0.11]:
		body.add_tube(Vector3(sx, 0.45, 0.1), Vector3(sx, rw, rz), 0.035, 0.024, 8, Color.WHITE)
	# Triple engine: crankcase + three finned cylinders, radiator in front.
	body.surface("engine")
	body.flat = true
	body.add_bevel_box(Transform3D(Basis(), Vector3(0, 0.36, -0.06)), Vector3(0.36, 0.24, 0.36), 0.06, Color.WHITE)
	for cx in [-0.1, 0.0, 0.1]:
		body.add_bevel_box(Transform3D(Basis(Vector3.RIGHT, 0.4), Vector3(cx, 0.58, -0.2)), Vector3(0.09, 0.26, 0.16), 0.02, Color.WHITE)
	body.flat = false
	body.surface("metal")
	for cx in [-0.1, 0.0, 0.1]:
		for k in 4:
			body.add_box(Transform3D(Basis(Vector3.RIGHT, 0.4), Vector3(cx, 0.52 + k * 0.045, -0.2 - k * 0.018)), Vector3(0.1, 0.008, 0.18), Color.WHITE)
	body.surface("black")
	body.add_box(Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(0, 0.56, -0.4)), Vector3(0.34, 0.3, 0.05), Color.WHITE)
	# Header pipes to a short underbelly can + side can.
	body.surface("chrome")
	for cx in [-0.08, 0.0, 0.08]:
		body.add_tube(Vector3(cx, 0.5, -0.33), Vector3(cx * 1.2, 0.22, -0.2), 0.02, 0.02, 8, Color.WHITE)
		body.add_tube(Vector3(cx * 1.2, 0.22, -0.2), Vector3(0.12, 0.24, 0.2), 0.02, 0.02, 8, Color.WHITE)
	_exhaust_can(body, Vector3(0.14, 0.28, 0.22), Vector3(0.18, 0.42, 0.52), 0.06, "metal", "black")
	# Muscular angular tank with shrouds.
	body.surface("paint")
	body.flat = true
	body.add_loft(Transform3D(), [
		{"z": -0.42, "y": 0.9, "w": 0.13, "h": 0.1, "round": 0.4},
		{"z": -0.28, "y": 0.97, "w": 0.22, "h": 0.14, "round": 0.4},
		{"z": -0.05, "y": 0.98, "w": 0.21, "h": 0.12, "round": 0.45},
		{"z": 0.08, "y": 0.93, "w": 0.14, "h": 0.07, "round": 0.6},
	], 12, Color.WHITE)
	body.surface("accent")
	for sx in [-1.0, 1.0]:
		var poly := PackedVector2Array([Vector2(-0.42, 0.9), Vector2(-0.22, 0.9), Vector2(-0.16, 0.66), Vector2(-0.3, 0.6), Vector2(-0.46, 0.74)])
		body.add_extrusion(Transform3D(Basis(), Vector3(sx * 0.2, 0, 0)), poly, 0.02, Color.WHITE)
	body.flat = false
	# Seat + short tail.
	body.surface("seat")
	body.add_loft(Transform3D(), [
		{"z": 0.06, "y": 0.9, "w": 0.15, "h": 0.045, "round": 0.8},
		{"z": 0.34, "y": 0.93, "w": 0.13, "h": 0.045, "round": 0.8},
		{"z": 0.46, "y": 0.96, "w": 0.1, "h": 0.04, "round": 0.8},
	], 12, Color.WHITE)
	body.surface("paint")
	body.add_loft(Transform3D(), [
		{"z": 0.3, "y": 0.86, "w": 0.13, "h": 0.06, "round": 0.6},
		{"z": 0.56, "y": 0.94, "w": 0.08, "h": 0.05, "round": 0.6},
		{"z": 0.64, "y": 0.96, "w": 0.04, "h": 0.03, "round": 0.9},
	], 10, Color.WHITE)
	body.surface("light_rear")
	body.add_box(Transform3D(Basis(), Vector3(0, 0.95, 0.64)), Vector3(0.08, 0.03, 0.03), Color.WHITE)
	body.surface("accent")
	body.add_tube(Vector3(0, 0.44, 0.2), Vector3(0, 0.78, 0.08), 0.032, 0.032, 8, Color.WHITE)
	body.surface("metal")
	for sx in [-0.17, 0.17]:
		body.add_tube(Vector3(sx * 0.6, 0.38, 0.12), Vector3(sx, 0.36, 0.14), 0.012, 0.012, 5, Color.WHITE)
	# Front.
	var axle := Vector3(0, rw, fz)
	_fork(front, head, axle, 0.1, 0.03, 0.038, "metal", "black")
	front.surface("black")
	front.add_loft(Transform3D(), [
		{"z": fz - 0.15, "y": rw + 0.13, "w": 0.055, "h": 0.02, "round": 1.0},
		{"z": fz + 0.02, "y": rw + 0.2, "w": 0.075, "h": 0.025, "round": 0.9},
		{"z": fz + 0.16, "y": rw + 0.15, "w": 0.07, "h": 0.02, "round": 1.0},
	], 10, Color.WHITE)
	var bar := _handlebar(front, head + Vector3(0, 0.1, 0.08), 0.36, 0.05, 0.04)
	_round_headlight(front, head + Vector3(0, -0.08, -0.14), 0.09, "black")
	front.surface("black")
	front.add_box(Transform3D(Basis(Vector3.RIGHT, -0.6), head + Vector3(0, 0.1, -0.02)), Vector3(0.14, 0.09, 0.03), Color.WHITE)
	return {"body": body, "front": front, "head": head, "bar": bar, "seat": Vector3(0, 0.95, 0.2),
		"peg": Vector3(0.17, 0.36, 0.14), "exhaust": Vector3(0.19, 0.44, 0.56),
		"headlight": head + Vector3(0, -0.08, -0.2), "taillight": Vector3(0, 0.95, 0.66), "rider": "upright"}


# --- Supermoto ---------------------------------------------------------------

static func _supermoto(wb: float, rw: float) -> Dictionary:
	var body := MeshBuilder.new(false)
	var front := MeshBuilder.new(false)
	var fz := -wb * 0.5
	var rz := wb * 0.5
	var head := Vector3(0, 1.08, fz + 0.36)
	body.surface("frame")
	for sx in [-0.09, 0.09]:
		body.add_tube(head + Vector3(0, -0.03, 0.04), Vector3(sx, 0.86, -0.08), 0.022, 0.022, 6, Color.WHITE)
		body.add_tube(Vector3(sx, 0.86, -0.08), Vector3(sx, 0.48, 0.08), 0.022, 0.022, 6, Color.WHITE)
		body.add_tube(head + Vector3(0, -0.12, 0.06), Vector3(sx * 0.5, 0.3, -0.28), 0.02, 0.02, 6, Color.WHITE)
		body.add_tube(Vector3(sx * 0.5, 0.3, -0.28), Vector3(sx, 0.3, 0.06), 0.02, 0.02, 6, Color.WHITE)
		body.add_tube(Vector3(sx, 0.86, -0.08), Vector3(sx * 0.7, 1.0, 0.55), 0.016, 0.016, 6, Color.WHITE)
	body.surface("metal")
	for sx in [-0.09, 0.09]:
		body.add_tube(Vector3(sx, 0.44, 0.08), Vector3(sx, rw, rz), 0.03, 0.02, 8, Color.WHITE)
	# Single cylinder engine.
	body.surface("engine")
	body.flat = true
	body.add_bevel_box(Transform3D(Basis(), Vector3(0, 0.4, -0.04)), Vector3(0.24, 0.26, 0.3), 0.05, Color.WHITE)
	body.add_bevel_box(Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, 0.64, -0.12)), Vector3(0.14, 0.26, 0.16), 0.03, Color.WHITE)
	body.flat = false
	body.surface("metal")
	for k in 5:
		body.add_box(Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, 0.56 + k * 0.035, -0.1 - k * 0.009)), Vector3(0.17, 0.007, 0.19), Color.WHITE)
	# Radiator shrouds + slim tank.
	body.surface("paint")
	body.flat = true
	for sx in [-1.0, 1.0]:
		var poly := PackedVector2Array([Vector2(-0.52, 1.0), Vector2(-0.18, 1.0), Vector2(-0.12, 0.86), Vector2(-0.3, 0.64), Vector2(-0.5, 0.7)])
		body.add_extrusion(Transform3D(Basis(), Vector3(sx * 0.16, 0, 0)), poly, 0.02, Color.WHITE)
	body.flat = false
	body.add_loft(Transform3D(), [
		{"z": -0.42, "y": 0.98, "w": 0.1, "h": 0.07, "round": 0.8},
		{"z": -0.22, "y": 1.0, "w": 0.15, "h": 0.08, "round": 0.8},
		{"z": -0.02, "y": 0.98, "w": 0.13, "h": 0.06, "round": 0.8},
	], 12, Color.WHITE)
	# Long flat seat.
	body.surface("seat")
	body.add_loft(Transform3D(), [
		{"z": -0.12, "y": 1.02, "w": 0.1, "h": 0.035, "round": 0.9},
		{"z": 0.2, "y": 1.02, "w": 0.12, "h": 0.04, "round": 0.9},
		{"z": 0.5, "y": 1.03, "w": 0.1, "h": 0.035, "round": 0.9},
	], 12, Color.WHITE)
	# Side panels and high tail / rear fender.
	body.surface("accent")
	body.add_loft(Transform3D(), [
		{"z": 0.1, "y": 0.9, "w": 0.13, "h": 0.07, "round": 0.4},
		{"z": 0.45, "y": 0.97, "w": 0.1, "h": 0.05, "round": 0.5},
		{"z": 0.82, "y": 1.02, "w": 0.06, "h": 0.015, "round": 1.0},
	], 10, Color.WHITE)
	body.surface("light_rear")
	body.add_box(Transform3D(Basis(), Vector3(0, 0.99, 0.74)), Vector3(0.06, 0.025, 0.02), Color.WHITE)
	# High exhaust on the right.
	body.surface("metal")
	body.add_tube(Vector3(0.02, 0.62, -0.24), Vector3(0.12, 0.36, -0.28), 0.022, 0.022, 8, Color.WHITE)
	body.add_tube(Vector3(0.12, 0.36, -0.28), Vector3(0.14, 0.6, 0.18), 0.024, 0.024, 8, Color.WHITE)
	_exhaust_can(body, Vector3(0.14, 0.62, 0.2), Vector3(0.14, 0.82, 0.58), 0.05, "metal", "black")
	body.surface("accent")
	body.add_tube(Vector3(0, 0.44, 0.14), Vector3(0, 0.84, 0.02), 0.03, 0.03, 8, Color.WHITE)
	body.surface("metal")
	for sx in [-0.16, 0.16]:
		body.add_tube(Vector3(sx * 0.5, 0.36, 0.08), Vector3(sx, 0.34, 0.1), 0.013, 0.013, 5, Color.WHITE)
	# Front: long fork, high "beak" fender, number plate, wide tapered bar.
	var axle := Vector3(0, rw, fz)
	_fork(front, head, axle, 0.085, 0.03, 0.036, "black", "metal")
	front.surface("paint")
	front.flat = true
	front.add_loft(Transform3D(), [
		{"z": head.z - 0.36, "y": head.y - 0.22, "w": 0.06, "h": 0.012, "round": 1.0},
		{"z": head.z - 0.1, "y": head.y - 0.12, "w": 0.09, "h": 0.018, "round": 1.0},
		{"z": head.z + 0.08, "y": head.y - 0.14, "w": 0.08, "h": 0.015, "round": 1.0},
	], 10, Color.WHITE)
	front.surface("accent")
	front.add_bevel_box(Transform3D(Basis(Vector3.RIGHT, PI * 0.5 - 0.3), head + Vector3(0, -0.02, -0.12)), Vector3(0.24, 0.015, 0.22), 0.05, Color.WHITE)
	front.flat = false
	var bar := _handlebar(front, head + Vector3(0, 0.12, 0.08), 0.4, 0.04, 0.02, "metal")
	front.surface("light_front")
	front.add_box(Transform3D(Basis(Vector3.RIGHT, -0.3), head + Vector3(0, -0.02, -0.135)), Vector3(0.08, 0.04, 0.01), Color.WHITE)
	return {"body": body, "front": front, "head": head, "bar": bar, "seat": Vector3(0, 1.03, 0.08),
		"peg": Vector3(0.16, 0.34, 0.1), "exhaust": Vector3(0.14, 0.84, 0.62),
		"headlight": head + Vector3(0, -0.02, -0.16), "taillight": Vector3(0, 0.99, 0.75), "rider": "supermoto"}


# --- Cafe racer --------------------------------------------------------------

static func _cafe(wb: float, rw: float) -> Dictionary:
	var body := MeshBuilder.new(false)
	var front := MeshBuilder.new(false)
	var fz := -wb * 0.5
	var rz := wb * 0.5
	var head := Vector3(0, 0.94, fz + 0.3)
	# Classic double cradle frame.
	body.surface("frame")
	for sx in [-0.12, 0.12]:
		body.add_tube(head + Vector3(0, 0.0, 0.03), Vector3(sx * 0.5, 0.84, 0.1), 0.02, 0.02, 6, Color.WHITE)
		body.add_tube(Vector3(sx * 0.5, 0.84, 0.1), Vector3(sx, 0.78, 0.62), 0.018, 0.018, 6, Color.WHITE)
		body.add_tube(head + Vector3(0, -0.12, 0.06), Vector3(sx, 0.24, -0.26), 0.02, 0.02, 6, Color.WHITE)
		body.add_tube(Vector3(sx, 0.24, -0.26), Vector3(sx, 0.22, 0.12), 0.02, 0.02, 6, Color.WHITE)
		body.add_tube(Vector3(sx, 0.22, 0.12), Vector3(sx * 0.5, 0.84, 0.1), 0.02, 0.02, 6, Color.WHITE)
	body.surface("chrome")
	for sx in [-0.11, 0.11]:
		body.add_tube(Vector3(sx, 0.36, 0.12), Vector3(sx, rw, rz), 0.024, 0.02, 8, Color.WHITE)
		# Twin rear shocks with springs.
		body.add_tube(Vector3(sx * 1.1, rw + 0.05, rz - 0.1), Vector3(sx * 1.1, 0.8, 0.52), 0.018, 0.018, 8, Color.WHITE)
	body.surface("accent")
	for sx in [-0.121, 0.121]:
		for k in 7:
			var p := Vector3(sx * 1.1, rw + 0.12, rz - 0.12).lerp(Vector3(sx * 1.1, 0.74, 0.54), k / 6.0)
			body.add_torus(Transform3D(Basis(Vector3.FORWARD, PI * 0.5) * Basis(Vector3.RIGHT, 0.5), p), 0.03, 0.006, 10, 4, Color.WHITE)
	# Parallel twin: round cases, two finned cylinders.
	body.surface("engine")
	body.add_cylinder(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-0.16, 0.34, -0.02)), 0.13, 0.13, 0.32, 18, Color.WHITE)
	body.surface("metal")
	for cx in [-0.06, 0.06]:
		body.add_cylinder(Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(cx, 0.42, -0.1)), 0.055, 0.05, 0.3, 12, Color.WHITE)
		for k in 6:
			body.add_cylinder(Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(cx, 0.46 + k * 0.04, -0.11 - k * 0.01)), 0.075, 0.075, 0.012, 12, Color.WHITE)
	body.surface("chrome")
	for sx in [-1.0, 1.0]:
		body.add_cylinder(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(sx * 0.16 - (0.0 if sx > 0 else 0.01), 0.34, -0.02)), 0.09, 0.09, 0.01, 16, Color.WHITE)
		# Twin upswept megaphones.
		body.add_tube(Vector3(sx * 0.06, 0.6, -0.26), Vector3(sx * 0.13, 0.3, -0.3), 0.022, 0.022, 8, Color.WHITE)
		body.add_tube(Vector3(sx * 0.13, 0.3, -0.3), Vector3(sx * 0.16, 0.34, 0.2), 0.022, 0.022, 8, Color.WHITE)
		body.add_tube(Vector3(sx * 0.16, 0.34, 0.2), Vector3(sx * 0.17, 0.48, 0.62), 0.035, 0.055, 14, Color.WHITE)
	# Long tank with knee dents.
	body.surface("paint")
	body.add_loft(Transform3D(), [
		{"z": -0.45, "y": 0.9, "w": 0.1, "h": 0.07, "round": 1.0},
		{"z": -0.34, "y": 0.95, "w": 0.16, "h": 0.1, "round": 1.0},
		{"z": -0.12, "y": 0.96, "w": 0.17, "h": 0.1, "round": 1.0},
		{"z": 0.02, "y": 0.94, "w": 0.12, "h": 0.08, "round": 1.0},
		{"z": 0.1, "y": 0.9, "w": 0.1, "h": 0.05, "round": 1.0},
	], 16, Color.WHITE)
	body.surface("accent")
	body.add_loft(Transform3D(), [
		{"z": -0.36, "y": 0.955, "w": 0.161, "h": 0.101, "round": 1.0, "top": 1.0},
		{"z": -0.3, "y": 0.958, "w": 0.166, "h": 0.103, "round": 1.0},
	], 16, Color.WHITE)
	body.surface("chrome")
	body.add_cylinder(Transform3D(Basis(), Vector3(0, 1.02, -0.2)), 0.03, 0.03, 0.03, 12, Color.WHITE)
	# Seat with hump cowl.
	body.surface("seat")
	body.add_loft(Transform3D(), [
		{"z": 0.08, "y": 0.87, "w": 0.12, "h": 0.04, "round": 0.9},
		{"z": 0.3, "y": 0.88, "w": 0.13, "h": 0.04, "round": 0.9},
	], 12, Color.WHITE)
	body.surface("paint")
	body.add_loft(Transform3D(), [
		{"z": 0.32, "y": 0.86, "w": 0.13, "h": 0.05, "round": 0.9},
		{"z": 0.4, "y": 0.92, "w": 0.12, "h": 0.1, "round": 0.9},
		{"z": 0.56, "y": 0.9, "w": 0.1, "h": 0.07, "round": 0.9},
		{"z": 0.64, "y": 0.86, "w": 0.05, "h": 0.03, "round": 1.0},
	], 12, Color.WHITE)
	body.surface("light_rear")
	body.add_cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.84, 0.66)), 0.03, 0.03, 0.02, 12, Color.WHITE)
	body.surface("metal")
	for sx in [-0.16, 0.16]:
		body.add_tube(Vector3(sx * 0.6, 0.36, 0.18), Vector3(sx, 0.34, 0.2), 0.012, 0.012, 5, Color.WHITE)
	# Front: gaitered fork, chrome headlight bucket, clip-ons, small chrome fender.
	var axle := Vector3(0, rw, fz)
	_fork(front, head, axle, 0.1, 0.028, 0.034, "chrome", "black")
	front.surface("chrome")
	front.add_loft(Transform3D(), [
		{"z": fz - 0.14, "y": rw + 0.1, "w": 0.05, "h": 0.015, "round": 1.0},
		{"z": fz + 0.02, "y": rw + 0.17, "w": 0.065, "h": 0.02, "round": 1.0},
		{"z": fz + 0.13, "y": rw + 0.12, "w": 0.06, "h": 0.015, "round": 1.0},
	], 10, Color.WHITE)
	var bar := _handlebar(front, head + Vector3(0, -0.04, 0.02), 0.28, -0.04, 0.08, "chrome")
	_round_headlight(front, head + Vector3(0, -0.1, -0.12), 0.1, "chrome")
	front.surface("chrome")
	for sx in [-0.05, 0.05]:
		front.add_cylinder(Transform3D(Basis(), head + Vector3(sx, 0.04, 0.0)), 0.035, 0.035, 0.035, 12, Color.WHITE)
	return {"body": body, "front": front, "head": head, "bar": bar, "seat": Vector3(0, 0.9, 0.2),
		"peg": Vector3(0.16, 0.34, 0.2), "exhaust": Vector3(0.17, 0.5, 0.66),
		"headlight": head + Vector3(0, -0.1, -0.2), "taillight": Vector3(0, 0.84, 0.68), "rider": "cafe"}

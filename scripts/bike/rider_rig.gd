class_name RiderRig
extends Node3D
## Procedural animated rider. Limbs are rigid segments placed each frame by two-bone IK
## between the torso and the bike's contact points (bars and pegs). The pose reacts to
## lean (hang-off), speed (tuck), braking, wheelies and stopping (foot down). On a crash the
## rider detaches and tumbles as a simple ragdoll-lite.

const THIGH := 0.44
const SHIN := 0.46
const UPPER_ARM := 0.31
const FOREARM := 0.31

var style := "sport"
var bike_model: Node3D
var suit_main := Color(0.1, 0.1, 0.12)
var suit_accent := Color(0.85, 0.15, 0.1)
var helmet_color := Color(0.95, 0.95, 0.95)

var _torso: MeshInstance3D
var _pelvis: MeshInstance3D
var _head: MeshInstance3D
var _limbs: Dictionary = {} # name -> MeshInstance3D
var _mats: Dictionary = {}

# Smoothed pose values.
var _lean := 0.0
var _tuck := 0.0
var _foot := 0.0
var _brake := 0.0
var _hang := 0.0
var _look := 0.0

# Tumble state.
var tumbling := false
var _tumble_vel := Vector3.ZERO
var _tumble_spin := Vector3.ZERO
var _tumble_time := 0.0
var _flail_seed := 0.0
var _ground_func: Callable


static func create(p_style: String, main: Color, accent: Color, helmet: Color) -> RiderRig:
	var r := RiderRig.new()
	r.style = p_style
	r.suit_main = main
	r.suit_accent = accent
	r.helmet_color = helmet
	r.name = "Rider"
	r._build()
	return r


func _material(key: String, c: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	_mats[key] = m
	return m


func set_colors(main: Color, accent: Color, helmet: Color) -> void:
	suit_main = main
	suit_accent = accent
	helmet_color = helmet
	_material("main", main).albedo_color = main
	_material("accent", accent).albedo_color = accent
	_material("helmet", helmet).albedo_color = helmet


func _mats_dict() -> Dictionary:
	return {
		"main": _material("main", suit_main, 0.55),
		"accent": _material("accent", suit_accent, 0.5),
		"helmet": _material("helmet", helmet_color, 0.2, 0.1),
		"visor": _material("visor", Color(0.03, 0.03, 0.05), 0.05, 0.6),
		"boot": _material("boot", Color(0.06, 0.06, 0.06), 0.5),
		"glove": _material("glove", Color(0.08, 0.08, 0.09), 0.6),
	}


func _mesh_node(n: String, mb: MeshBuilder) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mb.commit(_mats_dict())
	add_child(mi)
	return mi


func _build() -> void:
	# Torso: loft from waist (y=0) up to the shoulders (y=0.5); front is -Z.
	var tb := MeshBuilder.new(false)
	tb.surface("main")
	tb.add_loft(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), [
		{"z": 0.0, "y": 0.0, "w": 0.16, "h": 0.11, "round": 0.8},
		{"z": -0.18, "y": 0.0, "w": 0.17, "h": 0.12, "round": 0.8},
		{"z": -0.38, "y": 0.01, "w": 0.215, "h": 0.13, "round": 0.75},
		{"z": -0.5, "y": 0.0, "w": 0.2, "h": 0.11, "round": 0.85},
		{"z": -0.56, "y": 0.0, "w": 0.08, "h": 0.06, "round": 1.0},
	], 12, Color.WHITE)
	tb.surface("accent")
	for sx in [-1.0, 1.0]:
		tb.add_box(Transform3D(Basis(Vector3.FORWARD, sx * 0.12), Vector3(sx * 0.17, 0.3, 0.0)), Vector3(0.02, 0.36, 0.2), Color.WHITE)
	if style == "sport" or style == "cafe":
		tb.surface("main")
		tb.add_sphere(Transform3D(Basis().scaled(Vector3(0.8, 1.2, 0.7)), Vector3(0, 0.5, 0.1)), 0.09, 4, 8, Color.WHITE)
	_torso = _mesh_node("Torso", tb)

	var pb := MeshBuilder.new(false)
	pb.surface("main")
	pb.add_sphere(Transform3D(Basis().scaled(Vector3(1.0, 0.7, 0.85)), Vector3.ZERO), 0.16, 5, 10, Color.WHITE)
	_pelvis = _mesh_node("Pelvis", pb)

	var hb := MeshBuilder.new(false)
	hb.surface("helmet")
	hb.add_sphere(Transform3D(Basis().scaled(Vector3(0.95, 1.0, 1.1)), Vector3(0, 0.13, 0)), 0.14, 7, 14, Color.WHITE)
	hb.surface("accent")
	hb.add_torus(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0.15, 0.0)), 0.142, 0.012, 16, 4, Color.WHITE, Vector2(1.0, 1.0))
	hb.surface("visor")
	hb.add_sphere(Transform3D(Basis().scaled(Vector3(0.9, 0.38, 0.72)), Vector3(0, 0.145, -0.05)), 0.14, 6, 14, Color.WHITE)
	if style == "supermoto":
		hb.surface("helmet")
		hb.add_box(Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(0, 0.25, -0.16)), Vector3(0.2, 0.015, 0.14), Color.WHITE)
		hb.add_box(Transform3D(Basis(), Vector3(0, 0.06, -0.15)), Vector3(0.1, 0.07, 0.08), Color.WHITE)
	_head = _mesh_node("Head", hb)

	# Limbs: built along +Y from 0 to length.
	for side in ["L", "R"]:
		_limbs["upper_arm_" + side] = _mesh_node("UpperArm" + side, _segment(UPPER_ARM, 0.064, 0.056, "main", "accent"))
		_limbs["forearm_" + side] = _mesh_node("Forearm" + side, _segment(FOREARM, 0.056, 0.046, "main", ""))
		_limbs["hand_" + side] = _mesh_node("Hand" + side, _hand())
		_limbs["thigh_" + side] = _mesh_node("Thigh" + side, _segment(THIGH, 0.098, 0.074, "main", "accent"))
		_limbs["shin_" + side] = _mesh_node("Shin" + side, _segment(SHIN, 0.07, 0.056, "boot" if style == "supermoto" else "main", ""))
		_limbs["foot_" + side] = _mesh_node("Foot" + side, _boot())


func _segment(length: float, r0: float, r1: float, surf: String, stripe: String) -> MeshBuilder:
	var mb := MeshBuilder.new(false)
	mb.surface(surf)
	mb.add_lathe(Transform3D(), [
		Vector2(r0 * 0.6, -r0 * 0.4), Vector2(r0, 0.0), Vector2(lerpf(r0, r1, 0.5) * 1.04, length * 0.5),
		Vector2(r1, length), Vector2(r1 * 0.6, length + r1 * 0.4)], 10, Color.WHITE, true)
	if stripe != "":
		mb.surface(stripe)
		mb.add_box(Transform3D(Basis(), Vector3(r0 * 0.95, length * 0.5, 0)), Vector3(0.012, length * 0.8, r0 * 0.6), Color.WHITE)
	return mb


func _hand() -> MeshBuilder:
	var mb := MeshBuilder.new(false)
	mb.surface("glove")
	mb.add_sphere(Transform3D(Basis().scaled(Vector3(0.9, 1.2, 0.7)), Vector3(0, 0.04, 0)), 0.045, 4, 8, Color.WHITE)
	return mb


func _boot() -> MeshBuilder:
	var mb := MeshBuilder.new(true)
	mb.surface("boot")
	# Boot points along -Z from the ankle.
	mb.add_bevel_box(Transform3D(Basis(), Vector3(0, -0.02, -0.06)), Vector3(0.09, 0.08, 0.24), 0.03, Color.WHITE)
	mb.surface("accent")
	mb.add_box(Transform3D(Basis(), Vector3(0, 0.02, -0.02)), Vector3(0.095, 0.02, 0.12), Color.WHITE)
	return mb


static func _place(node: Node3D, a: Vector3, b: Vector3, roll_hint := Vector3.FORWARD) -> void:
	var y := b - a
	var l := y.length()
	if l < 1e-5:
		return
	y /= l
	var x := roll_hint.cross(y)
	if x.length_squared() < 1e-6:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	node.transform = Transform3D(Basis(x, y, z), a)


## Two-bone IK: returns the middle joint position.
static func solve_ik(root: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3) -> Vector3:
	var to := target - root
	var d := clampf(to.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.001)
	var dir := to.normalized() if to.length() > 1e-5 else Vector3.DOWN
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var sin_a := sqrt(1.0 - cos_a * cos_a)
	var p := pole - root
	var n := p - dir * p.dot(dir)
	if n.length_squared() < 1e-8:
		n = dir.cross(Vector3.RIGHT)
	n = n.normalized()
	return root + dir * (l1 * cos_a) + n * (l1 * sin_a)


func attach(model: Node3D) -> void:
	bike_model = model
	style = String(model.get_meta("rider_style", style))
	var seat: Node3D = model.get_node("Lean/Pitch/Seat")
	if get_parent() != null:
		get_parent().remove_child(self)
	model.get_node("Lean/Pitch").add_child(self)
	transform = Transform3D(Basis(), seat.position)
	tumbling = false
	visible = true


## Updates the riding pose. `p` keys: lean, tuck, steer, speed, brake, pitch, foot_down,
## ground_y (world height under the bike).
func update_pose(p: Dictionary, delta: float) -> void:
	if tumbling:
		_update_tumble(delta)
		return
	if bike_model == null:
		return
	var k := clampf(delta * 8.0, 0.0, 1.0)
	_lean = lerpf(_lean, p.get("lean", 0.0), k)
	_tuck = lerpf(_tuck, p.get("tuck", 0.0), clampf(delta * 3.0, 0.0, 1.0))
	_foot = lerpf(_foot, p.get("foot_down", 0.0), clampf(delta * 5.0, 0.0, 1.0))
	_brake = lerpf(_brake, p.get("brake", 0.0), k)
	_look = lerpf(_look, p.get("steer", 0.0), k)
	var lean_n := clampf(_lean / 0.9, -1.0, 1.0)

	var base_pitch := {"sport": 0.95, "upright": 0.42, "supermoto": 0.38, "cafe": 0.8}.get(style, 0.6) as float
	var hang_amount := {"sport": 0.13, "upright": 0.08, "supermoto": -0.03, "cafe": 0.07}.get(style, 0.08) as float
	var torso_pitch: float = base_pitch + _tuck * 0.35 - _brake * 0.08 + p.get("pitch", 0.0) * 0.6
	_hang = lerpf(_hang, lean_n * hang_amount, k)

	# Hips on the seat, shifted toward the inside of the turn.
	var hips := Vector3(_hang, 0.1 - absf(_hang) * 0.3, 0.02 - _tuck * 0.03)
	var torso_roll := -_lean * (0.4 if style != "supermoto" else -0.15)
	var torso_basis := Basis(Vector3.FORWARD, torso_roll) * Basis(Vector3.RIGHT, -torso_pitch)
	_pelvis.transform = Transform3D(Basis(Vector3.FORWARD, torso_roll * 0.5), hips)
	_torso.transform = Transform3D(torso_basis, hips + Vector3(0, 0.02, 0))
	var neck := hips + torso_basis * Vector3(0, 0.56, 0)
	# Head stays closer to level and looks into the turn.
	var head_basis := Basis(Vector3.UP, -_look * 0.35) * Basis(Vector3.FORWARD, -torso_roll * 0.6) * Basis(Vector3.RIGHT, -clampf(torso_pitch - 0.9, -0.3, 0.4) * 0.5)
	_head.transform = Transform3D(head_basis, neck + Vector3(0, 0.0, 0))

	var inv_self := transform.affine_inverse()
	for side in ["L", "R"]:
		var sgn := -1.0 if side == "L" else 1.0
		var shoulder := hips + torso_basis * Vector3(sgn * 0.2, 0.47, 0.0)
		var bar: Node3D = bike_model.get_node("Lean/Pitch/Steer/Bar" + side)
		var hand := inv_self * _to_pitch_space(bar)
		var elbow_pole := shoulder + Vector3(sgn * 0.5, -0.4, 0.1)
		var elbow := solve_ik(shoulder, hand, UPPER_ARM, FOREARM, elbow_pole)
		_place(_limbs["upper_arm_" + side], shoulder, elbow)
		_place(_limbs["forearm_" + side], elbow, hand)
		_limbs["hand_" + side].transform = Transform3D(_limbs["forearm_" + side].transform.basis, hand)

		var hip := hips + Vector3(sgn * 0.11, -0.02, 0.0)
		var peg: Node3D = bike_model.get_node("Lean/Pitch/Peg" + side)
		var foot := inv_self * peg.position + Vector3(0, 0.05, 0.03)
		# Foot down on the left when stopped.
		if side == "L" and _foot > 0.01:
			var ground_local := _ground_point_local(Vector3(-0.42, 0.0, -0.05), p.get("ground_y", 0.0))
			foot = foot.lerp(ground_local + Vector3(0, 0.07, 0), _foot)
		# Supermoto: inside leg out in corners.
		if style == "supermoto" and absf(_lean) > 0.3 and signf(_lean) == sgn and _foot < 0.1:
			var out := clampf((absf(_lean) - 0.3) * 2.5, 0.0, 1.0)
			foot = foot.lerp(hip + Vector3(sgn * 0.35, -0.65, -0.45), out)
		var knee_pole := hip + Vector3(sgn * (0.25 + (0.35 if style == "sport" and signf(_lean) == sgn else 0.0) * absf(lean_n)), -0.1, -0.8)
		var knee := solve_ik(hip, foot, THIGH, SHIN, knee_pole)
		_place(_limbs["thigh_" + side], hip, knee)
		_place(_limbs["shin_" + side], knee, foot)
		_limbs["foot_" + side].transform = Transform3D(Basis(), foot)


func _to_pitch_space(n: Node3D) -> Vector3:
	## Position of a node expressed in this rider's parent (Pitch) space.
	var pitch_node: Node3D = get_parent()
	var local := Transform3D()
	var cur: Node3D = n
	while cur != null and cur != pitch_node:
		local = cur.transform * local
		cur = cur.get_parent() as Node3D
	return local.origin


func _ground_point_local(offset_bike: Vector3, ground_y: float) -> Vector3:
	# Point beside the bike at ground height, expressed in rider-local space.
	var pitch_node: Node3D = get_parent()
	var world := pitch_node.global_transform * (offset_bike + Vector3(0, 0, 0))
	world.y = ground_y
	return global_transform.affine_inverse() * world


# --- Crash tumble ------------------------------------------------------------

## Detaches the rider into `world_parent` and throws it with the bike's velocity.
func start_tumble(world_parent: Node3D, velocity: Vector3, ground_func: Callable) -> void:
	if tumbling:
		return
	var gxf := global_transform
	get_parent().remove_child(self)
	world_parent.add_child(self)
	global_transform = gxf
	tumbling = true
	_tumble_time = 0.0
	_tumble_vel = velocity * 0.85 + Vector3(0, 3.0 + velocity.length() * 0.05, 0)
	_tumble_spin = Vector3(randf_range(-6, 6), randf_range(-3, 3), randf_range(-6, 6))
	_flail_seed = randf() * 100.0
	_ground_func = ground_func


func _update_tumble(delta: float) -> void:
	_tumble_time += delta
	_tumble_vel.y -= 9.81 * delta
	var p := global_position + _tumble_vel * delta
	var g: float = _ground_func.call(p) if _ground_func.is_valid() else 0.0
	if p.y < g + 0.15:
		p.y = g + 0.15
		if _tumble_vel.y < 0.0:
			_tumble_vel.y = -_tumble_vel.y * 0.3
		var h := Vector3(_tumble_vel.x, 0, _tumble_vel.z)
		h *= maxf(1.0 - delta * 2.2, 0.0)
		_tumble_vel = Vector3(h.x, _tumble_vel.y, h.z)
		_tumble_spin *= maxf(1.0 - delta * 3.0, 0.0)
	global_position = p
	var settle := clampf(_tumble_time / 2.5, 0.0, 1.0)
	rotate_object_local(Vector3.RIGHT, _tumble_spin.x * delta)
	rotate_object_local(Vector3.UP, _tumble_spin.y * delta)
	rotate_object_local(Vector3.FORWARD, _tumble_spin.z * delta)
	# Limbs flail, then go limp.
	var t := _tumble_time * 9.0 + _flail_seed
	var amp := (1.0 - settle) * 0.6 + 0.1
	var hips := Vector3.ZERO
	var torso_basis := Basis(Vector3.RIGHT, sin(t * 0.3) * 0.4 * amp)
	_pelvis.transform = Transform3D(Basis(), hips)
	_torso.transform = Transform3D(torso_basis, hips)
	_head.transform = Transform3D(torso_basis, hips + torso_basis * Vector3(0, 0.56, 0))
	for side in ["L", "R"]:
		var sgn := -1.0 if side == "L" else 1.0
		var shoulder := hips + torso_basis * Vector3(sgn * 0.2, 0.47, 0)
		var hand := shoulder + Vector3(sgn * (0.35 + sin(t + sgn) * 0.2 * amp), 0.2 * sin(t * 1.3 + sgn) * amp - 0.2, cos(t * 0.9) * 0.3 * amp)
		var elbow := solve_ik(shoulder, hand, UPPER_ARM, FOREARM, shoulder + Vector3(sgn, -0.5, 0.3))
		_place(_limbs["upper_arm_" + side], shoulder, elbow)
		_place(_limbs["forearm_" + side], elbow, hand)
		_limbs["hand_" + side].transform = Transform3D(Basis(), hand)
		var hip := hips + Vector3(sgn * 0.11, 0, 0)
		var foot := hip + Vector3(sgn * (0.2 + sin(t * 0.8 + sgn * 2.0) * 0.2 * amp), -0.8 + absf(cos(t * 1.1)) * 0.25 * amp, sin(t * 1.2 + sgn) * 0.3 * amp)
		var knee := solve_ik(hip, foot, THIGH, SHIN, hip + Vector3(0, 0, -1))
		_place(_limbs["thigh_" + side], hip, knee)
		_place(_limbs["shin_" + side], knee, foot)
		_limbs["foot_" + side].transform = Transform3D(Basis(), foot)

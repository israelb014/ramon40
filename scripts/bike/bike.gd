class_name Bike
extends Node3D
## A racing motorcycle in the world: owns the physics state, the procedural model and the
## rider, and maps simulation state to visuals every frame. Controllers (player, AI,
## network, replay) write the physics inputs; the race manager steps the simulation.

signal crashed(bike: Bike)
signal respawned(bike: Bike)

const RESPAWN_DELAY := 3.2

var bike_id := "naked"
var rider_name := ""
var index := 0 ## slot in the race
var is_player := false
var player_index := -1 ## local player number (0/1) or -1
var is_remote := false ## network-driven (no local simulation)
var physics: BikePhysics
var track: TrackData
var world_root: Node3D

var model: Node3D
var rider: RiderRig
var paint := Color.RED
var accent := Color.WHITE
var suit_main := Color(0.1, 0.1, 0.12)
var suit_accent := Color.RED
var helmet := Color.WHITE

var _lean_node: Node3D
var _pitch_node: Node3D
var _steer_node: Node3D
var _front_wheel: Node3D
var _rear_wheel: Node3D
var _steer_base: Basis
var _wheel_r := 0.31
var _wb := 1.42
var _visual_lean := 0.0
var _respawn_timer := 0.0
var _stand_lean := 0.0
var headlight: SpotLight3D
var effects: Node3D ## BikeEffects (particles), optional
var sound: Node ## BikeAudio, optional
## When set, the visual transform comes from this dictionary (network / replay playback).
var external_state: Dictionary = {}
var ghost := false


func setup(p_bike_id: String, p_track: TrackData, colors: Dictionary) -> void:
	bike_id = p_bike_id
	track = p_track
	physics = BikePhysics.new(GameData.bike(bike_id))
	physics.crashed.connect(_on_crashed)
	paint = colors.get("paint", paint)
	accent = colors.get("accent", accent)
	suit_main = colors.get("suit_main", suit_main)
	suit_accent = colors.get("suit_accent", suit_accent)
	helmet = colors.get("helmet", helmet)
	_build_visuals()


func _build_visuals() -> void:
	if model:
		model.queue_free()
	model = BikeModel.build(bike_id, paint, accent)
	add_child(model)
	_lean_node = model.get_node("Lean")
	_pitch_node = model.get_node("Lean/Pitch")
	_steer_node = model.get_node("Lean/Pitch/Steer")
	_front_wheel = model.get_node("Lean/Pitch/Steer/FrontWheel")
	_rear_wheel = model.get_node("Lean/Pitch/RearWheel")
	_steer_base = _steer_node.get_meta("base_basis")
	_wheel_r = model.get_meta("wheel_radius")
	_wb = model.get_meta("wheelbase")
	if rider == null:
		rider = RiderRig.create(String(model.get_meta("rider_style")), suit_main, suit_accent, helmet)
	rider.attach(model)


func set_paint(p_paint: Color, p_accent: Color) -> void:
	paint = p_paint
	accent = p_accent
	var body: MeshInstance3D = model.get_node("Lean/Pitch/Body")
	for i in body.mesh.get_surface_count():
		var n: String = body.mesh.surface_get_name(i)
		if n == "paint":
			(body.mesh.surface_get_material(i) as StandardMaterial3D).albedo_color = paint
		elif n == "accent":
			(body.mesh.surface_get_material(i) as StandardMaterial3D).albedo_color = accent


func enable_headlight(on: bool) -> void:
	if on and headlight == null:
		headlight = SpotLight3D.new()
		headlight.spot_range = 60.0
		headlight.spot_angle = 26.0
		headlight.spot_attenuation = 0.8
		headlight.light_energy = 5.0
		headlight.light_color = Color(1.0, 0.95, 0.85)
		headlight.shadow_enabled = false
		headlight.distance_fade_enabled = true
		headlight.distance_fade_begin = 160.0
		headlight.distance_fade_length = 40.0
		var hl: Node3D = model.get_node("Lean/Pitch/Headlight")
		hl.add_child(headlight)
		headlight.rotation_degrees = Vector3(-6, 0, 0)
	elif not on and headlight:
		headlight.queue_free()
		headlight = null


func place_at(xf: Transform3D) -> void:
	physics.place(xf)
	physics.track_index = -1
	physics.step(0.0001, track)
	sync_visual(0.0)


func speed_kmh() -> float:
	return absf(physics.speed) * 3.6


func is_crashed() -> bool:
	return physics.is_crashed


func _on_crashed(_reason: String) -> void:
	_respawn_timer = RESPAWN_DELAY
	if rider and world_root:
		rider.start_tumble(world_root, physics.vel, Callable(self, "_ground_at"))
	crashed.emit(self)


func _ground_at(p: Vector3) -> float:
	if track == null:
		return 0.0
	var proj := track.project(p, physics.track_index)
	return track.ground(p, proj)["height"]


## Called by the race manager each physics tick after stepping. Handles respawn timing.
func post_step(dt: float) -> void:
	if physics.is_crashed:
		_respawn_timer -= dt
		if _respawn_timer <= 0.0:
			respawn()


func respawn() -> void:
	var d := physics.track_dist
	# Step back a little so the rider re-enters the racing line before the crash spot.
	physics.respawn(track, d - 5.0, 0.0)
	_visual_lean = 0.0
	if rider:
		rider.attach(model)
	respawned.emit(self)


## Maps the simulation state to the node transforms.
func sync_visual(delta: float) -> void:
	if not external_state.is_empty():
		_sync_external(delta)
		return
	var p := physics
	var basis := Basis(Vector3.UP, p.yaw) * Basis(Vector3.RIGHT, p.ground_pitch)
	global_transform = Transform3D(basis, p.pos)
	if p.is_crashed:
		# Bike tumbles/slides on its side.
		_lean_node.transform = Transform3D(Basis.from_euler(Vector3(p.crash_rot.x * 0.3, p.crash_rot.y, -clampf(absf(p.crash_rot.z), 0.0, 1.45) * signf(p.crash_rot.z if p.crash_rot.z != 0.0 else 1.0))), Vector3(0, 0.12, 0))
		_pitch_node.transform = Transform3D()
	else:
		# Leaning slightly onto the left foot when stopped.
		var stopped := absf(p.speed) < 1.2 and p.in_throttle < 0.2
		_stand_lean = move_toward(_stand_lean, -0.12 if stopped else 0.0, delta * 0.6)
		_visual_lean = p.lean + _stand_lean
		_lean_node.transform = Transform3D(Basis(Vector3.FORWARD, _visual_lean), Vector3.ZERO)
		_apply_pitch(p.pitch, p.suspension_front)
	_steer_node.basis = _steer_base * Basis(Vector3.UP, -p.steer_angle)
	_front_wheel.get_child(0).rotation.x = -p.wheel_front_angle
	_rear_wheel.get_child(0).rotation.x = -p.wheel_rear_angle
	if rider and not rider.tumbling:
		rider.update_pose({
			"lean": p.lean, "tuck": p.tuck_amount, "steer": p.in_steer, "speed": p.speed,
			"brake": p.in_brake, "pitch": p.pitch,
			"foot_down": 1.0 if absf(p.speed) < 1.2 and p.in_throttle < 0.2 else 0.0,
			"ground_y": p.pos.y,
		}, delta)
	elif rider:
		rider.update_pose({}, delta)


func _apply_pitch(pitch: float, dive: float) -> void:
	var pivot := Vector3(0, 0, _wb * 0.5) if pitch >= 0.0 else Vector3(0, 0, -_wb * 0.5)
	var rot := Basis(Vector3.RIGHT, pitch + dive * 0.015)
	var xf := Transform3D(Basis(), pivot) * Transform3D(rot, Vector3.ZERO) * Transform3D(Basis(), -pivot)
	_pitch_node.transform = xf


## Snapshot of the visual state for replays, ghosts and network sync.
func snapshot() -> Dictionary:
	var p := physics
	return {
		"pos": p.pos, "yaw": p.yaw, "lean": p.lean, "pitch": p.pitch, "gp": p.ground_pitch,
		"steer": p.steer_angle, "spd": p.speed, "rpm": p.rpm, "gear": p.gear, "tuck": p.tuck_amount,
		"crash": p.is_crashed, "crot": p.crash_rot, "wf": p.wheel_front_angle, "wr": p.wheel_rear_angle,
		"brk": p.in_brake, "thr": p.in_throttle, "slip": p.slip, "surf": p.surface,
	}


func apply_snapshot(s: Dictionary) -> void:
	external_state = s


func _sync_external(delta: float) -> void:
	var s := external_state
	var p := physics
	p.pos = s.get("pos", p.pos)
	p.yaw = s.get("yaw", p.yaw)
	p.lean = s.get("lean", 0.0)
	p.pitch = s.get("pitch", 0.0)
	p.ground_pitch = s.get("gp", 0.0)
	p.steer_angle = s.get("steer", 0.0)
	p.speed = s.get("spd", 0.0)
	p.rpm = s.get("rpm", 1000.0)
	p.gear = s.get("gear", 1)
	p.tuck_amount = s.get("tuck", 0.0)
	p.wheel_front_angle = s.get("wf", 0.0)
	p.wheel_rear_angle = s.get("wr", 0.0)
	p.in_brake = s.get("brk", 0.0)
	p.in_throttle = s.get("thr", 0.0)
	p.slip = s.get("slip", 0.0)
	p.surface = s.get("surf", 0)
	var was_crashed := p.is_crashed
	p.is_crashed = s.get("crash", false)
	p.crash_rot = s.get("crot", Vector3.ZERO)
	if p.is_crashed and not was_crashed and rider and world_root and not rider.tumbling:
		rider.start_tumble(world_root, Vector3(-sin(p.yaw), 0, -cos(p.yaw)) * p.speed, Callable(self, "_ground_at"))
	elif not p.is_crashed and was_crashed and rider:
		rider.attach(model)
	var saved := external_state
	external_state = {}
	sync_visual(delta)
	external_state = saved

class_name RaceCamera
extends Camera3D
## Follows a bike with three modes: chase, close chase and helmet. Speed-dependent FOV,
## smoothing, look-back and a small shake for impacts and high speed.

enum Mode { CHASE, CLOSE, HELMET }

const MODE_COUNT := 3

var target: Bike
var mode := Mode.CHASE
var look_back := false
var shake := 0.0
var own_layer := 0 ## render layer holding the followed rider's head (hidden in helmet view)

var _pos := Vector3.ZERO
var _offset := Vector3.ZERO
var _look := Vector3.ZERO
var _yaw := 0.0
var _fov := 70.0
var _initialized := false
var _noise := FastNoiseLite.new()
var _t := 0.0


func _ready() -> void:
	near = 0.08
	far = 9000.0
	_noise.frequency = 0.9
	_noise.seed = randi()


func cycle_mode() -> void:
	mode = ((int(mode) + 1) % MODE_COUNT) as Mode
	_apply_cull()


func set_mode(m: int) -> void:
	mode = (m % MODE_COUNT) as Mode
	_apply_cull()


func _apply_cull() -> void:
	if own_layer <= 0:
		return
	set_cull_mask_value(own_layer, mode != Mode.HELMET)


func snap() -> void:
	_initialized = false


func add_shake(amount: float) -> void:
	shake = clampf(shake + amount, 0.0, 1.5)


func update_camera(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	_t += delta
	var p := target.physics
	var speed := absf(p.speed)
	var yaw_target := p.yaw + (PI if look_back else 0.0)
	var fwd := Vector3(-sin(yaw_target), 0.0, -cos(yaw_target))
	var bike_pos := target.global_position
	var fov_target := 68.0 + clampf(speed / 75.0, 0.0, 1.0) * 16.0

	if not _initialized:
		_yaw = yaw_target
		_pos = bike_pos - fwd * 5.0 + Vector3.UP * 2.0
		_offset = Vector3.ZERO
		_look = bike_pos
		_fov = fov_target
		_initialized = true

	if p.is_crashed and target.rider and target.rider.tumbling:
		# Watch the tumble from where we are.
		var focus := target.rider.global_position
		_look = _look.lerp(focus, clampf(delta * 4.0, 0.0, 1.0))
		var away := (_pos - focus)
		away.y = 0.0
		if away.length() > 9.0:
			_pos = _pos.lerp(focus + away.normalized() * 9.0 + Vector3.UP * 3.0, clampf(delta * 2.0, 0.0, 1.0))
		global_position = _pos
		look_at(_look, Vector3.UP)
		fov = lerpf(fov, 62.0, clampf(delta * 2.0, 0.0, 1.0))
		return

	match mode:
		Mode.HELMET:
			_helmet(delta, fov_target)
		_:
			_chase(delta, fov_target, fwd, yaw_target, bike_pos, speed)

	shake = maxf(shake - delta * 1.6, 0.0)


func _chase(delta: float, fov_target: float, fwd: Vector3, yaw_target: float, bike_pos: Vector3, speed: float) -> void:
	var dist := 5.4 if mode == Mode.CHASE else 3.3
	var height := 1.85 if mode == Mode.CHASE else 1.25
	dist += clampf(speed / 80.0, 0.0, 1.0) * (1.2 if mode == Mode.CHASE else 0.5)
	# Yaw follows with a lag so turns read clearly.
	_yaw = lerp_angle(_yaw, yaw_target, clampf(delta * (3.2 if mode == Mode.CHASE else 4.5), 0.0, 1.0))
	var cam_fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var desired := bike_pos - cam_fwd * dist + Vector3.UP * height
	# Keep the camera above the ground.
	if target.track:
		var proj := target.track.project(desired, target.physics.track_index)
		var g: float = target.track.ground(desired, proj)["height"]
		if absf(float(proj["lateral"])) > target.track.half_width + target.track.shoulder:
			g = maxf(g, target.track.terrain_height(desired.x, desired.z))
		desired.y = maxf(desired.y, g + 0.6)
	# Smooth the offset relative to the bike (not the absolute position) so the camera never
	# falls behind at speed.
	var off := desired - bike_pos
	_offset = _offset.lerp(off, clampf(delta * 8.0, 0.0, 1.0)) if _offset != Vector3.ZERO else off
	_pos = bike_pos + _offset
	var look_target := bike_pos + Vector3.UP * (0.95 if mode == Mode.CHASE else 0.85) + cam_fwd * 2.5
	_look = look_target
	var shake_off := _shake_offset()
	global_position = _pos + shake_off
	look_at(_look + shake_off * 0.5, Vector3.UP)
	# Roll the horizon slightly with the lean for a dynamic feel.
	rotate_object_local(Vector3.FORWARD, -target.physics.lean * (0.12 if mode == Mode.CHASE else 0.2))
	_fov = lerpf(_fov, fov_target, clampf(delta * 2.0, 0.0, 1.0))
	fov = _fov


func _helmet(delta: float, fov_target: float) -> void:
	var head: Node3D = target.rider.get_node_or_null("Head") if target.rider else null
	var p := target.physics
	var origin: Vector3
	if head:
		origin = head.global_transform * Vector3(0, 0.15, -0.12)
	else:
		origin = target.global_position + Vector3.UP * 1.5
	var yaw := p.yaw + (PI if look_back else 0.0)
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, p.ground_pitch - 0.08 - p.pitch * 0.6) * Basis(Vector3.FORWARD, p.lean * 0.55)
	var shake_off := _shake_offset() * 0.4
	global_transform = Transform3D(basis, origin + shake_off)
	_fov = lerpf(_fov, fov_target + 4.0, clampf(delta * 2.0, 0.0, 1.0))
	fov = _fov
	_initialized = false


func _shake_offset() -> Vector3:
	var speed_shake := clampf((absf(target.physics.speed) - 45.0) / 40.0, 0.0, 1.0) * 0.015
	var offroad := 0.03 if target.physics.surface == BikePhysics.Surface.OFFROAD and absf(target.physics.speed) > 5.0 else 0.0
	var amount := shake * 0.25 + speed_shake + offroad
	if amount <= 0.0001:
		return Vector3.ZERO
	return Vector3(_noise.get_noise_1d(_t * 40.0), _noise.get_noise_1d(_t * 40.0 + 100.0), _noise.get_noise_1d(_t * 40.0 + 200.0)) * amount

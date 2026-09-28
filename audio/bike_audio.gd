class_name BikeAudio
extends Node3D
## Engine and tire audio for one bike. Three RPM layers (low/mid/high) are crossfaded and
## pitched to the current RPM; on-load and off-load recordings are blended by throttle.
## Also handles tire screech, gravel rumble, gear-shift clunks and backfire pops.

const LISTEN_RANGE := 220.0

var bike: Node
var local := false
var _rpms: Array = []
var _on: Array = []
var _off: Array = []
var _screech: AudioStreamPlayer3D
var _gravel: AudioStreamPlayer3D
var _shift_stream: AudioStream
var _pop_stream: AudioStream
var _load := 0.0
var _last_shift := 0
var _last_gear := 1
var _rng := RandomNumberGenerator.new()
var _active := true


func setup(p_bike: Node, bank: Dictionary, sounds: Dictionary, p_local: bool) -> void:
	bike = p_bike
	local = p_local
	_rpms = bank["rpms"]
	_rng.seed = hash(bike.name)
	for i in 3:
		_on.append(_player(bank["on"][i], "Engine"))
		if local:
			_off.append(_player(bank["off"][i], "Engine"))
	_screech = _player(sounds.get("screech"), "SFX")
	_gravel = _player(sounds.get("gravel"), "SFX")
	_shift_stream = sounds.get("shift")
	_pop_stream = sounds.get("backfire")


func _player(stream: AudioStream, bus: String) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = bus
	p.unit_size = 6.0 if not local else 9.0
	p.max_distance = LISTEN_RANGE
	p.volume_db = -80.0
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_IDLE_STEP
	p.attenuation_filter_cutoff_hz = 6000.0
	p.panning_strength = 0.8
	add_child(p)
	return p


func _ready() -> void:
	for p in _on + _off + [_screech, _gravel]:
		p.play(randf() * 0.5)


func _layer_weights(rpm: float) -> Array:
	var w := [0.0, 0.0, 0.0]
	if rpm <= _rpms[0]:
		w[0] = 1.0
	elif rpm >= _rpms[2]:
		w[2] = 1.0
	elif rpm < _rpms[1]:
		var t: float = (rpm - _rpms[0]) / (_rpms[1] - _rpms[0])
		w[0] = cos(t * PI * 0.5)
		w[1] = sin(t * PI * 0.5)
	else:
		var t2: float = (rpm - _rpms[1]) / (_rpms[2] - _rpms[1])
		w[1] = cos(t2 * PI * 0.5)
		w[2] = sin(t2 * PI * 0.5)
	return w


func update(delta: float) -> void:
	var ph: BikePhysics = bike.physics
	var cam := get_viewport().get_camera_3d()
	var dist := cam.global_position.distance_to(global_position) if cam else 0.0
	var should := dist < LISTEN_RANGE
	if should != _active:
		_active = should
		for p in _on + _off + [_screech, _gravel]:
			if should:
				p.play(randf() * 0.3)
			else:
				p.stop()
	if not _active:
		return
	var rpm := ph.rpm
	var throttle := ph.in_throttle if not ph.is_crashed else 0.0
	_load = move_toward(_load, throttle, delta * 6.0)
	var w := _layer_weights(rpm)
	var rpm_k := clampf(rpm / float(ph.spec["redline"]), 0.0, 1.0)
	var base := 0.55 + 0.45 * rpm_k
	if ph.is_crashed:
		base *= 0.4
	for i in 3:
		var pitch := clampf(rpm / _rpms[i], 0.35, 2.4)
		var on_gain: float = w[i] * base * (0.45 + 0.55 * _load if local else 0.6 + 0.4 * _load)
		_on[i].pitch_scale = pitch
		_on[i].volume_db = linear_to_db(maxf(on_gain, 0.0001))
		if local:
			var off_gain: float = w[i] * base * (1.0 - _load) * 0.8
			_off[i].pitch_scale = pitch
			_off[i].volume_db = linear_to_db(maxf(off_gain, 0.0001))
	# Tires.
	var speed := absf(ph.speed)
	var on_asphalt := ph.surface == BikePhysics.Surface.ASPHALT
	var squeal := 0.0
	if on_asphalt and not ph.is_crashed:
		squeal = clampf((ph.slip - 1.2) / 4.0, 0.0, 1.0)
		if ph.front_locked or ph.rear_locked:
			squeal = maxf(squeal, clampf(speed / 20.0, 0.0, 0.9))
		squeal = maxf(squeal, clampf(ph.wheelspin * 1.5, 0.0, 1.0) * clampf(speed / 6.0, 0.0, 1.0))
	_screech.volume_db = linear_to_db(maxf(squeal * 0.8, 0.0001))
	_screech.pitch_scale = 0.9 + clampf(speed / 60.0, 0.0, 0.3)
	var rumble := 0.0
	if not on_asphalt or ph.is_crashed:
		rumble = clampf(ph.vel.length() / 25.0, 0.0, 1.0)
	_gravel.volume_db = linear_to_db(maxf(rumble * 0.9, 0.0001))
	_gravel.pitch_scale = 0.7 + rumble * 0.5
	# Gear changes: clunk on upshift, occasional pop on downshift / closing the throttle.
	if ph.shift_count != _last_shift:
		_last_shift = ph.shift_count
		if local and _shift_stream:
			_one_shot(_shift_stream, -6.0, 1.0)
		if ph.gear < _last_gear and _pop_stream and _rng.randf() < 0.55:
			_one_shot(_pop_stream, -4.0 if local else -8.0, _rng.randf_range(0.85, 1.15))
		_last_gear = ph.gear
	elif throttle < 0.05 and rpm_k > 0.75 and _pop_stream and _rng.randf() < delta * 1.5:
		_one_shot(_pop_stream, -8.0 if local else -12.0, _rng.randf_range(0.9, 1.2))


func _one_shot(stream: AudioStream, db: float, pitch: float) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = "SFX"
	p.volume_db = db
	p.pitch_scale = pitch
	p.unit_size = 8.0
	p.max_distance = 150.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

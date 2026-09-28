class_name RemoteController
extends RefCounted
## Drives a bike from network snapshots with ~100 ms interpolation delay.

const DELAY := 0.1
const MAX_BUFFER := 40

var times := PackedFloat32Array()
var frames: Array = [] ## PackedFloat32Array snapshots (ReplayRecorder layout)
var players: Array = []
var enabled := true
var _clock := 0.0
var _offset := 0.0
var _have_offset := false
var _last_pos := Vector3.ZERO


func push(t: float, snapshot: PackedFloat32Array) -> void:
	if not times.is_empty() and t <= times[times.size() - 1]:
		return
	if not _have_offset:
		_offset = t - _clock
		_have_offset = true
	times.append(t)
	frames.append(snapshot)
	while times.size() > MAX_BUFFER:
		times.remove_at(0)
		frames.pop_front()


func update(bike: Bike, delta: float) -> void:
	_clock += delta
	if times.is_empty():
		return
	# Slowly track the sender clock so the delay stays constant.
	var newest := times[times.size() - 1]
	var target_offset := newest - _clock
	_offset = lerpf(_offset, target_offset, clampf(delta * 0.5, 0.0, 1.0))
	var t := _clock + _offset - DELAY
	var flat := PackedFloat32Array()
	for f in frames:
		flat.append_array(f)
	var s := ReplayRecorder.sample(times, flat, t)
	if s.is_empty():
		return
	var ph := bike.physics
	var prev := ph.pos
	bike.apply_snapshot(s)
	# Keep the physics state in sync for collisions, progress and audio.
	ph.pos = s["pos"]
	ph.yaw = s["yaw"]
	ph.speed = s["spd"]
	ph.rpm = s["rpm"]
	ph.gear = s["gear"]
	ph.in_throttle = s["thr"]
	ph.in_brake = s["brk"]
	ph.is_crashed = s["crash"]
	if delta > 0.0:
		ph.vel = (ph.pos - prev) / delta if prev != Vector3.ZERO else Vector3.ZERO
	if bike.track:
		var proj := bike.track.project(ph.pos, ph.track_index)
		ph.track_index = proj["index"]
		ph.track_dist = proj["dist"]
		ph.track_lateral = proj["lateral"]

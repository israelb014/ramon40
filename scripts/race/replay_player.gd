class_name ReplayPlayer
extends Node
## Plays back a recorded race with automatic TV-style direction: trackside cameras that
## zoom and pan on the focused rider, mixed with chase, low-side and helicopter shots.

enum Shot { TRACKSIDE, CHASE, LOW, HELI, ONBOARD }

var race: Race
var rec: ReplayRecorder
var t := 0.0
var speed := 1.0
var focus := 0
var cam: Camera3D
var shot := Shot.TRACKSIDE
var shot_time := 0.0
var shot_len := 5.0
var cam_index := 0
var _overlay: Control
var _prev_camera: Camera3D
var _t_draw := 0.0
var _heli_angle := 0.0
var _rng := RandomNumberGenerator.new()


func play(p_rec: ReplayRecorder) -> void:
	rec = p_rec
	t = 0.0
	focus = race.local_players[0] if not race.local_players.is_empty() else race.progress.standings()[0]
	_prev_camera = get_viewport().get_camera_3d()
	cam = Camera3D.new()
	cam.far = 9000.0
	cam.near = 0.1
	race.add_child(cam)
	cam.make_current()
	if race.has_method("set_split_visible"):
		race.set_split_visible(false)
	for b in race.bikes:
		if b.rider:
			b.rider.attach(b.model)
		b.physics.is_crashed = false
	_overlay = _ReplayOverlay.new()
	_overlay.player = self
	race._ui_layer.add_child(_overlay)
	_pick_shot()
	Audio.replay_started()


func _process(delta: float) -> void:
	if rec == null:
		return
	_t_draw += delta
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("ui_back"):
		finish()
		return
	if Input.is_action_just_pressed("ui_right"):
		_cycle_focus(1)
	elif Input.is_action_just_pressed("ui_left"):
		_cycle_focus(-1)
	if Input.is_action_just_pressed("ui_up"):
		speed = minf(speed * 2.0, 2.0)
	elif Input.is_action_just_pressed("ui_down"):
		speed = maxf(speed * 0.5, 0.25)
	t += delta * speed
	if t >= rec.duration():
		finish()
		return
	for i in race.bikes.size():
		var b: Bike = race.bikes[i]
		b.apply_snapshot(rec.sample_bike(i, t))
		b.sync_visual(delta * speed)
	shot_time += delta
	_update_camera(delta)
	Audio.update_replay(race, focus, delta)


func _cycle_focus(dir: int) -> void:
	focus = (focus + dir + race.bikes.size()) % race.bikes.size()
	_pick_shot()


func _focus_bike() -> Bike:
	return race.bikes[focus]


func _pick_shot() -> void:
	shot_time = 0.0
	var r := _rng.randf()
	if r < 0.5:
		shot = Shot.TRACKSIDE
		cam_index = race.world.camera_near(_focus_bike().physics.track_dist)
		shot_len = _rng.randf_range(4.0, 7.0)
	elif r < 0.68:
		shot = Shot.CHASE
		shot_len = _rng.randf_range(4.0, 6.0)
	elif r < 0.8:
		shot = Shot.LOW
		shot_len = _rng.randf_range(3.0, 5.0)
	elif r < 0.92:
		shot = Shot.HELI
		_heli_angle = _rng.randf() * TAU
		shot_len = _rng.randf_range(5.0, 7.0)
	else:
		shot = Shot.ONBOARD
		shot_len = _rng.randf_range(3.0, 5.0)


func _update_camera(delta: float) -> void:
	var b := _focus_bike()
	var p := b.global_position + Vector3.UP * 0.8
	var yaw := b.physics.yaw
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var rgt := Vector3(cos(yaw), 0, -sin(yaw))
	match shot:
		Shot.TRACKSIDE:
			var cxf: Transform3D = race.world.trackside_cameras[cam_index]
			cam.global_position = cxf.origin
			cam.look_at(p, Vector3.UP)
			var dist := cxf.origin.distance_to(p)
			# Zoom to keep the bike a consistent size on screen.
			cam.fov = clampf(rad_to_deg(2.0 * atan(4.5 / maxf(dist, 1.0))), 6.0, 60.0)
			# Switch when the rider has clearly passed this camera.
			var cam_d := 30.0 + cam_index * 150.0
			if race.track.wrap_delta(cam_d, b.physics.track_dist) > 70.0:
				cam_index = race.world.camera_near(b.physics.track_dist)
		Shot.CHASE:
			var desired := p - fwd * 6.0 + Vector3.UP * 1.6 + rgt * sin(shot_time * 0.4) * 1.5
			cam.global_position = cam.global_position.lerp(desired, clampf(delta * 5.0, 0.0, 1.0)) if shot_time > 0.1 else desired
			cam.look_at(p, Vector3.UP)
			cam.fov = 55.0
		Shot.LOW:
			var side := 1.0 if int(shot_len * 10.0) % 2 == 0 else -1.0
			cam.global_position = b.global_position + rgt * side * 2.2 + fwd * (1.5 - shot_time * 0.6) + Vector3.UP * 0.35
			cam.look_at(p, Vector3.UP)
			cam.fov = 50.0
		Shot.HELI:
			_heli_angle += delta * 0.25
			var off := Vector3(cos(_heli_angle), 0, sin(_heli_angle)) * 38.0 + Vector3.UP * 26.0
			cam.global_position = p + off
			cam.look_at(p, Vector3.UP)
			cam.fov = 45.0
		Shot.ONBOARD:
			cam.global_transform = b.global_transform * Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3(0, 1.6, 0.9))
			cam.fov = 70.0
	if shot_time > shot_len:
		_pick_shot()


func finish() -> void:
	if rec == null:
		return
	rec = null
	for b in race.bikes:
		b.external_state = {}
		if b.rider and b.rider.tumbling:
			b.rider.attach(b.model)
	if _overlay:
		_overlay.queue_free()
	if race.has_method("set_split_visible"):
		race.set_split_visible(true)
	if _prev_camera and is_instance_valid(_prev_camera):
		_prev_camera.make_current()
	cam.queue_free()
	Audio.replay_finished()
	race.end_replay()
	queue_free()


class _ReplayOverlay extends Control:
	var player: ReplayPlayer

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var s := size.y / 1080.0
		var rtl := Settings.is_rtl()
		var text := tr("REPLAY")
		var hf := UITheme.heading_font()
		var fs := int(64 * s)
		var w := hf.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x := size.x - 70.0 * s - w if rtl else 110.0 * s
		var dot_x := size.x - 40.0 * s if rtl else 70.0 * s
		var blink := 0.5 + 0.5 * sin(player._t_draw * 5.0)
		draw_circle(Vector2(dot_x, 70.0 * s), 12.0 * s, Color(UITheme.BAD, 0.4 + 0.6 * blink))
		draw_string(hf, Vector2(x, 92.0 * s), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.TEXT)
		var b: Bike = player._focus_bike()
		var name_text := "%s  ·  %s" % [b.rider_name, tr(GameData.bike(b.bike_id)["name"])]
		var bf := UITheme.body_font(600)
		var nw := bf.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(30 * s)).x
		draw_string(bf, Vector2(size.x - 70.0 * s - nw if rtl else 70.0 * s, 140.0 * s), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(30 * s), UITheme.MUTED)
		var hint := tr("REPLAY_HINT")
		var hw := bf.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 * s)).x
		draw_string(bf, Vector2((size.x - hw) * 0.5, size.y - 50.0 * s), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 * s), Color(UITheme.TEXT, 0.7))
		# Progress bar.
		var frac := player.t / maxf(player.rec.duration(), 0.01) if player.rec else 1.0
		var bar := Rect2(Vector2(size.x * 0.3, size.y - 30.0 * s), Vector2(size.x * 0.4, 5.0 * s))
		draw_rect(bar, Color(1, 1, 1, 0.15))
		var fill := Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y))
		if rtl:
			fill.position.x = bar.end.x - bar.size.x * frac
		draw_rect(fill, UITheme.ACCENT)

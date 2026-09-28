class_name MenuBackground
extends Node3D
## Live 3D backdrop for the main menu: the Ramon crater rim at sunset with the player's
## bike parked on the shoulder, a slow cinematic camera and a few riders passing by.

signal ready_to_show

var world: TrackWorld
var track: TrackData
var hero: Bike
var cam: Camera3D
var riders: Array = []
var _ai: Array = []
var _t := 0.0
var _task := -1
var _data: Dictionary = {}
var _built := false
const HERO_DIST := 330.0


func _ready() -> void:
	_task = WorkerThreadPool.add_task(func(): _data = TrackWorld.generate_data("ramon", true, 0.8), true, "menu_bg")


func _process(delta: float) -> void:
	if not _built:
		if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
			WorkerThreadPool.wait_for_task_completion(_task)
			_task = -1
			_build()
		return
	_t += delta
	_update_camera()
	for i in riders.size():
		var b: Bike = riders[i]
		_ai[i].update(b, delta)
		for s in 2:
			b.physics.step(delta * 0.5, track)
		b.post_step(delta)
		b.sync_visual(delta)
	hero.sync_visual(delta)


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)


func _build() -> void:
	world = TrackWorld.new()
	add_child(world)
	world.assemble(_data, 1)
	_data = {}
	track = world.track
	var sel: String = Save.progress.get("selected_bike", "naked")
	hero = _spawn(sel, _hero_colors(sel))
	var xf := track.transform_at(HERO_DIST, track.half_width + 1.6)
	xf.basis = xf.basis * Basis(Vector3.UP, deg_to_rad(-24.0))
	hero.place_at(xf)
	hero.physics.in_throttle = 0.0
	# A few riders lapping in the background.
	var line := RacingLine.for_track(track)
	var bikes := ["sport", "supermoto", "cafe"]
	for i in 3:
		var b := _spawn(bikes[i], {"paint": GameData.paint_color([6, 3, 9][i]), "accent": GameData.paint_color(1)})
		b.place_at(track.transform_at(HERO_DIST - 260.0 - i * 90.0, 0.0))
		var ai := AIController.new(line, GameData.bike(bikes[i]), "easy", i + 3)
		ai.all_bikes = riders
		ai.rubber_band_enabled = false
		riders.append(b)
		_ai.append(ai)
	for a in _ai:
		a.all_bikes = riders
	cam = Camera3D.new()
	cam.far = 9000.0
	cam.fov = 48.0
	add_child(cam)
	cam.make_current()
	_built = true
	add_to_group("quality_listeners")
	apply_quality_settings()
	_update_camera()
	ready_to_show.emit()


func apply_quality_settings() -> void:
	EnvironmentBuilder.apply_quality(world.environment_node.environment, world.sun)
	EnvironmentBuilder.apply_viewport_quality(get_viewport())


func _hero_colors(bike_id: String) -> Dictionary:
	var p := Save.get_paint(bike_id)
	var suit: Dictionary = Save.progress.get("suit", {"main": 2, "accent": 0})
	return {
		"paint": GameData.paint_color(int(p.get("body", 0))),
		"accent": GameData.paint_color(int(p.get("accent", 10))),
		"suit_main": GameData.paint_color(int(suit.get("main", 2))),
		"suit_accent": GameData.paint_color(int(suit.get("accent", 0))),
	}


func _spawn(bike_id: String, colors: Dictionary) -> Bike:
	var b := Bike.new()
	b.world_root = world
	add_child(b)
	b.setup(bike_id, track, colors)
	b.physics.crashes_enabled = false
	b.enable_headlight(false)
	return b


func refresh_hero() -> void:
	if not _built:
		return
	var sel: String = Save.progress.get("selected_bike", "naked")
	var xf := hero.global_transform
	var yaw := hero.physics.yaw
	hero.queue_free()
	hero = _spawn(sel, _hero_colors(sel))
	hero.place_at(Transform3D(Basis(Vector3.UP, yaw), xf.origin))


func _update_camera() -> void:
	if hero == null:
		return
	var center := hero.global_position + Vector3.UP * 0.75
	# Camera on the road side looking across the bike toward the crater (south).
	var a := -1.57 + sin(_t * 0.07) * 0.75
	var r := 5.6 + sin(_t * 0.05) * 0.8
	var pos := center + Vector3(cos(a) * r, 0.9 + sin(_t * 0.11) * 0.35, sin(a) * r)
	cam.global_position = pos
	# Frame the bike off-center so the menu cards have room on the reading side.
	var side := hero.global_transform.basis.x
	cam.look_at(center + side * (1.6 if Settings.is_rtl() else -1.6), Vector3.UP)

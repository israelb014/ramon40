class_name Race
extends Node3D
## Race scene: builds the world, spawns riders, runs the fixed-step simulation, tracks
## laps/positions and drives the countdown -> race -> results -> replay flow.

signal race_finished(results: Array)

enum State { INTRO, COUNTDOWN, RACING, FINISHING, RESULTS, REPLAY }

const SUBSTEPS := 2
const COUNTDOWN_TIME := 3.0
const AI_COLORS := [0, 1, 3, 4, 5, 6, 7, 8, 9, 10]

var config: Dictionary
var world: TrackWorld
var track: TrackData
var line: RacingLine
var bikes: Array[Bike] = []
var controllers: Array = []
var local_players: Array[int] = [] ## bike indices of local humans
var cameras: Array[RaceCamera] = []
var huds: Array[RaceHUD] = []
var progress: RaceProgress
var state := State.INTRO
var countdown := COUNTDOWN_TIME
var state_time := 0.0
var sim_time := 0.0
var recorder: ReplayRecorder
var ghost_player: GhostPlayer
var net: Node ## NetRace, when online
var results: Array = []
var paused := false
var effects_enabled := true

var _ui_layer: CanvasLayer
var _pause_menu: Control
var _results_screen: Control
var _viewports: Array = []
var _split_layer: CanvasLayer
var _finish_wait := 0.0
var _post_fx: Array = []
var _lap_start_samples: Dictionary = {}
var _camera_modes: Array = []


func _ready() -> void:
	config = Game.race_config if not Game.race_config.is_empty() else Game.default_config()
	_build_world()
	_spawn_bikes()
	_setup_views()
	_setup_ui()
	recorder = ReplayRecorder.new(bikes.size())
	if config.get("ghost", false):
		_setup_ghost()
	state = State.INTRO
	state_time = 0.0
	Audio.race_started(self)


# --- Setup -------------------------------------------------------------------

func _build_world() -> void:
	var data: Dictionary = Game.take_preloaded_world(config["track"])
	if data.is_empty():
		var veg: float = [0.45, 0.75, 1.0, 1.0][clampi(int(Settings.get_value("vegetation", 2)), 0, 3)]
		data = TrackWorld.generate_data(config["track"], true, veg)
	world = TrackWorld.new()
	add_child(world)
	world.assemble(data, int(Settings.get_value("draw_distance", 2)))
	track = world.track
	line = RacingLine.for_track(track)


func _player_colors(p: Dictionary) -> Dictionary:
	var bike_id: String = p.get("bike", "naked")
	var paint_sel: Dictionary = Save.get_paint(bike_id)
	var suit: Dictionary = Save.progress.get("suit", {"main": 2, "accent": 0})
	return {
		"paint": GameData.paint_color(int(p.get("paint", paint_sel.get("body", 0)))),
		"accent": GameData.paint_color(int(p.get("accent", paint_sel.get("accent", 10)))),
		"suit_main": GameData.paint_color(int(p.get("suit_main", suit.get("main", 2)))),
		"suit_accent": GameData.paint_color(int(p.get("suit_accent", suit.get("accent", 0)))),
		"helmet": Color(0.95, 0.95, 0.95),
	}


func _spawn_bikes() -> void:
	var players: Array = config.get("players", [])
	var mode: String = config.get("mode", "quick")
	var n_ai: int = 0 if mode == "time_trial" else int(config.get("opponents", 7))
	var remote: Array = config.get("remote", [])
	var total := players.size() + remote.size() + n_ai
	progress = RaceProgress.new(track.length, int(config.get("laps", 3)))
	# Grid order: humans start mid-pack unless a grid order is supplied.
	var slots := []
	for i in total:
		slots.append(i)
	var human_slots := []
	if mode == "time_trial":
		human_slots = [0]
	elif config.has("grid"):
		human_slots = config["grid"]
	else:
		var start_slot := mini(4, total - players.size())
		for i in players.size():
			human_slots.append(start_slot + i)
	var ai_slots := []
	for s in slots:
		if not s in human_slots:
			ai_slots.append(s)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(config["track"]) + int(Time.get_unix_time_from_system()) % 1000
	var idx := 0
	for i in players.size():
		var p: Dictionary = players[i]
		var b := _make_bike(idx, p.get("bike", "naked"), _player_colors(p), human_slots[i])
		b.is_player = true
		b.player_index = i
		b.rider_name = p.get("name", Game.player_name())
		if config.get("autopilot", false):
			var bot := AIController.new(line, GameData.bike(b.bike_id), config.get("autopilot_skill", "hard"), 77 + i)
			bot.enabled = false
			bot.rubber_band_enabled = false
			controllers.append(bot)
		else:
			var pc := PlayerController.new(["p1", "p2"] if players.size() == 1 else (["p1"] if i == 0 else ["p2"]))
			pc.enabled = false
			controllers.append(pc)
		local_players.append(idx)
		idx += 1
	for r in remote:
		var b2 := _make_bike(idx, r.get("bike", "naked"), _player_colors(r), ai_slots.pop_front())
		b2.is_remote = true
		b2.rider_name = r.get("name", "")
		controllers.append(null)
		idx += 1
	var difficulty: String = config.get("difficulty", "medium")
	var bike_pool := ["sport", "naked", "supermoto", "cafe"]
	for k in n_ai:
		var bike_id: String = bike_pool[(k + rng.randi_range(0, 3)) % 4]
		if config.has("ai_bikes") and k < config["ai_bikes"].size():
			bike_id = config["ai_bikes"][k]
		var colors := {
			"paint": GameData.paint_color(AI_COLORS[(k * 3 + rng.randi_range(0, 9)) % AI_COLORS.size()]),
			"accent": GameData.paint_color(rng.randi_range(0, 11)),
			"suit_main": GameData.paint_color([2, 1, 5, 8][k % 4]),
			"suit_accent": GameData.paint_color(rng.randi_range(0, 11)),
			"helmet": Color.from_hsv(rng.randf(), 0.5, 0.95),
		}
		var slot: int = ai_slots[k] if k < ai_slots.size() else idx
		var b3 := _make_bike(idx, bike_id, colors, slot)
		b3.rider_name = config["ai_names"][k] if config.has("ai_names") else GameData.rider_name(k)
		var ai := AIController.new(line, GameData.bike(bike_id), difficulty, 1000 + k * 17)
		ai.enabled = false
		ai.progress = progress
		ai.reference_ids = local_players.duplicate()
		controllers.append(ai)
		idx += 1
	for c in controllers:
		if c is AIController:
			c.all_bikes = bikes
	for b in bikes:
		progress.add_rider(b.index, b.physics.track_dist)
		if b.is_player:
			b.physics.assist = 0.55
	var night: bool = GameData.TRACKS.get(track.id, {}).get("time_of_day", "") == "night"
	for b in bikes:
		b.enable_headlight(night)


func _make_bike(idx: int, bike_id: String, colors: Dictionary, slot: int) -> Bike:
	var b := Bike.new()
	b.name = "Bike%d" % idx
	b.index = idx
	b.world_root = world
	add_child(b)
	b.setup(bike_id, track, colors)
	b.place_at(track.grid_transform(slot))
	b.crashed.connect(_on_bike_crashed)
	b.respawned.connect(_on_bike_respawned)
	var fx := BikeEffects.new()
	b.add_child(fx)
	fx.setup(b)
	b.effects = fx
	bikes.append(b)
	return b


func _setup_views() -> void:
	var n := local_players.size()
	if n <= 1:
		var cam := RaceCamera.new()
		cam.own_layer = 11
		add_child(cam)
		cam.target = bikes[local_players[0]] if n == 1 else bikes[0]
		cam.set_mode(int(Settings.get_value("camera", 0)))
		cam.make_current()
		cameras.append(cam)
		EnvironmentBuilder.apply_viewport_quality(get_viewport())
		_set_rider_layer(cam.target, 11)
		return
	# Split screen: two sub-viewports sharing this world.
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	_split_layer = layer
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 4)
	layer.add_child(box)
	for i in n:
		var cont := SubViewportContainer.new()
		cont.stretch = true
		cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cont.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(cont)
		var vp := SubViewport.new()
		vp.world_3d = get_viewport().world_3d
		vp.audio_listener_enable_3d = i == 0
		cont.add_child(vp)
		EnvironmentBuilder.apply_viewport_quality(vp)
		var cam := RaceCamera.new()
		cam.own_layer = 11 + i
		vp.add_child(cam)
		cam.target = bikes[local_players[i]]
		cam.set_mode(int(Settings.get_value("camera", 0)))
		cam.current = true
		_set_rider_layer(cam.target, 11 + i)
		cameras.append(cam)
		_viewports.append(vp)


func _set_rider_layer(b: Bike, layer: int) -> void:
	## Puts the rider's head on its own render layer so the helmet camera can hide it.
	if b.rider == null:
		return
	var head := b.rider.get_node_or_null("Head") as VisualInstance3D
	if head:
		head.layers = 1 << (layer - 1)
	for other in cameras:
		if other.own_layer != layer:
			other.set_cull_mask_value(layer, true)


func _setup_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)
	if local_players.size() <= 1:
		var hud := RaceHUD.new()
		_ui_layer.add_child(hud)
		hud.setup_track(track)
		huds.append(hud)
		_add_post_fx(self, 0)
	else:
		for i in _viewports.size():
			_add_post_fx(_viewports[i], i)
			var l := CanvasLayer.new()
			l.layer = 5
			_viewports[i].add_child(l)
			var hud := RaceHUD.new()
			hud.compact = true
			l.add_child(hud)
			hud.setup_track(track)
			huds.append(hud)
	_pause_menu = PauseMenu.new()
	_pause_menu.race = self
	_ui_layer.add_child(_pause_menu)
	_pause_menu.hide()


func _add_post_fx(parent: Node, _player: int) -> void:
	# Own layer below the HUD so interface elements are never blurred.
	var layer := CanvasLayer.new()
	layer.layer = 1
	parent.add_child(layer)
	var fx := PostFX.new()
	layer.add_child(fx)
	fx.setup(track.style.style)
	_post_fx.append(fx)


func _setup_ghost() -> void:
	var data := Save.load_ghost(track.id)
	if data.is_empty():
		return
	var gb := Bike.new()
	gb.name = "Ghost"
	gb.index = -1
	gb.ghost = true
	gb.world_root = world
	add_child(gb)
	gb.setup(String(data.get("bike", "naked")), track, {"paint": Color(0.6, 0.9, 1.0), "accent": Color(1, 1, 1)})
	ghost_player = GhostPlayer.new(gb, data)


# --- Simulation --------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if paused or state == State.RESULTS or state == State.REPLAY:
		return
	state_time += delta
	match state:
		State.INTRO:
			if state_time > 0.6:
				_set_state(State.COUNTDOWN)
		State.COUNTDOWN:
			countdown -= delta
			for i in local_players:
				var ph := bikes[i].physics
				# Revving on the line: throttle input only moves the tach.
				var ctrl = controllers[i]
				var inp := Controls.read_drive(ctrl.players) if ctrl is PlayerController else {"throttle": 0.6}
				ph.rpm = lerpf(ph.rpm, ph.spec["idle"] + (ph.spec["redline"] * 0.8 - ph.spec["idle"]) * inp["throttle"], 0.15)
			if countdown <= 0.0:
				_start_racing()
		State.RACING, State.FINISHING:
			_simulate(delta)
	_update_net(delta)


func _set_state(s: State) -> void:
	state = s
	state_time = 0.0
	if s == State.COUNTDOWN:
		countdown = COUNTDOWN_TIME
		Audio.play_countdown()


func _start_racing() -> void:
	_set_state(State.RACING)
	for c in controllers:
		if c:
			c.enabled = true
	Audio.play_go()
	for i in local_players:
		Controls.rumble(bikes[i].player_index, 0.3, 0.2, 0.25)


func _simulate(delta: float) -> void:
	sim_time += delta
	progress.tick(delta)
	for i in bikes.size():
		var c = controllers[i]
		if c:
			c.update(bikes[i], delta)
	var h := delta / SUBSTEPS
	for s in SUBSTEPS:
		for b in bikes:
			if not b.is_remote:
				b.physics.step(h, track)
		var events := BikeCollisions.resolve(bikes)
		for e in events:
			_on_collision(e)
	for b in bikes:
		b.post_step(delta)
		var ph := b.physics
		var heading := ph.forward().dot(track.tangents[maxi(ph.track_index, 0)])
		var ev := progress.update_rider(b.index, ph.track_dist, heading, absf(ph.speed), delta)
		if ev != "":
			_on_lap_event(b, ev)
	if ghost_player:
		ghost_player.update(progress.current_lap_time(local_players[0]) if not local_players.is_empty() else 0.0)
	recorder.record(sim_time, bikes)
	if state == State.FINISHING:
		_finish_wait += delta
		if _finish_wait > 4.0:
			_end_race()


func _on_lap_event(b: Bike, ev: String) -> void:
	var e: Dictionary = progress.riders[b.index]
	if b.is_player:
		var hud := _hud_for(b)
		var lap_time: float = e["last_lap_time"]
		var new_record := false
		if lap_time > 0.0:
			new_record = Save.submit_lap(track.id, lap_time, b.bike_id)
			if new_record:
				Save.save_progress()
		if ev == "finish":
			if hud:
				hud.flash(tr("HUD_FINISH"), UITheme.GOLD, 4.0)
			Audio.play_finish()
			_player_finished(b)
		else:
			var remaining := progress.total_laps - int(e["laps_done"])
			if hud:
				if new_record:
					hud.flash(tr("HUD_LAP_RECORD"), UITheme.GOLD)
				elif remaining == 1:
					hud.flash(tr("HUD_FINAL_LAP"), UITheme.ACCENT)
				else:
					hud.flash(GameData.format_time(lap_time), UITheme.TEXT, 1.8)
			Audio.play_ui("lap")
		# Ghost: keep the player's best lap samples.
		if config.get("mode", "") == "time_trial" and lap_time > 0.0:
			_store_ghost_lap(b, lap_time)
	elif ev == "finish" and net and net.has_method("on_rider_finished"):
		net.on_rider_finished(b.index)


func _store_ghost_lap(b: Bike, lap_time: float) -> void:
	var start: float = _lap_start_samples.get(b.index, 0.0)
	var samples := recorder.extract(b.index, start, sim_time)
	_lap_start_samples[b.index] = sim_time
	var best := Save.load_ghost(track.id)
	if best.is_empty() or lap_time < float(best.get("time", INF)):
		var ghost := {"time": lap_time, "bike": b.bike_id, "samples": samples}
		Save.save_ghost(track.id, ghost)
		if ghost_player == null:
			_setup_ghost()
		else:
			ghost_player.set_data(ghost)
		var hud := _hud_for(b)
		if hud:
			hud.flash(tr("HUD_NEW_GHOST"), UITheme.GOLD)


func _player_finished(b: Bike) -> void:
	# The finished player's bike is taken over by the autopilot for a cool-down lap.
	var i := b.index
	var ai := AIController.new(line, b.physics.spec, "easy", 999)
	ai.all_bikes = bikes
	ai.rubber_band_enabled = false
	controllers[i] = ai
	var all_done := true
	for p in local_players:
		if not progress.riders[p]["finished"]:
			all_done = false
	if config.get("mode", "") == "time_trial":
		all_done = true
	if all_done and state == State.RACING:
		_set_state(State.FINISHING)
		_finish_wait = 0.0


func _end_race() -> void:
	progress.force_finish_all()
	results = _build_results()
	_set_state(State.RESULTS)
	Game.last_result = {"config": config, "results": results, "track": track.id}
	_apply_race_rewards()
	race_finished.emit(results)
	_show_results()


func _build_results() -> Array:
	var out := []
	var order := progress.standings()
	for pos in order.size():
		var id: int = order[pos]
		var b := bikes[id]
		var e: Dictionary = progress.riders[id]
		out.append({
			"position": pos + 1, "index": id, "name": b.rider_name, "bike": b.bike_id,
			"time": float(e["finish_time"]), "best_lap": float(e["best_lap"]),
			"is_player": b.is_player, "player_index": b.player_index, "estimated": e.get("estimated", false),
			"remote": b.is_remote, "paint": b.paint,
		})
	return out


func _apply_race_rewards() -> void:
	if config.get("mode", "") in ["online"]:
		return
	for r in results:
		if not r["is_player"]:
			continue
		Save.progress["races_finished"] = int(Save.progress.get("races_finished", 0)) + 1
		if r["position"] == 1:
			Save.progress["wins"] = int(Save.progress.get("wins", 0)) + 1
		if not r["estimated"]:
			Save.submit_race(track.id, r["time"], r["bike"], progress.total_laps)
	Save.save_progress()


func _show_results() -> void:
	for h in huds:
		h.visible = false
	_results_screen = ResultsScreen.new()
	_results_screen.race = self
	_ui_layer.add_child(_results_screen)


func _on_collision(e: Dictionary) -> void:
	var impact: float = e["impact"]
	for key in ["a", "b"]:
		var b: Bike = e[key]
		if b.is_player:
			Controls.rumble(b.player_index, 0.4, clampf(impact / 12.0, 0.1, 1.0), 0.18)
			var cam := _camera_for(b)
			if cam:
				cam.add_shake(clampf(impact / 10.0, 0.1, 0.8))
	Audio.play_impact(e["a"].global_position, impact)


func _on_bike_crashed(b: Bike) -> void:
	Audio.play_crash(b.global_position)
	if b.is_player:
		Controls.rumble(b.player_index, 1.0, 1.0, 0.6)
		var cam := _camera_for(b)
		if cam:
			cam.add_shake(1.0)


func _on_bike_respawned(b: Bike) -> void:
	var cam := _camera_for(b)
	if cam:
		cam.snap()
	# Keep race distance continuous after a respawn step-back.
	progress.update_rider(b.index, b.physics.track_dist)


func _camera_for(b: Bike) -> RaceCamera:
	for c in cameras:
		if c.target == b:
			return c
	return null


func _hud_for(b: Bike) -> RaceHUD:
	var i := local_players.find(b.index)
	if i >= 0 and i < huds.size():
		return huds[i]
	return null


# --- Frame update ------------------------------------------------------------

func _process(delta: float) -> void:
	if state == State.REPLAY:
		return
	for b in bikes:
		b.sync_visual(delta)
	if ghost_player:
		ghost_player.bike.sync_visual(delta)
	for i in cameras.size():
		var cam := cameras[i]
		if state != State.RESULTS:
			var ctrl = controllers[local_players[i]]
			var players: Array = ctrl.players if ctrl is PlayerController else (["p1"] if i == 0 else ["p2"])
			cam.look_back = Controls.pressed(players, "look_back")
			if Controls.just_pressed(players, "camera"):
				cam.cycle_mode()
				Settings.set_value("camera", int(cam.mode))
			if state == State.RACING and Controls.just_pressed(players, "respawn"):
				var b := cam.target
				if not b.physics.is_crashed and not progress.riders[b.index]["finished"]:
					b.respawn()
		cam.update_camera(delta)
	_update_huds()
	for i in _post_fx.size():
		var fx: PostFX = _post_fx[i]
		var target: Bike = cameras[mini(i, cameras.size() - 1)].target if not cameras.is_empty() else null
		if target:
			fx.update_fx(absf(target.physics.speed), cameras[mini(i, cameras.size() - 1)].mode == RaceCamera.Mode.HELMET, delta)
	Audio.update_race(self, delta)


func _update_huds() -> void:
	for i in huds.size():
		if i >= local_players.size():
			break
		var b := bikes[local_players[i]]
		var e: Dictionary = progress.riders[b.index]
		var markers := []
		for o in bikes:
			markers.append({"pos": o.physics.pos, "self": o == b, "color": o.paint.lightened(0.2)})
		if ghost_player and ghost_player.visible:
			markers.append({"pos": ghost_player.bike.physics.pos, "self": false, "color": Color(0.6, 0.9, 1.0, 0.7)})
		var ph := b.physics
		var st := {
			"speed": absf(ph.speed) * Settings.speed_factor(),
			"gear": ph.gear,
			"rpm": ph.rpm / float(ph.spec["redline"]),
			"position": progress.position_of(b.index),
			"total": bikes.size(),
			"lap": progress.current_lap(b.index),
			"laps": progress.total_laps,
			"lap_time": progress.current_lap_time(b.index) if state != State.COUNTDOWN and state != State.INTRO else 0.0,
			"best_lap": float(e["best_lap"]) if float(e["best_lap"]) > 0.0 else Save.best_lap(track.id),
			"wrong_way": progress.is_wrong_way(b.index) and state == State.RACING,
			"countdown": countdown if state == State.COUNTDOWN else (-0.5 if state == State.RACING and state_time < 1.0 else -1.0),
			"markers": markers,
		}
		if state == State.RACING and state_time < 1.0:
			st["countdown"] = 0.0 if state_time < 1.0 else -1.0
		huds[i].state = st


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and state in [State.COUNTDOWN, State.RACING, State.FINISHING, State.INTRO]:
		if net == null or not net.has_method("is_online") or not net.is_online():
			set_paused(not paused)
		else:
			_pause_menu.visible = not _pause_menu.visible
		get_viewport().set_input_as_handled()


func set_paused(p: bool) -> void:
	paused = p
	get_tree().paused = p
	_pause_menu.visible = p
	if p:
		_pause_menu.call("open")
	Audio.set_race_paused(p)


func restart() -> void:
	get_tree().paused = false
	Game.start_race(config)


func quit_to_menu() -> void:
	get_tree().paused = false
	Game.go_to_menu("")


func _update_net(delta: float) -> void:
	if net and net.has_method("race_tick"):
		net.race_tick(self, delta)


# --- Replay ------------------------------------------------------------------

func set_split_visible(v: bool) -> void:
	if _split_layer:
		_split_layer.visible = v

func start_replay() -> void:
	if _results_screen:
		_results_screen.visible = false
	_set_state(State.REPLAY)
	var rp := ReplayPlayer.new()
	rp.race = self
	add_child(rp)
	rp.play(recorder)


func end_replay() -> void:
	_set_state(State.RESULTS)
	if _results_screen:
		_results_screen.visible = true
		if _results_screen.has_method("refocus"):
			_results_screen.refocus()
	if not cameras.is_empty():
		cameras[0].make_current() if local_players.size() <= 1 else null

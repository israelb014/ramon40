extends Node
## Central audio service. Bakes every sound procedurally on a worker thread at startup
## (UI blips first, then the menu music, effects and the four engines), then provides
## music, interface sounds, positional one-shots, ambience and per-bike engine audio.

signal bank_ready

var sounds: Dictionary = {} ## id -> AudioStreamWAV
var engines: Dictionary = {} ## bike_id -> {"on": [..], "off": [..], "rpms": [..]}
var music: AudioStreamWAV
var ready_ui := false
var ready_all := false

var _ui_players: Array = []
var _ui_next := 0
var _music_player: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _wind: Array = [] # per local player
var _task := -1
var _music_task := -1
var _pending: Dictionary = {}
var _music_wanted := false
var _race: Node
var _music_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "UI"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_ui_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)
	if DisplayServer.get_name() == "headless" and OS.get_environment("RAMON_AUDIO") == "":
		# Headless runs (tests, CI) skip the heavy synthesis.
		return
	_music_task = WorkerThreadPool.add_task(_bake_music, true, "music_bake")
	_task = WorkerThreadPool.add_task(_bake_bank, true, "audio_bake")


func _setup_buses() -> void:
	var music_idx := AudioServer.get_bus_index("Music")
	if music_idx >= 0 and AudioServer.get_bus_effect_count(music_idx) == 0:
		var rev := AudioEffectReverb.new()
		rev.room_size = 0.55
		rev.damping = 0.4
		rev.wet = 0.18
		rev.dry = 0.9
		AudioServer.add_bus_effect(music_idx, rev)
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		var lim := AudioEffectLimiter.new()
		lim.ceiling_db = -0.5
		lim.threshold_db = -3.0
		AudioServer.add_bus_effect(master, lim)
	var sfx := AudioServer.get_bus_index("SFX")
	if sfx >= 0 and AudioServer.get_bus_effect_count(sfx) == 0:
		var comp := AudioEffectCompressor.new()
		comp.threshold = -12.0
		comp.ratio = 3.0
		AudioServer.add_bus_effect(sfx, comp)


# --- Baking (worker threads) -------------------------------------------------

func _bake_music() -> void:
	var lr := MusicSynth.generate()
	_pending["music"] = Synth.to_stream(lr[0], true, Synth.RATE, lr[1])


func _bake_bank() -> void:
	var out := {}
	for id in ["move", "tick", "click", "back", "confirm", "error", "count", "go", "lap", "finish"]:
		out["ui_" + id] = Synth.to_stream(SfxSynth.ui(id))
	_pending["ui"] = out.duplicate()
	out["wind"] = Synth.to_stream(SfxSynth.wind(), true)
	out["screech"] = Synth.to_stream(SfxSynth.screech(), true)
	out["gravel"] = Synth.to_stream(SfxSynth.gravel(), true)
	out["crash"] = Synth.to_stream(SfxSynth.crash())
	out["impact"] = Synth.to_stream(SfxSynth.impact())
	out["shift"] = Synth.to_stream(SfxSynth.gear_shift())
	out["backfire"] = Synth.to_stream(SfxSynth.backfire())
	for style in ["ramon", "deadsea", "jerusalem"]:
		out["amb_" + style] = Synth.to_stream(SfxSynth.ambience(style), true)
	var eng := {}
	for bike_id in GameData.BIKE_ORDER:
		var spec: Dictionary = GameData.BIKES[bike_id]
		var layout: String = spec["engine"]
		var rpms := EngineSynth.layer_rpms(spec)
		var on := []
		var off := []
		for r in rpms:
			on.append(Synth.to_stream(EngineSynth.bake(layout, r, true), true))
			off.append(Synth.to_stream(EngineSynth.bake(layout, r, false), true))
		eng[bike_id] = {"on": on, "off": off, "rpms": rpms}
	_pending["bank"] = out
	_pending["engines"] = eng


func _process(_delta: float) -> void:
	if _pending.has("ui") and not ready_ui:
		sounds.merge(_pending["ui"])
		ready_ui = true
	if _music_task >= 0 and WorkerThreadPool.is_task_completed(_music_task):
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
		music = _pending.get("music")
		if _music_wanted:
			play_menu_music()
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		sounds.merge(_pending.get("bank", {}), true)
		engines = _pending.get("engines", {})
		_pending.clear()
		ready_all = true
		bank_ready.emit()
		if _race and is_instance_valid(_race):
			race_started(_race)


func is_baking() -> bool:
	return _task >= 0 or _music_task >= 0


func _exit_tree() -> void:
	release()
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
	if _music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_task)


## Stops all playback and drops the baked streams (called on exit).
func release() -> void:
	if _music_tween:
		_music_tween.kill()
	_music_player.stop()
	_music_player.stream = null
	for p in _ui_players:
		p.stop()
		p.stream = null
	music = null
	sounds.clear()
	engines.clear()


# --- Interface & music --------------------------------------------------------

func play_ui(id: String) -> void:
	var s: AudioStreamWAV = sounds.get("ui_" + id)
	if s == null:
		return
	var p: AudioStreamPlayer = _ui_players[_ui_next]
	_ui_next = (_ui_next + 1) % _ui_players.size()
	p.stream = s
	p.volume_db = -4.0 if id in ["move", "tick"] else 0.0
	p.play()


func play_menu_music() -> void:
	_music_wanted = true
	if music == null:
		return
	if _music_player.playing and _music_player.stream == music:
		_fade_music(0.0, 0.8)
		return
	_music_player.stream = music
	_music_player.volume_db = -30.0
	_music_player.play()
	_fade_music(0.0, 1.6)


func menu_music_fade_out() -> void:
	_music_wanted = false
	_fade_music(-40.0, 1.2, true)


func _fade_music(target_db: float, time: float, stop_after := false) -> void:
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", target_db, time)
	if stop_after:
		_music_tween.tween_callback(_music_player.stop)


# --- Race ---------------------------------------------------------------------

func race_started(race: Node) -> void:
	_race = race
	if not ready_all:
		return
	var track_id: String = race.track.id if race.track else "ramon"
	for b in race.bikes:
		_attach_bike(b, b.is_player)
	if race.ghost_player:
		pass # the ghost is silent
	_ambience = AudioStreamPlayer.new()
	_ambience.stream = sounds.get("amb_" + track_id)
	_ambience.bus = "SFX"
	_ambience.volume_db = -14.0
	race.add_child(_ambience)
	_ambience.play()
	_wind.clear()
	for i in race.local_players.size():
		var w := AudioStreamPlayer.new()
		w.stream = sounds.get("wind")
		w.bus = "SFX"
		w.volume_db = -60.0
		race.add_child(w)
		w.play()
		_wind.append(w)
	for cam in race.cameras:
		cam.doppler_tracking = Camera3D.DOPPLER_TRACKING_IDLE_STEP


func _attach_bike(b: Node, local: bool) -> void:
	if b.sound != null or not engines.has(b.bike_id):
		return
	var ba := BikeAudio.new()
	ba.setup(b, engines[b.bike_id], sounds, local)
	b.add_child(ba)
	b.sound = ba


func update_race(race: Node, delta: float) -> void:
	if not ready_all:
		return
	for b in race.bikes:
		if b.sound:
			b.sound.update(delta)
	for i in _wind.size():
		if i < race.local_players.size():
			var ph: BikePhysics = race.bikes[race.local_players[i]].physics
			var v := absf(ph.speed)
			var k := clampf(v / 70.0, 0.0, 1.0)
			_wind[i].volume_db = linear_to_db(maxf(k * k * 0.9 * (1.0 - ph.tuck_amount * 0.35), 0.0001))
			_wind[i].pitch_scale = 0.7 + k * 0.6


func update_replay(race: Node, _focus: int, delta: float) -> void:
	update_race(race, delta)


func set_race_paused(p: bool) -> void:
	var idx := AudioServer.get_bus_index("Engine")
	AudioServer.set_bus_mute(idx, p)
	var sfx := AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_mute(sfx, p)


func replay_started() -> void:
	pass


func replay_finished() -> void:
	pass


func play_countdown() -> void:
	# Three beeps, one per second.
	for k in 3:
		get_tree().create_timer(float(k), false).timeout.connect(func(): play_ui("count"))


func play_go() -> void:
	play_ui("go")


func play_finish() -> void:
	play_ui("finish")


func _one_shot(id: String, pos: Vector3, volume_db := 0.0) -> void:
	if _race == null or not is_instance_valid(_race) or not sounds.has(id):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = sounds[id]
	p.bus = "SFX"
	p.unit_size = 14.0
	p.volume_db = volume_db
	p.max_distance = 250.0
	_race.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


func play_crash(pos: Vector3) -> void:
	_one_shot("crash", pos, 2.0)


func play_impact(pos: Vector3, strength: float) -> void:
	_one_shot("impact", pos, linear_to_db(clampf(strength / 10.0, 0.15, 1.0)))

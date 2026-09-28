extends Node
## Dev harness: runs a full race with the player on autopilot and reports the outcome.
## Usage: godot --headless --fixed-fps 60 --path . tools/dev/race_bot.tscn -- <track> <laps> <difficulty> [shots_prefix]

var race: Race
var crashes := {}
var _frames := 0
var _shots := ""
var _shot_times: Array = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if OS.get_environment("RB_PRESET") != "":
		Settings.apply_preset(OS.get_environment("RB_PRESET"))
	var cfg := Game.default_config()
	cfg["track"] = args[0] if args.size() > 0 else "ramon"
	cfg["laps"] = int(args[1]) if args.size() > 1 else 1
	cfg["difficulty"] = args[2] if args.size() > 2 else "medium"
	_shots = args[3] if args.size() > 3 else ""
	if args.size() > 4:
		for a in args[4].split(","):
			_shot_times.append(float(a))
	cfg["autopilot"] = true
	cfg["players"] = [{"bike": "sport", "name": "BOT"}]
	Game.race_config = cfg
	race = load(Game.RACE).instantiate()
	add_child(race)
	for b in race.bikes:
		crashes[b.index] = 0
		b.crashed.connect(func(bb): crashes[bb.index] += 1; print("CRASH bike=", bb.index, " ", bb.bike_id, " reason=", bb.physics.crash_reason, " t=", snappedf(race.sim_time, 0.1), " d=", int(bb.physics.track_dist), " v=", int(bb.physics.speed * 3.6)))
	race.race_finished.connect(_on_finished)


var offtime := {}
var _log_t := 0.0


func _physics_process(d: float) -> void:
	_frames += 1
	var fast := int(OS.get_environment("BOT_FAST")) if OS.get_environment("BOT_FAST") != "" else 0
	if race.state == Race.State.RACING and (_shot_times.is_empty() or race.sim_time < _shot_times[0] - 1.0):
		for k in fast:
			race._physics_process(d)
	_log_t += d
	for b in race.bikes:
		var ph: BikePhysics = b.physics
		if ph.surface != BikePhysics.Surface.ASPHALT and not ph.is_crashed and race.state == Race.State.RACING:
			offtime[b.index] = offtime.get(b.index, 0.0) + d
			if _log_t > 0.5 and OS.get_environment("BOT_VERBOSE") != "":
				print("OFF bike=%d %s d=%d lat=%.1f v=%d" % [b.index, b.bike_id, int(ph.track_dist), ph.track_lateral, int(ph.speed * 3.6)])
	if _log_t > 0.5:
		_log_t = 0.0
	if _shots != "" and not _shot_times.is_empty() and race.sim_time > _shot_times[0]:
		_shot_times.pop_front()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_%03d.png" % [_shots, int(race.sim_time)])
	if race.sim_time > 60.0 * 12:
		print("TIMEOUT")
		get_tree().quit(1)


func _on_finished(results: Array) -> void:
	print("RACE FINISHED sim_time=", snappedf(race.sim_time, 0.1), " frames=", _frames)
	for r in results:
		print("  P%d %-12s %-10s time=%s best=%s crashes=%d off=%.1fs %s" % [r["position"], r["name"], r["bike"], GameData.format_time(r["time"]), GameData.format_time(r["best_lap"]), crashes.get(r["index"], 0), offtime.get(r["index"], 0.0), "(est)" if r["estimated"] else ""])
	print("BOT DONE")
	if _shots != "":
		for i in 30:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s_results.png" % _shots)
		if OS.get_environment("BOT_REPLAY") != "":
			race.start_replay()
			for i in 40:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("%s_replay.png" % _shots)
	get_tree().quit(0)

extends Node
## Headless end-to-end smoke run used by CI. Drives the real game flows and fails on any
## error output (checked by tools/ci_smoke.sh):
##   menu -> every page -> quick race (autopilot) -> results -> replay -> menu
##   -> split-screen race -> time trial (ghost saved) -> menu.

var _log_prefix := "[smoke] "


func _ready() -> void:
	# Survive scene changes: live directly under the root instead of as the current scene.
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait_for(cond: Callable, max_frames: int, what: String) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().process_frame
	push_error("smoke: timed out waiting for " + what)
	return false


func _current() -> Node:
	return get_tree().current_scene


func _run() -> void:
	await _frames(2)
	Save.base_dir = "user://smoke_save"
	Save.load_progress()
	# 1. Main menu and pages.
	get_tree().change_scene_to_file(Game.MAIN_MENU)
	await _frames(5)
	var menu := _current() as MainMenu
	print(_log_prefix, "menu loaded")
	await _wait_for(func(): return menu.background._built, 3000, "menu background")
	for p in [PageRaceSetup.create("quick"), PageRaceSetup.create("time_trial"), PageRaceSetup.create("split"), PageChampionship.new(), PageGarage.new(), PageSettings.new(), PageCredits.new(), PageOnline.new()]:
		menu.open_page(p)
		await _frames(6)
		if p is PageSettings:
			for tab in 5:
				p._panel._select_tab(tab)
				await _frames(3)
		menu.back()
		await _frames(4)
	print(_log_prefix, "pages ok")
	# 2. Quick race through the loading screen.
	await _race({"mode": "quick", "track": "deadsea", "laps": 1, "difficulty": "hard", "players": [{"bike": "naked", "name": "SMOKE"}], "opponents": 7, "autopilot": true})
	var race := _current() as Race
	race.start_replay()
	await _frames(90)
	for c in race.get_children():
		if c is ReplayPlayer:
			c.finish()
	await _frames(5)
	print(_log_prefix, "replay ok")
	# 3. Split screen.
	await _race({"mode": "split", "track": "jerusalem", "laps": 1, "difficulty": "easy", "players": [{"bike": "sport", "name": "P1"}, {"bike": "cafe", "name": "P2"}], "opponents": 2, "autopilot": true})
	print(_log_prefix, "split ok")
	# 4. Time trial with ghost.
	await _race({"mode": "time_trial", "track": "ramon", "laps": 2, "difficulty": "medium", "players": [{"bike": "supermoto", "name": "TT"}], "opponents": 0, "ghost": true, "autopilot": true})
	if Save.load_ghost("ramon").is_empty():
		push_error("smoke: ghost was not saved")
	print(_log_prefix, "time trial ok")
	# 5. One championship round.
	var st := Championship.create("naked", "medium", "SMOKE", 3)
	Save.progress["championship"] = st
	var ccfg := Championship.race_config(st)
	ccfg["laps"] = 1
	ccfg["autopilot"] = true
	await _race(ccfg)
	var st2: Dictionary = Save.progress["championship"]
	var total := 0
	for r in st2["riders"]:
		total += int(r["points"])
	if int(st2["round"]) != 1 or total != 98:
		push_error("smoke: championship points not applied (round %d, total %d)" % [int(st2["round"]), total])
	Game.championship_after_race()
	await _frames(60)
	if not (_current() is MainMenu):
		push_error("smoke: standings page did not open")
	print(_log_prefix, "championship round ok")
	# 6. Back to the menu.
	Game.go_to_menu("")
	await _frames(40)
	print("SMOKE OK")
	get_tree().quit(0)


func _race(cfg: Dictionary) -> void:
	var previous_id := _current().get_instance_id() if _current() else 0
	Game.start_race(cfg)
	await _wait_for(func(): return _current() is Race and _current().get_instance_id() != previous_id, 4000, "race scene")
	var race := _current() as Race
	var done := [false]
	race.race_finished.connect(func(_r): done[0] = true)
	# Fast-forward the simulation.
	for i in 40000:
		if done[0]:
			break
		if race.state == Race.State.RACING or race.state == Race.State.FINISHING:
			for k in 12:
				race._physics_process(1.0 / 60.0)
		await get_tree().process_frame
	if not done[0]:
		push_error("smoke: race did not finish")
	await _frames(20)
	print(_log_prefix, "race finished: ", cfg["mode"], " ", cfg["track"])

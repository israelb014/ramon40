extends Node
## Dev/CI: two-process LAN test. Usage: -- host <port> | client <port>
var role := "host"
var finished := false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0]
	var port := int(args[1]) if args.size() > 1 else 24555
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	Save.base_dir = "user://net_test_" + role
	if role == "host":
		print("NET host err=", Net.host(port))
		Net.lobby_settings = {"track": "deadsea", "laps": 1, "difficulty": "easy", "autopilot": true}
	else:
		print("NET join err=", Net.join("127.0.0.1", port))
	Net.race_starting.connect(func(): print("NET race starting (", role, ")"))

func _process(_d: float) -> void:
	if role == "host" and Net.race == null and Net.players.size() >= 2 and not finished:
		var ids := Net.players.keys()
		for id in ids:
			Net.players[id]["ready"] = true
		if Net.all_ready() and get_tree().current_scene == null or not (get_tree().current_scene is Race):
			if Net.race_config.is_empty():
				Net.lobby_settings["autopilot"] = true
				Net.start_race()
	var scene := get_tree().current_scene
	if scene is Race and not finished:
		var r: Race = scene
		if not r.race_finished.is_connected(_on_finished):
			r.race_finished.connect(_on_finished)
		# Fast forward a little.
		if r.state == Race.State.RACING or r.state == Race.State.FINISHING:
			for k in 2:
				r._physics_process(1.0 / 60.0)

func _on_finished(results: Array) -> void:
	finished = true
	print("NET results (", role, "):")
	for res in results:
		print("  P%d %s %s remote=%s" % [res["position"], res["name"], res["bike"], res["remote"]])
	await get_tree().create_timer(2.0).timeout
	print("NET DONE ", role)
	Net.leave()
	get_tree().quit(0)

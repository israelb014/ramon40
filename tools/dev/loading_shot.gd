extends Node
func _ready() -> void:
	var cfg := Game.default_config()
	cfg["track"] = OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "jerusalem"
	Game.race_config = cfg
	var l: Control = load(Game.LOADING).instantiate()
	l.set("_min_time", 10000.0)
	add_child(l)
	for i in 30:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()

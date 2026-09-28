extends Node
func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hud := RaceHUD.new()
	layer.add_child(hud)
	var t := TrackData.build(TrackLayouts.get_layout("ramon"), false)
	hud.setup_track(t)
	hud.state = {"speed": 187.0, "gear": 4, "rpm": 0.82, "position": 3, "total": 8, "lap": 2, "laps": 3, "lap_time": 63.2, "best_lap": 131.4, "wrong_way": true, "countdown": 2.4, "markers": [{"pos": t.points[100], "self": true}, {"pos": t.points[300], "self": false, "color": Color.RED}]}
	hud.flash("הקפה אחרונה", UITheme.ACCENT)
	for i in 10:
		await get_tree().process_frame
	print("hud size ", hud.size, " vp ", get_viewport().get_visible_rect().size)
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()

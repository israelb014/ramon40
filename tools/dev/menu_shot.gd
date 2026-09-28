extends Node
## Dev: screenshots of the main menu and its pages.
func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var lang := OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "he"
	Settings.set_value("language", lang, false)
	var menu: MainMenu = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	var t := 0
	while not menu.background._built and t < 600:
		await get_tree().process_frame
		t += 1
	for i in 30:
		await get_tree().process_frame
	_shot(out + "_home.png")
	var pages := {"online": PageOnline.new(), "quick": PageRaceSetup.create("quick"), "garage": PageGarage.new(), "champ": PageChampionship.new(), "settings": PageSettings.new()}
	if OS.get_environment("SHOT_ONLINE_ONLY") != "":
		pages = {"online": PageOnline.new()}
	for k in pages:
		menu.open_page(pages[k], false)
		if k == "online":
			pages[k]._on_host()
		for i in 25:
			await get_tree().process_frame
		_shot(out + "_" + k + ".png")
		menu.back()
		for i in 8:
			await get_tree().process_frame
	get_tree().quit()

func _shot(p: String) -> void:
	get_viewport().get_texture().get_image().save_png(p)

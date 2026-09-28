class_name PauseMenu
extends Control
## In-race pause overlay: resume, restart, settings and quit to menu.

var race: Race
var _buttons: Array = []
var _settings: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.theme()
	Widgets.apply_direction(self)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.04, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := Widgets.card(Vector2(620, 0))
	center.add_child(card)
	var v := Widgets.vbox(16)
	card.add_child(v)
	var title := UITheme.heading(tr("PAUSE_TITLE"), 110)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var cfg: Dictionary = race.config if race else {}
	var sub := UITheme.body("%s  ·  %s" % [tr(GameData.TRACKS.get(cfg.get("track", "ramon"), {}).get("name", "")), tr("LAPS_N") % int(cfg.get("laps", 3))], 28, UITheme.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 12)
	v.add_child(sp)
	var online: bool = cfg.get("mode", "") == "online"
	var resume := Widgets.button(tr("PAUSE_RESUME"), "play", true)
	resume.pressed.connect(_on_resume)
	v.add_child(resume)
	_buttons.append(resume)
	if not online:
		var restart := Widgets.button(tr("PAUSE_RESTART"), "restart")
		restart.pressed.connect(func(): race.restart())
		v.add_child(restart)
		_buttons.append(restart)
	var settings := Widgets.button(tr("MENU_SETTINGS"), "settings")
	settings.pressed.connect(_open_settings)
	v.add_child(settings)
	_buttons.append(settings)
	var quit := Widgets.button(tr("PAUSE_QUIT"), "home")
	quit.pressed.connect(func(): race.quit_to_menu())
	v.add_child(quit)
	_buttons.append(quit)
	Widgets.link_focus(_buttons)


func open() -> void:
	if _settings:
		_settings.queue_free()
		_settings = null
	await get_tree().process_frame
	if _buttons.size() > 0 and is_instance_valid(_buttons[0]):
		_buttons[0].grab_focus()


func _on_resume() -> void:
	if race.config.get("mode", "") == "online":
		visible = false
	else:
		race.set_paused(false)


func _open_settings() -> void:
	_settings = SettingsPanel.new()
	_settings.in_race = true
	add_child(_settings)
	_settings.closed.connect(func():
		_settings.queue_free()
		_settings = null
		race.apply_quality_settings()
		_buttons[0].grab_focus())


func _unhandled_input(event: InputEvent) -> void:
	if visible and _settings == null and event.is_action_pressed("ui_back") and not event.is_action_pressed("pause"):
		_on_resume()
		get_viewport().set_input_as_handled()

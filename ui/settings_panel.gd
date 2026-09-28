class_name SettingsPanel
extends Control
## Settings: graphics (preset + individual toggles), display, audio, controls with full
## rebinding for both players, and language. Used from the main menu and the pause menu.

signal closed

var in_race := false
var _tab := 0
var _tab_buttons: Array = []
var _content: VBoxContainer
var _scroll: ScrollContainer
var _capture: Dictionary = {} ## active rebinding: {"player", "action", "keyboard", "button"}
var _control_player := "p1"
var _first_focus: Control

const TABS := [["SET_GRAPHICS", "monitor"], ["SET_DISPLAY", "camera"], ["SET_AUDIO", "volume"], ["SET_CONTROLS", "gamepad"], ["SET_LANGUAGE", "language"]]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.theme()
	Widgets.apply_direction(self)
	if in_race:
		var dim := ColorRect.new()
		dim.color = Color(0.03, 0.02, 0.04, 0.85)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 90)
	margin.add_theme_constant_override("margin_top", 64 if not in_race else 50)
	margin.add_theme_constant_override("margin_bottom", 70)
	add_child(margin)
	var v := Widgets.vbox(18)
	margin.add_child(v)
	var head := Widgets.hbox(22)
	v.add_child(head)
	var back := Button.new()
	back.icon = Widgets.icon("arrow_right" if Settings.is_rtl() else "arrow_left")
	back.custom_minimum_size = Vector2(72, 72)
	back.expand_icon = true
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_constant_override("icon_max_width", 34)
	back.add_theme_stylebox_override("normal", UITheme.pill_style(Color(1, 1, 1, 0.06), 36))
	back.add_theme_stylebox_override("hover", UITheme.pill_style(Color(1, 0.54, 0.24, 0.3), 36))
	back.pressed.connect(_close)
	head.add_child(back)
	head.add_child(UITheme.heading(tr("MENU_SETTINGS"), 110))
	var tabs := Widgets.hbox(12)
	v.add_child(tabs)
	for i in TABS.size():
		var b := Widgets.button(tr(TABS[i][0]), TABS[i][1], false, 26)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 64)
		var idx := i
		b.pressed.connect(func(): _select_tab(idx))
		tabs.add_child(b)
		_tab_buttons.append(b)
	var card := Widgets.card()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(card)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	card.add_child(_scroll)
	_content = Widgets.vbox(10)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	_select_tab(0)


func _select_tab(i: int) -> void:
	_tab = i
	for k in _tab_buttons.size():
		_tab_buttons[k].button_pressed = k == i
	for c in _content.get_children():
		c.queue_free()
	_first_focus = null
	match i:
		0: _build_graphics()
		1: _build_display()
		2: _build_audio()
		3: _build_controls()
		4: _build_language()
	await get_tree().process_frame
	_link()
	if _first_focus:
		_first_focus.grab_focus()


func _link() -> void:
	var focusables: Array = []
	for c in _content.get_children():
		if c is Control and c.focus_mode == Control.FOCUS_ALL and not c.is_queued_for_deletion():
			focusables.append(c)
		elif c is HBoxContainer:
			for cc in c.get_children():
				if cc is Control and cc.focus_mode == Control.FOCUS_ALL:
					focusables.append(cc)
					break
	if focusables.is_empty():
		return
	Widgets.link_focus(focusables)
	for b in _tab_buttons:
		b.focus_neighbor_bottom = b.get_path_to(focusables[0])
	focusables[0].focus_neighbor_top = focusables[0].get_path_to(_tab_buttons[_tab])


func _row(key: String, label: String, options: Array, icon_name := "") -> OptionRow:
	var cur = Settings.get_value(key)
	var idx := 0
	for i in options.size():
		if options[i]["value"] == cur:
			idx = i
	var r := OptionRow.make(label, options, idx, icon_name)
	r.changed.connect(func(_i, v): _on_setting(key, v))
	_content.add_child(r)
	if _first_focus == null:
		_first_focus = r
	return r


func _toggle(key: String, label: String) -> OptionRow:
	return _row(key, label, [{"text": tr("ON"), "value": true}, {"text": tr("OFF"), "value": false}])


func _on_setting(key: String, v) -> void:
	Settings.set_value(key, v)
	if key != "preset" and Settings.PRESET_VALUES.has(Settings.data["preset"]) and Settings.PRESET_VALUES["high"].has(key):
		Settings.set_value("preset", "custom")
	_apply_live()


func _apply_live() -> void:
	# Re-apply quality to whatever scene is running.
	get_tree().call_group("quality_listeners", "apply_quality_settings")


func _section(title: String) -> void:
	var l := UITheme.body(title, 24, UITheme.ACCENT, 700)
	l.custom_minimum_size = Vector2(0, 44)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_content.add_child(l)


# --- Tabs --------------------------------------------------------------------

func _build_graphics() -> void:
	var presets := []
	for p in Settings.PRESETS:
		presets.append({"text": tr("PRESET_" + p.to_upper()), "value": p})
	if Settings.get_value("preset") == "custom":
		presets.append({"text": tr("PRESET_CUSTOM"), "value": "custom"})
	var pr := OptionRow.make(tr("SET_PRESET"), presets, 0, "monitor")
	for i in presets.size():
		if presets[i]["value"] == Settings.get_value("preset"):
			pr.index = i
	pr.changed.connect(func(_i, v):
		if v != "custom":
			Settings.apply_preset(v)
			_apply_live()
			_select_tab(0))
	_content.add_child(pr)
	_first_focus = pr
	_section(tr("SET_LIGHTING"))
	_row("shadows", tr("SET_SHADOWS"), [{"text": tr("OFF"), "value": 0}, {"text": tr("Q_LOW"), "value": 1}, {"text": tr("Q_MEDIUM"), "value": 2}, {"text": tr("Q_HIGH"), "value": 3}])
	_toggle("ssao", tr("SET_SSAO"))
	_toggle("ssil", tr("SET_SSIL"))
	_toggle("sdfgi", tr("SET_SDFGI"))
	_toggle("volumetric_fog", tr("SET_VOLFOG"))
	_toggle("glow", tr("SET_GLOW"))
	_section(tr("SET_EFFECTS"))
	_toggle("motion_blur", tr("SET_MOTION_BLUR"))
	_toggle("heat_haze", tr("SET_HEAT_HAZE"))
	_row("particles", tr("SET_PARTICLES"), [{"text": tr("OFF"), "value": 0}, {"text": tr("Q_LOW"), "value": 1}, {"text": tr("Q_HIGH"), "value": 2}])
	_section(tr("SET_IMAGE"))
	_row("aa", tr("SET_AA"), [{"text": "FXAA", "value": "fxaa"}, {"text": "TAA", "value": "taa"}, {"text": "FSR 2", "value": "fsr2"}])
	var scales := []
	for s in [0.5, 0.6, 0.67, 0.77, 0.85, 1.0]:
		scales.append({"text": "%d%%" % int(round(s * 100.0)), "value": s})
	_row("render_scale", tr("SET_RENDER_SCALE"), scales)
	_row("draw_distance", tr("SET_DRAW_DISTANCE"), [{"text": tr("Q_LOW"), "value": 0}, {"text": tr("Q_MEDIUM"), "value": 1}, {"text": tr("Q_HIGH"), "value": 2}, {"text": tr("Q_ULTRA"), "value": 3}])
	_row("vegetation", tr("SET_VEGETATION"), [{"text": tr("Q_LOW"), "value": 0}, {"text": tr("Q_MEDIUM"), "value": 1}, {"text": tr("Q_HIGH"), "value": 2}])
	var note := UITheme.body(tr("SET_RESTART_NOTE"), 22, UITheme.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(note)


func _build_display() -> void:
	_row("window_mode", tr("SET_WINDOW"), [{"text": tr("WIN_FULLSCREEN"), "value": "fullscreen"}, {"text": tr("WIN_EXCLUSIVE"), "value": "exclusive"}, {"text": tr("WIN_WINDOWED"), "value": "windowed"}], "monitor")
	var res := []
	for r in ["1280x720", "1366x768", "1600x900", "1920x1080", "2560x1440", "3840x2160"]:
		res.append({"text": r, "value": r})
	_row("resolution", tr("SET_RESOLUTION"), res)
	_toggle("vsync", tr("SET_VSYNC"))
	var caps := []
	for c in [0, 30, 60, 120, 144, 165, 240]:
		caps.append({"text": tr("FPS_UNLIMITED") if c == 0 else str(c), "value": c})
	_row("fps_cap", tr("SET_FPS_CAP"), caps)
	_section(tr("SET_HUD"))
	_toggle("show_minimap", tr("SET_MINIMAP"))
	_row("units", tr("SET_UNITS"), [{"text": tr("HUD_KMH"), "value": "kmh"}, {"text": "mph", "value": "mph"}])
	_row("camera", tr("SET_CAMERA"), [{"text": tr("CAM_CHASE"), "value": 0}, {"text": tr("CAM_CLOSE"), "value": 1}, {"text": tr("CAM_HELMET"), "value": 2}], "camera")


func _build_audio() -> void:
	for pair in [["master_volume", "SET_VOL_MASTER"], ["music_volume", "SET_VOL_MUSIC"], ["sfx_volume", "SET_VOL_SFX"], ["engine_volume", "SET_VOL_ENGINE"], ["ui_volume", "SET_VOL_UI"]]:
		var opts := []
		for n in 11:
			opts.append({"text": "%d%%" % (n * 10), "value": n / 10.0})
		var cur: float = float(Settings.get_value(pair[0], 0.8))
		var r := OptionRow.make(tr(pair[1]), opts, int(round(cur * 10.0)), "volume")
		r.wrap = false
		var key: String = pair[0]
		r.changed.connect(func(_i, v):
			Settings.set_value(key, v)
			Audio.play_ui("tick"))
		_content.add_child(r)
		if _first_focus == null:
			_first_focus = r


func _build_controls() -> void:
	var pr := OptionRow.make(tr("SET_PLAYER"), [{"text": tr("PLAYER_1"), "value": "p1"}, {"text": tr("PLAYER_2"), "value": "p2"}], 0 if _control_player == "p1" else 1, "users")
	pr.changed.connect(func(_i, v):
		_control_player = v
		_select_tab(3))
	_content.add_child(pr)
	_first_focus = pr
	var header := Widgets.hbox(12)
	var hl := UITheme.body(tr("SET_ACTION"), 22, UITheme.MUTED, 700)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(hl)
	for t in [["keyboard", "SET_KEYBOARD"], ["gamepad", "SET_GAMEPAD"]]:
		var hh := Widgets.hbox(8)
		hh.custom_minimum_size = Vector2(300, 0)
		hh.add_child(Widgets.icon_rect(t[0], 30, UITheme.MUTED))
		hh.add_child(UITheme.body(tr(t[1]), 22, UITheme.MUTED, 700))
		header.add_child(hh)
	_content.add_child(header)
	for action in Controls.PLAYER_ACTIONS:
		var row := Widgets.hbox(12)
		var l := UITheme.body(tr("ACT_" + action.to_upper()), 28, UITheme.TEXT, 600)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		for kb in [true, false]:
			var b := Button.new()
			b.text = Controls.binding_label(Controls.binding_for(_control_player, action, kb))
			b.custom_minimum_size = Vector2(300, 60)
			b.focus_mode = Control.FOCUS_ALL
			b.add_theme_font_size_override("font_size", 26)
			var act: String = action
			var is_kb: bool = kb
			b.pressed.connect(func(): _start_capture(act, is_kb, b))
			row.add_child(b)
		_content.add_child(row)
	_toggle("vibration", tr("SET_VIBRATION"))
	var reset := Widgets.button(tr("SET_RESET_CONTROLS"), "restart")
	reset.pressed.connect(func():
		Controls.reset_defaults()
		_select_tab(3))
	_content.add_child(reset)


func _build_language() -> void:
	var r := _row("language", tr("SET_LANGUAGE"), [{"text": "עברית", "value": "he"}, {"text": "English", "value": "en"}], "language")
	r.changed.connect(func(_i, _v):
		await get_tree().process_frame
		if not in_race:
			Game.menu_return_page = "settings"
			get_tree().reload_current_scene()
		else:
			Widgets.apply_direction(self)
			_select_tab(4))
	var note := UITheme.body(tr("SET_LANGUAGE_NOTE"), 24, UITheme.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(note)


# --- Rebinding ---------------------------------------------------------------

func _start_capture(action: String, keyboard: bool, button: Button) -> void:
	_capture = {"player": _control_player, "action": action, "keyboard": keyboard, "button": button}
	button.text = tr("SET_PRESS_KEY") if keyboard else tr("SET_PRESS_BUTTON")
	Audio.play_ui("click")


func _input(event: InputEvent) -> void:
	if _capture.is_empty():
		return
	var kb: bool = _capture["keyboard"]
	if kb and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_end_capture()
		else:
			_apply_capture(Controls.event_to_binding(event))
		get_viewport().set_input_as_handled()
	elif not kb and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		var b := Controls.event_to_binding(event)
		if not b.is_empty():
			_apply_capture(b)
			get_viewport().set_input_as_handled()


func _apply_capture(binding: Dictionary) -> void:
	if binding.is_empty():
		return
	Controls.rebind(_capture["player"], _capture["action"], binding)
	Audio.play_ui("confirm")
	_end_capture()


func _end_capture() -> void:
	var b: Button = _capture["button"]
	b.text = Controls.binding_label(Controls.binding_for(_capture["player"], _capture["action"], _capture["keyboard"]))
	_capture = {}


func _close() -> void:
	Settings.save_settings()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _capture.is_empty() and event.is_action_pressed("ui_back"):
		_close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_page_up") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_LEFT_SHOULDER):
		_select_tab((_tab - 1 + TABS.size()) % TABS.size())
	elif event.is_action_pressed("ui_page_down") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_RIGHT_SHOULDER):
		_select_tab((_tab + 1) % TABS.size())

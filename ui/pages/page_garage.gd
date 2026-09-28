class_name PageGarage
extends MenuPage
## Garage: 3D showroom with the selected bike on a turntable, stats, and paint / suit colors.

var _showroom: Showroom
var _bike_row: OptionRow
var _stats: Array = []
var _desc: Label
var _lock_note: Label
var _tabs: Array = []
var _tab_i := 0
var _swatch_holder: Control
var _swatch: ColorSwatches
var _tab_buttons: Array = []
var _dragging := false


func _ready() -> void:
	var v := make_frame(tr("MENU_GARAGE"), tr("GARAGE_SUB"))
	var row := Widgets.hbox(30)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)

	var panel := Widgets.card(Vector2(760, 0))
	row.add_child(panel)
	var pv := Widgets.vbox(12)
	panel.add_child(pv)
	var opts := []
	var sel := 0
	for i in GameData.BIKE_ORDER.size():
		var id: String = GameData.BIKE_ORDER[i]
		opts.append({"text": tr(GameData.BIKES[id]["name"]), "value": id, "locked": not Save.is_bike_unlocked(id)})
		if id == Save.progress.get("selected_bike", "naked"):
			sel = i
	_bike_row = OptionRow.make(tr("SETUP_BIKE"), opts, sel, "bike")
	_bike_row.changed.connect(func(_i, _v): _on_bike_changed())
	pv.add_child(_bike_row)
	_desc = UITheme.body("", 24, UITheme.MUTED)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(0, 66)
	pv.add_child(_desc)
	_lock_note = UITheme.body("", 24, UITheme.GOLD, 700)
	pv.add_child(_lock_note)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 26)
	pv.add_child(grid)
	for key in ["speed", "accel", "handling", "braking"]:
		var sb := StatBar.make(tr("STAT_" + key.to_upper()), 0)
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(sb)
		_stats.append(sb)
	# Paint tabs.
	var tabs := Widgets.hbox(10)
	pv.add_child(tabs)
	_tabs = [["GARAGE_BODY", "paint"], ["GARAGE_ACCENT", "paint"], ["GARAGE_SUIT", "users"], ["GARAGE_SUIT_ACCENT", "users"]]
	for t in _tabs.size():
		var b := Button.new()
		b.text = tr(_tabs[t][0])
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_font_size_override("font_size", 24)
		b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := t
		b.pressed.connect(func(): _select_tab(idx))
		tabs.add_child(b)
		_tab_buttons.append(b)
	_swatch_holder = Widgets.vbox(0)
	pv.add_child(_swatch_holder)
	var hint := UITheme.body(tr("GARAGE_HINT"), 22, Color(UITheme.TEXT, 0.5))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv.add_child(hint)

	# Showroom viewport.
	var clip: Control = PageRaceSetup._RoundedClip.new()
	clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(clip)
	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.mouse_filter = Control.MOUSE_FILTER_STOP
	cont.gui_input.connect(_on_view_input)
	clip.add_child(cont)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_4X
	cont.add_child(vp)
	_showroom = Showroom.new()
	vp.add_child(_showroom)
	_select_tab(0)
	_on_bike_changed()
	Widgets.link_focus([_bike_row, _tab_buttons[0]])
	_focus_first = _bike_row
	Widgets.animate_in(panel, 0.05)


func _current_bike() -> String:
	return _bike_row.value()


func _paint_for(bike_id: String) -> Dictionary:
	return Save.get_paint(bike_id)


func _colors() -> Dictionary:
	var p := _paint_for(_current_bike())
	var suit: Dictionary = Save.progress.get("suit", {"main": 2, "accent": 0})
	return {
		"paint": GameData.paint_color(p["body"]), "accent": GameData.paint_color(p["accent"]),
		"suit_main": GameData.paint_color(int(suit.get("main", 2))), "suit_accent": GameData.paint_color(int(suit.get("accent", 0))),
		"helmet": Color(0.95, 0.95, 0.95),
	}


func _on_bike_changed() -> void:
	var id := _current_bike()
	var spec: Dictionary = GameData.BIKES[id]
	_desc.text = tr(spec["desc"])
	var keys := ["speed", "accel", "handling", "braking"]
	for i in 4:
		_stats[i].set_value(float(spec["ratings"][keys[i]]))
	var locked := _bike_row.is_locked()
	_lock_note.text = tr("GARAGE_LOCKED_" + id.to_upper()) if locked else ""
	_lock_note.visible = locked
	if not locked:
		Save.progress["selected_bike"] = id
		Save.save_progress()
	_showroom.show_bike(id, _colors())
	_select_tab(_tab_i)


func _select_tab(t: int) -> void:
	_tab_i = t
	for i in _tab_buttons.size():
		_tab_buttons[i].button_pressed = i == t
	if _swatch:
		_swatch.queue_free()
	var p := _paint_for(_current_bike())
	var suit: Dictionary = Save.progress.get("suit", {"main": 2, "accent": 0})
	var current := [p["body"], p["accent"], int(suit.get("main", 2)), int(suit.get("accent", 0))][t] as int
	_swatch = ColorSwatches.make(current)
	_swatch.picked.connect(_on_pick)
	_swatch_holder.add_child(_swatch)
	# Focus chain: tabs -> swatches.
	await get_tree().process_frame
	for b in _tab_buttons:
		b.focus_neighbor_bottom = b.get_path_to(_swatch.swatches()[0])
		b.focus_neighbor_top = b.get_path_to(_bike_row)
	_bike_row.focus_neighbor_bottom = _bike_row.get_path_to(_tab_buttons[0])


func _on_pick(i: int) -> void:
	var id := _current_bike()
	var p := _paint_for(id)
	match _tab_i:
		0:
			Save.set_paint(id, i, p["accent"])
		1:
			Save.set_paint(id, p["body"], i)
		2:
			Save.progress["suit"]["main"] = i
		3:
			Save.progress["suit"]["accent"] = i
	Save.save_progress()
	_showroom.show_bike(id, _colors())


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_showroom.rotate_by(event.relative.x * 0.01)


func _process(delta: float) -> void:
	if not visible:
		return
	if Input.is_action_pressed("p1_look_back") or Input.is_key_pressed(KEY_Q):
		_showroom.rotate_by(-delta * 2.0)
	if Input.is_action_pressed("p1_rear_brake") and not Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_E):
		_showroom.rotate_by(delta * 2.0)


func on_exit() -> void:
	if menu and menu.background:
		menu.background.refresh_hero()

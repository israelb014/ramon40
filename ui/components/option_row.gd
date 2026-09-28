class_name OptionRow
extends PanelContainer
## A focusable "label  < value >" selector that works with mouse, keyboard and gamepad.
## Left/right (or clicking the arrows) steps through `options`; values can be locked.

signal changed(index: int, value)

var label_text := ""
var options: Array = [] ## Array of {"text": String, "value": Variant, "locked": bool}
var index := 0
var wrap := true
var icon_name := ""

var _value_label: Label
var _left: Button
var _right: Button
var _lock_icon: TextureRect
var _normal: StyleBoxFlat
var _focus: StyleBoxFlat


static func make(p_label: String, p_options: Array, p_index := 0, p_icon := "") -> OptionRow:
	var r := OptionRow.new()
	r.label_text = p_label
	r.options = p_options
	r.index = clampi(p_index, 0, maxi(p_options.size() - 1, 0))
	r.icon_name = p_icon
	return r


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_normal = UITheme.pill_style(Color(1, 1, 1, 0.045), UITheme.RADIUS_SMALL)
	_normal.content_margin_top = 8
	_normal.content_margin_bottom = 8
	_focus = UITheme.pill_style(Color(1, 0.54, 0.24, 0.16), UITheme.RADIUS_SMALL)
	_focus.border_color = UITheme.ACCENT
	_focus.set_border_width_all(2)
	_focus.content_margin_top = 8
	_focus.content_margin_bottom = 8
	add_theme_stylebox_override("panel", _normal)
	custom_minimum_size = Vector2(0, 78)
	var h := Widgets.hbox(12)
	add_child(h)
	if icon_name != "":
		h.add_child(Widgets.icon_rect(icon_name, 34, UITheme.MUTED))
	var l := UITheme.body(label_text, 30, UITheme.TEXT, 600)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	# First arrow = previous, second = next. Chevrons point outward on screen.
	_left = _arrow(1.0 if _rtl() else -1.0)
	_left.pressed.connect(func(): step(-1))
	h.add_child(_left)
	var mid := Widgets.hbox(8)
	mid.custom_minimum_size = Vector2(300, 0)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(mid)
	_lock_icon = Widgets.icon_rect("lock", 28, UITheme.MUTED)
	mid.add_child(_lock_icon)
	_value_label = UITheme.body("", 30, UITheme.TEXT, 700)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mid.add_child(_value_label)
	_right = _arrow(-1.0 if _rtl() else 1.0)
	_right.pressed.connect(func(): step(1))
	h.add_child(_right)
	focus_entered.connect(func():
		add_theme_stylebox_override("panel", _focus)
		Audio.play_ui("move"))
	focus_exited.connect(func(): add_theme_stylebox_override("panel", _normal))
	mouse_entered.connect(grab_focus)
	_refresh()


func _rtl() -> bool:
	return is_layout_rtl()


func _arrow(screen_dir: float) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(56, 56)
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", UITheme.pill_style(Color(1, 1, 1, 0.08), 28))
	b.add_theme_stylebox_override("pressed", UITheme.pill_style(Color(1, 0.54, 0.24, 0.3), 28))
	var c := Chevron.new()
	c.direction = screen_dir
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(c)
	return b


func step(dir: int) -> void:
	if options.is_empty():
		return
	var n := options.size()
	var ni := index + dir
	if wrap:
		ni = (ni + n) % n
	else:
		ni = clampi(ni, 0, n - 1)
	if ni == index:
		return
	index = ni
	Audio.play_ui("tick")
	_refresh()
	_pulse()
	changed.emit(index, value())


func set_index(i: int, emit := false) -> void:
	index = clampi(i, 0, maxi(options.size() - 1, 0))
	_refresh()
	if emit:
		changed.emit(index, value())


func value():
	if options.is_empty():
		return null
	return options[index].get("value")


func is_locked() -> bool:
	return not options.is_empty() and options[index].get("locked", false)


func _refresh() -> void:
	if _value_label == null:
		return
	if options.is_empty():
		_value_label.text = "-"
		_lock_icon.visible = false
		return
	var o: Dictionary = options[index]
	_value_label.text = String(o.get("text", str(o.get("value"))))
	var locked: bool = o.get("locked", false)
	_lock_icon.visible = locked
	_value_label.add_theme_color_override("font_color", UITheme.MUTED if locked else UITheme.TEXT)


func _pulse() -> void:
	_value_label.pivot_offset = _value_label.size * 0.5
	var tw := create_tween()
	_value_label.scale = Vector2(1.12, 1.12)
	tw.tween_property(_value_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		step(-1 if not _rtl() else 1)
		accept_event()
	elif event.is_action_pressed("ui_right"):
		step(1 if not _rtl() else -1)
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		step(1)
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()

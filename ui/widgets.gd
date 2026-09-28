class_name Widgets
extends RefCounted
## Small factory helpers for consistent UI controls.

static var _icons: Dictionary = {}


static func icon(name: String) -> Texture2D:
	if not _icons.has(name):
		var path := "res://ui/icons/%s.svg" % name
		_icons[name] = load(path) if ResourceLoader.exists(path) else null
	return _icons[name]


static func button(text: String, icon_name := "", primary := false, font_size := 32) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, 76)
	b.add_theme_font_size_override("font_size", font_size)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_constant_override("h_separation", 18)
	b.add_theme_constant_override("icon_max_width", 36)
	if icon_name != "":
		b.icon = icon(icon_name)
	if primary:
		var sb := UITheme.pill_style(UITheme.ACCENT)
		b.add_theme_stylebox_override("normal", sb)
		var hov := UITheme.pill_style(UITheme.ACCENT.lightened(0.12))
		hov.border_color = Color.WHITE
		hov.set_border_width_all(2)
		b.add_theme_stylebox_override("hover", hov)
		b.add_theme_stylebox_override("focus", hov)
		b.add_theme_color_override("font_color", UITheme.BG)
		b.add_theme_color_override("font_hover_color", UITheme.BG)
		b.add_theme_color_override("font_focus_color", UITheme.BG)
		b.add_theme_color_override("icon_normal_color", UITheme.BG)
		b.add_theme_color_override("icon_hover_color", UITheme.BG)
		b.add_theme_color_override("icon_focus_color", UITheme.BG)
	b.pressed.connect(func(): Audio.play_ui("click"))
	b.focus_entered.connect(func(): Audio.play_ui("move"))
	b.mouse_entered.connect(func(): b.grab_focus())
	return b


static func card(min_size := Vector2.ZERO, color := UITheme.CARD) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.card_style(color))
	p.custom_minimum_size = min_size
	return p


static func vbox(sep := 14) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 14) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func icon_rect(name: String, size := 40.0, color := UITheme.TEXT) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon(name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.modulate = color
	return t


## Chains focus neighbours vertically and focuses the first control.
static func link_focus(controls: Array) -> void:
	for i in controls.size():
		var c: Control = controls[i]
		c.focus_neighbor_top = c.get_path_to(controls[(i - 1 + controls.size()) % controls.size()])
		c.focus_neighbor_bottom = c.get_path_to(controls[(i + 1) % controls.size()])


## Applies the right-to-left layout for Hebrew to a root control.
static func apply_direction(root: Control) -> void:
	root.layout_direction = Control.LAYOUT_DIRECTION_RTL if Settings.is_rtl() else Control.LAYOUT_DIRECTION_LTR


## Fades and scales a control in (works inside containers).
static func animate_in(c: Control, delay := 0.0) -> void:
	c.modulate.a = 0.0
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(0.96, 0.96)
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, 0.3).set_delay(delay)
	tw.tween_property(c, "scale", Vector2.ONE, 0.4).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

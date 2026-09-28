class_name UITheme
extends RefCounted
## Visual language for all UI: sunset palette, Karantina headings, Assistant body text,
## card panels with a consistent corner radius, and a Godot Theme built from these.

const RADIUS := 22
const RADIUS_SMALL := 14

const BG := Color("140c16")
const CARD := Color(0.10, 0.065, 0.11, 0.82)
const CARD_HI := Color(0.16, 0.10, 0.17, 0.92)
const LINE := Color(1.0, 1.0, 1.0, 0.08)
const TEXT := Color("f7efe6")
const MUTED := Color("b9a9b5")
const ACCENT := Color("ff8a3d")
const ACCENT2 := Color("e8457c")
const GOLD := Color("f5c542")
const GOOD := Color("59d48c")
const BAD := Color("ff5a5a")

static var _fonts: Dictionary = {}
static var _theme: Theme


static func heading_font() -> Font:
	if not _fonts.has("heading"):
		var f := FontFile.new()
		f.load_dynamic_font("res://assets/fonts/Karantina-Bold.ttf")
		var fb := FontFile.new()
		fb.load_dynamic_font("res://assets/fonts/Assistant.ttf")
		f.fallbacks = [fb]
		_fonts["heading"] = f
	return _fonts["heading"]


static func heading_light_font() -> Font:
	if not _fonts.has("heading_light"):
		var f := FontFile.new()
		f.load_dynamic_font("res://assets/fonts/Karantina-Regular.ttf")
		f.fallbacks = [body_font()]
		_fonts["heading_light"] = f
	return _fonts["heading_light"]


static func _assistant() -> FontFile:
	if not _fonts.has("assistant_file"):
		var f := FontFile.new()
		f.load_dynamic_font("res://assets/fonts/Assistant.ttf")
		_fonts["assistant_file"] = f
	return _fonts["assistant_file"]


static func body_font(weight := 500) -> Font:
	var key := "body_%d" % weight
	if not _fonts.has(key):
		var fv := FontVariation.new()
		fv.base_font = _assistant()
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[key] = fv
	return _fonts[key]


static func card_style(color := CARD, radius := RADIUS, border := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.corner_detail = 10
	s.anti_aliasing = true
	if border:
		s.border_color = LINE
		s.set_border_width_all(1)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 18
	s.content_margin_bottom = 18
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 18
	s.shadow_offset = Vector2(0, 6)
	return s


static func pill_style(color: Color, radius := RADIUS_SMALL) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.corner_detail = 8
	s.anti_aliasing = true
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = body_font(500)
	t.default_font_size = 30
	# Labels
	t.set_color("font_color", "Label", TEXT)
	# Buttons
	var normal := pill_style(Color(1, 1, 1, 0.06))
	var hover := pill_style(Color(1, 0.54, 0.24, 0.22))
	hover.border_color = ACCENT
	hover.set_border_width_all(2)
	var pressed := pill_style(Color(1, 0.54, 0.24, 0.4))
	var focus := pill_style(Color(1, 0.54, 0.24, 0.22))
	focus.border_color = ACCENT
	focus.set_border_width_all(2)
	var disabled := pill_style(Color(1, 1, 1, 0.03))
	for cls in ["Button", "OptionButton", "CheckButton"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("focus", cls, focus)
		t.set_stylebox("disabled", cls, disabled)
		t.set_stylebox("hover_pressed", cls, pressed)
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_focus_color", cls, Color.WHITE)
		t.set_color("font_pressed_color", cls, Color.WHITE)
		t.set_color("font_disabled_color", cls, Color(1, 1, 1, 0.3))
		t.set_font("font", cls, body_font(700))
		t.set_font_size("font_size", cls, 30)
	# Panels
	t.set_stylebox("panel", "PanelContainer", card_style())
	t.set_stylebox("panel", "Panel", card_style())
	# Sliders
	var track_sb := pill_style(Color(1, 1, 1, 0.1), 6)
	track_sb.content_margin_top = 4
	track_sb.content_margin_bottom = 4
	var fill := pill_style(ACCENT, 6)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track_sb)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _circle_icon(26, TEXT))
	t.set_icon("grabber_highlight", "HSlider", _circle_icon(30, Color.WHITE))
	# Popup menus (OptionButton lists)
	var pm := card_style(CARD_HI, RADIUS_SMALL)
	t.set_stylebox("panel", "PopupMenu", pm)
	t.set_font("font", "PopupMenu", body_font(600))
	t.set_font_size("font_size", "PopupMenu", 28)
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_stylebox("hover", "PopupMenu", pill_style(Color(1, 0.54, 0.24, 0.3), 10))
	# Line edit
	var le := pill_style(Color(1, 1, 1, 0.07))
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_font_size("font_size", "LineEdit", 30)
	# Scroll bars (thin)
	var sb := pill_style(Color(1, 1, 1, 0.12), 6)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	t.set_stylebox("grabber", "VScrollBar", sb)
	t.set_stylebox("grabber_highlight", "VScrollBar", pill_style(ACCENT, 6))
	t.set_stylebox("grabber_pressed", "VScrollBar", pill_style(ACCENT, 6))
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	_theme = t
	return t


static func _circle_icon(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(color, a))
	return ImageTexture.create_from_image(img)


static func heading(text: String, size := 96, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", heading_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func body(text: String, size := 30, color := TEXT, weight := 500) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", body_font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

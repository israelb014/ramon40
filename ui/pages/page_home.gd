class_name PageHome
extends MenuPage
## Title page: logo and the main mode list.

var _buttons: Array = []


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 100)
	margin.add_theme_constant_override("margin_right", 100)
	margin.add_theme_constant_override("margin_top", 50)
	margin.add_theme_constant_override("margin_bottom", 80)
	add_child(margin)
	var row := Widgets.hbox(0)
	margin.add_child(row)
	var col := Widgets.vbox(10)
	col.custom_minimum_size = Vector2(640, 0)
	row.add_child(col)
	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(filler)

	# Logo block.
	var logo := _Logo.new()
	logo.custom_minimum_size = Vector2(640, 236)
	col.add_child(logo)
	var sub := UITheme.body(tr("MENU_TAGLINE"), 30, UITheme.MUTED, 600)
	col.add_child(sub)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 14)
	col.add_child(sp)

	var entries := [
		["MENU_QUICK_RACE", "play", func(): menu.open_page(PageRaceSetup.create("quick")), true],
		["MENU_CHAMPIONSHIP", "trophy", func(): menu.open_page(PageChampionship.new()), false],
		["MENU_TIME_TRIAL", "stopwatch", func(): menu.open_page(PageRaceSetup.create("time_trial")), false],
		["MENU_SPLIT", "split", func(): menu.open_page(PageRaceSetup.create("split")), false],
		["MENU_ONLINE", "globe", func(): menu.open_page(PageOnline.new()), false],
		["MENU_GARAGE", "garage", func(): menu.open_page(PageGarage.new()), false],
		["MENU_SETTINGS", "settings", func(): menu.open_page(PageSettings.new()), false],
		["MENU_QUIT", "power", func(): Game.quit_game(), false],
	]
	var i := 0
	for e in entries:
		var b := Widgets.button(tr(e[0]), e[1], e[3], 34)
		b.custom_minimum_size = Vector2(560, 68)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.pressed.connect(e[2])
		col.add_child(b)
		_buttons.append(b)
		Widgets.animate_in(b, 0.08 + i * 0.04)
		i += 1
	Widgets.link_focus(_buttons)
	_focus_first = _buttons[0]
	# Version and credits corner.
	var ver := Button.new()
	ver.text = "v%s  ·  %s" % [ProjectSettings.get_setting("application/config/version", "1.0.0"), tr("MENU_CREDITS")]
	ver.flat = true
	ver.focus_mode = Control.FOCUS_NONE
	ver.add_theme_font_size_override("font_size", 22)
	ver.add_theme_color_override("font_color", Color(UITheme.TEXT, 0.5))
	# Anchors mirror in RTL, so bottom-right means "reading end" corner in both directions.
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 40)
	ver.pressed.connect(func(): menu.open_page(PageCredits.new()))
	add_child(ver)


class _Logo extends Control:
	var _t := 0.0

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var rtl := is_layout_rtl()
		var hf := UITheme.heading_font()
		var title := tr("GAME_TITLE")
		var fs := 220
		var w := hf.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x := size.x - w if rtl else 0.0
		# Warm glow behind the title.
		draw_string(hf, Vector2(x + 5, 196), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.9, 0.2, 0.3, 0.35))
		draw_string(hf, Vector2(x, 190), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.TEXT)
		# Road-line underline: yellow edge line with a white dashed center.
		var y := 222.0
		var lx := x
		draw_rect(Rect2(lx, y, w, 7), UITheme.GOLD)
		var dash := 34.0
		var off := fmod(_t * 60.0, dash * 2.0)
		var k := -1
		while true:
			k += 1
			var dx := k * dash * 2.0 - off
			if dx > w:
				break
			var a := clampf(dx, 0.0, w)
			var b := clampf(dx + dash, 0.0, w)
			if b > a:
				draw_rect(Rect2(lx + (w - b if rtl else a), y + 16, b - a, 5), Color(1, 1, 1, 0.8))

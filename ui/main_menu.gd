class_name MainMenu
extends Control
## Main menu shell: live 3D background, header, animated page stack with back navigation.

var background: MenuBackground
var pages_root: Control
var _stack: Array = []
var _art: TrackArt
var _header: Control
var _hint: Label


func _ready() -> void:
	theme = UITheme.theme()
	Widgets.apply_direction(self)
	# 3D background behind everything.
	var bg_root := Node3D.new()
	add_child(bg_root)
	background = MenuBackground.new()
	bg_root.add_child(background)
	# Until the 3D scene is ready, show the illustrated backdrop.
	_art = TrackArt.new()
	_art.track_id = "ramon"
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_art)
	background.ready_to_show.connect(_on_bg_ready)
	# Gradient scrim on the reading side for legibility.
	var scrim := _Scrim.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	pages_root = Control.new()
	pages_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(pages_root)
	_hint = UITheme.body("", 22, Color(UITheme.TEXT, 0.55))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -56
	_hint.offset_bottom = -24
	_hint.offset_left = 80
	_hint.offset_right = -80
	add_child(_hint)
	_update_hint()
	Audio.play_menu_music()
	var start_page := Game.menu_return_page
	Game.menu_return_page = ""
	open_page(PageHome.new(), false)
	match start_page:
		"quick":
			open_page(PageRaceSetup.create("quick"))
		"time_trial":
			open_page(PageRaceSetup.create("time_trial"))
		"split":
			open_page(PageRaceSetup.create("split"))
		"championship", "championship_standings":
			open_page(PageChampionship.new())
		"online":
			open_page(PageOnline.new())
		"settings":
			open_page(PageSettings.new())
		"garage":
			open_page(PageGarage.new())


func _on_bg_ready() -> void:
	var tw := create_tween()
	tw.tween_property(_art, "modulate:a", 0.0, 1.2)
	tw.tween_callback(func(): _art.visible = false)


func _update_hint() -> void:
	_hint.text = tr("MENU_HINT")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func current_page() -> MenuPage:
	return _stack.back() if not _stack.is_empty() else null


func open_page(page: MenuPage, animate := true) -> void:
	var prev := current_page()
	page.menu = self
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pages_root.add_child(page)
	_stack.append(page)
	if prev:
		_transition_out(prev, false)
	if animate:
		_transition_in(page, true)
	page.on_enter()


func back() -> void:
	if _stack.size() <= 1:
		return
	var page: MenuPage = _stack.pop_back()
	page.on_exit()
	Audio.play_ui("back")
	_transition_out(page, true)
	var prev := current_page()
	prev.visible = true
	_transition_in(prev, false)
	prev.on_enter()


func replace_page(page: MenuPage) -> void:
	var old: MenuPage = _stack.pop_back()
	old.queue_free()
	open_page(page)


func _transition_in(page: Control, forward: bool) -> void:
	var dir := (1.0 if forward else -1.0) * (-1.0 if Settings.is_rtl() else 1.0)
	page.modulate.a = 0.0
	page.position.x = 60.0 * dir
	var tw := page.create_tween().set_parallel(true)
	tw.tween_property(page, "modulate:a", 1.0, 0.28)
	tw.tween_property(page, "position:x", 0.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _transition_out(page: Control, destroy: bool) -> void:
	var dir := (-1.0 if not destroy else 1.0) * (-1.0 if Settings.is_rtl() else 1.0)
	var tw := page.create_tween().set_parallel(true)
	tw.tween_property(page, "modulate:a", 0.0, 0.2)
	tw.tween_property(page, "position:x", 40.0 * dir, 0.2)
	tw.chain().tween_callback(func():
		if destroy:
			page.queue_free()
		else:
			page.visible = false)


func refresh_language() -> void:
	## Rebuilds the whole menu after a language change.
	Widgets.apply_direction(self)
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_back"):
		var p := current_page()
		if p and p.handle_back():
			get_viewport().set_input_as_handled()
			return
		if _stack.size() > 1:
			back()
			get_viewport().set_input_as_handled()


class _Scrim extends Control:
	## Smooth gradient scrims (reading side + bottom) built from gradient textures.
	func _ready() -> void:
		var rtl := Settings.is_rtl()
		var side := TextureRect.new()
		var g := Gradient.new()
		g.set_color(0, Color(0.05, 0.03, 0.06, 0.8))
		g.set_color(1, Color(0.05, 0.03, 0.06, 0.0))
		g.add_point(0.45, Color(0.05, 0.03, 0.06, 0.55))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.width = 256
		gt.height = 4
		gt.fill_from = Vector2(1, 0) if rtl else Vector2(0, 0)
		gt.fill_to = Vector2(0, 0) if rtl else Vector2(1, 0)
		side.texture = gt
		side.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		side.stretch_mode = TextureRect.STRETCH_SCALE
		side.mouse_filter = Control.MOUSE_FILTER_IGNORE
		side.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(side)
		var bottom := TextureRect.new()
		var g2 := Gradient.new()
		g2.set_color(0, Color(0.05, 0.03, 0.06, 0.0))
		g2.set_color(1, Color(0.05, 0.03, 0.06, 0.6))
		var gt2 := GradientTexture2D.new()
		gt2.gradient = g2
		gt2.width = 4
		gt2.height = 128
		gt2.fill_from = Vector2(0, 0)
		gt2.fill_to = Vector2(0, 1)
		bottom.texture = gt2
		bottom.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bottom.stretch_mode = TextureRect.STRETCH_SCALE
		bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		bottom.offset_top = -220
		add_child(bottom)

class_name ColorSwatches
extends GridContainer
## Grid of paint swatches (vector-drawn circles). Locked colors show a lock and can't be picked.

signal picked(index: int)

var selected := 0
var _items: Array = []


static func make(p_selected: int) -> ColorSwatches:
	var c := ColorSwatches.new()
	c.selected = p_selected
	c.columns = 6
	c.add_theme_constant_override("h_separation", 12)
	c.add_theme_constant_override("v_separation", 12)
	return c


func _ready() -> void:
	for i in GameData.PAINTS.size():
		var s := _Swatch.new()
		s.index = i
		s.color = GameData.paint_color(i)
		s.locked = not Save.is_color_unlocked(i)
		s.tooltip_text = tr(GameData.PAINTS[i]["name"])
		s.owner_grid = self
		add_child(s)
		_items.append(s)
	_update()


func swatches() -> Array:
	return _items


func select(i: int) -> void:
	if _items[i].locked:
		Audio.play_ui("error")
		return
	selected = i
	_update()
	Audio.play_ui("tick")
	picked.emit(i)


func _update() -> void:
	for s in _items:
		s.is_selected = s.index == selected
		s.queue_redraw()


class _Swatch extends Control:
	var index := 0
	var color := Color.WHITE
	var locked := false
	var is_selected := false
	var owner_grid: ColorSwatches
	var _hover := false

	func _ready() -> void:
		custom_minimum_size = Vector2(64, 64)
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_entered.connect(func():
			_hover = true
			queue_redraw()
			Audio.play_ui("move"))
		focus_exited.connect(func():
			_hover = false
			queue_redraw())
		mouse_entered.connect(grab_focus)

	func _gui_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			owner_grid.select(index)
			accept_event()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 6.0
		if is_selected:
			draw_arc(c, r + 4.0, 0, TAU, 48, UITheme.TEXT, 3.0, true)
		elif _hover:
			draw_arc(c, r + 4.0, 0, TAU, 48, UITheme.ACCENT, 3.0, true)
		draw_circle(c, r, color if not locked else color.darkened(0.6))
		# Glossy highlight.
		draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.28, Color(1, 1, 1, 0.18))
		if locked:
			var icon := Widgets.icon("lock")
			var s := r * 1.0
			draw_texture_rect(icon, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, 0.8))
		elif is_selected:
			var icon2 := Widgets.icon("check")
			var s2 := r * 0.9
			var ink := Color.BLACK if color.get_luminance() > 0.6 else Color.WHITE
			draw_texture_rect(icon2, Rect2(c - Vector2(s2, s2) * 0.5, Vector2(s2, s2)), false, ink)

class_name MenuPage
extends Control
## Base class for main-menu pages.

var menu: MainMenu
var _focus_first: Control


func on_enter() -> void:
	if _focus_first and is_instance_valid(_focus_first):
		_focus_first.call_deferred("grab_focus")


## Called when the page is popped off the stack.
func on_exit() -> void:
	pass


## Return true when the page consumed the back action itself.
func handle_back() -> bool:
	return false


## Standard page frame: margins, a title row with a back button, and a content box.
func make_frame(title: String, subtitle := "", with_back := true) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_right", 90)
	margin.add_theme_constant_override("margin_top", 64)
	margin.add_theme_constant_override("margin_bottom", 90)
	add_child(margin)
	var v := Widgets.vbox(18)
	margin.add_child(v)
	var head := Widgets.hbox(22)
	v.add_child(head)
	if with_back:
		var b := Button.new()
		b.icon = Widgets.icon("arrow_right" if Settings.is_rtl() else "arrow_left")
		b.custom_minimum_size = Vector2(72, 72)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 34)
		b.add_theme_stylebox_override("normal", UITheme.pill_style(Color(1, 1, 1, 0.06), 36))
		b.add_theme_stylebox_override("hover", UITheme.pill_style(Color(1, 0.54, 0.24, 0.3), 36))
		b.add_theme_stylebox_override("focus", UITheme.pill_style(Color(1, 0.54, 0.24, 0.3), 36))
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): menu.back())
		head.add_child(b)
	var tv := Widgets.vbox(0)
	head.add_child(tv)
	tv.add_child(UITheme.heading(title, 110))
	if subtitle != "":
		tv.add_child(UITheme.body(subtitle, 28, UITheme.MUTED))
	return v

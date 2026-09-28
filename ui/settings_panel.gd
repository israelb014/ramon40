class_name SettingsPanel
extends Control
## Settings screen (full version built in the menus milestone).

signal closed

var in_race := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var b := Widgets.button(tr("BACK"), "arrow_left")
	b.pressed.connect(func(): closed.emit())
	add_child(b)
	b.grab_focus()

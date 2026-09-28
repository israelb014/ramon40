class_name PageOnline
extends MenuPage
## LAN / online multiplayer lobby (host or join by IP).


func _ready() -> void:
	var v := make_frame(tr("MENU_ONLINE"), tr("ONLINE_SUB"))
	var b := Widgets.button(tr("BACK"), "arrow_left", true)
	b.pressed.connect(func(): menu.back())
	v.add_child(b)
	_focus_first = b

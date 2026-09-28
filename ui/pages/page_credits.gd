class_name PageCredits
extends MenuPage
## Credits and licenses.


func _ready() -> void:
	var v := make_frame(tr("MENU_CREDITS"), tr("CREDITS_SUB"))
	var card := Widgets.card(Vector2(1100, 0))
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(card)
	var cv := Widgets.vbox(14)
	card.add_child(cv)
	for key in ["CREDITS_1", "CREDITS_2", "CREDITS_3", "CREDITS_4", "CREDITS_5"]:
		var l := UITheme.body(tr(key), 28, UITheme.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(l)
	var ok := Widgets.button(tr("BACK"), "arrow_right" if Settings.is_rtl() else "arrow_left", true)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ok.custom_minimum_size = Vector2(260, 76)
	ok.pressed.connect(func(): menu.back())
	cv.add_child(ok)
	_focus_first = ok

extends Control
## Temporary entry menu (replaced by the full menu system).


func _ready() -> void:
	theme = UITheme.theme()
	var v := Widgets.vbox(20)
	v.position = Vector2(120, 200)
	add_child(v)
	v.add_child(UITheme.heading(tr("GAME_TITLE"), 160))
	var b := Widgets.button("Quick race", "play", true)
	b.pressed.connect(func(): Game.start_race(Game.default_config()))
	v.add_child(b)
	b.grab_focus()

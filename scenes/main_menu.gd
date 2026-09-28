extends Control


func _ready() -> void:
	var l := Label.new()
	l.text = tr("GAME_TITLE")
	add_child(l)

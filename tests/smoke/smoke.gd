extends Node
## Headless smoke run used by CI: loads the main menu, then prints SMOKE OK.

var _frames := 0


func _ready() -> void:
	var menu: Node = load(Game.MAIN_MENU).instantiate()
	add_child(menu)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 30:
		print("SMOKE OK")
		get_tree().quit(0)

extends Node
## First scene: waits one frame for autoloads, then enters the main menu.


func _ready() -> void:
	await get_tree().process_frame
	get_tree().change_scene_to_file.call_deferred(Game.MAIN_MENU)

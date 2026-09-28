extends Node
func _ready() -> void:
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	get_tree().change_scene_to_file.call_deferred(Game.MAIN_MENU)
	for i in 3000:
		await get_tree().process_frame
		if Audio.ready_all and i > 200:
			break
	print("audio ready ", Audio.ready_all)
	Game.quit_game()

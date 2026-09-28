extends Node
## Central audio service. Synthesizes and caches all sounds (filled in by the audio milestone).


func play_ui(_id: String) -> void:
	pass


func race_started(_race: Node) -> void:
	pass


func update_race(_race: Node, _delta: float) -> void:
	pass


func set_race_paused(_p: bool) -> void:
	pass


func play_countdown() -> void:
	pass


func play_go() -> void:
	pass


func play_finish() -> void:
	pass


func play_crash(_pos: Vector3) -> void:
	pass


func play_impact(_pos: Vector3, _strength: float) -> void:
	pass


func replay_started() -> void:
	pass


func replay_finished() -> void:
	pass


func update_replay(_race: Node, _focus: int, _delta: float) -> void:
	pass


func menu_music_fade_out() -> void:
	pass

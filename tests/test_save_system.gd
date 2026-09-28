extends GutTest
## Save/load of progress, best times and ghosts in an isolated folder.

var _save: Node
var _dir := ""


func before_each():
	_dir = "user://test_save_%d" % randi()
	_save = load("res://scripts/core/save_system.gd").new()
	_save.base_dir = _dir
	_save.progress = _save.default_progress()


func after_each():
	_save.free()
	var d := DirAccess.open(_dir)
	if d:
		for sub in ["ghosts"]:
			var g := DirAccess.open(_dir.path_join(sub))
			if g:
				for f in g.get_files():
					g.remove(f)
				d.remove(sub)
		for f in d.get_files():
			d.remove(f)
		DirAccess.remove_absolute(_dir)


func _reload() -> Node:
	var s: Node = load("res://scripts/core/save_system.gd").new()
	s.base_dir = _dir
	s.load_progress()
	return s


func test_defaults():
	assert_true(_save.is_bike_unlocked("naked"))
	assert_true(_save.is_bike_unlocked("supermoto"))
	assert_false(_save.is_bike_unlocked("sport"))
	assert_true(_save.is_color_unlocked(0))
	assert_false(_save.is_color_unlocked(11))


func test_roundtrip_progress():
	_save.unlock_bike("sport")
	_save.set_paint("sport", 3, 7)
	_save.progress["player_name"] = "רוכב בדיקה"
	_save.progress["suit"] = {"main": 4, "accent": 2}
	assert_true(_save.save_progress())
	var s2 := _reload()
	assert_true(s2.is_bike_unlocked("sport"))
	assert_eq(s2.get_paint("sport"), {"body": 3, "accent": 7})
	assert_eq(s2.get_paint("naked"), {"body": 5, "accent": 10}, "default paint")
	assert_eq(s2.progress["player_name"], "רוכב בדיקה")
	assert_eq(int(s2.progress["suit"]["main"]), 4)
	assert_typeof(s2.progress["unlocked_colors"][0], TYPE_INT)
	s2.free()


func test_best_lap_only_improves():
	assert_true(_save.submit_lap("ramon", 130.5, "naked"))
	assert_false(_save.submit_lap("ramon", 140.0, "sport"))
	assert_true(_save.submit_lap("ramon", 128.25, "sport"))
	assert_almost_eq(_save.best_lap("ramon"), 128.25, 0.0001)
	_save.save_progress()
	var s2 := _reload()
	assert_almost_eq(s2.best_lap("ramon"), 128.25, 0.0001)
	s2.free()


func test_ghost_roundtrip():
	var ghost := {"time": 99.5, "bike": "cafe", "samples": {"t": PackedFloat32Array([0.0, 0.5]), "d": PackedFloat32Array([1, 2, 3])}}
	assert_true(_save.save_ghost("deadsea", ghost))
	var g: Dictionary = _save.load_ghost("deadsea")
	assert_almost_eq(float(g["time"]), 99.5, 0.001)
	assert_eq(g["bike"], "cafe")
	assert_eq((g["samples"]["t"] as PackedFloat32Array).size(), 2)
	assert_eq(_save.load_ghost("jerusalem"), {})


func test_corrupt_file_falls_back_to_defaults():
	DirAccess.make_dir_recursive_absolute(_dir)
	var f := FileAccess.open(_dir.path_join("save.json"), FileAccess.WRITE)
	f.store_string("{not valid json")
	f.close()
	var s2 := _reload()
	assert_true(s2.is_bike_unlocked("naked"))
	assert_eq(s2.best_lap("ramon"), 0.0)
	s2.free()


func test_unlock_next_color_sequence():
	var c: int = _save.unlock_next_color()
	assert_eq(c, 6)
	assert_true(_save.is_color_unlocked(6))

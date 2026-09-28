extends GutTest
## Championship points, standings, tie-breaks and rewards.

var _save: Node


func before_each():
	_save = load("res://scripts/core/save_system.gd").new()
	_save.base_dir = "user://test_champ_%d" % randi()
	_save.progress = _save.default_progress()


func after_each():
	_save.free()


func _results(order: Array) -> Array:
	var out := []
	for i in order.size():
		out.append({"index": order[i], "position": i + 1})
	return out


func test_create_has_eight_riders_and_three_rounds():
	var st := Championship.create("naked", "medium", "Tester", 42)
	assert_eq(st["riders"].size(), 8)
	assert_true(st["riders"][0]["player"])
	assert_eq(Championship.current_track(st), "ramon")


func test_points_awarded_per_position():
	var st := Championship.create("naked", "medium", "Tester", 1)
	Championship.apply_results(st, _results([3, 0, 1, 2, 4, 5, 6, 7]))
	assert_eq(int(st["riders"][3]["points"]), 25)
	assert_eq(int(st["riders"][0]["points"]), 18)
	assert_eq(int(st["riders"][7]["points"]), 4)
	assert_eq(int(st["round"]), 1)
	assert_eq(Championship.current_track(st), "deadsea")


func test_championship_completes_after_three_rounds():
	var st := Championship.create("naked", "hard", "Tester", 1)
	for r in 3:
		Championship.apply_results(st, _results([0, 1, 2, 3, 4, 5, 6, 7]))
	assert_true(st["complete"])
	assert_false(st["active"])
	assert_eq(int(st["riders"][0]["points"]), 75)
	assert_eq(Championship.player_rank(st), 1)


func test_standings_tiebreak_by_wins():
	var st := Championship.create("naked", "medium", "Tester", 1)
	# Rider 1: 1st then 3rd = 40; rider 2: 2nd then 2nd = 36 -> make equal points case
	st["riders"][1]["points"] = 40
	st["riders"][1]["results"] = [1, 3]
	st["riders"][2]["points"] = 40
	st["riders"][2]["results"] = [2, 2]
	var order := Championship.standings(st)
	assert_lt(order.find(1), order.find(2), "more wins ranks higher on equal points")


func test_race_config_uses_same_ai_roster():
	var st := Championship.create("supermoto", "easy", "Tester", 7)
	var cfg := Championship.race_config(st)
	assert_eq(cfg["mode"], "championship")
	assert_eq(cfg["ai_names"].size(), 7)
	assert_eq(cfg["ai_bikes"].size(), 7)
	assert_eq(cfg["players"][0]["bike"], "supermoto")


func test_rewards_unlock_bikes_and_colors():
	var st := Championship.create("naked", "medium", "Tester", 1)
	for r in 3:
		Championship.apply_results(st, _results([0, 1, 2, 3, 4, 5, 6, 7]))
	var gained := Championship.grant_rewards(st, 1, _save)
	assert_true(_save.is_bike_unlocked("sport"))
	assert_true(_save.is_bike_unlocked("cafe"))
	assert_true(_save.is_color_unlocked(11))
	assert_gt(gained.size(), 2)


func test_podium_unlocks_one_color_midseason():
	var st := Championship.create("naked", "medium", "Tester", 1)
	Championship.apply_results(st, _results([1, 0, 2, 3, 4, 5, 6, 7]))
	var before: int = _save.progress["unlocked_colors"].size()
	Championship.grant_rewards(st, 2, _save)
	assert_eq(_save.progress["unlocked_colors"].size(), before + 1)
	assert_false(_save.is_bike_unlocked("sport"), "bikes only after completing")

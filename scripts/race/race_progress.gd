class_name RaceProgress
extends RefCounted
## Lap counting, timing and race positions. Independent of nodes so it can be tested.
##
## Each rider has a continuous race distance: lap distance unwrapped across the start line.
## The starting grid sits behind the line (negative race distance), crossing the line the
## first time starts lap 1 and each further multiple of the track length completes a lap.

var track_length := 1000.0
var total_laps := 3
var riders: Dictionary = {} # id -> entry
var finish_order: Array = []
var race_time := 0.0


func _init(p_length := 1000.0, p_laps := 3) -> void:
	track_length = p_length
	total_laps = p_laps


func add_rider(id: int, lap_dist: float) -> void:
	var rd := lap_dist
	if rd > track_length * 0.5:
		rd -= track_length # behind the start line
	riders[id] = {
		"id": id, "race_dist": rd, "max_dist": rd, "last_lap_dist": lap_dist,
		"laps_done": 0, "lap_start": 0.0, "lap_times": [], "best_lap": 0.0,
		"finished": false, "finish_time": 0.0, "wrong_way": 0.0, "last_lap_time": 0.0,
	}


## Advances timing. Call once per tick before updating riders.
func tick(dt: float) -> void:
	race_time += dt


## Updates a rider with its current lap distance. Returns "lap" when a lap was completed,
## "finish" when the race was completed, or "" otherwise.
func update_rider(id: int, lap_dist: float, heading_dot := 1.0, speed := 0.0, dt := 0.0) -> String:
	var e: Dictionary = riders[id]
	if e["finished"]:
		return ""
	var delta := lap_dist - float(e["last_lap_dist"])
	if delta > track_length * 0.5:
		delta -= track_length
	elif delta < -track_length * 0.5:
		delta += track_length
	e["last_lap_dist"] = lap_dist
	e["race_dist"] = float(e["race_dist"]) + delta
	e["max_dist"] = maxf(e["max_dist"], e["race_dist"])
	# Wrong way detection.
	if heading_dot < -0.3 and speed > 3.0:
		e["wrong_way"] = float(e["wrong_way"]) + dt
	else:
		e["wrong_way"] = maxf(float(e["wrong_way"]) - dt * 2.0, 0.0)
	var result := ""
	var next_line: float = (int(e["laps_done"]) + 1) * track_length
	if float(e["race_dist"]) >= next_line and float(e["max_dist"]) >= next_line:
		var lap_time: float = race_time - float(e["lap_start"])
		e["lap_times"].append(lap_time)
		e["last_lap_time"] = lap_time
		if float(e["best_lap"]) <= 0.0 or lap_time < float(e["best_lap"]):
			e["best_lap"] = lap_time
		e["laps_done"] = int(e["laps_done"]) + 1
		e["lap_start"] = race_time
		result = "lap"
		if int(e["laps_done"]) >= total_laps:
			e["finished"] = true
			e["finish_time"] = race_time
			finish_order.append(id)
			result = "finish"
	return result


## Forces a rider to finish now (used when the race ends for the remaining field);
## unfinished riders are ranked by distance.
func force_finish_all() -> void:
	var rest := []
	for id in riders:
		if not riders[id]["finished"]:
			rest.append(id)
	rest.sort_custom(func(a, b): return float(riders[a]["race_dist"]) > float(riders[b]["race_dist"]))
	for id in rest:
		var e: Dictionary = riders[id]
		e["finished"] = true
		# Estimate the finishing time from the remaining distance at the current pace.
		var covered: float = maxf(float(e["race_dist"]), 1.0)
		var remaining: float = total_laps * track_length - covered
		var pace: float = covered / maxf(race_time, 1.0)
		e["finish_time"] = race_time + remaining / maxf(pace, 5.0)
		e["estimated"] = true
		finish_order.append(id)


## Rider ids ordered by race position (leader first).
func standings() -> Array:
	var ids := riders.keys()
	ids.sort_custom(_compare)
	return ids


func _compare(a, b) -> bool:
	var ea: Dictionary = riders[a]
	var eb: Dictionary = riders[b]
	if ea["finished"] and eb["finished"]:
		return finish_order.find(a) < finish_order.find(b)
	if ea["finished"] != eb["finished"]:
		return ea["finished"]
	return float(ea["race_dist"]) > float(eb["race_dist"])


func position_of(id: int) -> int:
	return standings().find(id) + 1


func current_lap(id: int) -> int:
	## 1-based lap the rider is on (clamped to total laps).
	return mini(int(riders[id]["laps_done"]) + 1, total_laps)


func current_lap_time(id: int) -> float:
	var e: Dictionary = riders[id]
	if e["finished"]:
		return float(e["last_lap_time"])
	return race_time - float(e["lap_start"])


func is_wrong_way(id: int) -> bool:
	return float(riders[id]["wrong_way"]) > 1.2


func all_finished(ids: Array) -> bool:
	for id in ids:
		if not riders[id]["finished"]:
			return false
	return true


## Gap in meters from `id` to the rider ahead (0 for the leader).
func gap_ahead(id: int) -> float:
	var order := standings()
	var i := order.find(id)
	if i <= 0:
		return 0.0
	return float(riders[order[i - 1]]["race_dist"]) - float(riders[id]["race_dist"])

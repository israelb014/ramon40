class_name Championship
extends RefCounted
## Championship rules: three rounds (one per track), 8 riders, points per finishing
## position, standings with tie-breaks, and the unlocks earned along the way.
## State is a plain Dictionary so it can be saved as JSON.

const ROUNDS := ["ramon", "deadsea", "jerusalem"]


static func create(player_bike: String, difficulty: String, player_name: String, seed_value := 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	var riders := [{"name": player_name, "bike": player_bike, "player": true, "points": 0, "results": []}]
	var names := range(GameData.AI_RIDERS.size())
	names.shuffle()
	var bikes := ["sport", "naked", "supermoto", "cafe", "sport", "naked", "cafe"]
	for i in 7:
		riders.append({"name_idx": names[i], "bike": bikes[(i + rng.randi_range(0, 6)) % bikes.size()], "player": false, "points": 0, "results": []})
	return {"active": true, "complete": false, "round": 0, "difficulty": difficulty, "bike": player_bike, "riders": riders, "rewards": []}


static func rider_name(state: Dictionary, i: int) -> String:
	var r: Dictionary = state["riders"][i]
	if r.get("player", false):
		return String(r.get("name", ""))
	return GameData.rider_name(int(r.get("name_idx", i)))


static func current_track(state: Dictionary) -> String:
	return ROUNDS[clampi(int(state.get("round", 0)), 0, ROUNDS.size() - 1)]


## Race configuration for the next round.
static func race_config(state: Dictionary) -> Dictionary:
	var track := current_track(state)
	var ai_names := []
	var ai_bikes := []
	for i in range(1, state["riders"].size()):
		ai_names.append(rider_name(state, i))
		ai_bikes.append(state["riders"][i]["bike"])
	var cfg := {
		"mode": "championship", "track": track,
		"laps": int(GameData.TRACKS[track].get("default_laps", 2)),
		"difficulty": state["difficulty"],
		"players": [{"bike": state["bike"], "name": rider_name(state, 0)}],
		"opponents": 7, "ai_names": ai_names, "ai_bikes": ai_bikes,
	}
	if int(state.get("round", 0)) > 0:
		# Grid by standings: the leader starts on pole.
		var order := standings(state)
		cfg["grid"] = [order.find(0)]
		var ai_grid := []
		for i in range(1, state["riders"].size()):
			ai_grid.append(order.find(i))
		cfg["ai_grid"] = ai_grid
	return cfg


## Applies finishing positions. `results` entries need "index" (rider id) and "position".
static func apply_results(state: Dictionary, results: Array) -> Dictionary:
	var summary := {"points": {}, "player_position": 0}
	for r in results:
		var id := int(r["index"])
		if id < 0 or id >= state["riders"].size():
			continue
		var pos := int(r["position"])
		var pts := GameData.points_for(pos)
		var rider: Dictionary = state["riders"][id]
		rider["points"] = int(rider["points"]) + pts
		rider["results"].append(pos)
		summary["points"][id] = pts
		if rider.get("player", false):
			summary["player_position"] = pos
	state["round"] = int(state["round"]) + 1
	if int(state["round"]) >= ROUNDS.size():
		state["complete"] = true
		state["active"] = false
	return summary


## Rider ids sorted by points; ties broken by number of wins, then best result, then
## the most recent finish.
static func standings(state: Dictionary) -> Array:
	var ids := range(state["riders"].size())
	var riders: Array = state["riders"]
	ids.sort_custom(func(a, b):
		var ra: Dictionary = riders[a]
		var rb: Dictionary = riders[b]
		if int(ra["points"]) != int(rb["points"]):
			return int(ra["points"]) > int(rb["points"])
		var wa: int = ra["results"].count(1)
		var wb: int = rb["results"].count(1)
		if wa != wb:
			return wa > wb
		var ba: int = ra["results"].min() if not ra["results"].is_empty() else 99
		var bb: int = rb["results"].min() if not rb["results"].is_empty() else 99
		if ba != bb:
			return ba < bb
		var la: int = ra["results"].back() if not ra["results"].is_empty() else 99
		var lb: int = rb["results"].back() if not rb["results"].is_empty() else 99
		return la < lb)
	return ids


static func player_rank(state: Dictionary) -> int:
	return standings(state).find(0) + 1


## Grants unlocks for a finished round / championship. Returns human-readable keys.
static func grant_rewards(state: Dictionary, round_position: int, save: Node) -> Array:
	var gained := []
	if round_position >= 1 and round_position <= 3:
		var c: int = save.unlock_next_color()
		if c >= 0:
			gained.append({"type": "color", "id": c})
	if state.get("complete", false):
		var rank := player_rank(state)
		save.progress["championships_completed"] = int(save.progress.get("championships_completed", 0)) + 1
		if save.unlock_bike("sport"):
			gained.append({"type": "bike", "id": "sport"})
		if rank == 1:
			save.progress["championships_won"] = int(save.progress.get("championships_won", 0)) + 1
			if save.unlock_bike("cafe"):
				gained.append({"type": "bike", "id": "cafe"})
			if not save.is_color_unlocked(11):
				save.progress["unlocked_colors"].append(11)
				gained.append({"type": "color", "id": 11})
	state["rewards"] = gained
	return gained

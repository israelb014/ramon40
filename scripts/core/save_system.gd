extends Node
## Persistent game progress: unlocks, paint choices, best times, championship state, ghosts.
## Everything lives under `base_dir` (user:// by default; tests point it at a temp folder).

signal progress_changed

const SAVE_VERSION := 1
const STARTER_BIKES := ["naked", "supermoto"]
const STARTER_COLORS := [0, 1, 2, 3, 4, 5]
const TOTAL_COLORS := 12

var base_dir := "user://"
var progress: Dictionary = {}


func _ready() -> void:
	load_progress()


func default_progress() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"player_name": "",
		"unlocked_bikes": STARTER_BIKES.duplicate(),
		"unlocked_colors": STARTER_COLORS.duplicate(),
		"selected_bike": "naked",
		"paint": {}, # bike_id -> {"body": int, "accent": int}
		"suit": {"main": 0, "accent": 3},
		"best_laps": {}, # track_id -> {"time": float, "bike": String}
		"best_races": {}, # track_id -> {"time": float, "bike": String, "laps": int}
		"championship": {},
		"championships_completed": 0,
		"championships_won": 0,
		"races_finished": 0,
		"wins": 0,
	}


func _save_path() -> String:
	return base_dir.path_join("save.json")


func _ghost_dir() -> String:
	return base_dir.path_join("ghosts")


func load_progress() -> void:
	progress = default_progress()
	var path := _save_path()
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var json := JSON.new()
	var parsed = json.data if json.parse(f.get_as_text()) == OK else null
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file is corrupt; starting fresh.")
		return
	for key in parsed:
		if progress.has(key) and typeof(parsed[key]) == typeof(progress[key]):
			progress[key] = parsed[key]
		elif progress.has(key) and typeof(progress[key]) == TYPE_INT and typeof(parsed[key]) == TYPE_FLOAT:
			progress[key] = int(parsed[key])
	# JSON has no ints: normalize the numeric lists.
	progress["unlocked_colors"] = _int_array(progress["unlocked_colors"])
	for bike in progress["paint"]:
		var p: Dictionary = progress["paint"][bike]
		for k in p:
			p[k] = int(p[k])
	for k in progress["suit"]:
		progress["suit"][k] = int(progress["suit"][k])


func _int_array(a: Array) -> Array:
	var out := []
	for v in a:
		out.append(int(v))
	return out


func save_progress() -> bool:
	DirAccess.make_dir_recursive_absolute(base_dir)
	var f := FileAccess.open(_save_path(), FileAccess.WRITE)
	if f == null:
		push_warning("Cannot write save file: %s" % _save_path())
		return false
	f.store_string(JSON.stringify(progress, "\t"))
	f.close()
	progress_changed.emit()
	return true


func reset_progress() -> void:
	progress = default_progress()
	save_progress()
	var d := DirAccess.open(_ghost_dir())
	if d:
		for file in d.get_files():
			d.remove(file)


# --- Unlocks -----------------------------------------------------------------

func is_bike_unlocked(bike_id: String) -> bool:
	return bike_id in progress["unlocked_bikes"]


func unlock_bike(bike_id: String) -> bool:
	if is_bike_unlocked(bike_id):
		return false
	progress["unlocked_bikes"].append(bike_id)
	return true


func is_color_unlocked(idx: int) -> bool:
	return idx in progress["unlocked_colors"]


## Unlocks the next locked color, returns its index or -1 if all are unlocked.
func unlock_next_color() -> int:
	for i in TOTAL_COLORS:
		if not is_color_unlocked(i):
			progress["unlocked_colors"].append(i)
			return i
	return -1


const DEFAULT_PAINT := {"sport": 0, "naked": 5, "supermoto": 1, "cafe": 9}


## Paint of a bike ({"body": idx, "accent": idx}); defaults when never customised.
func get_paint(bike_id: String) -> Dictionary:
	if progress["paint"].has(bike_id):
		var p: Dictionary = progress["paint"][bike_id]
		return {"body": int(p.get("body", 0)), "accent": int(p.get("accent", 10))}
	return {"body": int(DEFAULT_PAINT.get(bike_id, 0)), "accent": 10}


func set_paint(bike_id: String, body: int, accent: int) -> void:
	progress["paint"][bike_id] = {"body": body, "accent": accent}


# --- Best times --------------------------------------------------------------

## Returns true if `time` is a new record for the track.
func submit_lap(track_id: String, time: float, bike_id: String) -> bool:
	if time <= 0.0:
		return false
	var cur = progress["best_laps"].get(track_id)
	if cur == null or time < float(cur["time"]):
		progress["best_laps"][track_id] = {"time": time, "bike": bike_id}
		return true
	return false


func best_lap(track_id: String) -> float:
	var cur = progress["best_laps"].get(track_id)
	return float(cur["time"]) if cur != null else 0.0


func submit_race(track_id: String, time: float, bike_id: String, laps: int) -> bool:
	var key := "%s_%d" % [track_id, laps]
	var cur = progress["best_races"].get(key)
	if cur == null or time < float(cur["time"]):
		progress["best_races"][key] = {"time": time, "bike": bike_id, "laps": laps}
		return true
	return false


# --- Ghosts ------------------------------------------------------------------

func save_ghost(track_id: String, ghost: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(_ghost_dir())
	var f := FileAccess.open(_ghost_dir().path_join(track_id + ".ghost"), FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(ghost, false)
	f.close()
	return true


func load_ghost(track_id: String) -> Dictionary:
	var path := _ghost_dir().path_join(track_id + ".ghost")
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var v = f.get_var(false)
	return v if typeof(v) == TYPE_DICTIONARY else {}

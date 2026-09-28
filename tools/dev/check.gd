extends Node
## Loads every GDScript in the project to surface parse/compile errors.
func _ready():
	var bad := 0
	for f in _scan("res://"):
		var s = load(f)
		if s == null or not (s as GDScript).can_instantiate():
			print("FAILED: ", f)
			bad += 1
	print("check done, failures: ", bad)
	get_tree().quit(1 if bad > 0 else 0)

func _scan(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		if sub.begins_with(".") or sub == "addons":
			continue
		out.append_array(_scan(dir.path_join(sub)))
	return out

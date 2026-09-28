class_name GhostPlayer
extends RefCounted
## Plays back the saved best lap as a translucent ghost bike in Time Trial.

var bike: Bike
var data: Dictionary
var visible := false
var _ts := PackedFloat32Array()
var _d := PackedFloat32Array()


func _init(ghost_bike: Bike, ghost_data: Dictionary) -> void:
	bike = ghost_bike
	set_data(ghost_data)
	_make_translucent(bike)
	bike.visible = false


func set_data(ghost_data: Dictionary) -> void:
	data = ghost_data
	var samples: Dictionary = data.get("samples", {})
	_ts = samples.get("t", PackedFloat32Array())
	_d = samples.get("d", PackedFloat32Array())


static func _make_translucent(root: Node) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.85, 1.0, 0.32)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.6, 1.0)
	mat.emission_energy_multiplier = 0.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Positions the ghost at the given time into the current lap.
func update(lap_time: float) -> void:
	if _ts.is_empty():
		visible = false
		bike.visible = false
		return
	var dur := _ts[_ts.size() - 1]
	visible = lap_time > 0.05 and lap_time <= dur
	bike.visible = visible
	if visible:
		bike.apply_snapshot(ReplayRecorder.sample(_ts, _d, lap_time))

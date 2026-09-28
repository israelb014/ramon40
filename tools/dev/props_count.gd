extends Node
func _ready() -> void:
	for id in ["ramon", "deadsea", "jerusalem"]:
		var t := TrackData.build(TrackLayouts.get_layout(id))
		var groups := PropPlacer.new(t, 1.0).place_all()
		var tot := 0
		var line := ""
		var w := TrackWorld.new()
		w.track = t
		for g in groups:
			var n: int = groups[g].size()
			var m: ArrayMesh = w._prop_mesh(g)
			var tris := 0
			for si in m.get_surface_count():
				tris += m.surface_get_array_index_len(si) / 3
			tot += n * tris
			line += "%s:%dx%d " % [g, n, tris]
		print(id, " total_tris=", tot, "  ", line)
		w.free()
	get_tree().quit()

extends Node
## Dev tool: renders screenshots of a track from several viewpoints.
## Usage: godot --path . tools/dev/shot.tscn -- <track_id> <out_prefix> [fractions]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var id := args[0] if args.size() > 0 else "ramon"
	var out := args[1] if args.size() > 1 else "/tmp/shot"
	var t0 := Time.get_ticks_msec()
	var data := TrackWorld.generate_data(id)
	var t1 := Time.get_ticks_msec()
	var w := TrackWorld.new()
	add_child(w)
	w.assemble(data)
	var t2 := Time.get_ticks_msec()
	print("gen ms ", t1 - t0, " assemble ms ", t2 - t1, " nodes ", w.find_children("*", "GeometryInstance3D", true, false).size())
	var cam := Camera3D.new()
	cam.far = 12000.0
	cam.fov = 70.0
	w.add_child(cam)
	var tr: TrackData = w.track
	var fracs := [0.0, 0.12, 0.3, 0.5, 0.7, 0.9]
	if args.size() > 2:
		fracs = []
		for a in args[2].split(","):
			fracs.append(float(a))
	for f in fracs:
		var d: float = f * tr.length
		var xf := tr.transform_at(d - 12.0, 1.5)
		cam.global_position = xf.origin + Vector3.UP * 2.2
		var target := tr.point_at_distance(d + 25.0) + Vector3.UP * 1.0
		cam.look_at(target, Vector3.UP)
		for i in 10:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s_%s_%03d.png" % [out, id, int(f * 100)])
		print("frac %.2f draws=%d prims=%d objects=%d" % [f, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])
	var b := tr.bounds()
	cam.global_position = Vector3(b.get_center().x, 900, b.end.y + 900)
	cam.look_at(Vector3(b.get_center().x, 0, b.get_center().y), Vector3.UP)
	for i in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s_%s_aerial.png" % [out, id])
	get_tree().quit()

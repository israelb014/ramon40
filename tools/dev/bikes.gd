extends Node3D
## Dev tool: renders the four bike models (and riders once available) for inspection.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp/bikes"
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.25, 0.27, 0.3)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.65)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor_mi.mesh = pm
	add_child(floor_mi)
	var ids := ["sport", "naked", "supermoto", "cafe"]
	var paints := [Color(0.78, 0.13, 0.1), Color(0.1, 0.28, 0.7), Color(0.95, 0.95, 0.9), Color(0.05, 0.4, 0.3)]
	var poses := [[0.7, true, 30.0], [0.0, false, 0.0], [-0.55, false, 15.0], [0.0, true, 25.0]]
	var i := 0
	var with_rider := args.size() > 1 and args[1] == "rider"
	for id in ids:
		var b := Bike.new()
		add_child(b)
		b.world_root = self
		b.setup(id, null, {"paint": paints[i], "accent": Color(0.95, 0.75, 0.1), "suit_main": Color(0.12, 0.12, 0.14), "suit_accent": paints[i], "helmet": Color(0.95, 0.95, 0.95)})
		b.place_at(Transform3D(Basis(), Vector3(0, 0, i * 2.4 - 3.6)))
		if not with_rider:
			b.rider.visible = false
		b.physics.lean = poses[i][0]
		b.physics.in_tuck = poses[i][1]
		b.physics.tuck_amount = 1.0 if poses[i][1] else 0.0
		b.physics.speed = poses[i][2]
		b.physics.in_throttle = 0.0 if poses[i][2] == 0.0 else 0.5
		for k in 60:
			b.sync_visual(1.0 / 30.0)
		i += 1
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 40
	var views := {"side": [Vector3(9.0, 1.0, 0), Vector3(0, 0.6, 0)], "34": [Vector3(5.5, 2.4, -7.5), Vector3(0, 0.5, -1.0)], "close": [Vector3(2.2, 1.3, -5.2), Vector3(0, 0.6, -3.6)], "close2": [Vector3(2.0, 1.2, 3.8), Vector3(0, 0.6, 1.2)]}
	for v in views:
		cam.position = views[v][0]
		cam.look_at(views[v][1])
		for k in 8:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s_%s.png" % [out, v])
	get_tree().quit()

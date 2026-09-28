extends Node3D
## Dev: traces one AI bike on a track without rendering.
func _ready() -> void:
	print("start")
	var args := OS.get_cmdline_user_args()
	var tid := args[0] if args.size() > 0 else "ramon"
	var bid := args[1] if args.size() > 1 else "sport"
	var t := TrackData.build(TrackLayouts.get_layout(tid))
	print("track built")
	var line := RacingLine.for_track(t)
	print("line built")
	var b := Bike.new()
	add_child(b)
	b.world_root = self
	b.setup(bid, t, {})
	b.place_at(t.grid_transform(int(args[2]) if args.size() > 2 else 0))
	var ai := AIController.new(line, GameData.bike(bid), "hard", 5)
	ai.all_bikes = [b]
	var dt := 1.0 / 60.0
	var off := 0.0
	var maxlat := 0.0
	var tt := 0.0
	var lapd := 0.0
	var last := b.physics.track_dist
	while tt < float(OS.get_environment("TRACE_T") if OS.get_environment("TRACE_T") != "" else "30"):
		ai.update(b, dt)
		for s in 2:
			b.physics.step(dt / 2.0, t)
		b.post_step(dt)
		tt += dt
		var ph := b.physics
		var dd := t.wrap_delta(last, ph.track_dist)
		last = ph.track_dist
		lapd += dd
		if absf(ph.track_lateral) > t.half_width:
			off += dt
		maxlat = maxf(maxlat, absf(ph.track_lateral))
		if int(tt * 60.0) % 30 == 0 and (tt < 12.0 or OS.get_environment("TRACE_ALL") != ""):
			print("t=%.1f d=%d lat=%.2f line=%.2f v=%d steer=%.2f lean=%.2f thr=%.2f brk=%.2f g=%d pitch=%.2f surf=%d yawerr=%.2f" % [tt, int(ph.track_dist), ph.track_lateral, line.offsets[maxi(ph.track_index,0)], int(ph.speed*3.6), ph.in_steer, ph.lean, ph.in_throttle, ph.in_brake, ph.gear, ph.pitch, ph.surface, ph.forward().angle_to(t.tangents[maxi(ph.track_index,0)])])
		if lapd > t.length:
			print("LAP ", GameData.format_time(tt), " off=", snappedf(off, 0.1), " maxlat=", snappedf(maxlat, 0.1), " crashed=", ph.is_crashed)
			break
	get_tree().quit()

extends GutTest
## Physics model sanity checks on flat ground (no track).

const DT := 1.0 / 120.0


func _run(bike: BikePhysics, seconds: float, throttle := 1.0, brake := 0.0, steer := 0.0) -> void:
	bike.in_throttle = throttle
	bike.in_brake = brake
	bike.in_steer = steer
	for i in int(seconds / DT):
		bike.step(DT)


func _bike(id: String) -> BikePhysics:
	var b := BikePhysics.new(GameData.bike(id))
	b.place(Transform3D())
	b.crashes_enabled = true
	return b


func test_accelerates_from_standstill():
	var b := _bike("naked")
	_run(b, 3.0)
	assert_gt(b.speed, 20.0, "naked should exceed 72 km/h after 3 s")
	assert_lt(b.speed, 35.0)
	assert_false(b.is_crashed)


func test_top_speed_ordering():
	var tops := {}
	for id in GameData.BIKE_ORDER:
		var b := _bike(id)
		b.in_tuck = true
		_run(b, 60.0)
		tops[id] = b.speed
	assert_gt(tops["sport"], tops["naked"])
	assert_gt(tops["naked"], tops["cafe"])
	assert_gt(tops["cafe"], tops["supermoto"])
	assert_between(tops["sport"] * 3.6, 250.0, 310.0, "sport top speed km/h")
	assert_between(tops["supermoto"] * 3.6, 160.0, 215.0, "supermoto top speed km/h")


func test_gears_shift_up_under_acceleration():
	var b := _bike("sport")
	_run(b, 12.0)
	assert_gt(b.gear, 3)
	assert_gt(b.shift_count, 2)


func test_braking_stops_bike():
	var b := _bike("sport")
	_run(b, 6.0)
	var v0 := b.speed
	var p0 := b.pos
	_run(b, 8.0, 0.0, 1.0)
	assert_almost_eq(b.speed, 0.0, 0.6)
	var dist := p0.distance_to(b.pos)
	# Rough physics bound: v^2 / (2 * a) with a between 6 and 12 m/s^2.
	assert_between(dist, v0 * v0 / 30.0, v0 * v0 / 10.0, "stopping distance")
	assert_false(b.is_crashed)


func test_turning_radius_grows_with_speed():
	var radii := []
	for target in [12.0, 30.0]:
		var b := _bike("naked")
		while b.speed < target:
			b.in_throttle = 1.0
			b.step(DT)
		# Hold speed roughly and steer fully.
		var yaw0 := b.yaw
		var t := 0.0
		for i in 240:
			b.in_throttle = 0.35 if b.speed < target else 0.0
			b.in_steer = 1.0
			b.step(DT)
			t += DT
		var yaw_rate := absf(b.yaw - yaw0) / t
		radii.append(b.speed / maxf(yaw_rate, 0.001))
	assert_gt(radii[1], radii[0] * 2.0, "radius at 30 m/s should be much larger than at 12 m/s")


func test_steer_right_turns_right():
	var b := _bike("naked")
	_run(b, 3.0)
	var r0 := b.right()
	var p0 := b.pos
	_run(b, 1.5, 0.3, 0.0, 1.0)
	assert_gt((b.pos - p0).dot(r0), 1.0, "bike should move to its right")
	assert_gt(b.lean, 0.1, "lean right is positive")


func test_counter_lean_takes_time():
	var b := _bike("sport")
	_run(b, 4.0)
	b.in_steer = 1.0
	b.step(DT)
	assert_lt(b.lean, 0.1, "lean builds progressively, not instantly")


func test_wheelie_on_naked_launch():
	var b := _bike("naked")
	var max_pitch := 0.0
	b.in_throttle = 1.0
	for i in 240:
		b.step(DT)
		max_pitch = maxf(max_pitch, b.pitch)
	assert_gt(max_pitch, 0.03, "naked should lift the front on a full-throttle launch")
	assert_false(b.is_crashed)


func test_stoppie_under_hard_front_brake():
	var b := _bike("sport")
	_run(b, 2.2)
	var min_pitch := 0.0
	b.in_throttle = 0.0
	b.in_brake = 1.0
	for i in 200:
		b.step(DT)
		min_pitch = minf(min_pitch, b.pitch)
	assert_lt(min_pitch, -0.01, "hard front braking at moderate speed lifts the rear")


func test_trail_braking_reduces_cornering_grip():
	var b := _bike("naked")
	b.assist = 0.0
	_run(b, 5.0)
	b.in_throttle = 0.0
	b.in_steer = 1.0
	for i in 120:
		b.step(DT)
	var calm_usage := b.grip_usage
	b.in_brake = 1.0
	b.step(DT)
	assert_gt(b.grip_usage, calm_usage, "braking while leaned uses more of the friction circle")


func test_crash_when_grip_exceeded_badly():
	var b := _bike("cafe")
	b.assist = 0.0
	_run(b, 8.0)
	# Offroad surface with full lean and hard front brake: must crash.
	var crashed := false
	for i in 400:
		b.surface = BikePhysics.Surface.OFFROAD
		b.in_steer = 1.0
		b.in_brake = 1.0
		b.in_throttle = 0.0
		b.step(DT)
		if b.is_crashed:
			crashed = true
			break
	assert_true(crashed, "gross grip abuse should crash")


func test_offroad_slows_bike():
	var road := _bike("sport")
	var dirt := _bike("sport")
	for i in int(10.0 / DT):
		road.in_throttle = 1.0
		road.step(DT)
		dirt.in_throttle = 1.0
		dirt.step(DT)
		dirt.surface = BikePhysics.Surface.OFFROAD
	assert_lt(dirt.speed, road.speed * 0.8)


func test_supermoto_better_offroad():
	var sm := _bike("supermoto")
	var sp := _bike("sport")
	assert_gt(sm.surface_grip() if true else 0.0, 0.0)
	sm.surface = BikePhysics.Surface.OFFROAD
	sp.surface = BikePhysics.Surface.OFFROAD
	assert_gt(sm.surface_grip(), sp.surface_grip())


func test_crashed_bike_slides_to_stop():
	var b := _bike("naked")
	_run(b, 4.0)
	b.crash("test")
	_run(b, 6.0, 0.0)
	assert_true(b.is_crashed)
	assert_almost_eq(b.vel.length(), 0.0, 0.1)


func test_power_curve_shape():
	assert_lt(BikePhysics.power_curve(0.1), BikePhysics.power_curve(0.8))
	assert_lt(BikePhysics.power_curve(1.08), BikePhysics.power_curve(0.95))

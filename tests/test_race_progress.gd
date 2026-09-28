extends GutTest
## Lap counting, positions and wrong-way logic.

const L := 1000.0


func _drive(rp: RaceProgress, id: int, from: float, to: float, step := 5.0, dt := 0.1) -> Array:
	var events := []
	var d := from
	while d < to:
		d += step
		rp.tick(dt)
		var ev := rp.update_rider(id, fposmod(d, L), 1.0, 20.0, dt)
		if ev != "":
			events.append(ev)
	return events


func test_grid_behind_line_starts_negative():
	var rp := RaceProgress.new(L, 3)
	rp.add_rider(0, L - 20.0)
	assert_almost_eq(float(rp.riders[0]["race_dist"]), -20.0, 0.001)
	assert_eq(rp.current_lap(0), 1)


func test_crossing_start_line_first_time_is_not_a_lap():
	var rp := RaceProgress.new(L, 3)
	rp.add_rider(0, L - 20.0)
	var ev := _drive(rp, 0, L - 20.0, L + 50.0)
	assert_eq(ev.size(), 0)
	assert_eq(rp.current_lap(0), 1)


func test_full_race_counts_laps_and_finishes():
	var rp := RaceProgress.new(L, 3)
	rp.add_rider(0, L - 20.0)
	var ev := _drive(rp, 0, L - 20.0, 4.0 * L + 10.0)
	assert_eq(ev, ["lap", "lap", "finish"])
	assert_true(rp.riders[0]["finished"])
	assert_eq(rp.riders[0]["lap_times"].size(), 3)
	assert_gt(float(rp.riders[0]["best_lap"]), 0.0)


func test_reversing_across_line_does_not_count_lap():
	var rp := RaceProgress.new(L, 3)
	rp.add_rider(0, L - 20.0)
	_drive(rp, 0, L - 20.0, 2.0 * L - 10.0) # nearly through lap 1
	# Go back 30 m, then forward again past the line once.
	var d := 2.0 * L - 10.0
	for i in 6:
		d -= 5.0
		rp.update_rider(0, fposmod(d, L))
	var ev := []
	for i in 12:
		d += 5.0
		var e := rp.update_rider(0, fposmod(d, L))
		if e != "":
			ev.append(e)
	assert_eq(ev, ["lap"], "exactly one lap completion")


func test_positions_by_distance():
	var rp := RaceProgress.new(L, 3)
	rp.add_rider(0, L - 10.0)
	rp.add_rider(1, L - 20.0)
	rp.add_rider(2, L - 30.0)
	rp.update_rider(2, 200.0)
	rp.update_rider(0, 100.0)
	rp.update_rider(1, 150.0)
	assert_eq(rp.standings(), [2, 1, 0])
	assert_eq(rp.position_of(2), 1)
	assert_eq(rp.position_of(0), 3)


func test_finished_riders_rank_by_finish_order():
	var rp := RaceProgress.new(L, 1)
	rp.add_rider(0, L - 10.0)
	rp.add_rider(1, L - 20.0)
	_drive(rp, 1, L - 20.0, 2.0 * L + 10.0)
	_drive(rp, 0, L - 10.0, 2.0 * L + 10.0)
	assert_eq(rp.standings(), [1, 0])


func test_wrong_way_detection():
	var rp := RaceProgress.new(L, 3)
	rp.add_rider(0, 100.0)
	for i in 20:
		rp.update_rider(0, 100.0 - i, -0.9, 10.0, 0.1)
	assert_true(rp.is_wrong_way(0))
	for i in 20:
		rp.update_rider(0, 80.0 + i, 1.0, 10.0, 0.1)
	assert_false(rp.is_wrong_way(0))


func test_force_finish_ranks_by_distance():
	var rp := RaceProgress.new(L, 3)
	rp.add_rider(0, 0.0)
	rp.add_rider(1, 0.0)
	rp.race_time = 60.0
	rp.update_rider(0, 300.0)
	rp.update_rider(1, 500.0)
	rp.force_finish_all()
	assert_eq(rp.standings(), [1, 0])
	assert_gt(float(rp.riders[0]["finish_time"]), float(rp.riders[1]["finish_time"]))

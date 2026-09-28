extends GutTest


func test_points_table():
	assert_eq(GameData.points_for(1), 25)
	assert_eq(GameData.points_for(8), 4)
	assert_eq(GameData.points_for(9), 0)
	assert_eq(GameData.points_for(0), 0)


func test_format_time():
	assert_eq(GameData.format_time(83.456), "1:23.456")
	assert_eq(GameData.format_time(0.0), "--:--.---")


func test_all_bikes_defined():
	for id in GameData.BIKE_ORDER:
		assert_true(GameData.BIKES.has(id), id)
		assert_eq(GameData.BIKES[id]["gears"].size(), 6)

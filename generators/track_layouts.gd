class_name TrackLayouts
extends RefCounted
## Hand-designed layouts for the three tracks. Control points are (x, height, z) in meters;
## the road is a closed Catmull-Rom spline through them. Layouts were designed with a
## prototype script checking length, minimum radius, self-clearance and grades.


static func get_layout(id: String) -> Dictionary:
	match id:
		"ramon":
			return _ramon()
		"deadsea":
			return _deadsea()
		"jerusalem":
			return _jerusalem()
		"test_oval":
			return _test_oval()
	push_error("Unknown track id: %s" % id)
	return _test_oval()


static func _pts(arr: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in arr:
		out.append(Vector3(p[0], p[2], p[1]))
	return out


## Route 40 into Makhtesh Ramon at sunset: rim plateau, switchback descent down the
## escarpment, fast crater floor, long climb back up the western slope.
static func _ramon() -> Dictionary:
	return {
		"id": "ramon",
		"style": "ramon",
		"seed": 4040,
		"points": _pts([[-600, -600, 82], [-300, -620, 84], [0, -590, 85], [250, -640, 86], [470, -610, 85],
			[580, -540, 83], [610, -450, 80], [660, -425, 77], [710, -420, 75], [742, -410, 74],
			[752, -392, 73], [742, -374, 72], [710, -366, 71], [640, -356, 68], [570, -346, 64],
			[536, -336, 63], [526, -318, 62], [536, -300, 61], [570, -292, 60], [640, -282, 56],
			[710, -270, 53], [744, -260, 52], [754, -242, 51], [744, -224, 50], [710, -216, 49],
			[640, -200, 45], [580, -160, 38], [545, -80, 28], [560, 20, 17], [450, 150, 8],
			[200, 220, 4], [-100, 180, 3], [-350, 250, 5], [-600, 150, 8], [-750, -20, 16],
			[-700, -200, 34], [-820, -350, 55], [-800, -500, 72], [-700, -590, 80]]),
		"half_width": 5.5,
		"shoulder": 2.5,
		"wall": 26.0,
		"tunnels": [],
		"signs": [
			{"at": 0.06, "side": 1, "lines": ["מצפה רמון", "Mitzpe Ramon"], "sub": "40"},
			{"at": 0.21, "side": 1, "lines": ["מכתש רמון", "Ramon Crater"], "sub": "40"},
			{"at": 0.47, "side": -1, "lines": ["אילת", "Eilat"], "sub": "40"},
			{"at": 0.66, "side": 1, "lines": ["באר שבע", "Be'er Sheva"], "sub": "40"},
			{"at": 0.86, "side": 1, "lines": ["שדה בוקר", "Sde Boker"], "sub": "40"},
		],
		"banner": "כביש 40 · מכתש רמון",
		# Keep more of the natural escarpment: the road cuts into the rim.
		"terrain_correction": 0.7,
		"blend_radius": 34.0,
	}


## Route 90 along the Dead Sea at midday: fast shore road southbound, return north along
## the foot of the cliffs through the palm groves.
static func _deadsea() -> Dictionary:
	return {
		"id": "deadsea",
		"style": "deadsea",
		"seed": 9090,
		"points": _pts([[0, -900, 2], [20, -600, 1], [60, -300, 0], [40, 0, 1], [90, 250, 2], [60, 500, 1],
			[-20, 700, 2], [-150, 780, 4], [-300, 740, 7], [-360, 600, 10], [-330, 400, 12],
			[-400, 250, 14], [-350, 150, 14], [-420, 0, 16], [-380, -250, 18], [-300, -450, 16],
			[-360, -650, 14], [-300, -850, 10], [-180, -1000, 6], [-60, -1020, 3], [-10, -980, 2]]),
		"half_width": 5.5,
		"shoulder": 3.0,
		"wall": 30.0,
		"tunnels": [],
		"signs": [
			{"at": 0.05, "side": -1, "lines": ["עין גדי", "Ein Gedi"], "sub": "90"},
			{"at": 0.24, "side": -1, "lines": ["מצדה", "Masada"], "sub": "90"},
			{"at": 0.45, "side": 1, "lines": ["עין בוקק", "Ein Bokek"], "sub": "90"},
			{"at": 0.62, "side": -1, "lines": ["ירושלים", "Jerusalem"], "sub": "1"},
			{"at": 0.83, "side": -1, "lines": ["ים המלח", "Dead Sea"], "sub": "90"},
		],
		"banner": "כביש 90 · ים המלח",
	}


## Route 1 descending from Jerusalem at night: winding forested descent with a tunnel,
## valley floor, and a twisting climb back to the city.
static func _jerusalem() -> Dictionary:
	return {
		"id": "jerusalem",
		"style": "jerusalem",
		"seed": 1111,
		"points": _pts([[0, 0, 120], [-250, 20, 118], [-450, -40, 112], [-600, 20, 104], [-800, 10, 96],
			[-950, -80, 86], [-1050, -220, 74], [-1000, -380, 62], [-850, -420, 52], [-750, -520, 42],
			[-800, -680, 30], [-650, -760, 22], [-450, -700, 18], [-300, -760, 20], [-150, -650, 30],
			[-50, -700, 42], [100, -600, 56], [120, -450, 70], [40, -330, 82], [160, -220, 96],
			[140, -80, 110], [100, 10, 118]]),
		"half_width": 5.5,
		"shoulder": 2.0,
		"wall": 22.0,
		# Tunnel sections given as [start fraction, end fraction] of the lap.
		"tunnels": [[0.155, 0.225], [0.735, 0.775]],
		"signs": [
			{"at": 0.04, "side": 1, "lines": ["תל אביב", "Tel Aviv"], "sub": "1"},
			{"at": 0.30, "side": 1, "lines": ["שער הגיא", "Sha'ar HaGai"], "sub": "1"},
			{"at": 0.52, "side": -1, "lines": ["בית שמש", "Beit Shemesh"], "sub": "38"},
			{"at": 0.70, "side": 1, "lines": ["מבשרת ציון", "Mevaseret Zion"], "sub": "1"},
			{"at": 0.90, "side": 1, "lines": ["ירושלים", "Jerusalem"], "sub": "1"},
		],
		"banner": "כביש 1 · עליה לירושלים",
	}


## Small flat oval used by unit tests and the physics sandbox.
static func _test_oval() -> Dictionary:
	var pts := []
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append([cos(a) * 300.0, sin(a) * 150.0, 0.0])
	return {
		"id": "test_oval", "style": "flat", "seed": 1, "points": _pts(pts),
		"half_width": 6.0, "shoulder": 2.0, "wall": 25.0, "tunnels": [], "signs": [], "banner": "TEST",
	}

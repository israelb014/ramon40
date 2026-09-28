class_name GameData
extends RefCounted
## Static game content definitions: bikes, tracks, paint palette, AI rider roster, points.

const BIKE_ORDER := ["sport", "naked", "supermoto", "cafe"]

## Physical parameters for BikePhysics. Display ratings (1-10) are derived for the UI.
const BIKES := {
	"sport": {
		"name": "BIKE_SPORT", "desc": "BIKE_SPORT_DESC",
		"mass": 265.0, "power": 108000.0, "cda": 0.34, "cda_tuck": 0.27,
		"launch_accel": 8.6, "grip": 1.28, "max_lean": 52.0, "lean_rate": 2.1,
		"brake_front": 10.8, "brake_rear": 3.8, "wheelbase": 1.40, "offroad": 0.55,
		"redline": 14500.0, "idle": 1400.0, "gears": [30.0, 44.0, 56.0, 66.0, 75.0, 84.0],
		"wheelie": 0.9, "engine": "inline4",
		"ratings": {"speed": 10, "accel": 9, "handling": 7, "braking": 9},
	},
	"naked": {
		"name": "BIKE_NAKED", "desc": "BIKE_NAKED_DESC",
		"mass": 250.0, "power": 86000.0, "cda": 0.42, "cda_tuck": 0.34,
		"launch_accel": 8.9, "grip": 1.22, "max_lean": 50.0, "lean_rate": 2.4,
		"brake_front": 10.2, "brake_rear": 4.0, "wheelbase": 1.42, "offroad": 0.62,
		"redline": 12000.0, "idle": 1300.0, "gears": [28.0, 40.0, 50.0, 58.0, 65.0, 72.0],
		"wheelie": 1.2, "engine": "triple",
		"ratings": {"speed": 8, "accel": 9, "handling": 8, "braking": 8},
	},
	"supermoto": {
		"name": "BIKE_SUPERMOTO", "desc": "BIKE_SUPERMOTO_DESC",
		"mass": 205.0, "power": 50000.0, "cda": 0.46, "cda_tuck": 0.40,
		"launch_accel": 8.2, "grip": 1.18, "max_lean": 50.0, "lean_rate": 3.0,
		"brake_front": 10.4, "brake_rear": 4.6, "wheelbase": 1.48, "offroad": 0.9,
		"redline": 10500.0, "idle": 1600.0, "gears": [19.0, 27.0, 35.0, 42.0, 49.0, 56.0],
		"wheelie": 1.5, "engine": "single",
		"ratings": {"speed": 5, "accel": 7, "handling": 10, "braking": 9},
	},
	"cafe": {
		"name": "BIKE_CAFE", "desc": "BIKE_CAFE_DESC",
		"mass": 255.0, "power": 64000.0, "cda": 0.40, "cda_tuck": 0.33,
		"launch_accel": 7.6, "grip": 1.12, "max_lean": 46.0, "lean_rate": 2.0,
		"brake_front": 9.0, "brake_rear": 3.6, "wheelbase": 1.45, "offroad": 0.6,
		"redline": 9000.0, "idle": 950.0, "gears": [22.0, 33.0, 43.0, 51.0, 58.0, 64.0],
		"wheelie": 0.8, "engine": "twin",
		"ratings": {"speed": 7, "accel": 6, "handling": 6, "braking": 6},
	},
}

const TRACK_ORDER := ["ramon", "deadsea", "jerusalem"]

const TRACKS := {
	"ramon": {
		"name": "TRACK_RAMON", "subtitle": "TRACK_RAMON_SUB", "road": "ROUTE_40",
		"time_of_day": "sunset", "default_laps": 2,
	},
	"deadsea": {
		"name": "TRACK_DEADSEA", "subtitle": "TRACK_DEADSEA_SUB", "road": "ROUTE_90",
		"time_of_day": "midday", "default_laps": 3,
	},
	"jerusalem": {
		"name": "TRACK_JERUSALEM", "subtitle": "TRACK_JERUSALEM_SUB", "road": "ROUTE_1",
		"time_of_day": "night", "default_laps": 2,
	},
}

## 12 paints. The first six are unlocked from the start.
const PAINTS := [
	{"name": "PAINT_CRATER_RED", "color": Color(0.78, 0.13, 0.10)},
	{"name": "PAINT_SALT_WHITE", "color": Color(0.92, 0.92, 0.90)},
	{"name": "PAINT_NIGHT_BLACK", "color": Color(0.06, 0.06, 0.07)},
	{"name": "PAINT_SEA_TEAL", "color": Color(0.05, 0.62, 0.62)},
	{"name": "PAINT_DESERT_SAND", "color": Color(0.85, 0.66, 0.38)},
	{"name": "PAINT_ROAD_BLUE", "color": Color(0.10, 0.28, 0.70)},
	{"name": "PAINT_SUNSET_ORANGE", "color": Color(0.98, 0.45, 0.08)},
	{"name": "PAINT_ACACIA_GREEN", "color": Color(0.28, 0.45, 0.18)},
	{"name": "PAINT_ROCK_PURPLE", "color": Color(0.42, 0.18, 0.50)},
	{"name": "PAINT_SIGN_GREEN", "color": Color(0.0, 0.42, 0.25)},
	{"name": "PAINT_LINE_YELLOW", "color": Color(0.98, 0.80, 0.08)},
	{"name": "PAINT_CHAMPION_GOLD", "color": Color(0.83, 0.64, 0.22)},
]

const AI_RIDERS := [
	{"name": "יואב כהן", "name_en": "Yoav Cohen"},
	{"name": "נועה לוי", "name_en": "Noa Levi"},
	{"name": "עומר מזרחי", "name_en": "Omer Mizrahi"},
	{"name": "מאיה פרץ", "name_en": "Maya Peretz"},
	{"name": "איתי ביטון", "name_en": "Itay Biton"},
	{"name": "שירה אברהם", "name_en": "Shira Avraham"},
	{"name": "דניאל פרידמן", "name_en": "Daniel Friedman"},
	{"name": "תמר אזולאי", "name_en": "Tamar Azulay"},
	{"name": "אורי שפירא", "name_en": "Uri Shapira"},
	{"name": "רוני גבאי", "name_en": "Roni Gabay"},
]

## Championship points for positions 1..8.
const POINTS := [25, 18, 15, 12, 10, 8, 6, 4]

const DIFFICULTIES := ["easy", "medium", "hard"]


static func bike(id: String) -> Dictionary:
	return BIKES.get(id, BIKES["naked"])


static func paint_color(idx: int) -> Color:
	return PAINTS[clampi(idx, 0, PAINTS.size() - 1)]["color"]


static func points_for(position: int) -> int:
	## position is 1-based.
	if position < 1 or position > POINTS.size():
		return 0
	return POINTS[position - 1]


static func rider_name(idx: int) -> String:
	var r: Dictionary = AI_RIDERS[idx % AI_RIDERS.size()]
	return r["name"] if TranslationServer.get_locale().begins_with("he") else r["name_en"]


static func format_time(t: float) -> String:
	if t <= 0.0 or is_inf(t) or is_nan(t):
		return "--:--.---"
	var total_ms := int(round(t * 1000.0))
	var m := total_ms / 60000
	var s := (total_ms / 1000) % 60
	var ms := total_ms % 1000
	return "%d:%02d.%03d" % [m, s, ms]

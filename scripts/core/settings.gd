extends Node
## Global user settings: graphics, display, audio, language.
## Persisted to user://settings.cfg. Controls (key bindings) live in the Controls autoload.

signal changed(key: String)

const PATH := "user://settings.cfg"
const PRESETS := ["low", "medium", "high", "ultra"]

## Per-preset graphics values. Individual toggles start from these values
## and can then be overridden by the player.
const PRESET_VALUES := {
	"low": {
		"shadows": 1, "ssao": false, "ssil": false, "sdfgi": false, "volumetric_fog": false,
		"glow": true, "motion_blur": false, "heat_haze": false, "particles": 1,
		"aa": "fxaa", "render_scale": 0.77, "draw_distance": 0, "vegetation": 0,
	},
	"medium": {
		"shadows": 2, "ssao": true, "ssil": false, "sdfgi": false, "volumetric_fog": false,
		"glow": true, "motion_blur": true, "heat_haze": true, "particles": 1,
		"aa": "taa", "render_scale": 1.0, "draw_distance": 1, "vegetation": 1,
	},
	"high": {
		"shadows": 2, "ssao": true, "ssil": true, "sdfgi": false, "volumetric_fog": true,
		"glow": true, "motion_blur": true, "heat_haze": true, "particles": 2,
		"aa": "taa", "render_scale": 1.0, "draw_distance": 2, "vegetation": 2,
	},
	"ultra": {
		"shadows": 3, "ssao": true, "ssil": true, "sdfgi": true, "volumetric_fog": true,
		"glow": true, "motion_blur": true, "heat_haze": true, "particles": 2,
		"aa": "fsr2", "render_scale": 1.0, "draw_distance": 3, "vegetation": 2,
	},
}

const DEFAULTS := {
	"preset": "high",
	"window_mode": "fullscreen", # windowed | fullscreen | exclusive
	"resolution": "1920x1080",
	"vsync": true,
	"fps_cap": 0,
	"master_volume": 0.9,
	"music_volume": 0.6,
	"sfx_volume": 0.9,
	"engine_volume": 0.85,
	"ui_volume": 0.8,
	"language": "he",
	"units": "kmh",
	"camera": 0,
	"show_minimap": true,
	"vibration": true,
}

var data: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_all()


func reset_to_defaults() -> void:
	data = DEFAULTS.duplicate(true)
	for k in PRESET_VALUES["high"]:
		data[k] = PRESET_VALUES["high"][k]


func load_settings() -> void:
	reset_to_defaults()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in cfg.get_section_keys("settings") if cfg.has_section("settings") else []:
		var v = cfg.get_value("settings", key)
		if data.has(key) and typeof(v) == typeof(data[key]):
			data[key] = v
		elif data.has(key) and typeof(data[key]) == TYPE_FLOAT and typeof(v) == TYPE_INT:
			data[key] = float(v)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in data:
		cfg.set_value("settings", key, data[key])
	cfg.save(PATH)


func get_value(key: String, fallback = null):
	return data.get(key, fallback)


func set_value(key: String, value, persist := true) -> void:
	data[key] = value
	_apply_key(key)
	if persist:
		save_settings()
	changed.emit(key)


func apply_preset(preset: String) -> void:
	if not PRESET_VALUES.has(preset):
		return
	data["preset"] = preset
	for k in PRESET_VALUES[preset]:
		data[k] = PRESET_VALUES[preset][k]
	save_settings()
	apply_all()
	changed.emit("preset")


func apply_all() -> void:
	for key in ["window_mode", "vsync", "fps_cap", "language", "master_volume", "music_volume", "sfx_volume", "engine_volume", "ui_volume"]:
		_apply_key(key)


func _apply_key(key: String) -> void:
	match key:
		"window_mode", "resolution":
			_apply_window()
		"vsync":
			if DisplayServer.get_name() != "headless":
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if data["vsync"] else DisplayServer.VSYNC_DISABLED)
		"fps_cap":
			Engine.max_fps = int(data["fps_cap"])
		"language":
			TranslationServer.set_locale(data["language"])
		"master_volume", "music_volume", "sfx_volume", "engine_volume", "ui_volume":
			var bus_name: String = {"master_volume": "Master", "music_volume": "Music", "sfx_volume": "SFX", "engine_volume": "Engine", "ui_volume": "UI"}[key]
			var idx := AudioServer.get_bus_index(bus_name)
			if idx >= 0:
				var lin: float = clampf(float(data[key]), 0.0, 1.0)
				AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(lin, 0.0001)))
				AudioServer.set_bus_mute(idx, lin <= 0.001)


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var win := get_window()
	match data["window_mode"]:
		"fullscreen":
			win.mode = Window.MODE_FULLSCREEN
		"exclusive":
			win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		_:
			win.mode = Window.MODE_WINDOWED
			var parts: PackedStringArray = String(data["resolution"]).split("x")
			if parts.size() == 2:
				var size := Vector2i(int(parts[0]), int(parts[1]))
				var screen := DisplayServer.screen_get_size()
				size = Vector2i(mini(size.x, screen.x), mini(size.y, screen.y))
				win.size = size
				win.position = (screen - size) / 2


func is_rtl() -> bool:
	return String(data.get("language", "he")) == "he"


func speed_factor() -> float:
	## Converts m/s into the display unit.
	return 3.6 if data.get("units", "kmh") == "kmh" else 2.23694

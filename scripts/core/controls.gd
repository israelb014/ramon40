extends Node
## Input actions for up to two local players, with keyboard + Xbox-layout gamepad defaults
## and full rebinding persisted to user://controls.cfg.
##
## Each binding is described by a small dictionary so it can be saved as text:
##   {"type": "key", "code": KEY_W}
##   {"type": "button", "code": JOY_BUTTON_A}
##   {"type": "axis", "code": JOY_AXIS_LEFT_X, "dir": -1}

const PATH := "user://controls.cfg"

## Actions every player has, in the order shown in the rebinding screen.
const PLAYER_ACTIONS := ["accelerate", "brake", "rear_brake", "steer_left", "steer_right", "tuck", "camera", "look_back", "respawn"]

const DEFAULTS := {
	"p1": {
		"accelerate": [{"type": "key", "code": KEY_W}, {"type": "axis", "code": JOY_AXIS_TRIGGER_RIGHT, "dir": 1}],
		"brake": [{"type": "key", "code": KEY_S}, {"type": "axis", "code": JOY_AXIS_TRIGGER_LEFT, "dir": 1}],
		"rear_brake": [{"type": "key", "code": KEY_SPACE}, {"type": "button", "code": JOY_BUTTON_RIGHT_SHOULDER}],
		"steer_left": [{"type": "key", "code": KEY_A}, {"type": "axis", "code": JOY_AXIS_LEFT_X, "dir": -1}],
		"steer_right": [{"type": "key", "code": KEY_D}, {"type": "axis", "code": JOY_AXIS_LEFT_X, "dir": 1}],
		"tuck": [{"type": "key", "code": KEY_SHIFT}, {"type": "button", "code": JOY_BUTTON_A}],
		"camera": [{"type": "key", "code": KEY_C}, {"type": "button", "code": JOY_BUTTON_Y}],
		"look_back": [{"type": "key", "code": KEY_Q}, {"type": "button", "code": JOY_BUTTON_LEFT_SHOULDER}],
		"respawn": [{"type": "key", "code": KEY_R}, {"type": "button", "code": JOY_BUTTON_BACK}],
	},
	"p2": {
		"accelerate": [{"type": "key", "code": KEY_UP}, {"type": "axis", "code": JOY_AXIS_TRIGGER_RIGHT, "dir": 1}],
		"brake": [{"type": "key", "code": KEY_DOWN}, {"type": "axis", "code": JOY_AXIS_TRIGGER_LEFT, "dir": 1}],
		"rear_brake": [{"type": "key", "code": KEY_CTRL}, {"type": "button", "code": JOY_BUTTON_RIGHT_SHOULDER}],
		"steer_left": [{"type": "key", "code": KEY_LEFT}, {"type": "axis", "code": JOY_AXIS_LEFT_X, "dir": -1}],
		"steer_right": [{"type": "key", "code": KEY_RIGHT}, {"type": "axis", "code": JOY_AXIS_LEFT_X, "dir": 1}],
		"tuck": [{"type": "key", "code": KEY_ENTER}, {"type": "button", "code": JOY_BUTTON_A}],
		"camera": [{"type": "key", "code": KEY_SLASH}, {"type": "button", "code": JOY_BUTTON_Y}],
		"look_back": [{"type": "key", "code": KEY_PERIOD}, {"type": "button", "code": JOY_BUTTON_LEFT_SHOULDER}],
		"respawn": [{"type": "key", "code": KEY_BACKSPACE}, {"type": "button", "code": JOY_BUTTON_BACK}],
	},
}

const DEADZONE := 0.12

var bindings: Dictionary = {}
var _rumble_ok := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_bindings()
	_register_global_actions()


func _register_global_actions() -> void:
	_ensure_action("pause")
	InputMap.action_erase_events("pause")
	var k := InputEventKey.new()
	k.physical_keycode = KEY_ESCAPE
	InputMap.action_add_event("pause", k)
	var k2 := InputEventKey.new()
	k2.physical_keycode = KEY_P
	InputMap.action_add_event("pause", k2)
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_START
	b.device = -1
	InputMap.action_add_event("pause", b)
	# Gamepad B acts as "back" in menus.
	_ensure_action("ui_back")
	InputMap.action_erase_events("ui_back")
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_B
	back.device = -1
	InputMap.action_add_event("ui_back", back)
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	InputMap.action_add_event("ui_back", esc)
	var bs := InputEventKey.new()
	bs.physical_keycode = KEY_BACKSPACE
	InputMap.action_add_event("ui_back", bs)


func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, DEADZONE)


func action_name(player: String, action: String) -> String:
	return "%s_%s" % [player, action]


func load_bindings() -> void:
	bindings = DEFAULTS.duplicate(true)
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for player in bindings:
			for action in PLAYER_ACTIONS:
				var v = cfg.get_value(player, action, null)
				if typeof(v) == TYPE_ARRAY and _valid_list(v):
					bindings[player][action] = v
	apply_bindings()


func _valid_list(list: Array) -> bool:
	for e in list:
		if typeof(e) != TYPE_DICTIONARY or not e.has("type") or not e.has("code"):
			return false
	return true


func save_bindings() -> void:
	var cfg := ConfigFile.new()
	for player in bindings:
		for action in bindings[player]:
			cfg.set_value(player, action, bindings[player][action])
	cfg.save(PATH)


func reset_defaults() -> void:
	bindings = DEFAULTS.duplicate(true)
	apply_bindings()
	save_bindings()


func apply_bindings() -> void:
	for player in bindings:
		var device := 0 if player == "p1" else 1
		for action in PLAYER_ACTIONS:
			var name := action_name(player, action)
			_ensure_action(name)
			InputMap.action_set_deadzone(name, DEADZONE)
			InputMap.action_erase_events(name)
			for b in bindings[player][action]:
				var ev := binding_to_event(b, device)
				if ev:
					InputMap.action_add_event(name, ev)


static func binding_to_event(b: Dictionary, device: int) -> InputEvent:
	match b.get("type", ""):
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = int(b["code"])
			return k
		"button":
			var jb := InputEventJoypadButton.new()
			jb.button_index = int(b["code"])
			jb.device = device
			return jb
		"axis":
			var ja := InputEventJoypadMotion.new()
			ja.axis = int(b["code"])
			ja.axis_value = float(b.get("dir", 1))
			ja.device = device
			return ja
	return null


## Converts a raw input event into a binding dictionary (used by the rebinding screen).
static func event_to_binding(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey and ev.pressed:
		var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		return {"type": "key", "code": code}
	if ev is InputEventJoypadButton and ev.pressed:
		return {"type": "button", "code": ev.button_index}
	if ev is InputEventJoypadMotion and absf(ev.axis_value) > 0.6:
		return {"type": "axis", "code": ev.axis, "dir": signi(int(signf(ev.axis_value)))}
	return {}


## Replaces the keyboard (slot 0) or gamepad (slot 1) binding of an action.
func rebind(player: String, action: String, binding: Dictionary) -> void:
	var list: Array = bindings[player][action]
	var is_key: bool = binding["type"] == "key"
	var replaced := false
	for i in list.size():
		if (list[i]["type"] == "key") == is_key:
			list[i] = binding
			replaced = true
			break
	if not replaced:
		list.append(binding)
	apply_bindings()
	save_bindings()


func binding_for(player: String, action: String, keyboard: bool) -> Dictionary:
	for b in bindings[player][action]:
		if (b["type"] == "key") == keyboard:
			return b
	return {}


static func binding_label(b: Dictionary) -> String:
	if b.is_empty():
		return "—"
	match b["type"]:
		"key":
			return OS.get_keycode_string(int(b["code"]))
		"button":
			var names := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
				JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_BACK: "View",
				JOY_BUTTON_START: "Menu", JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
				JOY_BUTTON_DPAD_UP: "D-Up", JOY_BUTTON_DPAD_DOWN: "D-Down", JOY_BUTTON_DPAD_LEFT: "D-Left",
				JOY_BUTTON_DPAD_RIGHT: "D-Right", JOY_BUTTON_GUIDE: "Guide"}
			return names.get(int(b["code"]), "Btn %d" % int(b["code"]))
		"axis":
			var axis := int(b["code"])
			var d := int(b.get("dir", 1))
			match axis:
				JOY_AXIS_LEFT_X: return "LS Left" if d < 0 else "LS Right"
				JOY_AXIS_LEFT_Y: return "LS Up" if d < 0 else "LS Down"
				JOY_AXIS_RIGHT_X: return "RS Left" if d < 0 else "RS Right"
				JOY_AXIS_RIGHT_Y: return "RS Up" if d < 0 else "RS Down"
				JOY_AXIS_TRIGGER_LEFT: return "LT"
				JOY_AXIS_TRIGGER_RIGHT: return "RT"
			return "Axis %d" % axis
	return "?"


## Reads the driving input for a player. `players` is the list of player prefixes to merge
## (single-player merges p1 and p2 so every keyboard layout and pad works).
func read_drive(players: Array) -> Dictionary:
	var out := {"throttle": 0.0, "brake": 0.0, "rear_brake": 0.0, "steer": 0.0, "tuck": false}
	for p in players:
		out["throttle"] = maxf(out["throttle"], Input.get_action_strength(action_name(p, "accelerate")))
		out["brake"] = maxf(out["brake"], Input.get_action_strength(action_name(p, "brake")))
		out["rear_brake"] = maxf(out["rear_brake"], Input.get_action_strength(action_name(p, "rear_brake")))
		var s := Input.get_action_strength(action_name(p, "steer_right")) - Input.get_action_strength(action_name(p, "steer_left"))
		if absf(s) > absf(out["steer"]):
			out["steer"] = s
		out["tuck"] = out["tuck"] or Input.is_action_pressed(action_name(p, "tuck"))
	return out


func just_pressed(players: Array, action: String) -> bool:
	for p in players:
		if Input.is_action_just_pressed(action_name(p, action)):
			return true
	return false


func pressed(players: Array, action: String) -> bool:
	for p in players:
		if Input.is_action_pressed(action_name(p, action)):
			return true
	return false


func rumble(player_index: int, weak: float, strong: float, duration: float) -> void:
	if not Settings.get_value("vibration", true):
		return
	var pads := Input.get_connected_joypads()
	if player_index < pads.size():
		Input.start_joy_vibration(pads[player_index], weak, strong, duration)

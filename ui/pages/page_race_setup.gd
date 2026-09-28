class_name PageRaceSetup
extends MenuPage
## Race setup for Quick Race, Time Trial and local split-screen.

var mode := "quick"
var _track_row: OptionRow
var _bike_row: OptionRow
var _bike2_row: OptionRow
var _laps_row: OptionRow
var _diff_row: OptionRow
var _opp_row: OptionRow
var _ghost_row: OptionRow
var _art: TrackArt
var _track_name: Label
var _track_sub: Label
var _record: Label
var _stats: Array = []
var _bike_name: Label
var _start: Button


static func create(p_mode: String) -> PageRaceSetup:
	var p := PageRaceSetup.new()
	p.mode = p_mode
	return p


func _ready() -> void:
	var titles := {"quick": "MENU_QUICK_RACE", "time_trial": "MENU_TIME_TRIAL", "split": "MENU_SPLIT"}
	var subs := {"quick": "SETUP_QUICK_SUB", "time_trial": "SETUP_TT_SUB", "split": "SETUP_SPLIT_SUB"}
	var v := make_frame(tr(titles[mode]), tr(subs[mode]))
	var row := Widgets.hbox(36)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)

	# Options card (reading side).
	var opts := Widgets.card(Vector2(820, 0))
	row.add_child(opts)
	var ov := Widgets.vbox(12)
	opts.add_child(ov)
	var controls: Array = []
	var track_opts := []
	for id in GameData.TRACK_ORDER:
		track_opts.append({"text": tr(GameData.TRACKS[id]["name"]), "value": id})
	var last_track: String = Save.progress.get("last_track", "ramon")
	_track_row = OptionRow.make(tr("SETUP_TRACK"), track_opts, maxi(GameData.TRACK_ORDER.find(last_track), 0), "road")
	_track_row.changed.connect(func(_i, _v): _refresh_preview())
	ov.add_child(_track_row)
	controls.append(_track_row)
	_bike_row = _make_bike_row(tr("SETUP_BIKE") if mode != "split" else tr("SETUP_BIKE_P1"), Save.progress.get("selected_bike", "naked"))
	ov.add_child(_bike_row)
	controls.append(_bike_row)
	if mode == "split":
		_bike2_row = _make_bike_row(tr("SETUP_BIKE_P2"), "supermoto")
		ov.add_child(_bike2_row)
		controls.append(_bike2_row)
	var laps_opts := []
	var max_laps := 10 if mode == "time_trial" else 5
	for n in range(1, max_laps + 1):
		laps_opts.append({"text": tr("LAP_1") if n == 1 else tr("LAPS_N") % n, "value": n})
	_laps_row = OptionRow.make(tr("SETUP_LAPS"), laps_opts, 2, "flag")
	_laps_row.wrap = false
	_laps_row.changed.connect(func(_i, _v): set_meta("laps_touched", true))
	ov.add_child(_laps_row)
	controls.append(_laps_row)
	if mode != "time_trial":
		var diff_opts := []
		for d in GameData.DIFFICULTIES:
			diff_opts.append({"text": tr("DIFF_" + d.to_upper()), "value": d})
		_diff_row = OptionRow.make(tr("SETUP_DIFFICULTY"), diff_opts, maxi(GameData.DIFFICULTIES.find(String(Save.progress.get("last_difficulty", "medium"))), 0), "star")
		ov.add_child(_diff_row)
		controls.append(_diff_row)
	if mode == "split":
		var opp := []
		for n in range(0, 7):
			opp.append({"text": str(n), "value": n})
		_opp_row = OptionRow.make(tr("SETUP_OPPONENTS"), opp, 4, "users")
		_opp_row.wrap = false
		ov.add_child(_opp_row)
		controls.append(_opp_row)
	if mode == "time_trial":
		_ghost_row = OptionRow.make(tr("SETUP_GHOST"), [{"text": tr("ON"), "value": true}, {"text": tr("OFF"), "value": false}], 0, "replay")
		ov.add_child(_ghost_row)
		controls.append(_ghost_row)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ov.add_child(filler)
	if mode == "split":
		var note := UITheme.body(tr("SETUP_SPLIT_NOTE"), 24, UITheme.MUTED)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ov.add_child(note)
	_start = Widgets.button(tr("SETUP_START"), "play", true, 36)
	_start.custom_minimum_size = Vector2(0, 86)
	_start.pressed.connect(_on_start)
	ov.add_child(_start)
	controls.append(_start)
	Widgets.link_focus(controls)
	_focus_first = _track_row

	# Preview card.
	var prev := Widgets.card()
	prev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(prev)
	var pv := Widgets.vbox(10)
	prev.add_child(pv)
	var art_holder := _RoundedClip.new()
	art_holder.custom_minimum_size = Vector2(0, 360)
	pv.add_child(art_holder)
	_art = TrackArt.new()
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art_holder.add_child(_art)
	_track_name = UITheme.heading("", 86)
	pv.add_child(_track_name)
	_track_sub = UITheme.body("", 26, UITheme.MUTED)
	_track_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv.add_child(_track_sub)
	_record = UITheme.body("", 26, UITheme.GOLD, 700)
	pv.add_child(_record)
	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", UITheme.pill_style(Color(1, 1, 1, 0.08), 2))
	pv.add_child(sep)
	_bike_name = UITheme.body("", 30, UITheme.TEXT, 700)
	pv.add_child(_bike_name)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 6)
	pv.add_child(grid)
	for key in ["speed", "accel", "handling", "braking"]:
		var sb := StatBar.make(tr("STAT_" + key.to_upper()), 0)
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(sb)
		_stats.append(sb)
	_bike_row.changed.connect(func(_i, _v): _refresh_preview())
	_refresh_preview()
	Widgets.animate_in(opts, 0.05)
	Widgets.animate_in(prev, 0.12)


func _make_bike_row(label: String, selected: String) -> OptionRow:
	var opts := []
	var sel := 0
	for i in GameData.BIKE_ORDER.size():
		var id: String = GameData.BIKE_ORDER[i]
		opts.append({"text": tr(GameData.BIKES[id]["name"]), "value": id, "locked": not Save.is_bike_unlocked(id)})
		if id == selected:
			sel = i
	return OptionRow.make(label, opts, sel, "bike")


func _refresh_preview() -> void:
	var tid: String = _track_row.value()
	var info: Dictionary = GameData.TRACKS[tid]
	_art.track_id = tid
	_art.queue_redraw()
	_track_name.text = tr(info["name"])
	_track_sub.text = "%s  ·  %s" % [tr(info["road"]), tr(info["subtitle"])]
	var best := Save.best_lap(tid)
	_record.text = "%s  %s" % [tr("RESULTS_TRACK_RECORD"), "\u200e" + GameData.format_time(best)] if best > 0.0 else tr("SETUP_NO_RECORD")
	if _laps_row and mode != "time_trial" and not has_meta("laps_touched"):
		_laps_row.set_index(int(info.get("default_laps", 2)) - 1)
	var bid: String = _bike_row.value()
	var ratings: Dictionary = GameData.BIKES[bid]["ratings"]
	var keys := ["speed", "accel", "handling", "braking"]
	for i in 4:
		_stats[i].set_value(float(ratings[keys[i]]))
	_bike_name.text = tr(GameData.BIKES[bid]["name"]) + ("   " + tr("LOCKED") if _bike_row.is_locked() else "")
	var locked := _bike_row.is_locked() or (_bike2_row != null and _bike2_row.is_locked())
	_start.disabled = locked
	_start.text = tr("SETUP_LOCKED_BIKE") if locked else tr("SETUP_START")


func _on_start() -> void:
	if _start.disabled:
		return
	var tid: String = _track_row.value()
	var bid: String = _bike_row.value()
	Save.progress["selected_bike"] = bid
	Save.progress["last_track"] = tid
	if _diff_row:
		Save.progress["last_difficulty"] = _diff_row.value()
	Save.save_progress()
	var cfg := Game.default_config()
	cfg["mode"] = mode
	cfg["track"] = tid
	cfg["laps"] = int(_laps_row.value())
	cfg["difficulty"] = _diff_row.value() if _diff_row else "medium"
	cfg["players"] = [{"bike": bid, "name": Game.player_name()}]
	match mode:
		"time_trial":
			cfg["opponents"] = 0
			cfg["ghost"] = bool(_ghost_row.value())
		"split":
			cfg["players"] = [{"bike": bid, "name": tr("PLAYER_1")}, {"bike": _bike2_row.value(), "name": tr("PLAYER_2"), "paint": 5, "accent": 1, "suit_main": 1, "suit_accent": 5}]
			cfg["opponents"] = int(_opp_row.value())
		_:
			cfg["opponents"] = 7
	Game.start_race(cfg)


class _RoundedClip extends PanelContainer:
	func _ready() -> void:
		clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color.WHITE
		sb.set_corner_radius_all(UITheme.RADIUS_SMALL)
		sb.corner_detail = 10
		add_theme_stylebox_override("panel", sb)

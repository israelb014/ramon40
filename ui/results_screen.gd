class_name ResultsScreen
extends Control
## Post-race results: finishing order with times and gaps, best laps, and next actions.

var race: Race
var _buttons: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.theme()
	Widgets.apply_direction(self)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.04, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 70)
	add_child(margin)
	var root := Widgets.hbox(36)
	margin.add_child(root)
	# Results table card.
	var table_card := Widgets.card()
	table_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table_card.size_flags_stretch_ratio = 2.2
	root.add_child(table_card)
	var tv := Widgets.vbox(6)
	table_card.add_child(tv)
	var cfg: Dictionary = race.config
	var title := UITheme.heading(tr("RESULTS_TITLE"), 104)
	tv.add_child(title)
	var track_name := tr(GameData.TRACKS.get(race.track.id, {}).get("name", ""))
	tv.add_child(UITheme.body("%s  ·  %s  ·  %s" % [track_name, tr("LAPS_N") % race.progress.total_laps, tr("DIFF_" + String(cfg.get("difficulty", "medium")).to_upper())], 28, UITheme.MUTED))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 14)
	tv.add_child(sp)
	tv.add_child(_row(["#", tr("RESULTS_RIDER"), tr("RESULTS_BIKE"), tr("RESULTS_TIME"), tr("RESULTS_BEST")], true, false, 0))
	var winner_time := 0.0
	var i := 0
	for r in race.results:
		if i == 0:
			winner_time = r["time"]
		var time_text := GameData.format_time(r["time"]) if i == 0 else ("+" + _gap(r["time"] - winner_time))
		if r.get("estimated", false):
			time_text = tr("RESULTS_DNF") if race.config.get("mode", "") == "time_trial" else "~" + time_text
		# Keep numeric strings left-to-right inside the RTL layout.
		time_text = "\u200e" + time_text + "\u200e"
		var row := _row(["%d" % r["position"], r["name"], tr(GameData.bike(r["bike"])["name"]), time_text, GameData.format_time(r["best_lap"])], false, r["is_player"], i)
		tv.add_child(row)
		Widgets.animate_in(row, 0.05 * i)
		i += 1
	# Side card: player summary + actions.
	var side := Widgets.card(Vector2(520, 0))
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(side)
	var sv := Widgets.vbox(16)
	side.add_child(sv)
	var me: Dictionary = {}
	for r in race.results:
		if r["is_player"]:
			me = r
			break
	if not me.is_empty():
		var badge := _PositionBadge.new()
		badge.position_value = me["position"]
		badge.custom_minimum_size = Vector2(0, 230)
		sv.add_child(badge)
		var msg_key := "RESULTS_WIN" if me["position"] == 1 else ("RESULTS_PODIUM" if me["position"] <= 3 else "RESULTS_FINISHED")
		var msg := UITheme.heading(tr(msg_key), 64, UITheme.GOLD if me["position"] <= 3 else UITheme.TEXT)
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sv.add_child(msg)
		var best := Save.best_lap(race.track.id)
		var info := UITheme.body("%s  %s" % [tr("RESULTS_TRACK_RECORD"), GameData.format_time(best)], 26, UITheme.MUTED)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sv.add_child(info)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sv.add_child(filler)
	var mode: String = cfg.get("mode", "quick")
	if mode == "championship":
		_add_button(sv, tr("RESULTS_STANDINGS"), "trophy", true, func(): Game.championship_after_race())
	else:
		_add_button(sv, tr("RESULTS_CONTINUE"), "arrow_right", true, func(): Game.go_to_menu(Game.menu_page_for_mode(mode)))
	_add_button(sv, tr("RESULTS_REPLAY"), "replay", false, func(): race.start_replay())
	if mode != "championship" and mode != "online":
		_add_button(sv, tr("PAUSE_RESTART"), "restart", false, func(): race.restart())
	if mode != "championship":
		_add_button(sv, tr("PAUSE_QUIT"), "home", false, func(): Game.go_to_menu(""))
	Widgets.link_focus(_buttons)
	Widgets.animate_in(side, 0.2)
	refocus()


func refocus() -> void:
	await get_tree().process_frame
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


func _add_button(parent: Control, text: String, icon_name: String, primary: bool, cb: Callable) -> void:
	var b := Widgets.button(text, icon_name, primary)
	b.pressed.connect(cb)
	parent.add_child(b)
	_buttons.append(b)


func _gap(t: float) -> String:
	if t < 60.0:
		return "%.3f" % t
	return GameData.format_time(t)


func _row(cols: Array, header: bool, highlight: bool, idx: int) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(UITheme.RADIUS_SMALL)
	sb.bg_color = Color(UITheme.ACCENT, 0.28) if highlight else (Color(1, 1, 1, 0.035) if idx % 2 == 0 and not header else Color(0, 0, 0, 0))
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	var h := Widgets.hbox(10)
	panel.add_child(h)
	var widths := [70, 0, 250, 190, 170]
	for c in cols.size():
		var l := UITheme.body(String(cols[c]), 24 if header else 30, UITheme.MUTED if header else (Color.WHITE if highlight else UITheme.TEXT), 700 if (highlight or c == 0) else 500)
		if widths[c] > 0:
			l.custom_minimum_size = Vector2(widths[c], 0)
		else:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if c == 0 and not header:
			l.add_theme_font_override("font", UITheme.heading_font())
			l.add_theme_font_size_override("font_size", 40)
			l.add_theme_color_override("font_color", UITheme.GOLD if idx < 3 else UITheme.TEXT)
		l.clip_text = true
		h.add_child(l)
	return panel


class _PositionBadge extends Control:
	var position_value := 1
	var _t := 0.0

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		var r := minf(size.y * 0.45, 100.0)
		var col := UITheme.GOLD if position_value == 1 else (Color(0.8, 0.82, 0.86) if position_value == 2 else (Color(0.8, 0.5, 0.3) if position_value == 3 else UITheme.ACCENT))
		draw_circle(c, r + 14.0, Color(col, 0.12))
		var k := clampf(_t / 0.9, 0.0, 1.0)
		k = 1.0 - pow(1.0 - k, 3.0)
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * k, 96, col, 10.0, true)
		var hf := UITheme.heading_font()
		var text := str(position_value)
		var fs := int(r * 1.5)
		var w := hf.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(hf, c + Vector2(-w * 0.5, fs * 0.33), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.TEXT)

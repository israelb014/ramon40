class_name PageChampionship
extends MenuPage
## Championship hub: setup, standings between rounds, final podium and rewards.

var _bike_row: OptionRow
var _diff_row: OptionRow


func _ready() -> void:
	var st: Dictionary = Save.progress.get("championship", {})
	if st.is_empty() or (not st.get("active", false) and not st.get("complete", false)):
		_build_setup()
	else:
		_build_standings(st)


func _build_setup() -> void:
	var v := make_frame(tr("MENU_CHAMPIONSHIP"), tr("CHAMP_SUB"))
	var row := Widgets.hbox(36)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	var card := Widgets.card(Vector2(820, 0))
	row.add_child(card)
	var cv := Widgets.vbox(12)
	card.add_child(cv)
	var opts := []
	var sel := 0
	for i in GameData.BIKE_ORDER.size():
		var id: String = GameData.BIKE_ORDER[i]
		opts.append({"text": tr(GameData.BIKES[id]["name"]), "value": id, "locked": not Save.is_bike_unlocked(id)})
		if id == Save.progress.get("selected_bike", "naked"):
			sel = i
	_bike_row = OptionRow.make(tr("SETUP_BIKE"), opts, sel, "bike")
	cv.add_child(_bike_row)
	var dopts := []
	for d in GameData.DIFFICULTIES:
		dopts.append({"text": tr("DIFF_" + d.to_upper()), "value": d})
	_diff_row = OptionRow.make(tr("SETUP_DIFFICULTY"), dopts, 1, "star")
	cv.add_child(_diff_row)
	var rules := UITheme.body(tr("CHAMP_RULES"), 26, UITheme.MUTED)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(rules)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.add_child(filler)
	var start := Widgets.button(tr("CHAMP_START"), "trophy", true, 36)
	start.custom_minimum_size = Vector2(0, 86)
	start.pressed.connect(func():
		if _bike_row.is_locked():
			return
		var st := Championship.create(_bike_row.value(), _diff_row.value(), Game.player_name())
		Save.progress["championship"] = st
		Save.progress["selected_bike"] = _bike_row.value()
		Save.save_progress()
		Game.start_race(Championship.race_config(st)))
	cv.add_child(start)
	Widgets.link_focus([_bike_row, _diff_row, start])
	_focus_first = _bike_row
	# Rounds preview.
	var rounds := Widgets.vbox(16)
	rounds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rounds)
	var i := 0
	for tid in Championship.ROUNDS:
		rounds.add_child(_round_card(i, tid, false, false))
		i += 1
	Widgets.animate_in(card, 0.05)


func _round_card(i: int, tid: String, done: bool, next: bool) -> Control:
	var c := Widgets.card(Vector2(0, 150), Color(0.1, 0.065, 0.11, 0.85) if not next else Color(0.2, 0.1, 0.12, 0.92))
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var h := Widgets.hbox(24)
	c.add_child(h)
	var art_clip: Control = PageRaceSetup._RoundedClip.new()
	art_clip.custom_minimum_size = Vector2(230, 120)
	h.add_child(art_clip)
	var art := TrackArt.new()
	art.track_id = tid
	art.animate = next
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art_clip.add_child(art)
	var tv := Widgets.vbox(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	tv.add_child(UITheme.body(tr("CHAMP_ROUND_N") % (i + 1), 24, UITheme.ACCENT if next else UITheme.MUTED, 700))
	tv.add_child(UITheme.heading(tr(GameData.TRACKS[tid]["name"]), 64))
	tv.add_child(UITheme.body(tr(GameData.TRACKS[tid]["road"]), 24, UITheme.MUTED))
	if done:
		h.add_child(Widgets.icon_rect("check", 48, UITheme.GOOD))
	return c


func _build_standings(st: Dictionary) -> void:
	var complete: bool = st.get("complete", false)
	var title := tr("CHAMP_FINAL") if complete else tr("CHAMP_STANDINGS")
	var round_i := int(st.get("round", 0))
	var v := make_frame(title, tr("CHAMP_AFTER_N") % round_i if round_i > 0 else tr("CHAMP_SUB"))
	var row := Widgets.hbox(36)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	# Standings table.
	var table := Widgets.card()
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.size_flags_stretch_ratio = 1.8
	row.add_child(table)
	var tv := Widgets.vbox(6)
	table.add_child(tv)
	tv.add_child(_standing_row(["#", tr("RESULTS_RIDER"), tr("RESULTS_BIKE"), "1", "2", "3", tr("CHAMP_POINTS")], true, false, 0))
	var order := Championship.standings(st)
	var k := 0
	for id in order:
		var r: Dictionary = st["riders"][id]
		var res: Array = r["results"]
		var cells := [str(k + 1), Championship.rider_name(st, id), tr(GameData.bike(r["bike"])["name"])]
		for n in 3:
			cells.append(str(res[n]) if n < res.size() else "-")
		cells.append(str(int(r["points"])))
		var line := _standing_row(cells, false, r.get("player", false), k)
		tv.add_child(line)
		Widgets.animate_in(line, 0.04 * k)
		k += 1
	# Side: next round or final result.
	var side := Widgets.card(Vector2(560, 0))
	row.add_child(side)
	var sv := Widgets.vbox(14)
	side.add_child(sv)
	var buttons: Array = []
	if complete:
		var rank := Championship.player_rank(st)
		var badge: Control = ResultsScreen._PositionBadge.new()
		badge.position_value = rank
		badge.custom_minimum_size = Vector2(0, 220)
		sv.add_child(badge)
		var msg := UITheme.heading(tr("CHAMP_CHAMPION") if rank == 1 else tr("CHAMP_COMPLETE"), 64, UITheme.GOLD if rank <= 3 else UITheme.TEXT)
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sv.add_child(msg)
	else:
		sv.add_child(_round_card(round_i, Championship.current_track(st), false, true))
	# Rewards from the last round.
	for g in st.get("rewards", []):
		var h := Widgets.hbox(12)
		if g["type"] == "bike":
			h.add_child(Widgets.icon_rect("bike", 36, UITheme.GOLD))
			h.add_child(UITheme.body(tr("REWARD_BIKE") % tr(GameData.bike(g["id"])["name"]), 26, UITheme.GOLD, 700))
		else:
			var sw := ColorRect.new()
			sw.color = GameData.paint_color(int(g["id"]))
			sw.custom_minimum_size = Vector2(36, 36)
			h.add_child(sw)
			h.add_child(UITheme.body(tr("REWARD_COLOR") % tr(GameData.PAINTS[int(g["id"])]["name"]), 26, UITheme.GOLD, 700))
		sv.add_child(h)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sv.add_child(filler)
	if complete:
		var again := Widgets.button(tr("CHAMP_NEW"), "restart", true)
		again.pressed.connect(func():
			Save.progress["championship"] = {}
			Save.save_progress()
			menu.replace_page(PageChampionship.new()))
		sv.add_child(again)
		buttons.append(again)
	else:
		var go := Widgets.button(tr("CHAMP_RACE_ROUND") % (round_i + 1), "play", true, 34)
		go.custom_minimum_size = Vector2(0, 86)
		go.pressed.connect(func(): Game.start_race(Championship.race_config(st)))
		sv.add_child(go)
		buttons.append(go)
		var quit := Widgets.button(tr("CHAMP_ABANDON"), "close")
		quit.pressed.connect(func():
			Save.progress["championship"] = {}
			Save.save_progress()
			menu.replace_page(PageChampionship.new()))
		sv.add_child(quit)
		buttons.append(quit)
	Widgets.link_focus(buttons)
	_focus_first = buttons[0]
	Widgets.animate_in(side, 0.15)


func _standing_row(cols: Array, header: bool, highlight: bool, idx: int) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(UITheme.RADIUS_SMALL)
	sb.bg_color = Color(UITheme.ACCENT, 0.28) if highlight else (Color(1, 1, 1, 0.035) if idx % 2 == 0 and not header else Color(0, 0, 0, 0))
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	var h := Widgets.hbox(8)
	panel.add_child(h)
	var widths := [60, 0, 200, 60, 60, 60, 110]
	for c in cols.size():
		var l := UITheme.body(String(cols[c]), 22 if header else 28, UITheme.MUTED if header else UITheme.TEXT, 700 if (highlight or c == 6) else 500)
		if widths[c] > 0:
			l.custom_minimum_size = Vector2(widths[c], 0)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if c >= 3 else HORIZONTAL_ALIGNMENT_LEFT
		else:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if c == 6 and not header:
			l.add_theme_font_override("font", UITheme.heading_font())
			l.add_theme_font_size_override("font_size", 40)
			l.add_theme_color_override("font_color", UITheme.GOLD if idx == 0 else UITheme.TEXT)
		l.clip_text = true
		h.add_child(l)
	return panel

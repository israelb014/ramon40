class_name PageOnline
extends MenuPage
## LAN / online lobby: host or join by IP, pick a bike, ready up; the host picks the track
## and starts the race. Empty grid slots are filled by AI riders.

var _ip: LineEdit
var _port: LineEdit
var _status: Label
var _connect_box: VBoxContainer
var _lobby_box: VBoxContainer
var _players_box: VBoxContainer
var _track_row: OptionRow
var _laps_row: OptionRow
var _diff_row: OptionRow
var _bike_row: OptionRow
var _ready_btn: Button
var _start_btn: Button
var _host_btn: Button
var _local_ips: Label


func _ready() -> void:
	var v := make_frame(tr("MENU_ONLINE"), tr("ONLINE_SUB"))
	var row := Widgets.hbox(36)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	# Connect card.
	var cc := Widgets.card(Vector2(700, 0))
	row.add_child(cc)
	_connect_box = Widgets.vbox(14)
	cc.add_child(_connect_box)
	_connect_box.add_child(UITheme.body(tr("NET_HOST_TITLE"), 30, UITheme.ACCENT, 700))
	var port_row := Widgets.hbox(12)
	port_row.add_child(UITheme.body(tr("NET_PORT"), 28, UITheme.TEXT))
	_port = LineEdit.new()
	_port.text = str(Net.DEFAULT_PORT)
	_port.custom_minimum_size = Vector2(200, 64)
	_port.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	port_row.add_child(_port)
	_connect_box.add_child(port_row)
	_host_btn = Widgets.button(tr("NET_HOST"), "globe", true)
	_host_btn.pressed.connect(_on_host)
	_connect_box.add_child(_host_btn)
	_local_ips = UITheme.body("", 24, UITheme.MUTED)
	_local_ips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_connect_box.add_child(_local_ips)
	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", UITheme.pill_style(Color(1, 1, 1, 0.08), 2))
	_connect_box.add_child(sep)
	_connect_box.add_child(UITheme.body(tr("NET_JOIN_TITLE"), 30, UITheme.ACCENT, 700))
	_ip = LineEdit.new()
	_ip.placeholder_text = tr("NET_IP_HINT")
	_ip.text = String(Save.progress.get("last_ip", "127.0.0.1"))
	_ip.custom_minimum_size = Vector2(0, 64)
	_ip.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_connect_box.add_child(_ip)
	var join := Widgets.button(tr("NET_JOIN"), "arrow_right")
	join.pressed.connect(_on_join)
	_connect_box.add_child(join)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_connect_box.add_child(filler)
	_status = UITheme.body("", 26, UITheme.GOLD, 700)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_connect_box.add_child(_status)
	Widgets.link_focus([_host_btn, _ip, join])
	_focus_first = _host_btn

	# Lobby card.
	var lc := Widgets.card()
	lc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lc)
	_lobby_box = Widgets.vbox(12)
	lc.add_child(_lobby_box)
	_lobby_box.add_child(UITheme.body(tr("NET_LOBBY"), 30, UITheme.ACCENT, 700))
	_players_box = Widgets.vbox(8)
	_lobby_box.add_child(_players_box)
	var track_opts := []
	for id in GameData.TRACK_ORDER:
		track_opts.append({"text": tr(GameData.TRACKS[id]["name"]), "value": id})
	_track_row = OptionRow.make(tr("SETUP_TRACK"), track_opts, 0, "road")
	_lobby_box.add_child(_track_row)
	var laps := []
	for n in range(1, 6):
		laps.append({"text": tr("LAP_1") if n == 1 else tr("LAPS_N") % n, "value": n})
	_laps_row = OptionRow.make(tr("SETUP_LAPS"), laps, 1, "flag")
	_lobby_box.add_child(_laps_row)
	var diffs := []
	for d in GameData.DIFFICULTIES:
		diffs.append({"text": tr("DIFF_" + d.to_upper()), "value": d})
	_diff_row = OptionRow.make(tr("SETUP_DIFFICULTY"), diffs, 1, "star")
	_lobby_box.add_child(_diff_row)
	for r in [_track_row, _laps_row, _diff_row]:
		r.changed.connect(func(_i, _v): _push_settings())
	var bikes := []
	var sel := 0
	for i in GameData.BIKE_ORDER.size():
		var id: String = GameData.BIKE_ORDER[i]
		bikes.append({"text": tr(GameData.BIKES[id]["name"]), "value": id, "locked": not Save.is_bike_unlocked(id)})
		if id == Save.progress.get("selected_bike", "naked"):
			sel = i
	_bike_row = OptionRow.make(tr("SETUP_BIKE"), bikes, sel, "bike")
	_bike_row.changed.connect(func(_i, _v): _push_info())
	_lobby_box.add_child(_bike_row)
	var note := UITheme.body(tr("NET_AI_NOTE"), 24, UITheme.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lobby_box.add_child(note)
	var f2 := Control.new()
	f2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lobby_box.add_child(f2)
	var btns := Widgets.hbox(12)
	_lobby_box.add_child(btns)
	_ready_btn = Widgets.button(tr("NET_READY"), "check")
	_ready_btn.toggle_mode = true
	_ready_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ready_btn.toggled.connect(func(_on): _push_info())
	btns.add_child(_ready_btn)
	_start_btn = Widgets.button(tr("SETUP_START"), "play", true)
	_start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_btn.pressed.connect(func(): Net.start_race())
	btns.add_child(_start_btn)
	var leave := Widgets.button(tr("NET_LEAVE"), "close")
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.pressed.connect(_on_leave)
	btns.add_child(leave)
	Net.lobby_changed.connect(_refresh)
	Net.connection_failed.connect(_on_failed)
	Net.session_ended.connect(_on_failed)
	_show_local_ips()
	_refresh()


func _exit_tree() -> void:
	if Net.lobby_changed.is_connected(_refresh):
		Net.lobby_changed.disconnect(_refresh)
		Net.connection_failed.disconnect(_on_failed)
		Net.session_ended.disconnect(_on_failed)


func on_exit() -> void:
	# Leaving the page from the menu ends any lobby session.
	Net.leave()


func _show_local_ips() -> void:
	var ips := []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254"):
			ips.append(a)
	_local_ips.text = tr("NET_YOUR_IP") % ("  ".join(ips) if not ips.is_empty() else "127.0.0.1")


func _on_host() -> void:
	var err := Net.host(int(_port.text))
	if err != OK:
		_status.text = tr("NET_ERR_HOST") % err
		Audio.play_ui("error")
	else:
		_status.text = tr("NET_HOSTING")
		_push_settings()
		_push_info()
	_refresh()


func _on_join() -> void:
	Save.progress["last_ip"] = _ip.text
	Save.save_progress()
	var err := Net.join(_ip.text, int(_port.text))
	_status.text = tr("NET_CONNECTING") if err == OK else tr("NET_ERR_CONNECT")
	_refresh()


func _on_leave() -> void:
	Net.leave()
	_status.text = ""
	_ready_btn.button_pressed = false
	_refresh()


func _on_failed(reason: String) -> void:
	_status.text = tr(reason)
	Audio.play_ui("error")
	_refresh()


func _push_settings() -> void:
	if Net.is_host:
		Net.set_lobby_settings({"track": _track_row.value(), "laps": int(_laps_row.value()), "difficulty": _diff_row.value()})


func _push_info() -> void:
	if not Net.is_online():
		return
	var info := Net.local_info()
	if not _bike_row.is_locked():
		info["bike"] = _bike_row.value()
		var paint := Save.get_paint(info["bike"])
		info["paint"] = paint["body"]
		info["accent"] = paint["accent"]
	info["ready"] = Net.is_host or _ready_btn.button_pressed
	Net.set_local_info(info)


func _refresh() -> void:
	var online := Net.is_online()
	for c in _players_box.get_children():
		c.queue_free()
	if not online:
		_players_box.add_child(UITheme.body(tr("NET_NOT_CONNECTED"), 26, UITheme.MUTED))
	else:
		var ids := Net.players.keys()
		ids.sort()
		for id in ids:
			var p: Dictionary = Net.players[id]
			var h := Widgets.hbox(12)
			h.add_child(Widgets.icon_rect("check" if p.get("ready", false) else "users", 32, UITheme.GOOD if p.get("ready", false) else UITheme.MUTED))
			var name := UITheme.body(String(p.get("name", "?")) + ("  (" + tr("NET_HOST_TAG") + ")" if int(id) == 1 else ""), 28, UITheme.TEXT, 700 if int(id) == Net.my_id() else 500)
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(name)
			h.add_child(UITheme.body(tr(GameData.bike(String(p.get("bike", "naked")))["name"]), 26, UITheme.MUTED))
			_players_box.add_child(h)
		var free_slots: int = Net.TOTAL_RIDERS - Net.players.size()
		_players_box.add_child(UITheme.body(tr("NET_AI_SLOTS") % free_slots, 24, UITheme.MUTED))
		if not Net.is_host:
			var s: Dictionary = Net.lobby_settings
			_track_row.set_index(maxi(GameData.TRACK_ORDER.find(String(s.get("track", "ramon"))), 0))
			_laps_row.set_index(int(s.get("laps", 2)) - 1)
			_diff_row.set_index(maxi(GameData.DIFFICULTIES.find(String(s.get("difficulty", "medium"))), 0))
			_status.text = tr("NET_CONNECTED")
	for r in [_track_row, _laps_row, _diff_row]:
		r.focus_mode = Control.FOCUS_ALL if Net.is_host else Control.FOCUS_NONE
		r.modulate.a = 1.0 if Net.is_host or not online else 0.6
	_bike_row.modulate.a = 1.0 if online else 0.6
	_ready_btn.visible = online and not Net.is_host
	_start_btn.visible = Net.is_host
	_start_btn.disabled = not Net.all_ready()
	_host_btn.disabled = online

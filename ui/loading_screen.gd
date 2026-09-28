extends Control
## Loading screen with the track illustration. Generates the track world on a worker thread
## while showing an animated progress ring and a rotating tip, then enters the race.

const TIPS := ["TIP_1", "TIP_2", "TIP_3", "TIP_4", "TIP_5", "TIP_6", "TIP_7", "TIP_8"]

var _task := -1
var _data: Dictionary = {}
var _track_id := "ramon"
var _done := false
var _t := 0.0
var _min_time := 1.2
var _ring: Control
var _tip: Label


func _ready() -> void:
	theme = UITheme.theme()
	Widgets.apply_direction(self)
	var cfg: Dictionary = Game.race_config if not Game.race_config.is_empty() else Game.default_config()
	_track_id = cfg.get("track", "ramon")
	var art := TrackArt.new()
	art.track_id = _track_id
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.04, 0.25)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 80)
	add_child(margin)
	var col := Widgets.vbox(0)
	margin.add_child(col)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var card := Widgets.card(Vector2(0, 0), Color(0.07, 0.045, 0.08, 0.78))
	col.add_child(card)
	var row := Widgets.hbox(40)
	card.add_child(row)
	var texts := Widgets.vbox(4)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	var info: Dictionary = GameData.TRACKS.get(_track_id, {})
	texts.add_child(UITheme.body(tr(info.get("road", "")), 30, UITheme.ACCENT, 700))
	texts.add_child(UITheme.heading(tr(info.get("name", "")), 130))
	texts.add_child(UITheme.body(tr(info.get("subtitle", "")), 32, UITheme.MUTED))
	_tip = UITheme.body(tr(TIPS[randi() % TIPS.size()]), 28, UITheme.TEXT)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(_tip)
	_ring = _Spinner.new()
	_ring.custom_minimum_size = Vector2(150, 150)
	row.add_child(_ring)
	Widgets.animate_in(card, 0.1)
	var veg: float = [0.45, 0.75, 1.0, 1.0][clampi(int(Settings.get_value("vegetation", 2)), 0, 3)]
	_task = WorkerThreadPool.add_task(func(): _data = TrackWorld.generate_data(_track_id, true, veg), true, "track_gen")
	Audio.menu_music_fade_out()


func _process(delta: float) -> void:
	_t += delta
	if _done:
		return
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	if _task < 0 and _t > _min_time and not _data.is_empty():
		_done = true
		Game.store_preloaded_world(_track_id, _data)
		Game.change_scene(Game.RACE)


class _Spinner extends Control:
	var _t := 0.0

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.4
		draw_arc(c, r, 0, TAU, 64, Color(1, 1, 1, 0.1), 10.0, true)
		var a := _t * 4.0
		draw_arc(c, r, a, a + 1.6 + sin(_t * 2.0) * 0.8, 48, UITheme.ACCENT, 10.0, true)
		# Small wheel icon in the center.
		draw_arc(c, r * 0.35, 0, TAU, 32, UITheme.TEXT, 4.0, true)
		for k in 5:
			var ang := _t * 6.0 + TAU * k / 5.0
			draw_line(c, c + Vector2(cos(ang), sin(ang)) * r * 0.33, UITheme.TEXT, 3.0, true)

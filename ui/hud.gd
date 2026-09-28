class_name RaceHUD
extends Control
## In-race HUD drawn entirely in code: circular speedometer ring with gear and revs,
## position, lap counter, lap times, minimap, wrong-way warning, countdown and messages.
## Layout mirrors horizontally for right-to-left languages.

var state: Dictionary = {}
var rtl := true
var track: TrackData
var _map_pts := PackedVector2Array()
var _map_rect := Rect2()
var _map_scale := 1.0
var _map_center := Vector2.ZERO
var _msg := ""
var _msg_time := 0.0
var _msg_color := UITheme.TEXT
var _count_anim := 0.0
var _last_count := -1
var _speed_smooth := 0.0
var _t := 0.0
var show_minimap := true
var compact := false ## split-screen: smaller layout


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtl = Settings.is_rtl()
	show_minimap = bool(Settings.get_value("show_minimap", true))


func setup_track(t: TrackData) -> void:
	track = t
	_map_pts.clear()
	var b := t.bounds()
	_map_center = b.get_center()
	var s := maxf(b.size.x, b.size.y)
	_map_scale = 1.0 / maxf(s, 1.0)
	for i in range(0, t.count, 6):
		var p := t.points[i]
		_map_pts.append(Vector2(p.x - _map_center.x, p.z - _map_center.y) * _map_scale)
	_map_pts.append(_map_pts[0])


func flash(text: String, color := UITheme.TEXT, time := 2.4) -> void:
	_msg = text
	_msg_time = time
	_msg_color = color


func _process(delta: float) -> void:
	_t += delta
	_msg_time = maxf(_msg_time - delta, 0.0)
	_count_anim += delta
	_speed_smooth = lerpf(_speed_smooth, float(state.get("speed", 0.0)), clampf(delta * 10.0, 0.0, 1.0))
	queue_redraw()


func _ui_scale() -> float:
	return clampf(minf(size.x / 1920.0, size.y / 1080.0), 0.45, 2.0) * (1.25 if compact else 1.0)


func _mx(x: float) -> float:
	return size.x - x if rtl else x


func _draw() -> void:
	if state.is_empty():
		return
	var s := _ui_scale()
	_draw_speedo(s)
	_draw_race_info(s)
	if show_minimap and track:
		_draw_minimap(s)
	if state.get("wrong_way", false):
		_draw_wrong_way(s)
	var cd: float = state.get("countdown", -1.0)
	if cd > -0.9:
		_draw_countdown(s, cd)
	if _msg_time > 0.0:
		_draw_message(s)


# --- Speedometer -------------------------------------------------------------

func _draw_speedo(s: float) -> void:
	var r := 132.0 * s
	var c := Vector2(size.x - 60.0 * s - r if not rtl else 60.0 * s + r, size.y - 56.0 * s - r)
	var start := deg_to_rad(135.0)
	var sweep := deg_to_rad(270.0)
	# Backing disc with soft glow.
	draw_circle(c, r + 22.0 * s, Color(0.05, 0.03, 0.06, 0.55))
	draw_arc(c, r, start, start + sweep, 96, Color(1, 1, 1, 0.1), 16.0 * s, true)
	var top_kmh := 300.0
	var frac := clampf(_speed_smooth / top_kmh, 0.0, 1.0)
	# Gradient arc: draw in segments from orange to pink.
	var segs := int(96 * frac) + 1
	for k in segs:
		var a0 := start + sweep * frac * float(k) / segs
		var a1 := start + sweep * frac * float(k + 1) / segs
		var col := UITheme.ACCENT.lerp(UITheme.ACCENT2, float(k) / 96.0)
		draw_arc(c, r, a0, a1 + 0.004, 3, col, 16.0 * s, true)
	# Tick marks every 20 km/h.
	for k in 16:
		var a := start + sweep * float(k) / 15.0
		var inner := r - (26.0 if k % 5 == 0 else 20.0) * s
		var outer := r - 12.0 * s
		draw_line(c + Vector2(cos(a), sin(a)) * inner, c + Vector2(cos(a), sin(a)) * outer, Color(1, 1, 1, 0.35 if k % 5 else 0.7), 2.0 * s, true)
	# Rev ring inside.
	var rpm_frac: float = state.get("rpm", 0.0)
	var rr := r - 38.0 * s
	draw_arc(c, rr, start, start + sweep, 64, Color(1, 1, 1, 0.07), 6.0 * s, true)
	var rev_col := UITheme.TEXT if rpm_frac < 0.88 else UITheme.BAD
	draw_arc(c, rr, start, start + sweep * clampf(rpm_frac, 0.0, 1.0), 64, rev_col, 6.0 * s, true)
	# Speed number and unit.
	var speed_text := str(int(round(_speed_smooth)))
	var hf := UITheme.heading_font()
	var fs := int(118 * s)
	var tw := hf.get_string_size(speed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(hf, c + Vector2(-tw * 0.5, 30.0 * s), speed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.TEXT)
	var unit := tr("HUD_KMH")
	var bf := UITheme.body_font(600)
	var us := int(24 * s)
	var uw := bf.get_string_size(unit, HORIZONTAL_ALIGNMENT_LEFT, -1, us).x
	draw_string(bf, c + Vector2(-uw * 0.5, 62.0 * s), unit, HORIZONTAL_ALIGNMENT_LEFT, -1, us, UITheme.MUTED)
	# Gear badge.
	var gc := c + Vector2(0, r * 0.78)
	draw_circle(gc, 30.0 * s, UITheme.ACCENT)
	var g := str(state.get("gear", 1))
	var gs := int(52 * s)
	var gw := hf.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, gs).x
	draw_string(hf, gc + Vector2(-gw * 0.5, 17.0 * s), g, HORIZONTAL_ALIGNMENT_LEFT, -1, gs, UITheme.BG)


# --- Position, lap and times -------------------------------------------------

func _draw_race_info(s: float) -> void:
	var hf := UITheme.heading_font()
	var bf := UITheme.body_font(600)
	var x0 := 56.0 * s
	var y0 := 46.0 * s
	var card := Rect2(Vector2(_left(x0, 430.0 * s), y0), Vector2(430.0 * s, 250.0 * s))
	draw_style_box(UITheme.card_style(Color(0.07, 0.045, 0.08, 0.62), int(UITheme.RADIUS * s)), card)
	var pad := 30.0 * s
	# Position
	var pos_text := "%d" % int(state.get("position", 1))
	var total_text := "/%d" % int(state.get("total", 1))
	var px := card.position.x + (card.size.x - pad if rtl else pad)
	var big := int(120 * s)
	var small := int(46 * s)
	var pw := hf.get_string_size(pos_text, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	var tw := hf.get_string_size(total_text, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
	var base_y := card.position.y + 118.0 * s
	# Numbers are always LTR: "2/8"
	var nx := px - (pw + tw) if rtl else px
	draw_string(hf, Vector2(nx, base_y), pos_text, HORIZONTAL_ALIGNMENT_LEFT, -1, big, UITheme.TEXT)
	draw_string(hf, Vector2(nx + pw, base_y), total_text, HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.MUTED)
	_text_aligned(bf, tr("HUD_POSITION"), Vector2(px, card.position.y + 150.0 * s), int(22 * s), UITheme.MUTED)
	# Lap counter on the other side of the card.
	var lx := card.position.x + (pad if rtl else card.size.x - pad)
	var lap_text := "%d/%d" % [int(state.get("lap", 1)), int(state.get("laps", 3))]
	var lw := hf.get_string_size(lap_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(72 * s)).x
	var lpos := Vector2(lx if rtl else lx - lw, card.position.y + 96.0 * s)
	draw_string(hf, lpos, lap_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(72 * s), UITheme.TEXT)
	_draw_flag_icon(Vector2(lpos.x + (lw + 26.0 * s if rtl else -26.0 * s), lpos.y - 28.0 * s), 22.0 * s)
	var lap_label := tr("HUD_LAP")
	var llw := bf.get_string_size(lap_label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * s)).x
	draw_string(bf, Vector2(lx if rtl else lx - llw, card.position.y + 130.0 * s), lap_label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * s), UITheme.MUTED)
	# Times row.
	var ty := card.position.y + 205.0 * s
	var cur := GameData.format_time(float(state.get("lap_time", 0.0)))
	var best := GameData.format_time(float(state.get("best_lap", 0.0)))
	_draw_clock_icon(Vector2(px - 12.0 * s if rtl else px + 12.0 * s, ty - 10.0 * s), 12.0 * s)
	var tx := px - 36.0 * s if rtl else px + 36.0 * s
	_text_aligned(UITheme.body_font(700), cur, Vector2(tx, ty), int(34 * s), UITheme.TEXT, true)
	var bx := lx
	var best_label := tr("HUD_BEST") + "  " + best
	_text_aligned(bf, best_label, Vector2(bx, ty), int(26 * s), UITheme.GOLD, false, not rtl)
	# Gap / last lap delta.
	var delta_text: String = state.get("delta_text", "")
	if delta_text != "":
		var dc: Color = state.get("delta_color", UITheme.TEXT)
		_text_aligned(UITheme.body_font(700), delta_text, Vector2(px, card.end.y + 40.0 * s), int(30 * s), dc)


func _left(margin: float, w: float) -> float:
	## x of a box of width w placed at `margin` from the reading-start edge.
	return size.x - margin - w if rtl else margin


func _text_aligned(font: Font, text: String, anchor: Vector2, fs: int, col: Color, numeric := false, right_align := false) -> void:
	## Draws text starting at the reading-start anchor (right edge in RTL).
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := anchor.x - w if (rtl or right_align) else anchor.x
	if right_align and not rtl:
		x = anchor.x - w
	draw_string(font, Vector2(x, anchor.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_flag_icon(p: Vector2, sz: float) -> void:
	draw_line(p + Vector2(-sz * 0.5, -sz * 0.6), p + Vector2(-sz * 0.5, sz * 0.8), UITheme.TEXT, 2.0, true)
	var cell := sz * 0.3
	for yy in 3:
		for xx in 3:
			var col := UITheme.TEXT if (xx + yy) % 2 == 0 else Color(1, 1, 1, 0.2)
			draw_rect(Rect2(p + Vector2(-sz * 0.45 + xx * cell, -sz * 0.6 + yy * cell), Vector2(cell, cell)), col)


func _draw_clock_icon(c: Vector2, r: float) -> void:
	draw_arc(c, r, 0, TAU, 24, UITheme.MUTED, 2.0, true)
	draw_line(c, c + Vector2(0, -r * 0.65), UITheme.MUTED, 2.0, true)
	draw_line(c, c + Vector2(r * 0.5, 0), UITheme.MUTED, 2.0, true)


# --- Minimap -----------------------------------------------------------------

func _draw_minimap(s: float) -> void:
	var sz := 250.0 * s
	var margin := 56.0 * s
	var box := Rect2(Vector2(size.x - margin - sz if not rtl else margin, 46.0 * s), Vector2(sz, sz))
	draw_style_box(UITheme.card_style(Color(0.07, 0.045, 0.08, 0.5), int(UITheme.RADIUS * s)), box)
	var inner := sz * 0.8
	var c := box.get_center()
	var pts := PackedVector2Array()
	for p in _map_pts:
		pts.append(c + p * inner)
	draw_polyline(pts, Color(0, 0, 0, 0.45), 9.0 * s, true)
	draw_polyline(pts, Color(1, 1, 1, 0.8), 4.5 * s, true)
	# Start line.
	if track:
		var sp := c + _world_to_map(track.points[0]) * inner
		var r := track.rights[0]
		var rv := Vector2(r.x, r.z) * 9.0 * s
		draw_line(sp - rv, sp + rv, UITheme.GOLD, 3.0 * s, true)
	var markers: Array = state.get("markers", [])
	# Draw others first, then self on top.
	for pass_i in 2:
		for m in markers:
			var is_self: bool = m.get("self", false)
			if (pass_i == 0) == is_self:
				continue
			var mp := c + _world_to_map(m["pos"]) * inner
			if is_self:
				draw_circle(mp, 9.0 * s, UITheme.BG)
				draw_circle(mp, 7.0 * s, UITheme.ACCENT)
			else:
				draw_circle(mp, 5.5 * s, m.get("color", UITheme.MUTED))


func _world_to_map(p: Vector3) -> Vector2:
	return Vector2(p.x - _map_center.x, p.z - _map_center.y) * _map_scale


# --- Overlays ----------------------------------------------------------------

func _draw_wrong_way(s: float) -> void:
	var text := tr("HUD_WRONG_WAY")
	var bf := UITheme.body_font(800)
	var fs := int(46 * s)
	var w := bf.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 140.0 * s
	var pulse := 0.75 + 0.25 * sin(_t * 8.0)
	var rect := Rect2(Vector2((size.x - w) * 0.5, size.y * 0.24), Vector2(w, 86.0 * s))
	draw_style_box(UITheme.pill_style(Color(UITheme.BAD, 0.85 * pulse), int(43 * s)), rect)
	# U-turn arrow icon.
	var ic := rect.position + Vector2(56.0 * s if not rtl else rect.size.x - 56.0 * s, rect.size.y * 0.5)
	draw_arc(ic, 16.0 * s, PI, TAU, 16, Color.WHITE, 5.0 * s, true)
	draw_line(ic + Vector2(-16.0 * s, 0), ic + Vector2(-16.0 * s, 16.0 * s), Color.WHITE, 5.0 * s, true)
	draw_colored_polygon(PackedVector2Array([ic + Vector2(16.0 * s - 10.0 * s, 2.0 * s), ic + Vector2(16.0 * s + 10.0 * s, 2.0 * s), ic + Vector2(16.0 * s, 16.0 * s)]), Color.WHITE)
	var tx := rect.position.x + (100.0 * s if not rtl else rect.size.x - 100.0 * s - (w - 140.0 * s))
	draw_string(bf, Vector2(tx, rect.position.y + 58.0 * s), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _draw_countdown(s: float, cd: float) -> void:
	var n := int(ceil(cd))
	if n != _last_count:
		_last_count = n
		_count_anim = 0.0
	var text := str(n) if n > 0 else tr("HUD_GO")
	var k := clampf(_count_anim / 0.35, 0.0, 1.0)
	var scale := lerpf(1.6, 1.0, 1.0 - pow(1.0 - k, 3.0))
	var alpha := 1.0 if n > 0 else clampf(1.0 - (_count_anim - 0.4) / 0.6, 0.0, 1.0)
	var hf := UITheme.heading_font()
	var fs := int(300 * s * scale)
	var w := hf.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2((size.x - w) * 0.5, size.y * 0.47 + fs * 0.3)
	var col := UITheme.GOLD if n > 0 else UITheme.GOOD
	# Ring that empties with the second.
	var c := Vector2(size.x * 0.5, size.y * 0.42)
	var frac := cd - floorf(cd) if n > 0 else 0.0
	if n > 0:
		draw_arc(c, 190.0 * s, -PI * 0.5, -PI * 0.5 + TAU * frac, 64, Color(col, 0.8 * alpha), 10.0 * s, true)
	draw_string(hf, pos + Vector2(4, 6) * s, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.45 * alpha))
	draw_string(hf, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, alpha))


func _draw_message(s: float) -> void:
	var a := clampf(_msg_time / 0.4, 0.0, 1.0)
	var bf := UITheme.heading_font()
	var fs := int(86 * s)
	var w := bf.get_string_size(_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var rect := Rect2(Vector2((size.x - w) * 0.5 - 40.0 * s, size.y * 0.14), Vector2(w + 80.0 * s, 110.0 * s))
	draw_style_box(UITheme.card_style(Color(0.07, 0.045, 0.08, 0.7 * a), int(UITheme.RADIUS * s)), rect)
	draw_string(bf, Vector2((size.x - w) * 0.5, rect.position.y + 84.0 * s), _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(_msg_color, a))

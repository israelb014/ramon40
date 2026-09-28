class_name TrackArt
extends Control
## Procedural poster-style illustration of a track, used on loading screens and menus.
## Layered silhouettes with gentle parallax animation; drawn entirely with polygons.

var track_id := "ramon"
var animate := true
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _stars: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 40
	for i in 140:
		_stars.append(Vector3(_rng.randf(), _rng.randf() * 0.55, _rng.randf()))


func _process(delta: float) -> void:
	if animate:
		_t += delta
		queue_redraw()


func _ridge(y_base: float, amp: float, freq: float, phase: float, seed_off: float, steps := 64) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(0, size.y))
	for i in steps + 1:
		var x := float(i) / steps
		var y := y_base + sin(x * freq + phase) * amp * 0.5 + sin(x * freq * 2.3 + seed_off) * amp * 0.3 + sin(x * freq * 5.1 + seed_off * 2.0) * amp * 0.12
		pts.append(Vector2(x * size.x, y * size.y))
	pts.append(Vector2(size.x, size.y))
	return pts


func _gradient_rect(top: Color, bottom: Color, y0: float, y1: float, bands := 24) -> void:
	for i in bands:
		var a := float(i) / bands
		var b := float(i + 1) / bands
		draw_rect(Rect2(0, lerpf(y0, y1, a) * size.y, size.x, (y1 - y0) * size.y / bands + 1.0), top.lerp(bottom, (a + b) * 0.5))


func _draw() -> void:
	if size.x < 2.0:
		return
	match track_id:
		"deadsea":
			_draw_deadsea()
		"jerusalem":
			_draw_jerusalem()
		_:
			_draw_ramon()


func _draw_ramon() -> void:
	_gradient_rect(Color("2b1745"), Color("c2456a"), 0.0, 0.45)
	_gradient_rect(Color("c2456a"), Color("ff9a4d"), 0.45, 0.68)
	var sun := Vector2(size.x * 0.66, size.y * 0.62)
	draw_circle(sun, size.y * 0.2, Color(1.0, 0.75, 0.4, 0.18))
	draw_circle(sun, size.y * 0.12, Color("ffd37a"))
	var drift := sin(_t * 0.05) * 0.01
	draw_colored_polygon(_ridge(0.6, 0.05, 6.0, 1.0 + drift, 2.0), Color("8a2f4f"))
	draw_colored_polygon(_ridge(0.66, 0.06, 4.0, 2.0 - drift, 5.0), Color("6d2440"))
	# Crater escarpment with strata bands.
	var cliff := _ridge(0.72, 0.1, 3.0, 0.4, 1.3)
	draw_colored_polygon(cliff, Color("5a1d3f"))
	for k in 5:
		var band := _ridge(0.76 + k * 0.035, 0.08, 3.0, 0.4, 1.3)
		var col: Color = [Color("7a2a3a"), Color("5c2146"), Color("8c3a32"), Color("4a1a3a"), Color("6b2a36")][k]
		draw_colored_polygon(band, col)
	# Road snaking to the horizon.
	_road(Vector2(size.x * 0.52, size.y * 0.7), Color("241020"), Color("f5c542"))
	_acacia(Vector2(size.x * 0.16, size.y * 0.86), size.y * 0.13, Color("1c0c1e"))
	_acacia(Vector2(size.x * 0.88, size.y * 0.9), size.y * 0.09, Color("1c0c1e"))


func _draw_deadsea() -> void:
	_gradient_rect(Color("3f86c9"), Color("cfe3ec"), 0.0, 0.5)
	draw_circle(Vector2(size.x * 0.3, size.y * 0.16), size.y * 0.09, Color(1, 1, 0.95, 0.9))
	draw_circle(Vector2(size.x * 0.3, size.y * 0.16), size.y * 0.16, Color(1, 1, 0.9, 0.15))
	# Moab mountains across the water.
	draw_colored_polygon(_ridge(0.42, 0.08, 5.0, 0.3, 3.0), Color("c9a7a3"))
	draw_colored_polygon(_ridge(0.47, 0.05, 7.0, 1.3, 4.0), Color("b89390"))
	# Sea.
	draw_rect(Rect2(0, size.y * 0.5, size.x, size.y * 0.2), Color("3fb4b0"))
	for i in 40:
		var x := fmod(i * 97.3 + _t * 20.0 * (0.5 + (i % 3) * 0.3), size.x)
		var y := size.y * (0.52 + (i % 7) * 0.025)
		draw_line(Vector2(x, y), Vector2(x + 18.0 + (i % 4) * 6.0, y), Color(1, 1, 1, 0.35 + 0.25 * sin(_t * 2.0 + i)), 2.0)
	# Salt shore and the road.
	draw_colored_polygon(_ridge(0.68, 0.03, 4.0, 2.0, 1.0), Color("efe9df"))
	draw_colored_polygon(_ridge(0.74, 0.04, 3.0, 0.2, 2.0), Color("d8c3a2"))
	_road(Vector2(size.x * 0.62, size.y * 0.7), Color("3a3336"), Color("f5c542"))
	# Palm silhouettes.
	for p in [[0.1, 0.95, 0.3], [0.2, 0.98, 0.26], [0.86, 0.96, 0.28], [0.94, 1.0, 0.22]]:
		_palm(Vector2(size.x * p[0], size.y * p[1]), size.y * p[2], Color("2a3a22"))
	# Judean cliffs on the right edge.
	var cliff := PackedVector2Array([Vector2(size.x * 0.78, size.y), Vector2(size.x * 0.84, size.y * 0.5), Vector2(size.x * 0.9, size.y * 0.42), Vector2(size.x, size.y * 0.38), Vector2(size.x, size.y)])
	draw_colored_polygon(cliff, Color("a8835f"))


func _draw_jerusalem() -> void:
	_gradient_rect(Color("050814"), Color("1d2446"), 0.0, 0.7)
	for s in _stars:
		var tw := 0.5 + 0.5 * sin(_t * (1.0 + s.z * 3.0) + s.z * 40.0)
		draw_circle(Vector2(s.x * size.x, s.y * size.y), 1.2 + s.z, Color(1, 1, 1, 0.3 + 0.6 * tw))
	draw_circle(Vector2(size.x * 0.78, size.y * 0.18), size.y * 0.06, Color("f3efe0"))
	draw_circle(Vector2(size.x * 0.795, size.y * 0.17), size.y * 0.055, Color("1a2040"))
	# City glow on the horizon.
	for i in 12:
		draw_circle(Vector2(size.x * 0.25, size.y * 0.58), size.y * (0.4 - i * 0.03), Color(1.0, 0.55, 0.25, 0.025))
	var hills := _ridge(0.55, 0.08, 4.0, 0.6, 2.0)
	draw_colored_polygon(hills, Color("141a33"))
	# City lights along the far hill.
	_rng.seed = 7
	for i in 220:
		var x := _rng.randf()
		var yb := 0.55 + sin(x * 4.0 + 0.6) * 0.04 + sin(x * 9.2 + 2.0) * 0.024
		var y := yb + _rng.randf() * 0.05
		var flick := 0.7 + 0.3 * sin(_t * 3.0 + i)
		draw_circle(Vector2(x * size.x, y * size.y), 1.6, Color(1.0, 0.75, 0.4, flick * 0.9))
	draw_colored_polygon(_ridge(0.66, 0.1, 3.0, 2.0, 4.0), Color("0e1226"))
	# Forest silhouettes.
	_rng.seed = 11
	for i in 60:
		var x := _rng.randf()
		var base := 0.66 + sin(x * 3.0 + 2.0) * 0.05 + sin(x * 6.9 + 4.0) * 0.03 + 0.02
		var h := _rng.randf_range(0.04, 0.09)
		var w := h * 0.35
		draw_colored_polygon(PackedVector2Array([Vector2((x - w) * size.x, base * size.y), Vector2(x * size.x, (base - h) * size.y), Vector2((x + w) * size.x, base * size.y)]), Color("0a0d1c"))
	draw_colored_polygon(_ridge(0.8, 0.06, 2.0, 1.0, 0.5), Color("080a16"))
	_road(Vector2(size.x * 0.4, size.y * 0.74), Color("15151c"), Color("f5c542"))
	# Street lights.
	for k in 5:
		var t := float(k) / 4.0
		var p := Vector2(lerpf(size.x * 0.46, size.x * 0.9, t), lerpf(size.y * 0.76, size.y * 1.0, t))
		var h := lerpf(size.y * 0.05, size.y * 0.2, t)
		draw_line(p, p - Vector2(0, h), Color("2a2a33"), lerpf(2.0, 6.0, t))
		draw_circle(p - Vector2(0, h), lerpf(10.0, 40.0, t), Color(1.0, 0.75, 0.4, 0.12))
		draw_circle(p - Vector2(0, h), lerpf(2.0, 6.0, t), Color("ffd08a"))


func _road(horizon: Vector2, asphalt: Color, line_col: Color) -> void:
	var pts_l := PackedVector2Array()
	var pts_r := PackedVector2Array()
	var steps := 24
	for i in steps + 1:
		var t := float(i) / steps
		var y := lerpf(horizon.y, size.y, t)
		var cx := horizon.x + sin(t * 3.2 + 0.5) * size.x * 0.08 * (1.0 - t) + (t * t) * size.x * 0.05
		var w := lerpf(size.x * 0.005, size.x * 0.3, t * t)
		pts_l.append(Vector2(cx - w, y))
		pts_r.append(Vector2(cx + w, y))
	var poly := PackedVector2Array(pts_l)
	var rr := pts_r.duplicate()
	rr.reverse()
	poly.append_array(rr)
	draw_colored_polygon(poly, asphalt)
	for i in steps:
		var t := float(i) / steps
		var a := pts_l[i].lerp(pts_r[i], 0.5)
		var b := pts_l[i + 1].lerp(pts_r[i + 1], 0.5)
		if i % 2 == 0:
			draw_line(a, b, Color(1, 1, 1, 0.85), lerpf(1.0, 6.0, t * t))
		draw_line(pts_l[i].lerp(pts_r[i], 0.04), pts_l[i + 1].lerp(pts_r[i + 1], 0.04), line_col, lerpf(1.0, 5.0, t * t))
		draw_line(pts_l[i].lerp(pts_r[i], 0.96), pts_l[i + 1].lerp(pts_r[i + 1], 0.96), line_col, lerpf(1.0, 5.0, t * t))


func _acacia(base: Vector2, h: float, col: Color) -> void:
	draw_line(base, base - Vector2(0, h * 0.55), col, h * 0.06)
	draw_line(base - Vector2(0, h * 0.4), base - Vector2(h * 0.3, h * 0.75), col, h * 0.04)
	draw_line(base - Vector2(0, h * 0.4), base + Vector2(h * 0.28, -h * 0.78), col, h * 0.04)
	var canopy := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		canopy.append(base + Vector2(cos(a) * h * 0.62, -h * 0.82 + sin(a) * h * 0.12 - absf(sin(a * 3.0)) * h * 0.03))
	draw_colored_polygon(canopy, col)


func _palm(base: Vector2, h: float, col: Color) -> void:
	var top := base + Vector2(h * 0.08, -h)
	draw_line(base, top, col, h * 0.05)
	for i in 9:
		var a := -PI * 0.5 + (i - 4) * 0.42
		var tip := top + Vector2(cos(a), sin(a) + 0.9) * h * 0.4
		var mid := top + Vector2(cos(a), sin(a) + 0.2) * h * 0.22
		draw_colored_polygon(PackedVector2Array([top, mid + Vector2(0, -h * 0.02), tip, mid + Vector2(0, h * 0.03)]), col)

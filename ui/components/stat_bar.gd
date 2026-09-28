class_name StatBar
extends Control
## Segmented rating bar (0..10) with an animated fill, used for bike stats.

var label_text := ""
var value := 5.0
var _shown := 0.0
var _compare := -1.0


static func make(p_label: String, p_value: float) -> StatBar:
	var s := StatBar.new()
	s.label_text = p_label
	s.value = p_value
	s.custom_minimum_size = Vector2(0, 58)
	return s


func set_value(v: float) -> void:
	value = v


func _process(delta: float) -> void:
	var prev := _shown
	_shown = move_toward(_shown, value, delta * 18.0)
	if prev != _shown:
		queue_redraw()


func _draw() -> void:
	var rtl := is_layout_rtl()
	var bf := UITheme.body_font(600)
	var fs := 24
	var tw := bf.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tx := size.x - tw if rtl else 0.0
	draw_string(bf, Vector2(tx, 22), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.MUTED)
	var segs := 10
	var gap := 6.0
	var w := (size.x - gap * (segs - 1)) / segs
	var y := 32.0
	var h := 16.0
	for i in segs:
		var x := i * (w + gap)
		if rtl:
			x = size.x - x - w
		var fill := clampf(_shown - i, 0.0, 1.0)
		var r := Rect2(x, y, w, h)
		draw_style_box(UITheme.pill_style(Color(1, 1, 1, 0.08), 6), r)
		if fill > 0.0:
			var fr := Rect2(r.position, Vector2(w * fill, h))
			if rtl:
				fr.position.x = r.end.x - w * fill
			var col := UITheme.ACCENT.lerp(UITheme.ACCENT2, float(i) / segs)
			draw_style_box(UITheme.pill_style(col, 6), fr)

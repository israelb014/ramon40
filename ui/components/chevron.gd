class_name Chevron
extends Control
## Vector chevron arrow pointing left (-1) or right (+1) on screen, independent of layout
## direction.

var direction := 1.0
var color := UITheme.TEXT
var thickness := 4.0


func _draw() -> void:
	var c := size * 0.5
	var s := minf(size.x, size.y) * 0.18
	var pts := PackedVector2Array([c + Vector2(-s * 0.5 * direction, -s), c + Vector2(s * 0.5 * direction, 0), c + Vector2(-s * 0.5 * direction, s)])
	draw_polyline(pts, color, thickness, true)

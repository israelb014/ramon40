class_name PropPlacer
extends RefCounted
## Deterministic scatter of props around a track. Returns groups of transforms keyed by a
## prop id; the world builder turns each group into tiled MultiMeshes.
## `density` scales vegetation counts (quality setting: 0 low .. 2 high).

var t: TrackData
var rng := RandomNumberGenerator.new()
var groups: Dictionary = {} # id -> Array[Transform3D]
var density := 1.0
var _cluster := FastNoiseLite.new()


func _init(track: TrackData, p_density := 1.0) -> void:
	t = track
	density = p_density
	rng.seed = int(t.layout.get("seed", 1)) * 7 + 13
	_cluster.seed = int(t.layout.get("seed", 1)) + 99
	_cluster.frequency = 0.006
	_cluster.fractal_octaves = 3


func add(id: String, xf: Transform3D) -> void:
	if not groups.has(id):
		groups[id] = []
	groups[id].append(xf)


func place_all() -> Dictionary:
	_reflector_posts()
	match t.style.style:
		"ramon":
			_scatter("rock_big", 26.0, 0.30, 14.0, 400.0, 0.0, 0.55, Vector2(1.4, 3.8), true)
			_scatter("rock_small", 10.0, 0.22 * density, 9.5, 90.0, 0.0, 0.8, Vector2(0.4, 1.1), true)
			_scatter("acacia", 38.0, 0.40 * density, 13.0, 380.0, 0.0, 0.18, Vector2(0.8, 1.3), false, -INF, 35.0)
			_scatter("bush_dry", 15.0, 0.25 * density, 10.0, 200.0, 0.0, 0.3, Vector2(0.6, 1.3), false)
		"deadsea":
			_groves([Rect2(-300, -720, 190, 250), Rect2(-330, 260, 240, 300), Rect2(-250, -330, 150, 120)])
			_scatter("palm", 45.0, 0.25 * density, 12.0, 240.0, 0.0, 0.2, Vector2(0.8, 1.2), false, -1.0, 30.0)
			_scatter("rock_big", 30.0, 0.30, 14.0, 500.0, 0.3, 1.0, Vector2(2.0, 5.0), true)
			_scatter("rock_small", 12.0, 0.18 * density, 9.5, 80.0, 0.0, 0.8, Vector2(0.4, 1.0), true, -3.0)
			_scatter("bush_dry", 17.0, 0.18 * density, 10.0, 160.0, 0.0, 0.3, Vector2(0.6, 1.2), false, -2.0)
		"jerusalem":
			_scatter("pine", 10.5, 0.62 * density, 10.5, 330.0, 0.0, 0.75, Vector2(0.8, 1.25), false, -INF, INF, 0.35)
			_scatter("cypress", 60.0, 0.25 * density, 11.0, 140.0, 0.0, 0.3, Vector2(0.8, 1.2), false)
			_scatter("bush_green", 8.0, 0.25 * density, 9.0, 120.0, 0.0, 0.7, Vector2(0.6, 1.3), false)
			_scatter("rock_lime", 20.0, 0.18, 9.5, 250.0, 0.0, 1.0, Vector2(0.6, 1.8), true)
			_stone_walls()
			_streetlights(32.0)
	return groups


func _reflector_posts() -> void:
	var spacing := 40.0
	var d := 0.0
	var lat := t.half_width + t.shoulder - 0.35
	while d < t.length - spacing * 0.5:
		var i := t.index_at_distance(d)
		if t.tunnel[i] == 0 and d > 30.0:
			var p := t.points[i]
			var tan := t.tangents[i]
			var r := t.rights[i]
			for side in [-1.0, 1.0]:
				var pos: Vector3 = p + r * lat * side
				pos.y = p.y - 0.15
				add("post", Transform3D(Basis(Vector3.UP.cross(tan).normalized(), Vector3.UP, tan), pos))
		d += spacing


## Jittered grid scatter.
## spacing: grid step; prob: acceptance probability; road_min/max: distance band from the
## centerline; slope_min/max: allowed slope (0 flat .. 1 vertical); scale range; random
## tilt for rocks; height band; cluster: if > 0, uses noise to form forests.
func _scatter(id: String, spacing: float, prob: float, road_min: float, road_max: float, slope_min: float, slope_max: float, scale: Vector2, tilt: bool, h_min := -INF, h_max := INF, cluster := 0.0) -> void:
	if prob <= 0.0:
		return
	var b := t.bounds().grow(minf(road_max, TrackData.MARGIN - 20.0))
	var x := b.position.x
	while x < b.end.x:
		var z := b.position.y
		while z < b.end.y:
			var px := x + rng.randf_range(-0.45, 0.45) * spacing
			var pz := z + rng.randf_range(-0.45, 0.45) * spacing
			var roll := rng.randf()
			z += spacing
			var p := prob
			if cluster > 0.0:
				p *= clampf(0.5 + _cluster.get_noise_2d(px, pz) * 1.6 + cluster, 0.0, 1.5)
			if roll > p:
				continue
			var rd := t.terrain_road_distance(px, pz)
			if rd < road_min or rd > road_max:
				continue
			var h := t.terrain_height(px, pz)
			if h < h_min or h > h_max:
				continue
			var hx := t.terrain_height(px + 2.0, pz)
			var hz := t.terrain_height(px, pz + 2.0)
			var slope := clampf(Vector2(hx - h, hz - h).length() / 2.0, 0.0, 1.0)
			if slope < slope_min or slope > slope_max:
				continue
			if _near_tunnel(px, pz):
				continue
			var s := rng.randf_range(scale.x, scale.y)
			var basis := Basis(Vector3.UP, rng.randf() * TAU)
			if tilt:
				basis = Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.35)) * basis
			basis = basis.scaled(Vector3(s, s * (rng.randf_range(0.7, 1.1) if tilt else 1.0), s))
			var sink := 0.25 * s if tilt else 0.05
			add(id + "_%d" % rng.randi_range(0, 3), Transform3D(basis, Vector3(px, h - sink, pz)))
		x += spacing


func _near_tunnel(x: float, z: float) -> bool:
	if not t.tunnel.has(1):
		return false
	var i := t.closest_index(Vector3(x, 0, z))
	return t.tunnel[i] == 1 and Vector2(t.points[i].x - x, t.points[i].z - z).length() < 60.0


func _groves(rects: Array) -> void:
	for r in rects:
		var rect: Rect2 = r
		var ang := rng.randf_range(-0.3, 0.3)
		var basis := Basis(Vector3.UP, ang)
		var step := 7.5
		var x := 0.0
		while x < rect.size.x:
			var z := 0.0
			while z < rect.size.y:
				var local := basis * Vector3(x, 0, z)
				var px := rect.position.x + local.x + rng.randf_range(-0.6, 0.6)
				var pz := rect.position.y + local.z + rng.randf_range(-0.6, 0.6)
				z += step
				if rng.randf() > 0.9 * minf(density + 0.3, 1.0):
					continue
				if t.terrain_road_distance(px, pz) < 12.0:
					continue
				var h := t.terrain_height(px, pz)
				var s := rng.randf_range(0.85, 1.1)
				add("palm_%d" % rng.randi_range(0, 3), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(px, h - 0.1, pz)))
			x += step


func _stone_walls() -> void:
	var d := 0.0
	var lat := t.half_width + t.shoulder + 1.4
	var wall_noise := FastNoiseLite.new()
	wall_noise.seed = 77
	wall_noise.frequency = 0.004
	while d < t.length:
		var i := t.index_at_distance(d)
		if t.tunnel[i] == 0 and d > 40.0 and d < t.length - 20.0:
			var p := t.points[i]
			var tan := t.tangents[i]
			var r := t.rights[i]
			for side in [-1.0, 1.0]:
				if wall_noise.get_noise_2d(d, side * 100.0) > -0.1:
					var pos: Vector3 = p + r * lat * side
					pos.y = t.terrain_height(pos.x, pos.z) - 0.05
					add("wall_%d" % rng.randi_range(0, 3), Transform3D(Basis(Vector3.UP.cross(tan).normalized(), Vector3.UP, tan), pos))
		d += 4.0


func _streetlights(spacing: float) -> void:
	var d := 25.0
	var lat := t.half_width + t.shoulder + 0.6
	var n := 0
	while d < t.length - 20.0:
		var i := t.index_at_distance(d)
		if t.tunnel[i] == 0:
			var p := t.points[i]
			var tan := t.tangents[i]
			var r := t.rights[i]
			var side := 1.0 if n % 2 == 0 else -1.0
			var pos: Vector3 = p + r * lat * side
			pos.y = p.y - 0.2
			# Arm points along local +X toward the road center.
			var x_axis: Vector3 = -r * side
			add("streetlight", Transform3D(Basis(x_axis, Vector3.UP, x_axis.cross(Vector3.UP).normalized()), pos))
			n += 1
		d += spacing

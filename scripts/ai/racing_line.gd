class_name RacingLine
extends RefCounted
## Precomputed racing line for a track: lateral offsets that minimise curvature within the
## road, plus per-bike target speed profiles with braking points (backward pass).

var track: TrackData
var offsets := PackedFloat32Array() ## lateral offset per centerline sample
var positions := PackedVector3Array()
var curvature := PackedFloat32Array() ## |curvature| along the line
var _profiles: Dictionary = {} # bike_id -> PackedFloat32Array of target speeds

static var _cache: Dictionary = {}


static func for_track(t: TrackData) -> RacingLine:
	var key := "%s_%d" % [t.id, t.count]
	if _cache.has(key):
		return _cache[key]
	var rl := RacingLine.new()
	rl._compute(t)
	_cache[key] = rl
	return rl


func _compute(t: TrackData) -> void:
	track = t
	var n := t.count
	offsets.resize(n)
	offsets.fill(0.0)
	var lim := t.half_width - 1.3
	# Iterative smoothing (discrete elastic band) constrained to the road width.
	var pos := PackedVector3Array()
	pos.resize(n)
	for i in n:
		pos[i] = t.points[i]
	for it in 180:
		var step := 2 if it < 120 else 1
		for i in range(0, n, 1):
			var a := pos[(i - step + n) % n]
			var b := pos[(i + step) % n]
			var mid := (a + b) * 0.5
			var d := (mid - pos[i]).dot(t.rights[i])
			var o := clampf(offsets[i] + d * 0.6, -lim, lim)
			offsets[i] = o
			pos[i] = t.points[i] + t.rights[i] * o
	# Tunnels and the start straight stay near the center-right for fairness/safety.
	for i in n:
		if t.tunnel[i] == 1:
			offsets[i] = clampf(offsets[i], -t.half_width + 1.8, t.half_width - 1.8)
			pos[i] = t.points[i] + t.rights[i] * offsets[i]
	positions = pos
	curvature.resize(n)
	for i in n:
		var a := pos[(i - 3 + n) % n]
		var b := pos[i]
		var c := pos[(i + 3) % n]
		curvature[i] = _menger(a, b, c)
	# Smooth curvature a bit.
	var c2 := curvature.duplicate()
	for i in n:
		var s := 0.0
		for k in range(-4, 5):
			s += c2[(i + k + n) % n]
		curvature[i] = s / 9.0


static func _menger(a: Vector3, b: Vector3, c: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var bc := Vector2(c.x - b.x, c.z - b.z)
	var ca := Vector2(a.x - c.x, a.z - c.z)
	var area2 := absf(ab.x * (-ca.y) - ab.y * (-ca.x))
	var denom := ab.length() * bc.length() * ca.length()
	if denom < 1e-6:
		return 0.0
	return 2.0 * area2 / denom


## Target speed (m/s) at each sample for a given bike spec, with braking zones.
func speed_profile(spec: Dictionary) -> PackedFloat32Array:
	var key: String = str(spec.get("name", "")) + str(spec.get("grip", 1.0))
	if _profiles.has(key):
		return _profiles[key]
	var n := track.count
	var ds := track.length / n
	var g := BikePhysics.G
	var mu: float = spec["grip"]
	var lat := minf(mu * 0.86, tan(deg_to_rad(spec["max_lean"])) * 0.9) * g
	var v := PackedFloat32Array()
	v.resize(n)
	for i in n:
		var k := maxf(curvature[i], 1e-4)
		v[i] = minf(sqrt(lat / k), 95.0)
	# Braking: backward passes (loop twice for wrap-around).
	var a_brake := minf(float(spec["brake_front"]) * 0.72, mu * g * 0.7)
	for pass_i in 2:
		for j in range(n - 1, -1, -1):
			var nxt := v[(j + 1) % n]
			v[j] = minf(v[j], sqrt(nxt * nxt + 2.0 * a_brake * ds))
	# Downhill sections: brake earlier.
	for i in n:
		var dy := track.points[(i + 8) % n].y - track.points[i].y
		if dy < -1.0:
			v[i] *= 0.97
	_profiles[key] = v
	return v


func point_at(i: int) -> Vector3:
	return positions[i % positions.size()]

class_name AIController
extends RefCounted
## AI rider: follows the precomputed racing line with pure-pursuit steering, targets the
## speed profile (braking points), overtakes, defends and applies mild rubber-banding.

const SKILL := {
	"easy": {"pace": 0.82, "noise": 0.9, "aggression": 0.3, "mistakes": 0.012, "reaction": 0.35},
	"medium": {"pace": 0.9, "noise": 0.5, "aggression": 0.6, "mistakes": 0.006, "reaction": 0.22},
	"hard": {"pace": 0.965, "noise": 0.2, "aggression": 0.9, "mistakes": 0.002, "reaction": 0.12},
}

var line: RacingLine
var profile: PackedFloat32Array
var difficulty := "medium"
var skill: Dictionary
var personality := 1.0 ## small per-rider pace variation
var lane := 0.0 ## current lateral offset from the racing line
var lane_target := 0.0
var rubber := 1.0
var enabled := true
var all_bikes: Array = []
var progress: RaceProgress
var reference_ids: Array = [] ## ids of human players used for rubber-banding
var rubber_band_enabled := true

var _stuck_time := 0.0
var _mistake_time := 0.0
var _noise := FastNoiseLite.new()
var _t := 0.0


func _init(p_line: RacingLine, spec: Dictionary, p_difficulty: String, seed_value: int) -> void:
	line = p_line
	profile = line.speed_profile(spec)
	difficulty = p_difficulty
	skill = SKILL.get(difficulty, SKILL["medium"])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	personality = rng.randf_range(0.975, 1.02)
	_noise.seed = seed_value
	_noise.frequency = 0.25


func update(bike: Bike, delta: float) -> void:
	var ph := bike.physics
	_t += delta
	if not enabled or ph.is_crashed:
		ph.in_throttle = 0.0
		ph.in_brake = 0.0
		ph.in_steer = 0.0
		return
	var t := line.track
	var n := t.count
	var i := ph.track_index if ph.track_index >= 0 else t.closest_index(ph.pos)
	var speed := ph.speed
	var ds := t.length / n

	_update_rubber_band(bike)
	_update_traffic(bike, i)
	lane = move_toward(lane, lane_target, delta * 1.6)

	# --- Steering: pure pursuit toward a look-ahead point on the (offset) line, measured
	# from the heading the bike will have once its current lean has acted (damping).
	var v := maxf(absf(speed), 3.0)
	var look := 6.0 + v * 0.62
	var j := (i + int(look / ds)) % n
	var target := line.positions[j] + t.rights[j] * lane
	var wobble := _noise.get_noise_1d(_t * 10.0) * float(skill["noise"]) * 0.35
	target += t.rights[j] * wobble
	var to := target - ph.pos
	to.y = 0.0
	var omega_now := BikePhysics.G * tan(ph.lean) / v
	var pred_yaw := ph.yaw - omega_now * 0.32
	var fwd := Vector3(-sin(pred_yaw), 0.0, -cos(pred_yaw))
	var rgt := Vector3(cos(pred_yaw), 0.0, -sin(pred_yaw))
	var ang := atan2(to.dot(rgt), to.dot(fwd))
	var dist := maxf(to.length(), 1.0)
	var curv := 2.0 * sin(ang) / dist
	var desired_lean := atan(curv * v * v / BikePhysics.G)
	var max_lean := ph.max_lean_at(speed)
	desired_lean = clampf(desired_lean, -max_lean, max_lean)
	var steer := desired_lean / maxf(max_lean, 0.05)
	if absf(speed) < 4.0:
		steer = clampf(ang * 2.0, -1.0, 1.0)
	ph.in_steer = clampf(steer, -1.0, 1.0)

	# --- Speed: minimum of the profile over the braking horizon ahead.
	var pace: float = float(skill["pace"]) * personality * rubber
	var horizon := int((v * v / 14.0 + 12.0) / ds)
	var target_v := 999.0
	var k := 0
	while k <= horizon:
		var idx := (i + k) % n
		# Allow more speed where the profile is far ahead (braking distance covered by the pass).
		target_v = minf(target_v, profile[idx])
		k += 3
	target_v *= pace
	# Off the racing line (overtaking) corners need a little more margin.
	target_v *= 1.0 - clampf(absf(lane) / 12.0, 0.0, 0.08)
	if ph.surface != BikePhysics.Surface.ASPHALT:
		target_v = minf(target_v, 22.0)
	# Occasional small mistakes on lower difficulties: a moment of hesitation.
	if _mistake_time > 0.0:
		_mistake_time -= delta
		target_v *= 0.8
	elif randf() < float(skill["mistakes"]) * delta:
		_mistake_time = randf_range(0.4, 1.2)

	var err := target_v - speed
	if err < -1.0:
		ph.in_throttle = 0.0
		ph.in_brake = clampf(-err / 5.0, 0.15, 1.0)
		# Trail braking: ease off the lever as lean increases.
		ph.in_brake *= clampf(1.15 - absf(ph.lean) / maxf(max_lean, 0.1), 0.2, 1.0)
		ph.in_rear = 0.2 if -err > 4.0 else 0.0
	else:
		ph.in_brake = 0.0
		ph.in_rear = 0.0
		ph.in_throttle = clampf(err / 3.0 + 0.35, 0.0, 1.0)
		# Keep grip for leaning: roll the throttle when heavily leaned.
		if absf(ph.lean) > max_lean * 0.8:
			ph.in_throttle = minf(ph.in_throttle, 0.6)
	ph.in_tuck = ph.in_throttle > 0.95 and absf(ph.in_steer) < 0.15 and speed > 25.0
	ph.assist = 1.0

	# --- Stuck recovery.
	if absf(speed) < 2.0 and not ph.is_crashed:
		_stuck_time += delta
		if _stuck_time > 4.0:
			_stuck_time = 0.0
			bike.respawn()
	else:
		_stuck_time = 0.0


func _update_rubber_band(bike: Bike) -> void:
	rubber = 1.0
	if not rubber_band_enabled or progress == null or reference_ids.is_empty():
		return
	var my_d: float = float(progress.riders[bike.index]["race_dist"])
	var best := -INF
	for id in reference_ids:
		best = maxf(best, float(progress.riders[id]["race_dist"]))
	var gap := my_d - best # + = AI ahead of the best human
	var strength := {"easy": 1.0, "medium": 0.7, "hard": 0.4}.get(difficulty, 0.7) as float
	if gap > 60.0:
		rubber = 1.0 - clampf((gap - 60.0) / 400.0, 0.0, 0.07) * strength
	elif gap < -60.0:
		rubber = 1.0 + clampf((-gap - 60.0) / 400.0, 0.0, 0.05) * strength


func _update_traffic(bike: Bike, i: int) -> void:
	var t := line.track
	var ph := bike.physics
	var my_lat := ph.track_lateral
	var line_lat := line.offsets[i]
	var aggression: float = skill["aggression"]
	var desired := 0.0
	var closest_ahead := INF
	for other: Bike in all_bikes:
		if other == bike or other.physics.is_crashed or other.ghost:
			continue
		var od := t.wrap_delta(ph.track_dist, other.physics.track_dist)
		var olat := other.physics.track_lateral
		if od > 0.0 and od < 22.0:
			var rel_speed := ph.speed - other.physics.speed
			if absf(olat - (line_lat + lane)) < 2.2 and (rel_speed > -1.0 or od < 8.0):
				# Pass on the side with more room.
				var room_left := olat + t.half_width
				var room_right := t.half_width - olat
				var side := -1.0 if room_left > room_right else 1.0
				var want := olat + side * 2.6 - line_lat
				if absf(want) > absf(desired) or desired == 0.0:
					desired = want
				closest_ahead = minf(closest_ahead, od)
		elif od < 0.0 and od > -14.0 and aggression > 0.5:
			# Defend: drift toward the attacker's line a little (never block hard).
			if absf(olat - my_lat) > 1.0 and absf(olat - my_lat) < 3.5:
				desired = clampf((olat - line_lat) * 0.35 * aggression, -1.8, 1.8)
	var lim := t.half_width - 1.0
	lane_target = clampf(desired, -lim - line_lat, lim - line_lat)

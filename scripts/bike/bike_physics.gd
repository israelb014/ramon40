class_name BikePhysics
extends RefCounted
## Custom single-track vehicle model (not a car model).
##
## The rider's steering input sets a target lean angle (counter-steering is implicit: the
## bike leans toward the input and the lean produces the yaw rate g*tan(lean)/v, so the
## turning radius grows with speed). At walking pace the handlebar steers directly.
## Tires share a friction circle: braking or accelerating reduces available cornering grip
## (trail braking), exceeding it makes the bike slide; sliding too far crashes.
## Wheelies/stoppies come from longitudinal load transfer. Surfaces change grip and drag.

const G := 9.81
const AIR_DENSITY := 1.2

enum Surface { ASPHALT, SHOULDER, OFFROAD }

signal crashed(reason: String)
signal gear_changed(gear: int)

var spec: Dictionary

# --- Inputs (set every frame) ---
var in_throttle := 0.0
var in_brake := 0.0
var in_rear := 0.0
var in_steer := 0.0
var in_tuck := false
## 0..1: how much the model eases lean to stay inside the grip limit (rider assist).
var assist := 0.6

# --- State ---
var pos := Vector3.ZERO
var yaw := 0.0
var vel := Vector3.ZERO
var speed := 0.0 ## signed forward speed m/s
var lateral_speed := 0.0
var lean := 0.0 ## rad, + = leaning right
var lean_vel := 0.0
var steer_angle := 0.0 ## handlebar angle, rad (visual + low speed)
var pitch := 0.0 ## + = wheelie, - = stoppie
var pitch_vel := 0.0
var ground_pitch := 0.0 ## slope of the ground along the heading
var ground_normal := Vector3.UP
var rpm := 1000.0
var gear := 1
var shift_timer := 0.0
var shift_count := 0
var surface := Surface.ASPHALT
var grip_usage := 0.0 ## demand / capacity of the friction circle
var slip := 0.0 ## lateral slide speed m/s
var slide_angle := 0.0
var wheelspin := 0.0
var front_locked := false
var rear_locked := false
var a_long := 0.0 ## last longitudinal acceleration
var tuck_amount := 0.0
var wheel_front_angle := 0.0
var wheel_rear_angle := 0.0
var suspension_front := 0.0 ## + = compressed
var reversing := false

# Track info (updated every step)
var track_index := -1
var track_dist := 0.0
var track_lateral := 0.0
var off_track_time := 0.0
var wall_hit := 0.0 ## impact speed of the last wall contact (for sound / rumble)

# Crash state
var is_crashed := false
var crash_time := 0.0
var crash_reason := ""
var crash_spin := Vector3.ZERO
var crash_rot := Vector3.ZERO
var _slide_timer := 0.0
var _lock_timer := 0.0
var ghost_time := 0.0 ## > 0: no bike collisions (after respawn)
var crashes_enabled := true

const WHEEL_RADIUS := 0.31


func _init(p_spec: Dictionary = {}) -> void:
	spec = p_spec if not p_spec.is_empty() else GameData.bike("naked")


func forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func right() -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))


func place(xf: Transform3D) -> void:
	pos = xf.origin
	var f := -xf.basis.z
	yaw = atan2(-f.x, -f.z)
	vel = Vector3.ZERO
	speed = 0.0
	lean = 0.0
	lean_vel = 0.0
	pitch = 0.0
	pitch_vel = 0.0
	gear = 1
	rpm = spec["idle"]
	is_crashed = false
	crash_time = 0.0
	_slide_timer = 0.0
	_lock_timer = 0.0
	slip = 0.0
	slide_angle = 0.0
	track_index = -1


## Normalized power curve over the rev range (0..1 of redline).
static func power_curve(x: float) -> float:
	x = clampf(x, 0.0, 1.08)
	if x > 1.0:
		return lerpf(1.0, 0.2, (x - 1.0) / 0.08)
	return clampf(0.18 + 1.55 * x - 0.75 * x * x, 0.0, 1.0)


func gear_top(g: int) -> float:
	return spec["gears"][clampi(g - 1, 0, spec["gears"].size() - 1)]


func rpm_for(u: float, g: int) -> float:
	var r: float = spec["redline"] * absf(u) / gear_top(g)
	return maxf(r, spec["idle"])


func max_lean_at(u: float) -> float:
	var full := deg_to_rad(spec["max_lean"])
	var k := clampf((absf(u) - 1.5) / 10.0, 0.0, 1.0)
	var lean_cap := lerpf(deg_to_rad(8.0), full, k)
	if in_tuck:
		lean_cap *= 0.88
	return lean_cap


func surface_grip() -> float:
	match surface:
		Surface.SHOULDER:
			return lerpf(0.62, 0.9, spec["offroad"])
		Surface.OFFROAD:
			return lerpf(0.42, 0.78, spec["offroad"])
	return 1.0


func surface_resistance(u: float) -> float:
	## Rolling + surface drag as a deceleration (m/s^2).
	match surface:
		Surface.SHOULDER:
			return 0.35 + absf(u) * 0.02 * (1.4 - spec["offroad"])
		Surface.OFFROAD:
			return 1.0 + absf(u) * 0.075 * (1.45 - spec["offroad"])
	return 0.15


## Advances the simulation. `track` may be null (flat ground at y=0, used by tests).
func step(dt: float, track: TrackData = null) -> void:
	if is_crashed:
		_step_crashed(dt, track)
		return
	ghost_time = maxf(ghost_time - dt, 0.0)
	var fwd := forward()
	var rgt := right()
	var u := vel.dot(fwd)
	var mu: float = spec["grip"] * surface_grip()
	var grip_acc := mu * G

	# ---------------- Longitudinal ----------------
	tuck_amount = move_toward(tuck_amount, 1.0 if in_tuck else 0.0, dt * 3.0)
	var cda: float = lerpf(spec["cda"], spec["cda_tuck"], tuck_amount)
	var mass: float = spec["mass"]
	var drag := 0.5 * AIR_DENSITY * cda * u * u / mass
	var roll := surface_resistance(u)
	var slope := sin(ground_pitch) * G

	# Gearbox (automatic, with a short power cut on shifts).
	shift_timer = maxf(shift_timer - dt, 0.0)
	var redline: float = spec["redline"]
	rpm = rpm_for(u, gear)
	if gear == 1 and in_throttle > 0.05:
		# Clutch slip on launch keeps revs up.
		rpm = maxf(rpm, lerpf(spec["idle"], redline * 0.62, in_throttle))
	if shift_timer <= 0.0:
		if rpm > redline * 0.94 and gear < spec["gears"].size() and in_throttle > 0.1:
			gear += 1
			shift_timer = 0.14
			shift_count += 1
			gear_changed.emit(gear)
		elif gear > 1 and rpm_for(u, gear - 1) < redline * 0.82 and (rpm < redline * 0.52 or in_brake > 0.3 and rpm < redline * 0.7):
			gear -= 1
			shift_timer = 0.1
			shift_count += 1
			gear_changed.emit(gear)
	rpm = maxf(rpm_for(u, gear), rpm if gear == 1 else 0.0)
	rpm = clampf(rpm, spec["idle"], redline * 1.02)

	var a_engine := 0.0
	if shift_timer <= 0.0 and in_throttle > 0.0 and not reversing:
		var pf := power_curve(rpm / redline)
		a_engine = in_throttle * minf(spec["power"] * pf / (mass * maxf(u, 3.0)), spec["launch_accel"])
		if pitch > 0.42:
			a_engine *= 0.35 # wheelie control
	# Rear traction limit: excess becomes wheelspin (power slides on loose surfaces).
	var rear_cap := grip_acc * 0.92
	wheelspin = clampf((a_engine - rear_cap) / maxf(rear_cap, 0.1), 0.0, 1.0)
	a_engine = minf(a_engine, rear_cap)
	var engine_brake := 0.0
	if in_throttle < 0.05 and u > 1.0:
		engine_brake = 0.35 + 0.9 * (rpm / redline)

	# Brakes, limited by what the friction circle leaves after cornering.
	var a_lat_demand := G * tan(absf(lean))
	var long_cap := sqrt(maxf(grip_acc * grip_acc - a_lat_demand * a_lat_demand * 0.85, (grip_acc * 0.25) * (grip_acc * 0.25)))
	var front_dem: float = in_brake * spec["brake_front"]
	var rear_dem: float = in_rear * spec["brake_rear"]
	# Rider assist: modulates the lever like an experienced rider (ABS-like) to stay just
	# inside the friction circle; with assist off, over-braking locks the wheels.
	if assist > 0.0 and front_dem + rear_dem > long_cap * 0.97:
		var scale_b := long_cap * 0.97 / (front_dem + rear_dem)
		front_dem = lerpf(front_dem, front_dem * scale_b, assist)
		rear_dem = lerpf(rear_dem, rear_dem * scale_b, assist)
	if pitch < -0.12:
		rear_dem *= 0.2 # rear wheel unloaded in a stoppie
	var brake_dem := front_dem + rear_dem
	var a_brake := brake_dem
	front_locked = false
	rear_locked = false
	if absf(u) > 1.0 and brake_dem > long_cap:
		a_brake = long_cap * 0.82
		front_locked = front_dem > long_cap * 0.75
		rear_locked = not front_locked or rear_dem > long_cap * 0.3
	elif rear_dem > long_cap * 0.45 and absf(u) > 3.0:
		rear_locked = true
		a_brake = front_dem + rear_dem * 0.8

	var resist := drag + roll + engine_brake
	var sgn := signf(u) if absf(u) > 0.05 else 0.0
	var accel := a_engine - slope
	var decel := resist + a_brake
	# Resistive terms oppose motion and cannot reverse it.
	var du := accel * dt
	var new_u := u + du
	if absf(new_u) > 0.0:
		var s2 := signf(new_u)
		new_u = new_u - s2 * minf(absf(new_u), decel * dt)
	# Paddling backwards when stopped with brake held.
	reversing = false
	if u < 0.5 and in_brake > 0.5 and in_throttle < 0.05:
		reversing = true
		new_u = maxf(new_u - 1.2 * dt, -1.6)
	elif new_u < 0.0 and u >= 0.0 and in_brake > 0.05:
		new_u = 0.0
	a_long = (new_u - u) / dt
	u = new_u

	# ---------------- Lean / steering ----------------
	var lean_cap := max_lean_at(u)
	var target := in_steer * lean_cap
	# Assist: ease off lean the rider could not hold with the remaining grip.
	var usable := atan(maxf(sqrt(maxf(grip_acc * grip_acc - a_long * a_long, 0.0)), 0.1) / G)
	if assist > 0.0 and absf(target) > usable:
		target = lerpf(target, signf(target) * usable, assist)
	if u < 1.2:
		target = 0.0
	var rate: float = spec["lean_rate"] * lerpf(1.0, 0.62, clampf((u - 15.0) / 60.0, 0.0, 1.0))
	if in_tuck:
		rate *= 0.85
	if pitch > 0.15:
		rate *= 0.4
	# Critically damped approach to the target lean.
	var lean_acc := (target - lean) * rate * rate * 4.0 - lean_vel * rate * 4.0
	lean_vel += lean_acc * dt
	lean += lean_vel * dt
	var lean_hard := deg_to_rad(spec["max_lean"]) + 0.08
	lean = clampf(lean, -lean_hard, lean_hard)

	var bar_target := in_steer * deg_to_rad(30.0) * (1.0 - clampf((u - 1.0) / 7.0, 0.0, 1.0))
	bar_target += -lean * 0.06 # visual counter-steer hint
	steer_angle = move_toward(steer_angle, bar_target, dt * 3.0)

	var omega_lean := G * tan(lean) / maxf(absf(u), 4.0)
	var omega_steer: float = u * tan(in_steer * deg_to_rad(30.0)) / spec["wheelbase"]
	var k := clampf((absf(u) - 2.5) / 5.0, 0.0, 1.0)
	var omega := lerpf(omega_steer, omega_lean, k)
	if pitch > 0.2:
		omega *= 0.5
	# Loose surfaces + rear lock / wheelspin let the rear step out (dirt slides).
	var loose := 1.0 - surface_grip()
	var rear_slide := (wheelspin * 0.8 + (1.0 if rear_locked else 0.0)) * (0.35 + loose * 1.6)
	omega += in_steer * rear_slide * 0.55
	yaw -= omega * dt

	# ---------------- Tire lateral force ----------------
	fwd = forward()
	rgt = right()
	var v_world := vel
	v_world.y = 0.0
	# Keep forward speed as integrated, carry lateral velocity over from last frame.
	var v_lat := v_world.dot(rgt)
	var lat_cap := sqrt(maxf(grip_acc * grip_acc - a_long * a_long, 0.0))
	if rear_slide > 0.0:
		lat_cap *= 1.0 - clampf(rear_slide * 0.5, 0.0, 0.6)
	var need := absf(v_lat) / dt
	var applied := minf(need, lat_cap)
	v_lat -= signf(v_lat) * applied * dt
	grip_usage = sqrt(a_lat_demand * a_lat_demand + a_long * a_long) / maxf(grip_acc, 0.1)
	vel = fwd * u + rgt * v_lat
	speed = u
	lateral_speed = v_lat
	slip = absf(v_lat)
	slide_angle = atan2(v_lat, maxf(absf(u), 1.0))

	# ---------------- Pitch (wheelie / stoppie) ----------------
	var w_thr: float = 9.0 / spec["wheelie"]
	var target_pitch := 0.0
	if a_long > w_thr and in_throttle > 0.5 and absf(lean) < 0.35:
		target_pitch = clampf((a_long - w_thr) / w_thr * 2.2, 0.0, 0.55)
	var s_thr := 8.4
	if -a_long > s_thr and in_brake > 0.6 and absf(lean) < 0.25 and u < 30.0:
		target_pitch = -clampf((-a_long - s_thr) / s_thr * 1.8, 0.0, 0.32)
	var p_acc := (target_pitch - pitch) * 38.0 - pitch_vel * 9.0
	pitch_vel += p_acc * dt
	pitch += pitch_vel * dt
	if pitch < 0.0 and target_pitch == 0.0:
		pitch = move_toward(pitch, 0.0, dt * 0.8)
	pitch = clampf(pitch, -0.42, 0.9)
	suspension_front = move_toward(suspension_front, clampf(-a_long / 12.0, -0.4, 1.0), dt * 4.0)

	# ---------------- Integrate position ----------------
	pos += vel * dt
	wheel_front_angle = fmod(wheel_front_angle + u * dt / WHEEL_RADIUS, TAU)
	wheel_rear_angle = fmod(wheel_rear_angle + (u + wheelspin * 8.0) * dt / WHEEL_RADIUS, TAU)
	_follow_ground(track, dt)

	# ---------------- Crash checks ----------------
	if not crashes_enabled:
		return
	var slide_limit := 0.42 if surface == Surface.ASPHALT else 0.75
	if absf(slide_angle) > slide_limit and absf(u) > 9.0:
		_slide_timer += dt
		if _slide_timer > 0.22:
			crash("slide")
			return
	else:
		_slide_timer = maxf(_slide_timer - dt * 2.0, 0.0)
	if front_locked and absf(lean) > 0.3 and absf(u) > 6.0:
		_lock_timer += dt
		if _lock_timer > 0.25:
			crash("front_lock")
			return
	else:
		_lock_timer = 0.0
	if pitch > 0.82:
		crash("wheelie")


func _follow_ground(track: TrackData, dt := 0.0) -> void:
	if track == null:
		pos.y = 0.0
		ground_pitch = 0.0
		surface = Surface.ASPHALT
		return
	var proj := track.project(pos, track_index)
	track_index = proj["index"]
	track_dist = proj["dist"]
	track_lateral = proj["lateral"]
	var g := track.ground(pos, proj)
	surface = g["surface"]
	var fwd := forward()
	# Ground slope along the heading from two probes.
	var pa := pos + fwd * 0.8
	var pb := pos - fwd * 0.8
	var ha: float = track.ground(pa, track.project(pa, track_index))["height"]
	var hb: float = track.ground(pb, track.project(pb, track_index))["height"]
	ground_pitch = atan2(ha - hb, 1.6)
	pos.y = g["height"]
	if surface == Surface.OFFROAD:
		off_track_time += dt
	else:
		off_track_time = 0.0
	# Invisible walls (edge of the drivable corridor / tunnel walls).
	var limit := track.wall_limit(track_index)
	wall_hit = 0.0
	if absf(track_lateral) > limit:
		var n: Vector3 = proj["right"] * signf(track_lateral)
		var excess := absf(track_lateral) - limit
		pos -= n * excess
		var vn := vel.dot(n)
		if vn > 0.0:
			wall_hit = vn
			vel -= n * vn * 1.25
			vel *= 0.985
			var fwd2 := forward()
			# Turn the bike along the wall.
			var along := vel - n * vel.dot(n)
			if along.length() > 1.0:
				var target_yaw := atan2(-along.x, -along.z)
				yaw = lerp_angle(yaw, target_yaw, 0.25)
			speed = vel.dot(fwd2)
			if vn > 13.0 and crashes_enabled:
				crash("wall")


func crash(reason: String) -> void:
	if is_crashed:
		return
	is_crashed = true
	crash_time = 0.0
	crash_reason = reason
	var s := vel.length()
	crash_spin = Vector3(randf_range(-2.0, 2.0), randf_range(-4.0, 4.0), signf(lean if lean != 0.0 else 1.0) * (2.0 + s * 0.08))
	crash_rot = Vector3(0, 0, lean)
	crashed.emit(reason)


func _step_crashed(dt: float, track: TrackData) -> void:
	crash_time += dt
	var h := Vector3(vel.x, 0.0, vel.z)
	var s := h.length()
	var decel := 7.5 if surface == Surface.ASPHALT else 11.0
	if s > 0.0:
		h = h / s * maxf(s - decel * dt, 0.0)
	vel = h
	speed = vel.dot(forward())
	pos += vel * dt
	crash_rot += crash_spin * dt
	crash_spin *= maxf(1.0 - dt * 1.4, 0.0)
	rpm = move_toward(rpm, spec["idle"], dt * 6000.0)
	_follow_ground(track, dt)


## Puts the bike back on the track center at the given lap distance, pointing forward.
func respawn(track: TrackData, dist: float, lateral := 0.0) -> void:
	place(track.transform_at(dist, lateral))
	ghost_time = 2.0
	rpm = spec["idle"]
	track_index = track.index_at_distance(dist)
	_follow_ground(track)

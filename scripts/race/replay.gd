class_name ReplayRecorder
extends RefCounted
## Records every bike's visual state at a fixed rate for replays and ghosts.
## Each frame of a bike is a fixed-stride block of floats in a PackedFloat32Array.

const RATE := 30.0
const STRIDE := 23

var times := PackedFloat32Array()
var data: Array = [] # per bike PackedFloat32Array
var _next := 0.0


func _init(bike_count: int) -> void:
	for i in bike_count:
		data.append(PackedFloat32Array())


func record(t: float, bikes: Array) -> void:
	if t < _next:
		return
	_next = t + 1.0 / RATE
	times.append(t)
	for i in mini(bikes.size(), data.size()):
		data[i].append_array(encode(bikes[i].snapshot()))


func frame_count() -> int:
	return times.size()


func duration() -> float:
	return times[times.size() - 1] if times.size() > 0 else 0.0


static func encode(s: Dictionary) -> PackedFloat32Array:
	var p: Vector3 = s["pos"]
	var cr: Vector3 = s["crot"]
	return PackedFloat32Array([p.x, p.y, p.z, s["yaw"], s["lean"], s["pitch"], s["gp"], s["steer"],
		s["spd"], s["rpm"], float(s["gear"]), s["tuck"], 1.0 if s["crash"] else 0.0, cr.x, cr.y, cr.z,
		s["wf"], s["wr"], s["brk"], s["thr"], s["slip"], float(s["surf"]), 0.0])


static func decode(d: PackedFloat32Array, o: int) -> Dictionary:
	return {
		"pos": Vector3(d[o], d[o + 1], d[o + 2]), "yaw": d[o + 3], "lean": d[o + 4], "pitch": d[o + 5],
		"gp": d[o + 6], "steer": d[o + 7], "spd": d[o + 8], "rpm": d[o + 9], "gear": int(d[o + 10]),
		"tuck": d[o + 11], "crash": d[o + 12] > 0.5, "crot": Vector3(d[o + 13], d[o + 14], d[o + 15]),
		"wf": d[o + 16], "wr": d[o + 17], "brk": d[o + 18], "thr": d[o + 19], "slip": d[o + 20],
		"surf": int(d[o + 21]),
	}


## Interpolated snapshot of bike `i` at time `t` using the given time/data arrays.
static func sample(ts: PackedFloat32Array, d: PackedFloat32Array, t: float) -> Dictionary:
	var n := ts.size()
	if n == 0:
		return {}
	if t <= ts[0]:
		return decode(d, 0)
	if t >= ts[n - 1]:
		return decode(d, (n - 1) * STRIDE)
	# Binary search for the frame.
	var lo := 0
	var hi := n - 1
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if ts[mid] <= t:
			lo = mid
		else:
			hi = mid
	var f := (t - ts[lo]) / maxf(ts[hi] - ts[lo], 1e-5)
	var a := decode(d, lo * STRIDE)
	var b := decode(d, hi * STRIDE)
	a["pos"] = (a["pos"] as Vector3).lerp(b["pos"], f)
	a["yaw"] = lerp_angle(a["yaw"], b["yaw"], f)
	for k in ["lean", "pitch", "gp", "steer", "spd", "rpm", "tuck", "brk", "thr", "slip"]:
		a[k] = lerpf(a[k], b[k], f)
	a["crot"] = (a["crot"] as Vector3).lerp(b["crot"], f)
	a["wf"] = lerp_angle(a["wf"], b["wf"], f)
	a["wr"] = lerp_angle(a["wr"], b["wr"], f)
	return a


func sample_bike(i: int, t: float) -> Dictionary:
	return sample(times, data[i], t)


## Copies frames of one bike between two race times into a standalone ghost dictionary
## with times relative to t0.
func extract(i: int, t0: float, t1: float) -> Dictionary:
	var ts := PackedFloat32Array()
	var d := PackedFloat32Array()
	for k in times.size():
		var t := times[k]
		if t >= t0 - 0.001 and t <= t1 + 0.001:
			ts.append(t - t0)
			d.append_array(data[i].slice(k * STRIDE, (k + 1) * STRIDE))
	return {"t": ts, "d": d}

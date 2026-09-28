class_name BikeCollisions
extends RefCounted
## Bike-vs-bike contacts: each bike is a capsule along its heading in the ground plane.

const HALF_LENGTH := 0.72
const RADIUS := 0.36


static func _closest_segments(p1: Vector2, q1: Vector2, p2: Vector2, q2: Vector2) -> Array:
	var d1 := q1 - p1
	var d2 := q2 - p2
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	var c := d1.dot(r)
	var b := d1.dot(d2)
	var denom := a * e - b * b
	if denom > 1e-6:
		s = clampf((b * f - c * e) / denom, 0.0, 1.0)
	t = (b * s + f) / e if e > 1e-6 else 0.0
	if t < 0.0:
		t = 0.0
		s = clampf(-c / a, 0.0, 1.0) if a > 1e-6 else 0.0
	elif t > 1.0:
		t = 1.0
		s = clampf((b - c) / a, 0.0, 1.0) if a > 1e-6 else 0.0
	return [p1 + d1 * s, p2 + d2 * t]


## Resolves all contacts. Returns a list of {a, b, impact} for effects/sounds.
static func resolve(bikes: Array) -> Array:
	var events := []
	for i in bikes.size():
		var A: Bike = bikes[i]
		if A.physics.is_crashed or A.physics.ghost_time > 0.0 or A.ghost:
			continue
		for j in range(i + 1, bikes.size()):
			var B: Bike = bikes[j]
			if B.physics.is_crashed or B.physics.ghost_time > 0.0 or B.ghost:
				continue
			var pa := A.physics.pos
			var pb := B.physics.pos
			if absf(pa.y - pb.y) > 2.5 or Vector2(pa.x - pb.x, pa.z - pb.z).length_squared() > 9.0:
				continue
			var fa := A.physics.forward()
			var fb := B.physics.forward()
			var a0 := Vector2(pa.x + fa.x * HALF_LENGTH, pa.z + fa.z * HALF_LENGTH)
			var a1 := Vector2(pa.x - fa.x * HALF_LENGTH, pa.z - fa.z * HALF_LENGTH)
			var b0 := Vector2(pb.x + fb.x * HALF_LENGTH, pb.z + fb.z * HALF_LENGTH)
			var b1 := Vector2(pb.x - fb.x * HALF_LENGTH, pb.z - fb.z * HALF_LENGTH)
			var cp := _closest_segments(a0, a1, b0, b1)
			var delta: Vector2 = cp[1] - cp[0]
			var dist := delta.length()
			if dist >= RADIUS * 2.0:
				continue
			var n2 := delta / dist if dist > 1e-4 else Vector2(1, 0)
			var n := Vector3(n2.x, 0.0, n2.y)
			var overlap := RADIUS * 2.0 - dist
			var ma: float = A.physics.spec["mass"]
			var mb: float = B.physics.spec["mass"]
			var wa := mb / (ma + mb)
			var wb := ma / (ma + mb)
			A.physics.pos -= n * overlap * wa
			B.physics.pos += n * overlap * wb
			var rel := (B.physics.vel - A.physics.vel).dot(n)
			if rel < 0.0:
				var e := 0.25
				var jimp := -(1.0 + e) * rel / (1.0 / ma + 1.0 / mb)
				A.physics.vel -= n * (jimp / ma)
				B.physics.vel += n * (jimp / mb)
				var impact := -rel
				events.append({"a": A, "b": B, "impact": impact})
				# Hard side hits unsettle the lighter / more side-on bike.
				if impact > 8.5:
					var side_a := absf(fa.dot(n))
					var side_b := absf(fb.dot(n))
					var victim: Bike = A if side_a > side_b else B
					if victim.physics.crashes_enabled and randf() < clampf((impact - 8.5) / 6.0, 0.0, 1.0):
						victim.physics.crash("collision")
	return events

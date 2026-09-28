class_name RoadMesher
extends RefCounted
## Builds road surface, gravel shoulders and tunnel shells from a TrackData centerline.

const CHUNK_SAMPLES := 64


## Returns Array of {"road": arrays, "shoulder": arrays, "center": Vector3}.
static func build_chunks(t: TrackData) -> Array:
	var out := []
	var i0 := 0
	while i0 < t.count:
		var i1 := mini(i0 + CHUNK_SAMPLES, t.count)
		out.append(_chunk(t, i0, i1))
		i0 = i1
	return out


static func _chunk(t: TrackData, i0: int, i1: int) -> Dictionary:
	var hw := t.half_width
	var sw := t.shoulder
	var rv := PackedVector3Array()
	var rn := PackedVector3Array()
	var ruv := PackedVector2Array()
	var ri := PackedInt32Array()
	var sv := PackedVector3Array()
	var sn := PackedVector3Array()
	var suv := PackedVector2Array()
	var si := PackedInt32Array()
	var center := Vector3.ZERO
	var n := 0
	for s in range(i0, i1 + 1):
		var i := s % t.count
		var p := t.points[i]
		var r := t.rights[i]
		var d := t.dists[i] if s < t.count else t.length
		var y := p.y + 0.03
		center += p
		n += 1
		# Road: 5 vertices across so the surface can follow terrain curvature slightly.
		for k in 5:
			var lat := lerpf(-hw, hw, k / 4.0)
			rv.append(Vector3(p.x, y, p.z) + r * lat)
			rn.append(Vector3.UP)
			ruv.append(Vector2(lat, d))
		# Shoulders: inner edge at road level, outer edge dropping to the verge.
		var outer := hw + sw
		var drop := 0.22
		for side in [-1.0, 1.0]:
			sv.append(Vector3(p.x, y - 0.01, p.z) + r * (hw * side))
			sv.append(Vector3(p.x, y - drop, p.z) + r * (outer * side))
			sn.append(Vector3.UP)
			sn.append(Vector3.UP)
			suv.append(Vector2(hw * side, d))
			suv.append(Vector2(outer * side, d))
	var rows := i1 - i0 + 1
	for row in rows - 1:
		var a := row * 5
		var b := (row + 1) * 5
		for k in 4:
			var l0 := a + k
			var r0 := a + k + 1
			var l1 := b + k
			var r1 := b + k + 1
			ri.append_array([l0, r1, r0, l0, l1, r1])
		# Shoulder vertex layout per row: [L_in, L_out, R_in, R_out]
		var sa := row * 4
		var sb := (row + 1) * 4
		# Left shoulder: outer (1) is further left than inner (0).
		si.append_array([sa + 1, sb + 0, sa + 0, sa + 1, sb + 1, sb + 0])
		# Right shoulder: inner (2) left of outer (3).
		si.append_array([sa + 2, sb + 3, sa + 3, sa + 2, sb + 2, sb + 3])
	var road := []
	road.resize(Mesh.ARRAY_MAX)
	road[Mesh.ARRAY_VERTEX] = rv
	road[Mesh.ARRAY_NORMAL] = rn
	road[Mesh.ARRAY_TEX_UV] = ruv
	road[Mesh.ARRAY_INDEX] = ri
	var shoulder := []
	shoulder.resize(Mesh.ARRAY_MAX)
	shoulder[Mesh.ARRAY_VERTEX] = sv
	shoulder[Mesh.ARRAY_NORMAL] = sn
	shoulder[Mesh.ARRAY_TEX_UV] = suv
	shoulder[Mesh.ARRAY_INDEX] = si
	return {"road": road, "shoulder": shoulder, "center": center / maxi(n, 1)}


## Tunnel shells for every tunnel range. Returns Array of {"shell": ArrayMesh builder data,
## "portals": [Transform3D], "lights": [Vector3]}.
static func build_tunnels(t: TrackData) -> Array:
	var out := []
	# Find contiguous tunnel runs.
	var runs := []
	var in_run := false
	var start := 0
	for k in t.count:
		var inside: bool = t.tunnel[k] == 1
		if inside and not in_run:
			in_run = true
			start = k
		elif not inside and in_run:
			in_run = false
			runs.append([start, k - 1])
	if in_run:
		runs.append([start, t.count - 1])
	for run in runs:
		var mb := MeshBuilder.new(false)
		mb.surface("concrete")
		mb.invert_faces = true
		var rings := []
		var profile := _tunnel_profile(t.half_width + 0.6)
		for k in range(run[0], run[1] + 1):
			var p := t.points[k]
			var r := t.rights[k]
			var ring := PackedVector3Array()
			for q in profile:
				ring.append(p + r * q.x + Vector3.UP * q.y)
			rings.append(ring)
		mb.add_rings(rings, Color(0.62, 0.60, 0.56), false)
		mb.invert_faces = false
		# Emissive light strip along the ceiling.
		mb.surface("lamp")
		var lights := []
		for k in range(run[0], run[1] + 1, 3):
			var p := t.points[k]
			var tt := t.tangents[k]
			var r := t.rights[k]
			var c := p + Vector3.UP * 6.65
			var xf := Transform3D(Basis(r, Vector3.UP, -tt), c)
			mb.add_box(xf, Vector3(0.35, 0.06, 2.4), Color(1, 0.85, 0.6))
		for k in range(run[0] + 6, run[1], 16):
			lights.append(t.points[k] + Vector3.UP * 6.0)
		var portals := []
		for k in [run[0], run[1]]:
			var tt: Vector3 = t.tangents[k]
			if k == run[1]:
				tt = -tt
			portals.append(Transform3D(Basis(t.rights[k] if k == run[0] else -t.rights[k], Vector3.UP, -tt), t.points[k]))
		out.append({"builder": mb, "portals": portals, "lights": lights, "run": run})
	return out


## Cross-section of a tunnel: vertical walls then an arch. Returns Vector2(lateral, height),
## ordered from the right wall base, over the top, to the left wall base.
static func _tunnel_profile(hw: float) -> Array:
	var pts := []
	pts.append(Vector2(hw, -0.3))
	pts.append(Vector2(hw, 4.2))
	for k in range(1, 10):
		var a := PI * float(k) / 10.0
		pts.append(Vector2(cos(a) * hw, 4.2 + sin(a) * 2.6))
	pts.append(Vector2(-hw, 4.2))
	pts.append(Vector2(-hw, -0.3))
	return pts

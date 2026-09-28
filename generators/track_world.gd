class_name TrackWorld
extends Node3D
## The complete 3D world of a track: terrain, road, props, landmarks, sky and lighting.
## Heavy data generation (`generate_data`) is thread-safe; `assemble` creates the nodes.

const PROP_TILE := 320.0

const TERRAIN_PALETTES := {
	"ramon": {
		"base_color": Color(0.80, 0.56, 0.38), "base_color2": Color(0.70, 0.44, 0.32),
		"rock_color": Color(0.55, 0.28, 0.24), "strata_a": Color(0.74, 0.30, 0.22),
		"strata_b": Color(0.46, 0.25, 0.40), "strata_c": Color(0.90, 0.70, 0.46),
		"verge_color": Color(0.74, 0.62, 0.50), "vegetation_color": Color(0.40, 0.40, 0.22),
		"strata_scale": 0.14, "strata_strength": 1.0, "vegetation_amount": 0.0,
	},
	"deadsea": {
		"base_color": Color(0.82, 0.74, 0.60), "base_color2": Color(0.74, 0.64, 0.50),
		"rock_color": Color(0.66, 0.54, 0.42), "strata_a": Color(0.74, 0.62, 0.48),
		"strata_b": Color(0.60, 0.50, 0.40), "strata_c": Color(0.86, 0.80, 0.68),
		"verge_color": Color(0.84, 0.80, 0.72), "vegetation_color": Color(0.46, 0.48, 0.26),
		"strata_scale": 0.06, "strata_strength": 0.7, "vegetation_amount": 0.0,
	},
	"jerusalem": {
		"base_color": Color(0.46, 0.34, 0.24), "base_color2": Color(0.56, 0.42, 0.30),
		"rock_color": Color(0.74, 0.70, 0.62), "strata_a": Color(0.78, 0.74, 0.64),
		"strata_b": Color(0.66, 0.62, 0.54), "strata_c": Color(0.84, 0.80, 0.70),
		"verge_color": Color(0.62, 0.56, 0.46), "vegetation_color": Color(0.22, 0.30, 0.14),
		"strata_scale": 0.35, "strata_strength": 0.5, "vegetation_amount": 0.75,
	},
	"flat": {},
}

var track: TrackData
var environment_node: WorldEnvironment
var sun: DirectionalLight3D
var sky_material: ShaderMaterial
var tod := "sunset"
var trackside_cameras: Array[Transform3D] = []


## Heavy, node-free generation. Safe to call from a WorkerThreadPool task.
static func generate_data(track_id: String, with_props := true, veg_density := 1.0) -> Dictionary:
	var t := TrackData.build(TrackLayouts.get_layout(track_id))
	var data := {
		"track": t,
		"terrain": TerrainMesher.build_core_chunks(t),
		"far": TerrainMesher.build_far(t),
		"road": RoadMesher.build_chunks(t),
		"tunnels": RoadMesher.build_tunnels(t),
		"props": {},
	}
	if with_props:
		var placer := PropPlacer.new(t, veg_density)
		data["props"] = placer.place_all()
	return data


func assemble(data: Dictionary, quality_draw := 2) -> void:
	track = data["track"]
	name = "TrackWorld_" + track.id
	var info: Dictionary = GameData.TRACKS.get(track.id, {})
	tod = info.get("time_of_day", "sunset")
	_build_environment()
	_build_terrain(data["terrain"], data["far"])
	_build_road(data["road"])
	_build_tunnels(data["tunnels"])
	_build_props(data["props"], quality_draw)
	_build_landmarks()
	_build_extras()
	_compute_trackside_cameras()


func _build_environment() -> void:
	var e := EnvironmentBuilder.build(tod)
	environment_node = WorldEnvironment.new()
	environment_node.environment = e["environment"]
	add_child(environment_node)
	sun = e["sun"]
	add_child(sun)
	sky_material = e["sky_material"]


func _terrain_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/terrain.gdshader")
	var pal: Dictionary = TERRAIN_PALETTES.get(track.style.style, {})
	for k in pal:
		m.set_shader_parameter(k, pal[k])
	return m


func _build_terrain(chunks: Array, far_arrays: Array) -> void:
	var mat := _terrain_material()
	var root := Node3D.new()
	root.name = "Terrain"
	add_child(root)
	for c in chunks:
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, c["arrays"])
		mesh.surface_set_material(0, mat)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		root.add_child(mi)
	var far := ArrayMesh.new()
	far.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, far_arrays)
	far.surface_set_material(0, mat)
	var fmi := MeshInstance3D.new()
	fmi.name = "FarTerrain"
	fmi.mesh = far
	fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fmi)
	var water := track.style.water_level()
	if water > -INF:
		var wm := MeshInstance3D.new()
		wm.name = "Sea"
		var plane := PlaneMesh.new()
		plane.size = Vector2(24000, 24000)
		plane.subdivide_width = 4
		plane.subdivide_depth = 4
		var wmat := ShaderMaterial.new()
		wmat.shader = load("res://shaders/water.gdshader")
		plane.material = wmat
		wm.mesh = plane
		wm.position = Vector3(track.bounds().get_center().x + 9000.0, water, track.bounds().get_center().y)
		wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(wm)


func _build_road(chunks: Array) -> void:
	var road_mat := ShaderMaterial.new()
	road_mat.shader = load("res://shaders/road.gdshader")
	road_mat.set_shader_parameter("half_width", track.half_width)
	road_mat.set_shader_parameter("lap_length", track.length)
	road_mat.set_shader_parameter("marking_emission", 0.05 if tod == "night" else 0.0)
	var sh_mat := ShaderMaterial.new()
	sh_mat.shader = load("res://shaders/gravel.gdshader")
	var pal: Dictionary = TERRAIN_PALETTES.get(track.style.style, {})
	sh_mat.set_shader_parameter("gravel_color", pal.get("verge_color", Color(0.6, 0.55, 0.5)))
	var root := Node3D.new()
	root.name = "Road"
	add_child(root)
	for c in chunks:
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, c["road"])
		mesh.surface_set_material(0, road_mat)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, c["shoulder"])
		mesh.surface_set_material(1, sh_mat)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)


func _build_tunnels(tunnels: Array) -> void:
	for tn in tunnels:
		var mb: MeshBuilder = tn["builder"]
		var concrete := StandardMaterial3D.new()
		concrete.vertex_color_use_as_albedo = true
		concrete.roughness = 0.9
		var mi := MeshInstance3D.new()
		mi.name = "Tunnel"
		mi.mesh = mb.commit({"concrete": concrete, "lamp": PropMeshes.lamp_material(Color(1.0, 0.78, 0.45), 3.0)})
		add_child(mi)
		for p in tn["portals"]:
			var portal := Landmarks.tunnel_portal(track.half_width)
			portal.transform = p
			add_child(portal)
		for lp in tn["lights"]:
			var l := OmniLight3D.new()
			l.position = lp
			l.omni_range = 16.0
			l.light_energy = 2.2
			l.light_color = Color(1.0, 0.75, 0.45)
			l.distance_fade_enabled = true
			l.distance_fade_begin = 160.0
			l.distance_fade_length = 40.0
			add_child(l)


static func _prop_base(id: String) -> String:
	var us := id.rfind("_")
	if us > 0 and id.substr(us + 1).is_valid_int():
		return id.substr(0, us)
	return id


func _prop_mesh(id: String) -> ArrayMesh:
	var base := id
	var variant := 0
	var us := id.rfind("_")
	if us > 0 and id.substr(us + 1).is_valid_int():
		base = id.substr(0, us)
		variant = int(id.substr(us + 1))
	var seed_value := variant * 31 + 7
	match base:
		"post":
			return PropMeshes.reflector_post()
		"rock_big":
			var c := Color(0.62, 0.34, 0.27) if track.style.style == "ramon" else Color(0.66, 0.56, 0.44)
			return PropMeshes.rock(seed_value, c, 1.0, 0.65)
		"rock_small":
			var c2 := Color(0.52, 0.30, 0.26) if track.style.style == "ramon" else Color(0.62, 0.52, 0.42)
			return PropMeshes.rock(seed_value + 5, c2, 1.0, 0.6)
		"rock_lime":
			return PropMeshes.rock(seed_value + 9, Color(0.78, 0.75, 0.68), 1.0, 0.55)
		"acacia":
			return PropMeshes.acacia(seed_value)
		"palm":
			return PropMeshes.palm(seed_value, 8.0 + variant)
		"pine":
			return PropMeshes.pine(seed_value)
		"cypress":
			return PropMeshes.cypress(seed_value)
		"bush_dry":
			return PropMeshes.bush(seed_value, Color(0.48, 0.46, 0.28))
		"bush_green":
			return PropMeshes.bush(seed_value, Color(0.22, 0.32, 0.14))
		"wall":
			return PropMeshes.stone_wall(seed_value)
		"streetlight":
			return PropMeshes.streetlight()
	return PropMeshes.rock(1, Color.GRAY)


func _prop_range(base: String, quality_draw: int) -> float:
	var mult: float = [0.55, 0.8, 1.0, 1.4][clampi(quality_draw, 0, 3)]
	match base:
		"post", "rock_small", "bush_dry", "bush_green", "wall":
			return 320.0 * mult
		"streetlight", "cypress", "palm", "acacia", "pine":
			return 1100.0 * mult
	return 800.0 * mult


func _build_props(groups: Dictionary, quality_draw: int) -> void:
	var root := Node3D.new()
	root.name = "Props"
	add_child(root)
	for id in groups:
		var mesh := _prop_mesh(id)
		var base := _prop_base(String(id))
		var tiles: Dictionary = {}
		for xf in groups[id]:
			var key := Vector2i(floori(xf.origin.x / PROP_TILE), floori(xf.origin.z / PROP_TILE))
			if not tiles.has(key):
				tiles[key] = []
			tiles[key].append(xf)
		var small := base in ["post", "rock_small", "bush_dry", "bush_green"]
		for key in tiles:
			var list: Array = tiles[key]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = list.size()
			for k in list.size():
				mm.set_instance_transform(k, list[k])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.visibility_range_end = _prop_range(base, quality_draw)
			mmi.visibility_range_end_margin = 40.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			if small or quality_draw == 0:
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mmi)
		if base == "streetlight":
			for xf in groups[id]:
				var l := OmniLight3D.new()
				l.position = xf * Vector3(2.1, 8.2, 0)
				l.omni_range = 30.0
				l.omni_attenuation = 1.1
				l.light_energy = 3.6
				l.light_color = Color(1.0, 0.78, 0.48)
				l.distance_fade_enabled = true
				l.distance_fade_begin = 140.0 + 60.0 * quality_draw
				l.distance_fade_length = 40.0
				root.add_child(l)


func _build_landmarks() -> void:
	var g := Landmarks.gantry(track.half_width + track.shoulder + 1.2, String(track.layout.get("banner", "")), tod == "night")
	g.transform = track.transform_at(0.0)
	add_child(g)
	for s in track.layout.get("signs", []):
		var d: float = float(s["at"]) * track.length
		var side: float = float(s["side"])
		var sign := Landmarks.direction_sign(s["lines"], String(s.get("sub", "")))
		var xf := track.transform_at(d, side * (track.half_width + track.shoulder + 2.8))
		# Face oncoming traffic: board +Z points back along the road.
		var tan := track.tangent_at_distance(d)
		xf.basis = Basis(Vector3.UP.cross(-tan).normalized(), Vector3.UP, -tan)
		xf.origin.y = track.point_at_distance(d).y - 0.1
		sign.transform = xf
		add_child(sign)


func _build_extras() -> void:
	if track.style.style == "jerusalem":
		_city_lights()


## Distant city lights on the eastern hills (Jerusalem glow).
func _city_lights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	var b := track.bounds()
	var mb := MeshBuilder.new(true)
	mb.surface("lamp")
	var mesh_box := BoxMesh.new()
	mesh_box.size = Vector3(0.9, 0.9, 0.9)
	mesh_box.material = PropMeshes.lamp_material(Color(1.0, 0.76, 0.46), 2.2)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh_box
	var count := 1800
	mm.instance_count = count
	for k in count:
		var x := b.end.x + rng.randf_range(700.0, 4500.0)
		var z := b.get_center().y + rng.randf_range(-3500.0, 3500.0)
		var h := track.style.height(x, z)
		var s := rng.randf_range(0.6, 1.8)
		mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(x, h + 2.0, z)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "CityLights"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## Places TV cameras along the track for replays: alternating sides, raised.
func _compute_trackside_cameras() -> void:
	trackside_cameras.clear()
	var d := 30.0
	var n := 0
	while d < track.length:
		var i := track.index_at_distance(d)
		var side := 1.0 if n % 2 == 0 else -1.0
		var lat := (track.half_width + track.shoulder + 6.0) * side
		if track.tunnel[i] == 1:
			lat = (track.half_width - 0.5) * side
		var p := track.point_at_distance(d) + track.rights[i] * lat
		var ground := track.terrain_height(p.x, p.z) if track.tunnel[i] == 0 else p.y
		p.y = maxf(ground, track.points[i].y) + (2.5 if track.tunnel[i] == 1 else 4.5)
		trackside_cameras.append(Transform3D(Basis(), p))
		d += 150.0
		n += 1


func camera_near(dist: float) -> int:
	## Index of the trackside camera best placed to see a rider at lap distance `dist`.
	var best := 0
	var best_d := INF
	for k in trackside_cameras.size():
		var cam_d := 30.0 + k * 150.0
		var dd := track.wrap_delta(dist, cam_d)
		# Prefer cameras slightly ahead of the rider.
		var score := absf(dd - 40.0)
		if score < best_d:
			best_d = score
			best = k
	return best

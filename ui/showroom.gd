class_name Showroom
extends Node3D
## Garage showroom: a lit turntable stage in its own world, shown through a SubViewport.

var bike: Bike
var stage: Node3D
var cam: Camera3D
var _angle := 0.6
var _target_angle := 0.6
var _auto := true
var _t := 0.0
var _bike_id := ""


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("120b14")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.45, 0.55)
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.1
	e.glow_enabled = true
	e.glow_bloom = 0.05
	e.ssao_enabled = true
	e.fog_enabled = true
	e.fog_light_color = Color("24132a")
	e.fog_density = 0.02
	e.fog_sky_affect = 0.0
	env.environment = e
	add_child(env)
	# Floor with a soft radial spotlight pool and a turntable.
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("1a1119")
	fm.roughness = 0.25
	fm.metallic = 0.3
	pm.material = fm
	floor_mi.mesh = pm
	add_child(floor_mi)
	stage = Node3D.new()
	add_child(stage)
	var tt := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.0
	cyl.bottom_radius = 2.05
	cyl.height = 0.12
	cyl.radial_segments = 64
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color("2b1d2e")
	tm.metallic = 0.6
	tm.roughness = 0.2
	cyl.material = tm
	tt.mesh = cyl
	tt.position.y = 0.06
	stage.add_child(tt)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.02
	torus.outer_radius = 2.08
	torus.rings = 64
	var rm := StandardMaterial3D.new()
	rm.albedo_color = UITheme.ACCENT
	rm.emission_enabled = true
	rm.emission = UITheme.ACCENT
	rm.emission_energy_multiplier = 2.5
	torus.material = rm
	ring.mesh = torus
	ring.position.y = 0.1
	stage.add_child(ring)
	# Three-point lighting.
	_spot(Vector3(3.5, 5.5, 3.0), Color(1.0, 0.86, 0.72), 32.0)
	_spot(Vector3(-4.0, 4.0, 1.5), Color(0.7, 0.75, 1.0), 20.0)
	_spot(Vector3(0.0, 4.5, -4.5), Color(1.0, 0.55, 0.35), 26.0)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55, 30, 0)
	key.light_energy = 0.35
	key.shadow_enabled = true
	add_child(key)
	cam = Camera3D.new()
	cam.fov = 34.0
	add_child(cam)
	cam.current = true
	_update_cam()


func _spot(pos: Vector3, col: Color, energy: float) -> void:
	var s := SpotLight3D.new()
	s.position = pos
	s.light_color = col
	s.light_energy = energy
	s.spot_range = 14.0
	s.spot_angle = 32.0
	s.shadow_enabled = true
	add_child(s)
	s.look_at(Vector3(0, 0.6, 0), Vector3.UP)


func show_bike(bike_id: String, colors: Dictionary) -> void:
	if bike and _bike_id == bike_id:
		bike.set_paint(colors.get("paint", Color.RED), colors.get("accent", Color.WHITE))
		if bike.rider:
			bike.rider.set_colors(colors.get("suit_main", Color.BLACK), colors.get("suit_accent", Color.RED), Color(0.95, 0.95, 0.95))
		return
	if bike:
		bike.queue_free()
	_bike_id = bike_id
	bike = Bike.new()
	stage.add_child(bike)
	bike.world_root = stage
	bike.setup(bike_id, null, colors)
	bike.place_at(Transform3D(Basis(), Vector3(0, 0.12, 0)))
	bike.physics.pos.y = 0.12
	bike.sync_visual(0.1)
	# Pop-in animation.
	bike.scale = Vector3.ONE * 0.85
	var tw := create_tween()
	tw.tween_property(bike, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func rotate_by(amount: float) -> void:
	_target_angle += amount
	_auto = false


func _process(delta: float) -> void:
	_t += delta
	if _auto:
		_target_angle += delta * 0.25
	_angle = lerp_angle(_angle, _target_angle, clampf(delta * 5.0, 0.0, 1.0))
	stage.rotation.y = _angle
	if bike:
		bike.global_position.y = 0.12
		bike.physics.pos = bike.global_position
		for i in 2:
			bike.sync_visual(delta)
		bike.global_transform = Transform3D(stage.global_transform.basis, stage.global_position + Vector3(0, 0.12, 0))
	_update_cam()


func _update_cam() -> void:
	cam.position = Vector3(0.0, 1.6 + sin(_t * 0.3) * 0.08, 6.4)
	cam.look_at(Vector3(0, 0.62, 0), Vector3.UP)

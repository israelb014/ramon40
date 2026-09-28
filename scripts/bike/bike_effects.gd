class_name BikeEffects
extends Node3D
## Per-bike particles: dust off the asphalt, tire smoke when sliding or locking a wheel,
## sparks when a crashed bike scrapes along the road. Particle counts follow the quality
## setting.

var bike: Bike
var dust: GPUParticles3D
var smoke: GPUParticles3D
var sparks: GPUParticles3D
var _quality := 2
var _dust_color := Color(0.8, 0.65, 0.5)

static var _soft_tex: Texture2D


static func soft_texture() -> Texture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 64
		gt.height = 64
		_soft_tex = gt
	return _soft_tex


func setup(p_bike: Bike) -> void:
	bike = p_bike
	_quality = int(Settings.get_value("particles", 2))
	if _quality <= 0:
		return
	var style := bike.track.style.style if bike.track else "ramon"
	_dust_color = {"ramon": Color(0.82, 0.55, 0.40), "deadsea": Color(0.88, 0.84, 0.74), "jerusalem": Color(0.62, 0.52, 0.42)}.get(style, Color(0.8, 0.7, 0.6))
	var mult := 1.0 if _quality >= 2 else 0.5
	dust = _make_puffs(int(48 * mult), 1.6, _dust_color, 2.2, 0.9)
	smoke = _make_puffs(int(40 * mult), 1.3, Color(0.85, 0.85, 0.88), 1.6, 0.6)
	sparks = _make_sparks(int(60 * mult))
	for p in [dust, smoke, sparks]:
		add_child(p)
		p.emitting = false


func _make_puffs(amount: int, lifetime: float, color: Color, size: float, spread: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(amount, 4)
	p.lifetime = lifetime
	p.local_coords = false
	p.fixed_fps = 30
	p.visibility_aabb = AABB(Vector3(-20, -5, -20), Vector3(40, 15, 40))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0.6)
	pm.spread = 35.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0, 0.35, 0)
	pm.damping_min = 1.2
	pm.damping_max = 2.0
	pm.scale_min = size * 0.5
	pm.scale_max = size
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.35))
	curve.add_point(Vector2(1, 1.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.set_color(0, Color(color, 0.55 * spread))
	grad.set_color(1, Color(color, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.2
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = soft_texture()
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	quad.material = mat
	p.draw_pass_1 = quad
	return p


func _make_sparks(amount: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(amount, 8)
	p.lifetime = 0.45
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-20, -5, -20), Vector3(40, 15, 40))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.6, 1)
	pm.spread = 55.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 9.0
	pm.gravity = Vector3(0, -12, 0)
	pm.scale_min = 0.03
	pm.scale_max = 0.07
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.9, 0.5, 1))
	grad.set_color(1, Color(1.0, 0.35, 0.05, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 4)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.2)
	mat.emission_energy_multiplier = 4.0
	mat.albedo_texture = soft_texture()
	quad.material = mat
	p.draw_pass_1 = quad
	return p


func _process(_delta: float) -> void:
	if bike == null or dust == null:
		return
	var ph := bike.physics
	var speed := absf(ph.speed)
	var rear := bike.global_transform * Vector3(0, 0.1, 0.7)
	dust.global_position = rear
	smoke.global_position = rear
	var crashed := ph.is_crashed
	var offroad := ph.surface != BikePhysics.Surface.ASPHALT
	dust.emitting = (offroad and speed > 4.0) or (crashed and offroad and ph.vel.length() > 2.0)
	var sliding := ph.slip > 1.6 or (ph.rear_locked and speed > 6.0) or (ph.wheelspin > 0.25 and speed > 2.0)
	smoke.emitting = sliding and not offroad and not crashed
	sparks.emitting = crashed and not offroad and ph.vel.length() > 3.0
	if sparks.emitting:
		sparks.global_position = bike.global_position + Vector3.UP * 0.15

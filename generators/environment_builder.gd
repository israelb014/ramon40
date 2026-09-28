class_name EnvironmentBuilder
extends RefCounted
## Sky, sun and post-processing for each time of day, respecting the quality settings.

const TIMES := {
	"sunset": {
		"sun_az": 262.0, "sun_el": 11.0, "sun_color": Color(1.0, 0.60, 0.34), "sun_energy": 1.9,
		"zenith_day": Color(0.20, 0.30, 0.58), "horizon_day": Color(0.85, 0.72, 0.62),
		"zenith_sunset": Color(0.17, 0.14, 0.38), "horizon_sunset": Color(1.0, 0.50, 0.26),
		"ground": Color(0.30, 0.16, 0.13), "night": 0.0, "stars": 0.0, "clouds": 0.42,
		"cloud_color": Color(1.0, 0.72, 0.60), "city_glow": 0.0,
		"fog_color": Color(0.78, 0.50, 0.40), "fog_density": 0.00035, "fog_sky_affect": 0.2,
		"fog_height": -40.0, "fog_height_density": 0.002, "vol_fog_density": 0.006, "vol_fog_albedo": Color(1.0, 0.75, 0.6),
		"ambient_energy": 1.1, "exposure": 1.05, "white": 6.0, "glow_bloom": 0.08, "glow_strength": 1.0,
		"adjust_saturation": 1.12, "adjust_contrast": 1.06,
	},
	"midday": {
		"sun_az": 150.0, "sun_el": 62.0, "sun_color": Color(1.0, 0.96, 0.90), "sun_energy": 2.3,
		"zenith_day": Color(0.18, 0.40, 0.76), "horizon_day": Color(0.72, 0.80, 0.86),
		"zenith_sunset": Color(0.18, 0.40, 0.76), "horizon_sunset": Color(0.9, 0.8, 0.7),
		"ground": Color(0.55, 0.48, 0.40), "night": 0.0, "stars": 0.0, "clouds": 0.18,
		"cloud_color": Color(1.0, 1.0, 1.0), "city_glow": 0.0,
		"fog_color": Color(0.82, 0.84, 0.86), "fog_density": 0.00032, "fog_sky_affect": 0.35,
		"fog_height": -30.0, "fog_height_density": 0.002, "vol_fog_density": 0.004, "vol_fog_albedo": Color(0.95, 0.95, 1.0),
		"ambient_energy": 0.85, "exposure": 0.92, "white": 7.0, "glow_bloom": 0.03, "glow_strength": 0.8,
		"adjust_saturation": 1.05, "adjust_contrast": 1.04,
	},
	"night": {
		"sun_az": 120.0, "sun_el": 38.0, "sun_color": Color(0.55, 0.66, 1.0), "sun_energy": 0.28,
		"zenith_day": Color(0.02, 0.03, 0.08), "horizon_day": Color(0.07, 0.09, 0.16),
		"zenith_sunset": Color(0.02, 0.03, 0.08), "horizon_sunset": Color(0.07, 0.09, 0.16),
		"ground": Color(0.02, 0.02, 0.03), "night": 1.0, "stars": 1.0, "clouds": 0.25,
		"cloud_color": Color(0.35, 0.38, 0.5), "city_glow": 0.7,
		"fog_color": Color(0.06, 0.07, 0.12), "fog_density": 0.0011, "fog_sky_affect": 0.15,
		"fog_height": 0.0, "fog_height_density": 0.004, "vol_fog_density": 0.012, "vol_fog_albedo": Color(0.6, 0.65, 0.8),
		"ambient_energy": 0.35, "exposure": 1.35, "white": 5.0, "glow_bloom": 0.12, "glow_strength": 1.2,
		"adjust_saturation": 1.1, "adjust_contrast": 1.08,
	},
}


static func sun_direction(az_deg: float, el_deg: float) -> Vector3:
	var az := deg_to_rad(az_deg)
	var el := deg_to_rad(el_deg)
	return Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el)).normalized()


## Builds a WorldEnvironment and the sun/moon light for a time of day.
static func build(tod: String) -> Dictionary:
	var c: Dictionary = TIMES.get(tod, TIMES["sunset"])
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	for key in ["zenith_day", "horizon_day", "zenith_sunset", "horizon_sunset"]:
		sky_mat.set_shader_parameter(key, c[key])
	sky_mat.set_shader_parameter("ground_color", c["ground"])
	sky_mat.set_shader_parameter("night", c["night"])
	sky_mat.set_shader_parameter("star_amount", c["stars"])
	sky_mat.set_shader_parameter("cloud_amount", c["clouds"])
	sky_mat.set_shader_parameter("cloud_color", c["cloud_color"])
	sky_mat.set_shader_parameter("city_glow", c["city_glow"])
	sky_mat.set_shader_parameter("city_glow_dir", Vector3(1, 0, 0.2))
	sky_mat.set_shader_parameter("sun_size", 0.99955 if tod != "night" else 0.99975)

	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_AUTOMATIC

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = c["ambient_energy"]
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = c["exposure"]
	env.tonemap_white = c["white"]
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = c["fog_color"]
	env.fog_density = c["fog_density"]
	env.fog_sky_affect = c["fog_sky_affect"]
	env.fog_sun_scatter = 0.25
	env.fog_height = c["fog_height"]
	env.fog_height_density = c["fog_height_density"]
	env.fog_aerial_perspective = 0.35
	env.volumetric_fog_density = c["vol_fog_density"]
	env.volumetric_fog_albedo = c["vol_fog_albedo"]
	env.volumetric_fog_emission = Color(0, 0, 0)
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 180.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_strength = c["glow_strength"]
	env.glow_bloom = c["glow_bloom"]
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.0
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 0.8)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.4)
	env.adjustment_enabled = true
	env.adjustment_saturation = c["adjust_saturation"]
	env.adjustment_contrast = c["adjust_contrast"]
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.8
	env.ssao_power = 1.4
	env.ssil_radius = 5.0
	env.ssil_intensity = 0.8
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.4
	env.sdfgi_energy = 0.8

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	var dir := sun_direction(c["sun_az"], c["sun_el"])
	sun.transform = Transform3D(Basis.looking_at(-dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD), Vector3.ZERO)
	sun.light_color = c["sun_color"]
	sun.light_energy = c["sun_energy"]
	sun.light_angular_distance = 0.6
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 220.0
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.18
	sun.directional_shadow_split_3 = 0.45
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.85
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	sun.light_volumetric_fog_energy = 1.2 if tod == "sunset" else 0.8
	apply_quality(env, sun)
	return {"environment": env, "sun": sun, "sky_material": sky_mat, "config": c}


## Applies the current graphics settings to an environment and sun.
static func apply_quality(env: Environment, sun: DirectionalLight3D) -> void:
	var s: Dictionary = Settings.data
	env.ssao_enabled = bool(s.get("ssao", true))
	env.ssil_enabled = bool(s.get("ssil", false))
	env.sdfgi_enabled = bool(s.get("sdfgi", false))
	env.volumetric_fog_enabled = bool(s.get("volumetric_fog", false))
	env.glow_enabled = bool(s.get("glow", true))
	var shadows := int(s.get("shadows", 2))
	if sun:
		sun.shadow_enabled = shadows > 0
		match shadows:
			1:
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
				sun.directional_shadow_max_distance = 120.0
				sun.directional_shadow_split_1 = 0.2
			2:
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
				sun.directional_shadow_max_distance = 200.0
			3:
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
				sun.directional_shadow_max_distance = 320.0
	var size := 2048 if shadows <= 1 else (4096 if shadows == 2 else 8192)
	RenderingServer.directional_shadow_atlas_set_size(size, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW if shadows <= 1 else RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_LOW if shadows <= 1 else RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 2, 50, 300)
	RenderingServer.environment_set_volumetric_fog_volume_size(64 if shadows <= 2 else 96, 64)


## Applies anti-aliasing and render scale to a viewport.
static func apply_viewport_quality(vp: Viewport) -> void:
	var s: Dictionary = Settings.data
	var aa: String = s.get("aa", "taa")
	var scale: float = clampf(float(s.get("render_scale", 1.0)), 0.5, 1.0)
	vp.use_taa = false
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = scale
	match aa:
		"fxaa":
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			if scale < 1.0:
				vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		"taa":
			vp.use_taa = true
			if scale < 1.0:
				vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		"fsr2":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
			vp.scaling_3d_scale = minf(scale, 0.9) if scale < 1.0 else 1.0
	vp.mesh_lod_threshold = 1.0 if int(s.get("draw_distance", 2)) >= 2 else 2.0

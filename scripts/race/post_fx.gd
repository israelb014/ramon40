class_name PostFX
extends ColorRect
## Screen-space motion blur / heat haze overlay driven by rider speed and settings.

var _mat: ShaderMaterial
var _haze_base := 0.0
var _blur := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(style: String) -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/post_fx.gdshader")
	material = _mat
	_haze_base = {"ramon": 0.35, "deadsea": 1.0, "jerusalem": 0.0}.get(style, 0.0)
	update_fx(0.0, false, 0.0)


## Updates the sun flare from the active camera and the scene's sun light.
func update_flare(cam: Camera3D, sun: DirectionalLight3D) -> void:
	if _mat == null or cam == null or sun == null or not is_instance_valid(cam):
		return
	var sun_dir := sun.global_transform.basis.z.normalized()
	var facing := -cam.global_transform.basis.z.dot(sun_dir)
	var amount := 0.0
	if facing > 0.0 and sun_dir.y > -0.02 and sun.light_energy > 0.8:
		var world_p := cam.global_position + sun_dir * 1000.0
		if not cam.is_position_behind(world_p):
			var sp := cam.unproject_position(world_p)
			var vs := cam.get_viewport().get_visible_rect().size
			var uv := sp / vs
			var inside := 1.0 - clampf((maxf(absf(uv.x - 0.5), absf(uv.y - 0.5)) - 0.45) / 0.2, 0.0, 1.0)
			amount = pow(facing, 3.0) * inside * (1.0 if sun_dir.y < 0.35 else 0.5)
			_mat.set_shader_parameter("sun_pos", uv)
			_mat.set_shader_parameter("flare_color", sun.light_color)
	_mat.set_shader_parameter("flare_amount", amount)


func update_fx(speed: float, helmet: bool, delta: float) -> void:
	if _mat == null:
		return
	var use_blur := bool(Settings.get_value("motion_blur", true))
	var use_haze := bool(Settings.get_value("heat_haze", true))
	var target := clampf((speed - 28.0) / 50.0, 0.0, 1.0) * (1.25 if helmet else 1.0) if use_blur else 0.0
	_blur = lerpf(_blur, target, clampf(delta * 3.0, 0.0, 1.0))
	_mat.set_shader_parameter("blur_amount", _blur)
	_mat.set_shader_parameter("aberration", _blur * 0.8)
	_mat.set_shader_parameter("haze_amount", _haze_base if use_haze else 0.0)
	_mat.set_shader_parameter("vignette", 0.32 + _blur * 0.25)

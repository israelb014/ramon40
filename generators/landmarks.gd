class_name Landmarks
extends RefCounted
## Unique track objects built as nodes: Israeli green direction signs with Hebrew text,
## the start/finish gantry and tunnel portals.

const SIGN_GREEN := Color(0.0, 0.40, 0.23)
const SIGN_WHITE := Color(0.96, 0.96, 0.94)

static var _hebrew_font: Font


static func sign_font() -> Font:
	if _hebrew_font == null:
		var f := FontFile.new()
		f.load_dynamic_font("res://assets/fonts/Assistant.ttf")
		var fv := FontVariation.new()
		fv.base_font = f
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
		_hebrew_font = fv
	return _hebrew_font


static func _label(text: String, size: int, pos: Vector3, color: Color, width := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = sign_font()
	l.font_size = size
	l.pixel_size = 0.0045
	l.position = pos
	l.modulate = color
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if width > 0.0:
		l.width = width
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


## Green direction sign on two posts; the board faces local +Z (toward traffic).
static func direction_sign(lines: Array, route: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Sign"
	var mb := MeshBuilder.new(true)
	var w := 4.6
	var h := 2.3
	var base_y := 2.4
	var grey := Color(0.55, 0.56, 0.58)
	for sx in [-1.0, 1.0]:
		mb.add_cylinder(Transform3D(Basis(), Vector3(sx * w * 0.32, -0.3, -0.08)), 0.07, 0.07, base_y + h - 0.1 + 0.3, 8, grey)
	# White border then green face slightly in front.
	mb.add_bevel_box(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, base_y + h * 0.5, 0)), Vector3(w, 0.06, h), 0.18, SIGN_WHITE)
	mb.add_bevel_box(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, base_y + h * 0.5, 0.012)), Vector3(w - 0.14, 0.06, h - 0.14), 0.14, SIGN_GREEN)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit({"default": PropMeshes.vertex_material(0.6)})
	root.add_child(mi)
	var z := 0.05
	root.add_child(_label(String(lines[0]), 150, Vector3(0.35, base_y + h * 0.66, z), SIGN_WHITE))
	if lines.size() > 1:
		root.add_child(_label(String(lines[1]), 88, Vector3(0.35, base_y + h * 0.3, z), SIGN_WHITE))
	# Route number shield on the left side of the board.
	if route != "":
		var shield := MeshBuilder.new(true)
		shield.add_bevel_box(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-w * 0.36, base_y + h * 0.5, 0.03)), Vector3(0.82, 0.03, 0.62), 0.1, SIGN_WHITE)
		var smi := MeshInstance3D.new()
		smi.mesh = shield.commit({"default": PropMeshes.vertex_material(0.6)})
		root.add_child(smi)
		root.add_child(_label(route, 110, Vector3(-w * 0.36, base_y + h * 0.5, 0.05), Color(0.08, 0.08, 0.08)))
	return root


## Start/finish gantry spanning the road; origin on the road center, facing -Z travel.
static func gantry(half_span: float, banner: String, night: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Gantry"
	var mb := MeshBuilder.new(true)
	var dark := Color(0.12, 0.12, 0.14)
	var red := Color(0.75, 0.10, 0.08)
	var height := 6.8
	for sx in [-1.0, 1.0]:
		var x: float = sx * half_span
		# Truss pillar: four legs plus cross braces.
		for lx in [-0.35, 0.35]:
			for lz in [-0.35, 0.35]:
				mb.add_cylinder(Transform3D(Basis(), Vector3(x + lx, 0, lz)), 0.07, 0.07, height + 1.2, 6, dark)
		for k in 6:
			var y0 := k * (height / 6.0)
			var y1 := y0 + height / 6.0
			mb.add_tube(Vector3(x - 0.35, y0, -0.35), Vector3(x + 0.35, y1, -0.35), 0.035, 0.035, 4, dark)
			mb.add_tube(Vector3(x - 0.35, y0, 0.35), Vector3(x + 0.35, y1, 0.35), 0.035, 0.035, 4, dark)
		mb.add_box(Transform3D(Basis(), Vector3(x, 0.15, 0)), Vector3(1.2, 0.3, 1.2), Color(0.6, 0.6, 0.6))
	# Beam with a banner board on each face.
	mb.add_box(Transform3D(Basis(), Vector3(0, height + 0.6, 0)), Vector3(half_span * 2.0 + 1.0, 1.6, 0.5), red)
	# Checkered strip under the banner.
	var cells := int(half_span * 2.0 / 0.5)
	for c in cells:
		for row in 2:
			var col := Color(0.95, 0.95, 0.95) if (c + row) % 2 == 0 else Color(0.05, 0.05, 0.05)
			var x := -half_span + (c + 0.5) * 0.5
			mb.add_box(Transform3D(Basis(), Vector3(x, height - 0.45 + row * 0.25, 0)), Vector3(0.5, 0.25, 0.52), col)
	mb.surface("lamp")
	for k in 5:
		var x := lerpf(-half_span + 1.0, half_span - 1.0, k / 4.0)
		mb.add_box(Transform3D(Basis(), Vector3(x, height - 0.72, 0)), Vector3(0.5, 0.08, 0.3), Color(1, 1, 1))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit({"default": PropMeshes.vertex_material(0.5), "lamp": PropMeshes.lamp_material(Color(1.0, 0.95, 0.85), 3.0)})
	root.add_child(mi)
	for face in [1.0, -1.0]:
		var title := _label("רמון 40", 230, Vector3(-half_span * 0.45, height + 0.62, 0.27 * face), Color(1, 1, 1))
		var sub := _label(banner, 120, Vector3(half_span * 0.3, height + 0.62, 0.27 * face), Color(1.0, 0.86, 0.5))
		if face < 0.0:
			title.rotation.y = PI
			sub.rotation.y = PI
			title.position.x = half_span * 0.45
			sub.position.x = -half_span * 0.3
		root.add_child(title)
		root.add_child(sub)
	if night:
		var light := SpotLight3D.new()
		light.position = Vector3(0, height - 0.8, 0)
		light.rotation_degrees = Vector3(-90, 0, 0)
		light.spot_range = 16.0
		light.spot_angle = 55.0
		light.light_energy = 6.0
		light.light_color = Color(1.0, 0.93, 0.8)
		root.add_child(light)
	return root


## Concrete tunnel portal facade around the opening; faces local +Z (outward).
static func tunnel_portal(half_width: float) -> Node3D:
	var root := Node3D.new()
	var mb := MeshBuilder.new(true)
	var concrete := Color(0.66, 0.64, 0.6)
	var hw := half_width + 0.6
	var poly := PackedVector2Array()
	# Outer rectangle minus arch opening, built as blocks around the arch.
	mb.add_box(Transform3D(Basis(), Vector3(-hw - 2.0, 4.5, 0)), Vector3(4.0, 11.0, 1.2), concrete)
	mb.add_box(Transform3D(Basis(), Vector3(hw + 2.0, 4.5, 0)), Vector3(4.0, 11.0, 1.2), concrete)
	mb.add_box(Transform3D(Basis(), Vector3(0, 8.8, 0)), Vector3(hw * 2.0 + 8.0, 2.4, 1.2), concrete)
	# Arch fill between wall top and lintel.
	for k in 10:
		var a0 := PI * float(k) / 10.0
		var a1 := PI * float(k + 1) / 10.0
		var p0 := Vector3(cos(a0) * hw, 4.2 + sin(a0) * 2.6, 0)
		var p1 := Vector3(cos(a1) * hw, 4.2 + sin(a1) * 2.6, 0)
		var top0 := Vector3(p0.x, 7.6, 0)
		var top1 := Vector3(p1.x, 7.6, 0)
		for zf in [0.6, -0.6]:
			var off := Vector3(0, 0, zf)
			mb.add_triangle_facing(p0 + off, top0 + off, top1 + off, concrete, Vector3(0, 0, zf))
			mb.add_triangle_facing(p0 + off, top1 + off, p1 + off, concrete, Vector3(0, 0, zf))
	# Yellow-black hazard band on the lintel.
	for k in 12:
		var x := lerpf(-hw, hw, (k + 0.5) / 12.0)
		mb.add_box(Transform3D(Basis(), Vector3(x, 7.75, 0.62)), Vector3(hw * 2.0 / 12.0, 0.25, 0.02), Color(0.95, 0.75, 0.05) if k % 2 == 0 else Color(0.05, 0.05, 0.05))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit({"default": PropMeshes.vertex_material(0.85)})
	root.add_child(mi)
	return root

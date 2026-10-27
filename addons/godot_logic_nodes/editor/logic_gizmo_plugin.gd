@tool
extends EditorNode3DGizmoPlugin
## Draws one Logic Node type's icons in the 3D view (clickable), plus a wire to each output target.
## godot_logic_nodes.gd makes one of these per type, so each type gets its own toggle in the
## 3D view's View > Gizmos menu.

const FALLBACK_ICON := "res://addons/godot_logic_nodes/icons/BaseNode.png"
## Width of an icon in world units. Icons are real 3D quads, so they shrink with distance.
const ICON_SIZE := 0.5
## Thickness of a wire in world units. Godot draws gizmo lines 1 px wide, so wires are thin tubes instead.
const WIRE_WIDTH := 0.03
## Pulses travel along each wire from the sending node to its target, so the direction of a
## connection shows at a glance. UV.x is the distance along the wire, in world units.
const WIRE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 color : source_color;
uniform float speed = 1.5;    // world units per second
uniform float spacing = 0.75; // world units between pulses
uniform float opacity = 0.55; // between pulses; pulses are more solid

void fragment() {
	float t = fract((UV.x - TIME * speed) / spacing);
	float pulse = smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(0.2, 0.45, t));
	ALBEDO = mix(color.rgb * 0.6, mix(color.rgb, vec3(1.0), 0.4), pulse);
	ALPHA = mix(opacity, 0.9, pulse);
}
"""
## Each family's color: its viewport badges are this color, and so are the wires its nodes send.
## Okabe-Ito hues, so the four families stay distinct for color-blind designers.
const TRIGGERS := Color("f2a93b")
const MOVERS := Color("56b4e9")
const LOGIC := Color("cc79a7")
const FEEDBACK := Color("f0e442")
const FAMILY_COLORS := {
	&"LogicTrigger": TRIGGERS, &"LogicInteract": TRIGGERS,
	&"LogicMove": MOVERS, &"LogicRotate": MOVERS,
	&"LogicAuto": LOGIC, &"LogicRelay": LOGIC, &"LogicCounter": LOGIC, &"LogicTimer": LOGIC, &"LogicBranch": LOGIC,
	&"LogicAudioClip": FEEDBACK, &"LogicDebug": FEEDBACK,
}

var logic_type: StringName  # the class this plugin draws, e.g. &"LogicMove"
var _icon_by_script := {}  # Script -> icon path, so the class list is only scanned once per script
var _made := {}            # icon paths that already have a material
var _tints := {}           # trigger Volume Colors (as html) that already have materials
var _wire_material: ShaderMaterial  # ShaderMaterial, so it can't go through add_material()
var _quad := QuadMesh.new()
var _click_shape: TriangleMesh  # a box around the icon, so it can be clicked from any angle


func _init(type: StringName = &"LogicNode") -> void:
	logic_type = type
	_wire_material = _make_wire_material(FAMILY_COLORS.get(type, Color(1.0, 0.6, 0.1)))
	create_material("path", Color(0.3, 0.9, 1.0))
	_quad.size = Vector2.ONE * ICON_SIZE
	var box := BoxMesh.new()
	box.size = Vector3.ONE * ICON_SIZE
	_click_shape = box.generate_triangle_mesh()


func _get_gizmo_name() -> String:
	return String(logic_type).capitalize()  # "LogicAudioClip" -> "Logic Audio Clip"


## True for nodes of exactly this type: a node's type is the nearest named class in its script.
func _has_gizmo(node: Node3D) -> bool:
	if not node is LogicNode:
		return false
	var script: Script = node.get_script()
	while script and script.get_global_name() == &"":
		script = script.get_base_script()
	return script != null and script.get_global_name() == logic_type


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node := gizmo.get_node_3d()
	gizmo.add_mesh(_quad, _icon_material(node, gizmo))
	gizmo.add_collision_triangles(_click_shape)
	if node is LogicTrigger or node is LogicInteract:
		var fill := BoxMesh.new()
		fill.size = node.size
		var key := _volume_materials(node.volume_color)
		gizmo.add_mesh(fill, get_material("volume_fill_" + key, gizmo))
		var edges := _box_lines(node.size)
		gizmo.add_lines(edges, get_material("volume_" + key, gizmo))
		# Clicking any edge of the box selects the trigger, like Godot's own shape gizmos.
		# Edges rather than faces, so objects inside the box (like the doors) stay clickable.
		gizmo.add_collision_segments(edges)

	# A Move's path: a line from its target to where the target will end up, with a cross at the end.
	if node is LogicMove and not node.move_offset.is_zero_approx():
		var mover: Node3D = node.target if node.target else node
		var start := node.to_local(mover.global_position)
		var end := node.to_local(mover.global_position + node.world_offset())
		var path := PackedVector3Array([start, end])
		for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
			path.append(end - axis * 0.1)
			path.append(end + axis * 0.1)
		gizmo.add_lines(path, get_material("path", gizmo))

	# Wires: a line from this node to each output target.
	# Endpoints are baked in local space, so godot_logic_nodes.gd redraws this when a target moves.
	var lines := PackedVector3Array()
	for row in node.all_outputs():
		var target := node.get_node_or_null(row.target) as Node3D if row else null
		if target:
			lines.append(Vector3.ZERO)
			lines.append(node.to_local(target.global_position))
	if not lines.is_empty():
		gizmo.add_mesh(_wire_mesh(lines), _wire_material)


## The 12 edges of a box of `size`, centered on the node.
func _box_lines(size: Vector3) -> PackedVector3Array:
	var h := size / 2.0
	var lines := PackedVector3Array()
	for i in 8:
		var a := Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z)
		for bit in [1, 2, 4]:
			if not i & bit:  # draw each edge once, from the corner on its minus side
				var b := a
				b[[1, 2, 4].find(bit)] *= -1.0
				lines.append(a)
				lines.append(b)
	return lines


## A square tube WIRE_WIDTH thick along each pair of points in `lines`, so wires read from any angle.
func _wire_mesh(lines: PackedVector3Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var r := WIRE_WIDTH / 2.0
	for i in range(0, lines.size(), 2):
		var a := lines[i]
		var b := lines[i + 1]
		var dir := (b - a).normalized()
		if dir.is_zero_approx():
			continue
		var side := dir.cross(Vector3.UP)
		if side.is_zero_approx():  # a vertical wire
			side = dir.cross(Vector3.RIGHT)
		side = side.normalized() * r
		var up := dir.cross(side).normalized() * r
		var ring := [side + up, side - up, -side - up, -side + up]
		var length := a.distance_to(b)
		for k in 4:
			var p: Vector3 = ring[k]
			var q: Vector3 = ring[(k + 1) % 4]
			verts.append_array(PackedVector3Array([a + p, b + p, b + q, a + p, b + q, a + q]))
			uvs.append_array(PackedVector2Array([Vector2.ZERO, Vector2(length, 0), Vector2(length, 1),
					Vector2.ZERO, Vector2(length, 1), Vector2(0, 1)]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	if not verts.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Unlit family color for wires with pulses moving toward the target, visible from both sides.
func _make_wire_material(color: Color) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = WIRE_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("color", color)
	return material


## Makes the icon material the first time an icon is needed, so get_material() never asks for a missing one.
## Uses the class's viewport badge (LogicNode_Move_Viewport.svg next to LogicNode_Move.svg) when
## there is one, since the Scene tree icon is a small glyph made for 16 px.
func _icon_material(node: Node3D, gizmo: EditorNode3DGizmo) -> StandardMaterial3D:
	var path := _icon_path(node.get_script())
	var badge := path.get_basename() + "_Viewport.svg"
	if ResourceLoader.exists(badge):
		path = badge
	if not _made.has(path):
		var texture := load(path) as Texture2D
		if texture == null:
			push_warning("Logic Nodes: can't load icon '%s', using the default icon." % path)
			path = FALLBACK_ICON
			texture = load(path)
		if not _made.has(path):
			add_material(path, _make_icon_material(texture))
			_made[path] = true
	return get_material(path, gizmo)


## A camera-facing, unshaded quad sized in world units, unlike create_icon_material().
## Drawn on top of level geometry, so an icon inside a wall or under the floor stays visible.
func _make_icon_material(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# Alpha blending (not scissor) puts icons in the transparent pass, after level geometry,
	# which is what lets no_depth_test draw them on top.
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.render_priority = Material.RENDER_PRIORITY_MAX
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.albedo_texture = texture
	return material


## Makes the edge and fill materials for a trigger's Volume Color the first time it's used,
## so triggers sharing a color share materials. Returns the name suffix for get_material().
func _volume_materials(tint: Color) -> String:
	var key := tint.to_html()
	if not _tints.has(key):
		create_material("volume_" + key, Color(tint, 1.0))  # solid edges
		add_material("volume_fill_" + key, _make_fill_material(tint))
		_tints[key] = true
	return key


## See-through tint for a trigger's box, visible from inside it too.
func _make_fill_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	material.albedo_color = color
	return material


## The icon of the node's class, or of the nearest parent class that has one.
func _icon_path(script: Script) -> String:
	if _icon_by_script.has(script):
		return _icon_by_script[script]
	var icons := {}
	for cls in ProjectSettings.get_global_class_list():
		icons[cls["class"]] = cls["icon"]
	var path := FALLBACK_ICON
	var s := script
	while s:
		var icon: String = icons.get(s.get_global_name(), "")
		if icon != "":
			path = icon
			break
		s = s.get_base_script()
	_icon_by_script[script] = path
	return path

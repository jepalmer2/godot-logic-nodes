@tool
extends EditorNode3DGizmoPlugin
## Draws every Logic Node's icon in the 3D view (clickable), plus a wire to each output target.

const FALLBACK_ICON := "res://addons/godot_logic_nodes/icons/BaseNode.png"
## Width of an icon in world units. Icons are real 3D quads, so they shrink with distance.
const ICON_SIZE := 0.5

var _icon_by_script := {}  # Script -> icon path, so the class list is only scanned once per script
var _made := {}            # icon paths that already have a material
var _quad := QuadMesh.new()
var _click_shape: TriangleMesh  # a box around the icon, so it can be clicked from any angle


func _init() -> void:
	create_material("wire", Color(1.0, 0.6, 0.1))
	_quad.size = Vector2.ONE * ICON_SIZE
	var box := BoxMesh.new()
	box.size = Vector3.ONE * ICON_SIZE
	_click_shape = box.generate_triangle_mesh()


func _get_gizmo_name() -> String:
	return "Logic Nodes"


func _has_gizmo(node: Node3D) -> bool:
	return node is LogicNode #or node is LogicVolume


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node := gizmo.get_node_3d()
	gizmo.add_mesh(_quad, _icon_material(node, gizmo))
	gizmo.add_collision_triangles(_click_shape)

	# Prodeus-style wires: a line from this node to each output target.
	# Endpoints are baked in local space, so godot_logic_nodes.gd redraws this when a target moves.
	var lines := PackedVector3Array()
	for row in node.outputs:
		var target := node.get_node_or_null(row.target) as Node3D if row else null
		if target:
			lines.append(Vector3.ZERO)
			lines.append(node.to_local(target.global_position))
	if not lines.is_empty():
		gizmo.add_lines(lines, get_material("wire", gizmo))


## Makes the icon material the first time an icon is needed, so get_material() never asks for a missing one.
func _icon_material(node: Node3D, gizmo: EditorNode3DGizmo) -> StandardMaterial3D:
	var path := _icon_path(node.get_script())
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


## A camera-facing, unshaded quad that is depth-tested and sized in world units, unlike create_icon_material().
func _make_icon_material(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.albedo_texture = texture
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

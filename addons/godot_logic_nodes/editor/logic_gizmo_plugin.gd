@tool
extends EditorNode3DGizmoPlugin
## Draws every Logic Node's icon in the 3D view (clickable), plus a wire to each output target.

const FALLBACK_ICON := "res://addons/godot_logic_nodes/icons/BaseNode.png"
## Width of an icon in world units. Icons are real 3D quads, so they shrink with distance.
const ICON_SIZE := 0.5

var _icon_by_script := {}  # Script -> icon path, so the class list is only scanned once per script
var _made := {}            # icon paths that already have a material
var _tints := {}           # trigger Volume Colors (as html) that already have materials
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
	if node is LogicTrigger:
		var fill := BoxMesh.new()
		fill.size = node.size
		var key := _volume_materials(node.volume_color)
		gizmo.add_mesh(fill, get_material("volume_fill_" + key, gizmo))
		gizmo.add_lines(_box_lines(node.size), get_material("volume_" + key, gizmo))

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

@tool
extends EditorPlugin

const LogicGizmoPlugin := preload("res://addons/godot_logic_nodes/editor/logic_gizmo_plugin.gd")
const LogicIOPanel := preload("res://addons/godot_logic_nodes/editor/logic_io_panel.tscn")

var _gizmo_plugin := LogicGizmoPlugin.new()
var _panel: Control
var _wire_ends := {}  # LogicNode -> positions its wires were last drawn between


func _enter_tree() -> void:
	add_node_3d_gizmo_plugin(_gizmo_plugin)

	_panel = LogicIOPanel.instantiate()
	_panel.undo_redo = get_undo_redo()
	add_control_to_bottom_panel(_panel, "Logic I/O")
	EditorInterface.get_selection().selection_changed.connect(_on_selection_changed)

	var dock := _scene_tree_dock()
	if dock:
		dock.connect(&"node_created", _on_node_created)


func _exit_tree() -> void:
	# Null-safe on purpose: a script error here aborts the function and leaves the
	# gizmo plugin registered, so it keeps redrawing until the editor restarts.
	if _gizmo_plugin:
		remove_node_3d_gizmo_plugin(_gizmo_plugin)
	var selection := EditorInterface.get_selection()
	if selection.selection_changed.is_connected(_on_selection_changed):
		selection.selection_changed.disconnect(_on_selection_changed)
	var dock := _scene_tree_dock()
	if dock and dock.is_connected(&"node_created", _on_node_created):
		dock.disconnect(&"node_created", _on_node_created)
	if is_instance_valid(_panel):
		remove_control_from_bottom_panel(_panel)
		_panel.queue_free()


## Godot only redraws a gizmo when its own node changes, so a wire would stay put when the
## node it points at moves. Each frame, redraw any Logic Node whose wire endpoints moved.
func _process(_delta: float) -> void:
	var scene := EditorInterface.get_edited_scene_root()
	if scene == null:
		_wire_ends.clear()
		return
	var seen := {}
	for node in get_tree().get_nodes_in_group(&"logic_nodes"):
		if node != scene and not scene.is_ancestor_of(node):
			continue
		var ends := _wire_ends_of(node)
		if _wire_ends.get(node) != ends:
			node.update_gizmos()
		seen[node] = ends
	_wire_ends = seen  # also forgets deleted nodes


func _wire_ends_of(node: LogicNode) -> PackedVector3Array:
	var ends := PackedVector3Array([node.global_position])
	for row in node.all_outputs():
		var target := node.get_node_or_null(row.target) as Node3D if row else null
		if target:
			ends.append(target.global_position)
	return ends


## Godot adds new nodes at the origin, which is often far from where the designer is looking.
## A new Logic Node goes in front of the 3D editor camera instead: on the first surface the
## camera is pointing at (lifted a little off it), or a few meters ahead if there's nothing there.
func _on_node_created(node: Node) -> void:
	var logic_node := node as LogicNode
	if logic_node == null or not logic_node.is_inside_tree():
		return
	var camera := EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
	if camera == null:
		return
	const DISTANCE := 4.0
	var from := camera.global_position
	var forward := -camera.global_basis.z
	var spot := from + forward * DISTANCE
	var query := PhysicsRayQueryParameters3D.create(from, spot)
	var hit := logic_node.get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		spot = hit.position + hit.normal * 0.5
	logic_node.global_position = spot.round()  # whole numbers, e.g. (1, 1, 2.34) -> (1, 1, 2)


## The Scene dock, whose "node_created" signal fires when a node is made with Add Child Node.
func _scene_tree_dock() -> Node:
	var docks := EditorInterface.get_base_control().find_children("*", "SceneTreeDock", true, false)
	return docks[0] if docks else null


func _on_selection_changed() -> void:
	var selected := EditorInterface.get_selection().get_selected_nodes()
	var node: Node = selected[0] if selected.size() == 1 else null
	if node is LogicNode:  # add "or node is LogicVolume" once LogicVolume exists
		_panel.edit(node)
		make_bottom_panel_item_visible(_panel)
	else:
		_panel.edit(null)

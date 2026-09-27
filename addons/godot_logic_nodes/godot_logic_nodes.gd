@tool
extends EditorPlugin

const LogicGizmoPlugin := preload("res://addons/godot_logic_nodes/editor/logic_gizmo_plugin.gd")
const LogicIOPanel := preload("res://addons/godot_logic_nodes/editor/logic_io_panel.tscn")

var _gizmo_plugin := LogicGizmoPlugin.new()
var _panel: Control


func _enter_tree() -> void:
	add_node_3d_gizmo_plugin(_gizmo_plugin)

	_panel = LogicIOPanel.instantiate()
	_panel.undo_redo = get_undo_redo()
	add_control_to_bottom_panel(_panel, "Logic I/O")
	EditorInterface.get_selection().selection_changed.connect(_on_selection_changed)


func _exit_tree() -> void:
	EditorInterface.get_selection().selection_changed.disconnect(_on_selection_changed)
	remove_control_from_bottom_panel(_panel)
	_panel.queue_free()
	remove_node_3d_gizmo_plugin(_gizmo_plugin)


func _on_selection_changed() -> void:
	var selected := EditorInterface.get_selection().get_selected_nodes()
	var node: Node = selected[0] if selected.size() == 1 else null
	if node is LogicNode:  # add "or node is LogicVolume" once LogicVolume exists
		_panel.edit(node)
		make_bottom_panel_item_visible(_panel)
	else:
		_panel.edit(null)

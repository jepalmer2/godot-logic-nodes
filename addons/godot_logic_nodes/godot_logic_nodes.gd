@tool
extends EditorPlugin

const LogicGizmoPlugin := preload("res://addons/godot_logic_nodes/editor/logic_gizmo_plugin.gd")

var _gizmo_plugin := LogicGizmoPlugin.new()


func _enter_tree() -> void:
	add_node_3d_gizmo_plugin(_gizmo_plugin)


func _exit_tree() -> void:
	remove_node_3d_gizmo_plugin(_gizmo_plugin)

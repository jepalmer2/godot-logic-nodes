@tool
@icon("res://addons/godot_logic_nodes/icons/LogicNode_Auto.png")
class_name LogicAuto
extends LogicNode
## Fires [signal on_scene_start] once when the scene starts, after every other node is ready.

## Output: the scene has started. Activator is always null.
signal on_scene_start(activator: Node)

## Extra seconds to wait after the scene is ready before firing.
@export_range(0.0, 60.0, 0.05, "or_greater", "suffix:s") var delay := 0.0


func _logic_ready() -> void:
	await get_tree().physics_frame  # every _ready() has run, physics has had a tick
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	_fire(on_scene_start)

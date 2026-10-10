@tool
@icon("res://addons/godot_logic_nodes/icons/LogicNode_Interact_Placeholder.svg")
class_name LogicInteract
extends LogicTrigger
## A box-shaped area where the player presses a key to use something: a lever, a button,
## a door handle. Fires [signal on_interact] when the key is pressed while someone matching
## [member only_group] is inside. It also fires On Trigger Enter and On Trigger Exit, which
## are handy for showing and hiding a "Press E" prompt.

## Output: the interact key was pressed inside the box. Activator is whoever pressed it.
signal on_interact(activator: Node)

## The Input Map action that counts as interacting. Add it in Project Settings > Input Map.
@export var action: StringName = &"interact":
	set(value):
		action = value
		update_configuration_warnings()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _inside.is_empty() or not InputMap.has_action(action):
		return
	if event.is_action_pressed(action, false):  # false = ignore key repeat while held
		_fire(on_interact, _inside[0])


func _logic_warnings() -> PackedStringArray:
	var warnings := super()
	if action == &"":
		warnings.append("Action is empty, so nothing can ever interact with this zone.")
	elif not ProjectSettings.has_setting("input/" + action):
		warnings.append("The Input Map has no '%s' action. Add it in Project Settings > Input Map." % action)
	return warnings

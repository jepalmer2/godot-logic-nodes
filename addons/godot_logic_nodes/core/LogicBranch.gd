@tool
@icon("res://addons/godot_logic_nodes/icons/LogicNode_Branch_Placeholder.svg")
class_name LogicBranch
extends LogicNode
## Remembers one yes/no fact about the level ("power is on") and, on Check, sends the event
## to On True or On False. Setting the value and checking it are separate inputs.
## The value resets to Start Value on every scene load and is never saved to disk.

## Output: Check was sent and the value is true.
signal on_true(activator: Node)
## Output: Check was sent and the value is false.
signal on_false(activator: Node)
## Output: the value changed (by Set True, Set False or Toggle).
signal on_value_change(activator: Node)

## The value when the scene loads.
@export var start_value := false
## Every change also runs Check, so On True / On False fire right away.
@export var check_on_change := false

## The current value. Change it with Set True, Set False and Toggle.
var value := false


func _logic_ready() -> void:
	value = start_value


## Input: the value becomes true.
func set_true(activator: Variant = null) -> void:
	if _receive(&"set_true", activator):
		_set_value(true, activator)


## Input: the value becomes false.
func set_false(activator: Variant = null) -> void:
	if _receive(&"set_false", activator):
		_set_value(false, activator)


## Input: flip the value.
func toggle(activator: Variant = null) -> void:
	if _receive(&"toggle", activator):
		_set_value(not value, activator)


## Input: fire On True or On False for the value right now. Doesn't change the value.
func check(activator: Variant = null) -> void:
	if _receive(&"check", activator):
		_check(activator)


func _set_value(new_value: bool, activator: Variant) -> void:
	if new_value == value:
		return  # no change, nothing fires
	value = new_value
	_fire(on_value_change, activator)
	if check_on_change:
		_check(activator)


func _check(activator: Variant) -> void:
	_fire(on_true if value else on_false, activator)

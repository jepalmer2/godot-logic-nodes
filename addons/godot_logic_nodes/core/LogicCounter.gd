@tool
@icon("res://addons/godot_logic_nodes/icons/LogicNode_Counter.svg")
class_name LogicCounter
extends LogicNode
## Counts how many times something happened and fires once [member goal] is reached.
## For example, wire three switches to Add and On Goal Reached to a gate's Move.

enum AfterGoal {
	STOP,           ## Ignores Add and Subtract until Reset, so it fires once per Reset.
	RESET,          ## Goes straight back to Start Count, so it fires again every Goal adds.
	KEEP_COUNTING,  ## Counts past Goal. Fires again only if the count drops below Goal and comes back up.
}

## Output: the count went up, down or was reset.
signal on_count_change(activator: Node)
## Output: the count reached [member goal]. Activator = whoever sent the Add that reached it.
signal on_goal_reached(activator: Node)

## Count needed to fire On Goal Reached.
@export_range(1, 1000, 1, "or_greater") var goal := 3:
	set(value):
		goal = maxi(value, 1)
		update_configuration_warnings()
## Count when the scene loads, and what Reset goes back to.
@export_range(0, 1000, 1, "or_greater") var start_count := 0:
	set(value):
		start_count = maxi(value, 0)
		update_configuration_warnings()
## What happens once the goal is reached.
@export var after_goal := AfterGoal.STOP

## The current count. Read-only for designers; change it with Add, Subtract and Reset.
var count := 0
var _reached := false  # On Goal Reached has fired and hasn't been re-armed yet


func _logic_ready() -> void:
	count = start_count


## Input: count up by one.
func add(activator: Variant = null) -> void:
	if not _receive(&"add", activator) or _stopped():
		return
	count += 1
	_fire(on_count_change, activator)
	if _reached or count < goal:
		return
	_reached = true
	_fire(on_goal_reached, activator)
	if after_goal == AfterGoal.RESET:
		count = start_count
		_reached = false


## Input: count down by one. Never goes below 0, and does nothing at 0.
func subtract(activator: Variant = null) -> void:
	if not _receive(&"subtract", activator) or _stopped() or count == 0:
		return
	count -= 1
	if count < goal:
		_reached = false  # Keep Counting: coming back up to Goal fires again
	_fire(on_count_change, activator)


## Input: go back to Start Count and start counting again.
func reset(activator: Variant = null) -> void:
	if not _receive(&"reset", activator):
		return
	count = start_count
	_reached = false
	_fire(on_count_change, activator)


func _stopped() -> bool:
	return _reached and after_goal == AfterGoal.STOP


func _logic_warnings() -> PackedStringArray:
	var warnings := super()
	if start_count >= goal:
		warnings.append("Start Count is already at the Goal, so On Goal Reached only fires on the next Add.")
	return warnings

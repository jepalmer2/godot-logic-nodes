@tool
@icon("res://addons/godot_logic_nodes/icons/LogicNode_Move.png")
class_name LogicMove
extends LogicNode
## Slides a node back and forth between its start position and [member move_offset]
## (Hammer's func_movelinear). Put the geometry to move under this node, or pick another [member target].

## Output: started moving toward the open position.
signal opening(activator: Node)
## Output: started moving toward the closed (start) position.
signal closing(activator: Node)
## Output: reached the open position.
signal fully_opened(activator: Node)
## Output: reached the closed (start) position.
signal fully_closed(activator: Node)

## The node to move. Empty moves this node, and everything under it.
@export var target: Node3D:
	set(value):
		target = value
		update_configuration_warnings()
## How far the open position is from the start position, in the target's parent space.
@export var move_offset := Vector3(0.0, 2.0, 0.0):
	set(value):
		move_offset = value
		update_configuration_warnings()
## Units per second.
@export_range(0.01, 100.0, 0.01, "or_greater", "suffix:m/s") var speed := 2.0
## Where to start: 0 is closed, 1 is open.
@export_range(0.0, 1.0, 0.01) var start_position := 0.0
## Easing of the motion (1 is linear). Applied the same way in both directions.
@export_exp_easing var easing := 1.0

var _mover: Node3D
var _closed_position: Vector3
var _progress := 0.0  # 0 = closed, 1 = open
var _goal := 0.0
var _moving := false
var _activator: Node


func _logic_ready() -> void:
	_mover = target if target else self
	_closed_position = _mover.position
	_progress = start_position
	_goal = start_position
	_apply()


## Input: move to the open position.
func open(activator: Variant = null) -> void:
	if _receive(&"open", activator):
		_move_to(1.0, activator)


## Input: move back to the closed (start) position.
func close(activator: Variant = null) -> void:
	if _receive(&"close", activator):
		_move_to(0.0, activator)


## Input: open if closed or closing, close if open or opening.
func toggle(activator: Variant = null) -> void:
	if _receive(&"toggle", activator):
		_move_to(0.0 if _goal > 0.5 else 1.0, activator)


## Input: stop where it is. The next Open, Close or Toggle carries on from there.
func stop(activator: Variant = null) -> void:
	if _receive(&"stop", activator):
		_moving = false


func _move_to(goal: float, activator: Variant) -> void:
	_activator = LogicCore.as_activator(activator)
	if is_equal_approx(_progress, goal):
		return
	_goal = goal
	_moving = true
	set_physics_process(true)
	_fire(opening if goal > _progress else closing, _activator)


func _physics_process(delta: float) -> void:
	if not _moving:
		set_physics_process(false)  # also switches it off in the editor
		return
	var distance := move_offset.length()
	var step := 1.0 if distance == 0.0 else speed * delta / distance
	_progress = move_toward(_progress, _goal, step)
	_apply()
	if is_equal_approx(_progress, _goal):
		_moving = false
		_fire(fully_opened if _goal > 0.5 else fully_closed, LogicCore.as_activator(_activator))


func _apply() -> void:
	_mover.position = _closed_position + move_offset * ease(_progress, easing)


func _logic_warnings() -> PackedStringArray:
	var warnings := super()
	if move_offset.is_zero_approx():
		warnings.append("Move Offset is zero, so this node has nowhere to go.")
	if target == null and get_child_count() == 0:
		warnings.append("Nothing to move: add geometry under this node or pick a Target.")
	return warnings

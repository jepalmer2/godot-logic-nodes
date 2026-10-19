@tool
@icon("res://addons/godot_logic_nodes/icons/LogicNode_Move.png")
class_name LogicMove
extends LogicNode
## Moves a node in a straight line, between where it was placed (the start) and
## [member move_offset] away from there (the end). Put the node to move under this
## one, or pick another [member target].
## For moving platforms and elevators the player can ride, make the moving body an
## AnimatableBody3D (not a StaticBody3D).

enum Mode {
	ONCE,       ## Each Start travels to the other end and stops there.
	PING_PONG,  ## Travels back and forth until Stop.
	LOOP,       ## Travels to the end, jumps back to the start, and repeats until Stop.
}

## Output: began moving.
signal on_move_start(activator: Node)
## Output: arrived at either end.
signal on_move_end(activator: Node)

## The node to move. Empty moves this node, and everything under it.
@export var target: Node3D:
	set(value):
		target = value
		update_configuration_warnings()
## Where the end is, relative to the start, in the target's parent space.
@export var move_offset := Vector3(0.0, 2.0, 0.0):
	set(value):
		move_offset = value
		update_configuration_warnings()
## Units per second.
@export_range(0.01, 100.0, 0.01, "or_greater", "suffix:m/s") var speed := 2.0
## What happens when it reaches an end.
@export var mode := Mode.ONCE

var _mover: Node3D
var _origin: Vector3
var _progress := 0.0     # 0 = start, 1 = end
var _direction := 1.0    # +1 toward the end, -1 toward the start
var _moving := false
var _activator: Node


func _logic_ready() -> void:
	_mover = target if target else self
	_origin = _mover.position
	LogicCore.prepare_platforms(_mover)
	_apply()


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		get_tree().node_added.connect(_on_tree_changed)
		get_tree().node_removed.connect(_on_tree_changed)


func _exit_tree() -> void:
	if Engine.is_editor_hint() and get_tree().node_added.is_connected(_on_tree_changed):
		get_tree().node_added.disconnect(_on_tree_changed)
		get_tree().node_removed.disconnect(_on_tree_changed)


func _on_tree_changed(node: Node) -> void:
	LogicCore.watch_mover(self, target if target else self, node)


## Input: start moving, or carry on after Stop. Resting at an end, it heads for the other end
## (in Loop mode, it jumps back to the start first).
func start(activator: Variant = null) -> void:
	if not _receive(&"start", activator) or _moving:
		return
	_activator = LogicCore.as_activator(activator)
	if mode == Mode.LOOP and _progress >= 1.0:
		_wrap_to_start()
	elif _progress >= 1.0:
		_direction = -1.0
	elif _progress <= 0.0:
		_direction = 1.0
	_moving = true
	set_physics_process(true)
	_fire(on_move_start, _activator)


## Input: stop where it is. The next Start carries on in the same direction.
func stop(activator: Variant = null) -> void:
	if _receive(&"stop", activator):
		_moving = false


func _physics_process(delta: float) -> void:
	if not _moving:
		set_physics_process(false)  # also switches it off in the editor
		return

	var goal := 1.0 if _direction > 0.0 else 0.0
	var distance := move_offset.length()
	_progress = move_toward(_progress, goal, 1.0 if distance == 0.0 else speed * delta / distance)
	_apply()
	if _progress != goal:
		return

	var who := LogicCore.as_activator(_activator)  # it may have been freed along the way
	match mode:
		Mode.ONCE:
			_moving = false
			_direction = -_direction
		Mode.PING_PONG:
			_direction = -_direction
		Mode.LOOP:
			_wrap_to_start()
	_fire(on_move_end, who)


func _wrap_to_start() -> void:
	_progress = 0.0
	_direction = 1.0
	_apply()


func _apply() -> void:
	_mover.position = _origin + move_offset * _progress


func _logic_warnings() -> PackedStringArray:
	var warnings := super()
	if move_offset.is_zero_approx():
		warnings.append("Move Offset is zero, so this node has nowhere to go.")
	if target == null and get_child_count() == 0:
		warnings.append("Nothing to move: add a node under this one or pick a Target.")
	warnings.append_array(LogicCore.platform_warnings(target if target else self))
	return warnings

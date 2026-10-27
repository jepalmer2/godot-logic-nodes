@tool
@icon("res://addons/godot_logic_nodes/icons/LogicNode_Rotate.svg")
class_name LogicRotate
extends LogicNode
## Rotates a node between how it was placed (the start) and [member rotate_offset]
## degrees away from there (the end). Put the node to rotate under this one, or pick
## another [member target]. Good for hinged doors, fans and levers.
## For turning platforms the player can ride, make the turning body an AnimatableBody3D
## (not a StaticBody3D).

enum Mode {
	ONCE,       ## Each Start turns to the other end and stops there.
	PING_PONG,  ## Turns back and forth until Stop.
	LOOP,       ## Turns to the end, jumps back to the start, and repeats until Stop.
}

## Output: began rotating.
signal on_rotate_start(activator: Node)
## Output: arrived at either end.
signal on_rotate_end(activator: Node)

## The node to rotate. Empty rotates this node, and everything under it.
@export var target: Node3D:
	set(value):
		target = value
		update_configuration_warnings()
## How far to turn, in degrees around X, Y and Z. A door swinging open is usually (0, 90, 0).
@export var rotate_offset := Vector3(0.0, 90.0, 0.0):
	set(value):
		rotate_offset = value
		update_configuration_warnings()
## Degrees per second.
@export_range(0.1, 3600.0, 0.1, "or_greater", "suffix:°/s") var speed := 90.0
## What happens when it reaches an end.
@export var mode := Mode.ONCE

var _rotator: Node3D
var _origin: Vector3     # starting rotation, in degrees
var _progress := 0.0     # 0 = start, 1 = end
var _direction := 1.0    # +1 toward the end, -1 toward the start
var _rotating := false
var _activator: Node


func _logic_ready() -> void:
	_rotator = target if target else self
	_origin = _rotator.rotation_degrees
	LogicCore.prepare_platforms(_rotator)
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


## Input: start rotating, or carry on after Stop. Resting at an end, it heads for the other end
## (in Loop mode, it jumps back to the start first).
func start(activator: Variant = null) -> void:
	if not _receive(&"start", activator) or _rotating:
		return
	_activator = LogicCore.as_activator(activator)
	if mode == Mode.LOOP and _progress >= 1.0:
		_wrap_to_start()
	elif _progress >= 1.0:
		_direction = -1.0
	elif _progress <= 0.0:
		_direction = 1.0
	_rotating = true
	set_physics_process(true)
	_fire(on_rotate_start, _activator)


## Input: stop where it is. The next Start carries on in the same direction.
func stop(activator: Variant = null) -> void:
	if _receive(&"stop", activator):
		_rotating = false


func _physics_process(delta: float) -> void:
	if not _rotating:
		set_physics_process(false)  # also switches it off in the editor
		return

	var goal := 1.0 if _direction > 0.0 else 0.0
	var degrees := rotate_offset.length()
	_progress = move_toward(_progress, goal, 1.0 if degrees == 0.0 else speed * delta / degrees)
	_apply()
	if _progress != goal:
		return

	var who := LogicCore.as_activator(_activator)  # it may have been freed along the way
	match mode:
		Mode.ONCE:
			_rotating = false
			_direction = -_direction
		Mode.PING_PONG:
			_direction = -_direction
		Mode.LOOP:
			_wrap_to_start()
	_fire(on_rotate_end, who)


func _wrap_to_start() -> void:
	_progress = 0.0
	_direction = 1.0
	_apply()


func _apply() -> void:
	_rotator.rotation_degrees = _origin + rotate_offset * _progress


func _logic_warnings() -> PackedStringArray:
	var warnings := super()
	if rotate_offset.is_zero_approx():
		warnings.append("Rotate Offset is zero, so this node has nowhere to turn.")
	if target == null and get_child_count() == 0:
		warnings.append("Nothing to rotate: add a node under this one or pick a Target.")
	warnings.append_array(LogicCore.platform_warnings(target if target else self))
	return warnings

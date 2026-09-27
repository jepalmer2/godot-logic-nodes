@tool
@icon("res://addons/godot_logic_nodes/icons/BaseNode.png")
class_name LogicNode
extends Node3D
## Base for every Logic Node. Outputs are signals, inputs are methods, and
## connections are rows in [member outputs], edited in the Logic I/O panel.
## Add a subclass (LogicRelay, LogicRotate...), not this node itself.

## If off, this node ignores inputs and fires nothing until it receives Enable.
@export var start_enabled := true
## Print every input and output of this node to the Output panel.
@export var trace := false

## The Outputs table. Saved with the scene, edited in the Logic I/O panel, hidden from the Inspector.
@export_storage var outputs: Array[LogicConnection] = []:
	set(value):
		outputs = value
		update_configuration_warnings()
		update_gizmos()

var is_enabled := true
var _spent_rows := {}  # "Once" state lives here: row Resources are shared between instances of a scene


func _ready() -> void:
	add_to_group(&"logic_nodes")  # the panel and gizmo find Logic Nodes through this group
	if Engine.is_editor_hint():
		return
	is_enabled = start_enabled
	_wire_outputs()
	_logic_ready()


## Input: turn this node on.
func enable(activator: Variant = null) -> void:
	if trace:
		LogicCore.trace_input(self, &"enable", activator)
	is_enabled = true


## Input: turn this node off. It ignores inputs and fires nothing until enabled again.
func disable(activator: Variant = null) -> void:
	if trace:
		LogicCore.trace_input(self, &"disable", activator)
	is_enabled = false


# --- For subclasses ------------------------------------------------------------

## Override instead of _ready(). Runs in the game only, never in the editor.
func _logic_ready() -> void:
	pass


## Call first in every input. Returns false when the input should be ignored.
func _receive(input_name: StringName, activator: Variant) -> bool:
	if Engine.is_editor_hint():
		return false
	if trace:
		LogicCore.trace_input(self, input_name, activator)
	return is_enabled


## Call to fire an output signal.
func _fire(output: Signal, activator: Variant = null) -> void:
	if is_enabled:
		LogicCore.fire(self, output, activator, trace)


## Override to add warnings. Call super() and append to the result.
func _logic_warnings() -> PackedStringArray:
	return PackedStringArray()


# --- Internals -----------------------------------------------------------------

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := _logic_warnings()
	for row in outputs:
		var problem := _row_problem(row)
		if problem:
			warnings.append(problem)
	return warnings


## Why a row can't work, or "" if it's fine.
func _row_problem(row: LogicConnection) -> String:
	if row == null:
		return "An output row is empty. Delete it in the Logic I/O panel."
	if not has_signal(row.output):
		return "Output '%s' doesn't exist on this node." % row.output
	var target := get_node_or_null(row.target)
	if target == null:
		return "Output '%s' points at '%s', which isn't in the scene." % [row.output, row.target]
	if not target.has_method(row.input):
		return "Output '%s': '%s' has no input '%s'." % [row.output, target.name, row.input]
	return ""


func _wire_outputs() -> void:
	# One connection per output signal, which then walks its rows in table order.
	# (Godot refuses a second connection to the same method on the same signal, even with different binds.)
	var wired := {}
	for row in outputs:
		var problem := _row_problem(row)
		if problem:
			push_warning("%s: %s The row was skipped." % [get_path(), problem])
			continue
		if not wired.has(row.output):
			wired[row.output] = true
			connect(row.output, _dispatch.bind(row.output))


func _dispatch(activator: Node, output: StringName) -> void:
	for row in outputs:
		if row and row.output == output and not _row_problem(row):
			_send(activator, row, get_node(row.target))


func _send(activator: Node, row: LogicConnection, target: Node) -> void:
	if row.once:
		if _spent_rows.has(row):
			return
		_spent_rows[row] = true
	if row.delay > 0.0:
		await get_tree().create_timer(row.delay, false).timeout
		if not is_instance_valid(target):
			return
		activator = LogicCore.as_activator(activator)  # it may have been freed while waiting
	if target is LogicNode:
		target.call(row.input, activator)
	else:
		target.call(row.input)  # a built-in node (AnimationPlayer.play...) doesn't take an activator

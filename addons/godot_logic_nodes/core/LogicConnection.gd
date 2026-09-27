@tool
class_name LogicConnection
extends Resource
## One row in a Logic Node's Outputs table: when OUTPUT fires, call INPUT on TARGET.

## The output (signal) on the node that owns this row.
@export var output: StringName
## Path from the node that owns this row to the target node.
@export var target: NodePath
## The input (method) to call on the target.
@export var input: StringName
## Seconds to wait before calling the input.
@export_range(0.0, 3600.0, 0.05, "or_greater", "suffix:s") var delay := 0.0
## Only ever fire this row once.
@export var once := false

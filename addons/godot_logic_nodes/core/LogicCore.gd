@tool
class_name LogicCore
extends RefCounted
## Shared helpers for LogicNode, LogicVolume and the editor panel. Never added to a scene.

const MAX_CHAIN_DEPTH := 64
static var _depth := 0


## Fires an output: cleans up the activator, guards against loops, traces.
static func fire(from: Node, output: Signal, activator: Variant, trace: bool) -> void:
	var who := as_activator(activator)
	if trace:
		print("[%s] → %s  (activator: %s)" % [from.name, output.get_name(), _name_of(who)])
	if _depth >= MAX_CHAIN_DEPTH:
		push_error("%s: '%s' fired %d links deep, which looks like a loop. Put a delay somewhere in the cycle." \
				% [from.get_path(), output.get_name(), _depth])
		return
	_depth += 1
	output.emit(who)
	_depth -= 1


static func trace_input(to: Node, input_name: StringName, activator: Variant) -> void:
	print("[%s] ← %s  (activator: %s)" % [to.name, input_name, _name_of(as_activator(activator))])


## Anything that isn't a live Node becomes null.
static func as_activator(value: Variant) -> Node:
	if is_instance_valid(value) and value is Node:
		return value
	return null


## The outputs (signals) a Logic Node declares, for the panel's dropdowns.
static func outputs_of(node: Node) -> Array[StringName]:
	var result: Array[StringName] = []
	var script: Script = node.get_script()
	if script:
		for sig in script.get_script_signal_list():
			result.append(StringName(sig["name"]))
	return result


## The inputs (public methods taking at most one argument) a node's script declares.
static func inputs_of(node: Node) -> Array[StringName]:
	var result: Array[StringName] = []
	var script: Script = node.get_script()
	if script:
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if method_name.begins_with("_") or method_name.begins_with("@") or method["args"].size() > 1:
				continue
			if not result.has(StringName(method_name)):
				result.append(StringName(method_name))
	return result


## For Move and Rotate: lets players ride whatever [param mover] carries. An AnimatableBody3D
## under the mover stays where it was in the physics world while its mesh moves away, unless
## Sync to Physics is off (that setting only follows changes to the body's own position).
static func prepare_platforms(mover: Node3D) -> void:
	for body in mover.find_children("*", "AnimatableBody3D", true, false):
		body.sync_to_physics = false


## For Move and Rotate: a warning for each StaticBody3D that [param mover] carries. A StaticBody3D
## that moves still pushes things, but a player standing on it slides off instead of riding along.
static func platform_warnings(mover: Node3D) -> PackedStringArray:
	var warnings := PackedStringArray()
	var bodies := mover.find_children("*", "StaticBody3D", true, false)
	bodies.push_front(mover)
	for body in bodies:
		if body is StaticBody3D and not body is AnimatableBody3D:
			var where := str(mover.name) if body == mover else "%s/%s" % [mover.name, mover.get_path_to(body)]
			warnings.append(("'%s' is a StaticBody3D, so a player standing on it won't ride along. " +
					"Right-click it in the Scene tree, choose Change Type, and pick AnimatableBody3D.") % where)
	return warnings


## For Move and Rotate in the editor: refresh warnings when a node under [param mover] is added,
## removed or has its type changed (Change Type swaps in a new node).
static func watch_mover(logic_node: Node, mover: Node, changed: Node) -> void:
	if mover and is_instance_valid(mover) and (mover == changed or mover.is_ancestor_of(changed)):
		logic_node.update_configuration_warnings.call_deferred()  # a removed node is still in the tree right now


static func _name_of(node: Node) -> String:
	return str(node.name) if node else "none"

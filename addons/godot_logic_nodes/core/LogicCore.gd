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


static func _name_of(node: Node) -> String:
	return str(node.name) if node else "none"

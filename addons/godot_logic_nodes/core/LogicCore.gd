@tool
class_name LogicCore
extends RefCounted
## Shared helpers for LogicNode, LogicVolume and the editor panel. Never added to a scene.

const MAX_CHAIN_DEPTH := 64
## Seconds trimmed off every delay so rounding error never adds a whole extra physics tick.
const DELAY_SLACK := 0.0001
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


## For delays: a signal that fires [param seconds] from now, pausing with the game. Counts
## physics ticks (a fixed 60 a second by default), not rendered frames, so a delay takes the
## same time on every machine whatever the frame rate. The tiny trim stops rounding error from
## adding a whole extra tick (0.05 s minus three 1/60 s ticks comes out a hair above zero).
static func wait(node: Node, seconds: float) -> Signal:
	return node.get_tree().create_timer(maxf(seconds - DELAY_SLACK, 0.0), false, true).timeout


static func trace_input(to: Node, input_name: StringName, activator: Variant) -> void:
	print("[%s] ← %s  (activator: %s)" % [to.name, input_name, _name_of(as_activator(activator))])


## The ## doc comment written above [param member] (an output signal or input method) in
## [param node]'s script or the scripts it extends, as plain text for the panel's tooltips.
## One description, shared with the Inspector and the built-in help. Empty if there is none.
static func describe(node: Node, member: StringName) -> String:
	var declaration := RegEx.create_from_string("^(?:signal|func)\\s+%s\\b" % member)
	var script: Script = node.get_script()
	while script:
		var lines := script.source_code.split("\n")
		for i in lines.size():
			if declaration.search(lines[i]):
				var doc := PackedStringArray()
				var above := i - 1
				while above >= 0 and lines[above].strip_edges().begins_with("##"):
					doc.insert(0, lines[above].strip_edges().trim_prefix("##").strip_edges())
					above -= 1
				return _plain_text(" ".join(doc))
		script = script.get_base_script()
	return ""


## "Output: the count reached [member goal]." → "The count reached Goal."
static func _plain_text(doc: String) -> String:
	for prefix in ["Output:", "Input:"]:
		doc = doc.trim_prefix(prefix).strip_edges()
	var references := RegEx.create_from_string("\\[(?:member|signal|method|param) ([^\\]]+)\\]")
	for found in references.search_all(doc):
		doc = doc.replace(found.get_string(), found.get_string(1).capitalize())
	doc = RegEx.create_from_string("\\[/?[a-z]+\\]").sub(doc, "", true)  # [b], [code] and the like
	return doc.left(1).to_upper() + doc.substr(1)


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


## The inputs (public methods taking at most one argument and returning nothing) a node's script declares.
static func inputs_of(node: Node) -> Array[StringName]:
	var result: Array[StringName] = []
	var script: Script = node.get_script()
	if script:
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if method_name.begins_with("_") or method_name.begins_with("@") or method["args"].size() > 1:
				continue
			if method["return"]["type"] != TYPE_NIL:
				continue  # a helper that returns something (All Outputs, World Offset), not an input
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


## For Trigger and Interact: adds the hidden box-shaped Area3D that detects bodies.
## The area is internal, so it never shows in the Scene tree or gets saved.
static func add_volume(to: Node3D, shape: BoxShape3D, mask: int) -> Area3D:
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var area := Area3D.new()
	area.collision_layer = 0  # nothing needs to detect the volume itself
	area.collision_mask = mask
	area.monitorable = false
	area.add_child(collision)
	to.add_child(area, false, Node.INTERNAL_MODE_FRONT)
	return area


static func _name_of(node: Node) -> String:
	return str(node.name) if node else "none"

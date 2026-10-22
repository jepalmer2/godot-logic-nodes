@tool
@icon("res://addons/godot_logic_nodes/icons/LogicNode_Interact_Placeholder.svg")
class_name LogicInteract
extends LogicNode
## A box-shaped area where the player presses a key to use something: a lever, a button,
## a door handle. Fires [signal on_interact] when the key is pressed while someone matching
## [member only_group] is inside. It also fires On Trigger Enter and On Trigger Exit, which
## are handy for showing and hiding a "Press E" prompt.
## (Built like the Trigger Volume, but not a subclass of it, so the two sit side by side
## in Add Child Node.)

## Output: the interact key was pressed inside the box. Activator is whoever pressed it.
signal on_interact(activator: Node)
## Output: something that matches [member only_group] entered the box.
signal on_trigger_enter(activator: Node)
## Output: something that matches [member only_group] left the box.
signal on_trigger_exit(activator: Node)

## The Input Map action that counts as interacting. Add it in Project Settings > Input Map.
@export var action: StringName = &"gln_interact":
	set(value):
		action = value
		update_configuration_warnings()
## Width, height and depth of the box, in meters, centered on this node.
@export var size := Vector3(2.0, 2.0, 2.0):
	set(value):
		size = value.max(Vector3.ONE * 0.01)
		if _shape:
			_shape.size = size
		update_gizmos()
## Only react to bodies in this group (for example "gln_player"). Leave empty to react to any body.
@export var only_group: StringName = &"gln_player"
## Which physics layers it detects.
@export_flags_3d_physics var collision_mask := 1:
	set(value):
		collision_mask = value
		if _area:
			_area.collision_mask = value
## Editor only: tint of the see-through box in the 3D view, so different zones are easy to
## tell apart. Alpha sets how see-through the fill is. Never shown in the game.
@export var volume_color := Color(1.0, 127.0 / 255.0, 0.0, 16.0 / 255.0):  # R255 G127 B0 A16
	set(value):
		volume_color = value
		update_gizmos()

var _area: Area3D
var _shape: BoxShape3D
var _inside: Array[Node3D] = []  # matching bodies in the box right now, oldest first


func _logic_ready() -> void:
	_shape = BoxShape3D.new()
	_shape.size = size
	_area = LogicCore.add_volume(self, _shape, collision_mask)
	_area.body_entered.connect(_on_body.bind(on_trigger_enter))
	_area.body_exited.connect(_on_body.bind(on_trigger_exit))


func _on_body(body: Node3D, output: Signal) -> void:
	if only_group != &"" and not body.is_in_group(only_group):
		return
	if output == on_trigger_enter:
		_inside.append(body)
	else:
		_inside.erase(body)
	_fire(output, body)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _inside.is_empty() or not InputMap.has_action(action):
		return
	if event.is_action_pressed(action, false):  # false = ignore key repeat while held
		_fire(on_interact, _inside[0])


func _logic_warnings() -> PackedStringArray:
	var warnings := super()
	if collision_mask == 0:
		warnings.append("Collision Mask is empty, so nothing can ever enter this zone.")
	if action == &"":
		warnings.append("Action is empty, so nothing can ever interact with this zone.")
	elif not ProjectSettings.has_setting("input/" + action):
		warnings.append("The Input Map has no '%s' action. Add it in Project Settings > Input Map." % action)
	return warnings

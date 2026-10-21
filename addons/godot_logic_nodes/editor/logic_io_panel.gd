@tool
extends VBoxContainer
## The Logic I/O bottom panel: a Hammer-style table of the selected Logic Node's
## outputs, plus a read-only list of everything wired into it.

const HEADERS := ["My Output", "Target", "", "Target Input", "Delay", "Once", ""]

## Set by godot_logic_nodes.gd. When null (tests), edits are applied directly without undo.
var undo_redo: EditorUndoRedoManager

var _node: Node  # the Logic Node being edited
var _rebuild_queued := false

@onready var _title: Label = $Header/Title
@onready var _show_all: CheckBox = $Header/ShowAll
@onready var _add_button: Button = $Header/AddOutput
@onready var _tabs: TabContainer = $Tabs
@onready var _grid: GridContainer = $Tabs/Outputs/Grid
@onready var _inputs: ItemList = $Tabs/Inputs


func _ready() -> void:
	_add_button.pressed.connect(_add_row)
	_show_all.toggled.connect(func(_on: bool) -> void: _queue_rebuild())
	_inputs.item_activated.connect(_select_source)
	visibility_changed.connect(_queue_rebuild)  # pick up renames made while the panel was hidden
	_rebuild()


## Called by godot_logic_nodes.gd when the selection changes. Pass null to clear the panel.
func edit(node: Node) -> void:
	_node = node
	_queue_rebuild()


# --- Building the UI -----------------------------------------------------------

func _queue_rebuild() -> void:
	# Rebuild after the current signal finishes, so we never free the control that is emitting.
	if not _rebuild_queued:
		_rebuild_queued = true
		_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	if not is_node_ready():
		return
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_inputs.clear()

	var editing := is_instance_valid(_node) and _node.is_inside_tree()
	_add_button.disabled = not editing
	if not editing:
		_node = null
		_title.text = "Select a Logic Node to edit its connections."
		return
	_title.text = "%s  (%s)" % [_node.name, _class_label(_node)]
	var prefab := _prefab_path()
	if prefab:
		_title.text += "  ·  greyed-out rows come from %s; edit them there" % prefab.get_file()

	for header in HEADERS:
		var label := Label.new()
		label.text = header
		label.add_theme_color_override("font_color", get_theme_color("font_disabled_color", "Editor"))
		_grid.add_child(label)
	if prefab:
		for row in _node.outputs:
			_add_row_controls(-1, row, true)
	var rows: Array[LogicConnection] = _node.get(_layer())
	for i in rows.size():
		_add_row_controls(i, rows[i])

	_tabs.set_tab_title(0, "Outputs (%d)" % _node.all_outputs().size())
	_fill_incoming()
	_tabs.set_tab_title(1, "Inputs (%d)" % _inputs.item_count)


## One row of controls. [param locked] rows (from a placed scene's own file) are shown but can't be edited.
func _add_row_controls(index: int, row: LogicConnection, locked := false) -> void:
	var first_control := _grid.get_child_count()
	if row == null:
		row = LogicConnection.new()  # an empty slot in the array; shown as a blank row
	var target: Node = _node.get_node_or_null(row.target) if not row.target.is_empty() else null

	# My Output
	var output_menu := OptionButton.new()
	_fill_menu(output_menu, LogicCore.outputs_of(_node), row.output)
	output_menu.item_selected.connect(func(item: int) -> void:
		_set_field(index, "output", StringName(output_menu.get_item_metadata(item))))
	_grid.add_child(output_menu)

	# Target
	var target_menu := OptionButton.new()
	target_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var root := _scene_root()
	var candidates := _target_candidates()
	if target == null:
		target_menu.add_item("(pick a target)" if row.target.is_empty() else "Missing: %s" % row.target)
		target_menu.set_item_metadata(0, "")
	for node in candidates:
		target_menu.add_item(str(root.get_path_to(node)))
		target_menu.set_item_metadata(target_menu.item_count - 1, node.get_path())
		if node == target:
			target_menu.select(target_menu.item_count - 1)
	target_menu.item_selected.connect(func(item: int) -> void:
		var picked: Variant = target_menu.get_item_metadata(item)
		if picked is NodePath:
			_set_target(index, get_tree().root.get_node(picked)))
	_grid.add_child(target_menu)

	# Pick... (opens Godot's node picker, which also reaches nodes inside instanced scenes)
	var pick := Button.new()
	pick.text = "…"
	pick.tooltip_text = "Pick the target from the scene tree."
	pick.pressed.connect(func() -> void:
		EditorInterface.popup_node_selector(func(path: NodePath) -> void:
			if not path.is_empty():
				_set_target(index, _scene_root().get_node_or_null(path))))
	_grid.add_child(pick)

	# Target Input
	var input_menu := OptionButton.new()
	if target:
		_fill_menu(input_menu, _inputs_of(target), row.input)
	else:
		input_menu.add_item("(pick a target first)")
		input_menu.disabled = true
	input_menu.item_selected.connect(func(item: int) -> void:
		_set_field(index, "input", StringName(input_menu.get_item_metadata(item))))
	_grid.add_child(input_menu)

	# Delay
	var delay := SpinBox.new()
	delay.min_value = 0.0
	delay.max_value = 3600.0
	delay.step = 0.05
	delay.allow_greater = true
	delay.suffix = "s"
	delay.value = row.delay
	delay.value_changed.connect(func(value: float) -> void: _set_field(index, "delay", value))
	_grid.add_child(delay)

	# Once
	var once := CheckBox.new()
	once.button_pressed = row.once
	once.tooltip_text = "Only fire this connection once."
	once.toggled.connect(func(on: bool) -> void: _set_field(index, "once", on))
	_grid.add_child(once)

	# Delete
	var delete := Button.new()
	delete.text = "✕"
	delete.tooltip_text = "Delete this output."
	delete.pressed.connect(func() -> void: _delete_row(index))
	_grid.add_child(delete)

	if locked:
		var hint := "From %s. Open that scene to change this row." % _prefab_path().get_file()
		for i in range(first_control, _grid.get_child_count()):
			var control: Control = _grid.get_child(i)
			if control is BaseButton:
				control.disabled = true
			elif control is SpinBox:
				control.editable = false
			control.tooltip_text = hint


## Fills a dropdown with friendly names ("cancel_pending" → "Cancel Pending") and selects `current`.
func _fill_menu(menu: OptionButton, names: Array[StringName], current: StringName) -> void:
	if current != &"" and not names.has(current):
		menu.add_item("Missing: %s" % current)
		menu.set_item_metadata(0, current)
	for n in names:
		menu.add_item(String(n).capitalize())
		menu.set_item_metadata(menu.item_count - 1, n)
		if n == current:
			menu.select(menu.item_count - 1)


func _fill_incoming() -> void:
	var root := _scene_root()
	for source in _all_nodes(root):
		if not _is_logic_node(source):
			continue
		for row in source.all_outputs():
			if row and source.get_node_or_null(row.target) == _node:
				var text := "%s · %s → %s" % [root.get_path_to(source), String(row.output).capitalize(), String(row.input).capitalize()]
				if row.delay > 0.0:
					text += "  (%.2fs)" % row.delay
				if row.once:
					text += "  (once)"
				_inputs.add_item(text)
				_inputs.set_item_metadata(_inputs.item_count - 1, source.get_path())


# --- Editing (every change goes through undo/redo) -----------------------------

func _add_row() -> void:
	var rows := _copy_outputs()
	var row := LogicConnection.new()
	var outputs := LogicCore.outputs_of(_node)
	if not outputs.is_empty():
		row.output = outputs[0]
	rows.append(row)
	_commit(rows, "Add Logic Output")


func _delete_row(index: int) -> void:
	var rows := _copy_outputs()
	rows.remove_at(index)
	_commit(rows, "Delete Logic Output")


func _set_field(index: int, field: String, value: Variant) -> void:
	var rows := _copy_outputs()
	rows[index].set(field, value)
	_commit(rows, "Change Logic Output", field == "delay")


func _set_target(index: int, target: Node) -> void:
	if target == null:
		return
	var rows := _copy_outputs()
	rows[index].target = _node.get_path_to(target)
	var inputs := _inputs_of(target)
	if not inputs.has(rows[index].input):
		rows[index].input = inputs[0] if not inputs.is_empty() else &""
	_commit(rows, "Change Logic Output Target")


## Rows are Resources, and Array.duplicate() doesn't copy Resources, so copy each row by hand.
func _copy_outputs() -> Array[LogicConnection]:
	var rows: Array[LogicConnection] = []
	for row: LogicConnection in _node.get(_layer()):
		rows.append(row.duplicate() if row else LogicConnection.new())
	return rows


func _commit(rows: Array[LogicConnection], action: String, merge := false) -> void:
	var layer := _layer()
	if undo_redo == null:
		_node.set(layer, rows)
	else:
		undo_redo.create_action(action, UndoRedo.MERGE_ENDS if merge else UndoRedo.MERGE_DISABLE, _node)
		undo_redo.add_do_property(_node, layer, rows)
		undo_redo.add_undo_property(_node, layer, _node.get(layer))
		undo_redo.add_do_method(self, &"_queue_rebuild")
		undo_redo.add_undo_method(self, &"_queue_rebuild")
		undo_redo.commit_action()
	_queue_rebuild()


func _select_source(item: int) -> void:
	var source := get_tree().root.get_node_or_null(_inputs.get_item_metadata(item))
	if source:
		EditorInterface.get_selection().clear()
		EditorInterface.get_selection().add_node(source)


# --- Helpers -------------------------------------------------------------------

func _scene_root() -> Node:
	if Engine.is_editor_hint() and EditorInterface.get_edited_scene_root():
		return EditorInterface.get_edited_scene_root()
	var top := _node  # outside the editor (tests): the topmost node under the tree root
	while top.get_parent() and top.get_parent() != top.get_tree().root:
		top = top.get_parent()
	return top


## The scene file the node's own rows come from, when the node is part of a placed scene
## (a prefab) rather than the scene being edited. Empty otherwise.
func _prefab_path() -> String:
	var root := _scene_root()
	if _node == root:
		return ""
	if not _node.scene_file_path.is_empty():
		return _node.scene_file_path  # the root of a placed scene
	if _node.owner and _node.owner != root:
		return _node.owner.scene_file_path  # a node inside a placed scene (Editable Children)
	return ""


## Which list the panel edits. Rows added to a placed scene's node go in scene_outputs, so they
## add to the prefab's own rows instead of replacing them.
func _layer() -> StringName:
	return &"scene_outputs" if _prefab_path() else &"outputs"


## Every node in the scene, including nodes inside instanced scenes.
func _all_nodes(from: Node) -> Array[Node]:
	var result: Array[Node] = [from]
	for child in from.get_children():
		result.append_array(_all_nodes(child))
	return result


func _target_candidates() -> Array[Node]:
	var result: Array[Node] = []
	for node in _all_nodes(_scene_root()):
		if _is_logic_node(node) or _show_all.button_pressed:
			result.append(node)
	return result


func _inputs_of(target: Node) -> Array[StringName]:
	if _is_logic_node(target):
		return LogicCore.inputs_of(target)
	# A built-in node: its own "action" methods, meaning public, returning nothing, callable with
	# no arguments, and not a property setter. For example AnimationPlayer: play, stop, pause.
	# Built-in targets are called WITHOUT the activator (see LogicNode._send).
	var result: Array[StringName] = []
	for method in ClassDB.class_get_method_list(target.get_class(), true):
		var method_name := String(method["name"])
		if method_name.begins_with("_") or method_name.begins_with("set_") or method["args"].size() > method["default_args"].size():
			continue
		if method["return"]["type"] == TYPE_NIL:
			result.append(StringName(method_name))
	result.sort()
	return result


func _is_logic_node(node: Node) -> bool:
	return node is LogicNode  # add "or node is LogicVolume" once LogicVolume exists


func _class_label(node: Node) -> String:
	var script: Script = node.get_script()
	var class_name_ := script.get_global_name() if script else &""
	return String(class_name_).trim_prefix("Logic") if class_name_ else node.get_class()

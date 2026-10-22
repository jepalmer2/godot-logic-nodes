@tool
@icon("res://addons/godot_logic_nodes/icons/LogicNode_Debug.png")
class_name LogicDebug
extends LogicNode
## Shows a short message on the game screen when something reaches it, then passes the event on.
## Drop it into a chain to see what fired while playing. For a full console log, turn on Trace instead.

const MAX_LINES := 8
const FADE_TIME := 0.5

## Output: the message was shown. Also fires in a release build, where nothing is shown.
signal on_show(activator: Node)

## The text to show. Empty shows this node's name.
@export var message := "Debug"
## Text color, so different checkpoints are easy to tell apart.
@export var color := Color(1.0, 0.85, 0.1)
## Seconds the line stays on screen before it fades.
@export_range(0.1, 30.0, 0.1, "or_greater", "suffix:s") var duration := 3.0
## Adds who set it off, e.g. "Gate open (Player)".
@export var show_activator := false
## Also print the line to the Output panel.
@export var print_to_console := false
## Show and print nothing in an exported release game. On Show still fires, so the chain keeps working.
@export var debug_builds_only := true

static var _list: VBoxContainer  # one on-screen list, shared by every Debug node in the scene


## Input: show the message, then pass the event on.
func trigger(activator: Variant = null) -> void:
	if not _receive(&"trigger", activator):
		return
	if OS.is_debug_build() or not debug_builds_only:
		_show(LogicCore.as_activator(activator))
	_fire(on_show, activator)


func _show(who: Node) -> void:
	var text := message if message != "" else str(name)
	if show_activator:
		text += " (%s)" % (str(who.name) if who else "none")
	if print_to_console:
		print("[Debug] %s: %s" % [name, text])

	var list := _get_list()
	var last: Label = list.get_child(-1) if list.get_child_count() > 0 else null
	if last and last.get_meta(&"text") == text and last.get_meta(&"color") == color:
		# Same message again: count it on the same line instead of flooding the screen.
		var repeats: int = last.get_meta(&"repeats") + 1
		last.set_meta(&"repeats", repeats)
		last.text = "%s ×%d" % [text, repeats]
		_start_fade(last)
		return

	var label := Label.new()
	label.text = text
	label.set_meta(&"text", text)
	label.set_meta(&"color", color)
	label.set_meta(&"repeats", 1)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 6)
	label.add_theme_font_size_override(&"font_size", 22)
	list.add_child(label)
	while list.get_child_count() > MAX_LINES:
		var oldest := list.get_child(0)
		list.remove_child(oldest)
		oldest.queue_free()
	_start_fade(label)


## Shows the line fully, waits Duration, fades it out and removes it. Restarts if already fading.
func _start_fade(label: Label) -> void:
	if label.has_meta(&"tween"):  # get_meta() with a null default still errors when the key is missing
		(label.get_meta(&"tween") as Tween).kill()
	label.modulate.a = 1.0
	var tween := label.create_tween()
	tween.tween_interval(duration)
	tween.tween_property(label, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(label.queue_free)
	label.set_meta(&"tween", tween)


## The shared list, built the first time any Debug node fires in this scene.
func _get_list() -> VBoxContainer:
	if not is_instance_valid(_list):  # first message, or the last scene (and its list) was freed
		var layer := CanvasLayer.new()
		layer.name = "LogicDebugMessages"
		layer.layer = 100  # above the game's own UI
		layer.process_mode = Node.PROCESS_MODE_ALWAYS  # keeps fading while the game is paused
		_list = VBoxContainer.new()
		_list.position = Vector2(16, 16)
		_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_list)
		var scene := get_tree().current_scene
		# Deferred: Debug often fires inside a physics callback, where the tree can't change.
		(scene if scene else get_tree().root).add_child.call_deferred(layer)
	return _list

@tool
@icon("res://addons/logic_nodes/icons/relay.svg")
class_name LogicRelay
extends LogicNode
## Passes a trigger on to everything wired to [signal triggered], optionally after a delay.

## Output: fires after [member delay] seconds.
signal triggered(activator: Node)

## Seconds to wait before firing. 0 fires immediately.
@export_range(0.0, 60.0, 0.05, "or_greater", "suffix:s") var delay := 0.0
## Only ever fire once.
@export var fire_once := false

var _spent := false
var _generation := 0  # bumped by cancel_pending so waiting triggers are dropped


## Input: pass the trigger on.
func trigger(activator: Variant = null) -> void:
	if not _receive(&"trigger", activator) or _spent:
		return
	_spent = fire_once
	if delay > 0.0:
		var gen := _generation
		await get_tree().create_timer(delay, false).timeout  # false = pauses with the game
		if gen != _generation:
			return
	_fire(triggered, activator)


## Input: drop any triggers still waiting on the delay (Hammer's CancelPending).
func cancel_pending(activator: Variant = null) -> void:
	if _receive(&"cancel_pending", activator):
		_generation += 1

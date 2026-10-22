@tool
@icon("res://addons/godot_logic_nodes/icons/LogicNode_Timer_Placeholder.svg")
class_name LogicTimer
extends LogicNode
## Waits [member wait_time] seconds, then fires On Timeout. With [member repeat] on, it keeps
## firing every Wait Time until Stop. Pauses with the game.

## Output: Wait Time ran out. Activator = whoever sent the last Start or Restart.
signal on_timeout(activator: Node)

## Seconds until On Timeout.
@export_range(0.05, 3600.0, 0.05, "or_greater", "suffix:s") var wait_time := 1.0
## Off: fire once and stop. On: fire every Wait Time until Stop.
@export var repeat := false
## Only used when Repeat is on. 0 = forever; 3 = fire 3 times, then stop.
@export_range(0, 1000, 1, "or_greater") var max_repeats := 0

var _running := false
var _time_left := 0.0  # 0 = at rest; the next Start begins a full Wait Time
var _fired := 0        # timeouts since the last fresh Start or Restart
var _activator: Node


## Input: start counting. After Stop, carries on with the time that was left. Ignored if already running.
func start(activator: Variant = null) -> void:
	if not _receive(&"start", activator) or _running:
		return
	_activator = LogicCore.as_activator(activator)
	if _time_left <= 0.0:
		_time_left = wait_time
		_fired = 0
	_run()


## Input: pause and keep the time left. The next Start carries on from there.
func stop(activator: Variant = null) -> void:
	if _receive(&"stop", activator):
		_running = false


## Input: start again from the full Wait Time, whether running or not.
func restart(activator: Variant = null) -> void:
	if not _receive(&"restart", activator):
		return
	_activator = LogicCore.as_activator(activator)
	_time_left = wait_time
	_fired = 0
	_run()


func _run() -> void:
	_running = true
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not _running:
		set_physics_process(false)  # also switches it off in the editor
		return

	_time_left -= delta
	if _time_left > 0.0:
		return

	_fired += 1
	if repeat and (max_repeats == 0 or _fired < max_repeats):
		_time_left += wait_time  # carry the overshoot, so ticks don't drift; a changed Wait Time applies here
	else:
		_running = false
		_time_left = 0.0
	_fire(on_timeout, LogicCore.as_activator(_activator))  # it may have been freed while waiting

extends Node
## Test harness for StressTest.tscn. Not part of the addon: it only watches the Logic Nodes
## in this scene, prints live stats on screen, and prints PASS or FAIL after [member duration].

## How long the test runs, in seconds. The Alpha success criterion is 5 minutes.
@export var duration := 300.0
## Seconds to let the scene settle before taking the memory and node-count baseline.
@export var warmup := 10.0
## The relay at the end of the ring. One lap ends each time it fires.
@export var lap_relay: LogicRelay

const MIN_FPS := 30.0
const LAP_DRIFT := 0.10        # mean lap time may drift at most 10% from the warm-up laps
const LAP_SPIKE := 1.5         # no single lap may take more than 1.5x the warm-up mean
const MEMORY_GROWTH := 0.05    # static memory may grow at most 5% after warm-up...
const MEMORY_SLACK := 2 << 20  # ...or 2 MB, whichever is larger

var _counts := {}              # Logic Node -> times it fired
var _laps: Array[float] = []   # seconds each lap took
var _lap_started := 0.0
var _elapsed := 0.0
var _min_fps := INF
var _baseline := {}
var _done := false
var _logger := _ErrorCounter.new()

@onready var _label: Label = $Overlay/Stats


func _ready() -> void:
	OS.add_logger(_logger)
	for node in get_tree().get_nodes_in_group(&"logic_nodes"):
		if node is LogicRelay:
			_counts[node] = 0
			node.on_trigger.connect(_on_fired.bind(node))
	lap_relay.on_trigger.connect(_on_lap)
	print("Stress test: watching %d relays for %d seconds." % [_counts.size(), duration])


func _exit_tree() -> void:
	OS.remove_logger(_logger)


func _on_fired(_activator: Node, node: LogicRelay) -> void:
	_counts[node] += 1


func _on_lap(_activator: Node) -> void:
	if _lap_started > 0.0:
		_laps.append(_elapsed - _lap_started)
	_lap_started = _elapsed


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	if _elapsed > warmup:  # loading hitches aren't steady-state
		_min_fps = minf(_min_fps, Engine.get_frames_per_second())
	if _baseline.is_empty() and _elapsed >= warmup:
		_baseline = _snapshot()
	_label.text = "STRESS TEST  %ds / %ds\nRelays: %d   Fires: %d   Laps: %d\nFPS: %d (min %d)   Errors: %d   Warnings: %d" % [
		_elapsed, duration, _counts.size(), _total_fires(), _laps.size(),
		Engine.get_frames_per_second(), 0 if _min_fps == INF else _min_fps, _logger.errors, _logger.warnings]
	if _elapsed >= duration:
		_done = true
		_report()


func _snapshot() -> Dictionary:
	return {
		memory = Performance.get_monitor(Performance.MEMORY_STATIC),
		nodes = _count_nodes(get_tree().current_scene),  # this scene only, not editor tooling
	}


func _total_fires() -> int:
	var total := 0
	for count in _counts.values():
		total += count
	return total


func _report() -> void:
	var now := _snapshot()
	var results: Array[Array] = []  # [passed, metric, detail]

	results.append([_logger.errors == 0 and _logger.warnings == 0, "No errors or warnings",
			"%d errors, %d warnings" % [_logger.errors, _logger.warnings]])

	var laps := _laps.size()
	var rounds: int = _counts[lap_relay]  # times the ring went all the way round
	var skipped: Array[String] = []
	for node in _counts:
		if absi(_counts[node] - rounds) > 1:
			skipped.append("%s (%d)" % [node.name, _counts[node]])
	results.append([rounds > 0 and skipped.is_empty(), "Every relay fired once per lap",
			"%d laps, %d relays, %d fires%s" % [rounds, _counts.size(), _total_fires(),
			"" if skipped.is_empty() else "; off: " + ", ".join(skipped.slice(0, 5))]])

	var warm := _mean(_laps.slice(0, 5))
	var late := _mean(_laps.slice(maxi(0, laps - 20)))
	var slowest := _laps.max() if laps else 0.0
	results.append([laps >= 10 and absf(late - warm) <= warm * LAP_DRIFT, "Lap time doesn't drift",
			"first laps %.3fs, last laps %.3fs (limit ±%d%%)" % [warm, late, LAP_DRIFT * 100]])
	results.append([laps >= 10 and slowest <= warm * LAP_SPIKE, "No lap spikes",
			"slowest lap %.3fs (limit %.3fs)" % [slowest, warm * LAP_SPIKE]])

	var growth: float = now.memory - _baseline.memory
	var allowed := maxf(_baseline.memory * MEMORY_GROWTH, MEMORY_SLACK)
	results.append([growth <= allowed, "Memory stays flat",
			"%+.2f MB since warm-up (limit %.2f MB)" % [growth / 1048576.0, allowed / 1048576.0]])

	results.append([now.nodes == _baseline.nodes, "No leaked nodes",
			"%d nodes in the scene after warm-up, %d at the end" % [_baseline.nodes, now.nodes]])

	results.append([_min_fps >= MIN_FPS, "Frame rate holds",
			"minimum %d FPS (limit %d)" % [_min_fps, MIN_FPS]])

	var passed := results.all(func(r: Array) -> bool: return r[0])
	var lines: Array[String] = ["", "===== STRESS TEST: %s =====" % ("PASS" if passed else "FAIL"),
			"%d Logic Nodes, %d seconds" % [get_tree().get_nodes_in_group(&"logic_nodes").size(), duration]]
	for r in results:
		lines.append("[%s] %s: %s" % ["PASS" if r[0] else "FAIL", r[1], r[2]])
	var text := "\n".join(lines)
	print(text)
	_label.text = text.strip_edges()
	_label.modulate = Color.GREEN if passed else Color.RED


func _count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children(true):
		total += _count_nodes(child)
	return total


func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v in values:
		total += v
	return total / values.size()


## Counts every error and warning the engine reports while the test runs.
class _ErrorCounter extends Logger:
	var errors := 0
	var warnings := 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			warnings += 1
		else:
			errors += 1

	func _log_message(_message: String, error: bool) -> void:
		if error:
			errors += 1

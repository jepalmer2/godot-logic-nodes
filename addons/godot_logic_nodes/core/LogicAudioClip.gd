@tool
@icon("res://addons/godot_logic_nodes/icons/LogicNode_AudioClip_Placeholder.svg")
class_name LogicAudioClip
extends LogicNode
## Plays a sound from logic. Loop off: a one-shot, played once per Play (door creak, click).
## Loop on: repeats until Stop (ambient hum, music). For variety between plays, put an
## AudioStreamRandomizer in Stream.

## Output: Play started the sound.
signal on_audio_start(activator: Node)
## Output: a one-shot sound reached its end. Never fires with Loop on. Activator = whoever sent the last Play.
signal on_audio_end(activator: Node)

## The sound file (.wav, .ogg or .mp3).
@export var stream: AudioStream:
	set(value):
		stream = value
		update_configuration_warnings()
## Off: plays once per Play. On: repeats until Stop, and On Audio End never fires.
## Overrides the file's own Loop import setting.
@export var loop := false
## Loudness in decibels. 0 = the file's own level; -6 is about half as loud.
@export_range(-80.0, 24.0, 0.1, "suffix:dB") var volume_db := -12.0
## Each Play picks a random pitch within ± this amount. 0 = always the same.
@export_range(0.0, 0.5, 0.01) var pitch_variation := 0.0
## On: the sound comes from this node's spot in the level and fades with distance.
## Off: same volume everywhere (music, announcements).
@export var positional := true
## Positional only. Beyond this distance the sound can't be heard. 0 = no limit.
@export_range(0.0, 500.0, 0.5, "or_greater", "suffix:m") var max_distance := 30.0
## How many copies can play at once. 1 = Play restarts the sound.
@export_range(1, 8, 1) var polyphony := 1
## The audio bus it plays on (for separate SFX and Music volume).
@export var bus: StringName = &"Master"

var _player: Node  # AudioStreamPlayer3D, or AudioStreamPlayer when Positional is off
var _loops_itself := false  # false = the stream type can't loop on its own, so _on_finished replays it
var _activator: Node


func _logic_ready() -> void:
	if positional:
		var player_3d := AudioStreamPlayer3D.new()
		player_3d.max_distance = max_distance
		_player = player_3d
	else:
		_player = AudioStreamPlayer.new()
	_player.name = "Player"  # readable name for the remote scene tree while debugging
	_player.stream = _own_copy(stream)
	_player.volume_db = volume_db
	_player.max_polyphony = polyphony
	_player.bus = bus
	_player.finished.connect(_on_finished)
	add_child(_player, false, Node.INTERNAL_MODE_FRONT)  # follows this node; hidden and never saved


## Input: play from the start. With Loop on, it then repeats until Stop.
func play(activator: Variant = null) -> void:
	if not _receive(&"play", activator) or _player.stream == null:
		return
	_activator = LogicCore.as_activator(activator)
	if pitch_variation > 0.0:
		_player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	_player.play()
	_fire(on_audio_start, _activator)


## Input: stop the sound. Doesn't fire On Audio End.
func stop(activator: Variant = null) -> void:
	if _receive(&"stop", activator):
		_player.stop()


## A copy of the stream with its loop flag set from the Loop checkbox, so the file itself never changes.
func _own_copy(source: AudioStream) -> AudioStream:
	if source == null:
		return null
	var copy: AudioStream = source.duplicate()
	if copy is AudioStreamWAV:
		copy.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		if loop:
			copy.loop_begin = 0
			copy.loop_end = int(copy.get_length() * copy.mix_rate)
		_loops_itself = true
	elif "loop" in copy:  # AudioStreamOggVorbis, AudioStreamMP3
		copy.loop = loop
		_loops_itself = true
	return copy


func _on_finished() -> void:
	if loop:
		if not _loops_itself:
			_player.play()  # e.g. an AudioStreamRandomizer: replay it by hand
		return
	_fire(on_audio_end, LogicCore.as_activator(_activator))  # it may have been freed while playing


func _logic_warnings() -> PackedStringArray:
	var warnings := super()
	if stream == null:
		warnings.append("No sound chosen. Pick a file for Stream.")
	return warnings

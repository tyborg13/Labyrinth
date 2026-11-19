extends RefCounted
## The bank supplies the real result, gain, pitch and voice slot after arbitration.

var file: FileAccess
var scene: Node
var decision: int = 0
var sequence: int = 0
var epoch_usec: int = -1
var _bank_id: int = 0
var _loop_id: String = ""

func _millis() -> float:
	var now: int = Time.get_ticks_usec()
	if epoch_usec < 0: epoch_usec = now
	return float(now - epoch_usec) / 1000.0

func requested(bank: Node, cue: String, stack: Array) -> int:
	var ms: float = _millis()
	if bank.get_instance_id() != _bank_id:
		_bank_id = bank.get_instance_id()
		_loop_id = ""
	sequence += 1
	var route: Array[String]
	for frame: Dictionary in stack:
		var path: String = str(frame["source"]).get_file().trim_prefix("sfx_sync_instrumented_")
		if path == "sfx_bank.gd": continue
		route.append("%s:%d:%s" % [path, frame["line"], frame["function"]])
	var router: RefCounted = scene.get("_sfx_router")
	var action: Dictionary = router.get("_action") if router != null else {}
	var actor: Dictionary = router.get("_actor") if router != null else {}
	var run: Dictionary = scene.get("_run_state")
	_write({"id": sequence, "ms": ms, "requested": cue, "decision": decision,
		"section": run.get("section_index", -1), "bank": _bank_id, "source": route,
		"action_serial": router.get("_action_serial") if router != null else -1,
		"action": action.get("type", action.get("kind", "")), "actor": actor.get("type", "")})
	return sequence

func resolved(bank: Node, cue: String, result: String, opts: Dictionary) -> void:
	var ms: float = _millis()
	var row: Dictionary = {"id": opts["qa111_id"], "cue": cue, "ms": ms, "result": result,
		"role": bank.last_request["role"]}
	if result == "played":
		var state: Dictionary = bank.cues[cue]
		var selected: Dictionary = bank.last_play["selected"]
		var stream: AudioStream = bank.last_play["stream"]
		var original: AudioStream = selected["resource"]
		var entry: Dictionary = state["entry"]
		var loop: bool = entry.get("loop", false)
		var changed: bool = not loop or cue != _loop_id
		var voice: AudioStreamPlayer
		if loop:
			voice = bank.active_loop_player()
			_loop_id = cue
		else:
			for candidate: AudioStreamPlayer in state["voices"]:
				if voice == null or int(candidate.get_meta("serial")) > int(voice.get_meta("serial")):
					voice = candidate
		var pitch: float = selected["pitch"]
		var duration: float = stream.get_length() / pitch
		var stop: float = opts.get("duration", entry.get("duration", -1.0))
		if stop >= 0.0: duration = minf(duration, stop)
		row.merge({"slot": voice.get_instance_id(), "start": changed, "gain": selected["gain"],
			"pitch": pitch, "duration_ms": duration * 1000.0, "loop": loop,
			"loop_fade_ms": bank.CROSSFADE_SECONDS * 1000.0 / Engine.time_scale,
			"variant": selected["sample_index"], "path": original.resource_path,
			"cut_ms": bank.last_play["alignment"].get("stream_offset_ms", 0.0)})
	_write(row)

func stop_voice(player: AudioStreamPlayer) -> void:
	_write({"stop_slot": player.get_instance_id(), "ms": _millis()})

func fade_loop(bank: Node) -> void:
	_loop_id = ""
	_write({"fade_bank": bank.get_instance_id(), "ms": _millis(),
		"loop_fade_ms": bank.CROSSFADE_SECONDS * 1000.0 / Engine.time_scale})

func _write(row: Dictionary) -> void:
	file.store_line(JSON.stringify(row))

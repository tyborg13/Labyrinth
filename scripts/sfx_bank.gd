extends Node
class_name SfxBank

const PeakAlignment = preload("res://scripts/sfx_peak_alignment.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Attacks = preload("res://scripts/attack_sfx_library.gd")
const Runs = preload("res://scripts/run_sfx_library.gd")
const DATA_PATH: String = "res://data/sfx_cues.json"
const CROSSFADE_SECONDS: float = 0.6
# A fresh primary contact outranks its optional attenuated area layers. Equal
# priority voices steal the oldest; saturation never shifts an onset in time.
const PRIMARY_PRIORITY: int = 0
const AREA_PRIORITY: int = -1
const LEGACY_WARM_VOICES: int = 8
signal cue_requested(cue_id: String, result: String)

var data: Dictionary = {}
var cues: Dictionary = {}
var players: Array = []
var active_loop_id: String = ""
var _loops: Array = []
var _loop_targets: Array[float] = []
var _loop_starts: Array[float] = []
var _fade_elapsed: float = CROSSFADE_SECONDS
var _loop_cursor: int = 0
var _serial: int = 0
var _peak_pending: Array[Dictionary]
var last_play: Dictionary = {}
var last_request: Dictionary = {}
var _clock_ms: float = -1.0
var presentation_clock: Callable
var _host: Node
var _legacy_options: Dictionary = {"gain_db": 0.0, "duration": -1.0}
const EMPTY_OPTIONS: Dictionary = {}

func warm_up(host: Node = null, source: Dictionary = {}, seed_value: int = -1) -> void:
	if not cues.is_empty(): return
	_host = host if host != null else self
	Settings.ensure_audio_buses()
	data = source if not source.is_empty() else JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	for cue_id: String in data.get("cues", {}):
		_compile(cue_id, data["cues"][cue_id], seed_value)
	for cue: String in cues:
		if bool(cues[cue]["entry"].get("sync_warm_up", false)):
			for stream: AudioStream in cues[cue]["streams"]: PeakAlignment.decoded(stream)
	for index: int in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "AmbientSfxPlayer" if index == 0 else "AmbientSfxCrossfadePlayer"
		_host.add_child(player)
		_loops.append(player)
		_loop_targets.append(0.0)
		_loop_starts.append(0.0)

func _source_entry(cue_id: String, visited: Dictionary = {}) -> Dictionary:
	if visited.has(cue_id): return {}
	visited[cue_id] = true
	var entry: Dictionary = data.get("cues", {}).get(cue_id, {})
	if entry.has("variants_from"):
		return _source_entry(str(entry["variants_from"]), visited)
	return entry

func _compile(cue_id: String, entry: Dictionary, seed_value: int) -> void:
	var source: Dictionary = _source_entry(cue_id)
	if source.is_empty(): source = entry
	var paths: Array = source.get("variants", [])
	var fallback: bool = paths.is_empty()
	if fallback: paths = source.get("fallback", [])
	var streams: Array = []
	for path: String in paths:
		var stream: AudioStream = Assets.load_audio_stream(path)
		if stream != null and bool(entry.get("loop", false)):
			stream = Assets.looping_audio_copy(stream)
			if stream is AudioStreamOggVorbis: (stream as AudioStreamOggVorbis).loop = true
		if stream != null: streams.append(stream)
	var rng := RandomNumberGenerator.new()
	if seed_value >= 0: rng.seed = seed_value + cue_id.hash()
	else: rng.randomize()
	var voices: Array = []
	if not bool(entry.get("loop", false)) and not streams.is_empty():
		for index: int in range(maxi(1, int(entry.get("max_voices", 1)))):
			var player := AudioStreamPlayer.new()
			player.name = "SfxPlayer%d" % players.size()
			player.bus = bus_for(str(entry.get("bus", "World")))
			player.set_meta("play_generation", 0)
			player.set_meta("serial", -1)
			player.set_meta("until", 0)
			player.set_meta("priority", PRIMARY_PRIORITY)
			_host.add_child(player)
			players.append(player)
			voices.append(player)
	var fallback_db: float = float(entry.get("volume_db", 0.0))
	if fallback and not paths.is_empty(): fallback_db = _legacy_volume(str(paths[0]), fallback_db)
	cues[cue_id] = {"entry": entry, "streams": streams, "voices": voices, "rng": rng,
		"next": rng.randi_range(0, streams.size() - 1) if not streams.is_empty() else 0,
		"last_ms": -1000000, "fallback": fallback, "fallback_db": fallback_db,
		"requests": 0, "silent": 0, "played": 0, "suppressed": 0}

func _legacy_volume(path: String, default_db: float) -> float:
	for entry: Dictionary in Attacks.SFX.values():
		if str(entry.get("path", "")) == path: return float(entry["volume_db"])
	for entry: Dictionary in Runs.SFX.values():
		if str(entry.get("path", "")) == path: return float(entry["volume_db"])
	# Board pickups reuse today's item equip level.
	if path == "res://assets/audio/sfx/item_equip.wav": return -1.0
	return default_db

func set_test_clock(milliseconds: float) -> void:
	_clock_ms = milliseconds

func now_ms() -> int:
	return int(_clock_ms) if _clock_ms >= 0 else Time.get_ticks_msec()

func _precise_ms() -> float:
	return _clock_ms if _clock_ms >= 0 else float(Time.get_ticks_usec()) / 1000.0

func presentation_ms() -> float:
	return float(presentation_clock.call()) / 1000.0 if presentation_clock.is_valid() else _precise_ms()

func _presentation_active() -> bool:
	return Engine.time_scale > 0.0 and (not is_inside_tree() or not get_tree().paused)

func frame_id() -> int:
	return int(_clock_ms) if _clock_ms >= 0 else Engine.get_process_frames()

func play(cue_id: String, opts: Dictionary = EMPTY_OPTIONS) -> float:
	if cues.is_empty(): warm_up()
	cue_id = Attacks.CUE_ALIASES.get(cue_id, Runs.CUE_ALIASES.get(cue_id, cue_id))
	if not cues.has(cue_id):
		_report_request(cue_id, opts, "unknown")
		return 0.0
	var state: Dictionary = cues[cue_id]
	var entry: Dictionary = state["entry"]
	if bool(entry.get("sync_contact_alignment", false)) and not opts.has("peak_climax_ms") and not opts.has("peak_deadline_ms"):
		opts = opts.duplicate()
		opts["peak_deadline_ms"] = presentation_ms()
	state["requests"] += 1
	var now: int = now_ms()
	if not bool(opts.get("area_instance", false)) and now - int(state["last_ms"]) < int(entry.get("cooldown_ms", 0)):
		state["suppressed"] += 1
		_report_request(cue_id, opts, "cooldown")
		return 0.0
	var streams: Array = state["streams"]
	if streams.is_empty():
		state["silent"] += 1
		_report_request(cue_id, opts, "silent")
		if bool(entry.get("loop", false)): stop_loop()
		return 0.0
	var resource: AudioStream = streams[int(state["next"])]
	state["next"] = (int(state["next"]) + 1) % streams.size()
	var gain: float = float(state["fallback_db"] if state["fallback"] else entry.get("volume_db", 0.0)) + float(opts.get("gain_db", 0.0))
	var rng: RandomNumberGenerator = state["rng"]
	var jitter: float = float(entry.get("pitch_jitter", 0.0))
	var pitch: float = float(entry.get("pitch_scale", 1.0)) * (1.0 + rng.randf_range(-jitter, jitter))
	var selected: Dictionary = {"resource": resource, "pitch": pitch, "gain": gain, "sample_index": posmod(int(state["next"]) - 1, streams.size())}
	if opts.has("peak_deadline_ms"):
		# Set by the actual climax submission, never an estimated future frame.
		# Dispatch in this same process tick when already due: deferring to this
		# node's next callback could add a full 30 fps frame to the minimum lead.
		selected["alignment"] = PeakAlignment.plan(resource, pitch, 0.0)
		selected["presentation_deadline_ms"] = float(opts["peak_deadline_ms"])
		_peak_pending.append({"cue": cue_id, "selected": selected, "opts": opts.duplicate()})
		_dispatch_presentation_deadlines()
		return float(selected.get("played_duration", resource.get_length() / pitch))
	if opts.has("peak_climax_ms"):
		var alignment: Dictionary = PeakAlignment.plan(resource, pitch, float(opts["peak_climax_ms"]))
		selected["alignment"] = alignment
		selected["due_ms"] = now + float(alignment["delay_ms"])
		selected["remaining_ms"] = float(alignment["delay_ms"])
		selected["last_advance_ms"] = _precise_ms()
		if float(alignment["delay_ms"]) > 0.0:
			_peak_pending.append({"cue": cue_id, "selected": selected, "opts": opts.duplicate()})
			return resource.get_length() / pitch + float(alignment["delay_ms"]) / 1000.0
	return _start_selected(cue_id, selected, opts)

func _report_request(cue_id: String, opts: Dictionary, result: String) -> void:
	var state: Dictionary = cues.get(cue_id, {})
	last_request = {"role": "optional_layer" if bool(opts.get("area_instance", false)) else "primary",
		"cooldown_ms": int(state.get("entry", {}).get("cooldown_ms", 0)),
		"since_success_ms": now_ms() - int(state.get("last_ms", -1000000))}
	cue_requested.emit(cue_id, result)

func _start_selected(cue_id: String, selected: Dictionary, opts: Dictionary) -> float:
	var state: Dictionary = cues[cue_id]
	var entry: Dictionary = state["entry"]
	var now: int = now_ms()
	if (selected.has("due_ms") or selected.has("presentation_deadline_ms")) and not bool(opts.get("area_instance", false)) and now - int(state["last_ms"]) < int(entry.get("cooldown_ms", 0)):
		state["suppressed"] += 1
		_report_request(cue_id, opts, "cooldown")
		return 0.0
	var resource: AudioStream = selected["resource"]
	var pitch: float = selected["pitch"]
	var gain: float = selected["gain"]
	var alignment: Dictionary = selected.get("alignment", {}).duplicate()
	if bool(entry.get("loop", false)):
		_start_loop(cue_id, resource, gain, pitch)
	else:
		var priority: int = AREA_PRIORITY if bool(opts.get("area_instance", false)) else PRIMARY_PRIORITY
		var player: AudioStreamPlayer = _voice(state["voices"], now, priority)
		if player == null:
			state["suppressed"] += 1
			_report_request(cue_id, opts, "priority")
			return 0.0
		if not alignment.is_empty():
			# Compensate a scheduler tick's overshoot without moving the target peak.
			var skip: float = float(alignment["skip_ms"]) + float(selected.get("late_ms", 0.0)) * pitch
			var trimmed: Dictionary = PeakAlignment.trimmed(resource, pitch, skip)
			resource = trimmed["stream"]
			alignment.merge(trimmed)
			alignment["late_ms"] = float(selected.get("late_ms", 0.0))
			alignment["requested_skip_ms"] = skip
			alignment.erase("stream")
		player.stop()
		player.stream = resource
		player.bus = bus_for(str(entry.get("bus", "World")))
		player.volume_db = gain
		player.pitch_scale = pitch
		_serial += 1
		player.set_meta("serial", _serial)
		player.set_meta("priority", priority)
		var stop_seconds: float = float(opts.get("duration", entry.get("duration", -1.0)))
		if stop_seconds < 0.0: stop_seconds = resource.get_length() / pitch
		player.set_meta("until", now + int(stop_seconds * 1000.0))
		player.set_meta("sfx_id", cue_id)
		player.set_meta("play_generation", int(player.get_meta("play_generation", 0)) + 1)
		if player.is_inside_tree(): player.play()
	last_play = {"cue": cue_id, "selected": selected, "alignment": alignment, "stream": resource}
	state["last_ms"] = now
	state["played"] += 1
	_report_request(cue_id, opts, "played")
	return resource.get_length() / pitch

static func bus_for(bus: String) -> String:
	if bus == "World": return Settings.WORLD_SFX_BUS
	if bus == "UI": return Settings.UI_SFX_BUS
	return bus

func _voice(voices: Array, now: int, priority: int = PRIMARY_PRIORITY) -> AudioStreamPlayer:
	var oldest: AudioStreamPlayer = voices[0]
	for player: AudioStreamPlayer in voices:
		if int(player.get_meta("until", 0)) <= now: return player
		var player_priority: int = int(player.get_meta("priority", PRIMARY_PRIORITY))
		var oldest_priority: int = int(oldest.get_meta("priority", PRIMARY_PRIORITY))
		if player_priority < oldest_priority or (player_priority == oldest_priority and int(player.get_meta("serial", -1)) < int(oldest.get_meta("serial", -1))): oldest = player
	if int(oldest.get_meta("priority", PRIMARY_PRIORITY)) > priority: return null
	return oldest

func prepare_legacy(entries: Array) -> void:
	for cue_id: String in Runs.SFX:
		var entry: Dictionary = Runs.entry(cue_id)
		_register_legacy(entry)
	for entry: Dictionary in entries: _register_legacy(entry)

func _register_legacy(entry: Dictionary) -> String:
	var cue_id: String = str(entry.get("id", ""))
	if Attacks.CUE_ALIASES.has(cue_id) or Runs.CUE_ALIASES.has(cue_id) or cues.has(cue_id): return cue_id
	var path: String = str(entry.get("path", ""))
	if path.is_empty(): return ""
	if cue_id.is_empty(): cue_id = "legacy:" + path
	if not cues.has(cue_id):
		var resource: AudioStream = Assets.load_audio_stream(path)
		if resource == null: return ""
		var compiled: Dictionary = entry.duplicate()
		compiled["fallback"] = [path]
		compiled["max_voices"] = LEGACY_WARM_VOICES
		compiled["pitch_jitter"] = float(entry.get("pitch_variance", 0.035 if resource.get_length() <= 1.25 else 0.0))
		_compile(cue_id, compiled, -1)
	return cue_id

func play_entry(entry: Dictionary) -> float:
	var cue_id: String = _register_legacy(entry)
	if cue_id.is_empty(): return 0.0
	if Attacks.CUE_ALIASES.has(cue_id) or Runs.CUE_ALIASES.has(cue_id) or data.get("cues", {}).has(cue_id): return play(cue_id)
	# The same approved file can have different authored gains at legacy moments.
	# Keep those per-call levels while sharing its warmed stream and voice pool.
	_legacy_options["gain_db"] = float(entry.get("volume_db", 0.0)) - float(cues[cue_id]["fallback_db"])
	_legacy_options["duration"] = float(entry.get("duration", -1.0))
	return play(cue_id, _legacy_options)

func schedule_area(cue_id: String, _delay_ms: int, gain_db: float) -> void:
	# Compatibility entry point. An area contact owns its visual frame; the old
	# 35/70 ms queue violated sfx-04 even when every target flashed together.
	play(cue_id, {"gain_db": gain_db, "area_instance": true})

func _process(delta: float) -> void:
	advance(delta)

func _dispatch_presentation_deadlines() -> void:
	if not _presentation_active(): return
	var now: float = presentation_ms()
	var due: Array[Dictionary]
	for pending: Dictionary in _peak_pending:
		var selected: Dictionary = pending["selected"]
		if selected.has("presentation_deadline_ms") and now >= float(selected["presentation_deadline_ms"]):
			selected["late_ms"] = (now - float(selected["presentation_deadline_ms"])) / Engine.time_scale
			due.append(pending)
	for pending: Dictionary in due:
		_peak_pending.erase(pending)
		pending["selected"]["played_duration"] = _start_selected(pending["cue"], pending["selected"], pending["opts"])

func advance(delta: float) -> void:
	_dispatch_presentation_deadlines()
	var due: Array[Dictionary]
	# _process is paused with the scene. Hit-stop supplies zero visual delta;
	# neither case consumes the active wall-time delay or catches up on resume.
	var active: bool = Engine.time_scale > 0.0 and (not is_inside_tree() or not get_tree().paused)
	var clock: float = _precise_ms()
	for pending: Dictionary in _peak_pending:
		var selected: Dictionary = pending["selected"]
		if selected.has("presentation_deadline_ms"): continue
		if active:
			# A request can arrive before this node's process callback. Do not
			# charge it time from the preceding frame. Clamp resumed wall time
			# to the active delta so a paused interval cannot release the cue.
			var elapsed: float = minf(maxf(0.0, clock - float(selected["last_advance_ms"])), delta * 1000.0 / Engine.time_scale)
			selected["remaining_ms"] -= elapsed
			if float(selected["remaining_ms"]) <= 0.0:
				selected["late_ms"] = -float(selected["remaining_ms"])
				due.append(pending)
		selected["last_advance_ms"] = clock
	for pending: Dictionary in due:
		_peak_pending.erase(pending)
		_start_selected(pending["cue"], pending["selected"], pending["opts"])
	for player: AudioStreamPlayer in players:
		if player.stream != null and now_ms() >= int(player.get_meta("until", 0)):
			player.stop()
			player.stream = null
	_fade_elapsed = minf(CROSSFADE_SECONDS, _fade_elapsed + delta)
	for index: int in range(_loops.size()):
		var player: AudioStreamPlayer = _loops[index]
		player.volume_linear = lerpf(_loop_starts[index], _loop_targets[index], _fade_elapsed / CROSSFADE_SECONDS)
		if _fade_elapsed >= CROSSFADE_SECONDS and _loop_targets[index] == 0.0:
			player.stop()
			player.stream = null

func _start_loop(cue_id: String, resource: AudioStream, gain: float, pitch: float) -> void:
	if cue_id == active_loop_id: return
	active_loop_id = cue_id
	_loop_cursor = 1 - _loop_cursor
	for index: int in range(_loops.size()):
		_loop_starts[index] = (_loops[index] as AudioStreamPlayer).volume_linear if (_loops[index] as AudioStreamPlayer).stream != null else 0.0
		_loop_targets[index] = db_to_linear(gain) if index == _loop_cursor else 0.0
	var player: AudioStreamPlayer = _loops[_loop_cursor]
	player.stop()
	player.stream = resource
	player.bus = bus_for(str(cues[cue_id]["entry"].get("bus", "World")))
	player.pitch_scale = pitch
	player.volume_linear = 0.0
	_loop_starts[_loop_cursor] = 0.0
	if player.is_inside_tree(): player.play()
	_fade_elapsed = 0.0

func stop_loop(immediate: bool = false) -> void:
	active_loop_id = ""
	for index: int in range(_loops.size()):
		_loop_starts[index] = (_loops[index] as AudioStreamPlayer).volume_linear
		_loop_targets[index] = 0.0
	_fade_elapsed = 0.0
	if immediate: advance(CROSSFADE_SECONDS)

func active_loop_player() -> AudioStreamPlayer:
	return _loops[_loop_cursor] if not _loops.is_empty() else null

# Preserve the legacy observable hall identity while the same hall asset is
# audible. Biome identity remains active_loop_id for routing and crossfades.
func audible_loop_id() -> String:
	if active_loop_id.begins_with("ambience.") and cues[active_loop_id]["fallback"]:
		var source: Dictionary = _source_entry(active_loop_id)
		if source.get("fallback", []).has(Runs.SFX[Runs.DUNGEON_AMBIENCE_ID]["path"]): return Runs.DUNGEON_AMBIENCE_ID
	return active_loop_id

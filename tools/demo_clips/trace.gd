extends RefCounted

const Alignment = preload("res://scripts/sfx_peak_alignment.gd")
var clock: RefCounted
var bank: Node
var directory: String
var active: bool = false
var events: Array[Dictionary]
var frames: Array[Dictionary]
var pending: Dictionary

func observe(state: Dictionary, shown: Dictionary) -> void:
	if not active: return
	var units: Array = [state.get("player", {})]
	units.append_array(state.get("enemies", []))
	var actors: Dictionary = {}
	for unit: Dictionary in units:
		var key: String = "enemy_%d" % int(unit["id"]) if unit.has("id") else "player"
		var values: Dictionary = {}
		for field: String in ["hp", "block", "stoneskin", "bleed", "freeze", "shock", "pos", "intent"]:
			values[field] = unit.get(field)
		actors[key] = values
	# Last board submission wins within a movie frame. Do not call an effect
	# function, re-render a hit, or infer contact from the sound's own deadline.
	pending = {"frame": clock.frame, "actors": actors, "effect": shown.get("effect", {}), "progress": shown.get("effect_progress", 0.0),
		"impacts": shown.get("impact_actor_keys", []), "traps": shown.get("trap_effects", []),
		"surfaces": shown.get("surface_feedback_events", []), "terrain": state.get("terrain", [])}

func flush() -> void:
	if not pending.is_empty():
		frames.append(_without_analytics(pending))
		pending.clear()

func cue(cue_id: String, result: String) -> void:
	if not active: return
	var row: Dictionary = {"kind": "cue", "cue": cue_id, "result": result, "frame": clock.frame}
	if result == "played" and bank.last_play.get("cue", "") == cue_id:
		var played: Dictionary = bank.last_play
		var selected: Dictionary = played["selected"]
		row["pitch"] = selected["pitch"]
		row["gain_db"] = selected["gain"]
		row["sample_index"] = selected["sample_index"]
		row["alignment"] = played["alignment"].duplicate(true)
		row["duration_s"] = played["stream"].get_length() / float(row["pitch"])
		if not cue_id.begins_with("ambience."):
			var pcm: Dictionary = Alignment.decoded(played["stream"])
			var wav := AudioStreamWAV.new()
			wav.format = AudioStreamWAV.FORMAT_16_BITS
			wav.stereo = true
			wav.mix_rate = pcm["rate"]
			wav.data = pcm["bytes"]
			row["pcm"] = "cue-%04d.wav" % events.size()
			wav.save_to_wav(directory.path_join(row["pcm"]))
	events.append(row)

func mark(kind: String, fields: Dictionary = {}) -> void:
	var row: Dictionary = fields.duplicate(true)
	# Analytics stays enabled and unmodified in the game. Its per-process run
	# identity belongs in the original JSONL, not in the deterministic demo log.
	if row.has("state"): row["state"] = _without_analytics(row["state"])
	row["kind"] = kind
	row["frame"] = clock.frame
	events.append(row)

func _without_analytics(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			if str(key) != "analytics": result[key] = _without_analytics(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(_without_analytics(item))
		return result
	return value

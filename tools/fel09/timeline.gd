extends RefCounted
## Monotonic wall timestamps. Hooks describe submissions, and the frame sampler
## describes the presentation that survived through the rendered boundary.

var origin_usec: int = 0
var events: Array[Dictionary]
var steps: Array[Dictionary]
var spans: Dictionary = {}
var step: int = -1
var actor: String = ""
var phase: String = ""


func now_ms() -> float:
	return (Time.get_ticks_usec() - origin_usec) / 1000.0


func active() -> bool:
	return origin_usec > 0


func mark(kind: String, source: String, details: Dictionary = {}, at: float = -1.0) -> void:
	var row: Dictionary = _row(kind, source, details, at)
	row["end_ms"] = row["start_ms"]
	events.append(row)


func begin(kind: String, id: String, source: String, details: Dictionary = {}, at: float = -1.0) -> void:
	if spans.has(id): return
	var row: Dictionary = _row(kind, source, details, at)
	spans[id] = row
	events.append(row)


func end(id: String, at: float = -1.0, clipped: bool = false) -> void:
	if not spans.has(id): return
	var row: Dictionary = spans[id]
	row["end_ms"] = now_ms() if at < 0.0 else at
	if clipped: row["clipped"] = true
	spans.erase(id)


func finish(at: float) -> void:
	for id: String in spans.keys(): end(id, at, true)


func _row(kind: String, source: String, details: Dictionary, at: float) -> Dictionary:
	return {
		"type": kind, "source": source, "details": details, "step": step, "actor": actor,
		"start_ms": now_ms() if at < 0.0 else at,
	}


func begin_step(data: Dictionary, counts_as_action: bool) -> void:
	step = steps.size()
	actor = str(data.get("source_actor_key", data.get("actor_key", "")))
	var kind: String = str(data.get("kind", ""))
	var row: Dictionary = {
		"step": step, "actor": actor, "kind": kind, "action": counts_as_action,
		"label": str(data.get("label", data.get("intent_name", ""))),
		"intent": str(data.get("intent_id", "")), "hidden": bool(data.get("hidden_by_umbra", false)),
		"geometry": var_to_str([data.get("from"), data.get("to"), data.get("tile"), data.get("tiles", []), data.get("path", [])]),
		"dispatch_ms": now_ms(),
	}
	steps.append(row)
	mark("step dispatched", "combat_pacing.gd:400", {"kind": kind, "label": row["label"]})


func start_action() -> void:
	var row: Dictionary = steps[step]
	if not row["action"]: return
	row["start_ms"] = now_ms()
	begin("action", "action:%d" % step, "combat_pacing.gd:400", {"kind": row["kind"], "label": row["label"]})


func end_action(index: int) -> void:
	if index < 0: return
	var row: Dictionary = steps[index]
	if not row.has("start_ms") or row.has("end_ms"): return
	row["end_ms"] = now_ms()
	end("action:%d" % index, row["end_ms"])


func measure_intervals() -> void:
	# Derived measurements keep their own spans so both reports use the same
	# populations and carry the same action/actor attribution.
	var raw: Array[Dictionary]
	raw.assign(events)
	raw.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["start_ms"] < b["start_ms"])
	for beat: Dictionary in raw:
		if beat["type"] == "caption shown":
			_caption_lead(beat, raw)
		elif beat["type"] == "contact":
			_contact_intervals(beat, raw)


func _caption_lead(caption: Dictionary, raw: Array[Dictionary]) -> void:
	for beat: Dictionary in raw:
		if beat["start_ms"] > caption["end_ms"]: return
		if beat["actor"] != caption["actor"] or beat["start_ms"] < caption["start_ms"]: continue
		if beat["type"] in ["unit move", "attack wind-up", "surface effect", "number on screen"]:
			_interval("caption lead before motion or feedback", caption, caption["start_ms"], beat["start_ms"])
			return


func _contact_intervals(contact: Dictionary, raw: Array[Dictionary]) -> void:
	var windup: float = -1.0
	var last_number: float = -1.0
	var clipped: bool = false
	var hit: float = contact["start_ms"]
	for beat: Dictionary in raw:
		if beat["step"] != contact["step"]: continue
		if beat["type"] == "attack wind-up" and beat["start_ms"] <= hit:
			windup = beat["start_ms"]
		if beat["type"] == "number on screen" and beat["end_ms"] >= hit:
			last_number = maxf(last_number, beat["end_ms"])
			clipped = clipped or beat.get("clipped", false)
	if windup >= 0.0: _interval("wind-up to contact", contact, windup, hit)
	if last_number >= 0.0 and not clipped: _interval("contact to last number gone", contact, hit, last_number)


func _interval(kind: String, parent: Dictionary, start: float, stop: float) -> void:
	events.append({
		"type": kind, "source": parent["source"], "details": {"derived": true}, "step": parent["step"],
		"actor": parent["actor"], "start_ms": start, "end_ms": stop,
	})

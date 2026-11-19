extends RefCounted
## Opt-in exclusive section timings, outside combat state and save receipts.

const ENVIRONMENT: String = "LABYRINTH_PROFILE_BOSS_INTENT"
static var enabled: bool = OS.is_debug_build() and OS.get_environment(ENVIRONMENT) == "1"

var _rows: Dictionary = {}
var _sample: Dictionary = {}
var _slowest_by_intent: Dictionary = {}
var _sections: Array[String]
var _elapsed: Array[int]
var _started: int
var _roll_started: int

func begin_roll() -> void:
	_sample = {}
	_roll_started = Time.get_ticks_usec()
	begin("roll_overhead")

func finish_roll(intent_id: String) -> void:
	end()
	var usec: int = Time.get_ticks_usec() - _roll_started
	var previous: Dictionary = _slowest_by_intent.get(intent_id, {})
	if usec > int(previous.get("usec", 0)):
		_slowest_by_intent[intent_id] = {"usec": usec, "exclusive_usec": _sample}

func active() -> bool:
	return not _sections.is_empty()

func begin(section: String) -> void:
	var now: int = Time.get_ticks_usec()
	if not _elapsed.is_empty(): _elapsed[-1] += now - _started
	_sections.append(section)
	_elapsed.append(0)
	_started = now

func end() -> void:
	var now: int = Time.get_ticks_usec()
	var section: String = _sections.pop_back()
	var usec: int = _elapsed.pop_back() + now - _started
	var row: Dictionary = _rows.get_or_add(section, {"count": 0, "total_usec": 0, "max_usec": 0})
	row["count"] += 1
	row["total_usec"] += usec
	row["max_usec"] = maxi(row["max_usec"], usec)
	_sample[section] = int(_sample.get(section, 0)) + usec
	_started = Time.get_ticks_usec()

func snapshot() -> Dictionary:
	return {"exclusive_sections": _rows.duplicate(true), "slowest_by_intent": _slowest_by_intent.duplicate(true)}

extends RefCounted
## The displayed board keeps its announced footprints. Pass supplies only the
## hero-tile contacts from its existing simulation.
## Sequential anchor and death receipts remain available to plates.

const Repeats = preload("res://scripts/pass_forecast_repeats.gd")
const Areas = preload("res://scripts/boss_area_rules.gd")
const HIT_PHASE: String = "pass_forecast_red_hits"
const RULE_KEY: String = "battlefield_rule"
const FOE_SURFACE_KEY: String = "foe_surface"
const FLOOR_KEY: String = "floor_threats"
const BEAT_RECEIPT: String = "_pass_forecast_red_beat_tiles"

# Keep only the first activation's anchor. Even an identical later cast can
# have a different anchor, for example if another foe moved the caster.
static func note(engine: RefCounted, cursor: Dictionary, enemy: Dictionary, after: Dictionary) -> void:
	if not bool(cursor.get("losses_only", false)): return
	var id: int = int(enemy["id"])
	if int((cursor.get("enemy_activations", {}) as Dictionary).get(id, 0)) != 1: return
	var started: int = Time.get_ticks_usec() if engine._runtime_performance_instrumentation_enabled else 0
	var key: String = "enemy_%d" % id
	var records: Dictionary = after.get(Areas.FORECAST_RECEIPT, {})
	var stamp: Dictionary = records.get(key, {})
	if not stamp.is_empty() and stamp["signature"] == Areas.forecast_signature(enemy.get("intent", {})):
		var announced: Dictionary = cursor.get("red_announced_areas", {})
		announced[key] = stamp
		cursor["red_announced_areas"] = announced
	var index: int = engine._enemy_index_for_id(after, id)
	var alive: bool = index >= 0 and int(((after.get("enemies", []) as Array)[index] as Dictionary).get("hp", 0)) > 0
	if not alive and not (cursor.get("enemy_hits", {}) as Dictionary).has(id):
		var died: Dictionary = cursor.get("red_died_first", {})
		died[id] = true
		cursor["red_died_first"] = died
	engine._record_runtime_performance_phase("pass_forecast_red_tiles", started)

# A foe visible at the forecast's start that never got to act and is gone by the
# hero's next turn died first as well (killed before its own turn came).
static func result_fields(engine: RefCounted, cursor: Dictionary) -> Dictionary:
	var died: Dictionary = (cursor.get("red_died_first", {}) as Dictionary).duplicate()
	var state: Dictionary = cursor.get("state", {})
	var activations: Dictionary = cursor.get("enemy_activations", {})
	if bool(cursor.get("losses_only", false)) and bool(cursor.get("complete", false)) and not state.is_empty():
		for id: int in cursor.get("initially_visible_enemy_ids", {}):
			if activations.has(id): continue
			var index: int = engine._enemy_index_for_id(state, id)
			if index < 0 or int(((state.get("enemies", []) as Array)[index] as Dictionary).get("hp", 0)) <= 0: died[id] = true
	return {"red_died_first": died, "red_relative_areas": cursor.get("red_announced_areas", {}),
		"red_beat_tiles": state.get(BEAT_RECEIPT, {}),
		"red_turn_start_surfaces": cursor.get("red_turn_start_surfaces", [])}

# --- atk-11: what strikes the hero's tile itself -----------------------------------

# Private forecast marker for the shared attack resolver's Chain receipts.
const FORECAST_MARKER: String = "_pass_forecast_marked"

static func schedule(engine: RefCounted, source: Dictionary, accepted: Callable = Callable()) -> Dictionary:
	var started: int = Time.get_ticks_usec() if engine._runtime_performance_instrumentation_enabled else 0
	var marked: Dictionary = source.duplicate(false)
	marked[FORECAST_MARKER] = true
	marked[Areas.FORECAST_RECEIPT] = source.get(Areas.FORECAST_RECEIPT, {}).duplicate(true)
	preload("res://scripts/pass_forecast_statuses.gd").begin(marked)
	engine._record_runtime_performance_phase(HIT_PHASE, started)
	if not accepted.is_valid(): accepted = preload("res://scripts/battlefield_rules/committed.gd").callback(engine)
	return engine.finish_player_activation(marked, preload("res://scripts/pass_forecast_statuses.gd").callback(engine, accepted))

static func hurt(before: Array, after: Array) -> bool:
	return after[0] < before[0] or after[1] < before[1] or after[2] < before[2] or after[3] > before[3] or after[4] < before[4]

static func note_beat(engine: RefCounted, before: Dictionary, after: Dictionary) -> void:
	if not before.has(FORECAST_MARKER): return
	var started: int = Time.get_ticks_usec() if engine._runtime_performance_instrumentation_enabled else 0
	if hurt(Repeats.hero_mark(before), Repeats.hero_mark(after)):
		var tiles: Dictionary = after.get(BEAT_RECEIPT, {})
		tiles[before["player"]["pos"]] = true
		after[BEAT_RECEIPT] = tiles
	engine._record_runtime_performance_phase(HIT_PHASE, started)

# The contact boundary excludes draw/Fatigue, status ticks and Meteorfall. Keep
# every contact in a Freeze-extended span, rather than overwriting an earlier hit.
static func before_turn_start_contact(engine: RefCounted, state: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec() if engine._runtime_performance_instrumentation_enabled else 0
	var tile: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1))
	var result: Dictionary = {"tile": tile, "mark": Repeats.hero_mark(state), "entry": engine.BoardSurfaceRules.surface_at(state, tile).duplicate(true)}
	engine._record_runtime_performance_phase(HIT_PHASE, started)
	return result

static func note_turn_start_surface(engine: RefCounted, cursor: Dictionary, contact: Dictionary, after: Dictionary) -> void:
	var started: int = Time.get_ticks_usec() if engine._runtime_performance_instrumentation_enabled else 0
	var entry: Dictionary = contact["entry"]
	if not str(entry.get("elemental", "")).is_empty() and hurt(contact["mark"], Repeats.hero_mark(after)):
		var contacts: Array = cursor.get("red_turn_start_surfaces", [])
		contacts.append({"tile": contact["tile"], "elemental": str(entry["elemental"]), "source": entry.get("elemental_source", {})})
		cursor["red_turn_start_surfaces"] = contacts
	engine._record_runtime_performance_phase(HIT_PHASE, started)

# Walking onto fire is a separate cost, outside this contact receipt. At turn
# start, a foe's ground still belongs to that foe even if it was laid earlier.
static func hero_owners(engine: RefCounted, _source: Dictionary, phase_result: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec() if engine._runtime_performance_instrumentation_enabled else 0
	var owners: Dictionary = {}
	for surface: Dictionary in phase_result.get("red_turn_start_surfaces", []):
		var laid: Dictionary = surface["source"]
		if str(laid.get("source_kind", "")) != RULE_KEY and str(laid.get("actor_kind", "")) == "enemy" and int(laid.get("actor_id", -1)) >= 0:
			owners["enemy_%d" % int(laid["actor_id"])] = true
	engine._record_runtime_performance_phase(HIT_PHASE, started)
	return owners


# Summary view, keyed like the rest badges ("enemy_<id>").
static func summary_fields(phase_result: Dictionary) -> Dictionary:
	var died: Dictionary = {}
	for id: int in phase_result.get("red_died_first", {}):
		died["enemy_%d" % id] = true
	return {"died_first_keys": died, "relative_red_areas": phase_result.get("red_relative_areas", {})}

# The full forecast records turn-start contacts separately from attack red.
static func hero_fields(engine: RefCounted, source: Dictionary, phase_result: Dictionary) -> Dictionary:
	var contacts: Dictionary = {}
	for tile: Vector2i in phase_result.get("red_beat_tiles", {}):
		contacts[tile] = {RULE_KEY: true}
	for surface: Dictionary in phase_result.get("red_turn_start_surfaces", []):
		var laid: Dictionary = surface["source"]
		var id: int = int(laid.get("actor_id", -1))
		var key: String
		if str(laid.get("source_kind", "")) == RULE_KEY:
			key = RULE_KEY
		elif str(laid.get("actor_kind", "")) == "enemy":
			var index: int = engine._enemy_index_for_id(source, id)
			var enemies: Array = source.get("enemies", [])
			key = "enemy_%d" % id if index >= 0 and engine.is_enemy_visible_to_player(source, enemies[index]) else FOE_SURFACE_KEY
		else:
			continue
		var owners: Dictionary = contacts.get_or_add(surface["tile"], {})
		owners[key] = true
	return {"hero_red_owners": hero_owners(engine, source, phase_result), "hero_red_contacts": contacts}

static func floor_override(rest: Dictionary, release_rest: Dictionary, marks: Dictionary) -> Variant:
	var first: Array = rest.get("threats", [])
	var hero: Vector2i = rest.get("hero_tile", Vector2i(-1, -1))
	var contacts: Dictionary = marks.get("hero_red_contacts", {}).get(hero, {})
	if contacts.is_empty():
		return null if first == release_rest.get("threats", []) else first
	var floor: Array = first.duplicate()
	for key: String in contacts:
		floor.append({"key": key, "tiles": [hero], "hero_hit": true, "rule_outline": key == RULE_KEY})
	return floor

static func floor_rows(presentation: Dictionary) -> Array:
	var rest: Dictionary = presentation.get("threats_at_rest", {})
	return presentation.get(FLOOR_KEY, rest.get("threats", []))

static func adjust_from_summary(rest: Dictionary, summary: Dictionary) -> Dictionary:
	var died_first: Dictionary = summary.get("died_first_keys", {})
	var relative_areas: Dictionary = summary.get("relative_red_areas", {})
	if died_first.is_empty() and relative_areas.is_empty(): return rest
	var threats: Array[Dictionary]
	for threat: Dictionary in rest.get("threats", []):
		var key: String = str(threat.get("key", ""))
		if not bool(threat.get("area_announced", threat.get("area_fixed", false))) and died_first.has(key): continue
		var resolved: Dictionary = relative_areas.get(key, {})
		var signature: Array = threat.get("area_signature", [])
		if not signature.is_empty() and resolved.get("signature", []) == signature:
			threat = threat.duplicate(false)
			threat["tiles"] = (resolved["tiles"] as Array).duplicate()
			threat["area_forecast_anchor"] = resolved["anchor"]
		threats.append(threat)
	var result: Dictionary = rest.duplicate(false)
	result["threats"] = threats
	return result

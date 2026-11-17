extends RefCounted
## atk-09 (director 2026-11-14): the red threat tiles agree with the forecast.
## A visible foe's first activation keeps the tiles its badge plan draws. Every
## later activation the PASS forecast resolves (second, third...) adds the tiles
## that foe's plan strikes on the forecast board at that moment. A foe the
## forecast has die before it acts (its own Bleed or Fire at its turn start, or
## anything else first) without hurting the hero loses its first-activation red,
## as its disc is already grey. Same paint: no new colour, mark, number or text.
##
## The PASS-loss cursor records while it plays (no new simulation); the rest red
## set reads the at-rest forecast's record, a hovered destination or card preview
## reads its own forecast's record once that forecast is ready. Presentation only.
##
## atk-11 (director 2026-11-14): the hero's own tile is red when that forecast has
## the hero lose Health, Block or Stoneskin to a battlefield rule beat (any kind:
## pushes, collisions, Upheaval; on a foe's turn or right after the hero's) or to a
## foe-laid surface that hurts the hero at their turn start. A beat
## is owned by "battlefield_rule"; a surface by the foe that laid it, else by the
## rule. Fatigue, the hero's own walk, ticks and other turn-end effects stay costs.

const Badges = preload("res://scripts/intent_badges.gd")
const Repeats = preload("res://scripts/pass_forecast_repeats.gd")
const RULE_KEY: String = "battlefield_rule"
const HIT_PHASE: String = "pass_forecast_red_hits"
# Marks that land after the hero's next turn strike nothing in that activation.
const TELEGRAPH_TYPES := ["lob_mark", "icefall_mark", "upheaval_mark", "cinder_marks", "burrow"]

# Cursor side: one resolved activation of a foe visible at the forecast's start
# (the PASS-loss copy only). `before` is the copy as the foe begins to act and
# `after` the copy once it has. Activations are already counted (Repeats.record).
static func note(engine: RefCounted, cursor: Dictionary, before: Dictionary, enemy_index: int, enemy_id: int, after: Dictionary) -> void:
	if not bool(cursor.get("losses_only", false)): return
	var started: int = Time.get_ticks_usec() if engine._runtime_performance_instrumentation_enabled else 0
	var count: int = int((cursor.get("enemy_activations", {}) as Dictionary).get(enemy_id, 0))
	if count <= 1:
		var index: int = engine._enemy_index_for_id(after, enemy_id)
		var alive: bool = index >= 0 and int(((after.get("enemies", []) as Array)[index] as Dictionary).get("hp", 0)) > 0
		if not alive and not (cursor.get("enemy_hits", {}) as Dictionary).has(enemy_id):
			var died: Dictionary = cursor.get("red_died_first", {})
			died[enemy_id] = true
			cursor["red_died_first"] = died
	else:
		var tiles: Array[Vector2i] = struck_tiles(engine, before, enemy_index)
		if not tiles.is_empty():
			var later: Dictionary = cursor.get("red_later_tiles", {})
			var known: Array = later.get(enemy_id, [])
			for tile: Vector2i in tiles:
				if not known.has(tile): known.append(tile)
			later[enemy_id] = known
			cursor["red_later_tiles"] = later
	engine._record_runtime_performance_phase("pass_forecast_red_tiles", started)

# The tiles a foe's attack plan strikes on this board, as the rest badges plan a
# first activation: attack intents only, nothing while Shocked or Frozen. A foe
# visible at the forecast's start keeps its plan past the hero's sight (atk-06).
static func struck_tiles(engine: RefCounted, state: Dictionary, enemy_index: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i]
	var enemies: Array = state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size(): return tiles
	var enemy: Dictionary = engine._normalized_enemy(enemies[enemy_index] as Dictionary)
	if int(enemy.get("hp", 0)) <= 0 or int(enemy.get("shock", 0)) > 0 or int(enemy.get("freeze", 0)) > 0: return tiles
	var primary: Dictionary = Badges.primary_action(enemy.get("intent", {}) as Dictionary)
	if not Badges.is_attack(primary) or TELEGRAPH_TYPES.has(str(primary.get("type", ""))): return tiles
	# The attack plan only (no Details reach), uncached: each forecast board is new,
	# and the shared plan cache serves the rest badges.
	tiles.assign(engine.enemy_planned_attack_tiles(state, enemy_index, not engine.is_enemy_visible_to_player(state, enemy)))
	return tiles

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
	return {"red_later_tiles": cursor.get("red_later_tiles", {}), "red_died_first": died,
		"red_beat_hit": bool(state.get(BEAT_RECEIPT, false)), "red_turn_start_surfaces": cursor.get("red_turn_start_surfaces", [])}

# --- atk-11: what strikes the hero's tile itself -----------------------------------

# Private receipt on the forecast copy only. The dispatcher observes its already
# resolved beat, including defense-only collisions; live/save/analytics state
# never carries this field. Scheduling uses the same resolver once, not a replay.
const BEAT_RECEIPT: String = "_pass_forecast_red_beat_hit"

static func schedule(engine: RefCounted, source: Dictionary, accepted: Callable = Callable()) -> Dictionary:
	var started: int = Time.get_ticks_usec() if engine._runtime_performance_instrumentation_enabled else 0
	var marked: Dictionary = source.duplicate(false)
	marked[BEAT_RECEIPT] = bool(source.get(BEAT_RECEIPT, false))
	preload("res://scripts/pass_forecast_statuses.gd").begin(marked)
	engine._record_runtime_performance_phase(HIT_PHASE, started)
	return engine.finish_player_activation(marked, preload("res://scripts/pass_forecast_statuses.gd").callback(engine, accepted))

static func note_beat(engine: RefCounted, before: Dictionary, after: Dictionary) -> void:
	if not after.has(BEAT_RECEIPT): return
	var started: int = Time.get_ticks_usec() if engine._runtime_performance_instrumentation_enabled else 0
	if hurt(Repeats.hero_mark(before), Repeats.hero_mark(after)):
		after[BEAT_RECEIPT] = true
	engine._record_runtime_performance_phase(HIT_PHASE, started)

static func hurt(before: Array, after: Array) -> bool:
	return after[0] < before[0] or after[1] < before[1] or after[2] < before[2] or after[3] > before[3] or after[4] < before[4]

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

# Summary owners use the original forecast source, even across skipped turns.
# Walking onto fire is a separate cost, outside this contact receipt. At turn
# start, a foe's ground still belongs to that foe even if it was laid earlier.
# Unattributed new ground falls back to the rule; old ambient ground stays a cost.
static func hero_owners(engine: RefCounted, source: Dictionary, phase_result: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec() if engine._runtime_performance_instrumentation_enabled else 0
	var owners: Dictionary = {}
	if bool(phase_result.get("red_beat_hit", false)): owners[RULE_KEY] = true
	for surface: Dictionary in phase_result.get("red_turn_start_surfaces", []):
		var laid: Dictionary = surface["source"]
		if str(laid.get("source_kind", "")) == "battlefield_rule": owners[RULE_KEY] = true
		elif str(laid.get("actor_kind", "")) == "enemy" and int(laid.get("actor_id", -1)) >= 0: owners["enemy_%d" % int(laid["actor_id"])] = true
		elif str(laid.get("actor_kind", "")) != "player":
			var earlier: Dictionary = engine.BoardSurfaceRules.surface_at(source, surface["tile"])
			if str(earlier.get("elemental", "")) != str(surface["elemental"]) or earlier.get("elemental_source", {}) != laid: owners[RULE_KEY] = true
	engine._record_runtime_performance_phase(HIT_PHASE, started)
	return owners


# Summary view, keyed like the rest badges ("enemy_<id>").
static func summary_fields(phase_result: Dictionary) -> Dictionary:
	var later: Dictionary = {}
	for id: int in phase_result.get("red_later_tiles", {}):
		later["enemy_%d" % id] = phase_result["red_later_tiles"][id]
	var died: Dictionary = {}
	for id: int in phase_result.get("red_died_first", {}):
		died["enemy_%d" % id] = true
	return {"later_red_tiles": later, "died_first_keys": died}

# Summary view of the hero's own tile (atk-11), needing the forecast's source.
static func hero_fields(engine: RefCounted, source: Dictionary, phase_result: Dictionary) -> Dictionary:
	return {"hero_red_owners": hero_owners(engine, source, phase_result)}

# --- presentation ------------------------------------------------------------------

# The rest set with a forecast's record applied. Idempotent: earlier added tiles
# are replaced. Only foes the set already shows a badge for (visible at the
# committed boundary) gain tiles; a foe that dies first keeps its badge. atk-11:
# hero_owners mark the set's hero tile, owned by the rule or by a visible foe.
static func adjust(rest: Dictionary, later: Dictionary, died_first: Dictionary, focus: String = "", hero_owners: Dictionary = {}) -> Dictionary:
	if later.is_empty() and died_first.is_empty() and hero_owners.is_empty() and not _has_later(rest): return rest
	var shown: Dictionary = {}
	for badge: Dictionary in rest.get("badges", []): shown[str(badge.get("key", ""))] = true
	var threats: Array[Dictionary]
	for threat: Dictionary in rest.get("threats", []):
		if bool(threat.get("later", false)) or died_first.has(str(threat.get("key", ""))): continue
		threats.append(threat)
	for key: String in later:
		if not shown.has(key) or died_first.has(key) or (later[key] as Array).is_empty(): continue
		var tiles: Array[Vector2i]
		tiles.assign(later[key])
		# No zone tag: an added activation carries no order number of its own.
		threats.append({"key": key, "tiles": tiles, "alpha": Badges.ISOLATED_ALPHA if not focus.is_empty() and focus != key else 1.0, "area": false, "order": "", "later": true})
	var hero: Vector2i = rest.get("hero_tile", Vector2i(-1, -1))
	for key: String in hero_owners:
		if hero.x < 0 or (key != RULE_KEY and not shown.has(key)): continue
		var tiles: Array[Vector2i]
		tiles.append(hero)
		threats.append({"key": key, "tiles": tiles, "alpha": Badges.ISOLATED_ALPHA if not focus.is_empty() and focus != key else 1.0, "area": false, "order": "", "later": true, "hero_hit": true})
	var result: Dictionary = rest.duplicate(false)
	result["threats"] = threats
	return result

static func adjust_from_summary(rest: Dictionary, summary: Dictionary, focus: String = "") -> Dictionary:
	return adjust(rest, summary.get("later_red_tiles", {}), summary.get("died_first_keys", {}), focus, summary.get("hero_red_owners", {}))

# Order-free identity of the foes' red tiles, for staleness checks.
static func signature(rest: Dictionary) -> Array:
	var result: Array = []
	for threat: Dictionary in rest.get("threats", []):
		var tiles: Array = (threat.get("tiles", []) as Array).map(func(tile: Vector2i) -> String: return str(tile))
		tiles.sort()
		result.append("%s|%s|%s|%s" % [threat.get("key", ""), bool(threat.get("later", false)), bool(threat.get("hero_hit", false)), ",".join(tiles)])
	result.sort()
	return result

static func _has_later(rest: Dictionary) -> bool:
	for threat: Dictionary in rest.get("threats", []):
		if bool(threat.get("later", false)): return true
	return false

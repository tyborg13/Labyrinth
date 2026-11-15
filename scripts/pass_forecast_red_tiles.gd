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

const Badges = preload("res://scripts/intent_badges.gd")
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
	return {"red_later_tiles": cursor.get("red_later_tiles", {}), "red_died_first": died}

# Summary view, keyed like the rest badges ("enemy_<id>").
static func summary_fields(phase_result: Dictionary) -> Dictionary:
	var later: Dictionary = {}
	for id: int in phase_result.get("red_later_tiles", {}):
		later["enemy_%d" % id] = phase_result["red_later_tiles"][id]
	var died: Dictionary = {}
	for id: int in phase_result.get("red_died_first", {}):
		died["enemy_%d" % id] = true
	return {"later_red_tiles": later, "died_first_keys": died}

# --- presentation ------------------------------------------------------------------

# The rest set with a forecast's record applied. Idempotent: earlier added tiles
# are replaced. Only foes the set already shows a badge for (visible at the
# committed boundary) gain tiles; a foe that dies first keeps its badge.
static func adjust(rest: Dictionary, later: Dictionary, died_first: Dictionary, focus: String = "") -> Dictionary:
	if later.is_empty() and died_first.is_empty() and not _has_later(rest): return rest
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
	var result: Dictionary = rest.duplicate(false)
	result["threats"] = threats
	return result

static func adjust_from_summary(rest: Dictionary, summary: Dictionary, focus: String = "") -> Dictionary:
	return adjust(rest, summary.get("later_red_tiles", {}), summary.get("died_first_keys", {}), focus)

# Does this forecast change any red tile of the set?
static func changes(summary: Dictionary) -> bool:
	return not (summary.get("later_red_tiles", {}) as Dictionary).is_empty() or not (summary.get("died_first_keys", {}) as Dictionary).is_empty()

# Order-free identity of the foes' red tiles, for staleness checks.
static func signature(rest: Dictionary) -> Array:
	var result: Array = []
	for threat: Dictionary in rest.get("threats", []):
		var tiles: Array = (threat.get("tiles", []) as Array).map(func(tile: Vector2i) -> String: return str(tile))
		tiles.sort()
		result.append("%s|%s|%s" % [threat.get("key", ""), bool(threat.get("later", false)), ",".join(tiles)])
	result.sort()
	return result

static func _has_later(rest: Dictionary) -> bool:
	for threat: Dictionary in rest.get("threats", []):
		if bool(threat.get("later", false)): return true
	return false

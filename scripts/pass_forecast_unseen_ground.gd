extends RefCounted
## atk-04 (director 2026-11-13): the forecast never says "Safe" when the Umbra
## could change the outcome. Forecasts play the enemy phase on the board the
## player can see; unseen terrain, traps and surfaces are left out
## (pass_forecast_action_source.gd information_state). Flag the forecast
## "unseen_ground_crossed" when any unit (a foe, a summon, the hero) enters or is
## forced onto a tile the player can't see, or an area effect targets an unseen
## tile next to a unit. Only the tiles' visibility is read, never their contents,
## so nothing leaks; the simulation itself is unchanged.
##
## The same sight also tells a visible new arrival (a summon or split) from a foe
## hidden in the Umbra: the panel names the first with the turn-clock "?".

# The decision-time sight (the committed board), carried by the forecast source.
const VISIBLE_KEY: String = "_pass_forecast_visible"
# The previewed action itself (a walk, a card's push) already crossed it.
const CROSSED_KEY: String = "_pass_forecast_unseen_crossed"
# Step fields that hold the tiles a unit walked or slid along (anchor first).
const PATH_KEYS: Array = ["path", "swept_path", "path_tiles"]
# Step fields that hold an area effect's tiles.
const AREA_KEYS: Array = ["tiles", "declared_tiles", "focus_tiles", "target_tiles", "burst_tiles", "force_tiles", "resolved_tiles"]
const INVALID := Vector2i(-1, -1)
# Preloaded, not global class names: exported packs may lack the class cache.
const PathUtils = preload("res://scripts/path_utils.gd")
const BoardSurfaceRules = preload("res://scripts/board_surface_rules.gd")

# Grid geometry is board-public even in Umbra, so a wall in the dark hides
# nothing. Only passable ground outside the decision-time sight is unseen.
static func unseen(state: Dictionary, visible: Dictionary, tile: Vector2i) -> bool:
	return not visible.has(tile) and PathUtils.is_passable(state.get("grid", []) as Array, tile)

# Called once per forecast source, after the information boundary.
static func attach(result: Dictionary, visible: Dictionary, committed: Dictionary, known: Dictionary) -> void:
	result[VISIBLE_KEY] = visible
	if moved_onto_unseen(visible, committed, known): result[CROSSED_KEY] = true

# A unit that changed tiles (or a new unit) now stands on unseen ground.
static func moved_onto_unseen(visible: Dictionary, before: Dictionary, after: Dictionary) -> bool:
	var hero_before: Vector2i = (before.get("player", {}) as Dictionary).get("pos", INVALID)
	var hero_after: Vector2i = (after.get("player", {}) as Dictionary).get("pos", INVALID)
	if hero_after != hero_before and unseen(after, visible, hero_after): return true
	var start: Dictionary = {}
	for enemy: Dictionary in before.get("enemies", []):
		start[int(enemy.get("id", -1))] = enemy.get("pos", INVALID)
	for enemy: Dictionary in after.get("enemies", []):
		var id: int = int(enemy.get("id", -1))
		if start.has(id) and start[id] == enemy.get("pos", INVALID): continue
		for tile: Vector2i in BoardSurfaceRules.footprint_tiles(enemy):
			if unseen(after, visible, tile): return true
	return false

# One resolved activation (or the turn-start beat) on the forecast copy.
static func note(cursor: Dictionary, before: Dictionary, after: Dictionary, steps: Array) -> void:
	if bool(cursor.get("unseen_ground_crossed", false)): return
	var visible: Variant = before.get(VISIBLE_KEY)
	if not visible is Dictionary: return
	if moved_onto_unseen(visible, before, after) or _steps_cross(visible, before, after, steps):
		cursor["unseen_ground_crossed"] = true

static func _steps_cross(visible: Dictionary, before: Dictionary, after: Dictionary, steps: Array) -> bool:
	var units: Array[Vector2i]
	for step_var: Variant in steps:
		if not step_var is Dictionary: continue
		var step: Dictionary = step_var
		var mover: Dictionary = _unit(before, str(step.get("actor_key", "")))
		for key: String in PATH_KEYS:
			var path: Variant = step.get(key)
			if not path is Array: continue
			for index: int in range(1, (path as Array).size()):
				if not (path as Array)[index] is Vector2i: continue
				for tile: Vector2i in BoardSurfaceRules.footprint_tiles(mover, (path as Array)[index]):
					if unseen(before, visible, tile): return true
		var area: Array[Vector2i]
		for key: String in AREA_KEYS:
			var tiles: Variant = step.get(key)
			if not tiles is Array: continue
			for tile: Variant in tiles:
				if tile is Vector2i: area.append(tile)
		for event: Variant in step.get("surface_events", []):
			if event is Dictionary and (event as Dictionary).get("tile") is Vector2i: area.append((event as Dictionary)["tile"])
		for tile: Vector2i in area:
			if not unseen(before, visible, tile): continue
			if units.is_empty(): units = _unit_tiles(before, after)
			for unit_tile: Vector2i in units:
				if PathUtils.manhattan(unit_tile, tile) <= 1: return true
	return false

static func _unit_tiles(before: Dictionary, after: Dictionary) -> Array[Vector2i]:
	var units: Array[Vector2i]
	for state: Dictionary in [before, after]:
		units.append((state.get("player", {}) as Dictionary).get("pos", INVALID))
		for enemy: Dictionary in state.get("enemies", []):
			if int(enemy.get("hp", 0)) > 0: units.append_array(BoardSurfaceRules.footprint_tiles(enemy))
	return units

static func _unit(state: Dictionary, key: String) -> Dictionary:
	if key.begins_with("enemy_"):
		var id: int = int(key.trim_prefix("enemy_"))
		for enemy: Dictionary in state.get("enemies", []):
			if int(enemy.get("id", -1)) == id: return enemy
	return {}

# A foe the forecast cannot plan (new this window, or without an intent).
# Visible to the player: a new foe acts first (turn-clock "?"). Otherwise it is
# hidden in the Umbra (the existing opaque marker). Without the decision-time
# sight, only a lit room can call it visible.
static func arrival_visible(engine: RefCounted, state: Dictionary, enemy: Dictionary) -> bool:
	var visible: Variant = state.get(VISIBLE_KEY)
	if not visible is Dictionary:
		return engine.effective_umbra_radius(state) >= engine.UMBRA_UNLIMITED_RADIUS
	for tile: Vector2i in BoardSurfaceRules.footprint_tiles(enemy):
		if (visible as Dictionary).has(tile): return true
	return false

# A foe already on the board when the forecast began keeps the opaque marker:
# only a summon, split or reinforcement is a new foe.
static func note_unplanned(engine: RefCounted, cursor: Dictionary, state: Dictionary, enemies: Array) -> void:
	var present: Dictionary = {}
	for enemy: Dictionary in (cursor.get("initial_state", {}) as Dictionary).get("enemies", []):
		present[int(enemy.get("id", -1))] = true
	for enemy: Variant in enemies:
		if not enemy is Dictionary or present.has(int((enemy as Dictionary).get("id", -1))) or not arrival_visible(engine, state, enemy):
			(cursor["steps"] as Array).append({"kind": "intent", "hidden_by_umbra": true})
			return
	cursor["new_arrival_before_player"] = true

static func result_fields(cursor: Dictionary) -> Dictionary:
	return {"unseen_ground_crossed": bool(cursor.get("unseen_ground_crossed", false)), "new_arrival_before_player": bool(cursor.get("new_arrival_before_player", false))}

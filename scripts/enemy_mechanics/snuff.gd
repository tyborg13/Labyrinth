extends RefCounted
## The Wick Shade's Snuff (spx-08): the existing `move_toward` carrying the
## existing `snuff_brazier` flag. It moves toward one lit brazier and puts it out
## when it ends its move on or beside it. Only braziers the room lets the hero
## relight by stepping onto them can be snuffed this way, so Guardian and dragon
## braziers (relit by Last Procession, or only while Noctyrax lives) never are.
const Paths = preload("res://scripts/path_utils.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const INVALID := Vector2i(-1, -1)
# "Put it out if adjacent": the Shade's tile is the brazier's or orthogonally next to it.
const SNUFF_REACH: int = 1
const RELIGHT_KEY: String = "brazier_relight_on_step"
const SNUFF_COUNT_KEY: String = "brazier_snuffs"
# The brief's own composition sentence (spx-08 requirement 6), shown as the
# known-move note. TODO_DESIGN_snuff_brazier_marker: no per-brazier marker yet.
const INTENT_NOTE: String = "Move 2 toward the nearest lit brazier, then put it out if adjacent."

static func handles(action: Dictionary) -> bool:
	return str(action.get("type", "")) == "move_toward" and bool(action.get("snuff_brazier", false))

static func action_index(intent: Dictionary) -> int:
	var actions: Array = intent.get("actions", [])
	for index: int in range(actions.size()):
		if actions[index] is Dictionary and handles(actions[index]): return index
	return -1

static func handles_intent(intent: Dictionary) -> bool:
	return action_index(intent) >= 0

static func room_enabled(state: Dictionary) -> bool:
	return bool(state.get(RELIGHT_KEY, false))

static func lit_braziers(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for brazier: Dictionary in state.get("guardian_braziers", []):
		if bool(brazier.get("lit", true)): result.append(brazier)
	return result

## Snuff is offered only while the room has a lit brazier the hero could relight.
static func available(state: Dictionary) -> bool:
	return room_enabled(state) and not lit_braziers(state).is_empty()

## Drops unavailable Snuff intents. Every other list is returned unchanged, so
## each existing fight keeps its exact intent cycle.
static func available_intents(state: Dictionary, intents: Array) -> Array:
	var found: bool = false
	for intent: Variant in intents:
		if intent is Dictionary and handles_intent(intent):
			found = true
			break
	if not found or available(state): return intents
	var result: Array = []
	for intent: Variant in intents:
		if not (intent is Dictionary and handles_intent(intent)): result.append(intent)
	return result

## The Wick Shade cycles its intents in order. Its authored Snuff weight is how
## many consecutive cycle slots Snuff fills; intents without Snuff are untouched.
## Weight w gives Snuff w cycle slots, interleaved after the other intents
## (Grasp, Snuff, Drift, Snuff) so a Shade threatens a brazier from its second turn.
static func cycle_intents(intents: Array) -> Array:
	var others: Array = []
	var snuffs: Array = []
	for intent: Variant in intents:
		if intent is Dictionary and handles_intent(intent):
			for _copy: int in range(maxi(1, int((intent as Dictionary).get("weight", 1)))): snuffs.append(intent)
		else:
			others.append(intent)
	if snuffs.is_empty(): return intents
	var result: Array = []
	for index: int in range(maxi(others.size(), snuffs.size())):
		if index < others.size(): result.append(others[index])
		if index < snuffs.size(): result.append(snuffs[index])
	return result

static func brazier_by_id(state: Dictionary, brazier_id: int) -> Dictionary:
	for brazier: Dictionary in state.get("guardian_braziers", []):
		if int(brazier.get("id", -1)) == brazier_id: return brazier
	return {}

## The lit brazier nearest the Shade; equal distances keep the lower brazier index.
static func nearest_lit(state: Dictionary, from: Vector2i) -> Dictionary:
	var best: Dictionary = {}
	var nearest: int = 2147483647
	for brazier: Dictionary in lit_braziers(state):
		var distance: int = Paths.manhattan(from, brazier["pos"])
		if distance < nearest:
			nearest = distance
			best = brazier
	return best

## Declared when the intent is chosen, so the plan and preview show its brazier.
static func declare(state: Dictionary, enemy: Dictionary, intent: Dictionary) -> Dictionary:
	var index: int = action_index(intent)
	if index < 0: return intent
	var result: Dictionary = intent.duplicate(true)
	var brazier: Dictionary = nearest_lit(state, enemy.get("pos", INVALID))
	if not brazier.is_empty(): result["actions"][index]["brazier_id"] = int(brazier["id"])
	return result

## The declared brazier while it stays lit. If another Shade has already put it
## out, the Shade turns to the lit brazier nearest it now.
static func target(state: Dictionary, enemy: Dictionary, action: Dictionary) -> Dictionary:
	var declared: Dictionary = brazier_by_id(state, int(action.get("brazier_id", -1)))
	if not declared.is_empty() and bool(declared.get("lit", true)): return declared
	var fallback: Dictionary = nearest_lit(state, enemy.get("pos", INVALID))
	return fallback if not fallback.is_empty() else declared

static func reaches(tile: Vector2i, brazier: Dictionary) -> bool:
	return not brazier.is_empty() and Paths.manhattan(tile, brazier["pos"]) <= SNUFF_REACH

static func plan(engine: RefCounted, state: Dictionary, index: int, intent: Dictionary, movement_disabled: bool = false, attack_disabled: bool = false) -> Dictionary:
	var enemy: Dictionary = engine._normalized_enemy(state["enemies"][index])
	var move_index: int = action_index(intent)
	var action: Dictionary = intent["actions"][move_index]
	var brazier: Dictionary = target(state, enemy, action)
	var start: Vector2i = enemy["pos"]
	var path: Array[Vector2i] = engine._vector2i_values([start])
	if not movement_disabled and not brazier.is_empty():
		path = engine._planned_enemy_movement_path(state, enemy, index, action, {}, {}, brazier["pos"], true)
	var end: Vector2i = path.back()
	var lands: bool = not attack_disabled and bool(brazier.get("lit", false)) and reaches(end, brazier)
	return {"enemy_index": index, "enemy_key": engine._enemy_key(enemy), "path": path, "route": path, "destination": end,
		"movement_action_index": move_index, "attack_action_index": -1, "attack_action": {}, "target": {}, "target_key": "",
		"target_tile": brazier.get("pos", INVALID), "projected_attack_target": INVALID, "projected_attack": engine._vector2i_values([]),
		"attack_available": false, "snuff_brazier_id": int(brazier.get("id", -1)), "snuff_lands": lands,
		"movement_disabled": movement_disabled, "attack_disabled": attack_disabled}

static func resolve(engine: RefCounted, state: Dictionary, index: int, action: Dictionary, context: Dictionary, bleed_steps: Array[Dictionary]) -> Dictionary:
	var enemy: Dictionary = engine._normalized_enemy(state["enemies"][index])
	var brazier: Dictionary = target(state, enemy, action)
	if brazier.is_empty(): return state
	if not bool(context.get("movement_disabled", false)):
		var path: Array[Vector2i] = engine._planned_enemy_movement_path(state, enemy, index, action, {}, context, brazier["pos"], true)
		if path.size() > 1:
			state = engine._trigger_enemy_bleed_for_resolved_action(state, index, action, bleed_steps)
			if engine._enemy_cannot_continue_after_bleed(state, index): return state
			state = engine._move_enemy_along_planned_path(state, index, path, context, int(action.get("range", 0)))
			engine._log(state, "%s closes in." % engine.EnemyIdentity.display_name(enemy))
	enemy = state["enemies"][index]
	if int(enemy.get("hp", 0)) <= 0 or bool(context.get("attack_disabled", false)) or engine.combat_outcome(state) != "": return state
	brazier = brazier_by_id(state, int(brazier["id"]))
	if not bool(brazier.get("lit", true)) or not reaches(enemy["pos"], brazier): return state
	brazier["lit"] = false
	var objective: Dictionary = state.get("objective", {})
	if objective.has(SNUFF_COUNT_KEY): objective[SNUFF_COUNT_KEY] = int(objective[SNUFF_COUNT_KEY]) + 1
	Surfaces.record_event(state, {"kind": "brazier_snuffed", "brazier_id": int(brazier["id"]), "tile": brazier["pos"], "source": engine._surface_source(state, action)})
	return state

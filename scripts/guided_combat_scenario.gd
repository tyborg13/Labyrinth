extends RefCounted
class_name GuidedCombatScenario

## Deterministic combat state used by the first-run guided curriculum. The
## scenario is applied once, when the first combat is created, and then travels
## with the normal combat checkpoint so save/resume needs no special UI state.

const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const CombatObjectiveRules = preload("res://scripts/combat_objective_rules.gd")
const GameData = preload("res://scripts/game_data.gd")
const PathUtils = preload("res://scripts/path_utils.gd")

const STATE_KEY: String = "guided_combat_scenario"
const RUN_ELIGIBILITY_KEY: String = "guided_combat_scenario_eligible"
const VERSION: int = 1
const TARGET_ENEMY_ID: int = 7101
const SUPPORT_ENEMY_ID: int = 7102
const TARGET_HP: int = 17
const SUPPORT_FIRST_ACTIVATION_TIME: int = 13
const PREVIEW_CARD_ID: String = "bone_dart"
const KILL_CARD_ID: String = "quick_stab"
const REFUND_CARD_ID: String = "brace"

static func mark_run_eligible(run_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var progression: Dictionary = next_state.get("progression", {}) as Dictionary
	if (
		ContextualCombatTutorial.is_active(progression)
		and ContextualCombatTutorial.completed_steps(progression).is_empty()
	):
		next_state[RUN_ELIGIBILITY_KEY] = true
	return next_state

static func prepare_for_run(run_state: Dictionary, combat_state: Dictionary) -> Dictionary:
	if not should_prepare(run_state, combat_state):
		return combat_state.duplicate(true)
	var next_state: Dictionary = combat_state.duplicate(true)
	var lane: Dictionary = _authored_lane(next_state.get("grid", []) as Array)
	if lane.is_empty():
		return next_state
	var player_tile: Vector2i = lane.get("player", Vector2i.ZERO)
	var move_tile: Vector2i = lane.get("move", Vector2i.ZERO)
	var target_tile: Vector2i = lane.get("target", Vector2i.ZERO)
	var support_tile: Vector2i = _support_tile(
		next_state.get("grid", []) as Array,
		_typed_tiles([player_tile, move_tile, target_tile]),
		move_tile
	)
	if support_tile.x < 0:
		return next_state

	var player: Dictionary = (next_state.get("player", {}) as Dictionary).duplicate(true)
	player["pos"] = player_tile
	next_state["player"] = player
	next_state["objective"] = {
		"type": CombatObjectiveRules.KILL_ALL,
		"name": CombatObjectiveRules.display_name(CombatObjectiveRules.KILL_ALL),
		"description": CombatObjectiveRules.description(CombatObjectiveRules.KILL_ALL),
		"icon_path": CombatObjectiveRules.icon_path(CombatObjectiveRules.KILL_ALL),
	}
	var support_crawler: Dictionary = _authored_crawler(
		SUPPORT_ENEMY_ID,
		support_tile,
		int(GameData.enemy_def("crawler").get("max_hp", 14)),
		0
	)
	support_crawler["intent"] = _tutorial_support_intent()
	next_state["enemies"] = [
		_authored_crawler(TARGET_ENEMY_ID, target_tile, TARGET_HP, 0),
		support_crawler,
	]
	next_state["traps"] = []
	next_state["terrain"] = []
	next_state["loot"] = []
	next_state["cards_per_turn"] = 2
	next_state["cards_played_this_turn"] = 0
	next_state["death_bonus_card_plays_this_turn"] = 0
	next_state["card_play_bonus_this_turn"] = 0
	next_state["banked_plays"] = 0
	next_state["banked_play_active"] = 0
	next_state["banked_play_spent_this_activation"] = 0
	next_state["player_movement_capacity"] = 2
	next_state["player_movement_remaining"] = 2
	next_state["current_actor"] = {
		"kind": "player", "actor_key": "player", "name": "Reaver",
		"type": "player", "team": "player", "time": 0, "seq": 0,
	}
	next_state["initiative_clock"] = 0
	next_state["activation_seq"] = 2
	next_state["turn_queue"] = [
		_enemy_queue_entry(next_state["enemies"][0] as Dictionary, 13, 1),
		_enemy_queue_entry(next_state["enemies"][1] as Dictionary, SUPPORT_FIRST_ACTIVATION_TIME, 2),
	]
	var deck: Dictionary = (next_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = [PREVIEW_CARD_ID, KILL_CARD_ID, REFUND_CARD_ID, "guarded_step", "pale_spark"]
	deck["draw"] = ["shadow_step", "dull_bolt", "ember_jab", "guarded_step", "quick_stab", "brace"]
	deck["discard"] = []
	deck["burned"] = []
	deck["consumed"] = []
	next_state["deck"] = deck
	next_state[STATE_KEY] = {
		"version": VERSION,
		"player_tile": player_tile,
		"move_tile": move_tile,
		"target_tile": target_tile,
		"support_tile": support_tile,
		"target_enemy_id": TARGET_ENEMY_ID,
		"support_enemy_id": SUPPORT_ENEMY_ID,
		"preview_card_id": PREVIEW_CARD_ID,
		"kill_card_id": KILL_CARD_ID,
		"refund_card_id": REFUND_CARD_ID,
	}
	return next_state

static func should_prepare(run_state: Dictionary, combat_state: Dictionary) -> bool:
	if combat_state.is_empty() or combat_state.has(STATE_KEY) or bool(run_state.get("debug_boss_run", false)):
		return false
	# RunEngine is also used directly by simulations, fixtures, and progression
	# tools. Only the real New Run entry point opts a run into the authored setup,
	# so a blank profile cannot silently replace otherwise ordinary combat.
	if not bool(run_state.get(RUN_ELIGIBILITY_KEY, false)):
		return false
	if str(combat_state.get("room_type", "combat")) != "combat":
		return false
	var progression: Dictionary = run_state.get("progression", {}) as Dictionary
	return (
		ContextualCombatTutorial.is_active(progression)
		and ContextualCombatTutorial.completed_steps(progression).is_empty()
	)

static func is_authored(combat_state: Dictionary) -> bool:
	return int((combat_state.get(STATE_KEY, {}) as Dictionary).get("version", 0)) == VERSION

static func move_tile(combat_state: Dictionary) -> Vector2i:
	return (combat_state.get(STATE_KEY, {}) as Dictionary).get("move_tile", Vector2i(-1, -1))

static func target_tile(combat_state: Dictionary) -> Vector2i:
	return (combat_state.get(STATE_KEY, {}) as Dictionary).get("target_tile", Vector2i(-1, -1))

static func target_enemy_id(combat_state: Dictionary) -> int:
	return int((combat_state.get(STATE_KEY, {}) as Dictionary).get("target_enemy_id", -1))

static func support_tile(combat_state: Dictionary) -> Vector2i:
	return (combat_state.get(STATE_KEY, {}) as Dictionary).get("support_tile", Vector2i(-1, -1))

static func support_enemy_id(combat_state: Dictionary) -> int:
	return int((combat_state.get(STATE_KEY, {}) as Dictionary).get("support_enemy_id", -1))

static func expected_card_id(combat_state: Dictionary, role: String) -> String:
	var scenario: Dictionary = combat_state.get(STATE_KEY, {}) as Dictionary
	return str(scenario.get("%s_card_id" % role, ""))

static func _authored_lane(grid: Array) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var center := Vector2(_grid_width(grid) * 0.5, grid.size() * 0.5)
	for y: int in range(grid.size()):
		for x: int in range(_grid_width(grid)):
			var player_tile := Vector2i(x, y)
			for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var move_tile := player_tile + direction
				var target_tile := move_tile + direction
				if not _tiles_are_passable(grid, _typed_tiles([player_tile, move_tile, target_tile])):
					continue
				candidates.append({
					"player": player_tile,
					"move": move_tile,
					"target": target_tile,
					"score": Vector2(move_tile).distance_squared_to(center),
				})
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score: float = float(left.get("score", INF))
		var right_score: float = float(right.get("score", INF))
		if not is_equal_approx(left_score, right_score):
			return left_score < right_score
		var left_move: Vector2i = left.get("move", Vector2i.ZERO)
		var right_move: Vector2i = right.get("move", Vector2i.ZERO)
		return left_move.y < right_move.y if left_move.y != right_move.y else left_move.x < right_move.x
	)
	return {} if candidates.is_empty() else candidates[0].duplicate(true)

static func _support_tile(grid: Array, occupied: Array[Vector2i], origin: Vector2i) -> Vector2i:
	var result := Vector2i(-1, -1)
	var best_score: int = 999999
	for y: int in range(grid.size()):
		for x: int in range(_grid_width(grid)):
			var tile := Vector2i(x, y)
			if occupied.has(tile) or not PathUtils.is_passable(grid, tile):
				continue
			var path: Array[Vector2i] = PathUtils.find_path(grid, tile, origin, {}, true)
			if path.is_empty():
				continue
			var distance: int = path.size() - 1
			# Skitter Strike moves 3 and then attacks at range 1. Prefer a
			# four-step route so its movement and Brace's damage absorption are
			# both visible when the player passes.
			if distance < 2 or distance > 4:
				continue
			var score: int = absi(4 - distance) * 10000 + tile.y * 100 + tile.x
			if score < best_score:
				best_score = score
				result = tile
	return result

static func _authored_crawler(enemy_id: int, tile: Vector2i, hp: int, intent_index: int) -> Dictionary:
	var definition: Dictionary = GameData.enemy_def("crawler")
	var intents: Array = definition.get("intents", []) as Array
	var intent: Dictionary = {}
	if not intents.is_empty() and typeof(intents[posmod(intent_index, intents.size())]) == TYPE_DICTIONARY:
		intent = (intents[posmod(intent_index, intents.size())] as Dictionary).duplicate(true)
	return {
		"id": enemy_id,
		"type": "crawler",
		"pos": tile,
		"hp": hp,
		"max_hp": hp,
		"block": 0,
		"stoneskin": 0,
		"burn": 0,
		"bleed": 0,
		"expose": 0,
		"freeze": 0,
		"shock": 0,
		"immobilize": false,
		"poison": {"damage": 0, "delay": 0},
		"intent": intent,
	}

static func _tutorial_support_intent() -> Dictionary:
	return {
		"id": "guided_skitter_strike",
		"name": "Skitter Strike",
		"time": 5,
		"actions": [
			{"type": "move_toward", "range": 3},
			{"type": "melee", "damage": 4, "range": 1},
		],
	}

static func _enemy_queue_entry(enemy: Dictionary, scheduled_time: int, sequence: int) -> Dictionary:
	return {
		"kind": "enemy",
		"actor_key": "enemy_%d" % int(enemy.get("id", -1)),
		"enemy_id": int(enemy.get("id", -1)),
		"type": str(enemy.get("type", "crawler")),
		"name": str(GameData.enemy_def(str(enemy.get("type", "crawler"))).get("name", "Enemy")),
		"team": "enemy",
		"time": scheduled_time,
		"seq": sequence,
		"pos": enemy.get("pos", Vector2i.ZERO),
		"intent_time_cost": int((enemy.get("intent", {}) as Dictionary).get("time", 0)),
	}

static func _tiles_are_passable(grid: Array, tiles: Array[Vector2i]) -> bool:
	for tile: Vector2i in tiles:
		if not PathUtils.is_passable(grid, tile):
			return false
	return true

static func _grid_width(grid: Array) -> int:
	var width: int = 0
	for row_var: Variant in grid:
		if typeof(row_var) == TYPE_ARRAY:
			width = maxi(width, (row_var as Array).size())
	return width

static func _typed_tiles(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Variant in values:
		if typeof(value) == TYPE_VECTOR2I:
			result.append(value as Vector2i)
	return result

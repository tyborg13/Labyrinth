extends "res://tools/run_hunt_policy.gd"
## Prefer progress and lower projected Health loss using the hunt's legal offers.

const Objectives = preload("res://scripts/combat_objective_rules.gd")
const PassForecast = preload("res://scripts/pass_forecast_red_tiles.gd")
const FORECAST_CHOICES := 12
const HEALTH_VALUE := 2.5
const DEFEAT_COST := 500.0
const WIN_VALUE := 1000.0
const CLOSE_DISTANCE_VALUE := 0.35
const EXIT_DISTANCE_VALUE := 9.0
const KILL_VALUE := 5.0
const BLOCK_VALUE := 0.15
const STATUS_VALUE := 0.7
const ENEMY_BLOCK_VALUE := 0.2


func choose(scene: Node, candidates: Array) -> Dictionary:
	var run: Dictionary = scene.get("_run_state")
	var outward: Array = _outward_rooms(scene, run, candidates)
	if not outward.is_empty(): return super.choose(scene, outward)
	if run.get("mode") != "combat" or browsing(scene) or candidates.size() == 1:
		return super.choose(scene, candidates)
	var engine: RefCounted = scene.get("_combat_engine")
	var state: Dictionary = scene.get("_combat_state")
	var choices: Array[Dictionary]
	var visible_enemies: Array[Dictionary]
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy["hp"]) > 0 and engine.is_enemy_visible_to_player(state, enemy):
			visible_enemies.append(enemy)
	for offer: Dictionary in candidates:
		var options: Array[Dictionary] = _outcomes(scene, engine, state, offer)
		var best_option: Dictionary = {}
		for option: Dictionary in options:
			var after: Dictionary = option["state"]
			option["score"] = _value(engine, state, after, visible_enemies)
			if best_option.is_empty() or option["score"] > best_option["score"]:
				best_option = option
		if not best_option.is_empty():
			best_option["offer"] = offer
			choices.append(best_option)
	if choices.is_empty(): return super.choose(scene, candidates)
	choices.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
	var best: Dictionary = choices[0]["offer"]
	var best_score: float = -INF
	for index: int in range(mini(FORECAST_CHOICES, choices.size())):
		var choice: Dictionary = choices[index]
		var score: float = float(choice["score"]) - _forecast_cost(engine, choice["state"])
		if score > best_score:
			best = choice["offer"]
			best_score = score
	return best


func _outward_rooms(scene: Node, run: Dictionary, candidates: Array) -> Array:
	var engine: RefCounted = scene.get("_run_engine")
	var room: Dictionary = engine.room_metadata(run, run["current_room"])
	var step: int = room.get("map_step", 0)
	var result: Array
	for offer: Dictionary in candidates:
		if offer["kind"] != "map_room": continue
		var target: Dictionary = engine.room_metadata(run, offer["args"][0])
		if int(target.get("map_step", 0)) > step: result.append(offer)
	return result


func _outcomes(scene: Node, engine: RefCounted, state: Dictionary, offer: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if offer["kind"] == "pass":
		result.append({"state": state})
	elif offer.has("tile"):
		result.append({"state": engine.apply_player_movement(state, offer["tile"])})
	elif offer["kind"] == "card":
		var index: int = offer["args"][0]
		if not scene.call("_guided_tutorial_card_allowed", index): return result
		var options: Dictionary = scene.call("_card_play_options_for_index", index)
		var preview: Dictionary = options.get("play", {})
		if preview.get("complete", false):
			result.append({"state": _finish_card(engine, preview["state"], index, preview["actions"])})
		else:
			for tile: Vector2i in preview.get("target_tiles", []):
				result.append({"state": _project_card(scene, engine, preview, index, tile)})
	elif offer.get("method") == "_on_board_tile_clicked" and not scene.call("_orientation_pending"):
		var preview: Dictionary = scene.call("_active_card_preview")
		if not preview.is_empty():
			var index: int = scene.get("_selected_card_index")
			var tile: Vector2i = offer["args"][0]
			var next: Dictionary = _project_card(scene, engine, preview, index, tile) if index >= 0 else _resolve(engine, preview, tile)
			result.append({"state": next})
	return result


func _resolve(engine: RefCounted, preview: Dictionary, tile: Vector2i) -> Dictionary:
	return engine.apply_player_action(preview["state"], preview["action"], tile)


func _project_card(scene: Node, engine: RefCounted, preview: Dictionary, index: int, tile: Vector2i) -> Dictionary:
	var state: Dictionary = _resolve(engine, preview, tile)
	var actions: Array = preview["actions"]
	var cursor: int = int(preview["action_index"]) + 1
	if cursor >= actions.size(): return _finish_card(engine, state, index, actions)
	var followup: Dictionary = scene.call("_card_preview_from_state", preview["card_id"], state, actions, cursor)
	if followup.get("complete", false): return _finish_card(engine, followup["state"], index, actions)
	return state


func _finish_card(engine: RefCounted, state: Dictionary, index: int, actions: Array) -> Dictionary:
	return engine.finish_player_card(state, index, engine.card_plays_spent_for_actions(actions))


func _value(engine: RefCounted, before: Dictionary, after: Dictionary, visible: Array[Dictionary]) -> float:
	var outcome: String = engine.combat_outcome(after)
	if outcome == "victory": return WIN_VALUE
	if outcome == "defeat": return -DEFEAT_COST
	var player: Dictionary = before["player"]
	var next_player: Dictionary = after["player"]
	var score: float = HEALTH_VALUE * (int(next_player["hp"]) - int(player["hp"]))
	score += BLOCK_VALUE * (int(next_player.get("block", 0)) - int(player.get("block", 0)))
	var next_by_id: Dictionary = {}
	for enemy: Dictionary in after.get("enemies", []): next_by_id[enemy["id"]] = enemy
	for enemy: Dictionary in visible:
		var next_enemy: Dictionary = next_by_id.get(enemy["id"], {})
		var remaining: int = maxi(0, int(next_enemy.get("hp", 0)))
		score += int(enemy["hp"]) - remaining
		score += KILL_VALUE if remaining == 0 else 0.0
		for status: String in ["freeze", "shock", "petrify"]:
			score += STATUS_VALUE * (int(next_enemy.get(status, 0)) - int(enemy.get(status, 0)))
		score += ENEMY_BLOCK_VALUE * (int(enemy.get("block", 0)) - int(next_enemy.get("block", 0)))
	var objective: Dictionary = before.get("objective", {})
	if objective.get("type") == Objectives.REACH_EXIT:
		var exits: Array = Objectives.exit_target_tiles(objective)
		return score + EXIT_DISTANCE_VALUE * (_distance(player["pos"], exits) - _distance(next_player["pos"], exits))
	if objective.get("type") == Objectives.SURVIVE: return score
	var enemies: Array[Vector2i]
	for enemy: Dictionary in visible:
		enemies.append_array(engine._enemy_footprint_tiles(enemy))
	return score + CLOSE_DISTANCE_VALUE * (_distance(player["pos"], enemies) - _distance(next_player["pos"], enemies))


func _distance(origin: Vector2i, tiles: Array) -> int:
	if tiles.is_empty(): return 0
	var result: int = 1000
	for tile: Vector2i in tiles:
		result = mini(result, absi(tile.x - origin.x) + absi(tile.y - origin.y))
	return result


func _forecast_cost(engine: RefCounted, state: Dictionary) -> float:
	if not engine.combat_outcome(state).is_empty(): return 0.0
	var scheduled: Dictionary = PassForecast.schedule(engine, state)
	var preview: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(scheduled, true)
	var after: Dictionary = preview.get("state", state)
	var hp: int = after["player"]["hp"]
	if hp <= 0: return DEFEAT_COST
	return HEALTH_VALUE * (int(state["player"]["hp"]) - hp)

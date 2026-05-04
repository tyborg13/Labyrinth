extends RefCounted
class_name CombatEngine

const ElementData = preload("res://scripts/element_data.gd")
const GameData = preload("res://scripts/game_data.gd")
const PathUtils = preload("res://scripts/path_utils.gd")

const FATIGUE_BASE_DAMAGE: int = 2
const BASE_CARDS_PER_TURN: int = 2
const BASE_DRAW_PER_TURN: int = 2
const MAX_HAND_SIZE: int = 8
const ATTACK_ACTION_TYPES: Array[String] = ["melee", "ranged", "aoe", "push", "pull"]
const ELEMENTAL_ATTACK_ACTION_TYPES: Array[String] = ["melee", "ranged", "aoe"]
const ZEKARION_TYPE: String = "zekarion"
const LIGHTNING_WISP_TYPE: String = "lightning_wisp"
const DEFAULT_AOE_PATTERN: Array = [
	[0, 0],
	[1, 0],
	[-1, 0],
	[0, 1],
	[0, -1]
]

func create_combat(run_seed: int, room_layout: Dictionary, player_snapshot: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _combat_seed(run_seed, room_layout.get("coord", Vector2i.ZERO))
	var deck_cards: Array = player_snapshot.get("deck_cards", []).duplicate()
	var draw_pile: Array[String] = GameData.shuffle_cards(deck_cards, rng)
	var player: Dictionary = _normalized_player({
		"pos": room_layout.get("player_start", Vector2i.ZERO),
		"hp": int(player_snapshot.get("hp", 1)),
		"max_hp": int(player_snapshot.get("max_hp", 1)),
		"block": 0,
		"stoneskin": 0
	})
	var enemies: Array[Dictionary] = []
	for enemy_var: Variant in room_layout.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		enemies.append(_normalized_enemy(enemy_var as Dictionary))
	var state: Dictionary = {
		"room_name": str(room_layout.get("name", "Room")),
		"room_coord": room_layout.get("coord", Vector2i.ZERO),
		"room_depth": int(room_layout.get("depth", 1)),
		"room_type": str(room_layout.get("type", "combat")),
		"room_element": str(room_layout.get("element", ElementData.NONE)),
		"grid": room_layout.get("grid", []).duplicate(true),
		"moss": room_layout.get("moss", {}).duplicate(true),
		"player": player,
		"enemies": enemies,
		"illusions": [],
		"next_illusion_id": 1,
		"traps": room_layout.get("traps", []).duplicate(true),
		"loot": room_layout.get("loot", []).duplicate(true),
		"relics": player_snapshot.get("relics", []).duplicate(),
		"card_upgrades": (player_snapshot.get("card_upgrades", {}) as Dictionary).duplicate(true),
		"card_mods": (player_snapshot.get("card_mods", {}) as Dictionary).duplicate(true),
		"hand_size": int(player_snapshot.get("hand_size", 5)),
		"cards_per_turn": int(player_snapshot.get("cards_per_turn", BASE_CARDS_PER_TURN)),
		"draw_per_turn": int(player_snapshot.get("draw_per_turn", BASE_DRAW_PER_TURN)),
		"cards_played_this_turn": 0,
		"death_bonus_card_plays_this_turn": 0,
		"card_play_bonus_this_turn": 0,
		"heal_bonus": int(player_snapshot.get("heal_bonus", 0)),
		"deck": {
			"draw": draw_pile,
			"hand": [],
			"discard": [],
			"burned": [],
			"cycles": 0,
			"fatigue_base": FATIGUE_BASE_DAMAGE
		},
		"turn": 1,
		"player_turn_restrictions": {
			"frozen": false,
			"shocked": false,
			"stunned": false
		},
		"pending_player_trap_restriction": "",
		"turn_flags": {
			"first_attack_bonus_used": false,
			"first_move_bonus_used": false
		},
		"death_rewards": [],
		"room_embers": 0,
		"rng_state": rng.state,
		"log": []
	}
	for enemy_index: int in range((state.get("enemies", []) as Array).size()):
		_assign_enemy_intent(state, enemy_index, rng)
	state["rng_state"] = rng.state
	state = _draw_cards_in_place(state, state.get("hand_size", 5) + GameData.stat_bonus_from_relics(state.get("relics", []), "opening_draw_bonus"))
	_log(state, "Entered %s." % state.get("room_name", "a room"))
	return state

func card_def(card_id: String, state: Dictionary = {}) -> Dictionary:
	return GameData.card_def_for_progression(card_id, state)

func player_action_needs_target(action: Dictionary) -> bool:
	var action_type: String = str(action.get("type", ""))
	if action_type == "aoe":
		return int(action.get("range", 0)) > 0
	return action_type in ["move", "blink", "melee", "ranged", "push", "pull", "illusion"]

func player_action_can_resolve(state: Dictionary, action: Dictionary) -> bool:
	var action_type: String = str(action.get("type", ""))
	var restrictions: Dictionary = state.get("player_turn_restrictions", {})
	if bool(restrictions.get("frozen", false)) or bool(restrictions.get("stunned", false)):
		return false
	if bool(restrictions.get("shocked", false)):
		return action_type in ["move", "blink"]
	return true

func valid_targets_for_player_action(state: Dictionary, action: Dictionary) -> Array[Vector2i]:
	if not player_action_can_resolve(state, action):
		return []
	var player: Dictionary = state.get("player", {})
	var player_pos: Vector2i = player.get("pos", Vector2i.ZERO)
	var action_type: String = str(action.get("type", ""))
	var occupied: Dictionary = _occupied_enemy_tiles(state)
	var targets: Array[Vector2i] = []
	match action_type:
		"move":
			occupied = _occupied_actor_tiles(state)
			var move_range: int = int(action.get("range", 0)) + _move_bonus_for_current_turn(state)
			targets = PathUtils.reachable_tiles(state.get("grid", []), player_pos, move_range, occupied)
		"blink":
			occupied = _occupied_actor_tiles(state)
			var max_range: int = int(action.get("range", 0))
			for tile: Vector2i in PathUtils.diamond_tiles(player_pos, max_range, state.get("grid", [])):
				if tile == player_pos:
					continue
				if occupied.has(tile):
					continue
				if not PathUtils.is_passable(state.get("grid", []), tile):
					continue
				targets.append(tile)
		"illusion":
			occupied = _occupied_actor_tiles(state)
			occupied[player_pos] = true
			var illusion_range: int = int(action.get("range", 0))
			for tile: Vector2i in PathUtils.diamond_tiles(player_pos, illusion_range, state.get("grid", [])):
				if occupied.has(tile):
					continue
				if not PathUtils.is_passable(state.get("grid", []), tile):
					continue
				targets.append(tile)
		"melee":
			for enemy: Dictionary in _live_enemies(state):
				if _enemy_distance_to_tile(enemy, player_pos) <= int(action.get("range", 1)):
					targets.append(_closest_enemy_tile_to(enemy, player_pos))
		"ranged":
			for enemy: Dictionary in _live_enemies(state):
				var enemy_pos: Vector2i = _closest_enemy_tile_to(enemy, player_pos)
				if PathUtils.manhattan(player_pos, enemy_pos) > int(action.get("range", 1)):
					continue
				if not PathUtils.has_line_of_sight(state.get("grid", []), player_pos, enemy_pos):
					continue
				targets.append(enemy_pos)
		"aoe":
			var aoe_range: int = int(action.get("range", 0))
			if aoe_range <= 0:
				if not _enemy_indices_in_tiles(state, _best_aoe_tiles_for_target(state, action, player_pos, false)).is_empty():
					targets.append(player_pos)
			else:
				for tile: Vector2i in PathUtils.diamond_tiles(player_pos, aoe_range, state.get("grid", [])):
					if tile == player_pos:
						continue
					if not PathUtils.is_passable(state.get("grid", []), tile):
						continue
					if not PathUtils.has_line_of_sight(state.get("grid", []), player_pos, tile):
						continue
					if _enemy_indices_in_tiles(state, _best_aoe_tiles_for_target(state, action, tile, false)).is_empty():
						continue
					targets.append(tile)
		"push", "pull":
			for enemy: Dictionary in _live_enemies(state):
				var enemy_pos: Vector2i = _closest_enemy_tile_to(enemy, player_pos)
				var max_range: int = int(action.get("range", 1))
				if PathUtils.manhattan(player_pos, enemy_pos) > max_range:
					continue
				if max_range > 1 and not PathUtils.has_line_of_sight(state.get("grid", []), player_pos, enemy_pos):
					continue
				targets.append(enemy_pos)
	return targets

func path_for_player_action(state: Dictionary, action: Dictionary, target_tile: Vector2i) -> Array[Vector2i]:
	var action_type: String = str(action.get("type", ""))
	var player_pos: Vector2i = (_normalized_player(state.get("player", {}))).get("pos", Vector2i.ZERO)
	match action_type:
		"move":
			var move_range: int = int(action.get("range", 0)) + _move_bonus_for_current_turn(state)
			return _actual_player_movement_path(state, player_pos, target_tile, move_range)
		"blink":
			if target_tile.x >= 0:
				return _vector2i_values([target_tile])
			return _vector2i_values([])
		_:
			return _vector2i_values([])

func apply_player_action(state: Dictionary, action: Dictionary, target_tile: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	if not player_action_can_resolve(next_state, action):
		return next_state
	var player: Dictionary = next_state.get("player", {})
	var player_pos: Vector2i = player.get("pos", Vector2i.ZERO)
	var action_type: String = str(action.get("type", ""))
	match action_type:
		"move":
			if valid_targets_for_player_action(next_state, action).has(target_tile):
				var movement_path: Array[Vector2i] = path_for_player_action(next_state, action, target_tile)
				next_state = _move_player_along_path(next_state, movement_path)
				_mark_first_move_used(next_state)
				_log(next_state, "Moved to %s." % str((next_state.get("player", {}) as Dictionary).get("pos", target_tile)))
		"blink":
			if valid_targets_for_player_action(next_state, action).has(target_tile):
				player["pos"] = target_tile
				next_state["player"] = player
				_collect_loot_at_player(next_state)
				next_state = _trigger_trap_on_player(next_state)
				_log(next_state, "Blinked to %s." % str(target_tile))
		"melee":
			next_state = _attack_enemy_on_tile(next_state, action, target_tile, "melee")
		"ranged":
			next_state = _attack_enemy_on_tile(next_state, action, target_tile, "ranged")
		"aoe":
			next_state = _aoe_enemies(next_state, action, target_tile)
		"push":
			next_state = _push_or_pull_enemy(next_state, action, target_tile, true)
		"pull":
			next_state = _push_or_pull_enemy(next_state, action, target_tile, false)
		"block":
			player["block"] = int(player.get("block", 0)) + int(action.get("amount", 0))
			next_state["player"] = player
			_log(next_state, "Gained %d block." % int(action.get("amount", 0)))
		"stoneskin":
			player["stoneskin"] = int(player.get("stoneskin", 0)) + int(action.get("amount", 0))
			next_state["player"] = player
			_log(next_state, "Gained %d stoneskin." % int(action.get("amount", 0)))
		"heal":
			var heal_amount: int = int(action.get("amount", 0))
			player["hp"] = mini(int(player.get("max_hp", 1)), int(player.get("hp", 0)) + heal_amount)
			next_state["player"] = player
			_log(next_state, "Recovered %d health." % heal_amount)
		"draw":
			next_state = _draw_cards_in_place(next_state, int(action.get("amount", 0)))
		"card_play":
			var bonus_card_plays: int = maxi(0, int(action.get("amount", 0)))
			next_state["card_play_bonus_this_turn"] = int(next_state.get("card_play_bonus_this_turn", 0)) + bonus_card_plays
			if bonus_card_plays > 0:
				_log(next_state, "Gained %d card play(s)." % bonus_card_plays)
		"illusion":
			if valid_targets_for_player_action(next_state, action).has(target_tile):
				next_state = _create_illusion(next_state, target_tile, int(action.get("health", action.get("amount", 0))))
	return next_state

func finish_player_card(state: Dictionary, hand_index: int) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var hand: Array = ((next_state.get("deck", {}) as Dictionary).get("hand", []) as Array).duplicate()
	if hand_index < 0 or hand_index >= hand.size():
		return next_state
	var card_id: String = str(hand[hand_index])
	hand.remove_at(hand_index)
	var deck: Dictionary = next_state.get("deck", {}).duplicate(true)
	deck["hand"] = hand
	var card: Dictionary = card_def(card_id, next_state)
	if bool(card.get("burn", false)):
		var burned: Array = deck.get("burned", []).duplicate()
		burned.append(card_id)
		deck["burned"] = burned
	else:
		var discard: Array = deck.get("discard", []).duplicate()
		discard.append(card_id)
		deck["discard"] = discard
	next_state["deck"] = deck
	var health_cost: int = int(card.get("health_cost", 0))
	if health_cost > 0:
		next_state = _lose_player_health(next_state, health_cost, true, false)
		_log(next_state, "Paid %d health for %s." % [health_cost, str(card.get("name", card_id))])
	next_state["cards_played_this_turn"] = int(next_state.get("cards_played_this_turn", 0)) + 1
	next_state = _apply_pending_player_trap_restriction(next_state)
	var restrictions: Dictionary = next_state.get("player_turn_restrictions", {})
	if bool(restrictions.get("frozen", false)) or bool(restrictions.get("stunned", false)):
		next_state["cards_played_this_turn"] = _card_play_capacity(next_state)
	return next_state

func resolve_enemy_phase(state: Dictionary) -> Dictionary:
	return (resolve_enemy_phase_with_steps(state).get("state", state.duplicate(true)) as Dictionary).duplicate(true)

func enemy_threat_tiles(state: Dictionary, enemy_index: int) -> Dictionary:
	var enemies: Array = state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return {"move": [], "attack": []}
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	if int(enemy.get("hp", 0)) <= 0:
		return {"move": [], "attack": []}
	var intent: Dictionary = enemy.get("intent", {})
	if intent.is_empty():
		return {"move": [], "attack": []}
	var grid: Array = state.get("grid", [])
	var player_pos: Vector2i = (_normalized_player(state.get("player", {}))).get("pos", Vector2i.ZERO)
	var target: Dictionary = _closest_enemy_target(state, enemy)
	var target_pos: Vector2i = target.get("pos", player_pos)
	var occupied: Dictionary = _enemy_blocking_tiles(state, int(enemy.get("id", -1)))
	for trap_tile_var: Variant in _trap_tiles_lookup(state).keys():
		occupied[trap_tile_var] = true
	var frontier: Array[Vector2i] = _vector2i_values([enemy.get("pos", Vector2i.ZERO)])
	var move_lookup: Dictionary = {}
	var attack_lookup: Dictionary = {}
	for action_var: Variant in intent.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var
		match str(action.get("type", "")):
			"move_toward", "move_away":
				var next_frontier: Array[Vector2i] = []
				var next_lookup: Dictionary = {}
				for start_tile: Vector2i in frontier:
					for move_tile: Vector2i in _threat_movement_tiles(grid, start_tile, target_pos, action, occupied):
						move_lookup[move_tile] = true
						if next_lookup.has(move_tile):
							continue
						next_lookup[move_tile] = true
						next_frontier.append(move_tile)
				if not next_frontier.is_empty():
					frontier = next_frontier
			"melee", "ranged", "aoe", "push", "pull":
				for start_tile: Vector2i in frontier:
					for attack_tile: Vector2i in _threat_attack_tiles(grid, start_tile, action):
						if move_lookup.has(attack_tile):
							continue
						attack_lookup[attack_tile] = true
	return {
		"move": _sorted_tiles_from_lookup(move_lookup),
		"attack": _sorted_tiles_from_lookup(attack_lookup)
	}

func resolve_enemy_phase_with_steps(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.state = int(next_state.get("rng_state", 0))
	var steps: Array[Dictionary] = []
	for enemy_index: int in range((next_state.get("enemies", []) as Array).size()):
		if combat_outcome(next_state) != "":
			break
		var enemy: Dictionary = _normalized_enemy((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			continue
		enemy["block"] = 0
		(next_state.get("enemies", []) as Array)[enemy_index] = enemy
		var turn_setup: Dictionary = _resolve_enemy_start_of_turn(next_state, enemy_index)
		next_state = (turn_setup.get("state", next_state) as Dictionary).duplicate(true)
		for step_var: Variant in turn_setup.get("steps", []):
			steps.append(step_var)
		if combat_outcome(next_state) != "":
			break
		if bool(turn_setup.get("skip_all", false)):
			_assign_enemy_intent(next_state, enemy_index, rng)
			continue
		var shocked: bool = bool(turn_setup.get("shocked", false))
		enemy = _normalized_enemy((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary)
		var intent: Dictionary = enemy.get("intent", {})
		if not intent.is_empty():
			steps.append({
				"kind": "intent",
				"actor_key": _enemy_key(enemy),
				"actor_name": str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")),
				"tile": enemy.get("pos", Vector2i.ZERO),
				"intent_name": str(intent.get("name", "Action"))
			})
			for action: Dictionary in intent.get("actions", []):
				if combat_outcome(next_state) != "":
					break
				if shocked and not _enemy_action_is_movement(action):
					continue
				var before_state: Dictionary = next_state.duplicate(true)
				next_state = _resolve_enemy_action(next_state, enemy_index, action, rng)
				var step: Dictionary = _enemy_action_step(before_state, next_state, enemy_index, action)
				if not step.is_empty():
					steps.append(step)
			_assign_enemy_intent(next_state, enemy_index, rng)
	next_state["rng_state"] = rng.state
	return {
		"state": next_state,
		"steps": steps
	}

func prepare_next_player_turn(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	if combat_outcome(next_state) != "":
		return next_state
	var player: Dictionary = _normalized_player(next_state.get("player", {}))
	player["block"] = 0
	next_state["player"] = player
	next_state["turn"] = int(next_state.get("turn", 1)) + 1
	next_state["cards_played_this_turn"] = 0
	next_state["death_bonus_card_plays_this_turn"] = 0
	next_state["card_play_bonus_this_turn"] = 0
	next_state["player_turn_restrictions"] = {
		"frozen": false,
		"shocked": false,
		"stunned": false
	}
	next_state["pending_player_trap_restriction"] = ""
	next_state["turn_flags"] = {
		"first_attack_bonus_used": false,
		"first_move_bonus_used": false
	}
	next_state = _resolve_player_start_of_turn(next_state)
	if combat_outcome(next_state) != "":
		return next_state
	next_state = _draw_cards_in_place(next_state, int(next_state.get("draw_per_turn", BASE_DRAW_PER_TURN)))
	var restrictions: Dictionary = next_state.get("player_turn_restrictions", {})
	if bool(restrictions.get("frozen", false)) or bool(restrictions.get("stunned", false)):
		next_state["cards_played_this_turn"] = _card_play_capacity(next_state)
	return next_state

func cards_remaining_this_turn(state: Dictionary) -> int:
	return maxi(
		0,
		_card_play_capacity(state) - int(state.get("cards_played_this_turn", 0))
	)

func _card_play_capacity(state: Dictionary) -> int:
	return (
		int(state.get("cards_per_turn", BASE_CARDS_PER_TURN))
		+ int(state.get("death_bonus_card_plays_this_turn", 0))
		+ int(state.get("card_play_bonus_this_turn", 0))
	)

func attack_bonus_for_current_turn(state: Dictionary) -> int:
	return _attack_bonus_for_current_turn(state)

func move_bonus_for_current_turn(state: Dictionary) -> int:
	return _move_bonus_for_current_turn(state)

func aoe_tiles_for_player_action(state: Dictionary, action: Dictionary, target_tile: Vector2i = Vector2i(-1, -1)) -> Array[Vector2i]:
	var player_pos: Vector2i = (_normalized_player(state.get("player", {}))).get("pos", Vector2i.ZERO)
	var center: Vector2i = target_tile if int(action.get("range", 0)) > 0 and target_tile.x >= 0 else player_pos
	return _best_aoe_tiles_for_target(state, action, center, false)

func final_damage_for_player_action(state: Dictionary, action: Dictionary) -> int:
	var action_type: String = str(action.get("type", ""))
	if action_type not in ATTACK_ACTION_TYPES:
		return int(action.get("damage", 0))
	var base_damage: int = int(action.get("damage", 0))
	return maxi(0, base_damage + _attack_bonus_for_current_turn(state))

func damage_modifiers_for_player_action(state: Dictionary, action: Dictionary) -> Array[Dictionary]:
	var modifiers: Array[Dictionary] = []
	var action_type: String = str(action.get("type", ""))
	if action_type not in ATTACK_ACTION_TYPES:
		return modifiers
	var attack_bonus: int = _attack_bonus_for_current_turn(state)
	if attack_bonus != 0:
		modifiers.append({
			"source": "Ember Lens",
			"amount": attack_bonus,
			"detail": "First attack this turn"
		})
	return modifiers

func combat_outcome(state: Dictionary) -> String:
	if int((state.get("player", {}) as Dictionary).get("hp", 0)) <= 0:
		return "defeat"
	if str(state.get("room_type", "")) == "boss":
		for enemy: Dictionary in _live_enemies(state):
			if str(enemy.get("type", "")) == ZEKARION_TYPE:
				return ""
		return "victory"
	if _live_enemies(state).is_empty():
		return "victory"
	return ""

func _resolve_enemy_intent(state: Dictionary, enemy_index: int, intent: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var enemy: Dictionary = ((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary)
	_log(next_state, "%s prepares %s." % [
		str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")),
		str(intent.get("name", "an action"))
	])
	for action: Dictionary in intent.get("actions", []):
		if combat_outcome(next_state) != "":
			break
		next_state = _resolve_enemy_action(next_state, enemy_index, action)
	return next_state

func _enemy_action_step(before_state: Dictionary, after_state: Dictionary, enemy_index: int, action: Dictionary) -> Dictionary:
	var before_enemies: Array = before_state.get("enemies", [])
	var after_enemies: Array = after_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= before_enemies.size() or enemy_index >= after_enemies.size():
		return {}
	var before_enemy: Dictionary = before_enemies[enemy_index]
	var after_enemy: Dictionary = after_enemies[enemy_index]
	var before_player: Dictionary = before_state.get("player", {})
	var after_player: Dictionary = after_state.get("player", {})
	var action_type: String = str(action.get("type", ""))
	var actor_name: String = str(GameData.enemy_def(str(after_enemy.get("type", ""))).get("name", "Enemy"))
	match action_type:
		"move_toward", "move_away":
			var from_tile: Vector2i = before_enemy.get("pos", Vector2i.ZERO)
			var to_tile: Vector2i = after_enemy.get("pos", Vector2i.ZERO)
			if from_tile == to_tile:
				return {}
			return {
				"kind": "move",
				"actor_key": _enemy_key(after_enemy),
				"actor_name": actor_name,
				"from": from_tile,
				"to": to_tile,
				"label": "Advance" if action_type == "move_toward" else "Retreat"
			}
		"block":
			var block_gain: int = int(after_enemy.get("block", 0)) - int(before_enemy.get("block", 0))
			if block_gain <= 0:
				return {}
			return {
				"kind": "block",
				"actor_key": _enemy_key(after_enemy),
				"actor_name": actor_name,
				"tile": after_enemy.get("pos", Vector2i.ZERO),
				"amount": block_gain,
				"sfx_id": str(action.get("sfx_id", action.get("block_sfx_id", ""))),
				"sfx_category": str(action.get("sfx_category", action.get("block_sfx_category", ""))),
				"label": "Guard"
			}
		"stoneskin":
			var skin_gain: int = int(after_enemy.get("stoneskin", 0)) - int(before_enemy.get("stoneskin", 0))
			if skin_gain <= 0:
				return {}
			return {
				"kind": "stoneskin",
				"actor_key": _enemy_key(after_enemy),
				"actor_name": actor_name,
				"tile": after_enemy.get("pos", Vector2i.ZERO),
				"amount": skin_gain,
				"label": "Stoneskin"
			}
		"heal_self":
			var heal_amount: int = int(after_enemy.get("hp", 0)) - int(before_enemy.get("hp", 0))
			if heal_amount <= 0:
				return {}
			return {
				"kind": "heal",
				"actor_key": _enemy_key(after_enemy),
				"actor_name": actor_name,
				"tile": after_enemy.get("pos", Vector2i.ZERO),
				"amount": heal_amount,
				"label": "Heal"
			}
		"melee", "ranged", "aoe", "push", "pull", "lightning_strikes":
			var hp_loss: int = int(before_player.get("hp", 0)) - int(after_player.get("hp", 0))
			var block_loss: int = int(before_player.get("block", 0)) - int(after_player.get("block", 0))
			var stoneskin_loss: int = int(before_player.get("stoneskin", 0)) - int(after_player.get("stoneskin", 0))
			var target_losses: Array[Dictionary] = _actor_target_losses(before_state, after_state)
			var moved: bool = before_player.get("pos", Vector2i.ZERO) != after_player.get("pos", Vector2i.ZERO)
			var status_text: String = _player_status_step_text(before_player, after_player, action)
			if target_losses.is_empty() and not moved and status_text.is_empty() and action_type != "lightning_strikes":
				return {}
			var target_tile: Vector2i = after_player.get("pos", Vector2i.ZERO)
			if not target_losses.is_empty():
				target_tile = (target_losses[0] as Dictionary).get("tile", target_tile)
			var center_tile: Vector2i = target_tile
			if action_type == "aoe" and int(action.get("range", 0)) <= 0:
				center_tile = before_enemy.get("pos", Vector2i.ZERO)
			var aoe_tiles: Array[Vector2i] = []
			if action_type == "aoe":
				aoe_tiles = _best_aoe_tiles_for_target(before_state, action, center_tile, true)
			elif action_type == "lightning_strikes":
				aoe_tiles = _lightning_strike_tiles(before_state, before_enemy, action)
			return {
				"kind": action_type,
				"actor_key": _enemy_key(after_enemy),
				"actor_name": actor_name,
				"from": after_enemy.get("pos", Vector2i.ZERO),
				"to": target_tile,
				"player_from": before_player.get("pos", Vector2i.ZERO),
				"player_to": after_player.get("pos", Vector2i.ZERO),
				"center": center_tile,
				"tiles": aoe_tiles,
				"amount": _target_loss_amount(target_losses),
				"hp_loss": hp_loss,
				"block_loss": block_loss,
				"stoneskin_loss": stoneskin_loss,
				"target_losses": target_losses,
				"impact_actor_keys": _target_loss_keys(target_losses),
				"status_text": status_text,
				"range": int(action.get("range", 0)),
				"sfx_id": str(action.get("sfx_id", action.get("attack_sfx_id", ""))),
				"sfx_category": str(action.get("sfx_category", action.get("attack_sfx_category", ""))),
				"label": "Strike" if action_type == "melee" else "Shot" if action_type == "ranged" else "Storm" if action_type == "lightning_strikes" else "Area" if action_type == "aoe" else "Push" if action_type == "push" else "Pull"
			}
		"summon_minions":
			var before_count: int = before_enemies.size()
			var after_count: int = after_enemies.size()
			if after_count <= before_count:
				return {}
			return {
				"kind": "summon",
				"actor_key": _enemy_key(after_enemy),
				"actor_name": actor_name,
				"tile": after_enemy.get("pos", Vector2i.ZERO),
				"amount": after_count - before_count,
				"label": "Summon"
			}
		_:
			return {}

func _actor_target_losses(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var losses: Array[Dictionary] = []
	var before_player: Dictionary = _normalized_player(before_state.get("player", {}))
	var after_player: Dictionary = _normalized_player(after_state.get("player", {}))
	var player_hp_loss: int = maxi(0, int(before_player.get("hp", 0)) - int(after_player.get("hp", 0)))
	var player_block_loss: int = maxi(0, int(before_player.get("block", 0)) - int(after_player.get("block", 0)))
	var player_stoneskin_loss: int = maxi(0, int(before_player.get("stoneskin", 0)) - int(after_player.get("stoneskin", 0)))
	if player_hp_loss > 0 or player_block_loss > 0 or player_stoneskin_loss > 0:
		losses.append({
			"key": "player",
			"kind": "player",
			"tile": after_player.get("pos", before_player.get("pos", Vector2i.ZERO)),
			"hp_loss": player_hp_loss,
			"block_loss": player_block_loss,
			"stoneskin_loss": player_stoneskin_loss,
			"amount": player_hp_loss + player_block_loss + player_stoneskin_loss
		})
	var after_illusions_by_id: Dictionary = {}
	for after_illusion_var: Variant in after_state.get("illusions", []):
		if typeof(after_illusion_var) != TYPE_DICTIONARY:
			continue
		var after_illusion: Dictionary = _normalized_illusion(after_illusion_var as Dictionary)
		after_illusions_by_id[int(after_illusion.get("id", -1))] = after_illusion
	for before_illusion_var: Variant in before_state.get("illusions", []):
		if typeof(before_illusion_var) != TYPE_DICTIONARY:
			continue
		var before_illusion: Dictionary = _normalized_illusion(before_illusion_var as Dictionary)
		if int(before_illusion.get("hp", 0)) <= 0:
			continue
		var illusion_id: int = int(before_illusion.get("id", -1))
		var after_illusion: Dictionary = after_illusions_by_id.get(illusion_id, before_illusion)
		var hp_loss: int = maxi(0, int(before_illusion.get("hp", 0)) - int(after_illusion.get("hp", 0)))
		if hp_loss <= 0:
			continue
		losses.append({
			"key": _illusion_key(before_illusion),
			"kind": "illusion",
			"id": illusion_id,
			"tile": after_illusion.get("pos", before_illusion.get("pos", Vector2i.ZERO)),
			"hp_loss": hp_loss,
			"block_loss": 0,
			"stoneskin_loss": 0,
			"amount": hp_loss
		})
	return losses

func _target_loss_amount(target_losses: Array[Dictionary]) -> int:
	var total: int = 0
	for loss: Dictionary in target_losses:
		total += int(loss.get("amount", 0))
	return total

func _target_loss_keys(target_losses: Array[Dictionary]) -> Array[String]:
	var keys: Array[String] = []
	for loss: Dictionary in target_losses:
		var key: String = str(loss.get("key", ""))
		if not key.is_empty() and not keys.has(key):
			keys.append(key)
	return keys

func _enemy_key(enemy: Dictionary) -> String:
	return "enemy_%d" % int(enemy.get("id", -1))

func _actor_targets(state: Dictionary) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	var player: Dictionary = _normalized_player(state.get("player", {}))
	if int(player.get("hp", 0)) > 0:
		targets.append({
			"kind": "player",
			"key": "player",
			"pos": player.get("pos", Vector2i.ZERO),
			"hp": int(player.get("hp", 0))
		})
	for illusion: Dictionary in _live_illusions(state):
		targets.append({
			"kind": "illusion",
			"key": _illusion_key(illusion),
			"id": int(illusion.get("id", -1)),
			"pos": illusion.get("pos", Vector2i.ZERO),
			"hp": int(illusion.get("hp", 0))
		})
	return targets

func _closest_enemy_target(state: Dictionary, enemy: Dictionary) -> Dictionary:
	var best_target: Dictionary = {}
	var best_distance: int = 9999
	for target: Dictionary in _actor_targets(state):
		var target_pos: Vector2i = target.get("pos", Vector2i.ZERO)
		var distance: int = _enemy_distance_to_tile(enemy, target_pos)
		if distance < best_distance:
			best_distance = distance
			best_target = target
	return best_target

func _closest_enemy_target_for_action(state: Dictionary, enemy: Dictionary, action: Dictionary) -> Dictionary:
	var best_target: Dictionary = {}
	var best_distance: int = 9999
	for target: Dictionary in _actor_targets(state):
		if not _enemy_action_reaches_target(state, enemy, action, target):
			continue
		var target_pos: Vector2i = target.get("pos", Vector2i.ZERO)
		var distance: int = _enemy_distance_to_tile(enemy, target_pos)
		if distance < best_distance:
			best_distance = distance
			best_target = target
	return best_target

func _enemy_action_reaches_target(state: Dictionary, enemy: Dictionary, action: Dictionary, target: Dictionary) -> bool:
	var action_type: String = str(action.get("type", ""))
	var target_pos: Vector2i = target.get("pos", Vector2i.ZERO)
	var source_pos: Vector2i = _closest_enemy_tile_to(enemy, target_pos)
	match action_type:
		"melee":
			return _enemy_distance_to_tile(enemy, target_pos) <= int(action.get("range", 1))
		"ranged":
			return (
				PathUtils.manhattan(source_pos, target_pos) <= int(action.get("range", 1))
				and PathUtils.has_line_of_sight(state.get("grid", []), source_pos, target_pos)
			)
		"push", "pull":
			var max_range: int = int(action.get("range", 1))
			return (
				PathUtils.manhattan(source_pos, target_pos) <= max_range
				and (max_range <= 1 or PathUtils.has_line_of_sight(state.get("grid", []), source_pos, target_pos))
			)
		"aoe":
			var center: Vector2i = enemy.get("pos", Vector2i.ZERO)
			if int(action.get("range", 0)) > 0:
				if PathUtils.manhattan(source_pos, target_pos) > int(action.get("range", 0)):
					return false
				if not PathUtils.has_line_of_sight(state.get("grid", []), source_pos, target_pos):
					return false
				center = target_pos
			return _best_aoe_tiles_for_target(state, action, center, true).has(target_pos)
	return false

func _actor_targets_in_tiles(state: Dictionary, tiles: Array[Vector2i]) -> Array[Dictionary]:
	var tile_lookup: Dictionary = {}
	for tile: Vector2i in tiles:
		tile_lookup[tile] = true
	var targets: Array[Dictionary] = []
	for target: Dictionary in _actor_targets(state):
		if tile_lookup.has(target.get("pos", Vector2i.ZERO)):
			targets.append(target)
	return targets

func _damage_actor_target(state: Dictionary, target: Dictionary, damage: int, bypass_block: bool) -> Dictionary:
	if damage <= 0:
		return state
	match str(target.get("kind", "")):
		"player":
			return _damage_player(state, damage, bypass_block)
		"illusion":
			return _damage_illusion(state, int(target.get("id", -1)), damage)
	return state

func _apply_action_keywords_to_target(state: Dictionary, target: Dictionary, action: Dictionary, source_pos: Vector2i) -> Dictionary:
	if str(target.get("kind", "")) != "player":
		return state
	return _apply_action_keywords_to_player(state, action, source_pos)

func _resolve_enemy_action(state: Dictionary, enemy_index: int, action: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	if int(enemy.get("hp", 0)) <= 0:
		return next_state
	var player: Dictionary = _normalized_player(next_state.get("player", {}))
	var player_pos: Vector2i = player.get("pos", Vector2i.ZERO)
	var target: Dictionary = _closest_enemy_target(next_state, enemy)
	var target_pos: Vector2i = target.get("pos", player_pos)
	var action_type: String = str(action.get("type", ""))
	match action_type:
		"move_toward":
			var toward_tile: Vector2i = _best_move_toward(next_state, enemy_index, target_pos, int(action.get("range", 0)))
			enemy["pos"] = toward_tile
			enemies[enemy_index] = enemy
			_log(next_state, "%s closes in." % str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")))
		"move_away":
			var away_tile: Vector2i = _best_move_away(next_state, enemy_index, target_pos, int(action.get("range", 0)))
			enemy["pos"] = away_tile
			enemies[enemy_index] = enemy
			_log(next_state, "%s falls back." % str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")))
		"block":
			enemies[enemy_index] = enemy
		"stoneskin":
			enemy["stoneskin"] = int(enemy.get("stoneskin", 0)) + int(action.get("amount", 0))
			enemies[enemy_index] = enemy
			_log(next_state, "%s hardens for %d stoneskin." % [
				str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")),
				int(action.get("amount", 0))
			])
		"heal_self":
			enemy["hp"] = mini(int(enemy.get("max_hp", 1)), int(enemy.get("hp", 0)) + int(action.get("amount", 0)))
			enemies[enemy_index] = enemy
			_log(next_state, "%s recovers %d health." % [
				str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")),
				int(action.get("amount", 0))
			])
		"melee":
			next_state = _enemy_attack_target(next_state, enemy_index, action, "hits")
		"ranged":
			next_state = _enemy_attack_target(next_state, enemy_index, action, "fires")
		"aoe":
			next_state = _enemy_attack_target(next_state, enemy_index, action, "sweeps the area")
		"lightning_strikes":
			next_state = _enemy_lightning_strikes(next_state, enemy_index, action)
		"push":
			next_state = _enemy_push_or_pull_target(next_state, enemy_index, action, true)
		"pull":
			next_state = _enemy_push_or_pull_target(next_state, enemy_index, action, false)
		"summon_minions":
			next_state = _enemy_summon_minions(next_state, enemy_index, action, rng)
	return next_state

func _attack_enemy_on_tile(state: Dictionary, action: Dictionary, target_tile: Vector2i, attack_kind: String) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var enemy_index: int = _enemy_index_at_tile(next_state, target_tile)
	if enemy_index < 0:
		return next_state
	var damage: int = final_damage_for_player_action(next_state, action)
	if damage > 0 or _action_has_keyword_effect(action):
		if _attack_bonus_for_current_turn(next_state) > 0 and int(action.get("damage", 0)) > 0:
			_mark_first_attack_used(next_state)
		next_state = _damage_enemy(next_state, enemy_index, damage)
		next_state = _apply_action_keywords_to_enemy(next_state, enemy_index, action, next_state.get("player", {}).get("pos", Vector2i.ZERO))
		next_state = _apply_chain_from_enemy(next_state, enemy_index, action, damage)
		_log(next_state, "%s for %d." % [attack_kind.capitalize(), damage])
	return next_state

func _aoe_enemies(state: Dictionary, action: Dictionary, target_tile: Vector2i) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var player_pos: Vector2i = (_normalized_player(next_state.get("player", {}))).get("pos", Vector2i.ZERO)
	var center: Vector2i = target_tile if int(action.get("range", 0)) > 0 and target_tile.x >= 0 else player_pos
	if int(action.get("range", 0)) > 0 and not valid_targets_for_player_action(next_state, action).has(center):
		return next_state
	var affected: Array[int] = _enemy_indices_in_tiles(next_state, _best_aoe_tiles_for_target(next_state, action, center, false))
	if affected.is_empty():
		return next_state
	var damage: int = final_damage_for_player_action(next_state, action)
	if _attack_bonus_for_current_turn(next_state) > 0 and int(action.get("damage", 0)) > 0:
		_mark_first_attack_used(next_state)
	for enemy_index: int in affected:
		next_state = _damage_enemy(next_state, enemy_index, damage)
		next_state = _apply_action_keywords_to_enemy(next_state, enemy_index, action, next_state.get("player", {}).get("pos", Vector2i.ZERO))
	_log(next_state, "Area attack hits %d foe(s) for %d." % [affected.size(), damage])
	return next_state

func _damage_enemy(state: Dictionary, enemy_index: int, damage: int, apply_freeze_multiplier: bool = true) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var was_alive: bool = int(enemy.get("hp", 0)) > 0
	var total_damage: int = damage
	if apply_freeze_multiplier and int(enemy.get("freeze", 0)) > 0:
		total_damage *= 2
	var block_amount: int = int(enemy.get("block", 0))
	var applied_to_block: int = mini(block_amount, total_damage)
	block_amount -= applied_to_block
	var remaining: int = total_damage - applied_to_block
	var stoneskin_amount: int = int(enemy.get("stoneskin", 0))
	var applied_to_stoneskin: int = mini(stoneskin_amount, remaining)
	stoneskin_amount -= applied_to_stoneskin
	remaining -= applied_to_stoneskin
	enemy["block"] = block_amount
	enemy["stoneskin"] = stoneskin_amount
	enemy["hp"] = maxi(0, int(enemy.get("hp", 0)) - remaining)
	enemies[enemy_index] = enemy
	if was_alive and int(enemy.get("hp", 0)) <= 0:
		var reward_embers: int = int(GameData.enemy_def(str(enemy.get("type", ""))).get("reward_embers", 0))
		var bonus_card_plays: int = 0 if bool(enemy.get("summoned", false)) else 1
		next_state["room_embers"] = int(next_state.get("room_embers", 0)) + reward_embers
		next_state["death_bonus_card_plays_this_turn"] = int(next_state.get("death_bonus_card_plays_this_turn", 0)) + bonus_card_plays
		_record_death_reward(next_state, enemy, reward_embers, bonus_card_plays)
		_log(next_state, "%s falls." % str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")))
	return next_state

func _record_death_reward(state: Dictionary, enemy: Dictionary, embers: int, card_plays: int) -> void:
	var rewards: Array = state.get("death_rewards", []).duplicate(true)
	rewards.append({
		"enemy_id": int(enemy.get("id", -1)),
		"actor_key": _enemy_key(enemy),
		"type": str(enemy.get("type", "")),
		"tile": enemy.get("pos", Vector2i.ZERO),
		"embers": maxi(0, embers),
		"card_plays": maxi(0, card_plays),
		"summoned": bool(enemy.get("summoned", false))
	})
	state["death_rewards"] = rewards

func _damage_player(state: Dictionary, damage: int, bypass_block: bool, apply_freeze_multiplier: bool = true) -> Dictionary:
	var next_state: Dictionary = state
	var player: Dictionary = _normalized_player(next_state.get("player", {}))
	var remaining: int = damage * 2 if apply_freeze_multiplier and int(player.get("freeze", 0)) > 0 else damage
	if not bypass_block:
		var block_amount: int = int(player.get("block", 0))
		var applied_to_block: int = mini(block_amount, remaining)
		block_amount -= applied_to_block
		remaining -= applied_to_block
		player["block"] = block_amount
		var stoneskin_amount: int = int(player.get("stoneskin", 0))
		var applied_to_stoneskin: int = mini(stoneskin_amount, remaining)
		stoneskin_amount -= applied_to_stoneskin
		remaining -= applied_to_stoneskin
		player["stoneskin"] = stoneskin_amount
	player["hp"] = maxi(0, int(player.get("hp", 0)) - remaining)
	next_state["player"] = player
	return next_state

func _lose_player_health(state: Dictionary, amount: int, bypass_block: bool, apply_freeze_multiplier: bool = true) -> Dictionary:
	return _damage_player(state, amount, bypass_block, apply_freeze_multiplier)

func _damage_illusion(state: Dictionary, illusion_id: int, damage: int) -> Dictionary:
	var next_state: Dictionary = state
	if damage <= 0:
		return next_state
	var illusions: Array = next_state.get("illusions", []).duplicate(true)
	for index: int in range(illusions.size()):
		if typeof(illusions[index]) != TYPE_DICTIONARY:
			continue
		var illusion: Dictionary = _normalized_illusion(illusions[index] as Dictionary)
		if int(illusion.get("id", -1)) != illusion_id:
			continue
		var was_alive: bool = int(illusion.get("hp", 0)) > 0
		illusion["hp"] = maxi(0, int(illusion.get("hp", 0)) - damage)
		illusions[index] = illusion
		next_state["illusions"] = illusions
		if was_alive and int(illusion.get("hp", 0)) <= 0:
			_log(next_state, "Illusion fades.")
		return next_state
	return next_state

func _create_illusion(state: Dictionary, pos: Vector2i, health: int) -> Dictionary:
	var next_state: Dictionary = state
	var illusion_health: int = maxi(1, health)
	var illusions: Array = next_state.get("illusions", []).duplicate(true)
	var illusion_id: int = int(next_state.get("next_illusion_id", 1))
	illusions.append({
		"id": illusion_id,
		"pos": pos,
		"hp": illusion_health,
		"max_hp": illusion_health
	})
	next_state["illusions"] = illusions
	next_state["next_illusion_id"] = illusion_id + 1
	_log(next_state, "Illusion appears.")
	return next_state

func _normalized_player(player_value: Variant) -> Dictionary:
	return _normalized_unit(player_value)

func _normalized_illusion(illusion_value: Variant) -> Dictionary:
	var illusion: Dictionary = {}
	if typeof(illusion_value) == TYPE_DICTIONARY:
		illusion = (illusion_value as Dictionary).duplicate(true)
	illusion["id"] = int(illusion.get("id", -1))
	illusion["pos"] = illusion.get("pos", Vector2i.ZERO)
	illusion["hp"] = int(illusion.get("hp", 0))
	illusion["max_hp"] = maxi(1, int(illusion.get("max_hp", illusion.get("hp", 1))))
	return illusion

func _normalized_enemy(enemy_value: Variant) -> Dictionary:
	var enemy: Dictionary = _normalized_unit(enemy_value)
	if not enemy.has("element"):
		enemy["element"] = ElementData.NONE
	if not enemy.has("footprint"):
		var footprint_value: Variant = GameData.enemy_def(str(enemy.get("type", ""))).get("footprint", [])
		if typeof(footprint_value) == TYPE_ARRAY and (footprint_value as Array).size() >= 2:
			enemy["footprint"] = Vector2i(int((footprint_value as Array)[0]), int((footprint_value as Array)[1]))
	var footprint: Vector2i = enemy.get("footprint", Vector2i.ONE)
	enemy["footprint"] = Vector2i(maxi(1, footprint.x), maxi(1, footprint.y))
	for status_id: String in _enemy_status_immunities(enemy):
		enemy[status_id] = 0
	return enemy

func _normalized_unit(unit_value: Variant) -> Dictionary:
	var unit: Dictionary = {}
	if typeof(unit_value) == TYPE_DICTIONARY:
		unit = (unit_value as Dictionary).duplicate(true)
	unit["block"] = int(unit.get("block", 0))
	unit["stoneskin"] = int(unit.get("stoneskin", 0))
	unit["burn"] = int(unit.get("burn", 0))
	unit["freeze"] = int(unit.get("freeze", 0))
	unit["shock"] = int(unit.get("shock", 0))
	unit["stun"] = int(unit.get("stun", 0))
	var poison_value: Variant = unit.get("poison", {})
	var poison: Dictionary = {}
	if typeof(poison_value) == TYPE_DICTIONARY:
		poison = (poison_value as Dictionary).duplicate(true)
	unit["poison"] = {
		"damage": int(poison.get("damage", 0)),
		"delay": int(poison.get("delay", 0))
	}
	return unit

func _enemy_status_immunities(enemy: Dictionary) -> Array[String]:
	var immunities: Array[String] = []
	var raw_immunities: Variant = GameData.enemy_def(str(enemy.get("type", ""))).get("status_immunities", [])
	if typeof(raw_immunities) != TYPE_ARRAY:
		return immunities
	for immunity_var: Variant in raw_immunities:
		var status_id: String = str(immunity_var)
		if not status_id.is_empty() and not immunities.has(status_id):
			immunities.append(status_id)
	return immunities

func _enemy_is_immune_to_status(enemy: Dictionary, status_id: String) -> bool:
	return _enemy_status_immunities(enemy).has(status_id)

func _action_has_keyword_effect(action: Dictionary) -> bool:
	return (
		int(action.get("burn", 0)) > 0
		or int(action.get("freeze", 0)) > 0
		or int(action.get("shock", 0)) > 0
		or int(action.get("stun", 0)) > 0
		or int(action.get("poison", 0)) > 0
		or int(action.get("push", 0)) > 0
		or int(action.get("pull", 0)) > 0
		or int(action.get("chain", 0)) > 0
	)

func _apply_action_keywords_to_enemy(state: Dictionary, enemy_index: int, action: Dictionary, source_pos: Vector2i) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	if int(enemy.get("hp", 0)) <= 0:
		return next_state
	if int(action.get("burn", 0)) > 0:
		enemy["burn"] = int(enemy.get("burn", 0)) + int(action.get("burn", 0))
	if int(action.get("freeze", 0)) > 0:
		enemy["freeze"] = maxi(int(enemy.get("freeze", 0)), int(action.get("freeze", 0)))
	if int(action.get("shock", 0)) > 0 and not _enemy_is_immune_to_status(enemy, "shock"):
		enemy["shock"] = maxi(int(enemy.get("shock", 0)), int(action.get("shock", 0)))
	if int(action.get("stun", 0)) > 0:
		enemy["stun"] = maxi(int(enemy.get("stun", 0)), int(action.get("stun", 0)))
	if int(action.get("poison", 0)) > 0:
		var poison: Dictionary = enemy.get("poison", {}).duplicate(true)
		poison["damage"] = int(poison.get("damage", 0)) + int(action.get("poison", 0))
		poison["delay"] = 2
		enemy["poison"] = poison
	enemies[enemy_index] = enemy
	next_state["enemies"] = enemies
	if int(action.get("push", 0)) > 0:
		next_state = _move_enemy_from_source(next_state, enemy_index, source_pos, int(action.get("push", 0)), true)
	elif int(action.get("pull", 0)) > 0:
		next_state = _move_enemy_from_source(next_state, enemy_index, source_pos, int(action.get("pull", 0)), false)
	return next_state

func _apply_action_keywords_to_player(state: Dictionary, action: Dictionary, source_pos: Vector2i) -> Dictionary:
	var next_state: Dictionary = state
	var player: Dictionary = _normalized_player(next_state.get("player", {}))
	if int(action.get("burn", 0)) > 0:
		player["burn"] = int(player.get("burn", 0)) + int(action.get("burn", 0))
	if int(action.get("freeze", 0)) > 0:
		player["freeze"] = maxi(int(player.get("freeze", 0)), int(action.get("freeze", 0)))
	if int(action.get("shock", 0)) > 0:
		player["shock"] = maxi(int(player.get("shock", 0)), int(action.get("shock", 0)))
	if int(action.get("stun", 0)) > 0:
		player["stun"] = maxi(int(player.get("stun", 0)), int(action.get("stun", 0)))
	if int(action.get("poison", 0)) > 0:
		var poison: Dictionary = player.get("poison", {}).duplicate(true)
		poison["damage"] = int(poison.get("damage", 0)) + int(action.get("poison", 0))
		poison["delay"] = 2
		player["poison"] = poison
	next_state["player"] = player
	if int(action.get("push", 0)) > 0:
		next_state = _move_player_from_source(next_state, source_pos, int(action.get("push", 0)), true)
	elif int(action.get("pull", 0)) > 0:
		next_state = _move_player_from_source(next_state, source_pos, int(action.get("pull", 0)), false)
	return next_state

func _apply_chain_from_enemy(state: Dictionary, initial_enemy_index: int, action: Dictionary, damage: int) -> Dictionary:
	var max_distance: int = int(action.get("chain", 0))
	if max_distance <= 0:
		return state
	var next_state: Dictionary = state
	var visited: Dictionary = {}
	var current_index: int = initial_enemy_index
	visited[current_index] = true
	while true:
		var current_enemy: Dictionary = _normalized_enemy(((next_state.get("enemies", []) as Array)[current_index] as Dictionary))
		var next_index: int = _nearest_chain_target(next_state, current_enemy.get("pos", Vector2i.ZERO), visited, max_distance)
		if next_index < 0:
			break
		visited[next_index] = true
		next_state = _damage_enemy(next_state, next_index, damage)
		next_state = _apply_action_keywords_to_enemy(next_state, next_index, action, current_enemy.get("pos", Vector2i.ZERO))
		current_index = next_index
	return next_state

func _nearest_chain_target(state: Dictionary, from_tile: Vector2i, visited: Dictionary, max_distance: int) -> int:
	var best_index: int = -1
	var best_distance: int = 9999
	var enemies: Array = state.get("enemies", [])
	for index: int in range(enemies.size()):
		if visited.has(index):
			continue
		var enemy: Dictionary = _normalized_enemy(enemies[index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			continue
		var distance: int = PathUtils.manhattan(from_tile, enemy.get("pos", Vector2i.ZERO))
		if distance > max_distance:
			continue
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index

func _enemy_attack_target(state: Dictionary, enemy_index: int, action: Dictionary, verb: String) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var action_type: String = str(action.get("type", ""))
	var target: Dictionary = _closest_enemy_target_for_action(next_state, enemy, action)
	if target.is_empty():
		return next_state
	var damage: int = int(action.get("damage", 0))
	if action_type == "aoe":
		var center: Vector2i = enemy.get("pos", Vector2i.ZERO)
		if int(action.get("range", 0)) > 0:
			center = target.get("pos", Vector2i.ZERO)
		var affected_targets: Array[Dictionary] = _actor_targets_in_tiles(next_state, _best_aoe_tiles_for_target(next_state, action, center, true))
		if affected_targets.is_empty():
			return next_state
		for affected_target: Dictionary in affected_targets:
			if damage > 0:
				next_state = _damage_actor_target(next_state, affected_target, damage, false)
			next_state = _apply_action_keywords_to_target(next_state, affected_target, action, _closest_enemy_tile_to(enemy, affected_target.get("pos", Vector2i.ZERO)))
	else:
		if damage > 0:
			next_state = _damage_actor_target(next_state, target, damage, false)
		next_state = _apply_action_keywords_to_target(next_state, target, action, _closest_enemy_tile_to(enemy, target.get("pos", Vector2i.ZERO)))
	_log(next_state, "%s %s for %d." % [
		str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")),
		verb,
		damage
	])
	next_state = _apply_enemy_self_damage(next_state, enemy_index, int(action.get("self_damage", 0)))
	return next_state

func _enemy_push_or_pull_target(state: Dictionary, enemy_index: int, action: Dictionary, pushing: bool) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var target: Dictionary = _closest_enemy_target_for_action(next_state, enemy, action)
	if target.is_empty():
		return next_state
	var target_pos: Vector2i = target.get("pos", Vector2i.ZERO)
	var source_pos: Vector2i = _closest_enemy_tile_to(enemy, target_pos)
	var damage: int = int(action.get("damage", 0))
	if damage > 0:
		next_state = _damage_actor_target(next_state, target, damage, false)
	if str(target.get("kind", "")) == "player":
		next_state = _move_player_from_source(next_state, source_pos, int(action.get("amount", 0)), pushing)
	next_state = _apply_action_keywords_to_target(next_state, target, action, source_pos)
	next_state = _apply_enemy_self_damage(next_state, enemy_index, int(action.get("self_damage", 0)))
	_log(next_state, "%s %s." % [
		str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")),
		"batters the line" if pushing else "drags inward"
	])
	return next_state

func _enemy_lightning_strikes(state: Dictionary, enemy_index: int, action: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var strike_tiles: Array[Vector2i] = _lightning_strike_tiles(next_state, enemy, action)
	for target: Dictionary in _actor_targets_in_tiles(next_state, strike_tiles):
		next_state = _damage_actor_target(next_state, target, int(action.get("damage", 0)), false)
		next_state = _apply_action_keywords_to_target(next_state, target, action, _closest_enemy_tile_to(enemy, target.get("pos", Vector2i.ZERO)))
	_log(next_state, "%s calls down the storm." % str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")))
	return next_state

func _enemy_summon_minions(state: Dictionary, enemy_index: int, action: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", []).duplicate(true)
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var minion_type: String = str(action.get("minion_type", LIGHTNING_WISP_TYPE))
	var count: int = int(action.get("count", 2))
	var spawn_tiles: Array[Vector2i] = _summon_tiles_for_enemy(next_state, enemy, count)
	var first_minion_index: int = enemies.size()
	var next_id: int = _next_enemy_id(next_state)
	for tile: Vector2i in spawn_tiles:
		var definition: Dictionary = GameData.enemy_def(minion_type)
		var minion: Dictionary = {
			"id": next_id,
			"type": minion_type,
			"summoned": true,
			"element": str(next_state.get("room_element", ElementData.NONE)),
			"pos": tile,
			"hp": int(definition.get("max_hp", 1)),
			"max_hp": int(definition.get("max_hp", 1)),
			"block": 0,
			"stoneskin": 0
		}
		enemies.append(minion)
		next_id += 1
	next_state["enemies"] = enemies
	var intent_rng: RandomNumberGenerator = rng
	if intent_rng == null:
		intent_rng = RandomNumberGenerator.new()
		intent_rng.state = int(next_state.get("rng_state", 1))
	for minion_index: int in range(first_minion_index, first_minion_index + spawn_tiles.size()):
		_assign_enemy_intent(next_state, minion_index, intent_rng)
	if rng == null:
		next_state["rng_state"] = intent_rng.state
	_log(next_state, "%s summons lightning wisps." % str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")))
	return next_state

func _push_or_pull_enemy(state: Dictionary, action: Dictionary, target_tile: Vector2i, pushing: bool) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var enemy_index: int = _enemy_index_at_tile(next_state, target_tile)
	if enemy_index < 0:
		return next_state
	var damage: int = final_damage_for_player_action(next_state, action)
	if _attack_bonus_for_current_turn(next_state) > 0 and int(action.get("damage", 0)) > 0:
		_mark_first_attack_used(next_state)
	if damage > 0:
		next_state = _damage_enemy(next_state, enemy_index, damage)
	if int(((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary).get("hp", 0)) <= 0:
		return next_state
	next_state = _apply_action_keywords_to_enemy(next_state, enemy_index, action, (next_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO))
	next_state = _move_enemy_from_source(next_state, enemy_index, (next_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO), int(action.get("amount", 0)), pushing)
	_log(next_state, "%s %d." % ["Push" if pushing else "Pull", int(action.get("amount", 0))])
	return next_state

func _move_enemy_from_source(state: Dictionary, enemy_index: int, source_pos: Vector2i, amount: int, pushing: bool) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size() or amount <= 0:
		return next_state
	for _step: int in range(amount):
		enemies = next_state.get("enemies", [])
		var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			break
		var current: Vector2i = enemy.get("pos", Vector2i.ZERO)
		var occupied: Dictionary = _enemy_blocking_tiles(next_state, int(enemy.get("id", -1)))
		var player_pos: Vector2i = (next_state.get("player", {}) as Dictionary).get("pos", Vector2i(-99, -99))
		var candidate: Vector2i = (
			_next_tile_away_from_source(next_state.get("grid", []), current, source_pos, occupied, player_pos)
			if pushing
			else _next_tile_toward_source(next_state.get("grid", []), current, source_pos, occupied)
		)
		if candidate == current:
			break
		if not _enemy_can_occupy_anchor(next_state, enemy, candidate, occupied, player_pos):
			break
		enemy["pos"] = candidate
		enemies[enemy_index] = enemy
		next_state["enemies"] = enemies
		next_state = _trigger_trap_on_enemy(next_state, enemy_index)
		if int(((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary).get("hp", 0)) <= 0:
			break
	return next_state

func _move_player_from_source(state: Dictionary, source_pos: Vector2i, amount: int, pushing: bool) -> Dictionary:
	var next_state: Dictionary = state
	if amount <= 0:
		return next_state
	for _step: int in range(amount):
		var player: Dictionary = _normalized_player(next_state.get("player", {}))
		var current: Vector2i = player.get("pos", Vector2i.ZERO)
		var enemy_occupied: Dictionary = _occupied_actor_tiles(next_state)
		var next_tile: Vector2i = (
			_next_tile_away_from_source(next_state.get("grid", []), current, source_pos, enemy_occupied, Vector2i(-99, -99))
			if pushing
			else _next_tile_toward_source(next_state.get("grid", []), current, source_pos, enemy_occupied)
		)
		if next_tile == current:
			break
		player["pos"] = next_tile
		next_state["player"] = player
		_collect_loot_at_player(next_state)
		next_state = _trigger_trap_on_player(next_state)
		if int((next_state.get("player", {}) as Dictionary).get("hp", 0)) <= 0:
			break
	return next_state

func _move_player_along_path(state: Dictionary, path: Array[Vector2i]) -> Dictionary:
	var next_state: Dictionary = state
	if path.size() <= 1:
		return next_state
	for step_index: int in range(1, path.size()):
		var player: Dictionary = _normalized_player(next_state.get("player", {}))
		player["pos"] = path[step_index]
		next_state["player"] = player
		_collect_loot_at_player(next_state)
		next_state = _trigger_trap_on_player(next_state)
		if int((next_state.get("player", {}) as Dictionary).get("hp", 0)) <= 0:
			break
	return next_state

func _actual_player_movement_path(state: Dictionary, start: Vector2i, goal: Vector2i, max_distance: int) -> Array[Vector2i]:
	if max_distance <= 0:
		return []
	return _lowest_trap_path(
		state.get("grid", []),
		start,
		goal,
		max_distance,
		_occupied_actor_tiles(state),
		_trap_tiles_lookup(state)
	)

func _lowest_trap_path(grid: Array, start: Vector2i, goal: Vector2i, max_distance: int, occupied: Dictionary, trap_tiles: Dictionary) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if start == goal:
		return _vector2i_values([start])
	if max_distance <= 0:
		return empty
	var grid_height: int = grid.size()
	var grid_width: int = (grid[0] as Array).size() if grid_height > 0 else 0
	var trap_weight: int = grid_height * maxi(1, grid_width) + 1
	var frontier: Array[Vector2i] = _vector2i_values([start])
	var came_from: Dictionary = {start: start}
	var step_costs: Dictionary = {start: 0}
	var path_costs: Dictionary = {start: 0}
	while not frontier.is_empty():
		var best_index: int = 0
		var best_tile: Vector2i = frontier[0]
		var best_cost: int = int(path_costs.get(best_tile, 0))
		for index: int in range(1, frontier.size()):
			var candidate: Vector2i = frontier[index]
			var candidate_cost: int = int(path_costs.get(candidate, 0))
			if candidate_cost < best_cost:
				best_index = index
				best_tile = candidate
				best_cost = candidate_cost
		var current: Vector2i = best_tile
		frontier.remove_at(best_index)
		if current == goal:
			break
		var current_steps: int = int(step_costs.get(current, 0))
		if current_steps >= max_distance:
			continue
		for dir: Vector2i in PathUtils.DIRS_4:
			var next_tile: Vector2i = current + dir
			if not PathUtils.is_passable(grid, next_tile):
				continue
			if occupied.has(next_tile) and next_tile != goal:
				continue
			var next_steps: int = current_steps + 1
			if next_steps > max_distance:
				continue
			var trap_cost: int = trap_weight if trap_tiles.has(next_tile) else 0
			var next_cost: int = best_cost + trap_cost + 1
			if path_costs.has(next_tile) and next_cost >= int(path_costs.get(next_tile, 0)):
				continue
			path_costs[next_tile] = next_cost
			step_costs[next_tile] = next_steps
			came_from[next_tile] = current
			if not frontier.has(next_tile):
				frontier.append(next_tile)
	if not came_from.has(goal):
		return empty
	var path: Array[Vector2i] = _vector2i_values([goal])
	var cursor: Vector2i = goal
	while cursor != start:
		cursor = came_from[cursor]
		path.push_front(cursor)
	return path

func _trigger_trap_on_player(state: Dictionary) -> Dictionary:
	var trap_index: int = _trap_index_at_tile(state, (_normalized_player(state.get("player", {}))).get("pos", Vector2i(-1, -1)))
	if trap_index < 0:
		return state
	var next_state: Dictionary = state
	var traps: Array = next_state.get("traps", []).duplicate(true)
	var trap: Dictionary = traps[trap_index]
	traps.remove_at(trap_index)
	next_state["traps"] = traps
	var damage: int = int(trap.get("damage", 0))
	if damage > 0:
		next_state = _damage_player(next_state, damage, false)
	next_state = _apply_trap_keywords_to_player(next_state, trap)
	_log(next_state, _trap_trigger_log(trap))
	return next_state

func _trigger_trap_on_enemy(state: Dictionary, enemy_index: int) -> Dictionary:
	var enemies: Array = state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var trap_index: int = -1
	for tile: Vector2i in _enemy_footprint_tiles(enemy):
		trap_index = _trap_index_at_tile(state, tile)
		if trap_index >= 0:
			break
	if trap_index < 0:
		return state
	var next_state: Dictionary = state
	var traps: Array = next_state.get("traps", []).duplicate(true)
	var trap: Dictionary = traps[trap_index]
	traps.remove_at(trap_index)
	next_state["traps"] = traps
	var damage: int = int(trap.get("damage", 0))
	if damage > 0:
		next_state = _damage_enemy(next_state, enemy_index, damage)
	if int(((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary).get("hp", 0)) > 0:
		next_state = _apply_action_keywords_to_enemy(next_state, enemy_index, trap, enemy.get("pos", Vector2i.ZERO))
	_log(next_state, _trap_trigger_log(trap))
	return next_state

func _apply_trap_keywords_to_player(state: Dictionary, trap: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var player: Dictionary = _normalized_player(next_state.get("player", {}))
	if int(trap.get("burn", 0)) > 0:
		player["burn"] = int(player.get("burn", 0)) + int(trap.get("burn", 0))
	if int(trap.get("poison", 0)) > 0:
		var poison: Dictionary = player.get("poison", {}).duplicate(true)
		poison["damage"] = int(poison.get("damage", 0)) + int(trap.get("poison", 0))
		poison["delay"] = 2
		player["poison"] = poison
	var restriction_kind: String = _trap_action_blocker_kind(trap)
	if restriction_kind.is_empty():
		next_state["player"] = player
		return next_state
	if _player_trap_applies_this_turn(next_state):
		next_state["player"] = player
		next_state["pending_player_trap_restriction"] = _stronger_restriction(
			str(next_state.get("pending_player_trap_restriction", "")),
			restriction_kind
		)
		return next_state
	player[restriction_kind] = maxi(int(player.get(restriction_kind, 0)), int(trap.get(restriction_kind, 0)))
	next_state["player"] = player
	return next_state

func _player_trap_applies_this_turn(state: Dictionary) -> bool:
	return cards_remaining_this_turn(state) > 1

func _trap_action_blocker_kind(trap: Dictionary) -> String:
	if int(trap.get("stun", 0)) > 0:
		return "stun"
	if int(trap.get("freeze", 0)) > 0:
		return "freeze"
	if int(trap.get("shock", 0)) > 0:
		return "shock"
	return ""

func _stronger_restriction(current_kind: String, next_kind: String) -> String:
	if current_kind.is_empty():
		return next_kind
	if current_kind in ["freeze", "stun"]:
		return current_kind
	return next_kind

func _apply_pending_player_trap_restriction(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var restriction_kind: String = str(next_state.get("pending_player_trap_restriction", ""))
	if restriction_kind.is_empty():
		return next_state
	next_state["pending_player_trap_restriction"] = ""
	var restrictions: Dictionary = (next_state.get("player_turn_restrictions", {}) as Dictionary).duplicate(true)
	match restriction_kind:
		"freeze":
			restrictions["frozen"] = true
		"shock":
			restrictions["shocked"] = true
		"stun":
			restrictions["stunned"] = true
	next_state["player_turn_restrictions"] = restrictions
	return next_state

func _trap_trigger_log(trap: Dictionary) -> String:
	var parts: PackedStringArray = ["%s trap hits for %d." % [ElementData.name(str(trap.get("element", ElementData.NONE))), int(trap.get("damage", 0))]]
	if int(trap.get("burn", 0)) > 0:
		parts.append("Burn %d." % int(trap.get("burn", 0)))
	if int(trap.get("freeze", 0)) > 0:
		parts.append("Freeze.")
	if int(trap.get("shock", 0)) > 0:
		parts.append("Shock.")
	if int(trap.get("stun", 0)) > 0:
		parts.append("Stun.")
	if int(trap.get("poison", 0)) > 0:
		parts.append("Poison %d." % int(trap.get("poison", 0)))
	return " ".join(parts)

func _trap_tiles_lookup(state: Dictionary) -> Dictionary:
	var lookup: Dictionary = {}
	for trap_var: Variant in state.get("traps", []):
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		var trap: Dictionary = trap_var
		lookup[trap.get("pos", Vector2i(-1, -1))] = true
	return lookup

func _trap_index_at_tile(state: Dictionary, tile: Vector2i) -> int:
	var traps: Array = state.get("traps", [])
	for index: int in range(traps.size()):
		var trap: Dictionary = traps[index]
		if trap.get("pos", Vector2i(-1, -1)) == tile:
			return index
	return -1

func _next_tile_away_from_source(grid: Array, start: Vector2i, source_pos: Vector2i, occupied: Dictionary, blocked_target: Vector2i) -> Vector2i:
	var best_tile: Vector2i = start
	var best_score: int = PathUtils.manhattan(start, source_pos)
	for dir: Vector2i in PathUtils.DIRS_4:
		var candidate: Vector2i = start + dir
		if candidate == blocked_target:
			continue
		if occupied.has(candidate):
			continue
		if not PathUtils.is_passable(grid, candidate):
			continue
		var score: int = PathUtils.manhattan(candidate, source_pos)
		if score > best_score:
			best_score = score
			best_tile = candidate
	return best_tile

func _next_tile_toward_source(grid: Array, start: Vector2i, source_pos: Vector2i, occupied: Dictionary) -> Vector2i:
	var path: Array[Vector2i] = PathUtils.find_path(grid, start, source_pos, occupied, true)
	if path.is_empty():
		return start
	var candidate: Vector2i = path[1] if path.size() > 1 else start
	return start if candidate == source_pos else candidate

func _apply_enemy_self_damage(state: Dictionary, enemy_index: int, amount: int) -> Dictionary:
	if amount <= 0:
		return state
	return _damage_enemy(state, enemy_index, amount, false)

func _resolve_enemy_start_of_turn(state: Dictionary, enemy_index: int) -> Dictionary:
	var next_state: Dictionary = state
	var steps: Array[Dictionary] = []
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return {"steps": steps, "skip_all": false, "shocked": false}
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var actor_name: String = str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy"))
	if int(enemy.get("burn", 0)) > 0:
		var burn_amount: int = int(enemy.get("burn", 0))
		var before_enemy: Dictionary = enemy.duplicate(true)
		next_state = _damage_enemy(next_state, enemy_index, burn_amount)
		enemy = _normalized_enemy(((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary))
		enemy["burn"] = maxi(0, int(enemy.get("burn", 0)) - 1)
		var burn_enemies: Array = next_state.get("enemies", [])
		burn_enemies[enemy_index] = enemy
		next_state["enemies"] = burn_enemies
		steps.append({
			"kind": "status_damage",
			"actor_key": _enemy_key(enemy),
			"actor_name": actor_name,
			"tile": enemy.get("pos", Vector2i.ZERO),
			"amount": int(before_enemy.get("hp", 0)) - int(enemy.get("hp", 0)),
			"label": "Burn",
			"text": "Burn %d" % burn_amount
		})
		if int(enemy.get("hp", 0)) <= 0:
			return {"steps": steps, "skip_all": true, "shocked": false}
	if _poison_damage(enemy) > 0:
		var poison_before: Dictionary = enemy.duplicate(true)
		enemy = _advance_poison(enemy)
		var poison_enemies: Array = next_state.get("enemies", [])
		poison_enemies[enemy_index] = enemy
		next_state["enemies"] = poison_enemies
		if int(enemy.get("poison", {}).get("trigger", 0)) > 0:
			var poison_damage: int = int(enemy.get("poison", {}).get("trigger", 0))
			next_state = _damage_enemy(next_state, enemy_index, poison_damage)
			enemy = _normalized_enemy(((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary))
			steps.append({
				"kind": "status_damage",
				"actor_key": _enemy_key(enemy),
				"actor_name": actor_name,
				"tile": enemy.get("pos", Vector2i.ZERO),
				"amount": int(poison_before.get("hp", 0)) - int(enemy.get("hp", 0)),
				"label": "Poison",
				"text": "Poison %d" % poison_damage
			})
			var poison: Dictionary = enemy.get("poison", {}).duplicate(true)
			poison["trigger"] = 0
			enemy["poison"] = poison
			poison_enemies = next_state.get("enemies", [])
			poison_enemies[enemy_index] = enemy
			next_state["enemies"] = poison_enemies
			if int(enemy.get("hp", 0)) <= 0:
				return {"steps": steps, "skip_all": true, "shocked": false}
	else:
		enemy = _advance_poison(enemy)
		var pending_poison_enemies: Array = next_state.get("enemies", [])
		pending_poison_enemies[enemy_index] = enemy
		next_state["enemies"] = pending_poison_enemies
	var skip_all: bool = false
	var shocked: bool = false
	if int(enemy.get("freeze", 0)) > 0:
		enemy["freeze"] = maxi(0, int(enemy.get("freeze", 0)) - 1)
		var frozen_enemies: Array = next_state.get("enemies", [])
		frozen_enemies[enemy_index] = enemy
		next_state["enemies"] = frozen_enemies
		skip_all = true
		steps.append({
			"kind": "status",
			"actor_key": _enemy_key(enemy),
			"actor_name": actor_name,
			"tile": enemy.get("pos", Vector2i.ZERO),
			"label": "Frozen",
			"text": "Frozen"
		})
	elif int(enemy.get("stun", 0)) > 0:
		enemy["stun"] = maxi(0, int(enemy.get("stun", 0)) - 1)
		var stunned_enemies: Array = next_state.get("enemies", [])
		stunned_enemies[enemy_index] = enemy
		next_state["enemies"] = stunned_enemies
		skip_all = true
		steps.append({
			"kind": "status",
			"actor_key": _enemy_key(enemy),
			"actor_name": actor_name,
			"tile": enemy.get("pos", Vector2i.ZERO),
			"label": "Stunned",
			"text": "Stunned"
		})
	elif int(enemy.get("shock", 0)) > 0:
		enemy["shock"] = maxi(0, int(enemy.get("shock", 0)) - 1)
		var shocked_enemies: Array = next_state.get("enemies", [])
		shocked_enemies[enemy_index] = enemy
		next_state["enemies"] = shocked_enemies
		shocked = true
		steps.append({
			"kind": "status",
			"actor_key": _enemy_key(enemy),
			"actor_name": actor_name,
			"tile": enemy.get("pos", Vector2i.ZERO),
			"label": "Shocked",
			"text": "Shocked"
		})
	return {"steps": steps, "skip_all": skip_all, "shocked": shocked, "state": next_state}

func _resolve_player_start_of_turn(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var player: Dictionary = _normalized_player(next_state.get("player", {}))
	if int(player.get("burn", 0)) > 0:
		var burn_amount: int = int(player.get("burn", 0))
		next_state = _damage_player(next_state, burn_amount, false)
		player = _normalized_player(next_state.get("player", {}))
		player["burn"] = maxi(0, int(player.get("burn", 0)) - 1)
		next_state["player"] = player
		_log(next_state, "Burn deals %d." % burn_amount)
		if combat_outcome(next_state) != "":
			return next_state
	if _poison_damage(player) > 0:
		player = _advance_poison(player)
		next_state["player"] = player
		if int(player.get("poison", {}).get("trigger", 0)) > 0:
			var poison_damage: int = int(player.get("poison", {}).get("trigger", 0))
			next_state = _damage_player(next_state, poison_damage, false)
			player = _normalized_player(next_state.get("player", {}))
			var poison: Dictionary = player.get("poison", {}).duplicate(true)
			poison["trigger"] = 0
			player["poison"] = poison
			next_state["player"] = player
			_log(next_state, "Poison deals %d." % poison_damage)
			if combat_outcome(next_state) != "":
				return next_state
	else:
		player = _advance_poison(player)
		next_state["player"] = player
	var restrictions: Dictionary = {
		"frozen": false,
		"shocked": false,
		"stunned": false
	}
	if int(player.get("freeze", 0)) > 0:
		player["freeze"] = maxi(0, int(player.get("freeze", 0)) - 1)
		restrictions["frozen"] = true
		_log(next_state, "Frozen this turn.")
	elif int(player.get("stun", 0)) > 0:
		player["stun"] = maxi(0, int(player.get("stun", 0)) - 1)
		restrictions["stunned"] = true
		_log(next_state, "Stunned this turn.")
	elif int(player.get("shock", 0)) > 0:
		player["shock"] = maxi(0, int(player.get("shock", 0)) - 1)
		restrictions["shocked"] = true
		_log(next_state, "Shocked this turn.")
	next_state["player"] = player
	next_state["player_turn_restrictions"] = restrictions
	return next_state

func _poison_damage(unit: Dictionary) -> int:
	return int((unit.get("poison", {}) as Dictionary).get("damage", 0))

func _advance_poison(unit: Dictionary) -> Dictionary:
	var next_unit: Dictionary = unit.duplicate(true)
	var poison: Dictionary = (next_unit.get("poison", {}) as Dictionary).duplicate(true)
	var damage: int = int(poison.get("damage", 0))
	var delay: int = int(poison.get("delay", 0))
	poison["trigger"] = 0
	if damage <= 0 or delay <= 0:
		poison["damage"] = damage
		poison["delay"] = maxi(0, delay)
		next_unit["poison"] = poison
		return next_unit
	delay -= 1
	if delay <= 0:
		poison["trigger"] = damage
		poison["damage"] = 0
		poison["delay"] = 0
	else:
		poison["delay"] = delay
	next_unit["poison"] = poison
	return next_unit

func _enemy_action_is_movement(action: Dictionary) -> bool:
	return str(action.get("type", "")) in ["move_toward", "move_away"]

func _threat_movement_tiles(grid: Array, start_tile: Vector2i, player_pos: Vector2i, action: Dictionary, occupied: Dictionary) -> Array[Vector2i]:
	var move_range: int = int(action.get("range", 0))
	if move_range <= 0:
		return []
	var current_distance: int = PathUtils.manhattan(start_tile, player_pos)
	var results: Array[Vector2i] = []
	for tile: Vector2i in PathUtils.reachable_tiles(grid, start_tile, move_range, occupied):
		var tile_distance: int = PathUtils.manhattan(tile, player_pos)
		if str(action.get("type", "")) == "move_toward" and tile_distance >= current_distance:
			continue
		if str(action.get("type", "")) == "move_away" and tile_distance <= current_distance:
			continue
		results.append(tile)
	return results

func _threat_attack_tiles(grid: Array, start_tile: Vector2i, action: Dictionary) -> Array[Vector2i]:
	var lookup: Dictionary = {}
	var action_type: String = str(action.get("type", ""))
	match action_type:
		"melee":
			for tile: Vector2i in PathUtils.diamond_tiles(start_tile, int(action.get("range", 1)), grid):
				if tile == start_tile or not PathUtils.is_passable(grid, tile):
					continue
				lookup[tile] = true
		"ranged":
			for tile: Vector2i in PathUtils.diamond_tiles(start_tile, int(action.get("range", 1)), grid):
				if tile == start_tile or not PathUtils.is_passable(grid, tile):
					continue
				if not PathUtils.has_line_of_sight(grid, start_tile, tile):
					continue
				lookup[tile] = true
		"push", "pull":
			for tile: Vector2i in PathUtils.diamond_tiles(start_tile, int(action.get("range", 1)), grid):
				if tile == start_tile or not PathUtils.is_passable(grid, tile):
					continue
				if int(action.get("range", 1)) > 1 and not PathUtils.has_line_of_sight(grid, start_tile, tile):
					continue
				lookup[tile] = true
		"aoe":
			var attack_range: int = int(action.get("range", 0))
			var centers: Array[Vector2i] = _vector2i_values([start_tile])
			if attack_range > 0:
				centers = PathUtils.diamond_tiles(start_tile, attack_range, grid)
			for center: Vector2i in centers:
				if center != start_tile and not PathUtils.has_line_of_sight(grid, start_tile, center):
					continue
				if not PathUtils.is_passable(grid, center):
					continue
				for tile: Vector2i in _aoe_tiles_for_anchor(grid, action, center):
					if tile == start_tile:
						continue
					lookup[tile] = true
		"lightning_strikes":
			for tile: Vector2i in PathUtils.diamond_tiles(start_tile, 99, grid):
				if tile == start_tile or not PathUtils.is_passable(grid, tile):
					continue
				lookup[tile] = true
	return _sorted_tiles_from_lookup(lookup)

func _player_status_step_text(before_player: Dictionary, after_player: Dictionary, action: Dictionary) -> String:
	var tags: PackedStringArray = []
	if int(after_player.get("burn", 0)) > int(before_player.get("burn", 0)):
		tags.append("Burn")
	if int(after_player.get("freeze", 0)) > int(before_player.get("freeze", 0)):
		tags.append("Freeze")
	if int(after_player.get("shock", 0)) > int(before_player.get("shock", 0)):
		tags.append("Shock")
	if int(after_player.get("stun", 0)) > int(before_player.get("stun", 0)):
		tags.append("Stun")
	var before_poison: Dictionary = before_player.get("poison", {})
	var after_poison: Dictionary = after_player.get("poison", {})
	if int(after_poison.get("damage", 0)) > int(before_poison.get("damage", 0)):
		tags.append("Poison")
	if int(action.get("push", 0)) > 0 and before_player.get("pos", Vector2i.ZERO) != after_player.get("pos", Vector2i.ZERO):
		tags.append("Push")
	if int(action.get("pull", 0)) > 0 and before_player.get("pos", Vector2i.ZERO) != after_player.get("pos", Vector2i.ZERO):
		tags.append("Pull")
	if tags.is_empty():
		return ""
	return ", ".join(tags)

func _draw_cards_in_place(state: Dictionary, count: int) -> Dictionary:
	var next_state: Dictionary = state
	var deck: Dictionary = next_state.get("deck", {}).duplicate(true)
	for _draw_index: int in range(count):
		if (deck.get("hand", []) as Array).size() >= MAX_HAND_SIZE:
			break
		if combat_outcome(next_state) != "":
			break
		if (deck.get("draw", []) as Array).is_empty():
			var discard: Array = deck.get("discard", []).duplicate()
			if discard.is_empty():
				break
			deck["cycles"] = int(deck.get("cycles", 0)) + 1
			var fatigue_damage: int = int(deck.get("fatigue_base", FATIGUE_BASE_DAMAGE)) + int(deck.get("cycles", 0)) - 1
			next_state["deck"] = deck
			next_state = _lose_player_health(next_state, fatigue_damage, true)
			deck = next_state.get("deck", {}).duplicate(true)
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.state = int(next_state.get("rng_state", 0))
			deck["draw"] = GameData.shuffle_cards(discard, rng)
			deck["discard"] = []
			next_state["rng_state"] = rng.state
			_log(next_state, "Fatigue costs %d health." % fatigue_damage)
			if combat_outcome(next_state) != "":
				break
		var draw_pile: Array = deck.get("draw", []).duplicate()
		if draw_pile.is_empty():
			break
		var hand: Array = deck.get("hand", []).duplicate()
		hand.append(str(draw_pile.pop_back()))
		deck["draw"] = draw_pile
		deck["hand"] = hand
	next_state["deck"] = deck
	return next_state

func _collect_loot_at_player(state: Dictionary) -> void:
	var loot_entries: Array = state.get("loot", [])
	var player_pos: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	for index: int in range(loot_entries.size()):
		var loot: Dictionary = loot_entries[index]
		if bool(loot.get("claimed", false)):
			continue
		if loot.get("pos", Vector2i(-1, -1)) != player_pos:
			continue
		loot["claimed"] = true
		loot_entries[index] = loot
		var amount: int = int(loot.get("amount", 0))
		match str(loot.get("kind", "")):
			"healing_vial":
				var player: Dictionary = state.get("player", {})
				var total_heal: int = amount + int(state.get("heal_bonus", 0))
				player["hp"] = mini(int(player.get("max_hp", 1)), int(player.get("hp", 0)) + total_heal)
				state["player"] = player
				_log(state, "Collected a vial for %d health." % total_heal)
			"ember_cache":
				state["room_embers"] = int(state.get("room_embers", 0)) + amount
				_log(state, "Collected %d embers." % amount)

func _occupied_enemy_tiles(state: Dictionary, exclude_id: int = -1) -> Dictionary:
	var occupied: Dictionary = {}
	for enemy: Dictionary in _live_enemies(state):
		if int(enemy.get("id", -1)) == exclude_id:
			continue
		for tile: Vector2i in _enemy_footprint_tiles(enemy):
			occupied[tile] = true
	return occupied

func _occupied_illusion_tiles(state: Dictionary, exclude_id: int = -1) -> Dictionary:
	var occupied: Dictionary = {}
	for illusion: Dictionary in _live_illusions(state):
		if int(illusion.get("id", -1)) == exclude_id:
			continue
		occupied[illusion.get("pos", Vector2i.ZERO)] = true
	return occupied

func _occupied_actor_tiles(state: Dictionary, exclude_enemy_id: int = -1, exclude_illusion_id: int = -1) -> Dictionary:
	var occupied: Dictionary = _occupied_enemy_tiles(state, exclude_enemy_id)
	for tile_var: Variant in _occupied_illusion_tiles(state, exclude_illusion_id).keys():
		occupied[tile_var] = true
	return occupied

func _enemy_blocking_tiles(state: Dictionary, exclude_enemy_id: int = -1) -> Dictionary:
	var occupied: Dictionary = _occupied_actor_tiles(state, exclude_enemy_id)
	var player_pos: Vector2i = (_normalized_player(state.get("player", {}))).get("pos", Vector2i.ZERO)
	occupied[player_pos] = true
	return occupied

func _live_enemies(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) > 0:
			result.append(enemy)
	return result

func _live_illusions(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for illusion_var: Variant in state.get("illusions", []):
		if typeof(illusion_var) != TYPE_DICTIONARY:
			continue
		var illusion: Dictionary = _normalized_illusion(illusion_var as Dictionary)
		if int(illusion.get("hp", 0)) > 0:
			result.append(illusion)
	return result

func _illusion_key(illusion: Dictionary) -> String:
	return "illusion_%d" % int(illusion.get("id", -1))

func _enemy_index_at_tile(state: Dictionary, tile: Vector2i) -> int:
	var enemies: Array = state.get("enemies", [])
	for index: int in range(enemies.size()):
		var enemy: Dictionary = _normalized_enemy(enemies[index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			continue
		if _enemy_footprint_tiles(enemy).has(tile):
			return index
	return -1

func _enemy_indices_in_tiles(state: Dictionary, tiles: Array[Vector2i]) -> Array[int]:
	var tile_lookup: Dictionary = {}
	for tile: Vector2i in tiles:
		tile_lookup[tile] = true
	var indices: Array[int] = []
	var enemies: Array = state.get("enemies", [])
	for index: int in range(enemies.size()):
		var enemy: Dictionary = _normalized_enemy(enemies[index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			continue
		for tile: Vector2i in _enemy_footprint_tiles(enemy):
			if tile_lookup.has(tile):
				indices.append(index)
				break
	return indices

func _enemy_footprint_tiles(enemy: Dictionary, origin_override: Vector2i = Vector2i(-999, -999)) -> Array[Vector2i]:
	var origin: Vector2i = origin_override if origin_override.x > -900 else enemy.get("pos", Vector2i(-1, -1))
	var footprint: Vector2i = enemy.get("footprint", Vector2i.ONE)
	var tiles: Array[Vector2i] = []
	for y: int in range(maxi(1, footprint.y)):
		for x: int in range(maxi(1, footprint.x)):
			tiles.append(origin + Vector2i(x, y))
	return tiles

func _enemy_distance_to_tile(enemy: Dictionary, tile: Vector2i) -> int:
	var best_distance: int = 9999
	for enemy_tile: Vector2i in _enemy_footprint_tiles(enemy):
		best_distance = mini(best_distance, PathUtils.manhattan(enemy_tile, tile))
	return best_distance

func _closest_enemy_tile_to(enemy: Dictionary, tile: Vector2i) -> Vector2i:
	var best_tile: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var best_distance: int = 9999
	for enemy_tile: Vector2i in _enemy_footprint_tiles(enemy):
		var distance: int = PathUtils.manhattan(enemy_tile, tile)
		if distance < best_distance:
			best_distance = distance
			best_tile = enemy_tile
	return best_tile

func _enemy_can_occupy_anchor(state: Dictionary, enemy: Dictionary, anchor: Vector2i, occupied: Dictionary, blocked_target: Vector2i = Vector2i(-999, -999)) -> bool:
	for tile: Vector2i in _enemy_footprint_tiles(enemy, anchor):
		if tile == blocked_target:
			return false
		if occupied.has(tile):
			return false
		if not PathUtils.is_passable(state.get("grid", []), tile):
			return false
	return true

func _lightning_strike_tiles(state: Dictionary, enemy: Dictionary, action: Dictionary) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var grid: Array = state.get("grid", [])
	var occupied: Dictionary = _occupied_enemy_tiles(state)
	for y: int in range(grid.size()):
		for x: int in range((grid[y] as Array).size()):
			var tile: Vector2i = Vector2i(x, y)
			if occupied.has(tile):
				continue
			if not PathUtils.is_passable(grid, tile):
				continue
			candidates.append(tile)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var a_score: int = _lightning_tile_score(state, enemy, action, a)
		var b_score: int = _lightning_tile_score(state, enemy, action, b)
		if a_score == b_score:
			if a.y == b.y:
				return a.x < b.x
			return a.y < b.y
		return a_score < b_score
	)
	var results: Array[Vector2i] = []
	var strike_count: int = mini(int(action.get("count", 4)), candidates.size())
	for index: int in range(strike_count):
		results.append(candidates[index])
	return results

func _lightning_tile_score(state: Dictionary, enemy: Dictionary, action: Dictionary, tile: Vector2i) -> int:
	var seed: int = int(state.get("rng_state", 0))
	seed = int((seed + int(state.get("turn", 1)) * 1103515245 + int(enemy.get("id", 0)) * 92821 + int(action.get("count", 0)) * 193) & 0x7fffffff)
	seed = int((seed + tile.x * 68917 + tile.y * 28307) & 0x7fffffff)
	return seed

func _summon_tiles_for_enemy(state: Dictionary, enemy: Dictionary, count: int) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var occupied: Dictionary = _enemy_blocking_tiles(state)
	for tile: Vector2i in PathUtils.diamond_tiles(enemy.get("pos", Vector2i.ZERO), 4, state.get("grid", [])):
		if occupied.has(tile):
			continue
		if not PathUtils.is_passable(state.get("grid", []), tile):
			continue
		if _enemy_distance_to_tile(enemy, tile) <= 0:
			continue
		candidates.append(tile)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var a_distance: int = _enemy_distance_to_tile(enemy, a)
		var b_distance: int = _enemy_distance_to_tile(enemy, b)
		if a_distance == b_distance:
			if a.y == b.y:
				return a.x < b.x
			return a.y < b.y
		return a_distance < b_distance
	)
	var results: Array[Vector2i] = []
	for tile: Vector2i in candidates:
		results.append(tile)
		if results.size() >= count:
			break
	return results

func _next_enemy_id(state: Dictionary) -> int:
	var next_id: int = 1
	for enemy_var: Variant in state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		next_id = maxi(next_id, int((enemy_var as Dictionary).get("id", 0)) + 1)
	return next_id

func _enemy_should_summon_wisps(state: Dictionary, enemy: Dictionary) -> bool:
	if str(enemy.get("type", "")) != ZEKARION_TYPE:
		return false
	for other: Dictionary in _live_enemies(state):
		if str(other.get("type", "")) == LIGHTNING_WISP_TYPE:
			return false
	return true

func _zekarion_summon_intent() -> Dictionary:
	return {
		"id": "call_wisps",
		"name": "Call Wisps",
		"actions": [
			{"type": "summon_minions", "minion_type": LIGHTNING_WISP_TYPE, "count": 2}
		]
	}

func _best_aoe_tiles_for_target(state: Dictionary, action: Dictionary, target_tile: Vector2i, score_player: bool) -> Array[Vector2i]:
	var grid: Array = state.get("grid", [])
	var variants: Array = _aoe_pattern_variants(action)
	var best_tiles: Array[Vector2i] = []
	var best_score: int = -1
	var best_size: int = 9999
	for offsets_var: Variant in variants:
		var offsets: Array = offsets_var
		var tiles: Array[Vector2i] = _tiles_for_aoe_offsets(grid, target_tile, offsets)
		var score: int = 0
		if score_player:
			score = _actor_targets_in_tiles(state, tiles).size()
		else:
			score = _enemy_indices_in_tiles(state, tiles).size()
		if score > best_score or (score == best_score and tiles.size() < best_size):
			best_score = score
			best_size = tiles.size()
			best_tiles = tiles
	return best_tiles

func _aoe_tiles_for_anchor(grid: Array, action: Dictionary, target_tile: Vector2i) -> Array[Vector2i]:
	var variants: Array = _aoe_pattern_variants(action)
	if variants.is_empty():
		return []
	return _tiles_for_aoe_offsets(grid, target_tile, variants[0])

func _tiles_for_aoe_offsets(grid: Array, anchor: Vector2i, offsets: Array) -> Array[Vector2i]:
	var lookup: Dictionary = {}
	for offset: Vector2i in _vector2i_values(offsets):
		var tile: Vector2i = anchor + offset
		if not PathUtils.is_passable(grid, tile):
			continue
		lookup[tile] = true
	return _sorted_tiles_from_lookup(lookup)

func _aoe_pattern_variants(action: Dictionary) -> Array:
	var offsets: Array[Vector2i] = _aoe_pattern_offsets(action)
	var variants: Array = []
	var seen: Dictionary = {}
	var rotation_count: int = 4 if bool(action.get("rotate", true)) else 1
	for rotation: int in range(rotation_count):
		var rotated: Array[Vector2i] = []
		for offset: Vector2i in offsets:
			rotated.append(_rotated_offset(offset, rotation))
		var key_parts: PackedStringArray = []
		for rotated_offset: Vector2i in rotated:
			key_parts.append("%d,%d" % [rotated_offset.x, rotated_offset.y])
		key_parts.sort()
		var key: String = "|".join(key_parts)
		if seen.has(key):
			continue
		seen[key] = true
		var unique_lookup: Dictionary = {}
		for rotated_offset: Vector2i in rotated:
			unique_lookup[rotated_offset] = true
		var unique_offsets: Array[Vector2i] = _sorted_tiles_from_lookup(unique_lookup)
		variants.append(unique_offsets)
	return variants

func _aoe_pattern_offsets(action: Dictionary) -> Array[Vector2i]:
	var raw_pattern: Array = action.get("pattern", DEFAULT_AOE_PATTERN)
	var offsets: Array[Vector2i] = []
	for offset_var: Variant in raw_pattern:
		match typeof(offset_var):
			TYPE_VECTOR2I:
				offsets.append(offset_var)
			TYPE_ARRAY:
				var pair: Array = offset_var
				if pair.size() >= 2:
					offsets.append(Vector2i(int(pair[0]), int(pair[1])))
			TYPE_DICTIONARY:
				var offset_dict: Dictionary = offset_var
				offsets.append(Vector2i(int(offset_dict.get("x", 0)), int(offset_dict.get("y", 0))))
	if offsets.is_empty():
		offsets.append(Vector2i.ZERO)
	return offsets

func _vector2i_values(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Variant in values:
		if typeof(value) == TYPE_VECTOR2I:
			result.append(value)
	return result

func _rotated_offset(offset: Vector2i, rotation: int) -> Vector2i:
	match posmod(rotation, 4):
		1:
			return Vector2i(-offset.y, offset.x)
		2:
			return Vector2i(-offset.x, -offset.y)
		3:
			return Vector2i(offset.y, -offset.x)
		_:
			return offset

func _assign_enemy_intent(state: Dictionary, enemy_index: int, rng: RandomNumberGenerator) -> void:
	var enemies: Array = state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var enemy_type: String = str(enemy.get("type", ""))
	var definition: Dictionary = GameData.enemy_def(enemy_type)
	if _enemy_should_summon_wisps(state, enemy):
		enemy["intent"] = _zekarion_summon_intent()
		enemy["block"] = _preview_block_for_intent(enemy["intent"])
		enemies[enemy_index] = enemy
		return
	var intents: Array = _elementalized_enemy_intents(
		definition.get("intents", []),
		str(state.get("room_element", ElementData.NONE)),
		int(state.get("room_depth", 1))
	)
	if intents.is_empty():
		return
	var total_weight: int = 0
	for intent: Dictionary in intents:
		total_weight += maxi(1, int(intent.get("weight", 1)))
	var roll: int = rng.randi_range(1, total_weight)
	var cursor: int = 0
	for intent: Dictionary in intents:
		cursor += maxi(1, int(intent.get("weight", 1)))
		if roll <= cursor:
			enemy["intent"] = intent.duplicate(true)
			enemy["block"] = _preview_block_for_intent(enemy["intent"])
			enemies[enemy_index] = enemy
			return
	enemy["intent"] = (intents[0] as Dictionary).duplicate(true)
	enemy["block"] = _preview_block_for_intent(enemy["intent"])
	enemies[enemy_index] = enemy

func _elementalized_enemy_intents(base_intents: Array, room_element: String, room_depth: int) -> Array:
	var intents: Array = []
	for intent_var: Variant in base_intents:
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		intents.append(_elementalize_enemy_intent(intent_var as Dictionary, room_element, room_depth))
	return intents

func _elementalize_enemy_intent(base_intent: Dictionary, room_element: String, room_depth: int) -> Dictionary:
	var intent: Dictionary = base_intent.duplicate(true)
	if not ElementData.is_elemental(room_element):
		return intent
	var allow_control: bool = _intent_gets_elemental_control(base_intent, room_element, room_depth)
	var actions: Array = []
	for action_var: Variant in base_intent.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		actions.append(_elementalize_enemy_action(action_var as Dictionary, room_element, room_depth, allow_control))
	intent["actions"] = actions
	intent["element"] = room_element
	return intent

func _intent_gets_elemental_control(base_intent: Dictionary, room_element: String, room_depth: int) -> bool:
	if room_element not in [ElementData.ICE, ElementData.LIGHTNING]:
		return false
	if room_depth < 3:
		return false
	return int(base_intent.get("weight", 1)) <= 2

func _elementalize_enemy_action(base_action: Dictionary, room_element: String, room_depth: int, allow_control: bool = true) -> Dictionary:
	var action: Dictionary = base_action.duplicate(true)
	var action_type: String = str(action.get("type", ""))
	var full_power: bool = room_depth >= 3
	var medium_power: bool = room_depth >= 2
	var shallow_power: bool = not medium_power
	match room_element:
		ElementData.FIRE:
			if action_type in ELEMENTAL_ATTACK_ACTION_TYPES:
				if action_type in ["ranged", "aoe"]:
					action["type"] = "aoe"
					if not action.has("pattern"):
						action["pattern"] = DEFAULT_AOE_PATTERN.duplicate(true)
					action["rotate"] = bool(action.get("rotate", true))
				action["damage"] = int(action.get("damage", 0)) + (2 if medium_power else 1)
				action["burn"] = maxi(1 if shallow_power else 2, int(action.get("burn", 0)) + (2 if full_power else 1))
				if full_power and int(action.get("damage", 0)) >= 6:
					action["self_damage"] = maxi(1, int(action.get("self_damage", 0)))
		ElementData.ICE:
			if action_type in ELEMENTAL_ATTACK_ACTION_TYPES:
				var base_range: int = int(action.get("range", 1))
				var range_floor: int = 4 if action_type == "ranged" else 3
				action["type"] = "ranged"
				action["range"] = maxi(range_floor, base_range)
				if allow_control:
					action["range"] = mini(int(action.get("range", 0)), 4)
				action.erase("pattern")
				action.erase("rotate")
				if allow_control:
					action["freeze"] = 1
				else:
					action.erase("freeze")
		ElementData.LIGHTNING:
			if action_type in ELEMENTAL_ATTACK_ACTION_TYPES:
				var base_range: int = int(action.get("range", 1))
				var range_floor: int = 4 if action_type == "ranged" else 3
				action["type"] = "ranged"
				action["range"] = maxi(range_floor, base_range)
				if allow_control:
					action["range"] = mini(int(action.get("range", 0)), 4)
				action.erase("pattern")
				action.erase("rotate")
				if allow_control:
					action["shock"] = 1
				else:
					action.erase("shock")
		ElementData.AIR:
			if action_type == "move_toward" or action_type == "move_away":
				action["range"] = int(action.get("range", 0)) + (1 if medium_power else 0)
			elif action_type in ELEMENTAL_ATTACK_ACTION_TYPES:
				action["type"] = "ranged"
				action["range"] = maxi(3 if not medium_power else 4, int(action.get("range", 1)))
				action.erase("pattern")
				action.erase("rotate")
				action["damage"] = maxi(1, int(action.get("damage", 0)) - 2)
				if int(action.get("damage", 0)) % 2 == 0:
					action["push"] = maxi(1, int(action.get("push", 0)) + (2 if full_power else 1))
				else:
					action["pull"] = maxi(1, int(action.get("pull", 0)) + (2 if full_power else 1))
		ElementData.EARTH:
			if action_type == "block":
				action["type"] = "stoneskin"
			elif action_type in ELEMENTAL_ATTACK_ACTION_TYPES:
				action["type"] = "melee"
				action["range"] = mini(2, maxi(1, int(action.get("range", 1))))
				action.erase("pattern")
				action.erase("rotate")
				action["damage"] = int(action.get("damage", 0)) + (1 if medium_power else 0)
				var poison_bonus: int = 1
				if medium_power:
					poison_bonus = 2
				if full_power:
					poison_bonus = 3
				action["poison"] = maxi(1 if shallow_power else 2, int(action.get("poison", 0)) + poison_bonus)
	return action

func _apply_revealed_intent_blocks(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var enemies: Array = next_state.get("enemies", [])
	for enemy_index: int in range(enemies.size()):
		var enemy: Dictionary = enemies[enemy_index]
		enemy["block"] = _preview_block_for_intent(enemy.get("intent", {}))
		enemies[enemy_index] = enemy
	return next_state

func _preview_block_for_intent(intent: Dictionary) -> int:
	var total: int = 0
	for action_var: Variant in intent.get("actions", []):
		var action: Dictionary = action_var
		if str(action.get("type", "")) == "block":
			total += int(action.get("amount", 0))
	return total

func _best_move_toward(state: Dictionary, enemy_index: int, target: Vector2i, move_range: int) -> Vector2i:
	var enemies: Array = state.get("enemies", [])
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var start: Vector2i = enemy.get("pos", Vector2i.ZERO)
	if move_range <= 0:
		return start
	var occupied: Dictionary = _enemy_blocking_tiles(state, int(enemy.get("id", -1)))
	for trap_tile_var: Variant in _trap_tiles_lookup(state).keys():
		occupied[trap_tile_var] = true
	if enemy.get("footprint", Vector2i.ONE) != Vector2i.ONE:
		var reachable: Array[Vector2i] = _reachable_enemy_anchor_tiles(state, enemy, move_range, occupied, target)
		var best_tile: Vector2i = start
		var best_score: int = _enemy_distance_to_tile(enemy, target)
		for tile: Vector2i in reachable:
			var candidate_enemy: Dictionary = enemy.duplicate(true)
			candidate_enemy["pos"] = tile
			var score: int = _enemy_distance_to_tile(candidate_enemy, target)
			if score < best_score:
				best_tile = tile
				best_score = score
		return best_tile
	var path: Array[Vector2i] = PathUtils.find_path(state.get("grid", []), start, target, occupied, true)
	if path.is_empty():
		return start
	var best_tile: Vector2i = start
	for step_index: int in range(1, mini(path.size(), move_range + 1)):
		var candidate: Vector2i = path[step_index]
		if candidate == target:
			break
		best_tile = candidate
	return best_tile

func _best_move_away(state: Dictionary, enemy_index: int, target: Vector2i, move_range: int) -> Vector2i:
	var enemies: Array = state.get("enemies", [])
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var start: Vector2i = enemy.get("pos", Vector2i.ZERO)
	if move_range <= 0:
		return start
	var occupied: Dictionary = _enemy_blocking_tiles(state, int(enemy.get("id", -1)))
	for trap_tile_var: Variant in _trap_tiles_lookup(state).keys():
		occupied[trap_tile_var] = true
	if enemy.get("footprint", Vector2i.ONE) != Vector2i.ONE:
		var reachable: Array[Vector2i] = _reachable_enemy_anchor_tiles(state, enemy, move_range, occupied, target)
		var best_big_tile: Vector2i = start
		var best_big_score: int = _enemy_distance_to_tile(enemy, target)
		for tile: Vector2i in reachable:
			var candidate_enemy: Dictionary = enemy.duplicate(true)
			candidate_enemy["pos"] = tile
			var score: int = _enemy_distance_to_tile(candidate_enemy, target)
			if score > best_big_score:
				best_big_tile = tile
				best_big_score = score
		return best_big_tile
	var reachable: Array[Vector2i] = PathUtils.reachable_tiles(state.get("grid", []), start, move_range, occupied)
	var best_tile: Vector2i = start
	var best_score: int = PathUtils.manhattan(start, target)
	for tile: Vector2i in reachable:
		var score: int = PathUtils.manhattan(tile, target)
		if score > best_score:
			best_tile = tile
			best_score = score
	return best_tile

func _reachable_enemy_anchor_tiles(state: Dictionary, enemy: Dictionary, max_distance: int, occupied: Dictionary, blocked_target: Vector2i) -> Array[Vector2i]:
	var results: Array[Vector2i] = []
	var start: Vector2i = enemy.get("pos", Vector2i.ZERO)
	if max_distance <= 0:
		return results
	var queue: Array[Vector2i] = _vector2i_values([start])
	var distance_by_tile: Dictionary = {start: 0}
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var current_distance: int = int(distance_by_tile.get(current, 0))
		if current_distance > 0:
			results.append(current)
		if current_distance >= max_distance:
			continue
		for dir: Vector2i in PathUtils.DIRS_4:
			var next_tile: Vector2i = current + dir
			if distance_by_tile.has(next_tile):
				continue
			if not _enemy_can_occupy_anchor(state, enemy, next_tile, occupied, blocked_target):
				continue
			distance_by_tile[next_tile] = current_distance + 1
			queue.append(next_tile)
	return results

func _attack_bonus_for_current_turn(state: Dictionary) -> int:
	if bool((state.get("turn_flags", {}) as Dictionary).get("first_attack_bonus_used", false)):
		return 0
	return GameData.stat_bonus_from_relics(state.get("relics", []), "first_attack_bonus")

func _move_bonus_for_current_turn(state: Dictionary) -> int:
	if bool((state.get("turn_flags", {}) as Dictionary).get("first_move_bonus_used", false)):
		return 0
	return GameData.stat_bonus_from_relics(state.get("relics", []), "first_move_bonus")

func _sorted_tiles_from_lookup(lookup: Dictionary) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for tile_var: Variant in lookup.keys():
		if typeof(tile_var) == TYPE_VECTOR2I:
			tiles.append(tile_var)
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)
	return tiles

func _mark_first_attack_used(state: Dictionary) -> void:
	var flags: Dictionary = state.get("turn_flags", {}).duplicate(true)
	flags["first_attack_bonus_used"] = true
	state["turn_flags"] = flags

func _mark_first_move_used(state: Dictionary) -> void:
	var flags: Dictionary = state.get("turn_flags", {}).duplicate(true)
	flags["first_move_bonus_used"] = true
	state["turn_flags"] = flags

func _combat_seed(run_seed: int, coord: Vector2i) -> int:
	var value: int = run_seed
	value = int((value * 214013 + 2531011 + coord.x * 19349663 + coord.y * 83492791) & 0x7fffffff)
	return value

func _log(state: Dictionary, message: String) -> void:
	var log_lines: Array = state.get("log", [])
	log_lines.append(message)
	state["log"] = log_lines

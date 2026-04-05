extends RefCounted
class_name CombatEngine

const GameData = preload("res://scripts/game_data.gd")
const PathUtils = preload("res://scripts/path_utils.gd")

const FATIGUE_BASE_DAMAGE: int = 2
const BASE_CARDS_PER_TURN: int = 2
const BASE_DRAW_PER_TURN: int = 2

func create_combat(run_seed: int, room_layout: Dictionary, player_snapshot: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _combat_seed(run_seed, room_layout.get("coord", Vector2i.ZERO))
	var deck_cards: Array = player_snapshot.get("deck_cards", []).duplicate()
	var draw_pile: Array[String] = GameData.shuffle_cards(deck_cards, rng)
	var state: Dictionary = {
		"room_name": str(room_layout.get("name", "Room")),
		"room_coord": room_layout.get("coord", Vector2i.ZERO),
		"room_type": str(room_layout.get("type", "combat")),
		"grid": room_layout.get("grid", []).duplicate(true),
		"player": {
			"pos": room_layout.get("player_start", Vector2i.ZERO),
			"hp": int(player_snapshot.get("hp", 1)),
			"max_hp": int(player_snapshot.get("max_hp", 1)),
			"block": 0
		},
		"enemies": room_layout.get("enemies", []).duplicate(true),
		"loot": room_layout.get("loot", []).duplicate(true),
		"relics": player_snapshot.get("relics", []).duplicate(),
		"hand_size": int(player_snapshot.get("hand_size", 5)),
		"cards_per_turn": int(player_snapshot.get("cards_per_turn", BASE_CARDS_PER_TURN)),
		"draw_per_turn": int(player_snapshot.get("draw_per_turn", BASE_DRAW_PER_TURN)),
		"cards_played_this_turn": 0,
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
		"turn_flags": {
			"first_attack_bonus_used": false,
			"first_move_bonus_used": false
		},
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

func card_def(card_id: String) -> Dictionary:
	return GameData.card_def(card_id)

func player_action_needs_target(action: Dictionary) -> bool:
	var action_type: String = str(action.get("type", ""))
	return action_type in ["move", "blink", "melee", "ranged", "blast"]

func valid_targets_for_player_action(state: Dictionary, action: Dictionary) -> Array[Vector2i]:
	var player: Dictionary = state.get("player", {})
	var player_pos: Vector2i = player.get("pos", Vector2i.ZERO)
	var action_type: String = str(action.get("type", ""))
	var occupied: Dictionary = _occupied_enemy_tiles(state)
	var targets: Array[Vector2i] = []
	match action_type:
		"move":
			var move_range: int = int(action.get("range", 0)) + _move_bonus_for_current_turn(state)
			targets = PathUtils.reachable_tiles(state.get("grid", []), player_pos, move_range, occupied)
		"blink":
			var max_range: int = int(action.get("range", 0))
			for tile: Vector2i in PathUtils.diamond_tiles(player_pos, max_range, state.get("grid", [])):
				if tile == player_pos:
					continue
				if occupied.has(tile):
					continue
				if not PathUtils.is_passable(state.get("grid", []), tile):
					continue
				targets.append(tile)
		"melee":
			for enemy: Dictionary in _live_enemies(state):
				var enemy_pos: Vector2i = enemy.get("pos", Vector2i(-1, -1))
				if PathUtils.manhattan(player_pos, enemy_pos) <= int(action.get("range", 1)):
					targets.append(enemy_pos)
		"ranged":
			for enemy: Dictionary in _live_enemies(state):
				var enemy_pos: Vector2i = enemy.get("pos", Vector2i(-1, -1))
				if PathUtils.manhattan(player_pos, enemy_pos) > int(action.get("range", 1)):
					continue
				if not PathUtils.has_line_of_sight(state.get("grid", []), player_pos, enemy_pos):
					continue
				targets.append(enemy_pos)
		"blast":
			var blast_range: int = int(action.get("range", 0))
			var radius: int = int(action.get("radius", 1))
			for tile: Vector2i in PathUtils.diamond_tiles(player_pos, blast_range, state.get("grid", [])):
				if tile == player_pos:
					continue
				if not PathUtils.is_passable(state.get("grid", []), tile):
					continue
				if not PathUtils.has_line_of_sight(state.get("grid", []), player_pos, tile):
					continue
				if _enemies_in_radius(state, tile, radius).is_empty():
					continue
				targets.append(tile)
	return targets

func apply_player_action(state: Dictionary, action: Dictionary, target_tile: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var player: Dictionary = next_state.get("player", {})
	var player_pos: Vector2i = player.get("pos", Vector2i.ZERO)
	var action_type: String = str(action.get("type", ""))
	match action_type:
		"move":
			if valid_targets_for_player_action(next_state, action).has(target_tile):
				player["pos"] = target_tile
				next_state["player"] = player
				_mark_first_move_used(next_state)
				_collect_loot_at_player(next_state)
				_log(next_state, "Moved to %s." % str(target_tile))
		"blink":
			if valid_targets_for_player_action(next_state, action).has(target_tile):
				player["pos"] = target_tile
				next_state["player"] = player
				_collect_loot_at_player(next_state)
				_log(next_state, "Blinked to %s." % str(target_tile))
		"melee":
			next_state = _attack_enemy_on_tile(next_state, target_tile, int(action.get("damage", 0)), "melee")
		"ranged":
			next_state = _attack_enemy_on_tile(next_state, target_tile, int(action.get("damage", 0)), "ranged")
		"blast":
			next_state = _blast_enemies(next_state, target_tile, int(action.get("damage", 0)), int(action.get("radius", 1)))
		"block":
			player["block"] = int(player.get("block", 0)) + int(action.get("amount", 0))
			next_state["player"] = player
			_log(next_state, "Gained %d block." % int(action.get("amount", 0)))
		"heal":
			var heal_amount: int = int(action.get("amount", 0))
			player["hp"] = mini(int(player.get("max_hp", 1)), int(player.get("hp", 0)) + heal_amount)
			next_state["player"] = player
			_log(next_state, "Recovered %d health." % heal_amount)
		"draw":
			next_state = _draw_cards_in_place(next_state, int(action.get("amount", 0)))
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
	var card: Dictionary = GameData.card_def(card_id)
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
		next_state = _lose_player_health(next_state, health_cost, true)
		_log(next_state, "Paid %d health for %s." % [health_cost, str(card.get("name", card_id))])
	next_state["cards_played_this_turn"] = int(next_state.get("cards_played_this_turn", 0)) + 1
	return next_state

func resolve_enemy_phase(state: Dictionary) -> Dictionary:
	return (resolve_enemy_phase_with_steps(state).get("state", state.duplicate(true)) as Dictionary).duplicate(true)

func resolve_enemy_phase_with_steps(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.state = int(next_state.get("rng_state", 0))
	var steps: Array[Dictionary] = []
	for enemy_index: int in range((next_state.get("enemies", []) as Array).size()):
		if combat_outcome(next_state) != "":
			break
		var enemy: Dictionary = (next_state.get("enemies", []) as Array)[enemy_index]
		if int(enemy.get("hp", 0)) <= 0:
			continue
		enemy["block"] = 0
		(next_state.get("enemies", []) as Array)[enemy_index] = enemy
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
				var before_state: Dictionary = next_state.duplicate(true)
				next_state = _resolve_enemy_action(next_state, enemy_index, action)
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
	var player: Dictionary = next_state.get("player", {})
	player["block"] = 0
	next_state["player"] = player
	next_state["turn"] = int(next_state.get("turn", 1)) + 1
	next_state["cards_played_this_turn"] = 0
	next_state["turn_flags"] = {
		"first_attack_bonus_used": false,
		"first_move_bonus_used": false
	}
	next_state = _draw_cards_in_place(next_state, int(next_state.get("draw_per_turn", BASE_DRAW_PER_TURN)))
	return next_state

func cards_remaining_this_turn(state: Dictionary) -> int:
	return maxi(
		0,
		int(state.get("cards_per_turn", BASE_CARDS_PER_TURN)) - int(state.get("cards_played_this_turn", 0))
	)

func attack_bonus_for_current_turn(state: Dictionary) -> int:
	return _attack_bonus_for_current_turn(state)

func move_bonus_for_current_turn(state: Dictionary) -> int:
	return _move_bonus_for_current_turn(state)

func final_damage_for_player_action(state: Dictionary, action: Dictionary) -> int:
	var action_type: String = str(action.get("type", ""))
	if action_type not in ["melee", "ranged", "blast"]:
		return int(action.get("damage", 0))
	var base_damage: int = int(action.get("damage", 0))
	return maxi(0, base_damage + _attack_bonus_for_current_turn(state))

func damage_modifiers_for_player_action(state: Dictionary, action: Dictionary) -> Array[Dictionary]:
	var modifiers: Array[Dictionary] = []
	var action_type: String = str(action.get("type", ""))
	if action_type not in ["melee", "ranged", "blast"]:
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
				"label": "Guard"
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
		"melee", "ranged", "blast":
			var hp_loss: int = int(before_player.get("hp", 0)) - int(after_player.get("hp", 0))
			var block_loss: int = int(before_player.get("block", 0)) - int(after_player.get("block", 0))
			if hp_loss <= 0 and block_loss <= 0:
				return {}
			return {
				"kind": action_type,
				"actor_key": _enemy_key(after_enemy),
				"actor_name": actor_name,
				"from": after_enemy.get("pos", Vector2i.ZERO),
				"to": after_player.get("pos", Vector2i.ZERO),
				"center": after_player.get("pos", Vector2i.ZERO),
				"radius": int(action.get("radius", 1)),
				"amount": hp_loss + block_loss,
				"hp_loss": hp_loss,
				"block_loss": block_loss,
				"label": "Strike" if action_type == "melee" else "Shot" if action_type == "ranged" else "Blast"
			}
		_:
			return {}

func _enemy_key(enemy: Dictionary) -> String:
	return "enemy_%d" % int(enemy.get("id", -1))

func _resolve_enemy_action(state: Dictionary, enemy_index: int, action: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = enemies[enemy_index]
	if int(enemy.get("hp", 0)) <= 0:
		return next_state
	var player: Dictionary = next_state.get("player", {})
	var player_pos: Vector2i = player.get("pos", Vector2i.ZERO)
	var action_type: String = str(action.get("type", ""))
	match action_type:
		"move_toward":
			var toward_tile: Vector2i = _best_move_toward(next_state, enemy_index, player_pos, int(action.get("range", 0)))
			enemy["pos"] = toward_tile
			enemies[enemy_index] = enemy
			_log(next_state, "%s closes in." % str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")))
		"move_away":
			var away_tile: Vector2i = _best_move_away(next_state, enemy_index, player_pos, int(action.get("range", 0)))
			enemy["pos"] = away_tile
			enemies[enemy_index] = enemy
			_log(next_state, "%s falls back." % str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")))
		"block":
			enemies[enemy_index] = enemy
		"heal_self":
			enemy["hp"] = mini(int(enemy.get("max_hp", 1)), int(enemy.get("hp", 0)) + int(action.get("amount", 0)))
			enemies[enemy_index] = enemy
			_log(next_state, "%s recovers %d health." % [
				str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")),
				int(action.get("amount", 0))
			])
		"melee":
			if PathUtils.manhattan(enemy.get("pos", Vector2i.ZERO), player_pos) <= int(action.get("range", 1)):
				next_state = _damage_player(next_state, int(action.get("damage", 0)), false)
				_log(next_state, "%s hits for %d." % [
					str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")),
					int(action.get("damage", 0))
				])
		"ranged":
			if PathUtils.manhattan(enemy.get("pos", Vector2i.ZERO), player_pos) <= int(action.get("range", 1)) and PathUtils.has_line_of_sight(next_state.get("grid", []), enemy.get("pos", Vector2i.ZERO), player_pos):
				next_state = _damage_player(next_state, int(action.get("damage", 0)), false)
				_log(next_state, "%s fires for %d." % [
					str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")),
					int(action.get("damage", 0))
				])
		"blast":
			var center: Vector2i = enemy.get("pos", Vector2i.ZERO)
			if int(action.get("range", 0)) > 0 and PathUtils.manhattan(enemy.get("pos", Vector2i.ZERO), player_pos) <= int(action.get("range", 0)):
				center = player_pos
			if PathUtils.manhattan(center, player_pos) <= int(action.get("radius", 1)):
				next_state = _damage_player(next_state, int(action.get("damage", 0)), false)
				_log(next_state, "%s unleashes a blast for %d." % [
					str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")),
					int(action.get("damage", 0))
				])
	return next_state

func _attack_enemy_on_tile(state: Dictionary, target_tile: Vector2i, base_damage: int, attack_kind: String) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var enemy_index: int = _enemy_index_at_tile(next_state, target_tile)
	if enemy_index < 0:
		return next_state
	var attack_bonus: int = _attack_bonus_for_current_turn(next_state)
	var damage: int = maxi(0, base_damage + attack_bonus)
	if damage <= 0:
		return next_state
	if attack_bonus > 0:
		_mark_first_attack_used(next_state)
	next_state = _damage_enemy(next_state, enemy_index, damage)
	_log(next_state, "%s for %d." % [attack_kind.capitalize(), damage])
	return next_state

func _blast_enemies(state: Dictionary, center: Vector2i, base_damage: int, radius: int) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var affected: Array[int] = _enemies_in_radius(next_state, center, radius)
	if affected.is_empty():
		return next_state
	var attack_bonus: int = _attack_bonus_for_current_turn(next_state)
	var damage: int = maxi(0, base_damage + attack_bonus)
	if attack_bonus > 0:
		_mark_first_attack_used(next_state)
	for enemy_index: int in affected:
		next_state = _damage_enemy(next_state, enemy_index, damage)
	_log(next_state, "Blast hits %d foe(s) for %d." % [affected.size(), damage])
	return next_state

func _damage_enemy(state: Dictionary, enemy_index: int, damage: int) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	var enemy: Dictionary = enemies[enemy_index]
	var block_amount: int = int(enemy.get("block", 0))
	var applied_to_block: int = mini(block_amount, damage)
	block_amount -= applied_to_block
	var remaining: int = damage - applied_to_block
	enemy["block"] = block_amount
	enemy["hp"] = maxi(0, int(enemy.get("hp", 0)) - remaining)
	enemies[enemy_index] = enemy
	if int(enemy.get("hp", 0)) <= 0:
		var reward_embers: int = int(GameData.enemy_def(str(enemy.get("type", ""))).get("reward_embers", 0))
		next_state["room_embers"] = int(next_state.get("room_embers", 0)) + reward_embers
		_log(next_state, "%s falls." % str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")))
	return next_state

func _damage_player(state: Dictionary, damage: int, bypass_block: bool) -> Dictionary:
	var next_state: Dictionary = state
	var player: Dictionary = next_state.get("player", {})
	var remaining: int = damage
	if not bypass_block:
		var block_amount: int = int(player.get("block", 0))
		var applied_to_block: int = mini(block_amount, remaining)
		block_amount -= applied_to_block
		remaining -= applied_to_block
		player["block"] = block_amount
	player["hp"] = maxi(0, int(player.get("hp", 0)) - remaining)
	next_state["player"] = player
	return next_state

func _lose_player_health(state: Dictionary, amount: int, bypass_block: bool) -> Dictionary:
	return _damage_player(state, amount, bypass_block)

func _draw_cards_in_place(state: Dictionary, count: int) -> Dictionary:
	var next_state: Dictionary = state
	var deck: Dictionary = next_state.get("deck", {}).duplicate(true)
	for _draw_index: int in range(count):
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
		occupied[enemy.get("pos", Vector2i(-1, -1))] = true
	return occupied

func _live_enemies(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) > 0:
			result.append(enemy)
	return result

func _enemy_index_at_tile(state: Dictionary, tile: Vector2i) -> int:
	var enemies: Array = state.get("enemies", [])
	for index: int in range(enemies.size()):
		var enemy: Dictionary = enemies[index]
		if int(enemy.get("hp", 0)) <= 0:
			continue
		if enemy.get("pos", Vector2i(-1, -1)) == tile:
			return index
	return -1

func _enemies_in_radius(state: Dictionary, center: Vector2i, radius: int) -> Array[int]:
	var indices: Array[int] = []
	var enemies: Array = state.get("enemies", [])
	for index: int in range(enemies.size()):
		var enemy: Dictionary = enemies[index]
		if int(enemy.get("hp", 0)) <= 0:
			continue
		if PathUtils.manhattan(center, enemy.get("pos", Vector2i(-1, -1))) <= radius:
			indices.append(index)
	return indices

func _assign_enemy_intent(state: Dictionary, enemy_index: int, rng: RandomNumberGenerator) -> void:
	var enemies: Array = state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return
	var enemy: Dictionary = enemies[enemy_index]
	var enemy_type: String = str(enemy.get("type", ""))
	var definition: Dictionary = GameData.enemy_def(enemy_type)
	var intents: Array = definition.get("intents", [])
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
	var enemy: Dictionary = enemies[enemy_index]
	var start: Vector2i = enemy.get("pos", Vector2i.ZERO)
	if move_range <= 0:
		return start
	var occupied: Dictionary = _occupied_enemy_tiles(state, int(enemy.get("id", -1)))
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
	var enemy: Dictionary = enemies[enemy_index]
	var start: Vector2i = enemy.get("pos", Vector2i.ZERO)
	if move_range <= 0:
		return start
	var occupied: Dictionary = _occupied_enemy_tiles(state, int(enemy.get("id", -1)))
	var reachable: Array[Vector2i] = PathUtils.reachable_tiles(state.get("grid", []), start, move_range, occupied)
	var best_tile: Vector2i = start
	var best_score: int = PathUtils.manhattan(start, target)
	for tile: Vector2i in reachable:
		var score: int = PathUtils.manhattan(tile, target)
		if score > best_score:
			best_tile = tile
			best_score = score
	return best_tile

func _attack_bonus_for_current_turn(state: Dictionary) -> int:
	if bool((state.get("turn_flags", {}) as Dictionary).get("first_attack_bonus_used", false)):
		return 0
	return GameData.stat_bonus_from_relics(state.get("relics", []), "first_attack_bonus")

func _move_bonus_for_current_turn(state: Dictionary) -> int:
	if bool((state.get("turn_flags", {}) as Dictionary).get("first_move_bonus_used", false)):
		return 0
	return GameData.stat_bonus_from_relics(state.get("relics", []), "first_move_bonus")

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

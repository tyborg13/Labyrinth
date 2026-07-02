extends RefCounted
class_name CombatEngine

const ElementData = preload("res://scripts/element_data.gd")
const GameData = preload("res://scripts/game_data.gd")
const PathUtils = preload("res://scripts/path_utils.gd")

const FATIGUE_BASE_DAMAGE: int = 15
const BASE_CARDS_PER_TURN: int = 2
const BASE_DRAW_PER_TURN: int = 2
const MAX_HAND_SIZE: int = 8
const MAX_LOG_LINES: int = 12
const PLAYER_BASE_INITIATIVE: int = 9
const PLAYER_MIN_INITIATIVE: int = 5
const ENEMY_MIN_INITIATIVE: int = 4
const DEFAULT_CARD_TIME_COST: int = 5
const MIN_CARD_TIME_COST: int = 1
const MAX_CARD_TIME_COST: int = 10
const DEFAULT_ENEMY_BASE_INITIATIVE: int = 12
const DEFAULT_ENEMY_INTENT_TIME_COST: int = 4
const TURN_ORDER_PREVIEW_LIMIT: int = 8
const ELEMENTAL_INTENSITY_ROOM_BASE: int = 1
const DEPTHS_PER_SEQUENCE: int = 4
const ENEMY_HP_SCALE_PER_SEQUENCE: float = 0.45
const ENEMY_HP_FLAT_BONUS_PER_SEQUENCE: int = 40
const ENEMY_DAMAGE_BONUS_PER_SEQUENCE: int = 20
const ENEMY_SUPPORT_BONUS_PER_SEQUENCE: int = 20
const ENEMY_HP_SCALE_DEPTH_ONE: float = 0.85
const ENEMY_HP_SCALE_DEPTH_THREE: float = 1.12
const ENEMY_DAMAGE_DELTA_DEPTH_ONE: int = -10
const ENEMY_DAMAGE_DELTA_DEPTH_THREE: int = 0
const ENEMY_SUPPORT_DELTA_DEPTH_ONE: int = -10
const ENEMY_SUPPORT_DELTA_DEPTH_THREE: int = 0
const ATTACK_ACTION_TYPES: Array[String] = ["melee", "ranged", "aoe", "push", "pull"]
const ELEMENTAL_ATTACK_ACTION_TYPES: Array[String] = ["melee", "ranged", "aoe"]
const ENEMY_SUPPORT_ACTION_TYPES: Array[String] = ["heal_ally", "guard_ally"]
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0)
]
const INTENSITY_BONUS_ADDITIVE_FIELDS := ["amount", "damage", "burn", "freeze", "shock", "poison", "bleed", "expose", "sunder", "chain", "push", "pull"]
const ZEKARION_TYPE: String = "zekarion"
const LIGHTNING_WISP_TYPE: String = "lightning_wisp"
const INVALID_TILE: Vector2i = Vector2i(-999999, -999999)
const DEFAULT_AOE_PATTERN: Array = [
	[0, 0],
	[1, 0],
	[-1, 0],
	[0, 1],
	[0, -1]
]
const TRAP_BLAST_OFFSETS: Array[Vector2i] = [
	Vector2i.ZERO,
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(-1, -1)
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
	var relic_ids: Array = player_snapshot.get("relics", []).duplicate()
	player["block"] = int(player.get("block", 0)) + GameData.stat_bonus_from_relics(relic_ids, "start_combat_block")
	player["stoneskin"] = int(player.get("stoneskin", 0)) + GameData.stat_bonus_from_relics(relic_ids, "start_combat_stoneskin")
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
		"elemental_intensity": _initial_elemental_intensity(str(room_layout.get("element", ElementData.NONE))),
		"elemental_intensity_gained_total": _empty_elemental_intensity(),
		"elemental_intensity_spent_total": _empty_elemental_intensity(),
		"grid": room_layout.get("grid", []).duplicate(true),
		"moss": room_layout.get("moss", {}).duplicate(true),
		"player": player,
		"enemies": enemies,
		"illusions": [],
		"next_illusion_id": 1,
		"traps": room_layout.get("traps", []).duplicate(true),
		"loot": room_layout.get("loot", []).duplicate(true),
		"terrain": room_layout.get("terrain", []).duplicate(true),
		"relics": relic_ids,
		"card_upgrades": (player_snapshot.get("card_upgrades", {}) as Dictionary).duplicate(true),
		"card_mods": (player_snapshot.get("card_mods", {}) as Dictionary).duplicate(true),
		"stats": GameData.normalized_progression_stats(player_snapshot.get("stats", {})),
		"level": int(player_snapshot.get("level", 1)),
		"hand_size": int(player_snapshot.get("hand_size", 5)) + GameData.stat_bonus_from_relics(relic_ids, "hand_size_bonus"),
		"cards_per_turn": int(player_snapshot.get("cards_per_turn", BASE_CARDS_PER_TURN)) + GameData.stat_bonus_from_relics(relic_ids, "cards_per_turn_bonus"),
		"draw_per_turn": int(player_snapshot.get("draw_per_turn", BASE_DRAW_PER_TURN)) + GameData.stat_bonus_from_relics(relic_ids, "draw_per_turn_bonus"),
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
		"initiative_clock": 0,
		"activation_seq": 0,
		"current_actor": _player_actor_entry(0, 0),
		"turn_queue": [],
		"player_turn_time_spent": 0,
		"player_turn_restrictions": {
			"frozen": false,
			"shocked": false,
			"immobilized": false
		},
		"pending_player_trap_restriction": "",
		"turn_flags": {
			"first_attack_bonus_used": false,
			"first_move_bonus_used": false
		},
		"relic_flags": {},
		"death_rewards": [],
		"room_embers": 0,
		"recovered_embers_total": 0,
		"rng_state": rng.state,
		"log": []
	}
	state = _apply_start_combat_relic_effects(state, player_snapshot)
	for enemy_index: int in range((state.get("enemies", []) as Array).size()):
		_assign_enemy_intent(state, enemy_index, rng)
	state["rng_state"] = rng.state
	state = _initialize_initiative_queue(state)
	state = _draw_cards_in_place(state, maxi(0, int(state.get("hand_size", 5)) + GameData.stat_bonus_from_relics(state.get("relics", []), "opening_draw_bonus")))
	_log(state, "Entered %s." % state.get("room_name", "a room"))
	return state

func _apply_start_combat_relic_effects(state: Dictionary, player_snapshot: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var player: Dictionary = _normalized_player(next_state.get("player", {}))
	var deck_cards: Array = player_snapshot.get("deck_cards", []).duplicate()
	for effect: Dictionary in _relic_effects(next_state):
		match str(effect.get("type", "")):
			"start_combat_stoneskin_per_deck_element":
				var element_id: String = str(effect.get("element", ElementData.NONE))
				var count: int = 0
				for card_id_var: Variant in deck_cards:
					if GameData.card_element(str(card_id_var)) == element_id:
						count += 1
				if count < int(effect.get("threshold", 1)):
					continue
				var bonus: int = count * GameData.fixed_point_amount(int(effect.get("value", 0)))
				if effect.has("max_value"):
					bonus = mini(bonus, GameData.fixed_point_amount(int(effect.get("max_value", bonus))))
				player["stoneskin"] = int(player.get("stoneskin", 0)) + bonus
			"start_combat_intensity":
				if not _start_combat_intensity_effect_applies(effect, deck_cards):
					continue
				var start_element: String = str(effect.get("element", ElementData.NONE))
				var start_amount: int = int(effect.get("amount", effect.get("value", 0)))
				next_state["player"] = player
				next_state = _gain_elemental_intensity(next_state, start_element, start_amount, _relic_effect_source_name(effect))
				player = _normalized_player(next_state.get("player", {}))
	next_state["player"] = player
	return next_state

func card_def(card_id: String, state: Dictionary = {}) -> Dictionary:
	return GameData.card_def_for_progression(card_id, state)

func player_action_needs_target(action: Dictionary) -> bool:
	var action_type: String = str(action.get("type", ""))
	if action_type == "aoe":
		return int(action.get("range", 0)) > 0
	return action_type in ["move", "blink", "melee", "ranged", "push", "pull", "illusion"]

func player_action_needs_orientation(action: Dictionary) -> bool:
	var action_type: String = str(action.get("type", ""))
	if action_type == "aoe":
		return int(action.get("range", 0)) > 0 and _aoe_pattern_variants(action).size() > 1
	return _action_has_forced_movement(action)

func player_action_can_resolve(state: Dictionary, action: Dictionary) -> bool:
	if not action_intensity_requirement_met(state, action):
		return false
	var action_type: String = str(action.get("type", ""))
	var restrictions: Dictionary = state.get("player_turn_restrictions", {})
	if bool(restrictions.get("frozen", false)):
		return false
	if bool(restrictions.get("shocked", false)):
		if action_type not in ["move", "blink"]:
			return false
	if bool(restrictions.get("immobilized", false)) and action_type in ["move", "blink"]:
		return false
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
			var melee_range: int = int(action.get("range", 1))
			for enemy: Dictionary in _live_enemies(state):
				if _enemy_distance_to_tile(enemy, player_pos) <= melee_range:
					var enemy_tile: Vector2i = _closest_enemy_tile_to(enemy, player_pos)
					if not targets.has(enemy_tile):
						targets.append(enemy_tile)
			for terrain: Dictionary in _live_terrain(state):
				var terrain_pos: Vector2i = terrain.get("pos", Vector2i.ZERO)
				if PathUtils.manhattan(player_pos, terrain_pos) <= melee_range and not targets.has(terrain_pos):
					targets.append(terrain_pos)
			for trap: Dictionary in _live_traps(state):
				var trap_pos: Vector2i = trap.get("pos", Vector2i.ZERO)
				if PathUtils.manhattan(player_pos, trap_pos) <= melee_range and not targets.has(trap_pos):
					targets.append(trap_pos)
		"ranged":
			var ranged_range: int = int(action.get("range", 1))
			for enemy: Dictionary in _live_enemies(state):
				var enemy_pos: Vector2i = _closest_enemy_tile_to(enemy, player_pos)
				if PathUtils.manhattan(player_pos, enemy_pos) > ranged_range:
					continue
				if not PathUtils.has_line_of_sight(state.get("grid", []), player_pos, enemy_pos):
					continue
				if not targets.has(enemy_pos):
					targets.append(enemy_pos)
			for terrain: Dictionary in _live_terrain(state):
				var terrain_pos: Vector2i = terrain.get("pos", Vector2i.ZERO)
				if PathUtils.manhattan(player_pos, terrain_pos) > ranged_range:
					continue
				if not PathUtils.has_line_of_sight(state.get("grid", []), player_pos, terrain_pos):
					continue
				if not targets.has(terrain_pos):
					targets.append(terrain_pos)
			for trap: Dictionary in _live_traps(state):
				var trap_pos: Vector2i = trap.get("pos", Vector2i.ZERO)
				if PathUtils.manhattan(player_pos, trap_pos) > ranged_range:
					continue
				if not PathUtils.has_line_of_sight(state.get("grid", []), player_pos, trap_pos):
					continue
				if not targets.has(trap_pos):
					targets.append(trap_pos)
		"aoe":
			var aoe_range: int = int(action.get("range", 0))
			if aoe_range <= 0:
				if _has_attackable_in_tiles(state, _best_aoe_tiles_for_target(state, action, player_pos, false)):
					targets.append(player_pos)
			else:
				for tile: Vector2i in PathUtils.diamond_tiles(player_pos, aoe_range, state.get("grid", [])):
					if tile == player_pos:
						continue
					if not PathUtils.is_passable(state.get("grid", []), tile):
						continue
					if not PathUtils.has_line_of_sight(state.get("grid", []), player_pos, tile):
						continue
					if not _has_attackable_in_tiles(state, _best_aoe_tiles_for_target(state, action, tile, false)):
						continue
					targets.append(tile)
		"push", "pull":
			var forced_range: int = int(action.get("range", 1))
			var resolved_force_action: Dictionary = _action_with_intensity_bonus(state, action)
			var force_direction: Vector2i = _action_force_direction(resolved_force_action)
			var force_amount: int = _forced_movement_amount(resolved_force_action)
			var pushing: bool = action_type == "push"
			for enemy_index: int in range((state.get("enemies", []) as Array).size()):
				var enemy: Dictionary = _normalized_enemy((state.get("enemies", []) as Array)[enemy_index] as Dictionary)
				if int(enemy.get("hp", 0)) <= 0:
					continue
				var enemy_pos: Vector2i = _closest_enemy_tile_to(enemy, player_pos)
				if PathUtils.manhattan(player_pos, enemy_pos) > forced_range:
					continue
				if forced_range > 1 and not PathUtils.has_line_of_sight(state.get("grid", []), player_pos, enemy_pos):
					continue
				if force_direction != Vector2i.ZERO:
					if not _forced_direction_can_move_enemy(state, enemy_index, force_direction, player_pos, pushing):
						continue
				elif _force_directions_for_enemy(state, enemy_index, player_pos, pushing, force_amount).is_empty():
					continue
				if not targets.has(enemy_pos):
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
	var resolved_action: Dictionary = _action_with_intensity_bonus(next_state, action)
	match action_type:
		"move":
			if valid_targets_for_player_action(next_state, action).has(target_tile):
				var movement_path: Array[Vector2i] = path_for_player_action(next_state, action, target_tile)
				next_state = _move_player_along_path(next_state, movement_path)
				_mark_first_move_used(next_state)
				next_state = _trigger_long_move_relics(next_state, movement_path.size() - 1)
				_log(next_state, "Moved to %s." % str((next_state.get("player", {}) as Dictionary).get("pos", target_tile)))
		"blink":
			if valid_targets_for_player_action(next_state, action).has(target_tile):
				player["pos"] = target_tile
				next_state["player"] = player
				_collect_loot_at_player(next_state)
				next_state = _trigger_trap_on_player(next_state)
				next_state = _trigger_blink_relics(next_state)
				_log(next_state, "Blinked to %s." % str(target_tile))
		"melee":
			next_state = _attack_target_on_tile(next_state, action, target_tile, "melee")
		"ranged":
			next_state = _attack_target_on_tile(next_state, action, target_tile, "ranged")
		"aoe":
			next_state = _aoe_enemies(next_state, action, target_tile)
		"push":
			next_state = _push_or_pull_target(next_state, action, target_tile, true)
		"pull":
			next_state = _push_or_pull_target(next_state, action, target_tile, false)
		"block":
			player["block"] = int(player.get("block", 0)) + int(resolved_action.get("amount", 0))
			next_state["player"] = player
			_log(next_state, "Gained %d block." % int(resolved_action.get("amount", 0)))
		"stoneskin":
			var stoneskin_before: int = int(player.get("stoneskin", 0))
			player["stoneskin"] = int(player.get("stoneskin", 0)) + int(resolved_action.get("amount", 0))
			next_state["player"] = player
			next_state = _trigger_stoneskin_relics(next_state, int(player.get("stoneskin", 0)) - stoneskin_before)
			_log(next_state, "Gained %d stoneskin." % int(resolved_action.get("amount", 0)))
		"heal":
			var heal_amount: int = int(resolved_action.get("amount", 0))
			player["hp"] = mini(int(player.get("max_hp", 1)), int(player.get("hp", 0)) + heal_amount)
			next_state["player"] = player
			_log(next_state, "Recovered %d health." % heal_amount)
		"draw":
			next_state = _draw_cards_in_place(next_state, int(resolved_action.get("amount", 0)))
		"card_play":
			var bonus_card_plays: int = maxi(0, int(resolved_action.get("amount", 0)))
			next_state["card_play_bonus_this_turn"] = int(next_state.get("card_play_bonus_this_turn", 0)) + bonus_card_plays
			if bonus_card_plays > 0:
				_log(next_state, "Gained %d card play(s)." % bonus_card_plays)
		"intensity":
			var element_id: String = _action_intensity_element(action)
			var amount: int = maxi(0, int(resolved_action.get("amount", 0)))
			next_state = _gain_elemental_intensity(next_state, element_id, amount)
		"illusion":
			if valid_targets_for_player_action(next_state, action).has(target_tile):
				next_state = _create_illusion(next_state, target_tile, int(resolved_action.get("health", resolved_action.get("amount", 0))))
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
	next_state["player_turn_time_spent"] = int(next_state.get("player_turn_time_spent", 0)) + card_time_cost_from_def(card)
	next_state = _apply_pending_player_trap_restriction(next_state)
	var restrictions: Dictionary = next_state.get("player_turn_restrictions", {})
	if bool(restrictions.get("frozen", false)):
		next_state["cards_played_this_turn"] = _card_play_capacity(next_state)
	return next_state

func is_player_turn(state: Dictionary) -> bool:
	var current_actor: Dictionary = state.get("current_actor", {})
	return str(current_actor.get("kind", "player")) == "player"

func player_base_initiative(state: Dictionary) -> int:
	var stats: Dictionary = GameData.normalized_progression_stats(state.get("stats", {}))
	return maxi(PLAYER_MIN_INITIATIVE, PLAYER_BASE_INITIATIVE - int(stats.get("agility", 0)))

func card_time_cost(card_id: String, state: Dictionary = {}) -> int:
	return card_time_cost_from_def(card_def(card_id, state))

func card_time_cost_from_def(card: Dictionary) -> int:
	if card.has("time"):
		return clampi(int(card.get("time", DEFAULT_CARD_TIME_COST)), MIN_CARD_TIME_COST, MAX_CARD_TIME_COST)
	return _estimated_card_time_cost(card)

func current_turn_order(state: Dictionary, limit: int = TURN_ORDER_PREVIEW_LIMIT) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var current_actor: Dictionary = _resolved_actor_entry(state, state.get("current_actor", {}))
	if not current_actor.is_empty():
		current_actor["active"] = true
		result.append(current_actor)
	var queue: Array = _sorted_turn_queue(state.get("turn_queue", []))
	var preview_queue: Array = []
	for entry_var: Variant in queue:
		preview_queue.append(entry_var)
		if typeof(entry_var) == TYPE_DICTIONARY:
			var projected_after_entry: Dictionary = _projected_next_entry_after_entry(state, entry_var as Dictionary)
			if not projected_after_entry.is_empty():
				preview_queue.append(projected_after_entry)
	var projected_current_future: Dictionary = _projected_next_entry_for_current_actor(state, current_actor)
	if not projected_current_future.is_empty():
		preview_queue.append(projected_current_future)
	queue = _sorted_turn_queue(preview_queue)
	var clock: int = int(state.get("initiative_clock", 0))
	for entry_var: Variant in queue:
		if result.size() >= limit:
			break
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = _resolved_actor_entry(state, entry_var as Dictionary)
		if entry.is_empty():
			continue
		entry["active"] = false
		entry["eta"] = maxi(0, int(entry.get("time", clock)) - clock)
		result.append(entry)
	return result

func finish_player_activation(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	if combat_outcome(next_state) != "" or not is_player_turn(next_state):
		return next_state
	var scheduled_time: int = (
		int(next_state.get("initiative_clock", 0))
		+ player_base_initiative(next_state)
		+ maxi(0, int(next_state.get("player_turn_time_spent", 0)))
	)
	_schedule_actor(next_state, _player_actor_entry(scheduled_time, 0))
	next_state["current_actor"] = {}
	return next_state

func advance_to_next_player_turn_with_steps(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var steps: Array[Dictionary] = []
	var player_turn_before_state: Dictionary = {}
	var safety: int = 0
	while combat_outcome(next_state) == "" and safety < 100:
		safety += 1
		var before_pop_state: Dictionary = next_state.duplicate(true)
		var popped: Dictionary = _pop_next_actor(next_state)
		next_state = (popped.get("state", next_state) as Dictionary).duplicate(true)
		var entry: Dictionary = popped.get("entry", {})
		if entry.is_empty():
			next_state["current_actor"] = _player_actor_entry(int(next_state.get("initiative_clock", 0)), int(next_state.get("activation_seq", 0)))
			player_turn_before_state = next_state.duplicate(true)
			next_state = prepare_next_player_turn(next_state)
			_append_turn_order_step(steps, before_pop_state, next_state, "activate")
			break
		match str(entry.get("kind", "")):
			"player":
				player_turn_before_state = next_state.duplicate(true)
				next_state = prepare_next_player_turn(next_state)
				_append_turn_order_step(steps, before_pop_state, next_state, "activate")
				break
			"enemy":
				_append_turn_order_step(steps, before_pop_state, next_state, "activate")
				var enemy_index: int = _enemy_index_for_id(next_state, int(entry.get("enemy_id", -1)))
				if enemy_index < 0:
					continue
				var turn_result: Dictionary = resolve_enemy_turn_with_steps(next_state, enemy_index)
				next_state = (turn_result.get("state", next_state) as Dictionary).duplicate(true)
				for step_var: Variant in turn_result.get("steps", []):
					if typeof(step_var) == TYPE_DICTIONARY:
						steps.append(step_var)
				if combat_outcome(next_state) != "":
					break
				enemy_index = _enemy_index_for_id(next_state, int(entry.get("enemy_id", -1)))
				var before_reschedule_state: Dictionary = next_state.duplicate(true)
				if enemy_index >= 0:
					var enemy: Dictionary = _normalized_enemy((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary)
					if int(enemy.get("hp", 0)) > 0:
						_schedule_enemy_after_turn(next_state, enemy, int(turn_result.get("time_cost", 0)))
				next_state["current_actor"] = {}
				_append_turn_order_step(steps, before_reschedule_state, next_state, "reschedule")
			_:
				continue
	if safety >= 100:
		_log(next_state, "The initiative clock stalls.")
	return {
		"state": next_state,
		"steps": steps,
		"player_turn_before_state": player_turn_before_state
	}

func preview_revealed_enemy_actions_before_player_turn_with_steps(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var steps: Array[Dictionary] = []
	var player_turn_before_state: Dictionary = {}
	var initially_visible_enemy_ids: Dictionary = {}
	var revealed_enemy_ids: Dictionary = {}
	var unrevealed_before_player: bool = false
	for enemy_var: Variant in next_state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var initial_enemy: Dictionary = _normalized_enemy(enemy_var as Dictionary)
		if int(initial_enemy.get("hp", 0)) <= 0:
			continue
		if (initial_enemy.get("intent", {}) as Dictionary).is_empty():
			continue
		initially_visible_enemy_ids[int(initial_enemy.get("id", -1))] = true
	var safety: int = 0
	while combat_outcome(next_state) == "" and safety < 100:
		safety += 1
		var before_pop_state: Dictionary = next_state.duplicate(true)
		var popped: Dictionary = _pop_next_actor(next_state)
		next_state = (popped.get("state", next_state) as Dictionary).duplicate(true)
		var entry: Dictionary = popped.get("entry", {})
		if entry.is_empty():
			next_state["current_actor"] = _player_actor_entry(int(next_state.get("initiative_clock", 0)), int(next_state.get("activation_seq", 0)))
			player_turn_before_state = next_state.duplicate(true)
			break
		match str(entry.get("kind", "")):
			"player":
				player_turn_before_state = next_state.duplicate(true)
				break
			"enemy":
				var enemy_id: int = int(entry.get("enemy_id", -1))
				var enemy_index: int = _enemy_index_for_id(next_state, enemy_id)
				if enemy_index < 0:
					continue
				var enemy: Dictionary = _normalized_enemy((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary)
				var intent: Dictionary = enemy.get("intent", {})
				if not initially_visible_enemy_ids.has(enemy_id) or revealed_enemy_ids.has(enemy_id) or intent.is_empty():
					unrevealed_before_player = true
					next_state = before_pop_state.duplicate(true)
					break
				revealed_enemy_ids[enemy_id] = true
				var turn_result: Dictionary = resolve_enemy_turn_with_steps(next_state, enemy_index)
				next_state = (turn_result.get("state", next_state) as Dictionary).duplicate(true)
				for step_var: Variant in turn_result.get("steps", []):
					if typeof(step_var) == TYPE_DICTIONARY:
						steps.append(step_var)
				if combat_outcome(next_state) != "":
					break
				enemy_index = _enemy_index_for_id(next_state, enemy_id)
				if enemy_index >= 0:
					enemy = _normalized_enemy((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary)
					if int(enemy.get("hp", 0)) > 0:
						_schedule_enemy_after_turn(next_state, enemy, int(turn_result.get("time_cost", 0)))
				next_state["current_actor"] = {}
			_:
				continue
	if safety >= 100:
		_log(next_state, "The initiative clock stalls.")
	return {
		"state": next_state,
		"steps": steps,
		"player_turn_before_state": player_turn_before_state,
		"unrevealed_before_player": unrevealed_before_player
	}

func resolve_enemy_phase(state: Dictionary) -> Dictionary:
	return (resolve_enemy_phase_with_steps(state).get("state", state.duplicate(true)) as Dictionary).duplicate(true)

func resolve_enemy_turn_with_steps(state: Dictionary, enemy_index: int) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.state = int(next_state.get("rng_state", 0))
	var steps: Array[Dictionary] = []
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return {"state": next_state, "steps": steps, "time_cost": 0}
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	if int(enemy.get("hp", 0)) <= 0:
		return {"state": next_state, "steps": steps, "time_cost": 0}
	next_state["current_actor"] = _enemy_actor_entry(next_state, enemy, int(next_state.get("initiative_clock", 0)), int(next_state.get("activation_seq", 0)))
	var intent: Dictionary = (enemy.get("intent", {}) as Dictionary).duplicate(true)
	var turn_time_cost: int = _enemy_intent_time_cost(intent)
	enemy["block"] = 0
	(next_state.get("enemies", []) as Array)[enemy_index] = enemy
	var turn_setup: Dictionary = _resolve_enemy_start_of_turn(next_state, enemy_index)
	next_state = (turn_setup.get("state", next_state) as Dictionary).duplicate(true)
	for step_var: Variant in turn_setup.get("steps", []):
		if typeof(step_var) == TYPE_DICTIONARY:
			steps.append(step_var)
	if combat_outcome(next_state) != "":
		next_state["rng_state"] = rng.state
		return {"state": next_state, "steps": steps, "time_cost": turn_time_cost}
	if bool(turn_setup.get("skip_all", false)):
		_assign_enemy_intent(next_state, enemy_index, rng)
		next_state["rng_state"] = rng.state
		return {"state": next_state, "steps": steps, "time_cost": 0}
	var shocked: bool = bool(turn_setup.get("shocked", false))
	var immobilized: bool = bool(turn_setup.get("immobilized", false))
	enemy = _normalized_enemy((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary)
	intent = enemy.get("intent", {})
	if not intent.is_empty():
		steps.append({
			"kind": "intent",
			"actor_key": _enemy_key(enemy),
			"actor_name": str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")),
			"tile": enemy.get("pos", Vector2i.ZERO),
			"intent_name": str(intent.get("name", "Action"))
		})
		var actions: Array = intent.get("actions", [])
		for action_index: int in range(actions.size()):
			var action_var: Variant = actions[action_index]
			if typeof(action_var) != TYPE_DICTIONARY:
				continue
			var action: Dictionary = action_var
			if combat_outcome(next_state) != "":
				break
			if shocked and not _enemy_action_is_movement(action):
				continue
			if immobilized and _enemy_action_is_movement(action):
				continue
			var before_state: Dictionary = next_state.duplicate(true)
			var followup_action: Dictionary = {}
			if not shocked:
				followup_action = _next_enemy_followup_attack_action(actions, action_index + 1)
			next_state = _resolve_enemy_action(next_state, enemy_index, action, rng, followup_action)
			var step: Dictionary = _enemy_action_step(before_state, next_state, enemy_index, action)
			if not step.is_empty():
				steps.append(step)
	if combat_outcome(next_state) == "":
		_assign_enemy_intent(next_state, enemy_index, rng)
	next_state["rng_state"] = rng.state
	return {
		"state": next_state,
		"steps": steps,
		"time_cost": turn_time_cost
	}

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
	var occupied: Dictionary = _enemy_threat_path_blockers(state, enemy, true, true)
	var blocked_target: Vector2i = Vector2i(-999, -999)
	var frontier: Array[Vector2i] = _vector2i_values([enemy.get("pos", Vector2i.ZERO)])
	var move_lookup: Dictionary = {}
	var attack_lookup: Dictionary = {}
	for action_var: Variant in intent.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var
		match str(action.get("type", "")):
			"move_toward", "move_away":
				var next_lookup: Dictionary = {}
				for start_tile: Vector2i in frontier:
					next_lookup[start_tile] = true
					for move_tile: Vector2i in _threat_movement_tiles(state, enemy, start_tile, action, occupied, blocked_target):
						move_lookup[move_tile] = true
						next_lookup[move_tile] = true
				if not next_lookup.is_empty():
					frontier = _sorted_tiles_from_lookup(next_lookup)
			"melee", "ranged", "aoe", "push", "pull", "lightning_strikes":
				for start_tile: Vector2i in frontier:
					for attack_tile: Vector2i in _threat_attack_tiles(state, enemy, start_tile, action):
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
		var immobilized: bool = bool(turn_setup.get("immobilized", false))
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
			var actions: Array = intent.get("actions", [])
			for action_index: int in range(actions.size()):
				var action_var: Variant = actions[action_index]
				if typeof(action_var) != TYPE_DICTIONARY:
					continue
				var action: Dictionary = action_var
				if combat_outcome(next_state) != "":
					break
				if shocked and not _enemy_action_is_movement(action):
					continue
				if immobilized and _enemy_action_is_movement(action):
					continue
				var before_state: Dictionary = next_state.duplicate(true)
				var followup_action: Dictionary = {}
				if not shocked:
					followup_action = _next_enemy_followup_attack_action(actions, action_index + 1)
				next_state = _resolve_enemy_action(next_state, enemy_index, action, rng, followup_action)
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
	next_state["current_actor"] = _player_actor_entry(int(next_state.get("initiative_clock", 0)), int(next_state.get("activation_seq", 0)))
	var player: Dictionary = _normalized_player(next_state.get("player", {}))
	player["block"] = 0
	next_state["player"] = player
	next_state["turn"] = int(next_state.get("turn", 1)) + 1
	next_state["player_turn_time_spent"] = 0
	next_state["cards_played_this_turn"] = 0
	next_state["death_bonus_card_plays_this_turn"] = 0
	next_state["card_play_bonus_this_turn"] = 0
	next_state["player_turn_restrictions"] = {
		"frozen": false,
		"shocked": false,
		"immobilized": false
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
	if bool(restrictions.get("frozen", false)):
		next_state["cards_played_this_turn"] = _card_play_capacity(next_state)
	return next_state

func cards_remaining_this_turn(state: Dictionary) -> int:
	if not is_player_turn(state):
		return 0
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

func forced_movement_tiles_for_player_action(state: Dictionary, action: Dictionary, target_tile: Vector2i) -> Array[Vector2i]:
	var resolved_action: Dictionary = _action_with_intensity_bonus(state, action)
	var force_direction: Vector2i = _action_force_direction(resolved_action)
	if force_direction == Vector2i.ZERO:
		return []
	if not force_directions_for_player_action(state, action, target_tile).has(force_direction):
		return []
	var enemy_index: int = _enemy_index_at_tile(state, target_tile)
	if enemy_index < 0:
		return []
	var amount: int = _forced_movement_amount(resolved_action)
	if amount <= 0:
		return []
	return _enemy_direction_path(state, enemy_index, force_direction, amount)

func force_directions_for_player_action(state: Dictionary, action: Dictionary, target_tile: Vector2i) -> Array[Vector2i]:
	var resolved_action: Dictionary = _action_with_intensity_bonus(state, action)
	var enemy_index: int = _enemy_index_at_tile(state, target_tile)
	if enemy_index < 0:
		return []
	var player_pos: Vector2i = (_normalized_player(state.get("player", {}))).get("pos", Vector2i.ZERO)
	return _force_directions_for_enemy(
		state,
		enemy_index,
		player_pos,
		_forced_movement_pushes(resolved_action),
		_forced_movement_amount(resolved_action)
	)

func final_damage_for_player_action(state: Dictionary, action: Dictionary) -> int:
	var resolved_action: Dictionary = _action_with_intensity_bonus(state, action)
	var action_type: String = str(resolved_action.get("type", ""))
	if action_type not in ATTACK_ACTION_TYPES:
		return int(resolved_action.get("damage", 0))
	var base_damage: int = int(resolved_action.get("damage", 0))
	return maxi(0, base_damage + _attack_bonus_for_current_turn(state) + _conditional_attack_bonus_for_action(state, resolved_action))

func damage_modifiers_for_player_action(state: Dictionary, action: Dictionary) -> Array[Dictionary]:
	var modifiers: Array[Dictionary] = []
	var action_type: String = str(action.get("type", ""))
	if action_type not in ATTACK_ACTION_TYPES:
		return modifiers
	var attack_bonus: int = _attack_bonus_for_current_turn(state)
	if attack_bonus != 0:
		modifiers.append({
			"source": "Ember Lens",
			"kind": "relic",
			"amount": attack_bonus,
			"detail": "First attack this turn"
		})
	for modifier: Dictionary in _intensity_bonus_damage_modifiers_for_action(state, action):
		modifiers.append(modifier)
	for modifier: Dictionary in _conditional_attack_modifiers_for_action(state, action):
		modifiers.append(modifier)
	return modifiers

func elemental_intensities(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var raw: Variant = state.get("elemental_intensity", {})
	var source: Dictionary = {}
	if typeof(raw) == TYPE_DICTIONARY:
		source = raw as Dictionary
	for element_id: String in ElementData.all_elements():
		result[element_id] = maxi(0, int(source.get(element_id, 0)))
	return result

func elemental_intensity(state: Dictionary, element_id: String) -> int:
	if not ElementData.is_elemental(element_id):
		return 0
	return int(elemental_intensities(state).get(element_id, 0))

func elemental_intensity_counter(state: Dictionary, counter_key: String) -> Dictionary:
	var result: Dictionary = _empty_elemental_intensity()
	var raw: Variant = state.get(counter_key, {})
	if typeof(raw) != TYPE_DICTIONARY:
		return result
	var source: Dictionary = raw as Dictionary
	for element_id: String in ElementData.all_elements():
		result[element_id] = maxi(0, int(source.get(element_id, 0)))
	return result

func action_intensity_requirement(action: Dictionary) -> Dictionary:
	return _action_intensity_requirement(action)

func action_intensity_requirement_met(state: Dictionary, action: Dictionary) -> bool:
	var requirement: Dictionary = _action_intensity_requirement(action)
	if requirement.is_empty():
		return true
	return elemental_intensity(state, str(requirement.get("element", ElementData.NONE))) >= int(requirement.get("amount", 0))

func action_intensity_bonus(action: Dictionary) -> Dictionary:
	return _action_intensity_bonus(action)

func action_intensity_bonus_requirement(action: Dictionary) -> Dictionary:
	return _action_intensity_bonus_requirement(action)

func action_intensity_bonus_requirement_met(state: Dictionary, action: Dictionary) -> bool:
	var requirement: Dictionary = _action_intensity_bonus_requirement(action)
	if requirement.is_empty():
		return false
	return elemental_intensity(state, str(requirement.get("element", ElementData.NONE))) >= int(requirement.get("amount", 0))

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
		"heal_ally":
			var heal_target_index: int = _enemy_support_target_index(before_state, enemy_index, action)
			if heal_target_index < 0 or heal_target_index >= before_enemies.size() or heal_target_index >= after_enemies.size():
				return {}
			var before_heal_target: Dictionary = before_enemies[heal_target_index]
			var after_heal_target: Dictionary = after_enemies[heal_target_index]
			var ally_heal_amount: int = int(after_heal_target.get("hp", 0)) - int(before_heal_target.get("hp", 0))
			if ally_heal_amount <= 0:
				return {}
			var heal_target_name: String = _enemy_display_name(after_heal_target)
			return {
				"kind": "heal",
				"actor_key": _enemy_key(after_heal_target),
				"actor_name": heal_target_name,
				"source_actor_key": _enemy_key(after_enemy),
				"source_actor_name": actor_name,
				"target_name": heal_target_name,
				"tile": after_heal_target.get("pos", Vector2i.ZERO),
				"amount": ally_heal_amount,
				"label": "Heal Self" if heal_target_index == enemy_index else "Heal Ally"
			}
		"guard_ally":
			var guard_target_index: int = _enemy_support_target_index(before_state, enemy_index, action)
			if guard_target_index < 0 or guard_target_index >= before_enemies.size() or guard_target_index >= after_enemies.size():
				return {}
			var before_guard_target: Dictionary = before_enemies[guard_target_index]
			var after_guard_target: Dictionary = after_enemies[guard_target_index]
			var guard_amount: int = int(after_guard_target.get("block", 0)) - int(before_guard_target.get("block", 0))
			if guard_amount <= 0:
				return {}
			var guard_target_name: String = _enemy_display_name(after_guard_target)
			return {
				"kind": "block",
				"actor_key": _enemy_key(after_guard_target),
				"actor_name": guard_target_name,
				"source_actor_key": _enemy_key(after_enemy),
				"source_actor_name": actor_name,
				"target_name": guard_target_name,
				"tile": after_guard_target.get("pos", Vector2i.ZERO),
				"amount": guard_amount,
				"sfx_id": str(action.get("sfx_id", action.get("block_sfx_id", ""))),
				"sfx_category": str(action.get("sfx_category", action.get("block_sfx_category", ""))),
				"label": "Guard Self" if guard_target_index == enemy_index else "Guard Ally"
			}
		"melee", "ranged", "aoe", "push", "pull", "lightning_strikes":
			var hp_loss: int = int(before_player.get("hp", 0)) - int(after_player.get("hp", 0))
			var block_loss: int = int(before_player.get("block", 0)) - int(after_player.get("block", 0))
			var stoneskin_loss: int = int(before_player.get("stoneskin", 0)) - int(after_player.get("stoneskin", 0))
			var target_losses: Array[Dictionary] = _actor_target_losses(before_state, after_state)
			var terrain_losses: Array[Dictionary] = _terrain_target_losses(before_state, after_state)
			var triggered_traps: Array[Dictionary] = _triggered_traps_between(before_state, after_state)
			var moved: bool = before_player.get("pos", Vector2i.ZERO) != after_player.get("pos", Vector2i.ZERO)
			var status_text: String = _player_status_step_text(before_player, after_player, action)
			if target_losses.is_empty() and terrain_losses.is_empty() and triggered_traps.is_empty() and not moved and status_text.is_empty() and action_type != "lightning_strikes":
				return {}
			var target_tile: Vector2i = after_player.get("pos", Vector2i.ZERO)
			if not target_losses.is_empty():
				target_tile = (target_losses[0] as Dictionary).get("tile", target_tile)
			elif not terrain_losses.is_empty():
				target_tile = (terrain_losses[0] as Dictionary).get("tile", target_tile)
			elif not triggered_traps.is_empty():
				target_tile = (triggered_traps[0] as Dictionary).get("pos", target_tile)
			var center_tile: Vector2i = target_tile
			if action_type == "aoe" and int(action.get("range", 0)) <= 0:
				center_tile = before_enemy.get("pos", Vector2i.ZERO)
			var aoe_tiles: Array[Vector2i] = []
			if action_type == "aoe":
				var resolved_step_action: Dictionary = _enemy_action_oriented_to_target(action, before_enemy, target_tile)
				aoe_tiles = _enemy_aoe_tiles_for_target(before_state, before_enemy, resolved_step_action, center_tile, true)
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
				"terrain_losses": terrain_losses,
				"triggered_traps": triggered_traps,
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

func _terrain_target_losses(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var losses: Array[Dictionary] = []
	var after_by_id: Dictionary = {}
	for after_terrain_var: Variant in after_state.get("terrain", []):
		if typeof(after_terrain_var) != TYPE_DICTIONARY:
			continue
		var after_terrain: Dictionary = _normalized_terrain(after_terrain_var)
		after_by_id[str(after_terrain.get("id", ""))] = after_terrain
	for before_terrain_var: Variant in before_state.get("terrain", []):
		if typeof(before_terrain_var) != TYPE_DICTIONARY:
			continue
		var before_terrain: Dictionary = _normalized_terrain(before_terrain_var)
		if int(before_terrain.get("hp", 0)) <= 0:
			continue
		var terrain_id: String = str(before_terrain.get("id", ""))
		var after_terrain: Dictionary = after_by_id.get(terrain_id, before_terrain)
		var hp_loss: int = maxi(0, int(before_terrain.get("hp", 0)) - int(after_terrain.get("hp", 0)))
		if hp_loss <= 0:
			continue
		losses.append({
			"key": "terrain_%s" % terrain_id,
			"kind": str(before_terrain.get("kind", "terrain")),
			"id": terrain_id,
			"tile": before_terrain.get("pos", Vector2i.ZERO),
			"hp_loss": hp_loss,
			"amount": hp_loss
		})
	return losses

func _triggered_traps_between(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var after_ids: Dictionary = {}
	for after_trap_var: Variant in after_state.get("traps", []):
		if typeof(after_trap_var) != TYPE_DICTIONARY:
			continue
		var after_trap: Dictionary = after_trap_var
		after_ids[str(after_trap.get("id", ""))] = true
	var triggered: Array[Dictionary] = []
	for before_trap_var: Variant in before_state.get("traps", []):
		if typeof(before_trap_var) != TYPE_DICTIONARY:
			continue
		var before_trap: Dictionary = (before_trap_var as Dictionary).duplicate(true)
		var trap_id: String = str(before_trap.get("id", ""))
		if trap_id.is_empty() or after_ids.has(trap_id):
			continue
		triggered.append(before_trap)
	return triggered

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

func _enemy_display_name(enemy: Dictionary) -> String:
	return str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy"))

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

func _closest_enemy_target(state: Dictionary, enemy: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var best_targets: Array = []
	var best_distance: int = 9999
	for target: Dictionary in _actor_targets(state):
		var target_pos: Vector2i = target.get("pos", Vector2i.ZERO)
		var distance: int = _enemy_distance_to_tile(enemy, target_pos)
		if distance < best_distance:
			best_distance = distance
			best_targets.clear()
			best_targets.append(target)
		elif distance == best_distance:
			best_targets.append(target)
	return _choose_actor_target_candidate(best_targets, rng)

func _closest_enemy_target_for_action(state: Dictionary, enemy: Dictionary, action: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var best_targets: Array = []
	var best_distance: int = 9999
	for target: Dictionary in _actor_targets(state):
		if not _enemy_action_reaches_target(state, enemy, action, target):
			continue
		var target_pos: Vector2i = target.get("pos", Vector2i.ZERO)
		var distance: int = _enemy_distance_to_tile(enemy, target_pos)
		if distance < best_distance:
			best_distance = distance
			best_targets.clear()
			best_targets.append(target)
		elif distance == best_distance:
			best_targets.append(target)
	return _choose_actor_target_candidate(best_targets, rng)

func _choose_actor_target_candidate(candidates: Array, rng: RandomNumberGenerator = null) -> Dictionary:
	if candidates.is_empty():
		return {}
	var index: int = 0
	if candidates.size() > 1 and rng != null:
		index = rng.randi_range(0, candidates.size() - 1)
	if typeof(candidates[index]) != TYPE_DICTIONARY:
		return {}
	return (candidates[index] as Dictionary).duplicate(true)

func _enemy_support_target_index(state: Dictionary, source_enemy_index: int, action: Dictionary) -> int:
	var enemies: Array = state.get("enemies", [])
	if source_enemy_index < 0 or source_enemy_index >= enemies.size():
		return -1
	var source_enemy: Dictionary = _normalized_enemy(enemies[source_enemy_index])
	if int(source_enemy.get("hp", 0)) <= 0:
		return -1
	var action_type: String = str(action.get("type", ""))
	if action_type not in ENEMY_SUPPORT_ACTION_TYPES:
		return -1
	var allow_self: bool = bool(action.get("allow_self", true))
	var max_range: int = int(action.get("range", 99)) if action.has("range") else 99
	var best_index: int = -1
	var best_enemy: Dictionary = {}
	var player: Dictionary = _normalized_player(state.get("player", {}))
	for index: int in range(enemies.size()):
		if index == source_enemy_index and not allow_self:
			continue
		var candidate: Dictionary = _normalized_enemy(enemies[index])
		if int(candidate.get("hp", 0)) <= 0:
			continue
		if not _enemy_support_action_can_affect(candidate, action):
			continue
		if _enemy_distance_between(source_enemy, candidate) > max_range:
			continue
		if best_index < 0 or _enemy_support_candidate_precedes(action_type, source_enemy, candidate, best_enemy, player):
			best_index = index
			best_enemy = candidate
	return best_index

func _enemy_support_action_can_affect(candidate: Dictionary, action: Dictionary) -> bool:
	if int(action.get("amount", 0)) <= 0:
		return false
	match str(action.get("type", "")):
		"heal_ally":
			return int(candidate.get("hp", 0)) < int(candidate.get("max_hp", 1))
		"guard_ally":
			return true
		_:
			return false

func _enemy_support_candidate_precedes(action_type: String, source_enemy: Dictionary, candidate: Dictionary, incumbent: Dictionary, player: Dictionary) -> bool:
	if incumbent.is_empty():
		return true
	match action_type:
		"heal_ally":
			var candidate_missing: int = maxi(0, int(candidate.get("max_hp", 1)) - int(candidate.get("hp", 0)))
			var incumbent_missing: int = maxi(0, int(incumbent.get("max_hp", 1)) - int(incumbent.get("hp", 0)))
			if candidate_missing != incumbent_missing:
				return candidate_missing > incumbent_missing
			var candidate_support_distance: int = _enemy_distance_between(source_enemy, candidate)
			var incumbent_support_distance: int = _enemy_distance_between(source_enemy, incumbent)
			if candidate_support_distance != incumbent_support_distance:
				return candidate_support_distance < incumbent_support_distance
			if int(candidate.get("hp", 0)) != int(incumbent.get("hp", 0)):
				return int(candidate.get("hp", 0)) < int(incumbent.get("hp", 0))
		"guard_ally":
			var player_pos: Vector2i = player.get("pos", Vector2i.ZERO)
			var candidate_threat_distance: int = _enemy_distance_to_tile(candidate, player_pos)
			var incumbent_threat_distance: int = _enemy_distance_to_tile(incumbent, player_pos)
			if candidate_threat_distance != incumbent_threat_distance:
				return candidate_threat_distance < incumbent_threat_distance
			var candidate_defense: int = int(candidate.get("block", 0)) + int(candidate.get("stoneskin", 0))
			var incumbent_defense: int = int(incumbent.get("block", 0)) + int(incumbent.get("stoneskin", 0))
			if candidate_defense != incumbent_defense:
				return candidate_defense < incumbent_defense
			var candidate_ratio: int = int(candidate.get("hp", 0)) * int(incumbent.get("max_hp", 1))
			var incumbent_ratio: int = int(incumbent.get("hp", 0)) * int(candidate.get("max_hp", 1))
			if candidate_ratio != incumbent_ratio:
				return candidate_ratio < incumbent_ratio
			var candidate_guard_distance: int = _enemy_distance_between(source_enemy, candidate)
			var incumbent_guard_distance: int = _enemy_distance_between(source_enemy, incumbent)
			if candidate_guard_distance != incumbent_guard_distance:
				return candidate_guard_distance < incumbent_guard_distance
	return int(candidate.get("id", 0)) < int(incumbent.get("id", 0))

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
			var resolved_action: Dictionary = _enemy_action_oriented_to_target(action, enemy, target_pos)
			return _enemy_aoe_tiles_for_target(state, enemy, resolved_action, center, true).has(target_pos)
	return false

func _enemy_action_reaches_tile(state: Dictionary, enemy: Dictionary, action: Dictionary, tile: Vector2i) -> bool:
	var action_type: String = str(action.get("type", ""))
	var source_pos: Vector2i = _closest_enemy_tile_to(enemy, tile)
	match action_type:
		"melee":
			return _enemy_distance_to_tile(enemy, tile) <= int(action.get("range", 1))
		"ranged":
			return (
				PathUtils.manhattan(source_pos, tile) <= int(action.get("range", 1))
				and PathUtils.has_line_of_sight(state.get("grid", []), source_pos, tile)
			)
		"push", "pull":
			var max_range: int = int(action.get("range", 1))
			return (
				PathUtils.manhattan(source_pos, tile) <= max_range
				and (max_range <= 1 or PathUtils.has_line_of_sight(state.get("grid", []), source_pos, tile))
			)
		"aoe":
			var center: Vector2i = enemy.get("pos", Vector2i.ZERO)
			if int(action.get("range", 0)) > 0:
				if PathUtils.manhattan(source_pos, tile) > int(action.get("range", 0)):
					return false
				if not PathUtils.has_line_of_sight(state.get("grid", []), source_pos, tile):
					return false
				center = tile
			var resolved_action: Dictionary = _enemy_action_oriented_to_target(action, enemy, tile)
			return _enemy_aoe_tiles_for_target(state, enemy, resolved_action, center, true).has(tile)
	return false

func _enemy_action_oriented_to_target(action: Dictionary, enemy: Dictionary, target_pos: Vector2i) -> Dictionary:
	var resolved_action: Dictionary = action.duplicate(true)
	if not bool(resolved_action.get("orient_toward_target", false)):
		return resolved_action
	var source_pos: Vector2i = _closest_enemy_tile_to(enemy, target_pos)
	var direction: Vector2i = _cardinal_direction(target_pos - source_pos)
	if direction != Vector2i.ZERO:
		resolved_action["orientation"] = direction
	return resolved_action

func _enemy_aoe_tiles_for_target(state: Dictionary, enemy: Dictionary, action: Dictionary, center: Vector2i, score_player: bool) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = _best_aoe_tiles_for_target(state, action, center, score_player)
	if not bool(action.get("stop_at_blockers", false)):
		return tiles
	var direction: Vector2i = _action_orientation_direction(action)
	if direction == Vector2i.ZERO:
		return tiles
	var source_pos: Vector2i = _closest_enemy_tile_to(enemy, center)
	return _aoe_tiles_until_blocked(state.get("grid", []), source_pos, direction, tiles)

func _aoe_tiles_until_blocked(grid: Array, source_pos: Vector2i, direction: Vector2i, tiles: Array[Vector2i]) -> Array[Vector2i]:
	var lookup: Dictionary = {}
	for tile: Vector2i in tiles:
		if _tile_is_on_directional_ray(source_pos, direction, tile) and _directional_ray_clear_to_tile(grid, source_pos, direction, tile):
			lookup[tile] = true
	return _sorted_tiles_from_lookup(lookup)

func _tile_is_on_directional_ray(source_pos: Vector2i, direction: Vector2i, tile: Vector2i) -> bool:
	var delta: Vector2i = tile - source_pos
	if direction.x != 0:
		return delta.y == 0 and delta.x * direction.x > 0
	if direction.y != 0:
		return delta.x == 0 and delta.y * direction.y > 0
	return false

func _directional_ray_clear_to_tile(grid: Array, source_pos: Vector2i, direction: Vector2i, tile: Vector2i) -> bool:
	var cursor: Vector2i = source_pos + direction
	while cursor != tile + direction:
		if not PathUtils.is_passable(grid, cursor):
			return false
		if cursor == tile:
			return true
		cursor += direction
	return false

func _best_enemy_trap_attack_index(state: Dictionary, enemy_index: int, action: Dictionary) -> int:
	var enemies: Array = state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return -1
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var direct_damage: int = _enemy_direct_player_damage_estimate(state, enemy, action)
	var best_index: int = -1
	var best_damage: int = direct_damage
	var traps: Array = state.get("traps", [])
	for trap_index: int in range(traps.size()):
		if typeof(traps[trap_index]) != TYPE_DICTIONARY:
			continue
		var trap: Dictionary = traps[trap_index]
		if not _enemy_action_reaches_tile(state, enemy, action, trap.get("pos", Vector2i(-1, -1))):
			continue
		if _trap_blast_hits_enemy(state, trap, enemy):
			continue
		if not _trap_blast_hits_player(state, trap):
			continue
		var trap_damage: int = int(trap.get("damage", 0))
		if direct_damage >= 0 and trap_damage <= direct_damage:
			continue
		if direct_damage < 0 and trap_damage <= 0:
			continue
		if trap_damage > best_damage:
			best_damage = trap_damage
			best_index = trap_index
	return best_index

func _enemy_direct_player_damage_estimate(state: Dictionary, enemy: Dictionary, action: Dictionary) -> int:
	var player: Dictionary = _normalized_player(state.get("player", {}))
	var target: Dictionary = {
		"kind": "player",
		"key": "player",
		"pos": player.get("pos", Vector2i.ZERO),
		"hp": int(player.get("hp", 0))
	}
	if not _enemy_action_reaches_target(state, enemy, action, target):
		return -1
	return int(action.get("damage", 0))

func _trap_blast_hits_player(state: Dictionary, trap: Dictionary) -> bool:
	var player_pos: Vector2i = (_normalized_player(state.get("player", {}))).get("pos", Vector2i(-1, -1))
	return _trap_blast_tiles(state, trap).has(player_pos)

func _trap_blast_hits_enemy(state: Dictionary, trap: Dictionary, enemy: Dictionary) -> bool:
	var blast_tiles: Array[Vector2i] = _trap_blast_tiles(state, trap)
	for tile: Vector2i in _enemy_footprint_tiles(enemy):
		if blast_tiles.has(tile):
			return true
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

func _has_attackable_in_tiles(state: Dictionary, tiles: Array[Vector2i]) -> bool:
	return (
		not _enemy_indices_in_tiles(state, tiles).is_empty()
		or not _terrain_indices_in_tiles(state, tiles).is_empty()
		or not _trap_tiles_in_tiles(state, tiles).is_empty()
	)

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

func _resolve_enemy_action(state: Dictionary, enemy_index: int, action: Dictionary, rng: RandomNumberGenerator = null, followup_action: Dictionary = {}) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	if int(enemy.get("hp", 0)) <= 0:
		return next_state
	var player: Dictionary = _normalized_player(next_state.get("player", {}))
	var player_pos: Vector2i = player.get("pos", Vector2i.ZERO)
	var target: Dictionary = _closest_enemy_target(next_state, enemy, rng)
	var target_pos: Vector2i = target.get("pos", player_pos)
	var action_type: String = str(action.get("type", ""))
	match action_type:
		"move_toward":
			var toward_tile: Vector2i = _best_move_toward_for_followup(next_state, enemy_index, target_pos, int(action.get("range", 0)), followup_action)
			if toward_tile == INVALID_TILE:
				toward_tile = _best_move_toward(next_state, enemy_index, target_pos, int(action.get("range", 0)))
			enemy["pos"] = toward_tile
			enemies[enemy_index] = enemy
			_log(next_state, "%s closes in." % str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")))
		"move_away":
			var away_tile: Vector2i = _best_move_away(next_state, enemy_index, target_pos, int(action.get("range", 0)))
			enemy["pos"] = away_tile
			enemies[enemy_index] = enemy
			_log(next_state, "%s falls back." % str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")))
		"block":
			enemy["block"] = int(enemy.get("block", 0)) + int(action.get("amount", 0))
			enemies[enemy_index] = enemy
			_log(next_state, "%s braces for %d block." % [
				str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")),
				int(action.get("amount", 0))
			])
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
		"heal_ally":
			var heal_target_index: int = _enemy_support_target_index(next_state, enemy_index, action)
			if heal_target_index < 0:
				return next_state
			var heal_target: Dictionary = _normalized_enemy(enemies[heal_target_index] as Dictionary)
			var heal_before: int = int(heal_target.get("hp", 0))
			heal_target["hp"] = mini(int(heal_target.get("max_hp", 1)), heal_before + int(action.get("amount", 0)))
			enemies[heal_target_index] = heal_target
			var healed_amount: int = int(heal_target.get("hp", 0)) - heal_before
			if healed_amount > 0:
				_log(next_state, "%s stitches %s for %d health." % [
					_enemy_display_name(enemy),
					"itself" if heal_target_index == enemy_index else _enemy_display_name(heal_target),
					healed_amount
				])
		"guard_ally":
			var guard_target_index: int = _enemy_support_target_index(next_state, enemy_index, action)
			if guard_target_index < 0:
				return next_state
			var guard_target: Dictionary = _normalized_enemy(enemies[guard_target_index] as Dictionary)
			guard_target["block"] = int(guard_target.get("block", 0)) + int(action.get("amount", 0))
			enemies[guard_target_index] = guard_target
			_log(next_state, "%s guards %s for %d block." % [
				_enemy_display_name(enemy),
				"itself" if guard_target_index == enemy_index else _enemy_display_name(guard_target),
				int(action.get("amount", 0))
			])
		"melee":
			next_state = _enemy_attack_target(next_state, enemy_index, action, "hits", rng)
		"ranged":
			next_state = _enemy_attack_target(next_state, enemy_index, action, "fires", rng)
		"aoe":
			next_state = _enemy_attack_target(next_state, enemy_index, action, "sweeps the area", rng)
		"lightning_strikes":
			next_state = _enemy_lightning_strikes(next_state, enemy_index, action)
		"push":
			next_state = _enemy_push_or_pull_target(next_state, enemy_index, action, true, rng)
		"pull":
			next_state = _enemy_push_or_pull_target(next_state, enemy_index, action, false, rng)
		"summon_minions":
			next_state = _enemy_summon_minions(next_state, enemy_index, action, rng)
	return next_state

func _attack_target_on_tile(state: Dictionary, action: Dictionary, target_tile: Vector2i, attack_kind: String) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	if not valid_targets_for_player_action(next_state, action).has(target_tile):
		return next_state
	var resolved_action: Dictionary = _action_with_intensity_bonus(next_state, action)
	var trap_index: int = _trap_index_at_tile(next_state, target_tile)
	if trap_index >= 0:
		if int(resolved_action.get("damage", 0)) > 0:
			_mark_first_attack_used(next_state)
		next_state = _trigger_trap_at_index(next_state, trap_index)
		_log(next_state, "%s triggers a trap." % attack_kind.capitalize())
		return next_state
	var terrain_index: int = _terrain_index_at_tile(next_state, target_tile)
	if terrain_index >= 0:
		var terrain_damage: int = final_damage_for_player_action(next_state, action)
		if terrain_damage > 0:
			_mark_first_attack_used(next_state)
			next_state = _damage_terrain(next_state, terrain_index, terrain_damage)
			_log(next_state, "%s splinters terrain for %d." % [attack_kind.capitalize(), terrain_damage])
		return next_state
	return _attack_enemy_on_tile(next_state, action, target_tile, attack_kind)

func _attack_enemy_on_tile(state: Dictionary, action: Dictionary, target_tile: Vector2i, attack_kind: String) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var resolved_action: Dictionary = _action_with_intensity_bonus(next_state, action)
	var enemy_index: int = _enemy_index_at_tile(next_state, target_tile)
	if enemy_index < 0:
		return next_state
	next_state = _sunder_enemy_defense(next_state, enemy_index, int(resolved_action.get("sunder", 0)))
	var damage: int = _damage_for_enemy_target(next_state, resolved_action, enemy_index)
	if damage > 0 or _action_has_keyword_effect(resolved_action):
		if _attack_bonus_for_current_turn(next_state) > 0 and int(resolved_action.get("damage", 0)) > 0:
			_mark_first_attack_used(next_state)
		next_state = _damage_enemy(next_state, enemy_index, damage, true, _action_pierces_defense(resolved_action))
		if damage > 0:
			next_state = _consume_enemy_expose(next_state, enemy_index)
		next_state = _apply_action_keywords_to_enemy(next_state, enemy_index, resolved_action, next_state.get("player", {}).get("pos", Vector2i.ZERO))
		next_state = _apply_chain_from_enemy(next_state, enemy_index, resolved_action, damage)
		_log(next_state, "%s for %d." % [attack_kind.capitalize(), damage])
	return next_state

func _aoe_enemies(state: Dictionary, action: Dictionary, target_tile: Vector2i) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var resolved_action: Dictionary = _action_with_intensity_bonus(next_state, action)
	var player_pos: Vector2i = (_normalized_player(next_state.get("player", {}))).get("pos", Vector2i.ZERO)
	var center: Vector2i = target_tile if int(action.get("range", 0)) > 0 and target_tile.x >= 0 else player_pos
	if int(action.get("range", 0)) > 0 and not valid_targets_for_player_action(next_state, action).has(center):
		return next_state
	var affected_tiles: Array[Vector2i] = _best_aoe_tiles_for_target(next_state, action, center, false)
	var affected: Array[int] = _enemy_indices_in_tiles(next_state, affected_tiles)
	var affected_terrain: Array[int] = _terrain_indices_in_tiles(next_state, affected_tiles)
	var affected_traps: Array[Vector2i] = _trap_tiles_in_tiles(next_state, affected_tiles)
	if affected.is_empty() and affected_terrain.is_empty() and affected_traps.is_empty():
		return next_state
	if _attack_bonus_for_current_turn(next_state) > 0 and int(resolved_action.get("damage", 0)) > 0:
		_mark_first_attack_used(next_state)
	var last_damage: int = 0
	for enemy_index: int in affected:
		next_state = _sunder_enemy_defense(next_state, enemy_index, int(resolved_action.get("sunder", 0)))
		var damage: int = _damage_for_enemy_target(next_state, resolved_action, enemy_index)
		last_damage = damage
		next_state = _damage_enemy(next_state, enemy_index, damage, true, _action_pierces_defense(resolved_action))
		if damage > 0:
			next_state = _consume_enemy_expose(next_state, enemy_index)
		next_state = _apply_action_keywords_to_enemy(next_state, enemy_index, resolved_action, next_state.get("player", {}).get("pos", Vector2i.ZERO))
	for terrain_index: int in affected_terrain:
		var terrain_damage: int = final_damage_for_player_action(next_state, action)
		if terrain_damage <= 0:
			continue
		last_damage = terrain_damage
		next_state = _damage_terrain(next_state, terrain_index, terrain_damage)
	next_state = _trigger_traps_on_tiles(next_state, affected_traps)
	_log(next_state, "Area attack hits %d target(s) for %d." % [affected.size() + affected_terrain.size() + affected_traps.size(), last_damage])
	return next_state

func _damage_enemy(state: Dictionary, enemy_index: int, damage: int, apply_freeze_multiplier: bool = true, bypass_defense: bool = false) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var was_alive: bool = int(enemy.get("hp", 0)) > 0
	var total_damage: int = damage
	if apply_freeze_multiplier and int(enemy.get("freeze", 0)) > 0:
		total_damage *= 2
	var remaining: int = total_damage
	if not bypass_defense:
		var block_amount: int = int(enemy.get("block", 0))
		var applied_to_block: int = mini(block_amount, remaining)
		block_amount -= applied_to_block
		remaining -= applied_to_block
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
		next_state = _trigger_enemy_death_relics(next_state, enemy)
		next_state = _trigger_enemy_death_spawn(next_state, enemy)
		_log(next_state, "%s falls." % str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")))
	return next_state

func _sunder_enemy_defense(state: Dictionary, enemy_index: int, amount: int) -> Dictionary:
	var next_state: Dictionary = state
	if amount <= 0:
		return next_state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var remaining: int = amount
	var block_removed: int = mini(int(enemy.get("block", 0)), remaining)
	enemy["block"] = int(enemy.get("block", 0)) - block_removed
	remaining -= block_removed
	if remaining > 0:
		var stoneskin_removed: int = mini(int(enemy.get("stoneskin", 0)), remaining)
		enemy["stoneskin"] = int(enemy.get("stoneskin", 0)) - stoneskin_removed
	enemies[enemy_index] = enemy
	next_state["enemies"] = enemies
	return next_state

func _consume_enemy_expose(state: Dictionary, enemy_index: int) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	if int(enemy.get("expose", 0)) <= 0:
		return next_state
	enemy["expose"] = 0
	enemies[enemy_index] = enemy
	next_state["enemies"] = enemies
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
	var was_alive: bool = int(player.get("hp", 0)) > 0
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
	if was_alive and int(player.get("hp", 0)) <= 0:
		next_state = _trigger_prevent_lethal_relics(next_state)
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

func _damage_terrain(state: Dictionary, terrain_index: int, damage: int) -> Dictionary:
	var next_state: Dictionary = state
	if damage <= 0:
		return next_state
	var terrain_entries: Array = next_state.get("terrain", []).duplicate(true)
	if terrain_index < 0 or terrain_index >= terrain_entries.size():
		return next_state
	var terrain: Dictionary = _normalized_terrain(terrain_entries[terrain_index])
	if int(terrain.get("hp", 0)) <= 0:
		return next_state
	terrain["hp"] = maxi(0, int(terrain.get("hp", 0)) - damage)
	terrain_entries[terrain_index] = terrain
	next_state["terrain"] = terrain_entries
	if int(terrain.get("hp", 0)) <= 0:
		_log(next_state, "Terrain breaks.")
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

func _normalized_terrain(terrain_value: Variant) -> Dictionary:
	var terrain: Dictionary = {}
	if typeof(terrain_value) == TYPE_DICTIONARY:
		terrain = (terrain_value as Dictionary).duplicate(true)
	terrain["id"] = str(terrain.get("id", ""))
	terrain["kind"] = str(terrain.get("kind", "wooden_box"))
	terrain["pos"] = terrain.get("pos", Vector2i.ZERO)
	terrain["hp"] = int(terrain.get("hp", 0))
	terrain["max_hp"] = maxi(1, int(terrain.get("max_hp", terrain.get("hp", 1))))
	return terrain

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
	unit["bleed"] = int(unit.get("bleed", 0))
	unit["expose"] = int(unit.get("expose", 0))
	unit["freeze"] = int(unit.get("freeze", 0))
	unit["shock"] = int(unit.get("shock", 0))
	unit["immobilize"] = bool(unit.get("immobilize", false))
	var poison_value: Variant = unit.get("poison", {})
	var poison: Dictionary = {}
	if typeof(poison_value) == TYPE_DICTIONARY:
		poison = (poison_value as Dictionary).duplicate(true)
	unit["poison"] = {
		"damage": int(poison.get("damage", 0)),
		"delay": int(poison.get("delay", 0))
	}
	return unit

func _initialize_initiative_queue(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	next_state["initiative_clock"] = 0
	next_state["activation_seq"] = 0
	next_state["current_actor"] = _player_actor_entry(0, 0)
	next_state["player_turn_time_spent"] = 0
	var queue: Array = []
	var enemies: Array = next_state.get("enemies", [])
	for enemy_index: int in range(enemies.size()):
		if typeof(enemies[enemy_index]) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			continue
		var intent_time_cost: int = _enemy_intent_time_cost(enemy.get("intent", {}) as Dictionary)
		var first_delay: int = maxi(ENEMY_MIN_INITIATIVE, _enemy_base_initiative(next_state, enemy) + maxi(0, intent_time_cost))
		var entry: Dictionary = _enemy_actor_entry(next_state, enemy, first_delay + enemy_index, _claim_activation_seq(next_state))
		entry["intent_time_cost"] = intent_time_cost
		queue.append(entry)
	next_state["turn_queue"] = _sorted_turn_queue(queue)
	return next_state

func _player_actor_entry(scheduled_time: int, seq: int) -> Dictionary:
	return {
		"kind": "player",
		"actor_key": "player",
		"name": "Reaver",
		"type": "player",
		"team": "player",
		"time": scheduled_time,
		"seq": seq
	}

func _enemy_actor_entry(state: Dictionary, enemy: Dictionary, scheduled_time: int, seq: int) -> Dictionary:
	var enemy_type: String = str(enemy.get("type", ""))
	return {
		"kind": "enemy",
		"actor_key": _enemy_key(enemy),
		"enemy_id": int(enemy.get("id", -1)),
		"type": enemy_type,
		"name": str(GameData.enemy_def(enemy_type).get("name", "Enemy")),
		"team": "enemy",
		"time": scheduled_time,
		"seq": seq,
		"pos": enemy.get("pos", Vector2i.ZERO)
	}

func _resolved_actor_entry(state: Dictionary, entry: Dictionary) -> Dictionary:
	var kind: String = str(entry.get("kind", ""))
	if kind == "player":
		if int((state.get("player", {}) as Dictionary).get("hp", 0)) <= 0:
			return {}
		var player_entry: Dictionary = _player_actor_entry(int(entry.get("time", state.get("initiative_clock", 0))), int(entry.get("seq", 0)))
		player_entry["eta"] = maxi(0, int(player_entry.get("time", 0)) - int(state.get("initiative_clock", 0)))
		player_entry["base_initiative"] = player_base_initiative(state)
		player_entry["turn_time_spent"] = int(state.get("player_turn_time_spent", 0))
		if bool(entry.get("projected", false)):
			player_entry["projected"] = true
		if entry.has("projected_time_cost"):
			player_entry["projected_time_cost"] = int(entry.get("projected_time_cost", 0))
		if entry.has("projected_card_name"):
			player_entry["projected_card_name"] = str(entry.get("projected_card_name", ""))
		return player_entry
	if kind == "enemy":
		var enemy_index: int = _enemy_index_for_id(state, int(entry.get("enemy_id", -1)))
		if enemy_index < 0:
			return {}
		var enemy: Dictionary = _normalized_enemy((state.get("enemies", []) as Array)[enemy_index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			return {}
		var enemy_entry: Dictionary = _enemy_actor_entry(state, enemy, int(entry.get("time", state.get("initiative_clock", 0))), int(entry.get("seq", 0)))
		enemy_entry["eta"] = maxi(0, int(enemy_entry.get("time", 0)) - int(state.get("initiative_clock", 0)))
		enemy_entry["base_initiative"] = _enemy_base_initiative(state, enemy)
		if bool(entry.get("projected", false)):
			enemy_entry["projected"] = true
		if entry.has("intent_time_cost"):
			enemy_entry["intent_time_cost"] = int(entry.get("intent_time_cost", 0))
		return enemy_entry
	return {}

func _projected_next_entry_for_current_actor(state: Dictionary, current_actor: Dictionary) -> Dictionary:
	if current_actor.is_empty():
		return {}
	var clock: int = int(state.get("initiative_clock", 0))
	match str(current_actor.get("kind", "")):
		"player":
			var preview_delta: int = maxi(0, int(state.get("turn_order_preview_time_delta", 0)))
			var player_entry: Dictionary = _player_actor_entry(
				clock + player_base_initiative(state) + maxi(0, int(state.get("player_turn_time_spent", 0))) + preview_delta,
				-1
			)
			player_entry["projected"] = true
			if preview_delta > 0:
				player_entry["projected_time_cost"] = preview_delta
			if state.has("turn_order_preview_card_name"):
				player_entry["projected_card_name"] = str(state.get("turn_order_preview_card_name", ""))
			return player_entry
		"enemy":
			var enemy_index: int = _enemy_index_for_id(state, int(current_actor.get("enemy_id", -1)))
			if enemy_index < 0:
				return {}
			var enemy: Dictionary = _normalized_enemy((state.get("enemies", []) as Array)[enemy_index] as Dictionary)
			if int(enemy.get("hp", 0)) <= 0:
				return {}
			var intent_time_cost: int = _enemy_intent_time_cost(enemy.get("intent", {}) as Dictionary)
			var delay: int = maxi(ENEMY_MIN_INITIATIVE, _enemy_base_initiative(state, enemy) + maxi(0, intent_time_cost))
			var enemy_entry: Dictionary = _enemy_actor_entry(state, enemy, clock + delay, -1)
			enemy_entry["projected"] = true
			enemy_entry["intent_time_cost"] = intent_time_cost
			return enemy_entry
	return {}

func _projected_next_entry_after_entry(state: Dictionary, entry: Dictionary) -> Dictionary:
	if bool(entry.get("projected", false)):
		return {}
	var resolved: Dictionary = _resolved_actor_entry(state, entry)
	if resolved.is_empty():
		return {}
	var scheduled_time: int = int(resolved.get("time", state.get("initiative_clock", 0)))
	var projected_seq: int = int(entry.get("seq", 0)) + 10000
	match str(resolved.get("kind", "")):
		"player":
			var player_entry: Dictionary = _player_actor_entry(scheduled_time + player_base_initiative(state), projected_seq)
			player_entry["projected"] = true
			return player_entry
		"enemy":
			var enemy_index: int = _enemy_index_for_id(state, int(resolved.get("enemy_id", -1)))
			if enemy_index < 0:
				return {}
			var enemy: Dictionary = _normalized_enemy((state.get("enemies", []) as Array)[enemy_index] as Dictionary)
			if int(enemy.get("hp", 0)) <= 0:
				return {}
			var intent_time_cost: int = _enemy_intent_time_cost(enemy.get("intent", {}) as Dictionary)
			var delay: int = maxi(ENEMY_MIN_INITIATIVE, _enemy_base_initiative(state, enemy) + maxi(0, intent_time_cost))
			var enemy_entry: Dictionary = _enemy_actor_entry(state, enemy, scheduled_time + delay, projected_seq)
			enemy_entry["projected"] = true
			enemy_entry["intent_time_cost"] = intent_time_cost
			return enemy_entry
	return {}

func _sorted_turn_queue(queue_value: Variant) -> Array:
	var queue: Array = []
	if typeof(queue_value) == TYPE_ARRAY:
		queue = (queue_value as Array).duplicate(true)
	queue.sort_custom(func(a: Variant, b: Variant) -> bool:
		var a_entry: Dictionary = {}
		if typeof(a) == TYPE_DICTIONARY:
			a_entry = a as Dictionary
		var b_entry: Dictionary = {}
		if typeof(b) == TYPE_DICTIONARY:
			b_entry = b as Dictionary
		var a_time: int = int(a_entry.get("time", 0))
		var b_time: int = int(b_entry.get("time", 0))
		if a_time == b_time:
			return int(a_entry.get("seq", 0)) < int(b_entry.get("seq", 0))
		return a_time < b_time
	)
	return queue

func _pop_next_actor(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var queue: Array = _sorted_turn_queue(next_state.get("turn_queue", []))
	while not queue.is_empty():
		var entry_var: Variant = queue.pop_front()
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var as Dictionary
		var resolved: Dictionary = _resolved_actor_entry(next_state, entry)
		if resolved.is_empty():
			continue
		next_state["turn_queue"] = queue
		next_state["current_actor"] = resolved
		next_state["initiative_clock"] = int(resolved.get("time", next_state.get("initiative_clock", 0)))
		return {"state": next_state, "entry": resolved}
	next_state["turn_queue"] = queue
	return {"state": next_state, "entry": {}}

func _schedule_actor(state: Dictionary, entry: Dictionary) -> void:
	if entry.is_empty():
		return
	var queue: Array = _sorted_turn_queue(state.get("turn_queue", []))
	var scheduled: Dictionary = entry.duplicate(true)
	scheduled["seq"] = _claim_activation_seq(state)
	queue.append(scheduled)
	state["turn_queue"] = _sorted_turn_queue(queue)

func _schedule_enemy_after_turn(state: Dictionary, enemy: Dictionary, turn_time_cost: int) -> void:
	var delay: int = maxi(ENEMY_MIN_INITIATIVE, _enemy_base_initiative(state, enemy) + maxi(0, turn_time_cost))
	_schedule_actor(state, _enemy_actor_entry(state, enemy, int(state.get("initiative_clock", 0)) + delay, 0))

func _append_turn_order_step(steps: Array[Dictionary], before_state: Dictionary, after_state: Dictionary, label: String) -> void:
	var before_order: Array[Dictionary] = current_turn_order(before_state, TURN_ORDER_PREVIEW_LIMIT)
	var after_order: Array[Dictionary] = current_turn_order(after_state, TURN_ORDER_PREVIEW_LIMIT)
	if _turn_order_signature(before_order) == _turn_order_signature(after_order):
		return
	steps.append({
		"kind": "turn_order",
		"label": label,
		"before_order": before_order,
		"after_order": after_order
	})

func _turn_order_signature(order: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for entry: Dictionary in order:
		parts.append("%s:%s:%d:%d:%s" % [
			str(entry.get("kind", "")),
			str(entry.get("actor_key", "")),
			int(entry.get("time", 0)),
			int(entry.get("seq", 0)),
			str(bool(entry.get("active", false)))
		])
	return "|".join(parts)

func _claim_activation_seq(state: Dictionary) -> int:
	var next_seq: int = int(state.get("activation_seq", 0)) + 1
	state["activation_seq"] = next_seq
	return next_seq

func _enemy_index_for_id(state: Dictionary, enemy_id: int) -> int:
	var enemies: Array = state.get("enemies", [])
	for index: int in range(enemies.size()):
		if typeof(enemies[index]) != TYPE_DICTIONARY:
			continue
		if int((enemies[index] as Dictionary).get("id", -1)) == enemy_id:
			return index
	return -1

func _enemy_base_initiative(state: Dictionary, enemy: Dictionary) -> int:
	var definition: Dictionary = GameData.enemy_def(str(enemy.get("type", "")))
	var base: int = int(definition.get("base_initiative", DEFAULT_ENEMY_BASE_INITIATIVE))
	var depth: int = maxi(1, int(state.get("room_depth", 1)))
	var depth_bonus: int = mini(4, int((depth - 1) / 3))
	return maxi(ENEMY_MIN_INITIATIVE, base - depth_bonus)

func _enemy_intent_time_cost(intent: Dictionary) -> int:
	if intent.has("time"):
		return clampi(int(intent.get("time", DEFAULT_ENEMY_INTENT_TIME_COST)), 0, 12)
	var total: int = 0
	for action_var: Variant in intent.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		total += _enemy_action_time_cost(action_var as Dictionary)
	return maxi(DEFAULT_ENEMY_INTENT_TIME_COST, total)

func _enemy_action_time_cost(action: Dictionary) -> int:
	match str(action.get("type", "")):
		"move_toward", "move_away":
			return 2 if int(action.get("range", 0)) <= 2 else 3
		"melee", "ranged", "push", "pull":
			return 3
		"aoe", "lightning_strikes":
			return 4
		"summon_minions":
			return 5
		"block", "stoneskin", "heal_self", "heal_ally", "guard_ally":
			return 2
		_:
			return DEFAULT_ENEMY_INTENT_TIME_COST

func _estimated_card_time_cost(card: Dictionary) -> int:
	var total: int = 1
	for action_var: Variant in card.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var
		match str(action.get("type", "")):
			"move", "blink", "block", "stoneskin", "draw", "card_play", "intensity":
				total += 1
			"heal", "illusion":
				total += 2
			"melee", "ranged", "push", "pull":
				total += 2
				if int(action.get("damage", 0)) >= 10:
					total += 1
			"aoe":
				total += 3
			_:
				total += 1
	if bool(card.get("burn", false)):
		total = maxi(1, total - 1)
	return clampi(total, MIN_CARD_TIME_COST, MAX_CARD_TIME_COST)

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
		or int(action.get("bleed", 0)) > 0
		or int(action.get("expose", 0)) > 0
		or int(action.get("sunder", 0)) > 0
		or int(action.get("freeze", 0)) > 0
		or int(action.get("shock", 0)) > 0
		or _action_applies_immobilize(action)
		or int(action.get("poison", 0)) > 0
		or int(action.get("push", 0)) > 0
		or int(action.get("pull", 0)) > 0
		or int(action.get("chain", 0)) > 0
	)

func _action_has_forced_movement(action: Dictionary) -> bool:
	var action_type: String = str(action.get("type", ""))
	return (
		(action_type == "push" and int(action.get("amount", 0)) > 0)
		or (action_type == "pull" and int(action.get("amount", 0)) > 0)
		or int(action.get("push", 0)) > 0
		or int(action.get("pull", 0)) > 0
	)

func _action_applies_immobilize(action: Dictionary) -> bool:
	return bool(action.get("immobilize", false))

func _forced_movement_amount(action: Dictionary) -> int:
	match str(action.get("type", "")):
		"push", "pull":
			return maxi(0, int(action.get("amount", 0)))
		_:
			return maxi(0, maxi(int(action.get("push", 0)), int(action.get("pull", 0))))

func _forced_movement_pushes(action: Dictionary) -> bool:
	var action_type: String = str(action.get("type", ""))
	if action_type == "pull":
		return false
	if action_type == "push":
		return true
	var push_amount: int = int(action.get("push", 0))
	var pull_amount: int = int(action.get("pull", 0))
	return push_amount > 0 or pull_amount <= 0

func _action_force_direction(action: Dictionary) -> Vector2i:
	return _cardinal_direction(action.get("force_direction", action.get("orientation", Vector2i.ZERO)))

func _action_orientation_direction(action: Dictionary) -> Vector2i:
	return _cardinal_direction(action.get("orientation", Vector2i.ZERO))

func _cardinal_direction(value: Variant) -> Vector2i:
	var raw: Vector2i = Vector2i.ZERO
	match typeof(value):
		TYPE_VECTOR2I:
			raw = value
		TYPE_VECTOR2:
			var vector_value: Vector2 = value
			raw = Vector2i(int(roundf(vector_value.x)), int(roundf(vector_value.y)))
		TYPE_ARRAY:
			var pair: Array = value
			if pair.size() >= 2:
				raw = Vector2i(int(pair[0]), int(pair[1]))
		TYPE_DICTIONARY:
			var dict: Dictionary = value
			raw = Vector2i(int(dict.get("x", 0)), int(dict.get("y", 0)))
	if raw == Vector2i.ZERO:
		return Vector2i.ZERO
	if absi(raw.x) >= absi(raw.y):
		return Vector2i(1 if raw.x >= 0 else -1, 0)
	return Vector2i(0, 1 if raw.y >= 0 else -1)

func _action_pierces_defense(action: Dictionary) -> bool:
	return bool(action.get("pierce", false))

func _initial_elemental_intensity(room_element: String) -> Dictionary:
	var intensities: Dictionary = {}
	for element_id: String in ElementData.all_elements():
		intensities[element_id] = ELEMENTAL_INTENSITY_ROOM_BASE if element_id == room_element else 0
	return intensities

func _empty_elemental_intensity() -> Dictionary:
	var intensities: Dictionary = {}
	for element_id: String in ElementData.all_elements():
		intensities[element_id] = 0
	return intensities

func _gain_elemental_intensity(state: Dictionary, element_id: String, amount: int, source_name: String = "") -> Dictionary:
	var next_state: Dictionary = state
	if not ElementData.is_elemental(element_id) or amount <= 0:
		return next_state
	var before_value: int = elemental_intensity(next_state, element_id)
	var intensities: Dictionary = elemental_intensities(next_state)
	intensities[element_id] = before_value + amount
	next_state["elemental_intensity"] = intensities
	var gained_total: Dictionary = elemental_intensity_counter(next_state, "elemental_intensity_gained_total")
	gained_total[element_id] = int(gained_total.get(element_id, 0)) + amount
	next_state["elemental_intensity_gained_total"] = gained_total
	if source_name.is_empty():
		_log(next_state, "%s intensity rises by %d." % [ElementData.name(element_id), amount])
	else:
		_log(next_state, "%s raises %s intensity by %d." % [source_name, ElementData.name(element_id), amount])
	return _trigger_intensity_threshold_relics(next_state, element_id, before_value, before_value + amount)

func _consume_elemental_intensity(state: Dictionary, element_id: String, amount: int) -> Dictionary:
	var next_state: Dictionary = state
	if not ElementData.is_elemental(element_id) or amount <= 0:
		return next_state
	var before_value: int = elemental_intensity(next_state, element_id)
	var after_value: int = maxi(0, before_value - amount)
	var spent: int = before_value - after_value
	if spent <= 0:
		return next_state
	var intensities: Dictionary = elemental_intensities(next_state)
	intensities[element_id] = after_value
	next_state["elemental_intensity"] = intensities
	var spent_total: Dictionary = elemental_intensity_counter(next_state, "elemental_intensity_spent_total")
	spent_total[element_id] = int(spent_total.get(element_id, 0)) + spent
	next_state["elemental_intensity_spent_total"] = spent_total
	_log(next_state, "%s intensity is spent by %d." % [ElementData.name(element_id), spent])
	return next_state

func _action_intensity_element(action: Dictionary) -> String:
	var element_id: String = str(action.get("element", action.get("_card_element", ElementData.NONE)))
	return element_id if ElementData.is_elemental(element_id) else ElementData.NONE

func _action_intensity_requirement(action: Dictionary) -> Dictionary:
	var raw: Variant = action.get("requires_intensity", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var requirement: Dictionary = raw as Dictionary
	var element_id: String = str(requirement.get("element", action.get("element", action.get("_card_element", ElementData.NONE))))
	var threshold: int = int(requirement.get("amount", requirement.get("threshold", 0)))
	if not ElementData.is_elemental(element_id) or threshold <= 0:
		return {}
	return {
		"element": element_id,
		"amount": threshold
	}

func _action_intensity_bonus(action: Dictionary) -> Dictionary:
	var raw: Variant = action.get("intensity_bonus", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var bonus: Dictionary = (raw as Dictionary).duplicate(true)
	var element_id: String = str(bonus.get("element", action.get("element", action.get("_card_element", ElementData.NONE))))
	var threshold: int = int(bonus.get("threshold", bonus.get("amount", bonus.get("requires", 0))))
	if not ElementData.is_elemental(element_id) or threshold <= 0:
		return {}
	bonus["element"] = element_id
	bonus["threshold"] = threshold
	return bonus

func _action_intensity_bonus_requirement(action: Dictionary) -> Dictionary:
	var bonus: Dictionary = _action_intensity_bonus(action)
	if bonus.is_empty():
		return {}
	return {
		"element": str(bonus.get("element", ElementData.NONE)),
		"amount": int(bonus.get("threshold", 0))
	}

func _action_with_intensity_bonus(state: Dictionary, action: Dictionary) -> Dictionary:
	var resolved_action: Dictionary = action.duplicate(true)
	resolved_action.erase("intensity_bonus")
	var bonus: Dictionary = _action_intensity_bonus(action)
	if bonus.is_empty():
		return resolved_action
	var element_id: String = str(bonus.get("element", ElementData.NONE))
	if elemental_intensity(state, element_id) < int(bonus.get("threshold", 0)):
		return resolved_action
	for field: String in INTENSITY_BONUS_ADDITIVE_FIELDS:
		if not bonus.has(field):
			continue
		resolved_action[field] = int(resolved_action.get(field, 0)) + int(bonus.get(field, 0))
	if bool(bonus.get("pierce", false)):
		resolved_action["pierce"] = true
	if bool(bonus.get("immobilize", false)):
		resolved_action["immobilize"] = true
	return resolved_action

func _intensity_bonus_damage_modifiers_for_action(state: Dictionary, action: Dictionary) -> Array[Dictionary]:
	var modifiers: Array[Dictionary] = []
	var bonus: Dictionary = _action_intensity_bonus(action)
	if bonus.is_empty() or int(bonus.get("damage", 0)) == 0:
		return modifiers
	var element_id: String = str(bonus.get("element", ElementData.NONE))
	var threshold: int = int(bonus.get("threshold", 0))
	if elemental_intensity(state, element_id) < threshold:
		return modifiers
	modifiers.append({
		"source": "%s Intensity" % ElementData.name(element_id),
		"kind": "elemental_intensity",
		"amount": int(bonus.get("damage", 0)),
		"detail": "%s %d+" % [ElementData.name(element_id), threshold]
	})
	return modifiers

func _apply_action_keywords_to_enemy(state: Dictionary, enemy_index: int, action: Dictionary, source_pos: Vector2i, trigger_player_relics: bool = true) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	if int(enemy.get("hp", 0)) <= 0:
		return next_state
	var triggered_statuses: Array[String] = []
	if int(action.get("burn", 0)) > 0:
		enemy["burn"] = int(enemy.get("burn", 0)) + int(action.get("burn", 0))
		triggered_statuses.append("burn")
	if int(action.get("bleed", 0)) > 0:
		enemy["bleed"] = int(enemy.get("bleed", 0)) + int(action.get("bleed", 0))
		triggered_statuses.append("bleed")
	if int(action.get("expose", 0)) > 0:
		enemy["expose"] = maxi(int(enemy.get("expose", 0)), int(action.get("expose", 0)))
		triggered_statuses.append("expose")
	if int(action.get("freeze", 0)) > 0:
		var before_freeze: int = int(enemy.get("freeze", 0))
		enemy["freeze"] = maxi(int(enemy.get("freeze", 0)), int(action.get("freeze", 0)))
		if int(enemy.get("freeze", 0)) > before_freeze:
			triggered_statuses.append("freeze")
	if int(action.get("shock", 0)) > 0 and not _enemy_is_immune_to_status(enemy, "shock"):
		var before_shock: int = int(enemy.get("shock", 0))
		enemy["shock"] = maxi(int(enemy.get("shock", 0)), int(action.get("shock", 0)))
		if int(enemy.get("shock", 0)) > before_shock:
			triggered_statuses.append("shock")
	if _action_applies_immobilize(action) and not _enemy_is_immune_to_status(enemy, "immobilize"):
		var before_immobilize: bool = bool(enemy.get("immobilize", false))
		enemy["immobilize"] = true
		if not before_immobilize:
			triggered_statuses.append("immobilize")
	if int(action.get("poison", 0)) > 0:
		var poison: Dictionary = enemy.get("poison", {}).duplicate(true)
		poison["damage"] = int(poison.get("damage", 0)) + int(action.get("poison", 0))
		poison["delay"] = 2
		enemy["poison"] = poison
		triggered_statuses.append("poison")
	enemies[enemy_index] = enemy
	next_state["enemies"] = enemies
	if trigger_player_relics:
		for status_id: String in triggered_statuses:
			next_state = _trigger_status_relics(next_state, status_id)
	if int(action.get("push", 0)) > 0:
		var push_direction: Vector2i = _action_force_direction(action)
		if push_direction != Vector2i.ZERO and _forced_direction_can_move_enemy(next_state, enemy_index, push_direction, source_pos, true):
			next_state = _move_enemy_in_direction(next_state, enemy_index, push_direction, int(action.get("push", 0)))
		elif push_direction == Vector2i.ZERO:
			next_state = _move_enemy_from_source(next_state, enemy_index, source_pos, int(action.get("push", 0)), true)
	elif int(action.get("pull", 0)) > 0:
		var pull_direction: Vector2i = _action_force_direction(action)
		if pull_direction != Vector2i.ZERO and _forced_direction_can_move_enemy(next_state, enemy_index, pull_direction, source_pos, false):
			next_state = _move_enemy_in_direction(next_state, enemy_index, pull_direction, int(action.get("pull", 0)))
		elif pull_direction == Vector2i.ZERO:
			next_state = _move_enemy_from_source(next_state, enemy_index, source_pos, int(action.get("pull", 0)), false)
	return next_state

func _apply_action_keywords_to_player(state: Dictionary, action: Dictionary, source_pos: Vector2i) -> Dictionary:
	var next_state: Dictionary = state
	var player: Dictionary = _normalized_player(next_state.get("player", {}))
	if int(action.get("burn", 0)) > 0:
		player["burn"] = int(player.get("burn", 0)) + int(action.get("burn", 0))
	if int(action.get("bleed", 0)) > 0:
		player["bleed"] = int(player.get("bleed", 0)) + int(action.get("bleed", 0))
	if int(action.get("expose", 0)) > 0:
		player["expose"] = maxi(int(player.get("expose", 0)), int(action.get("expose", 0)))
	if int(action.get("freeze", 0)) > 0:
		player["freeze"] = maxi(int(player.get("freeze", 0)), int(action.get("freeze", 0)))
	if int(action.get("shock", 0)) > 0:
		player["shock"] = maxi(int(player.get("shock", 0)), int(action.get("shock", 0)))
	if _action_applies_immobilize(action):
		player["immobilize"] = true
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
		next_state = _sunder_enemy_defense(next_state, next_index, int(action.get("sunder", 0)))
		next_state = _damage_enemy(next_state, next_index, damage, true, _action_pierces_defense(action))
		if damage > 0:
			next_state = _consume_enemy_expose(next_state, next_index)
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

func _enemy_attack_target(state: Dictionary, enemy_index: int, action: Dictionary, verb: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var action_type: String = str(action.get("type", ""))
	var trap_attack_index: int = _best_enemy_trap_attack_index(next_state, enemy_index, action)
	if trap_attack_index >= 0:
		next_state = _trigger_trap_at_index(next_state, trap_attack_index)
		_log(next_state, "%s triggers a trap." % str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")))
		return next_state
	var target: Dictionary = _closest_enemy_target_for_action(next_state, enemy, action, rng)
	if target.is_empty():
		return _enemy_attack_blocking_terrain(next_state, enemy_index, action)
	var damage: int = int(action.get("damage", 0))
	if action_type == "aoe":
		var center: Vector2i = enemy.get("pos", Vector2i.ZERO)
		var resolved_action: Dictionary = _enemy_action_oriented_to_target(action, enemy, target.get("pos", Vector2i.ZERO))
		if int(action.get("range", 0)) > 0:
			center = target.get("pos", Vector2i.ZERO)
		var affected_targets: Array[Dictionary] = _actor_targets_in_tiles(next_state, _enemy_aoe_tiles_for_target(next_state, enemy, resolved_action, center, true))
		if affected_targets.is_empty():
			return next_state
		for affected_target: Dictionary in affected_targets:
			if damage > 0:
				next_state = _damage_actor_target(next_state, affected_target, damage, _action_pierces_defense(action))
			next_state = _apply_action_keywords_to_target(next_state, affected_target, action, _closest_enemy_tile_to(enemy, affected_target.get("pos", Vector2i.ZERO)))
	else:
		if damage > 0:
			next_state = _damage_actor_target(next_state, target, damage, _action_pierces_defense(action))
		next_state = _apply_action_keywords_to_target(next_state, target, action, _closest_enemy_tile_to(enemy, target.get("pos", Vector2i.ZERO)))
	_log(next_state, "%s %s for %d." % [
		str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")),
		verb,
		damage
	])
	next_state = _apply_enemy_self_damage(next_state, enemy_index, int(action.get("self_damage", 0)))
	return next_state

func _enemy_push_or_pull_target(state: Dictionary, enemy_index: int, action: Dictionary, pushing: bool, rng: RandomNumberGenerator = null) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var trap_attack_index: int = _best_enemy_trap_attack_index(next_state, enemy_index, action)
	if trap_attack_index >= 0:
		next_state = _trigger_trap_at_index(next_state, trap_attack_index)
		_log(next_state, "%s triggers a trap." % str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")))
		return next_state
	var target: Dictionary = _closest_enemy_target_for_action(next_state, enemy, action, rng)
	if target.is_empty():
		return _enemy_attack_blocking_terrain(next_state, enemy_index, action)
	var target_pos: Vector2i = target.get("pos", Vector2i.ZERO)
	var source_pos: Vector2i = _closest_enemy_tile_to(enemy, target_pos)
	var damage: int = int(action.get("damage", 0))
	if damage > 0:
		next_state = _damage_actor_target(next_state, target, damage, _action_pierces_defense(action))
	if str(target.get("kind", "")) == "player":
		next_state = _move_player_from_source(next_state, source_pos, int(action.get("amount", 0)), pushing)
	next_state = _apply_action_keywords_to_target(next_state, target, action, source_pos)
	next_state = _apply_enemy_self_damage(next_state, enemy_index, int(action.get("self_damage", 0)))
	_log(next_state, "%s %s." % [
		str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")),
		"batters the line" if pushing else "drags inward"
	])
	return next_state

func _enemy_attack_blocking_terrain(state: Dictionary, enemy_index: int, action: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	if int(action.get("damage", 0)) <= 0:
		return next_state
	var terrain_index: int = _blocking_terrain_index_for_enemy_action(next_state, enemy_index, action)
	if terrain_index < 0:
		return next_state
	var damage: int = int(action.get("damage", 0))
	next_state = _damage_terrain(next_state, terrain_index, damage)
	var enemies: Array = next_state.get("enemies", [])
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	_log(next_state, "%s breaks through terrain for %d." % [
		str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")),
		damage
	])
	return next_state

func _blocking_terrain_index_for_enemy_action(state: Dictionary, enemy_index: int, action: Dictionary) -> int:
	var enemies: Array = state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return -1
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var player_pos: Vector2i = (_normalized_player(state.get("player", {}))).get("pos", Vector2i.ZERO)
	var occupied: Dictionary = _enemy_blocking_tiles_without_terrain(state, int(enemy.get("id", -1)))
	var start: Vector2i = _closest_enemy_tile_to(enemy, player_pos)
	var path: Array[Vector2i] = PathUtils.find_path(state.get("grid", []), start, player_pos, occupied, true)
	if path.is_empty():
		return -1
	for step_index: int in range(1, path.size()):
		var tile: Vector2i = path[step_index]
		var terrain_index: int = _terrain_index_at_tile(state, tile)
		if terrain_index < 0:
			continue
		if _enemy_action_reaches_tile(state, enemy, action, tile):
			return terrain_index
		return -1
	return -1

func _enemy_lightning_strikes(state: Dictionary, enemy_index: int, action: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var strike_tiles: Array[Vector2i] = _lightning_strike_tiles(next_state, enemy, action)
	for target: Dictionary in _actor_targets_in_tiles(next_state, strike_tiles):
		next_state = _damage_actor_target(next_state, target, int(action.get("damage", 0)), _action_pierces_defense(action))
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
		var minion_max_hp: int = _scaled_enemy_max_hp(minion_type, int(next_state.get("room_depth", 1)))
		var minion: Dictionary = {
			"id": next_id,
			"type": minion_type,
			"summoned": true,
			"element": str(next_state.get("room_element", ElementData.NONE)),
			"pos": tile,
			"hp": minion_max_hp,
			"max_hp": minion_max_hp,
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

func _push_or_pull_target(state: Dictionary, action: Dictionary, target_tile: Vector2i, pushing: bool) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var resolved_action: Dictionary = _action_with_intensity_bonus(next_state, action)
	if not valid_targets_for_player_action(next_state, action).has(target_tile):
		return next_state
	var trap_index: int = _trap_index_at_tile(next_state, target_tile)
	if trap_index >= 0:
		if int(resolved_action.get("damage", 0)) > 0:
			_mark_first_attack_used(next_state)
		next_state = _trigger_trap_at_index(next_state, trap_index)
		_log(next_state, "%s triggers a trap." % ("Push" if pushing else "Pull"))
		return next_state
	var terrain_index: int = _terrain_index_at_tile(next_state, target_tile)
	if terrain_index >= 0:
		var terrain_damage: int = final_damage_for_player_action(next_state, resolved_action)
		if terrain_damage > 0:
			if _attack_bonus_for_current_turn(next_state) > 0 and int(resolved_action.get("damage", 0)) > 0:
				_mark_first_attack_used(next_state)
			next_state = _damage_terrain(next_state, terrain_index, terrain_damage)
			_log(next_state, "%s splinters terrain for %d." % ["Push" if pushing else "Pull", terrain_damage])
		return next_state
	var enemy_index: int = _enemy_index_at_tile(next_state, target_tile)
	if enemy_index < 0:
		return next_state
	next_state = _sunder_enemy_defense(next_state, enemy_index, int(resolved_action.get("sunder", 0)))
	var damage: int = _damage_for_enemy_target(next_state, resolved_action, enemy_index)
	if _attack_bonus_for_current_turn(next_state) > 0 and int(resolved_action.get("damage", 0)) > 0:
		_mark_first_attack_used(next_state)
	if damage > 0:
		next_state = _damage_enemy(next_state, enemy_index, damage, true, _action_pierces_defense(resolved_action))
		next_state = _consume_enemy_expose(next_state, enemy_index)
	if int(((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary).get("hp", 0)) <= 0:
		return next_state
	next_state = _apply_action_keywords_to_enemy(next_state, enemy_index, resolved_action, (next_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO))
	var force_direction: Vector2i = _action_force_direction(resolved_action)
	if force_direction != Vector2i.ZERO:
		var player_source: Vector2i = (next_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
		if _forced_direction_can_move_enemy(next_state, enemy_index, force_direction, player_source, pushing):
			next_state = _move_enemy_in_direction(next_state, enemy_index, force_direction, int(resolved_action.get("amount", 0)))
	else:
		next_state = _move_enemy_from_source(next_state, enemy_index, (next_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO), int(resolved_action.get("amount", 0)), pushing)
	_log(next_state, "%s %d." % ["Push" if pushing else "Pull", int(resolved_action.get("amount", 0))])
	return next_state

func _force_directions_for_enemy(state: Dictionary, enemy_index: int, source_pos: Vector2i, pushing: bool, amount: int) -> Array[Vector2i]:
	var directions: Array[Vector2i] = []
	if amount <= 0:
		return directions
	for direction: Vector2i in CARDINAL_DIRECTIONS:
		if not _forced_direction_can_move_enemy(state, enemy_index, direction, source_pos, pushing):
			continue
		directions.append(direction)
	return directions

func _forced_direction_can_move_enemy(state: Dictionary, enemy_index: int, direction: Vector2i, source_pos: Vector2i, pushing: bool) -> bool:
	var step_direction: Vector2i = _cardinal_direction(direction)
	if step_direction == Vector2i.ZERO:
		return false
	var enemies: Array = state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return false
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	if int(enemy.get("hp", 0)) <= 0:
		return false
	var before_distance: int = _enemy_distance_to_tile(enemy, source_pos)
	var moved_enemy: Dictionary = enemy.duplicate(true)
	moved_enemy["pos"] = enemy.get("pos", Vector2i.ZERO) + step_direction
	var after_distance: int = _enemy_distance_to_tile(moved_enemy, source_pos)
	if pushing and after_distance <= before_distance:
		return false
	if not pushing and after_distance >= before_distance:
		return false
	return not _enemy_direction_path(state, enemy_index, step_direction, 1).is_empty()

func _enemy_direction_path(state: Dictionary, enemy_index: int, direction: Vector2i, amount: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var step_direction: Vector2i = _cardinal_direction(direction)
	if step_direction == Vector2i.ZERO or amount <= 0:
		return path
	var next_state: Dictionary = state.duplicate(true)
	for _step: int in range(amount):
		var enemies: Array = next_state.get("enemies", [])
		if enemy_index < 0 or enemy_index >= enemies.size():
			break
		var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			break
		var candidate: Vector2i = enemy.get("pos", Vector2i.ZERO) + step_direction
		var occupied: Dictionary = _enemy_blocking_tiles(next_state, int(enemy.get("id", -1)))
		var player_pos: Vector2i = (next_state.get("player", {}) as Dictionary).get("pos", Vector2i(-99, -99))
		if not _enemy_can_occupy_anchor(next_state, enemy, candidate, occupied, player_pos):
			break
		enemy["pos"] = candidate
		enemies[enemy_index] = enemy
		next_state["enemies"] = enemies
		path.append(candidate)
	return path

func _move_enemy_in_direction(state: Dictionary, enemy_index: int, direction: Vector2i, amount: int) -> Dictionary:
	var next_state: Dictionary = state
	var step_direction: Vector2i = _cardinal_direction(direction)
	if step_direction == Vector2i.ZERO or amount <= 0:
		return next_state
	for _step: int in range(amount):
		var enemies: Array = next_state.get("enemies", [])
		if enemy_index < 0 or enemy_index >= enemies.size():
			break
		var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			break
		var candidate: Vector2i = enemy.get("pos", Vector2i.ZERO) + step_direction
		var occupied: Dictionary = _enemy_blocking_tiles(next_state, int(enemy.get("id", -1)))
		var player_pos: Vector2i = (next_state.get("player", {}) as Dictionary).get("pos", Vector2i(-99, -99))
		if not _enemy_can_occupy_anchor(next_state, enemy, candidate, occupied, player_pos):
			break
		enemy["pos"] = candidate
		enemies[enemy_index] = enemy
		next_state["enemies"] = enemies
		next_state = _trigger_trap_on_enemy(next_state, enemy_index)
		if int(((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary).get("hp", 0)) <= 0:
			break
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
	return _trigger_trap_at_index(state, trap_index)

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
	return _trigger_trap_at_index(state, trap_index)

func _trigger_traps_on_tiles(state: Dictionary, trap_tiles: Array[Vector2i]) -> Dictionary:
	var next_state: Dictionary = state
	for trap_tile: Vector2i in trap_tiles:
		var trap_index: int = _trap_index_at_tile(next_state, trap_tile)
		if trap_index < 0:
			continue
		next_state = _trigger_trap_at_index(next_state, trap_index)
	return next_state

func _trigger_trap_at_index(state: Dictionary, trap_index: int) -> Dictionary:
	var next_state: Dictionary = state
	var traps: Array = next_state.get("traps", []).duplicate(true)
	if trap_index < 0 or trap_index >= traps.size():
		return next_state
	var trap: Dictionary = (traps[trap_index] as Dictionary).duplicate(true)
	traps.remove_at(trap_index)
	next_state["traps"] = traps
	var blast_tiles: Array[Vector2i] = _trap_blast_tiles(next_state, trap)
	var blast_lookup: Dictionary = {}
	for tile: Vector2i in blast_tiles:
		blast_lookup[tile] = true
	var damage: int = int(trap.get("damage", 0))
	var player_hit: bool = blast_lookup.has((_normalized_player(next_state.get("player", {}))).get("pos", Vector2i(-1, -1)))
	if player_hit:
		if damage > 0:
			next_state = _damage_player(next_state, damage, false)
		next_state = _apply_trap_keywords_to_player(next_state, trap)
	var illusions: Array = next_state.get("illusions", [])
	for illusion_var: Variant in illusions:
		if typeof(illusion_var) != TYPE_DICTIONARY:
			continue
		var illusion: Dictionary = _normalized_illusion(illusion_var as Dictionary)
		if int(illusion.get("hp", 0)) <= 0:
			continue
		if not blast_lookup.has(illusion.get("pos", Vector2i.ZERO)):
			continue
		next_state = _damage_illusion(next_state, int(illusion.get("id", -1)), damage)
	var enemies: Array = next_state.get("enemies", [])
	for enemy_index: int in range(enemies.size()):
		var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			continue
		var enemy_hit: bool = false
		for tile: Vector2i in _enemy_footprint_tiles(enemy):
			if blast_lookup.has(tile):
				enemy_hit = true
				break
		if not enemy_hit:
			continue
		if damage > 0:
			next_state = _damage_enemy(next_state, enemy_index, damage)
		if int(((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary).get("hp", 0)) > 0:
			next_state = _apply_action_keywords_to_enemy(next_state, enemy_index, trap, trap.get("pos", Vector2i.ZERO), false)
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
	if restriction_kind == "immobilize":
		player["immobilize"] = true
	else:
		player[restriction_kind] = maxi(int(player.get(restriction_kind, 0)), int(trap.get(restriction_kind, 0)))
	next_state["player"] = player
	return next_state

func _player_trap_applies_this_turn(state: Dictionary) -> bool:
	return cards_remaining_this_turn(state) > 1

func _trap_action_blocker_kind(trap: Dictionary) -> String:
	if int(trap.get("freeze", 0)) > 0:
		return "freeze"
	if int(trap.get("shock", 0)) > 0:
		return "shock"
	if bool(trap.get("immobilize", false)):
		return "immobilize"
	return ""

func _stronger_restriction(current_kind: String, next_kind: String) -> String:
	if current_kind.is_empty():
		return next_kind
	if current_kind == "freeze":
		return current_kind
	if next_kind == "freeze":
		return next_kind
	if current_kind == "shock" and next_kind == "immobilize":
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
		"immobilize":
			restrictions["immobilized"] = true
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
	if bool(trap.get("immobilize", false)):
		parts.append("Immobilize.")
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

func _live_traps(state: Dictionary) -> Array[Dictionary]:
	var traps: Array[Dictionary] = []
	for trap_var: Variant in state.get("traps", []):
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		traps.append((trap_var as Dictionary).duplicate(true))
	return traps

func _trap_tiles_in_tiles(state: Dictionary, tiles: Array[Vector2i]) -> Array[Vector2i]:
	var tile_lookup: Dictionary = {}
	for tile: Vector2i in tiles:
		tile_lookup[tile] = true
	var trap_tiles: Array[Vector2i] = []
	for trap: Dictionary in _live_traps(state):
		var trap_pos: Vector2i = trap.get("pos", Vector2i(-1, -1))
		if tile_lookup.has(trap_pos):
			trap_tiles.append(trap_pos)
	return trap_tiles

func _trap_blast_tiles(state: Dictionary, trap: Dictionary) -> Array[Vector2i]:
	var trap_pos: Vector2i = trap.get("pos", Vector2i(-1, -1))
	var tiles: Array[Vector2i] = []
	for offset: Vector2i in TRAP_BLAST_OFFSETS:
		var tile: Vector2i = trap_pos + offset
		if not PathUtils.is_in_bounds(state.get("grid", []), tile):
			continue
		if not PathUtils.is_passable(state.get("grid", []), tile):
			continue
		tiles.append(tile)
	return tiles

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
		return {"steps": steps, "skip_all": false, "shocked": false, "immobilized": false}
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var actor_name: String = str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy"))
	if int(enemy.get("burn", 0)) > 0:
		var burn_amount: int = int(enemy.get("burn", 0))
		var before_enemy: Dictionary = enemy.duplicate(true)
		next_state = _damage_enemy(next_state, enemy_index, burn_amount)
		enemy = _normalized_enemy(((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary))
		enemy["burn"] = maxi(0, int(enemy.get("burn", 0)) - GameData.status_tick_reduction("burn"))
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
			return {"steps": steps, "skip_all": true, "shocked": false, "immobilized": false}
	if int(enemy.get("bleed", 0)) > 0:
		var bleed_amount: int = int(enemy.get("bleed", 0))
		var before_bleed_enemy: Dictionary = enemy.duplicate(true)
		next_state = _damage_enemy(next_state, enemy_index, bleed_amount)
		enemy = _normalized_enemy(((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary))
		enemy["bleed"] = maxi(0, int(enemy.get("bleed", 0)) - 1)
		var bleed_enemies: Array = next_state.get("enemies", [])
		bleed_enemies[enemy_index] = enemy
		next_state["enemies"] = bleed_enemies
		steps.append({
			"kind": "status_damage",
			"actor_key": _enemy_key(enemy),
			"actor_name": actor_name,
			"tile": enemy.get("pos", Vector2i.ZERO),
			"amount": int(before_bleed_enemy.get("hp", 0)) - int(enemy.get("hp", 0)),
			"label": "Bleed",
			"text": "Bleed %d" % bleed_amount
		})
		if int(enemy.get("hp", 0)) <= 0:
			return {"steps": steps, "skip_all": true, "shocked": false, "immobilized": false}
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
				return {"steps": steps, "skip_all": true, "shocked": false, "immobilized": false}
	else:
		enemy = _advance_poison(enemy)
		var pending_poison_enemies: Array = next_state.get("enemies", [])
		pending_poison_enemies[enemy_index] = enemy
		next_state["enemies"] = pending_poison_enemies
	var skip_all: bool = false
	var shocked: bool = false
	var immobilized: bool = false
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
	else:
		if int(enemy.get("shock", 0)) > 0:
			enemy["shock"] = maxi(0, int(enemy.get("shock", 0)) - 1)
			shocked = true
			steps.append({
				"kind": "status",
				"actor_key": _enemy_key(enemy),
				"actor_name": actor_name,
				"tile": enemy.get("pos", Vector2i.ZERO),
				"label": "Shocked",
				"text": "Shocked"
			})
		if bool(enemy.get("immobilize", false)):
			enemy["immobilize"] = false
			immobilized = true
			steps.append({
				"kind": "status",
				"actor_key": _enemy_key(enemy),
				"actor_name": actor_name,
				"tile": enemy.get("pos", Vector2i.ZERO),
				"label": "Immobilized",
				"text": "Immobilized"
			})
		var restricted_enemies: Array = next_state.get("enemies", [])
		restricted_enemies[enemy_index] = enemy
		next_state["enemies"] = restricted_enemies
	return {"steps": steps, "skip_all": skip_all, "shocked": shocked, "immobilized": immobilized, "state": next_state}

func _resolve_player_start_of_turn(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var player: Dictionary = _normalized_player(next_state.get("player", {}))
	if int(player.get("burn", 0)) > 0:
		var burn_amount: int = int(player.get("burn", 0))
		next_state = _damage_player(next_state, burn_amount, false)
		player = _normalized_player(next_state.get("player", {}))
		player["burn"] = maxi(0, int(player.get("burn", 0)) - GameData.status_tick_reduction("burn"))
		next_state["player"] = player
		_log(next_state, "Burn deals %d." % burn_amount)
		if combat_outcome(next_state) != "":
			return next_state
	if int(player.get("bleed", 0)) > 0:
		var bleed_amount: int = int(player.get("bleed", 0))
		next_state = _damage_player(next_state, bleed_amount, false)
		player = _normalized_player(next_state.get("player", {}))
		player["bleed"] = maxi(0, int(player.get("bleed", 0)) - 1)
		next_state["player"] = player
		_log(next_state, "Bleed deals %d." % bleed_amount)
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
		"immobilized": false
	}
	if int(player.get("freeze", 0)) > 0:
		player["freeze"] = maxi(0, int(player.get("freeze", 0)) - 1)
		restrictions["frozen"] = true
		_log(next_state, "Frozen this turn.")
	else:
		if int(player.get("shock", 0)) > 0:
			player["shock"] = maxi(0, int(player.get("shock", 0)) - 1)
			restrictions["shocked"] = true
			_log(next_state, "Shocked this turn.")
		if bool(player.get("immobilize", false)):
			player["immobilize"] = false
			restrictions["immobilized"] = true
			_log(next_state, "Immobilized this turn.")
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

func _next_enemy_followup_attack_action(actions: Array, start_index: int) -> Dictionary:
	for action_index: int in range(start_index, actions.size()):
		var action_var: Variant = actions[action_index]
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var
		if str(action.get("type", "")) in ATTACK_ACTION_TYPES:
			return action.duplicate(true)
	return {}

func _threat_movement_tiles(state: Dictionary, enemy: Dictionary, start_tile: Vector2i, action: Dictionary, occupied: Dictionary, blocked_target: Vector2i) -> Array[Vector2i]:
	var move_range: int = int(action.get("range", 0))
	if move_range <= 0:
		return []
	var preview_enemy: Dictionary = enemy.duplicate(true)
	preview_enemy["pos"] = start_tile
	if preview_enemy.get("footprint", Vector2i.ONE) != Vector2i.ONE:
		return _reachable_enemy_anchor_tiles(state, preview_enemy, move_range, occupied, blocked_target)
	return PathUtils.reachable_tiles(state.get("grid", []), start_tile, move_range, occupied)

func _threat_attack_tiles(state: Dictionary, enemy: Dictionary, start_tile: Vector2i, action: Dictionary) -> Array[Vector2i]:
	var lookup: Dictionary = {}
	var grid: Array = state.get("grid", [])
	var preview_enemy: Dictionary = enemy.duplicate(true)
	preview_enemy["pos"] = start_tile
	var action_type: String = str(action.get("type", ""))
	match action_type:
		"melee", "ranged", "push", "pull":
			for tile: Vector2i in _threat_candidate_tiles(state, preview_enemy):
				if _enemy_action_reaches_tile(state, preview_enemy, action, tile):
					lookup[tile] = true
			for tile: Vector2i in _threat_trap_blast_tiles(state, preview_enemy, action):
				lookup[tile] = true
		"aoe":
			for tile: Vector2i in _threat_aoe_tiles(state, preview_enemy, action):
				lookup[tile] = true
			for tile: Vector2i in _threat_trap_blast_tiles(state, preview_enemy, action):
				lookup[tile] = true
		"lightning_strikes":
			var preview_state: Dictionary = _state_with_enemy_anchor(state, preview_enemy, start_tile)
			for tile: Vector2i in _lightning_strike_tiles(preview_state, preview_enemy, action):
				lookup[tile] = true
	return _sorted_tiles_from_lookup(lookup)

func _threat_candidate_tiles(state: Dictionary, enemy: Dictionary) -> Array[Vector2i]:
	var grid: Array = state.get("grid", [])
	var enemy_footprint: Array[Vector2i] = _enemy_footprint_tiles(enemy)
	var tiles: Array[Vector2i] = []
	for y: int in range(grid.size()):
		for x: int in range((grid[y] as Array).size()):
			var tile: Vector2i = Vector2i(x, y)
			if enemy_footprint.has(tile):
				continue
			if not PathUtils.is_passable(grid, tile):
				continue
			tiles.append(tile)
	return tiles

func _threat_aoe_tiles(state: Dictionary, enemy: Dictionary, action: Dictionary) -> Array[Vector2i]:
	var grid: Array = state.get("grid", [])
	var lookup: Dictionary = {}
	var centers: Array[Vector2i] = _vector2i_values([enemy.get("pos", Vector2i.ZERO)])
	var attack_range: int = int(action.get("range", 0))
	if attack_range > 0:
		centers = _threat_candidate_tiles(state, enemy)
	for center: Vector2i in centers:
		if attack_range > 0 and not _enemy_aoe_can_target_center(state, enemy, action, center):
			continue
		if _action_orientation_direction(action) != Vector2i.ZERO:
			for tile: Vector2i in _enemy_aoe_tiles_for_target(state, enemy, action, center, true):
				if _enemy_footprint_tiles(enemy).has(tile):
					continue
				lookup[tile] = true
		elif bool(action.get("orient_toward_target", false)):
			for target: Dictionary in _actor_targets(state):
				if not _enemy_action_reaches_target(state, enemy, action, target):
					continue
				var target_pos: Vector2i = target.get("pos", Vector2i.ZERO)
				if attack_range > 0 and center != target_pos:
					continue
				var resolved_action: Dictionary = _enemy_action_oriented_to_target(action, enemy, target_pos)
				for tile: Vector2i in _enemy_aoe_tiles_for_target(state, enemy, resolved_action, center, true):
					if _enemy_footprint_tiles(enemy).has(tile):
						continue
					lookup[tile] = true
		else:
			for offsets_var: Variant in _aoe_pattern_variants(action):
				var offsets: Array = offsets_var
				for tile: Vector2i in _tiles_for_aoe_offsets(grid, center, offsets):
					if _enemy_footprint_tiles(enemy).has(tile):
						continue
					lookup[tile] = true
	return _sorted_tiles_from_lookup(lookup)

func _threat_trap_blast_tiles(state: Dictionary, enemy: Dictionary, action: Dictionary) -> Array[Vector2i]:
	var lookup: Dictionary = {}
	for trap: Dictionary in _live_traps(state):
		var trap_pos: Vector2i = trap.get("pos", Vector2i(-1, -1))
		if not _enemy_action_reaches_tile(state, enemy, action, trap_pos):
			continue
		if _trap_blast_hits_enemy(state, trap, enemy):
			continue
		for tile: Vector2i in _trap_blast_tiles(state, trap):
			lookup[tile] = true
	return _sorted_tiles_from_lookup(lookup)

func _enemy_aoe_can_target_center(state: Dictionary, enemy: Dictionary, action: Dictionary, center: Vector2i) -> bool:
	var grid: Array = state.get("grid", [])
	if not PathUtils.is_passable(grid, center):
		return false
	var source_pos: Vector2i = _closest_enemy_tile_to(enemy, center)
	return (
		PathUtils.manhattan(source_pos, center) <= int(action.get("range", 0))
		and PathUtils.has_line_of_sight(grid, source_pos, center)
	)

func _state_with_enemy_anchor(state: Dictionary, enemy: Dictionary, anchor: Vector2i) -> Dictionary:
	var preview_state: Dictionary = state.duplicate(true)
	var enemies: Array = preview_state.get("enemies", []).duplicate(true)
	var enemy_id: int = int(enemy.get("id", -1))
	for index: int in range(enemies.size()):
		if typeof(enemies[index]) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = enemies[index]
		if int(candidate.get("id", -1)) != enemy_id:
			continue
		var preview_enemy: Dictionary = enemy.duplicate(true)
		preview_enemy["pos"] = anchor
		enemies[index] = preview_enemy
		break
	preview_state["enemies"] = enemies
	return preview_state

func _player_status_step_text(before_player: Dictionary, after_player: Dictionary, action: Dictionary) -> String:
	var tags: PackedStringArray = []
	if int(after_player.get("burn", 0)) > int(before_player.get("burn", 0)):
		tags.append("Burn")
	if int(after_player.get("freeze", 0)) > int(before_player.get("freeze", 0)):
		tags.append("Freeze")
	if int(after_player.get("shock", 0)) > int(before_player.get("shock", 0)):
		tags.append("Shock")
	if bool(after_player.get("immobilize", false)) and not bool(before_player.get("immobilize", false)):
		tags.append("Immobilize")
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
				var total_heal: int = amount
				player["hp"] = mini(int(player.get("max_hp", 1)), int(player.get("hp", 0)) + total_heal)
				state["player"] = player
				_log(state, "Collected a potion for %d health." % total_heal)
			"rusty_shield":
				var shield_player: Dictionary = state.get("player", {})
				shield_player["block"] = int(shield_player.get("block", 0)) + amount
				state["player"] = shield_player
				_log(state, "Collected a rusty shield for %d block." % amount)
			"dropped_embers":
				state["recovered_embers_total"] = int(state.get("recovered_embers_total", 0)) + amount
				state["recovery_marker_claimed"] = true
				_log(state, "Recovered %d embers." % amount)
			"equipment":
				var equipment_id: String = str(loot.get("equipment_id", ""))
				if not equipment_id.is_empty():
					var collected: Array = state.get("collected_equipment", []).duplicate()
					if not collected.has(equipment_id):
						collected.append(equipment_id)
					state["collected_equipment"] = collected
					var item_name: String = str(GameData.equipment_def(equipment_id).get("name", equipment_id))
					_log(state, "Found %s." % item_name)

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

func _occupied_terrain_tiles(state: Dictionary) -> Dictionary:
	var occupied: Dictionary = {}
	for terrain: Dictionary in _live_terrain(state):
		occupied[terrain.get("pos", Vector2i.ZERO)] = true
	return occupied

func _occupied_actor_tiles(state: Dictionary, exclude_enemy_id: int = -1, exclude_illusion_id: int = -1) -> Dictionary:
	var occupied: Dictionary = _occupied_enemy_tiles(state, exclude_enemy_id)
	for tile_var: Variant in _occupied_illusion_tiles(state, exclude_illusion_id).keys():
		occupied[tile_var] = true
	for tile_var: Variant in _occupied_terrain_tiles(state).keys():
		occupied[tile_var] = true
	return occupied

func _enemy_blocking_tiles(state: Dictionary, exclude_enemy_id: int = -1) -> Dictionary:
	var occupied: Dictionary = _occupied_actor_tiles(state, exclude_enemy_id)
	var player_pos: Vector2i = (_normalized_player(state.get("player", {}))).get("pos", Vector2i.ZERO)
	occupied[player_pos] = true
	return occupied

func _enemy_blocking_tiles_without_terrain(state: Dictionary, exclude_enemy_id: int = -1) -> Dictionary:
	var occupied: Dictionary = _occupied_enemy_tiles(state, exclude_enemy_id)
	for tile_var: Variant in _occupied_illusion_tiles(state).keys():
		occupied[tile_var] = true
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

func _live_terrain(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for terrain_var: Variant in state.get("terrain", []):
		if typeof(terrain_var) != TYPE_DICTIONARY:
			continue
		var terrain: Dictionary = _normalized_terrain(terrain_var)
		if int(terrain.get("hp", 0)) > 0:
			result.append(terrain)
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

func _terrain_index_at_tile(state: Dictionary, tile: Vector2i) -> int:
	var terrain_entries: Array = state.get("terrain", [])
	for index: int in range(terrain_entries.size()):
		if typeof(terrain_entries[index]) != TYPE_DICTIONARY:
			continue
		var terrain: Dictionary = _normalized_terrain(terrain_entries[index])
		if int(terrain.get("hp", 0)) <= 0:
			continue
		if terrain.get("pos", Vector2i(-1, -1)) == tile:
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

func _terrain_indices_in_tiles(state: Dictionary, tiles: Array[Vector2i]) -> Array[int]:
	var tile_lookup: Dictionary = {}
	for tile: Vector2i in tiles:
		tile_lookup[tile] = true
	var indices: Array[int] = []
	var terrain_entries: Array = state.get("terrain", [])
	for index: int in range(terrain_entries.size()):
		if typeof(terrain_entries[index]) != TYPE_DICTIONARY:
			continue
		var terrain: Dictionary = _normalized_terrain(terrain_entries[index])
		if int(terrain.get("hp", 0)) <= 0:
			continue
		if tile_lookup.has(terrain.get("pos", Vector2i.ZERO)):
			indices.append(index)
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

func _enemy_distance_between(first_enemy: Dictionary, second_enemy: Dictionary) -> int:
	var best_distance: int = 9999
	for first_tile: Vector2i in _enemy_footprint_tiles(first_enemy):
		for second_tile: Vector2i in _enemy_footprint_tiles(second_enemy):
			best_distance = mini(best_distance, PathUtils.manhattan(first_tile, second_tile))
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

func _trigger_enemy_death_spawn(state: Dictionary, enemy: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	if bool(enemy.get("summoned", false)):
		return next_state
	var spawn_def_value: Variant = GameData.enemy_def(str(enemy.get("type", ""))).get("death_spawn", {})
	if typeof(spawn_def_value) != TYPE_DICTIONARY:
		return next_state
	var spawn_def: Dictionary = (spawn_def_value as Dictionary).duplicate(true)
	if spawn_def.is_empty():
		return next_state
	var spawn_kind: String = str(spawn_def.get("type", "split"))
	if spawn_kind != "split":
		return next_state
	var spawn_type: String = str(spawn_def.get("enemy_type", ""))
	if spawn_type.is_empty() or GameData.enemy_def(spawn_type).is_empty():
		return next_state
	var spawn_count: int = maxi(0, int(spawn_def.get("count", 0)))
	if spawn_count <= 0:
		return next_state
	var spawn_tiles: Array[Vector2i] = _death_spawn_tiles_for_enemy(next_state, enemy, spawn_def)
	if spawn_tiles.is_empty():
		return next_state
	var enemies: Array = next_state.get("enemies", []).duplicate(true)
	var first_spawned_index: int = enemies.size()
	var next_id: int = _next_enemy_id(next_state)
	for tile: Vector2i in spawn_tiles:
		enemies.append(_spawned_enemy_entry(next_state, spawn_type, next_id, tile, bool(spawn_def.get("summoned", true))))
		next_id += 1
	next_state["enemies"] = enemies
	var intent_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	intent_rng.state = int(next_state.get("rng_state", 1))
	for spawned_index: int in range(first_spawned_index, first_spawned_index + spawn_tiles.size()):
		_assign_enemy_intent(next_state, spawned_index, intent_rng)
		var spawned_enemy: Dictionary = _normalized_enemy((next_state.get("enemies", []) as Array)[spawned_index] as Dictionary)
		_schedule_enemy_after_spawn(next_state, spawned_enemy, spawned_index - first_spawned_index)
	next_state["rng_state"] = intent_rng.state
	_log(next_state, "%s splits." % str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")))
	return next_state

func _spawned_enemy_entry(state: Dictionary, enemy_type: String, enemy_id: int, tile: Vector2i, summoned: bool) -> Dictionary:
	var max_hp: int = _scaled_enemy_max_hp(enemy_type, int(state.get("room_depth", 1)))
	var spawned: Dictionary = {
		"id": enemy_id,
		"type": enemy_type,
		"summoned": summoned,
		"element": str(state.get("room_element", ElementData.NONE)),
		"pos": tile,
		"hp": max_hp,
		"max_hp": max_hp,
		"block": 0,
		"stoneskin": 0
	}
	return _normalized_enemy(spawned)

func _schedule_enemy_after_spawn(state: Dictionary, enemy: Dictionary, spawn_order: int) -> void:
	var intent_time_cost: int = _enemy_intent_time_cost(enemy.get("intent", {}) as Dictionary)
	var delay: int = maxi(ENEMY_MIN_INITIATIVE, _enemy_base_initiative(state, enemy) + maxi(0, intent_time_cost))
	_schedule_actor(state, _enemy_actor_entry(state, enemy, int(state.get("initiative_clock", 0)) + delay + maxi(0, spawn_order), 0))

func _death_spawn_tiles_for_enemy(state: Dictionary, enemy: Dictionary, spawn_def: Dictionary) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = _vector2i_values([])
	var occupied: Dictionary = _enemy_blocking_tiles(state)
	var radius: int = maxi(1, int(spawn_def.get("radius", 1)))
	var origin: Vector2i = enemy.get("pos", Vector2i.ZERO)
	for tile: Vector2i in PathUtils.diamond_tiles(origin, radius, state.get("grid", [])):
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
	var results: Array[Vector2i] = _vector2i_values([])
	var count: int = maxi(0, int(spawn_def.get("count", 0)))
	for tile: Vector2i in candidates:
		results.append(tile)
		if results.size() >= count:
			break
	return results

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
		"time": 6,
		"actions": [
			{"type": "summon_minions", "minion_type": LIGHTNING_WISP_TYPE, "count": 2}
		]
	}

func _best_aoe_tiles_for_target(state: Dictionary, action: Dictionary, target_tile: Vector2i, score_player: bool) -> Array[Vector2i]:
	var grid: Array = state.get("grid", [])
	var centered_target: bool = int(action.get("range", 0)) > 0
	var orientation: Vector2i = _action_orientation_direction(action)
	if orientation != Vector2i.ZERO:
		var oriented_offsets: Array[Vector2i] = _aoe_pattern_offsets_for_direction(action, orientation)
		return _tiles_for_centered_aoe_offsets(grid, target_tile, oriented_offsets) if centered_target else _tiles_for_aoe_offsets(grid, target_tile, oriented_offsets)
	var variants: Array = _aoe_pattern_variants(action)
	var best_tiles: Array[Vector2i] = []
	var best_score: int = -1
	var best_size: int = 9999
	for offsets_var: Variant in variants:
		var offsets: Array = offsets_var
		var tiles: Array[Vector2i] = _tiles_for_centered_aoe_offsets(grid, target_tile, offsets) if centered_target else _tiles_for_aoe_offsets(grid, target_tile, offsets)
		var score: int = 0
		if score_player:
			score = _actor_targets_in_tiles(state, tiles).size()
		else:
			score = _enemy_indices_in_tiles(state, tiles).size()
			score += _terrain_indices_in_tiles(state, tiles).size()
			score += _trap_tiles_in_tiles(state, tiles).size()
		if score > best_score or (score == best_score and tiles.size() < best_size):
			best_score = score
			best_size = tiles.size()
			best_tiles = tiles
	return best_tiles

func _aoe_tiles_for_anchor(grid: Array, action: Dictionary, target_tile: Vector2i) -> Array[Vector2i]:
	var centered_target: bool = int(action.get("range", 0)) > 0
	var orientation: Vector2i = _action_orientation_direction(action)
	if orientation != Vector2i.ZERO:
		var oriented_offsets: Array[Vector2i] = _aoe_pattern_offsets_for_direction(action, orientation)
		return _tiles_for_centered_aoe_offsets(grid, target_tile, oriented_offsets) if centered_target else _tiles_for_aoe_offsets(grid, target_tile, oriented_offsets)
	var variants: Array = _aoe_pattern_variants(action)
	if variants.is_empty():
		return []
	return _tiles_for_centered_aoe_offsets(grid, target_tile, variants[0]) if centered_target else _tiles_for_aoe_offsets(grid, target_tile, variants[0])

func _tiles_for_centered_aoe_offsets(grid: Array, center: Vector2i, offsets: Array) -> Array[Vector2i]:
	return _tiles_for_aoe_offsets(grid, center - _aoe_center_offset(offsets), offsets)

func _tiles_for_aoe_offsets(grid: Array, anchor: Vector2i, offsets: Array) -> Array[Vector2i]:
	var lookup: Dictionary = {}
	for offset: Vector2i in _vector2i_values(offsets):
		var tile: Vector2i = anchor + offset
		if not PathUtils.is_passable(grid, tile):
			continue
		lookup[tile] = true
	return _sorted_tiles_from_lookup(lookup)

func _aoe_center_offset(offsets: Array) -> Vector2i:
	var typed_offsets: Array[Vector2i] = _vector2i_values(offsets)
	if typed_offsets.is_empty():
		return Vector2i.ZERO
	var center_sum: Vector2 = Vector2.ZERO
	for offset: Vector2i in typed_offsets:
		center_sum += Vector2(float(offset.x), float(offset.y))
	var centroid: Vector2 = center_sum / float(typed_offsets.size())
	var rounded_centroid: Vector2i = Vector2i(int(roundf(centroid.x)), int(roundf(centroid.y)))
	if is_equal_approx(centroid.x, float(rounded_centroid.x)) and is_equal_approx(centroid.y, float(rounded_centroid.y)):
		return rounded_centroid
	var best_offset: Vector2i = typed_offsets[0]
	var best_distance: float = INF
	var best_origin_distance: int = 99999
	for offset: Vector2i in typed_offsets:
		var distance: float = Vector2(float(offset.x), float(offset.y)).distance_squared_to(centroid)
		var origin_distance: int = PathUtils.manhattan(Vector2i.ZERO, offset)
		if distance < best_distance or (is_equal_approx(distance, best_distance) and origin_distance < best_origin_distance):
			best_distance = distance
			best_origin_distance = origin_distance
			best_offset = offset
	return best_offset

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

func _aoe_pattern_offsets_for_direction(action: Dictionary, direction: Vector2i) -> Array[Vector2i]:
	var rotation: int = _rotation_for_direction(direction)
	var result: Array[Vector2i] = []
	for offset: Vector2i in _aoe_pattern_offsets(action):
		result.append(_rotated_offset(offset, rotation))
	return result

func _rotation_for_direction(direction: Vector2i) -> int:
	match _cardinal_direction(direction):
		Vector2i(0, 1):
			return 1
		Vector2i(-1, 0):
			return 2
		Vector2i(0, -1):
			return 3
		_:
			return 0

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
			enemies[enemy_index] = enemy
			return
	enemy["intent"] = (intents[0] as Dictionary).duplicate(true)
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
	var is_elemental_room: bool = ElementData.is_elemental(room_element)
	var allow_control: bool = _intent_gets_elemental_control(base_intent, room_element, room_depth)
	var actions: Array = []
	for action_var: Variant in base_intent.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = (action_var as Dictionary).duplicate(true)
		if is_elemental_room:
			action = _elementalize_enemy_action(action, room_element, room_depth, allow_control)
		actions.append(_scale_enemy_action_for_depth(action, room_depth))
	intent["actions"] = actions
	if is_elemental_room:
		intent["element"] = room_element
	return intent

func _intent_gets_elemental_control(base_intent: Dictionary, room_element: String, room_depth: int) -> bool:
	if room_element not in [ElementData.ICE, ElementData.LIGHTNING]:
		return false
	if _encounter_depth_for_room_depth(room_depth) < 3:
		return false
	return int(base_intent.get("weight", 1)) <= 2

func _elementalize_enemy_action(base_action: Dictionary, room_element: String, room_depth: int, allow_control: bool = true) -> Dictionary:
	var action: Dictionary = base_action.duplicate(true)
	var action_type: String = str(action.get("type", ""))
	var encounter_depth: int = _encounter_depth_for_room_depth(room_depth)
	var full_power: bool = encounter_depth >= 3
	var medium_power: bool = encounter_depth >= 2
	match room_element:
		ElementData.FIRE:
			if action_type in ELEMENTAL_ATTACK_ACTION_TYPES:
				if action_type in ["ranged", "aoe"]:
					action["type"] = "aoe"
					if not action.has("pattern"):
						action["pattern"] = DEFAULT_AOE_PATTERN.duplicate(true)
					action["rotate"] = bool(action.get("rotate", true))
				action["damage"] = int(action.get("damage", 0)) + GameData.fixed_point_amount(2 if medium_power else 1)
				var fire_burn_amount: int = GameData.fixed_point_amount(2 if full_power else 1)
				action["burn"] = maxi(
					fire_burn_amount,
					int(action.get("burn", 0)) + fire_burn_amount
				)
				if full_power and int(action.get("damage", 0)) >= GameData.fixed_point_amount(6):
					action["self_damage"] = maxi(GameData.fixed_point_amount(1), int(action.get("self_damage", 0)))
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
			if action_type == "move_toward" or action_type == "move_away":
				var lightning_move_range: int = int(action.get("range", 0))
				if lightning_move_range > 0:
					action["range"] = maxi(1, lightning_move_range - 1)
			elif action_type in ELEMENTAL_ATTACK_ACTION_TYPES:
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
				action["range"] = mini(4, maxi(3, int(action.get("range", 1))))
				action.erase("pattern")
				action.erase("rotate")
				action["damage"] = maxi(GameData.fixed_point_amount(1), int(action.get("damage", 0)) - GameData.fixed_point_amount(2))
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
				action["damage"] = int(action.get("damage", 0)) + GameData.fixed_point_amount(1 if medium_power else 0)
				var poison_bonus: int = 1
				if full_power:
					poison_bonus = 2
				action["poison"] = maxi(
					GameData.fixed_point_amount(2 if full_power else 1),
					int(action.get("poison", 0)) + GameData.fixed_point_amount(poison_bonus)
				)
	return action

func _encounter_depth_for_room_depth(room_depth: int) -> int:
	return posmod(maxi(1, room_depth) - 1, DEPTHS_PER_SEQUENCE) + 1

func _depth_sequence_index(room_depth: int) -> int:
	return int((maxi(1, room_depth) - 1) / DEPTHS_PER_SEQUENCE)

func _scaled_enemy_max_hp(enemy_type: String, room_depth: int) -> int:
	var base_hp: int = int(GameData.enemy_def(enemy_type).get("max_hp", 1))
	var local_scale: float = _local_enemy_hp_scale(room_depth)
	var scaled_hp: int = ceili(float(base_hp) * local_scale)
	var sequence_index: int = _depth_sequence_index(room_depth)
	if sequence_index <= 0:
		return scaled_hp
	scaled_hp = ceili(float(scaled_hp) * (1.0 + ENEMY_HP_SCALE_PER_SEQUENCE * float(sequence_index)))
	return scaled_hp + ENEMY_HP_FLAT_BONUS_PER_SEQUENCE * sequence_index

func _scale_enemy_action_for_depth(action: Dictionary, room_depth: int) -> Dictionary:
	var scaled: Dictionary = action.duplicate(true)
	var action_type: String = str(scaled.get("type", ""))
	var damage_delta: int = _local_enemy_damage_delta(room_depth)
	if damage_delta != 0 and (action_type in ATTACK_ACTION_TYPES or action_type == "lightning_strikes") and scaled.has("damage"):
		scaled["damage"] = maxi(GameData.fixed_point_amount(1), int(scaled.get("damage", 0)) + damage_delta)
	var support_delta: int = _local_enemy_support_delta(room_depth)
	if support_delta != 0:
		if action_type == "block" or action_type == "stoneskin" or action_type == "guard_ally":
			scaled["amount"] = maxi(0, int(scaled.get("amount", 0)) + support_delta)
		elif action_type == "heal_self" or action_type == "heal_ally":
			scaled["amount"] = maxi(0, int(scaled.get("amount", 0)) + support_delta)
	var sequence_index: int = _depth_sequence_index(room_depth)
	if sequence_index <= 0:
		return scaled
	if action_type in ATTACK_ACTION_TYPES or action_type == "lightning_strikes":
		if scaled.has("damage"):
			scaled["damage"] = int(scaled.get("damage", 0)) + ENEMY_DAMAGE_BONUS_PER_SEQUENCE * sequence_index
	if action_type == "block" or action_type == "stoneskin" or action_type == "guard_ally":
		scaled["amount"] = int(scaled.get("amount", 0)) + ENEMY_SUPPORT_BONUS_PER_SEQUENCE * sequence_index
	elif action_type == "heal_self" or action_type == "heal_ally":
		scaled["amount"] = int(scaled.get("amount", 0)) + GameData.fixed_point_amount(sequence_index)
	return scaled

func _local_enemy_hp_scale(room_depth: int) -> float:
	match _encounter_depth_for_room_depth(room_depth):
		1:
			return ENEMY_HP_SCALE_DEPTH_ONE
		3:
			return ENEMY_HP_SCALE_DEPTH_THREE
		_:
			return 1.0

func _local_enemy_damage_delta(room_depth: int) -> int:
	match _encounter_depth_for_room_depth(room_depth):
		1:
			return ENEMY_DAMAGE_DELTA_DEPTH_ONE
		3:
			return ENEMY_DAMAGE_DELTA_DEPTH_THREE
		_:
			return 0

func _local_enemy_support_delta(room_depth: int) -> int:
	match _encounter_depth_for_room_depth(room_depth):
		1:
			return ENEMY_SUPPORT_DELTA_DEPTH_ONE
		3:
			return ENEMY_SUPPORT_DELTA_DEPTH_THREE
		_:
			return 0

func _apply_revealed_intent_blocks(state: Dictionary) -> Dictionary:
	# Intent can preview a future guard, but block only becomes real when that
	# actor reaches its activation and resolves the block action.
	return state.duplicate(true)

func _preview_block_for_intent(intent: Dictionary) -> int:
	var total: int = 0
	for action_var: Variant in intent.get("actions", []):
		var action: Dictionary = action_var as Dictionary
		if str(action.get("type", "")) == "block":
			total += int(action.get("amount", 0))
	return total

func _best_move_toward(state: Dictionary, enemy_index: int, target: Vector2i, move_range: int) -> Vector2i:
	var enemies: Array = state.get("enemies", [])
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var start: Vector2i = enemy.get("pos", Vector2i.ZERO)
	if move_range <= 0:
		return start
	var movement_occupied: Dictionary = _enemy_path_blockers(state, enemy, true, true)
	var best_tile: Vector2i = _best_move_toward_with_scoring(state, enemy, target, move_range, movement_occupied, movement_occupied)
	if best_tile != start:
		return best_tile
	var terrain_planning_occupied: Dictionary = _enemy_path_blockers(state, enemy, false, true)
	return _best_move_toward_with_scoring(state, enemy, target, move_range, movement_occupied, terrain_planning_occupied)

func _best_move_toward_for_followup(state: Dictionary, enemy_index: int, target: Vector2i, move_range: int, followup_action: Dictionary) -> Vector2i:
	if move_range <= 0:
		return INVALID_TILE
	if str(followup_action.get("type", "")) != "aoe" or not bool(followup_action.get("orient_toward_target", false)):
		return INVALID_TILE
	var enemies: Array = state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return INVALID_TILE
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var start: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var occupied: Dictionary = _enemy_path_blockers(state, enemy, true, true)
	var candidates: Array[Vector2i] = _vector2i_values([start])
	for tile: Vector2i in _reachable_enemy_anchor_tiles(state, enemy, move_range, occupied, target):
		if not candidates.has(tile):
			candidates.append(tile)
	var best_tile: Vector2i = INVALID_TILE
	var best_move_cost: int = 9999
	var best_target_distance: int = 9999
	for tile: Vector2i in candidates:
		var candidate_enemy: Dictionary = enemy.duplicate(true)
		candidate_enemy["pos"] = tile
		var candidate_state: Dictionary = _state_with_enemy_anchor(state, candidate_enemy, tile)
		if not _enemy_action_reaches_tile(candidate_state, candidate_enemy, followup_action, target):
			continue
		var move_cost: int = PathUtils.manhattan(start, tile)
		var target_distance: int = _enemy_distance_to_tile(candidate_enemy, target)
		if best_tile == INVALID_TILE or _line_setup_candidate_is_better(move_cost, target_distance, tile, best_move_cost, best_target_distance, best_tile):
			best_tile = tile
			best_move_cost = move_cost
			best_target_distance = target_distance
	return best_tile

func _line_setup_candidate_is_better(move_cost: int, target_distance: int, tile: Vector2i, best_move_cost: int, best_target_distance: int, best_tile: Vector2i) -> bool:
	if move_cost != best_move_cost:
		return move_cost < best_move_cost
	if target_distance != best_target_distance:
		return target_distance < best_target_distance
	if tile.y != best_tile.y:
		return tile.y < best_tile.y
	return tile.x < best_tile.x

func _best_move_away(state: Dictionary, enemy_index: int, target: Vector2i, move_range: int) -> Vector2i:
	var enemies: Array = state.get("enemies", [])
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var start: Vector2i = enemy.get("pos", Vector2i.ZERO)
	if move_range <= 0:
		return start
	var occupied: Dictionary = _enemy_path_blockers(state, enemy, true, true)
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

func _best_move_toward_with_scoring(state: Dictionary, enemy: Dictionary, target: Vector2i, move_range: int, movement_occupied: Dictionary, scoring_occupied: Dictionary) -> Vector2i:
	var start: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var start_score: int = _enemy_anchor_path_distance(state, enemy, target, scoring_occupied)
	var start_distance: int = _enemy_distance_to_tile(enemy, target)
	var best_tile: Vector2i = start
	var best_score: int = start_score
	var best_distance: int = start_distance
	for tile: Vector2i in _reachable_enemy_anchor_tiles(state, enemy, move_range, movement_occupied, target):
		var candidate_enemy: Dictionary = enemy.duplicate(true)
		candidate_enemy["pos"] = tile
		var score: int = _enemy_anchor_path_distance(state, candidate_enemy, target, scoring_occupied)
		var distance: int = _enemy_distance_to_tile(candidate_enemy, target)
		var improves_start: bool = score < start_score or (score == start_score and distance < start_distance)
		if not improves_start:
			continue
		if best_tile == start or _toward_move_candidate_is_better(score, distance, tile, best_score, best_distance, best_tile):
			best_tile = tile
			best_score = score
			best_distance = distance
	return best_tile

func _toward_move_candidate_is_better(score: int, distance: int, tile: Vector2i, best_score: int, best_distance: int, best_tile: Vector2i) -> bool:
	if score != best_score:
		return score < best_score
	if distance != best_distance:
		return distance < best_distance
	if tile.y != best_tile.y:
		return tile.y < best_tile.y
	return tile.x < best_tile.x

func _enemy_anchor_path_distance(state: Dictionary, enemy: Dictionary, target: Vector2i, occupied: Dictionary) -> int:
	if _enemy_distance_to_tile(enemy, target) <= 1:
		return 0
	var start: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var queue: Array[Vector2i] = _vector2i_values([start])
	var distance_by_tile: Dictionary = {start: 0}
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var current_distance: int = int(distance_by_tile.get(current, 0))
		for dir: Vector2i in PathUtils.DIRS_4:
			var next_tile: Vector2i = current + dir
			if distance_by_tile.has(next_tile):
				continue
			if not _enemy_can_occupy_anchor(state, enemy, next_tile, occupied, target):
				continue
			var next_enemy: Dictionary = enemy.duplicate(true)
			next_enemy["pos"] = next_tile
			var next_distance: int = current_distance + 1
			if _enemy_distance_to_tile(next_enemy, target) <= 1:
				return next_distance
			distance_by_tile[next_tile] = next_distance
			queue.append(next_tile)
	return 10000 + _enemy_distance_to_tile(enemy, target)

func _enemy_path_blockers(state: Dictionary, enemy: Dictionary, block_terrain: bool, avoid_traps: bool) -> Dictionary:
	var enemy_id: int = int(enemy.get("id", -1))
	var occupied: Dictionary = _enemy_blocking_tiles(state, enemy_id) if block_terrain else _enemy_blocking_tiles_without_terrain(state, enemy_id)
	if avoid_traps:
		for trap_tile_var: Variant in _trap_tiles_lookup(state).keys():
			occupied[trap_tile_var] = true
	return occupied

func _enemy_threat_path_blockers(state: Dictionary, enemy: Dictionary, block_terrain: bool, avoid_traps: bool) -> Dictionary:
	var occupied: Dictionary = _enemy_path_blockers(state, enemy, block_terrain, avoid_traps)
	var player: Dictionary = _normalized_player(state.get("player", {}))
	var player_pos_value: Variant = player.get("pos", null)
	if typeof(player_pos_value) == TYPE_VECTOR2I:
		occupied.erase(player_pos_value)
	return occupied

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

func _damage_for_enemy_target(state: Dictionary, action: Dictionary, enemy_index: int) -> int:
	var damage: int = final_damage_for_player_action(state, action)
	var enemies: Array = state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return damage
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	damage += int(enemy.get("expose", 0))
	for effect: Dictionary in _relic_effects(state):
		if str(effect.get("type", "")) != "damage_vs_status":
			continue
		var status_id: String = str(effect.get("status", ""))
		if status_id.is_empty() or _unit_status_amount(enemy, status_id) <= 0:
			continue
		damage += GameData.fixed_point_amount(int(effect.get("value", 0)))
	if _unit_status_amount(enemy, "freeze") > 0:
		damage += GameData.stat_value(state, "ice_magick") * 2
	return maxi(0, damage)

func _conditional_attack_bonus_for_action(state: Dictionary, action: Dictionary) -> int:
	var total: int = 0
	if str(action.get("type", "")) not in ATTACK_ACTION_TYPES:
		return total
	var player: Dictionary = _normalized_player(state.get("player", {}))
	for effect: Dictionary in _relic_effects(state):
		match str(effect.get("type", "")):
			"glass_attack_bonus":
				if int(player.get("block", 0)) <= 0 and int(player.get("stoneskin", 0)) <= 0:
					total += GameData.fixed_point_amount(int(effect.get("value", 0)))
			"bloodied_attack_bonus":
				if int(player.get("hp", 0)) * 2 <= int(player.get("max_hp", 1)):
					total += GameData.fixed_point_amount(int(effect.get("value", 0)))
			"room_element_attack_bonus":
				var card_element: String = str(action.get("_card_element", ElementData.NONE))
				if ElementData.is_elemental(card_element) and card_element == str(state.get("room_element", ElementData.NONE)):
					total += GameData.fixed_point_amount(int(effect.get("value", 0)))
	return total

func _conditional_attack_modifiers_for_action(state: Dictionary, action: Dictionary) -> Array[Dictionary]:
	var modifiers: Array[Dictionary] = []
	if str(action.get("type", "")) not in ATTACK_ACTION_TYPES:
		return modifiers
	var player: Dictionary = _normalized_player(state.get("player", {}))
	for effect: Dictionary in _relic_effects(state):
		var amount: int = 0
		var detail: String = ""
		match str(effect.get("type", "")):
			"glass_attack_bonus":
				if int(player.get("block", 0)) <= 0 and int(player.get("stoneskin", 0)) <= 0:
					amount = GameData.fixed_point_amount(int(effect.get("value", 0)))
					detail = "No block or stoneskin"
			"bloodied_attack_bonus":
				if int(player.get("hp", 0)) * 2 <= int(player.get("max_hp", 1)):
					amount = GameData.fixed_point_amount(int(effect.get("value", 0)))
					detail = "At half health or less"
			"room_element_attack_bonus":
				var card_element: String = str(action.get("_card_element", ElementData.NONE))
				if ElementData.is_elemental(card_element) and card_element == str(state.get("room_element", ElementData.NONE)):
					amount = GameData.fixed_point_amount(int(effect.get("value", 0)))
					detail = "Matching room element"
		if amount == 0:
			continue
		modifiers.append({
			"source": _relic_effect_source_name(effect),
			"kind": "relic",
			"amount": amount,
			"detail": detail
		})
	return modifiers

func _trigger_blink_relics(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	for effect: Dictionary in _relic_effects(next_state):
		match str(effect.get("type", "")):
			"blink_draw_once_per_turn":
				var draw_key: String = _turn_relic_flag_key(effect, "blink_draw")
				if _turn_flag(next_state, draw_key):
					continue
				_set_turn_flag(next_state, draw_key, true)
				next_state = _draw_cards_in_place(next_state, int(effect.get("value", 1)))
			"blink_intensity_gain_once_per_turn":
				var intensity_key: String = _turn_relic_flag_key(effect, "blink_intensity")
				if _turn_flag(next_state, intensity_key):
					continue
				_set_turn_flag(next_state, intensity_key, true)
				next_state = _gain_elemental_intensity(next_state, str(effect.get("element", ElementData.NONE)), int(effect.get("amount", effect.get("value", 1))), _relic_effect_source_name(effect))
	return next_state

func _trigger_long_move_relics(state: Dictionary, distance: int) -> Dictionary:
	var next_state: Dictionary = state
	for effect: Dictionary in _relic_effects(next_state):
		if str(effect.get("type", "")) != "long_move_card_play":
			continue
		if distance < int(effect.get("threshold", 1)):
			continue
		var flag_key: String = _turn_relic_flag_key(effect, "long_move_card_play")
		if _turn_flag(next_state, flag_key):
			continue
		_set_turn_flag(next_state, flag_key, true)
		next_state["card_play_bonus_this_turn"] = int(next_state.get("card_play_bonus_this_turn", 0)) + int(effect.get("value", 1))
	return next_state

func _trigger_stoneskin_relics(state: Dictionary, gained: int) -> Dictionary:
	var next_state: Dictionary = state
	if gained <= 0:
		return next_state
	for effect: Dictionary in _relic_effects(next_state):
		if str(effect.get("type", "")) != "stoneskin_thorns":
			continue
		next_state = _damage_adjacent_enemies_from_player(next_state, GameData.fixed_point_amount(int(effect.get("value", 0))))
	return next_state

func _trigger_status_relics(state: Dictionary, status_id: String) -> Dictionary:
	var next_state: Dictionary = state
	for effect: Dictionary in _relic_effects(next_state):
		if str(effect.get("status", "")) != status_id:
			continue
		match str(effect.get("type", "")):
			"first_status_card_play":
				var flag_key: String = _combat_relic_flag_key(effect, "first_status_card_play")
				if _combat_relic_flag(next_state, flag_key):
					continue
				_set_combat_relic_flag(next_state, flag_key, true)
				next_state["card_play_bonus_this_turn"] = int(next_state.get("card_play_bonus_this_turn", 0)) + int(effect.get("value", 1))
			"status_draw_once_per_turn":
				var turn_key: String = _turn_relic_flag_key(effect, "status_draw")
				if _turn_flag(next_state, turn_key):
					continue
				_set_turn_flag(next_state, turn_key, true)
				next_state = _draw_cards_in_place(next_state, int(effect.get("value", 1)))
			"status_intensity_gain":
				var intensity_key: String = _turn_relic_flag_key(effect, "status_intensity")
				if _turn_flag(next_state, intensity_key):
					continue
				_set_turn_flag(next_state, intensity_key, true)
				next_state = _gain_elemental_intensity(next_state, str(effect.get("element", ElementData.NONE)), int(effect.get("amount", effect.get("value", 1))), _relic_effect_source_name(effect))
	return next_state

func _trigger_intensity_threshold_relics(state: Dictionary, element_id: String, before_value: int, after_value: int) -> Dictionary:
	var next_state: Dictionary = state
	if not ElementData.is_elemental(element_id) or after_value <= before_value:
		return next_state
	for effect: Dictionary in _relic_effects(next_state):
		if str(effect.get("type", "")) != "intensity_threshold_reward":
			continue
		if not _relic_effect_matches_intensity_element(effect, element_id):
			continue
		var threshold: int = int(effect.get("threshold", effect.get("amount", 0)))
		if threshold <= 0 or before_value >= threshold or after_value < threshold:
			continue
		if not _relic_once_available(next_state, effect, "intensity_threshold", element_id):
			continue
		_mark_relic_once(next_state, effect, "intensity_threshold", element_id)
		next_state = _apply_relic_rewards(next_state, effect.get("rewards", []), effect)
		next_state = _consume_elemental_intensity(next_state, element_id, int(effect.get("consume", 0)))
	return next_state

func _trigger_enemy_death_relics(state: Dictionary, enemy: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	for effect: Dictionary in _relic_effects(next_state):
		match str(effect.get("type", "")):
			"kill_status_heal":
				var status_id: String = str(effect.get("status", ""))
				if _unit_status_amount(enemy, status_id) <= 0:
					continue
				next_state = _heal_player(next_state, GameData.fixed_point_amount(int(effect.get("value", 0))))
	return next_state

func _trigger_prevent_lethal_relics(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	for effect: Dictionary in _relic_effects(next_state):
		if str(effect.get("type", "")) != "prevent_lethal_once":
			continue
		var flag_key: String = _combat_relic_flag_key(effect, "prevent_lethal_once")
		if _combat_relic_flag(next_state, flag_key):
			continue
		_set_combat_relic_flag(next_state, flag_key, true)
		var player: Dictionary = _normalized_player(next_state.get("player", {}))
		player["hp"] = GameData.FIXED_POINT_SCALE
		next_state["player"] = player
		var burn_amount: int = GameData.fixed_point_amount(int(effect.get("burn_all_enemies", 0)))
		if burn_amount > 0:
			next_state = _burn_all_live_enemies(next_state, burn_amount)
		_log(next_state, "%s prevents death." % _relic_effect_source_name(effect))
		return next_state
	return next_state

func _scaled_relic_reward_amount(reward: Dictionary) -> int:
	var amount: int = int(reward.get("amount", reward.get("value", 0)))
	match str(reward.get("type", "")):
		"block", "stoneskin", "heal", "all_enemies_damage":
			return GameData.fixed_point_amount(amount)
		"all_enemies_status":
			var status_id: String = str(reward.get("status", ""))
			return GameData.fixed_point_amount(amount) if status_id in ["burn", "poison"] else amount
		_:
			return amount

func _apply_relic_rewards(state: Dictionary, raw_rewards: Variant, effect: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var rewards: Array = []
	if typeof(raw_rewards) == TYPE_ARRAY:
		rewards = (raw_rewards as Array).duplicate(true)
	elif typeof(raw_rewards) == TYPE_DICTIONARY:
		rewards = [raw_rewards]
	for reward_var: Variant in rewards:
		if typeof(reward_var) != TYPE_DICTIONARY:
			continue
		var reward: Dictionary = reward_var as Dictionary
		var amount: int = _scaled_relic_reward_amount(reward)
		match str(reward.get("type", "")):
			"draw":
				next_state = _draw_cards_in_place(next_state, amount)
			"card_play":
				if amount > 0:
					next_state["card_play_bonus_this_turn"] = int(next_state.get("card_play_bonus_this_turn", 0)) + amount
			"block":
				var block_player: Dictionary = _normalized_player(next_state.get("player", {}))
				block_player["block"] = int(block_player.get("block", 0)) + maxi(0, amount)
				next_state["player"] = block_player
			"stoneskin":
				var stoneskin_player: Dictionary = _normalized_player(next_state.get("player", {}))
				var stoneskin_before: int = int(stoneskin_player.get("stoneskin", 0))
				stoneskin_player["stoneskin"] = int(stoneskin_player.get("stoneskin", 0)) + maxi(0, amount)
				next_state["player"] = stoneskin_player
				next_state = _trigger_stoneskin_relics(next_state, int(stoneskin_player.get("stoneskin", 0)) - stoneskin_before)
			"heal":
				next_state = _heal_player(next_state, amount)
			"all_enemies_status":
				next_state = _apply_status_to_all_live_enemies(next_state, str(reward.get("status", "")), amount)
			"all_enemies_damage":
				next_state = _damage_all_live_enemies(next_state, amount)
	if not rewards.is_empty():
		_log(next_state, "%s triggers." % _relic_effect_source_name(effect))
	return next_state

func _apply_status_to_all_live_enemies(state: Dictionary, status_id: String, amount: int) -> Dictionary:
	var next_state: Dictionary = state
	if amount <= 0 or status_id.is_empty():
		return next_state
	var enemies: Array = next_state.get("enemies", []).duplicate(true)
	for index: int in range(enemies.size()):
		if typeof(enemies[index]) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = _normalized_enemy(enemies[index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			continue
		match status_id:
			"burn":
				enemy["burn"] = int(enemy.get("burn", 0)) + amount
			"freeze":
				enemy["freeze"] = maxi(int(enemy.get("freeze", 0)), amount)
			"shock":
				if not _enemy_is_immune_to_status(enemy, "shock"):
					enemy["shock"] = maxi(int(enemy.get("shock", 0)), amount)
			"poison":
				var poison: Dictionary = enemy.get("poison", {}).duplicate(true)
				poison["damage"] = int(poison.get("damage", 0)) + amount
				poison["delay"] = 2
				enemy["poison"] = poison
			_:
				continue
		enemies[index] = enemy
	next_state["enemies"] = enemies
	return next_state

func _damage_all_live_enemies(state: Dictionary, amount: int) -> Dictionary:
	var next_state: Dictionary = state
	if amount <= 0:
		return next_state
	var enemies: Array = next_state.get("enemies", [])
	for index: int in range(enemies.size()):
		var current_enemies: Array = next_state.get("enemies", [])
		if index < 0 or index >= current_enemies.size() or typeof(current_enemies[index]) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = _normalized_enemy(current_enemies[index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			continue
		next_state = _damage_enemy(next_state, index, amount)
	return next_state

func _damage_adjacent_enemies_from_player(state: Dictionary, amount: int) -> Dictionary:
	var next_state: Dictionary = state
	if amount <= 0:
		return next_state
	var player_pos: Vector2i = (_normalized_player(next_state.get("player", {}))).get("pos", Vector2i.ZERO)
	var enemies: Array = next_state.get("enemies", [])
	for index: int in range(enemies.size()):
		var enemy: Dictionary = _normalized_enemy(enemies[index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			continue
		if _enemy_distance_to_tile(enemy, player_pos) > 1:
			continue
		next_state = _damage_enemy(next_state, index, amount)
	return next_state

func _burn_all_live_enemies(state: Dictionary, amount: int) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", []).duplicate(true)
	for index: int in range(enemies.size()):
		if typeof(enemies[index]) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = _normalized_enemy(enemies[index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			continue
		enemy["burn"] = int(enemy.get("burn", 0)) + amount
		enemies[index] = enemy
	next_state["enemies"] = enemies
	return next_state

func _heal_player(state: Dictionary, amount: int) -> Dictionary:
	var next_state: Dictionary = state
	if amount <= 0:
		return next_state
	var player: Dictionary = _normalized_player(next_state.get("player", {}))
	player["hp"] = mini(int(player.get("max_hp", 1)), int(player.get("hp", 0)) + amount)
	next_state["player"] = player
	return next_state

func _start_combat_intensity_effect_applies(effect: Dictionary, deck_cards: Array) -> bool:
	var deck_element: String = str(effect.get("deck_element", ""))
	if not ElementData.is_elemental(deck_element):
		return true
	var count: int = 0
	for card_id_var: Variant in deck_cards:
		if GameData.card_element(str(card_id_var)) == deck_element:
			count += 1
	return count >= int(effect.get("threshold", 1))

func _relic_effect_matches_intensity_element(effect: Dictionary, element_id: String) -> bool:
	var effect_element: String = str(effect.get("element", "any"))
	return effect_element.is_empty() or effect_element == "any" or effect_element == element_id

func _relic_once_available(state: Dictionary, effect: Dictionary, suffix: String, element_id: String) -> bool:
	var once: String = str(effect.get("once", ""))
	if once.is_empty():
		return true
	var include_element: bool = once.ends_with("_per_element")
	var key: String = _relic_once_key(effect, suffix, element_id, include_element)
	if once.begins_with("turn"):
		return not _turn_flag(state, key)
	if once.begins_with("combat"):
		return not _combat_relic_flag(state, key)
	return true

func _mark_relic_once(state: Dictionary, effect: Dictionary, suffix: String, element_id: String) -> void:
	var once: String = str(effect.get("once", ""))
	if once.is_empty():
		return
	var include_element: bool = once.ends_with("_per_element")
	var key: String = _relic_once_key(effect, suffix, element_id, include_element)
	if once.begins_with("turn"):
		_set_turn_flag(state, key, true)
	elif once.begins_with("combat"):
		_set_combat_relic_flag(state, key, true)

func _relic_once_key(effect: Dictionary, suffix: String, element_id: String, include_element: bool) -> String:
	var key: String = "%s:%s:%s:%d" % [
		str(effect.get("relic_id", "")),
		str(effect.get("status", "")),
		suffix,
		int(effect.get("threshold", effect.get("amount", 0)))
	]
	if include_element:
		key = "%s:%s" % [key, element_id]
	return key

func _relic_effects(state: Dictionary) -> Array[Dictionary]:
	return GameData.relic_effects_for_ids(state.get("relics", []))

func _relic_effect_source_name(effect: Dictionary) -> String:
	var relic_id: String = str(effect.get("relic_id", ""))
	return str(GameData.relic_def(relic_id).get("name", relic_id))

func _unit_status_amount(unit: Dictionary, status_id: String) -> int:
	if status_id == "poison":
		return int((unit.get("poison", {}) as Dictionary).get("damage", 0))
	return int(unit.get(status_id, 0))

func _combat_relic_flag_key(effect: Dictionary, suffix: String) -> String:
	return "%s:%s:%s" % [str(effect.get("relic_id", "")), str(effect.get("status", "")), suffix]

func _turn_relic_flag_key(effect: Dictionary, suffix: String) -> String:
	return "%s:%s:%s" % [str(effect.get("relic_id", "")), str(effect.get("status", "")), suffix]

func _combat_relic_flag(state: Dictionary, key: String) -> bool:
	return bool((state.get("relic_flags", {}) as Dictionary).get(key, false))

func _set_combat_relic_flag(state: Dictionary, key: String, value: bool) -> void:
	var flags: Dictionary = state.get("relic_flags", {}).duplicate(true)
	flags[key] = value
	state["relic_flags"] = flags

func _turn_flag(state: Dictionary, key: String) -> bool:
	return bool((state.get("turn_flags", {}) as Dictionary).get(key, false))

func _set_turn_flag(state: Dictionary, key: String, value: bool) -> void:
	var flags: Dictionary = state.get("turn_flags", {}).duplicate(true)
	flags[key] = value
	state["turn_flags"] = flags

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
	while log_lines.size() > MAX_LOG_LINES:
		log_lines.remove_at(0)
	state["log"] = log_lines

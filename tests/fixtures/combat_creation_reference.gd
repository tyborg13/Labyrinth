extends "res://scripts/combat_engine.gd"
const OriginalDragonCombatRules = preload("res://tests/fixtures/dragon_combat_rules_reference.gd")
const OriginalGuardianCombatRules = preload("res://tests/fixtures/guardian_combat_rules_reference.gd")

# Frozen complete combat factory before owned cooperative creation.

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
	var enemies: Array[Dictionary]
	for enemy_var: Variant in room_layout.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		enemies.append(_normalized_enemy(enemy_var as Dictionary))
	var state: Dictionary = {
		"room_name": str(room_layout.get("name", "Room")),
		"room_coord": room_layout.get("coord", Vector2i.ZERO),
		"room_depth": int(room_layout.get("depth", 1)),
		"room_type": str(room_layout.get("type", "combat")),
		"boss_id": str(room_layout.get("boss_id", "")),
		"guardian_id": str(room_layout.get("guardian_id", "")),
		"guardian_braziers": room_layout.get("guardian_braziers", []).duplicate(true),
		"objective": (room_layout.get("objective", {}) as Dictionary).duplicate(true),
		"room_element": str(room_layout.get("element", ElementData.NONE)),
		"grid": room_layout.get("grid", []).duplicate(true),
		"surfaces": room_layout.get("surfaces", {}).duplicate(true),
		"surface_revision": 0,
		"surface_events": [],
		"balance_revision": GameData.BALANCE_REVISION,
		"rules_version": BoardSurfaceRules.RULES_VERSION,
		"moss": room_layout.get("moss", {}).duplicate(true),
		"player": player,
		"enemies": enemies,
		"illusions": [],
		"next_illusion_id": 1,
		"traps": room_layout.get("traps", []).duplicate(true),
		"loot": BattlefieldItemRules.normalized_loot(room_layout.get("loot", [])),
		"equipped_items": player_snapshot.get("equipped_items", BattlefieldItemRules.active_items_from_deck({"draw": deck_cards})).duplicate(),
		"item_inventory": player_snapshot.get("item_inventory", []).duplicate(),
		"terrain": room_layout.get("terrain", []).duplicate(true),
		"umbra": _initial_umbra_state(room_layout),
		"relics": relic_ids,
		"equipped_equipment": (player_snapshot.get("equipped_equipment", {}) as Dictionary).duplicate(true),
		"equipment_grafts": (player_snapshot.get("equipment_grafts", {}) as Dictionary).duplicate(true),
		"skill_ids": SkillTreeLibrary.normalized_ids(player_snapshot.get("skill_ids", [])),
		"skill_flags": {},
		"skill_events": [],
		"defiance_capacity": maxi(0, int(player_snapshot.get("defiance_capacity", 0))),
		"defiance_remaining": clampi(
			int(player_snapshot.get("defiance_remaining", 0)),
			0,
			maxi(0, int(player_snapshot.get("defiance_capacity", 0)))
		),
		"defiance_events": [],
		"defiance_event_revision": 0,
		"banked_plays": 0,
		"banked_play_active": 0,
		"banked_play_spent_this_activation": 0,
		"level": int(player_snapshot.get("level", 1)),
		"hand_size": int(player_snapshot.get("hand_size", 5)) + GameData.stat_bonus_from_relics(relic_ids, "hand_size_bonus"),
		"cards_per_turn": int(player_snapshot.get("cards_per_turn", BASE_CARDS_PER_TURN)) + GameData.stat_bonus_from_relics(relic_ids, "cards_per_turn_bonus"),
		"draw_per_turn": int(player_snapshot.get("draw_per_turn", BASE_DRAW_PER_TURN)) + GameData.stat_bonus_from_relics(relic_ids, "draw_per_turn_bonus"),
		"cards_played_this_turn": 0,
		"player_movement_capacity": BASE_PLAYER_MOVEMENT + GameData.stat_bonus_from_relics(relic_ids, "movement_pool_bonus"),
		"player_movement_remaining": BASE_PLAYER_MOVEMENT + GameData.stat_bonus_from_relics(relic_ids, "movement_pool_bonus"),
		"death_bonus_card_plays_this_turn": 0,
		"card_play_bonus_this_turn": 0,
		"pending_relic_card_plays": 0,
		"player_turn_ending": false,
		"heal_bonus": int(player_snapshot.get("heal_bonus", 0)),
		"deck": {
			"draw": draw_pile,
			"hand": [],
			"discard": [],
			"burned": [],
			"consumed": [],
			"draw_revision": 0,
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
		"turn_flags": {
			"first_attack_bonus_used": false,
			"first_move_bonus_used": false
		},
		"relic_flags": {},
		"zekarion_summon_waves": 0,
		"run_stats": normalized_run_stats(player_snapshot.get("run_stats", {})),
		"death_rewards": [],
		"room_embers": 0,
		"recovered_embers_total": 0,
		"rng_state": rng.state,
		"log": []
	}
	SurfaceRelicRules.configure(state)
	state = _apply_start_combat_relic_effects(state, player_snapshot)
	state = CommonRelicRules.start_combat(self, state)
	for enemy_index: int in range((state.get("enemies", []) as Array).size()):
		_assign_enemy_intent(state, enemy_index, rng)
	state["rng_state"] = rng.state
	state = _initialize_initiative_queue(state)
	ManeuverRules.record_activation_start(state)
	state = _draw_cards_in_place(state, maxi(0, int(state.get("hand_size", 5)) + GameData.stat_bonus_from_relics(state.get("relics", []), "opening_draw_bonus")))
	state = DefenseRelicRules.opening_hand(self, state)
	_log(state, "Entered %s." % state.get("room_name", "a room"))
	return state


func _assign_enemy_intent(state: Dictionary, enemy_index: int, rng: RandomNumberGenerator) -> void:
	var enemies: Array = state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var enemy_type: String = str(enemy.get("type", ""))
	var definition: Dictionary = GameData.enemy_def(enemy_type)
	if not bool(definition.get("dragon_cycle",false)) and _enemy_should_summon_wisps(state, enemy):
		enemy["intent"] = _surface_prepare_enemy_intent(state, enemy, _zekarion_summon_intent())
		enemies[enemy_index] = enemy
		return
	var intents: Array = _scaled_enemy_intents(
		definition.get("intents", []),
		int(state.get("room_depth", 1))
	)
	if bool(definition.get("dragon_cycle", false)) and not intents.is_empty():
		enemies[enemy_index] = enemy
		enemy["intent"] = OriginalDragonCombatRules.declare(self, state, enemy_index, intents)
		enemies[enemy_index] = enemy
		return
	if bool(definition.get("intent_cycle", false)) and not intents.is_empty():
		OriginalGuardianCombatRules.cleanup(state, enemy)
		var cycle: int = int(enemy.get("guardian_cycle", -1)) + 1
		enemy["guardian_cycle"] = cycle
		enemies[enemy_index] = enemy
		var chosen: Dictionary = _surface_prepare_enemy_intent(state, enemy, OriginalGuardianCombatRules.choose_intent(state, enemy, intents, cycle))
		chosen = OriginalGuardianCombatRules.with_reinforcements(state, enemy, chosen)
		enemy["intent"] = OriginalGuardianCombatRules.commit(self, state, enemy_index, chosen)
		enemies[enemy_index] = enemy
		return
	if enemy_type == DragonBossLibrary.FIRE_BOSS_ID and bool(enemy.get("cinder_detonation_pending", false)) and _cinder_fire_entries(state, int(enemy.get("id", -1))).is_empty():
		enemy["cinder_detonation_pending"] = false
		enemies[enemy_index] = enemy
		state["enemies"] = enemies
	var forced_intent: Dictionary = _forced_dragon_intent(state, enemy, intents)
	if not forced_intent.is_empty():
		enemy["intent"] = _surface_prepare_enemy_intent(state, enemy, forced_intent)
		enemies[enemy_index] = enemy
		return
	var available_intents: Array = []
	for intent_var: Variant in intents:
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		var intent: Dictionary = intent_var as Dictionary
		if _dragon_intent_available(state, enemy, intent):
			available_intents.append(intent)
	intents = available_intents
	if intents.is_empty():
		return
	var tactical_options: Array[Dictionary] = _enemy_tactical_intent_options(
		state,
		enemy_index,
		enemy,
		definition,
		intents
	)
	if not tactical_options.is_empty():
		var tactical_total_weight: int = 0
		for option: Dictionary in tactical_options:
			tactical_total_weight += int(option.get("effective_weight", 0))
		if tactical_total_weight > 0:
			var tactical_roll: int = rng.randi_range(1, tactical_total_weight)
			var tactical_cursor: int = 0
			for option: Dictionary in tactical_options:
				tactical_cursor += int(option.get("effective_weight", 0))
				if tactical_roll <= tactical_cursor:
					enemy["intent"] = _surface_prepare_enemy_intent(state, enemy, (option.get("intent", {}) as Dictionary).duplicate(true))
					enemies[enemy_index] = enemy
					return
	var total_weight: int = 0
	for intent: Dictionary in intents:
		total_weight += _objective_adjusted_intent_weight(state, intent)
	var roll: int = rng.randi_range(1, total_weight)
	var cursor: int = 0
	for intent: Dictionary in intents:
		cursor += _objective_adjusted_intent_weight(state, intent)
		if roll <= cursor:
			enemy["intent"] = _surface_prepare_enemy_intent(state, enemy, intent.duplicate(true))
			enemies[enemy_index] = enemy
			return
	enemy["intent"] = _surface_prepare_enemy_intent(state, enemy, (intents[0] as Dictionary).duplicate(true))
	enemies[enemy_index] = enemy


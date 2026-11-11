extends RefCounted
## Shared read-only snapshots for UI and manual headless JSONL emitters.
const DemoBuild = preload("res://scripts/demo_build.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngineScript = preload("res://scripts/run_engine.gd")
const BoardSurfaceRules = preload("res://scripts/board_surface_rules.gd")
const CombatObjectiveRules = preload("res://scripts/combat_objective_rules.gd")
const INVALID_TARGET_TILE := Vector2i(-1, -1)
const INVALID_ROOM_COORD := Vector2i(999, 999)

static func stage_run_ended(engine: RefCounted, state: Dictionary, outcome: String, context_fields: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	next["progression"] = ProgressionStore.queue_progression_analytics_event(
		next.get("progression", {}) as Dictionary, "run_ended",
		"run_ended|%s|%s" % [RunEngineScript.run_result_id(next), outcome],
		context_fields, run_ended(engine, next, outcome)
	)
	return next

static func context(_combat_engine: RefCounted, _run_engine: RefCounted, _progression: Dictionary, run_state: Dictionary, combat_state: Dictionary = {}, card_id: String = "", card_instance_id: String = "") -> Dictionary:
	var room_meta: Dictionary = {}
	if not run_state.is_empty():
		room_meta = _run_engine.room_metadata(run_state, run_state.get("current_room", Vector2i.ZERO))
	var player: Dictionary = (combat_state.get("player", {}) as Dictionary) if not combat_state.is_empty() else {}
	var combat_analytics: Dictionary = combat_state.get("analytics", {}) as Dictionary
	var run_analytics: Dictionary = run_state.get("analytics", {}) as Dictionary
	var progression: Dictionary = run_state.get("progression", _progression) as Dictionary
	var context: Dictionary = {
		"balance_transition": (combat_state.get("balance_transition", {}) as Dictionary).duplicate(true),
		"run_id": str(run_analytics.get("run_id", "")),
		"depth": int(run_state.get("umbra_depth", 0)),
		"combat_id": str(combat_analytics.get("combat_id", "")),
		"turn": int(combat_state.get("turn", 0)),
		"initiative_clock": int(combat_state.get("initiative_clock", 0)),
		"current_actor_kind": str((combat_state.get("current_actor", {}) as Dictionary).get("kind", "")),
		"current_actor_key": str((combat_state.get("current_actor", {}) as Dictionary).get("actor_key", "")),
		"room_depth": int(combat_state.get("room_depth", room_meta.get("depth", 0))),
		"room_element": str(combat_state.get("room_element", room_meta.get("element", ""))),
		"room_type": str(combat_state.get("room_type", room_meta.get("type", ""))),
		"guardian_id": str(combat_state.get("guardian_id", room_meta.get("guardian_id", ""))),
		"boss_id": str(combat_state.get("boss_id", room_meta.get("boss_id", ""))),
		"player_hp": int(player.get("hp", run_state.get("player_hp", -1))),
		"player_max_hp": int(player.get("max_hp", run_state.get("player_max_hp", -1))),
		"defiance_capacity": int(combat_state.get(
			RunEngineScript.DEFIANCE_CAPACITY_KEY,
			run_state.get(RunEngineScript.DEFIANCE_CAPACITY_KEY, 0)
		)),
		"defiance_remaining": int(combat_state.get(
			RunEngineScript.DEFIANCE_REMAINING_KEY,
			run_state.get(RunEngineScript.DEFIANCE_REMAINING_KEY, 0)
		)),
		"combat_unit_scale": 1,
		"rules_version": BoardSurfaceRules.RULES_VERSION,
		"surface_revision": int(combat_state.get("surface_event_sequence", 0)),
		"progression_level": int(progression.get("level", 1)),
		"progression_skills": ProgressionStore.selected_skill_ids(progression),
		"relics": (combat_state.get("relics", run_state.get("relics", [])) as Array).duplicate(true),
		"moltshards": ProgressionStore.moltshard_count(progression),
		"deck_size": int((run_state.get("deck_cards", []) as Array).size()),
		"card_id": card_id,
		"card_instance_id": card_instance_id
	}
	if not combat_state.is_empty():
		var objective: Dictionary = combat_state.get("objective", {}) as Dictionary
		context["umbra_stage"] = _combat_engine.effective_umbra_stage(combat_state)
		context["umbra_radius"] = _combat_engine.effective_umbra_radius(combat_state)
		context["visible_enemy_count"] = _combat_engine.visible_enemy_ids(combat_state).size()
		context["objective_type"] = str(objective.get("type", CombatObjectiveRules.KILL_ALL))
		context["objective_name"] = CombatObjectiveRules.title_for_objective(objective)
	context.merge(preload("res://scripts/encounter_analytics_context.gd").fields(run_state, combat_state, room_meta), true)
	return context


static func recovery_marker_amount(combat_state: Dictionary) -> int:
	for loot_var: Variant in combat_state.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = loot_var
		if bool(loot.get("claimed", false)):
			continue
		if str(loot.get("kind", "")) == "dropped_embers":
			return maxi(0, int(loot.get("amount", 0)))
	return 0

static func equipment_loot_ids(combat_state: Dictionary) -> Array:
	var ids: Array = []
	for loot_var: Variant in combat_state.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = loot_var
		if bool(loot.get("claimed", false)) or str(loot.get("kind", "")) != "equipment":
			continue
		var equipment_id: String = str(loot.get("equipment_id", ""))
		if not equipment_id.is_empty():
			ids.append(equipment_id)
	return ids


static func run_started(_run_state: Dictionary, _progression: Dictionary) -> Dictionary:
	var recovery_marker: Dictionary = ProgressionStore.recovery_marker(_progression)
	return {
		"seed": int(_run_state.get("seed", 0)),
		"build_kind": "demo" if DemoBuild.is_demo() else "full",
		"depth": int(_run_state.get("umbra_depth", 0)),
		"run_index": int(_run_state.get("run_index", 0)),
		"player_start_hp": int(_run_state.get("player_hp", 0)),
		"player_max_hp": int(_run_state.get("player_max_hp", 0)),
		"starting_deck": (_run_state.get("deck_cards", []) as Array).duplicate(true),
		"reward_cards": (_run_state.get("reward_cards", []) as Array).duplicate(true),
		"attuned_magic_cards": (_run_state.get("attuned_magic_cards", []) as Array).duplicate(true),
		"magic_inventory": (_run_state.get("magic_inventory", []) as Array).duplicate(true),
		"equipped_items": (_run_state.get("equipped_items", []) as Array).duplicate(true),
		"item_inventory": (_run_state.get("item_inventory", []) as Array).duplicate(true),
		"equipped_equipment": (_run_state.get("equipped_equipment", {}) as Dictionary).duplicate(true),
		"equipment_inventory": (_run_state.get("equipment_inventory", []) as Array).duplicate(true),
		"equipment_grafts": (_run_state.get("equipment_grafts", {}) as Dictionary).duplicate(true),
		"collected_equipment": (_run_state.get("collected_equipment", []) as Array).duplicate(true),
		"recovery_marker_active": not recovery_marker.is_empty(),
		"recovery_marker_amount": int(recovery_marker.get("amount", 0)),
		"recovery_marker_coord": ProgressionStore.recovery_coord(_progression) if not recovery_marker.is_empty() else Vector2i(-999, -999)
	}

static func run_ended(_run_engine: RefCounted, _run_state: Dictionary, outcome: String) -> Dictionary:
	var run_stats: Dictionary = RunEngineScript.normalized_run_stats(_run_state.get("run_stats", {}))
	return {
		"outcome": outcome,
		"build_kind": "demo" if DemoBuild.is_demo() else "full",
		"depth": int(_run_state.get("umbra_depth", 0)),
		"turns_spent": int(_run_state.get("turns_spent", 0)),
		"held_embers": _run_engine.held_embers(_run_state),
		"mode": str(_run_state.get("mode", "room")),
		"enemies_killed": int(run_stats.get("enemies_killed", 0)),
		"damage_dealt": int(run_stats.get("damage_dealt", 0)),
		"damage_received": int(run_stats.get("damage_received", 0))
	}

static func combat_started(_combat_engine: RefCounted, _run_engine: RefCounted, _run_state: Dictionary, _combat_state: Dictionary, reason: String) -> Dictionary:
	var encounter_room: Dictionary = _run_engine.room_metadata(_run_state, _combat_state.get("room_coord", Vector2i.ZERO))
	var objective: Dictionary = _combat_state.get("objective", {}) as Dictionary
	return {
		"reason": reason,
		"surface_rules_version": BoardSurfaceRules.RULES_VERSION,
		"surfaces": (_combat_state.get("surfaces", {}) as Dictionary).duplicate(true),
		"encounter_id": str(encounter_room.get("encounter_id", "")),
		"fight_number": int(encounter_room.get("fight_number", 0)),
		"encounter_tier": int(encounter_room.get("encounter_tier", 0)),
		"biome": str(encounter_room.get("biome", "")),
		"room_name": str(_combat_state.get("room_name", "")),
		"room_type": str(_combat_state.get("room_type", "")),
		"room_coord": _combat_state.get("room_coord", Vector2i.ZERO),
		"recovery_marker_present": recovery_marker_amount(_combat_state) > 0,
		"recovery_marker_amount": recovery_marker_amount(_combat_state),
		"umbra_stage": _combat_engine.effective_umbra_stage(_combat_state),
		"umbra_radius": _combat_engine.effective_umbra_radius(_combat_state),
		"visible_enemy_count": _combat_engine.visible_enemy_ids(_combat_state).size(),
		"objective_type": str(objective.get("type", CombatObjectiveRules.KILL_ALL)),
		"objective_target_clock": int(objective.get("target_clock", 0)),
		"objective_leader_type": str(objective.get("leader_type", "")),
		"objective_exit_count": (objective.get("exits", []) as Array).size(),
		"objective_initial_enemy_count": int(objective.get("initial_enemy_count", (_combat_state.get("enemies", []) as Array).size())),
		"deck_cards": (_run_state.get("deck_cards", []) as Array).duplicate(true),
		"reward_cards": (_run_state.get("reward_cards", []) as Array).duplicate(true),
			"attuned_magic_cards": (_run_state.get("attuned_magic_cards", []) as Array).duplicate(true),
			"magic_inventory": (_run_state.get("magic_inventory", []) as Array).duplicate(true),
			"equipped_items": (_run_state.get("equipped_items", []) as Array).duplicate(true),
			"item_inventory": (_run_state.get("item_inventory", []) as Array).duplicate(true),
			"equipped_equipment": (_run_state.get("equipped_equipment", {}) as Dictionary).duplicate(true),
		"equipment_inventory": (_run_state.get("equipment_inventory", []) as Array).duplicate(true),
		"equipment_grafts": (_run_state.get("equipment_grafts", {}) as Dictionary).duplicate(true),
		"equipment_drops": equipment_loot_ids(_combat_state),
		"opening_hand": ((_combat_state.get("deck", {}) as Dictionary).get("hand", []) as Array).duplicate(true)
	}

static func combat_ended(_combat_engine: RefCounted, combat_state: Dictionary, reason: String) -> Dictionary:
	var objective: Dictionary = combat_state.get("objective", {}) as Dictionary
	var objective_completion_tile: Vector2i = (
		(combat_state.get("player", {}) as Dictionary).get("pos", INVALID_TARGET_TILE)
		if str(objective.get("type", "")) == CombatObjectiveRules.REACH_EXIT
		else INVALID_TARGET_TILE
	)
	var objective_completion_exit: Dictionary = CombatObjectiveRules.exit_spec_for_target(objective, objective_completion_tile)
	return {
		"reason": reason,
		"outcome": _combat_engine.combat_outcome(combat_state),
		"turn": int(combat_state.get("turn", 0)),
		"initiative_clock": int(combat_state.get("initiative_clock", 0)),
		"objective_type": str(objective.get("type", CombatObjectiveRules.KILL_ALL)),
		"objective_target_clock": int(objective.get("target_clock", 0)),
		"doors_open_at_escape": int(_combat_engine.snare_escape_context(combat_state).get("doors_open_at_escape", 0)),
		"sealbinders_killed": int(_combat_engine.snare_escape_context(combat_state).get("sealbinders_killed", 0)),
		"snare_pressure": _combat_engine.SnareRules.Pressure.id(combat_state),
		"braziers_lit_at_dawn": int(_combat_engine.last_light_context(combat_state).get("braziers_lit_at_dawn", 0)),
		"brazier_snuffs": int(_combat_engine.last_light_context(combat_state).get("brazier_snuffs", 0)),
		"objective_reinforcement_waves": int(objective.get("reinforcement_waves_spawned", 0)),
		"objective_followers_cleared": int(objective.get("followers_cleared", 0)),
		"objective_completed_by_leader": bool(objective.get("completed_by_leader", false)),
		"hoarder_result": str(preload("res://scripts/hoarder_room_rules.gd").analytics(combat_state)["hoarder_result"]),
		"hoarder_caught_turn": int(preload("res://scripts/hoarder_room_rules.gd").analytics(combat_state)["hoarder_caught_turn"]),
		"objective_completion_tile": objective_completion_tile,
		"objective_completion_door": objective_completion_exit.get("door_tile", INVALID_TARGET_TILE),
		"objective_completion_destination": objective_completion_exit.get("coord", INVALID_ROOM_COORD),
		"room_embers": int(combat_state.get("room_embers", 0)),
		"recovered_embers": int(combat_state.get("recovered_embers_total", 0)),
		"collected_equipment": (combat_state.get("collected_equipment", []) as Array).duplicate(true),
		"missed_equipment": (combat_state.get("missed_equipment", []) as Array).duplicate(true),
		"remaining_player_hp": int((combat_state.get("player", {}) as Dictionary).get("hp", 0)),
		"umbra_tiles_illuminated": int((combat_state.get("umbra", {}) as Dictionary).get("tiles_illuminated_total", 0)),
		"umbra_enemies_revealed": int((combat_state.get("umbra", {}) as Dictionary).get("enemies_revealed_total", 0)),
		"umbra_movement_interruptions": int((combat_state.get("umbra", {}) as Dictionary).get("movement_interrupted_total", 0)),
		"umbra_hidden_attack_damage_received": int((combat_state.get("umbra", {}) as Dictionary).get("hidden_attack_damage_received_total", 0))
	}

static func reward_offered(_run_engine: RefCounted, _run_state: Dictionary, reason: String) -> Dictionary:
	var reward_state: Dictionary = (_run_state.get("pending_reward", {}) as Dictionary).duplicate(true)
	return {
		"reason": reason,
		"reward_kind": "dragon_milestone" if _run_engine.is_dragon_reward(_run_state) else ("guardian_trophy" if not (_run_state.get("guardian_reward", {}) as Dictionary).is_empty() else "combat"),
		"boss_id": reward_state.get("boss_id", ""),
		"milestone_id": reward_state.get("milestone_id", ""),
		"awarded_relic": reward_state.get("relic_id", ""),
		"next_descent": bool(reward_state.get("next_descent", false)),
		"moltshards": int(reward_state.get("moltshards", 0)),
		"healed_amount": int(reward_state.get("healed_amount", 0)),
		"offered_relics": (_run_state.get("pending_relics", []) as Array).duplicate(),
		"offered_cards": (reward_state.get("cards", []) as Array).duplicate(true),
		"heal_amount": int(reward_state.get("heal_amount", 0)),
		"ember_amount": int(reward_state.get("ember_amount", 0))
	}

static func reward_choice(choice_kind: String, reward_state: Dictionary, selected_card_id: String, player_hp_before: int, player_hp_after: int) -> Dictionary:
	return {
		"reward_kind": str(reward_state.get("kind", "combat")),
		"event_id": str(reward_state.get("event_id", "")),
		"choice_kind": choice_kind,
		"selected_card_id": selected_card_id,
		"destination": "deck" if choice_kind == "card" else "",
		"offered_cards": (reward_state.get("cards", []) as Array).duplicate(true),
		"heal_amount": int(reward_state.get("heal_amount", 0)),
		"ember_amount": int(reward_state.get("ember_amount", 0)),
		"player_hp_before": player_hp_before,
		"player_hp_after": player_hp_after
	}


extends RefCounted

# Approved explanation for the shared forecast safety ceiling.
const FORECAST_LIMIT_WARNING: String = "Too many moves ahead to forecast them all."

# Forecast only: use the production turn-start order, including Block expiry,
# surfaces, Meteorfall, draw/Fatigue, survival skills and Defiance. No live state,
# analytics or saves are touched. Compact receipts feed the existing PASS sum.
static func complete(engine: RefCounted, cursor: Dictionary) -> void:
	var started: int = Time.get_ticks_usec() if engine._runtime_performance_instrumentation_enabled else 0
	var before: Dictionary = cursor["player_turn_before_state"]
	var after: Dictionary
	if _can_project_draw_only(engine, cursor):
		# This is a compact loss result, never a state to commit or animate.
		# No start hook in this guarded subset can change durability except
		# Block expiry and draw/Fatigue. Use the actual draw resolver so lethal
		# loss, gross damage, deck cycles and Defiance retain one source of truth.
		after = cursor["state"]
		after["player"]["block"] = 0
		after["turn"] = int(after.get("turn", 1)) + 1
		after["player_turn_ending"] = false
		after = _draw_with_receipt(engine, after, cursor)
		cursor["turn_start_path"] = "draw_only"
	else:
		after = _prepare_full_with_receipt(engine, cursor["state"], cursor)
		cursor["turn_start_path"] = "full"
	var steps: Array = cursor["steps"]
	steps.append({"kind": "pass_turn_start", "target_losses": player_losses(engine, before, after), "fatigue_hp_loss": int(cursor.get("fatigue_hp_loss", 0))})
	var before_cycles: int = int(before.get("deck", {}).get("cycles", 0))
	var after_cycles: int = int(after.get("deck", {}).get("cycles", before_cycles))
	var fatigue: int = 0
	for cycle: int in range(before_cycles, after_cycles):
		fatigue += int(before.get("deck", {}).get("fatigue_base", engine.FATIGUE_BASE_DAMAGE)) + cycle
	cursor["fatigue_loss"] = fatigue
	cursor["state"] = after
	engine._record_runtime_performance_phase("pass_forecast_turn_start", started)

# Follow CombatEngine._prepare_next_player_turn_in_place's production order,
# calling the same rule helpers on the same engine. The single draw boundary
# needs a receipt: its applied cost can exceed the Health it actually removes.
# forecast_cases.gd compares this full result with production preparation.
static func _prepare_full_with_receipt(engine: RefCounted, next_state: Dictionary, cursor: Dictionary) -> Dictionary:
	if engine.combat_outcome(next_state) != "":
		return next_state
	next_state["current_actor"] = engine._player_actor_entry(int(next_state.get("initiative_clock", 0)), int(next_state.get("activation_seq", 0)))
	engine.SnareRules.end_round(next_state)
	engine.HoarderRules.end_round(next_state)
	next_state["player_turn_ending"] = false
	next_state["banked_play_active"] = clampi(int(next_state.get("banked_plays", 0)), 0, 1)
	next_state["banked_plays"] = 0
	next_state["banked_play_spent_this_activation"] = 0
	next_state = engine._tick_umbra_player_activation(next_state)
	var player: Dictionary = engine._normalized_player(next_state.get("player", {}))
	player["block"] = engine.CommonRelicRules.retained_block(engine._relic_effects(next_state), int(player.get("block", 0)))
	next_state["player"] = player
	engine.RetaliateRules.clear(next_state)
	engine.ManeuverRules.expire_flags(next_state, "next_turn")
	next_state["turn"] = int(next_state.get("turn", 1)) + 1
	next_state["player_turn_time_spent"] = 0
	next_state["cards_played_this_turn"] = 0
	next_state["plays_forfeited_this_turn"] = 0
	next_state["player_movement_capacity"] = engine.player_movement_capacity(next_state)
	next_state["player_movement_remaining"] = int(next_state.get("player_movement_capacity", engine.BASE_PLAYER_MOVEMENT))
	next_state["death_bonus_card_plays_this_turn"] = 0
	next_state["card_play_bonus_this_turn"] = maxi(0, int(next_state.get("pending_relic_card_plays", 0))) + maxi(0, int(next_state.get(engine.SummonCardPlays.PENDING_FIELD, 0)))
	next_state["pending_relic_card_plays"] = 0
	next_state[engine.SummonCardPlays.PENDING_FIELD] = 0
	next_state["player_turn_restrictions"] = {
		"frozen": false,
		"shocked": false,
		"immobilized": false
	}
	next_state["turn_flags"] = {
		"first_attack_bonus_used": false,
		"first_move_bonus_used": false
	}
	next_state = engine.CommonRelicRules.turn_start(engine, next_state)
	next_state = engine.DefenseRelicRules.player_turn_start(engine, next_state)
	next_state = engine._resolve_player_start_of_turn(next_state)
	if engine.combat_outcome(next_state) != "":
		return next_state
	next_state = engine.SurfaceCardRules.resolve_meteor_marks(engine, next_state)
	if engine.combat_outcome(next_state) != "":
		return next_state
	# Recorded after Meteorfall so "started your activation on" sees the board
	# the player takes control of.
	engine.ManeuverRules.record_activation_start(next_state)
	next_state = _draw_with_receipt(engine, next_state, cursor)
	next_state = engine.RiteRules.apply_player_turn_start(engine, next_state)
	next_state = engine.TerrainCardRules.apply_player_turn_start(engine, next_state)
	if engine.combat_outcome(next_state) != "":
		return next_state
	var restrictions: Dictionary = next_state.get("player_turn_restrictions", {})
	if bool(restrictions.get("frozen", false)):
		engine._forfeit_remaining_card_plays(next_state)
	return next_state

static func _draw_with_receipt(engine: RefCounted, state: Dictionary, cursor: Dictionary) -> Dictionary:
	var before: int = int(state.get("run_stats", {}).get(engine.RUN_STAT_DAMAGE_RECEIVED, 0))
	var after: Dictionary = engine._draw_cards_in_place(state, int(state.get("draw_per_turn", engine.BASE_DRAW_PER_TURN)))
	cursor["fatigue_hp_loss"] = maxi(0, int(after.get("run_stats", {}).get(engine.RUN_STAT_DAMAGE_RECEIVED, 0)) - before)
	return after

# Aggregate turn-start snapshots can include both damage and healing. The live
# score counter records gross Health loss, including Fatigue and lethal packets;
# using only the HP difference could turn a real loss into SAFE after recovery.
static func player_losses(engine: RefCounted, before: Dictionary, after: Dictionary) -> Array[Dictionary]:
	var losses: Array[Dictionary] = engine._actor_target_losses(before, after)
	var gross_hp: int = maxi(0, int(after.get("run_stats", {}).get(engine.RUN_STAT_DAMAGE_RECEIVED, 0)) - int(before.get("run_stats", {}).get(engine.RUN_STAT_DAMAGE_RECEIVED, 0)))
	if gross_hp <= 0:
		return losses
	for loss: Dictionary in losses:
		if str(loss.get("kind", "")) == "player":
			loss["hp_loss"] = maxi(gross_hp, int(loss.get("hp_loss", 0)))
			loss["amount"] = int(loss["hp_loss"]) + int(loss.get("block_loss", 0)) + int(loss.get("stoneskin_loss", 0))
			return losses
	losses.append({"key": "player", "kind": "player", "hp_loss": gross_hp, "block_loss": 0, "stoneskin_loss": 0, "amount": gross_hp})
	return losses

# A health-only guard, independent of whether future intent selection can be
# deferred. Empty equipment is also supported: it has no turn-start hooks.
# Any relic/skill/room/ground/terrain mechanic uses full production preparation.
static func _can_project_draw_only(engine: RefCounted, cursor: Dictionary) -> bool:
	var script: Script = engine.get_script()
	if script == null or script.resource_path != "res://scripts/combat_engine.gd": return false
	var state: Dictionary = cursor["state"]
	if str(state.get("room_type", "")) != "combat" or not str(state.get("objective", {}).get("special_type", "")).is_empty(): return false
	if str(state.get("objective", {}).get("type", "kill_all")) not in ["kill_all", "kill_leader"]: return false
	var equipment: Dictionary = state.get("equipped_equipment", {})
	if not equipment.is_empty() and equipment != preload("res://scripts/game_data.gd").starting_equipped_equipment(): return false
	for field: String in ["surfaces", "battlefield_rule", "equipment_grafts", "relic_flags", "skill_flags", "self_flags"]:
		if not (state.get(field, {}) as Dictionary).is_empty(): return false
	for field: String in ["relics", "skill_ids", "active_rites", "illusions", "equipped_items", "terrain", "traps", "meteor_marks", "_surface_pending_deaths"]:
		if not (state.get(field, []) as Array).is_empty(): return false
	return engine._relic_effects(state).is_empty()

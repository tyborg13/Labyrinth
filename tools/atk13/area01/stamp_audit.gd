extends "res://tools/atk13/area01/followup_audit.gd"
## Counterfactual card actions on untouched, naturally entered encounters.
## Reads the production card-aim source and rest-badge service; no roster,
## intent, position, card number or information boundary is substituted.
const PROOF_FORCE_CARDS: Array = ["updraft", "yank"]
const BadgeService = preload("res://scripts/intent_badges.gd")
const Same = preload("res://tests/suites/boss_area_rules_suite.gd")
const ForceData = preload("res://scripts/game_data.gd")
const Red = preload("res://scripts/pass_forecast_red_tiles.gd")

func _audit_decision_point() -> void:
	super._audit_decision_point()
	var state: Dictionary = scene.get("_combat_state")
	var engine: RefCounted = scene.get("_combat_engine")
	var point: String = "%d-%d" % [hunt_seed, audit_points]
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0 or not Areas.has_held(enemy.get("intent", {})): continue
		if not engine.is_enemy_visible_to_player(state,enemy): continue
		var id: int = int(enemy["id"])
		for card: String in PROOF_FORCE_CARDS:
			var action: Dictionary = ForceData.card_def(card)["actions"][0].duplicate(true)
			var targets: Array[Vector2i] = engine._vector2i_values(scene.call("_preview_target_tiles_for_action",state,action,engine.valid_targets_for_player_action(state,action)))
			var target: Vector2i = INVALID
			for tile: Vector2i in engine._enemy_footprint_tiles(enemy):
				if targets.has(tile): target = tile; break
			if target == INVALID: continue
			var resolution: Dictionary = scene.call("_surface_resolution_for_preview", state, action, target)
			var predicted: Dictionary = resolution["known"]["state"]
			predicted = preload("res://scripts/pass_forecast_action_source.gd").visibility_safe(scene,predicted)
			var actual: Dictionary = engine.apply_player_action(state, action, target)
			Committed.accept(engine, actual)
			var index: int = engine._enemy_index_for_id(actual, id)
			if index < 0 or int(actual["enemies"][index]["hp"]) <= 0: continue
			var forecast_index: int = engine._enemy_index_for_id(predicted, id)
			if forecast_index < 0: continue
			var badges: Dictionary = BadgeService.build(engine, state, predicted, "", predicted)
			var phase: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(Red.schedule(engine,predicted),true)
			var summary: Dictionary = scene.call("_pass_preview_summary_for_phase_result",predicted,phase)
			badges = Red.adjust_from_summary(badges,summary)
			var red: Array[Vector2i]
			for threat: Dictionary in badges.get("threats", []):
				if str(threat.get("key", "")) == "enemy_%d" % id and bool(threat.get("area_announced", false)): red.append_array(threat["tiles"])
			var projected: Dictionary = predicted["enemies"][forecast_index]
			var expected: Array[Vector2i] = Areas.announced_tiles(projected, engine, predicted)
			var resolved: Dictionary = summary.get("relative_red_areas",{}).get("enemy_%d" % id,{})
			if not resolved.is_empty() and resolved.get("signature",[]) == Areas.forecast_signature(projected.get("intent",{})): expected.assign(resolved["tiles"])
			var actual_plan: Dictionary = engine.enemy_intent_plan(actual, index)
			var forecast_plan: Dictionary = engine.enemy_intent_plan(predicted, forecast_index)
			var trace: Dictionary = _actual_trace(engine, state, actual)
			var records: Array = trace.get("receipts", []).duplicate(true)
			var relevant: Array = records.filter(func(record: Dictionary) -> bool: return str(record["owner"]) == "enemy_%d" % id and str(record["intent"]) == str(enemy["intent"]["id"]) and record.has("area_shown"))
			if relevant.size()>1: relevant.resize(1) # The already-announced cast, not a later cycle.
			var disclosed: bool = false
			for field: String in ["unseen_ground_crossed","unrevealed_before_player","umbra_unknown_before_player","forecast_limit_reached","terminal_unknown"]: disclosed = disclosed or bool(summary.get(field,false))
			samples.store_line(JSON.stringify({"kind":"stamp_check", "point":point, "source":str(enemy["type"]), "intent":str(enemy["intent"]["id"]), "card":card,
				"offset":actual["enemies"][index]["pos"]-Vector2i(enemy["pos"]), "source_matched_prediction":actual["enemies"][index]["pos"] == projected["pos"],
				"forecast_matches":Same.same(red, expected), "forecast_red":red, "forecast_expected":expected,
				"forecast_disclosed":disclosed,
				"actual_anchor":actual_plan.get("destination", actual["enemies"][index]["pos"]), "forecast_anchor":forecast_plan.get("destination", projected["pos"]),
				"receipts":relevant, "oracle_matches_production":trace.get("oracle_matches_production", false),
				"repro":_save_repro(point, state)}))
	samples.flush()

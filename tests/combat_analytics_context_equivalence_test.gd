extends SceneTree
const RunScene = preload("res://scripts/run_scene.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const Fixture = preload("res://tests/suites/card_playability_summary_suite.gd")
var failures: Array[String]
var comparisons: int = 0

class CapturingStore:
	extends "res://scripts/analytics_store.gd"
	var captured: Array = []
	func write_events(events: Array) -> bool:
		captured = events.duplicate(true)
		return true

class OriginalRunScene:
	extends RunScene

	func _analytics_context_from_states(run_state: Dictionary, combat_state: Dictionary = {}, card_id: String = "", card_instance_id: String = "") -> Dictionary:
		var room_meta: Dictionary = {}
		if not run_state.is_empty():
			room_meta = _run_engine.room_metadata(run_state, run_state.get("current_room", Vector2i.ZERO))
		var player: Dictionary = (combat_state.get("player", {}) as Dictionary) if not combat_state.is_empty() else {}
		var combat_analytics: Dictionary = (combat_state.get("analytics", {}) as Dictionary).duplicate(true)
		var run_analytics: Dictionary = (run_state.get("analytics", {}) as Dictionary).duplicate(true)
		var progression: Dictionary = (run_state.get("progression", _progression) as Dictionary).duplicate(true)
		var context: Dictionary = {
			"balance_transition": (combat_state.get("balance_transition", {}) as Dictionary).duplicate(true),
			"run_id": str(run_analytics.get("run_id", "")),
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
		return context

	func _analytics_log_card_draws(before_state: Dictionary, after_state: Dictionary, before_tracker: Dictionary, after_tracker: Dictionary, reason: String) -> void:
		var pickup_counts: Dictionary = BattlefieldItemRules.hand_pickup_counts(before_state, after_state)
		var before_hand_ids: Dictionary = {}
		var events: Array[Dictionary] = []
		for instance_id_var: Variant in _analytics_zone_ids(before_tracker, "hand"):
			before_hand_ids[str(instance_id_var)] = true
		var after_hand_ids: Array = _analytics_zone_ids(after_tracker, "hand")
		var after_hand_cards: Array[String] = _analytics_zone_cards(after_state, "hand")
		for index: int in range(mini(after_hand_ids.size(), after_hand_cards.size())):
			var instance_id: String = str(after_hand_ids[index])
			if before_hand_ids.has(instance_id):
				continue
			var card_id: String = after_hand_cards[index]
			var draw_reason: String = reason
			if int(pickup_counts.get(card_id, 0)) > 0:
				draw_reason = "item_pickup"
				pickup_counts[card_id] = int(pickup_counts[card_id]) - 1
			events.append({
				"event_type": "card_drawn",
				"context": _analytics_context_from_states(_run_state, after_state, card_id, instance_id),
				"payload": {
					"reason": draw_reason,
					"hand_index": index,
					"hand_size": after_hand_cards.size(),
					"draw_pile_size": _analytics_zone_cards(after_state, "draw").size()
				}
			})
		_analytics_store.write_events(events)

	func _sync_combat_state_from_run() -> void:
		var entering_combat: bool = _combat_state.is_empty()
		_combat_state = (_run_state.get("combat_state", {}) as Dictionary).duplicate(true)
		if not _combat_state.is_empty():
			_combat_state = _combat_engine.normalize_player_movement_pool(_combat_state)
			if str(_run_state.get("mode", "")) == "combat":
				_run_state = _run_engine.set_combat_state(_run_state, _combat_state)
		if entering_combat and not _combat_state.is_empty():
			# Never let a prior room's cached render signature suppress the first
			# complete Turn Clock render on combat-room entry.
			_turn_order_source_signature = "<room-entry>"
			_turn_order_render_signature = "<room-entry>"
		_mark_combat_preview_state_changed()

	func _sync_progression_from_run() -> void:
		var run_progression: Dictionary = (_run_state.get("progression", {}) as Dictionary).duplicate(true)
		if run_progression.is_empty():
			return
		# Victory has transferred the wallet into the embedded profile. A later
		# discovery/save must preserve that bank after held Embers have been cleared.
		_progression = run_progression if str(_run_state.get("mode", "")) == "victory" else ProgressionStore.set_embers(run_progression, _run_engine.held_embers(_run_state))

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var current := RunScene.new()
	var original := OriginalRunScene.new()
	var current_store := CapturingStore.new()
	var original_store := CapturingStore.new()
	current.set("_analytics_store", current_store)
	original.set("_analytics_store", original_store)
	var engine := RunEngine.new()
	var combat := CombatEngine.new()
	for schema: int in [1, 6, 8]:
		for stage: String in ["clear", "heart"]:
			var progression: Dictionary = ProgressionStore.default_data()
			progression["progression_schema"] = schema
			progression["skill_ids"] = ["quick_wits", "open_sky"]
			var run: Dictionary = engine.create_new_run(20260917, progression)
			var before: Dictionary = Fixture._fixture(combat, stage)
			before["umbra"]["stage"] = stage
			before["analytics"] = {"combat_id": "proof_combat"}
			before["balance_transition"] = {"proof": {"number": 1}}
			before["relics"] = ["ember_lens", "witchglass_lantern"]
			Fixture._set_hand(before, ["pale_spark"])
			var after: Dictionary = before.duplicate(true)
			Fixture._set_hand(after, ["pale_spark", "wildfire_halo", "pale_spark", "shadow_step", "gust_step", "thunderline", "threaded_path"])
			run["combat_state"] = after
			run["mode"] = "combat"
			var run_before: Dictionary = run.duplicate(true)
			var before_tracker: Dictionary = {"zones": {"hand": ["old_card"]}}
			var after_tracker: Dictionary = {"zones": {"hand": ["old_card", "new1", "new2", "new3", "new4", "new5", "new6"]}}
			for scene: RunScene in [current, original]:
				scene.set("_progression", progression.duplicate(true))
				scene.set("_run_state", run)
				scene._analytics_log_card_draws(before, after, before_tracker, after_tracker, "proof_draw")
			check(current_store.captured == original_store.captured and current_store.captured.size() == 6, "Every card-draw event, ordered context and payload equals original")
			var context: Dictionary = current._analytics_context_from_states(run, after, "pale_spark", "test")
			check(context == original._analytics_context_from_states(run, after, "pale_spark", "test"), "Full context preserves every scalar and nested field")
			context["balance_transition"]["proof"]["number"] = 100
			(context["progression_skills"] as Array).append("caller mutation")
			(context["relics"] as Array).append("caller mutation")
			current_store.captured[0]["context"]["relics"].append("first event mutation")
			check(current_store.captured[1]["context"] == original_store.captured[1]["context"], "Each batched event owns its nested context")
			check(run == run_before, "Building events and mutating returned context cannot mutate source run/combat")
			for scene: RunScene in [current, original]:
				scene.set("_run_state", run)
				scene._sync_combat_state_from_run()
				scene._sync_progression_from_run()
			check(current.get("_combat_state") == original.get("_combat_state") and current.get("_run_state") == original.get("_run_state") and current.get("_progression") == original.get("_progression"), "Combat/profile synchronization remains exactly equal")
			(current.get("_combat_state") as Dictionary)["player"]["hp"] = -1
			(current.get("_progression") as Dictionary)["skill_ids"].append("caller mutation")
			check(run == run_before, "Synchronized state still owns nested data")
	for mode: String in ["room", "victory", "defeat"]:
		var run: Dictionary = engine.create_new_run(20260917, ProgressionStore.default_data())
		run["mode"] = mode
		run["combat_state"] = {}
		var before: Dictionary = run.duplicate(true)
		for scene: RunScene in [current, original]:
			scene.set("_run_state", run)
			scene._sync_combat_state_from_run()
			scene._sync_progression_from_run()
		check(current.get("_progression") == original.get("_progression") and (current.get("_combat_state") as Dictionary).is_empty(), "Outcome and empty-combat synchronization preserve behavior")
		(current.get("_progression") as Dictionary)["skill_ids"].append("caller mutation")
		check(run == before, "Outcome progression is still an owned snapshot")
	current.free()
	original.free()
	print("TEST RESULT: %s — %d analytics-context/boundary comparisons (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", comparisons, failures.size()])
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	comparisons += 1
	if not ok:
		failures.append(message)
		push_error(message)

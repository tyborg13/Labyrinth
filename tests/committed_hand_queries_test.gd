extends SceneTree
const SceneScript = preload("res://scripts/run_scene.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const Fixture = preload("res://tests/suites/card_playability_summary_suite.gd")
const HAND: Array = ["threaded_path", "sidestep_slash", "pale_spark", "wildfire_halo", "shadow_step", "gust_step", "thunderline"]
var failures: Array[String]
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var progression = preload("res://scripts/progression_store.gd")
	progression.set_storage_path("user://hand_queries_profile.json")
	progression.set_run_storage_path("user://hand_queries_run.save")
	var scene: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var combat := CombatEngine.new()
	var source: Dictionary = Fixture._fixture(combat, "heart")
	Fixture._set_hand(source, HAND)
	var expected_state: Dictionary = combat.normalize_player_movement_pool(source)
	var unrelated: Dictionary = Fixture._fixture(combat, "blocked")
	scene.set("_combat_state", unrelated)
	var original: Dictionary = unrelated.duplicate(true)
	scene.call("_schedule_committed_hand_queries", source)
	await _settle_job(scene)
	check(scene.get("_combat_state") == original, "Background work must not replace live animation or information state")
	check(source == _fixture_source(combat), "Background queries must leave their input unchanged")
	scene.set("_combat_state", expected_state)
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_adopt_committed_hand_queries")
	check((scene.get("_card_playability_cache") as Dictionary).size() == HAND.size(), "An exact complete snapshot adopts all prepared flags")
	check((scene.get("_card_widget_display_cache") as Dictionary).size() == HAND.size(), "An exact complete snapshot adopts every display")
	var oracle := SceneScript.new()
	oracle.set("_combat_state", expected_state)
	for index: int in range(HAND.size()):
		check(scene.call("_card_playability_for_index", index) == oracle.call("_card_playability_for_index", index), "Adopted flags match ordinary synchronous calculation")
		check(scene.call("_card_widget_display_for_index", index) == oracle.call("_card_widget_display_for_index", index), "Adopted modifier display matches ordinary calculation")
		check(scene.call("_card_preview_for_index", index) == oracle.call("_card_preview_for_index", index), "Summary adoption must not truncate complete interactive previews")
	check(scene.call("_pass_preview_summary") == oracle.call("_pass_preview_summary"), "Prepared forecast matches synchronous hidden-enemy/initiative calculation")
	scene.call("_mark_preview_selection_changed")
	check(scene.call("_pass_preview_summary") == oracle.call("_pass_preview_summary"), "Selection revision changes retain the exact source forecast")
	oracle.free()
	check((scene.get("_committed_hand_query_state") as Dictionary).is_empty(), "Adoption releases the retained future state")

	# Any complete-state difference rejects the batch; no selected-field key can
	# accidentally omit a rule, information or ownership dependency.
	for field: String in ["hp", "hand", "umbra", "skill", "rng"]:
		scene.call("_schedule_committed_hand_queries", source)
		await _settle_job(scene)
		var changed: Dictionary = expected_state.duplicate(true)
		match field:
			"hp": changed["player"]["hp"] = 1
			"hand": changed["deck"]["hand"].reverse()
			"umbra": changed["umbra"]["stage"] = "clear"
			"skill": changed["skill_ids"] = ["open_sky"]
			"rng": changed["rng_state"] = int(changed.get("rng_state", 0)) + 1
		scene.set("_combat_state", changed)
		scene.call("_mark_combat_preview_state_changed")
		scene.call("_adopt_committed_hand_queries")
		check((scene.get("_card_playability_cache") as Dictionary).is_empty(), field + " mismatch rejects every prepared flag")
		check((scene.get("_card_widget_display_cache") as Dictionary).is_empty(), field + " mismatch rejects every display")
		check(not scene.get("_combat_forecast_cache").matches(changed), field + " mismatch rejects the prepared forecast")

	# Adoption never waits for the remaining work: a partial snapshot is useful,
	# and later frames cannot refill a cancelled generation's scratch storage.
	scene.call("_schedule_committed_hand_queries", source)
	for frame: int in range(3): await process_frame
	var partial_count: int = (scene.get("_committed_hand_query_flags") as Dictionary).size()
	check(partial_count > 0 and partial_count < HAND.size(), "Partial-work fixture must stop before completion")
	scene.set("_combat_state", expected_state)
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_adopt_committed_hand_queries")
	check((scene.get("_card_playability_cache") as Dictionary).size() == partial_count, "Partial adoption synchronously takes exactly the ready entries")
	check(not scene.get("_combat_forecast_cache").matches(expected_state), "Incomplete forecast falls back without waiting")
	for frame: int in range(12): await process_frame
	check((scene.get("_committed_hand_query_flags") as Dictionary).is_empty(), "Cancelled generation cannot repopulate scratch results")

	scene.call("_schedule_committed_hand_queries", source)
	await process_frame
	var replacement: Dictionary = Fixture._fixture(combat, "frozen")
	Fixture._set_hand(replacement, HAND)
	scene.call("_schedule_committed_hand_queries", replacement)
	await _settle_job(scene)
	check(scene.get("_committed_hand_query_state") == combat.normalize_player_movement_pool(replacement), "Replacement generation owns all completed results")
	scene.call("_cancel_committed_hand_queries")
	check((scene.get("_committed_hand_query_flags") as Dictionary).is_empty() and (scene.get("_committed_hand_query_state") as Dictionary).is_empty(), "Cancellation releases all retained query data")
	# Detaching a retained scene cancels suspended jobs before they can call
	# get_tree again. Reattachment must not revive the obsolete generation.
	scene.call("_schedule_committed_hand_queries", source)
	await process_frame
	root.remove_child(scene)
	for frame: int in range(12): await process_frame
	check((scene.get("_committed_hand_query_state") as Dictionary).is_empty(), "Detachment releases suspended query state")
	root.add_child(scene)
	for frame: int in range(3): await process_frame
	check((scene.get("_committed_hand_query_flags") as Dictionary).is_empty(), "Reattachment cannot revive a detached generation")
	scene.call("_schedule_committed_hand_queries", source)
	await _settle_job(scene)
	check((scene.get("_committed_hand_query_flags") as Dictionary).size() == HAND.size(), "Reattached scene can prepare a fresh generation")
	# Compare complete forecast summaries in distinct combat and status states,
	# including no selected card and the original information-limited fixture.
	for kind: String in ["open", "blocked", "dense", "heart", "frozen", "shocked", "immobilized", "surface_ready", "surface_spent"]:
		var forecast_source: Dictionary = Fixture._fixture(combat, kind)
		Fixture._set_hand(forecast_source, HAND)
		scene.call("_schedule_committed_hand_queries", forecast_source)
		await _settle_job(scene)
		var normalized: Dictionary = combat.normalize_player_movement_pool(forecast_source)
		scene.set("_combat_state", normalized)
		scene.call("_mark_combat_preview_state_changed")
		scene.call("_adopt_committed_hand_queries")
		var direct := SceneScript.new()
		direct.set("_combat_state", normalized.duplicate(true))
		check(scene.call("_pass_preview_summary") == direct.call("_pass_preview_summary"), kind + " prepared forecast equals synchronous summary")
		direct.free()
	var cache = preload("res://scripts/combat_forecast_cache.gd").new()
	var cache_source: Dictionary = {"nested": {"hp": 20}, "rng": 1}
	var cache_result: Dictionary = {"entries": [{"damage": 3}]}
	cache.remember(cache_source, cache_result)
	cache_source["nested"]["hp"] = 19
	cache_result["entries"][0]["damage"] = 999
	check(not cache.matches(cache_source), "Cache owns nested input; in-place mutations cannot create false hits")
	check(cache.summary()["entries"][0]["damage"] == 3, "Cache owns nested result input")
	var returned: Dictionary = cache.summary()
	returned["entries"].clear()
	check(cache.summary()["entries"].size() == 1, "Cache result callers cannot mutate remembered data")
	cache.remember({}, {})
	check(cache.matches({}) and cache.summary().is_empty(), "Empty summaries are valid cached results")
	cache.clear()
	check(not cache.matches({}), "Clearing invalidates even empty input")
	# Real scheduled, revealed attackers exercise multiple cursor slices. The
	# third variant also includes an unrevealed enemy beyond those two attacks.
	for hidden: bool in [false, true]:
		var forecast_state: Dictionary = _damaging_forecast_state(combat, hidden)
		scene.call("set_runtime_performance_instrumentation_enabled", true)
		scene.call("_schedule_committed_hand_queries", forecast_state)
		await _settle_job(scene)
		var normalized: Dictionary = combat.normalize_player_movement_pool(forecast_state)
		scene.set("_combat_state", normalized)
		scene.call("_mark_combat_preview_state_changed")
		scene.call("_adopt_committed_hand_queries")
		check(scene.get("_combat_forecast_cache").matches(normalized), "A complete damaging forecast is positively adopted")
		check(int((scene.call("committed_hand_query_instrumentation_snapshot") as Dictionary).get("adopted_forecasts", 0)) == 1, "Forecast adoption instrumentation records the prepared result")
		var direct := SceneScript.new()
		direct.set("_combat_state", normalized.duplicate(true))
		var expected: Dictionary = direct.call("_pass_preview_summary")
		check(int(expected.get("hp_loss", 0)) == 10, "Both revealed actors deal their five damage in the oracle")
		check(bool(expected.get("unrevealed_before_player", false)) == hidden, "The mixed fixture stops at the unrevealed follow-up")
		check(scene.call("_pass_preview_summary") == expected, "Prepared damaging forecast equals the synchronous oracle")
		scene.call("_mark_preview_selection_changed")
		check(scene.call("_pass_preview_summary") == expected, "Selection invalidation preserves an equal source result")
		check(int((scene.get("_runtime_performance_counts") as Dictionary).get("pass_preview_source_cache_hit", 0)) >= 2, "Both initial and selection-invalidated reads use the source cache")
		scene.call("_mark_combat_preview_state_changed")
		check(not scene.get("_combat_forecast_cache").matches(normalized), "Committed-state invalidation clears the remembered source")
		direct.free()
	# Interrupt AFTER an actual enemy has resolved, while another is pending.
	for operation: String in ["cancel", "replace", "detach", "free"]:
		var forecast_state: Dictionary = _damaging_forecast_state(combat, true)
		scene.call("set_runtime_performance_instrumentation_enabled", true)
		scene.call("_schedule_committed_hand_queries", forecast_state)
		await _await_forecast_slice(scene)
		check((scene.get("_committed_hand_query_flags") as Dictionary).size() == HAND.size() and not (scene.get("_committed_hand_query_forecast") as Dictionary).has("summary"), operation + " interrupts forecast after hand preparation and before completion")
		match operation:
			"cancel": scene.call("_cancel_committed_hand_queries")
			"replace": scene.call("_schedule_committed_hand_queries", replacement)
			"detach": root.remove_child(scene)
			"free": scene.queue_free()
		for frame: int in range(20): await process_frame
		if operation == "free":
			check(not is_instance_valid(scene), "A suspended forecast is safe to free")
			continue
		check(not scene.get("_combat_forecast_cache").matches(combat.normalize_player_movement_pool(forecast_state)), operation + " cannot publish an obsolete forecast")
		if operation == "replace":
			check(scene.get("_committed_hand_query_state") == combat.normalize_player_movement_pool(replacement), "Replacement owns forecast scratch state")
		else:
			check((scene.get("_committed_hand_query_state") as Dictionary).is_empty() and (scene.get("_committed_hand_query_forecast") as Dictionary).is_empty(), operation + " releases suspended forecast scratch")
		if operation == "detach":
			root.add_child(scene)
			await process_frame
	for frame: int in range(3): await process_frame
	print("TEST RESULT: %s — %d committed-hand query checks (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _damaging_forecast_state(combat: CombatEngine, hidden: bool) -> Dictionary:
	var state: Dictionary = Fixture._fixture(combat, "open")
	Fixture._set_hand(state, HAND)
	state["player"]["pos"] = Vector2i(2, 4)
	state["enemies"] = []
	state["turn_queue"] = []
	state["initiative_clock"] = 0
	state["activation_seq"] = 4
	state["current_actor"] = {"kind": "player", "actor_key": "player", "time": 0, "seq": 0}
	state["player_turn_time_spent"] = 10
	for index: int in range(3 if hidden else 2):
		var pos: Vector2i = [Vector2i(3, 4), Vector2i(2, 5), Vector2i(7, 4)][index]
		var enemy: Dictionary = Fixture._enemy(index + 1, pos)
		enemy["intent"] = {"name": "Revealed claw", "time": 20, "actions": [{"type": "melee", "damage": 5, "range": 1}]} if index < 2 else {}
		state["enemies"].append(enemy)
		state["turn_queue"].append({"kind": "enemy", "actor_key": "enemy_%d" % (index + 1), "enemy_id": index + 1, "type": "crawler", "team": "enemy", "time": index + 1, "seq": index + 1, "pos": pos})
	return state

func _await_forecast_slice(scene: Node) -> void:
	for frame: int in range(128):
		if int((scene.get("_runtime_performance_counts") as Dictionary).get("committed_forecast_slice", 0)) > 0: return
		await process_frame
	check(false, "A real enemy forecast slice must execute")

func _fixture_source(combat: CombatEngine) -> Dictionary:
	var state: Dictionary = Fixture._fixture(combat, "heart")
	Fixture._set_hand(state, HAND)
	return state

func _settle_job(scene: Node) -> void:
	for frame: int in range(128):
		if (scene.get("_committed_hand_query_flags") as Dictionary).size() == HAND.size() and (scene.get("_committed_hand_query_forecast") as Dictionary).has("summary"): return
		await process_frame
	check(false, "Prepared hand must finish within its bounded test frames")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

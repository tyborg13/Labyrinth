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
	# Free with a live suspended job, without an explicit test-side cancellation.
	scene.call("_schedule_committed_hand_queries", source)
	scene.queue_free()
	for frame: int in range(3): await process_frame
	print("TEST RESULT: %s — %d committed-hand query checks (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _fixture_source(combat: CombatEngine) -> Dictionary:
	var state: Dictionary = Fixture._fixture(combat, "heart")
	Fixture._set_hand(state, HAND)
	return state

func _settle_job(scene: Node) -> void:
	for frame: int in range(24):
		if (scene.get("_committed_hand_query_flags") as Dictionary).size() == HAND.size(): return
		await process_frame
	check(false, "Prepared hand must finish within its bounded test frames")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

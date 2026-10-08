extends SceneTree

const SceneScript = preload("res://scripts/run_scene.gd")
const Reference = preload("res://tests/fixtures/committed_card_shortcut_reference.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const Fixture = preload("res://tests/suites/card_playability_summary_suite.gd")
const Data = preload("res://scripts/game_data.gd")
const HAND: Array = ["sidestep_slash", "threaded_path", "pale_spark", "wildfire_halo", "shadow_step", "gust_step", "thunderline"]
var failures: Array[String]
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var progression = preload("res://scripts/progression_store.gd")
	progression.set_storage_path("user://prepared_card_profile.json")
	progression.set_run_storage_path("user://prepared_card_run.save")
	var scene: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var combat := CombatEngine.new()
	for kind: String in ["open", "blocked", "dense", "heart", "frozen", "shocked", "immobilized", "surface_ready", "surface_spent"]:
		var source: Dictionary = _source(combat, kind)
		var owned: Dictionary = source.duplicate(true)
		var expected: Dictionary = combat.normalize_player_movement_pool(owned)
		var unrelated: Dictionary = _source(combat, "blocked")
		scene.set("_combat_state", unrelated)
		scene.call("_mark_combat_preview_state_changed")
		scene.call("_schedule_committed_hand_queries", source, true)
		# A caller can reuse its dictionary as soon as scheduling returns.
		source["player"]["hp"] = 1
		await _settle_previews(scene)
		check(scene.get("_combat_state") == unrelated, kind + " preparation preserves the live animation/information state")
		check(scene.get("_committed_hand_query_state") == expected, kind + " preparation owns the source before its first yield")
		check((scene.get("_card_preview_cache") as Dictionary).is_empty(), kind + " preparation does not publish live previews")
		check((scene.get("_preview_shortcuts_content_cache") as Dictionary).is_empty(), kind + " preparation does not publish live shortcut plans")
		var oracle := Reference.new()
		oracle.set("_combat_state", expected.duplicate(true))
		var scratch: Dictionary = scene.get("_committed_hand_query_previews")
		var shortcuts: Dictionary = (scene.get("_committed_hand_query_shortcuts") as Dictionary).duplicate(true)
		for index: int in range(HAND.size()):
			var raw: Dictionary = oracle.call("_card_preview_for_index", index)
			check(scratch.get(index, {}) == raw, kind + " prepared full preview matches the original for card " + str(index))
			if shortcuts.has(index):
				var preview: Dictionary = oracle.call("_sanitize_preview_for_umbra_information", raw)
				var original_plans: Dictionary = oracle.call("_preview_shortcuts_for_current_action", preview, false, true)
				check(shortcuts[index]["result"] == original_plans, kind + " prepared shortcut keeps original routes, trap/loot costs and attack continuation")
				check(shortcuts[index]["exact_result"] == oracle.call("_preview_shortcuts_for_current_action", preview, false, false), kind + " exact selection shortcut matches its original semantics")
		scene.set("_combat_state", expected)
		scene.call("_mark_combat_preview_state_changed")
		scene.call("set_runtime_performance_instrumentation_enabled", true)
		scene.call("_adopt_committed_hand_queries")
		check((scene.get("_card_preview_cache") as Dictionary).size() == HAND.size(), kind + " adoption publishes every complete preview")
		check((scene.get("_committed_hand_query_previews") as Dictionary).is_empty(), kind + " adoption releases scratch previews")
		check((scene.get("_card_full_preview_summary_cache") as Dictionary).size() == HAND.size(), kind + " full-preview summaries remain bounded by the adopted hand")
		for index: int in range(HAND.size()):
			check(scene.call("_card_preview_for_index", index) == oracle.call("_card_preview_for_index", index), kind + " adopted preview retains every target and rule")
			check(scene.call("_card_playability_for_index", index) == oracle.call("_card_playability_for_index", index), kind + " prepared full-preview flags match the original hand state")
			if shortcuts.has(index):
				scene.set("_hovered_card_index", index)
				scene.call("_mark_preview_selection_changed")
				var preview: Dictionary = scene.call("_sanitize_preview_for_umbra_information", scene.call("_card_preview_for_index", index))
				var actual: Dictionary = scene.call("_preview_shortcuts_for_current_action", preview, false, true)
				var original_plans: Dictionary = oracle.call("_preview_shortcuts_for_current_action", preview, false, true)
				check(actual == original_plans, kind + " foreground shortcut adopts the exact original plan")
				var plans: Dictionary = actual.get("plans", {})
				if not plans.is_empty():
					(plans[plans.keys()[0]] as Dictionary)["move_distance"] = 999
					scene.call("_mark_preview_selection_changed")
					check(scene.call("_preview_shortcuts_for_current_action", preview, false, true) == original_plans, kind + " active plan mutation cannot change the owned content snapshot")
		# A real analytics acknowledgement changes the committed source after
		# adoption. Only that bookkeeping may preserve an otherwise exact key.
		if shortcuts.has(0):
			var preview: Dictionary = scene.call("_sanitize_preview_for_umbra_information", scene.call("_card_preview_for_index", 0))
			var live: Dictionary = scene.get("_combat_state")
			var analytics: Dictionary = (live.get("analytics", {}) as Dictionary).duplicate(true)
			analytics["fixture_ack_cursor"] = 1
			live["analytics"] = analytics
			oracle.set("_combat_state", live.duplicate(true))
			oracle.call("_mark_preview_selection_changed")
			scene.call("_mark_preview_selection_changed")
			var before: Dictionary = scene.call("runtime_performance_instrumentation_snapshot")
			var hits_before: int = int((before.get("shortcut_equivalent_input_hit", {}) as Dictionary).get("count", 0))
			check(scene.call("_preview_shortcuts_for_current_action", preview, false, true) == oracle.call("_preview_shortcuts_for_current_action", preview, false, true), kind + " analytics acknowledgement keeps exactly the original plan")
			var after: Dictionary = scene.call("runtime_performance_instrumentation_snapshot")
			check(int((after.get("shortcut_equivalent_input_hit", {}) as Dictionary).get("count", 0)) == hits_before + 1, kind + " analytics acknowledgement retains the prepared content snapshot")
			live["player"] = (live["player"] as Dictionary).duplicate(true)
			live["player"]["hp"] = 1
			oracle.set("_combat_state", live.duplicate(true))
			oracle.call("_mark_preview_selection_changed")
			scene.call("_mark_preview_selection_changed")
			check(scene.call("_preview_shortcuts_for_current_action", preview, false, true) == oracle.call("_preview_shortcuts_for_current_action", preview, false, true), kind + " non-analytics source changes keep the original fallback")
			var changed_metrics: Dictionary = scene.call("runtime_performance_instrumentation_snapshot")
			check(int((changed_metrics.get("shortcut_equivalent_input_hit", {}) as Dictionary).get("count", 0)) == hits_before + 1, kind + " every other source field still rejects the prepared key")
		var metrics: Dictionary = scene.call("runtime_performance_instrumentation_snapshot")
		if not shortcuts.is_empty():
			check(int((metrics.get("shortcut_equivalent_input_hit", {}) as Dictionary).get("count", 0)) > 0, kind + " foreground lookup proves prepared shortcut adoption")
		check((scene.get("_preview_shortcuts_content_cache") as Dictionary).size() <= 4, kind + " content snapshots remain bounded")
		scene.call("set_runtime_performance_instrumentation_enabled", false)
		oracle.free()
	var partial_source: Dictionary = _source(combat, "heart")
	scene.call("_schedule_committed_hand_queries", partial_source, true)
	await _settle_partial(scene)
	scene.set("_combat_state", combat.normalize_player_movement_pool(partial_source))
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_adopt_committed_hand_queries")
	check((scene.get("_card_preview_cache") as Dictionary).size() == 1, "Partial adoption publishes exactly the one ready complete query")
	var partial_oracle := Reference.new()
	partial_oracle.set("_combat_state", combat.normalize_player_movement_pool(partial_source))
	for index: int in range(HAND.size()):
		check(scene.call("_card_preview_for_index", index) == partial_oracle.call("_card_preview_for_index", index), "Partial adoption preserves synchronous fallback for card " + str(index))
	for frame: int in range(20): await process_frame
	check((scene.get("_committed_hand_query_previews") as Dictionary).is_empty() and (scene.get("_committed_hand_query_shortcuts") as Dictionary).is_empty(), "Partial adoption cancels suspended work without refilling scratch caches")
	partial_oracle.free()
	# Full-state and definition mismatches must reject every prepared result.
	for changed_input: String in ["hp", "hand", "umbra", "rng", "definition"]:
		var source: Dictionary = _source(combat, "heart")
		scene.call("_schedule_committed_hand_queries", source, true)
		await _settle_previews(scene)
		var changed: Dictionary = combat.normalize_player_movement_pool(source)
		var original_name: String = str((Data.cards()["sidestep_slash"] as Dictionary).get("name", ""))
		match changed_input:
			"hp": changed["player"]["hp"] = 1
			"hand": changed["deck"]["hand"].reverse()
			"umbra": changed["umbra"]["stage"] = "clear"
			"rng": changed["rng_state"] = int(changed.get("rng_state", 0)) + 1
			"definition": (Data.cards()["sidestep_slash"] as Dictionary)["name"] = "Changed fixture definition"
		scene.set("_combat_state", changed)
		scene.call("_mark_combat_preview_state_changed")
		scene.call("_adopt_committed_hand_queries")
		check((scene.get("_card_preview_cache") as Dictionary).is_empty(), changed_input + " rejects prepared previews")
		check((scene.get("_card_full_preview_summary_cache") as Dictionary).is_empty(), changed_input + " rejects exact full-preview flags")
		check((scene.get("_preview_shortcuts_content_cache") as Dictionary).is_empty(), changed_input + " rejects prepared shortcut plans")
		(Data.cards()["sidestep_slash"] as Dictionary)["name"] = original_name
	for operation: String in ["cancel", "replace", "detach", "definition"]:
		scene.call("_schedule_committed_hand_queries", _source(combat, "open"), true)
		await _settle_partial(scene)
		check((scene.get("_committed_hand_query_previews") as Dictionary).size() == 1, operation + " interrupts between full card queries")
		var original_name: String = str((Data.cards()["sidestep_slash"] as Dictionary).get("name", ""))
		match operation:
			"cancel": scene.call("_cancel_committed_hand_queries")
			"replace": scene.call("_schedule_committed_hand_queries", _source(combat, "heart"), true)
			"detach": root.remove_child(scene)
			"definition": (Data.cards()["sidestep_slash"] as Dictionary)["name"] = "Changed during preparation"
		for frame: int in range(12): await process_frame
		if operation == "replace":
			await _settle_previews(scene)
			check(scene.get("_committed_hand_query_state") == combat.normalize_player_movement_pool(_source(combat, "heart")), "Replacement owns the new preparation results")
		else:
			check((scene.get("_committed_hand_query_previews") as Dictionary).is_empty(), operation + " releases suspended preview results")
			check((scene.get("_committed_hand_query_shortcuts") as Dictionary).is_empty(), operation + " releases suspended plans")
		if operation == "detach": root.add_child(scene)
		(Data.cards()["sidestep_slash"] as Dictionary)["name"] = original_name
	# Ordinary cards, Encore, and surface actions retain only the original
	# flags/forecast job. Full preview work is an explicit Quick Wits opt-in.
	var ordinary_source: Dictionary = _source(combat, "open")
	scene.set("_combat_state", combat.normalize_player_movement_pool(ordinary_source))
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_schedule_committed_hand_queries", ordinary_source)
	for frame: int in range(40): await process_frame
	check((scene.get("_committed_hand_query_flags") as Dictionary).size() == HAND.size(), "Default preparation keeps all original hand flags")
	check((scene.get("_committed_hand_query_forecast") as Dictionary).has("summary"), "Default preparation keeps the original forecast")
	check((scene.get("_committed_hand_query_previews") as Dictionary).is_empty(), "Default preparation does not compute full previews")
	check((scene.get("_committed_hand_query_shortcuts") as Dictionary).is_empty(), "Default preparation does not compute shortcut plans")
	check((scene.get("_committed_hand_query_definitions") as Array).is_empty(), "Default preparation does not retain full definition snapshots")
	scene.call("_adopt_committed_hand_queries")
	check((scene.get("_card_playability_cache") as Dictionary).size() == HAND.size(), "Default preparation still adopts the original flags")
	check((scene.get("_card_preview_cache") as Dictionary).is_empty(), "Default adoption keeps full queries synchronous")
	scene.queue_free()
	for frame: int in range(3): await process_frame
	print("PREPARED CARD PREVIEW RESULT: " + JSON.stringify({"checks": checks, "failures": failures, "orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}))
	quit(0 if failures.is_empty() else 1)

func _source(combat: RefCounted, kind: String) -> Dictionary:
	var source: Dictionary = Fixture._fixture(combat, kind)
	Fixture._set_hand(source, HAND)
	return source

func _settle_previews(scene: Node) -> void:
	for frame: int in range(400):
		if (scene.get("_committed_hand_query_previews") as Dictionary).size() == HAND.size(): return
		await process_frame
	check(false, "Complete preview preparation must finish")

func _settle_partial(scene: Node) -> void:
	for frame: int in range(400):
		if not (scene.get("_committed_hand_query_previews") as Dictionary).is_empty(): return
		await process_frame
	check(false, "Partial preview preparation must begin")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

extends SceneTree
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")
var failures: Array[String]
func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	var choices: Array = [[], ["quick_wits", "encore", "prismatic_instinct", "rehearsed_escape", "makeshift_tool", "carry_the_guard"], ["layaway", "quick_wits", "quick_wits", "unknown"], ["long_dawn", "open_sky"], null, "unknown"]
	for choice: Variant in choices:
		for count: int in [0, 1, 5, 13, 19, 24]:
			for preference: Variant in [[], ["rehearsed_escape", "quick_wits", "encore"]]:
				var expected: Array[String] = _original_repaired_selection(choice, count, preference)
				var actual: Array[String] = SkillTreeLibrary.repaired_selection(choice, count, preference)
				check(actual == expected, "Cold repair equals original ordered algorithm")
				actual.append("caller mutation")
				check(SkillTreeLibrary.repaired_selection(choice, count, preference) == expected, "Warm repair owns its returned array")
	for schema: int in range(1, 9):
		for level: int in [0, 1, 6, 14, 20, 90]:
			for choice: Variant in choices:
				var source: Dictionary = {"progression_schema": schema, "level": level, "skill_ids": choice, "stats": {"might": 4, "air_magick": 3}, "moltshards": -7 if level < 6 else 13, "completed_run_results": [{"result_id": "previous", "outcome": "defeat", "stats": {"damage_dealt": 50}}], "progression_analytics_outbox": [{"event_type": " skill_triggered ", "idempotency_key": " key ", "context": {"player_hp": 110, "progression_skills": ["quick_wits"]}, "payload": {"amount": 30}}, {"event_type": "ignored duplicate", "idempotency_key": "key"}, "bad entry"]}
				var before: Dictionary = source.duplicate(true)
				var normalized: Dictionary = ProgressionStore.normalized_data(source)
				check(ProgressionStore.selected_skill_ids(source) == SkillTreeLibrary.normalized_ids(normalized["skill_ids"]), "Skill reader retains every schema/level/retired migration")
				check(ProgressionStore.moltshard_count(source) == normalized["moltshards"], "Currency reader retains missing/negative migration")
				var outbox: Array[Dictionary] = ProgressionStore.progression_analytics_outbox(source)
				check(outbox == normalized["progression_analytics_outbox"], "Outbox reader retains legacy unit conversion, validation and ordering")
				if not outbox.is_empty(): outbox[0]["context"]["player_hp"] = -1000
				check(source == before, "Getters and returned payloads cannot mutate caller profile")
	_test_definition_replacement()
	SkillTreeLibrary.clear_cache()
	check(SkillTreeLibrary._repair_cache.is_empty(), "Data reload clears repair cache")
	for count: int in range(90):
		SkillTreeLibrary.repaired_selection(["quick_wits"], count % 20, SkillTreeLibrary.ordered_ids().slice(count % 29))
	check(SkillTreeLibrary._repair_cache.size() <= SkillTreeLibrary.REPAIR_CACHE_LIMIT, "Repair cache is bounded")
	print("TEST RESULT: %s — profile read and repair equivalence (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _original_repaired_selection(value: Variant, target_count: int, preferred_order: Variant = []) -> Array[String]:
	var safe_target: int = clampi(target_count, 0, maxi(0, SkillTreeLibrary.definitions().size()))
	var source: Array[String] = SkillTreeLibrary.normalized_ids(value)
	var preference: Array[String] = SkillTreeLibrary._unique_known_ids(preferred_order)
	for skill_id: String in source:
		if not preference.has(skill_id):
			preference.append(skill_id)
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		if not preference.has(skill_id):
			preference.append(skill_id)
	var result: Array[String]
	var progress: bool = true
	while result.size() < safe_target and progress:
		progress = false
		for skill_id: String in preference:
			if result.size() >= safe_target:
				break
			if result.has(skill_id) or not source.has(skill_id):
				continue
			var retired_candidate: Array[String] = result.duplicate()
			retired_candidate.append(skill_id)
			var preserves_retired_skill: bool = SkillTreeLibrary.is_retired(skill_id) and SkillTreeLibrary.selection_is_valid(retired_candidate)
			if SkillTreeLibrary.is_available(skill_id, result) or preserves_retired_skill:
				result.append(skill_id)
				progress = true
	while result.size() < safe_target:
		var available: Array[String] = SkillTreeLibrary.available_ids(result)
		if available.is_empty():
			break
		var chosen_id: String = ""
		for skill_id: String in preference:
			if available.has(skill_id):
				chosen_id = skill_id
				break
		if chosen_id.is_empty():
			chosen_id = available[0]
		result.append(chosen_id)
	return result

func _test_definition_replacement() -> void:
	var original: Dictionary = SkillTreeLibrary.definitions()
	var selected: Array[String]
	selected.append("quick_wits")
	var before: Array[String] = SkillTreeLibrary.repaired_selection(selected, 1, selected)
	var replacement: Dictionary = original.duplicate(true)
	replacement["quick_wits"]["prerequisites"] = ["encore"]
	SkillTreeLibrary._cache = replacement
	SkillTreeLibrary._ordered_ids_cache.clear()
	SkillTreeLibrary._completion_cache.clear()
	var expected: Array[String] = _original_repaired_selection(selected, 1, selected)
	check(expected != before, "Replacement fixture must change the answer for identical inputs")
	check(SkillTreeLibrary.repaired_selection(selected, 1, selected) == expected, "Replacing definitions invalidates a warm repair key")
	SkillTreeLibrary._cache = original
	SkillTreeLibrary._ordered_ids_cache.clear()
	SkillTreeLibrary._completion_cache.clear()
	check(SkillTreeLibrary.repaired_selection(selected, 1, selected) == _original_repaired_selection(selected, 1, selected), "Restoring definitions also invalidates the same warm key")

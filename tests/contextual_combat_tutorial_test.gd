extends SceneTree

const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")

const STORAGE_PATH: String = "user://contextual_combat_tutorial_test_progression.json"
const RUN_STORAGE_PATH: String = "user://contextual_combat_tutorial_test_run.save"

var _failures: Array[String]

func _initialize() -> void:
	ProgressionStore.set_storage_path(STORAGE_PATH)
	ProgressionStore.set_run_storage_path(RUN_STORAGE_PATH)
	_remove_test_files()
	_test_curriculum_catalog()
	_test_new_and_returning_profile_migration()
	_test_milestones_and_revision_semantics()
	_test_terminal_states_and_replay()
	_test_merge_semantics()
	_test_compatibility_suppression()
	_test_save_and_load_round_trip()
	_remove_test_files()
	if _failures.is_empty():
		print("CONTEXTUAL COMBAT TUTORIAL TEST: PASS")
		quit()
		return
	for failure: String in _failures:
		push_error(failure)
	print("CONTEXTUAL COMBAT TUTORIAL TEST: FAIL (%d)" % _failures.size())
	quit(1)

func _test_curriculum_catalog() -> void:
	var phases: Array[String] = ContextualCombatTutorial.phase_ids()
	var milestones: Array[String] = ContextualCombatTutorial.milestone_ids()
	_assert(phases.size() == 23, "Authored curriculum should expose all twenty-three motor, rule, and decision phases")
	_assert(milestones.size() == 14, "Authored curriculum should persist exactly fourteen committed milestones")
	_assert(phases.front() == ContextualCombatTutorial.PHASE_SELECT_PLAYER, "Curriculum should begin by selecting the player")
	_assert(phases.back() == ContextualCombatTutorial.PHASE_COMPLETE, "Curriculum should end with an explicit completion phase")
	for phase_id: String in phases:
		var definition: Dictionary = ContextualCombatTutorial.phase_definition(phase_id)
		_assert(str(definition.get("id", "")) == phase_id, "%s should have a stable phase definition" % phase_id)
		_assert(not str(definition.get("title", "")).is_empty(), "%s should have a concise player-facing title" % phase_id)
		_assert(not str(definition.get("pointer_text", "")).is_empty(), "%s should provide pointer instructions" % phase_id)
		_assert(not str(definition.get("controller_text", "")).is_empty(), "%s should provide controller instructions" % phase_id)
		_assert(int(definition.get("lesson", 0)) in range(1, 11), "%s should belong to one of ten lessons" % phase_id)
	var select_player: Dictionary = ContextualCombatTutorial.phase_definition(ContextualCombatTutorial.PHASE_SELECT_PLAYER)
	_assert(str(select_player.get("pointer_text", "")) == "Click the glowing tile to choose a move.", "Step one should describe choosing a move without plan language")
	var choose_move: Dictionary = ContextualCombatTutorial.phase_definition(ContextualCombatTutorial.PHASE_CHOOSE_MOVE)
	_assert(str(choose_move.get("pointer_text", "")) == "You begin each turn with 2 movement. Use 1 to move onto the glowing tile.", "The destination prompt should teach the movement allowance before the action")
	var select_bone_dart: Dictionary = ContextualCombatTutorial.phase_definition(ContextualCombatTutorial.PHASE_SELECT_CARD_FOR_CANCEL)
	_assert(str(select_bone_dart.get("title", "")) == "Select Bone Dart", "Step three should directly tell the player to select Bone Dart")
	_assert(ContextualCombatTutorial.phase_definition("unknown_phase").is_empty(), "Unknown phases should not synthesize tutorial content")

func _test_new_and_returning_profile_migration() -> void:
	var fresh: Dictionary = ProgressionStore.default_data()
	var fresh_state: Dictionary = ContextualCombatTutorial.state_from_progression(fresh)
	_assert(int(fresh.get("progression_schema", 0)) == 7, "New profiles should use progression schema 7")
	_assert(str(fresh_state.get("status", "")) == ContextualCombatTutorial.STATUS_ACTIVE, "New profiles should begin the guide")
	_assert(int(fresh_state.get("version", 0)) == ContextualCombatTutorial.VERSION, "New profiles should store the tutorial record version")

	var pre_tutorial_fresh: Dictionary = _schema_six_profile(0)
	var migrated_fresh: Dictionary = ProgressionStore.normalized_data(pre_tutorial_fresh)
	_assert(ContextualCombatTutorial.is_active(migrated_fresh), "A never-played schema-6 profile should enter onboarding")

	var legacy_notes: Dictionary = _schema_six_profile(0)
	legacy_notes[ContextualCombatTutorial.LEGACY_PROGRESSION_KEY] = {"full_card_fallback": "completed"}
	var migrated_notes: Dictionary = ProgressionStore.normalized_data(legacy_notes)
	_assert(ContextualCombatTutorial.is_active(migrated_notes), "Profiles that saw the retired combat notes should receive the authored guide once")
	_assert(ContextualCombatTutorial.completed_steps(migrated_notes).is_empty(), "Retired combat notes should not skip any authored tutorial steps")
	_assert(not migrated_notes.has(ContextualCombatTutorial.LEGACY_PROGRESSION_KEY), "Migration should erase the retired prompt-state key")

	var returning: Dictionary = ProgressionStore.normalized_data(_schema_six_profile(3))
	_assert(ContextualCombatTutorial.is_active(returning), "Returning profiles without tutorial state should receive the authored guide once")
	_assert(ContextualCombatTutorial.completed_steps(returning).is_empty(), "Returning profiles should begin the authored guide at its first step")

	var formerly_exempt: Dictionary = _schema_six_profile(7)
	formerly_exempt[ContextualCombatTutorial.PROGRESSION_KEY] = {
		"version": ContextualCombatTutorial.VERSION,
		"status": ContextualCombatTutorial.STATUS_LEGACY_EXEMPT,
		"completed_steps": [ContextualCombatTutorial.MILESTONE_CARD],
	}
	var migrated_exempt: Dictionary = ProgressionStore.normalized_data(formerly_exempt)
	_assert(ContextualCombatTutorial.is_active(migrated_exempt), "A persisted legacy exemption should migrate to unseen onboarding")
	_assert(ContextualCombatTutorial.completed_steps(migrated_exempt).is_empty(), "Legacy exemption migration should restart at the authored scenario's first step")

	var malformed: Dictionary = _schema_six_profile(4)
	malformed[ContextualCombatTutorial.PROGRESSION_KEY] = {
		"version": -8,
		"status": "surprise",
		"completed_steps": [
			ContextualCombatTutorial.MILESTONE_CARD,
			"not_a_step",
			ContextualCombatTutorial.MILESTONE_MOVE,
			ContextualCombatTutorial.MILESTONE_CARD,
		],
	}
	var repaired: Dictionary = ProgressionStore.normalized_data(malformed)
	var repaired_state: Dictionary = ContextualCombatTutorial.state_from_progression(repaired)
	_assert(str(repaired_state.get("status", "")) == ContextualCombatTutorial.STATUS_ACTIVE, "Malformed tutorial status should safely restart unseen onboarding")
	_assert(int(repaired_state.get("version", 0)) == ContextualCombatTutorial.VERSION, "Malformed versions should normalize to the current record version")
	_assert((repaired_state.get("completed_steps", []) as Array).is_empty(), "Malformed tutorial state should not strand a profile partway through the authored scenario")
	_assert(ProgressionStore.normalized_data(repaired) == repaired, "Tutorial profile migration should be idempotent")

	var completed_returning: Dictionary = _schema_six_profile(9)
	completed_returning[ContextualCombatTutorial.PROGRESSION_KEY] = ContextualCombatTutorial.complete_tutorial(ProgressionStore.default_data()).get(ContextualCombatTutorial.PROGRESSION_KEY, {})
	completed_returning = ProgressionStore.normalized_data(completed_returning)
	_assert(ContextualCombatTutorial.is_completed(completed_returning), "A completed tutorial flag should remain terminal for returning profiles")

	var dismissed_returning: Dictionary = _schema_six_profile(11)
	dismissed_returning[ContextualCombatTutorial.PROGRESSION_KEY] = ContextualCombatTutorial.dismiss_tutorial(ProgressionStore.default_data()).get(ContextualCombatTutorial.PROGRESSION_KEY, {})
	dismissed_returning = ProgressionStore.normalized_data(dismissed_returning)
	_assert(not ContextualCombatTutorial.is_active(dismissed_returning), "A skipped tutorial flag should remain terminal for returning profiles")
	_assert(str(ContextualCombatTutorial.state_from_progression(dismissed_returning).get("status", "")) == ContextualCombatTutorial.STATUS_DISMISSED, "A skipped tutorial should not reappear on later profile loads")

func _test_milestones_and_revision_semantics() -> void:
	var original: Dictionary = ProgressionStore.default_data()
	var invalid: Dictionary = ContextualCombatTutorial.complete_milestone(original, "hovered_something")
	_assert(invalid == original, "Transient or unknown events should not change tutorial persistence")

	var progression: Dictionary = ContextualCombatTutorial.complete_milestone(original, ContextualCombatTutorial.MILESTONE_CARD)
	_assert(int(progression.get("progression_revision", -1)) == 1, "A newly committed milestone should increment progression revision once")
	_assert(ContextualCombatTutorial.has_completed(progression, ContextualCombatTutorial.MILESTONE_CARD), "Committed milestones should be queryable")
	_assert(not ContextualCombatTutorial.has_completed(original, ContextualCombatTutorial.MILESTONE_CARD), "Milestone updates should not mutate their input dictionary")

	var duplicate: Dictionary = ContextualCombatTutorial.complete_milestone(progression, ContextualCombatTutorial.MILESTONE_CARD)
	_assert(duplicate == progression, "Repeating a committed milestone should be idempotent")
	progression = ContextualCombatTutorial.complete_milestone(progression, ContextualCombatTutorial.MILESTONE_MOVE)
	_assert(
		ContextualCombatTutorial.completed_steps(progression) == _strings([ContextualCombatTutorial.MILESTONE_MOVE, ContextualCombatTutorial.MILESTONE_CARD]),
		"Out-of-order commits should persist in stable curriculum order"
	)

	for milestone_id: String in ContextualCombatTutorial.milestone_ids():
		progression = ContextualCombatTutorial.complete_milestone(progression, milestone_id)
	_assert(ContextualCombatTutorial.is_active(progression), "Committed milestones alone should leave the final acknowledgement available")
	progression = ContextualCombatTutorial.complete_tutorial(progression)
	_assert(ContextualCombatTutorial.is_completed(progression), "Explicit final acknowledgement should complete onboarding")
	_assert(ContextualCombatTutorial.completed_steps(progression).size() == ContextualCombatTutorial.milestone_ids().size(), "Completion should seal every milestone")
	_assert(int(progression.get("progression_revision", -1)) == 15, "Fourteen milestone commits plus completion should produce fifteen revisions")

func _test_terminal_states_and_replay() -> void:
	var progression: Dictionary = ProgressionStore.default_data()
	progression = ContextualCombatTutorial.complete_milestone(progression, ContextualCombatTutorial.MILESTONE_MOVE)
	progression = ContextualCombatTutorial.dismiss_tutorial(progression)
	var dismissed_revision: int = int(progression.get("progression_revision", -1))
	_assert(not ContextualCombatTutorial.is_active(progression), "Dismissal should suppress onboarding")
	_assert(str(ContextualCombatTutorial.state_from_progression(progression).get("status", "")) == ContextualCombatTutorial.STATUS_DISMISSED, "Dismissal should use a durable terminal status")
	_assert(ContextualCombatTutorial.complete_milestone(progression, ContextualCombatTutorial.MILESTONE_CARD) == progression, "Dismissed onboarding should ignore later gameplay milestones")
	_assert(ContextualCombatTutorial.dismiss_tutorial(progression) == progression, "Repeated dismissal should be idempotent")
	_assert(ContextualCombatTutorial.complete_tutorial(progression) == progression, "Final acknowledgement should not overwrite a prior dismissal")

	progression = ContextualCombatTutorial.restart_tutorial(progression)
	_assert(ContextualCombatTutorial.is_active(progression), "Replay should reactivate onboarding")
	_assert(ContextualCombatTutorial.completed_steps(progression).is_empty(), "Replay should reset only tutorial milestones")
	_assert(int(progression.get("progression_revision", -1)) == dismissed_revision + 1, "Replay should increment progression revision once")
	_assert(int(progression.get("run_counter", -1)) == 0, "Replay should preserve unrelated profile fields")
	var completed: Dictionary = ContextualCombatTutorial.complete_tutorial(progression)
	_assert(ContextualCombatTutorial.dismiss_tutorial(completed) == completed, "Dismissal should not overwrite prior completion without an explicit replay")

func _test_merge_semantics() -> void:
	var profile: Dictionary = ProgressionStore.default_data()
	profile = ContextualCombatTutorial.complete_milestone(profile, ContextualCombatTutorial.MILESTONE_CARD)
	var embedded: Dictionary = ProgressionStore.default_data()
	embedded = ContextualCombatTutorial.complete_milestone(embedded, ContextualCombatTutorial.MILESTONE_MOVE)
	var merged: Dictionary = ContextualCombatTutorial.merged_state(profile, embedded)
	_assert(
		(merged.get("completed_steps", []) as Array) == [ContextualCombatTutorial.MILESTONE_MOVE, ContextualCombatTutorial.MILESTONE_CARD],
		"Profile/run reconciliation should union committed milestones in curriculum order"
	)
	_assert(str(merged.get("status", "")) == ContextualCombatTutorial.STATUS_ACTIVE, "An active profile and run should remain active after reconciliation")

	var completed_profile: Dictionary = ContextualCombatTutorial.complete_tutorial(profile)
	merged = ContextualCombatTutorial.merged_state(embedded, completed_profile)
	_assert(str(merged.get("status", "")) == ContextualCombatTutorial.STATUS_COMPLETED, "Completion should win over a stale active copy")
	_assert((merged.get("completed_steps", []) as Array).size() == ContextualCombatTutorial.milestone_ids().size(), "Completed reconciliation should include the entire curriculum")

func _test_compatibility_suppression() -> void:
	var progression: Dictionary = ProgressionStore.default_data()
	for prompt_id: String in ContextualCombatTutorial.prompt_ids():
		_assert(not ContextualCombatTutorial.prompt_definition(prompt_id).is_empty(), "Compatibility prompt %s should map to representative guide content" % prompt_id)
		progression = ContextualCombatTutorial.resolve_progression(progression, prompt_id)
	_assert(ContextualCombatTutorial.is_completed(progression), "Resolving every compatibility prompt should fully suppress onboarding in unrelated probes")
	_assert(ContextualCombatTutorial.states_from_progression(progression).size() == ContextualCombatTutorial.milestone_ids().size(), "Compatibility state maps should report every resolved milestone")

	var skipped: Dictionary = ContextualCombatTutorial.resolve_progression(ProgressionStore.default_data(), ContextualCombatTutorial.MILESTONE_MOVE, true)
	_assert(str(ContextualCombatTutorial.state_from_progression(skipped).get("status", "")) == ContextualCombatTutorial.STATUS_DISMISSED, "Compatibility skip should dismiss the complete guide, not one transient phase")

func _test_save_and_load_round_trip() -> void:
	var progression: Dictionary = ProgressionStore.default_data()
	progression["embers"] = 17
	progression = ContextualCombatTutorial.complete_milestone(progression, ContextualCombatTutorial.MILESTONE_MOVE)
	progression = ContextualCombatTutorial.complete_milestone(progression, ContextualCombatTutorial.MILESTONE_INTENT)
	_assert(ProgressionStore.save_data(progression), "Tutorial progression should save transactionally")
	var loaded: Dictionary = ProgressionStore.load_data()
	_assert(ContextualCombatTutorial.state_from_progression(loaded) == ContextualCombatTutorial.state_from_progression(progression), "Versioned tutorial state should survive profile reload")
	_assert(int(loaded.get("progression_revision", -1)) == int(progression.get("progression_revision", -2)), "Tutorial revision should survive profile reload")
	_assert(int(loaded.get("embers", -1)) == 17, "Tutorial persistence should preserve unrelated profile progression")

	var skipped: Dictionary = ContextualCombatTutorial.dismiss_tutorial(loaded)
	_assert(ProgressionStore.save_data(skipped), "Skipping the tutorial should persist its terminal flag")
	var loaded_skipped: Dictionary = ProgressionStore.load_data()
	_assert(str(ContextualCombatTutorial.state_from_progression(loaded_skipped).get("status", "")) == ContextualCombatTutorial.STATUS_DISMISSED, "A saved skip flag should suppress the tutorial after reload")
	_assert(int(loaded_skipped.get("embers", -1)) == 17, "Skipping the tutorial should preserve unrelated profile progression")

	var completed: Dictionary = ContextualCombatTutorial.complete_tutorial(ContextualCombatTutorial.restart_tutorial(loaded_skipped))
	_assert(ProgressionStore.save_data(completed), "Completing the tutorial should persist its terminal flag")
	var loaded_completed: Dictionary = ProgressionStore.load_data()
	_assert(ContextualCombatTutorial.is_completed(loaded_completed), "A saved completion flag should suppress the tutorial after reload")
	_assert(int(loaded_completed.get("embers", -1)) == 17, "Completing the tutorial should preserve unrelated profile progression")

func _schema_six_profile(run_counter: int) -> Dictionary:
	var profile: Dictionary = ProgressionStore.default_data()
	profile["progression_schema"] = 6
	profile["run_counter"] = run_counter
	profile.erase(ContextualCombatTutorial.PROGRESSION_KEY)
	return profile

func _strings(values: Array) -> Array[String]:
	var result: Array[String]
	for value: Variant in values:
		result.append(str(value))
	return result

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _remove_test_files() -> void:
	for path: String in [
		STORAGE_PATH,
		STORAGE_PATH + ".backup",
		STORAGE_PATH + ".tmp",
		RUN_STORAGE_PATH,
		RUN_STORAGE_PATH + ".backup",
		RUN_STORAGE_PATH + ".tmp",
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

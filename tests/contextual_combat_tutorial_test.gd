extends SceneTree

const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const GrimoireLibrary = preload("res://scripts/grimoire_library.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")

const STORAGE_PATH: String = "user://contextual_combat_tutorial_test_progression.json"
const RUN_STORAGE_PATH: String = "user://contextual_combat_tutorial_test_run.save"

var _failures: Array[String] = []

func _initialize() -> void:
	ProgressionStore.set_storage_path(STORAGE_PATH)
	ProgressionStore.set_run_storage_path(RUN_STORAGE_PATH)
	_remove_if_present(STORAGE_PATH)
	_remove_if_present(RUN_STORAGE_PATH)
	_test_exact_prompt_catalog()
	_test_contextual_sequence_and_priority()
	_test_skip_and_completion_persist()
	_test_returning_profile_and_suppression()
	if _failures.is_empty():
		print("CONTEXTUAL COMBAT TUTORIAL TEST: PASS")
		quit()
		return
	for failure: String in _failures:
		push_error(failure)
	print("CONTEXTUAL COMBAT TUTORIAL TEST: FAIL (%d)" % _failures.size())
	quit(1)

func _test_exact_prompt_catalog() -> void:
	var expected: Array[String] = [
		ContextualCombatTutorial.FULL_CARD_FALLBACK,
		ContextualCombatTutorial.SELECT_TARGET,
		ContextualCombatTutorial.CANCEL_OPTIONAL,
		ContextualCombatTutorial.PASS_CONSEQUENCE,
		ContextualCombatTutorial.TIMELINE_READING
	]
	var prompt_ids: Array[String] = ContextualCombatTutorial.prompt_ids()
	_assert(prompt_ids.size() == 5, "Tutorial should define exactly five prompts")
	for prompt_id: String in expected:
		_assert(prompt_ids.has(prompt_id), "Tutorial should include %s" % prompt_id)
		var prompt: Dictionary = ContextualCombatTutorial.prompt_definition(prompt_id)
		var text: String = str(prompt.get("text", ""))
		_assert(not text.is_empty() and not text.contains("\n"), "%s should use one terse line" % prompt_id)
		_assert(text.split(" ", false).size() <= 16, "%s should stay at or below sixteen words" % prompt_id)
		_assert(not str(prompt.get("icon", "")).is_empty(), "%s should be icon-led" % prompt_id)
		_assert(not GrimoireLibrary.entry_def(str(prompt.get("grimoire_entry", ""))).is_empty(), "%s should deep-link to an existing Grimoire entry" % prompt_id)

func _test_contextual_sequence_and_priority() -> void:
	var progression: Dictionary = ProgressionStore.default_data()
	progression["run_counter"] = 1
	var context: Dictionary = _base_context()
	_assert_prompt(context, progression, ContextualCombatTutorial.FULL_CARD_FALLBACK, "fresh combat")

	progression = ContextualCombatTutorial.resolve_progression(progression, ContextualCombatTutorial.FULL_CARD_FALLBACK)
	context["card_time_preview"] = true
	_assert_prompt(context, progression, ContextualCombatTutorial.TIMELINE_READING, "card hover")

	context["card_selected"] = true
	context["card_time_preview"] = false
	context["target_required"] = true
	context["target_count"] = 4
	context["optional_step"] = true
	_assert_prompt(context, progression, ContextualCombatTutorial.SELECT_TARGET, "target selection should outrank optional-step help")

	progression = ContextualCombatTutorial.resolve_progression(progression, ContextualCombatTutorial.SELECT_TARGET)
	_assert_prompt(context, progression, ContextualCombatTutorial.CANCEL_OPTIONAL, "optional compound step")

	progression = ContextualCombatTutorial.resolve_progression(progression, ContextualCombatTutorial.CANCEL_OPTIONAL)
	context["card_selected"] = false
	context["target_required"] = false
	context["target_count"] = 0
	context["optional_step"] = false
	context["card_time_preview"] = true
	_assert_prompt(context, progression, ContextualCombatTutorial.TIMELINE_READING, "timeline after compound step")

	progression = ContextualCombatTutorial.resolve_progression(progression, ContextualCombatTutorial.TIMELINE_READING)
	context["card_time_preview"] = false
	_assert_prompt(context, progression, ContextualCombatTutorial.PASS_CONSEQUENCE, "pass consequence")

	progression = ContextualCombatTutorial.resolve_progression(progression, ContextualCombatTutorial.PASS_CONSEQUENCE)
	_assert(ContextualCombatTutorial.next_prompt(context, progression).is_empty(), "Resolved tutorial should not offer a sixth prompt")

func _test_skip_and_completion_persist() -> void:
	var progression: Dictionary = ProgressionStore.default_data()
	progression["run_counter"] = 1
	progression = ContextualCombatTutorial.resolve_progression(progression, ContextualCombatTutorial.FULL_CARD_FALLBACK)
	progression = ContextualCombatTutorial.resolve_progression(progression, ContextualCombatTutorial.CANCEL_OPTIONAL, true)
	_assert(ProgressionStore.save_data(progression), "Tutorial progression should save")
	var loaded: Dictionary = ProgressionStore.load_data()
	var states: Dictionary = ContextualCombatTutorial.states_from_progression(loaded)
	_assert(str(states.get(ContextualCombatTutorial.FULL_CARD_FALLBACK, "")) == ContextualCombatTutorial.STATUS_COMPLETED, "Completion should persist")
	_assert(str(states.get(ContextualCombatTutorial.CANCEL_OPTIONAL, "")) == ContextualCombatTutorial.STATUS_SKIPPED, "Skip should persist")
	var malformed: Dictionary = {
		ContextualCombatTutorial.FULL_CARD_FALLBACK: "unknown",
		"door_tutorial": ContextualCombatTutorial.STATUS_COMPLETED
	}
	_assert(ContextualCombatTutorial.normalized_states(malformed).is_empty(), "Unknown statuses and concepts should not enter the prompt state")

func _test_returning_profile_and_suppression() -> void:
	var returning: Dictionary = ProgressionStore.default_data()
	returning["run_counter"] = 2
	_assert(ContextualCombatTutorial.next_prompt(_base_context(), returning).is_empty(), "Returning profiles without first-run state should not begin onboarding")
	var context: Dictionary = _base_context()
	context["suppressed"] = true
	_assert(ContextualCombatTutorial.next_prompt(context, ProgressionStore.default_data()).is_empty(), "Prompts should hide while another presentation owns the screen")
	context["suppressed"] = false
	context["player_turn"] = false
	_assert(ContextualCombatTutorial.next_prompt(context, ProgressionStore.default_data()).is_empty(), "Prompts should wait for the player's turn")

func _base_context() -> Dictionary:
	return {
		"mode": "combat",
		"player_turn": true,
		"hand_count": 3,
		"card_selected": false,
		"target_required": false,
		"target_count": 0,
		"optional_step": false,
		"pass_available": true,
		"pass_preview_visible": true,
		"timeline_visible": true,
		"card_time_preview": false,
		"suppressed": false
	}

func _assert_prompt(context: Dictionary, progression: Dictionary, expected_id: String, label: String) -> void:
	var prompt: Dictionary = ContextualCombatTutorial.next_prompt(context, progression)
	_assert(str(prompt.get("id", "")) == expected_id, "%s should offer %s, got %s" % [label, expected_id, str(prompt.get("id", "<none>"))])

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

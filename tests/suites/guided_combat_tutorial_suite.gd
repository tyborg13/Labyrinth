extends RefCounted

const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const ContextualCombatPrompt = preload("res://scripts/contextual_combat_prompt.gd")
const HandFanContainerScript = preload("res://scripts/hand_fan_container.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const ReplayRunSceneHarness = preload("res://tests/fixtures/guided_tutorial_run_scene_harness.gd")

const PLAYER_TILE: Vector2i = Vector2i(2, 3)
const MOVE_TILE: Vector2i = Vector2i(3, 3)
const ENEMY_TILE: Vector2i = Vector2i(5, 3)
const OTHER_ENEMY_TILE: Vector2i = Vector2i(6, 4)
const WRONG_TILE: Vector2i = Vector2i(8, 7)
const INVALID_TILE: Vector2i = Vector2i(-1, -1)


class TutorialPromptStub:
	extends Control

	var configure_count: int = 0
	var clear_count: int = 0
	var blocked_messages: Array[String] = []
	var configured_phase_id: String = ""
	var configured_spotlights: Array = []

	func configure(definition: Dictionary, spotlights: Array, _avoid_rects: Array, _reduced_motion: bool) -> void:
		configure_count += 1
		configured_phase_id = str(definition.get("id", ""))
		configured_spotlights = spotlights.duplicate()

	func update_geometry(spotlights: Array, _avoid_rects: Array) -> void:
		configured_spotlights = spotlights.duplicate()

	func clear_prompt() -> void:
		clear_count += 1
		configured_phase_id = ""

	func show_blocked(message: String) -> void:
		blocked_messages.append(message)

	func focus_primary_action() -> void:
		pass


class BoardNavigationStub:
	extends Node

	var navigable_tiles: Array[Vector2i] = []

	func controller_navigable_tiles(_include_visible_doors: bool = false) -> Array[Vector2i]:
		return navigable_tiles.duplicate()


class BoardPresentationStub:
	extends Control

	var submission_count: int = 0
	var last_presentation: Dictionary = {}
	var rendered_bounds: Rect2 = Rect2(Vector2(100.0, 120.0), Vector2(1200.0, 720.0))

	func rendered_visual_bounds() -> Rect2:
		return rendered_bounds

	func set_combat_state(
		_next_state: Dictionary,
		_next_move_tiles: Array = [],
		_next_attack_tiles: Array = [],
		_next_selected_tile: Vector2i = INVALID_TILE,
		_next_status_label: String = "",
		_next_status_detail: String = "",
		_next_exit_tiles: Dictionary = {},
		_next_exit_icon_ids: Dictionary = {},
		next_presentation: Dictionary = {},
		_trust_same_reference_state: bool = false
	) -> void:
		submission_count += 1
		last_presentation = next_presentation.duplicate(true)


static func run(expect: Callable) -> void:
	_test_blocked_feedback_clears_only_on_phase_change(expect)
	_test_first_run_phase_derivation(expect)
	_test_hard_gate_blocks_wrong_actions_without_mutation(expect)
	_test_action_only_advancement(expect)
	_test_intent_confirmation_pins_exact_enemy_evidence(expect)
	_test_intent_confirmation_owns_rendered_evidence(expect)
	_test_forced_tutorial_blocks_skill_surfaces(expect)
	_test_controller_candidate_filtering(expect)
	_test_modal_suspension_and_resume(expect)
	_test_pause_menu_cannot_bypass_optional_surface_gate(expect)
	_test_pre_battle_actions_cannot_bypass_visible_completion_gate(expect)
	_test_skip_replay_and_completion_absence(expect)


static func _test_blocked_feedback_clears_only_on_phase_change(expect: Callable) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var prompt: Control = ContextualCombatPrompt.new()
	tree.root.add_child(prompt)
	var cancel_definition: Dictionary = ContextualCombatTutorial.phase_definition(ContextualCombatTutorial.PHASE_CANCEL_CARD)
	var target_definition: Dictionary = ContextualCombatTutorial.phase_definition(ContextualCombatTutorial.PHASE_SELECT_TARGET)
	prompt.call("configure", cancel_definition, [Rect2(Vector2(100.0, 100.0), Vector2(80.0, 80.0))], [], false)
	prompt.call("show_blocked", "Use Cancel first.")
	var blocked_until: int = int(prompt.get("_blocked_until_msec"))
	var feedback: Label = prompt.get("_feedback") as Label
	expect.call(blocked_until > Time.get_ticks_msec(), "Blocked input should begin a visible error-accent window")
	expect.call(feedback.visible and feedback.text == "Use Cancel first.", "Blocked input should explain the rejected action")

	prompt.call("update_geometry", [Rect2(Vector2(110.0, 100.0), Vector2(80.0, 80.0))], [])
	expect.call(
		int(prompt.get("_blocked_until_msec")) == blocked_until and feedback.visible and feedback.text == "Use Cancel first.",
		"Same-phase geometry refreshes should preserve both blocked accent and explanation"
	)
	prompt.call("configure", cancel_definition, [Rect2(Vector2(120.0, 100.0), Vector2(80.0, 80.0))], [], false)
	expect.call(
		int(prompt.get("_blocked_until_msec")) == blocked_until and feedback.visible and feedback.text == "Use Cancel first.",
		"Same-phase presentation refreshes should preserve both blocked accent and explanation"
	)

	prompt.call("configure", target_definition, [Rect2(Vector2(300.0, 220.0), Vector2(80.0, 80.0))], [], false)
	expect.call(
		int(prompt.get("_blocked_until_msec")) == 0 and not feedback.visible,
		"A successful transition to a new tutorial phase should clear the prior error accent and explanation immediately"
	)
	prompt.free()


static func _test_first_run_phase_derivation(expect: Callable) -> void:
	var scene: Node = _combat_fixture()
	scene.call("_guided_tutorial_reconcile_phase")
	expect.call(
		str(scene.get("_guided_tutorial_phase_id")) == ContextualCombatTutorial.PHASE_SELECT_PLAYER,
		"A fresh first-run combat should begin by selecting the player"
	)

	scene.set("_guided_tutorial_phase_id", ContextualCombatTutorial.PHASE_CHOOSE_MOVE)
	scene.set("_player_movement_selected", false)
	scene.call("_guided_tutorial_reconcile_phase")
	expect.call(
		str(scene.get("_guided_tutorial_phase_id")) == ContextualCombatTutorial.PHASE_SELECT_PLAYER,
		"Reloading without a transient movement selection should safely return to selecting the player"
	)

	var progression: Dictionary = scene.get("_progression") as Dictionary
	progression = ContextualCombatTutorial.complete_milestone(progression, ContextualCombatTutorial.MILESTONE_MOVE)
	scene.set("_progression", progression)
	scene.set("_guided_tutorial_phase_id", "")
	scene.call("_guided_tutorial_reconcile_phase")
	expect.call(
		str(scene.get("_guided_tutorial_phase_id")) == ContextualCombatTutorial.PHASE_INSPECT_ENEMY,
		"A resumed run should derive the first incomplete lesson from committed milestones"
	)

	for milestone_id: String in [
		ContextualCombatTutorial.MILESTONE_INTENT,
		ContextualCombatTutorial.MILESTONE_CANCEL,
		ContextualCombatTutorial.MILESTONE_CARD,
		ContextualCombatTutorial.MILESTONE_CLOCK,
		ContextualCombatTutorial.MILESTONE_PASS,
		ContextualCombatTutorial.MILESTONE_CORE,
	]:
		progression = ContextualCombatTutorial.complete_milestone(progression, milestone_id)
	scene.set("_progression", progression)
	scene.set("_guided_tutorial_phase_id", "")
	scene.call("_guided_tutorial_reconcile_phase")
	expect.call(
		str(scene.get("_guided_tutorial_phase_id")).is_empty(),
		"After the combat lesson, the guide should wait quietly for a real reward decision"
	)

	var reward_run_state: Dictionary = scene.get("_run_state") as Dictionary
	reward_run_state["mode"] = "reward"
	reward_run_state["pending_reward"] = {"cards": ["quick_stab"], "heal_amount": 0}
	scene.set("_run_state", reward_run_state)
	scene.call("_guided_tutorial_reconcile_phase")
	expect.call(
		str(scene.get("_guided_tutorial_phase_id")) == ContextualCombatTutorial.PHASE_CHOOSE_REWARD,
		"The reward lesson should appear only when the reward decision exists"
	)

	progression = ContextualCombatTutorial.complete_milestone(progression, ContextualCombatTutorial.MILESTONE_REWARD)
	scene.set("_progression", progression)
	scene.set("_guided_tutorial_phase_id", "")
	var room_run_state: Dictionary = scene.get("_run_state") as Dictionary
	room_run_state["mode"] = "room"
	scene.set("_run_state", room_run_state)
	scene.set("_exit_destinations_by_tile", {Vector2i(1, 3): Vector2i(0, 1)})
	scene.call("_guided_tutorial_reconcile_phase")
	expect.call(
		str(scene.get("_guided_tutorial_phase_id")) == ContextualCombatTutorial.PHASE_CHOOSE_PATH,
		"The path lesson should derive when an actual doorway choice is available"
	)

	progression = ContextualCombatTutorial.complete_milestone(progression, ContextualCombatTutorial.MILESTONE_PATH)
	scene.set("_progression", progression)
	scene.set("_guided_tutorial_phase_id", "")
	scene.call("_guided_tutorial_reconcile_phase")
	expect.call(
		str(scene.get("_guided_tutorial_phase_id")) == ContextualCombatTutorial.PHASE_COMPLETE,
		"Completing every demonstrated action should derive the explicit final acknowledgement"
	)
	scene.free()


static func _test_hard_gate_blocks_wrong_actions_without_mutation(expect: Callable) -> void:
	var scene: Node = _combat_fixture()
	var prompt := TutorialPromptStub.new()
	scene.add_child(prompt)
	scene.set("_contextual_combat_prompt", prompt)
	scene.set("_guided_tutorial_phase_id", ContextualCombatTutorial.PHASE_SELECT_PLAYER)

	expect.call(bool(scene.call("_guided_tutorial_hard_gate_active")), "A visible active guide phase should hard-gate gameplay input")
	expect.call(bool(scene.call("_guided_tutorial_board_tile_allowed", PLAYER_TILE)), "The spotlighted player tile should remain actionable")
	expect.call(not bool(scene.call("_guided_tutorial_board_tile_allowed", WRONG_TILE)), "An unrelated board tile should be rejected by the hard gate")
	expect.call(not bool(scene.call("_guided_tutorial_card_allowed", 0)), "Cards should remain gated during the movement lesson")

	var run_before: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	var combat_before: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	var phase_before: String = str(scene.get("_guided_tutorial_phase_id"))
	scene.call("_on_board_tile_clicked", WRONG_TILE)
	scene.call("_on_card_pressed", 0)
	expect.call((scene.get("_run_state") as Dictionary) == run_before, "A blocked tile or card should not mutate run state")
	expect.call((scene.get("_combat_state") as Dictionary) == combat_before, "A blocked tile or card should not mutate combat state")
	expect.call(int(scene.get("_selected_card_index")) == -1, "A blocked card should not create a transient selection")
	expect.call(not bool(scene.get("_player_movement_selected")), "A blocked tile should not create a movement selection")
	expect.call(str(scene.get("_guided_tutorial_phase_id")) == phase_before, "Wrong input should never advance the guide")
	expect.call(prompt.blocked_messages.size() == 2, "Each blocked action should produce immediate contextual feedback")
	scene.free()


static func _test_action_only_advancement(expect: Callable) -> void:
	var scene: Node = _combat_fixture()
	scene.set("_guided_tutorial_phase_id", ContextualCombatTutorial.PHASE_INSPECT_ENEMY)
	var display_only_progression: Dictionary = scene.get("_progression") as Dictionary
	expect.call(
		not ContextualCombatTutorial.has_completed(display_only_progression, ContextualCombatTutorial.MILESTONE_INTENT),
		"Displaying an instruction should not persist its milestone"
	)

	var non_gameplay_run_state: Dictionary = scene.get("_run_state") as Dictionary
	non_gameplay_run_state["mode"] = "test_fixture"
	scene.set("_run_state", non_gameplay_run_state)
	scene.call("_on_board_tile_hovered", ENEMY_TILE)
	expect.call(
		str(scene.get("_guided_tutorial_phase_id")) == ContextualCombatTutorial.PHASE_CONFIRM_INTENT,
		"Inspecting the highlighted enemy should reach a stable acknowledgement instead of auto-dismissal"
	)
	expect.call(
		not ContextualCombatTutorial.has_completed(scene.get("_progression") as Dictionary, ContextualCombatTutorial.MILESTONE_INTENT),
		"Hovering an enemy should not count as reading the intent until the player acknowledges it"
	)

	var revision_before: int = int((scene.get("_progression") as Dictionary).get("progression_revision", 0))
	scene.call("_on_contextual_combat_prompt_completed", ContextualCombatTutorial.PHASE_TURN_CLOCK)
	expect.call(
		int((scene.get("_progression") as Dictionary).get("progression_revision", 0)) == revision_before,
		"A stale prompt completion signal should not advance another phase"
	)

	# Keep the integration hook focused on profile state; committed run-state
	# checkpoint behavior has its own save-boundary coverage.
	scene.set("_run_state", {})
	scene.call("_on_contextual_combat_prompt_completed", ContextualCombatTutorial.PHASE_CONFIRM_INTENT)
	expect.call(
		ContextualCombatTutorial.has_completed(scene.get("_progression") as Dictionary, ContextualCombatTutorial.MILESTONE_INTENT),
		"The explicit acknowledgement action should commit the enemy-intent milestone"
	)
	expect.call(
		str(scene.get("_guided_tutorial_phase_id")) == ContextualCombatTutorial.PHASE_SELECT_CARD_FOR_CANCEL,
		"Acknowledging enemy intent should advance to the next actionable lesson"
	)
	scene.free()


static func _test_intent_confirmation_pins_exact_enemy_evidence(expect: Callable) -> void:
	var scene: Node = _combat_fixture()
	var combat_state: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	var enemies: Array = (combat_state.get("enemies", []) as Array).duplicate(true)
	enemies.append({"id": 2, "type": "crawler", "pos": OTHER_ENEMY_TILE, "hp": 12, "max_hp": 12})
	combat_state["enemies"] = enemies
	scene.set("_combat_state", combat_state)
	scene.set("_preview_combat_state", combat_state.duplicate(true))
	var fixture_run_state: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	fixture_run_state["mode"] = "test_fixture"
	fixture_run_state["combat_state"] = combat_state.duplicate(true)
	scene.set("_run_state", fixture_run_state)
	scene.set("_guided_tutorial_phase_id", ContextualCombatTutorial.PHASE_INSPECT_ENEMY)

	scene.call("_on_board_tile_hovered", ENEMY_TILE)
	expect.call(
		str(scene.get("_guided_tutorial_phase_id")) == ContextualCombatTutorial.PHASE_CONFIRM_INTENT,
		"Inspecting one enemy should enter the explicit intent-confirmation phase"
	)
	expect.call(
		scene.get("_guided_tutorial_intent_enemy_tile") == ENEMY_TILE,
		"Intent confirmation should pin the exact enemy tile that supplied the evidence"
	)
	var progression_revision: int = int((scene.get("_progression") as Dictionary).get("progression_revision", 0))

	scene.call("_on_board_tile_hovered", INVALID_TILE)
	expect.call(scene.get("_hovered_board_tile") == ENEMY_TILE, "Leaving the board should preserve the pinned enemy-intent evidence")
	scene.call("_on_board_tile_hovered", OTHER_ENEMY_TILE)
	expect.call(scene.get("_hovered_board_tile") == ENEMY_TILE, "Hovering another enemy should not replace the pinned intent evidence")
	expect.call(
		scene.get("_guided_tutorial_intent_enemy_tile") == ENEMY_TILE,
		"Invalid or competing hover input should not change the pinned tutorial enemy"
	)
	var allowed_tiles: Array[Vector2i] = scene.call("_guided_tutorial_allowed_board_tiles") as Array[Vector2i]
	expect.call(allowed_tiles == _tiles([ENEMY_TILE]), "The hard gate should retain only the enemy whose intent is awaiting confirmation")
	expect.call(
		int((scene.get("_progression") as Dictionary).get("progression_revision", 0)) == progression_revision
		and not ContextualCombatTutorial.has_completed(scene.get("_progression") as Dictionary, ContextualCombatTutorial.MILESTONE_INTENT),
		"Hovering away from pinned evidence should neither persist nor complete the intent lesson"
	)

	scene.set("_run_state", {})
	scene.call("_on_contextual_combat_prompt_completed", ContextualCombatTutorial.PHASE_CONFIRM_INTENT)
	expect.call(
		ContextualCombatTutorial.has_completed(scene.get("_progression") as Dictionary, ContextualCombatTutorial.MILESTONE_INTENT),
		"Only Continue should commit the pinned enemy-intent lesson"
	)
	expect.call(
		str(scene.get("_guided_tutorial_phase_id")) == ContextualCombatTutorial.PHASE_SELECT_CARD_FOR_CANCEL,
		"Continue should advance from the pinned intent to the card-cancel lesson"
	)
	expect.call(scene.get("_guided_tutorial_intent_enemy_tile") == INVALID_TILE, "Leaving intent confirmation should clear its pinned enemy tile")
	expect.call(scene.get("_hovered_board_tile") == INVALID_TILE, "Continue should clear the tutorial-owned enemy hover evidence")
	scene.call("_on_board_tile_hovered", OTHER_ENEMY_TILE)
	expect.call(scene.get("_hovered_board_tile") == OTHER_ENEMY_TILE, "After confirmation, normal hover evidence should no longer be pinned")
	scene.free()

	var dismiss_scene: Node = _combat_fixture()
	dismiss_scene.set("_guided_tutorial_phase_id", ContextualCombatTutorial.PHASE_CONFIRM_INTENT)
	dismiss_scene.set("_guided_tutorial_intent_enemy_tile", ENEMY_TILE)
	dismiss_scene.set("_hovered_board_tile", ENEMY_TILE)
	dismiss_scene.set("_run_state", {})
	dismiss_scene.call("_guided_tutorial_dismiss")
	expect.call(
		dismiss_scene.get("_guided_tutorial_intent_enemy_tile") == INVALID_TILE
		and dismiss_scene.get("_hovered_board_tile") == INVALID_TILE,
		"Dismissing from intent confirmation should clear both pinned and tutorial-owned hover evidence"
	)
	dismiss_scene.free()

	var restart_scene: Node = ReplayRunSceneHarness.new()
	restart_scene.set("_progression", _active_progression())
	restart_scene.set("_run_state", {})
	restart_scene.set("_guided_tutorial_phase_id", ContextualCombatTutorial.PHASE_CONFIRM_INTENT)
	restart_scene.set("_guided_tutorial_intent_enemy_tile", ENEMY_TILE)
	restart_scene.set("_hovered_board_tile", ENEMY_TILE)
	restart_scene.call("_guided_tutorial_restart")
	expect.call(
		restart_scene.get("_guided_tutorial_intent_enemy_tile") == INVALID_TILE
		and restart_scene.get("_hovered_board_tile") == INVALID_TILE,
		"Restarting from intent confirmation should clear both pinned and tutorial-owned hover evidence"
	)
	restart_scene.free()


static func _test_intent_confirmation_owns_rendered_evidence(expect: Callable) -> void:
	var scene: Node = _combat_fixture(ReplayRunSceneHarness.new())
	var board := BoardPresentationStub.new()
	scene.add_child(board)
	scene.set("board_view", board)
	var prompt := TutorialPromptStub.new()
	scene.add_child(prompt)
	scene.set("_contextual_combat_prompt", prompt)

	var combat_state: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	var enemies: Array = (combat_state.get("enemies", []) as Array).duplicate(true)
	enemies.append({"id": 2, "type": "crawler", "pos": OTHER_ENEMY_TILE, "hp": 12, "max_hp": 12})
	combat_state["enemies"] = enemies
	scene.set("_combat_state", combat_state)
	scene.set("_preview_combat_state", combat_state.duplicate(true))
	var run_state: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	run_state["combat_state"] = combat_state.duplicate(true)
	scene.set("_run_state", run_state)
	scene.set("_guided_tutorial_phase_id", ContextualCombatTutorial.PHASE_CONFIRM_INTENT)
	scene.set("_guided_tutorial_intent_enemy_tile", ENEMY_TILE)
	scene.set("_hovered_board_tile", OTHER_ENEMY_TILE)
	scene.set("_show_all_enemy_intents", true)

	scene.call("_refresh_stage_view")
	var threats: Array = board.last_presentation.get("enemy_threat_previews", []) as Array
	var pinned_enemy_key: String = str(scene.call("_enemy_key", enemies[0] as Dictionary))
	expect.call(board.submission_count == 1, "The intent evidence fixture should submit a real board presentation")
	expect.call(
		threats.size() == 1 and str((threats[0] as Dictionary).get("enemy_key", "")) == pinned_enemy_key,
		"Intent confirmation should render only the pinned enemy even when Show All Intents was already enabled"
	)
	expect.call(not bool(board.last_presentation.get("show_all_enemy_intents", true)), "Pinned intent confirmation should temporarily suppress the global show-all presentation")

	var intent_toggle := Button.new()
	intent_toggle.toggle_mode = true
	intent_toggle.set_pressed_no_signal(true)
	scene.add_child(intent_toggle)
	scene.set("_enemy_intent_toggle_button", intent_toggle)
	scene.call("_on_enemy_intent_toggle_toggled", false)
	expect.call(bool(scene.get("_show_all_enemy_intents")) and intent_toggle.button_pressed, "The intent button should not alter global intent state during confirmation")
	var keyboard_toggle := InputEventKey.new()
	keyboard_toggle.pressed = true
	keyboard_toggle.keycode = KEY_I
	expect.call(bool(scene.call("_is_enemy_intent_shortcut_event", keyboard_toggle)), "The keyboard fixture should exercise the same I-key intent-toggle command")
	expect.call(bool(scene.call("_guided_tutorial_hard_gate_active")), "The keyboard intent-toggle command should remain under the confirmation hard gate")
	scene.call("_refresh_stage_view")
	threats = board.last_presentation.get("enemy_threat_previews", []) as Array
	expect.call(
		threats.size() == 1 and str((threats[0] as Dictionary).get("enemy_key", "")) == pinned_enemy_key,
		"Rejected button or keyboard toggle commands must leave only the pinned enemy rendered"
	)
	scene.free()

	var keyboard_scene: Node = _attached_combat_fixture()
	expect.call(keyboard_scene != null, "The focused integration runner should provide a live viewport for keyboard dispatch")
	if keyboard_scene != null:
		var keyboard_prompt := TutorialPromptStub.new()
		keyboard_scene.add_child(keyboard_prompt)
		keyboard_scene.set("_contextual_combat_prompt", keyboard_prompt)
		keyboard_scene.set("_guided_tutorial_phase_id", ContextualCombatTutorial.PHASE_CONFIRM_INTENT)
		keyboard_scene.set("_guided_tutorial_intent_enemy_tile", ENEMY_TILE)
		keyboard_scene.set("_hovered_board_tile", ENEMY_TILE)
		keyboard_scene.set("_show_all_enemy_intents", true)
		keyboard_scene.call("_input", keyboard_toggle)
		expect.call(bool(keyboard_scene.get("_show_all_enemy_intents")), "The I-key should not alter global intent state during confirmation")
		expect.call(
			str(keyboard_scene.get("_guided_tutorial_phase_id")) == ContextualCombatTutorial.PHASE_CONFIRM_INTENT
			and keyboard_scene.get("_guided_tutorial_intent_enemy_tile") == ENEMY_TILE,
			"The I-key should preserve the exact pinned confirmation evidence"
		)
		expect.call(keyboard_prompt.blocked_messages.size() == 1, "The rejected I-key should provide immediate tutorial feedback")
		keyboard_scene.free()


static func _test_forced_tutorial_blocks_skill_surfaces(expect: Callable) -> void:
	var scene: Node = _combat_fixture()
	var prompt := TutorialPromptStub.new()
	scene.add_child(prompt)
	scene.set("_contextual_combat_prompt", prompt)
	scene.set("_guided_tutorial_phase_id", ContextualCombatTutorial.PHASE_CORE_COMPLETE)

	var skill_scrim := ColorRect.new()
	skill_scrim.visible = false
	scene.add_child(skill_scrim)
	scene.set("_skill_status_scrim", skill_scrim)
	var skill_popover := PanelContainer.new()
	skill_popover.visible = false
	skill_scrim.add_child(skill_popover)
	scene.set("_skill_status_popover", skill_popover)
	scene.set("_skill_status_selected_id", "rehearsed_escape")
	var hand_box: Control = HandFanContainerScript.new()
	scene.add_child(hand_box)
	scene.set("hand_box", hand_box)

	var combat_state: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	combat_state["skill_ids"] = ["rehearsed_escape"]
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["patch_up"]
	combat_state["deck"] = deck
	scene.set("_combat_state", combat_state)
	scene.set("_preview_combat_state", combat_state.duplicate(true))
	var run_state: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	run_state["combat_state"] = combat_state.duplicate(true)
	scene.set("_run_state", run_state)
	expect.call(str(scene.call("_skill_hud_status", "rehearsed_escape")) == "READY", "The fixture should offer a genuinely ready manual ability")
	expect.call(not bool(scene.call("_combat_skill_is_activatable", "rehearsed_escape")), "A forced tutorial phase should make even a ready manual ability unavailable")

	var combat_before: Dictionary = combat_state.duplicate(true)
	var run_before: Dictionary = run_state.duplicate(true)
	var phase_before: String = str(scene.get("_guided_tutorial_phase_id"))
	scene.call("_toggle_skill_status_popover")
	expect.call(not skill_scrim.visible and not skill_popover.visible, "The Abilities popover should not open during a forced tutorial action")
	scene.call("_on_skill_status_action_pressed")
	scene.call("_on_combat_skill_pressed", "rehearsed_escape")
	expect.call((scene.get("_combat_state") as Dictionary) == combat_before, "Blocked manual ability input should not mutate committed combat state")
	expect.call((scene.get("_run_state") as Dictionary) == run_before, "Blocked manual ability input should not mutate the run checkpoint")
	expect.call(str(scene.get("_combat_skill_card_selection_zone")).is_empty(), "Blocked abilities should not open a follow-up card-selection surface")
	expect.call(not bool(((scene.get("_combat_state") as Dictionary).get("skill_flags", {}) as Dictionary).get("burn_preserve_armed", false)), "Blocked Rehearsed Escape should not become armed")
	expect.call(str(scene.get("_guided_tutorial_phase_id")) == phase_before, "Blocked ability input should preserve the exact tutorial phase")
	expect.call(not skill_scrim.visible and not skill_popover.visible, "Direct manual activation should also leave the Abilities popover closed")
	expect.call(prompt.blocked_messages.size() >= 2, "Popover and direct ability attempts should each provide tutorial-blocked feedback")
	scene.free()


static func _test_controller_candidate_filtering(expect: Callable) -> void:
	var scene: Node = _combat_fixture()
	var board := BoardNavigationStub.new()
	board.navigable_tiles = _tiles([PLAYER_TILE, MOVE_TILE, WRONG_TILE])
	scene.add_child(board)
	scene.set("board_view", board)

	var grimoire := Button.new()
	var loadout := Button.new()
	var menu := Button.new()
	for button: Button in [grimoire, loadout, menu]:
		button.visible = true
		button.disabled = false
		scene.add_child(button)
	scene.set("grimoire_button", grimoire)
	scene.set("loadout_button", loadout)
	scene.set("menu_button", menu)
	scene.set("_guided_tutorial_phase_id", ContextualCombatTutorial.PHASE_CHOOSE_MOVE)
	scene.set("_player_movement_selected", true)
	scene.set("_player_movement_target_tiles", _tiles([MOVE_TILE]))

	var guided_board_tiles: Array[Vector2i] = scene.call("_controller_board_tiles") as Array[Vector2i]
	expect.call(guided_board_tiles == _tiles([MOVE_TILE]), "Controller board navigation should expose only the highlighted movement candidate")
	var guided_header: Array[Control] = scene.call("_controller_header_focus_controls") as Array[Control]
	expect.call(guided_header == _controls([menu]), "Controller header navigation should retain Menu while filtering unrelated utilities")

	var host: Control = scene.get("_contextual_combat_prompt_host") as Control
	host.visible = false
	var normal_board_tiles: Array[Vector2i] = scene.call("_controller_board_tiles") as Array[Vector2i]
	expect.call(normal_board_tiles.has(WRONG_TILE), "Normal controller board candidates should return after the guide releases its gate")
	var normal_header: Array[Control] = scene.call("_controller_header_focus_controls") as Array[Control]
	expect.call(normal_header.has(grimoire) and normal_header.has(loadout) and normal_header.has(menu), "Normal header navigation should return after the guide releases its gate")
	scene.free()


static func _test_modal_suspension_and_resume(expect: Callable) -> void:
	var scene: Node = _combat_fixture()
	var prompt := TutorialPromptStub.new()
	scene.add_child(prompt)
	scene.set("_contextual_combat_prompt", prompt)
	scene.set("_guided_tutorial_phase_id", ContextualCombatTutorial.PHASE_CORE_COMPLETE)
	var menu := ColorRect.new()
	menu.visible = false
	scene.add_child(menu)
	scene.set("_menu_scrim", menu)

	scene.call("_refresh_contextual_combat_tutorial")
	var host: Control = scene.get("_contextual_combat_prompt_host") as Control
	expect.call(host.visible and prompt.configured_phase_id == ContextualCombatTutorial.PHASE_CORE_COMPLETE, "The active guide should render before a modal opens")

	menu.visible = true
	scene.call("_refresh_contextual_combat_tutorial")
	expect.call(not host.visible and prompt.clear_count > 0, "Opening a modal should suspend and clear the guide presentation")
	expect.call(str(scene.get("_guided_tutorial_phase_id")) == ContextualCombatTutorial.PHASE_CORE_COMPLETE, "Modal suspension should preserve the exact pending guide phase")
	expect.call(not bool(scene.call("_guided_tutorial_hard_gate_active")), "A suspended guide should not gate modal input")

	menu.visible = false
	scene.call("_refresh_contextual_combat_tutorial")
	expect.call(host.visible and prompt.configure_count == 2, "Closing the modal should resume the same guide phase")
	expect.call(not ContextualCombatTutorial.has_completed(scene.get("_progression") as Dictionary, ContextualCombatTutorial.MILESTONE_CORE), "Suspending and resuming must not falsely complete a lesson")
	scene.free()


static func _test_pause_menu_cannot_bypass_optional_surface_gate(expect: Callable) -> void:
	var scene: Node = _combat_fixture(ReplayRunSceneHarness.new())
	scene.set("use_real_tutorial_refresh", true)
	var prompt := TutorialPromptStub.new()
	scene.add_child(prompt)
	scene.set("_contextual_combat_prompt", prompt)
	scene.set("_guided_tutorial_phase_id", ContextualCombatTutorial.PHASE_CORE_COMPLETE)

	var menu := ColorRect.new()
	menu.visible = false
	scene.add_child(menu)
	scene.set("_menu_scrim", menu)
	var menu_dialog := PanelContainer.new()
	menu.add_child(menu_dialog)
	scene.set("_menu_dialog", menu_dialog)
	var grimoire := ColorRect.new()
	grimoire.visible = false
	scene.add_child(grimoire)
	scene.set("_grimoire_scrim", grimoire)
	var character := ColorRect.new()
	character.visible = false
	scene.add_child(character)
	scene.set("_upgrade_scrim", character)

	scene.call("_refresh_contextual_combat_tutorial")
	var host: Control = scene.get("_contextual_combat_prompt_host") as Control
	expect.call(host.visible and prompt.configured_phase_id == ContextualCombatTutorial.PHASE_CORE_COMPLETE, "The exact guided prompt should be visible before pausing")
	var phase_before: String = str(scene.get("_guided_tutorial_phase_id"))
	var progression_before: Dictionary = (scene.get("_progression") as Dictionary).duplicate(true)

	scene.call("_open_menu_overlay")
	scene.call("_refresh_contextual_combat_tutorial")
	expect.call(menu.visible and not host.visible, "The pause menu should temporarily suspend the guided prompt")
	scene.call("_on_character_pressed")
	expect.call(not menu.visible, "A blocked Character request from pause should close the menu")
	expect.call(not character.visible, "A blocked Character request should not open its overlay")
	expect.call(host.visible and prompt.configured_phase_id == phase_before, "Closing pause after blocked Character should resume the exact prompt")
	expect.call(str(scene.get("_guided_tutorial_phase_id")) == phase_before, "Blocked Character navigation should not change the tutorial phase")

	scene.call("_open_menu_overlay")
	scene.call("_refresh_contextual_combat_tutorial")
	expect.call(menu.visible and not host.visible, "The guide should suspend again when pause is reopened")
	scene.call("_on_grimoire_button_pressed")
	expect.call(not menu.visible, "A blocked Grimoire request from pause should close the menu")
	expect.call(not grimoire.visible, "A blocked Grimoire request should not open its overlay")
	expect.call(host.visible and prompt.configured_phase_id == phase_before, "Closing pause after blocked Grimoire should resume the exact prompt")
	expect.call(str(scene.get("_guided_tutorial_phase_id")) == phase_before, "Blocked Grimoire navigation should not change the tutorial phase")
	expect.call((scene.get("_progression") as Dictionary) == progression_before, "Blocked pause-menu detours should not advance or persist tutorial progress")
	expect.call(
		prompt.blocked_messages.size() == 2
		and prompt.blocked_messages[0].contains("character")
		and prompt.blocked_messages[1].contains("Grimoire"),
		"Each blocked pause-menu destination should explain why the guided action still has priority"
	)
	scene.free()


static func _test_pre_battle_actions_cannot_bypass_visible_completion_gate(expect: Callable) -> void:
	var scene: Node = _combat_fixture(ReplayRunSceneHarness.new())
	scene.set("use_real_tutorial_refresh", true)
	var prompt := TutorialPromptStub.new()
	scene.add_child(prompt)
	scene.set("_contextual_combat_prompt", prompt)
	scene.set("_guided_tutorial_phase_id", ContextualCombatTutorial.PHASE_COMPLETE)
	var host: Control = scene.get("_contextual_combat_prompt_host") as Control

	var pre_battle := ColorRect.new()
	pre_battle.visible = true
	scene.add_child(pre_battle)
	scene.set("_pre_battle_scrim", pre_battle)
	var board := BoardPresentationStub.new()
	scene.add_child(board)
	scene.set("board_view", board)
	var character := ColorRect.new()
	character.visible = false
	scene.add_child(character)
	scene.set("_upgrade_scrim", character)
	var run_state: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "pre_battle"
	scene.set("_run_state", run_state)

	scene.call("_refresh_contextual_combat_tutorial")
	expect.call(
		host.visible and prompt.configured_phase_id == ContextualCombatTutorial.PHASE_COMPLETE,
		"The final acknowledgement should remain visible above the pre-battle dossier"
	)
	expect.call(prompt.configured_spotlights.is_empty(), "The final acknowledgement should fully dim the underlying pre-battle dossier")
	expect.call(bool(scene.call("_guided_tutorial_hard_gate_active")), "The visible final acknowledgement should hard-gate pre-battle actions")
	var progression_before: Dictionary = (scene.get("_progression") as Dictionary).duplicate(true)
	var run_before: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	scene.call("_on_pre_battle_equip_pressed")
	expect.call(pre_battle.visible, "Blocked pre-battle Equip should preserve the current pre-battle decision")
	expect.call(not character.visible, "Blocked pre-battle Equip should not open the Character overlay")
	expect.call(str(scene.get("_progression_overlay_mode")).is_empty(), "Blocked pre-battle Equip should not select an underlying Character tab")
	scene.call("_on_pre_battle_start_pressed")
	expect.call(pre_battle.visible and not bool(scene.get("_pre_battle_start_pending")), "Blocked pre-battle Start should leave the dossier open without staging combat")
	expect.call(str(scene.get("_guided_tutorial_phase_id")) == ContextualCombatTutorial.PHASE_COMPLETE, "Blocked pre-battle actions should preserve the pending completion phase")
	expect.call((scene.get("_progression") as Dictionary) == progression_before, "Blocked pre-battle actions should not mutate tutorial progression")
	expect.call((scene.get("_run_state") as Dictionary) == run_before, "Blocked pre-battle actions should not mutate the run checkpoint")
	expect.call(
		prompt.blocked_messages.size() == 2
		and prompt.blocked_messages[0].contains("Begin")
		and prompt.blocked_messages[1].contains("Begin"),
		"Blocked Equip and Start should both direct the player to the visible Begin acknowledgement"
	)
	scene.free()


static func _test_skip_replay_and_completion_absence(expect: Callable) -> void:
	var scene: Node = _combat_fixture()
	var prompt := TutorialPromptStub.new()
	scene.add_child(prompt)
	scene.set("_contextual_combat_prompt", prompt)
	scene.set("_guided_tutorial_phase_id", ContextualCombatTutorial.PHASE_SELECT_PLAYER)
	scene.set("_run_state", {})

	scene.call("_on_contextual_combat_prompt_skipped", ContextualCombatTutorial.PHASE_TURN_CLOCK)
	expect.call(ContextualCombatTutorial.is_active(scene.get("_progression") as Dictionary), "A stale Skip signal should not dismiss the active guide")
	scene.call("_on_contextual_combat_prompt_skipped", ContextualCombatTutorial.PHASE_SELECT_PLAYER)
	expect.call(
		str(ContextualCombatTutorial.state_from_progression(scene.get("_progression") as Dictionary).get("status", "")) == ContextualCombatTutorial.STATUS_DISMISSED,
		"Skipping the current guide phase should durably dismiss onboarding"
	)
	expect.call(str(scene.get("_guided_tutorial_phase_id")).is_empty(), "Skipping should remove the active phase immediately")
	expect.call(not bool(scene.call("_guided_tutorial_hard_gate_active")), "A skipped guide should not leave a stale input gate")

	var replay_scene: Node = ReplayRunSceneHarness.new()
	var dismissed_progression: Dictionary = scene.get("_progression") as Dictionary
	var dismissed_revision: int = int(dismissed_progression.get("progression_revision", 0))
	replay_scene.set("_progression", dismissed_progression)
	replay_scene.set("_run_state", {})
	replay_scene.call("_guided_tutorial_restart")
	var replayed: Dictionary = replay_scene.get("_progression") as Dictionary
	expect.call(ContextualCombatTutorial.is_active(replayed), "The real RunScene replay handler should reactivate a dismissed guide")
	expect.call(ContextualCombatTutorial.completed_steps(replayed).is_empty(), "The real RunScene replay handler should clear only tutorial progress")
	expect.call(int(replayed.get("progression_revision", 0)) == dismissed_revision + 1, "The real replay handler should persist one revisioned reset")
	expect.call(int(replay_scene.get("tutorial_refresh_count")) == 2, "Replay should rebuild both normal HUD and guide presentation once")
	replay_scene.free()
	scene.set("_progression", replayed)

	var progression: Dictionary = scene.get("_progression") as Dictionary
	for milestone_id: String in ContextualCombatTutorial.milestone_ids():
		progression = ContextualCombatTutorial.complete_milestone(progression, milestone_id)
	scene.set("_progression", progression)
	scene.set("_guided_tutorial_phase_id", ContextualCombatTutorial.PHASE_COMPLETE)
	var host: Control = scene.get("_contextual_combat_prompt_host") as Control
	host.visible = true
	scene.call("_on_contextual_combat_prompt_completed", ContextualCombatTutorial.PHASE_COMPLETE)
	expect.call(ContextualCombatTutorial.is_completed(scene.get("_progression") as Dictionary), "The final acknowledgement should complete the guide")
	expect.call(not host.visible, "Completion should remove the guide presentation")
	expect.call(not bool(scene.call("_guided_tutorial_hard_gate_active")), "Completion should remove every tutorial input restriction")

	scene.set("_guided_tutorial_phase_id", ContextualCombatTutorial.PHASE_SELECT_PLAYER)
	scene.call("_guided_tutorial_reconcile_phase")
	expect.call(str(scene.get("_guided_tutorial_phase_id")).is_empty(), "Completed profiles should never resurrect a stale tutorial phase")
	scene.free()


static func _combat_fixture(scene_override: Node = null) -> Node:
	var scene: Node = scene_override if scene_override != null else RunScene.new()
	var progression: Dictionary = _active_progression()
	var combat_state: Dictionary = {
		"current_actor": {"kind": "player", "key": "player"},
		"player": {"pos": PLAYER_TILE, "hp": 24, "max_hp": 24},
		"enemies": [{"id": 1, "type": "crawler", "pos": ENEMY_TILE, "hp": 12, "max_hp": 12}],
		"deck": {"hand": [], "draw": ["quick_stab"], "discard": [], "burned": [], "consumed": []},
		"cards_per_turn": 2,
		"cards_played_this_turn": 0,
	}
	scene.set("_progression", progression)
	scene.set("_combat_state", combat_state)
	scene.set("_preview_combat_state", combat_state.duplicate(true))
	scene.set("_run_state", {"mode": "combat", "combat_state": combat_state.duplicate(true), "progression": progression.duplicate(true)})
	var host := Control.new()
	host.visible = true
	scene.add_child(host)
	scene.set("_contextual_combat_prompt_host", host)
	return scene


static func _attached_combat_fixture() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null or not tree.root.is_inside_tree():
		return null
	# Attach the test harness after a plain Control has entered the tree. This
	# supplies a real Viewport for _input without running RunScene's unrelated
	# packed-scene _ready setup.
	var shell := Control.new()
	tree.root.add_child(shell)
	shell.set_script(ReplayRunSceneHarness)
	return _combat_fixture(shell)


static func _active_progression() -> Dictionary:
	return {
		"run_counter": 0,
		"progression_revision": 0,
		ContextualCombatTutorial.PROGRESSION_KEY: ContextualCombatTutorial.default_state(),
	}


static func _tiles(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Variant in values:
		if typeof(value) == TYPE_VECTOR2I:
			result.append(value as Vector2i)
	return result


static func _controls(values: Array) -> Array[Control]:
	var result: Array[Control] = []
	for value: Variant in values:
		if value is Control:
			result.append(value as Control)
	return result

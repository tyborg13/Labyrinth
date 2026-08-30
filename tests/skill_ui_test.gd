extends SceneTree

const AnalyticsStore = preload("res://scripts/analytics_store.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")
const SkillTreeView = preload("res://scripts/skill_tree_view.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

const TEST_PROGRESSION_PATH: String = "user://skill_ui_progression.json"
const TEST_RUN_PATH: String = "user://skill_ui_run.save"
const TEST_ANALYTICS_PATH: String = "user://skill_ui_analytics"

var _failures: Array[String]

func _initialize() -> void:
	ProgressionStore.set_storage_path(TEST_PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(TEST_RUN_PATH)
	AnalyticsStore.set_storage_dir(TEST_ANALYTICS_PATH)
	ProgressionStore.clear_saved_run()
	AnalyticsStore.clear_storage()
	call_deferred("_run")

func _run() -> void:
	var progression: Dictionary = _skill_progression()
	_expect(ProgressionStore.save_data(progression), "Skill UI fixture progression should save")
	_expect(ProgressionStore.selected_skill_ids(progression) == ["quick_wits", "discerning_eye"], "Skill UI fixture should retain both learned roots")

	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_failures.append("RunScene should load for skill UI coverage")
		_finish()
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	instance.call("_close_dialogue")

	var run_engine := RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(73031, progression)
	run_state["item_inventory"] = ["crimson_draught"]
	instance.set("_progression", progression)
	instance.call("_load_run_state", run_state)
	instance.call("_close_dialogue")
	await process_frame

	await _test_character_skill_tree(instance)
	await _test_level_up_commit_feedback_and_persistence(instance)
	await _test_reset_confirmation_is_immediate(instance)
	await _test_newer_embedded_progression_repairs_profile_and_reset(instance)
	await _test_open_arsenal_checkpoint_is_deduplicated(instance)
	await _test_contextual_run_skill_event_scope(instance)
	run_state = (instance.get("_run_state") as Dictionary).duplicate(true)
	await _test_combat_skill_surfaces(instance, run_state, progression)
	await _test_makeshift_tool_loadout_persistence(instance)
	await _test_terminal_skill_event_analytics(instance)
	await _test_reset_clears_stale_combat_preview(instance)
	await _test_reward_reroll(instance)
	await _test_out_of_combat_reset_preserves_unbanked_embers(instance)
	await _test_run_skill_event_cursor_resets_for_new_run(instance)
	await _test_debug_boss_progression_is_sandboxed(instance)
	await _test_content_migration_resaves_resume(instance)

	instance.queue_free()
	for _frame: int in range(4):
		await process_frame
	await create_timer(0.05).timeout
	_finish()

func _test_character_skill_tree(instance: Node) -> void:
	var open_started_usec: int = Time.get_ticks_usec()
	instance.call("_open_card_upgrade_overlay")
	var open_elapsed_usec: int = Time.get_ticks_usec() - open_started_usec
	await process_frame
	await process_frame
	var scrim := instance.get("_upgrade_scrim") as Control
	_expect(scrim != null and scrim.visible, "Character menu should open its Skills surface")
	_expect(open_elapsed_usec < 250000, "Opening the Skills surface should complete synchronously in under a quarter-second: %dus" % open_elapsed_usec)
	_expect(_button_with_text(scrim, "Skills") != null, "Character menu should expose a Skills tab")
	_expect(_button_with_text(scrim, "Stats") == null, "Character menu should not expose a Stats tab")
	_expect(scrim != null and scrim.find_child("CharacterSkillTree", true, false) != null, "Skills tab should render the shared skill tree")
	var tree := instance.get("_skill_tree_view") as SkillTreeView
	_expect(tree != null and tree.status_for_skill("quick_wits") == SkillTreeView.STATE_OWNED, "Skill tree should mark a learned combat ability")
	_expect(tree != null and tree.status_for_skill("discerning_eye") == SkillTreeView.STATE_OWNED, "Skill tree should mark a learned reward ability")
	_expect(tree != null and instance.get_viewport().gui_get_focus_owner() == tree.node_for_skill(tree.focused_skill_id()), "Opening the Skills surface should place real GUI focus on the tree")
	if tree != null:
		var reset_skills := scrim.find_child("ResetSkills", true, false) as Button
		var skills_tab := scrim.find_child("CharacterSkillsTab", true, false) as Button
		tree.focus_skill("ghost_stride")
		tree.grab_tree_focus()
		await process_frame
		_expect(tree.node_for_skill("ghost_stride").find_valid_focus_neighbor(SIDE_TOP) == skills_tab, "A root edge should expose a controller path from the tree to the active Skills tab")
		await _press_ui_action(&"ui_up")
		_expect(instance.get_viewport().gui_get_focus_owner() == skills_tab, "Live controller navigation should reach the Character tabs from the tree")
		await _press_ui_action(&"ui_down")
		_expect(instance.get_viewport().gui_get_focus_owner() == tree.node_for_skill("ghost_stride"), "Skills-tab Down should return to the tree's remembered node")
		tree.focus_skill("long_dawn")
		tree.grab_tree_focus()
		await process_frame
		_expect(tree.node_for_skill("long_dawn").find_valid_focus_neighbor(SIDE_RIGHT) == reset_skills, "The rightmost Radiance root should expose a controller path to Reset Skills")
		await _press_ui_action(&"ui_right")
		_expect(instance.get_viewport().gui_get_focus_owner() == reset_skills, "Live controller navigation should leave the graph for Reset Skills")
		_expect(reset_skills.find_valid_focus_neighbor(SIDE_TOP) == skills_tab, "Reset Skills should expose a direct controller path back to the Character tabs")
		await _press_ui_action(&"ui_up")
		_expect(instance.get_viewport().gui_get_focus_owner() == skills_tab, "Reset Skills Up should reach the active Skills tab")
		await _press_ui_action(&"ui_down")
		_expect(instance.get_viewport().gui_get_focus_owner() == tree.node_for_skill("long_dawn"), "Returning from the Skills tab should preserve the last focused tree node")
		tree.focus_skill("discerning_eye")
	_expect(tree != null and tree.detail_title_text() == "Discerning Eye", "Compact medallions should reveal full skill names in the persistent detail pane")
	var level_resource := scrim.find_child("ProgressionLevelLabel", true, false) as Label
	var point_resource := scrim.find_child("ProgressionSkillPointsLabel", true, false) as Label
	var moltshard_resource := scrim.find_child("ProgressionMoltshardsLabel", true, false) as Label
	_expect(level_resource != null and level_resource.get_theme_font_size("font_size") >= UiTypography.SIZE_SECTION, "Character resources should give Level prominent typography")
	_expect(point_resource != null and point_resource.get_theme_color("font_color") != level_resource.get_theme_color("font_color"), "Skill Points should have a distinct resource color")
	_expect(moltshard_resource != null and moltshard_resource.text.contains("2") and moltshard_resource.get_theme_color("font_color") != point_resource.get_theme_color("font_color"), "Moltshards should be large, color-coded, and show the saved count")
	_expect(scrim.find_child("SkillResetHint", true, false) == null, "Reset explanation should appear only in its confirmation, not as permanent footer copy")

	var visible_run_state: Dictionary = instance.get("_run_state") as Dictionary
	_expect(not visible_run_state.has("moltshards"), "Run state should not track respec resources as inventory")
	_expect(ProgressionStore.moltshard_count(visible_run_state.get("progression", {})) == 2, "Run profile snapshot should retain the saved respec resource")
	_expect(not _array_contains_fragment(visible_run_state.get("item_inventory", []), "molt"), "Run item inventory should not contain the respec resource")

	instance.call("_switch_character_overlay_mode", "equipment")
	await process_frame
	var dialog := instance.get("_upgrade_dialog") as Control
	var body: Control = dialog.find_child("CharacterBodyFrame", true, false) as Control if dialog != null else null
	_expect(body != null and _label_with_text(body, "Crimson Draught") != null, "Gear inventory fixture should render a normal run item")
	_expect(body != null and _label_containing(body, "MOLTSHARD") == null, "Run inventory surface should not display the respec resource")
	var skills_tab_started_usec: int = Time.get_ticks_usec()
	instance.call("_switch_character_overlay_mode", "skills")
	var skills_tab_elapsed_usec: int = Time.get_ticks_usec() - skills_tab_started_usec
	_expect(skills_tab_elapsed_usec < 250000, "Switching from Gear to Skills should stay below a quarter-second: %dus" % skills_tab_elapsed_usec)
	instance.call("_close_card_upgrade_overlay")
	await process_frame

func _test_level_up_commit_feedback_and_persistence(instance: Node) -> void:
	var profile_before: Dictionary = ProgressionStore.load_data()
	var run_before: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	var level_events_before: int = _analytics_event_count("progression_level_up")
	var level_profile: Dictionary = profile_before.duplicate(true)
	var cost: int = ProgressionStore.next_level_cost(level_profile)
	_expect(cost > 0, "Level-up feedback fixture should have another progression level available")
	level_profile = ProgressionStore.set_embers(level_profile, cost)
	_expect(ProgressionStore.save_data(level_profile), "Level-up feedback fixture should save enough embers")
	var run_engine := RunEngine.new()
	var level_run: Dictionary = run_engine.create_new_run(73032, level_profile)
	level_run["mode"] = "campfire"
	level_run["progression"] = level_profile.duplicate(true)
	level_run = run_engine.set_held_embers(level_run, cost)
	instance.set("_progression", level_profile)
	instance.call("_load_run_state", level_run)
	await process_frame
	await process_frame
	instance.call("_open_level_up_overlay")
	await process_frame
	await process_frame
	var tree := instance.get("_skill_tree_view") as SkillTreeView
	var committed_profile: Dictionary = ProgressionStore.load_data()
	var committed_run: Dictionary = ProgressionStore.load_saved_run()
	_expect(tree != null, "Campfire leveling should open the persistent Skills tree after granting the point")
	_expect(int(committed_profile.get("level", 0)) == int(profile_before.get("level", 1)) + 1, "Choosing Draw Strength should immediately advance the saved profile level")
	_expect(ProgressionStore.selected_skill_ids(committed_profile) == ProgressionStore.selected_skill_ids(profile_before), "Leveling should not force or silently choose a skill")
	_expect(ProgressionStore.unspent_skill_points(committed_profile) == ProgressionStore.unspent_skill_points(profile_before) + 1, "Leveling should bank exactly one skill point")
	_expect(int(committed_profile.get("embers", -1)) == 0, "Leveling should spend exactly the displayed ember cost")
	_expect(str((instance.get("_run_state") as Dictionary).get("mode", "")) == "room", "Immediate leveling should preserve the existing leave-campfire flow")
	_expect(str(committed_run.get("mode", "")) == "room", "The post-level room state should be committed for resume")
	_expect(_analytics_event_count("progression_level_up") == level_events_before + 1, "Immediate leveling should emit one progression event")
	var available_ids: Array[String] = ProgressionStore.available_skill_ids(committed_profile)
	if tree != null and not available_ids.is_empty():
		var learned_events_before: int = _analytics_event_count("progression_skill_learned")
		var chosen_skill_id: String = available_ids[0]
		tree.focus_skill(chosen_skill_id)
		var learn_started_usec: int = Time.get_ticks_usec()
		tree.activate_focused_skill()
		var learn_elapsed_usec: int = Time.get_ticks_usec() - learn_started_usec
		await process_frame
		await process_frame
		var learned_profile: Dictionary = ProgressionStore.load_data()
		_expect(ProgressionStore.selected_skill_ids(learned_profile).has(chosen_skill_id), "Learn should immediately save the chosen skill without a build confirmation")
		_expect(ProgressionStore.unspent_skill_points(learned_profile) == ProgressionStore.unspent_skill_points(committed_profile) - 1, "Immediate learning should spend exactly one point")
		_expect(_analytics_event_count("progression_skill_learned") == learned_events_before + 1, "Immediate learning should emit one skill event")
		_expect(tree.status_for_skill(chosen_skill_id) == SkillTreeView.STATE_OWNED, "Learning should update the existing tree in place")
		_expect(instance.find_child("ProgressionOverlayNotice", true, false) == null, "Learning should not add redundant learned/points-remaining copy")
		_expect(instance.find_child("SkillLearnedBanner", true, false) == null, "Learning feedback should stay inside the instant node/resource state change")
		_expect(learn_elapsed_usec < 250000, "Learning should commit and update the open tree in under a quarter-second: %dus" % learn_elapsed_usec)
	_expect(ProgressionStore.save_data(profile_before), "Level-up feedback fixture should restore the original profile")
	_expect(ProgressionStore.save_run_state(run_before), "Level-up feedback fixture should restore the original resumable run")
	instance.set("_progression", profile_before)
	instance.call("_load_run_state", run_before)
	await process_frame
	await process_frame

func _test_reset_confirmation_is_immediate(instance: Node) -> void:
	var profile_before: Dictionary = ProgressionStore.load_data()
	var run_before: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	var reset_events_before: int = _analytics_event_count("progression_skill_reset")
	instance.call("_open_character_overlay", "skills")
	await process_frame
	var scrim := instance.get("_upgrade_scrim") as Control
	var reset_button := scrim.find_child("ResetSkills", true, false) as Button
	_expect(reset_button != null and not reset_button.disabled, "A learned profile with a Moltshard should expose Reset Skills")
	if reset_button != null:
		reset_button.pressed.emit()
	await process_frame
	var confirmation := scrim.find_child("SkillResetConfirmationScrim", true, false) as Control
	var message := scrim.find_child("SkillResetConfirmationMessage", true, false) as Label
	_expect(confirmation != null and message != null and message.text.contains("Are you sure you want to clear all 2 learned skills?"), "Reset should open one explicit whole-tree confirmation")
	_expect(ProgressionStore.load_data() == profile_before, "Opening reset confirmation should not mutate the saved profile")
	var cancel_button := scrim.find_child("CancelSkillReset", true, false) as Button
	if cancel_button != null:
		cancel_button.pressed.emit()
	await process_frame
	_expect(scrim.find_child("SkillResetConfirmationScrim", true, false) == null, "Cancel should close reset confirmation")
	_expect(ProgressionStore.load_data() == profile_before, "Canceling reset should preserve the saved profile")
	_expect(_analytics_event_count("progression_skill_reset") == reset_events_before, "Canceling reset should emit no reset analytics")
	reset_button = scrim.find_child("ResetSkills", true, false) as Button
	if reset_button != null:
		reset_button.pressed.emit()
	await process_frame
	var confirm_button := scrim.find_child("ConfirmSkillReset", true, false) as Button
	_expect(confirm_button != null, "Reset prompt should expose a named destructive confirmation")
	if confirm_button != null:
		confirm_button.pressed.emit()
	await process_frame
	await process_frame
	var reset_profile: Dictionary = ProgressionStore.load_data()
	_expect(ProgressionStore.selected_skill_ids(reset_profile).is_empty(), "Confirming reset should immediately clear the whole tree")
	_expect(ProgressionStore.unspent_skill_points(reset_profile) == 2, "Confirming reset should refund every earned point")
	_expect(ProgressionStore.moltshard_count(reset_profile) == ProgressionStore.moltshard_count(profile_before) - 1, "Confirming reset should spend exactly one Moltshard")
	_expect(_analytics_event_count("progression_skill_reset") == reset_events_before + 1, "Confirming reset should emit one reset event")
	var tree := instance.get("_skill_tree_view") as SkillTreeView
	_expect(tree != null and tree.owned_skill_ids().is_empty() and tree.points_remaining() == 2, "The existing Skills surface should immediately show the cleared tree and refunded points")
	var close_button := (instance.get("_upgrade_dialog") as Control).find_child("CloseCharacterOverlay", true, false) as Button
	if close_button != null:
		close_button.pressed.emit()
	await process_frame
	_expect(scrim != null and not scrim.visible, "Character X should close the single-state Skills menu in one press")
	_expect(ProgressionStore.save_data(profile_before), "Reset fixture should restore the original profile")
	instance.set("_progression", profile_before)
	instance.call("_load_run_state", run_before)
	await process_frame
	instance.call("_close_card_upgrade_overlay")
	await process_frame

func _test_newer_embedded_progression_repairs_profile_and_reset(instance: Node) -> void:
	var profile_before: Dictionary = ProgressionStore.load_data()
	var run_before: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	var embedded_progression: Dictionary = ProgressionStore.add_moltshards(profile_before, 1)
	var run_engine := RunEngine.new()
	var torn_run: Dictionary = run_engine.create_new_run(73034, profile_before)
	torn_run = run_engine.set_held_embers(torn_run, 73)
	torn_run["progression"] = embedded_progression.duplicate(true)
	instance.set("_progression", profile_before)
	instance.call("_load_run_state", torn_run)
	await process_frame
	await process_frame
	var repaired_profile: Dictionary = ProgressionStore.load_data()
	_expect(int(repaired_profile.get("progression_revision", 0)) == int(embedded_progression.get("progression_revision", -1)), "Resume should backfill a newer embedded progression revision after a profile write failed")
	_expect(ProgressionStore.moltshard_count(repaired_profile) == ProgressionStore.moltshard_count(embedded_progression), "Resume should make an embedded Moltshard available to profile-owned reset")
	_expect(int(repaired_profile.get("embers", -1)) == int(profile_before.get("embers", 0)), "Repairing profile progression must not bank the active run's held embers")
	instance.call("_open_character_overlay", "skills")
	await process_frame
	instance.call("_open_skill_reset_confirmation")
	await process_frame
	instance.call("_confirm_skill_reset")
	await process_frame
	var reshaped_profile: Dictionary = ProgressionStore.load_data()
	_expect(ProgressionStore.selected_skill_ids(reshaped_profile).is_empty(), "Reset should remain usable after profile recovery from a newer run snapshot")
	_expect(ProgressionStore.moltshard_count(reshaped_profile) == ProgressionStore.moltshard_count(embedded_progression) - 1, "Recovered reset should consume exactly one Moltshard")
	instance.call("_close_card_upgrade_overlay")
	_expect(ProgressionStore.save_data(profile_before), "Embedded-progression recovery fixture should restore the original profile")
	instance.set("_progression", profile_before)
	instance.call("_load_run_state", run_before)
	await process_frame
	await process_frame

func _test_open_arsenal_checkpoint_is_deduplicated(instance: Node) -> void:
	var profile_before: Dictionary = ProgressionStore.load_data()
	var run_before: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	var arsenal_profile: Dictionary = ProgressionStore.default_data()
	arsenal_profile["level"] = 10
	arsenal_profile["skill_ids"] = [
		"quick_wits", "measured_breath", "ghost_stride", "discerning_eye",
		"pain_remembers", "afterimage", "carry_the_guard", "living_shadow", "open_arsenal",
	]
	arsenal_profile["progression_revision"] = int(profile_before.get("progression_revision", 0)) + 1
	arsenal_profile = ProgressionStore.normalized_data(arsenal_profile)
	_expect(ProgressionStore.selected_skill_ids(arsenal_profile).has("open_arsenal"), "Open Arsenal checkpoint fixture should retain its legal keystone build")
	_expect(ProgressionStore.save_data(arsenal_profile), "Open Arsenal checkpoint fixture should save its temporary profile")
	var run_engine := RunEngine.new()
	var arsenal_run: Dictionary = run_engine.apply_progression_update(run_before, arsenal_profile)
	arsenal_run["mode"] = "room"
	var inventory: Array = (arsenal_run.get("equipment_inventory", []) as Array).duplicate()
	if not inventory.has("stitcher_apron"):
		inventory.append("stitcher_apron")
	arsenal_run["equipment_inventory"] = inventory
	var collected: Array = (arsenal_run.get("collected_equipment", []) as Array).duplicate()
	if not collected.has("stitcher_apron"):
		collected.append("stitcher_apron")
	arsenal_run["collected_equipment"] = collected
	instance.set("_progression", arsenal_profile)
	instance.call("_load_run_state", arsenal_run)
	await process_frame
	instance.call("_open_character_overlay", "equipment")
	await process_frame
	var trigger_count_before: int = _skill_trigger_event_count("open_arsenal")
	await instance.call("_equip_equipment_from_overlay", "stitcher_apron", "trinket")
	var active_run: Dictionary = instance.get("_run_state") as Dictionary
	var event_revision: int = run_engine.run_skill_event_revision(active_run)
	_expect(_skill_trigger_event_count("open_arsenal") == trigger_count_before + 1, "A live Open Arsenal equip should log one realized skill activation")
	var saved_run: Dictionary = ProgressionStore.load_saved_run()
	_expect(int((saved_run.get("analytics", {}) as Dictionary).get("run_skill_event_revision_logged", 0)) == event_revision, "The equipment checkpoint should persist Open Arsenal's analytics cursor with its run event")
	var trigger_count_before_resume: int = _skill_trigger_event_count("open_arsenal")
	instance.call("_load_run_state", saved_run)
	await process_frame
	await process_frame
	_expect(_skill_trigger_event_count("open_arsenal") == trigger_count_before_resume, "Resuming the equipment checkpoint should not duplicate Open Arsenal analytics")
	instance.call("_close_card_upgrade_overlay")
	_expect(ProgressionStore.save_data(profile_before), "Open Arsenal checkpoint fixture should restore the original profile")
	instance.set("_progression", profile_before)
	instance.call("_load_run_state", run_before)
	await process_frame
	await process_frame

func _test_contextual_run_skill_event_scope(instance: Node) -> void:
	var profile_before: Dictionary = (instance.get("_progression") as Dictionary).duplicate(true)
	var run_before: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	var contextual_profile: Dictionary = profile_before.duplicate(true)
	contextual_profile["level"] = 4
	contextual_profile["skill_ids"] = SkillTreeLibrary.repaired_selection([], 3, ["quick_wits", "discerning_eye", "deferred_choice"])
	contextual_profile = ProgressionStore.normalized_data(contextual_profile)
	var run_engine := RunEngine.new()
	var reward_run: Dictionary = run_engine.apply_progression_update(run_before, contextual_profile)
	reward_run["mode"] = "reward"
	reward_run["combat_state"] = {}
	reward_run["pending_reward"] = {
		"cards": ["rime_shard", "static_lash", "gust_step"],
		"heal_amount": RunEngine.REWARD_HEAL,
		"ember_amount": 4,
	}
	instance.set("_progression", contextual_profile)
	instance.set("_run_state", reward_run)
	instance.set("_combat_state", {})
	instance.call("_refresh_ui")
	await process_frame
	var event_count_before: int = _skill_trigger_event_count("deferred_choice")
	instance.call("_commit_reward_heal", "rime_shard")
	await process_frame
	await process_frame
	_expect(_skill_trigger_event_count("deferred_choice") == event_count_before + 1, "A live contextual run ability should emit one skill-trigger event")
	var payload: Dictionary = _latest_skill_trigger_payload("deferred_choice")
	_expect(str(payload.get("trigger_scope", "")) == "run", "Contextual run ability analytics should identify the run event stream")
	var active_run: Dictionary = instance.get("_run_state") as Dictionary
	var event_revision: int = run_engine.run_skill_event_revision(active_run)
	var saved_run: Dictionary = ProgressionStore.load_saved_run()
	_expect(int((saved_run.get("analytics", {}) as Dictionary).get("run_skill_event_revision_logged", 0)) == event_revision, "A contextual trigger should persist its analytics cursor only after the event append")
	var crash_replay: Dictionary = saved_run.duplicate(true)
	var replay_analytics: Dictionary = (crash_replay.get("analytics", {}) as Dictionary).duplicate(true)
	replay_analytics["run_skill_event_revision_logged"] = maxi(0, event_revision - 1)
	crash_replay["analytics"] = replay_analytics
	var event_count_before_replay: int = _skill_trigger_event_count("deferred_choice")
	instance.call("_load_run_state", crash_replay)
	await process_frame
	await process_frame
	_expect(_skill_trigger_event_count("deferred_choice") == event_count_before_replay, "Replaying a persisted run-skill outbox after an append-before-cursor crash should not duplicate JSONL")
	var replayed_saved_run: Dictionary = ProgressionStore.load_saved_run()
	_expect(int((replayed_saved_run.get("analytics", {}) as Dictionary).get("run_skill_event_revision_logged", 0)) == event_revision, "Crash replay should advance and persist the run-skill cursor after the idempotent append succeeds")
	instance.set("_progression", profile_before)
	instance.call("_load_run_state", run_before)
	await process_frame
	await process_frame

func _test_combat_skill_surfaces(instance: Node, base_run_state: Dictionary, progression: Dictionary) -> void:
	var combat_engine := CombatEngine.new()
	var layout: Dictionary = _combat_layout()
	var combat_state: Dictionary = combat_engine.create_combat(73031, layout, {
		"hp": 360,
		"max_hp": 360,
		"deck_cards": base_run_state.get("deck_cards", []).duplicate(),
		"skill_ids": ProgressionStore.selected_skill_ids(progression),
		"level": int(progression.get("level", 1)),
		"relics": [],
		"hand_size": 5,
		"heal_bonus": 0,
	})
	var combat_run: Dictionary = base_run_state.duplicate(true)
	combat_run["mode"] = "combat"
	combat_run["current_room_layout"] = layout.duplicate(true)
	combat_run["combat_state"] = combat_state.duplicate(true)
	combat_run["progression"] = progression.duplicate(true)
	instance.set("_progression", progression)
	instance.call("_load_run_state", combat_run)
	instance.call("_close_dialogue")
	await process_frame
	await process_frame
	var loaded_combat_run: Dictionary = instance.get("_run_state") as Dictionary
	var run_engine := RunEngine.new()
	var loaded_skill_ids: Array[String] = run_engine.run_skill_ids(loaded_combat_run)
	_expect(loaded_skill_ids.has("quick_wits") and loaded_skill_ids.has("discerning_eye"), "Loaded combat should retain both learned abilities: %s" % [loaded_skill_ids])

	var sigil := instance.get("_skill_sigil") as Button
	_expect(sigil != null and sigil.is_visible_in_tree(), "Combat HUD should show the distinct skill sigil")
	_expect(
		sigil != null
		and _label_with_text(sigil, "ABILITIES") != null
		and int(sigil.get_meta("owned_count", -1)) == 2
		and sigil.find_child("SkillSigilSummary", true, false) is Label,
		"The Abilities launcher should label its purpose and summarize owned/readied abilities"
	)
	if sigil != null:
		sigil.grab_focus()
		await process_frame
		await _press_ui_action(&"ui_accept")
	await process_frame
	var popover := instance.get("_skill_status_popover") as Control
	_expect(popover != null and popover.visible, "Skill sigil should open its status popover")
	var status_close := popover.find_child("CloseSkillStatus", true, false) as Button if popover != null else null
	var opening_focus := instance.get_viewport().gui_get_focus_owner() as Control
	_expect(opening_focus != null and opening_focus.name.begins_with("SkillStatusTile_"), "Opening Abilities should enter the icon palette at the selected ability")
	await _press_ui_action(&"ui_cancel")
	_expect(popover != null and not popover.visible, "Controller Cancel should close the skill status popover")
	_expect(sigil != null and instance.get_viewport().gui_get_focus_owner() == sigil, "Closing the skill status popover should restore focus to its sigil")
	if sigil != null:
		await _press_ui_action(&"ui_accept")
	await process_frame
	_expect(_label_with_text(popover, "Quick Wits") != null, "Skill popover should list the learned combat ability")
	_expect(_label_with_text(popover, "Discerning Eye") != null, "Skill popover should list the learned reward ability")
	_expect(_label_with_text(popover, "READY") != null, "Skill popover should communicate readiness")
	var status_scrim := instance.get("_skill_status_scrim") as ColorRect
	_expect(status_scrim != null and status_scrim.visible and status_scrim.mouse_filter == Control.MOUSE_FILTER_STOP, "Skill status should use a full-screen mouse-blocking scrim")
	_expect(
		status_scrim != null and sigil != null and status_scrim.get_global_rect().has_point(sigil.get_global_rect().get_center()),
		"The skill-status scrim should cover combat controls behind the panel (scrim=%s, Abilities=%s)" % [
			status_scrim.get_global_rect() if status_scrim != null else Rect2(),
			sigil.get_global_rect() if sigil != null else Rect2()
		]
	)
	var combat_before_scrim_click: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	if status_scrim != null and sigil != null:
		var blocked_click := InputEventMouseButton.new()
		blocked_click.button_index = MOUSE_BUTTON_LEFT
		blocked_click.pressed = true
		blocked_click.position = sigil.get_global_rect().get_center()
		_expect(
			status_scrim.gui_input.is_connected(Callable(instance, "_on_skill_status_scrim_gui_input")),
			"The skill-status scrim should route pointer input to its modal close handler"
		)
		instance.call("_on_skill_status_scrim_gui_input", blocked_click)
		await process_frame
	_expect((instance.get("_combat_state") as Dictionary) == combat_before_scrim_click, "Clicking the modal skill-status scrim over combat controls must not advance combat")
	_expect(status_scrim != null and not status_scrim.visible, "Clicking outside the skill-status panel should close it")
	instance.call("_toggle_skill_status_popover")
	await process_frame
	instance.call("_refresh_skill_status_popover", SkillTreeLibrary.ordered_ids())
	instance.call("_layout_skill_status_popover")
	await process_frame
	await process_frame
	var status_grid := instance.get("_skill_status_grid") as GridContainer
	var status_tiles: Array[Control] = _visible_control_children(status_grid)
	var status_root_height: float = (instance.get("ui_root") as Control).get_global_rect().size.y
	_expect(
		popover != null
		and is_equal_approx(popover.size.x, minf(880.0, (instance.get("ui_root") as Control).get_global_rect().size.x - 16.0))
		and is_equal_approx(popover.size.y, minf(540.0, status_root_height - 16.0))
		and popover.size.y <= status_root_height - 16.0 + 1.0,
		"Skill popover should use one fixed viewport-bounded geometry"
	)
	_expect(popover.find_child("SkillStatusScroll", true, false) == null, "Abilities should not retain the old scrolling paragraph list")
	_expect(status_tiles.size() == 10, "The fixed icon palette should show ten learned identities per page (found %d)" % status_tiles.size())
	for tile_var: Variant in status_tiles:
		_expect(tile_var is Button and (tile_var as Button).focus_mode == Control.FOCUS_ALL, "Every ability icon should be keyboard/controller inspectable")
		_expect(tile_var is Button and not str((tile_var as Button).get_meta("icon_key", "")).is_empty(), "Every ability tile should carry a semantic icon")
	if status_close != null and not status_tiles.is_empty():
		status_close.grab_focus()
		await _press_ui_action(&"ui_down")
		_expect(instance.get_viewport().gui_get_focus_owner() == status_tiles[0], "Abilities Close Down should enter the first icon")
		await _press_ui_action(&"ui_up")
		_expect(instance.get_viewport().gui_get_focus_owner() == status_close, "The first ability icon Up should return to Close")
		await _press_ui_action(&"ui_down")
		await _press_ui_action(&"ui_right")
		_expect(instance.get_viewport().gui_get_focus_owner() == status_tiles[1], "Controller Right should traverse the icon grid")
		var first_tile := status_tiles[0] as Button
		var second_tile := status_tiles[1] as Button
		first_tile.pressed.emit()
		var clicked_skill_id: String = str(instance.get("_skill_status_selected_id"))
		second_tile.mouse_entered.emit()
		_expect(str(instance.get("_skill_status_selected_id")) == clicked_skill_id, "Hovering an ability icon must not change the selected detail")
		second_tile.pressed.emit()
		_expect(str(instance.get("_skill_status_selected_id")) == str(second_tile.get_meta("skill_id", "")), "Clicking an ability icon should change the selected detail")
	var paged_skill_ids: Array[String]
	for page_index: int in range(3):
		if page_index > 0:
			instance.call("_on_skill_status_page_pressed", 1)
			await process_frame
		status_tiles = _visible_control_children(status_grid)
		var expected_page_size: int = 10 if page_index < 2 else 9
		_expect(status_tiles.size() == expected_page_size, "Ability page %d should contain its complete visible palette slice" % [page_index + 1])
		for retained_tile: Node in status_grid.get_children():
			if retained_tile is Control and not (retained_tile as Control).visible:
				_expect((retained_tile as Control).focus_mode == Control.FOCUS_NONE, "Hidden retained ability tiles must not take controller focus")
		for tile_var: Variant in status_tiles:
			var page_tile := tile_var as Button
			var page_skill_id: String = str(page_tile.get_meta("skill_id", ""))
			paged_skill_ids.append(page_skill_id)
			var name_label := page_tile.find_child("SkillStatusName_%s" % page_skill_id, true, false) as Label
			_expect(name_label != null and name_label.text == SkillTreeLibrary.display_name(page_skill_id), "%s should show its complete name beneath the icon" % page_skill_id)
	paged_skill_ids.sort()
	var all_skill_ids: Array[String] = SkillTreeLibrary.visible_ids()
	all_skill_ids.sort()
	_expect(paged_skill_ids == all_skill_ids, "Paging should expose every learned ability identity without a dropdown or scrollbar")
	var stable_popover_size: Vector2 = popover.size
	instance.call("_show_skill_status_page_for_skill", "prismatic_instinct")
	await process_frame
	var long_description := popover.find_child("SkillStatusSelectedDescription", true, false) as RichTextLabel
	_expect(popover.size == stable_popover_size, "Selecting the longest ability description must not resize the Abilities panel")
	_expect(long_description != null and long_description.get_content_height() <= long_description.size.y + 1.0, "The longest ability description should fit fully inside the fixed detail well")
	_expect(long_description != null and long_description.get_theme_font_size("normal_font_size") >= UiTypography.SIZE_BODY_LARGE, "Ability rules should use the enlarged readable type tier")
	_expect(long_description != null and float(long_description.get_meta("inline_icon_size", 0.0)) > float(long_description.get_theme_font_size("normal_font_size")), "Ability mechanic icons should be larger than their rules text")
	instance.call("_show_skill_status_page_for_skill", "measured_breath")
	await process_frame
	var status_action := popover.find_child("ActivateSelectedSkill", true, false) as Button
	_expect(status_action != null and not status_action.visible, "Automatic abilities should not render a permanently disabled activation button")
	instance.call("_show_skill_status_page_for_skill", "open_arsenal")
	await process_frame
	_expect(status_action != null and not status_action.visible, "Passive abilities should not render a permanently disabled activation button")
	instance.call("_refresh_skill_status_popover", loaded_skill_ids)
	await process_frame
	var contextual_skill_ids: Array[String]
	contextual_skill_ids.append_array(["discerning_eye", "deferred_choice", "curators_patience", "true_bearing", "layaway"])
	var contextual_run_state: Dictionary = loaded_combat_run.duplicate(true)
	var contextual_progression: Dictionary = (contextual_run_state.get("progression", {}) as Dictionary).duplicate(true)
	contextual_progression["skill_ids"] = contextual_skill_ids
	contextual_run_state["progression"] = contextual_progression
	instance.set("_run_state", contextual_run_state)
	for contextual_skill_id: String in contextual_skill_ids:
		_expect(str(instance.call("_skill_hud_status", contextual_skill_id)) == "WAITING", "%s should state that it is waiting outside its relevant choice flow" % contextual_skill_id)
	_expect(str(instance.call("_skill_hud_status", "salvager")) == "WAITING", "Unspent Salvager should wait for a qualifying victory rather than claim to have triggered automatically")
	_expect(str(instance.call("_skill_hud_status", "last_door")) == "WAITING", "Unspent Last Door should wait for a qualifying defeat rather than claim to have triggered automatically")
	_expect(str(instance.call("_skill_hud_status", "measured_breath")) == "AUTOMATIC", "Measured Breath should identify itself as an automatic recurring rule")
	_expect(str(instance.call("_skill_hud_status", "open_arsenal")) == "PASSIVE", "Open Arsenal should identify itself as an always-on passive")
	var spent_sequence_run: Dictionary = contextual_run_state.duplicate(true)
	var spent_sequence_state: Dictionary = (spent_sequence_run.get("skill_state", {}) as Dictionary).duplicate(true)
	spent_sequence_state["used_by_sequence"] = {"0:salvager": true, "0:last_door": true}
	spent_sequence_run["skill_state"] = spent_sequence_state
	instance.set("_run_state", spent_sequence_run)
	_expect(str(instance.call("_skill_hud_status", "salvager")) == "SPENT", "Spent Salvager should remain visibly spent through the current boss sequence")
	_expect(str(instance.call("_skill_hud_status", "last_door")) == "SPENT", "Spent Last Door should remain visibly spent through the current boss sequence")
	instance.set("_run_state", contextual_run_state)
	var primed_run_state: Dictionary = contextual_run_state.duplicate(true)
	var primed_skill_state: Dictionary = (primed_run_state.get("skill_state", {}) as Dictionary).duplicate(true)
	primed_skill_state["pending_card"] = "rime_shard"
	primed_skill_state["pending_relic"] = "flint_edge"
	primed_skill_state["reserved_merchant"] = {"kind": "scavenger", "item_id": "stitcher_apron"}
	primed_run_state["skill_state"] = primed_skill_state
	instance.set("_run_state", primed_run_state)
	_expect(str(instance.call("_skill_hud_status", "deferred_choice")) == "PRIMED", "Deferred Choice should show its earned card waiting for the next reward")
	_expect(str(instance.call("_skill_hud_status", "curators_patience")) == "PRIMED", "Curator's Patience should show its earned relic waiting for the next offer")
	_expect(str(instance.call("_skill_hud_status", "layaway")) == "WAITING", "Layaway should show its held merchant stock waiting for the next visit")
	instance.set("_run_state", loaded_combat_run)
	_expect(str(instance.call("_skill_hud_status", "rehearsed_escape")) == "WAITING", "An unlearned manual combat ability should not appear ready")
	var status_combat: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	var status_flags: Dictionary = (status_combat.get("skill_flags", {}) as Dictionary).duplicate(true)
	status_flags["prismatic_armed"] = true
	status_combat["skill_flags"] = status_flags
	instance.set("_combat_state", status_combat)
	_expect(str(instance.call("_skill_hud_status", "prismatic_instinct")) == "ARMED", "Prismatic Instinct should show its pending armed state")
	status_flags.erase("prismatic_armed")
	status_flags["turn:living_shadow"] = int(status_combat.get("turn", 1))
	status_combat["skill_flags"] = status_flags
	instance.set("_combat_state", status_combat)
	_expect(str(instance.call("_skill_hud_status", "living_shadow")) == "SPENT", "Living Shadow should show SPENT after triggering in the current turn")
	var banked_status_combat: Dictionary = combat_state.duplicate(true)
	var banked_status_skills: Array = (banked_status_combat.get("skill_ids", []) as Array).duplicate()
	banked_status_skills.append_array(["measured_breath", "borrowed_time"])
	banked_status_combat["skill_ids"] = banked_status_skills
	banked_status_combat["banked_play_active"] = 1
	banked_status_combat["banked_play_spent_this_activation"] = 0
	instance.set("_combat_state", banked_status_combat)
	_expect(str(instance.call("_skill_hud_status", "measured_breath")) == "BANKED", "Measured Breath should show BANKED while a stored play remains")
	_expect(str(instance.call("_skill_hud_status", "borrowed_time")) == "PRIMED", "Borrowed Time should show PRIMED while its no-Time banked play remains")
	var spent_banked_flags: Dictionary = (banked_status_combat.get("skill_flags", {}) as Dictionary).duplicate(true)
	spent_banked_flags["used:borrowed_time"] = true
	banked_status_combat["skill_flags"] = spent_banked_flags
	banked_status_combat["banked_play_spent_this_activation"] = 1
	banked_status_combat["cards_played_this_turn"] = 3
	instance.set("_combat_state", banked_status_combat)
	_expect(str(instance.call("_skill_hud_status", "measured_breath")) == "AUTOMATIC", "Measured Breath should stop claiming a banked play after it is spent")
	_expect(str(instance.call("_skill_hud_status", "borrowed_time")) == "SPENT", "Borrowed Time should show SPENT after removing Time")
	instance.set("_combat_state", combat_state)
	instance.call("_close_skill_status_popover")
	await process_frame

	var choice_overlay := instance.get("_choice_button_overlay") as Control
	var choice_bar := instance.get("choice_bar") as Control
	_expect(_visible_button_with_text(choice_overlay, "Quick Wits") == null and _visible_button_with_text(choice_bar, "Quick Wits") == null, "Activated abilities should not reuse the combat choice row beside Pass")
	var quick_wits_combat_before: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	var quick_wits_run_before: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	var quick_wits_analytics_revision_before: int = int(instance.get("_analytics_skill_event_revision"))
	var quick_wits_seen_revision_before: int = int(instance.get("_skill_event_revision_seen"))
	var saved_before_blocked_activation: Dictionary = ProgressionStore.load_saved_run()
	instance.set("_selected_card_index", 0)
	instance.set("_preview_combat_state", quick_wits_combat_before.duplicate(true))
	var blocked_quick_wits_button: Button = await _ready_skill_button(instance, "Quick Wits")
	_expect(not bool(instance.call("_combat_skill_is_activatable", "quick_wits")), "Abilities should be unavailable while an uncommitted card preview is active")
	if blocked_quick_wits_button != null:
		blocked_quick_wits_button.pressed.emit()
	await process_frame
	_expect(str(instance.get("_combat_skill_card_selection_zone")).is_empty(), "A stale card preview should block Quick Wits before it can enter hand selection")
	_expect((instance.get("_combat_state") as Dictionary) == quick_wits_combat_before, "Blocked ability activation should not mutate committed combat state")
	_expect(ProgressionStore.load_saved_run() == saved_before_blocked_activation, "Blocked ability activation should not write a conflicting combat checkpoint")
	instance.call("_reset_card_resolution")
	instance.call("_close_skill_status_popover")
	instance.call("_refresh_ui")
	await process_frame
	var quick_wits_button: Button = await _ready_skill_button(instance, "Quick Wits")
	_expect(quick_wits_button != null, "The Abilities popover should expose ready Quick Wits as its dedicated entry")
	if quick_wits_button != null:
		quick_wits_button.pressed.emit()
	await process_frame
	var choice_scrim := instance.get("_skill_choice_scrim") as Control
	var selection_prompt := instance.get("_combat_skill_card_selection_prompt") as Control
	_expect(choice_scrim != null and not choice_scrim.visible, "Quick Wits should not open the name-only skill choice dialog")
	_expect(selection_prompt != null and selection_prompt.visible and _label_containing(selection_prompt, "CHOOSE A CARD TO DISCARD") != null, "Quick Wits should enter an explicit live-hand discard mode")
	var first_hand_card: CardWidget = _hand_card_widget(instance, 0)
	var first_hand_selection: Button = _hand_selection_button(instance, 0)
	_expect(first_hand_card != null and first_hand_card.is_visible_in_tree(), "Discard mode should keep the full card in its normal hand position")
	_expect(first_hand_selection != null and instance.get_viewport().gui_get_focus_owner() == first_hand_selection, "Quick Wits should transfer controller focus to the first full-card choice")
	if selection_prompt != null and instance.get("hand_scroll") != null:
		_expect(selection_prompt.get_global_rect().end.y <= (instance.get("hand_scroll") as Control).get_global_rect().position.y - 8.0, "The hand-selection prompt should remain above card headers instead of covering the choice evidence")
	if first_hand_selection != null:
		await _click_control(first_hand_selection)
	await process_frame
	_expect(selection_prompt != null and not selection_prompt.visible, "Choosing the live hand card should leave discard mode")
	_expect(combat_engine.skill_was_used(instance.get("_combat_state") as Dictionary, "quick_wits"), "Choosing Quick Wits through real input should commit its combat use")
	_expect(bool(instance.get("_animation_lock")), "Quick Wits should keep combat input locked while the chosen card discards and its replacement draws")
	var quick_wits_fx_layer := instance.get("_card_fx_layer") as Control
	_expect(quick_wits_fx_layer != null and quick_wits_fx_layer.get_child_count() > 0, "Quick Wits should reuse the visible card-proxy motion layer")
	await _wait_for_animation_unlock(instance)
	instance.set("_combat_state", quick_wits_combat_before)
	instance.set("_run_state", quick_wits_run_before)
	instance.set("_analytics_skill_event_revision", quick_wits_analytics_revision_before)
	instance.set("_skill_event_revision_seen", quick_wits_seen_revision_before)
	instance.call("_refresh_ui")
	await process_frame

	var original_combat_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	var original_run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	var escape_combat: Dictionary = original_combat_state.duplicate(true)
	var escape_skills: Array = (escape_combat.get("skill_ids", []) as Array).duplicate()
	escape_skills.append("rehearsed_escape")
	escape_skills.append("makeshift_tool")
	escape_skills.append("carry_the_guard")
	escape_combat["skill_ids"] = escape_skills
	var escape_player: Dictionary = (escape_combat.get("player", {}) as Dictionary).duplicate(true)
	escape_player["block"] = GameData.fixed_point_amount(2)
	escape_combat["player"] = escape_player
	var escape_deck: Dictionary = (escape_combat.get("deck", {}) as Dictionary).duplicate(true)
	escape_deck["hand"] = ["patch_up", "crimson_draught"]
	escape_combat["deck"] = escape_deck
	var escape_trigger_count: int = _skill_trigger_event_count("rehearsed_escape")
	var makeshift_trigger_count: int = _skill_trigger_event_count("makeshift_tool")
	var carry_trigger_count: int = _skill_trigger_event_count("carry_the_guard")
	instance.set("_combat_state", escape_combat)
	instance.set("_run_state", run_engine.set_combat_state(original_run_state, escape_combat))
	instance.call("_refresh_ui")
	await process_frame
	var ready_group := _button_beginning_with(instance.get("_choice_button_overlay") as Control, "Ready Skills (")
	_expect(ready_group == null, "Multiple activated abilities should stay in the common Abilities popover instead of creating a contextual Pass-row group")
	_expect(_visible_button_with_text(instance.get("_choice_button_overlay") as Control, "Rehearsed Escape") == null, "Activated abilities should never cover the combat hand with direct choice-row controls")
	var escape_button: Button = await _ready_skill_button(instance, "Rehearsed Escape")
	_expect(escape_button != null, "Rehearsed Escape should appear as an explicit Abilities entry")
	if escape_button != null:
		escape_button.pressed.emit()
	await process_frame
	var escape_flags: Dictionary = ((instance.get("_combat_state") as Dictionary).get("skill_flags", {}) as Dictionary)
	_expect(bool(escape_flags.get("burn_preserve_armed", false)), "Rehearsed Escape should visibly arm before it changes a Burn destination")
	_expect(str(instance.call("_skill_hud_status", "rehearsed_escape")) == "ARMED", "Rehearsed Escape should report ARMED after the player opts in")
	_expect(_skill_trigger_event_count("rehearsed_escape") == escape_trigger_count, "Arming Rehearsed Escape should not log a realized skill trigger")
	var makeshift_button: Button = await _ready_skill_button(instance, "Makeshift Tool")
	_expect(makeshift_button != null, "Makeshift Tool should appear as an explicit Abilities entry")
	if makeshift_button != null:
		makeshift_button.pressed.emit()
	await process_frame
	escape_flags = ((instance.get("_combat_state") as Dictionary).get("skill_flags", {}) as Dictionary)
	_expect(bool(escape_flags.get("item_preserve_armed", false)), "Makeshift Tool should visibly arm before it changes a consumable destination")
	_expect(str(instance.call("_skill_hud_status", "makeshift_tool")) == "ARMED", "Makeshift Tool should report ARMED after the player opts in")
	_expect(_skill_trigger_event_count("makeshift_tool") == makeshift_trigger_count, "Arming Makeshift Tool should not log a realized skill trigger")
	var carry_button: Button = await _ready_skill_button(instance, "Carry the Guard")
	_expect(carry_button != null, "Carry the Guard should appear in Abilities while block remains")
	if carry_button != null:
		carry_button.pressed.emit()
	await process_frame
	escape_flags = ((instance.get("_combat_state") as Dictionary).get("skill_flags", {}) as Dictionary)
	_expect(bool(escape_flags.get("guard_carry_armed", false)), "Carry the Guard should visibly arm for the current activation")
	_expect(str(instance.call("_skill_hud_status", "carry_the_guard")) == "ARMED", "Carry the Guard should report ARMED after the player opts in")
	_expect(_skill_trigger_event_count("carry_the_guard") == carry_trigger_count, "Arming Carry the Guard should not log a realized skill trigger")
	var resolved_escape: Dictionary = combat_engine.finish_player_card(instance.get("_combat_state") as Dictionary, 0)
	instance.call("_commit_combat_skill_state", resolved_escape, "rehearsed_escape")
	await process_frame
	_expect(_skill_trigger_event_count("rehearsed_escape") == escape_trigger_count + 1, "Preserving a Burn card should emit exactly one realized skill trigger")
	var resolved_item: Dictionary = combat_engine.finish_player_card(instance.get("_combat_state") as Dictionary, 0, 1, {"play_mode": "play"})
	instance.call("_commit_combat_skill_state", resolved_item, "makeshift_tool")
	await process_frame
	_expect(_skill_trigger_event_count("makeshift_tool") == makeshift_trigger_count + 1, "Preserving an item should emit exactly one realized skill trigger")
	var resolved_guard: Dictionary = combat_engine.finish_player_activation(instance.get("_combat_state") as Dictionary)
	instance.call("_commit_combat_skill_state", resolved_guard, "carry_the_guard")
	await process_frame
	_expect(combat_engine.skill_was_used(instance.get("_combat_state") as Dictionary, "carry_the_guard"), "Carry the Guard should spend when the armed conversion resolves")
	_expect(_skill_trigger_event_count("carry_the_guard") == carry_trigger_count + 1, "Carry the Guard should emit exactly one realized skill trigger at activation end")
	instance.set("_combat_state", original_combat_state)
	instance.set("_run_state", original_run_state)
	instance.call("_refresh_ui")
	await process_frame

	var prismatic_combat: Dictionary = original_combat_state.duplicate(true)
	var prismatic_skills: Array = (prismatic_combat.get("skill_ids", []) as Array).duplicate()
	prismatic_skills.append("prismatic_instinct")
	prismatic_combat["skill_ids"] = prismatic_skills
	var prismatic_deck: Dictionary = (prismatic_combat.get("deck", {}) as Dictionary).duplicate(true)
	prismatic_deck["hand"] = ["rime_shard", "quick_stab"]
	prismatic_combat["deck"] = prismatic_deck
	instance.set("_combat_state", prismatic_combat)
	instance.set("_run_state", run_engine.set_combat_state(original_run_state, prismatic_combat))
	instance.call("_refresh_ui")
	await process_frame
	var prismatic_button: Button = await _ready_skill_button(instance, "Prismatic Instinct")
	_expect(prismatic_button != null, "A ready Prismatic Instinct should appear in the common Abilities popover")
	if prismatic_button != null:
		prismatic_button.pressed.emit()
	await process_frame
	_expect(choice_scrim != null and not choice_scrim.visible, "Prismatic Instinct should avoid the name-only card list")
	_expect(selection_prompt != null and selection_prompt.visible and _label_containing(selection_prompt, "CHOOSE A CONDITIONAL CARD") != null, "Prismatic Instinct should select from the live hand")
	var rime_widget: CardWidget = _hand_card_widget(instance, 0)
	var quick_stab_widget: CardWidget = _hand_card_widget(instance, 1)
	var rime_selection: Button = _hand_selection_button(instance, 0)
	var quick_stab_selection: Button = _hand_selection_button(instance, 1)
	_expect(rime_widget != null and rime_selection != null and not rime_selection.disabled, "An eligible conditional card should remain a directly selectable full card")
	_expect(quick_stab_widget != null and quick_stab_selection != null and quick_stab_selection.disabled, "Cards without intensity conditions should remain visible but inert in Prismatic selection mode")
	_expect(instance.get_viewport().gui_get_focus_owner() == rime_selection, "Prismatic Instinct should focus its first eligible full-card choice")
	await _press_ui_action(&"ui_cancel")
	_expect(selection_prompt != null and not selection_prompt.visible, "Controller Cancel should leave hand selection without spending Prismatic Instinct")
	_expect(not combat_engine.skill_was_used(instance.get("_combat_state") as Dictionary, "prismatic_instinct"), "Canceling hand selection should preserve the ready ability")
	_expect(instance.get_viewport().gui_get_focus_owner() == instance.get("_skill_sigil"), "Canceling hand selection should restore focus to Abilities")
	prismatic_button = await _ready_skill_button(instance, "Prismatic Instinct")
	if prismatic_button != null:
		prismatic_button.pressed.emit()
	await process_frame
	await process_frame
	rime_selection = _hand_selection_button(instance, 0)
	if rime_selection != null:
		await _press_ui_action(&"ui_accept")
	await process_frame
	var armed_flags: Dictionary = ((instance.get("_combat_state") as Dictionary).get("skill_flags", {}) as Dictionary)
	_expect(bool(armed_flags.get("prismatic_armed", false)) and str(armed_flags.get("prismatic_target_card_id", "")) == "rime_shard", "Prismatic Instinct should bind its arm to the chosen card")

	var encore_combat: Dictionary = original_combat_state.duplicate(true)
	var encore_skills: Array = (encore_combat.get("skill_ids", []) as Array).duplicate()
	encore_skills.append("encore")
	encore_combat["skill_ids"] = encore_skills
	var encore_deck: Dictionary = (encore_combat.get("deck", {}) as Dictionary).duplicate(true)
	encore_deck["hand"] = ["rime_shard"]
	encore_deck["discard"] = ["quick_stab", "crimson_draught"]
	encore_combat["deck"] = encore_deck
	instance.set("_combat_state", encore_combat)
	instance.set("_run_state", run_engine.set_combat_state(original_run_state, encore_combat))
	instance.call("_refresh_ui")
	await process_frame
	var encore_button: Button = await _ready_skill_button(instance, "Encore")
	_expect(encore_button != null, "Encore should use the shared Abilities entry point")
	if encore_button != null:
		encore_button.pressed.emit()
	await process_frame
	var pile_scrim := instance.get("_pile_scrim") as Control
	var pile_title := instance.get("_pile_dialog_title") as Label
	var displayed_discard_cards: Array[Control] = _visible_control_children(instance.get("_pile_dialog_cards") as Control)
	_expect(displayed_discard_cards.size() == 2, "Encore should show exactly the two current discard cards, excluding retained hidden cards")
	var item_card: Button = displayed_discard_cards[0] as Button if displayed_discard_cards.size() > 0 else null
	var recall_card: Button = displayed_discard_cards[1] as Button if displayed_discard_cards.size() > 1 else null
	_expect(pile_scrim != null and pile_scrim.visible and pile_title != null and pile_title.text.contains("Choose a Card to Return"), "Encore should open the full-card discard pile in selection mode")
	var recalled_widget: CardWidget = _card_widget_descendant(recall_card)
	var item_widget: CardWidget = _card_widget_descendant(item_card)
	_expect(recall_card != null and not recall_card.disabled and recalled_widget != null and recalled_widget.card_id == "quick_stab" and int(recall_card.get_meta("source_card_index", -1)) == 0, "Encore should map the selectable displayed card back to its original discard index")
	_expect(item_card != null and item_card.disabled and item_widget != null and item_widget.card_id == "crimson_draught", "Encore should leave the displayed item card visible but inert after reversing pile order")
	_expect(instance.get_viewport().gui_get_focus_owner() == recall_card, "Encore should focus the first eligible full discard card for controller input")
	if recall_card != null:
		var focus_style := recall_card.get_theme_stylebox("focus") as StyleBoxFlat
		_expect(focus_style != null and focus_style.border_width_left >= 4, "Encore's focused full card should retain a visible non-color-only selection frame")
		var pile_close := (instance.get("_pile_dialog") as Control).find_child("CloseButton", true, false) as Button
		await _press_ui_action(&"ui_up")
		_expect(instance.get_viewport().gui_get_focus_owner() == pile_close, "Encore card Up should reach the pile close action")
		await _press_ui_action(&"ui_down")
		_expect(instance.get_viewport().gui_get_focus_owner() == recall_card, "Encore close Down should restore focus to the selectable full card")
	if recall_card != null:
		var normal_encore_motion_started_msec: int = Time.get_ticks_msec()
		await _click_control(recall_card)
		await process_frame
		var encore_result: Dictionary = instance.get("_combat_state") as Dictionary
		_expect(not pile_scrim.visible and ((encore_result.get("deck", {}) as Dictionary).get("hand", []) as Array).has("quick_stab"), "Selecting the full discard card should return it to hand and close the pile")
		_expect(combat_engine.skill_was_used(encore_result, "encore"), "Encore should spend after the discard-pile card is selected")
		_expect(bool(instance.get("_animation_lock")), "Encore should keep combat input locked while the recalled full card flies into hand")
		var encore_fx_layer := instance.get("_card_fx_layer") as Control
		_expect(encore_fx_layer != null and encore_fx_layer.get_child_count() > 0, "Encore should reuse the visible card-proxy motion layer")
		await _wait_for_animation_unlock(instance)
		var normal_encore_motion_msec: int = Time.get_ticks_msec() - normal_encore_motion_started_msec

		var original_settings: Dictionary = (instance.get("_settings") as Dictionary).duplicate(true)
		var reduced_settings: Dictionary = original_settings.duplicate(true)
		reduced_settings["reduced_motion"] = true
		instance.set("_settings", reduced_settings)
		instance.set("_combat_state", encore_combat.duplicate(true))
		instance.set("_run_state", run_engine.set_combat_state(original_run_state, encore_combat))
		instance.call("_refresh_ui")
		await process_frame
		var reduced_encore_button: Button = await _ready_skill_button(instance, "Encore")
		if reduced_encore_button != null:
			reduced_encore_button.pressed.emit()
		await process_frame
		var reduced_discard_cards: Array[Control] = _visible_control_children(instance.get("_pile_dialog_cards") as Control)
		var reduced_recall_card: Button = reduced_discard_cards[1] as Button if reduced_discard_cards.size() > 1 else null
		_expect(reduced_recall_card != null and int(reduced_recall_card.get_meta("source_card_index", -1)) == 0, "Reduced-motion Encore should preserve the displayed discard ordering")
		var reduced_encore_motion_started_msec: int = Time.get_ticks_msec()
		if reduced_recall_card != null:
			await _click_control(reduced_recall_card)
		await _wait_for_animation_unlock(instance)
		var reduced_encore_motion_msec: int = Time.get_ticks_msec() - reduced_encore_motion_started_msec
		var reduced_encore_result: Dictionary = instance.get("_combat_state") as Dictionary
		_expect(combat_engine.skill_was_used(reduced_encore_result, "encore") and ((reduced_encore_result.get("deck", {}) as Dictionary).get("hand", []) as Array).has("quick_stab"), "Reduced-motion Encore must actually recall the chosen card")
		_expect(
			reduced_recall_card != null and reduced_encore_motion_msec < normal_encore_motion_msec,
			"Reduced motion should keep Encore's visible state transition while shortening its card flight (%dms vs %dms)" % [
				reduced_encore_motion_msec,
				normal_encore_motion_msec,
			]
		)
		instance.set("_settings", original_settings)
	instance.set("_combat_state", original_combat_state)
	instance.set("_run_state", original_run_state)
	instance.call("_refresh_ui")
	await process_frame

func _test_makeshift_tool_loadout_persistence(instance: Node) -> void:
	var original_progression: Dictionary = (instance.get("_progression") as Dictionary).duplicate(true)
	var original_run: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	var item_progression: Dictionary = ProgressionStore.default_data()
	item_progression["level"] = 3
	item_progression["skill_ids"] = ["quick_wits", "makeshift_tool"]
	item_progression = ProgressionStore.normalized_data(item_progression)
	_expect(ProgressionStore.save_data(item_progression), "Makeshift Tool integration fixture should persist its legal build")

	var preserved: Dictionary = await _play_item_as_printed_card(instance, item_progression, true)
	var preserved_combat: Dictionary = preserved.get("combat", {}) as Dictionary
	var preserved_run: Dictionary = preserved.get("run", {}) as Dictionary
	var preserved_saved: Dictionary = preserved.get("saved", {}) as Dictionary
	var preserved_deck: Dictionary = preserved_combat.get("deck", {}) as Dictionary
	_expect((preserved_deck.get("discard", []) as Array).has("crimson_draught") and not (preserved_deck.get("consumed", []) as Array).has("crimson_draught"), "Armed Makeshift Tool should redirect a played item to discard")
	_expect((preserved_run.get("equipped_items", []) as Array).has("crimson_draught") and (preserved_saved.get("equipped_items", []) as Array).has("crimson_draught"), "Preserving an item should retain it in both the live and saved run loadout")
	_expect((preserved_run.get("deck_cards", []) as Array).has("crimson_draught") and (preserved_saved.get("deck_cards", []) as Array).has("crimson_draught"), "Preserving an item should retain its compiled deck card across checkpoint reload")
	_expect(CombatEngine.new().skill_was_used(preserved_combat, "makeshift_tool"), "Makeshift Tool should spend only after the protected item play resolves")

	var consumed: Dictionary = await _play_item_as_printed_card(instance, item_progression, false)
	var consumed_combat: Dictionary = consumed.get("combat", {}) as Dictionary
	var consumed_run: Dictionary = consumed.get("run", {}) as Dictionary
	var consumed_saved: Dictionary = consumed.get("saved", {}) as Dictionary
	var consumed_deck: Dictionary = consumed_combat.get("deck", {}) as Dictionary
	_expect((consumed_deck.get("consumed", []) as Array).has("crimson_draught"), "Declining Makeshift Tool should still consume a played item")
	_expect(not (consumed_run.get("equipped_items", []) as Array).has("crimson_draught") and not (consumed_saved.get("equipped_items", []) as Array).has("crimson_draught"), "An unprotected item should leave both the live and saved run loadout")
	_expect(not (consumed_run.get("deck_cards", []) as Array).has("crimson_draught") and not (consumed_saved.get("deck_cards", []) as Array).has("crimson_draught"), "Consuming an item should remove its compiled deck card across checkpoint reload")

	_expect(ProgressionStore.save_data(original_progression), "Makeshift Tool integration should restore the active profile")
	instance.set("_progression", original_progression)
	instance.call("_load_run_state", original_run)
	await process_frame
	await process_frame

func _play_item_as_printed_card(instance: Node, progression: Dictionary, arm_makeshift: bool) -> Dictionary:
	var run_engine := RunEngine.new()
	var combat_engine := CombatEngine.new()
	var run_state: Dictionary = run_engine.create_debug_boss_run(progression)
	run_state["debug_boss_run"] = false
	run_state["progression"] = progression.duplicate(true)
	var combat_state: Dictionary = (run_state.get("combat_state", {}) as Dictionary).duplicate(true)
	combat_state["skill_ids"] = ProgressionStore.selected_skill_ids(progression)
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["crimson_draught"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	deck["consumed"] = []
	combat_state["deck"] = deck
	if arm_makeshift:
		combat_state = combat_engine.arm_makeshift_tool(combat_state)
	run_state = run_engine.set_combat_state(run_state, combat_state)
	instance.set("_progression", progression)
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_refresh_ui")
	await process_frame
	await process_frame
	var resolved_state: Dictionary = combat_state.duplicate(true)
	var printed_actions: Array = combat_engine.card_play_actions("crimson_draught", combat_state)
	var selected_targets: Array[Vector2i]
	for action_var: Variant in printed_actions:
		var action: Dictionary = action_var as Dictionary
		resolved_state = combat_engine.apply_player_action(resolved_state, action)
		selected_targets.append(Vector2i(-1, -1))
	await instance.call("_play_player_card", 0, resolved_state, printed_actions, selected_targets)
	await process_frame
	await process_frame
	return {
		"combat": (instance.get("_combat_state") as Dictionary).duplicate(true),
		"run": (instance.get("_run_state") as Dictionary).duplicate(true),
		"saved": ProgressionStore.load_saved_run(),
	}

func _test_reward_reroll(instance: Node) -> void:
	var reward_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	reward_state["mode"] = "reward"
	reward_state["combat_state"] = {}
	reward_state["pending_reward"] = {
		"cards": ["spark_dart", "frostbolt", "guiding_flare"],
		"heal_amount": RunEngine.REWARD_HEAL,
		"ember_amount": 4,
	}
	instance.set("_run_state", reward_state)
	instance.set("_combat_state", {})
	instance.call("_refresh_ui")
	await process_frame
	await process_frame
	var loaded_reward_skills: Array[String] = RunEngine.new().run_skill_ids(instance.get("_run_state") as Dictionary)
	_expect(loaded_reward_skills.has("discerning_eye"), "Reward state should retain its learned reroll ability: %s" % [loaded_reward_skills])
	var reroll_button: Button = instance.find_child("RewardRerollButton", true, false) as Button
	_expect(reroll_button != null, "Ready reward ability should expose the reroll control")
	if reroll_button != null:
		_expect(reroll_button.text == "REROLL", "Reward reroll should use the compact secondary-action label")
	if reroll_button != null:
		reroll_button.pressed.emit()
	await process_frame
	await process_frame
	var rerolled_state: Dictionary = instance.get("_run_state") as Dictionary
	var run_engine := RunEngine.new()
	_expect(not run_engine.run_skill_is_ready(rerolled_state, "discerning_eye"), "Using reward reroll should spend it for the current sequence")
	_expect(instance.find_child("RewardRerollButton", true, false) == null, "Spent reward reroll should leave the active choice controls")
	_expect(not rerolled_state.has("moltshards"), "Reward flow should not copy respec resources into run inventory state")
	_expect(not _array_contains_fragment(rerolled_state.get("item_inventory", []), "molt"), "Reward flow should keep respec resources out of item inventory")
	var run_event_revision: int = run_engine.run_skill_event_revision(rerolled_state)
	_expect(run_event_revision > 0 and int(instance.get("_run_skill_event_revision_seen")) == run_event_revision, "A run-side trigger should advance the SkillSigil pulse cursor")
	var saved_run: Dictionary = ProgressionStore.load_saved_run()
	_expect(int((saved_run.get("analytics", {}) as Dictionary).get("run_skill_event_revision_logged", 0)) == run_event_revision, "The saved checkpoint should include the analytics de-duplication cursor")
	var trigger_count_before_resume: int = _skill_trigger_event_count("discerning_eye")
	var trigger_payload: Dictionary = _latest_skill_trigger_payload("discerning_eye")
	_expect(str(trigger_payload.get("trigger_scope", "")) == "run", "Automatic run ability analytics should identify the run event stream")
	instance.call("_load_run_state", saved_run)
	await process_frame
	await process_frame
	_expect(_skill_trigger_event_count("discerning_eye") == trigger_count_before_resume, "Resuming the saved trigger checkpoint should not append duplicate analytics")
	_expect(int(instance.get("_run_skill_event_revision_seen")) == run_event_revision, "Loading historical run events should baseline the pulse cursor instead of replaying them")

func _test_terminal_skill_event_analytics(instance: Node) -> void:
	var active_run: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	var active_combat: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	var active_progression: Dictionary = (instance.get("_progression") as Dictionary).duplicate(true)
	var prior_analytics_revision: int = int(instance.get("_analytics_skill_event_revision"))
	var terminal_revision: int = prior_analytics_revision + 1
	var terminal_combat: Dictionary = active_combat.duplicate(true)
	terminal_combat["enemies"] = []
	terminal_combat["skill_event_revision"] = terminal_revision
	terminal_combat["skill_events"] = [{
		"revision": terminal_revision,
		"skill_id": "afterimage",
		"turn": int(terminal_combat.get("turn", 1)),
		"message": "Afterimage resolves on the final action.",
	}]
	var event_count_before: int = _skill_trigger_event_count("afterimage")
	var transitioned_run: Dictionary = instance.call("_run_state_for_combat_checkpoint", active_run, terminal_combat) as Dictionary
	transitioned_run = instance.call("_hold_committed_run_state", transitioned_run, "terminal_skill_analytics_test") as Dictionary
	instance.set("_run_state", transitioned_run)
	instance.call("_sync_combat_state_from_run")
	instance.call("_release_committed_run_state")
	instance.call("_refresh_ui")
	await process_frame
	_expect(_skill_trigger_event_count("afterimage") == event_count_before + 1, "A skill triggered by the terminal action should flush from its durable outbox after the gameplay checkpoint")
	var trigger_payload: Dictionary = _latest_skill_trigger_payload("afterimage")
	_expect(str(trigger_payload.get("trigger_scope", "")) == "combat", "Combat ability analytics should identify the combat event stream")
	instance.set("_analytics_skill_event_revision", prior_analytics_revision)
	instance.set("_progression", active_progression)
	instance.set("_run_state", active_run)
	instance.set("_combat_state", active_combat)
	instance.call("_refresh_ui")
	await process_frame

func _test_reset_clears_stale_combat_preview(instance: Node) -> void:
	var stale_preview: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	stale_preview["stale_preview_marker"] = true
	instance.set("_selected_card_index", 0)
	instance.set("_card_action_choice_index", 0)
	instance.set("_preview_combat_state", stale_preview)
	instance.call("_open_character_overlay", "skills")
	await process_frame
	_expect(int(instance.get("_selected_card_index")) == -1, "Opening Character should cancel a selected card before reset")
	_expect(int(instance.get("_card_action_choice_index")) == -1, "Opening Character should clear pending card action choices before reset")
	_expect((instance.get("_preview_combat_state") as Dictionary).is_empty(), "Opening Character should discard any resolved combat preview before reset")
	instance.call("_open_skill_reset_confirmation")
	_expect(str(instance.get("_progression_overlay_mode")) == "skills", "Combat should allow viewing the tree but not changing the active build")
	_expect(instance.get("_skill_reset_confirmation_scrim") == null, "Combat should not open the reset confirmation")
	_expect(ProgressionStore.moltshard_count(instance.get("_progression") as Dictionary) == 2, "A blocked combat reset should not consume a Moltshard")
	instance.call("_close_card_upgrade_overlay")
	await process_frame

func _test_out_of_combat_reset_preserves_unbanked_embers(instance: Node) -> void:
	var run_engine := RunEngine.new()
	var reward_state: Dictionary = run_engine.set_held_embers(instance.get("_run_state") as Dictionary, 73)
	var pending_skill_state: Dictionary = (reward_state.get("skill_state", {}) as Dictionary).duplicate(true)
	pending_skill_state["pending_card"] = "rime_shard"
	pending_skill_state["pending_relic"] = "flint_edge"
	pending_skill_state["reserved_merchant"] = {
		"kind": "scavenger",
		"item_id": "stitcher_apron",
		"origin_coord": Vector2i(3, 0),
	}
	reward_state["skill_state"] = pending_skill_state
	instance.set("_run_state", reward_state)
	instance.call("_open_character_overlay", "skills")
	await process_frame
	instance.call("_open_skill_reset_confirmation")
	instance.call("_confirm_skill_reset")
	await process_frame
	var active_run: Dictionary = instance.get("_run_state") as Dictionary
	var saved_profile: Dictionary = ProgressionStore.load_data()
	_expect(ProgressionStore.selected_skill_ids(saved_profile).is_empty(), "A non-combat reset should clear the complete build")
	_expect(ProgressionStore.unspent_skill_points(saved_profile) == 2, "A non-combat reset should refund all earned points")
	_expect(ProgressionStore.moltshard_count(saved_profile) == 1, "A confirmed reset should consume exactly one Moltshard")
	_expect(int(saved_profile.get("embers", -1)) == 0, "Reset must not bank the run's unbanked embers into the persistent profile")
	_expect(run_engine.held_embers(active_run) == 73, "Reset should preserve the run's unbanked embers")
	var active_skill_state: Dictionary = active_run.get("skill_state", {}) as Dictionary
	_expect(str(active_skill_state.get("pending_card", "")) == "rime_shard", "Reset should preserve an already-earned deferred card in the active run")
	_expect(str(active_skill_state.get("pending_relic", "")) == "flint_edge", "Reset should preserve an already-earned deferred relic in the active run")
	_expect(str((active_skill_state.get("reserved_merchant", {}) as Dictionary).get("item_id", "")) == "stitcher_apron", "Reset should preserve already-held merchant stock in the active run")
	var saved_run: Dictionary = ProgressionStore.load_saved_run()
	var saved_skill_state: Dictionary = saved_run.get("skill_state", {}) as Dictionary
	_expect(str(saved_skill_state.get("pending_card", "")) == "rime_shard" and str(saved_skill_state.get("pending_relic", "")) == "flint_edge", "The reset checkpoint should persist earned deferred rewards")
	_expect(str((saved_skill_state.get("reserved_merchant", {}) as Dictionary).get("item_id", "")) == "stitcher_apron", "The reset checkpoint should persist earned Layaway stock")
	instance.call("_close_card_upgrade_overlay")
	await process_frame

func _test_run_skill_event_cursor_resets_for_new_run(instance: Node) -> void:
	var run_engine := RunEngine.new()
	instance.set("_run_skill_event_revision_seen", 9)
	var trigger_profile: Dictionary = _skill_progression()
	instance.set("_progression", trigger_profile)
	var second_run: Dictionary = run_engine.create_new_run(73032, trigger_profile)
	second_run["mode"] = "reward"
	second_run["pending_reward"] = {
		"cards": ["spark_dart", "frostbolt", "guiding_flare"],
		"heal_amount": RunEngine.REWARD_HEAL,
		"ember_amount": 4,
	}
	instance.call("_load_run_state", second_run)
	await process_frame
	_expect(int(instance.get("_run_skill_event_revision_seen")) == 0, "Loading a new run should reset a higher prior run-event pulse cursor")
	instance.call("_on_reward_reroll_pressed")
	await process_frame
	await process_frame
	_expect(int(instance.get("_run_skill_event_revision_seen")) == 1, "The first run-side trigger in a second run should still pulse at revision one")
	var progression_before_level_one_check: Dictionary = (instance.get("_progression") as Dictionary).duplicate(true)
	instance.set("_progression", ProgressionStore.default_data())
	_expect(not bool(instance.call("_skill_reset_can_apply")), "A level-one profile with no learned skills should not offer an impossible reset")
	instance.set("_progression", progression_before_level_one_check)

func _test_debug_boss_progression_is_sandboxed(instance: Node) -> void:
	var saved_progression: Dictionary = ProgressionStore.load_data()
	var debug_progression: Dictionary = ProgressionStore.default_data()
	var debug_run: Dictionary = RunEngine.new().create_debug_boss_run(debug_progression)
	var victorious_combat: Dictionary = (debug_run.get("combat_state", {}) as Dictionary).duplicate(true)
	victorious_combat["enemies"] = []
	instance.set("_progression", debug_progression)
	var finished_debug_run: Dictionary = instance.call("_run_state_for_combat_checkpoint", debug_run, victorious_combat) as Dictionary
	_expect(str(finished_debug_run.get("mode", "")) == "victory", "Debug boss fixture should reach victory for persistence coverage")
	var reloaded_profile: Dictionary = ProgressionStore.load_data()
	_expect(int(reloaded_profile.get("level", 0)) == int(saved_progression.get("level", -1)), "Debug boss victory must not replace the real profile level")
	_expect(ProgressionStore.selected_skill_ids(reloaded_profile) == ProgressionStore.selected_skill_ids(saved_progression), "Debug boss victory must not replace the real learned skills")
	_expect(ProgressionStore.moltshard_count(reloaded_profile) == ProgressionStore.moltshard_count(saved_progression), "Debug boss victory must not add or erase real Moltshards")

func _test_content_migration_resaves_resume(instance: Node) -> void:
	var legacy_card: String = _encoded_legacy_id([97, 115, 104, 108, 105, 110, 101, 95, 116, 101, 109, 112, 111])
	var legacy_equipment: String = _encoded_legacy_id([97, 115, 104, 119, 101, 97, 118, 101, 95, 109, 97, 105, 108])
	var profile: Dictionary = ProgressionStore.load_data()
	profile["grimoire_unlocked"] = ["magick:%s" % legacy_card, "equipment:%s" % legacy_equipment]
	profile["grimoire_unread"] = ["magick:%s" % legacy_card]
	_expect(ProgressionStore.save_data(profile), "Legacy discovery profile fixture should save")
	var run_engine := RunEngine.new()
	var legacy_run: Dictionary = run_engine.create_new_run(73033, profile)
	legacy_run.erase(RunEngine.RUN_CONTENT_SCHEMA_KEY)
	var embedded_progression: Dictionary = (legacy_run.get("progression", {}) as Dictionary).duplicate(true)
	embedded_progression["grimoire_unlocked"] = profile.get("grimoire_unlocked", []).duplicate(true)
	embedded_progression["grimoire_unread"] = profile.get("grimoire_unread", []).duplicate(true)
	legacy_run["progression"] = embedded_progression
	legacy_run["compatibility_probe"] = {"loot_id": "loot_equipment_%s_2_2" % legacy_equipment}
	_expect(ProgressionStore.save_run_state(legacy_run), "Legacy active-run fixture should save before resume migration")
	instance.set("_progression", ProgressionStore.load_data())
	instance.call("_load_run_state", ProgressionStore.load_saved_run())
	await process_frame
	await process_frame
	var persisted_run: Dictionary = ProgressionStore.load_saved_run()
	_expect(int(persisted_run.get(RunEngine.RUN_CONTENT_SCHEMA_KEY, 0)) == RunEngine.RUN_CONTENT_SCHEMA, "Resume should immediately atomically persist the current content schema")
	var persisted_progression: Dictionary = persisted_run.get("progression", {}) as Dictionary
	_expect((persisted_progression.get("grimoire_unlocked", []) as Array).has("magick:cinderline_tempo") and (persisted_progression.get("grimoire_unlocked", []) as Array).has("equipment:cinderweave_mail"), "Resume should migrate embedded discovery ids before Grimoire normalization")
	_expect(str((persisted_run.get("compatibility_probe", {}) as Dictionary).get("loot_id", "")) == "loot_equipment_cinderweave_mail_2_2", "Resume should preserve composite loot-id structure while migrating its equipment id")
	var persisted_profile: Dictionary = ProgressionStore.load_data()
	_expect((persisted_profile.get("grimoire_unlocked", []) as Array).has("magick:cinderline_tempo") and (persisted_profile.get("grimoire_unlocked", []) as Array).has("equipment:cinderweave_mail"), "Resume should persist migrated standalone profile discovery ids")
	var legacy_pattern := RegEx.new()
	var legacy_prefix: String = _encoded_legacy_id([97, 115, 104])
	_expect(legacy_pattern.compile("(?i)(?<![[:alnum:]])%s[[:alnum:]_-]*" % legacy_prefix) == OK, "Resume migration vocabulary scan should compile")
	_expect(legacy_pattern.search(var_to_str(persisted_run)) == null and legacy_pattern.search(var_to_str(persisted_profile)) == null, "Persisted run and profile should contain no retired vocabulary tokens after resume")

func _skill_progression() -> Dictionary:
	var progression: Dictionary = ProgressionStore.default_data()
	progression["level"] = 3
	progression["skill_ids"] = ["quick_wits", "discerning_eye"]
	progression["moltshards"] = 2
	return ProgressionStore.normalized_data(progression)

func _encoded_legacy_id(values: Array) -> String:
	var bytes := PackedByteArray()
	for value: Variant in values:
		bytes.append(int(value))
	return bytes.get_string_from_ascii()

func _skill_trigger_event_count(skill_id: String) -> int:
	var count: int = 0
	for event: Dictionary in AnalyticsStore.load_all_events():
		if str(event.get("event_type", "")) != "skill_triggered":
			continue
		var payload: Dictionary = event.get("payload", {}) as Dictionary
		if str(payload.get("skill_id", "")) == skill_id:
			count += 1
	return count

func _analytics_event_count(event_type: String) -> int:
	var count: int = 0
	for event: Dictionary in AnalyticsStore.load_all_events():
		if str(event.get("event_type", "")) == event_type:
			count += 1
	return count

func _latest_skill_trigger_payload(skill_id: String) -> Dictionary:
	var latest: Dictionary = {}
	for event: Dictionary in AnalyticsStore.load_all_events():
		if str(event.get("event_type", "")) != "skill_triggered":
			continue
		var payload: Dictionary = event.get("payload", {}) as Dictionary
		if str(payload.get("skill_id", "")) == skill_id:
			latest = payload
	return latest

func _combat_layout() -> Dictionary:
	var grid: Array = []
	for y: int in range(7):
		var row: Array = []
		for x: int in range(7):
			row.append("wall" if x == 0 or y == 0 or x == 6 or y == 6 else "stone")
		grid.append(row)
	return {
		"coord": Vector2i(1, 0),
		"name": "Skill Trial",
		"depth": 1,
		"type": "combat",
		"element": "fire",
		"grid": grid,
		"player_start": Vector2i(2, 3),
		"enemies": [{
			"id": "enemy_1",
			"type": "crawler",
			"name": "Tunnel Crawler",
			"pos": Vector2i(4, 3),
			"hp": 60,
			"max_hp": 60,
			"base_initiative": 9,
		}],
		"traps": [],
		"loot": [],
		"terrain": [],
	}

func _button_with_text(node: Node, expected: String) -> Button:
	if node == null:
		return null
	if node is Button and (node as Button).text == expected:
		return node as Button
	for child: Node in node.get_children():
		var found: Button = _button_with_text(child, expected)
		if found != null:
			return found
	return null

func _visible_button_with_text(node: Node, expected: String) -> Button:
	if node == null:
		return null
	if node is Button:
		var button := node as Button
		if button.text == expected and button.is_visible_in_tree():
			return button
	for child: Node in node.get_children():
		var found: Button = _visible_button_with_text(child, expected)
		if found != null:
			return found
	return null

func _button_beginning_with(node: Node, prefix: String) -> Button:
	if node == null:
		return null
	if node is Button and (node as Button).text.begins_with(prefix):
		return node as Button
	for child: Node in node.get_children():
		var found: Button = _button_beginning_with(child, prefix)
		if found != null:
			return found
	return null

func _ready_skill_button(instance: Node, skill_name: String) -> Button:
	var skill_id: String = ""
	for candidate_id: String in SkillTreeLibrary.ordered_ids():
		if SkillTreeLibrary.display_name(candidate_id) == skill_name:
			skill_id = candidate_id
			break
	if skill_id.is_empty():
		return null
	var popover := instance.get("_skill_status_popover") as Control
	if popover == null or not popover.visible:
		instance.call("_toggle_skill_status_popover")
		await process_frame
		await process_frame
	popover = instance.get("_skill_status_popover") as Control
	instance.call("_show_skill_status_page_for_skill", skill_id)
	await process_frame
	var tile := popover.find_child("SkillStatusTile_%s" % skill_id, true, false) as Button if popover != null else null
	if tile == null:
		return null
	tile.pressed.emit()
	await process_frame
	return popover.find_child("ActivateSelectedSkill", true, false) as Button

func _hand_card_widget(instance: Node, hand_index: int) -> CardWidget:
	var hand_box := instance.get("hand_box") as Control
	if hand_box == null or hand_index < 0 or hand_index >= hand_box.get_child_count():
		return null
	return _card_widget_descendant(hand_box.get_child(hand_index))

func _hand_selection_button(instance: Node, hand_index: int) -> Button:
	var hand_box := instance.get("hand_box") as Control
	if hand_box == null:
		return null
	return hand_box.find_child("SkillHandSelectionCard_%d" % hand_index, true, false) as Button

func _visible_control_children(parent: Node) -> Array[Control]:
	var result: Array[Control]
	if parent == null:
		return result
	for child: Node in parent.get_children():
		if child is Control and (child as Control).is_visible_in_tree():
			result.append(child as Control)
	return result

func _card_widget_descendant(node: Node) -> CardWidget:
	if node == null:
		return null
	if node is CardWidget:
		return node as CardWidget
	for child: Node in node.get_children():
		var found: CardWidget = _card_widget_descendant(child)
		if found != null:
			return found
	return null

func _label_with_text(node: Node, expected: String) -> Label:
	if node == null:
		return null
	if node is Label and (node as Label).text == expected:
		return node as Label
	for child: Node in node.get_children():
		var found: Label = _label_with_text(child, expected)
		if found != null:
			return found
	return null

func _label_containing(node: Node, fragment: String) -> Label:
	if node == null:
		return null
	if node is Label and (node as Label).text.contains(fragment):
		return node as Label
	for child: Node in node.get_children():
		var found: Label = _label_containing(child, fragment)
		if found != null:
			return found
	return null

func _array_contains_fragment(value: Variant, fragment: String) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	for item_var: Variant in value as Array:
		if str(item_var).to_lower().contains(fragment.to_lower()):
			return true
	return false

func _press_ui_action(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		event.strength = 1.0 if pressed else 0.0
		root.push_input(event)
		await process_frame
	await process_frame

func _click_control(control: Control) -> void:
	if control == null or not control.is_visible_in_tree():
		return
	var viewport: Viewport = control.get_viewport()
	var click_position: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = click_position
	motion.global_position = click_position
	viewport.push_input(motion, true)
	await process_frame
	var hovered: Control = viewport.gui_get_hovered_control()
	_expect(hovered == control, "%s should own the mouse hit instead of its decorative card subtree" % control.name)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = click_position
		event.global_position = click_position
		event.pressed = pressed
		viewport.push_input(event, true)
		await process_frame
	await process_frame

func _wait_for_animation_unlock(instance: Node, timeout_seconds: float = 2.0) -> void:
	var deadline_msec: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while bool(instance.get("_animation_lock")) and Time.get_ticks_msec() < deadline_msec:
		await process_frame
	_expect(not bool(instance.get("_animation_lock")), "Ability card motion should finish within %.1f seconds" % timeout_seconds)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	ProgressionStore.clear_saved_run()
	if _failures.is_empty():
		print("SKILL UI TEST: PASS")
		call_deferred("_quit_after_cleanup", 0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("SKILL UI TEST: FAIL (%d)" % _failures.size())
	call_deferred("_quit_after_cleanup", 1)

func _quit_after_cleanup(exit_code: int) -> void:
	quit(exit_code)

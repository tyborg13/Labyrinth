extends SceneTree

const AnalyticsStore = preload("res://scripts/analytics_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

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
	_test_contextual_run_skill_event_scope(instance)
	run_state = (instance.get("_run_state") as Dictionary).duplicate(true)
	await _test_combat_skill_surfaces(instance, run_state, progression)
	await _test_terminal_skill_event_analytics(instance)
	await _test_respec_clears_stale_combat_preview(instance)
	await _test_reward_reroll(instance)
	await _test_out_of_combat_respec_preserves_unbanked_embers(instance)
	await _test_run_skill_event_cursor_resets_for_new_run(instance)
	await _test_debug_boss_progression_is_sandboxed(instance)
	await _test_content_migration_resaves_resume(instance)

	instance.queue_free()
	for _frame: int in range(4):
		await process_frame
	await create_timer(0.05).timeout
	_finish()

func _test_character_skill_tree(instance: Node) -> void:
	instance.call("_open_card_upgrade_overlay")
	await process_frame
	await process_frame
	var scrim := instance.get("_upgrade_scrim") as Control
	_expect(scrim != null and scrim.visible, "Character menu should open its Skills surface")
	_expect(_button_with_text(scrim, "Skills") != null, "Character menu should expose a Skills tab")
	_expect(_button_with_text(scrim, "Stats") == null, "Character menu should not expose a Stats tab")
	_expect(scrim != null and scrim.find_child("CharacterSkillTree", true, false) != null, "Skills tab should render the shared skill tree")
	_expect(_label_with_text(scrim, "Quick Wits") != null, "Skill tree should show a learned combat ability")
	_expect(_label_with_text(scrim, "Discerning Eye") != null, "Skill tree should show a learned reward ability")
	_expect(_label_containing(scrim, "MOLTSHARDS 2") != null, "Skills surface should show the saved respec resource")

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
	instance.call("_close_card_upgrade_overlay")
	await process_frame

func _test_contextual_run_skill_event_scope(instance: Node) -> void:
	var event_count_before: int = _skill_trigger_event_count("true_bearing")
	instance.call("_analytics_log_run_skill_trigger", "true_bearing", "Chose a different combat entry tile.")
	_expect(_skill_trigger_event_count("true_bearing") == event_count_before + 1, "A contextual run ability should emit one skill-trigger event")
	var payload: Dictionary = _latest_skill_trigger_payload("true_bearing")
	_expect(str(payload.get("trigger_scope", "")) == "run", "Contextual run ability analytics should identify the run event stream")

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
	_expect(sigil != null and sigil.text.contains("2"), "Skill sigil should summarize learned ability count")
	if sigil != null:
		sigil.pressed.emit()
	await process_frame
	var popover := instance.get("_skill_status_popover") as Control
	_expect(popover != null and popover.visible, "Skill sigil should open its status popover")
	_expect(_label_with_text(popover, "Quick Wits") != null, "Skill popover should list the learned combat ability")
	_expect(_label_with_text(popover, "Discerning Eye") != null, "Skill popover should list the learned reward ability")
	_expect(_label_with_text(popover, "READY") != null, "Skill popover should communicate readiness")
	var contextual_skill_ids: Array[String]
	contextual_skill_ids.append_array(["discerning_eye", "deferred_choice", "curators_patience", "true_bearing", "layaway"])
	var contextual_run_state: Dictionary = loaded_combat_run.duplicate(true)
	var contextual_progression: Dictionary = (contextual_run_state.get("progression", {}) as Dictionary).duplicate(true)
	contextual_progression["skill_ids"] = contextual_skill_ids
	contextual_run_state["progression"] = contextual_progression
	instance.set("_run_state", contextual_run_state)
	for contextual_skill_id: String in contextual_skill_ids:
		_expect(str(instance.call("_skill_hud_status", contextual_skill_id)) == "CONTEXT", "%s should remain contextual rather than appearing ready during combat" % contextual_skill_id)
	var primed_run_state: Dictionary = contextual_run_state.duplicate(true)
	var primed_skill_state: Dictionary = (primed_run_state.get("skill_state", {}) as Dictionary).duplicate(true)
	primed_skill_state["pending_card"] = "rime_shard"
	primed_skill_state["pending_relic"] = "flint_edge"
	primed_skill_state["reserved_merchant"] = {"kind": "blacksmith", "item_id": "stitcher_apron"}
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
	instance.set("_combat_state", combat_state)
	instance.call("_close_skill_status_popover")

	var choice_overlay := instance.get("_choice_button_overlay") as Control
	var choice_bar := instance.get("choice_bar") as Control
	var ready_button: Button = _visible_button_with_text(choice_overlay, "Quick Wits")
	if ready_button == null:
		ready_button = _visible_button_with_text(choice_bar, "Quick Wits")
	_expect(ready_button != null, "A ready manual ability should appear beside normal combat choices")
	if ready_button != null:
		ready_button.pressed.emit()
	await process_frame
	var choice_scrim := instance.get("_skill_choice_scrim") as Control
	var choice_list := instance.get("_skill_choice_list") as Control
	_expect(choice_scrim != null and choice_scrim.visible, "Manual ability should open its dedicated choice dialog")
	_expect(_label_with_text(choice_scrim, "Quick Wits") != null, "Manual choice dialog should identify the selected ability")
	_expect(_button_beginning_with(choice_list, "Discard ") != null, "Manual choice dialog should offer cards from the current hand")
	instance.call("_close_skill_choice_dialog")

	var original_combat_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	var original_run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	var escape_combat: Dictionary = original_combat_state.duplicate(true)
	var escape_skills: Array = (escape_combat.get("skill_ids", []) as Array).duplicate()
	escape_skills.append("rehearsed_escape")
	escape_skills.append("makeshift_tool")
	escape_combat["skill_ids"] = escape_skills
	instance.set("_combat_state", escape_combat)
	instance.set("_run_state", run_engine.set_combat_state(original_run_state, escape_combat))
	instance.call("_refresh_ui")
	await process_frame
	var escape_button: Button = _visible_button_with_text(instance.get("_choice_button_overlay") as Control, "Rehearsed Escape")
	if escape_button == null:
		escape_button = _visible_button_with_text(instance.get("choice_bar") as Control, "Rehearsed Escape")
	_expect(escape_button != null, "Rehearsed Escape should appear as an explicit manual combat choice")
	if escape_button != null:
		escape_button.pressed.emit()
	await process_frame
	var escape_flags: Dictionary = ((instance.get("_combat_state") as Dictionary).get("skill_flags", {}) as Dictionary)
	_expect(bool(escape_flags.get("burn_preserve_armed", false)), "Rehearsed Escape should visibly arm before it changes a Burn destination")
	_expect(str(instance.call("_skill_hud_status", "rehearsed_escape")) == "ARMED", "Rehearsed Escape should report ARMED after the player opts in")
	var makeshift_button: Button = _visible_button_with_text(instance.get("_choice_button_overlay") as Control, "Makeshift Tool")
	if makeshift_button == null:
		makeshift_button = _visible_button_with_text(instance.get("choice_bar") as Control, "Makeshift Tool")
	_expect(makeshift_button != null, "Makeshift Tool should appear as an explicit manual combat choice")
	if makeshift_button != null:
		makeshift_button.pressed.emit()
	await process_frame
	escape_flags = ((instance.get("_combat_state") as Dictionary).get("skill_flags", {}) as Dictionary)
	_expect(bool(escape_flags.get("item_preserve_armed", false)), "Makeshift Tool should visibly arm before it changes a consumable destination")
	_expect(str(instance.call("_skill_hud_status", "makeshift_tool")) == "ARMED", "Makeshift Tool should report ARMED after the player opts in")
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
	var prismatic_button: Button = _visible_button_with_text(instance.get("_choice_button_overlay") as Control, "Prismatic Instinct")
	if prismatic_button == null:
		prismatic_button = _visible_button_with_text(instance.get("choice_bar") as Control, "Prismatic Instinct")
	_expect(prismatic_button != null, "A ready Prismatic Instinct should appear with the normal combat controls")
	if prismatic_button != null:
		prismatic_button.pressed.emit()
	await process_frame
	_expect(choice_scrim.visible, "Prismatic Instinct should open the shared card-choice dialog")
	var arm_rime_button: Button = _button_beginning_with(choice_list, "Name Rime Shard")
	_expect(arm_rime_button != null, "Prismatic Instinct should offer an eligible conditional card")
	_expect(_button_beginning_with(choice_list, "Name Quick Stab") == null, "Prismatic Instinct should not offer cards without elemental conditions")
	if arm_rime_button != null:
		arm_rime_button.pressed.emit()
	await process_frame
	var armed_flags: Dictionary = ((instance.get("_combat_state") as Dictionary).get("skill_flags", {}) as Dictionary)
	_expect(bool(armed_flags.get("prismatic_armed", false)) and str(armed_flags.get("prismatic_target_card_id", "")) == "rime_shard", "Prismatic Instinct should bind its arm to the chosen card")
	instance.set("_combat_state", original_combat_state)
	instance.set("_run_state", original_run_state)
	instance.call("_refresh_ui")
	await process_frame

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
	var choice_overlay := instance.get("_choice_button_overlay") as Control
	var choice_bar := instance.get("choice_bar") as Control
	var reroll_button: Button = _visible_button_with_text(choice_overlay, "Reroll Reward")
	if reroll_button == null:
		reroll_button = _visible_button_with_text(choice_bar, "Reroll Reward")
	_expect(reroll_button != null, "Ready reward ability should expose the reroll control")
	if reroll_button != null:
		reroll_button.pressed.emit()
	await process_frame
	await process_frame
	var rerolled_state: Dictionary = instance.get("_run_state") as Dictionary
	var run_engine := RunEngine.new()
	_expect(not run_engine.run_skill_is_ready(rerolled_state, "discerning_eye"), "Using reward reroll should spend it for the current sequence")
	_expect(_visible_button_with_text(instance, "Reroll Reward") == null, "Spent reward reroll should leave the active choice controls")
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
	instance.call("_reconcile_skill_event_analytics_for_state", terminal_combat, active_run)
	var transitioned_run: Dictionary = active_run.duplicate(true)
	transitioned_run["mode"] = "reward"
	transitioned_run["combat_state"] = {}
	instance.set("_run_state", transitioned_run)
	instance.set("_combat_state", {})
	instance.call("_refresh_ui")
	await process_frame
	_expect(_skill_trigger_event_count("afterimage") == event_count_before + 1, "A skill triggered by the terminal action should be logged before combat state is cleared")
	var trigger_payload: Dictionary = _latest_skill_trigger_payload("afterimage")
	_expect(str(trigger_payload.get("trigger_scope", "")) == "combat", "Combat ability analytics should identify the combat event stream")
	instance.set("_analytics_skill_event_revision", prior_analytics_revision)
	instance.set("_run_state", active_run)
	instance.set("_combat_state", active_combat)
	instance.call("_refresh_ui")
	await process_frame

func _test_respec_clears_stale_combat_preview(instance: Node) -> void:
	var stale_preview: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	stale_preview["stale_preview_marker"] = true
	instance.set("_selected_card_index", 0)
	instance.set("_card_action_choice_index", 0)
	instance.set("_preview_combat_state", stale_preview)
	instance.call("_open_character_overlay", "skills")
	await process_frame
	_expect(int(instance.get("_selected_card_index")) == -1, "Opening Character should cancel a selected card before respec")
	_expect(int(instance.get("_card_action_choice_index")) == -1, "Opening Character should clear pending card action choices before respec")
	_expect((instance.get("_preview_combat_state") as Dictionary).is_empty(), "Opening Character should discard any resolved combat preview before respec")
	instance.call("_begin_skill_respec")
	_expect(str(instance.get("_progression_overlay_mode")) == "skills", "Combat should allow viewing the tree but not changing the active build")
	_expect(ProgressionStore.moltshard_count(instance.get("_progression") as Dictionary) == 2, "A blocked combat respec should not consume a Moltshard")
	instance.call("_close_card_upgrade_overlay")
	await process_frame

func _test_out_of_combat_respec_preserves_unbanked_embers(instance: Node) -> void:
	var run_engine := RunEngine.new()
	var reward_state: Dictionary = run_engine.set_held_embers(instance.get("_run_state") as Dictionary, 73)
	var pending_skill_state: Dictionary = (reward_state.get("skill_state", {}) as Dictionary).duplicate(true)
	pending_skill_state["pending_card"] = "rime_shard"
	pending_skill_state["pending_relic"] = "flint_edge"
	pending_skill_state["reserved_merchant"] = {
		"kind": "blacksmith",
		"item_id": "stitcher_apron",
		"origin_coord": Vector2i(3, 0),
	}
	reward_state["skill_state"] = pending_skill_state
	instance.set("_run_state", reward_state)
	instance.call("_open_character_overlay", "skills")
	await process_frame
	instance.call("_begin_skill_respec")
	var proposed_ids: Array[String]
	proposed_ids.append("measured_breath")
	proposed_ids.append("discerning_eye")
	instance.call("_confirm_skill_respec", proposed_ids)
	await process_frame
	var active_run: Dictionary = instance.get("_run_state") as Dictionary
	var saved_profile: Dictionary = ProgressionStore.load_data()
	_expect(ProgressionStore.selected_skill_ids(saved_profile) == proposed_ids, "A non-combat respec should save the complete replacement build")
	_expect(ProgressionStore.moltshard_count(saved_profile) == 1, "A confirmed respec should consume exactly one Moltshard")
	_expect(int(saved_profile.get("embers", -1)) == 0, "Respec must not bank the run's unbanked embers into the persistent profile")
	_expect(run_engine.held_embers(active_run) == 73, "Respec should preserve the run's unbanked embers")
	var active_skill_state: Dictionary = active_run.get("skill_state", {}) as Dictionary
	_expect(str(active_skill_state.get("pending_card", "")) == "rime_shard", "Respec should preserve an already-earned deferred card in the active run")
	_expect(str(active_skill_state.get("pending_relic", "")) == "flint_edge", "Respec should preserve an already-earned deferred relic in the active run")
	_expect(str((active_skill_state.get("reserved_merchant", {}) as Dictionary).get("item_id", "")) == "stitcher_apron", "Respec should preserve already-held merchant stock in the active run")
	var saved_run: Dictionary = ProgressionStore.load_saved_run()
	var saved_skill_state: Dictionary = saved_run.get("skill_state", {}) as Dictionary
	_expect(str(saved_skill_state.get("pending_card", "")) == "rime_shard" and str(saved_skill_state.get("pending_relic", "")) == "flint_edge", "The respec checkpoint should persist earned deferred rewards")
	_expect(str((saved_skill_state.get("reserved_merchant", {}) as Dictionary).get("item_id", "")) == "stitcher_apron", "The respec checkpoint should persist earned Layaway stock")
	instance.call("_close_card_upgrade_overlay")
	await process_frame

func _test_run_skill_event_cursor_resets_for_new_run(instance: Node) -> void:
	var run_engine := RunEngine.new()
	instance.set("_run_skill_event_revision_seen", 9)
	instance.set("_manual_run_skill_event_revision_seen", 9)
	var second_run: Dictionary = run_engine.create_new_run(73032, instance.get("_progression") as Dictionary)
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
	_expect(not bool(instance.call("_skill_respec_can_edit")), "A level-one profile with no learned skills should not offer an impossible respec")
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

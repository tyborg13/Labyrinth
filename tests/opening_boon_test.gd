extends "res://tests/pre_battle_fixture.gd"

const Boons = preload("res://scripts/opening_boon_rules.gd")
const Fixture = preload("res://tests/helpers/opening_boon_fixture.gd")
const Suite = preload("res://tests/suites/opening_boon_suite.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const FOCUS_CYCLES: int = 2
const WALLET_RESUME_EMBERS: int = 120

func _initialize() -> void:
	_setup()
	Analytics.set_storage_dir("user://opening_boon_test_analytics")
	Analytics.clear_storage()
	call_deferred("_run")

func _run() -> void:
	Suite.run(_expect)
	ProgressionStore.save_data(Fixture.profile())
	var state: Dictionary = Fixture.state()
	var scene: Node = await _instance(state)
	_expect(not bool(scene.get("_dialogue_active")), "Boon conversation waits for deliberate talk")
	scene.call("_speak_to_emaciated_man")
	_expect(scene.get("_dialogue_text_label").get_parsed_text() == Boons.definitions()["dialogue"]["offer"], "Offer opener uses exact approved dialogue and existing NPC presentation")
	scene.call("_complete_current_dialogue_line")
	await _settle()
	var flow: RefCounted = scene.get("_opening_boon_flow")
	var modal: Control = flow.get("overlay")
	_expect(modal != null and scene.call("_controller_modal_visible"), "Offer opens as a modal input scope")
	_expect(not bool(scene.get("_large_map_scrim").visible), "Automatic map handoff waits so the boon modal stays over the start room")
	if modal != null:
		await _navigation(modal)
		await _key(KEY_ESCAPE)
		_expect(flow.call("active") and Boons.pending(scene.get("_run_state")), "Esc cannot dismiss or decline the initial offer")
		await _joy(JOY_BUTTON_B)
		_expect(flow.call("active"), "Controller B leaves the explicit offer choice open")
		_expect(bool(scene.get("_dialogue_active")) and not scene.get("_dialogue_footer").visible, "The real NPC dialogue stays visible without offer buttons or a click-to-leave hint")
		_expect(scene.call("_board_status_label", {}) == "", "Choose Door is hidden throughout the boon overlay")
		var gift: Control = modal.find_child("Boon_elemental_gift", true, false)
		_expect(gift != null, "Fixture has the actual Elemental Gift roll")
		if gift != null:
			gift.grab_focus()
			await _key(KEY_ENTER)
			await _settle()
			_expect(modal.find_child("BoonSpellChoices", true, false) != null, "Taking Elemental Gift opens its preroll spell choice")
			await _click(modal.find_child("BackFromBoonSpellChoice", true, false))
			_expect(Boons.pending(scene.get("_run_state")) and modal.find_child("OpeningBoonColumns", true, false) != null, "Pointer Back returns from the secondary choice without granting or charging")
			gift = modal.find_child("Boon_elemental_gift", true, false)
			gift.grab_focus()
			await _key(KEY_ENTER)
			await _settle()
			var choices: Node = modal.find_child("BoonSpellChoices", true, false)
			var first: Control = modal.get("_controls")[0]
			await _pointer(first.get_global_rect().get_center())
			await process_frame
			_expect(modal.get("_secondary_tooltips").visible, "Full spell-card hover opens the existing keyword tooltip stack")
			first.grab_focus()
			await _joy(JOY_BUTTON_A)
			await _settle()
			_expect(not Boons.pending(scene.get("_run_state")) and (scene.get("_run_state") as Dictionary)["attuned_magic_cards"].size() == 7, "Controller accepts one spell into the live deck")
			_expect(scene.get("_dialogue_text_label").get_parsed_text() == Boons.definitions()["dialogue"]["taken"], "Taking uses exact confirmation copy")
			scene.call("_complete_current_dialogue_line")
			scene.call("_advance_dialogue")
	await _heirloom_flow(scene)
	await _terminal_resume_wallet(scene)
	var counts: Dictionary = {}
	for event: Dictionary in Analytics.load_all_events():
		counts[event["event_type"]] = int(counts.get(event["event_type"], 0)) + 1
	_expect(int(counts.get("run_start_boon_offered", 0)) == 1 and int(counts.get("run_start_boon_chosen", 0)) == 1 and int(counts.get("heirloom_left", 0)) == 1, "Live save boundaries append each additive event exactly once")
	await _purge_selection(scene)
	await process_frame
	await process_frame
	scene.queue_free()
	_viewport.queue_free()
	await process_frame
	await process_frame
	print("OPENING BOON TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _navigation(modal: Control) -> void:
	var controls: Array = modal.get("_controls")
	for reverse: bool in [false, true]:
		modal.call("focus_default")
		for index: int in range(controls.size() * FOCUS_CYCLES):
			var event := InputEventKey.new()
			event.keycode = KEY_TAB
			event.shift_pressed = reverse
			event.pressed = true
			_viewport.push_input(event, true)
			await process_frame
			event = event.duplicate()
			event.pressed = false
			_viewport.push_input(event, true)
			await process_frame
			_expect(controls.has(_viewport.gui_get_focus_owner()), "Tab navigation remains inside the boon modal")
	for key: Key in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		await _key(key)
		_expect(controls.has(_viewport.gui_get_focus_owner()), "Directional keyboard navigation remains inside the boon modal")
	for button: JoyButton in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		await _joy(button)
		_expect(controls.has(_viewport.gui_get_focus_owner()), "Controller navigation remains inside the boon modal")
	modal.call("focus_default")
	await _key(KEY_RIGHT)
	_expect(_viewport.gui_get_focus_owner() == controls[1], "Right moves to the next boon card without entering a strip or socket")
	await _key(KEY_DOWN)
	_expect(_viewport.gui_get_focus_owner() == controls.back(), "Down reaches the explicit Take nothing pill")
	await _joy(JOY_BUTTON_DPAD_UP)
	_expect(_viewport.gui_get_focus_owner() == controls[1], "Controller Up returns from the pill to the middle card")
	var map_button: Control = root.find_child("SectionMapButton", true, false)
	if map_button != null:
		map_button.grab_focus()
		await _key(KEY_ENTER)
		_expect(controls.has(_viewport.gui_get_focus_owner()), "Stale toolbar focus is recovered before activation")

func _heirloom_flow(scene: Node) -> void:
	var state: Dictionary = Fixture.state(true)
	state["mode"] = "defeat"
	state["game_over"] = true
	state["player_hp"] = 0
	scene.call("_load_run_state", state)
	scene.call("_refresh_ui")
	await _settle()
	_expect(bool(scene.get("_dialogue_active")) and not bool(scene.get("_run_end_recap").visible), "Heirloom prompt precedes the run summary")
	_expect(scene.get("_dialogue_text_label").get_parsed_text() == Boons.definitions()["dialogue"]["heirloom_prompt"], "Terminal prompt uses exact approved copy")
	scene.call("_persist_committed_boundary", "boon_test_terminal")
	_expect(Boons.heirloom_prompt_pending(ProgressionStore.load_saved_run()), "Unanswered terminal prompt remains resumable")
	var menu: Node = preload("res://scenes/main_menu.tscn").instantiate()
	_expect((menu.call("_build_saved_run_preview", ProgressionStore.load_saved_run()) as Dictionary).get("location", "").ends_with("CHOOSING AN HEIRLOOM"), "Main menu labels the pending terminal heirloom save with the approved wording")
	menu.free()
	scene.call("_complete_current_dialogue_line")
	scene.call("_close_dialogue")
	_expect(bool(scene.get("_dialogue_active")), "Back cannot silently choose Leave nothing at run end")
	var item: String = str(state["equipped_equipment"]["offhand"])
	scene.call("_on_dialogue_option_pressed", {"action": "leave_heirloom", "item": item})
	_expect(ProgressionStore.heirloom(ProgressionStore.load_data()) == item, "Live run-end choice persists replacement heirloom")
	_expect(scene.get("_dialogue_text_label").get_parsed_text() == Boons.definitions()["dialogue"]["heirloom_confirmation"], "Run-end confirmation uses exact approved copy")
	_expect(not bool(scene.get("_run_end_recap").visible), "Summary waits for heirloom confirmation acknowledgment")
	scene.call("_complete_current_dialogue_line")
	scene.call("_advance_dialogue")
	await _settle()
	_expect(bool(scene.get("_run_end_recap").visible) and not ProgressionStore.has_saved_run(), "Acknowledged heirloom releases the normal summary and terminal cleanup")

func _terminal_resume_wallet(scene: Node) -> void:
	var state: Dictionary = Fixture.state()
	state["mode"] = "defeat"
	state["player_hp"] = 0
	state["held_embers"] = WALLET_RESUME_EMBERS
	state["unbanked_embers"] = WALLET_RESUME_EMBERS
	ProgressionStore.save_data(state["progression"])
	scene.call("_load_run_state", state)
	scene.call("_persist_committed_boundary", "boon_test_before_quit")
	var saved: Dictionary = ProgressionStore.load_saved_run()
	_expect(saved.has("heirloom_terminal_wallet") and saved["held_embers"] == 0, "Pending heirloom saves the already processed terminal wallet")
	var marker: Dictionary = ProgressionStore.load_data().get("recovery_marker", {})
	scene.set("_dialogue_script", {})
	scene.call("_close_dialogue")
	scene.call("_load_run_state", saved)
	scene.call("_persist_committed_boundary", "boon_test_after_resume")
	_expect(ProgressionStore.load_data().get("recovery_marker", {}) == marker and int(scene.get("_defeat_lost_amount")) == WALLET_RESUME_EMBERS, "Resuming the heirloom prompt preserves lost Embers and the summary amount")
	state = Fixture.state()
	state["mode"] = "victory"
	state["held_embers"] = WALLET_RESUME_EMBERS
	state["unbanked_embers"] = WALLET_RESUME_EMBERS
	ProgressionStore.save_data(state["progression"])
	scene.call("_load_run_state", state)
	scene.call("_persist_committed_boundary", "boon_test_victory_before_quit")
	saved = ProgressionStore.load_saved_run()
	_expect(int(ProgressionStore.load_data()["embers"]) == WALLET_RESUME_EMBERS, "Victory settles its wallet before the pending heirloom decision")
	scene.call("_start_run")
	_expect(scene.get("_run_engine").held_embers(scene.get("_run_state")) == WALLET_RESUME_EMBERS, "Starting a new descent from a terminal heirloom save preserves the banked victory wallet")

func _purge_selection(scene: Node) -> void:
	var state: Dictionary = Fixture.state()
	ProgressionStore.save_data(state["progression"])
	scene.call("_load_run_state", state)
	scene.call("_speak_to_emaciated_man")
	scene.call("_complete_current_dialogue_line")
	await _settle()
	var modal: Control = scene.get("_opening_boon_flow").overlay
	await _click(modal.find_child("Boon_purge", true, false).find_child("BoonRules", true, false))
	await _settle()
	var choices: Array = modal.get("_controls")
	_expect(choices.size() == 7, "Purge has six separate full starter-card copies and Back")
	var first: Control = choices[0]
	await _click(first)
	_expect(modal.get("_purge_indices") == [0], "First starter copy selects independently")
	await _click(first)
	_expect(modal.get("_purge_indices").is_empty(), "Clicking a selected starter copy deselects it")
	await _click(first)
	await _click(choices[1])
	await _settle()
	var confirmation: Control = modal.get("_confirmation")
	_expect(confirmation != null and confirmation.visible, "Second Purge selection opens the existing confirmation")
	if confirmation != null:
		var name_text: String = str(GameData.card_def(str(first.card_id))["name"])
		_expect(confirmation.question.text.count(name_text) == 2, "Confirmation lists both selected duplicate copies")
		await _click(confirmation.cancel_button)
		_expect(modal.get("_purge_indices").is_empty() and Boons.pending(scene.get("_run_state")), "Cancel clears both Purge selections without spending the boon")
	await _key(KEY_ESCAPE)
	_expect(modal.find_child("OpeningBoonColumns", true, false) != null, "Esc from the secondary step returns to the offer")
	await _click(modal.find_child("Boon_purge", true, false).find_child("BoonRules", true, false))
	await _settle()
	choices = modal.get("_controls")
	await _click(choices[0])
	await _click(choices[1])
	await _settle()
	confirmation = modal.get("_confirmation")
	if confirmation != null: await _click(confirmation.confirm_button)
	_expect(not Boons.pending(scene.get("_run_state")) and scene.get("_run_state")["attuned_magic_cards"].size() == 4, "Only confirmed Purge removes both selected starters")


extends "res://tests/pre_battle_fixture.gd"

const Fixture = preload("res://tests/suites/magic_deck_suite.gd")
const Presentation = preload("res://tests/suites/magic_purge_presentation.gd")
const NAVIGATION_CYCLES: int = 2
const POOR_WALLET: int = 49
const BADGE_VIEWPORT_IDENTITIES: int = 14

func _initialize() -> void:
	_setup()
	var profile: Dictionary = preload("res://scripts/contextual_combat_tutorial.gd").complete_tutorial(ProgressionStore.default_data())
	ProgressionStore.save_data(profile)
	await preload("res://tests/helpers/pile_viewer_duplicate_fixture.gd").run(self, _expect)
	var engine := RunEngine.new()
	var state: Dictionary = Fixture.shop_fixture(engine)
	for id: String in Presentation.EXTRA_SPELLS: state = engine.grant_magic_to_deck(state, id)
	var instance: Node = await _instance(state)
	await preload("res://tests/helpers/pile_copy_badge_checks.gd").assert_count_cases(instance, _viewport, _expect)
	await _badge_viewport_checks(instance, engine)
	for source: String in ["scavenger", "campfire"]:
		state["mode"] = "campfire" if source == "campfire" else "room"
		instance.call("_load_run_state", state)
		instance.call("_close_dialogue")
		await _settle()
		instance.set("_animation_lock", false)
		instance.call("_open_magic_purge", source)
		await _settle()
		var modal: Control = instance.get("_magic_purge_overlay")
		_expect(modal != null, source + " Purge opens")
		if modal == null: continue
		Presentation.assert_grid(modal, state["attuned_magic_cards"], _expect)
		Presentation.assert_polish_text_fit_mutations(modal, _expect)
		await _list_navigation(modal, source)
		await _blocked_toolbar(instance, modal, source)
		await _confirmation_navigation(instance, modal, source)
	# Pointer activation goes through the viewport onto a real card cell.
	state["mode"] = "room"
	instance.call("_load_run_state", state)
	instance.call("_close_dialogue")
	await _settle()
	instance.call("_open_magic_purge", "scavenger")
	await _settle()
	var pointer_modal: Control = instance.get("_magic_purge_overlay")
	await _click(pointer_modal.find_child("MagicPurgeRows", true, false).get_child(0))
	await _settle()
	_expect(not str(pointer_modal.get("pending_card_id")).is_empty(), "Pointer selects the real card")
	await _click(pointer_modal.find_child("CancelMagicPurge", true, false))
	_expect(str(pointer_modal.get("pending_card_id")).is_empty(), "Pointer Back returns to the grid")
	await _click(pointer_modal.find_child("CancelMagicPurgeList", true, false))
	_expect(not is_instance_valid(instance.get("_magic_purge_overlay")), "Pointer X closes the overlay")
	var poor: Dictionary = engine.set_held_embers(state, POOR_WALLET)
	instance.call("_load_run_state", poor)
	instance.call("_close_dialogue")
	await _settle()
	instance.call("_open_magic_purge", "scavenger")
	await _settle()
	var poor_modal: Control = instance.get("_magic_purge_overlay")
	await _key(KEY_ENTER)
	await _settle()
	var back: Button = poor_modal.find_child("CancelMagicPurge", true, false)
	var disabled_purge: Button = poor_modal.find_child("ConfirmMagicPurge", true, false)
	_expect(disabled_purge.disabled and back.has_focus(), "Unaffordable confirmation starts safely on Back")
	for key: Key in [KEY_LEFT, KEY_RIGHT, KEY_TAB]:
		await _key(key)
		_expect(back.has_focus(), "Disabled Purge cannot receive keyboard focus or escape the modal")
	for button: JoyButton in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		await _joy(button)
		_expect(back.has_focus(), "Disabled Purge cannot receive controller focus")
	var poor_before: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	await _key(KEY_ENTER)
	_expect(str(poor_modal.get("pending_card_id")).is_empty() and instance.get("_run_state") == poor_before, "Enter on the only affordable action returns without mutation")
	await _key(KEY_ESCAPE)
	# Empty ownership disables the plate and cannot bypass the open-hook guard.
	state["mode"] = "room"
	state["attuned_magic_cards"] = []
	state = engine.repair_loaded_run_state(state)
	instance.call("_load_run_state", state)
	instance.call("_close_dialogue")
	await _settle()
	var empty_plate: Button = instance.get("_scavenger_shop_view").find_child("ScavengerPurge", true, false)
	_expect(empty_plate.disabled and empty_plate.tooltip_text == "You have no spells to purge.", "Empty deck disables the Scavenger plate with the exact tooltip")
	empty_plate.pressed.emit()
	instance.call("_open_magic_purge", "scavenger")
	_expect(not is_instance_valid(instance.get("_magic_purge_overlay")), "A direct disabled-plate signal or open request cannot open empty Purge")
	state["mode"] = "campfire"
	instance.call("_load_run_state", state)
	instance.call("_close_dialogue")
	instance.call("_open_magic_purge", "campfire")
	_expect(not is_instance_valid(instance.get("_magic_purge_overlay")), "Campfire cannot open an empty Purge overlay")
	# Keep the previous empty fallback only for an unexpected direct configure.
	var defensive := preload("res://scripts/magic_purge_overlay.gd").new()
	instance.get("ui_root").add_child(defensive)
	defensive.configure(instance, state, "campfire", instance.get("_upgrade_dialog").size)
	await _settle()
	_expect(defensive.find_child("MagicPurgeEmpty", true, false).text == preload("res://scripts/event_rules.gd").MAGIC_REQUIREMENT_COPY, "Defensive empty fallback preserves its existing requirement copy")
	defensive.queue_free()
	state["mode"] = "room"
	state = engine.grant_magic_to_deck(state, "pale_spark")
	instance.call("_load_run_state", state)
	instance.call("_close_dialogue")
	await _settle()
	_expect(not empty_plate.disabled and empty_plate.tooltip_text == "Remove a spell from your deck.", "Receiving a spell restores the Scavenger service and normal tooltip")
	# Drain the existing deferred modal/layout refresh before disposing its host.
	for _frame: int in range(Presentation.TEARDOWN_FRAMES): await process_frame
	instance.queue_free()
	_viewport.queue_free()
	for _frame: int in range(Presentation.TEARDOWN_FRAMES): await process_frame
	print("MAGIC DECK INPUT TEST: %s" % ("FAIL" if _failed else "PASS"))
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _badge_viewport_checks(instance: Node, engine: RunEngine) -> void:
	# Two complete rows put duplicate badges on both the rightmost column and
	# the bottom row, unlike the main fixture's centred partial second row.
	var state: Dictionary = Fixture.shop_fixture(engine)
	var cards: Array = Presentation.unique_cards(BADGE_VIEWPORT_IDENTITIES)
	cards.append_array(cards.duplicate())
	state["attuned_magic_cards"] = cards
	state = engine.repair_loaded_run_state(state)
	instance.call("_load_run_state", state)
	instance.call("_close_dialogue")
	await _settle()
	instance.set("_animation_lock", false)
	instance.call("_open_magic_purge", "scavenger")
	await _settle()
	var modal: Control = instance.get("_magic_purge_overlay")
	Presentation.assert_grid(modal, state["attuned_magic_cards"], _expect)
	preload("res://tests/helpers/pile_copy_badge_checks.gd").assert_viewport_mutations(modal, _expect)
	instance.call("_close_magic_purge")
	await _settle()

func _list_navigation(modal: Control, source: String) -> void:
	var controls: Array[Control]
	for row: Control in (modal.get("_rows") as Dictionary).values(): controls.append(row)
	controls.append(modal.find_child("CancelMagicPurgeList", true, false) as Control)
	for failure: String in Presentation.text_fit_failures(modal): _expect(false, source + ": " + failure)
	# Two complete cycles prove both row ordering and wraparound, including the
	# reviewer's fourth-Tab escape. Events go through the viewport, not _input.
	for reverse: bool in [false, true]:
		modal.call("focus_default")
		for index: int in range(controls.size() * NAVIGATION_CYCLES):
			await _tab(reverse)
			var expected: int = posmod((index + 1) * (-1 if reverse else 1), controls.size())
			_expect(_viewport.gui_get_focus_owner() == controls[expected], "%s %s stays in the ordered Purge list at step %d" % [source, "Shift-Tab" if reverse else "Tab", index + 1])
	for key: Key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		modal.call("focus_default")
		for _step: int in range(controls.size() + 1):
			await _key(key)
			_expect(controls.has(_viewport.gui_get_focus_owner()), source + " directional keyboard focus stays in Purge")
	for button: JoyButton in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		modal.call("focus_default")
		for _step: int in range(controls.size() + 1):
			await _joy(button)
			_expect(controls.has(_viewport.gui_get_focus_owner()), source + " directional controller focus stays in Purge")
	modal.call("focus_default")
	if controls.size() > 1:
		await _key(KEY_UP)
		_expect(_viewport.gui_get_focus_owner() == controls.back(), source + " Up from first row reaches X")
		await _key(KEY_DOWN)
		_expect(_viewport.gui_get_focus_owner() == controls[0], source + " Down from X returns to cards")
		await _key(KEY_LEFT)
		_expect(_viewport.gui_get_focus_owner() == controls[controls.size() - 2], source + " Left wraps to the last card")
		await _key(KEY_RIGHT)
		_expect(_viewport.gui_get_focus_owner() == controls[0], source + " Right wraps to the first card")
		if controls.size() > 8:
			await _key(KEY_DOWN)
			_expect(_viewport.gui_get_focus_owner() == controls[7], source + " Down moves to the second row")
			await _key(KEY_UP)
			_expect(_viewport.gui_get_focus_owner() == controls[0], source + " Up moves to the matching first-row card")
	modal.call("focus_default")


func _blocked_toolbar(instance: Node, modal: Control, source: String) -> void:
	var before: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	var map: Button = instance.find_child("SectionMapButton", true, false)
	# Even a stale/external focus owner must not receive an accept event.
	map.grab_focus()
	await _key(KEY_ENTER)
	_expect(not (instance.get("_large_map_scrim") as Control).visible, source + " rejects Enter on an underlying toolbar button")
	_expect(modal.is_ancestor_of(_viewport.gui_get_focus_owner()), source + " recovers stale focus into Purge")
	instance.call("_close_large_map")
	# Toolbar callbacks also reject direct activation while the modal is open.
	for name: String in ["SectionMapButton", "MenuButton", "GrimoireButton", "LoadoutButton"]:
		(instance.find_child(name, true, false) as Button).pressed.emit()
		var blocked: bool = true
		for field: String in ["_large_map_scrim", "_menu_scrim", "_grimoire_scrim", "_upgrade_scrim"]:
			blocked = blocked and not (instance.get(field) as Control).visible
		_expect(blocked, source + " blocks underlying " + name)
		instance.call("_close_large_map")
		instance.call("_close_menu_overlay")
		instance.call("_close_grimoire_overlay")
		instance.call("_close_card_upgrade_overlay")
	instance.call("_open_pile_view", "deck")
	_expect(not (instance.get("_pile_scrim") as Control).visible, source + " blocks an underlying deck-pile action")
	instance.call("_close_pile_view")
	_expect(instance.get("_run_state") == before, source + " navigation never changes run state")
	modal.call("focus_default")

func _confirmation_navigation(instance: Node, modal: Control, source: String) -> void:
	var before: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	await _key(KEY_ENTER)
	await _settle()
	_expect(not str(modal.get("pending_card_id")).is_empty(), source + " Enter selects a spell through the viewport")
	var cancel: Button = modal.find_child("CancelMagicPurge", true, false)
	var confirm: Button = modal.find_child("ConfirmMagicPurge", true, false)
	_expect(cancel.has_focus(), source + " confirmation starts on Back")
	for failure: String in Presentation.text_fit_failures(modal): _expect(false, source + ": " + failure)
	await _tab(false)
	_expect(confirm.has_focus(), source + " confirmation Tab reaches Purge")
	await _tab(false)
	_expect(cancel.has_focus(), source + " confirmation Tab wraps to Back")
	await _tab(true)
	_expect(confirm.has_focus(), source + " confirmation Shift-Tab reaches Purge")
	(instance.find_child("SectionMapButton", true, false) as Button).grab_focus()
	await _key(KEY_ENTER)
	_expect(cancel.has_focus() and not (instance.get("_large_map_scrim") as Control).visible, source + " confirmation recovers stale toolbar focus to Back")
	_expect(instance.get("_run_state") == before, source + " stale focus cannot confirm a purge")
	await _key(KEY_ESCAPE)
	_expect(str(modal.get("pending_card_id")).is_empty(), source + " Escape returns to the list")
	await _joy(JOY_BUTTON_A)
	await _settle()
	_expect(cancel.has_focus(), source + " controller selection starts on Back")
	await _joy(JOY_BUTTON_B)
	_expect(str(modal.get("pending_card_id")).is_empty(), source + " controller B returns to the list")
	_expect(instance.get("_run_state") == before, source + " selection and cancellation preserve ownership and wallet")
	await _joy(JOY_BUTTON_A)
	await _settle()
	await _joy(JOY_BUTTON_DPAD_RIGHT)
	_expect(confirm.has_focus(), source + " controller Right reaches Purge")
	await _joy(JOY_BUTTON_A)
	await _settle()
	_expect(not is_instance_valid(instance.get("_magic_purge_overlay")), source + " controller A confirms and closes Purge")
	var after: Dictionary = instance.get("_run_state")
	_expect(int(after.get("magic_purges_this_run", 0)) == int(before.get("magic_purges_this_run", 0)) + 1, source + " confirmation purges exactly once")

func _tab(reverse: bool) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_TAB
		event.shift_pressed = reverse
		event.pressed = pressed
		_viewport.push_input(event, true)
		await process_frame

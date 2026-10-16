extends "res://tests/pre_battle_fixture.gd"

const Fixture = preload("res://tests/suites/magic_deck_suite.gd")
const NAVIGATION_CYCLES: int = 2

func _initialize() -> void:
	_setup()
	var profile: Dictionary = preload("res://scripts/contextual_combat_tutorial.gd").complete_tutorial(ProgressionStore.default_data())
	ProgressionStore.save_data(profile)
	var engine := RunEngine.new()
	var state: Dictionary = Fixture.shop_fixture(engine)
	var instance: Node = await _instance(state)
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
		await _list_navigation(modal, source)
		await _blocked_toolbar(instance, modal, source)
		await _confirmation_navigation(instance, modal, source)
	# The no-spell case still has one focusable Cancel, with no route out.
	state["attuned_magic_cards"] = []
	instance.call("_load_run_state", engine.repair_loaded_run_state(state))
	instance.call("_close_dialogue")
	await _settle()
	instance.call("_open_magic_purge", "campfire")
	await _settle()
	var empty: Control = instance.get("_magic_purge_overlay")
	_expect(empty != null, "Empty Purge can be cancelled")
	if empty != null:
		await _list_navigation(empty, "empty")
		await _key(KEY_ESCAPE)
		_expect(not is_instance_valid(instance.get("_magic_purge_overlay")), "Escape closes empty Purge")
	instance.queue_free()
	_viewport.queue_free()
	await process_frame
	print("MAGIC DECK INPUT TEST: %s" % ("FAIL" if _failed else "PASS"))
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _list_navigation(modal: Control, source: String) -> void:
	var controls: Array[Control]
	for row: Control in modal.find_child("MagicPurgeRows", true, false).get_children(): controls.append(row)
	controls.append(modal.find_child("CancelMagicPurgeList", true, false) as Control)
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
	_expect(cancel.has_focus(), source + " confirmation starts on Cancel")
	await _tab(false)
	_expect(confirm.has_focus(), source + " confirmation Tab reaches Purge")
	await _tab(false)
	_expect(cancel.has_focus(), source + " confirmation Tab wraps to Cancel")
	await _tab(true)
	_expect(confirm.has_focus(), source + " confirmation Shift-Tab reaches Purge")
	(instance.find_child("SectionMapButton", true, false) as Button).grab_focus()
	await _key(KEY_ENTER)
	_expect(cancel.has_focus() and not (instance.get("_large_map_scrim") as Control).visible, source + " confirmation recovers stale toolbar focus to Cancel")
	_expect(instance.get("_run_state") == before, source + " stale focus cannot confirm a purge")
	await _key(KEY_ESCAPE)
	_expect(str(modal.get("pending_card_id")).is_empty(), source + " Escape returns to the list")
	await _joy(JOY_BUTTON_A)
	await _settle()
	_expect(cancel.has_focus(), source + " controller selection starts on Cancel")
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

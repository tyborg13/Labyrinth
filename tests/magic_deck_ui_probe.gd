extends "res://tests/pre_battle_fixture.gd"

const MagicSuite = preload("res://tests/suites/magic_deck_suite.gd")
const Presentation = preload("res://tests/suites/magic_purge_presentation.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const TEST_ANALYTICS_DIR: String = "user://magic_deck_analytics"
const PROOF_SETTLE_SECONDS: float = 1.0
const OVERFLOW_SCROLL: int = 296
const POOR_WALLET: int = 49
var _output_dir: String
var _native: bool
var _exhaust_requests: int = 0

func _initialize() -> void:
	_setup()
	Analytics.set_storage_dir(TEST_ANALYTICS_DIR)
	Analytics.clear_storage()
	_native = DisplayServer.get_name().to_lower() != "headless"
	_output_dir = "user://probes/purge_02_%d/1920x1080_ui100" % int(Time.get_unix_time_from_system())
	var profile: Dictionary = preload("res://scripts/contextual_combat_tutorial.gd").complete_tutorial(ProgressionStore.default_data())
	ProgressionStore.save_data(profile)
	if _pile_viewer_only():
		await preload("res://tests/helpers/pile_viewer_duplicate_fixture.gd").run(self, _expect, _native)
		_viewport.queue_free()
		for _frame: int in range(Presentation.TEARDOWN_FRAMES): await process_frame
		print("PILE VIEWER DUPLICATE PROBE: %s" % ("FAIL" if _failed else "PASS"))
		print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
		quit(1 if _failed else 0)
		return
	var engine := RunEngine.new()
	var state: Dictionary = MagicSuite.shop_fixture(engine)
	for id: String in Presentation.EXTRA_SPELLS: state = engine.grant_magic_to_deck(state, id)
	var instance: Node = await _instance(state)
	instance.get("_sfx_bank").cue_requested.connect(func(cue_id: String, _result: String) -> void:
		if cue_id == "card.exhaust": _exhaust_requests += 1
	)
	# Keep the prior Character coverage; the panel itself is outside this unit.
	instance.call("_open_character_overlay", "magic")
	await _settle()
	_expect(_labels_text(instance.get("_upgrade_dialog")).contains("14 spells"), "Character retains its 14-spell count")
	await _proof_capture("character_magic_14")
	instance.call("_close_card_upgrade_overlay")
	await _settle()
	var shop: Control = instance.get("_scavenger_shop_view")
	var entry: Button = shop.find_child("ScavengerPurge", true, false)
	var sell: Button = shop.find_child("ScavengerSellMode", true, false)
	_expect(entry != null and entry.text == "Purge a spell" and entry.tooltip_text == "Remove a spell from your deck.", "Scavenger uses the one-line service and tooltip")
	_expect(entry.size == sell.size and entry.get_theme_font_size("font_size") == sell.get_theme_font_size("font_size"), "Purge reuses the Sell plate size and type")
	_expect(entry.get_node("ScavengerPurgePrice/PriceTagInk/PriceTagValue").text == "50", "Service price uses the existing parchment tag")
	var service_label: Label = entry.get("_label")
	_expect(service_label.get_line_count() == 1 and service_label.get_minimum_size().y <= service_label.size.y, "Service label fits on one line")
	_assert_service_text_fit(entry, "enabled Scavenger service")
	_test_service_text_fit_mutation(entry, "enabled")
	await _proof_capture("scavenger_purge_service")
	entry.pressed.emit()
	await _settle()
	var modal: Control = instance.get("_magic_purge_overlay")
	Presentation.assert_grid(modal, state["attuned_magic_cards"], _expect)
	Presentation.assert_polish_text_fit_mutations(modal, _expect)
	await _check_and_capture(modal, "scavenger_grid_14")
	# Real keyboard focus is visible through the CardWidget's existing lift/gold.
	await _key(KEY_RIGHT)
	var focused: Control = _viewport.gui_get_focus_owner()
	_expect(focused != null and focused.get_parent().name == "MagicPurgeRows" and focused.get("widget").get("_external_highlighted"), "Keyboard focus highlights the real card")
	await _check_and_capture(modal, "scavenger_card_focus")
	var original_grid_style: StyleBox = modal.find_child("MagicPurgePanel", true, false).get_theme_stylebox("panel")
	var before: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	modal.call("select_card", "pale_spark")
	await _settle()
	Presentation.assert_confirmation(modal, true, true, MagicSuite.TEST_WALLET, _expect)
	_expect(instance.get("_run_state") == before and _exhaust_requests == 0, "Selection never mutates or plays Exhaust")
	await _check_and_capture(modal, "scavenger_confirm_affordable")
	await _key(KEY_ESCAPE)
	_expect(str(modal.get("pending_card_id")).is_empty() and _exhaust_requests == 0, "Escape returns without Exhaust")
	Presentation.assert_grid(modal, state["attuned_magic_cards"], _expect)
	_expect(modal.find_child("MagicPurgePanel", true, false).get_theme_stylebox("panel") == original_grid_style, "Back restores the exact approved grid panel style resource")
	modal.call("select_card", "pale_spark")
	await _settle()
	(modal.find_child("ConfirmMagicPurge", true, false) as Button).pressed.emit()
	_expect(is_instance_valid(instance.get("_magic_purge_overlay")), "Overlay remains until Exhaust finishes")
	var proxy: Control = modal.find_child("CardProxy", true, false)
	_expect(proxy != null and proxy.z_as_relative and proxy.z_index > 0, "Exhaust renders above the modal scrim")
	# Cancellation and repeated confirms cannot interrupt or repeat the mutation.
	await _key(KEY_ESCAPE)
	if is_instance_valid(instance.get("_magic_purge_overlay")):
		(modal.find_child("ConfirmMagicPurge", true, false) as Button).pressed.emit()
	await create_timer(PROOF_SETTLE_SECONDS).timeout
	_expect(not is_instance_valid(instance.get("_magic_purge_overlay")), "Exhaust closes the overlay after completing")
	var after: Dictionary = instance.get("_run_state")
	_expect(after["attuned_magic_cards"].count("pale_spark") == 1 and engine.held_embers(after) == MagicSuite.TEST_WALLET - 50 and _exhaust_requests == 1, "Scavenger commits one copy, one price and one Exhaust")
	_expect(after["notice"] == "Purged Pale Spark." and _labels_text(shop).contains("Purged Pale Spark."), "Scavenger retains its persisted notice")
	_expect(entry.get_node("ScavengerPurgePrice/PriceTagInk/PriceTagValue").text == "75", "Service price refreshes after payment")
	_expect(ProgressionStore.load_saved_run()["attuned_magic_cards"] == after["attuned_magic_cards"], "Purge persists before closing")
	# Four unique spells use a centred single row.
	var small: Dictionary = MagicSuite.shop_fixture(engine)
	small["attuned_magic_cards"] = Presentation.unique_cards(Presentation.SMALL_IDENTITIES)
	small = engine.repair_loaded_run_state(small)
	modal = await _open(instance, small, "scavenger")
	Presentation.assert_grid(modal, small["attuned_magic_cards"], _expect)
	await _check_and_capture(modal, "scavenger_grid_4")
	instance.call("_close_magic_purge")
	# The service remains available when poor, but the destructive action cannot run.
	var poor: Dictionary = engine.set_held_embers(state, POOR_WALLET)
	modal = await _open(instance, poor, "scavenger")
	_expect(not bool(shop.find_child("ScavengerPurgePrice", true, false).get("affordable")), "Service tag retains its unaffordable treatment")
	modal.call("select_card", "pale_spark")
	await _settle()
	Presentation.assert_confirmation(modal, true, false, POOR_WALLET, _expect)
	await _check_and_capture(modal, "scavenger_confirm_unaffordable")
	var poor_before: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	(modal.find_child("ConfirmMagicPurge", true, false) as Button).pressed.emit()
	_expect(instance.get("_run_state") == poor_before and _exhaust_requests == 1, "Even a direct disabled action cannot remove or charge")
	instance.call("_close_magic_purge")
	# Campfire has the same grid/confirmation, with no price chip or payment.
	var fire: Dictionary = state.duplicate(true)
	fire["mode"] = "campfire"
	fire["player_hp"] = 1
	modal = await _open(instance, fire, "campfire")
	Presentation.assert_grid(modal, fire["attuned_magic_cards"], _expect)
	await _check_and_capture(modal, "campfire_grid")
	modal.call("select_card", "pale_spark")
	await _settle()
	Presentation.assert_confirmation(modal, false, true, MagicSuite.TEST_WALLET, _expect)
	await _check_and_capture(modal, "campfire_confirm")
	(modal.find_child("ConfirmMagicPurge", true, false) as Button).pressed.emit()
	await create_timer(PROOF_SETTLE_SECONDS).timeout
	after = instance.get("_run_state")
	_expect(after["mode"] == "room" and after["player_hp"] == 1 and engine.held_embers(after) == MagicSuite.TEST_WALLET and _exhaust_requests == 2, "Campfire spends its choice without healing or paying")
	var events: Array[Dictionary]
	for event: Dictionary in Analytics.load_all_events():
		if str(event.get("event_type", "")) == "magic_purged": events.append(event)
	_expect(events.size() == 2 and events[0]["payload"]["source"] == "scavenger" and events[0]["payload"]["price"] == 50 and events[1]["payload"]["source"] == "campfire" and events[1]["payload"]["price"] == 0, "Purge analytics retain their exact source and price once per removal")
	var overflow: Dictionary = MagicSuite.shop_fixture(engine)
	overflow["attuned_magic_cards"] = Presentation.unique_cards(Presentation.OVERFLOW_IDENTITIES)
	overflow = engine.repair_loaded_run_state(overflow)
	modal = await _open(instance, overflow, "scavenger")
	Presentation.assert_grid(modal, overflow["attuned_magic_cards"], _expect)
	var scroll: ScrollContainer = modal.find_child("MagicPurgeScroll", true, false)
	scroll.scroll_vertical = OVERFLOW_SCROLL
	await _settle()
	_expect(scroll.scroll_vertical > 0 and scroll.get_v_scroll_bar().visible, "Twenty identities scroll vertically")
	await _check_and_capture(modal, "scavenger_grid_20_scrolled")
	instance.call("_close_magic_purge")
	var settings: Dictionary = Settings.default_settings()
	settings["reduced_motion"] = true
	Settings.apply_settings(settings, null, false)
	instance.set("_settings", settings)
	_expect(instance.call("_reduced_motion_enabled") and Settings.applied_reduced_motion_enabled(), "Reduced-motion proof enables both scene and card motion settings")
	modal = await _open(instance, state, "scavenger")
	await _check_and_capture(modal, "reduced_motion_grid")
	modal.call("select_card", "pale_spark")
	await _settle()
	await _check_and_capture(modal, "reduced_motion_confirm")
	_test_text_fit_mutation(modal)
	# The disabled plate is also player-facing; visit it after all captures so
	# the accepted visual proof states and their sequence stay unchanged.
	instance.call("_close_magic_purge")
	var empty: Dictionary = state.duplicate(true)
	empty["attuned_magic_cards"] = []
	instance.call("_load_run_state", engine.repair_loaded_run_state(empty))
	instance.call("_close_dialogue")
	await _settle()
	entry = shop.find_child("ScavengerPurge", true, false)
	_expect(entry.disabled, "Text-fit proof covers the disabled empty-deck service")
	_assert_service_text_fit(entry, "disabled empty-deck Scavenger service")
	_test_service_text_fit_mutation(entry, "disabled")
	# Drain the existing deferred modal/layout refresh before disposing its host.
	for _frame: int in range(Presentation.TEARDOWN_FRAMES): await process_frame
	instance.queue_free()
	_viewport.queue_free()
	for _frame: int in range(Presentation.TEARDOWN_FRAMES): await process_frame
	print(ProjectSettings.globalize_path(_output_dir))
	print("MAGIC PURGE TEXT FIT TEST: %s" % ("FAIL" if _failed else "PASS"))
	print("MAGIC DECK UI PROBE: %s" % ("FAIL" if _failed else "PASS"))
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _open(instance: Node, state: Dictionary, source: String) -> Control:
	instance.call("_load_run_state", state)
	instance.call("_close_dialogue")
	await _settle()
	instance.set("_animation_lock", false)
	instance.call("_open_magic_purge", source)
	await _settle()
	var modal: Control = instance.get("_magic_purge_overlay")
	_expect(modal != null, "Fixture opens " + source + " Purge")
	if source == "scavenger": _assert_service_text_fit(instance.get("_scavenger_shop_view").find_child("ScavengerPurge", true, false), "Scavenger service after layout")
	return modal

func _check_and_capture(modal: Control, stem: String) -> void:
	await _settle()
	var failures: Array[String] = Presentation.text_fit_failures(modal)
	for failure: String in failures: _expect(false, stem + ": " + failure)
	await _proof_capture(stem)

func _assert_service_text_fit(service: Button, context: String) -> void:
	# Recursion includes the rendered _label and the parchment price tag's
	# nested value label, even when the service is disabled.
	for failure: String in Presentation.text_fit_failures(service): _expect(false, context + ": " + failure)

func _test_service_text_fit_mutation(service: Button, context: String) -> void:
	var label: Label = service.get("_label")
	var label_path: String = str(label.get_path())
	var caught: Array[String] = Presentation.service_label_clipping_failures(service)
	var killed: bool = caught.any(func(value: String) -> bool: return value.begins_with(label_path + " clips Label "))
	_expect(killed, "Nested service label clipping mutation is killed: " + context)
	_assert_service_text_fit(service, "restored " + context + " service")
	print("SERVICE TEXT FIT MUTATION (%s): %s" % [context, "KILLED" if killed else "SURVIVED"])

func _test_text_fit_mutation(modal: Control) -> void:
	# Prove the regression detects a clipped Label and a clipped Button rather
	# than merely asserting implementation constants.
	var label := Label.new()
	label.name = "ClippedLabelMutation"
	label.text = "This regression must catch clipped text"
	label.clip_text = true
	modal.add_child(label)
	label.size.x = 1.0
	var button := Button.new()
	button.name = "ClippedButtonMutation"
	button.text = label.text
	button.clip_text = true
	modal.add_child(button)
	button.size.x = 1.0
	var caught: Array[String] = Presentation.text_fit_failures(modal)
	_expect(caught.any(func(value: String) -> bool: return value.contains("ClippedLabelMutation")) and caught.any(func(value: String) -> bool: return value.contains("ClippedButtonMutation")), "Text-fit mutations are killed for both control types")
	label.queue_free()
	button.queue_free()

func _proof_capture(stem: String) -> void:
	if _native: await _capture("%s/%s.png" % [_output_dir, stem])

func _pile_viewer_only() -> bool:
	# The visual runner forwards no script arguments, so use an explicit
	# environment switch for the director's separate combat capture contract.
	return OS.get_environment("LABYRINTH_PURGE_02_PILE_PROOF") == "1"

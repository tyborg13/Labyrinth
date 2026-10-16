extends "res://tests/pre_battle_fixture.gd"

const MagicSuite = preload("res://tests/suites/magic_deck_suite.gd")
const MagicList = preload("res://scripts/magic_deck_list.gd")
const TEST_ANALYTICS_DIR: String = "user://magic_deck_analytics"
const EXTRA_SPELLS: Array = ["spark_dart", "frostbolt", "firebrand_volley", "chain_bolt", "stone_plate", "gust_step", "root_snare", "static_lash"]
const Analytics = preload("res://scripts/analytics_store.gd")
const PROOF_SETTLE_SECONDS: float = 1.0
var _output_dir: String
var _native: bool
var _exhaust_requests: int = 0

func _initialize() -> void:
	_setup()
	Analytics.set_storage_dir(TEST_ANALYTICS_DIR)
	Analytics.clear_storage()
	_native = DisplayServer.get_name().to_lower() != "headless"
	_output_dir = "user://probes/deck_01_%d/1920x1080_ui100" % int(Time.get_unix_time_from_system())
	var profile: Dictionary = preload("res://scripts/contextual_combat_tutorial.gd").complete_tutorial(ProgressionStore.default_data())
	ProgressionStore.save_data(profile)
	var engine := RunEngine.new()
	var state: Dictionary = engine.create_new_run(MagicSuite.TEST_SEED, profile)
	for id: String in EXTRA_SPELLS: state = engine.grant_magic_to_deck(state, id)
	var instance: Node = await _instance(state)
	var bank: Node = instance.get("_sfx_bank")
	bank.cue_requested.connect(func(cue_id: String, _result: String) -> void:
		if cue_id == "card.exhaust": _exhaust_requests += 1
	)
	instance.call("_open_character_overlay", "magic")
	await _settle()
	var panel: Control = instance.get("_upgrade_dialog")
	_expect(_labels_text(panel).contains("MAGIC IN DECK") and _labels_text(panel).contains("14 spells"), "Character Magic shows its 14-spell count")
	_expect(panel.find_child("MagicInventoryPanel", true, false) == null, "Character has no reserve list")
	var tiles: Dictionary = instance.get("_magic_attuned_tiles")
	_expect(tiles.size() == MagicList.entries(state["attuned_magic_cards"]).size(), "Character has one sorted row per spell identity")
	if not tiles.is_empty(): (tiles[0] as Control).grab_focus()
	await _proof_capture("character_magic_14")
	instance.call("_close_card_upgrade_overlay")
	state = MagicSuite.shop_fixture(engine)
	for id: String in EXTRA_SPELLS: state = engine.grant_magic_to_deck(state, id)
	instance.call("_load_run_state", state)
	instance.call("_close_dialogue")
	await _settle()
	var shop: Control = instance.get("_scavenger_shop_view")
	var entry: Button = shop.find_child("ScavengerPurge", true, false)
	_expect(entry != null and entry.text == "Purge\nRemove a spell from your deck.\n50 Embers", "Scavenger service exposes the approved title, description, and price")
	if entry != null:
		entry.grab_focus()
		var sell: Button = shop.find_child("ScavengerSellMode", true, false)
		_expect(sell.get_node(sell.focus_neighbor_right) == entry, "Scavenger directional focus reaches Purge")
		var service_label: Label = entry.get("_label")
		_expect(service_label.text == entry.text and service_label.size.y >= service_label.get_line_height() * service_label.get_line_count(), "Service text fits the reused shop action without clipping")
		_expect(Rect2(Vector2.ZERO, Vector2(PROBE_VIEWPORT)).encloses(entry.get_global_rect()) and not entry.get_global_rect().intersects(shop.get("_leave_button").get_global_rect()), "Content-sized service fits the viewport beside the existing actions")
	await _proof_capture("scavenger_purge_service")
	if entry != null: entry.pressed.emit()
	await _settle()
	var modal: Control = instance.get("_magic_purge_overlay")
	_expect(modal != null and modal.find_child("MagicPurgeRows", true, false).get_child_count() == tiles.size(), "Purge uses the same counted magic list")
	if modal != null:
		_assert_purge_backdrop(modal)
		_expect(_labels_text(modal).contains("PURGE A SPELL") and _labels_text(modal).contains("MAGIC IN DECK"), "Purge overlay keeps the approved heading and shared magic-list header")
		await _proof_capture("scavenger_purge_list")
		var before: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
		_select_magic_row(modal, "dull_bolt", true)
		await _settle()
		(modal.find_child("CancelMagicPurge", true, false) as Button).pressed.emit()
		_select_magic_row(modal, "pale_spark", true)
		await _settle()
		_assert_purge_confirmation(instance, modal, true)
		_expect(_selected_row_count(modal) == 1, "Selecting another spell leaves exactly one row selected")
		_expect(_labels_text(modal).contains("Purge Pale Spark?"), "Purge requires the authored confirmation question")
		_expect(instance.get("_run_state") == before, "Selection and hover never mutate ownership")
		_expect(_exhaust_requests == 0, "Selection and hover never play the confirmed purge cue")
		await _proof_capture("scavenger_purge_confirm")
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		instance.call("_input", escape)
		_expect(str(modal.get("pending_card_id")).is_empty(), "Cancel returns from confirmation to the list")
		_expect(_selected_row_count(modal) == 0 and _exhaust_requests == 0, "Cancel clears selection without playing Exhaust")
		_select_magic_row(modal, "pale_spark", false)
		await _settle()
		(modal.find_child("ConfirmMagicPurge", true, false) as Button).pressed.emit()
		await _settle()
		var after: Dictionary = instance.get("_run_state")
		_expect(after["attuned_magic_cards"].count("pale_spark") == 1 and engine.held_embers(after) == MagicSuite.TEST_WALLET - 50, "Confirmed Scavenger Purge commits one copy and exact price")
		_expect(after["notice"] == "Purged Pale Spark." and _exhaust_requests == 1, "Saved Scavenger purge shows its notice and reuses Exhaust once")
		_expect(_labels_text(shop).contains("Purged Pale Spark.") and (shop.get("_dialogue_words") as Control).is_visible_in_tree(), "Purge notice appears on the existing fullscreen shop text surface")
		_expect((shop.find_child("ScavengerPurge", true, false) as Button).text == "Purge\nRemove a spell from your deck.\n75 Embers", "Scavenger service refreshes its visible price after a paid purge")
		var purge_events: Array[Dictionary]
		for event: Dictionary in Analytics.load_all_events():
			if str(event.get("event_type", "")) == "magic_purged": purge_events.append(event)
		_expect(purge_events.size() == 1 and purge_events[0]["payload"]["source"] == "scavenger" and purge_events[0]["payload"]["price"] == 50, "Saved purge emits its source and exact price once")
		var saved: Dictionary = ProgressionStore.load_saved_run()
		_expect(saved["attuned_magic_cards"] == after["attuned_magic_cards"], "Purge persists ownership before closing")
	state["mode"] = "campfire"
	state["player_hp"] = 1
	instance.call("_load_run_state", state)
	instance.call("_close_dialogue")
	await create_timer(PROOF_SETTLE_SECONDS).timeout
	var choices: Control = instance.get("_relic_choice_bar")
	var purge_choice: Control
	for child: Node in choices.get_children():
		if str(child.get_meta("choice_id", "")) == "purge": purge_choice = child
	_expect(purge_choice != null, "Campfire retains existing choices and adds Purge")
	if purge_choice != null:
		_expect(_labels_text(purge_choice).contains("Remove a spell from your deck."), "Campfire uses the approved Purge description")
		_expect(purge_choice.get_meta("choice_accent") == preload("res://scripts/ui_palette.gd").DANGER, "Campfire reuses the danger accent")
		_expect(purge_choice.find_child("CampfireChoiceBackground", true, false).texture == null, "Purge uses the text-only choice without another concept's icon")
		_expect(Rect2(Vector2.ZERO, Vector2(PROBE_VIEWPORT)).encloses(purge_choice.get_global_rect()), "Fourth Campfire choice fits the 1920x1080 viewport")
		purge_choice.grab_focus()
	await _proof_capture("campfire_choice")
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	if purge_choice != null: purge_choice.gui_input.emit(accept)
	await _settle()
	modal = instance.get("_magic_purge_overlay")
	if modal != null:
		modal.call("select_card", "pale_spark")
		await _settle()
		_assert_purge_confirmation(instance, modal, false)
		await _proof_capture("campfire_purge_confirm")
		(modal.find_child("ConfirmMagicPurge", true, false) as Button).pressed.emit()
		await _settle()
		var after: Dictionary = instance.get("_run_state")
		_expect(after["mode"] == "room" and after["player_hp"] == 1 and engine.held_embers(after) == MagicSuite.TEST_WALLET, "Campfire confirmation consumes its choice without healing or paying")
		_expect(after["notice"] == "Purged Pale Spark." and _exhaust_requests == 2 and engine.scavenger_purge_price(after) == 50, "Campfire emits the same notice/cue without advancing the paid price")
	var events: Array[Dictionary]
	for event: Dictionary in Analytics.load_all_events():
		if str(event.get("event_type", "")) == "magic_purged": events.append(event)
	_expect(events.size() == 2 and events[1]["payload"]["source"] == "campfire" and events[1]["payload"]["price"] == 0, "Campfire purge emits a zero-price source receipt once")
	instance.queue_free()
	_viewport.queue_free()
	await process_frame
	print(ProjectSettings.globalize_path(_output_dir))
	print("MAGIC DECK UI PROBE: %s" % ("FAIL" if _failed else "PASS"))
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _proof_capture(stem: String) -> void:
	if _native: await _capture("%s/%s.png" % [_output_dir, stem])

func _assert_purge_backdrop(modal: Control) -> void:
	var backdrop: ColorRect = modal.find_child("MagicPurgeBackdrop", true, false)
	_expect(backdrop != null and backdrop.color == Color(Color.BLACK, 0.7) and backdrop.get_global_rect() == Rect2(Vector2.ZERO, Vector2(PROBE_VIEWPORT)), "Purge list and confirmation have one full-screen 70% black backdrop")

func _assert_purge_confirmation(instance: Node, modal: Control, paid: bool) -> void:
	_assert_purge_backdrop(modal)
	var underlying: Control = instance.get("_scavenger_shop_view") if paid else instance.get("_relic_choice_bar")
	var raised: Control = underlying.find_child("TimeCostBadge", true, false) as Control if paid else underlying.get_child(0) as Control
	_expect(raised != null and modal.z_index > _effective_z(raised), "Backdrop is above raised shop price badges and Campfire choices")
	var dialog: Control = modal.find_child("MagicPurgeConfirmationPanel", true, false)
	_expect(dialog.is_visible_in_tree() and dialog.size.is_equal_approx(Vector2(560.0, 240.0)) and dialog.get_global_rect().get_center().is_equal_approx(Vector2(PROBE_VIEWPORT) * 0.5), "Confirmation is centred at exactly 560x240")
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_expect(is_equal_approx(dialog.get_theme_stylebox("panel").get_content_margin(side), 32.0), "Confirmation keeps 32px inner padding")
	_expect(dialog.get_meta("surface_variant") == "dialog", "Confirmation uses the standard modal panel surface")
	var title: Label = modal.find_child("PurgeConfirmationQuestion", true, false)
	_expect(title.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and title.text == "Purge Pale Spark?" and title.get_theme_font_size("font_size") == preload("res://scripts/ui_typography.gd").SIZE_TITLE, "Confirmation question is a centred heading")
	var cancel: Button = modal.find_child("CancelMagicPurge", true, false)
	var confirm: Button = modal.find_child("ConfirmMagicPurge", true, false)
	_expect(cancel.size.is_equal_approx(Vector2(200.0, 52.0)) and confirm.size == cancel.size and is_equal_approx(confirm.global_position.x - cancel.get_global_rect().end.x, 24.0), "Cancel and Purge are 200x52 side by side with a 24px gap")
	_expect(cancel.text == "Cancel" and confirm.text == "Purge" and cancel.alignment == HORIZONTAL_ALIGNMENT_CENTER and confirm.alignment == HORIZONTAL_ALIGNMENT_CENTER, "Both action labels are centred, with Cancel left of Purge")
	_expect(cancel.get_meta("button_variant") == "standard" and (confirm.get_theme_stylebox("normal") as StyleBoxFlat).bg_color == preload("res://scripts/ui_palette.gd").DANGER, "Cancel is secondary and Purge uses UiPalette.DANGER")
	_expect(cancel.has_focus() and instance.call("_controller_focus_scope") == modal.call("focus_scope"), "Keyboard/controller focus starts on Cancel inside the confirmation scope")
	_expect(cancel.get_node(cancel.focus_neighbor_right) == confirm and confirm.get_node(confirm.focus_neighbor_left) == cancel, "Controller focus stays between the confirmation actions")
	_expect(not (modal.find_child("MagicPurgeRows", true, false) as Control).is_visible_in_tree(), "The spell list cannot receive focus behind confirmation")
	var price: Control = modal.find_child("MagicPurgePrice", true, false)
	_expect(price.is_visible_in_tree() == paid, "Only Scavenger confirmation shows a price line")
	if paid:
		_expect(price.get_node("Value").text == "50" and price.get_node("Caption").text == "Embers" and price.get_node("Socket").get("_source_icon") != null, "Scavenger confirmation uses the existing Ember glyph and price styling")

func _effective_z(item: CanvasItem) -> int:
	var depth: int = item.z_index
	var current: CanvasItem = item
	while current.z_as_relative and current.get_parent() is CanvasItem:
		current = current.get_parent() as CanvasItem
		depth += current.z_index
	return depth

func _selected_row_count(modal: Control) -> int:
	var count: int = 0
	for row: Control in modal.find_child("MagicPurgeRows", true, false).get_children():
		if not bool(row.get_meta("magic_purge_selected", false)): continue
		count += 1
		_expect((row.get_theme_stylebox("panel") as StyleBoxFlat).border_color == preload("res://scripts/ui_palette.gd").DANGER, "Selected spell retains the approved destructive accent after focus moves to confirmation")
	return count

func _select_magic_row(modal: Control, card_id: String, pointer: bool) -> void:
	var rows: Control = modal.find_child("MagicPurgeRows", true, false)
	for row: Control in rows.get_children():
		if str(row.get("card_id")) != card_id: continue
		var event: InputEvent
		if pointer:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			event = click
		else:
			var accept := InputEventAction.new()
			accept.action = "ui_accept"
			accept.pressed = true
			event = accept
		row.call("_gui_input", event)
		return
	_expect(false, "Purge list contains the requested magic row")

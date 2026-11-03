extends RefCounted

const Fixture = preload("res://tests/helpers/heirloom_fixture.gd")
const Rules = preload("res://scripts/opening_boon_rules.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Router = preload("res://scripts/input_router.gd")

static func open(driver: SceneTree, scene: Node, count: int) -> Control:
	# These are independent run fixtures sharing one expensive scene instance.
	# Do not carry a previous fixture's deferred notices into its screenshots.
	var queue: Node = scene.get_node_or_null("DeferredRunNotifications")
	if queue != null:
		queue.queued.clear()
		queue.set("_current", {})
		queue.set("_last_persistent", "")
		queue.set("_last_requested", "")
	scene.get("log_label").text = ""
	scene.get("log_overlay").hide()
	var state: Dictionary = Fixture.terminal(count)
	Store.save_data(state["progression"])
	scene.call("_load_run_state", state)
	scene.call("_refresh_ui")
	scene.call("_complete_current_dialogue_line")
	await driver.call("_settle")
	return scene.get("_opening_boon_flow").overlay

static func geometry(view: Control, count: int, expect: Callable) -> void:
	expect.call(view != null and view.cards.size() == count, "Heirloom builds %d eligible cards" % count)
	if view == null: return
	var width: float = count * 316.0 + (count - 1) * 30.0
	expect.call(view.row.size == Vector2(width, 540.0) and view.row.position == Vector2((1920.0 - width) * 0.5, 168.0), "Heirloom row has exact dimensions, 30px gaps and centring")
	expect.call(view.row.position.x >= 24.0 and view.row.get_rect().end.x <= 1896.0, "Five-card row stays inside the 24px safe margin")
	expect.call(view.leave_button.size == Vector2(360.0, 50.0) and view.leave_button.position == Vector2(780.0, 724.0), "Leave nothing uses the exact approved rectangle")
	expect.call(view.header.position.y == 84.0, "Header starts at y84")
	for index: int in range(count):
		var card: Control = view.cards[index]
		expect.call(card.size == Vector2(316.0, 540.0) and card.get_parent().position.x == index * 346.0, "Every card is 316x540 at a 346px pitch")
		expect.call(card.medallion.size == Vector2(204.0, 204.0) and card.art.size == Vector2(192.0, 192.0) and card.art.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Medallion and nearest-filtered art are exactly 204px and 192px")
		expect.call(is_equal_approx(card.position.y, -14.0 if index == 0 else 0.0) and is_equal_approx(card.modulate.r, 1.0 if index == 0 else 0.72), "First-focus lift is exactly 14px and other pieces have 0.72 brightness")
		var spell_rows: Array[Node] = card.find_children("HeirloomSpell_*", "Control", false, false)
		if not spell_rows.is_empty():
			var last: Control = spell_rows.back()
			var inner_border_bottom: float = card.size.y - 25.0
			expect.call(last.get_rect().end.y <= inner_border_bottom - 12.0, "%d-spell piece keeps the last row at least 12px above the real frame's 25px inner inset" % spell_rows.size())
		var title: Label = card.get_node("HeirloomTitle")
		expect.call(title.position.y == 36.0 and title.get_theme_font_size("font_size") == 27 and card.medallion.position.y == title.get_rect().end.y + 16.0, "Title and medallion have exact vertical geometry")
		for label: Node in card.find_children("*", "Label", true, false): expect.call(label.get_theme_font_size("font_size") >= 14, "Every heirloom text preserves the 14px floor")
		for thumb: Node in card.find_children("Thumbnail", "TextureRect", true, false): expect.call(thumb.size == Vector2(64.0, 36.0) and thumb.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "Spell thumbnail is an exact 64x36 cover crop")
		expect.call(card.get_node("BoonSurface/ChoiceSurfaceFinish") != null and card.get_node("BoonColumnTag") != null, "Heirloom reuses the opening boon frame finish and tab")

static func run(driver: SceneTree, scene: Node, expect: Callable) -> void:
	for count: int in range(1, 6):
		var view: Control = await open(driver, scene, count)
		geometry(view, count, expect)
		expect.call(driver.get("_viewport").gui_get_focus_owner() == view.cards[0], "First heirloom has first focus")
	var view: Control = scene.get("_opening_boon_flow").overlay
	await driver.call("_key", KEY_RIGHT)
	expect.call(view.selected_index == 1, "Right moves to the next piece")
	await driver.call("_joy", JOY_BUTTON_DPAD_LEFT)
	expect.call(view.selected_index == 0, "Controller left moves to the previous piece")
	await driver.call("_key", KEY_RIGHT)
	await driver.call("_key", KEY_DOWN)
	expect.call(view.selected_index == 5, "Down moves to Leave nothing")
	await driver.call("_key", KEY_UP)
	expect.call(view.selected_index == 1, "Up returns to the previously focused piece")
	await driver.call("_joy", JOY_BUTTON_B)
	expect.call(view.selected_index == 5 and scene.get("_opening_boon_flow").active(), "B focuses Leave nothing and never closes")
	await driver.call("_key", KEY_ESCAPE)
	expect.call(view.selected_index == 5 and scene.get("_opening_boon_flow").active(), "Escape keeps the prompt open")
	await driver.call("_key", KEY_UP)
	var spell: Control = view.cards[1].find_child("HeirloomSpell_*", true, false)
	await driver.call("_pointer", spell.get_global_rect().get_center())
	await driver.process_frame
	expect.call(is_instance_valid(view.get("_tooltip")), "Spell hover shows the existing card tooltip")
	await driver.call("_joy", JOY_BUTTON_A)
	var ceremony: Control = view.ceremony
	ceremony.fixed_clock = true
	ceremony.seek(Fixture.MID_CLOCK_SECONDS)
	expect.call(not ceremony.reduced_motion and ceremony.get_node("HeirloomFlyingArt").visible, "Normal ceremony takes the flight path at fixed t=0.70")
	expect.call(scene.get("_dialogue_script")["id"] == "opening_boon_heirloom_prompt", "Confirmation does not start before t=1.10")
	ceremony.seek(1.10)
	expect.call(scene.get("_dialogue_script")["id"] == "opening_boon_heirloom_confirmation", "At exactly 1.10s the dialogue changes to confirmation")
	ceremony.seek(1.20)
	expect.call(is_equal_approx(view.cards[1].modulate.a, 0.5), "Chosen card fades from 1.10 to 1.30 seconds")
	await driver.call("_key", KEY_SPACE)
	expect.call(not scene.get("_opening_boon_flow").active() and scene.get("_dialogue_script")["id"] == "opening_boon_heirloom_confirmation", "Any pressed input jumps the ceremony to confirmation")
	expect.call(not scene.get("_run_end_recap").visible, "Recap waits for confirmation acknowledgment")
	scene.call("_complete_current_dialogue_line")
	scene.call("_advance_dialogue")
	expect.call(scene.get("_run_end_recap").visible, "Acknowledgment continues to the unchanged recap")
	var settings: Dictionary = Settings.default_settings()
	settings["reduced_motion"] = true
	Settings.apply_settings(settings, null, false)
	view = await open(driver, scene, 1)
	await driver.call("_key", KEY_ENTER)
	ceremony = view.ceremony
	ceremony.fixed_clock = true
	ceremony.seek(Fixture.CROSSFADE_PROOF_SECONDS)
	expect.call(ceremony.reduced_motion and ceremony.burns.is_empty() and ceremony.duration() == 0.25 and ceremony.get_node_or_null("HeirloomFlyingArt") == null and is_equal_approx(view.row.modulate.a, 0.5), "Reduced motion is exactly a 0.25s crossfade with no flight or particles")
	ceremony.skip()
	expect.call(scene.get("_dialogue_script")["id"] == "opening_boon_heirloom_confirmation", "Reduced ceremony ends in the same confirmation")
	settings["reduced_motion"] = false
	Settings.apply_settings(settings, null, false)
	view = await open(driver, scene, 1)
	await driver.call("_joy", JOY_BUTTON_B)
	await driver.call("_key", KEY_ENTER)
	ceremony = view.ceremony
	ceremony.fixed_clock = true
	expect.call(ceremony.leaving_nothing and ceremony.duration() == 0.25, "Leave nothing takes only the 0.25s fade")
	ceremony.skip()
	expect.call(scene.get("_run_end_recap").visible and not scene.get("_dialogue_active"), "Leave nothing goes straight to recap")
	view = await open(driver, scene, 1)
	await driver.call("_click", view.cards[0])
	expect.call(scene.get("_run_state")[Rules.HEIRLOOM_END_KEY]["item"] == Fixture.PROOF_ITEMS[0], "Pointer click chooses the actual equipped piece")
	view.ceremony.skip()
	view = await open(driver, scene, 0)
	expect.call(view == null and scene.get("_run_end_recap").visible and not scene.get("_dialogue_active"), "Starter-only gear skips all dialogue and opens recap")
	expect.call(scene.get("_run_state")[Rules.HEIRLOOM_END_KEY] == {"item": "", "done": true}, "Live automatic skip records exactly Leave nothing")
	expect.call(scene.get("_run_state")[Rules.EVENTS_KEY].back()["payload"].get("skipped_no_eligible", false), "Live skip emits the additive analytics field")
	await preload("res://tests/helpers/heirloom_feedback_checks.gd").run(driver, scene, expect, open)
	print("HEIRLOOM VIEW CHECKS: completed geometry 1-5, navigation, previews, ceremony skip, reduced motion, recap and automatic skip")

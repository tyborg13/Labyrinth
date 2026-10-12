extends RefCounted

const View = preload("res://scripts/event_view.gd")
const Badges = preload("res://scripts/omen_badges.gd")
const Omens = preload("res://scripts/omen_rules.gd")
const Events = preload("res://scripts/event_rules.gd")
const Data = preload("res://scripts/game_data.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Router = preload("res://scripts/input_router.gd")
const Text = preload("res://scripts/event_view_text.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const FIXTURE_SEED: int = 421
const FIXTURE_FRAMES: int = 2
const FIXTURE_BLOCKED_HP: int = 5
const EXPIRE_PROOF_WAIT_SECONDS: float = 0.32
const CLOSE_PROOF_WAIT_SECONDS: float = 0.2
const CLOSE_PROOF_TIMEOUT_MSEC: int = 1000
const COMBAT_PROOF_SETTLE_SECONDS: float = 1.15
const DEFERRED_CLEANUP_FRAMES: int = 4
const PAINTING_LUMINANCE_TOLERANCE: float = 0.08
const PAINTING_CENTRAL_FRACTION: float = 0.4
const MOTION_SWITCH_PROOF_SECONDS: float = 0.2
const MOTION_RECHECK_PROOF_SECONDS: float = 0.12

static func fixture(id: String, rich: bool = false) -> Dictionary:
	var engine := Run.new()
	var state: Dictionary = engine.create_new_run(FIXTURE_SEED, Store.default_data())
	for room: Dictionary in state["rooms"].values():
		if str(room.get("type", "")) != "event": continue
		state["current_room"] = room["coord"]
		room["event_id"] = id
		state["mode"] = "event"
		break
	state = Events.enter_event(state)
	if rich:
		state["player_hp"] = 99
		state["player_max_hp"] = 99
		state["held_embers"] = 999
		state["unbanked_embers"] = 999
		var items: Array[String]
		for card_id: String in Data.cards():
			if Data.card_is_item(card_id): items.append(card_id)
		state["item_inventory"] = items
		var equipment: Dictionary = {}
		for gear_id: String in Data.equipment():
			var slot: String = str(Data.equipment_def(gear_id).get("slot", ""))
			if not equipment.has(slot): equipment[slot] = gear_id
		state["equipped_equipment"] = equipment
		var spells: Array[String]
		for pool: Array in Data.reward_card_pool_by_rarity().values():
			for card_id: String in pool:
				if spells.size() < 3: spells.append(card_id)
		state["attuned_magic_cards"] = spells
	return state

static func run(expect: Callable) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	tree.root.add_child(viewport)
	var view := View.new()
	viewport.add_child(view)
	var fitted_pages: int = 0
	var engine := Run.new()
	for rich: bool in [false, true]:
		for id: String in Data.events():
			var state: Dictionary = fixture(id, rich)
			view.present(state, true)
			view.finish_animation_for_test()
			for frame: int in range(FIXTURE_FRAMES): await tree.process_frame
			expect.call(view.fit_report().is_empty(), "Fit choices %s rich=%s: %s" % [id, rich, str(view.fit_report())])
			for button: Button in view.choices:
				expect.call(button.available == Events.choice_available(state, id, button.choice_id), "Availability is owned by EventRules: " + id + "/" + button.choice_id)
				for row: RichTextLabel in button.rows:
					expect.call(row.get_content_height() <= row.size.y + 1, "Live shaped choice text fits: " + id)
			fitted_pages += 1
			for choice: Dictionary in Data.event_def(id)["choices"]:
				if not Events.choice_available(state, id, str(choice["id"])): continue
				var result: Dictionary = engine.resolve_map_event(state, str(choice["id"]))
				view.present(result, true)
				view.finish_animation_for_test()
				for frame: int in range(FIXTURE_FRAMES): await tree.process_frame
				expect.call(view.fit_report().is_empty(), "Fit result %s/%s rich=%s: %s" % [id, choice["id"], rich, str(view.fit_report())])
				expect.call(view.continue_button != null and view.continue_button.has_focus(), "Result initially focuses Continue")
				fitted_pages += 1
	# Exercise every random branch's text and outcome rows, rather than only the
	# seed-selected branch. Costs/gains still resolve through the real API.
	var branch_pages: int = 0
	for id: String in Data.events():
		var state: Dictionary = fixture(id, true)
		for choice: Dictionary in Data.event_def(id)["choices"]:
			for variant: Dictionary in effect_variants(choice.get("effects", [])):
				var resolved: Dictionary = Events.apply_effects(state, variant["effects"], Events.rng_for(state, "fit-all-branches"), engine)
				var result: Dictionary = resolved["state"]
				result["event_state"]["page"] = "result"
				result["event_state"]["result_text"] = variant.get("result", choice.get("result", ""))
				result["event_state"]["outcomes"] = resolved["outcomes"]
				view.present(result, true)
				view.finish_animation_for_test()
				for frame: int in range(FIXTURE_FRAMES): await tree.process_frame
				expect.call(view.fit_report().is_empty(), "All outcome branches fit: %s/%s %s" % [id, choice["id"], str(view.fit_report())])
				branch_pages += 1
	# Navigation includes unavailable choices, while initial focus skips them.
	var blocked: Dictionary = fixture("bloodletters_basin")
	blocked["player_hp"] = FIXTURE_BLOCKED_HP
	view.present(blocked, true)
	view.finish_animation_for_test()
	expect.call(view.focused_choice_index() == 1, "Initial focus is first available choice")
	view.move_focus(-1)
	expect.call(view.focused_choice_index() == 0 and not view.choices[0].available, "Unavailable plate remains focusable")
	var selections: Array[String]
	view.choice_requested.connect(func(id: String) -> void: selections.append(id))
	view.activate_choice(0)
	expect.call(selections.is_empty(), "Unavailable plate cannot activate")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	view.handle_input(escape)
	expect.call(selections.is_empty(), "Choices page ignores Back/Escape")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = 1
	view.handle_input(stick)
	expect.call(view.focused_choice_index() == 1, "Controller stick advances focus")
	view.handle_input(stick)
	expect.call(view.focused_choice_index() == 1, "Held stick does not skip choices on repeated motion events")
	stick.axis_value = 0
	view.handle_input(stick)
	view.move_focus(-1)
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	view.handle_input(down)
	expect.call(view.focused_choice_index() == 1, "Down advances focus")
	var dpad := InputEventJoypadButton.new()
	dpad.button_index = JOY_BUTTON_DPAD_DOWN
	dpad.pressed = true
	view.handle_input(dpad)
	expect.call(view.focused_choice_index() == 2, "Controller D-pad advances to the next plate")
	var up := InputEventKey.new()
	up.keycode = KEY_UP
	up.pressed = true
	view.handle_input(up)
	expect.call(view.focused_choice_index() == 1, "Up returns to the previous choice")
	var accept := InputEventAction.new()
	accept.action = Router.ACTION_ACCEPT
	accept.pressed = true
	view.handle_input(accept)
	expect.call(selections.size() == 1 and selections[0] == view.choices[1].choice_id, "Controller A activates focused choice")
	view.handle_input(accept)
	expect.call(selections.size() == 1, "Repeated input cannot reapply a choice")
	for number: int in range(3):
		view.present(fixture("hanged_knight"), true)
		view.finish_animation_for_test()
		var digit := InputEventKey.new()
		digit.keycode = KEY_1 + number
		digit.pressed = true
		view.handle_input(digit)
		expect.call(selections.back() == view.choices[number].choice_id, "Number key %d maps to authored choice" % (number + 1))
	view.present(fixture("hanged_knight"), true)
	view.finish_animation_for_test()
	var controller_a := InputEventJoypadButton.new()
	controller_a.button_index = JOY_BUTTON_A
	controller_a.pressed = true
	view.handle_input(controller_a)
	expect.call(selections.back() == "cut", "Physical controller A activates choice")
	view.present(engine.resolve_map_event(fixture("hanged_knight"), "cut"), true)
	view.finish_animation_for_test()
	view.handle_input(escape)
	expect.call(selections.back() == "continue", "Result Back/Escape activates Continue")
	view.present(fixture("hanged_knight"), true)
	view.finish_animation_for_test()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	view.handle_input(enter)
	expect.call(selections.back() == "cut", "Enter activates initial focus")
	expect.call(Text.markup("50%: Pay 20 Embers. Gain a random Rare relic.", true).contains("#e07a6c") and Text.markup("50%: Pay 20 Embers. Gain a random Rare relic.", true).contains("#e9cf8f"), "Odds preserve neutral prefix and separate cost/gain tones")
	var grid := GridContainer.new()
	viewport.add_child(grid)
	var badges := Badges.new()
	badges.sync(grid, {"omens": [{"id": "stone_vow", "fights_left": 2}, {"id": "hunted", "fights_left": 1}]}, true)
	expect.call(badges.badges.size() == 2 and grid.get_child_count() == 2, "Blessing and bane each have a badge")
	var badge: Control = badges.badges["hunted"]
	expect.call(badge.tooltip_text.contains("1 fights left") and badge.tooltip_text.contains("Bane"), "Tooltip supplies kind and remaining fights")
	expect.call(badge.custom_minimum_size == Vector2(38, 38), "Seal is 38 px at native scale")
	var relic := Control.new()
	grid.add_child(relic)
	badges.clear_relic_children(grid)
	expect.call(grid.get_child_count() == 2, "Relic rebuild preserves omen nodes for boundary expiry fades")
	badges.sync(grid, {"omens": [{"id": "stone_vow", "fights_left": 1}]}, true)
	expect.call(badges.badges.size() == 1, "Expired omen is removed from active badges")
	await tree.create_timer(EXPIRE_PROOF_WAIT_SECONDS).timeout
	expect.call(grid.get_child_count() == 1, "Expired badge fades out and is removed")
	_luminance_contract(expect)
	await _motion(viewport, expect)
	await _integration(viewport, expect)
	var report: Array[String] = view.fit_report()
	expect.call(report.is_empty(), "Final live fit report is empty")
	print("Event view fit: %d pages, 27 events × fresh/rich states; %d outcome branches" % [fitted_pages, branch_pages])
	viewport.queue_free()
	await tree.process_frame

static func effect_variants(effects: Array) -> Array[Dictionary]:
	var variants: Array[Dictionary]
	variants.append({"effects": []})
	for effect: Dictionary in effects:
		if str(effect.get("type", "")) != "random":
			for variant: Dictionary in variants: variant["effects"].append(effect)
			continue
		var next: Array[Dictionary]
		for variant: Dictionary in variants:
			for outcome: Dictionary in effect["outcomes"]:
				for nested: Dictionary in effect_variants(outcome.get("effects", [])):
					var copy: Dictionary = variant.duplicate(true)
					copy["effects"].append_array(nested["effects"])
					if nested.has("result"): copy["result"] = nested["result"]
					elif outcome.has("result"): copy["result"] = outcome["result"]
					next.append(copy)
		variants = next
	return variants

static func _integration(viewport: SubViewport, expect: Callable) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	scene.call("_close_dialogue")
	scene.call("_load_run_state", fixture("moth_library", true))
	await tree.process_frame
	var view: Control = scene.get("_event_view")
	expect.call(view != null and view.visible and not scene.get("_large_map_scrim").visible, "Real event room opens modal with map closed")
	expect.call(not bool(scene.call("_map_shortcut_can_open")), "Event modal blocks map shortcut")
	view.finish_animation_for_test()
	view.choices[0].pressed.emit()
	view.finish_animation_for_test()
	expect.call(str(scene.get("_run_state")["event_state"]["page"]) == "result", "Mouse/keyboard choice signal reaches real rules and result page")
	var close_events: Dictionary = {"count": 0}
	view.closed.connect(func() -> void: close_events["count"] += 1)
	view.continue_button.pressed.emit()
	expect.call(str(scene.get("_run_state")["mode"]) == "reward" and str(scene.get("_run_state")["pending_reward"]["kind"]) == "event", "Continue follows through to granted card choice")
	# A timer can expire before the live close tween has received its final
	# frame. In the merged integration fixture it had advanced only 0.15 of
	# 0.16 seconds at the old 0.2-second timer assertion. Observe completion
	# across frames, with a deadline so a stuck modal still fails the suite.
	await wait_for_close(view)
	expect.call(not view.visible, "Event closes after Continue")
	expect.call(int(close_events["count"]) == 1 and not bool(view.get("_closing")), "Continue completes the live close tween and emits closed exactly once")
	var engine := Run.new()
	scene.call("_load_run_state", engine.skip_reward_for_heal(scene.get("_run_state")))
	await tree.process_frame
	await tree.process_frame
	expect.call(str(scene.get("_run_state")["mode"]) == "room" and bool(scene.get("_large_map_scrim").visible), "Map reopens after the deferred event card choice")
	scene.call("_load_run_state", fixture("hanged_knight"))
	view.finish_animation_for_test()
	scene.call("_on_section_map_event", "cut")
	view.finish_animation_for_test()
	var manager: RefCounted = scene.get("_omen_badges")
	expect.call(manager.badges.has("hunted"), "Gained omen is in real room HUD")
	var router: Node = tree.root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "controller", "xbox")
	scene.call("_refresh_controller_prompts")
	await tree.process_frame
	var prompts: Array = scene.get("_controller_prompt_bar").prompts_snapshot()
	expect.call(prompts.size() == 1 and prompts[0]["label"] == "Continue", "Real controller prompt names focused event action")
	router.call("clear_forced_state_for_test")
	var settings: Dictionary = scene.get("_settings").duplicate(true)
	settings["reduced_motion"] = true
	scene.call("_on_settings_changed", settings)
	expect.call(view.reduced_motion and view.panel.position == View.PANEL_RECT.position and is_equal_approx(float(view.art.material.get_shader_parameter("zoom")), 1.0), "Live settings callback applies reduced motion to an open event")
	scene.call("_load_run_state", combat_fixture())
	await tree.create_timer(COMBAT_PROOF_SETTLE_SECONDS).timeout
	expect.call(str(scene.get("_run_state")["mode"]) == "combat" and manager.badges.size() == 2, "Real combat header includes blessing and bane badges")
	for frame: int in range(DEFERRED_CLEANUP_FRAMES): await tree.process_frame
	scene.queue_free()
	await tree.process_frame

static func wait_for_close(view: Control) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var deadline: int = Time.get_ticks_msec() + CLOSE_PROOF_TIMEOUT_MSEC
	while view.visible and Time.get_ticks_msec() < deadline:
		await tree.process_frame

static func combat_fixture() -> Dictionary:
	var engine := Run.new()
	var state: Dictionary = engine.create_new_run(FIXTURE_SEED, Store.default_data())
	state = Omens.add(Omens.add(state, "stone_vow"), "hunted")
	for destination: Vector2i in engine.available_moves(state):
		if str(engine.room_metadata(state, destination).get("type", "")) == "combat":
			return engine.move_to_room(state, destination)
	return state

static func _motion(viewport: SubViewport, expect: Callable) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var view := View.new()
	viewport.add_child(view)
	view.present(fixture("hanged_knight"), true)
	expect.call(view.panel.position == View.PANEL_RECT.position, "Reduced-motion opening starts with no rise")
	expect.call(is_equal_approx(float(view.art.material.get_shader_parameter("zoom")), 1.0), "Reduced-motion opening starts with no painting zoom")
	await tree.create_timer(MOTION_RECHECK_PROOF_SECONDS).timeout
	expect.call(view.panel.position == View.PANEL_RECT.position and is_equal_approx(float(view.art.material.get_shader_parameter("zoom")), 1.0), "Reduced-motion opening remains fades only across live tween frames")
	view.dismiss()
	await tree.create_timer(CLOSE_PROOF_WAIT_SECONDS).timeout
	view.present(fixture("hanged_knight"), false)
	await tree.create_timer(MOTION_SWITCH_PROOF_SECONDS).timeout
	expect.call(float(view.art.material.get_shader_parameter("zoom")) > 1.0, "Normal opening exercises the painting settle before a settings change")
	view.present(fixture("hanged_knight"), true)
	expect.call(view.reduced_motion and view.panel.position == View.PANEL_RECT.position and is_equal_approx(float(view.art.material.get_shader_parameter("zoom")), 1.0), "Unchanged event signature still applies reduced motion immediately")
	await tree.create_timer(MOTION_RECHECK_PROOF_SECONDS).timeout
	expect.call(view.panel.position == View.PANEL_RECT.position and is_equal_approx(float(view.art.material.get_shader_parameter("zoom")), 1.0), "Cancelled rise/zoom cannot resume after enabling reduced motion")
	view.finish_animation_for_test()
	view.queue_free()
	await tree.process_frame

# The same check runs on actual native captures in event_view_probe.gd.
# Pixel values are compared in their PNG RGB encoding, using Rec.709 weights.
static func painting_luminance_report(capture: Image, source: Image, art_rect: Rect2i) -> Dictionary:
	var reference: Image = source.duplicate()
	var cover_scale: float = maxf(float(art_rect.size.x) / source.get_width(), float(art_rect.size.y) / source.get_height())
	reference.resize(roundi(source.get_width() * cover_scale), roundi(source.get_height() * cover_scale), Image.INTERPOLATE_LANCZOS)
	var offset := Vector2i(int((reference.get_width() - art_rect.size.x) / 2.0), int((reference.get_height() - art_rect.size.y) / 2.0))
	var inset: float = (1.0 - PAINTING_CENTRAL_FRACTION) * 0.5
	var central := Rect2i(Vector2i(roundi(art_rect.size.x * inset), roundi(art_rect.size.y * inset)), Vector2i(roundi(art_rect.size.x * PAINTING_CENTRAL_FRACTION), roundi(art_rect.size.y * PAINTING_CENTRAL_FRACTION)))
	var source_mean: float = _mean_luminance(reference, Rect2i(offset + central.position, central.size))
	var capture_mean: float = _mean_luminance(capture, Rect2i(art_rect.position + central.position, central.size))
	var relative_error: float = absf(capture_mean - source_mean) / source_mean if source_mean > 0.0 else INF
	return {"source_mean": source_mean, "capture_mean": capture_mean, "relative_error": relative_error}

static func _mean_luminance(image: Image, rect: Rect2i) -> float:
	var total: float = 0.0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var pixel: Color = image.get_pixel(x, y)
			total += 0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b
	return total / float(rect.size.x * rect.size.y)

static func _luminance_contract(expect: Callable) -> void:
	var source: Image = Image.load_from_file(Events.art_path("hanged_knight"))
	var drawn: Image = source.duplicate()
	var drawn_size := Vector2i(1062, 728)
	var cover_scale: float = float(drawn_size.y) / source.get_height()
	drawn.resize(roundi(source.get_width() * cover_scale), drawn_size.y, Image.INTERPOLATE_LANCZOS)
	drawn = drawn.get_region(Rect2i(Vector2i(int((drawn.get_width() - drawn_size.x) / 2.0), 0), drawn_size))
	var correct: Dictionary = painting_luminance_report(drawn, source, Rect2i(Vector2i.ZERO, drawn_size))
	expect.call(float(correct["relative_error"]) <= PAINTING_LUMINANCE_TOLERANCE, "Luminance contract accepts the unmodified cover-fit source")
	# Reproduce the reported regression in a private fixture, never in an asset.
	var squared: Image = drawn.duplicate()
	for y: int in range(squared.get_height()):
		for x: int in range(squared.get_width()):
			var pixel: Color = squared.get_pixel(x, y)
			squared.set_pixel(x, y, Color(pixel.r * pixel.r, pixel.g * pixel.g, pixel.b * pixel.b))
	var regression: Dictionary = painting_luminance_report(squared, source, Rect2i(Vector2i.ZERO, drawn_size))
	expect.call(float(regression["relative_error"]) > PAINTING_LUMINANCE_TOLERANCE, "Luminance contract rejects texture multiplied by itself")

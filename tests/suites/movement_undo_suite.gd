extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Rules = preload("res://scripts/movement_undo_rules.gd")
const Fixture = preload("res://tests/suites/player_movement_suite.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Router = preload("res://scripts/input_router.gd")
const Guided = preload("res://scripts/guided_combat_scenario.gd")
const UndoButton = preload("res://scripts/movement_undo_button.gd")

# Invisible deterministic proof defaults, shared by the director's probe.
const FIRST_TILE: Vector2i = Vector2i(3, 4)
const SECOND_TILE: Vector2i = Vector2i(4, 4)
const SETTLE_FRAMES: int = 8
const STORAGE_PREFIX: String = "user://movement_undo"
const FADE_SAMPLE_SECONDS: float = 0.06
const FADE_OPAQUE_CHECK_SECONDS: float = 0.2
const CAPTURE_STALL_MSEC: int = 180 # Invisible fixture for synchronous native readback/PNG stalls.

static func run(expect: Callable) -> void:
	var engine := Combat.new()
	var before: Dictionary = Fixture._state(engine)
	var initial_bytes: PackedByteArray = var_to_bytes(before)
	var after: Dictionary = engine.apply_player_movement(before, SECOND_TILE)
	var rules := Rules.new()
	rules.record_walk(before, after)
	expect.call(rules.available(after), "An ordinary multi-tile free walk is reversible")
	var result: Dictionary = rules.undo(after)
	expect.call(int(result.get("tiles", -1)) == 2, "Undo reports tiles traversed, one order at a time")
	expect.call(var_to_bytes(result.get("state", {})) == initial_bytes and hash(result.get("state", {})) == hash(before), "Walk round trip restores every field and the exact pre-walk state hash")
	expect.call(var_to_bytes(before) == initial_bytes, "Reversibility reporting and history never mutate their inputs")
	expect.call(not rules.available(result.get("state", {})), "A multi-tile walk consumes one history entry")

	var first: Dictionary = engine.apply_player_movement(before, FIRST_TILE)
	var second: Dictionary = engine.apply_player_movement(first, SECOND_TILE)
	rules.record_walk(before, first)
	rules.record_walk(first, second)
	expect.call(rules.undo(second).get("state", {}) == first, "First undo steps back one walk")
	expect.call(rules.undo(first).get("state", {}) == before, "Second undo steps back the preceding walk")
	rules.record_walk(before, first)
	expect.call(not rules.available(first, true) and rules.undo(first, true).is_empty(), "Tutorial hard gate disables undo without consuming history")
	expect.call(rules.available(first), "Undo becomes available again when the tutorial gate releases")

	for cause: String in ["trap", "item", "embers", "fire", "ice", "electrified", "bleed"]:
		var fixture: Dictionary = Fixture._state(engine)
		match cause:
			"trap": fixture["traps"] = [{"pos": SECOND_TILE, "element": "fire", "damage": 3}]
			"item": fixture["loot"] = [{"id": "undo_item", "kind": "item", "card_id": "crimson_draught", "pos": SECOND_TILE}]
			"embers": fixture["loot"] = [{"id": "undo_embers", "kind": "embers", "amount": 3, "pos": SECOND_TILE}]
			"fire", "ice", "electrified": Surface.place(fixture, SECOND_TILE, cause)
		# Electrified alone has no arrival rider in the current rules. Layer Fire
		# to exercise actual contact damage on the conducting tile.
		if cause == "electrified": Surface.place(fixture, SECOND_TILE, "fire")
		var safe: Dictionary = engine.apply_player_movement(fixture, FIRST_TILE)
		var history := Rules.new()
		history.record_walk(fixture, safe)
		expect.call(history.available(safe), "%s fixture begins with a reversible walk" % cause)
		if cause == "bleed":
			# Status existed before this walk; the prior safe snapshot is adjusted
			# solely for constructing a realistic mid-activation damage witness.
			safe["player"]["bleed"] = 2
		var committed: Dictionary = engine.apply_player_movement(safe, SECOND_TILE)
		expect.call(not bool(committed["last_player_movement"]["undo_report"]["reversible"]), "%s walk must fail closed" % cause)
		history.record_walk(safe, committed)
		expect.call(not history.available(committed) and history.last_walk_committed, "%s commits itself and preceding history" % cause)
		expect.call(history.undo(committed).is_empty(), "%s cannot be undone" % cause)

	var umbra: Dictionary = Fixture._state(engine)
	umbra["umbra"]["stage"] = "heart"
	var revealed: Dictionary = engine.apply_player_movement(umbra, FIRST_TILE)
	expect.call((revealed["last_player_movement"]["undo_report"]["changed_fields"] as Array).has("derived.umbra_visible_tiles"), "Derived tile visibility changes commit a walk even without a saved reveal field")
	umbra["enemies"][0]["pos"] = Vector2i(5, 4)
	revealed = engine.apply_player_movement(umbra, FIRST_TILE)
	expect.call(not engine.is_tile_visible_to_player(umbra, Vector2i(5, 4)) and engine.is_tile_visible_to_player(revealed, Vector2i(5, 4)) and not revealed["last_player_movement"]["undo_report"]["reversible"], "Revealing an enemy cannot leak information through undo")

	# A visibility excursion in a multi-tile path is unsafe even when endpoint
	# and origin happen to share the same view.
	var excursion: Array[Vector2i]
	excursion.assign([Vector2i(2, 4), FIRST_TILE, Vector2i(2, 4)])
	var returned: Dictionary = umbra.duplicate(true)
	returned["last_player_movement"] = {"resolved": true, "action_type": "move"}
	expect.call(not (Rules.walk_report(engine, umbra, returned, excursion)["changed_fields"] as Array).is_empty(), "Intermediate visibility changes are included in the generic report")

	var rubble: Dictionary = Fixture._state(engine)
	Surface.place(rubble, FIRST_TILE, "rubble")
	var rubble_walk: Dictionary = engine.apply_player_movement(rubble, FIRST_TILE)
	expect.call(bool(rubble_walk["last_player_movement"]["undo_report"]["reversible"]), "Rubble cost changes only the pool and remains reversible")
	var conducting: Dictionary = Fixture._state(engine)
	Surface.place(conducting, FIRST_TILE, "electrified")
	var conducting_walk: Dictionary = engine.apply_player_movement(conducting, FIRST_TILE)
	expect.call(bool(conducting_walk["last_player_movement"]["undo_report"]["reversible"]), "A surface with no arrival effect preserves existing movement rules")

	for boundary: String in ["card", "pass", "activation", "enemy"]:
		rules.clear()
		rules.record_walk(before, first)
		var changed: Dictionary = first.duplicate(true)
		match boundary:
			"card": changed = engine.finish_player_card(first, 0)
			"pass": changed = engine.finish_player_activation(first)
			"activation": changed = engine.prepare_next_player_turn(first)
			"enemy": changed["current_actor"] = {"kind": "enemy", "key": "enemy_1"}
		rules.observe(changed)
		expect.call(not rules.available(changed), "%s boundary invalidates all undo history" % boundary)

	for field: String in ["unknown_mechanic", "rng_state", "initiative_clock", "surface_event_sequence", "death_rewards", "reaction"]:
		var changed: Dictionary = first.duplicate(true)
		match field:
			"unknown_mechanic": changed["turn_flags"]["future_mechanic"] = {"nested": 1}
			"death_rewards": changed["death_rewards"].append({"new_reward": 1})
			"reaction": changed["enemies"][0]["block"] += 1
			_: changed[field] = int(changed.get(field, 0)) + 1
		expect.call(not bool(Rules.walk_report(engine, before, changed, _path())["reversible"]), "Unknown fields, RNG, clock, rewards, events and enemy reactions default to committed: %s" % field)
	var unknown: Dictionary = first.duplicate(true)
	unknown["last_player_movement"]["future_event"] = true
	expect.call(not Rules.changed_fields(before, unknown).is_empty(), "New request fields are not implicitly allowlisted")
	var removed: Dictionary = before.duplicate(true)
	removed.erase("rng_state")
	expect.call(Rules.changed_fields(before, removed).has("rng_state"), "Removing a state field also fails closed")

	var blink_before: Dictionary = Fixture._state(engine, [], ["ghost_stride"])
	blink_before = engine.arm_ghost_stride(blink_before)
	var blink_after: Dictionary = engine.apply_player_movement(blink_before, FIRST_TILE)
	expect.call(not bool(blink_after["last_player_movement"]["undo_report"]["reversible"]), "Ghost Stride and its skill consequence are never classified as free walks")
	var lethal: Dictionary = Fixture._state(engine)
	lethal["player"]["bleed"] = lethal["player"]["hp"]
	var killed: Dictionary = engine.apply_player_movement(lethal, FIRST_TILE)
	expect.call(killed["last_player_movement"]["resolved"] and not killed["last_player_movement"]["undo_report"]["reversible"], "Zero-step Bleed death commits instead of retaining undo")
	print("MOVEMENT UNDO RULES: completed")

static func _path() -> Array[Vector2i]:
	var result: Array[Vector2i]
	result.assign([Vector2i(2, 4), FIRST_TILE])
	return result

static func prepare_storage() -> void:
	Store.set_storage_path(STORAGE_PREFIX + "_profile.json")
	Store.set_run_storage_path(STORAGE_PREFIX + "_run.save")
	Settings.set_storage_path(STORAGE_PREFIX + "_settings.json")
	Analytics.set_storage_dir(STORAGE_PREFIX + "_events")
	Analytics.clear_storage()
	Store.clear_saved_run()
	var profile: Dictionary = Store.default_data()
	profile[Tutorial.PROGRESSION_KEY] = {"version": Tutorial.VERSION, "status": "dismissed", "completed_steps": []}
	Store.save_data(profile)
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	Settings.save_settings(settings)
	Settings.apply_settings(settings, null, false)

static func install(host: Node, state: Dictionary = {}) -> Dictionary:
	var engine := Combat.new()
	var fixture: Dictionary = Fixture._state(engine) if state.is_empty() else state
	fixture["deck"]["hand"] = ["brace", "quick_stab"]
	var run: Dictionary = host.get("_run_state").duplicate(true)
	run["mode"] = "combat"
	run["current_room"] = fixture["room_coord"]
	run["current_room_layout"] = Fixture._room()
	run["combat_state"] = fixture.duplicate(true)
	host.set("_run_state", run)
	host.set("_animation_lock", false)
	host.get("_movement_undo_button").clear_history()
	host.call("_sync_combat_state_from_run")
	host.call("_refresh_ui")
	return host.get("_combat_state").duplicate(true)

static func walk(host: Node, tile: Vector2i = FIRST_TILE) -> void:
	await host.call("_on_board_tile_clicked", host.get("_combat_state")["player"]["pos"])
	await host.call("_on_board_tile_clicked", tile)

static func settle(tree: SceneTree) -> void:
	for frame: int in range(SETTLE_FRAMES): await tree.process_frame

static func settle_hand_layout(tree: SceneTree, host: Node) -> void:
	await settle(tree)
	while int(host.get("_hand_layout_pending_revision")) == int(host.get("_hand_layout_revision")):
		await tree.process_frame
	host.call("_layout_combat_action_dock")

static func wait_for_wall_clock(tree: SceneTree, started_usec: int, elapsed_seconds: float) -> void:
	# A SceneTreeTimer created late in a slow native frame can consume that
	# frame's earlier delta and fire immediately. Sample actual elapsed time,
	# then give the renderer's pre-draw update a chance to submit the live alpha.
	var deadline_usec: int = started_usec + int(elapsed_seconds * 1000000.0)
	while Time.get_ticks_usec() < deadline_usec: await tree.process_frame
	if DisplayServer.get_name() == "headless":
		await tree.process_frame
	else:
		await RenderingServer.frame_pre_draw

static func set_reduced_motion(host: Node, enabled: bool) -> void:
	# RunScene gates animations using its own settings; the cutout reads the
	# applied preference. Changing only the latter silently skips the undo fade.
	var settings: Dictionary = host.get("_settings").duplicate(true)
	settings["reduced_motion"] = enabled
	Settings.apply_settings(settings, null, false)
	host.call("_on_settings_changed", settings)

static func drawn_hero_rig(host: Node, expect: Callable) -> CanvasItem:
	var board: Control = host.get("board_view")
	var unit: Dictionary = {"type": "player", "key": "player"}
	var renderer: Node = board.unit_cutout_renderer(unit)
	var drawn_texture: Texture2D = board.call("_texture_for_unit", unit)
	var renderer_texture: Texture2D = renderer.call("texture")
	expect.call(drawn_texture.get_rid() == renderer_texture.get_rid(), "Drawn hero texture comes from the sampled renderer")
	for layer: Control in board.call("_retained_render_layers"):
		expect.call(layer.unit_cutout_renderer(unit) == renderer, "Retained board layers use the same live hero renderer")
	var rig: CanvasItem = renderer.get("rigs")[str(renderer.get("facing"))]
	expect.call(rig.visible, "Fade sample uses the visible hero facing, not a hidden or discarded rig")
	return rig

static func run_live(tree: SceneTree, expect: Callable) -> void:
	prepare_storage()
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	tree.root.add_child(scene)
	await settle(tree)
	var before: Dictionary = install(scene)
	await settle_hand_layout(tree, scene)
	await walk(scene)
	await settle_hand_layout(tree, scene)
	print("MOVEMENT UNDO INTEGRATION: initial walk")
	var button: Button = scene.get("_movement_undo_button")
	expect.call(button.visible and button.undo_available(), "Production movement commit exposes the mouse button")
	var meter: Control = scene.get("_movement_meter")
	var dock_after_walk: Rect2 = meter.get_global_rect()
	button.hide()
	expect.call(meter.get_global_rect() == dock_after_walk, "Hiding the overlay leaves the settled resource dock unchanged")
	button.refresh()
	expect.call(button.visible and meter.get_global_rect() == dock_after_walk, "Showing the overlay leaves the settled resource dock unchanged")
	expect.call(button.size.x == meter.size.x and button.global_position.y == meter.get_global_rect().end.y + UndoButton.UNDO_BUTTON_GAP, "Button sits below the final chip at its authored gap and exactly its width")
	await scene.call("_on_card_pressed", 0)
	expect.call(button.undo_available(), "Selecting and aiming a card retains undo")
	await scene.call("_on_cancel_requested")
	expect.call(button.undo_available(), "Cancelling a card retains undo")
	set_reduced_motion(scene, false)
	expect.call(not scene.call("_reduced_motion_enabled"), "Normal undo fixture actually disables RunScene's reduced-motion gate")
	button.pressed.emit()
	var fade_started_usec: int = Time.get_ticks_usec()
	await wait_for_wall_clock(tree, fade_started_usec, FADE_SAMPLE_SECONDS)
	var fading_rig: CanvasItem = drawn_hero_rig(scene, expect)
	expect.call(fading_rig.modulate.a > 0.0 and fading_rig.modulate.a < 1.0, "Production undo fades the drawn hero at 0.06 seconds")
	expect.call(scene.get("_combat_state") == before, "Normal undo restores exact combat state before the fade completes")
	await wait_for_wall_clock(tree, fade_started_usec, FADE_OPAQUE_CHECK_SECONDS)
	expect.call(drawn_hero_rig(scene, expect).modulate.a == 1.0, "Drawn hero reaches full opacity by 0.2 seconds")
	set_reduced_motion(scene, true)
	expect.call(scene.call("_reduced_motion_enabled"), "Reduced-motion fixture enables the actual animation gate")
	await settle(tree)
	expect.call(scene.get("_combat_state") == before and not button.visible, "Mouse button restores exact state and hides without reserving space")
	expect.call(meter.get_global_rect() == dock_after_walk, "Dock after undo equals the settled dock after walk")
	for modifier: String in ["", "ctrl", "meta"]:
		await walk(scene)
		var key := InputEventKey.new()
		key.physical_keycode = KEY_Z
		key.pressed = true
		key.ctrl_pressed = modifier == "ctrl"
		key.meta_pressed = modifier == "meta"
		set_reduced_motion(scene, false)
		scene.get_viewport().push_input(key, true)
		expect.call(scene.get_viewport().is_input_handled() and scene.get("_animation_lock"), "Undo key is consumed synchronously before its animation completes")
		await wait_for_wall_clock(tree, Time.get_ticks_usec(), FADE_OPAQUE_CHECK_SECONDS)
		expect.call(scene.get("_combat_state") == before, "Keyboard Z with %s modifier restores exact state" % modifier)
	set_reduced_motion(scene, true)
	await walk(scene)
	var router: Node = tree.root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "controller", "steam_deck")
	scene.call("_refresh_controller_prompts")
	var prompts: Array = scene.get("_controller_prompt_bar").prompts_snapshot()
	expect.call(prompts.any(func(prompt: Dictionary) -> bool: return prompt.get("label") == "Undo move" and prompt.get("action") == str(Router.ACTION_UNDO_MOVE)), "Available undo adds the controller prompt")
	expect.call(Router.glyph_label_for_family(Router.ACTION_UNDO_MOVE, "steam_deck") == "L2" and Router.glyph_label_for_family(Router.ACTION_UNDO_MOVE, "xbox") == "LT", "Controller undo uses left trigger with the correct device glyph")
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_LEFT
	trigger.axis_value = 1.0
	await scene.call("_handle_controller_input", trigger)
	expect.call(scene.get("_combat_state") == before, "Controller left trigger restores exact state")
	scene.call("_refresh_controller_prompts")
	await settle(tree)
	prompts = scene.get("_controller_prompt_bar").prompts_snapshot()
	expect.call(not prompts.any(func(prompt: Dictionary) -> bool: return prompt.get("label") == "Undo move"), "Unavailable undo removes its prompt")
	trigger.axis_value = 0.0
	await scene.call("_handle_controller_input", trigger)
	router.call("set_forced_state_for_test", "pointer", "steam_deck")
	var undo_events: Array[Dictionary]
	for event: Dictionary in Analytics.load_all_events():
		if event.get("event_type") == "player_move_undone": undo_events.append(event)
	expect.call(undo_events.size() == 5, "Exactly one append-only event is written for each successful mouse/key/controller undo")
	for event: Dictionary in undo_events:
		var payload: Dictionary = event["payload"]
		expect.call(payload.size() == 2 and int(payload.get("tiles", -1)) == 1 and int(payload.get("activation_seq", -1)) == int(before["activation_seq"]), "Undo analytics carries exactly tiles and activation_seq after JSON normalization")
	await button.request_undo()
	expect.call(Analytics.load_all_events().filter(func(event: Dictionary) -> bool: return event.get("event_type") == "player_move_undone").size() == 5, "Unavailable undo appends no event")

	await walk(scene)
	var first_live: Dictionary = scene.get("_combat_state").duplicate(true)
	await walk(scene, SECOND_TILE)
	await button.request_undo()
	expect.call(scene.get("_combat_state") == first_live and button.undo_available(), "Production history survives a second reversible commit")
	await button.request_undo()
	expect.call(scene.get("_combat_state") == before, "Two production undos restore the exact initial state")

	var guided_fixture: Dictionary = Fixture._state(Combat.new())
	guided_fixture[Guided.STATE_KEY] = {"version": Guided.VERSION}
	var guided_before: Dictionary = install(scene, guided_fixture)
	await walk(scene)
	var guided_after: Dictionary = scene.get("_combat_state").duplicate(true)
	var profile: Dictionary = scene.get("_progression").duplicate(true)
	var active_profile: Dictionary = profile.duplicate(true)
	active_profile[Tutorial.PROGRESSION_KEY] = Tutorial.default_state()
	scene.set("_progression", active_profile)
	scene.set("_guided_tutorial_phase_id", Tutorial.PHASE_SELECT_PLAYER)
	var tutorial_host: Control = scene.get("_contextual_combat_prompt_host")
	tutorial_host.visible = true
	expect.call(scene.call("_guided_tutorial_hard_gate_active"), "Guided integration fixture exercises a real hard gate")
	await button.request_undo()
	expect.call(scene.get("_combat_state") == guided_after and not button.undo_available(), "Production mouse undo is disabled during the guided hard gate")
	scene.call("_refresh_controller_prompts")
	await settle(tree)
	expect.call(not scene.get("_controller_prompt_bar").prompts_snapshot().any(func(prompt: Dictionary) -> bool: return prompt.get("label") == "Undo move"), "Tutorial early-return prompts never retain Undo move")
	scene.set("_progression", profile)
	scene.set("_guided_tutorial_phase_id", "")
	tutorial_host.visible = false
	expect.call(button.undo_available(), "Tutorial gating does not consume a reversible history entry")
	await button.request_undo()
	expect.call(scene.get("_combat_state") == guided_before, "Guided gate release permits exact restoration")
	before = install(scene)

	await walk(scene)
	var saved: Dictionary = Store.load_saved_run()
	expect.call(saved["combat_state"] == scene.get("_combat_state"), "Movement save keeps its ordinary committed combat state")
	var loaded_rules := Rules.new()
	expect.call(not loaded_rules.available(saved["combat_state"]), "Save/load creates empty ephemeral undo history")
	expect.call(not saved.has("movement_undo_history") and not saved["combat_state"].has("movement_undo_history"), "Undo snapshots never enter saves")
	scene.call("_load_run_state", saved)
	expect.call(not button.rules.available(scene.get("_combat_state")), "Reloading the same mid-activation save clears live history too")
	install(scene)
	await walk(scene)

	# Actual production commit begins by clearing history, before its first await.
	await scene.call("_on_card_pressed", 0)
	await scene.call("_on_board_tile_clicked", FIRST_TILE)
	expect.call(not button.rules.available(scene.get("_combat_state")), "Actual card commit clears history")
	install(scene)
	await walk(scene)
	# Match the existing Turn Clock headless fixture: supply only the absent
	# render boundary signal, never a capture or a substitute for native proof.
	var headless_render_boundary: Callable = func() -> void: RenderingServer.frame_post_draw.emit()
	if DisplayServer.get_name() == "headless": tree.process_frame.connect(headless_render_boundary)
	await scene.call("_on_pass_turn_pressed")
	if tree.process_frame.is_connected(headless_render_boundary): tree.process_frame.disconnect(headless_render_boundary)
	expect.call(not button.rules.available(scene.get("_combat_state")), "Actual Pass/enemy phase clears history")
	set_reduced_motion(scene, false)
	button.call("_fade_hero_back")
	var stalled_fade_started: int = Time.get_ticks_usec()
	expect.call(bool(button.hero_fade_snapshot()["coroutine_running"]), "Fade diagnostics report the waiting presentation coroutine")
	OS.delay_msec(CAPTURE_STALL_MSEC)
	await wait_for_wall_clock(tree, stalled_fade_started, FADE_OPAQUE_CHECK_SECONDS)
	var completed_fade: Dictionary = button.hero_fade_snapshot()
	expect.call(completed_fade["alpha"] == 1.0 and not completed_fade["running"] and not completed_fade["coroutine_running"], "A native-style capture stall completes with exactly opaque drawn rig on the next frame")
	expect.call(completed_fade["completion_reason"] == "completed", "Deadline completion is explicit after a stalled frame")
	button.call("_fade_hero_back")
	button.clear_history()
	var interrupted_fade: Dictionary = button.hero_fade_snapshot()
	expect.call(interrupted_fade["alpha"] == 1.0 and not interrupted_fade["running"] and not interrupted_fade["coroutine_running"], "History/load interruption restores exact opacity and ends the coroutine immediately")
	for rig: CanvasItem in scene.get("board_view").unit_cutout_renderer({"type": "player"}).get("rigs").values():
		expect.call(rig.modulate.a == 1.0, "Interruption restores every hero facing to exactly 1.0")
	button.call("_fade_hero_back")
	set_reduced_motion(scene, true)
	await settle(tree)
	expect.call(button.hero_fade_snapshot()["alpha"] == 1.0 and not button.hero_fade_snapshot()["coroutine_running"], "Changing reduced motion during fade restores the drawn hero completely")
	scene.queue_free()
	await tree.process_frame
	print("MOVEMENT UNDO INTEGRATION: completed")

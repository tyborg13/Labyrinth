extends RefCounted

const Flow = preload("res://scripts/start_room_map_flow.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Dialogue = preload("res://scripts/dialogue_engine.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Router = preload("res://scripts/input_router.gd")
const Score = preload("res://scripts/run_score_rules.gd")
const Typography = preload("res://scripts/ui_typography.gd")

# Invisible deterministic fixtures and synchronization limits.
const FIXTURE_SEED: int = 81
const SETTLE_FRAMES: int = 8
const WAIT_TIMEOUT_MSEC: int = 5000
const NARRATION_INPUT_LIMIT: int = 20
const OUT_OF_LINES_INDEX: int = 999
const STORAGE_PREFIX: String = "user://start_room_map"

class FixedProofClock extends Score:
	# Wall-clock duration is deliberately fixed so state equality compares the
	# complete saved transaction, without filtering out a gameplay field.
	func sample_scene_play_time(_host: Control, _committed_state: Dictionary = {}) -> void: pass

class FlowHost extends Node:
	var _run_engine = Run.new()
	var _run_state: Dictionary
	var _dialogue_active: bool = false
	var _animation_lock: bool = false
	var _section_map_presented_key: String = ""
	var _large_map_scrim: Control = Control.new()
	var requests: int = 0
	func _queue_section_map_presentation() -> void: requests += 1
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE: _large_map_scrim.free()

static func run(expect: Callable) -> void:
	var host := FlowHost.new()
	var initial: Dictionary = Run.new().create_new_run(FIXTURE_SEED, Store.default_data())
	for section_index: int in range(6):
		var flow := Flow.new()
		host._run_state = initial.duplicate(true)
		var entry: Vector2i = Graph.section(host._run_state, section_index)["entry"]
		host._run_state["current_room"] = entry
		# Test only the hook contract for future owner-authored section narration.
		Graph.room(host._run_state, entry)["npcs"] = [{"id": "emaciated_man"}]
		expect.call(not flow.allows_auto_open(host), "Section %d waits for narration closure" % section_index)
		flow.dialogue_started(host, {"npc_id": "emaciated_man"})
		flow.dialogue_closed(host)
		expect.call(flow.allows_auto_open(host), "Section %d narration closure requests its map" % section_index)
		flow.map_presented(host)
		expect.call(not flow.allows_auto_open(host), "Section %d map request is consumed once" % section_index)
		flow.reset()
		expect.call(not flow.allows_auto_open(host), "Section %d load does not retain a map request without replay" % section_index)
		var before: int = host.requests
		Graph.record_event(host._run_state, "route_choice_committed", {"origin": entry})
		flow.dialogue_started(host, {"npc_id": "emaciated_man"})
		flow.dialogue_closed(host)
		expect.call(host.requests == before, "Section %d revisits do not acquire a narration handoff" % section_index)
	var flow := Flow.new()
	host._run_state = Run.new().move_to_pre_battle(initial, Run.new().available_moves(initial)[0])
	host._run_state["mode"] = "room"
	var before: int = host.requests
	flow.dialogue_started(host, {"npc_id": "emaciated_man"})
	flow.dialogue_closed(host)
	expect.call(host.requests == before and flow.allows_auto_open(host), "Other rooms retain their existing automatic-map policy")
	expect.call(flow.opening_dialogue({"type": "start"}, {}).is_empty(), "Missing later-section narration remains an empty design placeholder")
	host.free()
	print("START ROOM MAP RULES: completed (6 sections)")

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

static func fixture(profile: Dictionary = {}) -> Dictionary:
	return Run.new().create_new_run(FIXTURE_SEED, Store.load_data() if profile.is_empty() else profile)

static func settle(tree: SceneTree) -> void:
	for frame: int in range(SETTLE_FRAMES): await tree.process_frame

static func install(tree: SceneTree, host: Node, state: Dictionary) -> void:
	host.set("_animation_lock", false)
	host.call("_load_run_state", state)
	await settle(tree)

static func key(tree: SceneTree, viewport: Viewport, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	viewport.push_input(event, true)
	await tree.process_frame
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event, true)
	await tree.process_frame

static func joy(tree: SceneTree, viewport: Viewport, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	viewport.push_input(event, true)
	await tree.process_frame
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event, true)
	await tree.process_frame

static func pointer(tree: SceneTree, viewport: Viewport, position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	viewport.push_input(motion, true)
	await tree.process_frame
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	viewport.push_input(event, true)
	await tree.process_frame
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event, true)
	await tree.process_frame

static func finish_narration(tree: SceneTree, host: Node, input_kind: String) -> void:
	for step: int in range(NARRATION_INPUT_LIMIT):
		if not bool(host.get("_dialogue_active")): break
		match input_kind:
			"pointer":
				var event := InputEventMouseButton.new()
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = true
				host.call("_on_dialogue_overlay_gui_input", event)
			"keyboard": await key(tree, host.get_viewport(), KEY_ENTER)
			"controller": await joy(tree, host.get_viewport(), JOY_BUTTON_A)
			"escape": await key(tree, host.get_viewport(), KEY_ESCAPE)
			"controller_back": await joy(tree, host.get_viewport(), JOY_BUTTON_B)
			"out_of_lines": host.call("_show_dialogue_line", OUT_OF_LINES_INDEX)
	await settle(tree)

static func wait_for_travel(tree: SceneTree, host: Node, expect: Callable) -> void:
	var deadline: int = Time.get_ticks_msec() + WAIT_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline and (str(host.get("_run_state").get("mode", "")) == "room" or bool(host.get("_animation_lock"))):
		await tree.process_frame
	expect.call(str(host.get("_run_state").get("mode", "")) == "pre_battle" and not bool(host.get("_animation_lock")), "Map choice completes the existing door animation into pre-battle")
	await settle(tree)

static func run_live(tree: SceneTree, expect: Callable) -> void:
	prepare_storage()
	tree.root.size = Vector2i(1920, 1080)
	var host: Node = load("res://scenes/run_scene.tscn").instantiate()
	tree.root.add_child(host)
	await settle(tree)
	host.set("_run_play_clock", FixedProofClock.new())
	var initial: Dictionary = fixture()
	var router: Node = tree.root.get_node("InputRouter")
	for input_kind: String in ["pointer", "keyboard", "controller", "escape", "controller_back", "out_of_lines"]:
		router.call("set_forced_state_for_test", "controller" if input_kind.begins_with("controller") else "pointer", "xbox")
		await install(tree, host, initial)
		expect.call(host.get("_dialogue_active") and not host.get("_large_map_scrim").visible, "Narration owns input before " + input_kind)
		var state_before: Dictionary = host.get("_run_state").duplicate(true)
		await finish_narration(tree, host, input_kind)
		expect.call(not host.get("_dialogue_active") and host.get("_large_map_scrim").visible, input_kind + " narration closure opens the map")
		expect.call(host.get("_run_state") == state_before, "Narration map handoff changes no run rules or state: " + input_kind)
		var panel: Control = host.get("_large_map_view")
		var choices: Array[Vector2i] = panel.call("available_destinations")
		expect.call(choices.size() == Run.new().available_moves(initial).size(), "Auto-open uses all existing travel choices")
		for coord: Vector2i in choices:
			expect.call(panel.get("node_buttons")[coord].get("route_state") == "reachable", "Immediate destinations retain existing availability highlights")
		if input_kind == "controller":
			var focused: Control = host.get_viewport().gui_get_focus_owner()
			var first: Vector2i = choices[0]
			for coord: Vector2i in choices:
				if float(Graph.room(initial, coord)["map_lane"]) < float(Graph.room(initial, first)["map_lane"]): first = coord
			expect.call(focused == panel.get("node_buttons")[first], "Controller starts on the left-most available lane")
	print("START ROOM MAP CLOSE PATHS: completed (pointer, Enter, A, Esc, B, exhausted lines)")
	var panel: Control = host.get("_large_map_view")
	for section_index: int in range(6):
		var section_state: Dictionary = initial.duplicate(true)
		section_state["current_room"] = Graph.section(section_state, section_index)["entry"]
		Graph.refresh_knowledge(section_state)
		panel.call("set_run_state", section_state)
		panel.call("focus_controller_on_current")
		var choices: Array[Vector2i] = panel.call("available_destinations")
		var first: Vector2i = choices[0]
		for coord: Vector2i in choices:
			if float(Graph.room(section_state, coord)["map_lane"]) < float(Graph.room(section_state, first)["map_lane"]): first = coord
		expect.call(host.get_viewport().gui_get_focus_owner() == panel.get("node_buttons")[first], "Section %d controller focus starts on its lowest available lane" % section_index)
	print("START ROOM MAP CONTROLLER FOCUS: completed (6 sections)")

	for close_kind: String in ["escape", "controller", "button"]:
		await install(tree, host, initial)
		var board_rect: Rect2 = host.get("board_view").get_global_rect()
		await finish_narration(tree, host, "escape")
		match close_kind:
			"escape": await key(tree, host.get_viewport(), KEY_ESCAPE)
			"controller": await joy(tree, host.get_viewport(), JOY_BUTTON_B)
			"button": host.get("_large_map_view").get("_close").pressed.emit()
		await settle(tree)
		var flow: RefCounted = host.get("_start_room_map")
		expect.call(not host.get("_large_map_scrim").visible and flow.get("_hint").is_visible_in_tree(), "Map close leaves the visit hint: " + close_kind)
		expect.call(host.get("board_view").get_global_rect() == board_rect, "Showing the hint preserves the board frame")
		check_hint_layout(host, expect)
		host.call("_refresh_ui")
		await settle(tree)
		expect.call(not host.get("_large_map_scrim").visible and flow.get("_hint").is_visible_in_tree(), "Refresh respects map close for the rest of the visit")
		router.call("set_forced_state_for_test", "pointer", "xbox")
		expect.call(flow.get("_label").text == Flow.PATH_HINT, "Pointer/keyboard hint uses exact authored text")
		router.call("set_forced_state_for_test", "controller", "steam_deck")
		expect.call(flow.get("_glyph").visible and flow.get("_glyph").get("action_name") == Router.ACTION_MAP, "Controller hint uses the existing map-action glyph")
		router.call("set_forced_state_for_test", "controller", "xbox")
		expect.call(flow.get("_glyph").get("family") == Router.FAMILY_XBOX, "Hint glyph follows controller-family changes without a modality change")
		await settle(tree)
		check_hint_layout(host, expect)
		host.get("_context_choice_overlay").hide()
		flow.call("refresh_hint", host)
		await settle(tree)
		check_hint_layout(host, expect)
		host.get("_context_choice_overlay").show()
		flow.call("refresh_hint", host)
		await settle(tree)
		check_hint_layout(host, expect)
	print("START ROOM MAP DISMISSAL: completed (Esc, B, close button, refresh, device glyph)")

	# Service transition is synchronous until its overlay becomes visible; the
	# deferred map request must wait for the real level-up and resumed Leave.
	var profile: Dictionary = Store.load_data()
	profile[Store.EMACIATED_AWAKENING_SEEN_KEY] = true
	profile["embers"] = Store.next_level_cost(profile)
	Store.save_data(profile)
	host.set("_progression", profile)
	await install(tree, host, fixture(profile))
	await finish_narration(tree, host, "escape")
	host.call("_close_large_map")
	host.call("_show_emaciated_services")
	host.call("_on_dialogue_option_pressed", {"action": "emaciated_level_up"})
	await settle(tree)
	expect.call(host.get("_upgrade_scrim").visible and not host.get("_large_map_scrim").visible, "Level-up owns the modal until its service finishes")
	host.call("_close_card_upgrade_overlay")
	await settle(tree)
	expect.call(host.get("_dialogue_active") and not host.get("_large_map_scrim").visible, "Level-up returns to the existing service dialogue")
	host.call("_on_dialogue_option_pressed", {"action": "close"})
	await settle(tree)
	expect.call(host.get("_large_map_scrim").visible, "Service Leave after a real level-up opens the map")
	print("START ROOM MAP LEVEL-UP: completed")

	# Use one identical durable snapshot for native map input and physical doors.
	router.call("set_forced_state_for_test", "pointer", "xbox")
	initial = fixture(Store.load_data())
	await install(tree, host, initial)
	await finish_narration(tree, host, "escape")
	initial = host.get("_run_state").duplicate(true)
	var selected: Vector2i = host.get("_large_map_view").call("available_destinations")[0]
	var branch_profile: Dictionary = Store.load_data()
	await install(tree, host, initial)
	await finish_narration(tree, host, "escape")
	var branch_input: Dictionary = host.get("_run_state").duplicate(true)
	host.call("_close_large_map")
	var door: Vector2i = host.call("_door_tile_for_destination", selected)
	expect.call(door.x >= 0, "The destination still has a working physical door")
	await host.call("_on_board_tile_clicked", door)
	await wait_for_travel(tree, host, expect)
	var door_result: Dictionary = host.get("_run_state").duplicate(true)
	for input_kind: String in ["pointer", "keyboard", "controller"]:
		Store.save_data(branch_profile)
		host.set("_progression", branch_profile.duplicate(true))
		await install(tree, host, initial)
		await finish_narration(tree, host, "escape")
		expect.call(host.get("_run_state") == branch_input, "Travel comparison begins with identical saved run and profile state")
		router.call("set_forced_state_for_test", "controller" if input_kind == "controller" else "pointer", "xbox")
		var target: Control = host.get("_large_map_view").get("node_buttons")[selected]
		if input_kind == "pointer": await pointer(tree, host.get_viewport(), target.get_global_rect().get_center())
		else:
			target.grab_focus()
			if input_kind == "keyboard": await key(tree, host.get_viewport(), KEY_ENTER)
			else: await joy(tree, host.get_viewport(), JOY_BUTTON_A)
		await wait_for_travel(tree, host, expect)
		var map_result: Dictionary = host.get("_run_state").duplicate(true)
		expect.call(map_result == door_result and hash(map_result) == hash(door_result), "Native %s map activation and physical door produce the identical state hash" % input_kind)
		expect.call(Store.load_saved_run() == map_result, "Map travel persists the same resulting state")
		print("START ROOM MAP TRAVEL HASH: %s door=%d map=%d" % [input_kind, hash(door_result), hash(map_result)])
		var routes: Array = map_result.get("map_events", []).filter(func(event: Dictionary) -> bool: return event.get("type") == "route_choice_committed")
		expect.call(routes.size() == 1 and routes[0]["payload"]["destination"] == selected, "Map travel records exactly one existing route-choice transaction")
		var route_events: Array = Analytics.load_all_events().filter(func(event: Dictionary) -> bool: return event.get("event_type") == "route_choice_committed")
		expect.call(route_events.size() == 1, "Saved map/door route uses the same append-only analytics idempotency key")
		expect.call(not host.get("_start_room_map").get("_hint").visible, "Leaving the start room clears the hint")
	print("START ROOM MAP TRAVEL: completed (physical door, pointer, Enter, A, save, analytics)")

	await install(tree, host, initial)
	await finish_narration(tree, host, "escape")
	host.call("_close_large_map")
	host.call("_persist_committed_boundary", "start_room_map_test")
	var saved: Dictionary = Store.load_saved_run()
	expect.call(not saved.has("start_room_map_hint") and not saved.has("start_room_map_pending"), "Map presentation remains outside saves")
	await install(tree, host, saved)
	expect.call(host.get("_dialogue_active") and not host.get("_large_map_scrim").visible, "Load waits for existing narration replay, rather than opening immediately")
	await finish_narration(tree, host, "escape")
	expect.call(host.get("_large_map_scrim").visible, "Closing replayed narration restores the map handoff")
	# A load with no replay cannot retain an old deferred narration request.
	host.set("_defer_initial_run_presentation", true)
	host.call("_load_run_state", saved)
	host.set("_defer_initial_run_presentation", false)
	var room: Dictionary = Run.new().room_metadata(saved, saved["current_room"])
	host.set("_last_auto_dialogue_key", host.call("_dialogue_trigger_key", room))
	host.call("_refresh_ui")
	await settle(tree)
	expect.call(not host.get("_dialogue_active") and not host.get("_large_map_scrim").visible, "Loading without narration replay never reopens the map")
	print("START ROOM MAP SAVE/LOAD: completed (replay and no replay)")
	router.call("clear_forced_state_for_test")
	host.queue_free()
	await tree.process_frame

static func check_hint_layout(host: Node, expect: Callable) -> void:
	var flow: RefCounted = host.get("_start_room_map")
	var hint: Control = flow.get("_hint")
	var rect: Rect2 = hint.get_global_rect()
	var viewport: Rect2 = host.get_viewport().get_visible_rect()
	var row: Rect2 = flow.call("action_row_rect", host)
	var bottom: float = row.position.y - Flow.HINT_ACTION_ROW_GAP if row.has_area() else viewport.end.y - Flow.HINT_BOTTOM_GAP
	expect.call(hint.is_visible_in_tree() and rect.has_area() and viewport.encloses(rect), "Hint plate is visible and entirely inside the viewport")
	expect.call(is_equal_approx(rect.get_center().x, viewport.get_center().x) and is_equal_approx(rect.end.y, bottom), "Hint is centered, 16 px above the button row or 72 px above the bottom without buttons")
	var label: Label = flow.get("_label")
	expect.call(label.get_theme_font("font") == Typography.text_font() and label.get_theme_font_size("font_size") == Typography.scaled_size(label, Flow.HINT_FONT_SIZE), "Hint uses the approved Text 17 px style")
	expect.call(label.get_theme_color("font_color") == preload("res://scripts/ui_palette.gd").TEXT_2, "Hint uses the approved TEXT_2 colour")
	expect.call(hint.get_theme_stylebox("panel") == host.get("_controller_prompt_bar").get_theme_stylebox("panel"), "Hint reuses the existing hint plate")

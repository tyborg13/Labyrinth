extends SceneTree
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const RunEngineScript = preload("res://scripts/run_engine.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Objectives = preload("res://scripts/combat_objective_rules.gd")
var output_dir: String = "user://section_map_flow_v2"
var viewport: SubViewport
var instance: Node
var failed: bool = false

func _initialize() -> void:
	await _setup()
	var engine := RunEngineScript.new()
	var state: Dictionary = engine.create_new_run(81, Progression.default_data())
	# Use a real reward transaction with the current generated room and exits.
	state = engine.move_to_room(state, engine.available_moves(state)[0])
	var combat: Dictionary = (state.get("combat_state", {}) as Dictionary).duplicate(true)
	for enemy: Dictionary in combat.get("enemies", []): enemy["hp"] = 0
	state = engine.finish_combat(state, combat)
	state = engine.claim_card_reward(state, "")
	_load(state)
	await process_frame
	await process_frame
	await _capture("01_post_reward_map.png")
	var scrim: Control = instance.get("_large_map_scrim")
	_check(scrim.visible, "Post-reward room choice automatically opens the map")
	var panel: Control = instance.get("_large_map_view")
	var choices: Array = panel.call("available_destinations")
	var selected: Vector2i = choices[0]
	var before_coord: Vector2i = (instance.get("_run_state") as Dictionary).get("current_room", Vector2i.ZERO)
	var target_button: Control = (panel.get("node_buttons") as Dictionary).get(selected)
	# Current, bypassed, and future rooms remain inspectable but cannot travel.
	var blocked_states: Dictionary = {}
	for coord: Vector2i in (panel.get("node_buttons") as Dictionary):
		var blocked: Control = (panel.get("node_buttons") as Dictionary)[coord]
		var route_state: String = str(blocked.get("route_state"))
		if route_state == "reachable" or blocked_states.has(route_state): continue
		blocked_states[route_state] = true
		await _pointer_click(blocked.get_global_rect().get_center())
		_check((instance.get("_run_state") as Dictionary).get("current_room") == before_coord and _route_choices(instance.get("_run_state")) == _route_choices(state), "Activating " + route_state + " only inspects; no travel or route event")
	await _pointer_hover(target_button.get_global_rect().get_center())
	_check(panel.get("selected_coord") == selected and (instance.get("_run_state") as Dictionary).get("current_room") == before_coord, "Hover previews the branch without requiring a selection or moving the player")
	_check(str(panel.get("_preview_text")).contains("door"), "Optional tooltip retains the physical door identity")
	await _capture("01b_pointer_preview.png")
	panel.call("focus_controller_on_current")
	await _capture("02_keyboard_focus.png")
	_check(viewport.gui_get_focus_owner() != null and panel.get("_preview") != null, "Native keyboard/controller focus exposes the same route details without hover")
	var scout_button: Button = panel.get("_scout")
	scout_button.grab_focus()
	await _key(KEY_ENTER)
	_check(bool(panel.get("scout_targeting")) and int(Graph.section(instance.get("_run_state"), 0).get("scouts", 0)) == 2, "Scout activation starts branch targeting without spending a use")
	_check(_prompt_labels().has("Scout") and _prompt_labels().has("Cancel Scout"), "Controller cues distinguish Scout targeting from travel and closing")
	await _capture("02b_scout_targeting.png")
	await _key(KEY_ESCAPE)
	_check(scrim.visible and not bool(panel.get("scout_targeting")), "Keyboard cancel leaves the map open and exits Scout targeting")
	_check(int(Graph.section(instance.get("_run_state"), 0).get("scouts", 0)) == 2, "Cancelling Scout does not spend a use")
	scout_button.grab_focus()
	await _key(KEY_ENTER)
	await _key(KEY_ENTER)
	_check(int(Graph.section(instance.get("_run_state"), 0).get("scouts", 0)) == 1 and not bool(panel.get("scout_targeting")), "Confirming a branch spends one Scout use and exits targeting")
	_check((instance.get("_run_state") as Dictionary).get("current_room") == before_coord, "Scouting cannot move the player")
	await _capture("03_scout_result.png")
	await _key(KEY_ESCAPE)
	instance.call("_refresh_ui")
	await process_frame
	await process_frame
	_check(not scrim.visible, "Closing a map keeps it closed during refresh")
	await _capture("04_map_button.png")
	await _key(KEY_M)
	_check(scrim.visible, "M reopens the map through live shortcut input")
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "controller", "xbox")
	panel.call("focus_controller_on_current")
	var old_focus: Control = viewport.gui_get_focus_owner()
	await _joy(JOY_BUTTON_DPAD_RIGHT)
	_check(viewport.gui_get_focus_owner() != null and viewport.gui_get_focus_owner() != old_focus, "Controller direction moves native focus between map controls")
	await _capture("04b_controller_navigation.png")
	# Use a fresh horizon: the first Scout may have revealed every nearby branch.
	_load(state.duplicate(true))
	await process_frame
	await process_frame
	scout_button.grab_focus()
	await _joy(JOY_BUTTON_A)
	_check(bool(panel.get("scout_targeting")), "Controller activation starts Scout targeting")
	await _joy(JOY_BUTTON_B)
	_check(scrim.visible and not bool(panel.get("scout_targeting")), "Controller Back cancels Scout before closing the map")
	await _joy(JOY_BUTTON_B)
	_check(not scrim.visible, "Controller cancel closes the map outside Scout targeting")
	# Actual pointer, keyboard, and controller activation each commit travel once.
	for input_kind: String in ["pointer", "keyboard", "controller"]:
		router.call("set_forced_state_for_test", "controller" if input_kind == "controller" else "pointer", "xbox")
		_load(state.duplicate(true))
		await process_frame
		await process_frame
		target_button = (panel.get("node_buttons") as Dictionary).get(selected)
		if input_kind == "pointer":
			await _pointer_click(target_button.get_global_rect().get_center())
		else:
			target_button.grab_focus()
			if input_kind == "keyboard": await _key(KEY_ENTER)
			else: await _joy(JOY_BUTTON_A)
		await _wait_travel(selected)
		_check(_route_choices(instance.get("_run_state")) == _route_choices(state) + 1, "Direct " + input_kind + " activation commits exactly one route analytics event")
		_check((instance.get("_run_state") as Dictionary).get("current_room") == selected, "One " + input_kind + " activation enters the exact chosen room")
		await _capture("04c_direct_" + input_kind + ".png")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	# Match a generated reach-exit room to its real board doors.
	state = engine.create_new_run(92, Progression.default_data())
	for opening: Dictionary in (state.get("rooms", {}) as Dictionary).values():
		if str(opening.get("type", "")) == "combat" and int(opening.get("map_step", 0)) == 1:
			opening["cleared"] = true
			opening["visited"] = true
	var found: bool = false
	for room: Dictionary in (state.get("rooms", {}) as Dictionary).values():
		if str(room.get("type", "")) != "combat" or int(room.get("map_step",0)) <= 1: continue
		var objective: Dictionary = Objectives.build_for_room(92, room, Vector2i.RIGHT)
		if str(objective.get("type", "")) != Objectives.REACH_EXIT: continue
		state["current_room"] = room.get("coord", Vector2i.ZERO)
		room["visited"] = true
		room["revealed"] = true
		Graph.refresh_knowledge(state)
		state["mode"] = "pre_battle"
		state["pre_battle_travel_dir"] = Vector2i.RIGHT
		state = engine.begin_pre_battle_combat(state)
		found = str((state.get("combat_state", {}) as Dictionary).get("objective", {}).get("type", "")) == Objectives.REACH_EXIT
		if found: break
	_check(found, "Probe finds a generated reach-exit encounter")
	_load(state)
	instance.call("_open_large_map")
	await _capture("05_reach_exit_map.png")
	choices = panel.call("available_destinations")
	if not choices.is_empty():
		var origin: Vector2i = (instance.get("_run_state") as Dictionary).get("current_room")
		var door_button: Control = (panel.get("node_buttons") as Dictionary)[choices[0]]
		await _pointer_click(door_button.get_global_rect().get_center())
		_check((instance.get("_run_state") as Dictionary).get("current_room") == origin and not scrim.visible, "One room click shows its physical exit without committing travel")
	await _capture("06_reach_exit_board.png")
	state = engine.create_new_run(93, Progression.default_data())
	for room: Dictionary in (state.get("rooms", {}) as Dictionary).values():
		if str(room.get("type", "")) == "event":
			state["current_room"] = room.get("coord")
			room["visited"] = true
			state["mode"] = "event"
			Graph.refresh_knowledge(state)
			break
	_load(state)
	await process_frame
	await _capture("07_event.png")
	_check(scrim.visible and (panel.get("_event_panel") as Control).visible, "Event choices appear as a dedicated encounter surface")
	for coord: Vector2i in panel.call("available_destinations"):
		_check(not bool(panel.call("can_activate_room", coord)), "Event resolution blocks direct room travel")
	var event_button: Button = panel.get("_event_embers")
	await _pointer_click(event_button.get_global_rect().get_center())
	_check(str((instance.get("_run_state") as Dictionary).get("mode")) == "room", "The event releases normal route selection")
	await _capture("08_event_resolved.png")
	_load(state.duplicate(true))
	await process_frame
	await process_frame
	router.call("set_forced_state_for_test", "controller", "xbox")
	panel.call("focus_controller_on_current")
	_check(viewport.gui_get_focus_owner() == panel.get("_event_embers"), "Controller focus enters the dedicated event choices")
	_check(_prompt_labels().has("Take Embers"), "The event confirm cue names the focused choice")
	await _capture("08b_event_controller.png")
	await _joy(JOY_BUTTON_A)
	await process_frame
	_check(str((instance.get("_run_state") as Dictionary).get("mode")) == "room", "Controller confirm resolves the event")
	_check(viewport.gui_get_focus_owner() != null and viewport.gui_get_focus_owner().get_parent() == panel.get("_nodes"), "Controller event resolution restores room focus")
	_check(_prompt_labels().has("Enter"), "The room confirm cue explicitly means direct entry")
	await _capture("08c_event_focus_restored.png")
	instance.queue_free()
	await process_frame
	print(ProjectSettings.globalize_path(output_dir))
	quit(1 if failed else 0)

func _load(state: Dictionary) -> void:
	instance.call("_close_large_map")
	instance.set("_animation_lock", false)
	instance.set("_section_map_presented_key", "")
	instance.call("_load_run_state", state)
	instance.call("_close_dialogue")
	instance.set("_guided_tutorial_phase_id", "")
	instance.set("_reward_intro_suppressed", false)
	instance.call("_refresh_ui")

func _capture(name: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var image: Image = viewport.get_texture().get_image()
	_check(image.get_size() == Vector2i(1920,1080) and image.save_png(output_dir.path_join(name)) == OK, "Fresh native-resolution capture: " + name)

func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func _key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	viewport.push_input(event, true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event, true)
	await process_frame

func _joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	viewport.push_input(event, true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event, true)
	await process_frame

func _pointer_click(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	viewport.push_input(motion, true)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	viewport.push_input(event, true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event, true)
	await process_frame

func _setup() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920,1080))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = Vector2i(1920,1080)
	root.size = Vector2i(1920,1080)
	Settings.set_storage_path("user://section_map_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	Settings.save_settings(settings)
	Progression.set_storage_path("user://section_map_progression.json")
	Progression.set_run_storage_path("user://section_map_run.save")
	Progression.clear_saved_run()
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920,1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	instance = load("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(instance)
	await process_frame
	await process_frame

func _pointer_hover(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	viewport.push_input(motion, true)
	await process_frame
	await process_frame

func _wait_travel(destination: Vector2i) -> void:
	for tick: int in range(100):
		if (instance.get("_run_state") as Dictionary).get("current_room") == destination and not bool(instance.get("_animation_lock")):
			break
		await create_timer(0.05).timeout
	await process_frame
	await process_frame

func _route_choices(state: Dictionary) -> int:
	var count: int = 0
	for event: Dictionary in state.get("map_events", []):
		if str(event.get("type", "")) == "route_choice_committed": count += 1
	return count

func _prompt_labels() -> Array[String]:
	var labels: Array[String]
	for prompt: Dictionary in instance.get("_controller_prompt_bar").call("prompts_snapshot"):
		labels.append(str(prompt.get("label", "")))
	return labels

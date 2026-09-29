extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const Fixture = preload("res://tests/suites/move_attack_shortcut_suite.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const Relics = preload("res://scripts/surface_relic_rules.gd")
const Drag = preload("res://tests/suites/card_drag_play_suite.gd")
const InputRouter = preload("res://scripts/input_router.gd")
const OUT := "user://probes/card_targeting_audit_20260929_v4"
var scene: Node
var canvas: SubViewport

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_size(Vector2i(1920,1080))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920,1080)
	root.size = Vector2i(1920,1080)
	Analytics.set_storage_dir("user://audit_events")
	Store.set_storage_path("user://audit_profile.json")
	Store.set_run_storage_path("user://audit_run.save")
	var profile: Dictionary = Store.default_data()
	profile[Tutorial.PROGRESSION_KEY] = {"version":Tutorial.VERSION,"status":"dismissed","completed_steps":[]}
	Store.save_data(profile)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()

func _run() -> void:
	Settings.set_storage_path("user://audit_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	Settings.apply_settings(settings,root,false)
	canvas = SubViewport.new()
	canvas.size = Vector2i(1920,1080)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await _settle()
	# Both inside-range enemies are offered before any move, without step UI.
	await _install("gust_step")
	var before: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	await scene.call("_on_card_pressed",0)
	var board: Node = scene.get_node("BoardUnderlay/CombatBoard")
	assert((board.get("attack_tiles") as Array).has(Vector2i(3,4)))
	assert((board.get("attack_tiles") as Array).has(Vector2i(4,4)))
	await _hover(Vector2i(3,4))
	await _capture("01_gust_adjacent_target")
	assert(not (scene.get("_action_step_tracker") as Control).visible)
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = Vector2(1900,1040)
	canvas.push_input(right,true)
	await _settle()
	assert(int(scene.get("_selected_card_index")) < 0)
	assert(scene.get("_combat_state") == before)
	assert(_play_events().is_empty(), "Cancellation must not emit card_played")
	await _capture("02_right_click_cancelled")
	await scene.call("_on_card_pressed",0)
	await scene.call("_on_board_tile_clicked",Vector2i(3,4))
	var after: Dictionary = scene.get("_combat_state")
	assert(int(after["enemies"][0]["hp"]) == 97)
	assert(after["enemies"][0]["pos"] == Vector2i(3,4))
	assert(int(after["cards_played_this_turn"]) == 1 and int(after["player_turn_time_spent"]) == 4)
	assert(_play_events().size() == 1, "One target click emits one card_played event")
	assert(int(scene.get("_selected_card_index")) < 0)
	await _capture("03_gust_adjacent_resolved")
	await _install("guarded_step")
	await scene.call("_on_card_pressed",0)
	await _hover(Vector2i(2,3))
	await _capture("04_guarded_move_target")
	await scene.call("_on_board_tile_clicked",Vector2i(2,3))
	after = scene.get("_combat_state")
	assert(after["player"]["pos"] == Vector2i(2,3) and int(after["player"]["block"]) > 0)
	assert(int(scene.get("_selected_card_index")) < 0)
	await _capture("05_guarded_all_effects_resolved")
	await _install("molten_reach")
	await scene.call("_on_card_pressed",0)
	var controls: Node = scene.get("_action_context_command_bar")
	var rotate: Button
	for child: Node in controls.get_children():
		if child is Button and child.text == "Rotate": rotate = child
	assert(rotate != null and rotate.is_visible_in_tree())
	rotate.pressed.emit()
	await _hover(Vector2i(4,4))
	await _capture("06_optional_rotate_only")
	await _install("patch_up")
	await scene.call("_on_card_pressed",0)
	await _hover(Vector2i(2,4))
	await _capture("07_targetless_self_confirmation")
	await scene.call("_on_board_tile_clicked",Vector2i(2,4))
	assert(int(scene.get("_selected_card_index")) < 0)
	Settings._applied_reduced_motion = true
	await _install("gust_step")
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test","controller","steam_deck")
	scene.set("_controller_region","hand")
	scene.call("_controller_set_hand_focused",true)
	scene.call("_controller_set_hand_index",0)
	await scene.call("_controller_activate_current")
	scene.call("_controller_set_board_tile",Vector2i(3,4))
	await _capture("08_controller_target_reduced_motion")
	var cancel := InputEventAction.new()
	cancel.action = InputRouter.ACTION_CANCEL
	cancel.pressed = true
	await scene.call("_handle_controller_input",cancel)
	assert(int(scene.get("_selected_card_index")) < 0)
	router.call("set_forced_state_for_test","pointer","steam_deck")
	await _capture("09_controller_cancel_pointer_handoff")
	await _install("gathering_rhythm")
	await scene.call("_on_card_pressed",0)
	await scene.call("_on_board_tile_clicked",Vector2i(2,3))
	assert(int(scene.get("_selected_card_index")) < 0)
	await _capture("10_flurry_automatic_completion")
	Settings._applied_reduced_motion = false
	await _install("quick_stab")
	var worldroot: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	worldroot["relics"] = ["worldroot_idol"]
	worldroot["enemies"][0]["pos"] = Vector2i(5,4)
	worldroot["enemies"].remove_at(1)
	for x: int in range(2,5): Ground.place(worldroot,Vector2i(x,4),"rubble")
	scene.set("_combat_state",worldroot)
	(scene.get("_run_state") as Dictionary)["combat_state"] = worldroot
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
	await scene.call("_on_card_pressed",0)
	assert(int(scene.get("_selected_card_index")) == 0, "Remote-only reach remains playable")
	await _hover(Vector2i(5,4))
	var worldroot_preview: Dictionary = scene.call("_active_card_preview")
	assert((worldroot_preview["action"] as Dictionary).get("_origin_tile") == Vector2i(4,4))
	await _capture("11_worldroot_one_target")
	await scene.call("_on_board_cancel_requested")
	assert(scene.get("_combat_state") == worldroot)
	assert(_play_events().is_empty())
	await scene.call("_on_card_pressed",0)
	await scene.call("_on_board_tile_clicked",Vector2i(5,4))
	after = scene.get("_combat_state")
	assert(int(after["enemies"][0]["hp"]) == 91 and not Ground.has_rubble(after,Vector2i(4,4)))
	assert(int(scene.get("_selected_card_index")) < 0 and _play_events().size() == 1)
	await _capture("12_worldroot_resolved")
	await _install("stone_plate")
	before = (scene.get("_combat_state") as Dictionary).duplicate(true)
	scene.call("_on_card_drag_started",0,Drag._drag_start_position(scene,0))
	await process_frame
	var drop: Vector2 = Drag._tile_global_position(scene,Vector2i(2,4))
	await scene.call("_update_card_drag",drop)
	right.position = drop
	canvas.push_input(right,true)
	assert(bool(scene.get("_drag_cancel_in_progress")))
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = drop
	canvas.push_input(release,true)
	await create_timer(0.35).timeout
	assert(scene.get("_combat_state") == before and _play_events().is_empty())
	await _capture("13_drag_cancel_release_safe")
	print(ProjectSettings.globalize_path(OUT))
	print("CARD TARGETING NATIVE PROBE: PASS")
	quit()

func _install(card: String) -> void:
	Analytics.clear_storage()
	scene.call("_reset_card_resolution")
	var combat := CombatEngine.new()
	var state: Dictionary = Fixture._combat_state(combat,card,Vector2i(3,4),20260929)
	state["player"]["hp"] = 12
	state["enemies"].append({"id":2,"type":"crawler","pos":Vector2i(4,4),"hp":100,"max_hp":100,"intent":{"name":"Watch","time":10,"actions":[{"type":"block","amount":1}]}})
	state["deck"] = {"hand":[card,"gust_step" if card != "gust_step" else "guarded_step","sidestep_slash","patch_up","molten_reach"],"draw":["brace","brace","brace","brace"],"discard":[],"burned":[],"cycles":0}
	state["current_actor"] = {"kind":"player","key":"player"}
	state["cards_played_this_turn"] = 0
	state["umbra"] = combat.call("_initial_umbra_state",Fixture._live_combat_layout("clear",Vector2i(3,4)))
	state.erase("player_turn_restrictions")
	var run: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["current_room_layout"] = Fixture._live_combat_layout("clear",Vector2i(3,4))
	run["combat_state"] = state
	scene.set("_run_state",run)
	scene.set("_combat_state",state)
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
	await _settle()

func _hover(tile: Vector2i) -> void:
	var board: Control = scene.get_node("BoardUnderlay/CombatBoard")
	var point: Vector2 = board.get_global_transform() * (board.call("world_position_for_tile",tile) as Vector2)
	# Use the board's public probe coordinate helper if available; the target
	# handler itself owns legality, damage, and route preview.
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	canvas.push_input(motion,true)
	scene.call("_on_board_tile_hovered",tile)
	scene.call("_sync_click_targeting_arrow",point)
	await _settle()

func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.12).timeout

func _capture(name: String) -> void:
	await _settle()
	await create_timer(0.3).timeout
	await process_frame
	assert((scene.get("_action_step_tracker_steps") as Node).get_child_count() == 0)
	assert(not (scene.get("_action_context_header") as Control).visible)
	RenderingServer.force_draw()
	await process_frame
	var image: Image = canvas.get_texture().get_image()
	assert(image.get_size() == Vector2i(1920,1080))
	assert(image.save_png("%s/%s.png" % [OUT,name]) == OK)

func _play_events() -> Array:
	return Analytics.load_all_events().filter(func(event: Dictionary) -> bool: return str(event.get("event_type","")) == "card_played")

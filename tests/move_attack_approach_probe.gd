extends SceneTree

const Suite = preload("res://tests/suites/move_attack_approach_suite.gd")
const Base = preload("res://tests/suites/move_attack_shortcut_suite.gd")
const Drag = preload("res://tests/suites/card_drag_play_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const OUTPUT := "user://probes/move_attack_approach_v4"
var failures: Array[String]
var canvas: SubViewport

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	Store.set_storage_path("user://approach_profile.json")
	Store.set_run_storage_path("user://approach_run.save")
	Settings.set_storage_path("user://approach_settings.json")
	preload("res://scripts/analytics_store.gd").set_storage_dir("user://approach_events")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	settings["dialogue_speed"] = Settings.DIALOGUE_INSTANT
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	Store.save_data(Tutorial.dismiss_tutorial(Store.default_data()))
	Suite.run(Callable(self, "_expect"))
	canvas = SubViewport.new()
	canvas.size = Vector2i(1920, 1080)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	canvas.notify_mouse_entered()
	for input_path: String in ["pointer", "drag", "controller", "reduced_motion"]:
		await _exercise(input_path)
	for failure: String in failures:
		push_error(failure)
	print("MOVE ATTACK APPROACH: %d failures" % failures.size())
	if DisplayServer.get_name() != "headless": print(ProjectSettings.globalize_path(OUTPUT))
	quit(0 if failures.is_empty() else 1)

func _exercise(input_path: String) -> void:
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	var settings: Dictionary = Settings.load_settings()
	settings["reduced_motion"] = input_path == "reduced_motion"
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	Analytics.clear_storage()
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await _settle()
	_expect(bool(scene.call("_reduced_motion_enabled")) == (input_path == "reduced_motion"), "Probe applies the requested motion setting")
	var combat := Combat.new()
	var state: Dictionary = Base._combat_state(combat, "sidestep_slash", Suite.ENEMY, 9292026)
	state["umbra"]["stage"] = "clear"
	state["deck"]["hand"] = ["sidestep_slash", "slipstream_cut", "brace"]
	state["deck"]["draw"] = ["brace"]
	state["deck"]["discard"] = []
	state["deck"]["burned"] = []
	state["current_actor"] = {"kind":"player", "key":"player"}
	state["cards_played_this_turn"] = 0
	state.erase("player_turn_restrictions")
	var run: Dictionary = scene.get("_run_state")
	run["mode"] = "combat"
	run["current_room_layout"] = Base._live_combat_layout("clear", Suite.ENEMY)
	run["combat_state"] = state
	scene.set("_combat_state", state)
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
	await _settle()
	if input_path == "drag":
		scene.call("_on_card_drag_started", 0, Drag._drag_start_position(scene, 0))
		await scene.call("_update_card_drag", Drag._tile_global_position(scene, Suite.WEST))
	else:
		await scene.call("_on_card_pressed", 0)
	if input_path == "controller":
		router.call("set_forced_state_for_test", "controller", "steam_deck")
	await _settle()
	var before: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	for endpoint: Vector2i in [Suite.WEST, Suite.SOUTH]:
		await _hover(scene, endpoint, input_path)
		await _hover(scene, Suite.ENEMY, input_path)
		var presentation: Dictionary = scene.get("board_view").get("presentation")
		var path: Array = presentation.get("path_tiles", [])
		_expect(not path.is_empty() and path.back() == endpoint, "%s arrow chooses %s" % [input_path, endpoint])
		_expect((presentation.get("effect", {}) as Dictionary).get("from") == endpoint, "%s attack originates from the displayed endpoint" % input_path)
		_expect(scene.get("_combat_state") == before, "%s hover never spends the card or moves the player" % input_path)
		await _capture("%s_%s_v4" % [input_path, "west" if endpoint == Suite.WEST else "south"])
	# A selected card can be cancelled and reselected without stale intent.
	if input_path == "pointer":
		var defaults: Dictionary = scene.get("_preview_shortcuts_cache")
		var default_tile: Vector2i = defaults["plans"][Suite.ENEMY]["move_tile"]
		for outside: Vector2 in [Vector2(1000, 950), Vector2(1900, 45)]:
			await _hover(scene, Suite.SOUTH, input_path)
			await _hover(scene, Suite.ENEMY, input_path)
			await _pointer_motion(outside)
			_expect(scene.get("_move_attack_approach").entry == Suite.INVALID, "Actual pointer departure over hand/HUD clears approach")
			await _pointer_motion(Drag._tile_global_position(scene, Suite.ENEMY))
			_expect(scene.get("_hovered_board_tile") == Suite.ENEMY, "Actual pointer re-entry restores enemy preview")
			var returned: Dictionary = scene.call("_shortcut_plan_for_tile", scene.call("_active_card_preview"), Suite.ENEMY)
			_expect(returned.get("move_tile") == default_tile, "Actual pointer return from hand/HUD uses default route")
		await _capture("pointer_default_v4")
		await scene.call("_on_board_cancel_requested")
		_expect(int(scene.get("_selected_card_index")) < 0, "Board cancel leaves no selected card")
		await scene.call("_on_card_pressed", 0)
		_expect(scene.get("_move_attack_approach").entry == Suite.INVALID, "Reselection clears the approach")
		await _hover(scene, Suite.WEST, input_path)
		await _hover(scene, Suite.ENEMY, input_path)
		await _hover(scene, Suite.SOUTH, input_path)
		await _hover(scene, Suite.ENEMY, input_path)
	if input_path == "controller":
		router.call("set_forced_state_for_test", "pointer", "xbox")
		_expect(scene.get("_move_attack_approach").entry == Suite.INVALID, "Device handoff clears pointer/controller approach history")
		router.call("set_forced_state_for_test", "controller", "steam_deck")
		await _hover(scene, Suite.SOUTH, input_path)
		await _hover(scene, Suite.ENEMY, input_path)
	if input_path == "drag":
		await scene.call("_commit_drag_drop", "play", Drag._tile_global_position(scene, Suite.ENEMY))
	elif input_path == "controller":
		await scene.call("_controller_activate_current")
	else:
		await scene.call("_on_board_tile_clicked", Suite.ENEMY)
	await _settle()
	var actual: Dictionary = scene.get("_combat_state")
	_expect(actual["player"]["pos"] == Suite.SOUTH, "%s resolves at the exact previewed position" % input_path)
	_expect(int(actual["enemies"][0]["hp"]) == 95, "%s applies the attack exactly once" % input_path)
	_expect(int(scene.get("_selected_card_index")) < 0, "%s completes with one target decision" % input_path)
	_expect(int(actual.get("player_turn_time_spent", 0)) == 3, "%s pays the normal card Time once" % input_path)
	var played: Array[Dictionary]
	for event: Dictionary in Analytics.load_all_events():
		if event.get("event_type") == "card_played": played.append(event)
	_expect(played.size() == 1, "%s emits exactly one committed card event" % input_path)
	if played.size() == 1:
		var payload: Dictionary = played[0].get("payload", {})
		var targets: Array = payload.get("selected_targets", [])
		_expect(targets.size() == 2 and Vector2i(int(targets[0]["x"]), int(targets[0]["y"])) == Suite.SOUTH and Vector2i(int(targets[1]["x"]), int(targets[1]["y"])) == Suite.ENEMY, "%s analytics records chosen endpoint then enemy" % input_path)
		_expect(payload.get("target_decision_count") == 1, "Approach selection remains one confirmed decision")
	await _capture("%s_resolved_v4" % input_path)
	scene.queue_free()
	await _settle()

func _hover(scene: Node, tile: Vector2i, input_path: String) -> void:
	if input_path == "drag":
		await scene.call("_update_card_drag", Drag._tile_global_position(scene, tile))
	elif input_path == "controller":
		scene.call("_controller_set_board_tile", tile)
	else:
		if tile.x >= 0:
			var motion := InputEventMouseMotion.new()
			motion.position = Drag._tile_global_position(scene, tile)
			motion.global_position = motion.position
			canvas.push_input(motion, true)
	await _settle()

func _pointer_motion(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	canvas.push_input(motion, true)
	await _settle()

func _settle() -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless": RenderingServer.force_draw()
	await process_frame

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var image: Image = canvas.get_texture().get_image()
	_expect(image.get_size() == Vector2i(1920, 1080), "Capture is native 1920x1080")
	_expect(image.save_png(OUTPUT.path_join(label + ".png")) == OK, "Save " + label)

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

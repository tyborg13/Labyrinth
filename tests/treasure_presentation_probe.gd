extends "res://tests/ui_probe.gd"

const ChestProp = preload("res://scripts/relic_chest_prop.gd")
const TREASURE_OUTPUT: String = "user://probes/treasure_presentation_v1"
var _treasure_failures: Array[String]
var _treasure_scene: Node

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	SettingsStore.set_storage_path("user://treasure_settings.json")
	ProgressionStore.set_storage_path("user://treasure_progression.json")
	ProgressionStore.set_run_storage_path("user://treasure_run.save")
	ProgressionStore.clear_saved_run()
	var profile: Dictionary = preload("res://scripts/contextual_combat_tutorial.gd").complete_tutorial(ProgressionStore.default_data())
	ProgressionStore.save_data(profile)
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	root.get_node("InputRouter").call("set_forced_state_for_test", "pointer", "xbox")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TREASURE_OUTPUT))
	_proof_viewport = SubViewport.new()
	_proof_viewport.size = Vector2i(1920, 1080)
	_proof_viewport.msaa_2d = Viewport.MSAA_4X
	_proof_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_proof_viewport)
	_treasure_scene = load("res://scenes/run_scene.tscn").instantiate()
	_proof_viewport.add_child(_treasure_scene)
	await create_timer(0.25).timeout
	var engine := RunEngine.new()
	var base: Dictionary = engine.create_new_run(7321, profile)
	var treasure: Dictionary = _run_state_for_room(engine, base, _first_room_coord_of_type(engine, base, "treasure"), "treasure", Vector2i(1, 0))
	treasure["pending_relics"] = ["iron_lung", "ember_lens", "pilgrim_boots"]
	_prop_registration_contract()
	await _normal_sequence(treasure)
	await _reduced_and_cancellation(treasure, settings)
	await _input_handoffs(treasure)
	await _natural_room_entry(engine, base, treasure.get("current_room", Vector2i.ZERO))
	_treasure_scene.queue_free()
	await process_frame
	root.get_node("InputRouter").call("clear_forced_state_for_test")
	settings["reduced_motion"] = false
	SettingsStore.apply_settings(settings, root, false)
	for failure: String in _treasure_failures:
		push_error(failure)
	print(ProjectSettings.globalize_path(TREASURE_OUTPUT))
	print("TREASURE PRESENTATION PROBE: %s" % ("PASS" if _treasure_failures.is_empty() else "FAIL"))
	quit(0 if _treasure_failures.is_empty() else 1)

func _prop_registration_contract() -> void:
	for part: String in ["lid_interior", "lid_exterior"]:
		var pixels: Image = Image.load_from_file(ChestProp.ROOT + part + ".png")
		_expect_treasure(pixels != null and pixels.get_size() == Vector2i(128, 160), "Every lid layer uses the registered padded canvas")
		var used: Rect2 = Rect2(pixels.get_used_rect())
		for sample: int in range(101):
			var projection: float = lerpf(0.16 if part == "lid_interior" else 0.45, 1.0, float(sample) / 100.0)
			_expect_treasure(ChestProp.project_lid_point(ChestProp.HINGE_LEFT, projection).is_equal_approx(ChestProp.HINGE_LEFT) and ChestProp.project_lid_point(ChestProp.HINGE_RIGHT, projection).is_equal_approx(ChestProp.HINGE_RIGHT), "Both hinge landmarks remain fixed throughout the opening")
			for corner: Vector2 in [used.position, Vector2(used.end.x, used.position.y), used.end, Vector2(used.position.x, used.end.y)]:
				var point: Vector2 = ChestProp.project_lid_point(corner - ChestProp.CANVAS_OFFSET, projection) + ChestProp.CANVAS_OFFSET
				_expect_treasure(point.x >= 0.0 and point.y >= 0.0 and point.x <= 128.0 and point.y <= 160.0, "Painted lid stays in its fixed registered canvas")

func _normal_sequence(treasure: Dictionary) -> void:
	_treasure_scene.call("_load_run_state", treasure)
	_treasure_scene.call("_close_dialogue")
	_treasure_scene.call("_close_large_map")
	_expect_treasure(bool(_treasure_scene.get("_treasure_reveal_active")), "Treasure entry starts its opening gate")
	_expect_treasure(_choices().get_child_count() == 0, "Relic choices wait for chest opening")
	await _treasure_capture("01_chest_closed.png")
	await _wait_open_progress(0.20)
	_expect_treasure(_choices().get_child_count() == 0, "Choices stay absent during opening")
	await _treasure_capture("02_chest_opening.png")
	var epoch: int = int(_treasure_scene.get("_treasure_sequence_epoch"))
	var progress_before: float = float(_treasure_scene.get("_treasure_chest_progress"))
	_treasure_scene.call("_refresh_ui")
	_expect_treasure(int(_treasure_scene.get("_treasure_sequence_epoch")) == epoch and float(_treasure_scene.get("_treasure_chest_progress")) >= progress_before, "Harmless rebuild retains opening progress")
	_treasure_scene.call("_on_relic_pressed", "iron_lung", Rect2())
	_expect_treasure(not (_treasure_scene.get("_run_state") as Dictionary).get("relics", []).has("iron_lung"), "Early claim cannot bypass opening")
	await _wait_open_progress(0.99)
	var board: Node = _treasure_scene.get("board_view")
	var prop_index: Dictionary = board.get("_scene_props_by_tile")
	_expect_treasure(float((prop_index[Vector2i(4, 4)] as Array)[0].get("open_progress", 0.0)) >= 0.99, "Retained board tile receives every opening progress update")
	await _treasure_capture("03_chest_open_settle.png")
	await _wait_reveal()
	_expect_treasure(_choices().get_child_count() == 3, "Options appear after full opening settlement")
	var complete_key: String = str(_treasure_scene.get("_treasure_reveal_complete_key"))
	_treasure_scene.call("_refresh_ui")
	_expect_treasure(not bool(_treasure_scene.get("_treasure_reveal_active")) and str(_treasure_scene.get("_treasure_reveal_complete_key")) == complete_key, "Choices rebuild without replaying chest")
	_expect_treasure(_proof_viewport.gui_get_focus_owner() == null or not _choices().is_ancestor_of(_proof_viewport.gui_get_focus_owner()), "Pointer-only reveal leaves relic choices unfocused")
	await _treasure_capture("04_relic_options.png")
	var choice: Control = _choices().get_child(0) as Control
	choice.grab_focus()
	await _key_treasure(KEY_RIGHT)
	_expect_treasure((_choices().get_child(1) as Control).has_focus(), "Native keyboard focus traverses relic options")
	await _treasure_capture("05_relic_keyboard_focus.png")
	choice.grab_focus()
	await _key_treasure(KEY_ENTER)
	_expect_treasure(bool(_treasure_scene.get("_relic_claim_in_progress")), "Keyboard accept starts delivery")
	var saved: Dictionary = ProgressionStore.load_saved_run()
	_expect_treasure((saved.get("relics", []) as Array).count("iron_lung") == 1, "Claim is saved exactly once before delivery ends")
	_treasure_scene.call("_on_relic_pressed", "iron_lung", choice.get_global_rect() if is_instance_valid(choice) else Rect2())
	_treasure_scene.call("_open_large_map", true)
	_expect_treasure(not _map_visible(), "Manual map cannot cover delivery")
	var started: int = Time.get_ticks_msec()
	var captured_delivery: bool = false
	var captured_bounce: bool = false
	var captured_settle: bool = false
	while bool(_treasure_scene.get("_relic_claim_in_progress")) and Time.get_ticks_msec() - started < 4000:
		_expect_treasure(not _map_visible(), "Map remains hidden throughout delivery and settlement")
		var elapsed: float = float(Time.get_ticks_msec() - started) / 1000.0
		if elapsed > 0.15 and not captured_delivery:
			captured_delivery = true
			_treasure_scene.call("_refresh_ui")
			var beam: Node = _treasure_scene.find_child("RelicAcquisitionBeam", true, false)
			_expect_treasure(beam != null and not beam.is_queued_for_deletion(), "Harmless refresh retains the traveling delivery beam")
			await _treasure_capture("06_relic_delivery.png")
		if str(_treasure_scene.get("_relic_delivery_phase")) == "settlement" and not captured_bounce:
			captured_bounce = true
			await create_timer(0.12).timeout
			await _treasure_capture("07_relic_bounce.png")
		if str(_treasure_scene.get("_relic_delivery_phase")) == "settle" and not captured_settle:
			captured_settle = true
			await _treasure_capture("08_relic_final_settle.png")
		await process_frame
	_expect_treasure(captured_delivery and captured_bounce and captured_settle, "Temporal proof reaches delivery, bounce, and final settlement")
	_expect_treasure(not bool(_treasure_scene.get("_relic_claim_in_progress")) and _map_visible(), "Map opens promptly when presentation finishes")
	var frame: Control = _treasure_scene.call("_relic_frame_for_id", "iron_lung") as Control
	_expect_treasure(frame != null and frame.scale == Vector2.ONE and frame.modulate == Color.WHITE, "Destination has fully settled before map")
	_expect_treasure((_treasure_scene.get("_run_state") as Dictionary).get("relics", []).count("iron_lung") == 1, "Repeated claim input cannot duplicate ownership")
	await _treasure_capture("09_map_after_delivery.png")
	await _key_treasure(KEY_M)
	_expect_treasure(not _map_visible(), "Map keeps its native dismiss path after delivery")
	_treasure_scene.call("_load_run_state", saved)
	await process_frame
	await process_frame
	_expect_treasure(not bool(_treasure_scene.get("_treasure_reveal_active")) and not bool(_treasure_scene.get("_relic_claim_in_progress")), "Resuming the actual committed save does not replay reveal or delivery")
	_expect_treasure((_treasure_scene.get("_run_state") as Dictionary).get("relics", []).count("iron_lung") == 1 and _choices().get_child_count() == 0, "Resuming claimed treasure preserves one award and no choices")

func _reduced_and_cancellation(treasure: Dictionary, settings: Dictionary) -> void:
	settings["reduced_motion"] = true
	SettingsStore.apply_settings(settings, root, false)
	_treasure_scene.set("_settings", settings)
	root.get_node("InputRouter").call("set_forced_state_for_test", "controller", "xbox")
	_treasure_scene.call("_load_run_state", treasure)
	await process_frame
	await process_frame
	_expect_treasure(is_equal_approx(float(_treasure_scene.get("_treasure_chest_progress")), 1.0), "Reduced Motion shows the same static open chest")
	await _treasure_capture("10_reduced_open_chest.png")
	await _wait_reveal()
	_expect_treasure(_proof_viewport.gui_get_focus_owner() != null, "Controller recovers focus after opening")
	await _treasure_capture("11_reduced_controller_options.png")
	await _joy_treasure(JOY_BUTTON_DPAD_RIGHT)
	var focused: Control = _proof_viewport.gui_get_focus_owner()
	_expect_treasure(focused != null and str(focused.get_meta("relic_id", "")) == "ember_lens", "Native controller traversal reaches the second relic")
	await _joy_treasure(JOY_BUTTON_A)
	var choice: Control
	await process_frame
	_expect_treasure(_treasure_scene.find_child("RelicAcquisitionBeam", true, false) == null, "Reduced Motion suppresses traveling beam")
	await create_timer(0.35).timeout
	_expect_treasure(_map_visible() and not bool(_treasure_scene.get("_relic_claim_in_progress")), "Reduced delivery completes quickly without bounce")
	_expect_treasure((_treasure_scene.get("_run_state") as Dictionary).get("relics", []).has("ember_lens"), "Native controller accept claims the focused relic")
	await _treasure_capture("12_reduced_map.png")
	await _joy_treasure(JOY_BUTTON_B)
	_expect_treasure(not _map_visible(), "Controller back dismisses the delivered map")
	settings["reduced_motion"] = false
	SettingsStore.apply_settings(settings, root, false)
	_treasure_scene.set("_settings", settings)
	root.get_node("InputRouter").call("set_forced_state_for_test", "pointer", "xbox")
	_treasure_scene.call("_load_run_state", treasure)
	await _wait_open_progress(0.20)
	_treasure_scene.call("_load_run_state", treasure)
	await _wait_reveal()
	_expect_treasure(_choices().get_child_count() == 3, "Reload cancels stale opening and completes one fresh reveal")
	choice = _choices().get_child(0) as Control
	var choice_point: Vector2 = choice.get_global_rect().get_center()
	await _pointer_treasure(choice_point, true)
	await _pointer_treasure(choice_point, false)
	_expect_treasure(bool(_treasure_scene.get("_relic_claim_in_progress")), "Pointer still starts the claim")
	await create_timer(0.12).timeout
	_treasure_scene.call("_load_run_state", treasure)
	await _wait_reveal()
	await create_timer(1.3).timeout
	_expect_treasure(not bool(_treasure_scene.get("_relic_claim_in_progress")) and not _map_visible() and _choices().get_child_count() == 3, "Reload during delivery cannot reopen a stale map or strand input")

func _input_handoffs(treasure: Dictionary) -> void:
	var router: Node = root.get_node("InputRouter")
	router.call("clear_forced_state_for_test")
	router.call("set_modality", "controller")
	_treasure_scene.call("_load_run_state", treasure)
	var pointer := InputEventMouseMotion.new()
	pointer.position = Vector2(60, 60)
	pointer.relative = Vector2(30, 30)
	_proof_viewport.push_input(pointer, true)
	await _wait_reveal()
	var focused: Control = _proof_viewport.gui_get_focus_owner()
	_expect_treasure(focused == null or not _choices().is_ancestor_of(focused), "Pointer handoff during opening overrides stale controller mode")
	await _treasure_capture("13_pointer_handoff.png")
	router.call("set_modality", "pointer")
	_treasure_scene.call("_load_run_state", treasure)
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 0.75
	_proof_viewport.push_input(stick, true)
	await _wait_reveal()
	focused = _proof_viewport.gui_get_focus_owner()
	_expect_treasure(focused != null and _choices().is_ancestor_of(focused), "Stick navigation during opening restores visible choice focus")
	await _treasure_capture("14_controller_handoff.png")

func _natural_room_entry(engine: RunEngine, base: Dictionary, destination: Vector2i) -> void:
	var source := Vector2i(999, 999)
	for room: Dictionary in (base.get("rooms", {}) as Dictionary).values():
		for connection: Dictionary in room.get("connections", []):
			if connection.get("coord", Vector2i(999, 999)) == destination:
				source = room.get("coord", Vector2i(999, 999))
				break
		if source != Vector2i(999, 999):
			break
	_expect_treasure(source != Vector2i(999, 999), "Natural entry fixture has a real incoming route")
	if source == Vector2i(999, 999):
		return
	var incoming: Dictionary = _run_state_for_room(engine, base, source, "room", Vector2i(1, 0))
	var rooms: Dictionary = incoming.get("rooms", {}) as Dictionary
	(rooms[_room_key(destination)] as Dictionary)["revealed"] = true
	(rooms[_room_key(destination)] as Dictionary)["sealed"] = false
	_treasure_scene.call("_load_run_state", incoming)
	_treasure_scene.call("_close_dialogue")
	_treasure_scene.call("_close_large_map")
	await _treasure_scene.call("_on_map_view_room_selected", destination)
	_expect_treasure(bool(_treasure_scene.get("_treasure_reveal_active")) and not bool(_treasure_scene.get("_animation_lock")), "Natural room travel unlocks into chest opening before options")
	_expect_treasure(_choices().get_child_count() == 0, "Natural arrival cannot show choices before opening")
	await _wait_reveal()
	_expect_treasure(_choices().get_child_count() > 0, "Natural arrival reveals the engine's relic offer")
	await _treasure_capture("15_natural_room_entry.png")

func _joy_treasure(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		_proof_viewport.push_input(event, true)
		await process_frame

func _wait_reveal() -> void:
	var deadline: int = Time.get_ticks_msec() + 2500
	while bool(_treasure_scene.get("_treasure_reveal_active")) and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect_treasure(not bool(_treasure_scene.get("_treasure_reveal_active")), "Opening finishes within its bounded duration")
	await process_frame
	await process_frame

func _wait_open_progress(target: float) -> void:
	var deadline: int = Time.get_ticks_msec() + 2000
	while float(_treasure_scene.get("_treasure_chest_progress")) < target and Time.get_ticks_msec() < deadline:
		await process_frame

func _choices() -> HBoxContainer:
	return _treasure_scene.get("_relic_choice_bar") as HBoxContainer

func _map_visible() -> bool:
	return (_treasure_scene.get("_large_map_scrim") as Control).visible

func _key_treasure(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		_proof_viewport.push_input(event, true)
		await process_frame

func _pointer_treasure(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	_proof_viewport.push_input(event, true)
	await process_frame

func _treasure_capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var pixels: Image = _proof_viewport.get_texture().get_image()
	_expect_treasure(pixels.get_size() == Vector2i(1920, 1080), "Treasure proof uses native 1080/UI100")
	_expect_treasure(pixels.save_png(TREASURE_OUTPUT.path_join(filename)) == OK, "Save " + filename)

func _expect_treasure(ok: bool, message: String) -> void:
	if not ok and not _treasure_failures.has(message):
		_treasure_failures.append(message)

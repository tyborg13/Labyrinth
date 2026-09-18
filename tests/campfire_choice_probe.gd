extends SceneTree
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Hearth = preload("res://tests/suites/ember_hearth_suite.gd")
const ProbeScene = preload("res://tests/fixtures/ember_hearth_run_scene.gd")
const OUTPUT_DIR: String = "user://ember_hearth_probe_v2"
const PROBE_VIEWPORT: Vector2i = Vector2i(1920, 1080)
var _failed: bool = false
var _instance: Node

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(PROBE_VIEWPORT)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = PROBE_VIEWPORT
	root.size = PROBE_VIEWPORT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	Store.set_storage_path("user://hearth_probe_profile.json")
	Store.set_run_storage_path("user://hearth_probe_run.save")
	Settings.set_storage_path("user://hearth_probe_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	call_deferred("_run")

func _run() -> void:
	_instance = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_instance.set_script(ProbeScene)
	root.add_child(_instance)
	await process_frame
	Hearth.setup(_instance, 8, 0, false, true)
	var reveal_deadline: int = Time.get_ticks_msec() + 2000
	while Hearth.panel(_instance, 0).modulate.a < 0.1 and Time.get_ticks_msec() < reveal_deadline:
		await process_frame
	_check(Hearth.panel(_instance, 0).modulate.a > Hearth.panel(_instance, 2).modulate.a, "Arrival reveals the options in order")
	await _capture("01_arrival")
	await Hearth.wait_ready(self)
	_assert_framing()
	await _capture("02_unaffordable")
	Hearth.setup(_instance, 22, 180, false, true)
	await Hearth.wait_ready(self)
	await _capture("03_ready")
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "controller", "steam_deck")
	_instance.call("_refresh_controller_interface")
	Hearth.panel(_instance, 0).grab_focus()
	await _joy(JOY_BUTTON_DPAD_RIGHT)
	_check(root.gui_get_focus_owner() == Hearth.panel(_instance, 1), "Controller moves from Linger to Embrace")
	await _joy(JOY_BUTTON_DPAD_RIGHT)
	_check(root.gui_get_focus_owner() == Hearth.panel(_instance, 2), "Controller moves to affordable Strength")
	await _capture("04_controller_focus")
	# Return to pointer and use the actual viewport hit path, not a direct action call.
	router.call("set_forced_state_for_test", "pointer", "steam_deck")
	await process_frame
	await _click_panel(0)
	_check(bool(_instance.get("_campfire_choice_action_pending")), "Pointer activation begins one selection")
	await _capture("05_selected")
	await create_timer(0.22).timeout
	var board: Node = _instance.get("board_view")
	var presentation: Dictionary = board.get("presentation")
	_check((presentation.get("effect", {}) as Dictionary).get("kind", "") == "heal", "Healing uses the real character effect")
	_check(int((_instance.get("_run_state") as Dictionary).get("player_hp", 0)) == 24, "Healing shows the actual capped two-HP gain")
	await _capture("06_healing")
	await Hearth.wait_finished(self, _instance)
	await create_timer(0.5).timeout
	_check(not bool(_instance.get("_animation_lock")), "Linger releases travel after the result")
	_check((_instance.get("_large_map_scrim") as Control).visible, "The route map opens only after healing finishes")
	await _capture("07_continue")
	Hearth.setup(_instance, 8, 180, false, true)
	await Hearth.wait_ready(self)
	router.call("set_forced_state_for_test", "controller", "steam_deck")
	_instance.call("_refresh_controller_interface")
	Hearth.panel(_instance, 2).grab_focus()
	await _joy(JOY_BUTTON_A)
	await create_timer(0.43).timeout
	_check(int((_instance.get("_progression") as Dictionary).get("level", 0)) == 2, "Controller A commits Draw Strength")
	await _capture("08_strength_result")
	await Hearth.wait_finished(self, _instance)
	var learn: Button = (_instance.get("_skill_tree_view") as Node).get("_detail_action") as Button
	_check(learn != null and not learn.disabled, "The skill tree immediately enables spending the earned point")
	await _capture("09_skills")
	await _joy(JOY_BUTTON_B)
	_check(not (_instance.get("_upgrade_scrim") as Control).visible, "Controller B closes Skills")
	_check(not bool(_instance.get("_animation_lock")), "Closing Skills returns input")
	await create_timer(0.45).timeout
	_check((_instance.get("_large_map_scrim") as Control).visible, "Closing Skills returns to the route map")
	await _capture("10_strength_return")
	router.call("set_forced_state_for_test", "pointer", "steam_deck")
	Hearth.setup(_instance, 8, 0, true, true)
	await Hearth.wait_ready(self)
	await _click_panel(0)
	await create_timer(0.24).timeout
	presentation = board.get("presentation")
	_check(is_equal_approx(float(presentation.get("effect_progress", 0.0)), 0.48), "Reduced motion holds a visible static healing pose")
	_check(Hearth.panel(_instance, 0).scale == Vector2.ONE, "Reduced motion never scales a choice")
	await _capture("11_reduced_healing")
	await Hearth.wait_finished(self, _instance)
	Hearth.setup(_instance, 24, 180, false, true)
	await Hearth.wait_ready(self)
	await _capture("12_full_health")
	await _click_panel(1)
	await create_timer(0.44).timeout
	_check(not Store.has_saved_run(), "Embrace is already durably banked during departure")
	await _capture("13_bank_departure")
	await create_timer(1.1).timeout
	_check(_instance.get("requested_scene") == "res://scenes/main_menu.tscn", "Embrace finishes by returning to the main menu")
	router.call("clear_forced_state_for_test")
	_instance.queue_free()
	await process_frame
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("TEST RESULT: %s Ember Hearth visual and input sequence" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func _click_panel(index: int) -> void:
	var point: Vector2 = Hearth.panel(_instance, index).get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func _assert_framing() -> void:
	var board: Control = _instance.get("board_view") as Control
	var overlay: Control = _instance.get("_relic_choice_host") as Control
	var bounds: Rect2 = _instance.call("_contextual_combat_rendered_board_bounds")
	var safe: Rect2 = (board.get("presentation") as Dictionary).get("board_safe_global_rect", Rect2())
	_check(bounds.end.y <= overlay.get_global_rect().position.y - 8.0, "Room stays clear of the choices")
	_check(absf(bounds.get_center().y - safe.get_center().y) <= safe.size.y * 0.16, "Room remains centered above the choices")
	_check(bounds.size.x >= PROBE_VIEWPORT.x * 0.45, "Room remains visually primary")

func _capture(name: String) -> void:
	await _save_root_screenshot("%s/hearth_v2_%s.png" % [OUTPUT_DIR, name])

func _check(ok: bool, message: String) -> void:
	if not ok: _fail(message)

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	print("TEST RESULT: FAIL " + message)

func _save_root_screenshot(output_path: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(true)
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null:
		_fail("Campfire proof should capture a renderer image")
		return
	var source_size: Vector2i = image.get_size()
	var scale_x: float = float(source_size.x) / float(PROBE_VIEWPORT.x)
	var scale_y: float = float(source_size.y) / float(PROBE_VIEWPORT.y)
	if not is_equal_approx(scale_x, scale_y):
		_fail("Campfire proof should preserve 1920x1080 proportions, got %s" % source_size)
		return
	if source_size != PROBE_VIEWPORT:
		image.resize(PROBE_VIEWPORT.x, PROBE_VIEWPORT.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(output_path)

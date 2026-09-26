extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const OUTPUT: String = "user://ui_hover_sfx_v1"
var failed: bool = false
var feedback: Node
var viewport: SubViewport

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	Store.set_storage_path("user://ui_hover_profile.json")
	Store.set_run_storage_path("user://ui_hover_run.save")
	Settings.set_storage_path("user://ui_hover_settings.json")
	Store.clear_saved_run()
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	call_deferred("_run")

func _run() -> void:
	feedback = root.get_node("CursorFeedback")
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.notify_mouse_entered()
	while bool(feedback.call("is_loading")): await process_frame
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	viewport.add_child(menu)
	await _settle()
	var settings_button: Button = menu.get("settings_button")
	_move(Vector2(1900, 1040))
	await _settle()
	var before: int = _count()
	_move(settings_button.get_global_rect().get_center())
	await process_frame
	_check(_count() == before + 1, "Title Settings pointer hover plays one shared cue")
	_check(settings_button.is_hovered(), "Title proof shows a native hover")
	await _save("01_title_hover")
	# Actual press/release opens the existing Settings flow; hover/focus must not
	# replay the cue even when the pointer already dwelled beyond the cooldown.
	await _settle()
	before = _count()
	_click(settings_button.get_global_rect().get_center())
	await _settle()
	var panel: Control = menu.get("settings_panel")
	_check(panel.visible, "Pointer activation opens Settings")
	_check(_count() == before, "Clicking a hovered menu button does not double its hover cue")
	_move(Vector2(1900, 1040))
	var display_option: OptionButton = panel.get("_controls")["display_mode"]
	display_option.grab_focus()
	await _settle()
	before = _count()
	_key(KEY_TAB)
	await process_frame
	var focused: Control = viewport.gui_get_focus_owner()
	_check(focused != null and focused == panel.get("_controls")["ui_scale"], "Tab traverses the Settings controls")
	_check(_count() == before + 1, "Settings keyboard navigation plays one focus cue")
	await _save("02_settings_keyboard_focus")
	# Back/cancel restores the title's existing navigation state.
	menu.call("_on_settings_back_button_pressed")
	await _settle()
	menu.get("start_button").grab_focus()
	await _settle()
	before = _count()
	_joy(JOY_BUTTON_DPAD_DOWN)
	await process_frame
	_check(settings_button.has_focus(), "Controller navigation reaches title Settings")
	_check(_count() == before + 1, "Title controller navigation plays one focus cue")
	await _save("03_title_controller_focus")
	var music: AudioStreamPlayer = menu.get_node_or_null("MusicPlayer")
	if music != null: music.stop()
	menu.queue_free()
	await process_frame

	var run: Node = load("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(run)
	await _settle()
	run.call("_close_dialogue")
	var state: Dictionary = RunEngine.new().create_new_run(721, Store.default_data())
	state["mode"] = "campfire"
	state["current_room"] = Vector2i(3, -1)
	state["player_hp"] = 8
	state["player_max_hp"] = 24
	state["held_embers"] = 180
	run.call("_load_run_state", state)
	run.call("_close_dialogue")
	await create_timer(0.8).timeout
	_move(Vector2(1900, 1040))
	await _settle()
	_check(not bool(root.get_node("InputRouter").call("using_controller")), "Pointer input restores the existing input-device cues")
	var menu_button: Button = run.get("menu_button")
	before = _count()
	_move(menu_button.get_global_rect().get_center())
	await process_frame
	_check(_count() == before + 1, "In-run header hover plays the same cue")
	await _save("04_hearth_header_hover")
	_click(menu_button.get_global_rect().get_center())
	await _settle()
	var run_menu: Control = run.get("_menu_dialog")
	_check(run_menu != null and run_menu.visible, "In-run menu opens through native activation")
	await _save("05_run_menu")
	run.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame
	print(ProjectSettings.globalize_path(OUTPUT))
	print("TEST RESULT: %s Shared UI hover renderer/input proof" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)

func _move(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = Vector2(12, 12)
	root.get_node("InputRouter").call("_input", event)
	viewport.push_input(event, true)

func _click(point: Vector2) -> void:
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.get_node("InputRouter").call("_input", event)
		viewport.push_input(event, true)

func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		viewport.push_input(event, true)

func _joy(code: JoyButton) -> void:
	for down: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = code
		event.pressed = down
		root.get_node("InputRouter").call("_input", event)
		viewport.push_input(event, true)

func _count() -> int:
	return int(feedback.call("feedback_counts").get("focus", 0))

func _settle() -> void:
	await process_frame
	await process_frame
	var deadline: int = Time.get_ticks_msec() + 140
	while Time.get_ticks_msec() < deadline: await process_frame

func _save(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	_check(image.get_size() == Vector2i(1920, 1080), "Proof must render natively at 1920x1080")
	_check(image.save_png(ProjectSettings.globalize_path(OUTPUT.path_join(label + ".png"))) == OK, "Screenshot should save")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

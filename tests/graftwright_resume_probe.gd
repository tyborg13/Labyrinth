extends SceneTree

const Parallel = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Data = preload("res://scripts/game_data.gd")
const Rules = preload("res://scripts/graftwright_rules.gd")
const SIZE := Vector2i(1920, 1080)
const OUTPUT := "user://graftwright_resume_probe"
var failed: bool = false

func _initialize() -> void:
	Parallel.apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not check(args.size() == 1, "Pass the generated fixture's save directory"): return
	# Copy the real generated save into the probe's namespace. Do not reconstruct
	# state or bypass the main-menu resume gate with _load_run_state or root meta.
	for filename: String in ["current_run.save", "progression.json"]:
		var destination: String = ProjectSettings.globalize_path("user://" + filename)
		if not check(DirAccess.copy_absolute(args[0].path_join(filename), destination) == OK, "Copy generated " + filename): return
	var original: Dictionary = Store.load_saved_run()
	if not check(original.get("mode") == "graftwright" and original.has("inspection_fixture"), "Probe uses the generated Graftwright fixture"): return
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await process_frame
	var menu: Node = await open_menu()
	var button: Button = menu.get_node("MenuColumn/ContinueButton")
	if not check(not button.disabled, "Generated fixture enables Continue Run in the actual main menu"): return
	check((menu.get_node("ResumePanel/ResumeMargin/ResumeVBox/ResumeLocation") as Label).text.contains("GRAFTWRIGHT"), "Main menu identifies saved encounter")
	await capture("01_continue_enabled.png")
	await click(button)
	var view: Control = await resumed_view()
	if view == null: return
	check(not bool(view.call("semantic_snapshot")["used"]), "Pointer Continue reaches the unused workbench")
	var resumed: Dictionary = current_scene.get("_run_state")
	check(resumed["current_room"] == original["current_room"], "Continue preserves the saved destination")
	check(Rules.owned(resumed) == Rules.owned(original), "Continue preserves all equipment before any graft")
	await capture("02_resumed_workbench.png")
	# Finish the user's example through the live UI, then return to a newly
	# instantiated menu and resume the persisted result through controller input.
	await click(view.find_child("SourceCard_1", true, false) as Button)
	await click(view.find_child("TargetCard_1", true, false) as Button)
	await click(view.find_child("GraftCommit", true, false) as Button)
	var deadline: int = Time.get_ticks_msec() + 6000
	while bool(view.call("semantic_snapshot")["busy"]) and Time.get_ticks_msec() < deadline:
		await process_frame
	if not check(bool(view.call("semantic_snapshot")["used"]), "Live graft reaches its result"): return
	var grafted: Dictionary = Store.load_saved_run()
	check(Data.equipment_cards("undertaker_plate", grafted) == ["undertaker_stand", "shadow_step"], "Live graft persists Shadow Step")
	check(not Rules.owned(grafted).has("patched_cloak"), "Live graft consumes Patched Cloak once")
	await create_timer(0.4).timeout
	await capture("03_result_before_restart.png")
	var previous: Node = current_scene
	current_scene = null
	previous.queue_free()
	await process_frame
	await process_frame
	menu = await open_menu()
	button = menu.get_node("MenuColumn/ContinueButton")
	if not check(not button.disabled, "Completed graft still enables Continue Run"): return
	button.grab_focus()
	await capture("04_continue_after_graft.png")
	for down: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_A
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	view = await resumed_view()
	if view == null: return
	check(bool(view.call("semantic_snapshot")["used"]), "Controller Continue resumes the result instead of offering another graft")
	resumed = current_scene.get("_run_state")
	check(resumed["equipment_grafts"] == grafted["equipment_grafts"] and Rules.owned(resumed) == Rules.owned(grafted), "Menu resume neither loses nor duplicates inherited equipment")
	await capture("05_resumed_result.png")
	print(ProjectSettings.globalize_path(OUTPUT))
	print("TEST RESULT: PASS — generated fixture resumes through the main menu before and after grafting" if not failed else "TEST RESULT: FAIL — Graftwright menu resume")
	quit(1 if failed else 0)

func open_menu() -> Node:
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	await create_timer(0.4).timeout
	return menu

func resumed_view() -> Control:
	var deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/run_scene.tscn" and not root.gui_disable_input:
			await create_timer(0.4).timeout
			var view: Control = current_scene.find_child("GraftwrightView", true, false) as Control
			if check(view != null and view.is_visible_in_tree(), "Real menu transition reaches visible Graftwright workbench"):
				return view
			return null
	check(false, "Continue must finish its real scene transition")
	return null

func click(button: Button) -> void:
	if not check(button != null and not button.disabled, "Live pointer target is enabled"): return
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	var move := InputEventMouseMotion.new()
	move.position = point
	root.push_input(move, true)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	if not check(frame.get_size() == SIZE, "Native screenshot must be 1920x1080 without resizing"): return
	check(frame.save_png(OUTPUT.path_join(filename)) == OK, "Save proof screenshot " + filename)

func check(ok: bool, message: String) -> bool:
	if not ok:
		failed = true
		push_error(message)
		quit(1)
	return ok

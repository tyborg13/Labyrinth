extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const SIZE := Vector2i(1920, 1080)
const OUTPUT := "user://probes/protagonist_cutout_continue"
var failures: Array[String]
var phases: Array[String]
var surface: Viewport
var room: Node

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	Progression.set_storage_path("user://cutout_continue_progression.json")
	Progression.set_run_storage_path("user://cutout_continue_run.save")
	Settings.set_storage_path("user://cutout_continue_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["reduced_motion"] = false
	settings["music_volume"] = 0.0
	settings["sfx_volume"] = 0.0
	Settings.save_settings(settings)
	var saved: Dictionary = Run.new().create_debug_boss_run(Progression.default_data())
	saved["debug_boss_run"] = false
	Progression.save_run_state(saved)
	_run.call_deferred()

func _run() -> void:
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	# SceneTree.current_scene requires the real root, as the live menu flow does.
	surface = root
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	surface.add_child(menu)
	current_scene = menu
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await _capture("01_continue_ready.png")
	menu.call("_on_continue_button_pressed")
	var transition: Node = surface.get_node_or_null("MenuRunTransition")
	_check(transition != null, "Continue enters the staged transition")
	if transition == null:
		quit(1)
		return
	phases.append(str(transition.get("phase")))
	transition.phase_changed.connect(func(phase: StringName) -> void: phases.append(str(phase)))
	transition.finished.connect(func(destination: Node) -> void: room = destination)
	var deadline: int = Time.get_ticks_msec() + 20000
	var captured_reveal: bool = false
	while room == null and Time.get_ticks_msec() < deadline:
		await process_frame
		if is_instance_valid(transition) and str(transition.get("phase")) == "revealing" and not captured_reveal:
			captured_reveal = true
			await _capture("02_revealing.png")
	_check(room != null, "Staged Continue completes")
	if room != null:
		await _capture("03_continue_complete.png")
		var board: Control = room.get("board_view")
		var snapshot: Dictionary = board.call("protagonist_animation_snapshot")
		_check(not snapshot.is_empty() and str(snapshot.get("facing")) == "front" and not bool(snapshot.get("mirrored", false)), "Continue reveals the accepted front-facing cutout")
		_check(room.call("initial_presentation_is_ready") and not surface.gui_disable_input, "Complete Continue has settled layout and restored input")
	_check("preparing" in phases and "revealing" in phases and "complete" in phases, "Continue uses the actual staged reveal lifecycle")
	var output := FileAccess.open(OUTPUT.path_join("continue_manifest.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"ok": failures.is_empty(), "size": [1920, 1080], "ui_scale": 1.0, "phases": phases, "captured_reveal": captured_reveal, "errors": failures}, "\t"))
	output.close()
	print("Saved ", ProjectSettings.globalize_path(OUTPUT))
	print("CUTOUT_CONTINUE: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var captured: Image = surface.get_texture().get_image()
	_check(captured.get_size() == SIZE, "Capture retains 1920x1080: " + name)
	_check(captured.save_png(OUTPUT.path_join(name)) == OK, "Save " + name)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

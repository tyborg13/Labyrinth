extends SceneTree
const Suite = preload("res://tests/suites/event_rules_suite.gd")
var failures: Array[String]
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--write-proof-contract"):
		var index: int = args.find("--write-proof-contract")
		if index + 1 < args.size(): _write_contract(args[index + 1])
		else: quit(1)
	elif args.has("--probe"):
		_probe.call_deferred()
	else:
		_run.call_deferred()

func _run() -> void:
	Suite.run(func(ok: bool, message: String) -> void:
		if not ok and not failures.has(message): failures.append(message)
	)
	for failure: String in failures: push_error(failure)
	print("Event rules suite: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)

# Debug-only real-renderer proof mode; the design owner runs this windowed.
const PROOF_SIZE: Vector2i = Vector2i(1920, 1080)
const PROOF_SETTLE_FRAMES: int = 2
const PROOF_POST_DRAW_FRAMES: int = 1
const PROOF_DIRECTORY: String = "user://ev-01-events"
const PROOF_CONTRACT: Dictionary = {
	"min_images": 3,
	"expected_sizes": ["1920x1080"],
	"required_images": [
		{"pattern": "*01_choices.png", "width": 1920, "height": 1080},
		{"pattern": "*02_blocked_focus.png", "width": 1920, "height": 1080},
		{"pattern": "*03_result.png", "width": 1920, "height": 1080}
	]
}

func _write_contract(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write event proof contract: " + path)
		quit(1)
		return
	file.store_string(JSON.stringify(PROOF_CONTRACT, "\t") + "\n")
	print("Event proof contract: " + ProjectSettings.globalize_path(path))
	quit(0)

func _probe() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var settings = preload("res://scripts/settings_store.gd")
	settings.set_storage_path("user://event_probe_settings.json")
	var options: Dictionary = settings.default_settings()
	options["ui_scale"] = 1.0
	settings.save_settings(options)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = PROOF_SIZE
	root.content_scale_factor = 1.0
	root.size = PROOF_SIZE
	var viewport := SubViewport.new()
	viewport.size = PROOF_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var panel := preload("res://scripts/section_map_panel.gd").new()
	panel.size = Vector2(PROOF_SIZE)
	viewport.add_child(panel)
	var engine := preload("res://scripts/run_engine.gd").new()
	var state: Dictionary = Suite._event_state(engine, "bloodletters_basin")
	panel.set_run_state(state)
	await _capture(viewport, "01_choices.png")
	state["player_hp"] = 5
	panel.set_run_state(state)
	panel.focus_controller_on_current()
	await _capture(viewport, "02_blocked_focus.png")
	if panel.get("_event_buttons").size() != 3 or not panel.get("_event_buttons")[0].disabled:
		failures.append("Probe must retain three choices and disabled Health requirement")
	state = engine.resolve_map_event(state, "reach")
	panel.set_run_state(state)
	await _capture(viewport, "03_result.png")
	if panel.get("_event_buttons").size() != 1 or panel.get("_event_buttons")[0].text != "Continue":
		failures.append("Probe must show the result continuation")
	print(ProjectSettings.globalize_path(PROOF_DIRECTORY))
	print("Event UI probe: %d failures" % failures.size())
	for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _capture(viewport: SubViewport, filename: String) -> void:
	for _frame: int in range(PROOF_SETTLE_FRAMES): await process_frame
	RenderingServer.force_draw()
	for _frame: int in range(PROOF_POST_DRAW_FRAMES): await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROOF_DIRECTORY))
	var image: Image = viewport.get_texture().get_image()
	if image.get_size() != PROOF_SIZE or image.save_png(PROOF_DIRECTORY.path_join(filename)) != OK:
		failures.append("Capture failed: " + filename)

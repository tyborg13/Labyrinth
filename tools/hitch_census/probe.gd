extends SceneTree
## Visual handoff only. Separate from timing to keep PNG readback out of the trace.
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const PROOF_SIZE := Vector2i(1920, 1080)
const PROOF_SCALE: float = 1.0
const PROOF_SETTLE_FRAMES: int = 60
var output: String = ""

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless" or output.is_empty():
		push_error("HITCH PROOF: requires window server and --output")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	Settings.set_storage_path("user://hitch-proof-settings.json")
	Store.set_storage_path("user://hitch-proof-progression.json")
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = "windowed"
	settings["ui_scale"] = PROOF_SCALE
	Settings.save_settings(settings)
	Store.save_data(Store.default_data())
	root.size = PROOF_SIZE
	root.content_scale_factor = PROOF_SCALE
	var container := SubViewportContainer.new()
	root.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = PROOF_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	viewport.add_child(load("res://scenes/main_menu.tscn").instantiate())
	for frame: int in range(PROOF_SETTLE_FRAMES): await RenderingServer.frame_post_draw
	var path: String = output.path_join("census-title-1920.png")
	if viewport.get_texture().get_image().save_png(path) != OK:
		push_error("HITCH PROOF: PNG failed")
		quit(1)
		return
	print(path)
	print("HITCH VISUAL PROOF: PASS 1920x1080 scale=1.0")
	quit()

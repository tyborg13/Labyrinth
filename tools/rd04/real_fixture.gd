extends "res://tools/ptf09/real_fixture.gd"

const SharedFixture = preload("res://tools/ptf09/real_fixture.gd")
const CASE_ROOT: String = "/private/tmp/labyrinth_codex/rd-04/feedback2"

static func install_save(manifest_path: String = CASE_ROOT + "/overlap.json") -> Dictionary:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	assert(bool(manifest.get("verified", false)) and str(manifest.get("scenario", "")) in ["combat", "dragon", "snare"], "Stock-certified combat save required")
	var run_id: String = manifest["run_id"]
	var source: String = str(manifest["verification"]["godot_home_root"]).path_join(run_id).path_join("Library/Application Support/Escape the Umbra Parallel " + run_id)
	Store.set_storage_path("user://progression.json")
	Store.set_run_storage_path("user://current_run.save")
	for filename: String in ["progression.json", "current_run.save"]:
		assert(DirAccess.copy_absolute(source.path_join(filename), ProjectSettings.globalize_path("user://" + filename)) == OK, "Copy certified save")
	var state: Dictionary = Store.load_saved_run()
	assert(str(state.get("mode", "")) == "combat" and state.get("inspection_fixture", {}).get("scenario") == manifest["scenario"], "Real combat and certified scenario retained")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	return state

static func pointer(tree: SceneTree, board: Control, local_point: Vector2) -> void:
	# Native GUI layout and get_mouse_position() must observe the same position
	# as the injected event. push_input alone does not move the OS pointer.
	if DisplayServer.get_name() != "headless": tree.root.warp_mouse(board.get_global_transform_with_canvas() * local_point)
	SharedFixture.pointer(tree, board, local_point)

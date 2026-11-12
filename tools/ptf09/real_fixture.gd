extends RefCounted

## Resume the certified combat save through the production boot path. Copies
## isolate capture-time persistence from the owner's original inspection save.
const Parallel = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const SIZE := Vector2i(1920, 1080)
const MANIFEST: String = "/private/tmp/labyrinth_codex/ptf-09/feedback2/inspection.json"
const CRATE := Vector2i(3, 4)
const FOE := Vector2i(3, 3)
const TALL := Vector2i(4, 5)
const EMPTY_BEHIND := Vector2i(4, 4)
const SWEEP: Array = [Vector2i(2, 3), FOE, Vector2i(4, 3), EMPTY_BEHIND, Vector2i(5, 4), TALL]
const SETUP_FRAMES: int = 16

static func install_save(manifest_path: String = MANIFEST) -> Dictionary:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	assert(bool(manifest.get("verified", false)) and str(manifest.get("scenario", "")) == "combat", "A verified inspection_fixture.py --scenario combat manifest is required")
	var run_id: String = manifest["run_id"]
	var home: String = manifest["verification"]["godot_home_root"]
	var source: String = home.path_join(run_id).path_join("Library/Application Support/Escape the Umbra Parallel " + run_id)
	Store.set_storage_path("user://progression.json")
	Store.set_run_storage_path("user://current_run.save")
	assert(DirAccess.copy_absolute(source.path_join("progression.json"), ProjectSettings.globalize_path("user://progression.json")) == OK, "Copy certified inspection profile")
	assert(DirAccess.copy_absolute(source.path_join("current_run.save"), ProjectSettings.globalize_path("user://current_run.save")) == OK, "Copy certified inspection save")
	var state: Dictionary = Store.load_saved_run()
	assert(str(state.get("mode", "")) == "combat" and state.get("inspection_fixture", {}).get("scenario", "") == "combat", "Real certified combat state")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	return state

static func make_canvas(tree: SceneTree) -> SubViewport:
	tree.root.size = SIZE
	tree.root.content_scale_size = SIZE
	tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var container := SubViewportContainer.new()
	container.name = "RealCombatCapture"
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	tree.root.add_child(container)
	var canvas := SubViewport.new()
	canvas.size = SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(canvas)
	return canvas

static func resume(tree: SceneTree, canvas: SubViewport) -> Node:
	tree.root.set_meta("labyrinth_resume_saved_run", true)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	return scene

static func pointer(tree: SceneTree, board: Control, local_point: Vector2) -> void:
	var point: Vector2 = board.get_global_transform_with_canvas() * local_point
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	# One production input path only: viewport GUI dispatch owns tile hover,
	# last-pointer bookkeeping and scene presentation. Never write hover again.
	tree.root.push_input(motion, true)

static func slot(board: Control) -> bool:
	var border: Node2D = board.get("_targeted_tile_highlight")
	if border == null or not border.z_as_relative or border.z_index != 0: return false
	if border.get_index() != (board.get("_action_floor_render_layer") as Node).get_index() + 1: return false
	for layer: Node in board.get("_scene_render_layers"):
		if layer.get_index() <= border.get_index(): return false
	return bool(board.call("_scene_render_layers_match", board.call("_rendered_tiles_in_draw_order")))

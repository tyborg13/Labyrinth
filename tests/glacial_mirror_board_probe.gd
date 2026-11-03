extends "res://tools/inspection_fixture.gd"

## Production fixture and RunScene, with a fixed proof-only camera and clocks.
## --stage before requires the legacy profile; the capture helper restores it
## only for that process. --validate-only checks fixtures/facings headlessly.
const MirrorPresentation = preload("res://scripts/actor_presentation.gd")
const MirrorSettings = preload("res://scripts/settings_store.gd")
const MirrorTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const PROOF_SIZE := Vector2i(1920, 1080)
const PROOF_OUTPUT_ENV := "LABYRINTH_GLACIAL_MIRROR_PROOF_OUTPUT"
const PROOF_PLAYER_TILE := Vector2i(4, 4)
const PROOF_ENEMY_POSITIONS := "4:3,5:4,4:5,3:4"
const PROOF_TILE_WIDTH: float = 128.0
const PROOF_ORIGIN := Vector2(960.0, 160.0)
const FOOT_CROP_SIZE := Vector2i(240, 160)
const CROP_MAGNIFICATION: int = 3
const SETTLE_FRAMES: int = 5
const SETTLE_SECONDS: float = 0.5
const REGISTRATION_EPSILON_PX: float = 0.01
const EXPECTED_VIEWS: Array = ["front", "rear_mirrored", "rear", "front_mirrored"]
const LEGACY_ANCHORS: Array = [Vector2(127.0, 231.46), Vector2(130.0, 231.46)]
const CURRENT_ANCHORS: Array = [Vector2(113.64, 221.74), Vector2(109.90, 221.71)]

var _proof_errors: Array[String]
var _proof_scene: Node
var _proof_board: Control
var _proof_viewport: SubViewport
var _proof_stage: String = "after"
var _proof_validate_only: bool = false
var _proof_output: String = "user://probes/glacial_mirror_board"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	if not OS.get_environment(PROOF_OUTPUT_ENV).is_empty():
		_proof_output = OS.get_environment(PROOF_OUTPUT_ENV)
	call_deferred("_mirror_run")

func _mirror_run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_proof_validate_only = args.has("--validate-only")
	var stage_index: int = args.find("--stage")
	if stage_index >= 0 and stage_index + 1 < args.size():
		_proof_stage = args[stage_index + 1]
	if _proof_stage not in ["before", "after", "seer_reference"]:
		_proof_check(false, "Unknown proof stage")
		_finish()
		return
	if DisplayServer.get_name() == "headless" and not _proof_validate_only:
		_proof_check(false, "Captures require the windowed visual_probe_runner")
		_finish()
		return
	if _proof_stage != "seer_reference":
		var anchors: Array = LEGACY_ANCHORS if _proof_stage == "before" else CURRENT_ANCHORS
		for index: int in range(2):
			_proof_check(MirrorPresentation.floor_anchor("glacial_mirror", "front" if index == 0 else "rear").is_equal_approx(anchors[index]), "Stage uses its exact profile")
	var actor: String = "hoarfrost_seer" if _proof_stage == "seer_reference" else "glacial_mirror"
	# Same helper fields as inspection_fixture.py --enemy-types/--enemy-positions.
	_options = {"seed": DEFAULT_SEED, "player_position": "4:4",
		"enemy_types": ",".join([actor, actor, actor, actor]),
		"enemy_positions": PROOF_ENEMY_POSITIONS, "notice": "pt13-06 standing proof"}
	var progression: Dictionary = ProgressionStore.default_data()
	for prompt: String in MirrorTutorial.prompt_ids():
		progression = MirrorTutorial.resolve_progression(progression, prompt)
	var run: Dictionary = _build_run_state("combat", progression)
	if _failed or run.is_empty():
		_proof_check(false, "Build the production combat fixture")
		_finish()
		return
	var state: Dictionary = run["combat_state"]
	_proof_check(state["player"]["pos"] == PROOF_PLAYER_TILE, "Hero occupies the centre tile")
	_proof_check((state["enemies"] as Array).size() == 4, "Four adjacent enemies")
	for enemy: Dictionary in state["enemies"]:
		var delta: Vector2i = enemy["pos"] - PROOF_PLAYER_TILE
		_proof_check(absi(delta.x) + absi(delta.y) == 1, "Enemy occupies an adjacent tile")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = PROOF_SIZE
	root.size = PROOF_SIZE
	ProgressionStore.set_storage_path("user://mirror_progression.json")
	ProgressionStore.set_run_storage_path("user://mirror_run.save")
	MirrorSettings.set_storage_path("user://mirror_settings.json")
	ProgressionStore.clear_saved_run()
	var settings: Dictionary = MirrorSettings.default_settings()
	settings["display_mode"] = MirrorSettings.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	_proof_check(MirrorSettings.save_settings(settings), "Save isolated 100% UI settings")
	_proof_viewport = SubViewport.new()
	_proof_viewport.size = PROOF_SIZE
	_proof_viewport.disable_3d = true
	_proof_viewport.world_2d = World2D.new()
	_proof_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_proof_viewport.gui_disable_input = true
	root.add_child(_proof_viewport)
	_proof_scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_proof_viewport.add_child(_proof_scene)
	await _settle_proof()
	_proof_board = _proof_scene.get("board_view") as Control
	_proof_scene.set("_settings", settings)
	_proof_scene.set("_progression", progression)
	_proof_scene.set("_run_state", run)
	_proof_scene.set("_board_encounter_key", "")
	_proof_scene.call("_reset_card_resolution")
	_proof_scene.call("_sync_combat_state_from_run")
	_proof_scene.call("_refresh_ui")
	await create_timer(SETTLE_SECONDS).timeout
	_proof_scene.call("_close_dialogue")
	_proof_scene.call("_close_large_map")
	var presentation: Dictionary = _proof_scene.call("_stage_chrome_presentation")
	presentation["ambient_time_seconds"] = 0.0
	presentation["damage_preview_time_seconds"] = 0.0
	presentation["protagonist_motion"] = {"clip": "idle", "direction": Vector2i(0, 1)}
	_proof_scene.call("_render_board_state", state, presentation, false)
	await _settle_proof()
	_freeze(_proof_scene)
	for tween: Tween in get_processed_tweens():
		tween.kill()
	_proof_board.set("_idle_elapsed", 0.0)
	_proof_board.set("_idle_frame_by_source", {})
	# Use the existing resolved-geometry helper: all three stages share a camera
	# even though the corrected registration changes the production fit budget.
	_proof_board.call("_populate_board_layout_cache", _proof_board.get("_board_layout_cache_tiles"), PROOF_TILE_WIDTH, PROOF_ORIGIN)
	var actors: Array[Dictionary]
	for unit: Dictionary in _proof_board.call("_visible_units"):
		var renderer: Node = _proof_board.call("unit_cutout_renderer", unit)
		if is_instance_valid(renderer):
			renderer.set("_idle_seconds", 0.0)
			renderer.call("_apply_pose")
		if str(unit.get("role", "")) == "enemy":
			actors.append(unit)
	actors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["id"]) < int(b["id"]))
	var views: Array[String]
	var actor_proof: Array[Dictionary]
	for index: int in range(actors.size()):
		var unit: Dictionary = actors[index]
		var renderer: Node = _proof_board.call("unit_cutout_renderer", unit)
		_proof_check(is_instance_valid(renderer), "Production cutout exists")
		if not is_instance_valid(renderer): continue
		var facing: String = str(renderer.get("facing"))
		var mirrored: bool = bool(renderer.get("mirrored"))
		var view: String = facing + ("_mirrored" if mirrored else "")
		views.append(view)
		_proof_check(view == EXPECTED_VIEWS[index], "Expected adjacent facing: " + view)
		var center: Vector2 = _proof_board.call("_unit_center", unit)
		var rect: Rect2 = _proof_board.call("_unit_draw_rect_for_center", unit, center)
		var anchor: Vector2 = MirrorPresentation.floor_anchor(actor, facing, mirrored)
		_proof_check((rect.position + anchor * rect.size / 255.0).distance_to(center) < REGISTRATION_EPSILON_PX, view + " anchor registers on tile")
		var hp: Rect2 = _proof_board.call("_unit_health_bar_rect", unit, center)
		_proof_check(is_equal_approx(float(_proof_board.call("_unit_art_top_y", unit, center)) - hp.end.y, 4.0), view + " keeps four-pixel HUD clearance")
		actor_proof.append({"view": view, "tile": [unit["pos"].x, unit["pos"].y],
			"anchor": [anchor.x, anchor.y], "center": [center.x, center.y]})
	_proof_check(views.size() == 4, "All four production facings are visible")
	_proof_board.call("_sync_dynamic_render_state", false)
	_proof_board.call("_sync_static_render_cache")
	_proof_board.call("_queue_dynamic_redraw")
	_proof_board.queue_redraw()
	await _settle_proof()
	_proof_check(is_equal_approx(float(_proof_board.call("_tile_width")), PROOF_TILE_WIDTH), "Matched proof camera scale")
	_proof_check((_proof_board.call("_board_origin") as Vector2).is_equal_approx(PROOF_ORIGIN), "Matched proof camera origin")
	if not _proof_validate_only:
		await RenderingServer.frame_post_draw
		var image: Image = _proof_viewport.get_texture().get_image()
		_proof_check(image.get_size() == PROOF_SIZE, "Native 1920x1080 capture")
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_proof_output))
		_save(image, _proof_stage + ".png")
		if actor == "glacial_mirror":
			for index: int in range(actors.size()):
				var center: Vector2 = _proof_board.call("_unit_center", actors[index])
				center += _proof_board.position
				var crop_rect := Rect2i(Vector2i(center) - FOOT_CROP_SIZE / 2, FOOT_CROP_SIZE)
				_proof_check(Rect2i(Vector2i.ZERO, PROOF_SIZE).encloses(crop_rect), "Feet crop stays inside the capture")
				var crop: Image = image.get_region(crop_rect)
				crop.resize(FOOT_CROP_SIZE.x * CROP_MAGNIFICATION, FOOT_CROP_SIZE.y * CROP_MAGNIFICATION, Image.INTERPOLATE_NEAREST)
				_save(crop, _proof_stage + "_" + views[index] + "_feet_3x.png")
		var file := FileAccess.open(_proof_output.path_join(_proof_stage + ".json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"size": [1920, 1080], "ui_scale": 1.0, "actors": actor_proof,
			"tile_width": PROOF_TILE_WIDTH, "origin": [PROOF_ORIGIN.x, PROOF_ORIGIN.y], "errors": _proof_errors}, "\t"))
		file.close()
		print(ProjectSettings.globalize_path(_proof_output))
	_finish()

func _settle_proof() -> void:
	for frame: int in range(SETTLE_FRAMES):
		await process_frame

func _freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children():
		_freeze(child)

func _save(image: Image, filename: String) -> void:
	_proof_check(image.save_png(_proof_output.path_join(filename)) == OK, "Save " + filename)

func _proof_check(condition: bool, message: String) -> void:
	if not condition: _proof_errors.append(message)

func _finish() -> void:
	for error: String in _proof_errors: push_error(error)
	print("GLACIAL MIRROR BOARD %s: %s" % ["HEADLESS FIXTURE" if _proof_validate_only else "PROBE", "PASS" if _proof_errors.is_empty() else "FAIL"])
	if _proof_viewport != null:
		_proof_viewport.queue_free()
		await process_frame
	quit(0 if _proof_errors.is_empty() else 1)

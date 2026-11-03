extends "res://tools/inspection_fixture.gd"

## Production RunScene fight; deterministic samples only. The same fixture,
## facings, root travel and warmed meshes validate with --validate-only.
const Settings = preload("res://scripts/settings_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const FRAME_SIZE := Vector2i(1920, 1080)
const PLAYER_POSITION: String = "4:4"
const ENEMY_POSITIONS: String = "4:2,6:4,4:6,2:4"
const EXPECTED_VIEWS: Array = ["front", "rear_mirrored", "rear", "front_mirrored"]
const OUTPUT_ENV: String = "LABYRINTH_GRB01_PROOF_OUTPUT"
const DEFAULT_OUTPUT: String = "/private/tmp/labyrinth_codex/grb-01/captures"
const SETTLE_FRAMES: int = 5
const SCENE_SETTLE_SECONDS: float = 0.5
const MID_MOVE_PHASE: float = 0.5
const FROZEN_CLOCK: float = 0.0
const STANDING_CLIP: String = "idle"
const ROOT_TRAVEL_EPSILON: float = 2.0 # Source-pixel snapping can move the centre.
var _proof_errors: Array[String]
var _validate_only: bool = false
var _output: String = DEFAULT_OUTPUT
var _scene: Control
var _board: Control
var _canvas: SubViewport
var _samples: Array[Dictionary]
var _standing_meshes: Dictionary = {}

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_validate_only = OS.get_cmdline_user_args().has("--validate-only")
	if not OS.get_environment(OUTPUT_ENV).is_empty(): _output = OS.get_environment(OUTPUT_ENV)
	call_deferred("_run_proof")

func _run_proof() -> void:
	if DisplayServer.get_name() == "headless" and not _validate_only:
		_check(false, "Capture requires the windowed visual_probe_runner")
		await _finish()
		return
	_options = {"seed": DEFAULT_SEED, "player_position": PLAYER_POSITION,
		"enemy_types": "burrow_grub,burrow_grub,burrow_grub,burrow_grub", "enemy_positions": ENEMY_POSITIONS}
	var progression: Dictionary = _build_progression()
	for prompt: String in Tutorial.prompt_ids(): progression = Tutorial.resolve_progression(progression, prompt)
	var run: Dictionary = _build_run_state("combat", progression)
	_check(not _failed and not run.is_empty(), "Real fight fixture builds")
	if run.is_empty():
		await _finish()
		return
	root.size = FRAME_SIZE
	root.content_scale_size = FRAME_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	ProgressionStore.set_storage_path("user://grb01_progression.json")
	ProgressionStore.set_run_storage_path("user://grb01_run.save")
	Settings.set_storage_path("user://grb01_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	_check(Settings.save_settings(settings), "Save isolated 100% UI settings")
	_canvas = SubViewport.new()
	_canvas.size = FRAME_SIZE
	_canvas.disable_3d = true
	_canvas.world_2d = World2D.new()
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_canvas)
	_scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_canvas.add_child(_scene)
	await _settle()
	_scene._settings = settings
	_scene._progression = progression
	_scene._load_run_state(run)
	_scene._close_dialogue()
	_scene._close_large_map()
	await _settle()
	# Let awaited UI entry tweens finish before freezing their owners; killing an
	# awaited tween strands RunScene's coroutine during probe teardown.
	await create_timer(SCENE_SETTLE_SECONDS).timeout
	_board = _scene.board_view
	_check(is_equal_approx(Typography.ui_scale(_scene), 1.0), "100% UI scale")
	_freeze(_scene)
	var state: Dictionary = run["combat_state"]
	await _sample(state, false)
	await _sample(state, true)
	if not _validate_only:
		DirAccess.make_dir_recursive_absolute(_output)
		var file := FileAccess.open(_output.path_join("proof.json"), FileAccess.WRITE)
		_check(file != null, "Write semantic proof manifest")
		if file != null:
			file.store_string(JSON.stringify({"size": [1920, 1080], "ui_scale": 1.0, "samples": _samples, "errors": _proof_errors}, "\t"))
			file.close()
	await _finish()

func _sample(state: Dictionary, moving: bool) -> void:
	var stage: String = "mid_move" if moving else "standing"
	var presentation: Dictionary = _scene._stage_chrome_presentation()
	presentation["ambient_time_seconds"] = FROZEN_CLOCK
	presentation["damage_preview_time_seconds"] = FROZEN_CLOCK
	presentation["maquette_explicit_clip"] = true
	var motions: Dictionary = {}
	var positions: Dictionary = {}
	var expected_positions: Dictionary = {}
	for enemy: Dictionary in state["enemies"]:
		var key: String = "enemy_%d" % int(enemy["id"])
		var direction: Vector2i = (state["player"]["pos"] as Vector2i) - (enemy["pos"] as Vector2i)
		direction = Vector2i(signi(direction.x), signi(direction.y))
		motions[key] = {"clip": "move" if moving else STANDING_CLIP, "phase": MID_MOVE_PHASE if moving else FROZEN_CLOCK, "direction": direction}
		if moving:
			var start: Vector2 = _board._tile_center(enemy["pos"])
			var finish: Vector2 = _board._tile_center(enemy["pos"] + direction)
			positions[key] = start.lerp(finish, MID_MOVE_PHASE)
			expected_positions[key] = positions[key]
	presentation["burrow_grub_motion"] = motions
	if moving:
		presentation["unit_world_positions"] = positions
		presentation["unit_footprint_world_positions"] = positions
	_scene._render_board_state(state, presentation, false)
	_board._idle_elapsed = FROZEN_CLOCK
	await _settle()
	var actors: Array[Dictionary]
	for unit: Dictionary in _board._visible_units():
		if str(unit.get("role", "")) == "enemy": actors.append(unit)
	actors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["id"]) < int(b["id"]))
	_check(actors.size() == EXPECTED_VIEWS.size(), stage + " shows four Grubs")
	var records: Array[Dictionary]
	for index: int in range(actors.size()):
		var unit: Dictionary = actors[index]
		var renderer: Node = _board.unit_cutout_renderer(unit)
		_check(is_instance_valid(renderer), stage + " has its production rig")
		if not is_instance_valid(renderer): continue
		renderer.set("_idle_seconds", FROZEN_CLOCK)
		renderer.call("_apply_pose")
		var facing: String = str(renderer.get("facing"))
		var mirrored: bool = bool(renderer.get("mirrored"))
		var view: String = facing + ("_mirrored" if mirrored else "")
		_check(index < EXPECTED_VIEWS.size() and view == EXPECTED_VIEWS[index], stage + " facing: " + view)
		var center: Vector2 = _board._unit_center(unit)
		if moving:
			_check(center.distance_to(expected_positions[unit["key"]]) < ROOT_TRAVEL_EPSILON, "Mid-move contact follows the root")
		var mesh: ArrayMesh = _board._unit_ground_contact.mesh_for("burrow_grub", facing, _board._unit_draw_rect_for_center(unit, center).size)
		_check(mesh != null, stage + " contact mesh exists")
		if moving:
			_check(is_same(mesh, _standing_meshes.get(unit["key"])), "Mid-move reuses the standing mesh")
		else:
			_standing_meshes[unit["key"]] = mesh
		var submitted: bool = false
		for layer: Control in _board._retained_render_layers():
			if layer._submitted_shadow_meshes.has(mesh): submitted = true
		_check(submitted, stage + " contact mesh was submitted by the production draw")
		_check(str(renderer.get("clip")) == ("move" if moving else STANDING_CLIP), stage + " samples the requested production clip")
		records.append({"key": unit["key"], "view": view, "clip": renderer.get("clip"), "phase": renderer.get("phase"), "root": [center.x, center.y]})
	_samples.append({"stage": stage, "actors": records})
	if not _validate_only:
		await _settle()
		await RenderingServer.frame_post_draw
		var frame: Image = _canvas.get_texture().get_image()
		_check(frame != null and frame.get_size() == FRAME_SIZE, "Native 1920x1080 capture")
		DirAccess.make_dir_recursive_absolute(_output)
		var path: String = _output.path_join(stage + ".png")
		_check(frame.save_png(path) == OK, "Save " + stage)
		print(path)

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame

func _freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children(): _freeze(child)

func _check(ok: bool, message: String) -> void:
	if not ok: _proof_errors.append(message)

func _finish() -> void:
	for message: String in _proof_errors: push_error(message)
	print("GRB01 REAL FIGHT %s: %s (standing + mid-move; front/rear and mirrors; 1920x1080; UI 100%%)" % ["HEADLESS CONTRACT" if _validate_only else "PROBE", "PASS" if _proof_errors.is_empty() else "FAIL"])
	if _canvas != null:
		_canvas.queue_free()
		await _settle()
	quit(0 if _proof_errors.is_empty() else 1)

extends SceneTree

const CombatBoardViewScript = preload("res://scripts/combat_board_view.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const OUTPUT_DIR: String = "user://terrain_destruction_probe"
const VIEWPORT_SIZE: Vector2i = Vector2i(1280, 720)
const PULSE_PROOF_SIZE := Vector2i(1920, 1080)
const PULSE_PROOF_FRAMES: int = 30
const PULSE_PROOF_STEP_SECONDS: float = 1.0 / 60.0
const PULSE_PROOF_DIRECTORY: String = "user://qa66-terrain-pulse"
const PULSE_STRIP_COLUMNS: int = 6
const PULSE_STRIP_CELL := Vector2i(320, 216)

class PulseBoard extends CombatBoardViewScript:
	var preview_draws: int = 0
	var preview_alphas: Array[float]
	var preview_rect: Rect2
	func _draw_health_damage_preview(unit: Dictionary, rect: Rect2, preview: Dictionary) -> void:
		if str(unit.get("id", "")) == "probe_crate":
			preview_draws += 1
			preview_alphas.append((health_damage_preview_colors(false, presentation)["fill"] as Color).a)
			preview_rect = rect
		super._draw_health_damage_preview(unit, rect, preview)

var _errors: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	if OS.get_cmdline_user_args().has("--qa66-pulse"):
		_pulse_proof.call_deferred()
		return
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	await process_frame

	var board: Control = CombatBoardViewScript.new()
	board.size = root.get_visible_rect().size
	root.add_child(board)
	board.set_process(false)
	await process_frame

	var box_frames: Array = board.call("_terrain_destruction_frames_for_kind", "wooden_box")
	var crate_frames: Array = board.call("_terrain_destruction_frames_for_kind", "wooden_crate")
	_expect(box_frames.size() == 16, "Wooden box destruction probe requires all 16 frames")
	_expect(crate_frames.size() == 16, "Wooden crate destruction probe requires all 16 frames")

	await _capture(board, 7, 0.48, "terrain_destruction_mid.png")
	await _capture(board, 14, 0.92, "terrain_destruction_late.png")
	board.queue_free()
	await process_frame

	if _errors.is_empty():
		print("TERRAIN DESTRUCTION PROBE RESULT: PASS")
		print(ProjectSettings.globalize_path(OUTPUT_DIR))
		quit(0)
	else:
		for error: String in _errors:
			push_error(error)
		print("TERRAIN DESTRUCTION PROBE RESULT: FAIL (%d errors)" % _errors.size())
		quit(1)

func _capture(board: Control, frame: int, progress: float, file_name: String) -> void:
	var presentation: Dictionary = {
		"focus_tiles": [Vector2i(3, 3), Vector2i(5, 3)],
		"focus_color": Color(0.98, 0.55, 0.25, 0.18),
		"effect_progress": progress,
		"impact_progress": progress,
		"terrain_destruction_units": [
			{
				"key": "terrain_probe_box",
				"id": "probe_box",
				"kind": "wooden_box",
				"pos": Vector2i(3, 3),
				"destruction_frame": frame,
				"destruction_progress": progress
			},
			{
				"key": "terrain_probe_crate",
				"id": "probe_crate",
				"kind": "wooden_crate",
				"pos": Vector2i(5, 3),
				"destruction_frame": frame,
				"destruction_progress": progress
			}
		]
	}
	board.call(
		"set_combat_state",
		_probe_state(),
		_vector2i_array([]),
		_vector2i_array([]),
		Vector2i(-1, -1),
		"",
		"",
		{},
		{},
		presentation
	)
	await process_frame
	await process_frame
	var image: Image = root.get_texture().get_image()
	var output_path: String = ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	_expect(image.get_size() == VIEWPORT_SIZE, "%s should capture at 1280x720" % file_name)
	_expect(image.save_png(output_path) == OK, "%s could not be saved" % file_name)

func _pulse_proof() -> void:
	var semantics: bool = OS.get_cmdline_user_args().has("--semantics-only")
	if DisplayServer.get_name() == "headless" and not semantics:
		push_error("Terrain pulse captures require the native renderer")
		quit(1)
		return
	var settings_store = preload("res://scripts/settings_store.gd")
	settings_store.set_storage_path("user://qa66_terrain_settings.json")
	var settings: Dictionary = settings_store.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	settings_store.save_settings(settings)
	root.size = PULSE_PROOF_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = PULSE_PROOF_SIZE
	root.content_scale_factor = 1.0
	var viewport := SubViewport.new()
	viewport.size = PULSE_PROOF_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := PulseBoard.new()
	board.size = PULSE_PROOF_SIZE
	viewport.add_child(board)
	var state: Dictionary = _probe_state()
	state["terrain"] = [{"id": "probe_crate", "kind": "wooden_crate", "pos": Vector2i(5, 3), "hp": 3, "max_hp": 3}]
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"reduced_motion": false, "damage_preview": {"terrain_probe_crate": {"hp": 2, "hp_loss": 1, "lethal": false}}})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PULSE_PROOF_DIRECTORY))
	var samples: Array[Dictionary]
	var images: Array[Image]
	for frame: int in range(PULSE_PROOF_FRAMES):
		await process_frame
		if semantics: await create_timer(PULSE_PROOF_STEP_SECONDS).timeout
		else: await RenderingServer.frame_post_draw
		var canvases: Array[Control]
		canvases.append(board._hud_render_layer)
		canvases.append_array(board._hud_render_layer._layer_slices.canvases)
		var draws: int = 0
		var alpha: float = 0.0
		var rect: Rect2
		for canvas: Control in canvases:
			draws += canvas.preview_draws
			if not canvas.preview_alphas.is_empty():
				alpha = canvas.preview_alphas.back()
				rect = canvas.preview_rect
		samples.append({"frame": frame, "draws": draws, "alpha": alpha, "bar_rect": str(rect)})
		if not semantics:
			var image: Image = viewport.get_texture().get_image()
			var path: String = PULSE_PROOF_DIRECTORY.path_join("crate_%02d.png" % frame)
			_expect(image.get_size() == PULSE_PROOF_SIZE and image.save_png(path) == OK, "Pulse frame saves")
			images.append(image)
			print("Saved " + ProjectSettings.globalize_path(path))
	_expect(int(samples.back().draws) > int(samples.front().draws), "Unchanged terrain preview keeps drawing across the 30 frames")
	_expect(samples.any(func(sample: Dictionary) -> bool: return not is_equal_approx(float(sample.alpha), float(samples.front().alpha))), "Actual retained damage-band colours pulse")
	if not images.is_empty():
		var bar := Rect2i(board._hud_render_layer._terrain_rect_for_tile(Vector2i(5, 3), board._terrain_textures["wooden_crate"], "wooden_crate"))
		# Include the authored bar above the crate in the exported contact strip.
		bar.position.y -= ceili(board.TERRAIN_HEALTH_BAR_TOP_OFFSET + board.TERRAIN_HEALTH_BAR_SIZE.y)
		bar.size.y += ceili(board.TERRAIN_HEALTH_BAR_TOP_OFFSET + board.TERRAIN_HEALTH_BAR_SIZE.y)
		bar = bar.intersection(Rect2i(Vector2i.ZERO, PULSE_PROOF_SIZE))
		var strip := Image.create(PULSE_PROOF_SIZE.x, PULSE_PROOF_SIZE.y, false, Image.FORMAT_RGBA8)
		strip.fill(Color.BLACK)
		for frame: int in range(images.size()):
			var crop: Image = images[frame].get_region(bar)
			var factor: float = minf(1.0, minf(float(PULSE_STRIP_CELL.x) / crop.get_width(), float(PULSE_STRIP_CELL.y) / crop.get_height()))
			crop.resize(maxi(1, roundi(crop.get_width() * factor)), maxi(1, roundi(crop.get_height() * factor)))
			var cell := Vector2i(frame % PULSE_STRIP_COLUMNS, frame / PULSE_STRIP_COLUMNS) * PULSE_STRIP_CELL
			strip.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), cell + (PULSE_STRIP_CELL - crop.get_size()) / 2)
		var strip_path: String = PULSE_PROOF_DIRECTORY.path_join("crate_contact_strip.png")
		_expect(strip.save_png(strip_path) == OK, "Crate contact strip saves")
		print("Contact strip " + ProjectSettings.globalize_path(strip_path))
	var file := FileAccess.open(PULSE_PROOF_DIRECTORY.path_join("pulse_samples.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(samples, "\t"))
	for error: String in _errors: push_error(error)
	print("QA66 TERRAIN PULSE: %d failures; %s" % [_errors.size(), ProjectSettings.globalize_path(PULSE_PROOF_DIRECTORY)])
	viewport.queue_free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)

func _probe_state() -> Dictionary:
	return {
		"name": "Incidental Blast Destruction",
		"room_coord": Vector2i(2, -1),
		"room_element": "fire",
		"grid": _probe_grid(),
		"moss": {},
		"player": {
			"pos": Vector2i(1, 5),
			"hp": 80,
			"max_hp": 100,
			"block": 0,
			"stoneskin": 0,
			"burn": 0,
			"bleed": 0
		},
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(7, 1),
			"hp": 140,
			"max_hp": 140,
			"block": 0,
			"stoneskin": 0,
			"intent": {"name": "Skitter", "actions": [{"type": "move_toward", "range": 2}]}
		}],
		"illusions": [],
		"npcs": [],
		"loot": [],
		"terrain": [
			{"id": "probe_box", "kind": "wooden_box", "pos": Vector2i(3, 3), "hp": 0, "max_hp": 30},
			{"id": "probe_crate", "kind": "wooden_crate", "pos": Vector2i(5, 3), "hp": 0, "max_hp": 30}
		],
		"traps": [],
		"player_turn_restrictions": {}
	}

func _probe_grid() -> Array:
	return [
		["wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall"],
		["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
		["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
		["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
		["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
		["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
		["wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall"]
	]

func _vector2i_array(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Variant in values:
		if typeof(value) == TYPE_VECTOR2I:
			result.append(value)
	return result

func _clear_probe_output(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)

extends SceneTree

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
const OUTPUT_DIR: String = "user://ambient_particle_batch_equivalence"
const ELEMENTS := ["fire", "ice", "lightning", "air", "earth"]
const SAMPLE_STRIDE: int = 4

var _errors: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var legacy: Dictionary = await _make_board(false)
	var batched: Dictionary = await _make_board(true)
	var results: Dictionary = {}
	for element_id: String in ELEMENTS:
		var state: Dictionary = _state(element_id)
		var presentation: Dictionary = {"ambient_time_seconds": 42.0, "scene_props": []}
		(legacy.get("board") as Control).call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
		(batched.get("board") as Control).call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
		for _frame: int in range(4):
			await process_frame
		var legacy_image: Image = (legacy.get("viewport") as SubViewport).get_texture().get_image()
		var batched_image: Image = (batched.get("viewport") as SubViewport).get_texture().get_image()
		_expect(legacy_image.get_size() == VIEWPORT_SIZE, "%s legacy capture must be 1920x1080" % element_id)
		_expect(batched_image.get_size() == VIEWPORT_SIZE, "%s batched capture must be 1920x1080" % element_id)
		var metrics: Dictionary = _difference_metrics(legacy_image, batched_image)
		results[element_id] = metrics
		_expect(float(metrics.get("mean_rgb_delta", 1.0)) <= 0.006, "%s ambient batching changed mean RGB by more than 0.006" % element_id)
		_expect(float(metrics.get("fraction_over_8_of_255", 1.0)) <= 0.025, "%s ambient batching changed too many sampled pixels materially" % element_id)
		_expect(legacy_image.save_png(ProjectSettings.globalize_path("%s/%s_legacy.png" % [OUTPUT_DIR, element_id])) == OK, "%s legacy image save failed" % element_id)
		_expect(batched_image.save_png(ProjectSettings.globalize_path("%s/%s_batched.png" % [OUTPUT_DIR, element_id])) == OK, "%s batched image save failed" % element_id)
	print("AMBIENT BATCH EQUIVALENCE RESULT: %s" % JSON.stringify({"metrics": results, "semantic_errors": _errors}))
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0 if _errors.is_empty() else 1)

func _make_board(batch_enabled: bool) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	root.add_child(viewport)
	var board: Control = CombatBoardView.new()
	board.size = Vector2(VIEWPORT_SIZE)
	viewport.add_child(board)
	await process_frame
	var ambient_layer: Control = board.get("_ambient_render_layer") as Control
	_expect(ambient_layer != null, "combat board must create its retained ambient layer")
	if ambient_layer != null:
		ambient_layer.set("_ambient_particle_batch_enabled", batch_enabled)
	return {"viewport": viewport, "board": board}

func _difference_metrics(reference: Image, candidate: Image) -> Dictionary:
	var sampled: int = 0
	var sum_delta: float = 0.0
	var max_delta: float = 0.0
	var over_2: int = 0
	var over_8: int = 0
	for y: int in range(0, mini(reference.get_height(), candidate.get_height()), SAMPLE_STRIDE):
		for x: int in range(0, mini(reference.get_width(), candidate.get_width()), SAMPLE_STRIDE):
			var a: Color = reference.get_pixel(x, y)
			var b: Color = candidate.get_pixel(x, y)
			var delta: float = (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0
			sampled += 1
			sum_delta += delta
			max_delta = maxf(max_delta, delta)
			if delta > 2.0 / 255.0:
				over_2 += 1
			if delta > 8.0 / 255.0:
				over_8 += 1
	return {
		"sample_stride": SAMPLE_STRIDE,
		"sample_count": sampled,
		"mean_rgb_delta": sum_delta / float(maxi(1, sampled)),
		"max_rgb_delta": max_delta,
		"fraction_over_2_of_255": float(over_2) / float(maxi(1, sampled)),
		"fraction_over_8_of_255": float(over_8) / float(maxi(1, sampled))
	}

func _state(element_id: String) -> Dictionary:
	var intensity: Dictionary = {"fire": 0, "ice": 0, "lightning": 0, "air": 0, "earth": 0}
	intensity[element_id] = 6
	return {
		"name": "Ambient %s proof" % element_id,
		"room_coord": Vector2i(13, 17),
		"room_element": element_id,
		"grid": _grid(),
		"moss": {},
		"elemental_intensity": intensity,
		"player": {},
		"enemies": [],
		"illusions": [],
		"npcs": [],
		"loot": [],
		"terrain": [],
		"traps": []
	}

func _grid() -> Array:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or y == 0 or x == 8 or y == 8 else "stone")
		grid.append(row)
	return grid

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)

extends SceneTree

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const ElementData = preload("res://scripts/element_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
const OUTPUT_DIR: String = "user://probes/elemental_ambient_transition_v1"

var _errors: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	root.add_child(viewport)
	var board: Control = CombatBoardView.new()
	board.size = Vector2(VIEWPORT_SIZE)
	viewport.add_child(board)
	await process_frame
	board.set_process(false)

	var presentation: Dictionary = {"ambient_time_seconds": 42.0, "scene_props": []}
	for element_id: String in ElementData.all_elements():
		var state: Dictionary = _state()
		state["room_element"] = element_id
		board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
		await _settle()
		_expect(board.call("_ambient_active_element_ids") == PackedStringArray([element_id]), "Atmosphere follows room affinity")
		await _capture(viewport, "%s_room.png" % element_id)
	var initial_state: Dictionary = _state()
	board.call("set_combat_state", initial_state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
	var before_count: int = int(board.call("_ambient_particle_count", ElementData.ICE, 64))
	initial_state["surfaces"] = {"2,2": {"elemental": "fire", "rubble": true}, "3,2": {"elemental": "electrified", "rubble": false}}
	board.call("set_combat_state", initial_state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
	await _settle()
	_expect(board.call("_ambient_active_element_ids") == PackedStringArray([ElementData.ICE]), "Off-room ground does not tint the whole arena")
	_expect(int(board.call("_ambient_particle_count", ElementData.ICE, 64)) == before_count, "Ground does not scale ambient density")
	await _capture(viewport, "ice_room_mixed_ground.png")
	_verify_particle_phase_continuity(board)
	_verify_element_hash_caches(board)
	print("ELEMENTAL AMBIENT TRANSITION RESULT: %s" % JSON.stringify({"semantic_errors": _errors}))
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0 if _errors.is_empty() else 1)

func _capture(viewport: SubViewport, filename: String) -> Image:
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	_expect(image.get_size() == VIEWPORT_SIZE, "%s must be exactly 1920x1080" % filename)
	_expect(image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, filename])) == OK, "%s should save successfully" % filename)
	return image

func _settle() -> void:
	for _frame: int in range(3):
		await process_frame

func _mean_rgb_delta(reference: Image, candidate: Image) -> float:
	var total: float = 0.0
	var samples: int = 0
	for y: int in range(0, VIEWPORT_SIZE.y, 4):
		for x: int in range(0, VIEWPORT_SIZE.x, 4):
			var before: Color = reference.get_pixel(x, y)
			var after: Color = candidate.get_pixel(x, y)
			total += (absf(before.r - after.r) + absf(before.g - after.g) + absf(before.b - after.b)) / 3.0
			samples += 1
	return total / float(maxi(1, samples))

func _verify_particle_phase_continuity(board: Control) -> void:
	const SOURCE_TIME: float = 7200.0
	const FRAME_DELTA: float = 1.0 / 30.0
	const SEED: int = 9271
	var initial_motion_time: float = float(board.call("_ambient_motion_time", ElementData.LIGHTNING, SOURCE_TIME))
	var initial_cycle: float = float(board.call("_ambient_cycle", SEED, initial_motion_time, 1.0))
	var changed_motion_time: float = float(board.call("_ambient_motion_time", ElementData.LIGHTNING, SOURCE_TIME))
	var changed_cycle: float = float(board.call("_ambient_cycle", SEED, changed_motion_time, 1.0))
	_expect(is_equal_approx(initial_cycle, changed_cycle), "Repeated sampling at one instant must not jump particle phase")
	var next_motion_time: float = float(board.call("_ambient_motion_time", ElementData.LIGHTNING, SOURCE_TIME + FRAME_DELTA))
	var next_cycle: float = float(board.call("_ambient_cycle", SEED, next_motion_time, 1.0))
	var wrapped_delta: float = absf(wrapf(next_cycle - changed_cycle + 0.5, 0.0, 1.0) - 0.5)
	_expect(wrapped_delta < 0.05, "A room particle phase must advance by a bounded amount per frame")

func _verify_element_hash_caches(board: Control) -> void:
	board.call("_prepare_ambient_hash_cache", ElementData.FIRE)
	board.call("_ambient_hash01", 111)
	board.call("_prepare_ambient_hash_cache", ElementData.ICE)
	board.call("_ambient_hash01", 222)
	board.call("_prepare_ambient_hash_cache", ElementData.FIRE)
	var caches: Dictionary = board.get("_ambient_hash01_caches_by_element") as Dictionary
	var fire_cache: Dictionary = caches.get(ElementData.FIRE, {}) as Dictionary
	var ice_cache: Dictionary = caches.get(ElementData.ICE, {}) as Dictionary
	_expect(fire_cache.has(111), "Switching elemental passes must retain the Fire particle hash cache")
	_expect(ice_cache.has(222), "Switching elemental passes must retain the Ice particle hash cache")

func _state() -> Dictionary:
	return {
		"name": "Mixed elemental atmosphere proof",
		"room_coord": Vector2i(8, 12),
		"room_element": ElementData.ICE,
		"grid": _grid(),
		"moss": {},
		"surfaces": {},
		"player": {},
		"enemies": [],
		"illusions": [],
		"npcs": [],
		"loot": [],
		"terrain": [],
		"traps": [],
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

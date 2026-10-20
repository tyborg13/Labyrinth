extends "res://tests/rr20/production_capture.gd"

const TEST_BOARD_X: float = 13.5
const TEST_ENTRANCE_Y: float = 70.0
const TEST_ROOM_ENDPOINT_Y: float = 180.0
const TEST_MOVED_TILE := Vector2i(5, 4)
const TEST_ESCAPED_TILE := Vector2i(12, 4)
const TEST_TEXTURE_TRAVEL := Vector2(-200, -120)
const TEST_DOWNWARD_TRAVEL := Vector2(0, 400)
const TEST_SETTLED_FIXTURE_CROP := Rect2i(269, 156, 545, 544)
const TEST_EXPECTED_CROP := Rect2i(269, 156, 1045, 744)
const TEST_SCENARIOS := ["front/start", "rear/copied_action"]
var _board: MovingBoard
var _canvases: Array[Rect2]
var _pass_count: int = 0
var _native_crops: Array[Rect2i]

class MovingScene extends Control:
	var board_view: Control
	var _board_centering_target := Vector2(TEST_BOARD_X, TEST_ENTRANCE_Y)

class MovingBoard extends Control:
	const ORIGIN := Vector2(400, 300)
	const TILE_STEP := Vector2(100, 50)
	const BODY_SIZE := Vector2(255, 255)
	const CANVAS_SIZE := Vector2(512, 512)
	const SOURCE_OFFSET := Vector2(128, 128)
	var texture_travel := Vector2.ZERO
	func world_position_for_unit_origin(_unit: Dictionary, tile: Vector2i) -> Vector2:
		return ORIGIN + Vector2(tile) * TILE_STEP
	func _unit_center(unit: Dictionary) -> Vector2:
		return world_position_for_unit_origin(unit, unit["pos"]) + texture_travel
	func _unit_hud_anchor_texture(_unit: Dictionary) -> Texture2D:
		return null
	func _unit_draw_rect_for_texture(_unit: Dictionary, center: Vector2, _texture: Texture2D) -> Rect2:
		return Rect2(center, BODY_SIZE)
	func _unit_texture_draw_rect(_unit: Dictionary, center: Vector2) -> Rect2:
		return Rect2(center - SOURCE_OFFSET, CANVAS_SIZE)

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_output = args[args.find("--output") + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	CaptureStorage.setup(_output)
	CaptureStorage.encoding = "webp"
	await _create_capture_scene()
	# Reproduce cap-01: the initial fixture estimate misses both entrance motion
	# and a later scenario's actual board movement/texture-origin travel.
	CaptureStorage.begin_production()
	_seed_fixture()
	CaptureStorage.finish_production(SIZE)
	var unit: Dictionary = fixture("")["enemies"][0]
	_board.position.y = 0.0
	var error: String = CaptureStorage.production_canvas_error(CaptureStorage.production_canvas(_board, unit), TEST_SCENARIOS[0], "idle", 1)
	_check(error.contains("escaped the fixed run crop"), "Initial plan reproduces entrance-motion escape")
	unit["pos"] = TEST_MOVED_TILE
	error = CaptureStorage.production_canvas_error(CaptureStorage.production_canvas(_board, unit), TEST_SCENARIOS[1], "move", 2)
	_check(error.contains("scenario=rear/copied_action clip=move frame=2"), "Initial plan reproduces board-movement escape with exact context")
	# Even unused fixture facings must follow the board transform. Move the
	# observed texture downward so only the conservative seed covers this top.
	_board.position.y = TEST_ENTRANCE_Y
	CaptureStorage.begin_production()
	_seed_fixture()
	_board.position.y = 0.0
	_board.texture_travel = TEST_DOWNWARD_TRAVEL
	CaptureStorage.record_production_canvas(_board, fixture("")["enemies"][0])
	CaptureStorage.finish_production(SIZE)
	_check(CaptureStorage.board_crop.encloses(TEST_SETTLED_FIXTURE_CROP), "Conservative fixture envelope follows board motion")
	# A fresh scene can reach its first sampled frame earlier in the tween.
	# Use the real source endpoint to cover that interval without a new margin.
	CaptureStorage.begin_production()
	CaptureStorage.include_production_board_position(_board, Vector2(TEST_BOARD_X, TEST_ROOM_ENDPOINT_Y))
	_seed_fixture()
	CaptureStorage.record_production_canvas(_board, fixture("")["enemies"][0])
	CaptureStorage.finish_production(SIZE)
	_board.texture_travel = Vector2.ZERO
	_board.position.y = TEST_ROOM_ENDPOINT_Y
	_check(CaptureStorage.production_canvas_error(CaptureStorage.production_canvas(_board, fixture("")["enemies"][0]), "earlier_replay", "idle", 0).is_empty(), "Earlier replay is covered by the room-centering endpoint")
	_board.position.y = TEST_ENTRANCE_Y
	_board.texture_travel = Vector2.ZERO
	# Exercise the same two-pass orchestration used by every production writer.
	await _prepare_production_crop()
	_check(CaptureStorage.board_crop == TEST_EXPECTED_CROP, "Whole-run union, outward rounding and 16 px margin")
	_check(CaptureStorage.entries.is_empty(), "Planning writes no frames")
	_check(_frames.is_empty(), "Planning rows do not leak into the capture")
	_check(_scene.get_meta("fresh_capture"), "The real capture gets a fresh scene")
	if args.has("--escape-after-plan"):
		unit["pos"] = TEST_ESCAPED_TILE
		if not CaptureStorage.check_production_canvas(_board, unit, TEST_SCENARIOS[1], "mirror", 99):
			print("PRODUCTION CROP ESCAPE: REJECTED (scenario=rear/copied_action clip=mirror frame=99)")
			quit(1)
			return
		_failures.append("Escaping native frame was accepted")
	await _run_clips()
	_check(_pass_count == 2, "Exactly one planning pass precedes one capture pass")
	_check(_native_crops.size() == 4, "Both scenarios and every clip/frame are written")
	for crop: Rect2i in _native_crops:
		_check(crop == TEST_EXPECTED_CROP, "One fixed crop for every frame")
	CaptureStorage.finish()
	# A new run must not inherit the old run's bounds or crop.
	CaptureStorage.setup(_output)
	_check(not CaptureStorage.production_bounds.has_area() and not CaptureStorage.board_crop.has_area(), "Run bounds reset")
	_check(CaptureStorage.production_canvas_error(Rect2(1, 1, 1, 1), "new_run", "idle", 0).contains("Missing production crop plan: scenario=new_run clip=idle frame=0"), "Missing plan fails with context")
	for failure: String in _failures: push_error(failure)
	print("PRODUCTION CROP PLAN: %s (%d failures; 4 frames; 2 scenarios)" % ["PASS" if _failures.is_empty() else "FAIL", _failures.size()])
	_scene.free()
	quit(0 if _failures.is_empty() else 1)

func _create_capture_scene() -> void:
	_scene = MovingScene.new()
	_scene.set_meta("fresh_capture", _pass_count == 1)
	root.add_child(_scene)
	_board = MovingBoard.new()
	_board.position = Vector2(TEST_BOARD_X, TEST_ENTRANCE_Y)
	_scene.add_child(_board)
	_scene.board_view = _board

func fixture(_intent: String) -> Dictionary:
	return {"enemies": [{"type": "capture_fixture", "pos": Vector2i.ZERO, "intent": {"actions": []}}]}

func _seed_fixture() -> void:
	CaptureStorage.plan_production(_board, "capture_fixture", {"clips": {"move": {"intents": ["move"]}}}, fixture, Vector2i.ZERO)

func _run_clips() -> void:
	_pass_count += 1
	var unit: Dictionary = fixture("")["enemies"][0]
	if CaptureStorage.production_planning: _seed_fixture()
	for frame: int in range(4):
		var scenario: String = TEST_SCENARIOS[0] if frame < 2 else TEST_SCENARIOS[1]
		var clip: String = "idle" if frame < 2 else "move" if frame == 2 else "mirror"
		if frame == 1: _board.position.y = 0.0
		if frame == 2: unit["pos"] = TEST_MOVED_TILE
		if frame == 3: _board.texture_travel = TEST_TEXTURE_TRAVEL
		var bounds: Rect2 = CaptureStorage.production_canvas(_board, unit)
		if CaptureStorage.production_planning:
			CaptureStorage.record_production_canvas(_board, unit)
			_canvases.append(bounds)
		else:
			_check(CaptureStorage.check_production_canvas(_board, unit, scenario, clip, frame), "Frame canvas covered")
			_check(bounds == _canvases[frame], "Planning and capture replay the same screen geometry")
			var image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
			image.fill(Color.TRANSPARENT)
			image.fill_rect(Rect2i(bounds), Color.WHITE)
			var path: String = _output.path_join("frame_%d.png" % frame)
			CaptureStorage.save(image, path, clip)
			var record: Dictionary = CaptureStorage.entries[path.get_file()]
			var values: Array = record["crop"]
			_native_crops.append(Rect2i(values[0], values[1], values[2], values[3]))
			var decoded: Image = CaptureStorage.load_image(_output.path_join(record["stored_file"]), "webp")
			decoded.convert(Image.FORMAT_RGBA8)
			_check(decoded.get_data() == image.get_region(TEST_EXPECTED_CROP).get_data(), "Exact lossless pixels in the fixed crop")
		_frames.append({"stage": clip})

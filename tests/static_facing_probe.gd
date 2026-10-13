extends SceneTree

## Production board and turn clock, fixed real-renderer SubViewport. Headless
## --validate-only emits semantics without captures or a visual-proof claim.
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Fixture = preload("res://tests/static_facing_test.gd")
const Facing = preload("res://scripts/enemy_cutout_facing.gd")
const Data = preload("res://scripts/game_data.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Clock = preload("res://tests/suites/turn_clock_hud_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const SIZE := Vector2i(1920, 1080)
const OUTPUT: String = "user://probes/static_facing"
# Non-player-facing proof defaults.
const PROOF_SETTLE_FRAMES: int = 8
const PROOF_MOVE_PHASE: float = 0.5
const PROOF_CLOCK_TYPES: Array[String] = ["arc_thrall", "slag_mortar", "hoarfrost_seer"]
const PROOF_SELECTED_CLOCK_SLOT: int = 0
const PROOF_CLOCK_SEED: int = 73101
const PROOF_HAND_SIZE: int = 5
const PROOF_PLAYER_HP: int = 24
const PROOF_TURN_TIME: int = 1
const PROOF_TURN_STEP: int = 2
const PROOF_FACINGS: Array[String] = ["front", "front_mirrored", "rear", "rear_mirrored"]
var _canvas: SubViewport
var _board: Control
var _failures: Array[String]
var _captures: Array[Dictionary]
var _validate_only: bool = false
var _enemy_id: String = ""

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_validate_only = OS.get_cmdline_user_args().has("--validate-only")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--enemy-id"):
		var index: int = args.find("--enemy-id") + 1
		if index >= args.size() or str(Data.enemy_def(args[index]).get("art_rear_path", "")).is_empty():
			push_error("--enemy-id requires an enemy with approved front/rear art")
			quit(1)
			return
		_enemy_id = args[index]
	root.size = SIZE
	root.content_scale_size = SIZE
	Settings.set_storage_path("user://static_facing_settings.json")
	Progression.set_storage_path("user://static_facing_profile.json")
	Progression.set_run_storage_path("user://static_facing_run.save")
	Progression.clear_saved_run()
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	_expect(Settings.save_settings(settings), "100% UI scale")
	_run.call_deferred()

func _run() -> void:
	_canvas = SubViewport.new()
	_canvas.name = "StaticFacing1920x1080"
	_canvas.size = SIZE
	_canvas.disable_3d = true
	_canvas.world_2d = World2D.new()
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_canvas)
	_expect(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT)) == OK, "Capture directory")
	var types: Array[String]
	types.assign(["arc_thrall", "slag_mortar"])
	if not _enemy_id.is_empty(): types.assign([_enemy_id])
	for type: String in types:
		await _new_board()
		for index: int in range(Fixture.DIRECTIONS.size()):
			var state: Dictionary = Fixture.fixture(type)
			state["player"]["pos"] = Fixture.FIXTURE_ENEMY_TILE + Fixture.DIRECTIONS[index]
			_board.set_combat_state(state)
			await _settle()
			var semantics: Dictionary = _facing_semantics(type)
			_expect(semantics["facing"] == Facing.direction_for_delta(Fixture.DIRECTIONS[index]), "Idle facing " + PROOF_FACINGS[index])
			await _capture(type + "_" + PROOF_FACINGS[index], semantics)
	if _enemy_id.is_empty():
		await _new_board()
		var state: Dictionary = Fixture.fixture("arc_thrall")
		_board.set_combat_state(state)
		await _settle()
		var from: Vector2 = _board._tile_center(Fixture.FIXTURE_ENEMY_TILE)
		var to: Vector2 = _board._tile_center(Fixture.FIXTURE_ENEMY_TILE + Vector2i(-1, 0))
		var frame: Dictionary = {"unit_world_positions": {"enemy_1": from.lerp(to, PROOF_MOVE_PHASE)},
			"unit_draw_tiles": {"enemy_1": Fixture.FIXTURE_ENEMY_TILE + Vector2i(-1, 0)}}
		_board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, frame)
		await _settle()
		var semantics: Dictionary = _facing_semantics("arc_thrall")
		semantics["move_phase"] = PROOF_MOVE_PHASE
		_expect(semantics["facing"] == Facing.direction_for_delta(Vector2i(-1, 0)), "Mid-move faces away from hero along movement")
		await _capture("arc_thrall_mid_move", semantics)
		state = Fixture.fixture("slag_mortar")
		state["player"]["pos"] = Fixture.FIXTURE_ENEMY_TILE + Vector2i(-2, 0)
		_board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"reduced_motion": true})
		await _settle()
		semantics = _facing_semantics("slag_mortar")
		_expect(semantics["facing"] == Facing.direction_for_delta(Vector2i(-2, 0)), "Reduced motion follows the same idle policy")
		await _capture("slag_mortar_reduced_motion", semantics)
	_board.queue_free()
	await process_frame
	await _clock_capture()
	var manifest := {"size": [1920, 1080], "ui_scale": 1.0, "validate_only": _validate_only,
		"captures": _captures, "failures": _failures, "shadow_policy": "front/rear cached silhouette; mirrored about logical rect centre"}
	var file := FileAccess.open(OUTPUT.path_join("semantic-proof.json"), FileAccess.WRITE)
	_expect(file != null, "Semantic manifest")
	if file != null: file.store_string(JSON.stringify(manifest, "\t")); file.close()
	for failure: String in _failures: push_error(failure)
	print("STATIC FACING HEADLESS VALIDATION: %s" % ("PASS" if _failures.is_empty() else "FAIL") if _validate_only else "STATIC FACING PROBE RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	print(ProjectSettings.globalize_path(OUTPUT))
	_canvas.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)

func _new_board() -> void:
	if is_instance_valid(_board):
		_board.queue_free()
		await process_frame
	_board = Board.new()
	_board.size = Vector2(SIZE)
	_canvas.add_child(_board)
	await _settle()

func _settle() -> void:
	for frame: int in range(PROOF_SETTLE_FRAMES): await process_frame

func _facing_semantics(type: String) -> Dictionary:
	var unit: Dictionary = _board.combat_state["enemies"][0].duplicate()
	unit["key"] = "enemy_1"
	unit["role"] = "enemy"
	var facing: Dictionary = _board.presentation["static_enemy_facings"]["enemy_1"]
	var texture: Texture2D = _board._texture_for_unit(unit)
	var rect: Rect2 = _board._unit_draw_rect(unit)
	var source_path: String = str(Data.enemy_def(type)["art_rear_path" if facing["facing"] == "rear" else "art_path"])
	var source: Image = Image.load_from_file(source_path)
	if facing["mirrored"]: source.flip_x()
	_expect(texture.get_image().get_data() == source.get_data(), "Capture uses exact approved density-treated facing pixels")
	return {"type": type, "facing": facing, "source_path": source_path, "art_scale": _board._unit_art_scale(unit),
		"logical_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"reduced_motion": bool(_board.presentation.get("reduced_motion", false)), "ui_scale": 1.0}

func _clock_capture() -> void:
	var scene: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_canvas.add_child(scene)
	await _settle()
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	scene.set("_settings", settings)
	var room: Dictionary = Clock.room_layout()
	var clock_types: Array[String]
	clock_types.assign(PROOF_CLOCK_TYPES)
	if not _enemy_id.is_empty(): clock_types[PROOF_SELECTED_CLOCK_SLOT] = _enemy_id
	var enemies: Array[Dictionary]
	for index: int in range(clock_types.size()):
		var type: String = clock_types[index]
		var enemy: Dictionary = room["enemies"][index].duplicate(true)
		enemy["type"] = type
		enemy["hp"] = Data.enemy_def(type)["max_hp"]
		enemy["max_hp"] = enemy["hp"]
		enemies.append(enemy)
	room["enemies"] = enemies
	var state: Dictionary = Combat.new().create_combat(PROOF_CLOCK_SEED, room, {"hp": PROOF_PLAYER_HP, "max_hp": PROOF_PLAYER_HP,
		"deck_cards": Clock.HAND.duplicate(), "relics": [], "hand_size": PROOF_HAND_SIZE, "heal_bonus": 0})
	state.erase("umbra")
	# Stable early slots ensure all three portraits are actually visible at once.
	for index: int in range((state["turn_queue"] as Array).size()):
		state["turn_queue"][index]["time"] = PROOF_TURN_TIME + index * PROOF_TURN_STEP
	await Clock._install(self, scene, state)
	await _settle()
	var visible_portraits: Array[Dictionary]
	var rail: Control = scene.get("_turn_order_bar")
	for index: int in range(clock_types.size()):
		var type: String = clock_types[index]
		var key: String = "enemy:enemy_%d" % (index + 1)
		var found: bool = false
		for child: Node in rail.get_children():
			if str(child.get_meta("turn_order_actor_key", "")) != key or not (child as Control).is_visible_in_tree(): continue
			var texture: Texture2D = child.get_meta("turn_order_portrait_texture", null)
			var path: String = str(scene.TURN_ORDER_PORTRAITS[type])
			_expect(texture != null and texture.get_size() == Vector2(128, 128), "Visible 128x128 turn clock portrait " + type)
			_expect(texture != null and texture.get_image().get_data() == Image.load_from_file(path).get_data(), "Clock uses new production portrait " + type)
			var rect: Rect2 = (child as Control).get_global_rect()
			_expect(Rect2(Vector2.ZERO, Vector2(SIZE)).encloses(rect), "Portrait slot is inside the capture")
			visible_portraits.append({"type": type, "path": path, "slot_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})
			found = true
			break
		_expect(found, "Turn clock shows " + type)
	_expect(visible_portraits.size() == 3, "All three new portraits visible")
	await _capture("turn_clock_three_portraits", {"portraits": visible_portraits, "ui_scale": 1.0})
	scene.queue_free()
	await process_frame

func _capture(name: String, semantics: Dictionary) -> void:
	var path: String = OUTPUT.path_join(name + ".png")
	if not _validate_only:
		await RenderingServer.frame_post_draw
		var image: Image = _canvas.get_texture().get_image()
		_expect(image.get_size() == SIZE, "1920x1080 SubViewport capture")
		_expect(image.save_png(ProjectSettings.globalize_path(path)) == OK, "Save " + name)
		print("STATIC FACING CAPTURE: " + ProjectSettings.globalize_path(path))
	_captures.append({"path": path, "semantics": semantics, "captured": not _validate_only})

func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)

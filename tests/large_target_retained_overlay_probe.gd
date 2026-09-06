extends SceneTree

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const OUTPUT_DIR: String = "user://probes/large_target_retained_overlay"
const VIEWPORT_SIZE := Vector2i(1920, 1080)

var _errors: Array[String]
var _viewport: SubViewport
var _board: Control
var _overlay: Control
var _overlay_draw_count: int = 0
var _metrics: Dictionary = {}

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT_SIZE
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_board = CombatBoardView.new()
	_board.size = Vector2(VIEWPORT_SIZE)
	_viewport.add_child(_board)
	await process_frame
	_board.set_process(false)
	_board.set("_idle_elapsed", 0.0)
	var state: Dictionary = _fixture()
	var base := {"ambient_time_seconds": 42.0, "umbra_time_seconds": 42.0, "reduced_motion": true, "visible_enemy_ids": [3]}
	var fixed_target: Array = [Vector2i(4, 3)]
	_submit(state, base, fixed_target)
	await _settle()
	_overlay = _board.get("_overlay_render_layer") as Control
	_overlay.draw.connect(func() -> void: _overlay_draw_count += 1)
	await _verify("01_selected_large_enemy", 4, -1)

	# Keep attack_tiles exactly unchanged: both footprints contain the same
	# selected cell, but the other three highlighted cells must follow the actor.
	var moved: Dictionary = state.duplicate(true)
	moved["enemies"][0]["pos"] = Vector2i(4, 3)
	await _case("02_state_move", moved, base, fixed_target, 4)
	await _case("03_state_move_back", state, base, fixed_target, 4)
	var hidden: Dictionary = base.duplicate(true)
	hidden["visible_enemy_ids"] = []
	await _case("04_hide", state, hidden, fixed_target, 0)
	await _case("05_reveal", state, base, fixed_target, 4)
	var geometry: Dictionary = base.duplicate(true)
	geometry["unit_draw_tiles"] = {"enemy_3": Vector2i(4, 4)}
	geometry["unit_world_positions"] = {"enemy_3": _board.call("_tile_center", Vector2i(4, 4))}
	await _case("06_presentation_geometry", state, geometry, fixed_target, 4)
	await _case("07_clear_presentation_geometry", state, base, fixed_target, 4)
	var empty: Dictionary = state.duplicate(true)
	empty["enemies"] = []
	await _case("08_remove_enemy", empty, base, fixed_target, 0)
	await _case("09_restore_enemy", state, base, fixed_target, 4)

	# Ordinary unselected actor motion keeps the retained ground overlay idle.
	_submit(state, base, [])
	await _settle()
	var prior_draws: int = _overlay_draw_count
	_submit(moved, base, [])
	await _settle()
	await _verify("10_unselected_motion_control", 0, _overlay_draw_count - prior_draws, false)
	var file := FileAccess.open(ProjectSettings.globalize_path(OUTPUT_DIR.path_join("retained-proof.json")), FileAccess.WRITE)
	file.store_string(JSON.stringify(_metrics, "\t"))
	file.close()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	if _errors.is_empty():
		print("LARGE TARGET RETAINED OVERLAY PROBE: PASS")
		quit(0)
	else:
		for error: String in _errors:
			push_error(error)
		print("LARGE TARGET RETAINED OVERLAY PROBE: FAIL")
		quit(1)

func _case(label: String, state: Dictionary, presentation: Dictionary, targets: Array, expected_tiles: int) -> void:
	var prior_draws: int = _overlay_draw_count
	_submit(state, presentation, targets)
	await _settle()
	await _verify(label, expected_tiles, _overlay_draw_count - prior_draws)

func _verify(label: String, expected_tiles: int, routed_redraws: int, should_redraw: bool = true) -> void:
	var footprint: Array = _board.call("_large_enemy_attack_highlight_tiles", _board.call("_visible_units"))
	_expect(footprint.size() == expected_tiles, label + " must expose only the current visible footprint")
	if routed_redraws >= 0:
		_expect(routed_redraws > 0 if should_redraw else routed_redraws == 0, label + " must route the appropriate retained overlay redraw")
	var retained: Image = _viewport.get_texture().get_image()
	_expect(retained.get_size() == VIEWPORT_SIZE, label + " must use a direct 1920x1080 render")
	# Force ONLY the ground overlay to redraw. Every actor/scenery submission is
	# held constant, so a stale footprint appears as an exact native pixel delta.
	_overlay.queue_redraw()
	await _settle()
	var forced: Image = _viewport.get_texture().get_image()
	var identical: bool = retained.get_data() == forced.get_data()
	_expect(identical, label + " retained native pixels must equal an explicit fresh overlay redraw")
	_expect(retained.save_png(ProjectSettings.globalize_path(OUTPUT_DIR.path_join(label + ".png"))) == OK, label + " must save its retained frame")
	_metrics[label] = {"footprint": footprint, "routed_overlay_redraws": routed_redraws, "native_pixels_identical_to_forced_redraw": identical}
	print("RETAINED_OVERLAY_PROOF %s %s" % [label, JSON.stringify(_metrics[label])])

func _submit(state: Dictionary, presentation: Dictionary, targets: Array) -> void:
	_board.call("set_combat_state", state, [], targets, Vector2i(-1, -1), "", "", {}, {}, presentation)

func _settle() -> void:
	await process_frame
	await process_frame

func _fixture() -> Dictionary:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or y == 0 or x == 8 or y == 8 else "stone")
		grid.append(row)
	return {
		"room_coord": Vector2i(3, 2), "room_element": "none", "grid": grid, "moss": {},
		"player": {"pos": Vector2i(2, 5), "hp": 24, "max_hp": 24},
		"enemies": [{"id": 3, "type": "tharokh", "pos": Vector2i(3, 3), "hp": 64, "max_hp": 64, "footprint": Vector2i(2, 2)}],
		"illusions": [], "npcs": [], "traps": [], "terrain": [], "loot": [], "umbra": {"stage": "clear"}
	}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)

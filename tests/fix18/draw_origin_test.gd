extends "res://tests/fix18/real_fight_capture_probe.gd"

## The fix-18 fork of pt14-03 owns fixture/save/menu/Continue.
## This test only observes the renderer path, then exercises normal geometry
## invalidation with a viewport resize and a state-only (no motion) move.
const TEST_RESIZE := Vector2i(1600, 900)
const TEST_SETTLE_FRAMES: int = 8
const TEST_FIT_RECT := Rect2(200, 150, 1300, 600)
var _origin_checks: int = 0

func _capture_finish() -> void:
	_check(valid_frame_size(Vector2i(1600, 900), Vector2i(1600, 900)), "Frame policy accepts the director's window clamp")
	_check(valid_frame_size(FRAME_SIZE, FRAME_SIZE), "Frame policy accepts the requested window size")
	_check(not valid_frame_size(Vector2i(1599, 900), Vector2i(1599, 900)), "Frame policy rejects a smaller logical window")
	_check(not valid_frame_size(Vector2i(1600, 899), Vector2i(1600, 899)), "Frame policy rejects a shorter logical window")
	_check(not valid_frame_size(FRAME_SIZE, Vector2i(1600, 900)), "Frame policy rejects saved/logical size mismatch")
	if is_instance_valid(_capture_board) and _capture_errors.is_empty():
		_check_draw_origins("continue")
		root.size = TEST_RESIZE
		await _settle_origin_test()
		_check_draw_origins("resize")
		root.size = FRAME_SIZE
		await _settle_origin_test()
		_check_draw_origins("restore")
		# Stop the scene from replacing this deliberately state-only submission.
		_capture_scene.set_process(false)
		var layers: Dictionary = (_capture_board.get("_scene_render_layers_by_tile") as Dictionary).duplicate()
		var state: Dictionary = (_capture_board.get("combat_state") as Dictionary).duplicate(true)
		var enemies: Array = state["enemies"]
		# Rotate existing legal occupied tiles: no fixture tuning or new terrain.
		var first: Vector2i = enemies[0]["pos"]
		for index: int in range(enemies.size()):
			enemies[index]["pos"] = enemies[index + 1]["pos"] if index + 1 < enemies.size() else first
		var submitted: Dictionary = (_capture_board.get("presentation") as Dictionary).duplicate(true)
		_capture_board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, submitted)
		await _settle_origin_test()
		_check_draw_origins("no_animation_move")
		_check(not submitted.has("unit_world_positions") or submitted["unit_world_positions"].is_empty(), "Board must not bake tile origins into caller presentation")
		_check(_capture_board.get("_scene_render_layers_by_tile") == layers, "No-animation move retains the tile layers")
		var reframed: Dictionary = submitted.duplicate(true)
		reframed["board_fit_rect"] = TEST_FIT_RECT
		_capture_board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, reframed)
		await _settle_origin_test()
		_check_draw_origins("layout")
		_check(_capture_board.get("_scene_render_layers_by_tile") == layers, "Layout change retains the tile layers")
		preload("res://tests/fix18/travel_guard.gd").run(_capture_board, state, reframed, Callable(self, "_check"))
	print("FIX18 DRAW ORIGIN: %s (%d actor checks; %d failures)" % ["PASS" if _capture_errors.is_empty() else "FAIL", _origin_checks, _capture_errors.size()])
	await super._capture_finish()

func _settle_origin_test() -> void:
	for frame: int in range(TEST_SETTLE_FRAMES): await process_frame

func _check_draw_origins(stage: String) -> void:
	var observed: Array[String]
	for unit: Dictionary in _capture_board.call("_visible_units"):
		if unit["key"] != "player" and not CaptureActorPresentation.has_profile(str(unit["type"])): continue
		var actor: Dictionary = _rendered_actor_record(unit)
		observed.append(str(unit["type"]))
		_origin_checks += 1
		_check(bool(actor["uses_cached_draw_unit"]), stage + ": retained draw unit " + str(unit["key"]))
		var layer: Node = root.get_node(NodePath(actor["draw_layer"]))
		var submitted: bool = false
		for candidate: Dictionary in (layer.get("_units_by_draw_tile_cache") as Dictionary).get(_capture_board._effective_unit_tile(unit), []):
			if candidate.get("key") == unit["key"] and candidate.get("pos") == unit["pos"]: submitted = true
		_check(submitted, stage + ": actor exists in renderer's retained tile submission: " + str(unit["key"]))
		_check(bool(actor["floor_center_in_rest_rect"]), "FIX18 FLOOR CONTAINMENT " + stage + ": " + str(unit["type"]) + " " + JSON.stringify(actor))
		print("FIX18 ACTOR ", stage, " ", JSON.stringify(actor))
	for identity: String in _string_list(str(_options.get("enemy_types", ""))):
		if _capture_label == "four-rigs":
			_check(observed.has(identity), stage + ": requested rig is visible: " + identity)

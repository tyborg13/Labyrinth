extends SceneTree

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

var _errors: Array[String] = []
var _click_count: int = 0
var _tile_drag_count: int = 0
var _tile_drag_release_count: int = 0

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_size(Vector2i(960, 680))
	root.size = Vector2i(960, 680)
	var board: Control = CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	root.add_child(board)
	board.tile_clicked.connect(_on_tile_clicked)
	board.tile_dragged.connect(_on_tile_dragged)
	board.tile_drag_released.connect(_on_tile_drag_released)
	await process_frame

	var state: Dictionary = _board_state(Vector2i(2, 3))
	board.set_combat_state(state)
	await process_frame
	_test_navigation_reuses_content_cache(board)
	_test_hud_hover_layout_key_tracks_actor_not_empty_tile(board)
	_test_tile_depth_preserves_top_face_hit_testing(board)
	_test_backdrop_visibility_invalidates_static_layout(board, state)
	_test_bounded_zoom_and_hit_testing(board)
	_test_pickup_zoom_geometry_matches_actor(board)
	_test_wheel_zoom(board)
	_test_click_without_drag(board)
	_test_left_drag_pans_without_clicking(board)
	_test_aim_drag_keeps_combat_semantics(board, state)
	_test_new_room_recenters_without_resetting_zoom(board)

	board.queue_free()
	await process_frame
	if _errors.is_empty():
		print("COMBAT BOARD NAVIGATION TEST: PASS")
		quit(0)
	else:
		for error: String in _errors:
			push_error(error)
		print("COMBAT BOARD NAVIGATION TEST: FAIL (%d errors)" % _errors.size())
		quit(1)

func _test_navigation_reuses_content_cache(board: Control) -> void:
	board.call("navigation_snapshot")
	var before_count: int = int((board.call("render_instrumentation_snapshot") as Dictionary).get("layout_content_rebuild_count", -1))
	board.call("set_navigation_zoom", 1.20, board.size * 0.5)
	board.call("set_navigation_pan", Vector2(28.0, -18.0))
	board.call("world_position_for_tile", Vector2i(4, 3))
	var after_count: int = int((board.call("render_instrumentation_snapshot") as Dictionary).get("layout_content_rebuild_count", -1))
	_expect(after_count == before_count, "Pan and zoom should reuse cached tile order/extents instead of rebuilding room content each frame")
	board.call("reset_navigation")

func _test_hud_hover_layout_key_tracks_actor_not_empty_tile(board: Control) -> void:
	var hud_units: Array[Dictionary] = []
	for unit_var: Variant in board.call("_hud_layout_units") as Array:
		if typeof(unit_var) == TYPE_DICTIONARY:
			hud_units.append(unit_var as Dictionary)
	board.set("_hover_tile", Vector2i(2, 2))
	var first_empty_key: String = str(board.call("_hud_hover_actor_key", hud_units))
	board.call("_rebuild_hud_health_rects_cache")
	board.set("_hover_tile", Vector2i(4, 4))
	var second_empty_key: String = str(board.call("_hud_hover_actor_key", hud_units))
	var empty_layout_rebuilt: bool = bool(board.call("_rebuild_hud_health_rects_cache"))
	_expect(first_empty_key.is_empty() and second_empty_key.is_empty(), "Distinct empty hover tiles should share the same HUD layout key")
	_expect(not empty_layout_rebuilt, "Moving between empty Blink destinations should reuse the existing enemy HUD layout")

	board.set("_hover_tile", Vector2i(5, 3))
	var enemy_key: String = str(board.call("_hud_hover_actor_key", hud_units))
	var enemy_layout_rebuilt: bool = bool(board.call("_rebuild_hud_health_rects_cache"))
	_expect(not enemy_key.is_empty(), "Hovering an enemy footprint should identify the enemy whose intent expands")
	_expect(enemy_layout_rebuilt, "Entering an enemy footprint should still rebuild the expanded enemy-intent layout")

func _test_tile_depth_preserves_top_face_hit_testing(board: Control) -> void:
	var tile := Vector2i(4, 3)
	var top_face: PackedVector2Array = board.call("_tile_polygon", tile)
	var depth_faces: Array = board.call("_tile_depth_faces", tile)
	_expect(depth_faces.size() == 2, "Every rendered tile should expose two isometric depth faces")
	if top_face.size() < 4 or depth_faces.size() != 2:
		return
	var top_bottom_y: float = top_face[2].y
	for face_var: Variant in depth_faces:
		var face: PackedVector2Array = face_var as PackedVector2Array
		_expect(face.size() == 4, "Each tile depth face should remain a stable quadrilateral")
		if face.size() == 4:
			_expect(maxf(face[2].y, face[3].y) > top_bottom_y + 1.0, "Tile depth should extend visibly below the top diamond")
	var center: Vector2 = board.call("world_position_for_tile", tile)
	_expect(board.call("_tile_at_point", center) == tile, "Adding visual tile depth must not change top-face hit testing")

func _test_backdrop_visibility_invalidates_static_layout(board: Control, state: Dictionary) -> void:
	var room_grid_signature: String = str(board.call("_room_grid_signature", state))
	var opaque_signature: String = str(board.call(
		"_layout_signature_for_state",
		state,
		{},
		{"board_backdrop_visible": false},
		room_grid_signature
	))
	var transparent_signature: String = str(board.call(
		"_layout_signature_for_state",
		state,
		{},
		{"board_backdrop_visible": true},
		room_grid_signature
	))
	_expect(
		opaque_signature != transparent_signature,
		"Changing board-backdrop visibility should invalidate the cached static board layer"
	)
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"board_backdrop_visible": false})
	var before_signature: String = str(board.get("_board_layout_signature"))
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"board_backdrop_visible": true})
	var after_signature: String = str(board.get("_board_layout_signature"))
	_expect(
		before_signature != after_signature,
		"Submitting the same room with a newly visible backdrop should rebuild its opaque/transparent static state"
	)

func _test_bounded_zoom_and_hit_testing(board: Control) -> void:
	var focus_tile := Vector2i(4, 3)
	var focus_position: Vector2 = board.call("world_position_for_tile", focus_tile)
	board.call("set_navigation_zoom", 1.30, focus_position)
	var snapshot: Dictionary = board.call("navigation_snapshot")
	_expect(is_equal_approx(float(snapshot.get("zoom", 0.0)), 1.30), "Explicit zoom should use the requested in-range scale")
	var anchored_position: Vector2 = board.call("world_position_for_tile", focus_tile)
	_expect(anchored_position.distance_to(focus_position) <= 1.0, "Zoom should keep the focused tile anchored beneath the pointer")
	_expect(board.call("_tile_at_point", anchored_position) == focus_tile, "Zoomed board hit testing should still resolve the visible tile")

	board.call("set_navigation_zoom", 99.0, focus_position)
	snapshot = board.call("navigation_snapshot")
	_expect(is_equal_approx(float(snapshot.get("zoom", 0.0)), float(snapshot.get("max_zoom", -1.0))), "Zoom should clamp at the modest maximum")
	board.call("set_navigation_zoom", 0.01, focus_position)
	snapshot = board.call("navigation_snapshot")
	_expect(is_equal_approx(float(snapshot.get("zoom", 0.0)), float(snapshot.get("min_zoom", -1.0))), "Zoom should clamp at the modest minimum")

	board.call("set_navigation_pan", Vector2(100000.0, -100000.0))
	snapshot = board.call("navigation_snapshot")
	var pan: Vector2 = snapshot.get("pan", Vector2.ZERO)
	var limits: Rect2 = snapshot.get("pan_limits", Rect2())
	_expect(pan.x <= limits.end.x + 0.01 and pan.x >= limits.position.x - 0.01, "Horizontal panning should stay inside its board-aware bounds")
	_expect(pan.y <= limits.end.y + 0.01 and pan.y >= limits.position.y - 0.01, "Vertical panning should stay inside its board-aware bounds")
	board.call("reset_navigation")

func _test_wheel_zoom(board: Control) -> void:
	var before_zoom: float = float((board.call("navigation_snapshot") as Dictionary).get("zoom", 0.0))
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.factor = 1.0
	wheel.position = board.call("world_position_for_tile", Vector2i(4, 3))
	board.call("_gui_input", wheel)
	var after_zoom: float = float((board.call("navigation_snapshot") as Dictionary).get("zoom", 0.0))
	_expect(after_zoom > before_zoom, "Mouse-wheel input should zoom the board in")

func _test_pickup_zoom_geometry_matches_actor(board: Control) -> void:
	var state: Dictionary = _board_state(Vector2i(2, 3))
	state["loot"] = [
		{"id": "zoom_vial", "kind": "healing_vial", "amount": 4, "pos": Vector2i(2, 2)},
		{"id": "zoom_shield", "kind": "rusty_shield", "amount": 4, "pos": Vector2i(3, 2)},
		{"id": "zoom_equipment", "kind": "equipment", "equipment_id": "iron_cleaver", "pos": Vector2i(4, 2)}
	]
	board.set_combat_state(state)
	var minimum_zoom: float = float((board.call("navigation_snapshot") as Dictionary).get("min_zoom", 0.0))
	var maximum_zoom: float = float((board.call("navigation_snapshot") as Dictionary).get("max_zoom", 0.0))
	board.call("set_navigation_zoom", minimum_zoom, board.size * 0.5)
	var minimum: Dictionary = _pickup_and_actor_geometry(board, state)
	board.call("reset_navigation")
	var default_zoom: Dictionary = _pickup_and_actor_geometry(board, state)
	board.call("set_navigation_zoom", maximum_zoom, board.size * 0.5)
	var maximum: Dictionary = _pickup_and_actor_geometry(board, state)
	for object_id: String in ["healing_vial", "rusty_shield", "equipment"]:
		var min_width: float = float((minimum.get(object_id, Rect2()) as Rect2).size.x)
		var default_width: float = float((default_zoom.get(object_id, Rect2()) as Rect2).size.x)
		var max_width: float = float((maximum.get(object_id, Rect2()) as Rect2).size.x)
		_expect(min_width > 0.0, "%s pickup should produce a rendered geometry bound at minimum zoom" % object_id)
		_expect(min_width < default_width and default_width < max_width, "%s pickup should grow monotonically from minimum through default to maximum board zoom" % object_id)
		var min_actor_ratio: float = min_width / maxf(0.001, float((minimum.get("player", Rect2()) as Rect2).size.x))
		var default_actor_ratio: float = default_width / maxf(0.001, float((default_zoom.get("player", Rect2()) as Rect2).size.x))
		var max_actor_ratio: float = max_width / maxf(0.001, float((maximum.get("player", Rect2()) as Rect2).size.x))
		_expect(is_equal_approx(min_actor_ratio, default_actor_ratio) and is_equal_approx(default_actor_ratio, max_actor_ratio), "%s pickup should retain its actor-relative screen proportion across board zoom" % object_id)
	board.call("reset_navigation")
	board.set_combat_state(_board_state(Vector2i(2, 3)))

func _pickup_and_actor_geometry(board: Control, state: Dictionary) -> Dictionary:
	var player_unit: Dictionary = {}
	for unit_var: Variant in board.call("_visible_units") as Array:
		if typeof(unit_var) == TYPE_DICTIONARY and str((unit_var as Dictionary).get("role", "")) == "player":
			player_unit = unit_var as Dictionary
			break
	var geometry: Dictionary = {"player": board.call("_unit_draw_rect", player_unit) as Rect2}
	for loot_var: Variant in state.get("loot", []) as Array:
		var loot: Dictionary = loot_var as Dictionary
		var texture: Texture2D = board.call("_loot_texture", loot) as Texture2D
		geometry[str(loot.get("kind", ""))] = board.call("_loot_rect_for_tile", loot.get("pos", Vector2i.ZERO), texture, loot) as Rect2
	return geometry

func _test_click_without_drag(board: Control) -> void:
	var pointer: Vector2 = board.call("world_position_for_tile", Vector2i(4, 3))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pointer
	board.call("_gui_input", press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = pointer
	board.call("_gui_input", release)
	_expect(_click_count == 1, "A left click without a drag should still activate its combat tile")

func _test_left_drag_pans_without_clicking(board: Control) -> void:
	board.call("set_navigation_zoom", 1.30, board.size * 0.5)
	board.call("set_navigation_pan", Vector2.ZERO)
	var before_pan: Vector2 = (board.call("navigation_snapshot") as Dictionary).get("pan", Vector2.ZERO)
	var before_click_count: int = _click_count
	var pointer: Vector2 = board.call("world_position_for_tile", Vector2i(4, 3))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pointer
	board.call("_gui_input", press)
	var motion := InputEventMouseMotion.new()
	motion.position = pointer + Vector2(42.0, -24.0)
	motion.relative = Vector2(42.0, -24.0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	board.call("_gui_input", motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = motion.position
	board.call("_gui_input", release)
	var after_pan: Vector2 = (board.call("navigation_snapshot") as Dictionary).get("pan", Vector2.ZERO)
	_expect(after_pan.distance_to(before_pan) > 10.0, "Ordinary left-drag should visibly pan the board")
	_expect(_click_count == before_click_count, "A board pan should not accidentally click a combat tile")

func _test_aim_drag_keeps_combat_semantics(board: Control, state: Dictionary) -> void:
	board.call("reset_navigation")
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"tile_drag_aiming": true})
	var before_pan: Vector2 = (board.call("navigation_snapshot") as Dictionary).get("pan", Vector2.ZERO)
	var start_position: Vector2 = board.call("world_position_for_tile", Vector2i(4, 3))
	var target_position: Vector2 = board.call("world_position_for_tile", Vector2i(5, 3))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start_position
	board.call("_gui_input", press)
	var motion := InputEventMouseMotion.new()
	motion.position = target_position
	motion.relative = target_position - start_position
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	board.call("_gui_input", motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = target_position
	board.call("_gui_input", release)
	var after_pan: Vector2 = (board.call("navigation_snapshot") as Dictionary).get("pan", Vector2.ZERO)
	_expect(after_pan.is_equal_approx(before_pan), "Directional AOE dragging should not pan the board")
	_expect(_tile_drag_count > 0, "Directional AOE dragging should still emit tile-drag updates")
	_expect(_tile_drag_release_count == 1, "Directional AOE dragging should still emit its release confirmation")

func _test_new_room_recenters_without_resetting_zoom(board: Control) -> void:
	board.set_combat_state(_board_state(Vector2i(2, 3)))
	board.call("set_navigation_zoom", 1.25, board.size * 0.5)
	board.call("set_navigation_pan", Vector2(36.0, -24.0))
	board.set_combat_state(_board_state(Vector2i(3, 3)))
	var snapshot: Dictionary = board.call("navigation_snapshot")
	_expect((snapshot.get("pan", Vector2.ZERO) as Vector2).is_zero_approx(), "Entering a different room should recenter the board")
	_expect(is_equal_approx(float(snapshot.get("zoom", 0.0)), 1.25), "Entering a different room should preserve the player's zoom preference")

func _board_state(room_coord: Vector2i) -> Dictionary:
	return {
		"room_coord": room_coord,
		"room_element": "none",
		"grid": _simple_grid(),
		"player": {"pos": Vector2i(3, 3), "hp": 24, "max_hp": 24, "block": 0},
		"enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(5, 3), "hp": 18, "max_hp": 18, "block": 0}],
		"illusions": [],
		"npcs": [],
		"loot": [],
		"terrain": [],
		"traps": []
	}

func _simple_grid() -> Array:
	return [
		["wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall"],
		["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
		["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
		["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
		["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
		["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
		["wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall"]
	]

func _on_tile_clicked(_tile: Vector2i) -> void:
	_click_count += 1

func _on_tile_dragged(_start_tile: Vector2i, _current_tile: Vector2i) -> void:
	_tile_drag_count += 1

func _on_tile_drag_released(_start_tile: Vector2i, _current_tile: Vector2i) -> void:
	_tile_drag_release_count += 1

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)

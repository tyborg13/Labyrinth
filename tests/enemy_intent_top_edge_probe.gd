extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const GameData = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const OUTPUT_DIR_ROOT: String = "user://probes/enemy_intent_top_edge_v2"
const BOARD_PATH: String = "BoardUnderlay/CombatBoard"
const PROBE_VIEWPORT: Vector2i = Vector2i(1920, 1080)

var _output_dir: String = ""
var _requested_state: String = "compact"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(PROBE_VIEWPORT)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = PROBE_VIEWPORT
	root.size = PROBE_VIEWPORT
	ProgressionStore.set_storage_path("user://labyrinth_progression_enemy_intent_top_edge_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_enemy_intent_top_edge_probe.save")
	SettingsStore.set_storage_path("user://labyrinth_settings_enemy_intent_top_edge_probe.json")
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	var requested_state: String = OS.get_environment("LABYRINTH_INTENT_PROBE_STATE").strip_edges().to_lower()
	if requested_state.is_empty():
		requested_state = "compact"
	_expect(requested_state in ["compact", "expanded", "right_edge", "midboard", "show_all", "tallest", "retained"], "Enemy intent proof state should be compact, expanded, right_edge, midboard, show_all, tallest, or retained")
	_requested_state = requested_state
	_output_dir = "%s_%s" % [OUTPUT_DIR_ROOT, requested_state]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_dir))
	_clear_probe_output(ProjectSettings.globalize_path(_output_dir))

	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "Top-edge intent proof should load the real run scene")
	if packed == null:
		quit(1)
		return
	await _capture_fresh_state(packed, requested_state in ["expanded", "right_edge", "midboard"], requested_state)

	print("ENEMY INTENT TOP EDGE PROBE: PASS")
	print("ENEMY_INTENT_TOP_EDGE_PROOF_DIR=%s" % ProjectSettings.globalize_path(_output_dir))
	quit(0)

func _capture_fresh_state(packed: PackedScene, expanded: bool, label: String) -> void:
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle_ui()
	await _load_combat_fixture(instance, expanded, label in ["tallest", "retained"], label == "midboard", label == "right_edge", label == "show_all")
	var board: Control = instance.get_node(BOARD_PATH) as Control
	_expect(board != null, "%s top-edge intent proof should find the real combat board" % label)
	if board == null:
		return
	if label == "tallest":
		await _exercise_cached_tallest_transition(board)
	elif label == "retained":
		await _exercise_retained_blink_transition(instance, board)
	var enemy_unit: Dictionary = _enemy_unit(board)
	var enemy_center: Vector2 = board.call("_unit_center", enemy_unit)
	if label == "compact":
		await _capture_compact_state(board, label)
	elif label == "tallest":
		await _capture_tallest_state(board, enemy_unit, label)
	elif label == "midboard":
		await _capture_midboard_state(board, enemy_unit, enemy_center, label)
	elif label == "retained":
		await _capture_retained_state(board, label)
	elif label == "show_all":
		await _capture_show_all_state(instance, board, label)
	else:
		await _capture_state(board, enemy_unit, enemy_center, label)
	instance.queue_free()
	await process_frame
	await process_frame

func _load_combat_fixture(instance: Node, expanded: bool, tallest: bool = false, midboard: bool = false, right_edge: bool = false, show_all: bool = false) -> void:
	var enemy_type: String = "zekarion" if tallest else "harrier"
	var enemy_def: Dictionary = GameData.enemy_def(enemy_type)
	var max_hp: int = int(enemy_def.get("max_hp", 18))
	var layout: Dictionary = {
		"name": "Top-edge Intent Probe",
		"coord": Vector2i(4, 3),
		"type": "combat",
		"grid": _simple_grid(),
		"player_start": Vector2i(2, 6),
		"enemies": (
			[
				{"id": 1, "type": "harrier", "pos": Vector2i(2, 2), "hp": max_hp, "max_hp": max_hp},
				{"id": 2, "type": "crawler", "pos": Vector2i(5, 3), "hp": max_hp, "max_hp": max_hp}
			]
			if show_all
			else [{"id": 1, "type": enemy_type, "pos": Vector2i(4, 4) if midboard else Vector2i(6, 1) if right_edge else Vector2i(1, 1), "hp": max_hp, "max_hp": max_hp}]
		),
		"traps": [],
		"terrain": [],
		"loot": []
	}
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(88421, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab", "sidestep_slash", "guarded_step"],
		"relics": [],
		"hand_size": 3,
		"heal_bonus": 0
	})
	var enemy: Dictionary = (combat_state.get("enemies", []) as Array)[0]
	enemy["type"] = enemy_type
	enemy["hp"] = max_hp
	enemy["max_hp"] = max_hp
	if tallest:
		var footprint_data: Array = enemy_def.get("footprint", [2, 2]) as Array
		enemy["footprint"] = Vector2i(int(footprint_data[0]), int(footprint_data[1]))
		var intents: Array = enemy_def.get("intents", []) as Array
		enemy["intent"] = (intents[0] as Dictionary).duplicate(true) if not intents.is_empty() else {}
	else:
		enemy["intent"] = {
			"name": "Raking Pelt",
			"actions": [
				{"type": "move_toward", "range": 2},
				{"type": "ranged", "damage": 4, "range": 4, "bleed": 1}
			]
		}
	(combat_state.get("enemies", []) as Array)[0] = enemy
	if show_all:
		var second_enemy: Dictionary = (combat_state.get("enemies", []) as Array)[1]
		second_enemy["intent"] = {
			"name": "Skittering Bite",
			"actions": [
				{"type": "move_toward", "range": 2},
				{"type": "melee", "damage": 3, "range": 1}
			]
		}
		(combat_state.get("enemies", []) as Array)[1] = second_enemy
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.set("_animation_lock", false)
	instance.set("_turn_order_hovered_enemy_key", "enemy_1" if expanded else "")
	instance.call("_refresh_ui")
	if show_all:
		instance.call("_set_show_all_enemy_intents", true)
	var progression: Dictionary = (instance.get("_progression") as Dictionary).duplicate(true)
	for prompt_id: String in ContextualCombatTutorial.prompt_ids():
		progression = ContextualCombatTutorial.resolve_progression(progression, prompt_id)
	instance.set("_progression", progression)
	instance.call("_refresh_contextual_combat_tutorial")
	await _settle_ui()

func _exercise_cached_tallest_transition(board: Control) -> void:
	var tallest_state: Dictionary = (board.get("combat_state") as Dictionary).duplicate(true)
	var ordinary_state: Dictionary = tallest_state.duplicate(true)
	ordinary_state["enemies"] = [{
		"id": 1,
		"type": "harrier",
		"pos": Vector2i(4, 4),
		"hp": 18,
		"max_hp": 18,
		"intent": {}
	}]
	var current_presentation: Dictionary = board.get("presentation") as Dictionary
	var reset_state: Dictionary = ordinary_state.duplicate(true)
	reset_state["room_coord"] = Vector2i(99, 99)
	board.call("set_combat_state", reset_state, [], [], Vector2i(-1, -1), "", "", {}, {}, current_presentation)
	board.call("_board_origin")
	board.call("set_combat_state", ordinary_state, [], [], Vector2i(-1, -1), "", "", {}, {}, current_presentation)
	board.call("_board_origin")
	var ordinary_offset: float = float(board.get("_board_layout_cache_visual_top_offset"))
	board.call("set_combat_state", tallest_state, [], [], Vector2i(-1, -1), "", "", {}, {}, current_presentation)
	await _settle_ui()
	_expect(float(board.get("_board_layout_cache_visual_top_offset")) > ordinary_offset, "Tallest visual proof should exercise a same-room cached occupant transition")

func _exercise_retained_blink_transition(instance: Node, board: Control) -> void:
	var tallest_state: Dictionary = (board.get("combat_state") as Dictionary).duplicate(true)
	var ordinary_state: Dictionary = tallest_state.duplicate(true)
	ordinary_state["enemies"] = [{
		"id": 1,
		"type": "harrier",
		"pos": Vector2i(4, 4),
		"hp": 18,
		"max_hp": 18,
		"intent": {
			"name": "Raking Pelt",
			"actions": [
				{"type": "move_toward", "range": 2},
				{"type": "ranged", "damage": 4, "range": 4, "bleed": 1}
			]
		}
	}]
	var current_presentation: Dictionary = board.get("presentation") as Dictionary
	var reset_state: Dictionary = ordinary_state.duplicate(true)
	reset_state["room_coord"] = Vector2i(99, 99)
	board.call("set_combat_state", reset_state, [], [], Vector2i(-1, -1), "", "", {}, {}, current_presentation)
	board.call("_board_origin")
	board.call("set_combat_state", ordinary_state, [], [], Vector2i(-1, -1), "", "", {}, {}, current_presentation)
	board.call("_board_origin")
	var ordinary_offset: float = float(board.get("_board_layout_cache_visual_top_offset"))

	board.call("set_combat_state", tallest_state, [], [], Vector2i(-1, -1), "", "", {}, {}, current_presentation)
	# Match a card-resolution frame where the floor materializes adaptive
	# clearance but retained actor layers do not draw before Blink creates its
	# illusions and submits the next visual snapshot.
	board.call("_board_origin")
	var tallest_offset: float = float(board.get("_board_layout_cache_visual_top_offset"))
	_expect(tallest_offset > ordinary_offset, "Retained-layer proof should earn adaptive top clearance in an intermediate snapshot")

	var blink_state: Dictionary = ordinary_state.duplicate(true)
	(blink_state.get("player", {}) as Dictionary)["pos"] = Vector2i(5, 2)
	blink_state["illusions"] = [
		{"id": 1, "pos": Vector2i(5, 3), "hp": 3, "max_hp": 3},
		{"id": 2, "pos": Vector2i(4, 2), "hp": 2, "max_hp": 2}
	]
	board.call("set_combat_state", blink_state, [], [], Vector2i(-1, -1), "", "", {}, {}, current_presentation)
	_assert_retained_layout_alignment(board, tallest_offset)

	instance.set("_combat_state", blink_state)
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["combat_state"] = blink_state
	var room_layout: Dictionary = (run_state.get("current_room_layout", {}) as Dictionary).duplicate(true)
	room_layout["enemies"] = (ordinary_state.get("enemies", []) as Array).duplicate(true)
	run_state["current_room_layout"] = room_layout
	instance.set("_run_state", run_state)
	instance.call("_refresh_ui")
	await _settle_ui()
	_assert_retained_layout_alignment(board, tallest_offset)

func _assert_retained_layout_alignment(board: Control, expected_offset: float) -> void:
	var parent_origin: Vector2 = board.call("_board_origin") as Vector2
	_expect(is_equal_approx(float(board.get("_board_layout_cache_visual_top_offset")), expected_offset), "Blink/illusion state should retain the room's authoritative adaptive clearance")
	var actor_tiles: Array[Vector2i]
	actor_tiles.append(Vector2i(5, 2))
	actor_tiles.append(Vector2i(5, 3))
	actor_tiles.append(Vector2i(4, 2))
	actor_tiles.append(Vector2i(4, 4))
	for layer_var: Variant in board.call("_retained_render_layers") as Array:
		var layer: Control = layer_var as Control
		var layer_label: String = "%s:%s" % [str(layer.get("_render_layer_kind")), str(layer.get("_render_layer_tile"))]
		_expect((layer.call("_board_origin") as Vector2).is_equal_approx(parent_origin), "Retained %s origin should remain aligned with the floor after Blink/illusion creation" % layer_label)
		_expect(is_equal_approx(float(layer.get("_board_layout_cache_visual_top_offset")), expected_offset), "Retained %s should inherit the floor's adaptive clearance" % layer_label)
		for tile: Vector2i in actor_tiles:
			var parent_center: Vector2 = board.call("_tile_center", tile) as Vector2
			var layer_center: Vector2 = layer.call("_tile_center", tile) as Vector2
			_expect(layer_center.is_equal_approx(parent_center), "Retained %s should center actor tile %s on the floor" % [layer_label, tile])

func _capture_retained_state(board: Control, label: String) -> void:
	await _settle_ui()
	var visible_units: Array = board.call("_visible_units") as Array
	var illusion_count: int = 0
	for unit_var: Variant in visible_units:
		if typeof(unit_var) == TYPE_DICTIONARY and str((unit_var as Dictionary).get("role", "")) == "illusion":
			illusion_count += 1
	_expect(illusion_count == 2, "Retained framing screenshot should show both Blink-created illusions")
	await _save_root_screenshot("%s/%s.png" % [_output_dir, label])

func _capture_state(board: Control, enemy_unit: Dictionary, enemy_center: Vector2, label: String) -> void:
	await _settle_ui()
	var layout: Dictionary = _rendered_enemy_layout(board)
	_assert_layout(board, enemy_unit, enemy_center, layout, label)
	await _assert_pan_stability(board, enemy_unit, label)
	await _save_root_screenshot("%s/%s.png" % [_output_dir, label])

func _capture_compact_state(board: Control, label: String) -> void:
	await _settle_ui()
	var layout: Dictionary = _rendered_enemy_layout(board)
	_expect((layout.get("line_rects", []) as Array).is_empty(), "%s state should not render expanded intent text without hover or focus" % label)
	_expect((layout.get("intent_rect", Rect2()) as Rect2).size.is_zero_approx(), "%s state should not reserve an invisible intent panel" % label)
	var enemy: Dictionary = _enemy_unit(board)
	var compass_center: Vector2 = board.call("_intent_compass_center", enemy)
	_expect(not str(board.call("_get_tooltip", compass_center)).contains("Raking Pelt"), "Enemy hover should no longer expose the redundant whole-intent text tooltip")
	await _save_root_screenshot("%s/%s.png" % [_output_dir, label])

func _capture_show_all_state(instance: Node, board: Control, label: String) -> void:
	await _settle_ui()
	var layouts: Dictionary = {}
	var built: Dictionary = board.call("_build_hud_layout_data", board.call("_visible_units"))
	for entry_var: Variant in built.get("entries", []):
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var
		var actor_key: String = str(entry.get("actor_key", ""))
		if actor_key.begins_with("enemy_"):
			layouts[actor_key] = entry.get("layout", {})
	_expect(layouts.size() == 2, "Show-all proof should render independent contour layouts for both visible enemies")
	for actor_key: String in layouts:
		_expect(not ((layouts[actor_key] as Dictionary).get("line_rects", []) as Array).is_empty(), "Show-all proof should expand %s without hover" % actor_key)
	var presentation: Dictionary = board.get("presentation") as Dictionary
	_expect((presentation.get("enemy_threat_previews", []) as Array).size() == 2, "Show-all proof should include both enemy movement/threat previews")
	var toggle: Button = instance.find_child("EnemyIntentToggle", true, false) as Button
	_expect(toggle != null and toggle.button_pressed and toggle.text == "INTENTS ON [I]", "Show-all proof should visibly expose the active intent control and shortcut")
	await _save_root_screenshot("%s/%s.png" % [_output_dir, label])

func _capture_midboard_state(board: Control, enemy_unit: Dictionary, enemy_center: Vector2, label: String) -> void:
	await _settle_ui()
	var layout: Dictionary = _rendered_enemy_layout(board)
	_assert_layout(board, enemy_unit, enemy_center, layout, label)
	for requested_pan: Vector2 in [Vector2(-36.0, 0.0), Vector2(28.0, 0.0), Vector2.ZERO]:
		board.call("set_navigation_pan", requested_pan, false)
		await process_frame
		var moved_enemy: Dictionary = _enemy_unit(board)
		var moved_center: Vector2 = board.call("_unit_center", moved_enemy)
		_assert_layout(board, moved_enemy, moved_center, _rendered_enemy_layout(board), "%s motion" % label)
	await _settle_ui()
	await _save_root_screenshot("%s/%s.png" % [_output_dir, label])

func _capture_tallest_state(board: Control, enemy_unit: Dictionary, label: String) -> void:
	await _settle_ui()
	var art_rect: Rect2 = board.call("_unit_draw_rect", enemy_unit)
	var transform: Transform2D = board.get_global_transform()
	var global_top_left: Vector2 = transform * art_rect.position
	var global_bottom_right: Vector2 = transform * art_rect.end
	var global_art_rect := Rect2(global_top_left, global_bottom_right - global_top_left)
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(PROBE_VIEWPORT))
	_expect(str(enemy_unit.get("type", "")) == "zekarion", "Tallest framing proof should use the audited tallest shipped character")
	_expect(float(board.get("_board_layout_cache_visual_top_offset")) > 0.0, "Tallest top-corner character should activate adaptive visual framing")
	_expect(viewport_rect.encloses(global_art_rect), "Tallest top-corner character art should remain fully onscreen: %s" % global_art_rect)
	await _save_root_screenshot("%s/%s.png" % [_output_dir, label])

func _assert_pan_stability(board: Control, enemy_unit: Dictionary, label: String) -> void:
	var initial_layout: Dictionary = _rendered_enemy_layout(board)
	var remembered_side: String = str(initial_layout.get("side", ""))
	_expect(remembered_side in ["left", "right"], "%s motion proof should begin with a remembered HUD side" % label)
	var saw_motion: bool = false
	var requested_pans: Array[Vector2] = [
		Vector2(-36.0, 0.0),
		Vector2(-12.0, 0.0),
		Vector2(18.0, 0.0),
		Vector2(42.0, 0.0),
		Vector2.ZERO
	]
	for requested_pan: Vector2 in requested_pans:
		board.call("set_navigation_pan", requested_pan, false)
		await process_frame
		var actual_pan: Vector2 = (board.call("navigation_snapshot") as Dictionary).get("pan", Vector2.ZERO)
		saw_motion = saw_motion or not actual_pan.is_zero_approx()
		var moved_enemy: Dictionary = _enemy_unit(board)
		var moved_center: Vector2 = board.call("_unit_center", moved_enemy)
		var moved_layout: Dictionary = _rendered_enemy_layout(board)
		_expect(str(moved_layout.get("side", "")) == remembered_side, "%s intent HUD should keep one side throughout a clear board-pan sweep" % label)
		_assert_layout(board, moved_enemy, moved_center, moved_layout, "%s motion" % label)
	_expect(saw_motion, "%s motion proof should exercise a non-zero board pan" % label)
	board.call("set_navigation_pan", Vector2.ZERO, false)
	await _settle_ui()

func _rendered_enemy_layout(board: Control) -> Dictionary:
	var units: Array = board.call("_visible_units") as Array
	var built: Dictionary = board.call("_build_hud_layout_data", units)
	for entry_var: Variant in built.get("entries", []):
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var as Dictionary
		if str(entry.get("actor_key", "")) == "enemy_1":
			return entry.get("layout", {}) as Dictionary
	return {}

func _assert_layout(board: Control, enemy_unit: Dictionary, enemy_center: Vector2, layout: Dictionary, label: String) -> void:
	_expect(not layout.is_empty(), "%s top-edge proof should build an enemy HUD layout" % label)
	if layout.is_empty():
		return
	var health_rect: Rect2 = layout.get("health_rect", Rect2())
	var intent_rect: Rect2 = layout.get("intent_rect", Rect2())
	var default_health_rect: Rect2 = board.call("_unit_health_bar_rect", enemy_unit, enemy_center)
	var actor_clear_rect: Rect2 = board.call("_enemy_hud_actor_clear_rect", enemy_unit, enemy_center)
	var bounds: Rect2 = board.call("_enemy_hud_viewport_bounds")
	var rows: Array = layout.get("rows", []) as Array
	var line_count: int = rows.size() + (1 if not str(layout.get("intent_name", "")).is_empty() else 0)
	var line_rects: Array = layout.get("line_rects", []) as Array
	var side: String = str(layout.get("side", ""))
	_expect(side in ["left", "right"], "%s hover detail should choose an enemy shoulder" % label)
	_expect(health_rect.position.is_equal_approx(default_health_rect.position), "%s hover detail should not displace the enemy health bar" % label)
	_expect(line_rects.size() == line_count and line_count >= 2, "%s should preserve the title and every ordered action row" % label)
	_expect(bounds.encloses(intent_rect), "%s contour text should remain inside the combat viewport" % label)
	_expect((layout.get("tether", {}) as Dictionary).is_empty(), "%s freeform contour treatment should not draw the old panel tether" % label)
	for line_index: int in range(line_rects.size()):
		var line_rect: Rect2 = line_rects[line_index] as Rect2
		_expect(intent_rect.encloses(line_rect), "%s contour bounds should enclose line %d" % [label, line_index])
		if line_index > 0:
			var previous: Rect2 = line_rects[line_index - 1] as Rect2
			_expect(line_rect.position.y >= previous.end.y - 0.01, "%s action lines should descend in intent order" % label)
			_expect(line_rect.position.x > previous.position.x if side == "right" else line_rect.end.x < previous.end.x, "%s lines should stagger outward along the %s sprite contour" % [label, side])
	var title_rect: Rect2 = line_rects[0] as Rect2
	_expect(title_rect.position.y <= actor_clear_rect.position.y + 16.0, "%s intent name should begin at the sprite's highest shoulder contour" % label)

func _enemy_unit(board: Control) -> Dictionary:
	for unit_var: Variant in board.call("_visible_units"):
		if typeof(unit_var) == TYPE_DICTIONARY and str((unit_var as Dictionary).get("key", "")) == "enemy_1":
			return unit_var as Dictionary
	return {}

func _simple_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return grid

func _settle_ui() -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame

func _save_root_screenshot(output_path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	_queue_full_redraw(root)
	var image: Image = null
	var best_visibility_score: float = -1.0
	for _attempt: int in range(6):
		_queue_full_redraw(root)
		# Metal reliably captures the compact retained frame after force_draw,
		# while the expanded HUD needs frame_post_draw synchronization (and the
		# ANGLE proof command) to avoid reading only the HUD layer's dirty region.
		if _requested_state == "expanded":
			await process_frame
			await RenderingServer.frame_post_draw
		else:
			RenderingServer.force_draw()
			await process_frame
		var texture: Texture2D = root.get_viewport().get_texture()
		var candidate: Image = texture.get_image()
		var visibility_score: float = _image_visibility_score(candidate)
		if visibility_score > best_visibility_score:
			best_visibility_score = visibility_score
			image = candidate
		await process_frame
	_expect(image != null and best_visibility_score > 0.01, "Top-edge intent proof should capture a complete renderer image")
	if image == null:
		return
	var source_size: Vector2i = image.get_size()
	var scale_x: float = float(source_size.x) / float(PROBE_VIEWPORT.x)
	var scale_y: float = float(source_size.y) / float(PROBE_VIEWPORT.y)
	var proportional: bool = is_equal_approx(scale_x, scale_y) and is_equal_approx(float(source_size.x) / float(source_size.y), float(PROBE_VIEWPORT.x) / float(PROBE_VIEWPORT.y))
	_expect(proportional, "Top-edge intent proof should preserve the Full HD aspect ratio, got %s" % source_size)
	if not proportional:
		return
	if source_size != PROBE_VIEWPORT:
		image.resize(PROBE_VIEWPORT.x, PROBE_VIEWPORT.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(output_path)

func _image_visibility_score(image: Image) -> float:
	if image == null:
		return -1.0
	var image_size: Vector2i = image.get_size()
	if image_size.x <= 0 or image_size.y <= 0:
		return -1.0
	var x_step: int = maxi(1, image_size.x / 16)
	var y_step: int = maxi(1, image_size.y / 9)
	var total: float = 0.0
	var sample_count: int = 0
	for y: int in range(y_step / 2, image_size.y, y_step):
		for x: int in range(x_step / 2, image_size.x, x_step):
			var pixel: Color = image.get_pixel(x, y)
			total += maxf(pixel.r, maxf(pixel.g, pixel.b))
			sample_count += 1
	return total / float(maxi(1, sample_count))

func _queue_full_redraw(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).queue_redraw()
	for child: Node in node.get_children():
		_queue_full_redraw(child)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _clear_probe_output(absolute_dir: String) -> void:
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry.is_empty():
			break
		if entry in [".", ".."]:
			continue
		var child_path: String = absolute_dir.path_join(entry)
		if dir.current_is_dir():
			_clear_probe_output(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()

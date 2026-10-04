extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const FoeSuite = preload("res://tests/suites/pre_battle_ui_suite.gd")
const PROBE_VIEWPORT := Vector2i(1920, 1080)
const INVALID_COORD := Vector2i(999, 999)
var _viewport: SubViewport
var _failed: bool = false

func _setup() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://pre_battle_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://pre_battle_probe_run.save")
	ProgressionStore.clear_saved_run()
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	Settings.apply_settings(settings, null, false)
	_viewport = SubViewport.new()
	_viewport.size = PROBE_VIEWPORT
	_viewport.msaa_2d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)

func _instance(state: Dictionary) -> Node:
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(instance)
	await _settle()
	instance.call("_load_run_state", state)
	instance.call("_close_dialogue")
	await _settle()
	return instance

func _settle() -> void:
	await create_timer(0.35).timeout
	await process_frame
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)
		print("TEST RESULT: FAIL %s" % message)

func _fail(message: String) -> void:
	_expect(false, message)

func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	_expect(image != null and image.get_size() == PROBE_VIEWPORT, "Capture must be exactly 1920x1080 from the SubViewport")
	if image != null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		_expect(image.save_png(path) == OK, "Capture should save")

func _labels_text(node: Node) -> String:
	var parts := PackedStringArray()
	for child: Node in node.find_children("*", "Label", true, false):
		parts.append((child as Label).text)
	return "\n".join(parts)

func _assert_pre_battle_body_inside_panel(panel: Control, context: String) -> void:
	var scrim := panel.get_parent().get_parent() as Control
	var frame := scrim.find_child("PreBattleFrame", true, false) as Control
	_expect(frame != null and frame.get("texture") != null, "%s should render its authored outer frame" % context)
	if frame != null:
		_expect(frame.z_index > scrim.z_index, "%s ornate frame must render above the panel" % context)
		_expect(frame.size.x > panel.size.x and frame.size.y > panel.size.y and frame.get_global_rect().encloses(panel.get_global_rect()), "%s ornate frame must surround the panel" % context)
	var safe := panel.get_global_rect().grow(-8.0)
	for node_name: String in ["PreBattleRoomChip", "PreBattleObjectiveChip", "PreBattleEnemySection", "PreBattleDeckSection", "PreBattleEquipButton", "PreBattleStartButton", "TrueBearingButton"]:
		var control := panel.find_child(node_name, true, false) as Control
		if control == null and node_name == "TrueBearingButton":
			continue
		_expect(control != null, "%s should render %s" % [context, node_name])
		if control != null:
			_expect(safe.encloses(control.get_global_rect()), "%s %s must fit within the frame: %s in %s" % [context, node_name, control.get_global_rect(), safe])
	_expect(panel.size == Vector2(1210.0, 750.0), "%s must preserve the frame's original outer placement and panel dimensions, got %s" % [context, panel.size])

func _assert_foe_fit(panel: Control, count: int) -> void:
	var flow := panel.find_child("PreBattleEnemyFlow", true, false) as Control
	var scroll := panel.find_child("PreBattleEnemyScroll", true, false) as ScrollContainer
	_expect(flow != null and flow.get_child_count() == count, "Every foe should be listed")
	_expect(scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Up to six foes must fit without scrolling")
	var rect: Rect2 = scroll.get_global_rect().grow(1.0)
	FoeSuite.assert_true_scale(flow, _expect, "%d foes" % count)
	for index: int in range(flow.get_child_count()):
		var card := flow.get_child(index) as Control
		_expect(rect.encloses(card.get_global_rect()), "%d foes card %d must fit: %s in %s" % [count, index, card.get_global_rect(), rect])
		_expect(card.position.y == 0.0 and is_equal_approx(card.size.y, flow.size.y) if count <= 3 else int(card.get_meta("lineup_row")) in [0, 1], "Foes use one row through three, then two rows with large foes spanning both")
		for node_name: String in ["PreBattleEnemyHealth", "PreBattleEnemyName", "PreBattleMoveTags"]:
			var child := card.find_child(node_name, true, false) as Control
			_expect(child != null and rect.encloses(child.get_global_rect()), "%d foes %s must remain visible" % [count, node_name])
		for child: Node in card.find_children("*", "Label", true, false):
			var text := child as Label
			if text.is_visible_in_tree():
				_expect(text.get_theme_font_size("font_size") >= 14, "Foe text must retain the 14px floor")
				_expect(card.get_global_rect().grow(1.0).encloses(text.get_global_rect()), "%d foes %s text must fit inside its column: %s in %s" % [count, text.text, text.get_global_rect(), card.get_global_rect()])
		var tags := card.find_child("PreBattleMoveTags", true, false) as Control
		var name_label := card.find_child("PreBattleEnemyName", true, false) as Label
		_expect(not tags.get_global_rect().intersects(name_label.get_global_rect()), "%d foes %s name and tag row must not overlap" % [count, name_label.text])
		var name_gap: float = tags.global_position.y - name_label.get_global_rect().end.y
		_expect(absf(name_gap - 8.0) <= 0.5, "%d foes %s tags must flow 8px below the rendered name (got %.1f)" % [count, name_label.text, name_gap])
		var line_center: float = -1.0
		for child: Control in tags.get_children():
			if not child.is_visible_in_tree():
				continue
			_expect(tags.get_global_rect().grow(1.0).encloses(child.get_global_rect()), "Move tags and their overflow marker must fit on one line")
			var center: float = child.get_global_rect().get_center().y
			if line_center >= 0.0:
				_expect(absf(center - line_center) <= 1.0, "Move tags must never wrap")
			line_center = center

func _assert_cards(panel: Control, ids: Array, kind: String) -> void:
	var grid := panel.find_child("PreBattleDeckFlow" if kind == "deck" else "PreBattleAttunedRow", true, false) as Control
	var represented: Array = []
	var top_y: float = (grid.get_child(0) as Control).position.y if grid.get_child_count() > 0 else 0.0
	var first_row_count: int = 0
	for child: Node in grid.get_children():
		var strip := child as Control
		if is_equal_approx(strip.position.y, top_y):
			first_row_count += 1
		for index: int in range(int(strip.get_meta("card_count", 1))):
			represented.append(str(strip.get_meta("card_id", "")))
		var name_label := strip.get_node("Name") as Label
		_expect(name_label.get_theme_font_size("font_size") >= 14, "Card strips must retain the typography floor")
		_expect(strip.get_global_rect().grow(0.5).encloses(name_label.get_global_rect()), "Card name must fit within its strip")
		_expect(not name_label.text.is_empty() and name_label.size.x > 0.0, "Every strip must show its card identity")
		var count_label := strip.get_node("Count") as Label
		var count: int = int(strip.get_meta("card_count", 1))
		_expect(count_label.visible == (count > 1) and (count <= 1 or count_label.text == "×%d" % count), "Duplicate strips show exact counts")
	represented.sort()
	var expected: Array = ids.duplicate()
	expected.sort()
	_expect(represented == expected, "Every %s card and duplicate must be listed" % kind)
	_expect(first_row_count == mini(2, grid.get_child_count()), "Card strips must use exactly two columns")

func _pointer(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	_viewport.push_input(event, true)
	await process_frame

func _click(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	await _pointer(point)
	_expect(_viewport.gui_get_hovered_control() == control, "Pointer target should own its visible control")
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		_viewport.push_input(event, true)
		await process_frame

func _key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		_viewport.push_input(event, true)
		await process_frame

func _joy(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		_viewport.push_input(event, true)
		await process_frame

func _run_with_available_combat(probe_run_engine: RunEngine) -> Dictionary:
	var progression: Dictionary = ProgressionStore.default_data()
	for seed: int in range(1, 120):
		var state: Dictionary = probe_run_engine.create_new_run(seed, progression)
		if _first_available_combat_coord(probe_run_engine, state) != INVALID_COORD:
			return state
	return {}

func _first_available_combat_coord(probe_run_engine: RunEngine, run_state: Dictionary) -> Vector2i:
	if run_state.is_empty():
		return INVALID_COORD
	for coord_var: Variant in probe_run_engine.available_moves(run_state):
		if typeof(coord_var) != TYPE_VECTOR2I:
			continue
		var coord: Vector2i = coord_var
		var preview_state: Dictionary = probe_run_engine.move_to_room(run_state.duplicate(true), coord)
		if str(preview_state.get("mode", "")) == "combat" and not (preview_state.get("combat_state", {}) as Dictionary).is_empty():
			return coord
	return INVALID_COORD

func _first_room_coord_with_min_enemies(probe_run_engine: RunEngine, run_state: Dictionary, min_enemies: int) -> Vector2i:
	for radius: int in range(1, 9):
		for x: int in range(-radius, radius + 1):
			for y: int in range(-radius, radius + 1):
				var coord := Vector2i(x, y)
				if maxi(absi(x), absi(y)) != radius:
					continue
				var room: Dictionary = probe_run_engine.room_metadata(run_state, coord)
				if str(room.get("type", "")) not in ["combat", "boss"]:
					continue
				var layout: Dictionary = probe_run_engine.call("_combat_layout_for_room", room, _travel_dir_for_coord(coord), run_state)
				var enemies: Array = layout.get("enemies", [])
				if enemies.size() >= min_enemies:
					return coord
	return INVALID_COORD

func _pre_battle_state_for_room(probe_run_engine: RunEngine, run_state: Dictionary, coord: Vector2i) -> Dictionary:
	var state: Dictionary = run_state.duplicate(true)
	var travel_dir: Vector2i = _travel_dir_for_coord(coord)
	var room: Dictionary = probe_run_engine.room_metadata(state, coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = false
	room["sealed"] = false
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms[_room_key(coord)] = room
	state["rooms"] = rooms
	state["current_room"] = coord
	state["current_room_layout"] = probe_run_engine.call("_display_layout_for_room", int(state.get("seed", 0)), room, travel_dir)
	state["mode"] = RunEngine.MODE_PRE_BATTLE
	state["combat_state"] = {}
	state["pre_battle_pending"] = true
	state["pre_battle_travel_dir"] = travel_dir
	return state

func _travel_dir_for_coord(coord: Vector2i) -> Vector2i:
	if coord == Vector2i.ZERO:
		return Vector2i(1, 0)
	if absi(coord.x) >= absi(coord.y) and coord.x != 0:
		return Vector2i(1, 0) if coord.x > 0 else Vector2i(-1, 0)
	return Vector2i(0, 1) if coord.y > 0 else Vector2i(0, -1)

func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

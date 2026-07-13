extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const GameData = preload("res://scripts/game_data.gd")

const OUTPUT_DIR: String = "user://merchant_room_probe"
const PROBE_VIEWPORT: Vector2i = Vector2i(1280, 720)

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = PROBE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = PROBE_VIEWPORT
	await process_frame
	await process_frame
	root.size = PROBE_VIEWPORT
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	ProgressionStore.set_storage_path("user://labyrinth_progression_merchant_room_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_merchant_room_probe.save")
	ProgressionStore.clear_saved_run()
	await _capture_merchant_rooms()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(1 if _failed else 0)

func _capture_merchant_rooms() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load for merchant room probe")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	if not root.get_viewport().get_visible_rect().size.is_equal_approx(Vector2(PROBE_VIEWPORT)):
		_fail("Merchant room probe should use a 1280x720 logical viewport")
		return

	var probe_run_engine := RunEngine.new()
	var progression: Dictionary = ProgressionStore.set_embers(ProgressionStore.default_data(), 300)
	var base_state: Dictionary = _run_with_room_type(probe_run_engine, progression, "blacksmith")
	var blacksmith_coord: Vector2i = _first_room_coord_of_type(probe_run_engine, base_state, "blacksmith")
	if blacksmith_coord.x >= 900:
		_fail("Probe run should include a blacksmith room")
		return
	var blacksmith_state: Dictionary = _run_state_for_room(probe_run_engine, base_state, blacksmith_coord, Vector2i(1, 0))
	blacksmith_state["held_embers"] = 300
	blacksmith_state["unbanked_embers"] = 300
	blacksmith_state["equipment_inventory"] = ["ward_kite", "iron_cleaver"]
	blacksmith_state["collected_equipment"] = GameData.starter_equipment_ids() + ["ward_kite", "iron_cleaver"]
	instance.call("_load_run_state", blacksmith_state)
	await _settle_visuals()
	await _save_root_screenshot("%s/blacksmith_dialogue.png" % OUTPUT_DIR)
	instance.call("_close_dialogue")
	await _settle_visuals()
	await _save_root_screenshot("%s/blacksmith_trade.png" % OUTPUT_DIR)
	await _verify_merchant_door_access(instance, probe_run_engine)

	base_state = _run_with_room_type(probe_run_engine, progression, "arcanist")
	var arcanist_coord: Vector2i = _first_room_coord_of_type(probe_run_engine, base_state, "arcanist")
	if arcanist_coord.x >= 900:
		_fail("Probe run should include an arcanist room")
		return
	var arcanist_state: Dictionary = _run_state_for_room(probe_run_engine, base_state, arcanist_coord, Vector2i(1, 0))
	arcanist_state["held_embers"] = 220
	arcanist_state["unbanked_embers"] = 220
	arcanist_state["reward_cards"] = ["spark_dart", "frostbolt"]
	arcanist_state["magic_inventory"] = ["spark_dart", "frostbolt"]
	instance.call("_load_run_state", arcanist_state)
	await _settle_visuals()
	instance.call("_close_dialogue")
	await _settle_visuals()
	await _save_root_screenshot("%s/arcanist_trade.png" % OUTPUT_DIR)

	base_state = _run_with_room_type(probe_run_engine, progression, "scavenger")
	var scavenger_coord: Vector2i = _first_room_coord_of_type(probe_run_engine, base_state, "scavenger")
	if scavenger_coord.x >= 900:
		_fail("Probe run should include a scavenger room")
		return
	var scavenger_state: Dictionary = _run_state_for_room(probe_run_engine, base_state, scavenger_coord, Vector2i(1, 0))
	scavenger_state["held_embers"] = 180
	scavenger_state["unbanked_embers"] = 180
	scavenger_state["item_inventory"] = ["crimson_draught", "nail_bomb", "smoke_bomb"]
	instance.call("_load_run_state", scavenger_state)
	await _settle_visuals()
	instance.call("_close_dialogue")
	await _settle_visuals()
	await _save_root_screenshot("%s/scavenger_trade.png" % OUTPUT_DIR)

	instance.queue_free()
	await process_frame

func _run_with_room_type(probe_run_engine: RunEngine, progression: Dictionary, room_type: String) -> Dictionary:
	for seed: int in range(1, 90):
		var state: Dictionary = probe_run_engine.create_new_run(seed, progression)
		if _first_room_coord_of_type(probe_run_engine, state, room_type).x < 900:
			return state
	return {}

func _run_state_for_room(probe_run_engine: RunEngine, source_state: Dictionary, coord: Vector2i, travel_dir: Vector2i) -> Dictionary:
	var state: Dictionary = source_state.duplicate(true)
	var room: Dictionary = probe_run_engine.room_metadata(state, coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = true
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms[_room_key(coord)] = room
	state["rooms"] = rooms
	state["current_room"] = coord
	state["current_room_layout"] = probe_run_engine.call("_display_layout_for_room", int(state.get("seed", 0)), room, travel_dir)
	state["mode"] = "room"
	state["combat_state"] = {}
	state["pending_reward"] = {}
	state["pending_relics"] = []
	return state

func _first_room_coord_of_type(probe_run_engine: RunEngine, state: Dictionary, room_type: String) -> Vector2i:
	if state.is_empty():
		return Vector2i(999, 999)
	for radius: int in range(1, RunEngine.MAX_DEPTH + 1):
		for x: int in range(-radius, radius + 1):
			for y: int in range(-radius, radius + 1):
				var coord := Vector2i(x, y)
				if maxi(absi(x), absi(y)) != radius:
					continue
				if str(probe_run_engine.room_metadata(state, coord).get("type", "")) == room_type:
					return coord
	return Vector2i(999, 999)

func _settle_visuals() -> void:
	await process_frame
	await process_frame
	await create_timer(0.18).timeout
	await process_frame

func _verify_merchant_door_access(instance: Node, probe_run_engine: RunEngine) -> void:
	var trade_panel: Control = instance.find_child("MerchantTradePanel", true, false) as Control
	var show_doors_button: Button = instance.find_child("MerchantShowDoorsButton", true, false) as Button
	if trade_panel == null or show_doors_button == null:
		_fail("Merchant shop should provide a Show Doors action")
		return
	var board: Control = instance.get("board_view") as Control
	var run_state: Dictionary = instance.get("_run_state") as Dictionary
	var panel_rect: Rect2 = trade_panel.get_global_rect()
	var covered_option: Dictionary = {}
	for option_var: Variant in probe_run_engine.exit_options(run_state):
		var option: Dictionary = option_var as Dictionary
		var door_tile: Vector2i = option.get("door_tile", Vector2i(-1, -1))
		var door_center: Vector2 = board.get_global_transform() * (board.call("_tile_center", door_tile) as Vector2)
		if panel_rect.has_point(door_center):
			covered_option = option
			break
	if covered_option.is_empty():
		_fail("1280x720 merchant fixture should reproduce a valid door covered by the open shop")
		return

	show_doors_button.pressed.emit()
	await _settle_visuals()
	if instance.find_child("MerchantTradePanel", true, false) != null:
		_fail("Show Doors should remove the blocking merchant panel")
		return
	var return_to_shop_button: Button = _button_with_text(instance, "Return to Shop")
	if return_to_shop_button == null or not return_to_shop_button.is_visible_in_tree():
		_fail("Collapsed merchant shop should provide a Return to Shop action")
		return
	await _save_root_screenshot("%s/blacksmith_doors_revealed.png" % OUTPUT_DIR)
	var revealed_state: Dictionary = instance.get("_run_state") as Dictionary
	for option_var: Variant in probe_run_engine.exit_options(revealed_state):
		var option: Dictionary = option_var as Dictionary
		var option_tile: Vector2i = option.get("door_tile", Vector2i(-1, -1))
		var option_center: Vector2 = board.call("_tile_center", option_tile) as Vector2
		var option_global_center: Vector2 = board.get_global_transform() * option_center
		if return_to_shop_button.get_global_rect().has_point(option_global_center):
			_fail("Return to Shop should not replace the merchant panel with another blocked door")
			return
		if board.call("_tile_at_point", option_center) != option_tile:
			_fail("Every revealed merchant door should retain clickable board geometry")
			return

	var destination: Vector2i = covered_option.get("coord", Vector2i(999, 999))
	var door_tile: Vector2i = covered_option.get("door_tile", Vector2i(-1, -1))
	var door_center: Vector2 = board.call("_tile_center", door_tile) as Vector2

	return_to_shop_button.pressed.emit()
	await _settle_visuals()
	var reopened_panel: Control = instance.find_child("MerchantTradePanel", true, false) as Control
	var reopened_show_doors: Button = instance.find_child("MerchantShowDoorsButton", true, false) as Button
	if reopened_panel == null or reopened_show_doors == null:
		_fail("Return to Shop should restore the merchant trade panel")
		return
	await instance.call("_on_cancel_requested")
	await _settle_visuals()
	if instance.find_child("MerchantTradePanel", true, false) != null or _button_with_text(instance, "Return to Shop") == null:
		_fail("Cancel should collapse an open merchant shop to reveal its doors")
		return
	await _send_board_left_click(board, door_center)
	await create_timer(1.0).timeout
	await process_frame
	var moved_state: Dictionary = instance.get("_run_state") as Dictionary
	if moved_state.get("current_room", Vector2i(999, 999)) != destination:
		_fail("A door previously covered by the merchant panel should be clickable after Show Doors")

func _send_board_left_click(board: Control, position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	press.global_position = board.get_global_transform() * position
	board.call("_gui_input", press)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	release.global_position = board.get_global_transform() * position
	board.call("_gui_input", release)
	await process_frame

func _button_with_text(root_node: Node, text: String) -> Button:
	for child: Node in root_node.find_children("*", "Button", true, false):
		var button: Button = child as Button
		if button != null and button.text == text:
			return button
	return null

func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func _save_root_screenshot(output_path: String) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
	if image.get_size() != PROBE_VIEWPORT:
		image.resize(PROBE_VIEWPORT.x, PROBE_VIEWPORT.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(output_path)

func _clear_probe_output(output_dir: String) -> void:
	var absolute_dir: String = ProjectSettings.globalize_path(output_dir)
	_clear_probe_output_absolute(absolute_dir)

func _clear_probe_output_absolute(absolute_dir: String) -> void:
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
			_clear_probe_output_absolute(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()

func _fail(message: String) -> void:
	_failed = true
	push_error(message)

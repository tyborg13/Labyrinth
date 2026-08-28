extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const GameData = preload("res://scripts/game_data.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const InputRouter = preload("res://scripts/input_router.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const ItemSuite = preload("res://tests/suites/item_pickup_suite.gd")

var _viewport: SubViewport
var _scene: Node
var _router: Node
var _output: String
var _errors: Array[String] = []

func _physical_size() -> Vector2i:
	return Vector2i(1920, 1080)

func _logical_size() -> Vector2i:
	return _physical_size()

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_output = "user://item_pickup_proof_%dx%d_v1" % [_physical_size().x, _physical_size().y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	ProgressionStore.set_storage_path("user://pickup_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://pickup_probe_run.save")
	SettingsStore.set_storage_path("user://pickup_probe_settings.json")
	InputRouter.ensure_input_map()
	_router = root.get_node("InputRouter")
	_viewport = SubViewport.new()
	_viewport.size = _physical_size()
	_viewport.size_2d_override = _logical_size()
	_viewport.size_2d_override_stretch = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(_scene)
	await _settle()
	_scene.call("_close_dialogue")
	var tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
	var progression: Dictionary = _scene.get("_progression")
	for prompt_id: String in tutorial.prompt_ids():
		progression = tutorial.resolve_progression(progression, prompt_id)
	_scene.set("_progression", progression)
	await _load_fixture()
	await _save("01_spaced_pickups.png")
	var board: Control = _scene.get("board_view")
	for loot: Dictionary in (_scene.get("_combat_state") as Dictionary).get("loot", []):
		var rect: Rect2 = board.call("_loot_rect_for_tile", loot["pos"], board.call("_loot_texture", loot), loot)
		_require(not str(board.call("_get_tooltip", rect.get_center())).is_empty(), "Pointer can hit the actual floating pickup")
	var pointer_panel: Control = board.call("_make_custom_tooltip", "item:crimson_draught")
	pointer_panel.position = Vector2(300, 150)
	var pointer_layer := CanvasLayer.new()
	pointer_layer.layer = 500
	_viewport.add_child(pointer_layer)
	pointer_layer.add_child(pointer_panel)
	await _save("02_pointer_item_card.png")
	pointer_layer.queue_free()
	await _focus_pickup(Vector2i(6, 6), "equipment:iron_cleaver", "03_controller_equipment_cards.png")
	await _focus_pickup(Vector2i(2, 3), "item:crimson_draught", "04_controller_item_card.png")
	# Both D-pad snap and free analog processing must preserve the same real cards.
	_scene.call("_controller_process_board_cursor", 0.0)
	await _settle()
	_assert_rich_panel("item:crimson_draught")
	_router.call("set_forced_state_for_test", InputRouter.MODALITY_POINTER, InputRouter.FAMILY_XBOX)
	await _settle()
	_require(not (_scene.get("_controller_analog_cursor") as Control).visible, "Pointer handoff clears controller inspection")
	_scene.call("_begin_player_movement_selection")
	_scene.call("_commit_player_movement", Vector2i(2, 3))
	var found_banner: bool = false
	var banner_deadline: int = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < banner_deadline:
		await process_frame
		var banner: Label = _scene.find_child("LoadoutAcquisitionBanner", true, false)
		if banner != null and banner.text == "ITEM FOUND" and banner.modulate.a > 0.7:
			found_banner = true
			await _save("05_item_found_animation.png", false)
			break
	_require(found_banner, "Live movement uses Item Found acquisition flair")
	var completion_deadline: int = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < completion_deadline:
		if not bool(_scene.get("_animation_lock")):
			break
		await process_frame
	_require(not bool(_scene.get("_animation_lock")), "Collection animation completes")
	var state: Dictionary = _scene.get("_combat_state")
	_require((state["deck"]["hand"] as Array).has("crimson_draught"), "Live collection makes the item immediately playable")
	await _save("06_collected_item_in_hand.png")
	_scene.call("_open_character_overlay", "equipment")
	await _save("07_active_item_slot.png")
	_scene.call("_close_card_upgrade_overlay")
	await _settle()
	await _load_fixture([], ["quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab"])
	await _focus_pickup(Vector2i(2, 3), "item:crimson_draught", "08_full_hand_draw_preview.png")
	await _collect_without_motion()
	state = _scene.get("_combat_state")
	_require(state["deck"]["hand"].size() == 7 and state["deck"]["draw"].back() == "crimson_draught", "The full-hand live UI keeps its cap and queues the pickup")
	await _save("09_full_hand_after_pickup.png")
	await _load_fixture(["nail_bomb", "smoke_bomb"], ["nail_bomb", "smoke_bomb", "quick_stab"])
	await _focus_pickup(Vector2i(2, 3), "item:crimson_draught", "10_full_slots_inventory_preview.png")
	await _collect_without_motion()
	state = _scene.get("_combat_state")
	_require(state["item_inventory"] == ["crimson_draught"] and not state["deck"]["hand"].has("crimson_draught"), "Both occupied slots send the pickup only to inventory")
	_scene.call("_open_character_overlay", "equipment")
	await _save("11_stored_item_inventory.png")
	_scene.call("_close_card_upgrade_overlay")
	await _load_fixture()
	var settings: Dictionary = _scene.get("_settings")
	settings["reduced_motion"] = true
	_scene.set("_settings", settings)
	_scene.call("_refresh_ui")
	await _settle()
	board = _scene.get("board_view")
	_require(is_equal_approx(float(board.call("_equipment_pickup_pulse", Vector2i(2, 3), {"kind": "item"})), 0.5), "Reduced motion leaves a stable floating pickup beacon")
	await _save("12_reduced_motion.png")
	if _physical_size().x == 1920:
		await _card_sheet()
	await _capture_movement_alignment()
	_router.call("clear_forced_state_for_test")
	_scene.queue_free()
	await process_frame
	for error: String in _errors:
		push_error(error)
	print(ProjectSettings.globalize_path(_output))
	print("ITEM PICKUP PROBE: ", "PASS" if _errors.is_empty() else "FAIL")
	quit(0 if _errors.is_empty() else 1)

func _load_fixture(equipped: Array = [], hand: Array = ["quick_stab", "bone_dart", "shadow_step"]) -> void:
	_router.call("set_forced_state_for_test", InputRouter.MODALITY_POINTER, InputRouter.FAMILY_XBOX)
	var combat: Dictionary = ItemSuite._state(equipped, hand)
	combat["loot"] = [
		{"id": "probe_item_a", "kind": "item", "card_id": "crimson_draught", "pos": Vector2i(2, 3)},
		{"id": "probe_item_b", "kind": "item", "card_id": "nail_bomb", "pos": Vector2i(6, 1)},
		{"id": "probe_gear", "kind": "equipment", "equipment_id": "iron_cleaver", "pos": Vector2i(6, 6)}
	]
	var engine := RunEngine.new()
	var run_state: Dictionary = engine.create_new_run(82, _scene.get("_progression"))
	run_state["current_room"] = Vector2i(1, 0)
	run_state["current_room_layout"] = combat.duplicate(true)
	run_state["mode"] = "combat"
	run_state = engine.set_combat_state(run_state, combat)
	_scene.set("_run_state", run_state)
	# Use the production state boundary so prior fixture preview rows cannot survive.
	_scene.call("_sync_combat_state_from_run")
	_scene.set("_animation_lock", false)
	_scene.call("_analytics_initialize_combat_tracker", combat)
	_scene.call("_refresh_ui")
	await _settle()

func _focus_pickup(tile: Vector2i, key: String, filename: String) -> void:
	_router.call("set_forced_state_for_test", InputRouter.MODALITY_CONTROLLER, InputRouter.FAMILY_STEAM_DECK)
	_scene.call("_controller_set_hand_focused", false)
	_scene.set("_controller_region", "board")
	await _settle()
	_scene.call("_controller_set_board_tile", tile)
	await _settle()
	_assert_rich_panel(key)
	await _save(filename)

func _assert_rich_panel(key: String) -> void:
	var cursor: Control = _scene.get("_controller_analog_cursor")
	var panel: Control = cursor.get("_detail_panel")
	_require(cursor.get("_detail_key") == key, "Controller inspection keeps the selected pickup identity")
	_require(panel != null and not panel.find_children("*", "CardWidget", true, false).is_empty(), "Controller inspection contains actual CardWidgets")
	if panel != null:
		var rect: Rect2 = panel.get_global_rect()
		_require(Rect2(Vector2.ZERO, Vector2(_logical_size())).encloses(rect), "Rich tooltip is fully inside the target viewport")

func _collect_without_motion() -> void:
	_router.call("set_forced_state_for_test", InputRouter.MODALITY_POINTER, InputRouter.FAMILY_XBOX)
	var settings: Dictionary = _scene.get("_settings")
	settings["reduced_motion"] = true
	_scene.set("_settings", settings)
	_scene.call("_begin_player_movement_selection")
	await _scene.call("_commit_player_movement", Vector2i(2, 3))
	await _settle()

func _card_sheet() -> void:
	var background := ColorRect.new()
	background.color = Color("181312")
	background.size = Vector2(_logical_size())
	var layer := CanvasLayer.new()
	layer.layer = 500
	_viewport.add_child(layer)
	layer.add_child(background)
	var index: int = 0
	for card_id: String in GameData.item_card_ids():
		var card: Control = _scene.call("_build_card_preview_widget", card_id, Vector2(250, 352))
		card.position = Vector2(280 + (index % 5) * 274, 120 + (index / 5) * 395)
		background.add_child(card)
		index += 1
	await _save("13_rebalanced_item_cards_250x352.png")
	layer.queue_free()

func _settle() -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame

func _capture_movement_alignment() -> void:
	# Rebuild a pillar-filled room like the user's inspection. The old blank
	# board fixture did not earn enough adaptive clearance to expose this bug.
	_router.call("set_forced_state_for_test", InputRouter.MODALITY_POINTER, InputRouter.FAMILY_XBOX)
	var settings: Dictionary = _scene.get("_settings")
	settings["reduced_motion"] = false
	_scene.set("_settings", settings)
	var engine := RunEngine.new()
	var run_state: Dictionary = engine.create_new_run(82, _scene.get("_progression"))
	var coord := Vector2i(0, -1)
	var room: Dictionary = engine.room_metadata(run_state, coord)
	var layout: Dictionary = engine.call("_combat_layout_for_room", room, Vector2i(1, 0), run_state)
	layout["player_start"] = Vector2i(1, 1)
	layout["enemies"] = [{"id": 1, "type": "warden", "pos": Vector2i(7, 6), "hp": 40, "max_hp": 40}]
	layout["loot"] = [
		{"id": "route_item_a", "kind": "item", "card_id": "crimson_draught", "pos": Vector2i(2, 1)},
		{"id": "route_item_b", "kind": "item", "card_id": "nail_bomb", "pos": Vector2i(2, 7)},
		{"id": "route_gear", "kind": "equipment", "equipment_id": "iron_cleaver", "pos": Vector2i(7, 4)}
	]
	var cleared_tiles: Array = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(2, 7), Vector2i(7, 4), Vector2i(7, 6), Vector2i(6, 6)]
	for key: String in ["terrain", "traps"]:
		var entries: Array = []
		for entry: Dictionary in layout.get(key, []):
			if not cleared_tiles.has(entry.get("pos")):
				entries.append(entry)
		layout[key] = entries
	var combat: Dictionary = CombatEngine.new().create_combat(82, layout, {"hp": 12, "max_hp": 24, "deck_cards": [], "equipped_items": [], "item_inventory": []})
	combat["deck"] = {"hand": ["quick_stab", "bone_dart", "shadow_step"], "draw": ["pale_spark", "pale_spark", "waning_pulse", "waning_pulse"], "discard": [], "burned": [], "consumed": [], "cycles": 0}
	run_state["current_room"] = coord
	run_state["current_room_layout"] = layout
	run_state["mode"] = "combat"
	_scene.set("_run_state", engine.set_combat_state(run_state, combat))
	_scene.call("_sync_combat_state_from_run")
	_scene.call("_analytics_initialize_combat_tracker", combat)
	_scene.call("_refresh_ui")
	await _settle()
	await _save("14_route_before_pickup.png")
	_scene.call("_begin_player_movement_selection")
	_scene.call("_commit_player_movement", Vector2i(3, 1))
	var movement_captured: bool = false
	var deadline: int = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline and bool(_scene.get("_animation_lock")):
		await process_frame
		var board: Control = _scene.get("board_view")
		var overrides: Dictionary = (board.get("presentation") as Dictionary).get("unit_world_positions", {})
		if not movement_captured and overrides.has("player"):
			movement_captured = true
			await _save("15_route_moving.png", false)
	_require(movement_captured and not bool(_scene.get("_animation_lock")), "Live movement through the item finishes within its deadline")
	combat = _scene.get("_combat_state")
	_require(combat["player"]["pos"] == Vector2i(3, 1) and combat["equipped_items"] == ["crimson_draught"], "The route crosses the item and ends on the next tile")
	await _save("16_route_after_pickup.png")
	var enemy_start: Vector2i = combat["enemies"][0]["pos"]
	for _turn: int in range(4):
		await _scene.call("_on_pass_turn_pressed")
		combat = _scene.get("_combat_state")
		if combat["enemies"][0]["pos"] != enemy_start:
			break
	_require(combat["enemies"][0]["pos"] != enemy_start, "The next enemy movement is exercised after collection")
	await _save("17_route_after_enemy_move.png")
	_scene.call("_begin_player_movement_selection")
	await _scene.call("_commit_player_movement", Vector2i(2, 1))
	combat = _scene.get("_combat_state")
	_require(combat["player"]["pos"] == Vector2i(2, 1), "A later player movement completes after the enemy turn")
	await _save("18_route_later_player_move.png")
	# Resize and zoom use distinct invalidation paths; both must preserve actor
	# alignment, rather than merely fixing the one collection transition.
	var board: Control = _scene.get("board_view")
	board.call("_on_board_resized")
	board.call("set_navigation_zoom", float(board.call("navigation_snapshot")["zoom"]) * 0.95, board.size * 0.5)
	await _save("19_route_after_navigation.png")

func _assert_actor_alignment() -> void:
	var board: Control = _scene.get("board_view")
	var origin: Vector2 = board.call("_board_origin")
	for layer: Control in board.call("_retained_render_layers"):
		_require((layer.call("_board_origin") as Vector2).is_equal_approx(origin), "Every retained layer shares the authoritative floor origin")
		for unit: Dictionary in board.call("_visible_units"):
			var expected: Vector2 = board.call("_unit_center", unit)
			_require((layer.call("_unit_center", unit) as Vector2).is_equal_approx(expected), "Player/enemy centers remain on the same tiles in animated and idle layers")

func _assert_hand_card_content() -> void:
	var state: Dictionary = _scene.get("_combat_state")
	var hand: Array = (state.get("deck", {}) as Dictionary).get("hand", [])
	var hand_box: Control = _scene.get("hand_box")
	var widgets: Array[Node] = hand_box.find_children("*", "CardWidget", true, false)
	_require(widgets.size() == hand.size(), "Every hand card has a matching live widget")
	for index: int in range(mini(widgets.size(), hand.size())):
		var card_id: String = str(hand[index])
		var display: Dictionary = _scene.call("_card_widget_display", card_id, state)
		_require(str(widgets[index].get("card_id")) == card_id, "Hand widget identity matches its card")
		_require(widgets[index].get("_summary_rows") == display.get("summary_rows", []), "Hand actions match the current card, not a previous fixture")

func _save(filename: String, settle: bool = true) -> void:
	if settle:
		await _settle()
	_assert_hand_card_content()
	_assert_actor_alignment()
	var image: Image = _viewport.get_texture().get_image()
	_require(image != null and image.get_size() == _physical_size(), "Screenshot has exact physical resolution")
	if image != null:
		_require(image.save_png(ProjectSettings.globalize_path(_output + "/" + filename)) == OK, "Screenshot saved")

func _require(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)

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
	var requested_width: int = int(OS.get_environment("LABYRINTH_ITEM_PROOF_PHYSICAL_WIDTH"))
	var requested_height: int = int(OS.get_environment("LABYRINTH_ITEM_PROOF_PHYSICAL_HEIGHT"))
	if requested_width > 0 and requested_height > 0:
		return Vector2i(requested_width, requested_height)
	return Vector2i(1920, 1080)

func _logical_size() -> Vector2i:
	var requested_width: int = int(OS.get_environment("LABYRINTH_ITEM_PROOF_LOGICAL_WIDTH"))
	var requested_height: int = int(OS.get_environment("LABYRINTH_ITEM_PROOF_LOGICAL_HEIGHT"))
	if requested_width > 0 and requested_height > 0:
		return Vector2i(requested_width, requested_height)
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
	_assert_multi_pickup_hand_destinations()
	await _assert_pile_interactions()
	var layout_only: bool = OS.get_environment("LABYRINTH_ITEM_PROOF_LAYOUT_ONLY") == "1"
	if layout_only:
		_router.call("set_forced_state_for_test", InputRouter.MODALITY_CONTROLLER, InputRouter.FAMILY_STEAM_DECK)
		_scene.call("_controller_set_hand_focused", false)
		_scene.set("_controller_region", "board")
		await _settle()
	await _save("01_spaced_pickups.png")
	if layout_only:
		await _finish_probe()
		return
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
	var found_hand_ray: bool = false
	var banner_deadline: int = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < banner_deadline:
		await process_frame
		var banner: Label = _scene.find_child("LoadoutAcquisitionBanner", true, false)
		if not found_banner and banner != null and banner.text == "ITEM FOUND" and banner.modulate.a > 0.7:
			found_banner = true
			await _save("05_item_found_animation.png", false)
		var beam: Control = _scene.find_child("LoadoutAcquisitionBeam", true, false) as Control
		if not found_hand_ray and beam != null:
			found_hand_ray = true
			_assert_item_ray(beam, "hand", 3, 4)
			await _save("05b_item_to_hand_ray.png", false)
		if found_banner and found_hand_ray:
			break
	_require(found_banner, "Live movement uses Item Found acquisition flair")
	_require(found_hand_ray, "An immediately playable pickup rays to its future hand slot")
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
	await _collect_and_capture_ray("draw", "08b_item_to_draw_ray.png")
	state = _scene.get("_combat_state")
	_require(state["deck"]["hand"].size() == 7 and state["deck"]["draw"].back() == "crimson_draught", "The full-hand live UI keeps its cap and queues the pickup")
	await _save("09_full_hand_after_pickup.png")
	await _load_fixture(["nail_bomb", "smoke_bomb"], ["nail_bomb", "smoke_bomb", "quick_stab"])
	await _focus_pickup(Vector2i(2, 3), "item:crimson_draught", "10_full_slots_inventory_preview.png")
	await _collect_and_capture_ray("inventory", "10b_item_to_inventory_ray.png")
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
	await _finish_probe()

func _finish_probe() -> void:
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

func _assert_pile_interactions() -> void:
	var draw_pile: Control = _scene.get("draw_pile") as Control
	var discard_pile: Control = _scene.get("discard_pile") as Control
	_require(draw_pile.focus_mode == Control.FOCUS_ALL and discard_pile.focus_mode == Control.FOCUS_ALL, "Relocated piles remain controller focus stops")
	_require(draw_pile.mouse_filter == Control.MOUSE_FILTER_STOP and discard_pile.mouse_filter == Control.MOUSE_FILTER_STOP, "Relocated piles remain pointer targets")
	draw_pile.grab_focus()
	await process_frame
	_require(str(draw_pile.get_meta("pile_interaction_state", "")) == "focus", "Draw pile retains focused controller feedback")
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	_scene.call("_on_pile_gui_input", accept, "draw")
	await _settle()
	_require((_scene.get("_pile_scrim") as Control).visible and str(_scene.get("_active_pile_kind")) == "draw", "Controller accept still opens the relocated draw pile")
	_scene.call("_close_pile_view")
	await _settle()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_scene.call("_on_pile_gui_input", click, "discard")
	await _settle()
	_require((_scene.get("_pile_scrim") as Control).visible and str(_scene.get("_active_pile_kind")) == "discard", "Pointer click still opens the relocated discard pile")
	_scene.call("_close_pile_view")
	draw_pile.release_focus()
	await _settle()

func _assert_multi_pickup_hand_destinations() -> void:
	var before_state: Dictionary = {"deck": {"hand": ["quick_stab"]}}
	var after_state: Dictionary = {"deck": {"hand": ["quick_stab", "nail_bomb", "crimson_draught"]}}
	# The presentation list can differ from path acquisition order. Card identity
	# must still map each beam to the slot that actually receives that pickup.
	var picked_loot: Array = [
		{"id": "second", "kind": "item", "card_id": "crimson_draught", "destination": "hand"},
		{"id": "first", "kind": "item", "card_id": "nail_bomb", "destination": "hand"}
	]
	var indices: Dictionary = _scene.call("_pickup_hand_destination_indices", picked_loot, before_state, after_state)
	_require(int(indices.get("second", -1)) == 2 and int(indices.get("first", -1)) == 1, "Multi-pickup rays target each card's actual appended hand slot")

func _collect_and_capture_ray(expected_kind: String, filename: String) -> void:
	_router.call("set_forced_state_for_test", InputRouter.MODALITY_POINTER, InputRouter.FAMILY_XBOX)
	var settings: Dictionary = _scene.get("_settings")
	settings["reduced_motion"] = false
	_scene.set("_settings", settings)
	var before_state: Dictionary = _scene.get("_combat_state")
	var before_hand_size: int = (((before_state.get("deck", {}) as Dictionary).get("hand", []) as Array).size())
	_scene.call("_begin_player_movement_selection")
	_scene.call("_commit_player_movement", Vector2i(2, 3))
	var found_ray: bool = false
	var deadline: int = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var beam: Control = _scene.find_child("LoadoutAcquisitionBeam", true, false) as Control
		if beam != null:
			found_ray = true
			_assert_item_ray(
				beam,
				expected_kind,
				before_hand_size if expected_kind == "hand" else -1,
				before_hand_size + 1 if expected_kind == "hand" else -1
			)
			await _save(filename, false)
			break
	_require(found_ray, "Pickup animation exposes a ray to the %s destination" % expected_kind)
	var completion_deadline: int = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < completion_deadline and bool(_scene.get("_animation_lock")):
		await process_frame
	_require(not bool(_scene.get("_animation_lock")), "The %s pickup animation completes" % expected_kind)
	await _settle()

func _assert_item_ray(beam: Control, expected_kind: String, hand_index: int = -1, hand_total: int = -1) -> void:
	_require(str(beam.get_meta("acquisition_destination", "")) == expected_kind, "Pickup ray records its %s destination" % expected_kind)
	var target_global: Vector2 = beam.get_meta("acquisition_target_global", Vector2(-1.0, -1.0)) as Vector2
	var fx_layer: Control = _scene.get("_card_fx_layer") as Control
	var rendered_target: Vector2 = fx_layer.global_position + (beam.get("target") as Vector2)
	_require(rendered_target.distance_to(target_global) <= 1.0, "Pickup ray geometry terminates at its recorded destination")
	var expected_target: Vector2 = Vector2.ZERO
	match expected_kind:
		"hand":
			var card_size: Vector2 = _scene.call("_hand_card_size", hand_total, false)
			var card_rect: Rect2 = _scene.call("_hand_receive_rect", hand_index, hand_total, card_size)
			expected_target = card_rect.position + Vector2(card_rect.size.x * 0.5, minf(72.0, card_rect.size.y * 0.24))
			_require(card_rect.grow(1.0).has_point(target_global), "Hand pickup ray lands within the exact future card slot")
		"draw":
			var draw_pile: Control = _scene.get("draw_pile") as Control
			expected_target = draw_pile.get_global_rect().get_center()
			_require(draw_pile.get_global_rect().grow(1.0).has_point(target_global), "Full-hand pickup ray lands on the draw pile")
		"inventory":
			var loadout_button: Control = _scene.get("loadout_button") as Control
			expected_target = loadout_button.get_global_rect().get_center()
			_require(loadout_button.get_global_rect().grow(1.0).has_point(target_global), "Stored pickup ray lands on the inventory affordance")
	_require(target_global.distance_to(expected_target) <= 1.0, "Pickup ray targets the exact %s location" % expected_kind)

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
	_assert_pile_layout(filename)
	var image: Image = _viewport.get_texture().get_image()
	_require(image != null and image.get_size() == _physical_size(), "Screenshot has exact physical resolution")
	if image != null:
		_require(image.save_png(ProjectSettings.globalize_path(_output + "/" + filename)) == OK, "Screenshot saved")

func _assert_pile_layout(filename: String) -> void:
	var piles: Control = _scene.get("piles_bar") as Control
	if piles == null or not piles.is_visible_in_tree():
		return
	var ui_root: Control = _scene.get("ui_root") as Control
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(_logical_size()))
	var piles_rect: Rect2 = piles.get_global_rect()
	_require(piles.get_parent() == ui_root, "Combat piles use the viewport HUD instead of the hand container")
	_require(viewport_rect.grow(1.0).encloses(piles_rect), "Combat piles remain fully onscreen")
	_require(absf(viewport_rect.end.x - piles_rect.end.x - 12.0) <= 1.0, "Combat piles keep the authored right safe margin")
	_require(absf(viewport_rect.end.y - piles_rect.end.y - 12.0) <= 1.0, "Combat piles keep the authored bottom safe margin")
	var draw_rect: Rect2 = (_scene.get("draw_pile") as Control).get_global_rect()
	var discard_rect: Rect2 = (_scene.get("discard_pile") as Control).get_global_rect()
	_require(not draw_rect.intersects(discard_rect) and draw_rect.position.x < discard_rect.position.x, "Draw and discard remain separate and ordered")
	for protected_name: String in ["_play_meter", "_movement_meter", "_pass_preview_overlay", "_turn_order_panel", "_action_step_tracker", "_choice_button_overlay", "_contextual_combat_prompt_host"]:
		var protected: Control = _scene.get(protected_name) as Control
		if protected != null and protected.is_visible_in_tree() and protected.get_global_rect().has_area():
			_require(not piles_rect.intersects(protected.get_global_rect()), "Combat piles do not overlap %s" % protected_name)
	var state: Dictionary = _scene.get("_combat_state")
	var hand: Array = (state.get("deck", {}) as Dictionary).get("hand", [])
	for index: int in range(hand.size()):
		var card_control: Control = _scene.call("_hand_card_control", index) as Control
		if card_control != null and card_control.is_visible_in_tree():
			var card_rect: Rect2 = _scene.call("_control_visual_global_rect", card_control)
			_require(not piles_rect.intersects(card_rect), "Combat piles do not overlap hand card %d" % (index + 1))
	var board: Control = _scene.get("board_view") as Control
	var board_transform: Transform2D = board.get_global_transform()
	for local_rect: Rect2 in board.call("rendered_visual_rects") as Array[Rect2]:
		if not local_rect.has_area():
			continue
		var global_top_left: Vector2 = board_transform * local_rect.position
		var global_bottom_right: Vector2 = board_transform * local_rect.end
		var visual_rect := Rect2(global_top_left, global_bottom_right - global_top_left)
		_require(
			not piles_rect.intersects(visual_rect),
			"Combat piles stay clear of rendered tactical art in %s (piles=%s, visual=%s)" % [filename, piles_rect, visual_rect]
		)

func _require(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)

extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")

const OUTPUT_DIR: String = "user://probes/card_drag_overlay"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	ProgressionStore.set_storage_path("user://labyrinth_progression_card_drag_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_card_drag_probe.save")
	ProgressionStore.clear_saved_run()
	await _capture_drag_overlay_frames()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()

func _capture_drag_overlay_frames() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame

	await _load_combat_fixture(instance, Vector2i(2, 5), Vector2i(3, 5), 9401)
	instance.call("_on_card_drag_started", 0)
	await process_frame
	_position_drag_proxy(instance, Vector2(640.0, 420.0), "play")
	await process_frame
	_assert_drag_proxy_size(instance, "first drag", Vector2(640.0, 420.0))
	await _save_root_screenshot("%s/playable_zones.png" % OUTPUT_DIR)
	await instance.call("_animate_drag_cancel_to_source")
	await process_frame

	await _load_combat_fixture(instance, Vector2i(2, 5), Vector2i(6, 5), 9402)
	instance.call("_on_card_drag_started", 0)
	await process_frame
	_position_drag_proxy(instance, Vector2(640.0, 458.0), "move")
	await process_frame
	_assert_drag_proxy_size(instance, "reused fallback drag", Vector2(640.0, 458.0))
	await _save_root_screenshot("%s/fallback_only_zones.png" % OUTPUT_DIR)
	await instance.call("_animate_drag_cancel_to_source")
	await process_frame

	await _load_combat_fixture(instance, Vector2i(2, 5), Vector2i(3, 5), 9403)
	instance.call("_on_card_drag_started", 0)
	await process_frame
	_position_drag_proxy(instance, Vector2(122.0, 118.0), "")
	await process_frame
	_assert_drag_proxy_size(instance, "reused invalid-drop drag", Vector2(122.0, 118.0))
	await _save_root_screenshot("%s/invalid_drop_before_release.png" % OUTPUT_DIR)
	await instance.call("_commit_drag_drop", "")
	await process_frame
	await process_frame
	await _save_root_screenshot("%s/invalid_drop_after_snapback.png" % OUTPUT_DIR)

	await _capture_card_motion_frames(instance)

	instance.queue_free()
	await process_frame

func _capture_card_motion_frames(instance: Node) -> void:
	await _load_combat_fixture(instance, Vector2i(2, 5), Vector2i(3, 5), 9404)
	var card_id: String = str(instance.call("_card_id_for_hand_index", 0))
	var source_rect: Rect2 = instance.call("_hand_card_global_rect", 0)
	if card_id.is_empty() or source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		push_error("Card motion proof requires a visible hand card")
		return
	instance.set("_animating_hand_card_index", 0)
	instance.call("_refresh_ui")
	await process_frame
	instance.call("_animate_card_play_fx", card_id, source_rect, source_rect.size)
	await create_timer(0.12).timeout
	_assert_card_fx_proxy_sizes(instance, "play arc")
	await _save_root_screenshot("%s/play_arc.png" % OUTPUT_DIR)
	await create_timer(0.19).timeout
	var staged_proxy: Control = _first_card_fx_proxy(instance)
	if staged_proxy == null:
		push_error("Played card should reach center for a short readable beat")
	else:
		_assert_play_proxy_grew(staged_proxy, source_rect.size)
	await _save_root_screenshot("%s/play_center_grown.png" % OUTPUT_DIR)
	await create_timer(0.08).timeout
	await _save_root_screenshot("%s/play_center_beat.png" % OUTPUT_DIR)
	await create_timer(0.04).timeout

	var staged_proxy_id: int = staged_proxy.get_instance_id() if staged_proxy != null else 0
	instance.call("_animate_card_to_pile_fx", card_id, "discard", source_rect.size, staged_proxy)
	await create_timer(0.11).timeout
	_assert_card_fx_proxy_sizes(instance, "discard arc")
	var discard_proxy: Control = _first_card_fx_proxy(instance)
	if discard_proxy == null or discard_proxy.get_instance_id() != staged_proxy_id:
		push_error("Discard flight should continue with the exact staged play proxy")
	await _save_root_screenshot("%s/discard_arc.png" % OUTPUT_DIR)
	await create_timer(0.12).timeout
	await _save_root_screenshot("%s/discard_tuck.png" % OUTPUT_DIR)
	await create_timer(0.08).timeout
	if _first_card_fx_proxy(instance) != null:
		push_error("Played card should leave the board before action animations begin")
	await _save_root_screenshot("%s/action_stage_clear.png" % OUTPUT_DIR)

	instance.set("_animating_hand_card_index", -1)
	var draw_entries: Array = [
		{"card_id": "brace", "index": 1, "total": 3},
		{"card_id": "lantern_shot", "index": 2, "total": 3}
	]
	instance.call("_animate_draw_cards_fx", draw_entries)
	await create_timer(0.08).timeout
	_assert_card_fx_proxy_sizes(instance, "first draw arc")
	_assert_streamed_draw_launch(instance)
	await _save_root_screenshot("%s/draw_first_launch.png" % OUTPUT_DIR)
	await create_timer(0.12).timeout
	await _save_root_screenshot("%s/draw_stream_handoff.png" % OUTPUT_DIR)
	await create_timer(0.16).timeout
	await _save_root_screenshot("%s/draw_second_flight.png" % OUTPUT_DIR)
	await create_timer(0.14).timeout
	await _save_root_screenshot("%s/draw_second_settle.png" % OUTPUT_DIR)
	if _card_fx_proxy_count(instance) != 2:
		push_error("Both drawn cards should remain staged in their fan slots until the authoritative hand refresh")
	await create_timer(0.16).timeout
	instance.call("_clear_idle_card_fx_layer")
	await process_frame

	var previous_settings: Dictionary = (instance.get("_settings") as Dictionary).duplicate(true)
	instance.set("_settings", {"reduced_motion": true})
	instance.call("_animate_card_consumed_fx", card_id, source_rect.size)
	await create_timer(0.04).timeout
	var reduced_proxy: Control = _first_card_fx_proxy(instance)
	if reduced_proxy == null:
		push_error("Reduced-motion consume proof should have an active proxy")
	else:
		_assert_native_proxy_widget(reduced_proxy.get_child(0) as Control, "reduced-motion consume")
		if not is_zero_approx(reduced_proxy.rotation):
			push_error("Reduced-motion consume should not rotate the card")
	await _save_root_screenshot("%s/consume_reduced_motion.png" % OUTPUT_DIR)
	await create_timer(0.20).timeout
	if _first_card_fx_proxy(instance) != null:
		push_error("Reduced-motion consume should finish on its shortened duration")
	instance.set("_settings", previous_settings)

func _load_combat_fixture(instance: Node, player_pos: Vector2i, enemy_pos: Vector2i, seed: int) -> void:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var layout: Dictionary = _drag_room_layout(player_pos, enemy_pos)
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(seed, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_refresh_ui")
	await process_frame
	await process_frame

func _position_drag_proxy(instance: Node, mouse_position: Vector2, hover_zone: String) -> void:
	var source_rect: Rect2 = instance.get("_drag_card_source_rect")
	if source_rect.size.x > 0.0 and source_rect.size.y > 0.0:
		instance.set("_drag_card_grab_offset", source_rect.size * 0.5)
	instance.call("_update_drag_proxy_position", mouse_position)
	instance.call("_update_drag_overlay_hover", hover_zone)

func _assert_drag_proxy_size(instance: Node, context: String, expected_center: Vector2) -> void:
	var proxy: Control = instance.get("_drag_card_proxy") as Control
	var source_rect: Rect2 = instance.get("_drag_card_source_rect")
	if proxy == null or source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		push_error("%s should have a mounted drag proxy and source geometry" % context)
		return
	var bounds: Rect2 = _transformed_control_bounds(proxy)
	var maximum_size: Vector2 = source_rect.size * 1.18
	var actual_center: Vector2 = proxy.get_global_transform() * proxy.pivot_offset
	var widget: Control = proxy.get_child(0) as Control
	print("DRAG PROXY GEOMETRY %s: bounds=%s center=%s expected_center=%s source=%s widget_size=%s" % [context, bounds, actual_center, expected_center, source_rect.size, widget.size])
	_assert_native_proxy_widget(widget, context)
	if actual_center.distance_to(expected_center) > 1.0:
		push_error("%s proxy center missed the cursor grab point: %s versus %s" % [context, actual_center, expected_center])
	if bounds.size.x > maximum_size.x or bounds.size.y > maximum_size.y:
		push_error("%s transformed proxy bounds grew beyond the lifted-card limit: %s from source %s" % [context, bounds.size, source_rect.size])

func _assert_card_fx_proxy_sizes(instance: Node, context: String) -> void:
	var fx_layer: Control = instance.get("_card_fx_layer") as Control
	if fx_layer == null:
		push_error("%s should have a card FX layer" % context)
		return
	for child: Node in fx_layer.get_children():
		if child is Control and child.get_child_count() > 0 and child.get_child(0) is Control:
			_assert_native_proxy_widget(child.get_child(0) as Control, context)

func _assert_native_proxy_widget(widget: Control, context: String) -> void:
	if widget == null or widget.size != Vector2(250.0, 352.0):
		push_error("%s proxy widget must remain 250x352 after pooling, got %s" % [context, widget.size if widget != null else Vector2.ZERO])

func _assert_play_proxy_grew(proxy: Control, source_size: Vector2) -> void:
	var actual_size: Vector2 = proxy.size * proxy.get_global_transform().get_scale().abs()
	var expected_size: Vector2 = source_size * 1.08
	if not _vector2_near(actual_size, expected_size, 2.0):
		push_error("Staged played card should grow smoothly to 108%% of hand size: got %s, expected %s" % [actual_size, expected_size])

func _assert_streamed_draw_launch(instance: Node) -> void:
	var proxies: Array[Control] = _card_fx_proxies(instance)
	if proxies.size() != 2:
		push_error("Streamed draw proof requires two card proxies, got %d" % proxies.size())
		return
	var draw_rect: Rect2 = instance.call("_pile_global_rect", "draw")
	var pile_center: Vector2 = draw_rect.get_center()
	var first_distance: float = _proxy_visual_center(proxies[0]).distance_to(pile_center)
	var second_distance: float = _proxy_visual_center(proxies[1]).distance_to(pile_center)
	if first_distance < 20.0:
		push_error("The first drawn card should visibly lead the stream after 80ms")
	if second_distance > 2.0:
		push_error("The second drawn card should still be waiting at the pile during the first card's launch")

func _first_card_fx_proxy(instance: Node) -> Control:
	var fx_layer: Control = instance.get("_card_fx_layer") as Control
	if fx_layer == null:
		return null
	for child: Node in fx_layer.get_children():
		if child is Control and bool(child.get_meta("scaled_card_proxy", false)):
			return child as Control
	return null

func _card_fx_proxy_count(instance: Node) -> int:
	return _card_fx_proxies(instance).size()

func _card_fx_proxies(instance: Node) -> Array[Control]:
	var proxies: Array[Control] = []
	var fx_layer: Control = instance.get("_card_fx_layer") as Control
	if fx_layer == null:
		return proxies
	for child: Node in fx_layer.get_children():
		if child is Control and bool(child.get_meta("scaled_card_proxy", false)):
			proxies.append(child as Control)
	return proxies

func _proxy_visual_center(proxy: Control) -> Vector2:
	return proxy.get_global_transform() * proxy.pivot_offset

func _transformed_control_bounds(control: Control) -> Rect2:
	var transform: Transform2D = control.get_global_transform()
	var points: Array = [
		transform * Vector2.ZERO,
		transform * Vector2(control.size.x, 0.0),
		transform * control.size,
		transform * Vector2(0.0, control.size.y)
	]
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point_var: Variant in points:
		var point: Vector2 = point_var
		bounds = bounds.expand(point)
	return bounds

func _vector2_near(actual: Vector2, expected: Vector2, tolerance: float) -> bool:
	return absf(actual.x - expected.x) <= tolerance and absf(actual.y - expected.y) <= tolerance

func _drag_room_layout(player_pos: Vector2i, enemy_pos: Vector2i) -> Dictionary:
	return {
		"name": "Card Drag Probe",
		"coord": Vector2i(4, 1),
		"type": "combat",
		"grid": _simple_grid(),
		"player_start": player_pos,
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": enemy_pos,
			"hp": 140,
			"max_hp": 140,
			"block": 0
		}],
		"loot": []
	}

func _simple_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			if x == 0 or y == 0 or x == 7 or y == 7:
				row.append("wall")
			else:
				row.append("ash")
		grid.append(row)
	return grid

func _save_root_screenshot(output_path: String) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
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

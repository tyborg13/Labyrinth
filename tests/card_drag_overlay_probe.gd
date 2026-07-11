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
	_assert_drag_proxy_size(instance, "first drag")
	await _save_root_screenshot("%s/playable_zones.png" % OUTPUT_DIR)
	await instance.call("_animate_drag_cancel_to_source")
	await process_frame

	await _load_combat_fixture(instance, Vector2i(2, 5), Vector2i(6, 5), 9402)
	instance.call("_on_card_drag_started", 0)
	await process_frame
	_position_drag_proxy(instance, Vector2(640.0, 458.0), "move")
	await process_frame
	_assert_drag_proxy_size(instance, "reused fallback drag")
	await _save_root_screenshot("%s/fallback_only_zones.png" % OUTPUT_DIR)
	await instance.call("_animate_drag_cancel_to_source")
	await process_frame

	await _load_combat_fixture(instance, Vector2i(2, 5), Vector2i(3, 5), 9403)
	instance.call("_on_card_drag_started", 0)
	await process_frame
	_position_drag_proxy(instance, Vector2(122.0, 118.0), "")
	await process_frame
	_assert_drag_proxy_size(instance, "reused invalid-drop drag")
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
	await create_timer(0.09).timeout
	_assert_card_fx_proxy_sizes(instance, "play arc")
	await _save_root_screenshot("%s/play_arc.png" % OUTPUT_DIR)
	await create_timer(0.13).timeout
	await _save_root_screenshot("%s/play_settle.png" % OUTPUT_DIR)
	await create_timer(0.07).timeout
	await _save_root_screenshot("%s/play_resolve_fade.png" % OUTPUT_DIR)
	await create_timer(0.12).timeout

	instance.call("_animate_card_to_pile_fx", card_id, "discard", source_rect.size)
	await create_timer(0.08).timeout
	_assert_card_fx_proxy_sizes(instance, "discard arc")
	await _save_root_screenshot("%s/discard_arc.png" % OUTPUT_DIR)
	await create_timer(0.13).timeout
	await _save_root_screenshot("%s/discard_tuck.png" % OUTPUT_DIR)
	await create_timer(0.14).timeout

	instance.set("_animating_hand_card_index", -1)
	var draw_entries: Array = [
		{"card_id": "brace", "index": 1, "total": 3},
		{"card_id": "lantern_shot", "index": 2, "total": 3}
	]
	instance.call("_animate_draw_cards_fx", draw_entries)
	await create_timer(0.08).timeout
	_assert_card_fx_proxy_sizes(instance, "first draw arc")
	await _save_root_screenshot("%s/draw_first_arc.png" % OUTPUT_DIR)
	await create_timer(0.15).timeout
	await _save_root_screenshot("%s/draw_first_settle.png" % OUTPUT_DIR)
	await create_timer(0.14).timeout
	await _save_root_screenshot("%s/draw_second_arc.png" % OUTPUT_DIR)
	await create_timer(0.16).timeout
	await _save_root_screenshot("%s/draw_second_settle.png" % OUTPUT_DIR)
	await create_timer(0.16).timeout

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

func _assert_drag_proxy_size(instance: Node, context: String) -> void:
	var proxy: Control = instance.get("_drag_card_proxy") as Control
	var source_rect: Rect2 = instance.get("_drag_card_source_rect")
	if proxy == null or source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		push_error("%s should have a mounted drag proxy and source geometry" % context)
		return
	var visual_size: Vector2 = proxy.size * proxy.get_global_transform().get_scale().abs()
	var maximum_size: Vector2 = source_rect.size * 1.08
	var widget: Control = proxy.get_child(0) as Control
	print("DRAG PROXY SIZE %s: visual=%s local_scale=%s global_scale=%s source=%s widget_size=%s widget_scale=%s widget_global_scale=%s" % [context, visual_size, proxy.scale, proxy.get_global_transform().get_scale(), source_rect.size, widget.size, widget.scale, widget.get_global_transform().get_scale()])
	_assert_native_proxy_widget(widget, context)
	if visual_size.x > maximum_size.x or visual_size.y > maximum_size.y:
		push_error("%s proxy grew beyond the lifted-card limit: %s from source %s" % [context, visual_size, source_rect.size])

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

extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")

const OUTPUT_DIR: String = "user://probes/card_drag_overlay"
const PROBE_VIEWPORT: Vector2i = Vector2i(1920, 1080)

var _fixture_room_variant: int = 0

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(PROBE_VIEWPORT)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = PROBE_VIEWPORT
	root.size = PROBE_VIEWPORT
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

	await _load_combat_fixture(instance, "quick_stab", Vector2i(3, 5), Vector2i(4, 5), 9401)
	instance.call("_on_card_hover_started", 0)
	await create_timer(0.16).timeout
	var hover_source: Control = instance.call("_hand_card_control", 0) as Control
	var hover_bounds: Rect2 = instance.call("_control_visual_global_rect", hover_source) if hover_source != null else Rect2()
	await _save_root_screenshot("%s/drag_hover_large_arrow_v4.png" % OUTPUT_DIR)
	var initial_grab_ratio := Vector2(0.12, 0.16)
	var drag_start: Vector2 = hover_bounds.position + hover_bounds.size * initial_grab_ratio
	instance.call("_on_card_drag_started", 0, drag_start)
	await process_frame
	var board_rect: Rect2 = (instance.get("board_view") as Control).get_global_rect()
	var cancel_position := Vector2(drag_start.x + 128.0, board_rect.end.y + 54.0)
	await _position_card_drag(instance, cancel_position)
	await process_frame
	_assert_following_card_drag(instance, "pre-board following drag", cancel_position, hover_bounds)
	_assert_proxy_grab_point(instance, cancel_position, initial_grab_ratio, "pre-board following drag")
	await _save_root_screenshot("%s/drag_following_card_arrow_v4.png" % OUTPUT_DIR)
	var follow_proxy: Control = instance.get("_drag_card_proxy") as Control
	var follow_bounds: Rect2 = instance.call("_card_proxy_visual_rect", follow_proxy)
	instance.call("_animate_drag_cancel_to_source")
	await create_timer(0.10).timeout
	var snapping_proxy: Control = instance.get("_drag_card_proxy") as Control
	if snapping_proxy == null:
		push_error("Pre-board snapback should stay visible until it reaches the hand")
	else:
		var snapping_bounds: Rect2 = instance.call("_card_proxy_visual_rect", snapping_proxy)
		if snapping_bounds.size.x > follow_bounds.size.x + 1.0 or snapping_bounds.size.y > follow_bounds.size.y + 1.0:
			push_error("Pre-board snapback should settle smaller instead of growing through the stale hover pose")
	await _save_root_screenshot("%s/drag_snapback_settling_v4.png" % OUTPUT_DIR)
	await create_timer(0.10).timeout
	await process_frame

	await _load_combat_fixture(instance, "quick_stab", Vector2i(3, 5), Vector2i(4, 5), 9402)
	drag_start = _drag_start_position(instance, 0)
	instance.call("_on_card_drag_started", 0, drag_start)
	await process_frame
	var valid_target_position: Vector2 = _tile_global_position(instance, Vector2i(4, 5))
	await _position_card_drag(instance, valid_target_position)
	await process_frame
	_assert_targeting_drag(instance, "center valid targeting", valid_target_position, hover_bounds)
	await _save_root_screenshot("%s/drag_arrow_center_valid_v4.png" % OUTPUT_DIR)

	var left_target_position := Vector2(board_rect.position.x + 36.0, board_rect.position.y + board_rect.size.y * 0.26)
	await _position_card_drag(instance, left_target_position)
	await process_frame
	_assert_targeting_drag(instance, "hard-left targeting", left_target_position, hover_bounds)
	await _save_root_screenshot("%s/drag_arrow_hard_left_v4.png" % OUTPUT_DIR)

	var right_target_position := Vector2(board_rect.end.x - 36.0, board_rect.position.y + board_rect.size.y * 0.26)
	await _position_card_drag(instance, right_target_position)
	await process_frame
	_assert_targeting_drag(instance, "hard-right targeting", right_target_position, hover_bounds)
	await _save_root_screenshot("%s/drag_arrow_hard_right_v4.png" % OUTPUT_DIR)

	var short_target_position := Vector2(board_rect.get_center().x + 72.0, board_rect.end.y - 92.0)
	await _position_card_drag(instance, short_target_position)
	await process_frame
	_assert_targeting_drag(instance, "short targeting", short_target_position, hover_bounds)
	await _save_root_screenshot("%s/drag_arrow_short_v4.png" % OUTPUT_DIR)

	var outside_target_position := Vector2(board_rect.position.x - 92.0, board_rect.end.y + 42.0)
	await _position_card_drag(instance, outside_target_position)
	await process_frame
	_assert_targeting_drag(instance, "latched outside-board targeting", outside_target_position, hover_bounds)
	await _save_root_screenshot("%s/drag_arrow_outside_latched_v4.png" % OUTPUT_DIR)

	await _position_card_drag(instance, right_target_position)
	await process_frame
	await instance.call("_commit_drag_drop", "play", right_target_position)
	await process_frame
	if int(instance.get("_drag_card_index")) >= 0 or int(instance.get("_selected_card_index")) >= 0:
		push_error("Invalid targeted release should return to the idle hand")
	if _turn_order_has_card_projection(instance, "Quick Stab"):
		push_error("Invalid targeted release should remove its Turn Clock projection")
	await _save_root_screenshot("%s/drag_invalid_cancel_restored_v4.png" % OUTPUT_DIR)

	await _load_combat_fixture(instance, "stone_plate", Vector2i(2, 5), Vector2i(5, 5), 9403)
	drag_start = _drag_start_position(instance, 0)
	instance.call("_on_card_drag_started", 0, drag_start)
	await process_frame
	var targetless_board_position: Vector2 = (instance.get("board_view") as Control).get_global_rect().get_center()
	await _position_card_drag(instance, targetless_board_position)
	await process_frame
	_assert_targetless_board_drag(instance, targetless_board_position)
	await _save_root_screenshot("%s/drag_targetless_following_v4.png" % OUTPUT_DIR)
	await instance.call("_animate_drag_cancel_to_source")
	await process_frame

	var input_router: Node = root.get_node_or_null("InputRouter")
	if input_router != null and input_router.has_method("clear_forced_state_for_test"):
		input_router.call("clear_forced_state_for_test")
	await _load_combat_fixture(instance, "lantern_shot", Vector2i(2, 5), Vector2i(5, 5), 9407)
	var enemy_tile := Vector2i(5, 5)
	var enemy_position: Vector2 = _tile_global_position(instance, enemy_tile)
	root.warp_mouse(enemy_position)
	instance.call("_on_board_tile_hovered", enemy_tile)
	await process_frame
	await process_frame
	var board: Control = instance.get("board_view") as Control
	var baseline_presentation: Dictionary = board.get("presentation") as Dictionary
	if (baseline_presentation.get("enemy_threat_previews", []) as Array).is_empty():
		push_error("Idle enemy hover proof should expose the crawler's threat preview before card targeting")
	if not _presentation_has_enemy_movement_preview(baseline_presentation):
		push_error("Idle enemy hover proof should include the crawler's movement destination ghost")
	await _save_root_screenshot("%s/enemy_hover_movement_baseline_v4.png" % OUTPUT_DIR)

	await instance.call("_on_card_pressed", 0)
	root.warp_mouse(enemy_position)
	instance.call("_sync_click_targeting_arrow", enemy_position)
	instance.call("_on_board_tile_hovered", enemy_tile)
	await process_frame
	await process_frame
	_assert_click_targeting_arrow(instance, enemy_position, "pointer click targeting")
	var click_presentation: Dictionary = board.get("presentation") as Dictionary
	if not (click_presentation.get("enemy_threat_previews", []) as Array).is_empty():
		push_error("Click targeting should suppress hover-driven enemy threat previews")
	if _presentation_has_enemy_movement_preview(click_presentation):
		push_error("Click targeting should suppress the enemy movement destination ghost")
	if not (board.get("attack_tiles") as Array).has(enemy_tile):
		push_error("Click targeting should keep the card's legal target treatment after suppressing enemy hover evidence")
	await _save_root_screenshot("%s/click_arrow_enemy_hover_suppressed_v4.png" % OUTPUT_DIR)

	instance.call("_open_menu_overlay")
	root.warp_mouse(Vector2(960.0, 540.0))
	await process_frame
	await process_frame
	var modal_arrow: Control = instance.get("_drag_target_arrow") as Control
	if int(instance.get("_selected_card_index")) != 0:
		push_error("Opening a non-destructive menu should preserve the selected targeting card")
	if modal_arrow != null and modal_arrow.visible:
		push_error("The menu should suspend the targeting arrow while it owns the pointer")
	if bool(instance.get_meta("targeting_cursor_suppressed", false)):
		push_error("The menu should release targeting cursor suppression while it owns the pointer")
	var cursor_feedback: Node = root.get_node_or_null("CursorFeedback")
	if cursor_feedback != null and cursor_feedback.has_method("glyph_for_test"):
		var modal_cursor_glyph: Control = cursor_feedback.call("glyph_for_test") as Control
		if modal_cursor_glyph == null or not modal_cursor_glyph.visible:
			push_error("The menu should visibly restore the forged pointer during suspended card targeting")
	await _save_root_screenshot("%s/click_targeting_menu_cursor_restored_v4.png" % OUTPUT_DIR)
	instance.call("_close_menu_overlay")
	root.warp_mouse(enemy_position)
	instance.call("_sync_click_targeting_arrow", enemy_position)
	await process_frame
	_assert_click_targeting_arrow(instance, enemy_position, "menu-close click targeting")

	var click_previous_settings: Dictionary = (instance.get("_settings") as Dictionary).duplicate(true)
	var click_reduced_settings: Dictionary = click_previous_settings.duplicate(true)
	click_reduced_settings["reduced_motion"] = true
	instance.set("_settings", click_reduced_settings)
	instance.call("_sync_click_targeting_arrow", enemy_position)
	await process_frame
	_assert_click_targeting_arrow(instance, enemy_position, "reduced-motion click targeting")
	await _save_root_screenshot("%s/click_arrow_reduced_motion_v4.png" % OUTPUT_DIR)
	instance.set("_settings", click_previous_settings)

	if input_router != null and input_router.has_method("set_forced_state_for_test"):
		input_router.call("set_forced_state_for_test", "controller", "steam_deck")
		await process_frame
		instance.call("_controller_enter_board", true)
		await process_frame
		await process_frame
		var controller_arrow: Control = instance.get("_drag_target_arrow") as Control
		if controller_arrow != null and controller_arrow.visible:
			push_error("Controller handoff should preserve board focus without following the stale mouse with a pointer arrow")
		if bool(instance.get_meta("targeting_cursor_suppressed", false)):
			push_error("Controller modality should release pointer-only cursor suppression")
		await _save_root_screenshot("%s/click_targeting_controller_handoff_v4.png" % OUTPUT_DIR)

		input_router.call("set_forced_state_for_test", "pointer", "steam_deck")
		await process_frame
		root.warp_mouse(enemy_position)
		instance.call("_sync_click_targeting_arrow", enemy_position)
		await process_frame
		_assert_click_targeting_arrow(instance, enemy_position, "pointer handoff targeting")
		await _save_root_screenshot("%s/click_arrow_pointer_handoff_restored_v4.png" % OUTPUT_DIR)

	instance.call("_cancel_card_selection")
	root.warp_mouse(enemy_position)
	instance.call("_on_board_tile_hovered", enemy_tile)
	await process_frame
	await process_frame
	var cancel_arrow: Control = instance.get("_drag_target_arrow") as Control
	if int(instance.get("_selected_card_index")) >= 0 or (cancel_arrow != null and cancel_arrow.visible):
		push_error("Click-targeting cancel should restore the idle hand and clear the arrow")
	if int((instance.get("hand_box") as Control).call("emphasized_index")) != -1:
		push_error("Click-targeting cancel should release the selected-card hand pose")
	if bool(instance.get_meta("targeting_cursor_suppressed", false)):
		push_error("Click-targeting cancel should restore the forged pointer")
	var restored_presentation: Dictionary = board.get("presentation") as Dictionary
	if (restored_presentation.get("enemy_threat_previews", []) as Array).is_empty():
		push_error("Click-targeting cancel should restore ordinary enemy hover forecasts")
	await _save_root_screenshot("%s/click_arrow_cancel_cursor_restored_v4.png" % OUTPUT_DIR)

	await _load_combat_fixture(instance, "stone_plate", Vector2i(2, 5), Vector2i(5, 5), 9408)
	await instance.call("_on_card_pressed", 0)
	await process_frame
	if not bool(instance.call("_pending_card_requires_confirmation")):
		push_error("Targetless first click should settle into its normal confirmation state")
	if int((instance.get("hand_box") as Control).call("emphasized_index")) != 0:
		push_error("Targetless first click should visibly retain the restrained selected-card pose")
	var targetless_click_arrow: Control = instance.get("_drag_target_arrow") as Control
	if targetless_click_arrow != null and targetless_click_arrow.visible:
		push_error("Targetless click confirmation should not show a spatial targeting arrow")
	if bool(instance.get_meta("targeting_cursor_suppressed", false)):
		push_error("Targetless click confirmation should leave the normal pointer available")
	await _save_root_screenshot("%s/targetless_second_click_ready_v4.png" % OUTPUT_DIR)
	instance.call("_on_card_pressed", 0)
	await _wait_for_card_fx_proxy(instance, 1.0)
	await create_timer(0.08).timeout
	if str(instance.get_meta("last_card_play_source_kind", "")) != "hand":
		push_error("Targetless second click should confirm through the normal hand-origin play path")
	if targetless_click_arrow != null and targetless_click_arrow.visible:
		push_error("Targetless second-click play launch should remain free of the targeting arrow")
	if _first_card_fx_proxy(instance) == null:
		push_error("Targetless second-click confirmation should visibly launch the played card from the hand")
	await _save_root_screenshot("%s/targetless_second_click_launch_v4.png" % OUTPUT_DIR)
	await _wait_for_card_resolution(instance, 4.0)
	if bool(instance.get("_animation_lock")):
		push_error("Targetless second-click proof should finish before the next independent drag fixture")

	await _load_combat_fixture(instance, "quick_stab", Vector2i(3, 5), Vector2i(4, 5), 9404)
	var previous_settings: Dictionary = (instance.get("_settings") as Dictionary).duplicate(true)
	instance.set("_settings", {"reduced_motion": true})
	drag_start = _drag_start_position(instance, 0)
	instance.call("_on_card_drag_started", 0, drag_start)
	await process_frame
	valid_target_position = _tile_global_position(instance, Vector2i(4, 5))
	await _position_card_drag(instance, valid_target_position)
	await process_frame
	_assert_targeting_drag(instance, "reduced-motion targeted drag", valid_target_position, Rect2())
	var hand_box: Control = instance.get("hand_box") as Control
	if hand_box == null or int(hand_box.call("emphasized_index")) != 0:
		push_error("Reduced-motion targeting should immediately use the raised selected-card pose")
	await _save_root_screenshot("%s/drag_arrow_reduced_motion_v4.png" % OUTPUT_DIR)
	await instance.call("_animate_drag_cancel_to_source")
	instance.set("_settings", previous_settings)
	await process_frame

	await _load_combat_fixture(instance, "quick_stab", Vector2i(3, 5), Vector2i(4, 5), 9406)
	drag_start = _drag_start_position(instance, 0)
	instance.call("_on_card_drag_started", 0, drag_start)
	await process_frame
	valid_target_position = _tile_global_position(instance, Vector2i(4, 5))
	await _position_card_drag(instance, valid_target_position)
	instance.call("_commit_drag_drop", "play", valid_target_position)
	await create_timer(0.10).timeout
	_assert_drag_play_launch(instance)
	await _save_root_screenshot("%s/drag_play_launch_from_hand_v4.png" % OUTPUT_DIR)
	await create_timer(0.85).timeout

	if input_router != null and input_router.has_method("clear_forced_state_for_test"):
		input_router.call("clear_forced_state_for_test")

	instance.queue_free()
	await process_frame

func _capture_card_motion_frames(instance: Node) -> void:
	await _load_combat_fixture(instance, "quick_stab", Vector2i(2, 5), Vector2i(3, 5), 9405)
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

func _load_combat_fixture(instance: Node, card_id: String, player_pos: Vector2i, enemy_pos: Vector2i, seed: int) -> void:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var layout: Dictionary = _drag_room_layout(player_pos, enemy_pos)
	# Each probe fixture represents a fresh room. Give it a distinct coordinate so
	# ambient intensity transitions from the preceding card cannot bleed into the
	# next independently asserted screenshot while keeping the displayed depth at 4.
	_fixture_room_variant = 1 - _fixture_room_variant
	layout["coord"] = Vector2i(4, _fixture_room_variant)
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(seed, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": [card_id],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = [card_id]
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
	instance.call("_mark_combat_preview_state_changed")
	instance.call("_refresh_ui")
	await process_frame
	await process_frame

func _position_card_drag(instance: Node, mouse_position: Vector2) -> void:
	await instance.call("_update_card_drag", mouse_position)

func _tile_global_position(instance: Node, tile: Vector2i) -> Vector2:
	var board: Control = instance.get("board_view") as Control
	return board.get_global_transform_with_canvas() * (board.call("world_position_for_tile", tile) as Vector2)

func _drag_start_position(instance: Node, hand_index: int) -> Vector2:
	return (instance.call("_hand_card_global_rect", hand_index) as Rect2).get_center()

func _assert_no_drag_copy(instance: Node, context_name: String) -> void:
	var tracker: Control = instance.get("_action_step_tracker") as Control
	if tracker != null and tracker.visible:
		push_error("%s should not add instructional side copy during a spatial drag interaction" % context_name)

func _assert_click_targeting_arrow(instance: Node, cursor_position: Vector2, context: String) -> void:
	if int(instance.get("_selected_card_index")) < 0 or int(instance.get("_drag_card_index")) >= 0:
		push_error("%s should keep a clicked card selected without creating drag state" % context)
	var source_card: Control = instance.call("_hand_card_control", int(instance.get("_selected_card_index"))) as Control
	if source_card == null or not source_card.is_visible_in_tree():
		push_error("%s should keep the selected card visible and raised in the hand" % context)
	var hand_box: Control = instance.get("hand_box") as Control
	if hand_box == null or int(hand_box.call("emphasized_index")) != int(instance.get("_selected_card_index")):
		push_error("%s should use the restrained selected-card hand pose instead of the large hover preview" % context)
	var arrow: Control = instance.get("_drag_target_arrow") as Control
	if arrow == null or not arrow.visible:
		push_error("%s should show the shared targeting arrow" % context)
	else:
		if not bool(arrow.get_meta("raster_composed_arrow", false)) or not bool(arrow.get_meta("segmented_raster_arrow", false)):
			push_error("%s should use the authored segmented raster arrow" % context)
		var arrow_transform: Transform2D = arrow.get_global_transform_with_canvas()
		var endpoint: Vector2 = arrow_transform * (arrow.call("targeting_end") as Vector2)
		if endpoint.distance_to(cursor_position) > 1.0:
			push_error("%s arrowhead should follow the live pointer, got %s instead of %s" % [context, endpoint, cursor_position])
	if not bool(instance.get_meta("targeting_cursor_suppressed", false)):
		push_error("%s should suppress the ordinary pointer while the arrow owns targeting" % context)
	var cursor_feedback: Node = root.get_node_or_null("CursorFeedback")
	if cursor_feedback != null and cursor_feedback.has_method("glyph_visibility_suppressed"):
		if not bool(cursor_feedback.call("glyph_visibility_suppressed")):
			push_error("%s should register forged-pointer suppression with CursorFeedback" % context)
		if cursor_feedback.has_method("glyph_for_test"):
			var cursor_glyph: Control = cursor_feedback.call("glyph_for_test") as Control
			if cursor_glyph != null and cursor_glyph.visible:
				push_error("%s should hide the forged pointer glyph instead of layering it over the arrowhead" % context)

func _wait_for_card_resolution(instance: Node, timeout_seconds: float) -> void:
	var deadline_msec: int = Time.get_ticks_msec() + roundi(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline_msec:
		if not bool(instance.get("_animation_lock")) and int(instance.get("_selected_card_index")) < 0:
			return
		await process_frame

func _wait_for_card_fx_proxy(instance: Node, timeout_seconds: float) -> void:
	var deadline_msec: int = Time.get_ticks_msec() + roundi(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline_msec:
		if _first_card_fx_proxy(instance) != null:
			return
		await process_frame

func _presentation_has_enemy_movement_preview(presentation: Dictionary) -> bool:
	for preview_var: Variant in presentation.get("preview_units", []):
		if typeof(preview_var) == TYPE_DICTIONARY and str((preview_var as Dictionary).get("role", "")) == "enemy_move_preview":
			return true
	return false

func _assert_following_card_drag(instance: Node, context: String, cursor_position: Vector2, hover_bounds: Rect2) -> void:
	var proxy: Control = instance.get("_drag_card_proxy") as Control
	if proxy == null:
		push_error("%s should keep a small card attached to the pointer before board entry" % context)
		return
	var source_card: Control = instance.call("_hand_card_control", int(instance.get("_drag_card_index"))) as Control
	if source_card == null or source_card.is_visible_in_tree():
		push_error("%s should hide the duplicate hand copy while the card follows the pointer" % context)
	var proxy_bounds: Rect2 = instance.call("_card_proxy_visual_rect", proxy)
	if not proxy_bounds.grow(8.0).has_point(cursor_position):
		push_error("%s should visibly stay attached to the pointer" % context)
	if hover_bounds.size.x > 0.0 and (proxy_bounds.size.x >= hover_bounds.size.x - 1.0 or proxy_bounds.size.y >= hover_bounds.size.y - 1.0):
		push_error("%s should shrink below the large hover preview before following the pointer" % context)
	var arrow: Control = instance.get("_drag_target_arrow") as Control
	if bool(instance.get("_drag_targeting_active")) or (arrow != null and arrow.visible):
		push_error("%s should not show the targeting arrow before board entry" % context)
	_assert_no_drag_copy(instance, context)

func _assert_proxy_grab_point(instance: Node, cursor_position: Vector2, grab_ratio: Vector2, context: String) -> void:
	var proxy: Control = instance.get("_drag_card_proxy") as Control
	if proxy == null:
		return
	var pointer_local: Vector2 = proxy.get_global_transform().affine_inverse() * cursor_position
	var expected_local: Vector2 = proxy.size * grab_ratio
	if pointer_local.distance_to(expected_local) > 2.0:
		push_error("%s should preserve its off-center grab point under the pointer" % context)

func _assert_targeting_drag(instance: Node, context: String, cursor_position: Vector2, hover_bounds: Rect2) -> void:
	if instance.get("_drag_card_proxy") != null:
		push_error("%s should replace the following card with the targeting arrow" % context)
	var source_card: Control = instance.call("_hand_card_control", int(instance.get("_drag_card_index"))) as Control
	if source_card == null or not source_card.is_visible_in_tree():
		push_error("%s should restore the selected card visibly in the hand" % context)
		return
	if not bool(source_card.get_meta("drag_hand_origin", false)):
		push_error("%s should mark the restored hand card as the active targeting origin" % context)
	if not source_card.modulate.is_equal_approx(Color.WHITE):
		push_error("%s should not tint the card according to target validity" % context)
	var source_bounds: Rect2 = instance.call("_control_visual_global_rect", source_card)
	var hand_scroll: Control = instance.get("hand_scroll") as Control
	if hand_scroll == null or not hand_scroll.get_global_rect().grow(72.0).has_point(source_bounds.get_center()):
		push_error("%s should keep the selected card anchored in the hand" % context)
	if hover_bounds.size.x > 0.0 and (source_bounds.size.x >= hover_bounds.size.x - 1.0 or source_bounds.size.y >= hover_bounds.size.y - 1.0):
		push_error("%s selected pose should remain smaller than the hover preview" % context)
	if (instance.call("_control_visual_global_rect", source_card) as Rect2).has_point(cursor_position):
		push_error("%s should leave the hovered target and cursor unobscured" % context)
	var hand_box: Control = instance.get("hand_box") as Control
	if hand_box == null or int(hand_box.call("emphasized_index")) != int(instance.get("_drag_card_index")):
		push_error("%s should visibly raise the selected card above the rest of the hand" % context)
	var arrow: Control = instance.get("_drag_target_arrow") as Control
	if not bool(instance.get("_drag_targeting_active")) or arrow == null or not arrow.visible:
		push_error("%s should show the active targeting arrow" % context)
	elif not bool(arrow.get_meta("raster_composed_arrow", false)) or not bool(arrow.get_meta("segmented_raster_arrow", false)):
		push_error("%s should use the authored segmented raster arrow" % context)
	_assert_no_drag_copy(instance, context)

func _assert_targetless_board_drag(instance: Node, cursor_position: Vector2) -> void:
	_assert_following_card_drag(instance, "targetless board drag", cursor_position, Rect2())
	if bool(instance.get("_drag_targeting_active")) or int(instance.get("_selected_card_index")) >= 0:
		push_error("Targetless board drag should confirm with the following card instead of tile targeting")

func _assert_drag_play_launch(instance: Node) -> void:
	if str(instance.get_meta("last_card_play_source_kind", "")) != "drag_hand":
		push_error("A committed drag should reuse the normal hand-origin play launch")
	var source_rect: Rect2 = instance.get_meta("last_card_play_source_rect", Rect2()) as Rect2
	var hand_scroll: Control = instance.get("hand_scroll") as Control
	if hand_scroll == null or not hand_scroll.get_global_rect().grow(72.0).has_point(source_rect.get_center()):
		push_error("Drag play animation should start in the hand rather than at the cursor or screen edge")
	if _first_card_fx_proxy(instance) == null:
		push_error("Drag play launch proof should capture the real card animation in flight")
	var arrow: Control = instance.get("_drag_target_arrow") as Control
	if arrow != null and arrow.visible:
		push_error("The targeting arrow should clear before the played card launches")

func _turn_order_has_card_projection(instance: Node, card_name: String) -> bool:
	var turn_order_bar: Control = instance.get("_turn_order_bar") as Control
	if turn_order_bar == null:
		return false
	for child: Node in turn_order_bar.get_children():
		if str(child.get_meta("turn_order_projection_card_name", "")) == card_name:
			return true
	return false

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
				row.append("stone")
		grid.append(row)
	return grid

func _save_root_screenshot(output_path: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image != null and image.get_pixel(image.get_width() / 2, image.get_height() / 2).get_luminance() <= 0.01:
		# macOS can occasionally return the cleared back buffer immediately after a
		# proxy reparent. Capture the next completed frame instead of blessing black.
		await process_frame
		await RenderingServer.frame_post_draw
		image = root.get_viewport().get_texture().get_image()
	if image == null:
		push_error("Card drag proof should capture a renderer image")
		return
	var source_size := image.get_size()
	var valid_aspect := is_equal_approx(float(source_size.x) / float(source_size.y), float(PROBE_VIEWPORT.x) / float(PROBE_VIEWPORT.y))
	if not valid_aspect:
		push_error("Card drag proof should preserve the 16:9 canvas, got %s" % source_size)
		return
	if source_size != PROBE_VIEWPORT:
		image.resize(PROBE_VIEWPORT.x, PROBE_VIEWPORT.y, Image.INTERPOLATE_LANCZOS)
	if image.save_png(ProjectSettings.globalize_path(output_path)) != OK:
		push_error("Could not save card drag proof %s" % output_path)

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

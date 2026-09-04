extends RefCounted

const CardDragPlayRules = preload("res://scripts/card_drag_play_rules.gd")
const CardDragTargetingArrow = preload("res://scripts/card_drag_targeting_arrow.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const InputRouterScript = preload("res://scripts/input_router.gd")
const CardWidgetScene = preload("res://scenes/card_widget.tscn")

const PLAYER_TILE := Vector2i(2, 4)
const TARGET_TILE := Vector2i(3, 4)
const INVALID_TILE := Vector2i(6, 6)
const NO_TARGET_TILE := Vector2i(-1, -1)


static func run(expect: Callable) -> void:
	var targeted_preview: Dictionary = {
		"playable": true,
		"complete": false,
		"target_tiles": [TARGET_TILE],
	}
	var targetless_preview: Dictionary = {
		"playable": true,
		"complete": true,
		"target_tiles": [],
	}
	expect.call(CardDragPlayRules.preview_requires_target(targeted_preview), "An incomplete playable preview should enter drag targeting")
	expect.call(not CardDragPlayRules.preview_requires_target(targetless_preview), "A complete targetless preview should remain a board confirmation drag")
	expect.call(
		CardDragPlayRules.release_outcome(true, targeted_preview, true) == CardDragPlayRules.OUTCOME_PLAY_TARGET,
		"A legal targeted board release should commit its target"
	)
	expect.call(
		CardDragPlayRules.release_outcome(true, targeted_preview, false) == CardDragPlayRules.OUTCOME_CONTINUE_TARGETING,
		"An illegal targeted board release should continue in click-style targeting"
	)
	expect.call(
		CardDragPlayRules.release_outcome(false, targeted_preview, false) == CardDragPlayRules.OUTCOME_CANCEL,
		"A targeted release outside the board should still cancel"
	)
	expect.call(
		CardDragPlayRules.release_outcome(true, targetless_preview, false) == CardDragPlayRules.OUTCOME_PLAY_TARGETLESS,
		"Any board release should commit a targetless card"
	)
	expect.call(
		CardDragPlayRules.release_outcome(false, targetless_preview, false) == CardDragPlayRules.OUTCOME_CANCEL,
		"A targetless release outside the board should cancel"
	)
	_test_raster_arrow_geometry(expect)


static func _test_raster_arrow_geometry(expect: Callable) -> void:
	expect.call(FileAccess.file_exists(CardDragTargetingArrow.SEGMENT_ASSET_PATH), "Targeting arrow should own a raster body-segment asset")
	expect.call(FileAccess.file_exists(CardDragTargetingArrow.HEAD_ASSET_PATH), "Targeting arrow should own a separate raster arrowhead asset")
	var segment_image: Image = Image.load_from_file(CardDragTargetingArrow.SEGMENT_ASSET_PATH)
	var head_image: Image = Image.load_from_file(CardDragTargetingArrow.HEAD_ASSET_PATH)
	expect.call(segment_image != null and Vector2(segment_image.get_size()) == CardDragTargetingArrow.SEGMENT_DRAW_SIZE, "Targeting body segments should render at their fixed native raster size without stretching")
	expect.call(head_image != null and Vector2(head_image.get_size()) == CardDragTargetingArrow.HEAD_DRAW_SIZE, "Targeting head should render at its fixed native raster size without stretching")
	expect.call(CardDragTargetingArrow.SEGMENT_SPACING > CardDragTargetingArrow.SEGMENT_DRAW_SIZE.x, "Targeting body pieces should remain visibly segmented instead of overlapping into a cable")
	var start := Vector2(960.0, 900.0)
	var finishes := PackedVector2Array([Vector2(330.0, 300.0), Vector2(960.0, 280.0), Vector2(1590.0, 300.0), Vector2(850.0, 650.0)])
	for finish_index: int in range(finishes.size()):
		var finish: Vector2 = finishes[finish_index]
		var points: PackedVector2Array = CardDragTargetingArrow.sampled_curve(start, finish)
		expect.call(points.size() >= 4 and points[0].is_equal_approx(start) and points[points.size() - 1].is_equal_approx(finish), "Raster arrow arc samples should exactly connect the selected card to short, left, center, and right targets")
		var placements: Array[Dictionary] = CardDragTargetingArrow.segment_placements(start, finish)
		expect.call(placements.size() >= 2, "Every visible targeting arrow should have at least two full-size body segments before its head")
		var previous_tangent := Vector2.ZERO
		var previous_distance: float = -1.0
		var expected_spacing: float = float(placements[0].get("spacing", 0.0))
		expect.call(expected_spacing >= CardDragTargetingArrow.SEGMENT_DRAW_SIZE.x + 2.0, "Targeting body pieces should preserve a visible gap between their native-size silhouettes")
		for placement: Dictionary in placements:
			var tangent: Vector2 = placement.get("tangent", Vector2.ZERO)
			var distance: float = float(placement.get("distance", 0.0))
			if previous_distance >= 0.0:
				expect.call(absf((distance - previous_distance) - expected_spacing) <= 0.01, "Targeting body pieces should use uniform arc-length spacing")
			if previous_tangent.length_squared() > 0.0:
				expect.call(previous_tangent.dot(tangent) > 0.95, "Individually rotated raster segments should follow the curve without broken or kinked turns")
			previous_tangent = tangent
			previous_distance = distance
		var head: Dictionary = CardDragTargetingArrow.head_placement(start, finish)
		var head_tip: Vector2 = head.get("tip", Vector2.ZERO)
		var head_tangent: Vector2 = head.get("tangent", Vector2.ZERO)
		expect.call(head_tip.distance_to(finish) <= 0.05, "The authored arrowhead tip should land exactly on the pointer")
		expect.call(head_tangent.dot(CardDragTargetingArrow.tangent_at_arc_distance(CardDragTargetingArrow.curve_lookup(start, finish), float(head.get("arc_length", 0.0)))) > 0.999, "The arrowhead should rotate with the curve's final tangent")
		var last_distance: float = float(placements[placements.size() - 1].get("distance", 0.0))
		var terminal_limit: float = float(head.get("arc_length", 0.0)) - CardDragTargetingArrow.HEAD_DRAW_SIZE.x - CardDragTargetingArrow.SEGMENT_DRAW_SIZE.x * 0.5 + CardDragTargetingArrow.HEAD_SOCKET_OVERLAP
		expect.call(absf(last_distance - terminal_limit) <= 0.01, "The final body segment should meet the arrowhead socket without extending through or past its tip")
		if finish_index == 0:
			expect.call(head_tangent.x < -0.1 and head_tangent.y < -0.1, "A hard-left target should visibly rotate the arrowhead left")
		elif finish_index == 2:
			expect.call(head_tangent.x > 0.1 and head_tangent.y < -0.1, "A hard-right target should visibly rotate the arrowhead right")
	var source := FileAccess.open("res://scripts/card_drag_targeting_arrow.gd", FileAccess.READ)
	var source_text: String = source.get_as_text() if source != null else ""
	expect.call(source_text.contains("draw_texture(") and not source_text.contains("draw_texture_rect"), "Targeting arrow should stamp native-size raster pieces without length-scaling them")
	expect.call(source_text.contains("TEXTURE_FILTER_NEAREST"), "Targeting arrow should preserve crisp pixel-art filtering while its pieces rotate")
	expect.call(not source_text.contains("draw_line") and not source_text.contains("draw_polyline") and not source_text.contains("draw_polygon"), "Targeting arrow must be composed from raster pieces rather than procedural line or polygon geometry")


static func run_live(tree: SceneTree, expect: Callable) -> void:
	await _test_card_widget_drag_threshold(tree, expect)
	await _test_off_center_follow_and_snapback(tree, expect)
	await _test_targeted_drag_entry_and_invalid_release(tree, expect)
	await _test_invalid_board_release_can_cancel_selection(tree, expect)
	await _test_targeted_leaving_board_cancels(tree, expect)
	await _test_targeted_valid_release_plays(tree, expect)
	await _test_compound_target_release_plays(tree, expect)
	await _test_targetless_board_and_outside_releases(tree, expect)
	await _test_click_targeting_regression(tree, expect)
	await _test_click_targeting_arrow_and_hover_suppression(tree, expect)
	await _test_controller_first_card_press_enters_shared_targeting(tree, expect)
	await _test_controller_targeting_reuses_shared_arrow(tree, expect)
	await _test_modal_controller_handoff_suspends_targeting_cursors(tree, expect)
	await _test_controller_handoff_cancels_pointer_drags(tree, expect)
	await _test_targetless_click_confirmation_paths(tree, expect)


static func _test_card_widget_drag_threshold(tree: SceneTree, expect: Callable) -> void:
	var widget: Control = CardWidgetScene.instantiate()
	tree.root.add_child(widget)
	await tree.process_frame
	var signal_counts: Array[int] = [0, 0]
	widget.drag_started.connect(func() -> void: signal_counts[0] += 1)
	widget.activated.connect(func() -> void: signal_counts[1] += 1)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(40.0, 40.0)
	widget.call("_gui_input", press)
	var below_threshold := InputEventMouseMotion.new()
	below_threshold.position = Vector2(49.0, 40.0)
	widget.call("_gui_input", below_threshold)
	expect.call(signal_counts[0] == 0, "CardWidget should not begin a drag before the 10px movement threshold")
	var past_threshold := InputEventMouseMotion.new()
	past_threshold.position = Vector2(51.0, 40.0)
	widget.call("_gui_input", past_threshold)
	widget.call("_gui_input", past_threshold)
	expect.call(signal_counts[0] == 1, "CardWidget should emit exactly one drag start after crossing the movement threshold")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = past_threshold.position
	widget.call("_gui_input", release)
	expect.call(signal_counts[1] == 0, "Releasing a real CardWidget drag should not also activate its click path")
	widget.call("_gui_input", press)
	widget.call("_gui_input", release)
	expect.call(signal_counts[1] == 1, "A sub-threshold CardWidget press and release should retain the existing click path")
	widget.queue_free()
	await tree.process_frame


static func _test_off_center_follow_and_snapback(tree: SceneTree, expect: Callable) -> void:
	var instance: Node = await _live_instance(tree, expect, "quick_stab", TARGET_TILE, 93108)
	if instance == null:
		return
	instance.call("_on_card_hover_started", 0)
	await tree.create_timer(0.16).timeout
	var source_card: Control = instance.call("_hand_card_control", 0) as Control
	var hover_rect: Rect2 = instance.call("_control_visual_global_rect", source_card)
	var grab_ratio := Vector2(0.07, 0.10)
	var grab_position: Vector2 = hover_rect.position + hover_rect.size * grab_ratio
	instance.call("_on_card_drag_started", 0, grab_position)
	await tree.process_frame
	var proxy: Control = instance.get("_drag_card_proxy") as Control
	expect.call(proxy != null, "An off-center drag should still create the pre-board following card")
	if proxy == null:
		instance.queue_free()
		await tree.process_frame
		return
	var pointer_in_proxy: Vector2 = proxy.get_global_transform().affine_inverse() * grab_position
	var expected_local_grab: Vector2 = proxy.size * grab_ratio
	expect.call(pointer_in_proxy.distance_to(expected_local_grab) <= 2.0, "Shrinking and tilting the following card should preserve the exact edge/corner grab point under the pointer")
	var cancel_rect: Rect2 = instance.get("_drag_card_cancel_rect") as Rect2
	expect.call(cancel_rect.size.x < hover_rect.size.x and cancel_rect.size.y < hover_rect.size.y, "Pre-board cancel should target the settled hand card rather than the stale enlarged hover rect")
	var follow_rect: Rect2 = instance.call("_card_proxy_visual_rect", proxy)
	instance.call("_animate_drag_cancel_to_source")
	await tree.create_timer(0.11).timeout
	var snapping_proxy: Control = instance.get("_drag_card_proxy") as Control
	expect.call(snapping_proxy != null, "The snapback transition should remain visible until it reaches the hand")
	if snapping_proxy != null:
		var snapping_rect: Rect2 = instance.call("_card_proxy_visual_rect", snapping_proxy)
		expect.call(snapping_rect.size.x <= follow_rect.size.x + 1.0 and snapping_rect.size.y <= follow_rect.size.y + 1.0, "Cancel snapback should settle toward the normal hand size without growing back through the hover preview")
	await tree.create_timer(0.10).timeout
	expect.call(int(instance.get("_drag_card_index")) == -1 and source_card.is_visible_in_tree(), "Off-center cancel should finish with one restored hand card and no active drag")
	instance.queue_free()
	await tree.process_frame


static func _test_targeted_drag_entry_and_invalid_release(tree: SceneTree, expect: Callable) -> void:
	var instance: Node = await _live_instance(tree, expect, "quick_stab", TARGET_TILE, 93101)
	if instance == null:
		return
	var hand_before: Array = _hand(instance).duplicate()
	instance.call("_on_card_hover_started", 0)
	await tree.create_timer(0.16).timeout
	var hovered_card: Control = instance.call("_hand_card_control", 0) as Control
	var hover_rect: Rect2 = instance.call("_control_visual_global_rect", hovered_card)
	var drag_start: Vector2 = hover_rect.get_center()
	instance.call("_on_card_drag_started", 0, drag_start)
	await tree.process_frame
	var source_card: Control = instance.call("_hand_card_control", 0) as Control
	var hand_box: Control = instance.get("hand_box") as Control
	var proxy: Control = instance.get("_drag_card_proxy") as Control
	expect.call(proxy != null and source_card != null and not source_card.is_visible_in_tree(), "Crossing the drag threshold should temporarily move the card with the pointer and hide its hand copy")
	var proxy_rect: Rect2 = instance.call("_card_proxy_visual_rect", proxy)
	expect.call(proxy_rect.size.x < hover_rect.size.x and proxy_rect.size.y < hover_rect.size.y, "The following card should settle smaller than the large hover preview")
	var context: Control = instance.get("_action_step_tracker") as Control
	expect.call(context != null and not context.visible, "Drag state should not add instructional side copy")
	var valid_position: Vector2 = _tile_global_position(instance, TARGET_TILE)
	await instance.call("_update_card_drag", valid_position)
	await tree.process_frame
	expect.call(bool(instance.get("_drag_targeting_active")), "Crossing onto the board with a targeted card should enter targeting before release")
	expect.call(int(instance.get("_selected_card_index")) == 0, "Drag targeting should arm the exact held card")
	expect.call((instance.get("_pending_target_tiles") as Array).has(TARGET_TILE), "Drag targeting should expose the normal legal target set")
	expect.call(instance.get("_drag_card_proxy") == null, "Board entry should replace the following card with targeting feedback")
	expect.call(source_card.is_visible_in_tree() and bool(source_card.get_meta("drag_hand_origin", false)), "Board entry should restore the original card as the selected hand anchor")
	expect.call(hand_box != null and int(hand_box.call("emphasized_index")) == 0, "The targeted card should remain clearly raised above the other hand cards")
	var source_rect: Rect2 = instance.call("_control_visual_global_rect", source_card)
	var hand_scroll: Control = instance.get("hand_scroll") as Control
	expect.call(hand_scroll != null and hand_scroll.get_global_rect().has_point(source_rect.get_center()), "The dragged card should stay anchored inside the hand while the pointer targets the board")
	expect.call(source_rect.size.x < hover_rect.size.x and source_rect.size.y < hover_rect.size.y, "The selected targeting pose should be smaller than the hover preview")
	expect.call(not source_rect.has_point(valid_position), "The hand-origin card should never cover the hovered board target")
	expect.call(source_card.modulate.is_equal_approx(Color.WHITE), "Target validity should never tint the selected card")
	var arrow: Control = instance.get("_drag_target_arrow") as Control
	expect.call(arrow != null and arrow.visible and bool(arrow.get_meta("raster_composed_arrow", false)), "Targeting should show the raster-composed arrow from the selected card")
	expect.call(bool(arrow.get_meta("segmented_raster_arrow", false)), "The targeting arrow body should be a discrete chain of authored raster segments")
	expect.call(str(arrow.get_meta("segment_asset_path", "")).ends_with("card_drag_arrow_segment_v2.png") and str(arrow.get_meta("head_asset_path", "")).ends_with("card_drag_arrow_head_v2.png"), "The targeting arrow should use the reviewed chunky pixel-art segment and indented-bezel head assets")
	expect.call(not context.visible, "Arrow targeting should remain free of instructional side copy")
	var invalid_position: Vector2 = _tile_global_position(instance, INVALID_TILE)
	await instance.call("_update_card_drag", invalid_position)
	await tree.process_frame
	expect.call(bool(instance.get("_drag_targeting_active")) and arrow.visible, "Targeting should stay latched while the pointer moves across invalid space")
	expect.call(source_card.modulate.is_equal_approx(Color.WHITE), "Invalid targets should not recolor the card")
	var original_card_position: Vector2 = source_card.position
	source_card.position += Vector2(18.0, -6.0)
	var resized_source_rect: Rect2 = instance.call("_control_visual_global_rect", source_card)
	instance.call("_sync_card_targeting_arrow_after_layout")
	var resized_arrow_transform: Transform2D = arrow.get_global_transform_with_canvas()
	expect.call((resized_arrow_transform * (arrow.call("targeting_start") as Vector2)).distance_to(resized_source_rect.position + Vector2(resized_source_rect.size.x * 0.5, 4.0)) <= 1.0, "A layout change during held targeting should re-anchor the arrow to the newly positioned hand card")
	expect.call((resized_arrow_transform * (arrow.call("targeting_end") as Vector2)).distance_to(invalid_position) <= 1.0, "A held-targeting layout refresh should preserve the latest pointer endpoint")
	source_card.position = original_card_position
	instance.call("_sync_card_targeting_arrow_after_layout")
	tree.root.warp_mouse(invalid_position)
	await instance.call("_commit_drag_drop", "play", invalid_position)
	expect.call(int(instance.get("_drag_card_index")) == -1 and int(instance.get("_selected_card_index")) == 0, "Invalid in-board release should end only the held drag and preserve the selected card")
	expect.call(not bool(instance.get("_drag_targeting_active")) and instance.get("_drag_card_proxy") == null, "Invalid in-board release should settle into ordinary pointer targeting without stranded drag state")
	expect.call(_hand(instance) == hand_before, "Invalid in-board release should not consume or spend the card")
	expect.call(not (instance.call("_turn_order_card_time_preview") as Dictionary).is_empty(), "Invalid in-board release should preserve the Turn Clock card-time preview while targeting continues")
	expect.call(_turn_order_has_card_projection(instance, "Quick Stab"), "Invalid in-board release should keep the selected card projected in the Turn Clock")
	expect.call(arrow.visible, "Invalid in-board release should keep the shared arrow live at the release point")
	var arrow_transform: Transform2D = arrow.get_global_transform_with_canvas()
	expect.call((arrow_transform * (arrow.call("targeting_end") as Vector2)).distance_to(invalid_position) <= 1.0, "The handed-off arrowhead should remain at the exact release point")
	# Pointer motion can race the hand-layout callback queued by release. Prove the
	# deferred re-anchor follows the newest pointer instead of restoring the stale
	# release endpoint over it.
	var post_release_position: Vector2 = _tile_global_position(instance, PLAYER_TILE)
	tree.root.warp_mouse(post_release_position)
	instance.call("_sync_click_targeting_arrow", post_release_position)
	await tree.process_frame
	arrow_transform = arrow.get_global_transform_with_canvas()
	expect.call((arrow_transform * (arrow.call("targeting_end") as Vector2)).distance_to(post_release_position) <= 1.0, "Post-release pointer motion should win over deferred handoff layout and keep the arrow responsive")
	expect.call(hand_box != null and int(hand_box.call("emphasized_index")) == 0, "The selected card should retain its restrained targeting pose after handoff")
	var cursor_feedback: Node = tree.root.get_node_or_null("CursorFeedback")
	if cursor_feedback != null and cursor_feedback.has_method("glyph_visibility_suppressed"):
		expect.call(bool(cursor_feedback.call("glyph_visibility_suppressed")), "Pointer targeting handoff should keep the forged cursor hidden")
	var enemy_hp_before: int = _enemy_hp(instance)
	await instance.call("_on_board_tile_clicked", TARGET_TILE)
	await tree.process_frame
	expect.call(_enemy_hp(instance) < enemy_hp_before and not _hand(instance).has("quick_stab"), "A later click on a legal square should resolve the handed-off card exactly once")
	expect.call(int(instance.get("_selected_card_index")) == -1 and not arrow.visible, "Resolving after handoff should clear the selected card and targeting arrow")
	instance.queue_free()
	await tree.process_frame


static func _test_invalid_board_release_can_cancel_selection(tree: SceneTree, expect: Callable) -> void:
	var instance: Node = await _live_instance(tree, expect, "quick_stab", TARGET_TILE, 93115)
	if instance == null:
		return
	var hand_before: Array = _hand(instance).duplicate()
	var invalid_position: Vector2 = _tile_global_position(instance, INVALID_TILE)
	# Exercise a direct release over the illegal board square; commit must enter
	# targeting itself even if no intermediate motion event reached the scene.
	instance.call("_on_card_drag_started", 0, _drag_start_position(instance, 0))
	await instance.call("_commit_drag_drop", "play", invalid_position)
	await tree.process_frame
	expect.call(int(instance.get("_drag_card_index")) == -1 and int(instance.get("_selected_card_index")) == 0, "A direct illegal board release should settle into selected pointer targeting")
	var arrow: Control = instance.get("_drag_target_arrow") as Control
	expect.call(arrow != null and arrow.visible, "Direct release handoff should show the shared targeting arrow")
	await instance.call("_on_card_pressed", 0)
	await tree.process_frame
	expect.call(_hand(instance) == hand_before and int(instance.get("_selected_card_index")) == -1, "Clicking the handed-off targeted card again should cancel without spending it")
	expect.call(arrow != null and not arrow.visible, "Canceling after release handoff should clear the targeting arrow")
	instance.queue_free()
	await tree.process_frame


static func _test_targeted_leaving_board_cancels(tree: SceneTree, expect: Callable) -> void:
	var instance: Node = await _live_instance(tree, expect, "quick_stab", TARGET_TILE, 93107)
	if instance == null:
		return
	var hand_before: Array = _hand(instance).duplicate()
	instance.call("_on_card_drag_started", 0, _drag_start_position(instance, 0))
	await tree.process_frame
	await instance.call("_update_card_drag", _tile_global_position(instance, TARGET_TILE))
	var outside_position := Vector2(8.0, 8.0)
	await instance.call("_update_card_drag", outside_position)
	await tree.process_frame
	var arrow: Control = instance.get("_drag_target_arrow") as Control
	expect.call(bool(instance.get("_drag_targeting_active")) and int(instance.get("_selected_card_index")) == 0, "Once board entry begins targeted play, the selected-card pose should remain latched until release")
	expect.call(arrow != null and arrow.visible, "The targeting arrow should remain attached while the pointer leaves the board so the active card stays clear")
	await instance.call("_commit_drag_drop", "", outside_position)
	await tree.process_frame
	expect.call(_hand(instance) == hand_before and int(instance.get("_drag_card_index")) == -1 and not arrow.visible, "Releasing a targeted card after leaving the board should cancel and clear the arrow without spending it")
	instance.queue_free()
	await tree.process_frame


static func _test_targeted_valid_release_plays(tree: SceneTree, expect: Callable) -> void:
	var instance: Node = await _live_instance(tree, expect, "quick_stab", TARGET_TILE, 93102)
	if instance == null:
		return
	var enemy_hp_before: int = _enemy_hp(instance)
	instance.call("_on_card_drag_started", 0, _drag_start_position(instance, 0))
	await tree.process_frame
	var target_position: Vector2 = _tile_global_position(instance, TARGET_TILE)
	await instance.call("_update_card_drag", target_position)
	await instance.call("_commit_drag_drop", "play", target_position)
	await tree.process_frame
	expect.call(_enemy_hp(instance) < enemy_hp_before, "Releasing a targeted card on a legal square should resolve its effect")
	expect.call(not _hand(instance).has("quick_stab"), "A successful targeted drag should consume the exact hand card")
	expect.call(int(instance.get("_selected_card_index")) == -1 and instance.get("_drag_card_proxy") == null, "A successful targeted drag should finish without stranded selection or proxy state")
	expect.call(str(instance.get_meta("last_card_play_source_kind", "")) == "drag_hand", "A targeted drag should use the same hand-origin play launch as clicking")
	expect.call(_last_play_source_inside_hand(instance), "A targeted drag play should launch upward from the hand rather than from the cursor or screen edge")
	var arrow: Control = instance.get("_drag_target_arrow") as Control
	expect.call(arrow != null and not arrow.visible, "A successful targeted release should clear the targeting arrow")
	instance.queue_free()
	await tree.process_frame


static func _test_compound_target_release_plays(tree: SceneTree, expect: Callable) -> void:
	var compound_enemy_tile := Vector2i(5, 4)
	var instance: Node = await _live_instance(tree, expect, "sidestep_slash", compound_enemy_tile, 93103)
	if instance == null:
		return
	var enemy_hp_before: int = _enemy_hp(instance)
	instance.call("_on_card_drag_started", 0, _drag_start_position(instance, 0))
	await tree.process_frame
	var target_position: Vector2 = _tile_global_position(instance, compound_enemy_tile)
	await instance.call("_update_card_drag", target_position)
	expect.call(bool(instance.call("_drag_hover_target_is_valid", compound_enemy_tile)), "Compound move-attack shortcuts should count as legal drag targets")
	var compound_board: Control = instance.get("board_view") as Control
	var compound_presentation: Dictionary = compound_board.get("presentation") as Dictionary
	expect.call((compound_presentation.get("path_tiles", []) as Array).size() >= 2, "A move-and-attack shortcut should retain its valuable player movement-path arrow during card targeting")
	await instance.call("_commit_drag_drop", "play", target_position)
	await tree.process_frame
	expect.call(_enemy_hp(instance) < enemy_hp_before and not _hand(instance).has("sidestep_slash"), "One legal compound target release should resolve the full card")
	instance.queue_free()
	await tree.process_frame


static func _test_targetless_board_and_outside_releases(tree: SceneTree, expect: Callable) -> void:
	var cancel_instance: Node = await _live_instance(tree, expect, "stone_plate", Vector2i(5, 4), 93104)
	if cancel_instance == null:
		return
	var hand_before: Array = _hand(cancel_instance).duplicate()
	cancel_instance.call("_on_card_drag_started", 0, _drag_start_position(cancel_instance, 0))
	await tree.process_frame
	var outside_position := Vector2(8.0, 8.0)
	await cancel_instance.call("_update_card_drag", outside_position)
	await cancel_instance.call("_commit_drag_drop", "", outside_position)
	expect.call(_hand(cancel_instance) == hand_before and int(cancel_instance.get("_selected_card_index")) == -1, "Targetless release outside the board should cancel without arming or spending")
	cancel_instance.queue_free()
	await tree.process_frame

	var play_instance: Node = await _live_instance(tree, expect, "stone_plate", Vector2i(5, 4), 93105)
	if play_instance == null:
		return
	var stoneskin_before: int = int(((play_instance.get("_combat_state") as Dictionary).get("player", {}) as Dictionary).get("stoneskin", 0))
	play_instance.call("_on_card_drag_started", 0, _drag_start_position(play_instance, 0))
	await tree.process_frame
	var board_position: Vector2 = (play_instance.get("board_view") as Control).get_global_rect().get_center()
	await play_instance.call("_update_card_drag", board_position)
	expect.call(not bool(play_instance.get("_drag_targeting_active")) and int(play_instance.get("_selected_card_index")) == -1, "Targetless board drag should advertise confirmation without entering tile targeting")
	expect.call(play_instance.get("_drag_card_proxy") != null, "A targetless card should keep following the pointer because the board itself is its drop target")
	var arrow: Control = play_instance.get("_drag_target_arrow") as Control
	expect.call(arrow != null and not arrow.visible, "Targetless board confirmation should not show a misleading tile-targeting arrow")
	await play_instance.call("_commit_drag_drop", "play", board_position)
	await tree.process_frame
	var stoneskin_after: int = int(((play_instance.get("_combat_state") as Dictionary).get("player", {}) as Dictionary).get("stoneskin", 0))
	expect.call(stoneskin_after > stoneskin_before and not _hand(play_instance).has("stone_plate"), "Targetless release anywhere over the board should resolve the card")
	expect.call(str(play_instance.get_meta("last_card_play_source_kind", "")) == "drag_hand" and _last_play_source_inside_hand(play_instance), "A targetless drag should also launch its play animation from the hand")
	play_instance.queue_free()
	await tree.process_frame


static func _test_click_targeting_regression(tree: SceneTree, expect: Callable) -> void:
	var instance: Node = await _live_instance(tree, expect, "quick_stab", TARGET_TILE, 93106)
	if instance == null:
		return
	var enemy_hp_before: int = _enemy_hp(instance)
	await instance.call("_on_card_pressed", 0)
	await tree.process_frame
	expect.call(int(instance.get("_selected_card_index")) == 0 and int(instance.get("_drag_card_index")) == -1, "Clicking a card should retain its existing targeting path without entering drag state")
	await instance.call("_on_board_tile_clicked", TARGET_TILE)
	await tree.process_frame
	expect.call(_enemy_hp(instance) < enemy_hp_before, "The existing click-target path should still resolve the card")
	expect.call(str(instance.get_meta("last_card_play_source_kind", "")) == "hand" and _last_play_source_inside_hand(instance), "Click targeting should keep the same hand-origin play animation used by drag")
	instance.queue_free()
	await tree.process_frame


static func _test_click_targeting_arrow_and_hover_suppression(tree: SceneTree, expect: Callable) -> void:
	var enemy_tile := Vector2i(5, 4)
	var instance: Node = await _live_instance(tree, expect, "lantern_shot", enemy_tile, 93109)
	if instance == null:
		return
	var board: Control = instance.get("board_view") as Control
	instance.call("_on_board_tile_hovered", enemy_tile)
	await tree.process_frame
	var idle_presentation: Dictionary = board.get("presentation") as Dictionary
	expect.call(not (idle_presentation.get("enemy_threat_previews", []) as Array).is_empty(), "Ordinary enemy hover should expose the movement forecast before card targeting owns the board")
	expect.call(_presentation_has_enemy_movement_preview(idle_presentation), "The moving-enemy fixture should visibly own a destination ghost before targeting begins")

	var hand_before: Array = _hand(instance).duplicate()
	var enemy_hp_before: int = _enemy_hp(instance)
	await instance.call("_on_card_pressed", 0)
	await tree.process_frame
	var target_position: Vector2 = _tile_global_position(instance, enemy_tile)
	instance.call("_sync_click_targeting_arrow", target_position)
	await tree.process_frame
	var arrow: Control = instance.get("_drag_target_arrow") as Control
	expect.call(int(instance.get("_selected_card_index")) == 0 and int(instance.get("_drag_card_index")) == -1, "Click selection should enter pointer targeting without creating drag state")
	expect.call(arrow != null and arrow.visible, "Click targeting should reuse the same segmented raster arrow as drag targeting")
	var hand_box: Control = instance.get("hand_box") as Control
	expect.call(hand_box != null and int(hand_box.call("emphasized_index")) == 0, "Click targeting should keep the selected card in the restrained raised pose")
	var expected_start := Vector2.ZERO
	if arrow != null:
		var arrow_transform: Transform2D = arrow.get_global_transform_with_canvas()
		var source_card: Control = instance.call("_hand_card_control", 0) as Control
		var source_rect: Rect2 = instance.call("_control_visual_global_rect", source_card)
		expected_start = source_rect.position + Vector2(source_rect.size.x * 0.5, 4.0)
		expect.call((arrow_transform * (arrow.call("targeting_start") as Vector2)).distance_to(expected_start) <= 1.0, "Click and drag arrows should share the selected hand-card anchor")
		expect.call((arrow_transform * (arrow.call("targeting_end") as Vector2)).distance_to(target_position) <= 1.0, "Click targeting arrowhead should land on the live pointer")
	var cursor_feedback: Node = tree.root.get_node_or_null("CursorFeedback")
	if cursor_feedback != null and cursor_feedback.has_method("glyph_visibility_suppressed"):
		expect.call(bool(cursor_feedback.call("glyph_visibility_suppressed")), "A visible targeting arrow should suppress the forged pointer without changing input")
	if arrow != null:
		instance.call("_sync_click_targeting_arrow", expected_start + Vector2(10.0, 0.0))
		await tree.process_frame
		expect.call(not arrow.visible, "The arrow may stay visually quiet inside its short hand-anchor dead zone")
		if cursor_feedback != null and cursor_feedback.has_method("glyph_visibility_suppressed"):
			expect.call(bool(cursor_feedback.call("glyph_visibility_suppressed")), "The forged pointer should remain hidden throughout targeting even inside the arrow's short dead zone")

	var second_pointer: Vector2 = target_position + Vector2(12.0, -8.0)
	instance.call("_sync_click_targeting_arrow", second_pointer)
	await tree.process_frame
	if arrow != null:
		expect.call((arrow.get_global_transform_with_canvas() * (arrow.call("targeting_end") as Vector2)).distance_to(second_pointer) <= 1.0, "Click targeting arrow should follow pointer motion even within one board tile")
	expect.call(_hand(instance) == hand_before and _enemy_hp(instance) == enemy_hp_before, "Aiming with the click arrow should not commit the card before a legal target click")

	instance.call("_on_board_tile_hovered", enemy_tile)
	await tree.process_frame
	var targeting_presentation: Dictionary = board.get("presentation") as Dictionary
	expect.call((targeting_presentation.get("enemy_threat_previews", []) as Array).is_empty(), "Hover-driven enemy intent previews should be suppressed while a targeted card owns the pointer")
	expect.call(not _presentation_has_enemy_movement_preview(targeting_presentation), "Enemy destination ghosts should not compete with the card targeting arrow")
	expect.call((board.get("attack_tiles") as Array).has(enemy_tile), "Suppressing enemy hover evidence must preserve the card's legal target highlight")

	tree.root.warp_mouse(target_position)
	await tree.process_frame
	expect.call(bool(instance.call("_map_shortcut_can_open")), "The map shortcut should remain available while pointer click-targeting is selected")
	instance.call("_open_large_map")
	await tree.process_frame
	expect.call(int(instance.get("_selected_card_index")) == 0, "Opening a non-destructive modal should preserve the selected card")
	expect.call(arrow != null and not arrow.visible, "A modal should suspend the targeting arrow while it owns the pointer")
	if cursor_feedback != null and cursor_feedback.has_method("glyph_visibility_suppressed"):
		expect.call(not bool(cursor_feedback.call("glyph_visibility_suppressed")), "A modal should restore the forged pointer even though targeting remains selected behind it")
	instance.call("_close_large_map")
	await tree.process_frame
	expect.call(arrow != null and arrow.visible, "Closing the map should immediately restore the still-selected card's targeting arrow")
	if cursor_feedback != null and cursor_feedback.has_method("glyph_visibility_suppressed"):
		expect.call(bool(cursor_feedback.call("glyph_visibility_suppressed")), "Closing the map should return pointer ownership to card targeting")
	instance.call("_open_menu_overlay")
	await tree.process_frame
	expect.call(int(instance.get("_selected_card_index")) == 0 and arrow != null and not arrow.visible, "Button-opened menus should suspend targeting without discarding the selected card")
	if cursor_feedback != null and cursor_feedback.has_method("glyph_visibility_suppressed"):
		expect.call(not bool(cursor_feedback.call("glyph_visibility_suppressed")), "Button-opened menus should never inherit the targeting cursor suppression")
	instance.call("_close_menu_overlay")
	await tree.process_frame
	expect.call(arrow != null and arrow.visible, "Closing a button-opened menu should restore the click-targeting arrow")
	# Exercise the ordinary post-tutorial HUD surface rather than the guided run's
	# intentional optional-surface lock.
	instance.set("_guided_tutorial_phase_id", "")
	instance.call("_toggle_skill_status_popover")
	await tree.process_frame
	var skill_status_scrim: Control = instance.get("_skill_status_scrim") as Control
	expect.call(skill_status_scrim != null and skill_status_scrim.visible, "The Abilities popover fixture should open while a card remains selected")
	expect.call(int(instance.get("_selected_card_index")) == 0 and arrow != null and not arrow.visible, "Abilities should suspend click targeting without discarding the selected card")
	if cursor_feedback != null and cursor_feedback.has_method("glyph_visibility_suppressed"):
		expect.call(not bool(cursor_feedback.call("glyph_visibility_suppressed")), "Abilities should restore the forged pointer while its popover owns input")
	instance.call("_close_skill_status_popover")
	await tree.process_frame
	expect.call(arrow != null and arrow.visible, "Closing Abilities should restore the click-targeting arrow")
	if cursor_feedback != null and cursor_feedback.has_method("glyph_visibility_suppressed"):
		expect.call(bool(cursor_feedback.call("glyph_visibility_suppressed")), "Closing Abilities should return pointer ownership to click targeting")
	var skill_choice_options: Array = [{
		"text": "Keep Targeting",
		"detail": "Probe-only modal ownership option",
		"callback": Callable(instance, "_refresh_ui"),
	}]
	instance.call("_open_skill_choice_dialog", "Choose", "Probe modal ownership", skill_choice_options)
	await tree.process_frame
	var skill_choice_scrim: Control = instance.get("_skill_choice_scrim") as Control
	expect.call(skill_choice_scrim != null and skill_choice_scrim.visible, "The skill-choice fixture should open a valid option modal")
	expect.call(int(instance.get("_selected_card_index")) == 0 and arrow != null and not arrow.visible, "Skill choices should suspend click targeting without discarding the selected card")
	if cursor_feedback != null and cursor_feedback.has_method("glyph_visibility_suppressed"):
		expect.call(not bool(cursor_feedback.call("glyph_visibility_suppressed")), "Skill choices should restore the forged pointer while the modal owns input")
	instance.call("_close_skill_choice_dialog")
	await tree.process_frame
	expect.call(arrow != null and arrow.visible, "Closing a skill choice should restore the click-targeting arrow")
	if cursor_feedback != null and cursor_feedback.has_method("glyph_visibility_suppressed"):
		expect.call(bool(cursor_feedback.call("glyph_visibility_suppressed")), "Closing a skill choice should return pointer ownership to click targeting")

	instance.set("_show_all_enemy_intents", true)
	instance.call("_refresh_stage_view")
	var show_all_presentation: Dictionary = board.get("presentation") as Dictionary
	expect.call(not (show_all_presentation.get("enemy_threat_previews", []) as Array).is_empty(), "Explicit show-all intent mode should remain visible during card targeting")
	instance.set("_show_all_enemy_intents", false)
	await instance.call("_on_board_tile_clicked", enemy_tile)
	await tree.process_frame
	expect.call(_enemy_hp(instance) < enemy_hp_before and not _hand(instance).has("lantern_shot"), "A legal click-arrow target should resolve the selected card through the normal click path")
	expect.call(str(instance.get_meta("last_card_play_source_kind", "")) == "hand" and _last_play_source_inside_hand(instance), "Click-arrow play should retain the normal hand-origin launch")
	expect.call(arrow != null and not arrow.visible, "Playing through click targeting should clear the shared arrow")
	if cursor_feedback != null and cursor_feedback.has_method("glyph_visibility_suppressed"):
		expect.call(not bool(cursor_feedback.call("glyph_visibility_suppressed")), "Card resolution should restore the forged pointer after the targeting arrow clears")
	instance.queue_free()
	await tree.process_frame

	var cancel_instance: Node = await _live_instance(tree, expect, "lantern_shot", enemy_tile, 93110)
	if cancel_instance == null:
		return
	await cancel_instance.call("_on_card_pressed", 0)
	cancel_instance.call("_sync_click_targeting_arrow", _tile_global_position(cancel_instance, enemy_tile))
	await tree.process_frame
	var cancel_arrow: Control = cancel_instance.get("_drag_target_arrow") as Control
	await cancel_instance.call("_on_card_pressed", 0)
	await tree.process_frame
	expect.call(int(cancel_instance.get("_selected_card_index")) == -1 and _hand(cancel_instance).has("lantern_shot"), "A second click on a targeted card should retain the existing cancel behavior")
	expect.call(cancel_arrow != null and not cancel_arrow.visible, "Targeted-card second-click cancellation should clear the arrow")
	hand_box = cancel_instance.get("hand_box") as Control
	expect.call(hand_box != null and int(hand_box.call("emphasized_index")) == -1, "Targeted-card cancellation should release the selected-card hand pose")
	cursor_feedback = tree.root.get_node_or_null("CursorFeedback")
	if cursor_feedback != null and cursor_feedback.has_method("glyph_visibility_suppressed"):
		expect.call(not bool(cursor_feedback.call("glyph_visibility_suppressed")), "Targeted-card cancellation should restore the forged pointer")
	cancel_instance.call("_on_board_tile_hovered", enemy_tile)
	await tree.process_frame
	var cancel_board: Control = cancel_instance.get("board_view") as Control
	var restored_presentation: Dictionary = cancel_board.get("presentation") as Dictionary
	expect.call(not (restored_presentation.get("enemy_threat_previews", []) as Array).is_empty(), "Canceling targeting should immediately restore ordinary enemy hover forecasts")

	var drag_start: Vector2 = (cancel_instance.call("_hand_card_global_rect", 0) as Rect2).get_center()
	var drag_target: Vector2 = _tile_global_position(cancel_instance, enemy_tile)
	cancel_instance.call("_on_card_drag_started", 0, drag_start)
	await cancel_instance.call("_update_card_drag", drag_target)
	await tree.process_frame
	expect.call(bool(cancel_instance.get("_drag_targeting_active")), "Dragging a targeted card onto the board should enter the same aiming mode")
	var drag_targeting_presentation: Dictionary = cancel_board.get("presentation") as Dictionary
	expect.call((drag_targeting_presentation.get("enemy_threat_previews", []) as Array).is_empty(), "Drag targeting should suppress the same hover-driven enemy threat preview as click targeting")
	expect.call(not _presentation_has_enemy_movement_preview(drag_targeting_presentation), "Drag targeting should also remove the enemy movement destination ghost")
	var player_attack_effect: Dictionary = drag_targeting_presentation.get("effect", {}) as Dictionary
	expect.call(str(player_attack_effect.get("kind", "")) == "ranged" and not bool(player_attack_effect.get("target_curve_visible", true)), "Player ranged targeting should yield its curved trajectory to the card-origin arrow")
	expect.call(not (player_attack_effect.get("damage_preview", {}) as Dictionary).is_empty(), "Suppressing the player trajectory must preserve projected damage evidence")
	expect.call(not bool(cancel_board.call("_target_preview_curve_visible", player_attack_effect)), "The board renderer should honor the player preview's suppressed trajectory flag")
	expect.call(bool(cancel_instance.call("_player_preview_target_curve_visible", "push")), "Push targeting should retain its distinct forced-movement trajectory cue")
	expect.call(bool(cancel_instance.call("_player_preview_target_curve_visible", "pull")), "Pull targeting should retain its distinct forced-movement trajectory cue")
	expect.call(bool(cancel_instance.call("_player_preview_target_curve_visible", "aoe")), "AOE targeting should retain its cast-path cue")
	if cursor_feedback != null and cursor_feedback.has_method("glyph_visibility_suppressed"):
		expect.call(bool(cursor_feedback.call("glyph_visibility_suppressed")), "Drag targeting should suppress the forged pointer while the shared arrow owns aiming")
	cancel_instance.queue_free()
	await tree.process_frame
	if cursor_feedback != null and cursor_feedback.has_method("glyph_visibility_suppressed"):
		expect.call(not bool(cursor_feedback.call("glyph_visibility_suppressed")), "Leaving the scene during active targeting should release forged-pointer suppression")


static func _test_controller_first_card_press_enters_shared_targeting(tree: SceneTree, expect: Callable) -> void:
	var input_router: Node = tree.root.get_node_or_null("InputRouter")
	expect.call(input_router != null and input_router.has_method("set_forced_state_for_test"), "Controller-first targeting proof requires the test input router")
	if input_router == null or not input_router.has_method("set_forced_state_for_test"):
		return
	if input_router.has_method("clear_forced_state_for_test"):
		input_router.call("clear_forced_state_for_test")
	input_router.call("set_forced_state_for_test", "controller", "steam_deck")
	var enemy_tile := Vector2i(5, 4)
	var instance: Node = await _live_instance(tree, expect, "lantern_shot", enemy_tile, 93118)
	if instance == null:
		input_router.call("set_forced_state_for_test", "pointer", "steam_deck")
		return
	instance.set("_controller_region", "hand")
	instance.call("_controller_set_hand_focused", true)
	instance.call("_controller_set_hand_index", 0)
	await tree.create_timer(0.18).timeout
	expect.call(int(instance.get("_hovered_card_index")) == 0 and int(instance.get("_selected_card_index")) == -1, "Controller hand focus should begin in the same large card-preview state as pointer hover")
	await instance.call("_controller_activate_current")
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	var arrow: Control = instance.get("_drag_target_arrow") as Control
	var analog_cursor: Control = instance.get("_controller_analog_cursor") as Control
	var hand_box: Control = instance.get("hand_box") as Control
	var focus_candidate: Dictionary = instance.get("_controller_focus_candidate") as Dictionary
	var endpoint: Vector2 = focus_candidate.get("point", Vector2.ZERO)
	expect.call(int(instance.get("_selected_card_index")) == 0 and int(instance.get("_hovered_card_index")) == -1, "Controller Accept should turn hand preview into the same persistent selected-card state as the first pointer click")
	expect.call(str(instance.get("_controller_region")) == "board" and not bool(instance.get("_controller_hand_focused")), "Controller card selection should tuck the hand and transfer focus to board targeting")
	expect.call(hand_box != null and int(hand_box.call("emphasized_index")) == 0, "The controller-selected card should retain the restrained raised targeting pose")
	expect.call(instance.get("_controller_board_tile") == enemy_tile and not focus_candidate.is_empty(), "Controller-first targeting should choose the card's preferred legal square")
	expect.call(arrow != null and arrow.visible and bool(arrow.get_meta("segmented_raster_arrow", false)), "Controller-first targeting should enter the shared segmented card-origin arrow path")
	if arrow != null:
		var arrow_transform: Transform2D = arrow.get_global_transform_with_canvas()
		expect.call((arrow_transform * (arrow.call("targeting_end") as Vector2)).distance_to(endpoint) <= 1.0, "Controller-first targeting arrow should terminate at the focused board candidate")
	expect.call(analog_cursor != null and not analog_cursor.visible, "Controller-first card targeting should hide the competing analog puck")
	await instance.call("_on_cancel_requested")
	await tree.process_frame
	expect.call(int(instance.get("_selected_card_index")) == -1 and arrow != null and not arrow.visible, "Controller-first targeting should cancel through the shared selected-card state")
	instance.queue_free()
	await tree.process_frame
	input_router.call("set_forced_state_for_test", "pointer", "steam_deck")


static func _test_controller_targeting_reuses_shared_arrow(tree: SceneTree, expect: Callable) -> void:
	var input_router: Node = tree.root.get_node_or_null("InputRouter")
	expect.call(input_router != null and input_router.has_method("set_forced_state_for_test"), "Controller targeting proof requires the test input router")
	if input_router == null or not input_router.has_method("set_forced_state_for_test"):
		return
	if input_router.has_method("clear_forced_state_for_test"):
		input_router.call("clear_forced_state_for_test")
	input_router.call("set_forced_state_for_test", "pointer", "steam_deck")
	var enemy_tile := Vector2i(5, 4)
	var instance: Node = await _live_instance(tree, expect, "lantern_shot", enemy_tile, 93116)
	if instance == null:
		return
	var hand_before: Array = _hand(instance).duplicate()
	var enemy_hp_before: int = _enemy_hp(instance)
	await instance.call("_on_card_pressed", 0)
	await tree.process_frame
	input_router.call("set_forced_state_for_test", "controller", "steam_deck")
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame

	var arrow: Control = instance.get("_drag_target_arrow") as Control
	var analog_cursor: Control = instance.get("_controller_analog_cursor") as Control
	var board: Control = instance.get("board_view") as Control
	var focus_candidate: Dictionary = instance.get("_controller_focus_candidate") as Dictionary
	var expected_endpoint: Vector2 = focus_candidate.get("point", Vector2.ZERO)
	expect.call(int(instance.get("_selected_card_index")) == 0 and int(instance.get("_drag_card_index")) == -1, "Controller aiming should reuse the persistent selected-card state without creating a pointer drag")
	expect.call(instance.get("_controller_board_tile") == enemy_tile and board.get("_controller_focus_tile") == enemy_tile, "Controller targeting should retain its exact focused board-square evidence")
	expect.call(arrow != null and arrow.visible and bool(arrow.get_meta("segmented_raster_arrow", false)), "Controller targeting should reuse the same segmented card-origin arrow as pointer targeting")
	if arrow != null:
		var arrow_transform: Transform2D = arrow.get_global_transform_with_canvas()
		var source_card: Control = instance.call("_hand_card_control", 0) as Control
		var source_rect: Rect2 = instance.call("_control_visual_global_rect", source_card)
		var expected_start: Vector2 = source_rect.position + Vector2(source_rect.size.x * 0.5, 4.0)
		expect.call((arrow_transform * (arrow.call("targeting_start") as Vector2)).distance_to(expected_start) <= 1.0, "Controller and pointer targeting should share the selected hand-card anchor")
		expect.call((arrow_transform * (arrow.call("targeting_end") as Vector2)).distance_to(expected_endpoint) <= 1.0, "Controller arrowhead should land on the focused candidate point rather than a stale mouse position")
	expect.call(analog_cursor != null and not analog_cursor.visible, "The controller analog puck should hide while the shared arrow owns card targeting")
	expect.call(not bool(instance.get_meta("targeting_cursor_suppressed", false)), "Controller arrow ownership should not strand the pointer-only cursor suppressor")
	instance.call("_refresh_stage_view")
	var controller_presentation: Dictionary = board.get("presentation") as Dictionary
	var controller_effect: Dictionary = controller_presentation.get("effect", {}) as Dictionary
	expect.call(str(controller_effect.get("action_type", "")) == "ranged" and not bool(controller_effect.get("target_curve_visible", true)), "Controller card aiming should suppress the same redundant direct-ranged board curve as pointer aiming")
	expect.call(not (controller_effect.get("damage_preview", {}) as Dictionary).is_empty(), "Controller curve suppression should preserve projected damage evidence")

	# Empty focus with a finite virtual position is intentional free-cursor aiming,
	# not an uninitialized controller handoff. Deferred layout work must not snap it
	# back to the first legal target, and Accept must remain inert between squares.
	instance.call("_controller_clear_focus_candidate")
	var free_endpoint: Vector2 = _tile_global_position(instance, Vector2i(4, 3)) + Vector2(13.0, -9.0)
	instance.set("_controller_virtual_board_position", free_endpoint)
	instance.call("_sync_click_targeting_arrow")
	await instance.call("_refresh_controller_after_layout")
	expect.call((instance.get("_controller_focus_candidate") as Dictionary).is_empty() and instance.get("_controller_board_tile") == NO_TARGET_TILE, "Controller layout refresh should preserve intentional free-cursor targeting between candidates")
	if arrow != null:
		var free_transform: Transform2D = arrow.get_global_transform_with_canvas()
		expect.call((free_transform * (arrow.call("targeting_end") as Vector2)).distance_to(free_endpoint) <= 1.0, "Controller layout refresh should preserve the finite free-cursor arrow endpoint")
	var free_hand_before: Array = _hand(instance).duplicate()
	var free_enemy_hp_before: int = _enemy_hp(instance)
	await instance.call("_controller_activate_current")
	expect.call(_hand(instance) == free_hand_before and _enemy_hp(instance) == free_enemy_hp_before, "Controller Accept between board candidates should not resolve the selected card")

	var invalid_focus_tile := PLAYER_TILE
	instance.call("_controller_set_board_tile", invalid_focus_tile)
	await tree.process_frame
	var invalid_endpoint: Vector2 = (instance.get("_controller_focus_candidate") as Dictionary).get("point", Vector2.ZERO)
	if arrow != null:
		var moved_transform: Transform2D = arrow.get_global_transform_with_canvas()
		expect.call((moved_transform * (arrow.call("targeting_end") as Vector2)).distance_to(invalid_endpoint) <= 1.0, "Moving controller focus should move the shared arrow endpoint through the same persistent targeting state")
	expect.call(board.get("_controller_focus_tile") == invalid_focus_tile and _hand(instance) == hand_before, "Focusing an illegal controller square should remain non-destructive and visibly focused")

	instance.call("_open_menu_overlay")
	await tree.process_frame
	expect.call(int(instance.get("_selected_card_index")) == 0 and arrow != null and not arrow.visible, "A controller-opened modal should suspend the shared arrow without discarding the selected card")
	expect.call(analog_cursor != null and not analog_cursor.visible, "Modal ownership should not revive the controller puck over a suspended targeting arrow")
	instance.call("_close_menu_overlay")
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	expect.call(arrow != null and arrow.visible, "Closing a controller modal should restore the shared targeting arrow")
	if arrow != null:
		var restored_endpoint: Vector2 = (instance.get("_controller_focus_candidate") as Dictionary).get("point", Vector2.ZERO)
		var restored_transform: Transform2D = arrow.get_global_transform_with_canvas()
		expect.call((restored_transform * (arrow.call("targeting_end") as Vector2)).distance_to(restored_endpoint) <= 1.0, "Controller modal recovery should re-anchor the arrow to the restored board candidate")

	instance.call("_controller_set_board_tile", enemy_tile)
	await tree.process_frame
	await instance.call("_controller_activate_current")
	await tree.process_frame
	expect.call(_enemy_hp(instance) < enemy_hp_before and not _hand(instance).has("lantern_shot"), "Controller Accept should resolve the same selected-card target path exactly once")
	expect.call(str(instance.get_meta("last_card_play_source_kind", "")) == "hand" and _last_play_source_inside_hand(instance), "Controller arrow confirmation should retain the normal hand-origin play launch")
	expect.call(arrow != null and not arrow.visible and analog_cursor != null and not analog_cursor.visible, "Controller card resolution should clear the shared arrow and return focus to the hand")
	instance.queue_free()
	await tree.process_frame

	var cancel_instance: Node = await _live_instance(tree, expect, "lantern_shot", enemy_tile, 93117)
	if cancel_instance != null:
		var cancel_hand: Array = _hand(cancel_instance).duplicate()
		await cancel_instance.call("_on_card_pressed", 0)
		cancel_instance.call("_controller_enter_board", true)
		await tree.process_frame
		var cancel_arrow: Control = cancel_instance.get("_drag_target_arrow") as Control
		expect.call(cancel_arrow != null and cancel_arrow.visible, "Controller cancel proof should begin in shared-arrow targeting")
		await cancel_instance.call("_on_cancel_requested")
		await tree.process_frame
		expect.call(int(cancel_instance.get("_selected_card_index")) == -1 and _hand(cancel_instance) == cancel_hand, "Controller Cancel should leave the card unspent and exit the same selected-card targeting state")
		expect.call(cancel_arrow != null and not cancel_arrow.visible, "Controller Cancel should clear the shared card-origin arrow")
		cancel_instance.queue_free()
		await tree.process_frame
	input_router.call("set_forced_state_for_test", "pointer", "steam_deck")


static func _test_modal_controller_handoff_suspends_targeting_cursors(tree: SceneTree, expect: Callable) -> void:
	var input_router: Node = tree.root.get_node_or_null("InputRouter")
	if input_router == null or not input_router.has_method("set_forced_state_for_test"):
		return
	if input_router.has_method("clear_forced_state_for_test"):
		input_router.call("clear_forced_state_for_test")
	input_router.call("set_forced_state_for_test", "pointer", "steam_deck")
	var enemy_tile := Vector2i(5, 4)
	var instance: Node = await _live_instance(tree, expect, "lantern_shot", enemy_tile, 93119)
	if instance == null:
		return
	await instance.call("_on_card_pressed", 0)
	instance.call("_open_menu_overlay")
	await tree.process_frame
	input_router.call("set_forced_state_for_test", "controller", "steam_deck")
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	var arrow: Control = instance.get("_drag_target_arrow") as Control
	var analog_cursor: Control = instance.get("_controller_analog_cursor") as Control
	expect.call(int(instance.get("_selected_card_index")) == 0, "Controller handoff behind a modal should preserve the selected targeting card")
	expect.call(arrow != null and not arrow.visible and analog_cursor != null and not analog_cursor.visible, "Controller handoff behind a modal should keep both the targeting arrow and analog puck suspended")
	instance.call("_close_menu_overlay")
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	var focus_candidate: Dictionary = instance.get("_controller_focus_candidate") as Dictionary
	var restored_endpoint: Vector2 = focus_candidate.get("point", Vector2.ZERO)
	expect.call(instance.get("_controller_board_tile") == enemy_tile and not focus_candidate.is_empty(), "Closing the modal should initialize the controller card's preferred legal target")
	expect.call(arrow != null and arrow.visible and analog_cursor != null and not analog_cursor.visible, "Closing the modal should restore the shared targeting arrow without reviving the puck")
	if arrow != null:
		var arrow_transform: Transform2D = arrow.get_global_transform_with_canvas()
		expect.call((arrow_transform * (arrow.call("targeting_end") as Vector2)).distance_to(restored_endpoint) <= 1.0, "Modal recovery should restore the arrow at the preferred controller target")
	instance.queue_free()
	await tree.process_frame
	input_router.call("set_forced_state_for_test", "pointer", "steam_deck")


static func _test_controller_handoff_cancels_pointer_drags(tree: SceneTree, expect: Callable) -> void:
	var input_router: Node = tree.root.get_node_or_null("InputRouter")
	if input_router != null:
		if input_router.has_method("clear_forced_state_for_test"):
			input_router.call("clear_forced_state_for_test")
		input_router.call("set_modality", "pointer")
	var preboard_instance: Node = await _live_instance(tree, expect, "quick_stab", TARGET_TILE, 93113)
	if preboard_instance == null:
		return
	var preboard_hand: Array = _hand(preboard_instance).duplicate()
	var preboard_source: Control = preboard_instance.call("_hand_card_control", 0) as Control
	preboard_instance.call("_on_card_drag_started", 0, _drag_start_position(preboard_instance, 0))
	await tree.process_frame
	expect.call(preboard_instance.get("_drag_card_proxy") != null and int(preboard_instance.get("_drag_card_index")) == 0, "The pre-board fixture should hold a live pointer-following card before controller handoff")
	var drift_motion := InputEventJoypadMotion.new()
	drift_motion.device = 0
	drift_motion.axis = JOY_AXIS_LEFT_X
	drift_motion.axis_value = InputRouterScript.JOYSTICK_ACTIVITY_THRESHOLD * 0.5
	var drift_handled: bool = bool(await preboard_instance.call("_handle_controller_input", drift_motion))
	expect.call(not drift_handled and int(preboard_instance.get("_drag_card_index")) == 0, "Sub-threshold gamepad drift should not steal pointer modality or cancel a live mouse drag")
	var active_motion := InputEventJoypadMotion.new()
	active_motion.device = 0
	active_motion.axis = JOY_AXIS_LEFT_X
	active_motion.axis_value = InputRouterScript.JOYSTICK_ACTIVITY_THRESHOLD + 0.1
	await preboard_instance.call("_handle_controller_input", active_motion)
	expect.call(int(preboard_instance.get("_drag_card_index")) == -1 and preboard_instance.get("_drag_card_proxy") == null, "Real controller activity should synchronously cancel a pre-board pointer drag")
	preboard_instance.set("_controller_stick", Vector2(0.8, 0.0))
	var neutral_motion := InputEventJoypadMotion.new()
	neutral_motion.device = 0
	neutral_motion.axis = JOY_AXIS_LEFT_X
	neutral_motion.axis_value = 0.0
	var neutral_handled: bool = bool(await preboard_instance.call("_handle_controller_input", neutral_motion))
	expect.call(neutral_handled and is_zero_approx((preboard_instance.get("_controller_stick") as Vector2).x), "Neutral motion should still clear a stale stick axis after controller modality is active")
	await tree.process_frame
	expect.call(preboard_source != null and preboard_source.is_visible_in_tree() and _hand(preboard_instance) == preboard_hand, "Canceling a pre-board drag for controller input should restore the exact card without spending it")
	await preboard_instance.call("_commit_drag_drop", "play", _tile_global_position(preboard_instance, TARGET_TILE))
	expect.call(_hand(preboard_instance) == preboard_hand, "A stale mouse release after controller handoff must not commit the canceled pre-board drag")
	preboard_instance.queue_free()
	await tree.process_frame
	if input_router != null:
		input_router.call("set_modality", "pointer")

	var latched_instance: Node = await _live_instance(tree, expect, "quick_stab", TARGET_TILE, 93114)
	if latched_instance == null:
		return
	var latched_hand: Array = _hand(latched_instance).duplicate()
	var enemy_hp_before: int = _enemy_hp(latched_instance)
	latched_instance.call("_on_card_drag_started", 0, _drag_start_position(latched_instance, 0))
	await tree.process_frame
	var target_position: Vector2 = _tile_global_position(latched_instance, TARGET_TILE)
	await latched_instance.call("_update_card_drag", target_position)
	await tree.process_frame
	var latched_arrow: Control = latched_instance.get("_drag_target_arrow") as Control
	expect.call(bool(latched_instance.get("_drag_targeting_active")) and latched_arrow != null and latched_arrow.visible, "The latched fixture should own the pointer targeting arrow before controller handoff")
	await latched_instance.call("_handle_controller_input", active_motion)
	expect.call(int(latched_instance.get("_drag_card_index")) == -1 and int(latched_instance.get("_selected_card_index")) == -1, "Real controller activity should synchronously clear both drag and preview state after board targeting has latched")
	await tree.process_frame
	expect.call(latched_instance.get("_drag_card_proxy") == null and latched_arrow != null and not latched_arrow.visible, "Controller handoff should leave no stale card proxy or pointer arrow")
	var cursor_feedback: Node = tree.root.get_node_or_null("CursorFeedback")
	if cursor_feedback != null and cursor_feedback.has_method("glyph_visibility_suppressed"):
		expect.call(not bool(cursor_feedback.call("glyph_visibility_suppressed")), "Controller handoff should release pointer-targeting cursor suppression")
	await latched_instance.call("_commit_drag_drop", "play", target_position)
	expect.call(_hand(latched_instance) == latched_hand and _enemy_hp(latched_instance) == enemy_hp_before, "A stale mouse release after controller handoff must not resolve a latched drag")
	latched_instance.queue_free()
	await tree.process_frame
	if input_router != null:
		input_router.call("set_modality", "pointer")


static func _test_targetless_click_confirmation_paths(tree: SceneTree, expect: Callable) -> void:
	var second_click_instance: Node = await _live_instance(tree, expect, "stone_plate", Vector2i(5, 4), 93111)
	if second_click_instance == null:
		return
	var stoneskin_before: int = int(((second_click_instance.get("_combat_state") as Dictionary).get("player", {}) as Dictionary).get("stoneskin", 0))
	await second_click_instance.call("_on_card_pressed", 0)
	await tree.process_frame
	expect.call(bool(second_click_instance.call("_pending_card_requires_confirmation")), "The first targetless card click should retain its readable selected confirmation state")
	var targetless_arrow: Control = second_click_instance.get("_drag_target_arrow") as Control
	expect.call(targetless_arrow != null and not targetless_arrow.visible, "A targetless selected card should not show a tile-targeting arrow")
	var hand_box: Control = second_click_instance.get("hand_box") as Control
	expect.call(hand_box != null and int(hand_box.call("emphasized_index")) == 0, "Targetless click confirmation should keep the card visibly selected without the large hover pose")
	await second_click_instance.call("_on_card_pressed", 0)
	await tree.process_frame
	var stoneskin_after: int = int(((second_click_instance.get("_combat_state") as Dictionary).get("player", {}) as Dictionary).get("stoneskin", 0))
	expect.call(stoneskin_after > stoneskin_before and not _hand(second_click_instance).has("stone_plate"), "Clicking the selected targetless card a second time should confirm and play it exactly once")
	expect.call(str(second_click_instance.get_meta("last_card_play_source_kind", "")) == "hand" and _last_play_source_inside_hand(second_click_instance), "Targetless second-click confirmation should launch from the hand")
	second_click_instance.queue_free()
	await tree.process_frame

	var player_click_instance: Node = await _live_instance(tree, expect, "stone_plate", Vector2i(5, 4), 93112)
	if player_click_instance == null:
		return
	stoneskin_before = int(((player_click_instance.get("_combat_state") as Dictionary).get("player", {}) as Dictionary).get("stoneskin", 0))
	await player_click_instance.call("_on_card_pressed", 0)
	await player_click_instance.call("_on_board_tile_clicked", PLAYER_TILE)
	await tree.process_frame
	stoneskin_after = int(((player_click_instance.get("_combat_state") as Dictionary).get("player", {}) as Dictionary).get("stoneskin", 0))
	expect.call(stoneskin_after > stoneskin_before and not _hand(player_click_instance).has("stone_plate"), "Clicking the player should remain a valid targetless-card confirmation path")
	player_click_instance.queue_free()
	await tree.process_frame


static func _live_instance(tree: SceneTree, expect: Callable, card_id: String, enemy_tile: Vector2i, seed: int) -> Node:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	expect.call(packed != null, "Card drag integration fixture should load RunScene")
	if packed == null:
		return null
	var instance: Node = packed.instantiate()
	tree.root.add_child(instance)
	await tree.process_frame
	await tree.process_frame
	var combat := CombatEngine.new()
	var layout: Dictionary = _layout(enemy_tile)
	var state: Dictionary = combat.create_combat(seed, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": [card_id],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0,
	})
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = [card_id]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	state["deck"] = deck
	state["current_actor"] = {"kind": "player", "key": "player"}
	state["cards_played_this_turn"] = 0
	state["death_bonus_card_plays_this_turn"] = 0
	state["card_play_bonus_this_turn"] = 0
	state.erase("player_turn_restrictions")
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = state
	instance.set("_guided_tutorial_phase_id", "")
	instance.set("_run_state", run_state)
	instance.set("_combat_state", state)
	instance.call("_mark_combat_preview_state_changed")
	instance.call("_refresh_ui")
	await tree.process_frame
	await tree.process_frame
	return instance


static func _tile_global_position(instance: Node, tile: Vector2i) -> Vector2:
	var board: Control = instance.get("board_view") as Control
	return board.get_global_transform_with_canvas() * (board.call("world_position_for_tile", tile) as Vector2)


static func _drag_start_position(instance: Node, hand_index: int) -> Vector2:
	return (instance.call("_hand_card_global_rect", hand_index) as Rect2).get_center()


static func _last_play_source_inside_hand(instance: Node) -> bool:
	var source_rect: Rect2 = instance.get_meta("last_card_play_source_rect", Rect2()) as Rect2
	var hand_scroll: Control = instance.get("hand_scroll") as Control
	return (
		hand_scroll != null
		and source_rect.size.length_squared() > 0.0
		and hand_scroll.get_global_rect().grow(72.0).has_point(source_rect.get_center())
	)


static func _hand(instance: Node) -> Array:
	return (((instance.get("_combat_state") as Dictionary).get("deck", {}) as Dictionary).get("hand", []) as Array)


static func _enemy_hp(instance: Node) -> int:
	var enemies: Array = (instance.get("_combat_state") as Dictionary).get("enemies", []) as Array
	return int((enemies[0] as Dictionary).get("hp", 0)) if not enemies.is_empty() else 0


static func _presentation_has_enemy_movement_preview(presentation: Dictionary) -> bool:
	for preview_var: Variant in presentation.get("preview_units", []):
		if typeof(preview_var) == TYPE_DICTIONARY and str((preview_var as Dictionary).get("role", "")) == "enemy_move_preview":
			return true
	return false


static func _turn_order_has_card_projection(instance: Node, card_name: String) -> bool:
	var turn_order_bar: Control = instance.get("_turn_order_bar") as Control
	if turn_order_bar == null:
		return false
	for child: Node in turn_order_bar.get_children():
		if str(child.get_meta("turn_order_projection_card_name", "")) == card_name:
			return true
	return false


static func _layout(enemy_tile: Vector2i) -> Dictionary:
	return {
		"name": "Card Drag Play Test",
		"coord": Vector2i(4, 1),
		"type": "combat",
		"element": "earth",
		"grid": _grid(),
		"player_start": PLAYER_TILE,
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": enemy_tile,
			"hp": 100,
			"max_hp": 100,
			"block": 0,
		}],
		"traps": [],
		"loot": [],
		"terrain": [],
	}


static func _grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return grid

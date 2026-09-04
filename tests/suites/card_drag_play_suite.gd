extends RefCounted

const CardDragPlayRules = preload("res://scripts/card_drag_play_rules.gd")
const CardDragTargetingArrow = preload("res://scripts/card_drag_targeting_arrow.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const CardWidgetScene = preload("res://scenes/card_widget.tscn")

const PLAYER_TILE := Vector2i(2, 4)
const TARGET_TILE := Vector2i(3, 4)
const INVALID_TILE := Vector2i(6, 6)


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
		CardDragPlayRules.release_outcome(true, targeted_preview, false) == CardDragPlayRules.OUTCOME_CANCEL,
		"An illegal targeted board release should cancel"
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
	expect.call(FileAccess.file_exists(CardDragTargetingArrow.RIBBON_ASSET_PATH), "Targeting arrow should own a raster ribbon asset")
	expect.call(FileAccess.file_exists(CardDragTargetingArrow.HEAD_ASSET_PATH), "Targeting arrow should own a separate raster arrowhead asset")
	var start := Vector2(960.0, 900.0)
	for finish: Vector2 in PackedVector2Array([Vector2(430.0, 360.0), Vector2(960.0, 280.0), Vector2(1490.0, 360.0)]):
		var points: PackedVector2Array = CardDragTargetingArrow.sampled_curve(start, finish)
		expect.call(points.size() >= 4 and points[0].is_equal_approx(start) and points[points.size() - 1].is_equal_approx(finish), "Raster arrow samples should exactly connect the selected card to left, center, and right targets")
		var previous_tangent := Vector2.ZERO
		for index: int in range(points.size() - 1):
			var tangent: Vector2 = (points[index + 1] - points[index]).normalized()
			if previous_tangent.length_squared() > 0.0:
				expect.call(previous_tangent.dot(tangent) > 0.82, "Raster arrow samples should bend smoothly without broken or kinked segment joins")
			previous_tangent = tangent
	var source := FileAccess.open("res://scripts/card_drag_targeting_arrow.gd", FileAccess.READ)
	var source_text: String = source.get_as_text() if source != null else ""
	expect.call(not source_text.contains("draw_line") and not source_text.contains("draw_polyline") and not source_text.contains("draw_polygon"), "Targeting arrow must be composed from raster pieces rather than procedural line or polygon geometry")


static func run_live(tree: SceneTree, expect: Callable) -> void:
	await _test_card_widget_drag_threshold(tree, expect)
	await _test_off_center_follow_and_snapback(tree, expect)
	await _test_targeted_drag_entry_and_invalid_release(tree, expect)
	await _test_targeted_leaving_board_cancels(tree, expect)
	await _test_targeted_valid_release_plays(tree, expect)
	await _test_compound_target_release_plays(tree, expect)
	await _test_targetless_board_and_outside_releases(tree, expect)
	await _test_click_targeting_regression(tree, expect)


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
	expect.call(str(arrow.get_meta("ribbon_asset_path", "")).ends_with("card_drag_arrow_ribbon_v1.png") and str(arrow.get_meta("head_asset_path", "")).ends_with("card_drag_arrow_head_v1.png"), "The targeting arrow should use authored raster ribbon and head pieces")
	expect.call(not context.visible, "Arrow targeting should remain free of instructional side copy")
	var invalid_position: Vector2 = _tile_global_position(instance, INVALID_TILE)
	await instance.call("_update_card_drag", invalid_position)
	await tree.process_frame
	expect.call(bool(instance.get("_drag_targeting_active")) and arrow.visible, "Targeting should stay latched while the pointer moves across invalid space")
	expect.call(source_card.modulate.is_equal_approx(Color.WHITE), "Invalid targets should not recolor the card")
	await instance.call("_commit_drag_drop", "play", invalid_position)
	await tree.process_frame
	expect.call(int(instance.get("_drag_card_index")) == -1 and int(instance.get("_selected_card_index")) == -1, "Invalid target release should clear both drag and targeting state")
	expect.call(_hand(instance) == hand_before, "Invalid target release should not consume or spend the card")
	expect.call((instance.call("_turn_order_card_time_preview") as Dictionary).is_empty(), "Invalid target release should clear the Turn Clock card-time preview")
	expect.call(not _turn_order_has_card_projection(instance, "Quick Stab"), "Invalid target release should rebuild the Turn Clock without the canceled card projection")
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

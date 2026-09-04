extends RefCounted

const CardDragPlayRules = preload("res://scripts/card_drag_play_rules.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")

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
	var valid_cue: Dictionary = CardDragPlayRules.visual_cue(true, targeted_preview, true)
	var invalid_cue: Dictionary = CardDragPlayRules.visual_cue(true, targeted_preview, false)
	expect.call(str(valid_cue.get("verb", "")) == "RELEASE TO PLAY" and str(valid_cue.get("target", "")) == "VALID TARGET", "Legal target feedback should use both an action verb and target-state label")
	expect.call(str(invalid_cue.get("verb", "")) == "RELEASE CANCELS" and str(invalid_cue.get("target", "")) == "INVALID TARGET", "Illegal target feedback should state the cancel consequence without relying on color")


static func run_live(tree: SceneTree, expect: Callable) -> void:
	await _test_targeted_drag_entry_and_invalid_release(tree, expect)
	await _test_targeted_leaving_board_cancels(tree, expect)
	await _test_targeted_valid_release_plays(tree, expect)
	await _test_compound_target_release_plays(tree, expect)
	await _test_targetless_board_and_outside_releases(tree, expect)
	await _test_click_targeting_regression(tree, expect)


static func _test_targeted_drag_entry_and_invalid_release(tree: SceneTree, expect: Callable) -> void:
	var instance: Node = await _live_instance(tree, expect, "quick_stab", TARGET_TILE, 93101)
	if instance == null:
		return
	var hand_before: Array = _hand(instance).duplicate()
	instance.call("_on_card_drag_started", 0)
	await tree.process_frame
	var valid_position: Vector2 = _tile_global_position(instance, TARGET_TILE)
	await instance.call("_update_card_drag", valid_position)
	await tree.process_frame
	expect.call(bool(instance.get("_drag_targeting_active")), "Crossing onto the board with a targeted card should enter targeting before release")
	expect.call(int(instance.get("_selected_card_index")) == 0, "Drag targeting should arm the exact held card")
	expect.call((instance.get("_pending_target_tiles") as Array).has(TARGET_TILE), "Drag targeting should expose the normal legal target set")
	var context: Control = instance.get("_action_step_tracker") as Control
	expect.call(str(context.get_meta("target_state", "")) == "VALID TARGET", "A legal hovered square should be labeled as a valid target while held")
	var invalid_position: Vector2 = _tile_global_position(instance, INVALID_TILE)
	await instance.call("_update_card_drag", invalid_position)
	await tree.process_frame
	var invalid_verb: String = str(context.get_meta("action_verb", ""))
	expect.call(invalid_verb == "RELEASE CANCELS", "An illegal hovered square should preview the cancel consequence (got %s)" % invalid_verb)
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
	instance.call("_on_card_drag_started", 0)
	await tree.process_frame
	await instance.call("_update_card_drag", _tile_global_position(instance, TARGET_TILE))
	var outside_position := Vector2(8.0, 8.0)
	await instance.call("_update_card_drag", outside_position)
	await tree.process_frame
	expect.call(not bool(instance.get("_drag_targeting_active")) and int(instance.get("_selected_card_index")) == -1, "Leaving the board while held should leave targeting mode and restore a clean cancel state")
	await instance.call("_commit_drag_drop", "", outside_position)
	await tree.process_frame
	expect.call(_hand(instance) == hand_before and int(instance.get("_drag_card_index")) == -1, "Releasing a targeted card after leaving the board should cancel without spending it")
	instance.queue_free()
	await tree.process_frame


static func _test_targeted_valid_release_plays(tree: SceneTree, expect: Callable) -> void:
	var instance: Node = await _live_instance(tree, expect, "quick_stab", TARGET_TILE, 93102)
	if instance == null:
		return
	var enemy_hp_before: int = _enemy_hp(instance)
	instance.call("_on_card_drag_started", 0)
	await tree.process_frame
	var target_position: Vector2 = _tile_global_position(instance, TARGET_TILE)
	await instance.call("_update_card_drag", target_position)
	await instance.call("_commit_drag_drop", "play", target_position)
	await tree.process_frame
	expect.call(_enemy_hp(instance) < enemy_hp_before, "Releasing a targeted card on a legal square should resolve its effect")
	expect.call(not _hand(instance).has("quick_stab"), "A successful targeted drag should consume the exact hand card")
	expect.call(int(instance.get("_selected_card_index")) == -1 and instance.get("_drag_commit_proxy") == null, "A successful targeted drag should finish without stranded selection or proxy state")
	instance.queue_free()
	await tree.process_frame


static func _test_compound_target_release_plays(tree: SceneTree, expect: Callable) -> void:
	var compound_enemy_tile := Vector2i(5, 4)
	var instance: Node = await _live_instance(tree, expect, "sidestep_slash", compound_enemy_tile, 93103)
	if instance == null:
		return
	var enemy_hp_before: int = _enemy_hp(instance)
	instance.call("_on_card_drag_started", 0)
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
	cancel_instance.call("_on_card_drag_started", 0)
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
	play_instance.call("_on_card_drag_started", 0)
	await tree.process_frame
	var board_position: Vector2 = (play_instance.get("board_view") as Control).get_global_rect().get_center()
	await play_instance.call("_update_card_drag", board_position)
	expect.call(not bool(play_instance.get("_drag_targeting_active")) and int(play_instance.get("_selected_card_index")) == -1, "Targetless board drag should advertise confirmation without entering tile targeting")
	await play_instance.call("_commit_drag_drop", "play", board_position)
	await tree.process_frame
	var stoneskin_after: int = int(((play_instance.get("_combat_state") as Dictionary).get("player", {}) as Dictionary).get("stoneskin", 0))
	expect.call(stoneskin_after > stoneskin_before and not _hand(play_instance).has("stone_plate"), "Targetless release anywhere over the board should resolve the card")
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

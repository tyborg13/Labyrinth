extends SceneTree

const GameData = preload("res://scripts/game_data.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("user://probes")
	ProgressionStore.clear_saved_run()
	await _capture_scene("res://scenes/main_menu.tscn", "user://probes/main_menu.png")
	await _capture_run_states()
	print(ProjectSettings.globalize_path("user://probes"))
	quit()

func _capture_scene(scene_path: String, output_path: String) -> void:
	var packed: PackedScene = load(scene_path)
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	await _save_root_screenshot(output_path)
	instance.queue_free()
	await process_frame

func _capture_run_states() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	var probe_run_engine := RunEngine.new()
	instance.call("_load_run_state", probe_run_engine.create_new_run(123, ProgressionStore.default_data()))
	await process_frame
	await process_frame
	await _save_root_screenshot("user://probes/run_start.png")

	var run_state: Dictionary = instance.get("_run_state")
	var run_engine = instance.get("_run_engine")
	var combat_coord: Vector2i = Vector2i.ZERO
	for coord: Vector2i in run_engine.available_moves(run_state):
		var room: Dictionary = run_engine.room_metadata(run_state, coord)
		if str(room.get("type", "")) == "combat":
			combat_coord = coord
			break

	if combat_coord != Vector2i.ZERO:
		instance.call("_on_map_view_room_selected", combat_coord)
		await process_frame
		await process_frame
		await _save_root_screenshot("user://probes/run_combat.png")
		var combat_state: Dictionary = instance.get("_combat_state")
		var ranged_deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
		if ranged_deck.get("hand", []).is_empty():
			ranged_deck["hand"] = ["bone_dart"]
		else:
			ranged_deck["hand"][0] = "bone_dart"
		combat_state["deck"] = ranged_deck
		var ranged_run_state: Dictionary = instance.get("_run_state")
		ranged_run_state["combat_state"] = combat_state
		instance.set("_run_state", ranged_run_state)
		instance.set("_combat_state", combat_state)
		instance.call("_refresh_ui")
		await process_frame
		await process_frame
		await _save_root_screenshot("user://probes/run_combat_ranged_card.png")
		combat_state["relics"] = ["ember_lens", "pilgrim_boots", "mirror_shard"]
		var combat_deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
		if combat_deck.get("hand", []).is_empty():
			combat_deck["hand"] = ["quick_stab"]
		else:
			combat_deck["hand"][0] = "quick_stab"
		combat_state["deck"] = combat_deck
		var run_state_with_bonus: Dictionary = instance.get("_run_state")
		run_state_with_bonus["relics"] = ["ember_lens", "pilgrim_boots", "mirror_shard"]
		var rooms: Dictionary = (run_state_with_bonus.get("rooms", {}) as Dictionary).duplicate(true)
		for room_key: String in rooms.keys():
			var room_state: Dictionary = (rooms[room_key] as Dictionary).duplicate(true)
			if room_state.get("coord", Vector2i.ZERO) == Vector2i.ZERO:
				room_state["cleared"] = true
			elif room_state.get("coord", Vector2i.ZERO) == combat_coord:
				room_state["cleared"] = false
			elif bool(room_state.get("revealed", false)):
				room_state["cleared"] = true
			rooms[room_key] = room_state
		run_state_with_bonus["rooms"] = rooms
		run_state_with_bonus["combat_state"] = combat_state
		instance.set("_run_state", run_state_with_bonus)
		instance.set("_combat_state", combat_state)
		instance.call("_refresh_ui")
		await process_frame
		await process_frame
		await _save_root_screenshot("user://probes/run_combat_damage_bonus.png")
		var hand_box: HBoxContainer = instance.get_node("Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll/HandCenter/HandBox")
		if hand_box.get_child_count() > 0:
			var widget: Control = hand_box.get_child(0)
			var tooltip: Variant = widget.call("_make_custom_tooltip", "modifiers")
			if tooltip != null and tooltip is Control:
				var tooltip_control: Control = tooltip
				tooltip_control.position = widget.global_position + Vector2(widget.size.x + 12.0, 8.0)
				root.add_child(tooltip_control)
				await process_frame
				await process_frame
				await _save_root_screenshot("user://probes/run_combat_damage_tooltip.png")
				tooltip_control.queue_free()
				await process_frame
		instance.call("_open_menu_overlay")
		await process_frame
		await process_frame
		await _save_root_screenshot("user://probes/run_menu.png")
		instance.call("_close_menu_overlay")
		instance.call("_open_pile_view", "draw")
		await process_frame
		await process_frame
		await _save_root_screenshot("user://probes/run_draw_pile.png")
		instance.call("_close_pile_view")
		instance.call("_on_card_drag_started", 0)
		await process_frame
		await process_frame
		instance.call("_update_drag_proxy_position", Vector2(640.0, 430.0))
		instance.call("_update_drag_overlay_hover", "move")
		await process_frame
		await process_frame
		await _save_root_screenshot("user://probes/run_drag_overlay_move.png")
		instance.call("_commit_drag_drop", "move")
		await create_timer(0.25).timeout
		await process_frame
		await process_frame
		var drag_preview: Dictionary = instance.call("_active_card_preview")
		var drag_targets: Array = drag_preview.get("target_tiles", [])
		if not drag_targets.is_empty():
			instance.call("_on_board_tile_hovered", drag_targets[0])
			await process_frame
			await process_frame
			await _save_root_screenshot("user://probes/run_fallback_move_target.png")
			instance.call("_on_cancel_requested")
			await process_frame
			await process_frame
		var card_index: int = _targeted_card_index(instance)
		instance.call("_on_card_hover_started", card_index)
		await process_frame
		await process_frame
		await _save_root_screenshot("user://probes/run_combat_card_hover.png")
		instance.call("_on_card_pressed", card_index)
		var preview: Dictionary = instance.call("_active_card_preview")
		var target_tiles: Array = preview.get("target_tiles", [])
		if not target_tiles.is_empty():
			instance.call("_on_board_tile_hovered", target_tiles[0])
			await process_frame
			await process_frame
			await _save_root_screenshot("user://probes/run_combat_target_hover.png")
		await process_frame
		await process_frame
		await _save_root_screenshot("user://probes/run_combat_card_selected.png")
		if not target_tiles.is_empty():
			instance.call("_on_board_tile_clicked", target_tiles[0])
			await create_timer(2.1).timeout
			await process_frame
			await process_frame
			await _save_root_screenshot("user://probes/run_combat_after_play.png")
			instance.call("_open_pile_view", "discard")
			await process_frame
			await process_frame
			await _save_root_screenshot("user://probes/run_discard_pile.png")
			instance.call("_close_pile_view")

	instance.queue_free()
	await process_frame

func _save_root_screenshot(output_path: String) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
	image.save_png(output_path)

func _targeted_card_index(instance: Node) -> int:
	var combat_state: Dictionary = instance.get("_combat_state")
	var combat_engine = instance.get("_combat_engine")
	var hand: Array = (combat_state.get("deck", {}) as Dictionary).get("hand", [])
	for index: int in range(hand.size()):
		var preview: Dictionary = instance.call("_card_preview_for_index", index)
		if not bool(preview.get("playable", false)):
			continue
		if bool(preview.get("complete", false)):
			continue
		return index
	return 0

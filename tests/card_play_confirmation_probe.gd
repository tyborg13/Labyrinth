extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")

const OUTPUT_DIR: String = "user://probes/card_play_confirmation_v1"
const STORAGE_PATH: String = "user://card_play_confirmation_probe_progression.json"
const RUN_STORAGE_PATH: String = "user://card_play_confirmation_probe_run.save"

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path(STORAGE_PATH)
	ProgressionStore.set_run_storage_path(RUN_STORAGE_PATH)
	ProgressionStore.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_assert(packed != null, "Run scene should load for card confirmation proof")
	if packed != null:
		for viewport_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			await _capture_confirmation(packed, viewport_size)
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(1 if _failed else 0)

func _capture_confirmation(packed: PackedScene, viewport_size: Vector2i) -> void:
	var capture_viewport := SubViewport.new()
	capture_viewport.name = "CardPlayConfirmationViewport"
	capture_viewport.size = viewport_size
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture_viewport)
	var instance: Node = packed.instantiate()
	capture_viewport.add_child(instance)
	await _settle_ui()
	_install_combat_fixture(instance)
	await _settle_ui()
	var state_before: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	instance.call("_on_card_pressed", 0)
	await _settle_ui()

	var context: Control = instance.get("_action_step_tracker") as Control
	var play_button: Button = _button_with_text(context, "Play Card")
	var printed_mode: Button = context.find_child("CardActionChoicePlay", true, false) as Button
	var move_mode: Button = context.find_child("CardActionChoiceMove", true, false) as Button
	var viewport_bounds := Rect2(Vector2.ZERO, Vector2(viewport_size)).grow(1.0)
	var selected_card: Control = instance.call("_hand_card_control", 0) as Control
	var selected_card_rect: Rect2 = instance.call("_control_visual_global_rect", selected_card) if selected_card != null else Rect2()
	var play_button_rect: Rect2 = play_button.get_global_rect() if play_button != null else Rect2()
	var play_button_overlap: Rect2 = play_button_rect.intersection(selected_card_rect)
	var play_button_overlap_fraction: float = (play_button_overlap.size.x * play_button_overlap.size.y) / maxf(1.0, play_button_rect.size.x * play_button_rect.size.y)
	_assert(instance.get_viewport().get_visible_rect().size == Vector2(viewport_size), "%s proof should use the requested logical viewport" % viewport_size)
	_assert((instance.get("_combat_state") as Dictionary) == state_before, "%s card selection should not mutate live combat" % viewport_size)
	_assert(int(instance.get("_selected_card_index")) == 0 and int(instance.get("_card_action_choice_index")) == 0, "%s should arm the exact selected card and keep its modes open" % viewport_size)
	_assert(int(instance.get("_pending_action_index")) >= (instance.get("_pending_actions") as Array).size(), "%s targetless preview should finish without committing" % viewport_size)
	_assert(context != null and context.visible and viewport_bounds.encloses(context.get_global_rect()), "%s confirmation rail should remain fully visible" % viewport_size)
	_assert(context != null and context.get_global_rect().size.x <= float(viewport_size.x) * 0.5, "%s confirmation rail should stay compact" % viewport_size)
	_assert(play_button != null and play_button.visible and not play_button.disabled, "%s should expose an enabled Play Card action" % viewport_size)
	_assert(play_button != null and play_button.get_global_rect().size.x >= 88.0 and play_button.get_global_rect().size.y >= 36.0, "%s Play Card action should keep a deliberate click target" % viewport_size)
	_assert(printed_mode != null and printed_mode.button_pressed, "%s should keep Printed visibly selected" % viewport_size)
	_assert(move_mode != null and not move_mode.disabled, "%s should keep alternate Move available before confirmation" % viewport_size)
	_assert(str(context.get_meta("action_verb", "")) == "READY · PLAY CARD", "%s should identify the armed card state" % viewport_size)
	_assert(str(context.get_meta("target_state", "")) == "NO TARGET REQUIRED", "%s should explain the targetless state" % viewport_size)
	_assert(selected_card_rect.size.x > 0.0 and play_button != null and play_button_overlap_fraction <= 0.10, "%s Play Card target should stay substantially clear of the selected card" % viewport_size)

	var log_overlay: Control = instance.get("log_overlay") as Control
	if log_overlay != null:
		log_overlay.visible = false
	await _settle_ui()
	var output_dir: String = "%s/%dx%d" % [OUTPUT_DIR, viewport_size.x, viewport_size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var image: Image = capture_viewport.get_texture().get_image()
	_assert(image != null and image.get_size() == viewport_size, "%s proof should capture an exact-size renderer frame" % viewport_size)
	var frame_coverage: float = _non_black_frame_coverage(image)
	var context_luma_range: float = _image_region_luma_range(image, context.get_global_rect()) if context != null else 0.0
	_assert(frame_coverage >= 0.08, "%s proof should capture a complete scene frame, got %.3f non-black coverage" % [viewport_size, frame_coverage])
	_assert(context_luma_range >= 0.15, "%s proof should visibly render the confirmation rail, got %.3f luminance range" % [viewport_size, context_luma_range])
	if image != null and image.get_size() == viewport_size and frame_coverage >= 0.08 and context_luma_range >= 0.15:
		image.save_png("%s/targetless_confirmation.png" % output_dir)

	instance.call("_on_cancel_requested")
	await _settle_ui()
	_assert((instance.get("_combat_state") as Dictionary) == state_before, "%s cancel should preserve the untouched combat state" % viewport_size)
	_assert(int(instance.get("_selected_card_index")) == -1 and int(instance.get("_card_action_choice_index")) == -1, "%s cancel should return to idle" % viewport_size)
	instance.queue_free()
	capture_viewport.queue_free()
	await process_frame

func _install_combat_fixture(instance: Node) -> void:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var layout: Dictionary = _room_layout()
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(9811, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["stone_plate", "quick_stab"],
		"relics": [],
		"hand_size": 2,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["stone_plate", "quick_stab"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.set("_animation_lock", false)
	instance.call("_refresh_ui")

func _room_layout() -> Dictionary:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "ash")
		grid.append(row)
	return {
		"name": "Ashen Crossing",
		"coord": Vector2i(4, 3),
		"type": "combat",
		"grid": grid,
		"player_start": Vector2i(2, 4),
		"enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(5, 4), "hp": 140, "max_hp": 140, "block": 0}],
		"traps": [],
		"terrain": [],
		"loot": []
	}

func _button_with_text(root_node: Node, text: String) -> Button:
	if root_node == null:
		return null
	for node: Node in root_node.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button != null and button.text == text:
			return button
	return null

func _non_black_frame_coverage(image: Image) -> float:
	if image == null or image.is_empty():
		return 0.0
	var sampled: int = 0
	var non_black: int = 0
	for y: int in range(0, image.get_height(), 8):
		for x: int in range(0, image.get_width(), 8):
			sampled += 1
			var pixel: Color = image.get_pixel(x, y)
			if maxf(pixel.r, maxf(pixel.g, pixel.b)) > 0.015:
				non_black += 1
	return float(non_black) / float(maxi(1, sampled))

func _image_region_luma_range(image: Image, region: Rect2) -> float:
	if image == null or image.is_empty():
		return 0.0
	var clipped: Rect2 = region.intersection(Rect2(Vector2.ZERO, Vector2(image.get_size())))
	if clipped.size.x <= 1.0 or clipped.size.y <= 1.0:
		return 0.0
	var min_luma: float = INF
	var max_luma: float = -INF
	for y: int in range(int(floor(clipped.position.y)), int(ceil(clipped.end.y)), 3):
		for x: int in range(int(floor(clipped.position.x)), int(ceil(clipped.end.x)), 3):
			var luma: float = image.get_pixel(x, y).get_luminance()
			min_luma = minf(min_luma, luma)
			max_luma = maxf(max_luma, luma)
	return maxf(0.0, max_luma - min_luma)

func _settle_ui() -> void:
	await process_frame
	await process_frame
	await create_timer(0.16).timeout
	RenderingServer.force_draw()
	await process_frame

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true

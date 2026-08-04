extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
const TURN_ORDER_BACKING_PATH: String = "res://assets/art/ui/turn_order_brush_backing_v2.png"

func _initialize() -> void:
	print("turn order probe: start")
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute("user://probes")
	ProgressionStore.set_storage_path("user://labyrinth_progression_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_probe.save")
	ProgressionStore.clear_saved_run()
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	print("turn order probe: scene ready")
	var probe_run_engine := RunEngine.new()
	instance.call("_load_run_state", probe_run_engine.create_new_run(123, ProgressionStore.default_data()))
	await process_frame
	await process_frame
	print("turn order probe: run loaded")
	var run_state: Dictionary = instance.get("_run_state")
	var run_engine = instance.get("_run_engine")
	var combat_coord: Vector2i = Vector2i.ZERO
	for coord: Vector2i in run_engine.available_moves(run_state):
		var room: Dictionary = run_engine.room_metadata(run_state, coord)
		if str(room.get("type", "")) == "combat":
			combat_coord = coord
			break
	if combat_coord == Vector2i.ZERO:
		push_error("No combat room available for turn order animation probe.")
		quit(1)
		return
	print("turn order probe: entering combat")
	run_state = probe_run_engine.move_to_pre_battle(run_state, combat_coord)
	run_state = probe_run_engine.begin_pre_battle_combat(run_state)
	instance.call("_load_run_state", run_state)
	await process_frame
	await process_frame
	print("turn order probe: combat ready")
	var combat_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	_assert_complete_initial_turn_order(instance, combat_state)
	_assert_turn_order_label(instance)
	_assert_turn_order_panel_right_rail(instance)
	_assert_vertical_turn_order_geometry(instance)
	_assert_backing_texture_has_transparent_bleed()
	_assert_turn_order_badges_match_relative_clocks(instance, combat_state)
	await _save_root_screenshot("user://probes/turn_order_brush_v2_00_before.png")
	var combat_engine = instance.get("_combat_engine")
	var scheduled_state: Dictionary = combat_engine.finish_player_activation(combat_state.duplicate(true))
	print("turn order probe: animating")
	instance.call("_animate_turn_order_transition_between_states", combat_state.duplicate(true), scheduled_state.duplicate(true))
	await create_timer(0.10).timeout
	await process_frame
	_assert_single_turn_order_exit(instance)
	await _save_root_screenshot("user://probes/turn_order_brush_v2_01_remove.png")
	await create_timer(0.20).timeout
	await process_frame
	_assert_turn_order_width_locked(instance)
	await _save_root_screenshot("user://probes/turn_order_brush_v2_02_reflow.png")
	await create_timer(0.20).timeout
	await process_frame
	await _save_root_screenshot("user://probes/turn_order_brush_v2_03_insert.png")
	await create_timer(0.35).timeout
	await process_frame
	_assert_turn_order_slot_count(instance, 10)
	_assert_turn_order_panel_right_rail(instance)
	_assert_vertical_turn_order_geometry(instance)
	_assert_turn_order_badges_match_relative_clocks(instance, scheduled_state)
	await _save_root_screenshot("user://probes/turn_order_brush_v2_04_final.png")
	print("turn order probe: done")
	print(ProjectSettings.globalize_path("user://probes"))
	instance.queue_free()
	await process_frame
	quit()

func _save_root_screenshot(output_path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image: Image = root.get_viewport().get_texture().get_image()
	# macOS may expose a Retina-sized backing texture even when the authored
	# logical canvas is 1920x1080. Normalize proof to the rubric's exact canvas.
	if image.get_size() != VIEWPORT_SIZE:
		image.resize(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(output_path)

func _assert_single_turn_order_exit(instance: Node) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	if bar == null:
		push_error("Turn order bar missing during animation probe.")
		quit(1)
		return
	var exiting: int = 0
	for child_index: int in range(bar.get_child_count()):
		var child: Control = bar.get_child(child_index) as Control
		if child == null:
			continue
		if child.position.y < -2.0 or child.modulate.a < 0.98:
			exiting += 1
	if exiting != 1:
		push_error("Expected exactly one turn order entry exiting; found %d." % exiting)
		quit(1)

func _assert_turn_order_width_locked(instance: Node) -> void:
	var panel: PanelContainer = instance.get("_turn_order_panel") as PanelContainer
	if panel == null:
		push_error("Turn order panel missing during animation probe.")
		quit(1)
		return
	var locked_width: float = float(instance.get("_turn_order_panel_locked_width"))
	if locked_width <= 0.0:
		push_error("Turn order panel width was not locked during animation.")
		quit(1)
		return
	if absf(panel.custom_minimum_size.x - locked_width) > 0.5:
		push_error("Turn order panel width changed during animation.")
		quit(1)

func _assert_turn_order_slot_count(instance: Node, max_count: int) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	if bar == null:
		push_error("Turn order bar missing during slot-count probe.")
		quit(1)
		return
	if _turn_order_slot_controls(bar).size() > max_count:
		push_error("Turn order bar showed %d slots; expected at most %d." % [_turn_order_slot_controls(bar).size(), max_count])
		quit(1)

func _assert_complete_initial_turn_order(instance: Node, state: Dictionary) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	var panel: PanelContainer = instance.get("_turn_order_panel") as PanelContainer
	var combat_engine = instance.get("_combat_engine")
	if bar == null or panel == null or combat_engine == null:
		push_error("Turn order initialization probe is missing the bar, panel, or engine.")
		quit(1)
		return
	var expected: Array = combat_engine.current_turn_order(state, 10)
	if expected.is_empty():
		push_error("Turn order initialization fixture produced no expected entries.")
		quit(1)
		return
	if _turn_order_slot_controls(bar).size() != expected.size():
		push_error("Turn order showed %d of %d entries on room entry before any action." % [_turn_order_slot_controls(bar).size(), expected.size()])
		quit(1)
		return
	if panel.get_node_or_null(UiSkin.PANEL_ORNAMENT_NAME) != null:
		push_error("Turn order should present floating portrait frames, not a full-height ornamental enclosure.")
		quit(1)
	if bar.get_node_or_null("TurnOrderOverflowBadge") != null:
		push_error("The expanded rail should show scheduled portraits directly, not a +N overflow label.")
		quit(1)

func _assert_turn_order_label(instance: Node) -> void:
	var panel: PanelContainer = instance.get("_turn_order_panel") as PanelContainer
	if panel == null:
		push_error("Turn order panel missing during label probe.")
		quit(1)
		return
	var labels: Array[Label] = _labels_under(panel)
	for label: Label in labels:
		if label.text == "NEXT" or label.text.begins_with("+"):
			push_error("Expanded turn rail should not render detached NEXT or +N labels.")
			quit(1)

func _assert_turn_order_panel_right_rail(instance: Node) -> void:
	var panel: PanelContainer = instance.get("_turn_order_panel") as PanelContainer
	if panel == null:
		push_error("Turn order panel missing during right-rail probe.")
		quit(1)
		return
	var panel_rect: Rect2 = panel.get_global_rect()
	var viewport_rect: Rect2 = panel.get_viewport_rect()
	if panel_rect.end.x > viewport_rect.end.x - 8.0 or panel_rect.position.x < viewport_rect.size.x * 0.70:
		push_error("Turn order panel should stay inside the narrow right edge rail.")
		quit(1)

func _assert_vertical_turn_order_geometry(instance: Node) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	var panel: PanelContainer = instance.get("_turn_order_panel") as PanelContainer
	if bar == null or panel == null:
		push_error("Turn order rail geometry needs the bar and panel.")
		quit(1)
		return
	var slots: Array[Control] = _turn_order_slot_controls(bar)
	var previous_rect := Rect2()
	var first_width: float = 0.0
	for index: int in range(slots.size()):
		var slot: Control = slots[index]
		var rect: Rect2 = slot.get_global_rect()
		if index == 0:
			first_width = rect.size.x
		else:
			if rect.position.y < previous_rect.end.y - 0.5:
				push_error("Turn entries must descend without vertical overlap.")
				quit(1)
				return
			if rect.size.x > previous_rect.size.x + 0.5:
				push_error("Queued turn portraits must progressively shrink.")
				quit(1)
				return
			if index > 1 and previous_rect.size.x - rect.size.x < 2.0:
				push_error("Queued turn portraits should have a clearly descending rhythm.")
				quit(1)
				return
		if not panel.get_global_rect().encloses(rect):
			push_error("Turn entry escaped the rail panel bounds.")
			quit(1)
			return
		var aspect: float = rect.size.x / maxf(1.0, rect.size.y)
		if aspect < 1.18 or aspect > 1.52:
			push_error("Turn entries must remain portrait-shaped near 4:3 instead of collapsing into slivers.")
			quit(1)
			return
		var portrait_crop: Control = slot.find_child("TurnOrderPortraitCrop", true, false) as Control
		var backing: TextureRect = slot.find_child("TurnOrderBrushBacking", true, false) as TextureRect
		var slot_panel: PanelContainer = slot.get_child(0) as PanelContainer if slot.get_child_count() > 0 else null
		var slot_style: StyleBoxFlat = slot_panel.get_theme_stylebox("panel") as StyleBoxFlat if slot_panel != null else null
		if portrait_crop == null or backing == null or str(slot.get_meta("turn_order_art_hook", "")) != "brush_backing_v2" or str(slot.get_meta("turn_order_backing_asset", "")) != TURN_ORDER_BACKING_PATH or slot.find_child("TurnOrderActiveFrameArtHost", true, false) != null or slot.find_child("TurnOrderQueuedFrameArtHost", true, false) != null:
			push_error("Turn entry should pair its portrait with the user-provided brush backing and no rectangular frame-art host.")
			quit(1)
			return
		if slot.clip_contents or slot_panel == null or slot_panel.clip_contents or backing.clip_contents:
			push_error("Turn-entry brush backing must sit beneath a fully non-clipping control chain.")
			quit(1)
			return
		var team: String = str(slot.get_meta("turn_order_team", "enemy"))
		if (team == "player" and backing.modulate.b <= backing.modulate.r) or (team != "player" and backing.modulate.r <= backing.modulate.b):
			push_error("Turn-entry brush backing should use the subdued blue player or red enemy treatment.")
			quit(1)
			return
		if backing.modulate.a > 0.67:
			push_error("Turn-entry brush backing should remain a subdued secondary cue.")
			quit(1)
			return
		if slot_style == null or slot_style.bg_color.a > 0.001 or slot_style.border_color.a > 0.001 or slot_style.shadow_size > 0:
			push_error("Turn entry surface should remain fully transparent and borderless.")
			quit(1)
			return
		previous_rect = rect
	if slots.size() >= 8 and (first_width < 128.0 or previous_rect.size.x < 74.0):
		push_error("Dense rail should keep its leading and final portraits readable.")
		quit(1)

func _assert_backing_texture_has_transparent_bleed() -> void:
	var image := Image.new()
	var load_error: Error = image.load(TURN_ORDER_BACKING_PATH)
	if load_error != OK:
		push_error("Turn-order brush backing failed to load for alpha-bound validation: %s" % error_string(load_error))
		quit(1)
		return
	var size: Vector2i = image.get_size()
	var min_x: int = size.x
	var min_y: int = size.y
	var max_x: int = -1
	var max_y: int = -1
	for y: int in range(size.y):
		for x: int in range(size.x):
			if image.get_pixel(x, y).a <= 0.01:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		push_error("Turn-order brush backing contains no visible pixels.")
		quit(1)
		return
	var minimum_horizontal_bleed: int = 20
	var minimum_vertical_bleed: int = 40
	if min_x < minimum_horizontal_bleed or size.x - 1 - max_x < minimum_horizontal_bleed or min_y < minimum_vertical_bleed or size.y - 1 - max_y < minimum_vertical_bleed:
		push_error("Turn-order brush backing needs transparent bleed on every side; alpha bounds were %s inside %s." % [Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1), size])
		quit(1)

func _turn_order_slot_controls(bar: Control) -> Array[Control]:
	var result: Array[Control] = []
	for child: Node in bar.get_children():
		var slot: Control = child as Control
		if slot != null and slot.has_meta("turn_order_rail_index"):
			result.append(slot)
	return result

func _labels_under(node: Node) -> Array[Label]:
	var labels: Array[Label] = []
	if node is Label:
		labels.append(node as Label)
	for child: Node in node.get_children():
		labels.append_array(_labels_under(child))
	return labels

func _assert_turn_order_badges_match_relative_clocks(instance: Node, state: Dictionary) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	var combat_engine = instance.get("_combat_engine")
	if bar == null or combat_engine == null:
		push_error("Turn order bar or combat engine missing during badge probe.")
		quit(1)
		return
	var order: Array = combat_engine.current_turn_order(state, 10)
	var slots: Array[Control] = _turn_order_slot_controls(bar)
	if order.is_empty() or slots.is_empty():
		push_error("Turn order badge probe found no entries.")
		quit(1)
		return
	var count: int = mini(order.size(), slots.size())
	for index: int in range(count):
		var child: Control = slots[index]
		var entry: Dictionary = order[index] as Dictionary
		var expected: String = str(int(entry.get("eta", 0)))
		var actual: String = str(child.get_meta("turn_order_badge_text", ""))
		if actual != expected:
			push_error("Turn order badge %d showed %s, expected relative clock %s." % [index, actual, expected])
			quit(1)
			return

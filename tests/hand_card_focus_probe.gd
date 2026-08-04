extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const HandFanContainer = preload("res://scripts/hand_fan_container.gd")
const CardWidget = preload("res://scripts/card_widget.gd")

const OUTPUT_DIR: String = "user://hand_card_focus_v3_proof"
const PROOF_VERSION: String = "v3"
const FOCUSED_INDEX: int = 2
const HAND: Array = [
	"quick_stab",
	"wildfire_halo",
	"stormstring_shot",
	"rallying_breath",
	"guarded_step",
]

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://labyrinth_progression_hand_card_focus_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_hand_card_focus_probe.save")
	SettingsStore.set_storage_path("user://labyrinth_settings_hand_card_focus_probe.json")
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	_clear_probe_output(OUTPUT_DIR)
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("Hand-card focus proof must run with a real display renderer")
	else:
		await _capture_configuration(Vector2i(1920, 1080), 1.00, 73101)
	var defaults: Dictionary = SettingsStore.default_settings()
	SettingsStore.save_settings(defaults)
	SettingsStore.apply_settings(defaults, root, false)
	print("HAND_CARD_FOCUS_PROOF_DIR=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _capture_configuration(
	resolution: Vector2i,
	ui_scale: float,
	seed: int
) -> void:
	await _configure_window(resolution, ui_scale)
	var output_dir: String = "%s/%dx%d_ui%d" % [
		OUTPUT_DIR,
		resolution.x,
		resolution.y,
		roundi(ui_scale * 100.0),
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "%s should load the run scene" % output_dir)
	if packed == null:
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle()
	await _load_combat_fixture(instance, seed)
	var hand_box: HandFanContainer = instance.get("hand_box") as HandFanContainer
	_expect(hand_box != null and hand_box.get_child_count() == HAND.size(), "%s should render the complete five-card hand" % output_dir)
	if hand_box == null or hand_box.get_child_count() != HAND.size():
		instance.queue_free()
		await _settle()
		return
	_assert_hand_hud_layout(instance, output_dir)
	var baseline_positions: Array[Vector2] = _slot_positions(hand_box)
	var baseline_focus_rect: Rect2 = instance.call(
		"_control_visual_global_rect",
		instance.call("_hand_card_control", FOCUSED_INDEX)
	)
	_assert_hand_visibility(instance, "%s idle hand" % output_dir)
	_assert_tooltip_stack(instance, PackedStringArray(), "%s idle hand" % output_dir)
	_hide_fixture_notices(instance)
	await _save_root_screenshot("%s/idle_%s.png" % [output_dir, PROOF_VERSION], resolution)

	var focused_widget: CardWidget = _card_widget_at(hand_box, FOCUSED_INDEX)
	_expect(focused_widget != null, "%s should expose the focused CardWidget" % output_dir)
	if focused_widget != null:
		focused_widget.mouse_entered.emit()
		await _settle()
		_assert_focused_hand(
			instance,
			hand_box,
			baseline_positions,
			baseline_focus_rect,
			"%s pointer focus" % output_dir
		)
		_assert_hand_visibility(instance, "%s pointer-focused hand" % output_dir)
		var focused_rect: Rect2 = instance.call(
			"_control_visual_global_rect",
			instance.call("_hand_card_control", FOCUSED_INDEX)
		)
		_assert_tooltip_stack(
			instance,
			PackedStringArray(["time", "element_lightning", "ranged", "range", "chain", "shock"]),
			"%s pointer focus" % output_dir,
			focused_rect
		)
		_hide_fixture_notices(instance)
		await _save_root_screenshot("%s/pointer_multi_tooltips_%s.png" % [output_dir, PROOF_VERSION], resolution)
		focused_widget.mouse_exited.emit()
		await _settle()
		_assert_restored_hand(hand_box, baseline_positions, "%s pointer clear" % output_dir)
		_assert_tooltip_stack(instance, PackedStringArray(), "%s pointer clear" % output_dir)

	await _capture_simple_tooltips(instance, hand_box, output_dir, resolution)
	await _capture_wrapper_focus(instance, hand_box, output_dir, resolution)
	await _assert_existing_card_actions(instance, hand_box, output_dir)
	_assert_reduced_motion_focus(instance, hand_box, output_dir)
	instance.queue_free()
	await _settle()

func _configure_window(resolution: Vector2i, ui_scale: float) -> void:
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = resolution
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = resolution
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = ui_scale
	settings["reduced_motion"] = false
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	await _settle()
	root.size = resolution
	await _settle()

func _assert_hand_hud_layout(instance: Node, label: String) -> void:
	var hand_scroll: Control = instance.get("hand_scroll") as Control
	var hand_box: Control = instance.get("hand_box") as Control
	var play_meter: Control = instance.get("_play_meter") as Control
	var play_meter_slot: Control = instance.get("_play_meter_slot") as Control
	_expect(hand_scroll != null and hand_box != null and play_meter != null and play_meter_slot != null, "%s should expose the complete hand HUD" % label)
	if hand_scroll == null or hand_box == null or play_meter == null or play_meter_slot == null:
		return
	var viewport_rect := Rect2(Vector2.ZERO, instance.get_viewport().get_visible_rect().size)
	var visual_bounds: Rect2 = _hand_visual_bounds(instance, hand_box)
	var meter_rect: Rect2 = play_meter.get_global_rect()
	_expect(play_meter.get_parent() == instance.get("ui_root"), "%s should move the play meter into the independent combat action dock" % label)
	_expect(not visual_bounds.has_area() or meter_rect.end.x <= visual_bounds.position.x - 20.0, "%s should keep the left action dock clear of the resting hand" % label)
	_expect(not meter_rect.intersects(visual_bounds), "%s should keep the card-play meter independent from the rendered hand" % label)
	_expect(viewport_rect.encloses(hand_scroll.get_global_rect()), "%s should keep the complete hand viewport on screen" % label)
	_expect(not visual_bounds.has_area() or viewport_rect.encloses(visual_bounds), "%s should keep the complete resting fan on screen" % label)

func _hand_visual_bounds(instance: Node, hand_box: Control) -> Rect2:
	var bounds := Rect2()
	for index: int in range(hand_box.get_child_count()):
		var card_control: Control = instance.call("_hand_card_control", index) as Control
		if card_control == null:
			continue
		var card_rect: Rect2 = instance.call("_control_visual_global_rect", card_control)
		bounds = card_rect if not bounds.has_area() else bounds.merge(card_rect)
	return bounds

func _load_combat_fixture(instance: Node, seed: int) -> void:
	root.gui_release_focus()
	root.warp_mouse(Vector2(8.0, 8.0))
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var layout: Dictionary = _room_layout()
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(seed, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": HAND.duplicate(),
		"relics": [],
		"hand_size": HAND.size(),
		"heal_bonus": 0,
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = HAND.duplicate()
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["cards_played_this_turn"] = 0
	combat_state["death_bonus_card_plays_this_turn"] = 0
	combat_state["card_play_bonus_this_turn"] = 0
	combat_state["traps"] = []
	combat_state["terrain"] = []
	combat_state["log"] = []
	var progression: Dictionary = ProgressionStore.default_data()
	var tutorial_states: Dictionary = {}
	for prompt_id: String in ContextualCombatTutorial.prompt_ids():
		tutorial_states[prompt_id] = ContextualCombatTutorial.STATUS_COMPLETED
	progression[ContextualCombatTutorial.PROGRESSION_KEY] = tutorial_states
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	run_state["progression"] = progression
	run_state["notice"] = ""
	instance.call("_load_run_state", run_state)
	instance.set("_animation_lock", false)
	var log_overlay: Control = instance.get("log_overlay") as Control
	if log_overlay != null:
		log_overlay.visible = false
	await _settle()

func _assert_focused_hand(
	instance: Node,
	hand_box: HandFanContainer,
	baseline_positions: Array[Vector2],
	baseline_focus_rect: Rect2,
	label: String
) -> void:
	var focused_slot: Control = hand_box.get_child(FOCUSED_INDEX) as Control
	var left_slot: Control = hand_box.get_child(FOCUSED_INDEX - 1) as Control
	var right_slot: Control = hand_box.get_child(FOCUSED_INDEX + 1) as Control
	var focused_control: Control = instance.call("_hand_card_control", FOCUSED_INDEX) as Control
	var focused_rect: Rect2 = instance.call("_control_visual_global_rect", focused_control)
	var viewport_rect := Rect2(Vector2.ZERO, instance.get_viewport().get_visible_rect().size)
	_expect(int(instance.get("_hovered_card_index")) == FOCUSED_INDEX, "%s should preserve the exact hovered hand index" % label)
	_expect(hand_box.emphasized_index() == FOCUSED_INDEX, "%s should emphasize the hovered hand index" % label)
	_expect(hand_box.emphasis_strength() >= 0.99, "%s should settle the full emphasis pose" % label)
	_expect(focused_slot.scale.x >= 1.27 and focused_slot.scale.y >= 1.27, "%s should enlarge the full card by at least 27%%" % label)
	_expect(focused_rect.size.x >= baseline_focus_rect.size.x * 1.25, "%s should materially enlarge the rendered card" % label)
	_expect(focused_rect.position.y <= baseline_focus_rect.position.y - 64.0, "%s should raise the rendered card enough to improve reading" % label)
	_expect(absf(focused_rect.end.y - (baseline_focus_rect.end.y - HandFanContainer.DEFAULT_EMPHASIS_EXTRA_LIFT)) <= 5.0, "%s should add a slight lift beyond bottom-anchored growth" % label)
	_expect(absf(focused_slot.rotation) <= 0.001, "%s should straighten the focused card" % label)
	_expect(focused_slot.z_index > left_slot.z_index and focused_slot.z_index > right_slot.z_index, "%s should render the focused card above both neighbors" % label)
	_expect(left_slot.position.x < baseline_positions[FOCUSED_INDEX - 1].x - 20.0, "%s should move the left side away from focus" % label)
	_expect(right_slot.position.x > baseline_positions[FOCUSED_INDEX + 1].x + 20.0, "%s should move the right side away from focus" % label)
	var visible_focus: Rect2 = focused_rect.intersection(viewport_rect)
	var visible_fraction: float = (
		visible_focus.size.x * visible_focus.size.y
		/ maxf(1.0, focused_rect.size.x * focused_rect.size.y)
	)
	_expect(visible_fraction >= 0.96, "%s should keep the enlarged card inside the visible viewport" % label)

func _assert_restored_hand(
	hand_box: HandFanContainer,
	baseline_positions: Array[Vector2],
	label: String
) -> void:
	_expect(hand_box.emphasized_index() == -1, "%s should clear emphasis after pointer exit" % label)
	for index: int in range(hand_box.get_child_count()):
		var slot: Control = hand_box.get_child(index) as Control
		_expect(slot.scale.distance_to(Vector2.ONE) <= 0.01, "%s should restore card %d scale" % [label, index])
		_expect(slot.position.distance_to(baseline_positions[index]) <= 1.0, "%s should restore card %d fan position" % [label, index])
		_expect(slot.z_index == HandFanContainer.card_z_index_for_layout(index, hand_box.get_child_count()), "%s should restore card %d stacking order" % [label, index])

func _capture_wrapper_focus(
	instance: Node,
	hand_box: HandFanContainer,
	output_dir: String,
	resolution: Vector2i
) -> void:
	var valid_indices: Array[int] = []
	for index: int in range(HAND.size()):
		valid_indices.append(index)
	instance.call(
		"_begin_hand_skill_card_selection",
		"quick_wits",
		valid_indices,
		"QUICK WITS  ·  CHOOSE A CARD TO DISCARD"
	)
	await _settle()
	var focused_wrapper: Button = hand_box.find_child(
		"SkillHandSelectionCard_%d" % FOCUSED_INDEX,
		false,
		false
	) as Button
	_expect(focused_wrapper != null, "%s should expose the existing full-card focus wrapper" % output_dir)
	if focused_wrapper == null:
		return
	focused_wrapper.grab_focus()
	await _settle()
	_expect(focused_wrapper.has_focus(), "%s wrapper should keep keyboard/controller focus" % output_dir)
	_expect(hand_box.emphasized_index() == FOCUSED_INDEX, "%s wrapper focus should drive the same hand emphasis" % output_dir)
	_expect(focused_wrapper.scale.x >= 1.27, "%s wrapper focus should enlarge the complete card" % output_dir)
	_expect(focused_wrapper.z_index >= HandFanContainer.EMPHASIS_Z_INDEX_BONUS, "%s wrapper focus should move above the hand" % output_dir)
	_assert_hand_visibility(instance, "%s wrapper-focused hand" % output_dir)
	_assert_tooltip_stack(
		instance,
		PackedStringArray(["time", "element_lightning", "ranged", "range", "chain", "shock"]),
		"%s wrapper focus" % output_dir,
		instance.call("_control_visual_global_rect", instance.call("_hand_card_control", FOCUSED_INDEX))
	)
	_hide_fixture_notices(instance)
	await _save_root_screenshot("%s/wrapper_focused_%s.png" % [output_dir, PROOF_VERSION], resolution)
	instance.call("_cancel_combat_skill_card_selection")
	await _settle()
	_assert_tooltip_stack(instance, PackedStringArray(), "%s wrapper clear" % output_dir)

func _capture_simple_tooltips(
	instance: Node,
	hand_box: HandFanContainer,
	output_dir: String,
	resolution: Vector2i
) -> void:
	var simple_widget: CardWidget = _card_widget_at(hand_box, 0)
	_expect(simple_widget != null, "%s should expose a simple focused card" % output_dir)
	if simple_widget == null:
		return
	simple_widget.mouse_entered.emit()
	await _settle()
	var simple_rect: Rect2 = instance.call("_control_visual_global_rect", instance.call("_hand_card_control", 0))
	_assert_tooltip_stack(
		instance,
		PackedStringArray(["time", "melee"]),
		"%s simple pointer focus" % output_dir,
		simple_rect
	)
	_hide_fixture_notices(instance)
	await _save_root_screenshot("%s/pointer_simple_tooltips_%s.png" % [output_dir, PROOF_VERSION], resolution)
	simple_widget.mouse_exited.emit()
	await _settle()
	_assert_tooltip_stack(instance, PackedStringArray(), "%s simple pointer clear" % output_dir)

func _assert_existing_card_actions(
	instance: Node,
	hand_box: HandFanContainer,
	label: String
) -> void:
	var widget: CardWidget = _card_widget_at(hand_box, FOCUSED_INDEX)
	_expect(widget != null, "%s should restore normal interactive cards after wrapper focus" % label)
	if widget == null:
		return
	widget.mouse_entered.emit()
	await _settle()
	instance.call("_on_card_drag_started", FOCUSED_INDEX)
	await _settle()
	_expect(int(instance.get("_drag_card_index")) == FOCUSED_INDEX, "%s should preserve drag activation from the enlarged card" % label)
	_expect(hand_box.emphasized_index() == -1, "%s should clear emphasis when drag takes ownership" % label)
	instance.call("_cancel_drag_play")
	await _settle()
	instance.call("_on_card_pressed", FOCUSED_INDEX)
	await _settle()
	_expect(int(instance.get("_card_action_choice_index")) == FOCUSED_INDEX, "%s should preserve click activation from the enlarged card" % label)
	instance.call("_on_cancel_requested")
	await _settle()

func _assert_reduced_motion_focus(
	instance: Node,
	hand_box: HandFanContainer,
	label: String
) -> void:
	var settings: Dictionary = (instance.get("_settings") as Dictionary).duplicate(true)
	settings["reduced_motion"] = true
	instance.set("_settings", SettingsStore.normalize_settings(settings))
	hand_box.set_emphasized_index(-1, false)
	instance.call("_set_hand_emphasized_index", FOCUSED_INDEX, true)
	_expect(hand_box.emphasized_index() == FOCUSED_INDEX, "%s reduced motion should focus the requested card immediately" % label)
	_expect(hand_box.emphasis_strength() >= 0.999, "%s reduced motion should settle the final focus pose without tweening" % label)
	_expect(hand_box.get("_emphasis_tween") == null, "%s reduced motion should not create a focus tween" % label)
	instance.call("_set_hand_emphasized_index", -1, false)
	settings["reduced_motion"] = false
	instance.set("_settings", SettingsStore.normalize_settings(settings))

func _slot_positions(hand_box: HandFanContainer) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for child: Node in hand_box.get_children():
		if child is Control:
			positions.append((child as Control).position)
	return positions

func _card_widget_at(hand_box: HandFanContainer, index: int) -> CardWidget:
	if index < 0 or index >= hand_box.get_child_count():
		return null
	return hand_box.get_child(index).find_child("CardWidget", true, false) as CardWidget

func _assert_tooltip_stack(
	instance: Node,
	expected_icons: PackedStringArray,
	label: String,
	focused_rect: Rect2 = Rect2()
) -> void:
	var stack: Control = instance.get("_card_focus_tooltip_stack") as Control
	_expect(stack != null, "%s should expose the card focus tooltip stack" % label)
	if stack == null:
		return
	_expect(stack.visible == not expected_icons.is_empty(), "%s should match tooltip stack visibility to card focus" % label)
	if expected_icons.is_empty():
		return
	var actual_icons: Array[String] = []
	for icon_var: Variant in stack.call("entry_icon_keys"):
		actual_icons.append(str(icon_var))
	var expected_array: Array[String] = []
	for icon_key: String in expected_icons:
		expected_array.append(icon_key)
	_expect(actual_icons == expected_array, "%s should show every relevant icon once in card reading order" % label)
	_expect(stack.get_child_count() == expected_icons.size(), "%s should stack one framed tooltip per relevant icon" % label)
	var viewport_rect := Rect2(Vector2.ZERO, instance.get_viewport().get_visible_rect().size)
	var stack_rect: Rect2 = stack.get_global_rect()
	_expect(viewport_rect.encloses(stack_rect), "%s should keep the complete tooltip stack on screen" % label)
	if focused_rect.has_area():
		_expect(stack_rect.position.x >= focused_rect.end.x + 8.0, "%s should place the tooltip stack immediately to the focused card's right" % label)
	for icon_key: String in expected_icons:
		var panel: Control = stack.find_child("CardFocusTooltip_%s" % icon_key.to_pascal_case(), false, false) as Control
		_expect(panel != null and panel.find_child("TooltipIcon", true, false) != null, "%s should pair %s copy with its icon" % [label, icon_key])

func _assert_hand_visibility(instance: Node, label: String) -> void:
	var viewport_rect := Rect2(Vector2.ZERO, instance.get_viewport().get_visible_rect().size)
	for index: int in range(HAND.size()):
		var card_control: Control = instance.call("_hand_card_control", index) as Control
		_expect(card_control != null, "%s should retain card %d" % [label, index])
		if card_control == null:
			continue
		var card_rect: Rect2 = instance.call("_control_visual_global_rect", card_control)
		var visible_rect: Rect2 = card_rect.intersection(viewport_rect)
		var visible_fraction: float = (
			visible_rect.size.x * visible_rect.size.y
			/ maxf(1.0, card_rect.size.x * card_rect.size.y)
		)
		_expect(visible_fraction >= 0.80, "%s should keep at least 80%% of card %d inside the viewport" % [label, index])

func _hide_fixture_notices(instance: Node) -> void:
	var log_overlay: Control = instance.get("log_overlay") as Control
	if log_overlay != null:
		log_overlay.visible = false

func _room_layout() -> Dictionary:
	return {
		"name": "Cinder Crossing",
		"coord": Vector2i(4, 3),
		"type": "combat",
		"grid": _simple_grid(),
		"player_start": Vector2i(2, 4),
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(4, 4),
			"hp": 14,
			"max_hp": 14,
			"block": 0,
		}],
		"traps": [],
		"terrain": [],
		"loot": [],
	}

func _simple_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return grid

func _save_root_screenshot(output_path: String, resolution: Vector2i) -> void:
	RenderingServer.force_draw(true, 0.0)
	await process_frame
	RenderingServer.force_draw(true, 0.0)
	var image: Image = root.get_viewport().get_texture().get_image()
	_expect(image != null and not image.is_empty(), "%s should produce a renderer frame" % output_path)
	if image == null or image.is_empty():
		return
	if image.get_size() != resolution:
		image.resize(resolution.x, resolution.y, Image.INTERPOLATE_LANCZOS)
	var error: Error = image.save_png(output_path)
	if error != OK:
		_fail("Failed to save screenshot: %s" % output_path)

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame
	await create_timer(0.20).timeout
	RenderingServer.force_draw()
	await process_frame

func _clear_probe_output(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	var directory := DirAccess.open(absolute)
	if directory == null:
		DirAccess.make_dir_recursive_absolute(absolute)
		return
	directory.list_dir_begin()
	var file_name: String = directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir():
			directory.remove(file_name)
		file_name = directory.get_next()
	directory.list_dir_end()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	push_error(message)
	_failed = true

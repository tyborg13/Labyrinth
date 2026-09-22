extends "res://tests/hand_card_focus_probe.gd"

const CardScene = preload("res://scenes/card_widget.tscn")
const PROBE_SIZE := Vector2i(1920, 1080)
const MATERIAL_OUTPUT := "user://premium_card_material_v1"

var _viewport: SubViewport
var _baseline: bool = OS.get_environment("LABYRINTH_CARD_POLISH_BASELINE") == "1"
var _activations: int = 0
var _drags: int = 0
var _native_presses: int = 0

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://premium_card_progression.json")
	ProgressionStore.set_run_storage_path("user://premium_card_run.save")
	SettingsStore.set_storage_path("user://premium_card_settings.json")
	ProgressionStore.clear_saved_run()
	ProgressionStore.save_data(ContextualCombatTutorial.complete_tutorial(ProgressionStore.default_data()))
	_apply_motion(false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(PROBE_SIZE)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = PROBE_SIZE
	root.size = PROBE_SIZE
	root.get_node("InputRouter").call("set_forced_state_for_test", "pointer", "xbox")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MATERIAL_OUTPUT))
	_viewport = SubViewport.new()
	_viewport.size = PROBE_SIZE
	_viewport.msaa_2d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	await _gameplay_states()
	await _material_states()
	_viewport.queue_free()
	await process_frame
	root.get_node("InputRouter").call("clear_forced_state_for_test")
	_apply_motion(false)
	print(ProjectSettings.globalize_path(MATERIAL_OUTPUT))
	print("PREMIUM CARD MATERIAL PROBE: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _gameplay_states() -> void:
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(scene)
	await _settle()
	await _load_combat_fixture(scene, 73101)
	scene.call("_close_dialogue")
	scene.call("_close_large_map")
	await _settle()
	var hand_box: HandFanContainer = scene.get("hand_box") as HandFanContainer
	var widget: CardWidget = _card_widget_at(hand_box, FOCUSED_INDEX)
	_expect(widget != null, "Gameplay fixture exposes its real card")
	if widget == null:
		return
	var baseline_size: Vector2 = widget.size
	var content_rects: Array[Rect2] = _content_rects(widget)
	_hide_fixture_notices(scene)
	await _capture_material("01_hand_idle.png")
	var target: Rect2 = scene.call("_control_visual_global_rect", scene.call("_hand_card_control", FOCUSED_INDEX))
	await _point_card(target.get_center())
	await create_timer(0.09).timeout
	await _capture_material("02_hand_edge_response.png")
	await _settle()
	_expect(widget.size == baseline_size and _content_rects(widget) == content_rects, "Material response preserves card and text/art layout")
	_assert_hand_visibility(scene, "Material hand hover")
	await _capture_material("03_hand_inspect.png")
	await _point_card(Vector2(960, 530))
	await _settle()
	scene.call("_on_card_drag_started", FOCUSED_INDEX)
	await _settle()
	_expect(int(scene.get("_drag_card_index")) == FOCUSED_INDEX, "Existing card drag still takes ownership")
	await _capture_material("04_drag_proxy.png")
	scene.call("_cancel_drag_play")
	await _settle()
	scene.call("_on_card_pressed", FOCUSED_INDEX)
	await _settle()
	_expect(int(scene.get("_selected_card_index")) == FOCUSED_INDEX, "Existing card click still selects its targeted action")
	await _point_card(Vector2(960, 470))
	await _capture_material("05_selected_card.png")
	scene.call("_on_cancel_requested")
	await _settle()
	scene.queue_free()
	await process_frame

func _material_states() -> void:
	var gallery := Control.new()
	gallery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(gallery)
	var background := ColorRect.new()
	background.color = Color("251e19")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gallery.add_child(background)
	var cards: Array[CardWidget] = []
	var ids: Array[String] = ["quick_stab", "stormstring_shot", "wildfire_halo", "guarded_step"]
	var labels: Array[String] = ["Available", "Focused", "Unavailable", "Inspection / passive"]
	for index: int in range(ids.size()):
		var label := Label.new()
		label.text = labels[index]
		label.position = Vector2(190 + 410 * index, 240)
		label.size = Vector2(300, 45)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 23)
		gallery.add_child(label)
		var slot := Control.new()
		slot.position = Vector2(215 + 410 * index, 330)
		slot.size = Vector2(250, 352)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gallery.add_child(slot)
		var card: CardWidget = CardScene.instantiate()
		card.size = Vector2(250, 352)
		slot.add_child(card)
		card.configure(ids[index], false, index == 2, index != 2, false, index != 3)
		card.focus_mode = Control.FOCUS_ALL if index < 2 else Control.FOCUS_NONE
		cards.append(card)
	var card: CardWidget = cards[0]
	card.activated.connect(func(): _activations += 1)
	card.drag_started.connect(func(): _drags += 1)
	cards[1].pressed.connect(func(): _native_presses += 1)
	card.focus_neighbor_right = card.get_path_to(cards[1])
	card.focus_next = card.get_path_to(cards[1])
	await _settle()
	await _point_card(Vector2(8, 8))
	var idle_rect: Rect2 = card.get_global_rect()
	var minimum: Vector2 = card.get_combined_minimum_size()
	await _capture_material("06_material_states.png")
	if not _baseline:
		var inspection: CardWidget = cards[3]
		inspection.size = Vector2(300, 422)
		await process_frame
		var reflection: ShaderMaterial = inspection.get("_frame_reflection_material") as ShaderMaterial
		_expect(reflection.get_shader_parameter("card_size") == inspection.size, "Resize refreshes material geometry without a hover")
		_expect(is_equal_approx(float(reflection.get_shader_parameter("layout_scale")), float(inspection.call("_card_layout_scale"))), "Resize refreshes material scale without a hover")
		var shadow: Control = inspection.get("_elevation_shadow") as Control
		_expect(is_equal_approx(shadow.offset_left, 8.0 * float(inspection.call("_card_layout_scale"))), "Resize refreshes inset shadow geometry")
		inspection.size = Vector2(250, 352)
		await process_frame
	await _point_card(idle_rect.get_center())
	await create_timer(0.36).timeout
	if not _baseline:
		_expect(not card.is_processing() and not bool((card.get("_frame_reflection") as Control).visible), "Hover reflection finishes once while pointer stays over card")
	await _click_card(idle_rect.get_center())
	_expect(_activations == 1, "Native pointer activation remains exactly once")
	await _point_card(Vector2(8, 8))
	card.grab_focus()
	await _key_card(KEY_TAB)
	_expect(cards[1].has_focus(), "Native keyboard traversal retains the next focus target")
	await _key_card(KEY_ENTER)
	_expect(_native_presses == 1, "Focused card retains native accept activation")
	await _capture_material("07_native_focus.png")
	cards[1].release_focus()
	await _point_card(idle_rect.get_center())
	await _mouse_button(true, idle_rect.get_center())
	await _point_card(idle_rect.get_center() + Vector2(40, 0))
	await _mouse_button(false, idle_rect.get_center() + Vector2(40, 0))
	_expect(_drags == 1 and _activations == 1, "Native drag crosses its existing threshold without becoming a click")
	await _point_card(Vector2(8, 8))
	card.release_focus()
	await _settle()
	_expect(card.get_global_rect() == idle_rect and card.get_combined_minimum_size() == minimum, "Settled card preserves native hit rect and minimum geometry")
	if not _baseline:
		_expect(not card.is_processing(), "Settled material spends no frame processing")
		for decoration_name: String in ["CardElevationShadow", "CardFrameReflection"]:
			var decoration: Control = card.get_node_or_null(decoration_name) as Control
			_expect(decoration != null and decoration.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Card decoration never takes native input: " + decoration_name)
		_expect(not cards[2].is_processing() and not cards[3].is_processing(), "Unavailable and passive states have no decorative processing")
	await _point_card(idle_rect.get_center())
	card.play_ready_wave()
	await process_frame
	_apply_motion(true)
	await process_frame
	await process_frame
	var badge: Control = card.get("_time_badge") as Control
	var still_clock: float = float(badge.get("_clock_seconds"))
	await create_timer(0.12).timeout
	if not _baseline:
		_expect(not badge.is_processing() and is_equal_approx(float(badge.get("_clock_seconds")), still_clock), "Runtime Reduced Motion freezes the hovered clock")
		_expect(not bool(card.get("_ready_wave_active")) and not card.is_processing(), "Runtime Reduced Motion settles the wave and material response")
	card.play_ready_wave(0.1)
	if not _baseline:
		_expect(not bool(card.get("_ready_wave_active")), "Reduced Motion suppresses newly requested ready waves")
	await _capture_material("08_reduced_motion.png")
	_apply_motion(false)
	await _point_card(Vector2(8, 8))
	await _point_card(idle_rect.get_center())
	card.play_ready_wave(0.2)
	card.get_parent().hide()
	await process_frame
	if not _baseline:
		_expect(not card.is_processing() and not badge.is_processing() and not bool(card.get("_ready_wave_active")), "Hidden card cancels all decorative work including a delayed ready wave")
	card.prepare_for_pool()
	card.get_parent().show()
	card.set_interaction_state(false, false, true, false, true, true)
	await _point_card(Vector2(8, 8))
	await _settle()
	if not _baseline:
		_expect(not card.is_processing() and not badge.is_processing(), "Pool reuse does not revive stale motion")
	_expect(card.get_global_rect() == idle_rect and card.focus_mode == Control.FOCUS_ALL, "Pool reuse preserves geometry and supported focus")
	await _capture_material("09_reused_idle.png")
	gallery.queue_free()
	await process_frame

func _content_rects(card: CardWidget) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for path: String in ["Margin/VBox/TopRow/Title", "Margin/VBox/ArtBleed/ArtFrame", "Margin/VBox/DetailsPanel"]:
		result.append((card.get_node(path) as Control).get_rect())
	return result

func _apply_motion(reduced: bool) -> void:
	var settings: Dictionary = SettingsStore.default_settings()
	settings["reduced_motion"] = reduced
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)

func _point_card(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = Vector2(5, 5)
	_viewport.push_input(event, true)
	await process_frame

func _mouse_button(pressed: bool, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	_viewport.push_input(event, true)
	await process_frame

func _click_card(point: Vector2) -> void:
	await _point_card(point)
	await _mouse_button(true, point)
	await _mouse_button(false, point)

func _key_card(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		_viewport.push_input(event, true)
		await process_frame

func _capture_material(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	RenderingServer.force_draw(true, 0.0)
	var image: Image = _viewport.get_texture().get_image()
	_expect(image.get_size() == PROBE_SIZE, "Capture keeps native 1920x1080 dimensions")
	_expect(image.save_png(MATERIAL_OUTPUT.path_join(file_name)) == OK, "Save " + file_name)

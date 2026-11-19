extends SceneTree
## Real event choices loaded through RunScene. --semantics-only omits GPU capture.
const LayoutChecks = preload("res://tests/helpers/event_reward_layout_checks.gd")
const Fixtures = preload("res://tests/suites/event_view_suite.gd")
const Feedback = preload("res://tests/suites/event_feedback_suite.gd")
const TestClock = preload("res://tests/helpers/presentation_test_clock.gd")
const Events = preload("res://scripts/event_rules.gd")
const Demo = preload("res://scripts/demo_rules.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Preview = preload("res://scripts/event_reward_preview.gd")
const Plate = preload("res://scripts/event_reward_plate.gd")
const Builder = preload("res://scripts/item_preview_builders.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Tooltips = preload("res://scripts/event_reward_tooltips.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Stack = preload("res://scripts/card_focus_tooltip_stack.gd")
const LoopView = preload("res://scripts/tooltip_loop_view.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const REFERENCE_SIZE := Vector2i(1920, 1080)
const COMPACT_SIZE := Vector2i(1280, 800)
const COMPACT_UI_SCALE: float = 1.15
const CAPTURE_DIR: String = "user://ui-36-event-reward-plates"
const LOOP_PROOF_SECONDS: float = 0.7
const LOOP_PROOF_FPS: int = 30
const LOOP_PROOF_READY_MSEC: int = 2000
const LAYOUT_TOLERANCE: float = 1.0
const SETTLE_FRAMES: int = 4
const FIXTURE_DEPTH: int = 2
const FIXTURE_HEALTH: int = 24
const FIXTURE_MAX_HEALTH: int = 30
const FIXTURE_EMBERS: int = 47
const FIXTURE_LEVEL: int = 1
const BASIN: String = "bloodletters_basin"
const POINTER_PARK := Vector2(8, 8)
const CASES: Array = [
	["whispering_well", "ember", "card", "plasma_arc", "chain_card", "whispering_well"],
	[BASIN, "bleed", "relic", "coalheart_crucible", "", "basin_choice_1_hover"],
	["sealed_sarcophagus", "reach", "item", "storm_jar", "chain_card", "sealed_sarcophagus_item"],
	["lost_cartographer", "embers", "gain", "ember", "", "lost_cartographer_embers"],
]

var _semantics_only: bool
var _physical_size: Vector2i
var _viewport: SubViewport
var _scene: Node
var _failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_semantics_only = args.has("--semantics-only")
	if DisplayServer.get_name() == "headless" and not _semantics_only:
		push_error("UI-36 captures require the native renderer")
		quit(1)
		return
	var compact: bool = args.has("--compact")
	_physical_size = COMPACT_SIZE if compact else REFERENCE_SIZE
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = COMPACT_UI_SCALE if compact else 1.0
	settings["reduced_motion"] = false
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	Store.set_storage_path("user://ui36_probe_profile.json")
	Store.set_run_storage_path("user://ui36_probe_run.save")
	Settings.set_storage_path("user://ui36_probe_settings.json")
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.mode = Window.MODE_WINDOWED
	root.size = _physical_size
	# Reproduce the main Window's expand aspect policy and UI-scale factor
	# inside an exact-size render target, independent of the monitor's DPI.
	var expand: float = maxf(float(REFERENCE_SIZE.x) / _physical_size.x, float(REFERENCE_SIZE.y) / _physical_size.y)
	var logical_size := Vector2i((Vector2(_physical_size) * expand / float(settings["ui_scale"])).round())
	_viewport = SubViewport.new()
	_viewport.size = _physical_size
	_viewport.size_2d_override = logical_size
	_viewport.size_2d_override_stretch = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	Settings.inherit_edge_smoothing(_viewport, root)
	# Boot directly into the first event so the fresh-run intro doesn't leave
	# a pending animation when the probe swaps scenes or tears down.
	_expect(Store.save_run_state(_event_fixture(CASES[0][0])), "Saved the isolated starting fixture")
	root.set_meta("labyrinth_resume_saved_run", true)
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(_scene)
	for frame: int in range(Feedback.FIXTURE_READY_FRAMES):
		if _scene.call("initial_presentation_is_ready"): break
		await process_frame
	_expect(bool(_scene.call("initial_presentation_is_ready")), "RunScene finished initial presentation")
	if not _semantics_only:
		_expect(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR)) == OK, "Capture directory is writable")
	for fixture: Array in CASES: await _capture_choice(fixture)
	await _input_proof()
	if _semantics_only:
		if compact: _column_wrap()
		var report: Dictionary = await LayoutChecks.sweep(_viewport, _expect)
		var tallest: Dictionary = report.tallest
		_expect(tallest.get("columns", []).size() == 2, "The tallest authored tooltip set wraps into two columns")
		print("UI-36 catalog %dx%d at %.2f: %d events, %d choices, %d previews" % [_physical_size.x, _physical_size.y, settings["ui_scale"], report.events, report.choices, report.previews])
		print("UI-36 tallest tooltip set: %s %s, %d panels, %.1f px before layout, columns=%s" % [tallest.get("case", ""), tallest.get("ids", []), tallest.get("count", 0), tallest.height, tallest.get("columns", [])])
	# Let RunScene's unrelated deferred inventory preparation reach its
	# cancellation boundary while its owner is still alive.
	_scene._character_row_preparation_revision += 1
	_scene._grimoire_row_preparation_revision += 1
	await _settle()
	_scene.queue_free()
	await _settle()
	_viewport.queue_free()
	await _settle()
	for failure: String in _failures: push_error(failure)
	if not _semantics_only: print("UI-36 captures: " + ProjectSettings.globalize_path(CAPTURE_DIR))
	print("UI-36 %s %dx%d at %.2f: %d event choices, %d failures" % ["semantics" if _semantics_only else "native proof", _physical_size.x, _physical_size.y, settings["ui_scale"], CASES.size(), _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _event_fixture(event_id: String) -> Dictionary:
	var state: Dictionary = Fixtures.fixture(event_id)
	state["player_hp"] = FIXTURE_HEALTH
	state["player_max_hp"] = FIXTURE_MAX_HEALTH
	return Fixtures.Run.new().set_held_embers(state, FIXTURE_EMBERS)

func _capture_choice(fixture: Array) -> void:
	var event_id: String = fixture[0]
	var state: Dictionary = _event_fixture(event_id)
	var event: Dictionary = Events.GameData.event_def(event_id)
	var section: int = Events.section_index(state)
	_expect(section <= Demo.last_section_index() and section >= int(event["min_section"]) and section <= int(event["max_section"]) and event["pool"] in ["any", Events.section_element(state)], "Authored event is eligible on the demo route: " + event_id)
	_scene.call("_close_dialogue")
	_scene.call("_load_run_state", state)
	await _settle()
	var view: Control = _scene.get("_event_view")
	_expect(view != null and view.visible and view.art.texture != null, "RunScene presents authored event art: " + event_id)
	if view == null or not view.visible: return
	view.finish_animation_for_test()
	var live_state: Dictionary = view.run_state
	var room: Dictionary = Graph.room(live_state, live_state["current_room"])
	_expect(int(room.get("depth", 0)) == FIXTURE_DEPTH, "The event is at demo route depth %d: %s" % [FIXTURE_DEPTH, event_id])
	_expect(view.health.hp == FIXTURE_HEALTH and view.health.cap == FIXTURE_MAX_HEALTH, "The event shows the fixture's Health: " + event_id)
	_expect(live_state["held_embers"] == FIXTURE_EMBERS and live_state["progression"]["level"] == FIXTURE_LEVEL, "The event uses the fixture's Embers and level: " + event_id)
	var index: int = Feedback._choice_index(view, fixture[1])
	_expect(index >= 0, "Event choice exists: " + event_id)
	if index < 0: return
	_move_pointer(POINTER_PARK)
	_move_pointer(_choice_center(view, index))
	for frame: int in range(Feedback.FIXTURE_READY_FRAMES):
		if not view.hover_preview.preparation_snapshot().active: break
		await process_frame
	await _settle()
	var stage: Control = view.hover_preview.current
	var line: Dictionary = view.hover_preview.current_line
	_expect(stage != null and stage.is_visible_in_tree() and line.get("kind") == fixture[2] and line.get("ids", []).has(fixture[3]), "Hover presents the real rolled reward: " + event_id)
	if stage == null: return
	await _settle_preview(view)
	_check_layout(view, stage, str(fixture[2]), str(fixture[3]), event_id)
	var column: Control = stage.get_node_or_null("EventRewardTooltips")
	if not str(fixture[4]).is_empty() and column != null:
		await _check_loop(column, str(fixture[4]), event_id)
	await _capture(str(fixture[5]))

func _check_layout(view: Control, stage: Control, kind: String, reward_id: String, context: String) -> void:
	var plate: PanelContainer = stage.find_child("EventRewardPlate", true, false)
	var columns: Array[Rect2] = LayoutChecks.bounds(view, stage, _expect, context)
	_expect(plate != null and stage.find_children("EventRewardPlate", "PanelContainer", true, false).size() == 1, "One plate frames one reward: " + context)
	if plate == null: return
	var bounds: Rect2 = Stack._visual_global_rect(plate)
	var viewport: Rect2 = _viewport.get_visible_rect()
	var art: Rect2 = Stack._visual_global_rect(view.art)
	var right_column: Rect2 = Stack._visual_global_rect(view.column)
	var local_scale: float = stage.get_global_transform_with_canvas().get_scale().x
	_expect(bounds.get_center().distance_to(art.get_center()) <= LAYOUT_TOLERANCE, "Plate is centred on the painting: " + context)
	_expect(art.grow(LAYOUT_TOLERANCE).encloses(bounds) and viewport.encloses(bounds) and not right_column.intersects(bounds), "Plate fits the painting and clears the event column: " + context)
	_expect(is_equal_approx(plate.custom_minimum_size.x, Plate.WIDTH), "Plate uses the relic offer width: " + context)
	_expect(plate.has_node("ChoiceSurfaceFinish") and not plate.get_meta("tooltip_surface", false), "Plate has the native choice finish: " + context)
	var style: StyleBoxFlat = plate.get_theme_stylebox("panel")
	_expect(is_equal_approx(style.bg_color.a, 0.50) and style.shadow_size == 16, "Choice retains the translucent fill and existing shadow: " + context)
	var finish: Node2D = plate.get_node("ChoiceSurfaceFinish")
	_expect(style.border_color == Color(Palette.GOLD.lerp(Palette.GOLD_DIM, 0.5), 0.70) and finish.get("_choice_accent") == Palette.GOLD and not finish.get("_choice_emphasized"), "Frame uses resting gold independent of rarity: " + context)
	_expect(is_equal_approx(view.preview_brightness, 0.70) and is_equal_approx(float(view.art.material.get_shader_parameter("preview_brightness")), 0.70), "Painting reaches 0.70 brightness: " + context)
	var contents: VBoxContainer = Plate.contents(plate)
	var body: RichTextLabel = contents.get_node_or_null("RewardDescription")
	if kind != "card":
		_expect(is_equal_approx(plate.size.x, Plate.WIDTH), "Reward fits the exact relic-offer width: " + context)
	if kind in ["card", "item"]:
		var card: Control = contents.find_child("CardWidget", true, false)
		_expect(card != null and body == null and not contents.has_node("RewardRule"), "Native card face carries its own rules: " + context)
		if card != null:
			_expect(card.card_id == reward_id and bounds.grow(LAYOUT_TOLERANCE).encloses(Stack._visual_global_rect(card)), "Reward card fits inside the plate: " + context)
			var face_width: float = Builder.CARD_TOOLTIP_SIZE.x * (Preview.HOVER_CARD_SCALE if kind == "card" else 1.0)
			_expect(absf(Stack._visual_global_rect(card).size.x / local_scale - face_width) <= LAYOUT_TOLERANCE, "Card retains its native preview scale: " + context)
			var light: TextureRect = card.find_child("RewardAccentLight", true, false)
			if kind == "item": _check_light(light, card.art_rect, context)
			else: _expect(light == null, "Spell card art has no pool: " + context)
			_expect(bounds.grow(LAYOUT_TOLERANCE).encloses(Stack._visual_global_rect(card.title_label)) and bounds.grow(LAYOUT_TOLERANCE).encloses(Stack._visual_global_rect(card.details_panel)), "Card rules and name fit inside the plate: " + context)
	else:
		var name_label: Label = contents.get_node("RewardName")
		var icon: TextureRect = contents.get_node("RewardArt").get_child(1)
		var light: TextureRect = contents.get_node_or_null("RewardArt/RewardAccentLight")
		_check_light(light, icon, context)
		_expect(icon.size.is_equal_approx(Vector2.ONE * Preview.ICON_SIZE), "Reward keeps its native art size: " + context)
		_expect(name_label.get_theme_color("font_color").is_equal_approx(Palette.GOLD_BRIGHT), "Reward title has relic-offer gold: " + context)
		_expect(name_label.get_minimum_size().y <= name_label.size.y + LAYOUT_TOLERANCE, "Reward title fits: " + context)
		if kind == "gain":
			_expect(name_label.text == view.hover_preview.current_line.text and body == null and not contents.has_node("RewardRule"), "Plain reward carries exact gain copy and no divider: " + context)
		else:
			_expect(body != null and contents.has_node("RewardRule") and plate.get_meta("reward_description") == Events.GameData.relic_def(reward_id)["description"], "Relic shows its exact description below the divider: " + context)
			if body != null:
				_expect(body.get_theme_font("normal_font") == Typography.text_font() and body.get_content_height() <= body.size.y + LAYOUT_TOLERANCE and bounds.encloses(Stack._visual_global_rect(body)), "Relic text cut shows the full wrapped description: " + context)

	var host: Control = stage.get_node_or_null("EventRewardTooltips")
	if kind == "gain":
		_expect(host == null, "Plain gain has no keyword stack: " + context)
	else:
		_expect(host != null and not columns.is_empty(), "Reward retains keyword help: " + context)
	if kind in ["item", "card"] and not columns.is_empty():
		_expect(columns.size() == 1 and columns[0].position.y < bounds.position.y, "Long tooltip set slides up in one column when it fits: " + context)
	print("UI-36 layout %s: plate=%s, tooltip columns=%s" % [context, bounds, columns])

func _check_light(light: TextureRect, art: TextureRect, context: String) -> void:
	_expect(light != null and light.is_visible_in_tree(), "Reward art has a visible accent pool node: " + context)
	if light == null: return
	var pool: Rect2 = Stack._visual_global_rect(light)
	var art_bounds: Rect2 = Stack._visual_global_rect(art)
	var gradient: GradientTexture2D = light.texture
	_expect(pool.get_center().distance_to(art_bounds.get_center()) <= LAYOUT_TOLERANCE and pool.size.x >= art_bounds.size.x - LAYOUT_TOLERANCE, "Pool is under the full reward art: " + context)
	_expect((light.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD and is_equal_approx(light.modulate.a, 0.55) and gradient.fill == GradientTexture2D.FILL_RADIAL, "Pool retains the relic offer's radial and alpha: " + context)
	_expect(light.get_parent() == art.get_parent() and light.get_index() < art.get_index() or light.get_parent().get_parent() == art.get_parent() and light.get_parent().get_index() < art.get_index(), "Pool draws immediately behind the art: " + context)

func _check_loop(column: Control, loop_id: String, context: String) -> void:
	var loop: Control
	for node: Node in column.find_children("TooltipLoopWindow", "", true, false):
		if node.get_meta("tooltip_loop_id") == loop_id: loop = node as Control
	_expect(loop != null and not loop.reduced_motion, "The intended animated loop is active: " + context)
	if loop == null or _semantics_only: return
	loop.proof_seconds = LOOP_PROOF_SECONDS
	var target: int = int(LOOP_PROOF_SECONDS * LOOP_PROOF_FPS)
	var deadline: int = Time.get_ticks_msec() + LOOP_PROOF_READY_MSEC
	while (loop.displayed_frame != target or loop.get("_fade") < LoopView.FADE_IN_SECONDS) and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(loop.displayed_frame == target and loop.get("_fade") >= LoopView.FADE_IN_SECONDS, "The loop reached its proof frame at full opacity: " + context)

func _column_wrap() -> void:
	# Three tall panels force a wrap at native scale. Move the preview within
	# the same debug art bounds to verify each allowed secondary column.
	const TEST_ART := Rect2(26, 26, 1034, 728)
	const TEST_STAGE_SIZE := Vector2(304, 250)
	const TEST_TOOLTIP_SIZE := Vector2(250, 300)
	const TEST_STAGE_POSITION := Vector2(405, 350)
	const TEST_SHIFT_LEFT_COLUMN: float = 255.0
	const TEST_PANEL_COUNT: int = 3
	var stage := Control.new()
	_viewport.add_child(stage)
	stage.position = TEST_STAGE_POSITION
	stage.size = TEST_STAGE_SIZE
	stage.pivot_offset = stage.size * 0.5
	var host := Control.new()
	stage.add_child(host)
	for index: int in range(TEST_PANEL_COUNT):
		var panel := Control.new()
		panel.custom_minimum_size = TEST_TOOLTIP_SIZE
		host.add_child(panel)
	for second_on_right: bool in [true, false]:
		Tooltips.place(stage, host, TEST_ART, 1.0)
		var first: Rect2 = Stack._visual_global_rect(host.get_child(0))
		var middle: Rect2 = Stack._visual_global_rect(host.get_child(1))
		var last: Rect2 = Stack._visual_global_rect(host.get_child(2))
		var reward: Rect2 = Stack._visual_global_rect(stage)
		_expect(stage.scale.is_equal_approx(Vector2.ONE), "Both tooltip wrap paths retain native scale when they fit")
		_expect(is_equal_approx(first.position.x, middle.position.x) and middle.position.y >= first.end.y, "First column fills in reading order before wrapping")
		_expect(is_equal_approx(first.position.y, last.position.y) and TEST_ART.encloses(last), "Second column shares the first column's top edge inside the art")
		var wanted_gap: float = last.position.x - reward.end.x if second_on_right else first.position.x - last.end.x
		_expect(is_equal_approx(wanted_gap, Tooltips.GAP), "Second column uses the correct side and gap")
		stage.position.x += TEST_SHIFT_LEFT_COLUMN
	stage.free()

func _input_proof() -> void:
	_move_pointer(POINTER_PARK)
	_scene.call("_load_run_state", _event_fixture(BASIN))
	await _settle()
	var view: Control = _scene.get("_event_view")
	view.finish_animation_for_test()
	var router: Node = root.get_node("InputRouter")
	router.set_modality("pointer")
	# Simulate the GUI entering a newly opened button under a stationary pointer.
	view.choices[0].mouse_entered.emit()
	_expect(view.focused_choice_index() == 0 and _preview_hidden(view), "Pointer open keeps initial focus and full painting brightness")
	router.mark_controller_device(0)
	view.finish_animation_for_test()
	_expect(view.focused_choice_index() == 0 and _preview_hidden(view), "Controller open keeps initial focus and full painting brightness")
	await _capture("basin_open")

	_move_pointer(_choice_center(view, 0))
	await _settle_preview(view)
	_expect(_preview_matches(view, 0), "Pointer hover shows choice 1 and its keyword column")
	_move_pointer(POINTER_PARK)
	_expect(view.hover_preview.current_line.is_empty() and view.hover_preview.current.visible, "Hover exit starts the existing fade-out")
	await _settle_preview(view)
	_expect(_preview_hidden(view) and view.focused_choice_index() == 0, "Hover exit restores the painting while initial focus remains")

	_press_controller(JOY_BUTTON_DPAD_DOWN)
	await _settle_preview(view)
	_expect(view.focused_choice_index() == 1 and _preview_matches(view, 1), "Controller Down shows choice 2")
	view.choices[0].mouse_exited.emit()
	_expect(_preview_matches(view, 1), "A GUI hover exit without mouse motion preserves deliberate controller focus")
	_expect(view.hover_preview.current_line.get("kind") == "relic", "Basin choice 2 retains the authored common relic reward")
	await _capture("basin_choice_2_controller")
	_press_controller(JOY_BUTTON_DPAD_UP)
	await _settle_preview(view)
	_expect(view.focused_choice_index() == 0 and _preview_matches(view, 0), "Controller Up shows choice 1")
	_move_pointer(POINTER_PARK)
	await _settle_preview(view)
	_expect(_preview_hidden(view), "Mouse motion away from choices supersedes controller focus")
	_press_controller(JOY_BUTTON_DPAD_DOWN)
	await _settle_preview(view)
	_expect(view.focused_choice_index() == 1 and _preview_matches(view, 1), "Controller navigation supersedes mouse use")
	_move_pointer(_choice_center(view, 0))
	await _settle_preview(view)
	_expect(view.focused_choice_index() == 1 and _preview_matches(view, 0), "Mouse motion over a choice supersedes controller focus")
	_press_key(KEY_UP)
	await _settle_preview(view)
	_expect(view.focused_choice_index() == 0 and _preview_matches(view, 0), "Keyboard navigation shows focused choice")
	_move_pointer(_choice_center(view, 1))
	view.set_reduced_motion(true)
	_expect(_preview_matches(view, 1) and is_equal_approx(view.hover_preview.current.modulate.a, 1.0) and is_equal_approx(view.preview_brightness, 0.70), "Reduced motion keeps the hovered preview fully visible")
	_move_pointer(POINTER_PARK)
	_expect(_preview_hidden(view), "Reduced motion hides the preview immediately on hover exit")

	_press_controller(JOY_BUTTON_A)
	await _settle()
	_expect(view.page == "result" and view.continue_button.has_focus() and view.hover_preview.current_line.is_empty(), "Confirm opens the result with Continue focused")
	_expect(view.run_state["event_state"].get("choice_id") == "bleed", "Confirm resolves the focused choice")
	_press_controller(JOY_BUTTON_A)
	await _settle()
	_expect(_scene.get("_run_state").get("mode") != "event", "Continue leaves the result page")

func _preview_matches(view: Control, index: int) -> bool:
	var line: Dictionary = Preview.first_concrete(view.cached_preview_lines(view.choices[index].choice_id))
	var current: Control = view.hover_preview.current
	return not line.is_empty() and view.hover_preview.current_line == line and is_instance_valid(current) and current.is_visible_in_tree() and current.has_node("EventRewardTooltips")

func _preview_hidden(view: Control) -> bool:
	var current: Control = view.hover_preview.current
	return view.hover_preview.current_line.is_empty() and (not is_instance_valid(current) or not current.is_visible_in_tree()) and is_equal_approx(view.preview_brightness, 1.0)

func _choice_center(view: Control, index: int) -> Vector2:
	return Stack._visual_global_rect(view.choices[index]).get_center()

func _move_pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	_viewport.push_input(motion, true)

func _press_controller(button: JoyButton) -> void:
	var input := InputEventJoypadButton.new()
	input.button_index = button
	input.pressed = true
	_viewport.push_input(input, true)

func _press_key(key: Key) -> void:
	var input := InputEventKey.new()
	input.keycode = key
	input.pressed = true
	_viewport.push_input(input, true)

func _settle_preview(view: Control) -> void:
	for frame: int in range(Feedback.FIXTURE_READY_FRAMES):
		if not view.hover_preview.preparation_snapshot().active: break
		await process_frame
	var fade: Tween = view.hover_preview.get("_fade")
	if fade != null and fade.is_running(): await fade.finished
	await _settle()

func _capture(name: String) -> void:
	if _semantics_only: return
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	var path: String = CAPTURE_DIR.path_join(name + ".png")
	_expect(image.get_size() == _physical_size and image.save_png(path) == OK, "Wrote exact-size capture " + path)

func _settle() -> void:
	await TestClock.rendered_frames(self, SETTLE_FRAMES)

func _expect(ok: bool, message: String) -> void:
	if not ok: _failures.append(message)

extends RefCounted

const CursorFeedbackScript = preload("res://scripts/cursor_feedback.gd")
const CustomCursorGlyphScript = preload("res://scripts/custom_cursor_glyph.gd")
const LabyrinthMapViewScript = preload("res://scripts/labyrinth_map_view.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")

static func run(expect: Callable) -> void:
	_test_visual_state_contract(expect)
	_test_context_resolution(expect)
	_test_production_context_resolution(expect)
	_test_click_audio_contract(expect)
	_test_global_installation(expect)

static func _test_visual_state_contract(expect: Callable) -> void:
	var visual: Dictionary = CustomCursorGlyphScript.visual_contract()
	var states: PackedStringArray = visual.get("states", PackedStringArray())
	expect.call(states.size() == 8, "Custom cursor should expose a complete set of contextual visual states")
	for state: String in ["idle", "action", "pressed_valid", "pressed_invalid", "drag_ready", "dragging", "loading", "invalid"]:
		expect.call(states.has(state), "Custom cursor should expose the %s state" % state)
	expect.call(bool(visual.get("loading_spins", false)), "Loading cursor should explicitly use an animated spinner")
	expect.call(bool(visual.get("single_silhouette", false)), "Every cursor response should retain one coherent forged-pointer silhouette")
	expect.call(not bool(visual.get("context_glyphs", true)), "Cursor states should react through motion and material rather than a surrounding glyph language")
	expect.call(not bool(visual.get("center_stripe", true)), "Blade construction should read through joined facets rather than an artificial stripe down the middle")
	expect.call(bool(visual.get("press_holds", false)) and bool(visual.get("release_rebounds", false)), "Presses should stay compressed while held and rebound only after release")
	expect.call(str(visual.get("loading_integration", "")) == "heel_bearing", "The loading spin should be integrated into the cursor's physical heel bearing")
	expect.call(str(visual.get("pommel_detail", "")) == "faceted_socket_and_bearing", "The handle bearing should sit inside a detailed faceted pommel socket")
	var layers: Array = visual.get("layers", []) as Array
	expect.call(layers.has("joined_blade_facets") and layers.has("pommel_housing") and layers.has("bearing_race"), "Cursor art should join broad blade facets into a mechanically housed pommel bearing")
	expect.call(not layers.has("context_ward") and not layers.has("brass_seam"), "Cursor art should avoid detached wards and a bright center-seam treatment")
	expect.call(CustomCursorGlyphScript.HOTSPOT.x <= 5.0 and CustomCursorGlyphScript.HOTSPOT.y <= 5.0, "Cursor hotspot should remain at the forged pointer tip")
	expect.call(CustomCursorGlyphScript.state_requires_animation("loading"), "Loading state should continuously animate")
	expect.call(CustomCursorGlyphScript.state_requires_animation("dragging"), "Active drag state should retain subtle motion")

	var glyph: Control = CustomCursorGlyphScript.new()
	glyph.call("set_cursor_state", "pressed_valid")
	for _step: int in range(8):
		glyph.call("_process", 0.02)
	var held_snapshot: Dictionary = glyph.call("response_snapshot")
	expect.call(bool(held_snapshot.get("held", false)) and float(held_snapshot.get("press_depth", 0.0)) > 0.95, "A held press should settle into a visibly compressed pose")
	for _step: int in range(20):
		glyph.call("_process", 0.02)
	held_snapshot = glyph.call("response_snapshot")
	expect.call(float(held_snapshot.get("press_depth", 0.0)) > 0.99 and not bool(held_snapshot.get("rebound_active", true)), "Holding should latch the compressed pose without bouncing back")
	glyph.call("set_cursor_state", "action")
	glyph.call("_process", 0.04)
	var release_snapshot: Dictionary = glyph.call("response_snapshot")
	expect.call(bool(release_snapshot.get("rebound_active", false)) and float(release_snapshot.get("rebound_amount", 0.0)) > 0.15, "Releasing a press should begin a visible rebound")
	expect.call(float(release_snapshot.get("press_depth", 1.0)) < float(held_snapshot.get("press_depth", 0.0)), "Release should move the cursor body back out from the hotspot")
	glyph.free()

static func _test_context_resolution(expect: Callable) -> void:
	var button := Button.new()
	var button_context: Dictionary = CursorFeedbackScript.context_for_control(button)
	expect.call(bool(button_context.get("actionable", false)), "Enabled buttons should resolve as valid click targets even when their native cursor shape is the default arrow")
	expect.call(CursorFeedbackScript.state_for_context(button_context, false, false) == "action", "Enabled buttons should show the action cursor")
	expect.call(CursorFeedbackScript.state_for_context(button_context, true, false) == "pressed_valid", "Pressing an enabled button should show valid impact feedback")
	button.disabled = true
	var disabled_context: Dictionary = CursorFeedbackScript.context_for_control(button)
	expect.call(bool(disabled_context.get("invalid", false)) and not bool(disabled_context.get("actionable", true)), "Disabled buttons should resolve as invalid targets")
	expect.call(CursorFeedbackScript.state_for_context(disabled_context, false, false) == "invalid", "Disabled buttons should show the invalid cursor")
	button.free()

	var drag_control := Control.new()
	drag_control.mouse_default_cursor_shape = Control.CURSOR_MOVE
	var drag_context: Dictionary = CursorFeedbackScript.context_for_control(drag_control)
	expect.call(bool(drag_context.get("drag_source", false)) and not bool(drag_context.get("actionable", true)), "Move-shaped surfaces should be drag-ready without claiming that an inert click performs an action")
	expect.call(CursorFeedbackScript.state_for_context(drag_context, false, false) == "drag_ready", "Move-shaped surfaces should show the drag-ready ward")
	expect.call(CursorFeedbackScript.state_for_context(drag_context, true, true) == "dragging", "Dragging a move-shaped surface should show the active drag state")
	drag_control.free()

	var card_control := Control.new()
	card_control.set_meta("cursor_feedback_context", "action_drag")
	card_control.set_meta("cursor_feedback_drag_source", true)
	var card_context: Dictionary = CursorFeedbackScript.context_for_control(card_control)
	expect.call(bool(card_context.get("actionable", false)) and bool(card_context.get("drag_source", false)), "Card-like controls should communicate both click and drag semantics")
	expect.call(CursorFeedbackScript.state_for_context(card_context, false, false) == "drag_ready", "Card-like controls should advertise drag readiness before the press")
	card_control.free()

	var inert_control := Control.new()
	inert_control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	inert_control.set_meta("cursor_feedback_context", "inert")
	var inert_context: Dictionary = CursorFeedbackScript.context_for_control(inert_control)
	expect.call(not bool(inert_context.get("invalid", false)) and not bool(inert_context.get("actionable", true)), "Explicit inert metadata should override a stale native pointing-hand request without advertising a forbidden hover state")
	inert_control.free()

	var help_control := Control.new()
	help_control.mouse_default_cursor_shape = RunSceneScript.TOOLTIP_ONLY_CURSOR_SHAPE
	var help_context: Dictionary = CursorFeedbackScript.context_for_control(help_control)
	expect.call(RunSceneScript.TOOLTIP_ONLY_CURSOR_SHAPE == Control.CURSOR_HELP, "Production tooltip-only controls should use the non-click help semantic")
	expect.call(not bool(help_context.get("actionable", true)) and not bool(help_context.get("drag_source", true)), "Help-shaped tooltip surfaces should remain click-inert")
	expect.call(CursorFeedbackScript.state_for_context(help_context, true, false) == "pressed_invalid", "Clicking hover-only help should use dull feedback")
	help_control.free()

static func _test_production_context_resolution(expect: Callable) -> void:
	var map: Control = LabyrinthMapViewScript.new()
	map.size = Vector2(900.0, 600.0)
	map.set("show_legend", false)
	map.call("set_run_state", _map_cursor_fixture())
	var reachable_point: Vector2 = map.call("_coord_position", Vector2i(1, 0))
	var unavailable_point: Vector2 = map.call("_coord_position", Vector2i(0, 1))
	var reachable_context: Dictionary = CursorFeedbackScript.context_for_control(map, reachable_point)
	var unavailable_context: Dictionary = CursorFeedbackScript.context_for_control(map, unavailable_point)
	var background_context: Dictionary = CursorFeedbackScript.context_for_control(map, Vector2(8.0, 8.0))
	expect.call(bool(reachable_context.get("actionable", false)), "A reachable production map room should resolve as a valid custom click target")
	expect.call(not bool(unavailable_context.get("actionable", true)), "A sealed production map room should resolve as inert")
	expect.call(not bool(background_context.get("actionable", true)), "Production map background should resolve as inert")
	map.free()

	expect.call(RunSceneScript.pile_cursor_feedback_context_for_state(false, "combat", -1, -1, true) == "action", "A production pile should resolve valid when its click handler can open the overlay")
	expect.call(RunSceneScript.pile_cursor_feedback_context_for_state(true, "combat", -1, -1, true) == "inert", "An animation-locked pile should resolve inert")
	expect.call(RunSceneScript.pile_cursor_feedback_context_for_state(false, "room", -1, -1, true) == "inert", "A pile outside combat should resolve inert")
	expect.call(RunSceneScript.pile_cursor_feedback_context_for_state(false, "combat", 0, -1, true) == "inert", "A pile should resolve inert while a card action owns the pointer")

static func _map_cursor_fixture() -> Dictionary:
	return {
		"mode": "room",
		"current_room": Vector2i.ZERO,
		"rooms": {
			"0,0": {
				"coord": Vector2i.ZERO,
				"depth": 0,
				"revealed": true,
				"visited": true,
				"connections": [{"coord": Vector2i(1, 0)}, {"coord": Vector2i(0, 1)}]
			},
			"1,0": {
				"coord": Vector2i(1, 0),
				"depth": 1,
				"revealed": true,
				"connections": [{"coord": Vector2i.ZERO}]
			},
			"0,1": {
				"coord": Vector2i(0, 1),
				"depth": 1,
				"revealed": true,
				"sealed": true,
				"connections": [{"coord": Vector2i.ZERO}]
			}
		}
	}

static func _test_click_audio_contract(expect: Callable) -> void:
	var contract: Dictionary = CursorFeedbackScript.click_feedback_contract()
	expect.call(str(contract.get("bus", "")) == "SFX", "Cursor click sounds should honor the existing SFX volume bus")
	expect.call(float(contract.get("valid_seconds", 0.0)) < float(contract.get("invalid_seconds", 0.0)), "Valid click should be a tighter response than the dull invalid knock")
	expect.call(str(contract.get("valid_character", "")) != str(contract.get("invalid_character", "")), "Valid and invalid feedback should have deliberately different sound characters")
	var valid_stream: AudioStreamWAV = CursorFeedbackScript.build_click_stream(true)
	var invalid_stream: AudioStreamWAV = CursorFeedbackScript.build_click_stream(false)
	expect.call(valid_stream != null and invalid_stream != null, "Both procedural click streams should build without imported assets")
	if valid_stream == null or invalid_stream == null:
		return
	expect.call(valid_stream.format == AudioStreamWAV.FORMAT_16_BITS and invalid_stream.format == AudioStreamWAV.FORMAT_16_BITS, "Click feedback should use stable 16-bit PCM")
	expect.call(valid_stream.stereo and invalid_stream.stereo, "Click feedback should be stereo")
	expect.call(valid_stream.mix_rate == 44100 and invalid_stream.mix_rate == 44100, "Click feedback should use a standard 44.1kHz mix rate")
	expect.call(valid_stream.data.size() > 4000 and invalid_stream.data.size() > valid_stream.data.size(), "The dull knock should use a longer envelope than the satisfying click")
	expect.call(valid_stream.data != invalid_stream.data, "Valid and invalid clicks should not share the same waveform")

	var controller: CanvasLayer = CursorFeedbackScript.new()
	controller.set("_loading_until_msec", 0)
	controller.call("_begin_pointer_press_with_context", Vector2(20.0, 20.0), {"actionable": true, "drag_source": false})
	expect.call(str(controller.call("_resolved_cursor_state", null)) == "pressed_valid", "A classified valid press should enter the pressed-valid state")
	controller.call("_end_pointer_press")
	var counts: Dictionary = controller.call("feedback_counts")
	expect.call(int(counts.get("valid", 0)) == 1 and int(counts.get("invalid", 0)) == 0, "One classified valid input should acquire exactly one feedback event")
	controller.call("_begin_pointer_press_with_context", Vector2(20.0, 20.0), {"actionable": false, "drag_source": false})
	expect.call(str(controller.call("_resolved_cursor_state", null)) == "pressed_invalid", "A classified inert press should enter the dull pressed state")
	controller.call("_end_pointer_press")
	counts = controller.call("feedback_counts")
	expect.call(int(counts.get("valid", 0)) == 1 and int(counts.get("invalid", 0)) == 1, "One classified inert input should acquire exactly one dull feedback event")
	controller.call("_begin_pointer_press_with_context", Vector2(20.0, 20.0), {"actionable": false, "drag_source": true})
	counts = controller.call("feedback_counts")
	expect.call(int(counts.get("valid", 0)) == 1 and int(counts.get("invalid", 0)) == 1, "Drag-only surfaces should defer sound until the gesture is disambiguated")
	var drag_motion := InputEventMouseMotion.new()
	drag_motion.position = Vector2(40.0, 20.0)
	controller.call("_update_drag_from_motion", drag_motion)
	expect.call(str(controller.call("_resolved_cursor_state", null)) == "dragging", "Crossing the drag threshold should enter the active dragging state")
	controller.call("_end_pointer_press")
	counts = controller.call("feedback_counts")
	expect.call(int(counts.get("valid", 0)) == 2 and int(counts.get("invalid", 0)) == 1, "A completed drag should produce one valid gesture sound without a second release sound")
	controller.free()

static func _test_global_installation(expect: Callable) -> void:
	expect.call(str(ProjectSettings.get_setting("autoload/CursorFeedback", "")) == "*res://scripts/cursor_feedback.gd", "Cursor feedback should be an always-present autoload across menu and run scenes")
	expect.call(CursorFeedbackScript.SCENE_TRANSITION_LEAD_SECONDS > 0.0, "Scene changes should leave a visible frame interval for the loading spinner")
	expect.call(CursorFeedbackScript.SCENE_TRANSITION_MINIMUM_SECONDS >= 0.35, "Scene changes should keep the spinner readable across the transition")
	var suppression: Dictionary = CursorFeedbackScript.native_suppression_contract()
	var shape_ids: PackedInt32Array = suppression.get("shape_ids", PackedInt32Array())
	expect.call(str(suppression.get("primary", "")) == "hidden_mouse_mode", "Native cursor suppression should retain hidden mode as its primary path")
	expect.call(str(suppression.get("fallback", "")) == "transparent_custom_cursor_all_shapes", "Native cursor suppression should have an independent transparent-cursor fallback")
	expect.call(shape_ids.size() == 17 and shape_ids.has(Control.CURSOR_HELP) and shape_ids.has(Control.CURSOR_FORBIDDEN), "Transparent fallback should cover every Godot native cursor shape")
	expect.call(bool(suppression.get("focus_reassertion", false)) and bool(suppression.get("periodic_reassertion", false)), "Native cursor suppression should heal after focus and platform cursor resets")
	expect.call(float(suppression.get("refresh_seconds", 1.0)) <= 0.25, "Native cursor suppression should reassert quickly during prolonged interaction")

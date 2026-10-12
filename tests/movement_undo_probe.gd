extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Suite = preload("res://tests/suites/movement_undo_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Fixture = preload("res://tests/suites/player_movement_suite.gd")
const Router = preload("res://scripts/input_router.gd")
const UndoButton = preload("res://scripts/movement_undo_button.gd")

const OUTPUT_DIR: String = "user://probes/movement_undo"
const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
const FADE_CAPTURE_SECONDS: float = Suite.FADE_SAMPLE_SECONDS # Debug proof checkpoint halfway through the authored fade.
const FADE_OPAQUE_CHECK_SECONDS: float = Suite.FADE_OPAQUE_CHECK_SECONDS

var _scene: Node
var _canvas: SubViewport
var _failures: Array[String]
var _captures: Array[Dictionary]
var _diagnostics: Array[Dictionary]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	Suite.prepare_storage()
	root.size = VIEWPORT_SIZE
	root.content_scale_size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_run.call_deferred()

func _run() -> void:
	_canvas = SubViewport.new()
	_canvas.size = VIEWPORT_SIZE
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_canvas)
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_canvas.add_child(_scene)
	await Suite.settle(self)
	Suite.set_reduced_motion(_scene, false)
	_expect(not _scene.call("_reduced_motion_enabled"), "Normal-motion proof disables the actual RunScene animation gate")
	var before: Dictionary = Suite.install(_scene)
	await Suite.settle_hand_layout(self, _scene)
	# The dock anchors beside the hand envelope; let that envelope settle before taking the baseline.
	await Suite.settle(self)
	await Suite.settle_hand_layout(self, _scene)
	var meter: Control = _scene.get("_movement_meter")
	var dock_before_metadata: Dictionary = _dock_diagnostics("before_walk")
	await Suite.walk(_scene)
	await Suite.settle_hand_layout(self, _scene)
	var button: Button = _scene.get("_movement_undo_button")
	var dock_after_walk: Rect2 = meter.get_global_rect()
	var dock_shown_metadata: Dictionary = _dock_diagnostics("button_shown")
	_expect(not (button.get_parent() is Container), "Undo is an overlay outside the dock's layout containers")
	# Room-to-combat board centering already moves the dock on the base commit.
	# Isolate overlay visibility from that first walk's unrelated framing motion.
	button.hide()
	var dock_overlay_hidden_metadata: Dictionary = _dock_diagnostics("overlay_hidden")
	_expect(meter.get_global_rect() == dock_after_walk, "Hiding undo leaves the resource dock unchanged")
	button.refresh()
	_expect(meter.get_global_rect() == dock_after_walk, "Showing undo leaves the resource dock unchanged")
	_expect(button.visible and button.undo_available(), "Reversible walk shows Undo move")
	_expect(button.size.x == meter.size.x and button.global_position.y == meter.get_global_rect().end.y + UndoButton.UNDO_BUTTON_GAP, "Undo matches movement chip width and sits directly below it")
	_expect(button.tooltip_text == "Take back your last move. Moves that revealed or triggered something can't be undone.", "Button uses exact authored tooltip")
	await _capture("01_walk_button_visible", {"button_visible": button.visible, "button_rect": _rect(button), "movement_rect": _rect(meter), "dock_before": dock_before_metadata, "dock_shown": dock_shown_metadata, "dock_overlay_hidden": dock_overlay_hidden_metadata})

	button.request_undo()
	var fade_started_usec: int = Time.get_ticks_usec()
	await Suite.wait_for_wall_clock(self, fade_started_usec, FADE_CAPTURE_SECONDS)
	var alpha: float = Suite.drawn_hero_rig(_scene, Callable(self, "_expect")).modulate.a
	var partial_fade: Dictionary = _fade_diagnostics("partial_fade")
	_expect(alpha > 0.0 and alpha < 1.0, "Hero fades back over the authored 0.12 seconds")
	_expect(_scene.get("_combat_state") == before, "The hero is on the old tile before fade completes")
	await _capture("06_fade_back", {"hero_alpha": alpha, "sample_elapsed_seconds": float(Time.get_ticks_usec() - fade_started_usec) / 1000000.0, "scene_reduced_motion": _scene.call("_reduced_motion_enabled"), "fade": partial_fade})
	_fade_diagnostics("after_capture_before_frame_resume")
	await Suite.wait_for_wall_clock(self, fade_started_usec, FADE_OPAQUE_CHECK_SECONDS)
	var completed_alpha: float = Suite.drawn_hero_rig(_scene, Callable(self, "_expect")).modulate.a
	var opacity_check_elapsed_seconds: float = float(Time.get_ticks_usec() - fade_started_usec) / 1000000.0
	var completed_fade: Dictionary = _fade_diagnostics("opacity_deadline")
	_expect(completed_alpha == 1.0, "Drawn hero alpha reaches 1.0 by 0.2 seconds")
	_expect(not bool(completed_fade.get("coroutine_running", true)), "Fade coroutine finishes after restoring exactly 1.0 alpha")
	await Suite.settle(self)
	_expect(_scene.get("_combat_state") == before and not button.visible, "Undo restores exact state and hides its button")
	_expect(meter.get_global_rect() == dock_after_walk, "Dock after undo equals dock after walk")
	var dock_hidden_metadata: Dictionary = _dock_diagnostics("button_hidden")
	print("MOVEMENT UNDO DOCK RECTS: before=%s shown=%s hidden=%s" % [dock_before_metadata["movement_rect"], dock_shown_metadata["movement_rect"], dock_hidden_metadata["movement_rect"]])
	await _capture("02_after_undo", {"button_visible": button.visible, "movement_rect": _rect(meter), "restored_hash": hash(_scene.get("_combat_state")), "hero_alpha_at_0_2_seconds": completed_alpha, "opacity_check_elapsed_seconds": opacity_check_elapsed_seconds, "fade": completed_fade, "dock_before": dock_before_metadata, "dock_shown": dock_shown_metadata, "dock_hidden": dock_hidden_metadata})

	var committed_fixture: Dictionary = Fixture._state(Combat.new())
	committed_fixture["traps"] = [{"pos": Suite.FIRST_TILE, "element": "fire", "damage": 3}]
	Suite.install(_scene, committed_fixture)
	await Suite.walk(_scene)
	await Suite.settle(self)
	_expect(not button.visible and button.rules.last_walk_committed, "A trap walk commits and hides Undo move")
	var committed: Dictionary = _scene.get("_combat_state").duplicate(true)
	button.request_undo()
	await process_frame
	var texts: Array = _scene.get("board_view").get("presentation").get("floating_texts", [])
	_expect(texts.any(func(entry: Dictionary) -> bool: return entry.get("text") == "Can't undo — something changed."), "Blocked undo shows exact floating notice at the hero")
	await _capture("03_committed_walk_notice", {"notice": "Can't undo — something changed.", "hero_tile": str(committed["player"]["pos"]), "button_visible": button.visible})
	while bool(_scene.get("_animation_lock")): await process_frame
	_expect(_scene.get("_combat_state") == committed, "Blocked notice changes no combat state")

	before = Suite.install(_scene)
	await Suite.walk(_scene)
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "controller", "steam_deck")
	_scene.call("_refresh_controller_interface")
	await Suite.settle(self)
	var prompts: Array = _scene.get("_controller_prompt_bar").prompts_snapshot()
	_expect(prompts.any(func(prompt: Dictionary) -> bool: return prompt.get("label") == "Undo move" and prompt.get("action") == str(Router.ACTION_UNDO_MOVE)), "Controller prompt advertises available undo")
	_expect(router.call("glyph_label", Router.ACTION_UNDO_MOVE) == "L2", "Steam Deck uses left trigger glyph")
	await _capture("04_controller_prompt", {"prompts": prompts, "glyph": "L2", "button_rect": _rect(button)})

	Suite.set_reduced_motion(_scene, true)
	_expect(_scene.call("_reduced_motion_enabled"), "Reduced-motion proof enables the actual RunScene animation gate")
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_LEFT
	trigger.axis_value = 1.0
	await _scene.call("_handle_controller_input", trigger)
	await Suite.settle(self)
	_expect(_scene.get("_combat_state") == before and not button.visible, "Reduced motion controller undo restores instantly")
	_expect(Suite.drawn_hero_rig(_scene, Callable(self, "_expect")).modulate.a == 1.0, "Reduced motion never leaves a faded hero")
	await _capture("05_reduced_motion_undo", {"button_visible": button.visible, "reduced_motion": true})
	var report := FileAccess.open(OUTPUT_DIR.path_join("semantic-proof.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"captures": _captures, "diagnostics": _diagnostics, "failures": _failures}, "\t"))
	for failure: String in _failures: push_error(failure)
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("MOVEMENT UNDO PROBE RESULT: PASS" if _failures.is_empty() else "MOVEMENT UNDO PROBE RESULT: FAIL (%d failures)" % _failures.size())
	quit(0 if _failures.is_empty() else 1)

func _capture(name: String, semantics: Dictionary) -> void:
	await RenderingServer.frame_post_draw
	var path: String = OUTPUT_DIR.path_join(name + ".png")
	var frame: Image = _canvas.get_texture().get_image()
	_expect(frame.get_size() == VIEWPORT_SIZE, "Capture is exactly 1920x1080")
	_expect(frame.save_png(ProjectSettings.globalize_path(path)) == OK, "Capture writes %s" % name)
	_captures.append({"path": path, "semantics": semantics})
	print("MOVEMENT UNDO CAPTURE: %s" % ProjectSettings.globalize_path(path))

func _rect(control: Control) -> Array:
	return _rect_values(control.get_global_rect())

func _rect_values(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func _fade_diagnostics(label: String) -> Dictionary:
	var snapshot: Dictionary = _scene.get("_movement_undo_button").hero_fade_snapshot()
	snapshot["label"] = label
	snapshot["animation_lock"] = _scene.get("_animation_lock")
	_diagnostics.append(snapshot)
	print("MOVEMENT UNDO FADE: %s" % JSON.stringify(snapshot))
	return snapshot

func _dock_diagnostics(label: String) -> Dictionary:
	var centering: Tween = _scene.get("_board_centering_tween")
	var snapshot: Dictionary = {
		"label": label,
		"movement_rect": _rect(_scene.get("_movement_meter")),
		"play_rect": _rect(_scene.get("_play_meter")),
		"hand_scroll_rect": _rect(_scene.get("hand_scroll")),
		"hand_resting_rect": _rect_values(_scene.call("_combat_hand_resting_visual_bounds")),
		"board_rect": _rect(_scene.get("board_view")),
		"board_rendered_bounds": _rect_values(_scene.call("_contextual_combat_rendered_board_bounds")),
		"board_centering_running": centering != null and centering.is_valid() and centering.is_running(),
		"hand_layout_envelope": _scene.get("_hand_layout_envelope_signature"),
		"hand_layout_pending": _scene.get("_hand_layout_pending_revision"),
	}
	_diagnostics.append(snapshot)
	print("MOVEMENT UNDO DOCK: %s" % JSON.stringify(snapshot))
	return snapshot

func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)

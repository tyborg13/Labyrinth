extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const HandFanContainer = preload("res://scripts/hand_fan_container.gd")

var _failed: bool = false
const HUD_TAIL_FRAMES: int = 30
const HUD_TURN_TIMEOUT_MS: int = 25000
const HUD_FIXTURE_SIZE := Vector2i(1920, 1080)
const HUD_SETTLE_FRAMES: int = 8
const HUD_MIN_OPACITY: float = 0.999
const HUD_WIDE_FIXTURE_SIZE := Vector2i(2560, 1080)
const HUD_REVIEW_UI_SCALE: float = 1.25
const HUD_RECT_TOLERANCE: float = 0.01
const KEYWORD_SAMPLE_FPS: int = 60
const KEYWORD_TIMEOUT_FRAMES: int = 120
const KEYWORD_STABILITY_FRAMES: int = 10
const KEYWORD_PROOF_HOLD_FRAMES: int = 30
const KEYWORD_POSITION_TOLERANCE: float = 1.0
const KEYWORD_PROOF_DIR: String = "/private/tmp/labyrinth_codex/kb-02"
const TODO_DESIGN_POINTER_SETTLE_PARITY: String = "Pointer timing is protected by kb-02; confirm whether its existing two-frame reveal may also wait for the complete lift/spread."
var _keyword_proof_input: String = ""
var _keyword_capture_host: Node
var _keyword_viewport: Viewport

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute("user://card_draw_hand_flow_test")
	ProgressionStore.set_storage_path("user://card_draw_hand_flow_test/progression.json")
	ProgressionStore.set_run_storage_path("user://card_draw_hand_flow_test/current_run.save")
	SettingsStore.set_storage_path("user://card_draw_hand_flow_test/settings.json")
	ProgressionStore.clear_saved_run()
	_keyword_proof_input = OS.get_environment("LABYRINTH_KB02_PROOF_INPUT")
	if not _keyword_proof_input.is_empty() or OS.get_cmdline_user_args().has("--keyword-focus-only"):
		await _run_keyword_focus_regression(_keyword_proof_input == "pointer" or OS.get_cmdline_user_args().has("--keyword-pointer"))
		print("KB02 KEYWORD FOCUS TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
		quit(1 if _failed else 0)
		return
	await _run_keyword_focus_regression()
	await _run_opening_hand_entry_regression()
	await _run_transition_regression()
	await _run_resting_pointer_regression()
	await _run_turn_start_hud_regression()
	await _run_turn_start_hud_regression(true)
	await _run_hud_new_combat_regression()
	await _run_hud_shrinking_fan_regression()
	await _run_hud_handoff_resize_regression()
	if _failed:
		print("CARD DRAW HAND FLOW TEST RESULT: FAIL")
		quit(1)
		return
	print("CARD DRAW HAND FLOW TEST RESULT: PASS")
	quit()

func _run_keyword_focus_regression(pointer: bool = false) -> void:
	if pointer:
		# The pointer clip is a comparison trace, not permission to change its timing.
		print("TODO_DESIGN_POINTER_SETTLE_PARITY: " + TODO_DESIGN_POINTER_SETTLE_PARITY)
	var previous_fps: int = Engine.max_fps
	var previous_window: Dictionary = {"size": root.size, "content_scale_size": root.content_scale_size, "content_scale_mode": root.content_scale_mode, "content_scale_aspect": root.content_scale_aspect, "content_scale_factor": root.content_scale_factor}
	Engine.max_fps = KEYWORD_SAMPLE_FPS
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	settings["display_mode"] = SettingsStore.DISPLAY_WINDOWED
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	root.size = HUD_FIXTURE_SIZE
	root.content_scale_size = HUD_FIXTURE_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	await process_frame
	_keyword_capture_host = preload("res://tests/helpers/ui03_capture_viewport.gd").new()
	root.add_child(_keyword_capture_host)
	_keyword_capture_host.call("setup", root)
	_keyword_viewport = _keyword_capture_host.get("viewport") as Viewport
	var instance: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_keyword_viewport.add_child(instance)
	await process_frame
	await process_frame
	instance.call("_close_dialogue")
	instance.set("_progression", preload("res://scripts/contextual_combat_tutorial.gd").dismiss_tutorial(instance.get("_progression") as Dictionary))
	var router: Node = root.get_node("InputRouter")
	var previous_modality: String = str(router.call("modality"))
	var previous_family: String = str(router.call("controller_family"))
	router.call("set_forced_state_for_test", "pointer" if pointer else "controller", "xbox")
	await _load_combat_fixture(instance)
	instance.call("_refresh_controller_interface")
	for _frame: int in range(KEYWORD_PROOF_HOLD_FRAMES):
		await _keyword_frame()
	instance.call("_controller_clear_hand_hover")
	instance.set("_controller_hand_index", -1)
	var state_before: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	var hand: HandFanContainer = instance.get("hand_box") as HandFanContainer
	var stack: Control = instance.get("_card_focus_tooltip_stack") as Control
	for index: int in range(3):
		if pointer:
			var motion := InputEventMouseMotion.new()
			motion.position = _hand_card_center(instance, index)
			motion.relative = Vector2.ONE
			_keyword_capture_host.call("route", motion)
		else:
			_keyword_button(true)
		_expect(int(instance.get("_hovered_card_index")) == index, "KB02: real input must focus card %d" % index)
		if not pointer:
			_expect(not stack.visible, "KB02: moving focus must hide the previous keyword box in the input frame")
		var first_visible: int = -1
		var first_position := Vector2.ZERO
		var first_strength: float = -1.0
		for frame: int in range(KEYWORD_TIMEOUT_FRAMES):
			await _keyword_frame()
			var visible_this_frame: bool = stack.visible
			var position_this_frame: Vector2 = stack.global_position
			var strength_this_frame: float = hand.emphasis_strength()
			if frame == 0:
				_expect(not visible_this_frame, "KB02: the previous keyword box must be gone on the focus-change render")
				_keyword_save("card_%02d_lifting" % index)
				if not pointer:
					_keyword_button(false)
			if not visible_this_frame:
				continue
			first_visible = frame
			first_position = position_this_frame
			first_strength = strength_this_frame
			if not pointer:
				_expect(is_equal_approx(first_strength, 1.0) and not hand.is_sliding(), "KB02: first visible keyword frame must follow the completed lift (card %d, strength %.6f)" % [index, first_strength])
			_expect(not bool(instance.get("_hand_hover_rest_pending")) and frame >= int(instance.get("HAND_HOVER_REST_RENDERED_FRAMES")) - 1, "KB02: keyword reveal must include the pointer path's rendered rest frames")
			_keyword_save("card_%02d_first_visible" % index)
			break
		_expect(first_visible >= 0, "KB02: focused card %d must eventually show its keyword box" % index)
		for _frame: int in range(KEYWORD_STABILITY_FRAMES):
			await _keyword_frame()
		var drift: float = first_position.distance_to(stack.global_position)
		_expect(stack.visible, "KB02: the focused keyword box must remain visible 10 frames later")
		if not pointer:
			_expect(first_visible >= 0 and drift <= KEYWORD_POSITION_TOLERANCE, "KB02: first visible keyword position must match 10 frames later within 1px (card %d, drift %.3fpx)" % [index, drift])
		_keyword_save("card_%02d_plus_10" % index)
		print("KB02 KEYWORD TRACE: input=%s card=%d first_visible=%d strength=%.6f drift=%.3fpx" % ["pointer" if pointer else "controller", index, first_visible, first_strength, drift])
		if not _keyword_proof_input.is_empty():
			for _frame: int in range(KEYWORD_PROOF_HOLD_FRAMES):
				await _keyword_frame()
	_expect(state_before == instance.get("_combat_state"), "KB02: focus changes must preserve combat state and RNG")
	instance.queue_free()
	await process_frame
	_keyword_capture_host.call("close")
	_keyword_capture_host.queue_free()
	_keyword_capture_host = null
	_keyword_viewport = null
	router.call("set_forced_state_for_test", previous_modality, previous_family)
	router.call("clear_forced_state_for_test")
	for field: String in previous_window:
		root.set(field, previous_window[field])
	Engine.max_fps = previous_fps

func _keyword_button(pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = JOY_BUTTON_RIGHT_SHOULDER
	event.pressed = pressed
	_keyword_capture_host.call("route", event)

func _keyword_frame() -> void:
	await process_frame
	if DisplayServer.get_name() == "headless":
		# Headless checks model render boundaries; native proof uses actual draws.
		await create_timer(0.0).timeout
		RenderingServer.frame_post_draw.emit()
	else:
		await RenderingServer.frame_post_draw

func _keyword_save(label: String) -> void:
	if _keyword_proof_input.is_empty():
		return
	var directory: String = "%s/%s" % [KEYWORD_PROOF_DIR, _keyword_proof_input]
	DirAccess.make_dir_recursive_absolute(directory)
	var path: String = "%s/%s.png" % [directory, label]
	_expect(root.get_texture().get_image().save_png(path) == OK, "KB02: native proof frame must save")
	print(path)

func _run_opening_hand_entry_regression() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "Run scene should load for opening-hand entry coverage")
	if packed == null:
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	instance.call("_close_dialogue")

	var run_engine := RunEngine.new()
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	var combat_coord := Vector2i(999, 999)
	for coord_var: Variant in run_engine.available_moves(run_state):
		if typeof(coord_var) != TYPE_VECTOR2I:
			continue
		var coord: Vector2i = coord_var
		var preview_state: Dictionary = run_engine.move_to_room(run_state.duplicate(true), coord)
		if str(preview_state.get("mode", "")) == "combat" and not (preview_state.get("combat_state", {}) as Dictionary).is_empty():
			combat_coord = coord
			break
	_expect(combat_coord != Vector2i(999, 999), "Opening-hand entry coverage needs an available combat room")
	if combat_coord == Vector2i(999, 999):
		instance.queue_free()
		await process_frame
		return

	await instance.call("_on_map_view_room_selected", combat_coord)
	await process_frame
	var preview_scrim: Control = instance.get("_pre_battle_scrim") as Control
	_expect(preview_scrim != null and preview_scrim.visible, "Combat entry should pause on the pre-battle preview before Start")
	var sfx_before: int = _sfx_generation_total(instance.get("_sfx_players") as Array)
	instance.call("_on_pre_battle_start_pressed")
	var hand_box: Control = instance.get("hand_box") as Control
	var objective_hud: Control = instance.get("_combat_objective_hud") as Control
	_expect(preview_scrim != null and not preview_scrim.visible, "Start should uncover the combat room before the opening deal")
	_expect(bool(instance.get("_opening_hand_draw_in_progress")), "Start should enter an explicit opening-hand presentation phase")
	_expect(bool(instance.get("_animation_lock")), "Opening-hand presentation should lock combat input")
	_expect(hand_box != null and not hand_box.visible, "The authoritative complete hand must stay hidden before the first card launches")
	_expect((instance.get("_draw_hand_transition_proxies") as Array).is_empty(), "No card proxy should launch before the uncovered room receives its presentation wait")
	_expect(_sfx_generation_total(instance.get("_sfx_players") as Array) == sfx_before, "Draw audio must stay silent while the room is first uncovered")
	_expect(objective_hud != null and str(objective_hud.get("intro_phase")) == "prepared", "The uncovered-room frame should pre-stage the objective at upper center before it appears")
	if objective_hud != null:
		var prepared_viewport_size: Vector2 = instance.get_viewport_rect().size
		var prepared_intro_center := Vector2(prepared_viewport_size.x * 0.5, prepared_viewport_size.y * 0.28)
		var prepared_target_rect: Rect2 = instance.call("_combat_objective_hud_target_rect") as Rect2
		_expect(objective_hud.position + objective_hud.size * 0.5 == prepared_intro_center, "The hidden objective should already be staged at upper center before the first uncovered-room frame")
		_expect(not objective_hud.position.is_equal_approx(prepared_target_rect.position), "The objective must not flash in its final dock before the center pop")
		_expect(is_zero_approx(objective_hud.modulate.a), "The prepared upper-center objective should stay transparent until its pop begins")
		var prepared_intro_text: Control = objective_hud.get("_intro_text_stack") as Control
		_expect(prepared_intro_text != null and is_zero_approx(prepared_intro_text.modulate.a), "The transform-independent objective copy should also stay transparent until its pop begins")
		_expect(is_zero_approx(float(objective_hud.get("intro_shadow_progress"))), "The objective shadow should wait for the text reveal")
		_expect(is_zero_approx(float(objective_hud.get("intro_chrome_progress"))), "The prepared objective should keep its widget background and persistent contents hidden")
		_expect(is_zero_approx(float(objective_hud.get("intro_content_progress"))), "The prepared objective should keep the compact icon and detail hidden")

	var objective_deadline: int = Time.get_ticks_msec() + 2000
	while objective_hud != null and str(objective_hud.get("intro_phase")) != "holding" and Time.get_ticks_msec() < objective_deadline:
		await process_frame
	_expect(objective_hud != null and bool(objective_hud.get("intro_active")), "Battle entry should present the objective before dealing the opening hand")
	_expect(objective_hud != null and str(objective_hud.get("intro_phase")) == "holding", "The objective intro should reach its readable upper-center hold")
	_expect(objective_hud != null and objective_hud.visible, "The upper-center objective intro should reuse the visible persistent objective HUD")
	if objective_hud != null:
		var viewport_size: Vector2 = instance.get_viewport_rect().size
		var intro_center := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.28)
		_expect(objective_hud.position + objective_hud.size * 0.5 == intro_center, "The enlarged objective should hold at upper center")
		_expect(objective_hud.scale.x > 2.5, "The hidden widget shell should retain the established enlarged travel geometry for its later chrome reveal")
		_expect(is_zero_approx(float(objective_hud.get("intro_chrome_progress"))), "The readable hold should show only objective text without panel chrome")
		var intro_text_stack: Control = objective_hud.get("_intro_text_stack") as Control
		var intro_kicker: Label = objective_hud.get("_intro_kicker") as Label
		var intro_title: Label = objective_hud.get("_intro_title") as Label
		var settled_title: Label = objective_hud.get("_title") as Label
		var content_row: Control = objective_hud.get("_content_row") as Control
		_expect(intro_text_stack != null and intro_text_stack.visible and intro_text_stack.modulate.a > 0.99, "The readable hold should show the dedicated OBJECTIVE text treatment")
		_expect(intro_text_stack != null and intro_text_stack.scale.is_equal_approx(Vector2.ONE), "The held objective copy should render at native 1x scale instead of enlarging a low-resolution label")
		_expect(intro_text_stack != null and (intro_text_stack.position + intro_text_stack.size * 0.5).is_equal_approx(intro_center), "The native-size objective copy should preserve the approved upper-center placement")
		_expect(intro_kicker != null and intro_kicker.get_theme_font_size("font_size") == 46, "The OBJECTIVE kicker should use its authored large native font size")
		_expect(intro_title != null and intro_title.get_theme_font_size("font_size") == 92, "The opening objective title should be crisp and slightly larger than the previous approximately 80px presentation")
		_expect(intro_kicker != null and intro_kicker.get_theme_color("font_shadow_color").a > 0.65, "The held OBJECTIVE kicker should gain a restrained drop shadow over the board")
		_expect(intro_title != null and intro_title.get_theme_color("font_shadow_color").a > 0.75, "The held objective title should gain a readable drop shadow over the board")
		_expect(intro_title != null and intro_title.get_theme_constant("shadow_offset_y") == 8, "The title shadow should sit below the glyphs to add depth")
		_expect(settled_title != null and not settled_title.has_theme_color_override("font_shadow_color"), "The permanent objective widget should keep its established shadow-free title treatment")
		_expect(content_row != null and is_zero_approx(content_row.modulate.a), "The icon, live detail, and compact widget copy should remain hidden during the text-only hold")
		_expect(objective_hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "The objective intro should never intercept pointer input")
	_expect(bool(instance.get("_animation_lock")), "Combat input should remain locked throughout the objective introduction")
	_expect((instance.get("_draw_hand_transition_proxies") as Array).is_empty(), "Opening cards should wait until the objective has traveled to its HUD position")

	var travel_deadline: int = Time.get_ticks_msec() + 2000
	while objective_hud != null and str(objective_hud.get("intro_phase")) != "traveling" and Time.get_ticks_msec() < travel_deadline:
		await process_frame
	_expect(objective_hud != null and str(objective_hud.get("intro_phase")) == "traveling", "The objective should transition from its center hold toward the permanent HUD")
	var chrome_deadline: int = Time.get_ticks_msec() + 1000
	while (
		objective_hud != null
		and float(objective_hud.get("intro_chrome_progress")) < 0.5
		and Time.get_ticks_msec() < chrome_deadline
	):
		await process_frame
	if objective_hud != null:
		var traveling_intro_text: Control = objective_hud.get("_intro_text_stack") as Control
		_expect(traveling_intro_text != null and traveling_intro_text.scale.x > 0.32 and traveling_intro_text.scale.x < 1.0, "The traveling objective copy should visibly shrink toward its permanent size")
		_expect(float(objective_hud.get("intro_shadow_progress")) < 0.01, "The board-separation shadow should retire before the compact widget arrives")
		var chrome_progress: float = float(objective_hud.get("intro_chrome_progress"))
		_expect(chrome_progress >= 0.5, "The widget background should fade in behind the text during the latter travel")
		_expect(is_zero_approx(float(objective_hud.get("intro_content_progress"))), "The compact widget text and icon should wait until the large text has nearly retired")
	_expect((instance.get("_draw_hand_transition_proxies") as Array).is_empty(), "Card-deal motion should not compete with the traveling objective")
	var content_arrival_deadline: int = Time.get_ticks_msec() + 1000
	while (
		objective_hud != null
		and is_zero_approx(float(objective_hud.get("intro_content_progress")))
		and Time.get_ticks_msec() < content_arrival_deadline
	):
		await process_frame
	if objective_hud != null:
		var late_intro_text: Control = objective_hud.get("_intro_text_stack") as Control
		var content_progress: float = float(objective_hud.get("intro_content_progress"))
		_expect(late_intro_text != null and late_intro_text.modulate.a < 0.01, "The large objective copy should be fully gone before compact widget content arrives")
		_expect(content_progress > 0.0, "The compact widget content should fade in only after the large copy retires")
	_expect((instance.get("_draw_hand_transition_proxies") as Array).is_empty(), "Late objective-content arrival should still precede opening-card motion")

	var launch_deadline: int = Time.get_ticks_msec() + 3000
	while (
		(instance.get("_draw_hand_transition_proxies") as Array).is_empty()
		and Time.get_ticks_msec() < launch_deadline
	):
		await process_frame
	var opening_hand: Array = ((instance.get("_combat_state") as Dictionary).get("deck", {}) as Dictionary).get("hand", []) as Array
	var launch_proxies: Array = instance.get("_draw_hand_transition_proxies") as Array
	_expect(launch_proxies.size() == opening_hand.size(), "The opening deal should stage every final hand identity once its first card launches")
	_expect(_sfx_generation_total(instance.get("_sfx_players") as Array) == sfx_before + 1, "The first draw sound should begin on the same launch tick as the first visible opening card")
	_expect(hand_box != null and not hand_box.visible, "The live complete hand should remain hidden while draw proxies own the deal")

	var completion_deadline: int = Time.get_ticks_msec() + 5000
	while bool(instance.get("_opening_hand_draw_in_progress")) and Time.get_ticks_msec() < completion_deadline:
		await process_frame
	_expect(not bool(instance.get("_opening_hand_draw_in_progress")), "Opening-hand presentation should complete within its authored cadence")
	_expect(not bool(instance.get("_animation_lock")), "Completing the opening deal should restore combat input")
	_expect(hand_box != null and hand_box.visible, "The authoritative playable hand should replace the settled proxies")
	_expect((instance.get("_draw_hand_transition_proxies") as Array).is_empty(), "Opening-deal proxies should retire at authoritative handoff")
	_expect(_sfx_generation_total(instance.get("_sfx_players") as Array) == sfx_before + opening_hand.size(), "Opening deal should play exactly one synchronized draw sound per visible card")
	var ready_wave_count: int = 0
	if hand_box != null:
		for card_index: int in range(hand_box.get_child_count()):
			var widget: Control = instance.call("_hand_card_control", card_index) as Control
			if widget != null and str(widget.get_meta("ready_wave_reason", "")) == "combat_start":
				ready_wave_count += 1
	_expect(ready_wave_count > 0, "The normal playable-hand ready wave should follow the opening deal")
	_expect(objective_hud != null and str(objective_hud.get("intro_phase")) == "settled", "The objective intro should finish in its persistent HUD state")
	if objective_hud != null:
		var target_rect: Rect2 = instance.call("_combat_objective_hud_target_rect") as Rect2
		_expect(objective_hud.position.is_equal_approx(target_rect.position), "The objective should land at the permanent HUD position")
		_expect(objective_hud.scale.is_equal_approx(Vector2.ONE), "The settled objective should return to normal HUD scale")
		_expect(is_equal_approx(float(objective_hud.get("intro_chrome_progress")), 1.0), "The settled objective should restore the complete widget background and content")
		_expect(is_equal_approx(float(objective_hud.get("intro_content_progress")), 1.0), "The settled objective should restore the compact icon, title, and live detail")
		var settled_intro_text: Control = objective_hud.get("_intro_text_stack") as Control
		_expect(settled_intro_text != null and not settled_intro_text.visible, "The separate large intro text should retire after the widget settles")
		_expect(objective_hud.mouse_filter == Control.MOUSE_FILTER_STOP, "The settled objective should restore its existing tooltip interaction")

	var reduced_settings: Dictionary = (instance.get("_settings") as Dictionary).duplicate(true)
	reduced_settings["reduced_motion"] = true
	instance.set("_settings", reduced_settings)
	instance.call("_animate_combat_objective_intro")
	await process_frame
	_expect(objective_hud != null and str(objective_hud.get("intro_phase")) == "reduced_hold", "Reduced Motion should use a static center hold instead of the travel animation")
	_expect(objective_hud != null and objective_hud.get("_intro_tween") == null, "Reduced Motion should not create an objective motion tween")
	if objective_hud != null:
		var reduced_viewport_size: Vector2 = instance.get_viewport_rect().size
		var reduced_intro_center := Vector2(reduced_viewport_size.x * 0.5, reduced_viewport_size.y * 0.28)
		_expect(objective_hud.position + objective_hud.size * 0.5 == reduced_intro_center, "Reduced Motion should retain the clear upper-center objective emphasis")
		var reduced_intro_text: Control = objective_hud.get("_intro_text_stack") as Control
		var reduced_intro_title: Label = objective_hud.get("_intro_title") as Label
		_expect(reduced_intro_text != null and reduced_intro_text.scale.is_equal_approx(Vector2.ONE), "Reduced Motion should render its static objective copy at native 1x scale")
		_expect(reduced_intro_text != null and (reduced_intro_text.position + reduced_intro_text.size * 0.5).is_equal_approx(reduced_intro_center), "Reduced Motion should keep the native-size text in the approved upper-center position")
		_expect(reduced_intro_title != null and reduced_intro_title.get_theme_font_size("font_size") == 92, "Reduced Motion should retain the same crisp, enlarged authored title size")
		_expect(reduced_intro_title != null and reduced_intro_title.get_theme_color("font_shadow_color").a > 0.75, "Reduced Motion should retain the same shadowed board separation during its static hold")
		_expect(is_zero_approx(float(objective_hud.get("intro_chrome_progress"))), "Reduced Motion should preserve the text-only hold before snapping to the complete widget")
		_expect(is_zero_approx(float(objective_hud.get("intro_content_progress"))), "Reduced Motion should keep compact widget content out of its text-only hold")
	var reduced_deadline: int = Time.get_ticks_msec() + 1500
	while objective_hud != null and bool(objective_hud.get("intro_active")) and Time.get_ticks_msec() < reduced_deadline:
		await process_frame
	_expect(objective_hud != null and not bool(objective_hud.get("intro_active")), "Reduced Motion objective emphasis should settle promptly")
	if objective_hud != null:
		var reduced_target_rect: Rect2 = instance.call("_combat_objective_hud_target_rect") as Rect2
		_expect(objective_hud.position.is_equal_approx(reduced_target_rect.position), "Reduced Motion should snap to the same permanent objective HUD position")
		_expect(objective_hud.scale.is_equal_approx(Vector2.ONE), "Reduced Motion should settle at the normal persistent HUD scale")
		_expect(is_equal_approx(float(objective_hud.get("intro_chrome_progress")), 1.0), "Reduced Motion should restore the complete persistent widget after its static hold")
	instance.queue_free()
	await process_frame

func _sfx_generation_total(players: Array) -> int:
	var total: int = 0
	for player_var: Variant in players:
		var player: AudioStreamPlayer = player_var as AudioStreamPlayer
		if player != null:
			total += int(player.get_meta("play_generation", 0))
	return total

func _run_transition_regression() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "Run scene should load for hand-flow coverage")
	if packed == null:
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var before_state: Dictionary = await _load_combat_fixture(instance)
	await _run_pass_preview_warm_invalidation_regression(instance)
	await _run_retained_content_regression(instance, before_state)
	var intermediate_state: Dictionary = before_state.duplicate(true)
	var intermediate_deck: Dictionary = (intermediate_state.get("deck", {}) as Dictionary).duplicate(true)
	intermediate_deck["hand"] = ["shadow_step", "brace", "quick_stab", "lantern_shot", "patch_up"]
	intermediate_deck["draw"] = []
	intermediate_state["deck"] = intermediate_deck

	# This is the production card-play race: the action state still contains the
	# played card at index zero even though its hand widget has already disappeared.
	var transition: Dictionary = instance.call(
		"_draw_hand_transition_between_states",
		before_state,
		intermediate_state,
		0,
		true
	) as Dictionary
	var target_hand: Array = transition.get("target_hand", []) as Array
	var draw_entries: Array = transition.get("draw_entries", []) as Array
	_expect(target_hand == ["brace", "quick_stab", "lantern_shot", "patch_up"], "Draw transition should remove the played card before authoring final hand slots")
	_expect(draw_entries.size() == 2, "Draw transition should identify both incoming cards")
	if draw_entries.size() == 2:
		_expect(int((draw_entries[0] as Dictionary).get("index", -1)) == 2, "First draw should target final slot two instead of the stale played-card layout")
		_expect(int((draw_entries[1] as Dictionary).get("index", -1)) == 3, "Second draw should target final slot three instead of the stale played-card layout")
		_expect(int((draw_entries[0] as Dictionary).get("total", -1)) == 4, "Draw targets should use the authoritative four-card total")

	instance.set("_animating_hand_card_index", 0)
	instance.set("_animation_lock", true)
	instance.call("_refresh_animation_lock_ui")
	await process_frame
	var completion: Dictionary = {"done": false}
	instance.call(
		"_animate_draw_cards_fx_and_complete",
		draw_entries,
		Rect2(),
		0,
		transition,
		completion
	)
	await process_frame
	var hand_box: Control = instance.get("hand_box") as Control
	var initial_proxies: Array = instance.get("_draw_hand_transition_proxies") as Array
	_expect(hand_box != null and not hand_box.visible, "Staged draw should hide the stale live hand")
	_expect(initial_proxies.size() == target_hand.size(), "Staged draw should represent every final hand identity from its first frame")
	instance.call("_refresh_hand_panel")
	_expect(not hand_box.visible, "An incidental locked hand refresh must not expose the stale live hand during staged draw")
	_expect((instance.get("_draw_hand_transition_proxies") as Array).size() == target_hand.size(), "An incidental locked hand refresh must not retire running staged proxies")
	var initial_centers: Array[Vector2] = _proxy_centers(instance, initial_proxies)

	await create_timer(0.07).timeout
	var early_proxies: Array = instance.get("_draw_hand_transition_proxies") as Array
	var early_centers: Array[Vector2] = _proxy_centers(instance, early_proxies)
	_expect(_moved(initial_centers, early_centers, 0), "First retained card should begin reflowing immediately")
	_expect(_moved(initial_centers, early_centers, 1), "Second retained card should begin reflowing immediately")
	_expect(_moved(initial_centers, early_centers, 2), "First incoming card should begin its arc immediately")
	_expect(not _moved(initial_centers, early_centers, 3, 2.0), "Second incoming card should preserve the authored readable launch stagger")

	await create_timer(0.16).timeout
	var stream_proxies: Array = instance.get("_draw_hand_transition_proxies") as Array
	var stream_centers: Array[Vector2] = _proxy_centers(instance, stream_proxies)
	_expect(_moved(early_centers, stream_centers, 0), "Retained card reflow should continue while the draw stream advances")
	_expect(_moved(early_centers, stream_centers, 1), "Every retained card should keep flowing instead of freezing around an empty slot")
	_expect(_moved(early_centers, stream_centers, 3), "Second incoming card should launch after its stagger")
	_expect(stream_proxies.size() == target_hand.size(), "No transition frame should drop a hand identity")

	var deadline: int = Time.get_ticks_msec() + 2000
	while not bool(completion.get("done", false)) and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(bool(completion.get("done", false)), "Multi-card draw transition should complete")
	var settled_proxies: Array = instance.get("_draw_hand_transition_proxies") as Array
	_expect(settled_proxies.size() == target_hand.size(), "Settled staged hand should retain every proxy until authoritative refresh")
	var settled_centers: Array[Vector2] = _proxy_centers(instance, settled_proxies)
	for target_index: int in range(target_hand.size()):
		var card_size: Vector2 = instance.call("_hand_card_size", target_hand.size(), false)
		var target_rect: Rect2 = instance.call("_hand_receive_rect", target_index, target_hand.size(), card_size)
		_expect(settled_centers[target_index].distance_to(target_rect.get_center()) <= 1.0, "Settled proxy %d should occupy its exact authoritative hand slot" % target_index)

	var final_state: Dictionary = intermediate_state.duplicate(true)
	var final_deck: Dictionary = (final_state.get("deck", {}) as Dictionary).duplicate(true)
	final_deck["hand"] = target_hand.duplicate()
	final_state["deck"] = final_deck
	var final_run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	final_run_state["combat_state"] = final_state.duplicate(true)
	instance.set("_combat_state", final_state)
	instance.set("_run_state", final_run_state)
	instance.set("_animating_hand_card_index", -1)
	instance.set("_animation_lock", false)
	instance.set("_hand_panel_signature", "<unset>")
	instance.call("_refresh_ui")
	for _frame: int in range(6):
		await process_frame
	_expect((instance.get("_draw_hand_transition_proxies") as Array).is_empty(), "Authoritative hand refresh should retire every staged proxy")
	_expect(hand_box.visible, "Authoritative hand should become visible on the same refresh that retires proxies")
	for target_index: int in range(target_hand.size()):
		var final_card: Control = instance.call("_hand_card_control", target_index) as Control
		var final_center: Vector2 = final_card.get_global_transform_with_canvas() * (final_card.size * 0.5) if final_card != null else Vector2.ZERO
		_expect(
			final_center.distance_to(settled_centers[target_index]) <= 2.0,
			"Authoritative card %d should replace its proxy without a visible positional snap (proxy=%s real=%s delta=%.2f)" % [
				target_index,
				settled_centers[target_index],
				final_center,
				final_center.distance_to(settled_centers[target_index]),
			]
		)
	instance.queue_free()
	await process_frame

func _run_pass_preview_warm_invalidation_regression(instance: Node) -> void:
	# Production begins warming the next-turn Pass forecast before the staged draw.
	# Hiding a pointer-hovered hand then emits hover-ended while input is locked,
	# changing the forecast key before the warm coroutine finishes.
	instance.set("_hovered_card_index", 0)
	var warm_key: String = str(instance.call("_pass_preview_key"))
	var warm_generation: int = int(instance.get("_pass_preview_warm_generation")) + 1
	instance.set("_pass_preview_warm_generation", warm_generation)
	instance.set("_pass_preview_warm_active", true)
	instance.set("_pass_preview_warm_key", warm_key)
	_expect(bool(instance.get("_pass_preview_warm_active")), "Pass-preview warmup should be active before staged draw invalidation")
	_expect(not warm_key.is_empty(), "Pass-preview warmup should own its scheduled hover key")

	instance.set("_animation_lock", true)
	instance.call("_on_card_hover_ended", 0)
	_expect(int(instance.get("_hovered_card_index")) == -1, "Locked staged draw should still clear the stale card hover")
	_expect(str(instance.call("_pass_preview_key")) != warm_key, "Clearing hover should invalidate the scheduled Pass-preview key")
	_expect(
		bool(instance.call("_finish_pass_preview_cache_warm_if_stale", warm_generation, warm_key)),
		"The current Pass-preview worker should recognize and retire its invalidated key"
	)
	_expect(not bool(instance.get("_pass_preview_warm_active")), "A stale Pass-preview warmup must clear its active lifecycle flag")
	_expect(str(instance.get("_pass_preview_warm_key")).is_empty(), "A stale Pass-preview warmup must release its owned key")
	await instance.call("_await_pass_preview_cache_warm")
	instance.set("_animation_lock", false)

func _load_combat_fixture(instance: Node) -> Dictionary:
	var layout: Dictionary = {
		"name": "Card Draw Hand Flow Test",
		"coord": Vector2i(4, 1),
		"type": "combat",
		"grid": _simple_grid(),
		"player_start": Vector2i(2, 5),
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(5, 5),
			"hp": 20,
			"max_hp": 20,
			"block": 0,
		}],
		"loot": [],
	}
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(77104, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["shadow_step", "brace", "quick_stab", "lantern_shot", "patch_up"],
		"relics": [],
		"hand_size": 3,
		"heal_bonus": 0,
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["shadow_step", "brace", "quick_stab"]
	deck["draw"] = ["patch_up", "lantern_shot"]
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state.duplicate(true)
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_refresh_ui")
	await process_frame
	await process_frame
	return combat_state

# pol-43: a resting pointer owns hover across a deselect and a turn-start relayout.
func _run_resting_pointer_regression() -> void:
	var instance: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var source: Dictionary = await _load_combat_fixture(instance)
	var hand_box: Control = instance.get("hand_box") as Control
	instance.call("_ensure_sfx_bank")
	var ticks: Array[int] = [0]
	(instance.get("_sfx_bank") as Object).connect("cue_requested", func(cue_id: String, _result: String) -> void:
		if cue_id == "card.hover": ticks[0] += 1)

	# Deselect with the pointer still on the card: selected pose straight to hover pose, no tick.
	await _park_pointer(instance, _hand_card_center(instance, 0))
	_expect(int(instance.get("_hovered_card_index")) == 0, "A parked pointer should hover the card under it")
	await instance.call("_on_card_pressed", 0)
	_expect(int(instance.get("_selected_card_index")) == 0, "Shadow Step should select for targeting")
	await process_frame
	var ticks_before_deselect: int = ticks[0]
	await instance.call("_on_card_pressed", 0)
	_expect(int(instance.get("_selected_card_index")) == -1, "A second click on a targeted card should deselect it")
	_expect(
		int(instance.get("_hovered_card_index")) == 0
		and int(hand_box.call("emphasized_index")) == 0
		and is_equal_approx(float(hand_box.call("emphasis_strength")), 1.0)
		and is_equal_approx(float(hand_box.get("_emphasis_scale")), HandFanContainer.DEFAULT_EMPHASIS_SCALE),
		"A deselected card under the resting pointer should go straight to its hover pose"
	)
	_expect(ticks[0] == ticks_before_deselect, "Returning the same card to hover should not tick")

	# Turn start: the hand is rebuilt and unlocked under a resting pointer.
	var pointer: Vector2 = _hand_card_center(instance, 2)
	await _park_pointer(instance, pointer)
	instance.set("_hovered_card_index", -1)
	instance.call("_set_hand_emphasized_index", -1, false)
	instance.set("_animation_lock", true)
	instance.call("_refresh_animation_lock_ui")
	await process_frame
	var dealt: Dictionary = source.duplicate(true)
	dealt["deck"]["hand"] = ["shadow_step", "brace", "quick_stab", "patch_up", "lantern_shot"]
	dealt["deck"]["draw"] = []
	instance.set("_combat_state", dealt)
	(instance.get("_run_state") as Dictionary)["combat_state"] = dealt
	instance.call("_mark_combat_preview_state_changed")
	var ticks_before_deal: int = ticks[0]
	instance.call("_refresh_ui", false, true, true)
	_expect(int(instance.get("_hovered_card_index")) == -1 and int(hand_box.call("emphasized_index")) == -1, "No card may take hover from the half-built layout")
	# The cleared hover's neighbours are still easing back (pol-39), so the dealt
	# hand lands while sliding. Nothing lifts until it rests; its rested layout,
	# before anything lifts, decides the card under the pointer.
	_expect(bool(hand_box.call("is_sliding")), "The dealt hand should land while the hand is still easing")
	var rest_under: Array = [-2]
	hand_box.connect("slide_finished", func() -> void: rest_under[0] = _hand_card_under_point(instance, pointer), CONNECT_ONE_SHOT)
	var waited: int = 0
	var slide_clean: bool = true
	await process_frame
	while bool(hand_box.call("is_sliding")) and waited < 600:
		var sliding_hover: int = int(instance.get("_hovered_card_index"))
		var sliding_lift: int = int(hand_box.call("emphasized_index"))
		if slide_clean and (sliding_hover != -1 or sliding_lift != -1 or ticks[0] != ticks_before_deal):
			slide_clean = false
			_expect(false, "While the dealt hand slides nothing may hover, lift or tick (frame %d: hover %d, lifted %d)" % [waited + 1, sliding_hover, sliding_lift])
		await process_frame
		waited += 1
	_expect(not bool(hand_box.call("is_sliding")), "The dealt hand should come to rest")
	var under: int = int(rest_under[0])
	_expect(under >= 0, "The resting pointer should be over a card of the rested hand")
	# The first frame after the rest: the card under the pointer has taken hover and begun to lift.
	var hovered: int = int(instance.get("_hovered_card_index"))
	var native: int = _native_hand_index(instance)
	var lifted: int = int(hand_box.call("emphasized_index"))
	_expect(hovered == under and native == under and lifted == under, "The frame after the slide rests: hover %d (native %d, lifted %d) should be the card under the pointer %d" % [hovered, native, lifted, under])
	_expect(ticks[0] - ticks_before_deal == 1, "The rest should tick once for the card under the pointer, not %d times" % (ticks[0] - ticks_before_deal))
	# It keeps hover through its whole lift, with no further tick.
	waited = 0
	while lifted == under and float(hand_box.call("emphasis_strength")) < 1.0 and waited < 600:
		await process_frame
		waited += 1
		hovered = int(instance.get("_hovered_card_index"))
		lifted = int(hand_box.call("emphasized_index"))
		_expect(hovered == under and lifted == under, "During its lift: hover %d (lifted %d) should stay on the card under the pointer %d" % [hovered, lifted, under])
		if hovered != under: break
	_expect(ticks[0] - ticks_before_deal == 1, "The deal should tick once for the card under the pointer, not %d times" % (ticks[0] - ticks_before_deal))
	instance.queue_free()
	await process_frame

func _park_pointer(instance: Node, point: Vector2) -> void:
	# Headless roots are tiny and stretched; Input takes screen coordinates.
	var motion := InputEventMouseMotion.new()
	motion.position = instance.get_viewport().get_screen_transform() * point
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await process_frame
	await process_frame

# hud-01: exercise the real enemy hand-off, staged deal and authoritative landing.
# Sample the whole pass, including 30 frames after the last proxy has landed.
func _run_turn_start_hud_regression(exhausted: bool = false) -> void:
	root.content_scale_size = HUD_FIXTURE_SIZE
	root.content_scale_factor = 1.0
	root.size = HUD_FIXTURE_SIZE
	var instance: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	instance.call("_close_dialogue")
	var state: Dictionary = await _load_combat_fixture(instance)
	state["hand_size"] = 3
	state["draw_per_turn"] = 2
	state["objective"] = {"type": "kill_all"}
	if exhausted:
		state["cards_played_this_turn"] = state["cards_per_turn"]
		# A short pile presents real fatigue before the deal: hold the old home
		# until the surviving incoming card actually launches.
		state["deck"]["draw"] = ["patch_up"]
	instance.set("_combat_state", state)
	(instance.get("_run_state") as Dictionary)["combat_state"] = state.duplicate(true)
	instance.call("_refresh_ui")
	for _frame: int in range(HUD_SETTLE_FRAMES): await process_frame
	await _park_pointer(instance, _hand_card_center(instance, 2))
	var controls: Dictionary = {
		"pass": instance.find_child("PassPreviewChip", true, false),
		"card_plays": instance.get("_play_meter"),
		"movement": instance.get("_movement_meter"),
		"objective": instance.get("_combat_objective_hud"),
	}
	var rows: Array[Dictionary]
	var target_rects: Dictionary = {}
	var previous_rects: Dictionary = {}
	var hidden: Dictionary = {}
	var moved: Dictionary = {}
	var moved_before_deal: Dictionary = {}
	var saw_deal: bool = false
	var landing_frame: int = -1
	var tail: int = 0
	var deadline: int = Time.get_ticks_msec() + HUD_TURN_TIMEOUT_MS
	instance.call("_on_pass_turn_pressed")
	while Time.get_ticks_msec() < deadline:
		await process_frame
		# Headless has no renderer to release production's post-draw barriers.
		if DisplayServer.get_name() == "headless": RenderingServer.frame_post_draw.emit()
		var proxies: Array = instance.get("_draw_hand_transition_proxies") as Array
		var dealing: bool = false
		for proxy: Control in proxies:
			var tween: Tween = proxy.get_meta("active_card_proxy_tween", null) as Tween
			if tween != null and tween.is_valid() and tween.is_running(): dealing = true
		if not proxies.is_empty() and not saw_deal:
			saw_deal = true
			# The production Pass widget can be rebuilt during refresh; resolve it per frame.
			controls["pass"] = instance.find_child("PassPreviewChip", true, false)
			for key: String in controls:
				target_rects[key] = (controls[key] as Control).get_global_rect()
		if saw_deal and not dealing and landing_frame < 0: landing_frame = rows.size()
		controls["pass"] = instance.find_child("PassPreviewChip", true, false)
		var row: Dictionary = {"frame": rows.size(), "dealing": dealing, "landing_frame": landing_frame, "locked": instance.get("_animation_lock"), "controls": {}}
		for key: String in controls:
			var control: Control = controls[key] as Control
			var rect: Rect2 = control.get_global_rect() if control != null else Rect2()
			var shown: bool = control != null and control.is_visible_in_tree()
			var alpha: float = _hud_effective_alpha(control)
			# Selection/hover clearing belongs to the Pass input itself. Start the
			# retained hand-off comparison at its first submitted scene frame.
			if rows.is_empty(): previous_rects[key] = rect
			row["controls"][key] = {"visible": shown, "alpha": alpha, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]}
			if not shown or alpha < HUD_MIN_OPACITY or not rect.has_area(): hidden[key] = true
			if saw_deal and not rect.is_equal_approx(target_rects[key]): moved[key] = true
			if not saw_deal and not rect.is_equal_approx(previous_rects[key]): moved_before_deal[key] = true
		rows.append(row)
		if landing_frame >= 0:
			tail += 1
			if tail > HUD_TAIL_FRAMES and not bool(instance.get("_animation_lock")): break
	var trace_path: String = "user://card_draw_hand_flow_test/turn_start_hud_frames%s.jsonl" % ("_exhausted" if exhausted else "")
	var trace := FileAccess.open(trace_path, FileAccess.WRITE)
	if trace != null:
		for row: Dictionary in rows: trace.store_line(JSON.stringify(row))
		trace.close()
	print("TURN START HUD TRACE: %s frames=%d landing=%d hidden=%s moved=%s" % [ProjectSettings.globalize_path(trace_path), rows.size(), landing_frame, str(hidden.keys()), str(moved.keys())])
	_expect(saw_deal and landing_frame >= 0 and tail > HUD_TAIL_FRAMES, "HUD regression must observe a real turn deal and 30 post-landing frames")
	_expect(not bool(instance.get("_animation_lock")) and int((instance.get("_combat_state") as Dictionary).get("turn", 1)) == 2, "HUD regression must complete a real enemy phase and next player activation")
	_expect(hidden.is_empty(), "Turn-start HUD must remain visible at full opacity every frame: %s" % str(hidden.keys()))
	_expect(moved.is_empty(), "Turn-start HUD must occupy its deal-start rect through landing and pointer hover: %s" % str(moved.keys()))
	_expect(moved_before_deal.is_empty(), "Turn-start HUD must retain its previous home until the deal begins: %s" % str(moved_before_deal.keys()))
	if saw_deal:
		var old_pass_rect: Array = rows[0]["controls"]["pass"]["rect"]
		_expect(not is_equal_approx((target_rects["pass"] as Rect2).position.x, float(old_pass_rect[0])), "A wider new hand must move Pass to its new destination when the deal begins")
		var live_envelope: Rect2 = instance.call("_combat_hand_resting_visual_bounds")
		var dock_envelope: Rect2 = instance.call("_combat_dock_hand_bounds")
		# The director-approved reservation includes every remaining hand size and
		# future controller focus. Both axes stay fixed in the frame trace above.
		_expect(dock_envelope.position.x <= live_envelope.position.x and dock_envelope.end.x >= live_envelope.end.x, "The deal-start dock must reserve the final fan and every wider smaller/controller-focused fan")
	var pass_button: Button = controls["pass"] as Button
	_expect(pass_button != null and not pass_button.disabled and pass_button.focus_mode == Control.FOCUS_ALL, "Pass keeps its live click target and keyboard/gamepad focus after the deal")
	if pass_button != null:
		pass_button.grab_focus()
		_expect(pass_button.has_focus(), "The real Pass button must accept keyboard/gamepad focus at its new home")
		await _park_pointer(instance, pass_button.get_global_rect().get_center())
		var owner: Control = instance.get_viewport().gui_get_hovered_control()
		_expect(owner == pass_button or (owner != null and pass_button.is_ancestor_of(owner)), "Native pointer hit testing must use Pass's painted destination")
		pass_button.release_focus()
	# pol-37 also applies when this deal exceeds the original opening-hand floor.
	await _hud_review_play(instance, 1) # Fixture's targetless Brace, including confirmation.
	for _frame: int in range(HUD_SETTLE_FRAMES): await process_frame
	for key: String in controls:
		var control: Control = instance.find_child("PassPreviewChip", true, false) as Control if key == "pass" else controls[key] as Control
		_expect(control != null and control.is_visible_in_tree() and control.get_global_rect().is_equal_approx(target_rects[key]), "Playing a dealt card must preserve %s's home" % key)
	instance.queue_free()
	await process_frame

func _hud_effective_alpha(control: CanvasItem) -> float:
	if control == null: return 0.0
	var alpha: float = control.self_modulate.a
	var ancestor: Node = control
	while ancestor != null:
		if ancestor is CanvasItem: alpha *= (ancestor as CanvasItem).modulate.a
		ancestor = ancestor.get_parent()
	return alpha

# Director feedback: reuse one RunScene across encounters, including its real
# opening presentation. A preceding large fan cannot survive the room boundary.
func _run_hud_new_combat_regression() -> void:
	var scene: Node = await _hud_review_scene()
	var state: Dictionary = _hud_review_hand(scene, 10)
	var helper: RefCounted = scene.get("_combat_hud_layout")
	helper.call("begin_deal", scene)
	var run: Dictionary = scene.get("_run_state")
	run["mode"] = "room"
	run["combat_state"] = {}
	scene.call("_sync_combat_state_from_run")
	scene.call("_refresh_ui")
	var cleared: bool = int(helper.get("_dealt_count")) == 0
	state["room_coord"] = Vector2i(5, 1)
	state["deck"]["hand"] = _hud_review_cards(5)
	run["mode"] = "combat"
	run["combat_state"] = state
	scene.set("_combat_state", state)
	scene.call("_present_opening_hand_after_combat_entry")
	var deadline: int = Time.get_ticks_msec() + HUD_TURN_TIMEOUT_MS
	while (scene.get("_draw_hand_transition_proxies") as Array).is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
		if DisplayServer.get_name() == "headless": RenderingServer.frame_post_draw.emit()
	var opening_rect: Rect2 = (scene.find_child("PassPreviewChip", true, false) as Control).get_global_rect()
	var count_at_launch: int = int(helper.get("_dealt_count"))
	while bool(scene.get("_animation_lock")) and Time.get_ticks_msec() < deadline:
		await process_frame
		if DisplayServer.get_name() == "headless": RenderingServer.frame_post_draw.emit()
	for _frame: int in range(HUD_SETTLE_FRAMES): await process_frame
	var settled_rect: Rect2 = (scene.find_child("PassPreviewChip", true, false) as Control).get_global_rect()
	_expect(cleared, "HUD NEW COMBAT: ending combat must clear the preceding encounter's held layout")
	_expect(count_at_launch == 5, "HUD NEW COMBAT: the opening deal must own the new five-card hand before launch (got %d)" % count_at_launch)
	_expect(not bool(scene.get("_animation_lock")) and opening_rect.is_equal_approx(settled_rect), "HUD NEW COMBAT: opening Pass placement must survive input unlock")
	print("HUD REVIEW NEW COMBAT: cleared=%s launch_count=%d stable=%s" % [cleared, count_at_launch, opening_rect.is_equal_approx(settled_rect)])
	scene.queue_free()
	await process_frame

func _run_hud_shrinking_fan_regression() -> void:
	var scene: Node = await _hud_review_scene()
	_hud_review_hand(scene, 8)
	for _frame: int in range(HUD_SETTLE_FRAMES): await process_frame
	var helper: RefCounted = scene.get("_combat_hud_layout")
	helper.call("begin_deal", scene)
	var held: Rect2 = scene.call("_combat_dock_hand_bounds")
	var homes: Dictionary = _hud_review_rects(scene)
	await _hud_review_play(scene, 0)
	for _frame: int in range(HUD_SETTLE_FRAMES): await process_frame
	_expect(((scene.get("_combat_state") as Dictionary)["deck"]["hand"] as Array).size() == 7, "HUD SHRINKING FAN: the real Brace play must shrink eight cards to seven")
	var widest: float = 0.0
	var stable: bool = true
	var router: Node = root.get_node("InputRouter")
	for controller: bool in [false, true]:
		router.call("set_forced_state_for_test", "controller" if controller else "pointer", "xbox")
		scene.set("_controller_hand_focused", controller)
		for count: int in range(1, 9):
			_hud_review_hand(scene, count)
			for _frame: int in range(HUD_SETTLE_FRAMES): await process_frame
			widest = maxf(widest, (scene.call("_combat_hand_resting_visual_bounds") as Rect2).size.x)
			stable = stable and _hud_review_rects_match(homes, _hud_review_rects(scene))
	_expect(held.size.x + HUD_RECT_TOLERANCE >= widest, "HUD SHRINKING FAN: deal-start envelope must cover every smaller desktop/controller-focused fan (held %.2f, widest %.2f)" % [held.size.x, widest])
	_expect(stable, "HUD SHRINKING FAN: plays and controller focus must never move Pass, counters or Objective")
	# A mid-turn draw exceeding the original deal is the one allowed new home.
	var before: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	var after: Dictionary = before.duplicate(true)
	after["deck"]["hand"] = _hud_review_cards(9)
	var transition: Dictionary = scene.call("_draw_hand_transition_between_states", before, after)
	scene.set("_combat_state", after)
	(scene.get("_run_state") as Dictionary)["combat_state"] = after
	scene.set("_animation_lock", true)
	var completion: Dictionary = {"done": false}
	scene.call("_animate_draw_cards_fx_and_complete", transition["draw_entries"], Rect2(), 0, transition, completion)
	_expect(int(helper.get("_dealt_count")) == 9, "HUD SHRINKING FAN: an above-cap mid-turn draw must recompute placement when that draw launches")
	var deadline: int = Time.get_ticks_msec() + HUD_TURN_TIMEOUT_MS
	while not bool(completion["done"]) and Time.get_ticks_msec() < deadline: await process_frame
	scene.set("_animation_lock", false)
	router.call("set_forced_state_for_test", "pointer", "xbox")
	print("HUD REVIEW SHRINKING FAN: held=%.2f widest=%.2f stable=%s draw_cap=%d" % [held.size.x, widest, stable, int(helper.get("_dealt_count"))])
	scene.queue_free()
	await process_frame

func _run_hud_handoff_resize_regression() -> void:
	var scene: Node = await _hud_review_scene()
	root.content_scale_size = HUD_WIDE_FIXTURE_SIZE
	root.size = HUD_WIDE_FIXTURE_SIZE
	_hud_review_hand(scene, 8)
	for _frame: int in range(HUD_SETTLE_FRAMES): await process_frame
	(scene.get("_combat_hud_layout") as RefCounted).call("begin_deal", scene)
	scene.call("_on_pass_turn_pressed")
	await process_frame
	root.content_scale_size = HUD_FIXTURE_SIZE
	root.size = HUD_FIXTURE_SIZE
	var contained: bool = true
	for scale: float in [1.0, HUD_REVIEW_UI_SCALE]:
		root.content_scale_factor = scale
		for _frame: int in range(HUD_SETTLE_FRAMES):
			await process_frame
			if DisplayServer.get_name() == "headless": RenderingServer.frame_post_draw.emit()
			var viewport: Rect2 = scene.get_viewport_rect()
			for rect: Rect2 in _hud_review_rects(scene).values(): contained = contained and viewport.grow(HUD_RECT_TOLERANCE).encloses(rect)
	_expect(contained, "HUD HANDOFF RESIZE: every HUD rect must fit immediately after resize/UI-scale changes while the enemy hand-off holds layout")
	var deadline: int = Time.get_ticks_msec() + HUD_TURN_TIMEOUT_MS
	while bool(scene.get("_animation_lock")) and Time.get_ticks_msec() < deadline:
		await process_frame
		if DisplayServer.get_name() == "headless": RenderingServer.frame_post_draw.emit()
	print("HUD REVIEW HANDOFF RESIZE: contained=%s" % contained)
	scene.queue_free()
	await process_frame
	root.content_scale_factor = 1.0
	root.content_scale_size = HUD_FIXTURE_SIZE
	root.size = HUD_FIXTURE_SIZE

func _hud_review_scene() -> Node:
	root.content_scale_factor = 1.0
	root.content_scale_size = HUD_FIXTURE_SIZE
	root.size = HUD_FIXTURE_SIZE
	var scene: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.call("_close_dialogue")
	await _load_combat_fixture(scene)
	return scene

func _hud_review_play(scene: Node, index: int) -> void:
	var boundary: Callable = func() -> void: RenderingServer.frame_post_draw.emit()
	if DisplayServer.get_name() == "headless": process_frame.connect(boundary)
	await scene.call("_on_card_pressed", index)
	await scene.call("_on_confirm_card_play_pressed")
	if process_frame.is_connected(boundary): process_frame.disconnect(boundary)

func _hud_review_hand(scene: Node, count: int) -> Dictionary:
	var state: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	state["deck"]["hand"] = _hud_review_cards(count)
	scene.set("_combat_state", state)
	(scene.get("_run_state") as Dictionary)["combat_state"] = state
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
	return state

func _hud_review_cards(count: int) -> Array[String]:
	var cards: Array[String]
	for _index: int in range(count): cards.append("brace")
	return cards

func _hud_review_rects(scene: Node) -> Dictionary:
	var result: Dictionary = {}
	for field: String in ["_pass_preview_overlay", "_play_meter", "_movement_meter", "_combat_objective_hud"]:
		result[field] = (scene.get(field) as Control).get_global_rect()
	return result

func _hud_review_rects_match(before: Dictionary, after: Dictionary) -> bool:
	for field: String in before:
		if not (before[field] as Rect2).is_equal_approx(after[field]): return false
	return true

func _hand_card_center(instance: Node, index: int) -> Vector2:
	var card: Control = instance.call("_hand_card_control", index) as Control
	return card.get_global_transform_with_canvas() * (card.size * 0.5) if card != null else Vector2.ZERO

func _native_hand_index(instance: Node) -> int:
	var hovered: Control = instance.get_viewport().gui_get_hovered_control()
	var hand_box: Control = instance.get("hand_box") as Control
	for index: int in range(hand_box.get_child_count()):
		var card: Control = instance.call("_hand_card_control", index) as Control
		if hovered != null and card != null and (card == hovered or card.is_ancestor_of(hovered)):
			return index
	return -1

func _hand_card_under_point(instance: Node, point: Vector2) -> int:
	# Later siblings take the pointer where cards overlap.
	var hand_box: Control = instance.get("hand_box") as Control
	var under: int = -1
	for index: int in range(hand_box.get_child_count()):
		var card: Control = instance.call("_hand_card_control", index) as Control
		if card != null and card.is_visible_in_tree() and Rect2(Vector2.ZERO, card.size).has_point(card.get_global_transform_with_canvas().affine_inverse() * point):
			under = index
	return under

func _proxy_centers(instance: Node, proxies: Array) -> Array[Vector2]:
	var centers: Array[Vector2]
	for proxy_var: Variant in proxies:
		var proxy: Control = proxy_var as Control
		centers.append((instance.call("_card_proxy_visual_rect", proxy) as Rect2).get_center())
	return centers

func _moved(before: Array[Vector2], after: Array[Vector2], index: int, threshold: float = 0.5) -> bool:
	return index < before.size() and index < after.size() and before[index].distance_to(after[index]) > threshold

func _simple_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return grid

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)

func _run_retained_content_regression(instance: Node, source: Dictionary) -> void:
	var previous: Dictionary = {}
	var exits: Dictionary = {}
	var hands: Array = [
		["shadow_step", "brace", "quick_stab"],
		["quick_stab", "shadow_step", "quick_stab"],
		["shadow_step", "quick_stab"],
		["brace", "quick_stab", "shadow_step"],
	]
	for hand: Array in hands:
		var state: Dictionary = source.duplicate(true)
		state["deck"]["hand"] = hand.duplicate()
		instance.set("_combat_state", state)
		(instance.get("_run_state") as Dictionary)["combat_state"] = state
		instance.call("_mark_combat_preview_state_changed")
		instance.call("_refresh_hand_panel")
		await process_frame
		await process_frame
		var next: Dictionary = {}
		var used: Dictionary = {}
		_expect((instance.get("hand_box") as Control).get_child_count() == hand.size(), "Hand reconciliation must preserve exact order and duplicate cardinality")
		for index: int in range(hand.size()):
			var widget: Control = instance.call("_hand_card_control", index) as Control
			var card_id: String = str(hand[index])
			_expect(widget != null and widget.get("card_id") == card_id, "Reconciled hand widgets must match deck order")
			if widget == null: continue
			var widget_id: int = widget.get_instance_id()
			_expect(not used.has(widget_id), "Repeated card IDs must retain distinct widgets")
			used[widget_id] = true
			_expect(widget.size.is_equal_approx(Vector2(250, 352)), "Retained cards must keep native 250x352 geometry")
			_expect(int(instance.call("_hand_card_index_for_widget", widget)) == index, "Surviving card callbacks must resolve their new live index")
			if previous.has(card_id) and not next.has(card_id):
				var prior: Dictionary = previous[card_id]
				_expect(widget_id == int(prior["id"]), "First surviving duplicate should retain its existing widget")
				_expect(int(exits.get(widget_id, 0)) == int(prior["exits"]), "Surviving hand subtrees must stay in the scene tree")
			if not exits.has(widget_id):
				exits[widget_id] = 0
				widget.tree_exiting.connect(func() -> void: exits[widget_id] = int(exits.get(widget_id, 0)) + 1)
			if not next.has(card_id): next[card_id] = {"id": widget_id, "exits": exits[widget_id]}
		previous = next
		_expect(instance.get("_combat_state") == state, "Hand reconciliation must not mutate gameplay")
	instance.set("_combat_state", source.duplicate(true))
	(instance.get("_run_state") as Dictionary)["combat_state"] = instance.get("_combat_state")
	instance.call("_mark_combat_preview_state_changed")
	instance.call("_refresh_hand_panel")
	await process_frame
	await process_frame

extends RefCounted
## Reuses the archived perf134 combat states and sends public controller events.
const TRIGGER_FRAMES: int = 2
const SETTLE_FRAMES: int = 16
const DIRECTIONS: Array = [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]

static func run(probe: SceneTree) -> Dictionary:
	var scene: Control = probe._scene
	var board: Control = probe._board
	var trace: RefCounted = board.get("_board_redraw_trace")
	if trace == null:
		probe._errors.append("Set LABYRINTH_BOARD_REDRAW_TRACE=timing or inputs in a debug build")
		return {}
	var samples: Array[Dictionary]
	var start: Dictionary = scene.get("_combat_state")
	var initial_combat_sha256: String = probe._combat_digest(start)
	var before: Vector2i = start["player"]["pos"]
	# Establish controller modality before measuring the confirm action.
	_button(probe, JOY_BUTTON_X)
	if not bool(scene.get("_controller_hand_focused")): _button(probe, JOY_BUTTON_X)
	await probe._wait_frames(SETTLE_FRAMES)
	samples.append(await _sample(probe, trace, "A_select", JOY_BUTTON_A))
	if int(scene.get("_selected_card_index")) != 0:
		probe._errors.append("A did not select the fixture's opening card")
		return {"samples": samples}
	for button: int in DIRECTIONS:
		var focus: Vector2i = scene.get("_controller_board_tile")
		var sample: Dictionary = await _sample(probe, trace, "D-pad", button)
		if scene.get("_controller_board_tile") != focus: samples.append(sample)
		await probe._wait_frames(SETTLE_FRAMES)
	if samples.size() < 2: probe._errors.append("D-pad did not move the board cursor")
	var destination: Vector2i = scene.get("_controller_board_tile")
	samples.append(await _sample(probe, trace, "A_confirm", JOY_BUTTON_A))
	await probe._wait_for_action()
	await probe._wait_frames(SETTLE_FRAMES)
	if int(scene.get("_selected_card_index")) >= 0 or destination == before or scene.get("_combat_state")["player"]["pos"] != destination:
		probe._errors.append("A did not commit the fixture move to %s, from %s (now %s)" % [destination, before, scene.get("_combat_state")["player"]["pos"]])
	var turn: int = int(scene.get("_combat_state")["turn"])
	samples.append(await _sample(probe, trace, "Y_pass", JOY_BUTTON_Y))
	await probe._wait_for_action()
	if int(scene.get("_combat_state")["turn"]) <= turn:
		probe._errors.append("Y did not complete an enemy round")
	if samples.all(func(sample: Dictionary) -> bool: return sample["draws"].is_empty()):
		probe._errors.append("No _draw callbacks during the trigger windows")
	return {"samples": samples, "initial_combat_sha256": initial_combat_sha256,
		"destination": [destination.x, destination.y], "final_turn": scene.get("_combat_state")["turn"]}

static func _sample(probe: SceneTree, trace: RefCounted, trigger: String, button: int) -> Dictionary:
	var scene: Control = probe._scene
	var board: Control = probe._board
	scene.set_runtime_performance_instrumentation_enabled(true)
	board.set_submission_performance_instrumentation_enabled(true)
	board.set("_submission_detail_enabled", trace.resolve_inputs)
	board.get("_submission_detail_top").clear()
	var start_frame: int = Engine.get_process_frames()
	var before: Array = _input_witness(scene)
	trace.begin()
	_button(probe, button)
	await probe._wait_frames(TRIGGER_FRAMES)
	var draws: Array[Dictionary] = trace.finish()
	var stage: Dictionary = {}
	for phase: String in scene.get("_runtime_performance_counts"):
		if phase.begins_with("stage_") or phase == "hover_stage_refresh_total":
			stage[phase] = {
				"calls": scene.get("_runtime_performance_counts")[phase],
				"usec": scene.get("_runtime_performance_totals_usec")[phase],
				"max_usec": scene.get("_runtime_performance_max_usec")[phase],
			}
	return {"trigger": trigger, "button": button, "start_frame": start_frame, "before": before, "after": _input_witness(scene), "draws": draws, "stage": stage,
		"board_submission": board.submission_performance_instrumentation_snapshot(),
		"submission_detail": board.get("_submission_detail_top").duplicate(true)}

static func _input_witness(scene: Control) -> Array:
	var focus: Vector2i = scene.get("_controller_board_tile")
	var hero: Vector2i = scene.get("_combat_state")["player"]["pos"]
	return [focus.x, focus.y, hero.x, hero.y, scene.get("_selected_card_index"), scene.get("_animation_lock")]

static func _button(probe: SceneTree, button: int) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = button
		event.pressed = pressed
		probe._canvas.push_input(event, true)

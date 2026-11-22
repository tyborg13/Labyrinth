extends "res://tools/perf170/probe.gd"
## Compare the synchronous tooltip query and the single-card Chain restart.

const TooltipContext = preload("res://scripts/tooltip_loop_context.gd")
const LoopCache = preload("res://scripts/tooltip_loop_cache.gd")
const CHAIN_CASE: String = "single-storm-beacon"
const BURROW_CASE: String = "burrow-marks"
const ERUPT_POINT := Vector2(1093.854, 621.4206)
const CHAIN_START_FRAME: int = 14
const CHAIN_FOLLOWING_FRAMES: int = 4
const WARM_CHAIN_FRAMES := [0, 1, 2]

func _open(kind: String) -> bool:
	if kind == "tharokh":
		return await super._open(BURROW_CASE)
	var fixture: Dictionary = _fixtures["normal"].duplicate(true)
	fixture["combat_state"]["deck"]["hand"] = ["storm_beacon"]
	_fixtures[CHAIN_CASE] = fixture
	return await super._open(CHAIN_CASE)

func _exercise(kind: String) -> void:
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	await _wait_frames(READY_FRAMES)
	if kind == "tharokh":
		await _erupt_tooltip()
	else:
		await _chain_restart(JOY_BUTTON_DPAD_RIGHT, "chain-dpad")
		await _chain_restart(JOY_BUTTON_RIGHT_SHOULDER, "chain-rb")

func _erupt_tooltip() -> void:
	_scene._set_show_all_enemy_intents(true)
	if not await IntentReplay._prepare_card(self, "erupt-tooltip", false): return
	_register_headless_badges()
	var before: String = _board._get_tooltip(ERUPT_POINT)
	if before != _board.ActionIcons.description("erupt"):
		_errors.append("The armed Erupt tooltip was not registered at the reviewer point: " + before)
		return
	_button(JOY_BUTTON_B)
	var pressed: String = _board._get_tooltip(ERUPT_POINT)
	await _wait_frames(1)
	_register_headless_badges()
	var following: String = _board._get_tooltip(ERUPT_POINT)
	if _scene._selected_card_index >= 0 or _scene._controller_region != "board" or following != before:
		_errors.append("B did not return to the board with the Erupt tooltip on the next draw")
	_receipts["erupt-tooltip"] = {"before": before, "press": pressed, "following": following}

func _register_headless_badges() -> void:
	if not _headless: return
	for canvas: Control in IntentReplay._chip_canvases(self):
		var badge: Dictionary = canvas._render_slice_ops[0][1][0]
		canvas._tooltip_regions.clear()
		canvas._tooltip_loop_source = TooltipContext.actor_source(canvas, str(badge["key"]))
		TooltipContext.register_badge(canvas, badge, canvas._tooltip_loop_source)
		canvas._tooltip_loop_source = {}

func _chain_restart(button: int, key: String) -> void:
	if _scene._controller_region != "hand": _button(JOY_BUTTON_X)
	if not await _rest(key): return
	var loop: Control = _chain_window()
	if loop == null or loop.reduced_motion or loop.get_meta("tooltip_loop_id", "") == "":
		_errors.append(key + " did not start with a live tooltip demo and Reduced Motion off")
		return
	var deadline: int = Time.get_ticks_usec() + REST_TIMEOUT_USEC
	while loop.displayed_frame < CHAIN_START_FRAME and Time.get_ticks_usec() < deadline:
		await _wait_frames(1)
	if loop.displayed_frame != CHAIN_START_FRAME:
		_errors.append(key + " did not reach demo frame 14")
		return
	var original_id: int = loop.get_instance_id()
	var start_frame: int = loop.displayed_frame
	# Decode latency varies with the host. Warm the first frames independently
	# of playback so the samples compare the restart rather than a cold worker.
	loop.set_process(false)
	var asset: String = loop.asset_path
	var cache: Node = LoopCache.shared()
	for index: int in WARM_CHAIN_FRAMES:
		while cache.frame(asset, index) == null and Time.get_ticks_usec() < deadline:
			await _wait_frames(1)
		if cache.frame(asset, index) == null:
			_errors.append(key + " could not prepare demo media")
			return
	loop.set_process(true)
	_button(button)
	var frames: Array = []
	var replaced: bool = false
	for frame: int in range(CHAIN_FOLLOWING_FRAMES):
		await _wait_frames(1)
		loop = _chain_window()
		if loop == null:
			_errors.append(key + " lost the Chain panel on hand cycle")
			return
		replaced = replaced or loop.get_instance_id() != original_id
		frames.append(loop.displayed_frame)
	if _scene._controller_hand_index != 0 or _scene._hovered_card_index != 0 or _scene._selected_card_index != -1:
		_errors.append(key + " changed the one-card hand focus")
	_receipts[key] = {"start": start_frame, "replaced": replaced, "frames": frames}

func _chain_window() -> Control:
	var stack: Control = _scene._card_focus_tooltip_stack
	for panel: Node in stack.get_children():
		if str(panel.get_meta("icon_key", "")) == "chain":
			return panel.find_child("TooltipLoopWindow", true, false) as Control
	return null

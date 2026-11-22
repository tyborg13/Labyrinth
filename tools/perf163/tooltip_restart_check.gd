extends RefCounted
## The normal frame route has no animated keyword in its archived hand.

const CARD_ID: String = "storm_beacon"
const CHAIN_LOOP_ID: String = "chain_card"
const WARM_FRAME: int = 14
const BUTTONS := [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_RIGHT]

static func run(probe: SceneTree) -> void:
	var starting_errors: int = probe._errors.size()
	var original: Dictionary = probe._fixtures["normal"]
	var fixture: Dictionary = original.duplicate(true)
	probe._fixtures["normal"] = fixture
	for card_count: int in [1, 2]:
		var hand: Array[String]
		hand.resize(card_count)
		hand.fill(CARD_ID)
		fixture["combat_state"]["deck"]["hand"] = hand
		if not await probe._open("normal"):
			probe._scene.queue_free()
			break
		probe._button(JOY_BUTTON_RIGHT_SHOULDER)
		await probe._wait_frames(probe.RAPID_FRAMES)
		if probe._scene._controller_region != "hand": probe._button(JOY_BUTTON_X)
		if await probe._settle("Storm Beacon setup"):
			for button: int in BUTTONS:
				await _check_cycle(probe, button, card_count)
		probe._scene.queue_free()
		await probe._wait_frames(2)
	probe._fixtures["normal"] = original
	var failures: int = probe._errors.size() - starting_errors
	print("PERF-163 TOOLTIP RESTART: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])

static func _check_cycle(probe: SceneTree, button: int, card_count: int) -> void:
	var scene: Control = probe._scene
	var stack: Control = scene._card_focus_tooltip_stack
	var before: Control = await _wait_for_frame(probe, stack, WARM_FRAME)
	if before == null:
		probe._errors.append("Storm Beacon Chain demo did not reach frame %d" % WARM_FRAME)
		return
	var owner: int = scene._controller_hand_index
	var before_id: int = before.get_instance_id()
	probe._button(button)
	if scene._controller_hand_index != posmod(owner + 1, card_count) or scene._hovered_card_index != scene._controller_hand_index:
		probe._errors.append("Storm Beacon hand focus did not follow joypad button %d" % button)
	var after: Control = await _wait_for_frame(probe, stack, 0)
	var frame: int = after.displayed_frame if after != null else -1
	if after == null or after.get_instance_id() == before_id or frame != 0:
		probe._errors.append("Storm Beacon (%d copies, button %d) expected a new Chain demo at frame 0, got frame %d" % [card_count, button, frame])

static func _wait_for_frame(probe: SceneTree, stack: Control, minimum: int) -> Control:
	for index: int in range(probe.SETTLE_LIMIT):
		await probe._wait_frames(1)
		var loop: Control = stack.find_child("TooltipLoopWindow", true, false)
		if loop != null and loop.is_visible_in_tree() and loop.get_meta("tooltip_loop_id", "") == CHAIN_LOOP_ID and loop.displayed_frame >= minimum:
			return loop
	return null

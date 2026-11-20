extends "res://tools/hitch_census/driver.gd"
## Runs the original census demo route and observes its real controller presses.

const CONFIRM_FRAMES: int = 2
const HEADLESS_FPS: int = 60
var _down: Dictionary = {}
var _board_trace: RefCounted
var _take: Dictionary = {}
var _takes: Array[Dictionary]

func hold(duration: float) -> void:
	if not headless_smoke:
		await super.hold(duration)
		return
	# Match the fixed step of the headless replay. The native census keeps
	# its original wall-clock holds.
	for frame: int in range(ceili(duration * HEADLESS_FPS)):
		if finished: return
		await process_frame

func mark(label: String, stage: String = "action") -> void:
	if stage == "controller_input":
		for button: int in [JOY_BUTTON_A, JOY_BUTTON_Y]:
			if label.begins_with("controller:Joypad Button %d " % button):
				# The census marks both edges with the same label. Its joypad
				# sender always emits the press before the matching release.
				_down[button] = not bool(_down.get(button, false))
				if _down[button]: _start_press(button)
	super.mark(label, stage)

func _start_press(button: int) -> void:
	var live: Node = current_scene
	if not is_instance_valid(live) or live.get("_combat_state") == null: return
	if live.get("_run_state").get("mode") != "combat": return
	var state: Dictionary = live.get("_combat_state")
	if not (state.get("enemies", []) as Array).any(func(enemy: Dictionary) -> bool: return str(enemy.get("type", "")) == "tharokh"): return
	var board: Control = live.get("board_view")
	if not is_instance_valid(board): return
	var redraw: RefCounted = board.get("_board_redraw_trace")
	if redraw == null or not _take.is_empty(): return
	_board_trace = redraw
	_take = {
		"button": button, "decision": trace.decision + 1, "start_frame": Engine.get_process_frames(),
		"turn": state.get("turn"), "hand_index": live.get("_controller_hand_index"),
		"selected": live.get("_selected_card_index"), "walking": live.get("_player_movement_selected"),
		"phase": live.get("_controller_region"), "action_index": live.get("_pending_action_index"),
	}
	redraw.begin()
	for frame: int in range(CONFIRM_FRAMES):
		if headless_smoke: await process_frame
		else: await RenderingServer.frame_post_draw
	if not _take.is_empty(): _finish_press()

func _finish_press() -> void:
	_take["draws"] = _board_trace.finish()
	_takes.append(_take)
	_take = {}
	_board_trace = null

func finish(outcome: String) -> void:
	if finished: return
	if not _take.is_empty(): _finish_press()
	var file := FileAccess.open(output.path_join("tharokh-confirms.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"seed": run_seed, "headless": headless_smoke, "samples": _takes}, "\t"))
		file.close()
	var counts: Array = [0, 0]
	for sample: Dictionary in _takes:
		counts[0 if sample["button"] == JOY_BUTTON_A else 1] += 1
	if counts[0] == 0 or counts[1] == 0:
		errors.append("PERF-148 CENSUS TRACE did not reach both Tharokh button cohorts")
	print("PERF-148 CENSUS TRACE: %d A presses, %d Y presses" % counts)
	super.finish(outcome)

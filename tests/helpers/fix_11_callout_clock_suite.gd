extends RefCounted

const Callouts = preload("res://scripts/intent_callouts.gd")
const TestClock = preload("res://tests/helpers/presentation_test_clock.gd")
const Fixtures = preload("res://tests/suites/en03_enemies_suite.gd")
const STEP_SECONDS: float = 1.0 / 60.0
const FIRST_FRAME_STALL_SECONDS: float = 3.0
const PLAYBACK_TIMEOUT_SECONDS: float = 3.0
const LIFECYCLE_WAIT_FRAMES: int = 4

class DrawBoard:
	extends Control
	var _hud_render_layer: Control

class PlaybackScene:
	extends Control
	var samples: Array[Dictionary]
	var submission: int = 0
	var render_calls: int = 0
	var draw_enabled: bool = true
	var stall_seconds: float = 0.0
	var next_actor_frame: int = -1
	var _run_state: Dictionary = {"mode": "combat"}
	var _combat_state: Dictionary = {}
	var _combat_engine: RefCounted
	func _reduced_motion_enabled() -> bool: return false
	func _render_board_state(_state: Dictionary, presentation: Dictionary) -> void:
		render_calls += 1
		if presentation.is_empty():
			next_actor_frame = submission
			return
		submission += 1
		# A real first-frame stall is one long frame, followed by its draw.
		if submission == 1: TestClock.now_usec = roundi(stall_seconds * 1000000.0)
		if draw_enabled:
			samples.append((presentation["intent_callouts"][0] as Dictionary).duplicate(true))
			get_node("BoardUnderlay/CombatBoard").emit_signal("draw")
		TestClock.now_usec = roundi((float(submission) * STEP_SECONDS + stall_seconds) * 1000000.0)

static func _scene(tree: SceneTree) -> Control:
	var scene := PlaybackScene.new()
	var underlay := Control.new()
	underlay.name = "BoardUnderlay"
	var board := DrawBoard.new()
	board.name = "CombatBoard"
	board.hide() # Draw acknowledgements are controlled by the test harness.
	underlay.add_child(board)
	scene.add_child(underlay)
	tree.root.add_child(scene)
	return scene

static func run(tree: SceneTree, expect: Callable) -> void:
	var script: GDScript = TestClock.clocked_script(Callouts)
	for reason: bool in [true, false]:
		for mode: String in ["steady", "stall", "hidden"]:
			TestClock.now_usec = 0
			var scene: Control = _scene(tree)
			scene.set("draw_enabled", mode != "hidden")
			if mode == "stall": scene.set("stall_seconds", FIRST_FRAME_STALL_SECONDS)
			var entry: Dictionary = {"text": "No target" if reason else "Redirected", "no_action_reason": "no_target" if reason else ""}
			await script.play(scene, {}, entry)
			var samples: Array = scene.get("samples")
			var expected_frames: int = (66 if reason else 54) + (3 if mode == "hidden" else 0)
			expect.call(scene.get("next_actor_frame") == expected_frames, "%s: reason=%s keeps its exact next-actor frame %d" % [mode, reason, expected_frames])
			if mode != "hidden" and reason:
				expect.call(samples.size() == 66 and samples.slice(0, 48).all(func(sample: Dictionary) -> bool: return sample["alpha"] == 1.0), "One long first frame still draws the complete opaque hold and fade")
			expect.call(scene.get_node("BoardUnderlay/CombatBoard").get_signal_connection_list("draw").is_empty(), "%s: normal completion disconnects the clock" % mode)
			print("FIX-11 CLOCK: reason=%s mode=%s drawn_frames=%d next_actor_frame=%d" % [reason, mode, samples.size(), scene.get("next_actor_frame")])
			scene.free()
	var clock := Callouts.PresentationClock.new()
	clock.advance(FIRST_FRAME_STALL_SECONDS)
	expect.call(clock.elapsed == 0.0, "One undrawn process frame cannot consume the hold")
	clock.drawn()
	clock.advance(FIRST_FRAME_STALL_SECONDS)
	expect.call(is_equal_approx(clock.elapsed, 0.1), "Later frame stalls are capped to 0.1 unscaled seconds")
	await _test_detached_board(tree, expect)
	await _test_lifecycle(tree, expect)
	await _test_already_ended_state(tree, expect)

static func _play(scene: Control, completed: Dictionary) -> void:
	await _play_state(scene, {}, completed)

static func _play_state(scene: Control, state: Dictionary, completed: Dictionary) -> void:
	await Callouts.play(scene, state, {"actor_key": "enemy_1", "text": "No target", "no_action_reason": "no_target"})
	completed["done"] = true

static func _test_already_ended_state(tree: SceneTree, expect: Callable) -> void:
	var scene: Control = _scene(tree)
	var combat := Fixtures.Combat.new()
	var current: Dictionary = Fixtures.thralls()
	var animated: Dictionary = current.duplicate(true)
	animated["player"]["hp"] = 0
	scene.set("_combat_engine", combat)
	scene.set("_combat_state", current)
	var completed: Dictionary = {"done": false}
	expect.call(combat.combat_outcome(current) == "" and combat.combat_outcome(animated) != "", "Already-ended animated state is tested while the scene's current combat is live")
	_play_state(scene, animated, completed)
	await tree.process_frame
	expect.call(completed["done"], "Already-ended animated state completes within one frame")
	expect.call(scene.get("render_calls") == 0 and (scene.get("samples") as Array).is_empty(), "Already-ended animated state renders nothing")
	expect.call(scene.get_node("BoardUnderlay/CombatBoard").get_signal_connection_list("draw").is_empty(), "Already-ended animated state leaves no draw connection")
	# A failing guard mutation still gets a clean coroutine teardown.
	(scene.get("_run_state") as Dictionary)["mode"] = "room"
	for _frame: int in range(LIFECYCLE_WAIT_FRAMES): await tree.process_frame
	scene.free()

static func _test_detached_board(tree: SceneTree, expect: Callable) -> void:
	var scene: Control = _scene(tree)
	var board: Control = scene.get_node("BoardUnderlay/CombatBoard")
	board.get_parent().remove_child(board)
	var completed: Dictionary = {"done": false}
	var started: int = Time.get_ticks_usec()
	_play(scene, completed)
	while not completed["done"] and float(Time.get_ticks_usec() - started) / 1000000.0 < PLAYBACK_TIMEOUT_SECONDS: await tree.process_frame
	expect.call(completed["done"], "A board outside the tree completes using the three-frame no-draw fallback")
	expect.call(board.get_signal_connection_list("draw").is_empty(), "A detached board's clock signal is disconnected")
	board.free()
	scene.free()

static func _test_lifecycle(tree: SceneTree, expect: Callable) -> void:
	for mode: String in ["removed", "freed", "mode_ended", "combat_ended"]:
		var scene: Control = _scene(tree)
		scene.set("draw_enabled", false)
		var board: Control = scene.get_node("BoardUnderlay/CombatBoard")
		if mode == "combat_ended":
			scene.set("_combat_engine", Fixtures.Combat.new())
			scene.set("_combat_state", Fixtures.thralls())
		var completed: Dictionary = {"done": false}
		_play(scene, completed)
		await tree.process_frame
		if mode == "removed": tree.root.remove_child(scene)
		elif mode == "freed":
			# Retain the draw owner to verify cleanup even after the scene is gone.
			board.get_parent().remove_child(board)
			scene.queue_free()
		elif mode == "mode_ended": (scene.get("_run_state") as Dictionary)["mode"] = "room"
		else: (scene.get("_combat_state") as Dictionary)["player"]["hp"] = 0
		for _frame: int in range(LIFECYCLE_WAIT_FRAMES): await tree.process_frame
		expect.call(completed["done"], "%s: callout caller completes as soon as its presentation scope ends" % mode)
		expect.call(board.get_signal_connection_list("draw").is_empty(), "%s: cancellation disconnects the clock on every exit" % mode)
		if is_instance_valid(scene): scene.free()
		else: board.free()

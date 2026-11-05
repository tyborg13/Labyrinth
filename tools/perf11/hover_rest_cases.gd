extends RefCounted
## Opt-in rest/sweep proof, kept out of permanent suites. Dummy rendering uses
## explicitly clocked post-draw signals; native proof uses only real renders.
const Fixture = preload("res://tests/suites/turn_clock_hud_suite.gd")
const Trace = preload("res://tests/perf/combat_frame_trace.gd")
const FIRST_CARD: int = 0
const NEXT_CARD: int = 1
const NO_DRAW_PROCESS_FRAMES: int = 4
const HANDOFF_DRAWS: int = 8
const SMALL_POINTER_MOTION := Vector2(1, 0)
const HANDOFF_POINTER_MOTION := Vector2(3, 0)
const QUIET_CONTROLLER_ACTIVITY_MSEC: int = -10000
const CASES: Array = ["rest", "reduced_rest", "sweep", "sweep_exit", "sweep_rest", "rest_then_sweep", "repeat_enter", "reenter", "key_focus", "controller_focus"]
const CAPTURE_CASES: Array = ["rest", "sweep", "sweep_rest", "sweep_exit", "reduced_rest", "key_focus", "controller_focus"]
const PRESENTATION_KEYS: Array = ["preview_state", "board_state", "board_presentation", "move_tiles", "attack_tiles", "glossary", "glossary_visible", "strip_roles", "strip_visible", "strip_order", "tutorial_phase", "tutorial_definition"]

static func run(probe: SceneTree) -> Dictionary:
	var results: Dictionary = {}
	for case: String in CASES:
		results[case] = {}
		for side: String in ["before", "after"]:
			var scene: Node = probe._scene(probe.reference if side == "before" else probe.candidate)
			probe.root.add_child(scene)
			await probe._settle()
			await Fixture._install(probe, scene, Fixture.fixture(probe._combat_engine))
			var combat: Dictionary = scene.get("_combat_state")
			combat["analytics"]["combat_id"] = probe.FIXTURE_COMBAT_ID
			scene.call("_mark_combat_preview_state_changed")
			scene.call("_refresh_ui")
			await probe._settle()
			if case == "reduced_rest":
				var settings: Dictionary = scene.get("_settings")
				settings["reduced_motion"] = true
				scene.set("_settings", settings)
				probe._check(scene.call("_reduced_motion_enabled"), "reduced rest fixture enabled")
			if case == "rest_then_sweep":
				scene.call("_on_card_hover_started", FIRST_CARD)
				await probe._settle()
			var baseline: Dictionary = probe._snapshot(scene).duplicate(true)
			probe.headless_draw_paused = true
			scene.call("set_runtime_performance_instrumentation_enabled", true)
			Trace.reset()
			Trace.enabled = true
			var frames: Array[Dictionary]
			scene.call("_on_card_hover_started", FIRST_CARD)
			if case in ["key_focus", "controller_focus"]:
				# Both devices use the production hand-navigation entry point.
				if case == "key_focus":
					var key := InputEventKey.new()
					key.keycode = KEY_SHIFT
					key.pressed = true
					scene.call("_input", key)
				scene.set("_controller_region", "hand")
				scene.set("_controller_hand_focused", true)
				scene.call("_controller_set_hand_index", FIRST_CARD)
			if case == "rest_then_sweep":
				scene.call("_on_card_hover_ended", FIRST_CARD)
				scene.call("_on_card_hover_started", NEXT_CARD)
			frames.append(await _boundary(probe, scene))
			if case == "rest" and not probe.capture:
				# Process ticks and elapsed time alone must never mature a rest.
				for tick: int in range(NO_DRAW_PROCESS_FRAMES): await probe.process_frame
				probe._check(_stage_count() == 0 if side == "after" else true, "rest: process ticks without renders do not refresh")
			await _render(probe)
			if case in ["sweep", "sweep_exit", "sweep_rest"]:
				scene.call("_on_card_hover_ended", FIRST_CARD)
				scene.call("_on_card_hover_started", NEXT_CARD)
			if case == "reenter":
				scene.call("_on_card_hover_ended", FIRST_CARD)
				scene.call("_on_card_hover_started", FIRST_CARD)
			if case == "repeat_enter": scene.call("_on_card_hover_started", FIRST_CARD)
			frames.append(await _boundary(probe, scene))
			if probe.capture and case in CAPTURE_CASES: await _capture(probe, case + "_sweep_" + side)
			else: await _render(probe)
			if case in ["sweep", "sweep_exit"]: scene.call("_on_card_hover_ended", NEXT_CARD)
			frames.append(await _boundary(probe, scene))
			await _render(probe)
			frames.append(await _boundary(probe, scene))
			Trace.enabled = false
			if probe.capture and case in CAPTURE_CASES: await _capture(probe, case + "_rest_" + side)
			probe.headless_draw_paused = false
			await probe._settle()
			results[case][side] = {"baseline": baseline, "frames": frames, "final": probe._snapshot(scene).duplicate(true)}
			scene.queue_free()
			await probe._settle()
		var before: Dictionary = results[case]["before"]
		var after: Dictionary = results[case]["after"]
		var before_final: Dictionary = before["final"].duplicate(true)
		var after_final: Dictionary = after["final"].duplicate(true)
		# An exited sweep never constructed a strip. Its hidden retained rows
		# may differ; every visible field and all rested rows remain compared.
		if case in ["sweep", "sweep_exit"]:
			probe._check(not after_final["strip_visible"], case + ": strip clears on exit")
			before_final.erase("strip_roles")
			after_final.erase("strip_roles")
		probe._check(before_final == after_final, case + ": complete final state equals perf-12")
		var delayed: bool = case not in ["key_focus", "controller_focus"]
		if delayed:
			for index: int in range(2):
				var sample: Dictionary = after["frames"][index]
				probe._check(sample["refresh_count"] == 0, case + ": no passed-over stage at boundary " + str(index))
				var expected: Dictionary = _presentation(after["baseline"])
				if case == "rest_then_sweep":
					# pol-41: the rested card's keywords leave as the next card lifts.
					expected["glossary"] = []
					expected["glossary_visible"] = false
				probe._check(_presentation(sample["state"]) == expected, case + ": preview/strip retained, glossary " + ("hidden" if case == "rest_then_sweep" else "retained") + " before rest " + str(index))
				probe._check(sample["state"]["emphasis"] == before["frames"][index]["state"]["emphasis"], case + ": immediate emphasis " + str(index))
			var maturity: int = 3 if case in ["sweep_rest", "reenter"] else 2
			probe._check(after["frames"][maturity]["refresh_count"] == 1, case + ": exactly one refresh at rest/exit")
			if maturity == 3: probe._check(after["frames"][2]["refresh_count"] == 0, case + ": adjacent enter resets render count")
		else:
			probe._check(before["frames"][0]["state"] == after["frames"][0]["state"], case + ": immediate focus preview equals perf-12")
		print("PERF13 REST %s: stage counts %s -> %s" % [case, _counts(before), _counts(after)])
	results["modality_handoff"] = await _modality_handoff(probe)
	return results

static func _modality_handoff(probe: SceneTree) -> Dictionary:
	var scene: Node = probe._scene(probe.candidate)
	probe.root.add_child(scene)
	await probe._settle()
	await Fixture._install(probe, scene, Fixture.fixture(probe._combat_engine))
	var router: Node = probe.root.get_node("InputRouter")
	var old_modality: String = router.call("modality")
	var old_forced_modality: String = router.get("_forced_modality_for_test")
	var old_controller_activity: int = router.get("_last_controller_activity_msec")
	router.set("_forced_modality_for_test", "")
	router.set("_last_controller_activity_msec", QUIET_CONTROLLER_ACTIVITY_MSEC)
	scene.set("_controller_region", "board")
	router.call("set_modality", "controller")
	await probe._settle()
	probe.headless_draw_paused = true
	var small := InputEventMouseMotion.new()
	small.relative = SMALL_POINTER_MOTION
	router.call("record_input_activity", small)
	scene.call("_input", small)
	scene.call("_on_card_hover_started", FIRST_CARD)
	await _boundary(probe, scene)
	probe._check(router.call("modality") == "controller", "handoff: small motion keeps controller modality")
	probe._check(bool(scene.get("_hand_hover_rest_pending")), "handoff: mouse enter has a pending rest")
	var generation: int = scene.get("_hand_hover_rest_generation")
	await _render(probe)
	var motion := InputEventMouseMotion.new()
	motion.relative = HANDOFF_POINTER_MOTION
	router.call("record_input_activity", motion)
	scene.call("_input", motion)
	probe._check(router.call("modality") == "pointer" and int(scene.get("_hovered_card_index")) == -1, "handoff: larger motion clears the hovered card")
	var invalidated: bool = not bool(scene.get("_hand_hover_rest_pending")) and int(scene.get("_hand_hover_rest_generation")) > generation
	probe._check(invalidated, "handoff: ownership clear immediately invalidates the rest")
	for frame: int in range(HANDOFF_DRAWS):
		await _boundary(probe, scene)
		await _render(probe)
	scene.call("_on_card_hover_ended", FIRST_CARD)
	probe._check(not bool(scene.get("_hand_hover_rest_pending")), "handoff: rest stays clear after eight draws and hand exit")
	scene.call("set_runtime_performance_instrumentation_enabled", true)
	Trace.reset()
	Trace.enabled = true
	var combat: Dictionary = scene.get("_combat_state")
	var enemy_tile: Vector2i = combat["enemies"][0]["pos"]
	scene.call("_on_board_tile_hovered", enemy_tile)
	var board: Dictionary = await _boundary(probe, scene)
	probe._check(board["refresh_count"] > 0 and not bool(scene.get("_board_hover_refresh_pending")), "handoff: later board hover presents without discrete input")
	Trace.reset()
	scene.call("_on_card_hover_started", NEXT_CARD)
	await _boundary(probe, scene)
	await _render(probe)
	await _boundary(probe, scene)
	await _render(probe)
	var rested: Dictionary = await _boundary(probe, scene)
	probe._check(rested["refresh_count"] == 1 and not bool(scene.get("_hand_hover_rest_pending")), "handoff: next card previews after its own two draws")
	Trace.enabled = false
	probe.headless_draw_paused = false
	var result: Dictionary = {"invalidated_immediately": invalidated, "draws_after_handoff": HANDOFF_DRAWS, "board_refreshes": board["refresh_count"], "next_card_refreshes": rested["refresh_count"]}
	print("PERF13 REST modality_handoff: " + JSON.stringify(result))
	scene.queue_free()
	await probe._settle()
	router.call("set_modality", old_modality)
	router.set("_forced_modality_for_test", old_forced_modality)
	router.set("_last_controller_activity_msec", old_controller_activity)
	return result

static func _boundary(probe: SceneTree, scene: Node) -> Dictionary:
	probe.observed_scene = scene
	probe.input_frame = Engine.get_process_frames()
	probe.boundary_seen = false
	if probe.capture:
		await RenderingServer.frame_pre_draw
		probe._observe()
	else: probe.call_deferred("_observe")
	while not probe.boundary_seen: await probe.process_frame
	return probe.observed.duplicate(true)

static func _render(probe: SceneTree) -> void:
	if probe.capture: await RenderingServer.frame_post_draw
	else: RenderingServer.frame_post_draw.emit()

static func _capture(probe: SceneTree, name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = probe.output.path_join(name + ".png")
	probe._save_proof_image(probe.root.get_texture().get_image(), path)
	print(path)

static func _presentation(snapshot: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in PRESENTATION_KEYS: result[key] = snapshot[key]
	return result

static func _stage_count() -> int:
	var count: int = 0
	for frame: int in Trace.frames:
		for interval: Dictionary in Trace.frames[frame]:
			if interval["phase"] == "stage_total": count += 1
	return count

static func _counts(result: Dictionary) -> Array:
	var counts: Array = []
	for frame: Dictionary in result["frames"]: counts.append(frame["refresh_count"])
	return counts

extends "res://tools/inspection_fixture.gd"
## Opt-in perf-13 oracle: immediate emphasis/actions and equivalent rested
## presentation. No default-suite budgets/guards.
const Candidate = preload("res://tools/perf11/profiled_scene.gd")
const Fixture = preload("res://tests/suites/turn_clock_hud_suite.gd")
const Trace = preload("res://tests/perf/combat_frame_trace.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const RestProof = preload("res://tools/perf11/hover_rest_cases.gd")
const SIZE := Vector2i(1920, 1080)
const SETTLE_FRAMES: int = 8
const SETTLE_SECONDS: float = 0.22
const DRAG_POINTER := Vector2(960, 900)
const BOARD_TARGET := Vector2i(3, 4)
const PROOF_KEYCODE: int = KEY_SHIFT
const FIRST_CARD_INDEX: int = 0
const NEXT_CARD_INDEX: int = 1
const FIXTURE_COMBAT_ID: String = "perf12_oracle_combat"
const ACTION_TIMEOUT_FRAMES: int = 1200
const CASES: Array = ["enter", "enter_another", "leave", "leave_enter", "enter_board", "enter_locked", "leave_locked", "updating", "movement_guard", "selection_guard", "choice_guard", "drag_guard", "click", "drag", "pass", "key", "tutorial"]
const CAPTURE_CASES: Array = ["enter", "leave_enter", "click", "tutorial"]
const REST_CASES: Array = ["enter", "enter_another", "leave_enter", "enter_board", "updating", "tutorial"]
var reference: Script
var candidate: Script = Candidate
var output: String = ""
var capture: bool = false
var failures: Array[String]
var results: Dictionary = {}
var observed: Dictionary = {}
var observed_scene: Node
var input_frame: int = -1
var boundary_seen: bool = false
var motion_scenes: Array[Node]
var motion_result: Dictionary = {}
var rest_results: Dictionary = {}
var headless_draw_paused: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	if DisplayServer.get_name() == "headless": process_frame.connect(_draw_boundary)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size()):
		if args[index] == "--reference": reference = load(args[index + 1])
		if args[index] == "--candidate": candidate = load(args[index + 1])
		if args[index] == "--output-dir": output = args[index + 1]
		if args[index] == "--capture": capture = true
	call_deferred("_run")

func _run() -> void:
	if reference == null or output.is_empty() or (capture and DisplayServer.get_name() == "headless"):
		push_error("Supply --reference reference_profile.gd and --output-dir; --capture needs a real renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	ProgressionStore.set_storage_path(output.path_join("progression.json"))
	ProgressionStore.set_run_storage_path(output.path_join("run.save"))
	Settings.set_storage_path(output.path_join("settings.json"))
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	root.size = SIZE
	root.content_scale_size = SIZE
	for side: String in ["before", "after"]:
		results[side] = {}
		var scene: Node = _scene(reference if side == "before" else candidate)
		root.add_child(scene)
		await _settle()
		scene.call("set_runtime_performance_instrumentation_enabled", true)
		for case: String in CASES:
			await _case(scene, side, case)
		scene.queue_free()
		await _settle()
	await _motion_probe()
	rest_results = await RestProof.run(self)
	for case: String in CASES:
		var before: Dictionary = results["before"][case]
		var after: Dictionary = results["after"][case]
		if case in REST_CASES:
			for key: String in ["hover", "emphasis", "selected", "drag"]:
				_check(before["state"][key] == after["state"][key], case + ": immediate " + key + " equals original")
			_check(after["refresh_count"] == 0, case + ": no stage refresh before rest")
		else:
			_check(before["state"] == after["state"], case + ": first pre-draw state equals original")
		_check(before["final_state"] == after["final_state"], case + ": settled state equals original")
		_check(after["same_frame"], case + ": flush completed before the input frame drew")
		if case == "leave":
			_check(after["refresh_count"] == 1, case + ": exactly one stage refresh")
		print("PERF13 %s: first-boundary stage refreshes %d -> %d; same frame %s" % [case, before["refresh_count"], after["refresh_count"], after["same_frame"]])
	var file := FileAccess.open(output.path_join("hover_equivalence.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"results": results, "failures": failures, "capture": capture, "motion": motion_result, "rest": rest_results}, "\t").replace(String.chr(31), "\\u001f"))
	file.close()
	for failure: String in failures: push_error(failure)
	print("PERF13 HOVER EQUIVALENCE: %s (%d original cases; %d rest cases; %d failures; native %s)" % ["PASS" if failures.is_empty() else "FAIL", CASES.size(), rest_results.size(), failures.size(), capture])
	quit(0 if failures.is_empty() else 1)

func _motion_probe() -> void:
	var views: Array[SubViewport]
	for script: Script in [reference, candidate]:
		var view := SubViewport.new()
		view.size = SIZE
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		views.append(view)
		var scene: Node = _scene(script)
		view.add_child(scene)
		motion_scenes.append(scene)
		await _settle()
		await Fixture._install(self, scene, Fixture.fixture(_combat_engine))
	# Inject before process/tweens, as native input does. Both clocks receive
	# the same engine delta; compare their very first visible progression.
	await physics_frame
	boundary_seen = false
	input_frame = Engine.get_process_frames()
	if capture: RenderingServer.frame_pre_draw.connect(_observe_motion, CONNECT_ONE_SHOT)
	for scene: Node in motion_scenes: scene.call("_on_card_hover_started", FIRST_CARD_INDEX)
	if not capture: call_deferred("_headless_motion_boundary")
	while not boundary_seen: await process_frame
	if capture:
		await RenderingServer.frame_post_draw
		for index: int in range(views.size()):
			var path: String = output.path_join("motion_" + ("before" if index == 0 else "after") + ".png")
			_save_proof_image(views[index].get_texture().get_image(), path)
			print(path)
	for view: SubViewport in views: view.queue_free()
	motion_scenes.clear()
	await _settle()

func _headless_motion_boundary() -> void:
	await process_frame
	call_deferred("_observe_motion")

func _observe_motion() -> void:
	var samples: Array[Dictionary]
	for scene: Node in motion_scenes:
		samples.append({"emphasis_strength": (scene.get("hand_box") as Node).call("emphasis_strength"), "strip_alpha": (scene.get("_turn_order_landing_strip") as Control).modulate.a})
	motion_result = {"before": samples[0], "after": samples[1], "input_frame": input_frame, "boundary_frame": Engine.get_process_frames()}
	_check(Engine.get_process_frames() <= input_frame + 1, "motion: observed before the next draw")
	_check(is_equal_approx(samples[0]["emphasis_strength"], samples[1]["emphasis_strength"]), "motion: first-draw emphasis clock equals original")
	print("PERF13 FIRST DRAW MOTION: " + JSON.stringify(motion_result))
	boundary_seen = true

func _scene(script: Script) -> Node:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var bundle: Dictionary = packed._bundled.duplicate(true)
	var variants: Array = bundle["variants"]
	for index: int in range(variants.size()):
		if variants[index] is Script and variants[index].resource_path == "res://scripts/run_scene.gd": variants[index] = script
	bundle["variants"] = variants
	var replaced := PackedScene.new()
	replaced._bundled = bundle
	return replaced.instantiate()

func _case(scene: Node, side: String, case: String) -> void:
	await Fixture._install(self, scene, Fixture.fixture(_combat_engine))
	if case == "tutorial":
		_options = {"scenario": "guided_tutorial", "seed": DEFAULT_SEED, "hero_facing": "persist"}
		var run: Dictionary = _build_run_state("guided_tutorial", _build_progression())
		scene.call("_load_run_state", run)
		scene.set("_animation_lock", false)
		scene.call("_refresh_ui")
		await _settle()
		_check(scene.call("_guided_tutorial_is_active"), "authored tutorial actually active")
	# Analytics IDs are assigned from wall time on load. Pin only this fixture
	# identity before rebuilding either scene's caches; production is untouched.
	var combat: Dictionary = scene.get("_combat_state")
	combat["analytics"]["combat_id"] = FIXTURE_COMBAT_ID
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
	await _settle()
	if case in ["enter_another", "leave", "leave_enter", "leave_locked"]:
		scene.call("_on_card_hover_started", FIRST_CARD_INDEX)
		await _settle()
	if case in ["enter_locked", "leave_locked"]: scene.set("_animation_lock", true)
	if case == "movement_guard": scene.set("_player_movement_selected", true)
	if case == "selection_guard": scene.set("_selected_card_index", 0)
	if case == "choice_guard": scene.set("_card_action_choice_index", 0)
	if case == "drag_guard": scene.set("_drag_card_index", 0)
	Trace.reset()
	Trace.enabled = true
	input_frame = Engine.get_process_frames()
	boundary_seen = false
	observed_scene = scene
	# Headless has no draw signal. Its deferred sentinel observes the identical
	# message-queue boundary, without calling the candidate flush explicitly.
	if capture: RenderingServer.frame_pre_draw.connect(_observe, CONNECT_ONE_SHOT)
	if case == "updating": scene.set("_updating_hand_interactions", true)
	if case in ["leave", "leave_enter", "leave_locked"]: scene.call("_on_card_hover_ended", FIRST_CARD_INDEX)
	if case not in ["leave", "leave_locked"]: scene.call("_on_card_hover_started", NEXT_CARD_INDEX if case in ["enter_another", "leave_enter", "updating"] else FIRST_CARD_INDEX)
	if case == "enter_board": scene.call("_on_board_tile_hovered", BOARD_TARGET)
	if case == "updating":
		scene.set("_updating_hand_interactions", false)
		scene.call("_update_existing_hand_interaction_state")
	# Discrete actions must flush the final owner of a sweep, including a
	# leave/enter pair delivered in the very same input frame.
	if case in ["click", "drag", "pass", "key"]:
		scene.call("_on_card_hover_ended", FIRST_CARD_INDEX)
		scene.call("_on_card_hover_started", NEXT_CARD_INDEX)
	if case == "click": scene.call("_on_card_pressed", NEXT_CARD_INDEX)
	if case == "drag": scene.call("_on_card_drag_started", NEXT_CARD_INDEX, DRAG_POINTER)
	if case == "pass": scene.call("_on_pass_turn_pressed")
	if case == "key":
		var key := InputEventKey.new()
		key.keycode = PROOF_KEYCODE
		key.pressed = true
		scene.call("_input", key)
	if not capture: call_deferred("_observe")
	while not boundary_seen: await process_frame
	Trace.enabled = false
	results[side][case] = observed.duplicate(true)
	if capture and case in CAPTURE_CASES:
		await RenderingServer.frame_post_draw
		var path: String = output.path_join(case + "_" + side + ".png")
		_save_proof_image(root.get_texture().get_image(), path)
		print(path)
	# Allow real Pass to finish; its rules/analytics/save paths remain intact.
	if case == "pass":
		var waited: int = 0
		while bool(scene.get("_animation_lock")) and waited < ACTION_TIMEOUT_FRAMES:
			await process_frame
			waited += 1
		_check(waited < ACTION_TIMEOUT_FRAMES, "Pass completes")
	if case in ["enter_locked", "leave_locked"]: scene.set("_animation_lock", false)
	await _settle()
	results[side][case]["final_state"] = _snapshot(scene).duplicate(true)

func _observe() -> void:
	var count: int = 0
	var per_frame: Dictionary = {}
	for frame: int in Trace.frames:
		var frame_count: int = 0
		for interval: Dictionary in Trace.frames[frame]:
			if interval["phase"] == "stage_total": frame_count += 1
		per_frame[str(frame)] = frame_count
		count += frame_count
	observed = {"emphasis_strength": (observed_scene.get("hand_box") as Node).call("emphasis_strength"), "strip_alpha": (observed_scene.get("_turn_order_landing_strip") as Control).modulate.a, "state": _snapshot(observed_scene), "input_frame": input_frame, "boundary_frame": Engine.get_process_frames(), "same_frame": input_frame == Engine.get_process_frames(), "refresh_count": count, "refresh_counts_per_frame": per_frame}
	boundary_seen = true

func _save_proof_image(image: Image, path: String) -> void:
	# Preserve the oracle's root viewport and draw boundaries; only normalize
	# proof readback when macOS returns Retina backing pixels.
	if image.get_size() != SIZE:
		image.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
	_check(image.get_size() == SIZE, "Capture must be 1920x1080")
	_check(image.save_png(path) == OK, "save " + path)

func _snapshot(scene: Node) -> Dictionary:
	var board: Node = scene.get("board_view")
	var hand: Node = scene.get("hand_box")
	var stack: Node = scene.get("_card_focus_tooltip_stack")
	var strip: Node = scene.get("_turn_order_landing_strip")
	var prompt: Node = scene.get("_contextual_combat_prompt")
	return {"hover": scene.get("_hovered_card_index"), "emphasis": hand.get("_emphasized_index"), "preview": scene.call("_active_card_preview"), "preview_state": scene.get("_preview_combat_state"), "board_state": board.get("combat_state"), "board_presentation": board.get("presentation"), "move_tiles": board.get("move_tiles"), "attack_tiles": board.get("attack_tiles"), "glossary": stack.get("_entries"), "glossary_visible": stack.get("visible"), "strip_roles": strip.call("role_entries"), "strip_visible": strip.get("visible"), "strip_order": scene.get("_turn_order_all_entries"), "tutorial_phase": scene.get("_guided_tutorial_phase_id"), "tutorial_definition": prompt.get("_definition") if prompt != null else {}, "selected": scene.get("_selected_card_index"), "drag": scene.get("_drag_card_index")}

func _draw_boundary() -> void:
	if not headless_draw_paused: RenderingServer.frame_post_draw.emit()

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame
	await create_timer(SETTLE_SECONDS).timeout
	await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

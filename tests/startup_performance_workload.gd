extends RefCounted

const ProgressionStore = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SEED: int = 84217
var _probe: SceneTree
var _started_usec: int
var _phase_changes: Array[Dictionary]
var _destination: Node
var _transition_profile: Dictionary

func run(probe: SceneTree, sampler: Node) -> Dictionary:
	_probe = probe
	var mode: String = OS.get_environment("LABYRINTH_RUNTIME_PERF_STARTUP_MODE")
	mode = "continue" if mode == "continue" else "new"
	var progression: Dictionary = Tutorial.complete_tutorial(ProgressionStore.default_data())
	_check(ProgressionStore.save_data(progression), "Private startup profile must save")
	var engine := RunEngine.new()
	var expected: Dictionary = engine.create_new_run(SEED, progression)
	if mode == "continue":
		_check(ProgressionStore.save_run_state(expected), "Continue fixture must save")
	else:
		ProgressionStore.clear_saved_run()
	probe.root.set_meta("labyrinth_performance_probe_seed", SEED)
	await probe.call("_settle_render_frames", 3)
	sampler.call("begin")
	var boot_started: int = Time.get_ticks_usec()
	var packed: PackedScene = load("res://scenes/main_menu.tscn")
	var menu: Control = packed.instantiate() as Control
	probe.root.add_child(menu)
	probe.current_scene = menu
	await probe.call("_settle_render_frames", 12)
	var menu_boot: Dictionary = probe.call("_sampler_phase_result", sampler.call("finish"))
	menu_boot["completion_ms"] = float(Time.get_ticks_usec() - boot_started) / 1000.0
	await probe.call("_save_root_screenshot", "startup_%s_menu.png" % mode)
	await probe.call("_settle_render_frames", 3)
	sampler.call("begin")
	_started_usec = Time.get_ticks_usec()
	var button: Button = menu.get_node("MenuColumn/ContinueButton" if mode == "continue" else "MenuColumn/StartButton") as Button
	_check(button.is_visible_in_tree() and not button.disabled, "Startup must expose enabled public " + mode + " button")
	var handler_ms: float = probe.call("_routed_left_click", button, button.size * 0.5)
	var transition: Node = probe.root.get_node_or_null("MenuRunTransition")
	_check(transition != null, "Public startup must create the loading transition")
	if transition == null: return {}
	_phase_changes.append({"phase": "loading", "at_ms": float(Time.get_ticks_usec() - _started_usec) / 1000.0})
	transition.connect("phase_changed", _phase_changed)
	transition.connect("finished", func(destination: Node) -> void:
		_destination = destination
		_transition_profile = transition.call("performance_snapshot")
	)
	_check(probe.root.gui_disable_input, "Loading must lock ordinary GUI input")
	var frames: int = 0
	while _destination == null and frames < 1800:
		await probe.call("_await_render_frame")
		frames += 1
	_check(_destination != null, "Startup must finish before its deadlock guard")
	await probe.call("_await_render_frame")
	var start: Dictionary = probe.call("_sampler_phase_result", sampler.call("finish"))
	start["handler_ms"] = handler_ms
	start["completion_ms"] = float(Time.get_ticks_usec() - _started_usec) / 1000.0
	start["phase_changes"] = _phase_changes
	start["transition_profile"] = _transition_profile
	if _destination != null:
		_check(probe.current_scene == _destination, "Startup must commit the run as current scene")
		_check(not probe.root.gui_disable_input, "Ready run must restore GUI input")
		_check(bool(_destination.call("initial_presentation_is_ready")), "Loading reveal must wait for presentation readiness")
		var actual: Dictionary = _destination.get("_run_state") as Dictionary
		var semantics: Dictionary = {}
		for field: String in ["seed", "current_room", "mode", "equipped_equipment", "attuned_magic_cards", "held_embers", "player_hp", "player_max_hp"]:
			_check(actual.get(field) == expected.get(field), "Startup state must match deterministic run oracle: " + field)
			semantics[field] = actual.get(field)
		start["semantics"] = semantics
		var board: Node = _destination.get("board_view")
		var board_startup: Dictionary = {"main": board.get("_startup_performance_timings")}
		for layer: Node in board.call("_retained_render_layers"):
			board_startup[str(layer.name)] = layer.get("_startup_performance_timings")
		start["board_startup_profile"] = board_startup
		start["stage_profile"] = _destination.call("runtime_performance_instrumentation_snapshot")
		start["stage_frame_profile"] = _destination.call("runtime_performance_frame_instrumentation_snapshot")
		_check(not ProgressionStore.load_saved_run().is_empty(), "Startup must persist its run")
		await probe.call("_settle_render_frames", 3)
		_destination.call("set_runtime_performance_instrumentation_enabled", true)
		board.call("set_submission_performance_instrumentation_enabled", true)
		board.call("reset_render_instrumentation")
		sampler.call("begin")
		await probe.call("_settle_render_frames", 90)
		start["ready_idle"] = probe.call("_sampler_phase_result", sampler.call("finish"))
		start["ready_idle_stage_profile"] = _destination.call("runtime_performance_instrumentation_snapshot")
		start["ready_idle_frame_profile"] = _destination.call("runtime_performance_frame_instrumentation_snapshot")
		start["ready_idle_board_profile"] = board.call("render_instrumentation_snapshot")
		start["ready_idle_board_submission"] = board.call("submission_performance_instrumentation_snapshot")
		await probe.call("_save_root_screenshot", "startup_%s_ready.png" % mode)
	return {"schema_version": 1, "workload_id": "cold_process_public_menu_%s_v1" % mode, "viewport": "1920x1080", "ui_scale": 1.0, "cpu_profile": OS.get_environment("LABYRINTH_PERF_CPU_PROFILE"), "renderer": RenderingServer.get_video_adapter_name(), "sample_boundary": "RenderingServer.frame_post_draw", "menu_boot": menu_boot, "run_start": start, "static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)), "orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), "focus_observations": probe.get("_focus_observation_count"), "unfocused_observations": probe.get("_unfocused_observation_count")}

func _phase_changed(phase: StringName) -> void:
	_phase_changes.append({"phase": str(phase), "at_ms": float(Time.get_ticks_usec() - _started_usec) / 1000.0})
	if phase == &"revealing":
		var transition: Node = _probe.root.get_node_or_null("MenuRunTransition")
		var destination: Node = transition.get("destination") if transition != null else null
		_check(destination != null and bool(destination.call("initial_presentation_is_ready")), "Reveal phase must have a ready destination")

func _check(condition: bool, message: String) -> void:
	_probe.call("_expect", condition, message)

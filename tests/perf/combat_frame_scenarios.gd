extends SceneTree

# Full iterations, including actual queued CanvasItem draws and deferred layout.
# Headless measures CPU submission only. Native samples end at post_draw; neither
# TIME_PROCESS (a rolling peak) nor authored animation duration is a frame sample.
const Fixture = preload("res://tools/warband_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Data = preload("res://scripts/game_data.gd")
const Trace = preload("res://tests/perf/combat_frame_trace.gd")
const Partition = preload("res://scripts/performance_phase_partitioner.gd")
const ProfiledScene = preload("res://tests/perf/profiled_run_scene.gd")
const ProfiledBoard = preload("res://tests/perf/profiled_combat_board.gd")
const PROOF_SIZE := Vector2i(1920, 1080)
const SETTLE_SECONDS: float = 1.5
const IDLE_SECONDS: float = 4.0
const SWEEP_SECONDS: float = 6.0
const ACTION_TIMEOUT_SECONDS: float = 12.0
const IDLE_TAIL_SECONDS: float = 0.5
const TRAP_DAMAGE: int = 8
const PLAYER_TILE := Vector2i(2, 4)
const TARGET_TILE := Vector2i(4, 4)
const TRAP_TILE := Vector2i(5, 4)
const WALL_TILE := Vector2i(6, 4)
const LETHAL_HP: int = 12
const SURVIVING_HP: int = 40
const NO_ENEMY_TURN_TIME: int = 1000
const SAMPLE_FRAME_CAP: int = 0
const SAMPLER_DURATION_SECONDS: int = 5
const SAMPLER_INTERVAL_MS: int = 1
const SAMPLER_TIMEOUT_MS: int = 10000
const ORDINARY_HOVER_MAX_MS: float = 5.0
const WARBAND_HOVER_MAX_MS: float = 8.0
const HOVER_P95_MS: float = 10.0
const TRAP_MAX_MS: float = 19.5
const PIPELINE_MONITORS: Array = [Performance.PIPELINE_COMPILATIONS_CANVAS, Performance.PIPELINE_COMPILATIONS_MESH, Performance.PIPELINE_COMPILATIONS_SURFACE, Performance.PIPELINE_COMPILATIONS_DRAW, Performance.PIPELINE_COMPILATIONS_SPECIALIZATION]
var output: String = "res://output/perf-03/before.json"
var scenario: String = "all"
var case_filter: String = ""
var passes: int = 3
var enforce_budgets: bool = false
var captures: bool = false
var equivalence_only: bool = false
var reference: bool = false
var sample_stacks: bool = false
var failures: Array[String]
var budget_failures: Array[String]
var _native: bool = false
var _pulse: Control
var _samples: Array[Dictionary]
var _previous_boundary: int = 0
var _sampling: bool = false
var _last_pipelines: int = 0
var _sampler_pid: int = -1
var _checkpoint_comparisons: int = 0

class FramePulse extends Control:
	func _process(_delta: float) -> void:
		Trace.mark("process_end")
	func _draw() -> void:
		draw_rect(Rect2(-2, -2, 1, 1), Color.BLACK)

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--scenario="): scenario = arg.trim_prefix("--scenario=")
		if arg.begins_with("--case="): case_filter = arg.trim_prefix("--case=")
		if arg.begins_with("--passes="): passes = int(arg.trim_prefix("--passes="))
		if arg == "--enforce-budgets": enforce_budgets = true
		if arg == "--captures": captures = true
		if arg == "--equivalence-only": equivalence_only = true
		if arg == "--reference": reference = true
		if arg == "--sample-stacks": sample_stacks = true
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	_native = DisplayServer.get_name() != "headless"
	Engine.max_fps = SAMPLE_FRAME_CAP
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 0
	Settings.set_storage_path("user://perf-03-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	Settings.save_settings(settings)
	root.size = PROOF_SIZE
	root.content_scale_size = PROOF_SIZE
	if _native:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(PROOF_SIZE)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		DisplayServer.window_move_to_foreground()
		RenderingServer.frame_post_draw.connect(_boundary)
	else:
		process_frame.connect(_boundary)
	process_frame.connect(_mark_process_start)
	RenderingServer.frame_pre_draw.connect(_mark_pre_draw)
	RenderingServer.frame_post_draw.connect(_mark_post_draw)
	_pulse = FramePulse.new()
	_pulse.process_priority = 10000
	_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_pulse)
	var report: Dictionary = {"schema_version": 1, "reference_base": reference, "headless_cpu_only": not _native, "untimed_capture_run": captures, "viewport": PROOF_SIZE, "ui_scale": 1.0, "frame_cap": SAMPLE_FRAME_CAP,
		"environment": {"cpu": OS.get_processor_name(), "os": OS.get_name(), "godot": Engine.get_version_info()["string"], "display": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method()},
		"cases": [], "defaults": {"settle_seconds": SETTLE_SECONDS, "idle_seconds": IDLE_SECONDS, "sweep_seconds": SWEEP_SECONDS, "action_timeout_seconds": ACTION_TIMEOUT_SECONDS, "idle_tail_seconds": IDLE_TAIL_SECONDS}}
	await preload("res://tests/perf/combat_frame_equivalence.gd").run(self, _expect)
	await preload("res://tests/perf/hover_equivalence.gd").run(self, _expect)
	if equivalence_only: passes = 0
	_expect(scenario in ["all", "A", "B"], "Known scenario")
	for pass_index: int in range(passes):
		if scenario in ["all", "A"]:
			for case: Dictionary in [{"name": "ordinary"}, {"name": "air_t2", "biome": "air", "tier": 2}, {"name": "lightning_t3", "biome": "lightning", "tier": 3}]:
				if not case_filter.is_empty() and case_filter != case["name"]: continue
				report["cases"].append(await _hover(case, pass_index))
		if scenario in ["all", "B"]:
			for variant: String in ["lightning_kill", "fire_kill", "lightning_survive"]:
				if not case_filter.is_empty() and case_filter != variant: continue
				report["cases"].append(await _trap(variant, pass_index))
	_check_budgets(report)
	_pulse.queue_free()
	var sampler_deadline: int = Time.get_ticks_msec() + SAMPLER_TIMEOUT_MS
	while _sampler_pid > 0 and OS.is_process_running(_sampler_pid) and Time.get_ticks_msec() < sampler_deadline: await process_frame
	if _sampler_pid > 0 and OS.is_process_running(_sampler_pid): OS.kill(_sampler_pid)
	await process_frame
	report["resources_end"] = _resources()
	if int(report["resources_end"]["orphan_nodes"]) > 0: Node.print_orphan_nodes()
	_expect(int(report["resources_end"]["orphan_nodes"]) == 0, "No orphan nodes")
	report["failures"] = failures
	report["budget_failures"] = budget_failures
	report["budgets_enforced"] = enforce_budgets
	_expect(equivalence_only or not (report["cases"] as Array).is_empty(), "At least one measured scenario")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	for failure: String in failures: push_error(failure)
	print("PERF03 FRAME RESULT: %s (%d failures) report=%s" % ["PASS" if failures.is_empty() else "FAIL", failures.size(), output])
	print("PERF03 BUDGET RESULT: %s (%d misses)" % ["PASS" if budget_failures.is_empty() else "FAIL", budget_failures.size()])
	print("PERF03 CHECKPOINT OWNERSHIP: %d identical copied/direct inputs; caller mutation isolated" % _checkpoint_comparisons)
	RenderingServer.frame_pre_draw.disconnect(_mark_pre_draw)
	RenderingServer.frame_post_draw.disconnect(_mark_post_draw)
	quit(0 if failures.is_empty() else 1)

func _mark_process_start() -> void: Trace.mark("process_start")
func _mark_pre_draw() -> void: Trace.mark("pre_draw")
func _mark_post_draw() -> void: Trace.mark("post_draw")

func _state(case: Dictionary) -> Dictionary:
	var engine := Run.new()
	var combat := Combat.new()
	var state: Dictionary = engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data())
	if case.has("biome"): return Fixture.build(engine, combat, state, {"warband_biome": case["biome"], "warband_tier": case["tier"]})
	return engine.move_to_room(state, engine.available_moves(state)[0])

func _scene(state: Dictionary) -> Node:
	# Substitute before instantiation: set_script on a live instance abandons
	# Node-valued member initializers from its first script (an artificial leak).
	var packed: PackedScene = load("res://scenes/run_scene.tscn").duplicate()
	var bundled: Dictionary = packed.get("_bundled").duplicate(true)
	var variants: Array = bundled["variants"]
	for index: int in range(variants.size()):
		if variants[index] is Script:
			if variants[index].resource_path == "res://scripts/run_scene.gd": variants[index] = ProfiledScene
			if variants[index].resource_path == "res://scripts/combat_board_view.gd": variants[index] = preload("res://tests/perf/visual_rects_reference.gd") if reference else ProfiledBoard
	packed.set("_bundled", bundled)
	var scene: Node = packed.instantiate()
	scene.set("_combat_engine", preload("res://tests/perf/profiled_combat_engine.gd").new())
	scene.set("reference_checkpoint_copy", reference)
	root.add_child(scene)
	await process_frame
	scene.call("_load_run_state", state)
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	await create_timer(SETTLE_SECONDS).timeout
	_observe_controls(scene)
	return scene

func _observe_controls(node: Node) -> void:
	if node.has_meta("perf03_observed"): return
	node.set_meta("perf03_observed", true)
	if node is Control:
		node.minimum_size_changed.connect(Trace.event.bind("minimum_size_changed"))
		node.resized.connect(Trace.event.bind("resized"))
	node.child_entered_tree.connect(_observe_child)
	for child: Node in node.get_children(): _observe_controls(child)

func _observe_child(child: Node) -> void:
	Trace.event("node_entered")
	Trace.event("entered:" + str(child.get_parent().name) + "/" + child.get_class())
	_observe_controls(child)

func _begin(scene: Node) -> void:
	scene.call("set_runtime_performance_instrumentation_enabled", true)
	scene.get("board_view").call("set_submission_performance_instrumentation_enabled", true)
	scene.get("board_view").call("reset_render_instrumentation")
	Trace.reset()
	Trace.enabled = true
	_samples.clear()
	_previous_boundary = Time.get_ticks_usec()
	_last_pipelines = _pipelines()
	_sampling = true

func _boundary() -> void:
	if not _sampling: return
	var now: int = Time.get_ticks_usec()
	var pipelines: int = _pipelines()
	_samples.append({"frame_id": Engine.get_process_frames() if _native else Engine.get_process_frames() - 1, "start_usec": _previous_boundary, "end_usec": now,
		"frame_ms": float(now - _previous_boundary) / 1000.0, "monitor_process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"focused": not _native or DisplayServer.window_is_focused(), "memory": Performance.get_monitor(Performance.MEMORY_STATIC), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"pipelines": pipelines - _last_pipelines, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	_last_pipelines = pipelines
	_previous_boundary = now

func _pipelines() -> int:
	var count: int = 0
	for monitor: int in PIPELINE_MONITORS: count += int(Performance.get_monitor(monitor))
	return count

func _end(scene: Node, name: String, pass_index: int, max_ms: float, p95_ms: float) -> Dictionary:
	_sampling = false
	Trace.enabled = false
	var frame_times: Array[float]
	var uncovered: Array[float]
	var focus_lost: bool = false
	for sample: Dictionary in _samples:
		var id: int = sample["frame_id"]
		var partition: Dictionary = Partition.partition(Trace.frames.get(id, []), sample["start_usec"], sample["end_usec"])
		sample["exclusive_phase_usec"] = partition["phase_usec"]
		var inclusive: Dictionary = {}
		for interval: Dictionary in Trace.frames.get(id, []):
			var elapsed: int = maxi(0, mini(interval["end_usec"], sample["end_usec"]) - maxi(interval["start_usec"], sample["start_usec"]))
			inclusive[interval["phase"]] = int(inclusive.get(interval["phase"], 0)) + elapsed
		sample["inclusive_phase_usec"] = inclusive
		sample["covered_ms"] = float(partition["total_usec"]) / 1000.0
		sample["uncovered_ms"] = maxf(0.0, sample["frame_ms"] - sample["covered_ms"])
		sample["events"] = Trace.events.get(id, {})
		sample["lifecycle_usec"] = Trace.marks.get(id, {})
		frame_times.append(sample["frame_ms"])
		uncovered.append(sample["uncovered_ms"])
		focus_lost = focus_lost or not bool(sample["focused"])
	_expect(not focus_lost, "Native window stays focused")
	var stats: Dictionary = _stats(frame_times)
	_expect(not frame_times.is_empty(), "Completed real frames: " + name)
	var worst: Array[Dictionary] = _samples.duplicate()
	worst.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["frame_ms"] > b["frame_ms"])
	worst.resize(mini(10, worst.size()))
	var result: Dictionary = {"case": name, "pass": pass_index, "frame_ms": stats, "uncovered_ms": _stats(uncovered), "samples": _samples.duplicate(true), "worst": worst,
		"render": scene.get("board_view").call("render_instrumentation_snapshot"), "script": scene.call("runtime_performance_instrumentation_snapshot"), "resources": _resources(), "fixture": {"rooms": (scene.get("_run_state").get("rooms", {}) as Dictionary).size(), "map_revision": scene.get("_run_state").get("section_map_layout_revision", 0), "tiles": scene.get("board_view").call("_rendered_tiles_in_draw_order").size()}, "budget_max_ms": max_ms, "budget_p95_ms": p95_ms}
	print("PERF03 FRAME %s pass=%d max=%.3f p95=%.3f median=%.3f frames=%d" % [name, pass_index, stats["max"], stats["p95"], stats["median"], stats["count"]])
	scene.call("set_runtime_performance_instrumentation_enabled", false)
	return result

func _check_budgets(report: Dictionary) -> void:
	if captures:
		report["budget_rule"] = "untimed capture proof; run timing acceptance separately"
		report["budgets"] = {}
		return
	var grouped: Dictionary = {}
	for result: Dictionary in report["cases"]:
		var name: String = result["case"]
		if not grouped.has(name): grouped[name] = []
		grouped[name].append(result)
	report["budget_rule"] = "minimum of three per-run maxima; p95 from that same selected run"
	report["budgets"] = {}
	for name: String in grouped:
		var runs: Array = grouped[name]
		var best: Dictionary = runs[0]
		for result: Dictionary in runs:
			if float(result["frame_ms"]["max"]) < float(best["frame_ms"]["max"]): best = result
		var ok: bool = runs.size() == 3 and float(best["frame_ms"]["max"]) <= float(best["budget_max_ms"]) and float(best["frame_ms"]["p95"]) <= float(best["budget_p95_ms"])
		report["budgets"][name] = {"selected_pass": best["pass"], "frame_ms": best["frame_ms"], "passed": ok}
		if not ok:
			budget_failures.append("%s runs=%d min-max=%.3f p95=%.3f" % [name, runs.size(), best["frame_ms"]["max"], best["frame_ms"]["p95"]])
			if enforce_budgets: _expect(false, "Three-run frame budget " + name)

func _hover(case: Dictionary, pass_index: int) -> Dictionary:
	var scene: Node = await _scene(_state(case))
	var board: Control = scene.get("board_view")
	await create_timer(IDLE_SECONDS).timeout
	var rect: Rect2 = board.get_global_rect()
	var prepared_path_inputs: Array = []
	for entry: Dictionary in board.get("_path_draw_cache").get("_paths").values():
		prepared_path_inputs.append(entry["inputs"].duplicate(true))
	var prepared_hud_sources: Array = []
	for entry: Dictionary in board.get("_hud_layout_cache_by_signature").values():
		prepared_hud_sources.append(entry["source"].duplicate(true))
	_begin(scene)
	var started: int = Time.get_ticks_usec()
	while Time.get_ticks_usec() - started < int(SWEEP_SECONDS * 1000000.0):
		var t: float = float(Time.get_ticks_usec() - started) / 1000000.0
		_motion(Vector2(rect.position.x + rect.size.x * (0.2 + 0.6 * fmod(t * 0.35, 1.0)), rect.position.y + rect.size.y * (0.3 + 0.4 * (0.5 + 0.5 * sin(t * 2.3)))))
		_pulse.queue_redraw()
		await process_frame
	var result: Dictionary = _end(scene, "hover_" + str(case["name"]), pass_index, ORDINARY_HOVER_MAX_MS if case["name"] == "ordinary" else WARBAND_HOVER_MAX_MS, HOVER_P95_MS)
	result["prepared_path_inputs"] = prepared_path_inputs
	result["prepared_hud_sources"] = prepared_hud_sources
	result["hud_sources_after"] = []
	for entry: Dictionary in board.get("_hud_layout_cache_by_signature").values():
		result["hud_sources_after"].append(entry["source"].duplicate(true))
	_expect(int(result["script"].get("hover_stage_refresh_total", {}).get("count", 0)) > 0, "Sweep refreshes hovered tiles")
	_expect(int(scene.get("_selected_card_index")) == -1, "No selected card during sweep")
	_expect(int(result["render"].get("dynamic_draw_count", 0)) > 0, "Actual board draws")
	if captures and pass_index == 0: await _capture("hover_" + str(case["name"]))
	await _free_scene(scene)
	return result

func _trap(variant: String, pass_index: int) -> Dictionary:
	var state: Dictionary = _state({})
	var battle: Dictionary = state["combat_state"]
	# Fixture only: keep one spare enemy alive to stay in ordinary combat.
	for y: int in range(battle["grid"].size()):
		for x: int in range(battle["grid"][y].size()):
			battle["grid"][y][x] = "wall" if x == 0 or y == 0 or x == battle["grid"][y].size() - 1 or y == battle["grid"].size() - 1 else "stone"
	battle["grid"][WALL_TILE.y][WALL_TILE.x] = "wall"
	battle["player"]["pos"] = PLAYER_TILE
	battle["enemies"] = [{"id": 1, "type": "crawler", "pos": TARGET_TILE, "hp": Data.fixed_point_amount(SURVIVING_HP if variant.ends_with("survive") else LETHAL_HP), "max_hp": Data.fixed_point_amount(SURVIVING_HP), "block": 0, "intent": {}, "next_turn_time": NO_ENEMY_TURN_TIME},
		{"id": 2, "type": "crawler", "pos": Vector2i(2, 6), "hp": Data.fixed_point_amount(SURVIVING_HP), "max_hp": Data.fixed_point_amount(SURVIVING_HP), "block": 0, "intent": {}, "next_turn_time": NO_ENEMY_TURN_TIME}]
	battle["surfaces"] = {}
	battle["surface_events"] = []
	battle["surface_event_sequence"] = 0
	battle["terrain"] = []
	battle["loot"] = []
	battle["traps"] = [{"id": "perf03", "pos": TRAP_TILE, "element": "fire" if variant.begins_with("fire") else "lightning", "damage": Data.fixed_point_amount(TRAP_DAMAGE)}]
	battle["deck"]["hand"] = ["hobnail_drive"]
	battle["active_rites"] = []
	battle["current_actor"] = {"kind": "player", "key": "player"}
	battle["cards_played_this_turn"] = 0
	var replay_state: Dictionary = state.duplicate(true) if captures else {}
	var scene: Node = await _scene(state)
	var live_run: Dictionary = scene.get("_run_state")
	var live_battle: Dictionary = scene.get("_combat_state")
	var owned_before: Dictionary = live_run.duplicate(true)
	var expected_checkpoint: Dictionary = scene.call("_run_state_for_combat_checkpoint", live_run.duplicate(true), live_battle)
	var direct_checkpoint: Dictionary = scene.call("_run_state_for_combat_checkpoint", live_run, live_battle)
	_expect(expected_checkpoint == direct_checkpoint and live_run == owned_before, "Copied/direct checkpoint inputs have identical owned output")
	direct_checkpoint["combat_state"]["player"]["hp"] -= 1
	_expect(live_run == owned_before and direct_checkpoint != expected_checkpoint, "Checkpoint output mutation cannot reach source or another output")
	var resolver := Combat.new()
	var battle_before: Dictionary = live_battle.duplicate(true)
	var old_finish: Dictionary = resolver.finish_player_card(live_battle.duplicate(true), 0)
	var direct_finish: Dictionary = resolver.finish_player_card(live_battle, 0)
	_expect(old_finish == direct_finish and live_battle == battle_before, "Card finish owns its payment copy; retained pre-payment snapshot is unchanged")
	direct_finish["player"]["hp"] -= 1
	_expect(live_battle == battle_before and old_finish != direct_finish, "Payment output cannot mutate the retained pre-payment snapshot")
	_checkpoint_comparisons += 1
	await scene.call("_on_card_pressed", 0)
	_expect(int(scene.get("_selected_card_index")) == 0, "Hobnail Drive selected")
	var board: Control = scene.get("board_view")
	var point: Vector2 = board.get_global_transform() * (board.call("world_position_for_tile", TARGET_TILE) as Vector2)
	_motion(point)
	await process_frame
	if sample_stacks and _sampler_pid < 0:
		var stack_path: String = ProjectSettings.globalize_path(output.get_basename() + "-stacks.txt")
		_sampler_pid = OS.create_process("/usr/bin/sample", PackedStringArray([str(OS.get_process_id()), str(SAMPLER_DURATION_SECONDS), str(SAMPLER_INTERVAL_MS), "-file", stack_path]))
		print("PERF03 STACK SAMPLE: pid=%d file=%s (diagnostic only; sampler changes timings)" % [_sampler_pid, stack_path])
	_begin(scene)
	_click(point)
	var deadline: int = Time.get_ticks_usec() + int(ACTION_TIMEOUT_SECONDS * 1000000.0)
	var idle_since: int = 0
	while Time.get_ticks_usec() < deadline:
		_pulse.queue_redraw()
		await process_frame
		var shown: Dictionary = board.get("presentation")
		var done: bool = not bool(scene.get("_animation_lock")) and int(scene.get("_selected_card_index")) < 0 and (shown.get("effect", {}) as Dictionary).is_empty() and (shown.get("floating_texts", []) as Array).is_empty() and (shown.get("trap_effects", []) as Array).is_empty()
		if done and idle_since == 0: idle_since = Time.get_ticks_usec()
		if not done: idle_since = 0
		if idle_since > 0 and Time.get_ticks_usec() - idle_since >= int(IDLE_TAIL_SECONDS * 1000000.0): break
	_expect(idle_since > 0, "Card commit returns to idle")
	var result: Dictionary = _end(scene, "trap_" + variant, pass_index, TRAP_MAX_MS, TRAP_MAX_MS)
	var final: Dictionary = scene.get("_combat_state")
	var target: Dictionary = final["enemies"][0]
	var events: Array = final.get("surface_events", [])
	var trap_events: int = 0
	var collision_events: int = 0
	var death_events: int = 0
	var wake_tiles: Array = []
	for event: Dictionary in events:
		if str(event.get("kind", "")) == "trap_triggered":
			trap_events += 1
			wake_tiles = event.get("wake_tiles", [])
			_expect(int(event.get("damage", 0)) == Data.fixed_point_amount(TRAP_DAMAGE), "Trap deals exactly 8 damage")
		if str(event.get("kind", "")) == "force_collision": collision_events += 1
	_expect(trap_events == 1, "Exactly one trap event")
	_expect(collision_events == 1, "Exactly one blocked second push collision")
	for event: Dictionary in events:
		if str(event.get("kind", "")) == "force_collision": _expect(int(event.get("damage", 0)) == Data.fixed_point_amount(2), "Collision deals exactly 2")
		if str(event.get("kind", "")) == "actor_death" and str(event.get("actor_key", "")) == "enemy_1":
			death_events += 1
			_expect(str(event.get("source_kind", "")) == "force_collision", "Owner death source is force_collision")
	_expect(death_events == (0 if variant.ends_with("survive") else 1), "Exact collision death count")
	if variant.begins_with("lightning"): _expect(wake_tiles.size() == 3, "Lightning trap creates exactly three neighboring electrified surfaces")
	if variant.ends_with("survive"): _expect(int(target["hp"]) == Data.fixed_point_amount(SURVIVING_HP - 3 - 8 - 2), "Real kick, trap and collision damage total 13")
	result["outcome"] = {"target": target.duplicate(true), "events": events.duplicate(true), "traps": final["traps"], "run_stats": final.get("run_stats", {})}
	_expect(target["pos"] == TRAP_TILE, "Push enters trap")
	_expect((int(target["hp"]) > 0) == variant.ends_with("survive"), "Kick + trap + collision lethality " + variant)
	_expect((final["traps"] as Array).is_empty(), "Trap activated")
	if captures and pass_index == 0: await _capture("trap_" + variant)
	await _free_scene(scene)
	if captures and pass_index == 0: await _capture_trap_replay(replay_state, "trap_" + variant)
	return result

func _capture_trap_replay(state: Dictionary, label: String) -> void:
	# _end has stopped every sampler. Replay public input in a fresh scene so
	# viewport readback cannot stall this or any later gameplay timing sample.
	var scene: Node = await _scene(state)
	await scene.call("_on_card_pressed", 0)
	var board: Control = scene.get("board_view")
	var point: Vector2 = board.get_global_transform() * (board.call("world_position_for_tile", TARGET_TILE) as Vector2)
	_motion(point)
	await process_frame
	_click(point)
	var deadline: int = Time.get_ticks_usec() + int(ACTION_TIMEOUT_SECONDS * 1000000.0)
	var captured: bool = false
	var finished: bool = false
	while Time.get_ticks_usec() < deadline:
		await process_frame
		var shown: Dictionary = board.get("presentation")
		if not captured and not (shown.get("trap_effects", []) as Array).is_empty():
			await _capture(label + "_active")
			captured = true
		if not bool(scene.get("_animation_lock")) and int(scene.get("_selected_card_index")) < 0 and (shown.get("effect", {}) as Dictionary).is_empty() and (shown.get("trap_effects", []) as Array).is_empty() and (shown.get("floating_texts", []) as Array).is_empty():
			finished = true
			break
	_expect(captured and finished, "Untimed replay captures an active trap and completes: " + label)
	await _free_scene(scene)

func _motion(point: Vector2) -> void:
	var started: int = Time.get_ticks_usec()
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)
	Trace.record("pointer_dispatch", started, Time.get_ticks_usec(), -20)

func _click(point: Vector2) -> void:
	var started: int = Time.get_ticks_usec()
	for pressed: bool in [true, false]:
		var dispatch_started: int = Time.get_ticks_usec()
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		Trace.record("input_press" if pressed else "input_release", dispatch_started, Time.get_ticks_usec(), -25)
	Trace.record("input_dispatch", started, Time.get_ticks_usec(), -30)

func _capture(label: String) -> void:
	_expect(_native, "Captures require native renderer")
	if not _native: return
	_pulse.queue_redraw()
	await RenderingServer.frame_post_draw
	var path: String = output.get_base_dir().path_join(label + ".png")
	_expect(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path)) == OK, "Native capture written: " + label)
	print(ProjectSettings.globalize_path(path))

func _free_scene(scene: Node) -> void:
	scene.queue_free()
	for frame: int in range(3): await process_frame

func _resources() -> Dictionary:
	return {"memory": Performance.get_monitor(Performance.MEMORY_STATIC), "objects": Performance.get_monitor(Performance.OBJECT_COUNT), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "orphan_nodes": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)}

func _stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {"count": 0, "max": 0.0, "p95": 0.0, "median": 0.0}
	values.sort()
	var sum: float = 0.0
	var over: Dictionary = {"16.67": 0, "20": 0, "33.33": 0}
	for value: float in values:
		sum += value
		for limit: String in over:
			if value > float(limit): over[limit] += 1
	return {"count": values.size(), "mean": sum / values.size(), "median": values[values.size() / 2], "p95": values[int(values.size() * 0.95)], "p99": values[int(values.size() * 0.99)], "max": values.back(), "over_ms": over}

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

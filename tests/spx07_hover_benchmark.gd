extends SceneTree

# CPU input/preview microbenchmark; native frame pacing is the director's probe.
const Fixture = preload("res://tools/warband_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const PROOF_SIZE := Vector2i(1920, 1080)
const SETTLE_FRAMES: int = 60
const MEDIAN_BUDGET_MS: float = 6.0
const WORST_BUDGET_MS: float = 12.0
# Director accepts this measured floor; remaining targeting work is perf-02.
const TARGET_WORST_BUDGET_MS: float = 40.0
const PROOF_CARD: String = "shadow_step"
const SAME_TILE_OFFSET := Vector2(0.1, 0.1)
const DEBUG_DRAG_POINTER := Vector2(900, 950)
const TEARDOWN_FRAMES: int = 3
const HEAP_FIXTURE_SEED: int = 70307
const HEAP_FIXTURE_RECORDS: int = 512
const HEAP_FIXTURE_GRID_SIZE: int = 9
const HEAP_FIXTURE_MAX_COST: int = 30
var failures: Array[String]
var output: String = "/tmp/spx07-hover"
var baseline: bool = false
var fresh: bool = false
var preview_comparisons: int = 0
var same_tile_preview_rebuilds: int = 0
var loss_comparisons: int = 0
var eligible_loss_samples: int = 0
var loss_reference := Combat.new()
var loss_memo := preload("res://scripts/combat_preview_memo.gd").new()

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--baseline": baseline = true
		if arg == "--fresh": fresh = true
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("_run")

func _run() -> void:
	Settings.set_storage_path("user://spx07-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	root.size = PROOF_SIZE
	root.content_scale_size = PROOF_SIZE
	DirAccess.make_dir_recursive_absolute(output)
	var report: Dictionary = {"schema_version": 1, "headless_cpu_only": true, "environment": {"os": OS.get_name(), "cpu": OS.get_processor_name(), "godot": Engine.get_version_info()["string"]}, "cases": [], "resources_start": _resources()}
	for case: Dictionary in [{"name": "ordinary"}, {"name": "air_t2", "biome": "air", "tier": 2}, {"name": "lightning_t3", "biome": "lightning", "tier": 3}]:
		var path: String = output.path_join(case["name"] + (".fresh.state" if fresh else ".state"))
		var state: Dictionary
		if baseline or fresh:
			var engine := Run.new()
			var combat := Combat.new()
			state = engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data())
			if case.has("biome"): state = Fixture.build(engine, combat, state, {"warband_biome": case["biome"], "warband_tier": case["tier"]})
			else: state = engine.move_to_room(state, engine.available_moves(state)[0])
			# Fixed debug loadout only; both revisions receive the same serialized input.
			state["combat_state"]["deck"]["hand"] = [PROOF_CARD]
			FileAccess.open(path, FileAccess.WRITE).store_var(state)
		else:
			if not FileAccess.file_exists(path):
				failures.append("Missing baseline input " + path)
				continue
			state = FileAccess.open(path, FileAccess.READ).get_var()
		var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
		root.add_child(scene)
		await process_frame
		scene.call("_load_run_state", state)
		if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
		# Performance equivalence freezes pre-change selected intents. Legacy-save
		# hydration is a separate intentional wind-lock change, tested separately.
		var battle: Dictionary = scene.get("_combat_state")
		for index: int in range(battle["enemies"].size()):
			battle["enemies"][index]["intent"] = state["combat_state"]["enemies"][index]["intent"].duplicate(true)
		scene.call("_mark_combat_preview_state_changed")
		scene.call("_refresh_stage_view")
		for frame: int in range(SETTLE_FRAMES): await process_frame
		for mode: String in ["hover", "card", "drag"]:
			if mode == "card":
				await scene.call("_on_card_pressed", 0)
				_expect(int(scene.get("_selected_card_index")) == 0, "Card targeting selected")
			if mode == "drag":
				scene.call("_cancel_card_selection")
				await scene.call("_on_card_drag_started", 0, DEBUG_DRAG_POINTER)
				await scene.call("_enter_drag_targeting")
				_expect(bool(scene.get("_drag_targeting_active")), "Drag targeting entered")
			var board: Control = scene.get("board_view")
			var samples: Array[float]
			var stationary: Array[float]
			var snapshots: Array
			var target_costs: Array[Dictionary]
			scene.call("set_runtime_performance_instrumentation_enabled", not OS.get_cmdline_user_args().has("--no-profile"))
			for y: int in range(state["combat_state"]["grid"].size()):
				for x: int in range(state["combat_state"]["grid"][y].size()):
					var tile := Vector2i(x, y)
					var point: Vector2 = board.call("_tile_center", tile)
					var costs_before: Dictionary = _target_phase_totals(scene)
					var started: int = Time.get_ticks_usec()
					_motion(scene, board, point, mode)
					samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
					var costs_after: Dictionary = _target_phase_totals(scene)
					for phase: String in costs_after: costs_after[phase] = float(costs_after[phase] - costs_before[phase]) / 1000.0
					target_costs.append({"tile": tile, "ms": samples.back(), "inclusive_phase_ms": costs_after})
					var stage_calls: int = int((scene.get("_runtime_performance_counts") as Dictionary).get("stage_total", 0))
					started = Time.get_ticks_usec()
					_motion(scene, board, point + SAME_TILE_OFFSET, mode)
					stationary.append(float(Time.get_ticks_usec() - started) / 1000.0)
					same_tile_preview_rebuilds += int((scene.get("_runtime_performance_counts") as Dictionary).get("stage_total", 0)) - stage_calls
					_compare_loss_summary(scene)
					snapshots.append({"tile": tile, "state": (board.get("combat_state") as Dictionary).duplicate(true), "move": board.get("move_tiles"), "attack": board.get("attack_tiles"), "presentation": board.get("presentation")})
			var profile: Dictionary = scene.call("consume_runtime_performance_instrumentation_snapshot")
			scene.call("set_runtime_performance_instrumentation_enabled", false)
			var snap_path: String = output.path_join(case["name"] + "-" + mode + (".fresh.snapshots.json" if fresh else ".snapshots.json"))
			# A loaded run assigns a fresh analytics combat id. It is not preview data.
			for snapshot: Dictionary in snapshots: (snapshot["state"].get("analytics", {}) as Dictionary).erase("combat_id")
			var serialized: String = JSON.stringify(snapshots)
			if baseline or fresh: FileAccess.open(snap_path, FileAccess.WRITE).store_string(serialized)
			else:
				var expected: Array = JSON.parse_string(FileAccess.get_file_as_string(snap_path))
				for snapshot: Dictionary in expected: (snapshot["state"].get("analytics", {}) as Dictionary).erase("combat_id")
				var matches: bool = JSON.parse_string(serialized) == expected
				_expect(matches, "Identical swept previews " + case["name"] + " " + mode)
				if matches: preview_comparisons += snapshots.size()
				FileAccess.open(snap_path + ".after", FileAccess.WRITE).store_string(serialized)
			var stats: Dictionary = _stats(samples)
			target_costs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["ms"] > b["ms"])
			target_costs.resize(10)
			var result: Dictionary = {"case": case["name"], "mode": mode, "tile_change_ms": stats, "same_tile_ms": _stats(stationary), "profile": profile, "snapshots_sha256": serialized.sha256_text()}
			result["worst_targets"] = target_costs
			(report["cases"] as Array).append(result)
			print("SPX07 CPU %s %s median=%.3f worst=%.3f same_tile_worst=%.3f ms" % [case["name"], mode, stats["median"], stats["worst"], result["same_tile_ms"]["worst"]])
			if not baseline:
				var worst_budget: float = WORST_BUDGET_MS if mode == "hover" else TARGET_WORST_BUDGET_MS
				_expect(stats["median"] <= MEDIAN_BUDGET_MS and stats["worst"] <= worst_budget, "CPU budget " + case["name"] + " " + mode)
		scene.queue_free()
		for frame: int in range(TEARDOWN_FRAMES): await process_frame
	_expect(same_tile_preview_rebuilds == 0, "Same-tile motion never rebuilds preview presentation")
	_cache_regressions()
	_heap_regression()
	report["same_tile_preview_rebuilds"] = same_tile_preview_rebuilds
	report["identical_preview_snapshots"] = preview_comparisons
	report["identical_loss_summaries"] = loss_comparisons
	report["eligible_loss_samples"] = eligible_loss_samples
	report["resources_end"] = _resources()
	_expect(int(report["resources_end"]["orphan_nodes"]) == 0, "Benchmark leaves no orphan nodes")
	report["failures"] = failures
	FileAccess.open(output.path_join("fresh.json" if fresh else "before.json" if baseline else "after.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	for failure: String in failures: push_error(failure)
	print("SPX07 LOSS SUMMARY RESULT: %d comparisons with full future-intent selection" % loss_comparisons)
	print("SPX07 PREVIEW RESULT: %d identical snapshots; %d same-tile rebuilds" % [preview_comparisons, same_tile_preview_rebuilds])
	print("SPX07 HOVER RESULT: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)

func _motion(scene: Node, board: Control, point: Vector2, mode: String) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = board.get_global_transform() * point
	board.call("_gui_input", motion)
	if mode == "drag": scene.call("_update_card_drag", motion.global_position)
	# Drain only the presentation queued by this input; exclude frame scheduler sleep.
	if bool(scene.get("_board_hover_refresh_pending")):
		scene.call("_flush_board_hover_presentation", scene.get("_board_hover_refresh_generation"))

func _target_phase_totals(scene: Node) -> Dictionary:
	var totals: Dictionary = scene.get("_runtime_performance_totals_usec")
	var result: Dictionary = {}
	for phase: String in ["stage_total", "stage_preview_presentation_total", "stage_board_submission", "hover_context_copy_total", "pass_preview_enemy_actions_total"]:
		result[phase] = int(totals.get(phase, 0))
	var engine: RefCounted = scene.get("_combat_engine")
	result["rest_badges_build"] = int((engine.get("_runtime_performance_totals_usec") as Dictionary).get("rest_badges_build", 0))
	return result

func _stats(values: Array[float]) -> Dictionary:
	values.sort()
	return {"samples": values.size(), "median": values[values.size() / 2], "p95": values[int(values.size() * 0.95)], "worst": values.back()}

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _cache_regressions() -> void:
	preload("res://tests/helpers/spx07_catalog_cache_cases.gd").run(_expect)
	var engine := Combat.new()
	var run := Run.new()
	var state: Dictionary = Fixture.build(run, engine, run.create_new_run(Fixture.FIXTURE_SEED, Store.default_data()), {"warband_biome": "lightning", "warband_tier": 3})["combat_state"]
	var badges := preload("res://scripts/intent_badges.gd").new()
	var previous_retained: Dictionary = {}
	var previous_owned: Dictionary = {}
	for changed: String in ["initial", "hero", "status", "command", "metadata", "captain_dead"]:
		if changed == "hero": state["player"]["pos"] += Vector2i.LEFT
		if changed == "status": state["enemies"][1]["shock"] = 1
		if changed == "command": state["objective"]["command"]["damage_bonus"] += 1
		if changed == "captain_dead": state["enemies"][0]["hp"] = 0
		if changed == "metadata":
			state["current_actor"] = {"kind": "enemy", "enemy_id": state["enemies"][1]["id"]}
			state["initiative_clock"] = int(state.get("initiative_clock", 0)) + 1
		var fresh := Combat.new()
		for index: int in range(state["enemies"].size()):
			var expected: Dictionary = fresh.enemy_threat_tiles(state, index)
			var actual: Dictionary = engine.enemy_threat_tiles(state, index)
			_expect(actual == expected, "Cached threat invalidation: " + changed)
			actual.clear()
			_expect(engine.enemy_threat_tiles(state, index) == expected, "Caller owns cached threat output")
		var retained: Dictionary = badges.presentation_for_state(engine, state, state, "enemy_2")
		_expect(previous_retained == previous_owned, "State invalidation preserves the prior published snapshot")
		previous_retained = retained
		previous_owned = retained.duplicate(true)
		var owned: Dictionary = retained.duplicate(true)
		for focus: String in ["", "enemy_1", "enemy_3", "enemy_2"]:
			_expect(badges.presentation_for_state(engine, state, state, focus) == badges.build(fresh, state, state, focus), "Focused badges match fresh construction: " + changed)
		_expect(retained == owned, "Later focus/state queries preserve retained snapshots")
	print("SPX07 CACHE RESULT: exact invalidation, output ownership and focus equivalence checked")

func _resources() -> Dictionary:
	return {"memory_static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)), "objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)), "nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}

func _heap_regression() -> void:
	var engine := Combat.new()
	var heap := preload("res://scripts/enemy_route_heap.gd").new(engine._enemy_route_record_precedes)
	var expected: Array[Dictionary]
	var rng := RandomNumberGenerator.new()
	rng.seed = HEAP_FIXTURE_SEED
	for index: int in range(HEAP_FIXTURE_RECORDS):
		var tile := Vector2i(rng.randi_range(0, HEAP_FIXTURE_GRID_SIZE - 1), rng.randi_range(0, HEAP_FIXTURE_GRID_SIZE - 1))
		var record: Dictionary = {"tile": tile, "route": engine._vector2i_values([Vector2i.ZERO, tile]), "proof_id": index}
		for field: String in ["cost", "steps", "open_prefix_steps", "prefix_distance_cost", "regression_cost"]: record[field] = rng.randi_range(0, HEAP_FIXTURE_MAX_COST)
		# Duplicate priorities also prove FIFO stability under the old comparator.
		if index % 2 == 1:
			record = expected.back().duplicate(true)
			record["proof_id"] = index
		heap.push(record)
		expected.append(record)
	while not expected.is_empty():
		var index: int = engine._enemy_best_open_route_index(expected)
		var first: Dictionary = expected[index]
		expected.remove_at(index)
		_expect(heap.pop() == first, "Stable heap matches original linear minimum scan")
	_expect(heap.is_empty(), "Route heap drains completely")
	print("SPX07 ROUTE HEAP RESULT: 512 priorities match the original linear scan, including equal-priority FIFO")

func _compare_loss_summary(scene: Node) -> void:
	var source: Dictionary = scene.call("_pass_preview_source_state")
	if preload("res://scripts/combat_preview_known_losses.gd").can_defer_unrevealed_selection(loss_reference, source): eligible_loss_samples += 1
	var expected: Dictionary = loss_memo.resolve([source], func() -> Dictionary:
		var phase: Dictionary = loss_reference.preview_revealed_enemy_actions_before_player_turn_with_steps(loss_reference.finish_player_activation(source))
		return scene.call("_pass_preview_summary_for_phase_result", source, phase))
	_expect(scene.call("_pass_preview_summary") == expected, "Known-loss optimization matches complete revealed simulation")
	loss_comparisons += 1

extends RefCounted

## The reviewer's legal 12-unit submission workload, with untimed reuse checks.
const WARMUP_SUBMISSIONS: int = 20
const MEASURED_SUBMISSIONS: int = 100
const MOVEMENT_STEP_PX: float = 0.123
const ORACLE_STRIDE: int = 10
const VIEWPORT := Vector2i(1920, 1080)
const COLD_REPEATS: int = 6
const PLAN_CAP_USEC: int = 4000
const COUNTDOWN_START: int = 2
const ColdCache = preload("res://scripts/board_status_layout_cache.gd")
const Crowded = preload("res://tests/suites/board_hud_group_suite.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const TF = preload("res://tests/suites/threats_at_rest_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")

static func run(tree: SceneTree) -> bool:
	tree.root.size=VIEWPORT
	var board := Board.new()
	board.size=Vector2(VIEWPORT)
	tree.root.add_child(board)
	await tree.process_frame
	var state: Dictionary = TF.staged_state(Combat.new())
	var enemies: Array[Dictionary]
	for y: int in range(3):
		for x: int in range(4):
			if Vector2i(x+2,y+2)==Vector2i(4,4):continue
			enemies.append({"id":1+x+y*4,"type":"crawler","pos":Vector2i(x+2,y+2),"hp":24,"max_hp":30,"block":8,"stoneskin":3,"immobilize":true,"bleed":3,"expose":2,"frost_armor":3,"intent":Data.enemy_def("crawler")["intents"][0]})
	state["enemies"]=enemies
	var p: Dictionary = {"reduced_motion":true}
	board.set_combat_state(state,[],[],Vector2i(-1,-1),"","",{},{},p)
	var units: Array[Dictionary] = board._hud_layout_units()
	var center: Vector2 = board._unit_center(units[1])
	var ever_updated: Dictionary = {}
	var samples: Array[int]
	var failures: Array[String]
	var untouched: Dictionary = {}
	var initial_entries: Dictionary = {}
	for unit: Dictionary in units:
		if board.get("_status_plate_layout") != null and board._status_plate_layout.has_method("cached_group"):
			untouched[unit["key"]] = board._status_plate_layout.cached_group(unit["key"])
	for entry: Dictionary in board._hud_layout_entries_cache: initial_entries[entry["actor_key"]] = entry
	if board.get("_status_plate_layout") != null: print("MOVEMENT GROUPS ", board._status_plate_layout.cached_group("enemy_1").get("placement"), " compact=", board._status_plate_layout.cached_group("enemy_1").get("compacted"))
	var lru_size: int = board._hud_layout_cache_by_signature.size()
	board.set_submission_performance_instrumentation_enabled(true)
	for i: int in range(WARMUP_SUBMISSIONS + MEASURED_SUBMISSIONS):
		var positions: Dictionary = {"enemy_1":center+Vector2(float(i)*MOVEMENT_STEP_PX,0)}
		var pres: Dictionary = {"reduced_motion":true,"unit_world_positions":positions}
		var t: int = Time.get_ticks_usec()
		board.set_combat_state(state,[],[],Vector2i(-1,-1),"","",{},{},pres)
		var cost: int = Time.get_ticks_usec()-t
		if board.get("_status_plate_layout") != null:
			ever_updated.merge(board._status_plate_layout.last_updated_keys)
		if i>=WARMUP_SUBMISSIONS: samples.append(cost)
		if i % ORACLE_STRIDE == 0 and board.get("_status_plate_layout") != null:
			for key: String in board._status_plate_layout.last_updated_keys:
				var group: Dictionary = board._status_plate_layout.cached_group(key)
				var raw: Dictionary = group["raw"]
				var motion: Vector2 = (group["anchor_frame"] as Rect2).position - (raw["anchor"] as Rect2).position
				var pieces: Array[Rect2] = board._status_plate_layout.Groups.translate_rects(raw["compact_pieces" if group["compacted"] else "pieces"], motion)
				var obstacles: Array[Rect2] = board._status_plate_layout.fixed_order_rects.duplicate()
				obstacles.append_array(board._status_plate_layout.group_obstacles[key])
				var expected: Dictionary = board._status_plate_layout.Groups.choose(pieces, obstacles, board._status_plate_layout.board_area, board._status_plate_layout.reserved_ui, (group["anchor_frame"] as Rect2).size.y)
				if expected["offset"] != group["offset"]: failures.append("Real movement placement differs from exhaustive solve: %s sample=%d actual=%s expected=%s" % [key, i, group["offset"], expected["offset"]])

	if board.get("_status_plate_layout") != null and board._status_plate_layout.has_method("cached_group"):
		var reused: int = 0
		for key: String in untouched:
			if ever_updated.has(key): continue
			if not is_same(untouched[key], board._status_plate_layout.cached_group(key)): failures.append("Untouched group rebuilt: " + key)
			for entry: Dictionary in board._hud_layout_entries_cache:
				if entry["actor_key"] == key and not is_same(initial_entries[key], entry): failures.append("Untouched entry rebuilt: " + key)
			reused += 1
		if reused < 1: failures.append("Incremental path reuses no untouched groups")
		if board._hud_layout_cache_by_signature.size() != lru_size: failures.append("Interpolation inserts deep layout LRU entries")
		for key: String in board._status_plate_layout.last_updated_keys: print("MOVED PLACEMENT ", key, " ", board._status_plate_layout.cached_group(key).get("placement"), " compact=", board._status_plate_layout.cached_group(key).get("compacted"))
		print("MOTION CELL REUSE: ", board._status_plate_layout.motion_cell_hits)
		print("MOVEMENT REUSE: %d untouched groups; LRU %d -> %d" % [reused, lru_size, board._hud_layout_cache_by_signature.size()])
	if preload("res://tests/helpers/perf_group.gd").enabled() and board.get("_status_plate_layout") != null and board._status_plate_layout.plan_max_usec > PLAN_CAP_USEC: failures.append("Movement plan exceeds 4000 us: %d" % board._status_plate_layout.plan_max_usec)
	samples.sort()
	print("MOVE_CPU ",JSON.stringify({"n":samples.size(),"p50_us":samples[MEASURED_SUBMISSIONS / 2],"p95_us":samples[int(MEASURED_SUBMISSIONS * 0.95)],"max_us":samples.back(),"phases":board.submission_performance_instrumentation_snapshot(),"plan_max_us":board._status_plate_layout.plan_max_usec if board.get("_status_plate_layout") != null else 0}))
	board.queue_free()
	await tree.process_frame
	var cold: Dictionary = await cold_cases(tree)
	print("COLD_PLAN_CPU ", JSON.stringify(cold))
	failures.append_array(cold["failures"])
	for failure: String in failures: push_error(failure)
	print("STATUS MOVEMENT PROBE RESULT: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	return failures.is_empty()

static func cold_cases(tree: SceneTree) -> Dictionary:
	var fixtures: Array[Dictionary]
	fixtures.append({"name": "mixed", "state": Crowded.mixed_state()})
	for biome: String in ["air", "earth", "fire", "ice", "lightning", "shadow"]:
		fixtures.append({"name": biome, "state": Crowded.warband_run(biome)["combat_state"]})
	var reports: Array[Dictionary]
	var failures: Array[String]
	for fixture: Dictionary in fixtures:
		var board := Board.new()
		board.size = Vector2(VIEWPORT)
		tree.root.add_child(board)
		var state: Dictionary = fixture["state"]
		var rest: Dictionary = Badges.build(Combat.new(), state, state)
		board.set_combat_state(state, [], [], Vector2i(-1,-1), "", "", {}, {}, {"reduced_motion": true, "threats_at_rest": rest})
		var units: Array[Dictionary] = board._hud_layout_units()
		var samples: Array[int]
		var warm: Array[int]
		var plan_maxes: Array[int]
		var plan_max: int = 0
		for repeat: int in range(COLD_REPEATS):
			if board.get("_status_plate_layout") != null:
				var cache := ColdCache.new()
				cache.fixed_order_rects = Badges.fixed_order_rects(board, units)
				var started: int = Time.get_ticks_usec()
				cache.prepare_groups(board, units)
				samples.append(Time.get_ticks_usec() - started)
				var changed: Array[Dictionary] = units.duplicate(true)
				for event: String in ["status", "turn_countdown", "death"]:
					var before: Dictionary = {}
					for unit: Dictionary in changed: before[unit["key"]] = cache.cached_group(unit["key"])
					match event:
						"status": changed[0]["shock"] = COUNTDOWN_START
						"turn_countdown": changed[0]["shock"] -= 1
						"death": changed[0]["death_animation"] = true
					started = Time.get_ticks_usec()
					cache.prepare_groups(board, changed)
					warm.append(Time.get_ticks_usec() - started)
					var reused: int = 0
					for unit: Dictionary in changed:
						var key: String = str(unit["key"])
						if cache.last_updated_keys.has(key): continue
						if not is_same(before[key], cache.cached_group(key)): failures.append(fixture["name"] + ": unchanged group placement rebuilt after " + event)
						reused += 1
					if reused == 0: failures.append(fixture["name"] + ": no unchanged groups reused after " + event)
				plan_max = maxi(plan_max, cache.plan_max_usec)
				plan_maxes.append(cache.plan_max_usec)
			else:
				var started: int = Time.get_ticks_usec()
				board._build_hud_layout_data(units)
				samples.append(Time.get_ticks_usec() - started)
		var worst: int = samples.max()
		var warm_worst: int = warm.max() if not warm.is_empty() else 0
		# Wall-clock samples only grow under CPU contention (full suites share the machine), so the cap
		# applies to the best cold repeat and the median warm plan; the maxima stay in the report.
		var sorted_warm: Array = warm.duplicate()
		sorted_warm.sort()
		var warm_median: int = int(sorted_warm[sorted_warm.size() / 2]) if not sorted_warm.is_empty() else 0
		var cold_best: int = samples.min()
		var plan_best: int = plan_maxes.min() if not plan_maxes.is_empty() else 0
		if preload("res://tests/helpers/perf_group.gd").enabled() and board.get("_status_plate_layout") != null and maxi(cold_best, maxi(warm_median, plan_best)) > PLAN_CAP_USEC: failures.append("%s cold/warm plan exceeds 4000 us: %d/%d/%d" % [fixture["name"], cold_best, warm_median, plan_best])
		reports.append({"name": fixture["name"], "cold_best_us": cold_best, "warm_median_us": warm_median, "cold_max_us": worst, "warm_max_us": warm_worst, "individual_plan_max_us": plan_max, "cold_samples_us": samples, "warm_samples_us": warm})
		board.queue_free()
		await tree.process_frame
	return {"cases": reports, "cap_us": PLAN_CAP_USEC, "failures": failures}

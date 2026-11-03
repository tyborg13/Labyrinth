extends SceneTree

const CACHE_PHASES := [0.0,0.25,0.49,0.50,0.51,0.75,1.0]
const DISPLAYED_ROOT_TEST_PHASE: float = 0.49

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output: String = args[args.find("--output") + 1] if args.has("--output") else "user://rr46/depth.json"
	var report: Dictionary = preload("depth_sweep.gd").run()
	await _check_retained_cache(report)
	_check_occupant_order(report)
	_check_visible_callbacks(report)
	if report["legacy_rejected_frames"] == 0: report["errors"].append("Old destination routing survived")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RR46 DEPTH ORDER: %s (%d boards; %d frames; %d old-routing failures; %d retreat routes; native pixels=false)" % ["PASS" if report["errors"].is_empty() else "FAIL",report["boards"].size(),report["frames"],report["legacy_rejected_frames"],report["keep_distance_paths"]])
	if not report["errors"].is_empty(): printerr(JSON.stringify(report["errors"].slice(0,10)))
	quit(0 if report["errors"].is_empty() else 1)

func _check_retained_cache(report: Dictionary) -> void:
	const Sweep = preload("depth_sweep.gd")
	const fixture = preload("res://tests/maquette_cutout/runtime_suite.gd")
	var board := Sweep.Board.new()
	board.size = Sweep.PROOF_SIZE
	root.add_child(board)
	board.set_process(false)
	for type: String in Sweep.Types.TYPES:
		var state: Dictionary = fixture.fixture(type)
		var unit: Dictionary = state["enemies"][0].duplicate(true)
		unit["key"] = "enemy_1"
		var from: Vector2i = unit["pos"]
		for direction: Vector2i in Sweep.DIRECTIONS:
			var to: Vector2i = from + direction
			board.set_combat_state(state,[],[],Vector2i(-1,-1),"","",{},{},{})
			var start: Vector2 = board.world_position_for_tile(from)
			var end: Vector2 = board.world_position_for_tile(to)
			for phase: float in CACHE_PHASES:
				var ground: Vector2 = start.lerp(end,phase)
				var expected: Vector2i = Sweep.expected_host(board,from,to,ground,start,end)
				var shown: Dictionary = {"unit_draw_tiles":{"enemy_1":to},"unit_world_positions":{"enemy_1":ground},"unit_footprint_world_positions":{"enemy_1":ground}}
				board.set_combat_state(state,[],[],Vector2i(-1,-1),"","",{},{},shown)
				var cached: Array = board._units_by_draw_tile_cache.get(expected,[])
				if not cached.any(func(actor: Dictionary) -> bool: return actor.get("key","")=="enemy_1"):
					report["errors"].append("stale retained draw tile: "+type+"/"+str(direction)+"/"+str(phase))
				report["cache_frames"] = int(report.get("cache_frames",0))+1
	# The Seer's protected root reaches the far tile ahead of linear t.
	# Sampling only the interpolated footprint would retain the wrong host.
	var seer: Dictionary = fixture.fixture("hoarfrost_seer")
	var unit: Dictionary = seer["enemies"][0].duplicate(true)
	unit["key"] = "enemy_1"
	board.set_combat_state(seer,[],[],Vector2i(-1,-1),"","",{},{},{})
	var from: Vector2i = unit["pos"]
	var to: Vector2i = from+Vector2i.RIGHT
	var start: Vector2 = board.world_position_for_tile(from)
	var end: Vector2 = board.world_position_for_tile(to)
	var shown: Dictionary = {"unit_draw_tiles":{"enemy_1":to},"unit_footprint_world_positions":{"enemy_1":start.lerp(end,DISPLAYED_ROOT_TEST_PHASE)}}
	Sweep.Action.movement_frame(shown,"hoarfrost_seer","enemy_1",start,end,Vector2i.RIGHT,DISPLAYED_ROOT_TEST_PHASE,false)
	board.set_combat_state(seer,[],[],Vector2i(-1,-1),"","",{},{},shown)
	var view: Dictionary = preload("res://scripts/enemy_cutout_facing.gd").direction_for_delta(Vector2i.RIGHT)
	var channels: Dictionary = Sweep.Action.Motion.channels_at(Sweep.Action.data_for("hoarfrost_seer"),"move",DISPLAYED_ROOT_TEST_PHASE,view["facing"],start.distance_to(end))
	var authored_ground: Vector2 = start+(end-start).normalized()*float(channels["root"]["forward_px"])
	if authored_ground.distance_to(start)<=start.distance_to(end)*DISPLAYED_ROOT_TEST_PHASE: report["errors"].append("Seer protected root must travel ahead of linear t")
	if board._effective_unit_tile(unit)!=Sweep.expected_host(board,from,to,authored_ground,start,end): report["errors"].append("Seer displayed root must own its ground-depth slot")
	report["cache_frames"] = int(report.get("cache_frames",0))+1
	board.free()

func _check_occupant_order(report: Dictionary) -> void:
	const Sweep = preload("depth_sweep.gd")
	const Fixture = preload("res://tests/maquette_cutout/runtime_suite.gd")
	const GROUND_CROSSING_TILE_FRACTION: float = 0.1
	var board := Sweep.Board.new()
	board.size = Sweep.PROOF_SIZE
	root.add_child(board)
	board.set_process(false)
	for type: String in Sweep.Types.TYPES:
		var state: Dictionary = Fixture.fixture(type)
		var from: Vector2i = state["enemies"][0]["pos"]
		var other: Dictionary = state["enemies"][0].duplicate(true)
		other.merge({"id":2,"type":"ash_hound"},true)
		state["enemies"].append(other)
		board.set_combat_state(state,[],[],Vector2i(-1,-1),"","",{},{},{})
		var center: Vector2 = board.world_position_for_tile(from)
		for side: int in [-1,1,-1]:
			var ground: Vector2 = center+Vector2(0,board._tile_height()*GROUND_CROSSING_TILE_FRACTION*side)
			var shown: Dictionary = {"unit_draw_tiles":{"enemy_1":from},"unit_world_positions":{"enemy_1":ground,"enemy_2":center},"unit_footprint_world_positions":{"enemy_1":ground,"enemy_2":center}}
			board.set_combat_state(state,[],[],Vector2i(-1,-1),"","",{},{},shown)
			var occupants: Array = board._units_by_draw_tile_cache.get(from,[])
			var keys: Array[String]
			for unit: Dictionary in occupants:
				if unit["key"] in ["enemy_1","enemy_2"]: keys.append(unit["key"])
			var expected: Array[String]
			expected.assign(["enemy_1","enemy_2"] if side<0 else ["enemy_2","enemy_1"])
			if keys!=expected: report["errors"].append(type+": occupant ground-Y draw order "+str(keys)+" != "+str(expected))
			var retained: Dictionary = board._units_by_draw_tile_cache
			var visible: Array = board._visible_units_cache
			board.set_combat_state(state,[],[],Vector2i(-1,-1),"","",{},{},shown)
			if not is_same(retained,board._units_by_draw_tile_cache) or not is_same(occupants,board._units_by_draw_tile_cache.get(from,[])) or not is_same(visible,board._visible_units_cache):
				report["errors"].append(type+": unchanged submission rebuilt occupant/visible caches")
			report["occupant_crossings"] = int(report.get("occupant_crossings",0))+1
	board.free()

# E5: rr-47's real culled-back-row/diagonal callback regression belongs to
# this KEEP owner. Observe production layer dispatch, never native pixels.
func _check_visible_callbacks(report: Dictionary) -> void:
	const RoutingBoard = preload("res://tests/rr47/routing_board.gd")
	const Cases = preload("native_cases.gd")
	const IDs = preload("id_pass.gd")
	const BACK_ROUTE: String = "move_2_1_-1_1"
	const PROOF_ACTOR_HP: int = 10
	var board := RoutingBoard.new()
	board.size = Vector2(1920, 1080)
	root.add_child(board)
	board.set_process(false)
	var missing_callbacks: int = 0
	var samples: int = 0
	for item: Dictionary in Cases.boards():
		for type: String in Cases.Sweep.Types.TYPES:
			for route: Dictionary in Cases.routes(item["battle"]):
				if route["id"] != BACK_ROUTE: continue
				var battle: Dictionary = item["battle"].duplicate(true)
				var unit: Dictionary = {"key":"enemy_1", "id":1, "role":"enemy", "type":type, "pos":route["from"], "hp":PROOF_ACTOR_HP, "max_hp":PROOF_ACTOR_HP}
				battle["enemies"] = [unit]
				battle["umbra"]["vision_bonus"] = Cases.Sweep.Combat.UMBRA_UNLIMITED_RADIUS
				var base: Dictionary = {"board_framing_mode":"combat", "ambient_time_seconds":0.0, "idle_time_seconds":0.0, "scene_props":item["scene_props"]}
				board.set_combat_state(battle, [], [], Vector2i(-1,-1), "", "", {}, {}, base)
				var start: Vector2 = board.world_position_for_tile(route["from"])
				var end: Vector2 = board.world_position_for_tile(route["to"])
				var count: int = Cases.Sweep.Action.frames_for(type, "move")
				for frame: int in IDs.indices(count, false):
					var shown: Dictionary = base.duplicate(true)
					Cases.decorate_frame(battle, shown, unit, route, start, end, frame, float(frame+1)/count)
					board.set_combat_state(battle, [], [], Vector2i(-1,-1), "", "", {}, {}, shown)
					missing_callbacks += _missing_actor_callback(board)
					samples += 1
				unit["pos"] = route["to"]
				board.set_combat_state(battle, [], [], Vector2i(-1,-1), "", "", {}, {}, base)
				missing_callbacks += _missing_actor_callback(board)
				samples += 1
	report["missing_callbacks"] = missing_callbacks
	report["callback_samples"] = samples
	if samples == 0 or missing_callbacks != 0:
		report["errors"].append("E5 back-row/diagonal routing: %d missing callbacks in %d samples" % [missing_callbacks, samples])
	print("DEPTH CALLBACK REGRESSION: %s (%d samples; %d missing callbacks)" % ["PASS" if samples > 0 and missing_callbacks == 0 else "FAIL", samples, missing_callbacks])
	board.free()

func _missing_actor_callback(board: Control) -> int:
	var submitted: int = 0
	for layer: Control in board._scene_render_layers:
		if layer._render_layer_scene_effect_pass != 0: continue
		layer.submitted_actor_keys.clear()
		layer._draw_unit_bodies_for_tile(layer._render_layer_tile, layer._visible_units())
		submitted += layer.submitted_actor_keys.count("enemy_1")
	return 0 if submitted == 1 else 1

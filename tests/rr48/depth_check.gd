extends SceneTree

## Headless retained-host and ground-depth oracle; no renderer proof claimed.
const Cases = preload("res://tests/rr48/depth_cases.gd")
const Depth = preload("res://scripts/maquette_cutout_runtime/board_depth.gd")
const IDs = preload("res://tests/rr46/id_pass.gd")
const PHASES := [0.49,0.50,0.51]
const GROUND_ROUNDOFF_PIXELS: float = 0.001
const PROOF_ACTOR_HP: int = 10
const MAXIMUM_SAMPLING_TEST_LENGTH: int = 120
var report: Dictionary = {"errors":[],"boards":[],"routes":0,"samples":0,"prop_comparisons":0,"review_cases":[],"sampling":{},"native_pixels":false}

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var review_only: bool = args.has("--review-only")
	var board := Cases.Sweep.Board.new()
	board.size=Cases.Sweep.PROOF_SIZE
	root.add_child(board)
	board.set_process(false)
	for item: Dictionary in Cases.boards():
		report["boards"].append(item["label"])
		for type: String in Cases.ACTORS:
			for from: Vector2i in Cases.origins(item["battle"]):
				for direction: Vector2i in Cases.Sweep.DIRECTIONS:
					var to: Vector2i = from+direction
					if not Cases.Paths.is_passable(item["battle"]["grid"],to): continue
					if review_only and (from!=Cases.CORNER_FROM or to!=Cases.CORNER_TO): continue
					_sweep(board,item,type,from,to)
	board.free()
	for count: int in range(1,MAXIMUM_SAMPLING_TEST_LENGTH+1):
		report["sampling"][str(count)]=IDs.indices(count,false)
	for error: Variant in report["errors"].slice(0,10): printerr(error)
	if args.has("--output"):
		FileAccess.open(args[args.find("--output")+1],FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RR48 HEADLESS DEPTH: %s (%d boards; %d routes; %d samples; %d prop comparisons; native pixels=false)"%["PASS" if report["errors"].is_empty() else "FAIL",report["boards"].size(),report["routes"],report["samples"],report["prop_comparisons"]])
	quit(0 if report["errors"].is_empty() else 1)

func _sweep(board: Control, item: Dictionary, type: String, from: Vector2i, to: Vector2i) -> void:
	var battle: Dictionary = item["battle"].duplicate(true)
	var actor: Dictionary = {"key":"enemy_1","id":1,"role":"enemy","type":type,"pos":from,"hp":PROOF_ACTOR_HP,"max_hp":PROOF_ACTOR_HP}
	battle["enemies"]=[actor]
	battle["umbra"]["vision_bonus"]=Cases.Sweep.Combat.UMBRA_UNLIMITED_RADIUS
	var base: Dictionary = {"board_framing_mode":"combat","scene_props":item["scene_props"]}
	board.set_combat_state(battle,[],[],Vector2i(-1,-1),"","",{},{},base)
	var start: Vector2 = board.world_position_for_tile(from)
	var end: Vector2 = board.world_position_for_tile(to)
	var count: int = Cases.Sweep.Action.frames_for(type,"move")
	var route: Dictionary = {"clip":"move","to":to,"direction":to-from}
	var props: Array[Dictionary] = Cases.Primitives.catalog(board)
	var phases: Array[float]
	phases.assign(PHASES)
	for frame: int in range(1,count+1):
		var phase: float = float(frame)/count
		if not phases.has(phase): phases.append(phase)
	phases.sort()
	for phase: float in phases:
		var shown: Dictionary = base.duplicate(true)
		Cases.decorate_frame(battle,shown,actor,route,start,end,roundi(phase*count)-1,phase)
		board.set_combat_state(battle,[],[],Vector2i(-1,-1),"","",{},{},shown)
		var ground: Vector2 = Cases.displayed_ground(board,actor,shown)
		# Preserve parity with the old full-pose sampler, including non-linear
		# authored travel and fraction-of-step scaling in every facing.
		var motion: Dictionary = shown[type+"_motion"]["enemy_1"]
		var view: Dictionary = preload("res://scripts/enemy_cutout_facing.gd").direction_for_delta(to-from)
		var channels: Dictionary = Cases.Sweep.Action.Motion.channels_at(Cases.Sweep.Action.data_for(type),"move",phase,view["facing"],motion["step_distance_px"])
		var full_ground: Vector2 = start+(end-start).normalized()*float(channels.get("root",{}).get("forward_px",0.0))
		check(Depth.position(board,actor,shown).distance_to(full_ground)<GROUND_ROUNDOFF_PIXELS,"root-only/full-channel parity: "+type)
		var expected: Vector2i = Cases.Sweep.expected_host(board,from,to,ground,start,end)
		var host: Vector2i = board._effective_unit_tile(actor)
		var label: String = "%s/%s/%s/%s/%.2f"%[item["label"],type,from,to,phase]
		check(host==expected,label+": off-segment/tie host "+str(host)+" expected "+str(expected))
		check(Depth.position(board,actor,shown).distance_to(ground)<GROUND_ROUNDOFF_PIXELS,label+": ground track differs")
		var occupants: Array = board._units_by_draw_tile_cache.get(host,[])
		check(occupants.any(func(unit: Dictionary) -> bool: return unit.get("key","")=="enemy_1"),label+": missing retained occupant")
		check(board._scene_render_layers_by_tile.has(host),label+": missing retained host")
		# Compare directly against prop ground depths, never rounded coordinates
		# or a call to the production comparator. Observe actual child order.
		for prop: Dictionary in props:
			if prop["kind"]!="prop": continue
			var delta: float = ground.y-float(prop["ground_y"])
			if absf(delta)<=GROUND_ROUNDOFF_PIXELS: continue
			var prop_tile: Vector2i = prop["tile"]
			var actor_layer: Control = board._scene_render_layers_by_tile[host]
			var prop_layer: Control = board._scene_render_layers_by_tile[prop_tile]
			var after: bool = host==prop_tile or actor_layer.get_index()>prop_layer.get_index()
			check(after==(delta>0.0),label+": prop ground-depth order "+str(prop["id"]))
			report["prop_comparisons"]+=1
		report["samples"]+=1
	report["routes"]+=1

func check(ok: bool, message: String) -> void:
	if not ok: report["errors"].append(message)

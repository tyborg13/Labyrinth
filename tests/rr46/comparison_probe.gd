extends SceneTree

const ClockScene = preload("clock_scene.gd")
const Timing = preload("timing.gd")
const Fixture = preload("res://tests/maquette_cutout/runtime_suite.gd")
const OUTPUT: String = "user://probes/rr46-pair"
const SETTLE_FRAMES: int = 2
const PROOF_NEAR_ORIGIN := Vector2i(2,3)
const PROOF_FAR_ORIGIN := Vector2i(2,4)
const PROOF_TRAVEL_TILES: int = 2

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var validate: bool = args.has("--validate-only")
	if DisplayServer.get_name()=="headless" and not validate:
		printerr("RR46 comparison requires the windowed visual probe runner")
		quit(1)
		return
	var output: String = args[args.find("--output")+1] if args.has("--output") else OUTPUT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var board := Timing.Board.new()
	board.size = Timing.PROOF_SIZE
	var planner := ClockScene.new()
	planner.board_view = board
	planner._combat_pacing.enemies_active = true
	var state: Dictionary = Fixture.fixture("slag_mortar")
	state["enemies"][0]["pos"] = PROOF_NEAR_ORIGIN
	var other: Dictionary = state["enemies"][0].duplicate(true)
	other.merge({"id":2,"type":"ash_hound","pos":PROOF_FAR_ORIGIN},true)
	state["enemies"].append(other)
	var plans: Array[Dictionary]
	if not validate:
		var settings: Dictionary = Timing.Settings.default_settings()
		settings["ui_scale"] = 1.0
		settings["display_mode"] = "windowed"
		Timing.Settings.apply_settings(settings,root,false)
		root.size = Vector2i(Timing.PROOF_SIZE)
		root.content_scale_size = root.size
		root.add_child(board)
		board.set_combat_state(state,[],[],Vector2i(-1,-1),"","",{},{},{"board_framing_mode":"combat"})
	for index: int in range(2):
		var path: Array[Vector2i]
		var from: Vector2i = state["enemies"][index]["pos"]
		path.assign([from,from+Vector2i.RIGHT,from+Vector2i.RIGHT*PROOF_TRAVEL_TILES])
		planner.scheduled.clear()
		planner.submissions.clear()
		await planner._animate_actor_along_path(state,"enemy_%d"%(index+1),path,{})
		plans.append({"clock":planner.scheduled[0].duplicate(true),"frames":planner.submissions.duplicate(true)})
	var errors: Array[String]
	if absf(float(plans[0]["clock"]["seconds"])-float(plans[1]["clock"]["seconds"]))>Timing.FRAME_TOLERANCE_SECONDS: errors.append("Production two-tile schedules differ")
	var captures: Array[String]
	if not validate:
		for speed: String in Timing.SPEEDS:
			var scale: float = Timing.Settings.combat_speed_scale({"combat_speed":speed})
			var start: int = Time.get_ticks_usec()
			var duration: float = maxf(plans[0]["clock"]["seconds"],plans[1]["clock"]["seconds"])
			var frame: int = 0
			while true:
				var elapsed: float = (Time.get_ticks_usec()-start)/1000000.0*scale
				var shown: Dictionary = {"board_framing_mode":"combat"}
				for plan: Dictionary in plans:
					var at: int = clampi(floori(elapsed/float(plan["clock"]["frame_seconds"])),0,plan["frames"].size()-1)
					var submission: Dictionary = plan["frames"][at]
					for key: String in submission:
						if key in ["unit_world_positions","unit_footprint_world_positions","unit_texture_origins","unit_draw_tiles"]:
							var merged: Dictionary = shown.get(key,{}).duplicate()
							merged.merge(submission[key],true)
							shown[key] = merged
						elif key.ends_with("_motion"): shown[key] = submission[key]
				board.set_combat_state(state,[],[],Vector2i(-1,-1),"","",{},{},shown)
				await RenderingServer.frame_post_draw
				var name: String = "pair_%s_%04d%s.png"%[speed,frame,"_end" if elapsed>=duration else ""]
				root.get_texture().get_image().save_png(output.path_join(name))
				captures.append(name)
				frame += 1
				if elapsed>=duration: break
			for _frame: int in range(SETTLE_FRAMES): await RenderingServer.frame_post_draw
	FileAccess.open(output.path_join("comparison.json"),FileAccess.WRITE).store_string(JSON.stringify({"native":not validate,"plans":plans,"captures":captures,"errors":errors},"\t"))
	planner.board_view = null
	planner.free()
	board.free()
	print("RR46 COMPARISON: %s (two tiles; Slag Mortar beside Ash Hound; native=%s)"%["PASS" if errors.is_empty() else "FAIL",not validate])
	quit(0 if errors.is_empty() else 1)

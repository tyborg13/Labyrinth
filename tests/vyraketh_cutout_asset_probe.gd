extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProductionRig = preload("res://scripts/vyraketh_cutout/rig.gd")
const CaseRig = preload("res://tools/cutout_pipeline/rig.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Suite = preload("res://tests/suites/vyraketh_cutout_suite.gd")
const Cutout = preload("res://scripts/vyraketh_cutout/renderer.gd")
var board: Control
var board_surface: SubViewport
var board_state: Dictionary
var records: Array[Dictionary]
const OUTPUT: String = "user://probes/vyraketh_cutout_assets"
var _errors: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size = Vector2i(1920,1080)
	board_surface = _viewport()
	board_surface.size = Vector2i(1920,1080)
	board_surface.transparent_bg = false
	board = Board.new()
	board.size = Vector2(1920,1080)
	board_surface.add_child(board)
	board_state = Suite.fixture_state()
	var actual: SubViewport = _viewport()
	var accepted: SubViewport = _viewport()
	var compared: int = 0
	for facing: String in ["front", "rear"]:
		var production := ProductionRig.new()
		production.facing = facing
		actual.add_child(production)
		_check(production.load_rig(), "Production rig loads " + facing)
		var reference := CaseRig.new()
		accepted.add_child(reference)
		_check(reference.configure("res://experiments/cutouts/vyraketh/v01/cutout.json"), "Reviewed case loads")
		_check(reference.set_facing(facing), "Reviewed facing loads")
		production.position = Vector2(128, 128)
		reference.position = Vector2(128, 128)
		for reflected: bool in [false,true]:
			production.position = Vector2(383,128) if reflected else Vector2(128,128)
			reference.position = production.position
			production.scale = Vector2(-1,1) if reflected else Vector2.ONE
			reference.scale = production.scale
			for clip: String in ["rest", "idle", "walk", "maw", "kindle", "crownfire", "cinderfall"]:
				var frames: int = 1 if clip == "rest" else 24 if clip == "idle" else 32
				var folder: String = "%s_%s_%s" % [facing,"reflected" if reflected else "native",clip]
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.path_join(folder)))
				if clip != "rest":
					records.append({"folder":folder,"frames":frames,"frame_seconds":float(reference.config["clips"][clip]["duration"])/float(frames)})
				for index: int in range(frames):
					var phase: float = float(index) / float(frames - 1 if clip not in ["idle", "walk", "rest"] else frames)
					var playback: float = phase
					if clip != "rest":
						phase = reference.playback_phase(clip,phase)
					production.apply_pose(clip, phase)
					reference.apply_pose(clip, phase)
					_present_board(facing,reflected,clip,phase,playback)
					await _draw()
					var image: Image = actual.get_texture().get_image()
					_check(image.get_data() == accepted.get_texture().get_image().get_data(), "%s %s %d remains pixel-identical" % [facing, clip, index])
					compared += 1
					var bounds: Rect2i = image.get_used_rect()
					_check(bounds.has_area() and bounds.position.x >= 3 and bounds.position.y >= 3 and bounds.end.x <= 509 and bounds.end.y <= 509,"All views retain full fixed-canvas bounds")
					board_surface.get_texture().get_image().save_jpg(OUTPUT.path_join(folder).path_join("board_%04d.jpg" % index),0.95)
					if index == frames / 2:
						board_surface.get_texture().get_image().save_png(OUTPUT.path_join(folder+"_board.png"))
					image.save_png(OUTPUT.path_join("%s_%s_%s_%03d.png" % [facing, "reflected" if reflected else "native", clip,index]))
					if clip not in ["idle", "walk", "rest"] and index in [10, 13, 17, 21]:
						image.save_png(OUTPUT.path_join("%s_attack_%02d.png" % [facing, index]))
					if clip == "rest" and not reflected:
						var baked: Image = Image.load_from_file("res://assets/units/vyraketh_cutout/" + facing + "/rest.png")
						_check(image.get_region(Rect2i(128, 128, 255, 255)).get_data() == baked.get_data(), "Shipped rest silhouette matches the current assembly")
						_check(image.save_png(OUTPUT.path_join(facing + "_canvas.png")) == OK, "Save native rest canvas")
						_check(image.get_region(Rect2i(128, 128, 255, 255)).save_png(OUTPUT.path_join(facing + "_rest.png")) == OK, "Save logical rest silhouette")
		production.free()
		reference.free()
	var output := FileAccess.open(OUTPUT.path_join("comparison.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"ok": _errors.is_empty(), "native_identical_frames": compared, "errors": _errors}, "\t"))
	output.close()
	actual.free()
	accepted.free()
	board_surface.free()
	var rendered := FileAccess.open(OUTPUT.path_join("render_manifest.json"),FileAccess.WRITE)
	rendered.store_string(JSON.stringify({"size":[1920,1080],"ui_scale":1.0,"clips":records,"errors":_errors,"timing_basis":"Native production CombatBoardView study with case playback phase curves; actual action triggers are covered separately by the gameplay probe"},"\t"))
	rendered.close()
	for error: String in _errors:
		push_error(error)
	print("Saved " + ProjectSettings.globalize_path(OUTPUT))
	print("VYRAKETH ASSET PROBE: " + ("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)

func _viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport

func _draw() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)

func _present_board(facing: String, reflected: bool, clip: String, phase: float, playback: float) -> void:
	var direction: Vector2i = (Vector2i(-1,0) if reflected else Vector2i(0,-1)) if facing == "rear" else (Vector2i(1,0) if reflected else Vector2i(0,1))
	board_state["player"]["pos"] = Vector2i(3,3) + direction * 2
	var motion: Dictionary = {"clip":"walk" if clip == "walk" else "idle" if clip in ["rest","idle"] else "attack",
		"direction":direction,"phase":phase,"action":clip,"authored_phase":true}
	var presentation: Dictionary = {"vyraketh_motion":{"enemy_1":motion},"reduced_motion":clip == "rest"}
	if clip == "walk":
		var travel: Vector2 = Cutout.Motion.walk_cycle_info({},facing)["travel_per_cycle"] * playback
		if reflected: travel.x = -travel.x
		presentation["unit_world_positions"] = {"enemy_1":board.call("world_position_for_unit_origin",board_state["enemies"][0],Vector2i(3,3))+travel*float(board.call("vyraketh_source_pixel_scale"))}
	board.call("set_combat_state",board_state,[],[],Vector2i(-1,-1),"","",{},{},presentation)
	for key: String in board.get("_vyraketh_renderers"):
		var renderer: Node = board.get("_vyraketh_renderers")[key]
		renderer.set_process(false)
		if key == "enemy_1" and clip == "idle":
			renderer.set("_idle_seconds",phase*Cutout.IDLE_CYCLE_SECONDS)
			renderer.call("_apply_pose")

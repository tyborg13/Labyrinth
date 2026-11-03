extends SceneTree

const Fixtures = preload("res://tests/suites/en03_enemies_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Timing = preload("res://scripts/maquette_cutout_runtime/playback_timing.gd")
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Scene = preload("walk_turn_scene.gd")
const PROOF_ENEMY_TILE := Vector2i(6, 4)
const PROOF_PLAYER_TILE := Vector2i(2, 4)
const PROOF_SETTLE_FRAMES: int = 8
const PROOF_MOVE_TILES: int = 3
const EPSILON: float = 0.0001
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	scene.set_script(Scene)
	root.add_child(scene)
	scene.board_view.hide()
	for frame: int in range(PROOF_SETTLE_FRAMES): await process_frame
	var actors: Array[Dictionary]
	actors.assign([Fixtures.enemy("ashen_reaver", 1, PROOF_ENEMY_TILE, "raking_flame")])
	var state: Dictionary = Fixtures.state(actors, PROOF_PLAYER_TILE)
	# Debug-only movement intent supplies the requested three-tile route. The
	# real Reaver's printed Raking Flame currently advances only one tile.
	state["enemies"][0]["intent"]["actions"] = [{"type": "move_toward", "range": PROOF_MOVE_TILES}]
	Fixtures.install(scene, state)
	var resolved: Dictionary = Combat.new().resolve_enemy_turn_with_steps(state, 0)
	var moves: Array[Dictionary]
	for step: Dictionary in resolved["steps"]:
		if step.get("kind") == "move": moves.append(step)
	check(moves.size() == 1, "resolver must produce one movement step")
	var clock: Node = scene._combat_pacing
	clock.enemies_active = true
	clock.debug_timeline = true
	clock.fixed_usec = clock.presentation_usec()
	clock.controlled = true
	# Clock routing parity for hero, other rigs, reduced motion and player phase.
	var frames_per_tile: int = Action.frames_for("ashen_reaver", "move")
	var tile_seconds: float = Action.seconds_for("ashen_reaver", "move")
	var counts: Array[int]
	counts.assign([frames_per_tile, frames_per_tile, frames_per_tile])
	for type: String in preload("walk_samples.gd").TYPES:
		var type_frames: int = Action.frames_for(type, "move")
		var type_counts: Array[int]
		type_counts.assign([type_frames, type_frames, type_frames])
		check(is_equal_approx(Timing.movement_frame_seconds(Action.data_for(type), clock, "enemy_1", type_counts, 1.0 / 60.0), 1.0 / 60.0), type + ": authored enemy tile time")
	for type: String in ["burrow_grub", "ember_tick", "lightning_wisp"]:
		check(is_equal_approx(Timing.movement_frame_seconds(Action.data_for(type), clock, "enemy_1", counts, 1.0 / 60.0), float(Timing.MOVE_TILE_SECONDS[type]) / frames_per_tile), type + ": legacy creature clock")
	check(is_equal_approx(Timing.movement_frame_seconds(Action.data_for("ashen_reaver"), clock, "player", counts, 1.0 / 60.0), 1.0 / 60.0), "hero clock")
	check(is_equal_approx(Timing.movement_frame_seconds(Action.data_for("hollow_mimic"), clock, "enemy_1", counts, 1.0 / 60.0), clock.walk_frame_seconds("enemy_1", counts, 1.0 / 60.0)), "Mimic clock")
	check(is_equal_approx(Timing.movement_frame_seconds(Action.data_for("ashen_reaver"), clock, "enemy_1", counts, 1.0 / 60.0, true), clock.walk_frame_seconds("enemy_1", counts, 1.0 / 60.0)), "reduced-motion clock")
	clock.enemies_active = false
	check(is_equal_approx(Timing.movement_frame_seconds(Action.data_for("ashen_reaver"), clock, "enemy_1", counts, 1.0 / 60.0), 1.0 / 60.0), "outside enemy phase clock")
	clock.enemies_active = true
	scene._ensure_sfx_bank()
	scene._sfx_bank.cue_requested.connect(scene.walk_proof_cue)
	scene.walk_proof_active = true
	var animated: Dictionary = state.duplicate(true)
	for step: Dictionary in moves:
		check(step["to"] - step["from"] == Vector2i(-3, 0), "resolver path must walk three rear tiles")
		await clock.before_step(step)
		await scene._animate_move_step(animated, step)
	var total_frames: int = PROOF_MOVE_TILES * frames_per_tile
	check(scene.walk_proof_frames.size() == total_frames, "%d production movement frames" % total_frames)
	check(scene.walk_proof_clocks.size() == 1 and scene.walk_proof_clocks[0]["count"] == total_frames, "single production movement clock")
	var previous: Vector2 = scene.board_view.world_position_for_unit_origin(state["enemies"][0], PROOF_ENEMY_TILE)
	var maximum: float = 0.0
	for row: Dictionary in scene.walk_proof_frames:
		var position := Vector2(row["position"][0], row["position"][1])
		check(position.x <= previous.x + EPSILON and position.y <= previous.y + EPSILON, "monotonic rear travel")
		maximum = maxf(maximum, position.distance_to(previous))
		previous = position
		check(row["phase"] == "walk (tile %d)" % (ceili(float(row["frame"]) / frames_per_tile)), "walk phase follows tile clock")
	check(maximum <= 8.0, "no root jumps above 8 px including seams")
	check(scene.walk_proof_cues.size() == 3, "one footstep per tile")
	for index: int in range(scene.walk_proof_cues.size()):
		var cue: Dictionary = scene.walk_proof_cues[index]
		check(cue["frame"] == frames_per_tile * (index + 1), "footsteps follow tile completion frames")
		check(absf(cue["seconds"] - tile_seconds * (index + 1)) < EPSILON, "footsteps follow authored tile time")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--output"):
		FileAccess.open(args[args.find("--output") + 1], FileAccess.WRITE).store_string(JSON.stringify({"ok": failures.is_empty(), "native_pixels": false, "errors": failures, "frames": scene.walk_proof_frames, "clocks": scene.walk_proof_clocks, "cues": scene.walk_proof_cues, "frames_per_tile": frames_per_tile, "tile_seconds": tile_seconds, "maximum_frame_travel_px": maximum}, "\t"))
	for failure: String in failures: printerr(failure)
	print("WALK-01 RESOLVER: %s (%d movement frames; 3 rear tiles; max jump %.6f px; %d footsteps)" % ["PASS" if failures.is_empty() else "FAIL", scene.walk_proof_frames.size(), maximum, scene.walk_proof_cues.size()])
	scene.walk_proof_active = false
	scene.free()
	quit(0 if failures.is_empty() else 1)

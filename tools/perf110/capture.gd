extends SceneTree
## Production board and health widget at deterministic debug-only samples.
const Board = preload("res://scripts/combat_board_view.gd")
const Fixtures = preload("res://tests/maquette_cutout/runtime_suite.gd")
const Bar = preload("res://scripts/segmented_health_bar.gd")
const Tracker = preload("res://scripts/health_ghost_tracker.gd")
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const SIZE := Vector2i(1920, 1080)
const FIXTURE_TYPES := ["crawler", "hoarfrost_seer"]
const POSE_PHASE: float = 0.5
const AMBIENT_SECONDS: float = 0.5
const GHOST_SECONDS: float = 0.75
const FIXTURE_DAMAGE: float = 6.0
const HEALTH_POSITION := Vector2(64, 64)
const HEALTH_SIZE := Vector2(320, 20)
const SETTLE_FRAMES: int = 8
const PROOF_MOUSE_FILTER: int = Control.MOUSE_FILTER_IGNORE
var _output: String
var _verify_only: bool
var _viewport: SubViewport
var _failures: Array[String]
var _records: Array

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_output = OS.get_environment("PERF110_CAPTURE_DIR")
	_verify_only = OS.get_cmdline_user_args().has("--verify-only")
	if _output.is_empty():
		push_error("PERF110_CAPTURE_DIR is required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_output)
	_run.call_deferred()

func _run() -> void:
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_factor = 1.0
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	for type: String in FIXTURE_TYPES:
		var board := Board.new()
		board.size = Vector2(SIZE)
		board.mouse_filter = PROOF_MOUSE_FILTER
		_viewport.add_child(board)
		var combat: Dictionary = Fixtures.fixture(type)
		var presentation: Dictionary = {"ambient_time_seconds": AMBIENT_SECONDS,
			"umbra_time_seconds": AMBIENT_SECONDS, "torch_mote_proof_seconds": AMBIENT_SECONDS,
			"threats_proof_seconds": AMBIENT_SECONDS}
		board.set_combat_state(combat, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
		await _settle()
		var tracker: RefCounted = board.health_ghost_tracker
		(tracker.get("_clock") as Node).set_process(false)
		combat = combat.duplicate(true)
		combat["enemies"][0]["hp"] -= FIXTURE_DAMAGE
		board.set_combat_state(combat, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
		(tracker.get("_clock") as Node).set_process(false)
		tracker.advance(GHOST_SECONDS)
		var health := Bar.new()
		health.name = "FixtureSegmentedHealthBar"
		health.mouse_filter = PROOF_MOUSE_FILTER
		health.position = HEALTH_POSITION
		health.size = HEALTH_SIZE
		health.set_health(combat["enemies"][0]["hp"], combat["enemies"][0]["max_hp"])
		health.set_segment_count(Bar.segment_count_for_max_hp(combat["enemies"][0]["max_hp"]))
		health.bind_ghost(tracker, "enemy_1", true)
		_viewport.add_child(health)
		var hero: Node = board.get("_protagonist_renderer")
		var enemy: Node = board.unit_cutout_renderer(combat["enemies"][0])
		_expect(hero != null and enemy != null, "Production hero and enemy renderers exist: " + type)
		if hero == null or enemy == null:
			board.free()
			health.free()
			continue
		_freeze(board)
		hero.present({"clip": "idle"}, false)
		hero.set("_idle_seconds", POSE_PHASE * preload("res://scripts/protagonist_cutout/renderer.gd").IDLE_CYCLE_SECONDS)
		hero.call("_apply_pose")
		enemy.present({"clip": "idle"}, false)
		var idle_seconds: float = preload("res://scripts/crawler_cutout/renderer.gd").IDLE_CYCLE_SECONDS if type == "crawler" else float(Action.data_for(type)["clips"]["idle"]["seconds"])
		enemy.set("_idle_seconds", POSE_PHASE * idle_seconds)
		enemy.call("_apply_pose")
		await _capture(type, "idle", "idle", hero, enemy, health)
		var attack: String = "attack"
		if type != "crawler":
			for clip: String in Action.data_for(type)["clips"]:
				if Action.data_for(type)["clips"][clip].has("contact"):
					attack = clip
					break
		hero.present({"clip": "attack", "phase": POSE_PHASE}, false)
		enemy.present({"clip": attack, "phase": POSE_PHASE}, false)
		await _capture(type, "attack", attack, hero, enemy, health)
		board.free()
		health.free()
	await process_frame
	_viewport.free()
	FileAccess.open(_output.path_join("samples.json"), FileAccess.WRITE).store_string(JSON.stringify(_records, "\t"))
	for failure: String in _failures: push_error(failure)
	print("PERF110 CAPTURE %s: samples=%d failures=%d" % ["HEADLESS SETUP" if _verify_only else "NATIVE", _records.size(), _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	if node is Board:
		# Retained painter slices carry their own copies of the board clocks.
		node.set("_idle_elapsed", AMBIENT_SECONDS)
		node.set("_continuous_presentation_elapsed", AMBIENT_SECONDS)
		var treatment: RefCounted = node.get("_art_treatment")
		if treatment != null:
			treatment.set("_clock", AMBIENT_SECONDS)
			treatment.advance(0.0, false)
		node.queue_redraw()
	for child: Node in node.get_children(): _freeze(child)

func _capture(type: String, point: String, enemy_clip: String, hero: Node, enemy: Node, health: Control) -> void:
	var ghost: Dictionary = health.ghost_sample()
	_expect(_viewport.size == SIZE and root.content_scale_factor == 1.0, "Proof uses actual 1920x1080 and 100% UI scale")
	_expect(health.is_visible_in_tree(), "The sampled segmented health widget is visible")
	_expect(ghost.get("ghost_range", Vector2.ZERO).y > ghost.get("ghost_range", Vector2.ZERO).x, "Visible segmented health bar is mid-change")
	_records.append({"type": type, "point": point, "phase": POSE_PHASE,
		"enemy_clip": enemy_clip, "hero": hero.snapshot(), "enemy": enemy.snapshot(),
		"ghost": ghost, "size": str(_viewport.size), "ui_scale": root.content_scale_factor})
	if _verify_only: return
	await _settle()
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	_expect(image != null and image.get_size() == SIZE, "Native capture has exact dimensions")
	if image != null:
		var path: String = _output.path_join(type + "_" + point + ".png")
		_expect(image.save_png(path) == OK, "PNG saves")
		print(path)

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)

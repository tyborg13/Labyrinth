extends SceneTree

const Fixture = preload("res://tools/rd04/real_fixture.gd")
const MANIFEST: String = "/private/tmp/labyrinth_codex/rd-04/feedback2/zekarion.json"
var checks: int = 0
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--rail-only"):
		preload("res://tests/suites/intent_chip_placement_suite.gd").run(_check)
		print("RD04 INTENT CHIP PLACEMENT: %d checks, %d failures" % [checks, failures.size()])
		_report()
		return
	var manifest: String = args[args.find("--fixture-manifest") + 1] if args.has("--fixture-manifest") else MANIFEST
	Fixture.install_save(manifest)
	var canvas := Fixture.make_canvas(self)
	var scene: Node
	if args.has("--baseline"):
		root.set_meta("labyrinth_resume_saved_run", true)
		scene = load("res://tools/rd04/baseline.tscn").instantiate()
		canvas.add_child(scene)
	else: scene = Fixture.resume(self, canvas)
	for frame in range(Fixture.SETUP_FRAMES): await process_frame
	await preload("res://tests/suites/turn_order_lifetime_suite.gd").run(self, scene, _check)
	print("RD04 TURN ORDER RAIL: %d cumulative checks, %d failures" % [checks, failures.size()])
	_report()

func _report() -> void:
	for failure: String in failures: push_error(failure)
	print("RD04 FOCUSED: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

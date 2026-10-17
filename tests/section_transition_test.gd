extends SceneTree
const Mutations = preload("res://tests/helpers/section_transition_mutations.gd")
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if DisplayServer.get_name() == "headless": process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	_run.call_deferred()

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mutant=") and not Mutations.apply(arg.trim_prefix("--mutant=")):
			quit(2)
			return
	# Load only after any mutation takes over its resource path. Ordinary runs
	# load the exact production scripts; mutants never write to the worktree.
	var suite: Variant = load("res://tests/suites/section_transition_suite.gd")
	if suite == null or not suite.can_instantiate():
		quit(2)
		return
	suite.run(_expect)
	await suite.run_live(self, _expect)
	for failure: String in failures: push_error(failure)
	print("SECTION TRANSITION RESULT: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

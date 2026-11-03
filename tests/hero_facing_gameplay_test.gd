extends "res://tests/hero_facing_snap_golden_test.gd"

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--review-case" in args:
		ParallelRuntime.apply_from_environment()
		var case_name: String = args[args.find("--review-case") + 1]
		quit(await preload("res://tests/fixtures/hero_facing_review_cases.gd").run(self, case_name))
		return
	for case_name: String in ["undo", "trap", "erupt"]:
		var code: int = await preload("res://tests/fixtures/hero_facing_review_cases.gd").run(self, case_name)
		if code != 0:
			quit(code)
			return
	await super._initialize()

func default_mode() -> String:
	return "persist"

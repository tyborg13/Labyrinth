extends SceneTree

const Receipts = preload("receipts.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Expected base and candidate proof directories")
		quit(1)
		return
	var base := FileAccess.open(args[0].path_join("receipts.var"), FileAccess.READ)
	var candidate := FileAccess.open(args[1].path_join("receipts.var"), FileAccess.READ)
	if base == null or candidate == null:
		push_error("Missing headless route receipts")
		quit(1)
		return
	var expected: Dictionary = Receipts.normalize(base.get_var())
	var actual: Dictionary = Receipts.normalize(candidate.get_var())
	var failures: int = 0
	for stage: String in ["new_run", "first_fight", "after_pass", "continue"]:
		var changed: String = _difference(expected.get(stage), actual.get(stage), stage)
		if not changed.is_empty():
			print("PERF165 RECEIPT DIFFERENCE: ", changed)
			failures += 1
	var probe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1].path_join("probe.json")))
	var previous: int = 0
	for phase: String in ["startup", "title_new_idle", "title_new_a", "room_travel"]:
		var count: int = probe.get("completed_warm_recipes", {}).get(phase, 0)
		if count <= previous:
			print("PERF165 WARMUP DID NOT DRAW: ", phase)
			failures += 1
		previous = count
	print("PERF165 RECEIPTS: %s (%d differences; 4 milestones, 4 warmup windows)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)

func _difference(expected: Variant, actual: Variant, path: String) -> String:
	if expected == actual: return ""
	if expected is Dictionary and actual is Dictionary:
		if expected.size() != actual.size(): return path + " (dictionary sizes differ)"
		for key: Variant in expected:
			var next := path + "/" + str(key)
			if not actual.has(key): return next + " (missing)"
			var child := _difference(expected[key], actual[key], next)
			if not child.is_empty(): return child
	elif expected is Array and actual is Array:
		if expected.size() != actual.size(): return path + " (array sizes differ)"
		for index: int in expected.size():
			var child := _difference(expected[index], actual[index], path + "/" + str(index))
			if not child.is_empty(): return child
	return "%s (%s != %s)" % [path, str(expected).left(160), str(actual).left(160)]

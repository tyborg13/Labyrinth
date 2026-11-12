extends SceneTree
## Read finished replay saves directly; no migrations or writes to the saves.
## Wall-clock duration and randomized analytics identity are retained separately;
## the logical combat ordinal and every other saved field must match exactly.
var _directory: String
const NORMALIZED_RUN_ID: String = "<run>"

func _initialize() -> void:
	_directory = OS.get_environment("PERF110_AB_DIR")
	if _directory.is_empty():
		push_error("PERF110_AB_DIR is required")
		quit(2)
		return
	var takes: Array = JSON.parse_string(FileAccess.get_file_as_string(_directory.path_join("takes.json")))
	var pairs: Dictionary = {}
	for take: Dictionary in takes:
		var pair: String = str(int(take["pair"]))
		if not pairs.has(pair): pairs[pair] = {}
		pairs[pair][take["label"]] = take["directory"]
	var results: Dictionary = {}
	var differences: int = 0
	for pair: String in pairs:
		if not pairs[pair].has("A") or not pairs[pair].has("B"): continue
		var a: Dictionary = _read(pairs[pair]["A"])
		var b: Dictionary = _read(pairs[pair]["B"])
		var seconds_a: Variant = a.get("run_stats", {}).get("run_seconds")
		var seconds_b: Variant = b.get("run_stats", {}).get("run_seconds")
		if a.get("run_stats") is Dictionary: a["run_stats"].erase("run_seconds")
		if b.get("run_stats") is Dictionary: b["run_stats"].erase("run_seconds")
		var incidental: Array = _differences(a, b)
		_normalize_session_identity(a)
		_normalize_session_identity(b)
		var equal: bool = not a.is_empty() and not b.is_empty() and a == b
		var changed: Array = []
		for key: Variant in a:
			if not b.has(key) or a[key] != b[key]: changed.append(str(key))
		for key: Variant in b:
			if not a.has(key): changed.append(str(key))
		if not equal: differences += 1
		results[pair] = {"normalized_save_equal": equal, "differing_top_fields": changed,
			"leaf_differences": _differences(a, b),
			"raw_differences_after_clock_only": incidental,
			"run_seconds_A": seconds_a, "run_seconds_B": seconds_b,
			"normalization": "run_stats.run_seconds; analytics.run_id; matching run-id prefix of combat_state.analytics.combat_id (combat ordinal retained)"}
	var result: Dictionary = {"pairs": results, "differences": differences}
	FileAccess.open(_directory.path_join("state_comparison.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("PERF110 STATE OUTCOMES: pairs=%d differences=%d" % [results.size(), differences])
	quit(0 if differences == 0 and results.size() == 6 else 1)

func _read(take: String) -> Dictionary:
	var file := FileAccess.open(_directory.path_join(take).path_join("run.save"), FileAccess.READ)
	if file == null: return {}
	var state: Variant = file.get_var(false)
	return state if state is Dictionary else {}

func _normalize_session_identity(state: Dictionary) -> void:
	var analytics: Dictionary = state.get("analytics", {})
	var run_id: String = str(analytics.get("run_id", ""))
	if run_id.is_empty(): return
	analytics["run_id"] = NORMALIZED_RUN_ID
	var combat_analytics: Dictionary = state.get("combat_state", {}).get("analytics", {})
	var combat_id: String = str(combat_analytics.get("combat_id", ""))
	if combat_id.begins_with(run_id + "_"):
		combat_analytics["combat_id"] = NORMALIZED_RUN_ID + combat_id.trim_prefix(run_id)

func _differences(a: Variant, b: Variant, path: String = "") -> Array:
	var result: Array = []
	if a == b: return result
	if a is Dictionary and b is Dictionary:
		for key: Variant in a:
			var child: String = path + "/" + str(key)
			if b.has(key): result.append_array(_differences(a[key], b[key], child))
			else: result.append({"path": child, "A": a[key], "B_missing": true})
		for key: Variant in b:
			if not a.has(key): result.append({"path": path + "/" + str(key), "A_missing": true, "B": b[key]})
	elif a is Array and b is Array and a.size() == b.size():
		for index: int in range(a.size()): result.append_array(_differences(a[index], b[index], path + "[%d]" % index))
	else:
		result.append({"path": path, "A": a, "B": b})
	return result

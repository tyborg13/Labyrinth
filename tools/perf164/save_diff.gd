extends SceneTree
## perf-164: decode two run checkpoints through the production reader and list
## the key paths whose values differ (-- --a=<run.save> --b=<run.save>).
const Store = preload("res://scripts/progression_store.gd")

func _initialize() -> void:
	var paths: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--a="): paths["a"] = argument.trim_prefix("--a=")
		elif argument.begins_with("--b="): paths["b"] = argument.trim_prefix("--b=")
	var states: Dictionary = {}
	for key: String in paths:
		Store.set_run_storage_path(paths[key])
		states[key] = Store.load_saved_run()
	var differences := PackedStringArray()
	_diff(states.get("a", {}), states.get("b", {}), "", differences)
	print("PERF164 SAVE DIFF: %d paths%s" % [differences.size(), "" if differences.is_empty() else ": " + ", ".join(differences.slice(0, 40))])
	quit()

func _diff(a: Variant, b: Variant, path: String, out: PackedStringArray) -> void:
	if a is Dictionary and b is Dictionary:
		for key: Variant in (a as Dictionary).keys() + (b as Dictionary).keys():
			var child: String = path + "/" + str(key)
			if out.has(child): continue
			if (a as Dictionary).get(key) != (b as Dictionary).get(key): _diff((a as Dictionary).get(key), (b as Dictionary).get(key), child, out)
	elif a is Array and b is Array and (a as Array).size() == (b as Array).size():
		for index: int in range((a as Array).size()):
			if a[index] != b[index]: _diff(a[index], b[index], "%s[%d]" % [path, index], out)
	elif a != b:
		out.append("%s (%s -> %s)" % [path, str(a).left(40), str(b).left(40)])

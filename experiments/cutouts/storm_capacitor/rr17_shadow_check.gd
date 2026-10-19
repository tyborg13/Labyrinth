extends SceneTree

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.has("--baseline") or args.find("--baseline") + 1 >= args.size():
		push_error("Use -- --baseline PATH (unit_shadow_cache.res extracted from the task base)")
		quit(1)
		return
	var baseline: Resource = load(args[args.find("--baseline") + 1])
	if baseline == null:
		push_error("Cannot load requested shadow baseline")
		quit(1)
		return
	var current: Resource = load("res://assets/generated/unit_shadow_cache.res")
	var errors: Array[String]
	for key: String in baseline.entries:
		if not current.entries.has(key) or current.entries[key] != baseline.entries[key]: errors.append("Unrelated shadow changed: " + key)
	for path: String in baseline.source_sha256:
		if current.source_sha256.get(path) != baseline.source_sha256[path]: errors.append("Unrelated shadow source changed: " + path)
	for error: String in errors: push_error(error)
	print("RR17 SHADOW PRESERVATION: %s (%d existing entries unchanged)" % ["PASS" if errors.is_empty() else "FAIL", baseline.entries.size()])
	quit(0 if errors.is_empty() else 1)

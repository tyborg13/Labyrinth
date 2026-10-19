extends SceneTree

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var baseline: Resource = load("/private/tmp/labyrinth_codex/rr17_shadow_baseline.res")
	var current: Resource = load("res://assets/generated/unit_shadow_cache.res")
	var errors: Array[String]
	for key: String in baseline.entries:
		if not current.entries.has(key) or current.entries[key] != baseline.entries[key]: errors.append("Unrelated shadow changed: " + key)
	for path: String in baseline.source_sha256:
		if current.source_sha256.get(path) != baseline.source_sha256[path]: errors.append("Unrelated shadow source changed: " + path)
	for error: String in errors: push_error(error)
	print("RR17 SHADOW PRESERVATION: %s (%d existing entries unchanged)" % ["PASS" if errors.is_empty() else "FAIL", baseline.entries.size()])
	quit(0 if errors.is_empty() else 1)

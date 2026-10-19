extends "res://tools/generate_unit_shadow_cache.gd"

## Reuse extraction, update only this unit's records, retain every other entry.
const UNIT_SOURCE_PREFIX: String = "res://assets/units/glacial_mirror_cutout/"

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--check-baseline"):
		_check_baseline(args[args.find("--check-baseline") + 1])
		return
	var previous: Resource = load(DEFAULT_OUTPUT_PATH)
	var cache: Resource = previous.duplicate(true)
	var result: Dictionary = _build_cache()
	for field: String in ["entries", "source_sha256"]:
		var retained: Dictionary = {}
		var values: Dictionary = cache.get(field)
		for key: String in values.keys():
			if key.begins_with(UNIT_SOURCE_PREFIX): values.erase(key)
			else: retained[key] = values[key]
		var added: int = 0
		for key: String in result[field]:
			if key.begins_with(UNIT_SOURCE_PREFIX):
				values[key] = result[field][key]
				added += 1
		for key: String in retained:
			assert(values[key] == retained[key], "Unrelated shadow record changed: " + key)
		assert(added == 2, "Expected exactly the two v2 rest sources")
		cache.set(field, values)
	var error: Error = ResourceSaver.save(cache, DEFAULT_OUTPUT_PATH, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("RR18 shadow refresh failed: " + error_string(error))
		quit(1)
		return
	print("RR18 SHADOW RECORDS: PASS (2 v2 views; every other unit retained)")
	quit()

func _check_baseline(path: String) -> void:
	var baseline: Resource = load(path)
	var current: Resource = load(DEFAULT_OUTPUT_PATH)
	var errors: Array[String]
	for field: String in ["entries", "source_sha256"]:
		var before: Dictionary = baseline.get(field)
		var after: Dictionary = current.get(field)
		var mirror_count: int = 0
		for key: String in before:
			if key.begins_with(UNIT_SOURCE_PREFIX): continue
			if not after.has(key) or after[key] != before[key]: errors.append("Unrelated shadow changed: " + key)
		for key: String in after:
			if key.begins_with(UNIT_SOURCE_PREFIX):
				mirror_count += 1
				if field == "source_sha256" and after[key] != FileAccess.get_sha256(key): errors.append("Stale Mirror shadow source: " + key)
			elif not before.has(key): errors.append("Unrelated shadow added: " + key)
		if mirror_count != 2: errors.append("Expected exactly two Mirror shadow records: " + field)
	for error: String in errors: push_error(error)
	print("RR23 SHADOW PRESERVATION: %s (only 2 Mirror views may change; other records match pinned baseline)" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)

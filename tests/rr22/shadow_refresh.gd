extends "res://tools/generate_unit_shadow_cache.gd"

## Reuse extraction, update only this unit's records, retain every other entry.
const UNIT_SOURCE_PREFIX: String = "res://assets/units/slag_mortar_cutout/"

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
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
		push_error("RR22 shadow refresh failed: " + error_string(error))
		quit(1)
		return
	print("RR22 SHADOW RECORDS: PASS (2 v2 views; every other unit retained)")
	quit()

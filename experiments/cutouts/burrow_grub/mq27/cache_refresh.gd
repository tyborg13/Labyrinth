extends "res://tools/generate_unit_shadow_cache.gd"

## Reuse the common extractor while changing only this unit's cache records.
const OWNED_PREFIX: String = "res://assets/units/burrow_grub_cutout/"

func _initialize() -> void:
	var baseline_path: String = DEFAULT_OUTPUT_PATH
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--baseline"): baseline_path = args[args.find("--baseline") + 1]
	var cache: Resource = load(baseline_path)
	if cache == null:
		push_error("MQ27 shadow baseline could not load")
		quit(1)
		return
	var unowned: Dictionary = {}
	for key: String in cache.entries:
		if not key.begins_with(OWNED_PREFIX): unowned[key] = cache.entries[key]
	var result: Dictionary = _build_cache()
	var owned_count: int = 0
	for field: String in ["entries", "source_sha256"]:
		var records: Dictionary = cache.get(field)
		for key: String in records.keys():
			if key.begins_with(OWNED_PREFIX): records.erase(key)
		for key: String in result[field]:
			if key.begins_with(OWNED_PREFIX):
				records[key] = result[field][key]
				if field == "entries": owned_count += 1
	for key: String in unowned:
		if var_to_bytes(cache.entries[key]) != var_to_bytes(unowned[key]):
			push_error("Unowned shadow entry changed: " + key)
			quit(1)
			return
	if owned_count != 2 or ResourceSaver.save(cache, DEFAULT_OUTPUT_PATH, ResourceSaver.FLAG_COMPRESS) != OK:
		push_error("MQ27 shadow cache refresh failed")
		quit(1)
		return
	print("MQ27 SHADOW CACHE: PASS (2 views; %d unrelated entries preserved)" % unowned.size())
	quit()

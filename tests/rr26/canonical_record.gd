extends SceneTree

## Restore missing full diagnostics only when their committed hash matches.
## Copy raw pose JSON: parsing and reserializing would round tiny bone floats.
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 3:
		push_error("Use -- COMMITTED_METADATA CURRENT_FULL_SAMPLES OUTPUT_JSON")
		quit(1)
		return
	var value: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var reference: Dictionary = value.get("full_samples", value.get("full_evidence", {}))
	var expected: String = str(reference.get("sha256", value.get("full_sha256", "")))
	for field: String in ["samples", "full_samples", "full_evidence", "full_report", "full_sha256", "sample_counts", "sample_count", "inventory"]:
		value.erase(field)
	var current: String = FileAccess.get_file_as_string(args[1])
	var start: int = current.find('"samples":[') + '"samples":'.length()
	var end: int = current.rfind(',"screen_pixel_scale":')
	var metadata: String = JSON.stringify(value)
	var insertion: int = metadata.rfind('"screen_pixel_scale":')
	if expected.is_empty() or start < '"samples":'.length() or end <= start or insertion < 0:
		push_error("Expected a committed compact bone record and canonical sampler JSON")
		quit(1)
		return
	var result: String = metadata.substr(0, insertion) + '"samples":' + current.substr(start, end - start) + ',' + metadata.substr(insertion)
	var file := FileAccess.open(args[2], FileAccess.WRITE)
	file.store_string(result)
	file.close()
	var actual: String = FileAccess.get_sha256(args[2])
	print("RR26 COMMITTED RECORD RECONSTRUCTION: %s (sha256=%s; expected=%s)" % ["PASS" if actual == expected else "FAIL", actual, expected])
	quit(0 if actual == expected else 1)

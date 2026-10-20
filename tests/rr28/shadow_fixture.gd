extends SceneTree

## Corrupt a baseline copy without touching the production cache.
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output: String = args[args.find("--output") + 1]
	var mutation: String = args[args.find("--mutation") + 1]
	var cache: Resource = load("res://assets/generated/unit_shadow_cache.res").duplicate(true)
	var own: String = "res://assets/units/storm_capacitor_cutout/front/rest.png"
	match mutation:
		"other":
			for key: String in cache.entries.keys():
				if not key.begins_with("res://assets/units/storm_capacitor_cutout/"):
					cache.entries.erase(key)
			for key: String in cache.source_sha256.keys():
				if not key.begins_with("res://assets/units/storm_capacitor_cutout/"):
					cache.source_sha256.erase(key)
		"entry": cache.entries[own] = {}
		"source": cache.source_sha256[own] = "changed"
		"missing": cache.entries.erase(own)
		_:
			push_error("Unknown shadow fixture mutation")
			quit(1)
			return
	var result: Error = ResourceSaver.save(cache, output, ResourceSaver.FLAG_COMPRESS)
	print("RR28 SHADOW FIXTURE: %s" % ["PASS" if result == OK else "FAIL"])
	quit(0 if result == OK else 1)

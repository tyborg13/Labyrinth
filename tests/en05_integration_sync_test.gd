extends SceneTree

const CACHE_PATH: String = "res://assets/generated/unit_shadow_cache.res"
const MERGED_ENEMIES: Array = ["briar_weaver", "slag_mortar", "glacial_mirror", "gust_shrike", "storm_capacitor", "hollow_mimic"]
const EN05_ADDITIONS: int = 2

func _initialize() -> void:
	var failures: Array[String]
	var staged: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://spec/peer_benchmark/staged/enemies/wave_e2.json"))
	var production: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	for id: String in MERGED_ENEMIES:
		if production.get(id) != staged[id]: failures.append("Protected merged enemy data changed: " + id)
	var cache: Resource = load(CACHE_PATH)
	var base: Resource = load("res://output/en05_integration_shadow_base.res")
	if cache == null or base == null:
		failures.append("Integration shadow cache evidence cannot load")
	else:
		for key: String in base.entries:
			if cache.entries.get(key, {}) != base.entries[key]: failures.append("Integration shadow entry changed: " + key)
		for source: String in base.source_sha256:
			if cache.source_sha256.get(source, "") != base.source_sha256[source]: failures.append("Integration shadow source changed: " + source)
		for id: String in MERGED_ENEMIES:
			var path: String = "res://assets/art/enemies/%s.png" % id
			if cache.source_sha256.get(path, "") != FileAccess.get_sha256(path): failures.append("Merged shadow source missing or stale: " + id)
		if cache.entries.size() != base.entries.size() + EN05_ADDITIONS: failures.append("Expected two en-05 shadow additions after regeneration")
	for failure: String in failures: push_error(failure)
	print("EN05 INTEGRATION SYNC: %s (six protected enemy entries; integration shadows preserved; two en-05 additions)" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

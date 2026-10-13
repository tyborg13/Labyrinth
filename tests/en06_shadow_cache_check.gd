extends SceneTree
const Cache = preload("res://scripts/unit_shadow_cache_resource.gd")
var _failures: Array[String]
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Usage: en06_shadow_cache_check.gd -- <base-cache.res>")
		quit(1)
		return
	var base: Resource = load(args[0])
	var current: Resource = load("res://assets/generated/unit_shadow_cache.res")
	if base == null or current == null:
		push_error("Shadow cache cannot load")
		quit(1)
		return
	for key: String in base.entries:
		if current.entries.get(key, {}) != base.entries[key]: _failures.append("Existing shadow entry changed: " + key)
	for key: String in base.source_sha256:
		if current.source_sha256.get(key, "") != base.source_sha256[key]: _failures.append("Existing shadow source changed: " + key)
	for id: String in ["storm_capacitor", "hollow_mimic"]:
		var path: String = "res://assets/art/enemies/%s.png" % id
		if current.source_sha256.get(path, "") != FileAccess.get_sha256(path): _failures.append("New shadow source missing or stale: " + id)
	if current.entries.size() != base.entries.size() + 2: _failures.append("Expected exactly two added shadow entries")
	for failure: String in _failures: push_error(failure)
	print("EN06 SHADOW CACHE ADDITIVE CHECK: %s (%d existing entries; 2 additions)" % ["PASS" if _failures.is_empty() else "FAIL", base.entries.size()])
	quit(0 if _failures.is_empty() else 1)

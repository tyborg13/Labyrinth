extends SceneTree

## Add/replace approved sources, optionally one enemy; preserve all other records.
const Cache = preload("res://scripts/unit_shadow_cache_resource.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const APPROVED_PATH: String = "res://spec/peer_benchmark/staged/reart/approved_sources.json"
const CACHE_PATH: String = "res://assets/generated/unit_shadow_cache.res"

func _initialize() -> void:
	var approved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(APPROVED_PATH))["enemies"]
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var selected: String = ""
	if args.has("--enemy-id"):
		var index: int = args.find("--enemy-id") + 1
		if index >= args.size() or not approved.has(args[index]):
			push_error("--enemy-id requires an id from approved_sources.json")
			quit(1)
			return
		selected = args[index]
	var cache: Resource = load(CACHE_PATH)
	var board: Control = Board.new()
	var before: Dictionary = cache.entries.duplicate(true)
	var sources: Dictionary = cache.source_sha256.duplicate(true)
	var changed: Dictionary = {}
	var count: int = 0
	var expected: int = 0
	for id: String in approved:
		if not selected.is_empty() and id != selected: continue
		var paths: Array[String]
		paths.append("res://assets/art/enemies/%s.png" % id)
		if approved[id].has("rear"): paths.append("res://assets/art/enemies/%s_rear.png" % id)
		expected += paths.size()
		for path: String in paths:
			var texture: Texture2D = Assets.load_texture_source_first(path)
			var key: String = Cache.texture_key(texture)
			cache.entries[key] = board._compute_unit_shadow_data_for_image(Image.load_from_file(path))
			cache.source_sha256[path] = FileAccess.get_sha256(path)
			changed[path] = true
			count += 1
	var valid: bool = count == expected and expected > 0
	for key: String in before:
		if not changed.has(key): valid = valid and cache.entries[key] == before[key]
	for path: String in sources:
		if not changed.has(path): valid = valid and cache.source_sha256[path] == sources[path]
	if valid: valid = ResourceSaver.save(cache, CACHE_PATH, ResourceSaver.FLAG_COMPRESS) == OK
	board.free()
	print("ART SHADOW CACHE: %s (%d views; unrelated entries unchanged)" % ["PASS" if valid else "FAIL", count])
	quit(0 if valid else 1)

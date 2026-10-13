extends SceneTree

const Cache = preload("res://scripts/unit_shadow_cache_resource.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const CACHE_PATH: String = "res://assets/generated/unit_shadow_cache.res"
const ENEMIES: Array[String] = ["glacial_mirror", "gust_shrike"]

func _initialize() -> void:
	var cache: Resource = load(CACHE_PATH)
	var board: Control = Board.new()
	var previous: Dictionary = cache.entries.duplicate(true)
	var previous_sources: Dictionary = cache.source_sha256.duplicate(true)
	for id: String in ENEMIES:
		var path: String = "res://assets/art/enemies/%s.png" % id
		var key: String = Cache.texture_key(Assets.load_texture(path))
		cache.entries[key] = board._compute_unit_shadow_data_for_image(Image.load_from_file(path))
		cache.source_sha256[path] = FileAccess.get_sha256(path)
	var valid: bool = true
	for key: String in previous:
		if not key.contains("glacial_mirror") and not key.contains("gust_shrike"): valid = valid and cache.entries[key] == previous[key]
	for path: String in previous_sources:
		if not path.contains("glacial_mirror") and not path.contains("gust_shrike"): valid = valid and cache.source_sha256[path] == previous_sources[path]
	valid = valid and ResourceSaver.save(cache, CACHE_PATH, ResourceSaver.FLAG_COMPRESS) == OK
	board.free()
	print("EN05 SHADOW CACHE: %s (2 static sprites; existing entries unchanged)" % ("PASS" if valid else "FAIL"))
	quit(0 if valid else 1)

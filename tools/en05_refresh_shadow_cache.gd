extends SceneTree

const Cache = preload("res://scripts/unit_shadow_cache_resource.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const CACHE_PATH: String = "res://assets/generated/unit_shadow_cache.res"
const ENEMIES: Array[String] = ["glacial_mirror", "gust_shrike"]
const SHRIKE_REST: String = "res://assets/units/gust_shrike_cutout/front/rest.png"

func _initialize() -> void:
	var cache: Resource = load(CACHE_PATH)
	var board: Control = Board.new()
	var previous: Dictionary = cache.entries.duplicate(true)
	var previous_sources: Dictionary = cache.source_sha256.duplicate(true)
	var paths: Array[String]
	for id: String in ENEMIES: paths.append("res://assets/art/enemies/%s.png" % id)
	if preload("res://scripts/gust_shrike_cutout/renderer.gd").available(): paths.append(SHRIKE_REST)
	for path: String in paths:
		var key: String = Cache.texture_key(Assets.load_texture(path))
		cache.entries[key] = board._compute_unit_shadow_data_for_image(Image.load_from_file(path))
		cache.source_sha256[path] = FileAccess.get_sha256(path)
	var valid: bool = true
	for key: String in previous:
		if key not in paths: valid = valid and cache.entries[key] == previous[key]
	for path: String in previous_sources:
		if path not in paths: valid = valid and cache.source_sha256[path] == previous_sources[path]
	valid = valid and ResourceSaver.save(cache, CACHE_PATH, ResourceSaver.FLAG_COMPRESS) == OK
	board.free()
	print("EN05 SHADOW CACHE: %s (%d current sources; unrelated entries unchanged)" % ["PASS" if valid else "FAIL", paths.size()])
	quit(0 if valid else 1)

extends SceneTree

## Update only this unit's new rest keys; retain every other cached entry.
const Cache = preload("res://scripts/unit_shadow_cache_resource.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const PATH: String = "res://assets/generated/unit_shadow_cache.res"

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var cache: Resource = load(PATH)
	var board := Board.new()
	for view: String in ["front", "rear"]:
		var source: String = "res://assets/units/storm_capacitor_cutout/" + view + "/rest.png"
		var texture: Texture2D = Assets.load_texture_source_first(source)
		var key: String = Cache.texture_key(texture)
		cache.entries[key] = board.call("_compute_unit_shadow_data_for_image", Image.load_from_file(source))
		cache.source_sha256[key] = FileAccess.get_sha256(source)
	board.free()
	var result: Error = ResourceSaver.save(cache, PATH, ResourceSaver.FLAG_COMPRESS)
	print("RR17 SHADOW CACHE: " + ("PASS (2 rest keys; other entries retained)" if result == OK else "FAIL"))
	quit(0 if result == OK else 1)

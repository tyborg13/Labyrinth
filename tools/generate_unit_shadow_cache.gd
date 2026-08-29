extends SceneTree

const DEFAULT_OUTPUT_PATH: String = "res://assets/generated/unit_shadow_cache.res"
const CombatBoardViewScript = preload("res://scripts/combat_board_view.gd")
const UnitShadowCacheResourceScript = preload("res://scripts/unit_shadow_cache_resource.gd")

func _initialize() -> void:
	var output_path: String = DEFAULT_OUTPUT_PATH
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(user_args.size()):
		if user_args[index] == "--output" and index + 1 < user_args.size():
			output_path = user_args[index + 1]
	var result: Dictionary = _build_cache()
	var cache: Resource = UnitShadowCacheResourceScript.new()
	cache.schema_version = UnitShadowCacheResourceScript.SCHEMA_VERSION
	cache.extraction_signature = UnitShadowCacheResourceScript.expected_extraction_signature()
	cache.entries = result.get("entries", {}) as Dictionary
	cache.source_sha256 = result.get("source_sha256", {}) as Dictionary
	var save_error: Error = ResourceSaver.save(cache, output_path, ResourceSaver.FLAG_COMPRESS)
	if save_error != OK:
		push_error("UNIT SHADOW CACHE GENERATION FAILED: %s" % error_string(save_error))
		quit(1)
		return
	print("UNIT SHADOW CACHE GENERATED: %s entries=%d sources=%d" % [
		output_path,
		cache.entries.size(),
		cache.source_sha256.size(),
	])
	quit()

func _build_cache() -> Dictionary:
	var board: Control = CombatBoardViewScript.new()
	var unit_types: Array[String] = []
	unit_types.append("player")
	for enemy_type_var: Variant in GameData.enemies().keys():
		var enemy_type: String = str(enemy_type_var)
		if not enemy_type.is_empty() and not unit_types.has(enemy_type):
			unit_types.append(enemy_type)
	for npc_type_var: Variant in GameData.npcs().keys():
		var npc_type: String = str(npc_type_var)
		if not npc_type.is_empty() and not unit_types.has(npc_type):
			unit_types.append(npc_type)
	unit_types.sort()
	for unit_type: String in unit_types:
		board.call("_ensure_unit_assets_for_type", unit_type)
	var textures: Array[Texture2D] = []
	for unit_type: String in unit_types:
		_append_unique_texture(textures, (board.get("_unit_textures") as Dictionary).get(unit_type, null) as Texture2D)
		for texture_var: Variant in (board.get("_idle_frames_by_type") as Dictionary).get(unit_type, []):
			if texture_var is Texture2D:
				_append_unique_texture(textures, texture_var as Texture2D)
		for texture_var: Variant in (board.get("_death_frames_by_type") as Dictionary).get(unit_type, []):
			if texture_var is Texture2D:
				_append_unique_texture(textures, texture_var as Texture2D)
	var entries: Dictionary = {}
	var source_sha256: Dictionary = {}
	for texture: Texture2D in textures:
		var key: String = UnitShadowCacheResourceScript.texture_key(texture)
		if key.is_empty() or entries.has(key):
			continue
		var image: Image = texture.get_image()
		entries[key] = {
			"shadow_data": board.call("_unit_shadow_data_for_texture", texture),
			"used_rect": image.get_used_rect() if image != null and not image.is_empty() else Rect2i(),
		}
		var source_path: String = UnitShadowCacheResourceScript.source_path(texture)
		if not source_path.is_empty() and not source_sha256.has(source_path):
			source_sha256[source_path] = FileAccess.get_sha256(source_path)
	return {
		"entries": entries,
		"source_sha256": source_sha256,
	}

func _append_unique_texture(textures: Array[Texture2D], texture: Texture2D) -> void:
	if texture != null and not textures.has(texture):
		textures.append(texture)

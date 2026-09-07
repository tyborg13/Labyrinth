extends SceneTree

const Board = preload("res://scripts/combat_board_view.gd")
const GameData = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ASSET_FIELDS: Array = [
	"_tile_textures", "_floor_texture_variants", "_element_overlay_texture_variants",
	"_prop_textures", "_scene_prop_textures", "_scene_prop_idle_frames", "_pillar_torch_idle_frames",
	"_pillar_torch_light_texture", "_effect_textures", "_effect_frames", "_projectile_atlas", "_projectile_textures",
	"_ambient_particle_atlas", "_ambient_particle_glow_atlas", "_ambient_fire_soft_atlas",
	"_ambient_air_wisp_atlas", "_ambient_air_wisp_soft_atlas", "_ambient_air_wisp_glow_atlas",
	"_ambient_particle_textures", "_ambient_particle_glow_textures", "_ambient_fire_soft_textures",
	"_ambient_air_wisp_textures", "_ambient_air_wisp_soft_textures", "_ambient_air_wisp_glow_textures",
	"_ambient_combined_atlas", "_loot_textures", "_terrain_textures", "_terrain_destruction_frames_by_kind",
	"_unit_textures", "_unit_assets_loaded", "_element_textures", "_trap_textures", "_trap_idle_frames",
	"_trap_activation_frames", "_door_icon_textures", "_keyword_icon_textures", "_health_bar_frame_textures",
	"_door_opening_frames", "_door_opening_flipped_frames", "_idle_frames_by_type", "_death_frames_by_type",
	"_unit_shadow_precomputed_entries", "_unit_shadow_precomputed_source_sha256",
	"_unit_shadow_precomputed_loaded_keys", "_unit_shadow_precomputed_missing_keys"
]
var _errors: Array[String]
var _fingerprints: Dictionary = {}
var _present_count: int = 0

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var sync := Board.new()
	sync.call("_load_assets", false)
	sync.call("_ensure_ambient_combined_atlas")
	await _present_frame()
	var initial: Dictionary = _manifest(sync)
	var supports_staging: bool = sync.has_method("prepare_initial_assets_for")
	var async_board := Board.new()
	if supports_staging:
		await async_board.get_script().call("prepare_initial_assets_for", async_board, _present_frame, true)
		await _present_frame()
		_expect(_manifest(async_board) == initial, "Staged assets must exactly match synchronous pixels, regions, order and metadata")
		var prepared_atlas: Texture2D = async_board.get("_ambient_combined_atlas")
		var prepared_frames: Array = (async_board.get("_door_opening_frames") as Array).duplicate()
		var presents_before: int = _present_count
		await async_board.get_script().call("prepare_initial_assets_for", async_board, _present_frame, true)
		_expect(_present_count == presents_before, "Repeated preparation must perform no loading slices")
		async_board.size = Vector2(1920, 1080)
		root.add_child(async_board)
		await _present_frame()
		_expect(async_board.get("_ambient_combined_atlas") == prepared_atlas and async_board.get("_door_opening_frames") == prepared_frames, "Ready must retain prepared generated texture identities")
		for layer: Control in async_board.call("_retained_render_layers"):
			_expect(layer.get("_ambient_combined_atlas") == prepared_atlas, "Retained layers must reuse the owner's prepared atlas")
			_expect(is_same(layer.get("_ambient_combined_atlas_regions"), async_board.get("_ambient_combined_atlas_regions")), "Retained layers must share the matching region map")
		async_board.free()
	else:
		async_board.free()
	for type: String in GameData.enemies(): sync.call("_ensure_unit_assets_for_type", type)
	for type: String in GameData.npcs(): sync.call("_ensure_unit_assets_for_type", type)
	await _present_frame()
	var roster: Dictionary = _manifest(sync)
	print("BOARD STARTUP MANIFEST RESULT: %s" % JSON.stringify({"initial": initial, "full_roster": roster, "staging_supported": supports_staging, "presented_slices": _present_count, "semantic_errors": _errors}))
	sync.free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)

func _manifest(board: Control) -> Dictionary:
	var result: Dictionary = {}
	for field: String in ASSET_FIELDS:
		result[field] = _value(board.get(field))
	# These maps use process-specific Texture2D IDs. Resolve them through the
	# semantic texture fingerprints collected above, preserving every entry.
	for field: String in ["_ambient_combined_atlas_regions", "_unit_shadow_polygon_cache", "_unit_shadow_bottom_ratio_cache", "_texture_used_rect_cache"]:
		var normalized: Dictionary = {}
		for id: Variant in board.get(field):
			var object: Object = instance_from_id(int(id))
			var key: String = JSON.stringify(_value(object)) if object is Texture2D else str(id)
			normalized[key] = _value((board.get(field) as Dictionary)[id])
		result[field] = normalized
	return result

func _value(value: Variant) -> Variant:
	if value is Texture2D:
		var texture: Texture2D = value
		var id: int = texture.get_instance_id()
		if _fingerprints.has(id): return _fingerprints[id]
		var pixels: Image = texture.get_image()
		var fingerprint: Dictionary = {"size": str(texture.get_size()), "format": int(pixels.get_format()), "pixels_sha256": pixels.get_data().hex_encode().sha256_text()}
		if texture is AtlasTexture:
			fingerprint["atlas"] = _value((texture as AtlasTexture).atlas)
			fingerprint["region"] = str((texture as AtlasTexture).region)
			fingerprint["margin"] = str((texture as AtlasTexture).margin)
			fingerprint["filter_clip"] = (texture as AtlasTexture).filter_clip
		_fingerprints[id] = fingerprint
		return fingerprint
	if value is Dictionary:
		var result: Dictionary = {}
		var keys: Array = value.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key: Variant in keys: result[str(key)] = _value(value[key])
		return result
	if value is Array:
		var result: Array = []
		for child: Variant in value: result.append(_value(child))
		return result
	if value == null or value is bool or value is String or value is int or value is float: return value
	return var_to_str(value)

func _present_frame() -> void:
	_present_count += 1
	if DisplayServer.get_name() == "headless": await process_frame
	else: await RenderingServer.frame_post_draw

func _expect(condition: bool, message: String) -> void:
	if not condition: _errors.append(message)

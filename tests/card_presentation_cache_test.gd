extends SceneTree

const Card = preload("res://scripts/card_widget.gd")
const Cache = preload("res://scripts/card_presentation_cache.gd")
const Elements = preload("res://scripts/element_data.gd")

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var cache: Resource = load(Cache.PATH)
	assert(cache != null and cache.entries.size() == 35, "Generated cache must cover every frame and role image")
	var card := Card.new()
	var emblem := Card.DebossedRoleEmblem.new()
	var checked: int = 0
	for key: String in cache.entries:
		var parts: PackedStringArray = key.split("|")
		var role: bool = key.begins_with("emblem|")
		var path: String = parts[1] if role else parts[0]
		assert(FileAccess.get_sha256(path) == str(cache.source_sha256[path]), "Generated cache must match current authored source bytes")
		var source: Image = Image.load_from_file(path)
		var expected: Image = emblem.call("_build_masked_emblem_image", source) if role else card.call("_build_elemental_frame_image", source, parts[1])
		var signature: String = emblem.call("_transform_signature") if role else card.call("_frame_transform_signature", parts[1])
		var prepared: Texture2D = Cache.texture(key, path, signature)
		assert(prepared != null, "Current image must use the generated artifact")
		var actual: Image = prepared.get_image()
		assert(actual.get_size() == expected.get_size() and actual.get_format() == expected.get_format(), "Prepared image dimensions/format must exactly match authored fallback")
		assert(actual.get_data() == expected.get_data(), "Every generated pixel must equal the authored runtime transform")
		assert(Cache.texture(key, path, signature, source) == prepared, "Explicit raw image must reuse its exact cached texture")
		var imported: Image = source.duplicate()
		imported.fix_alpha_edges()
		var expected_imported: Image = emblem.call("_build_masked_emblem_image", imported) if role else card.call("_build_elemental_frame_image", imported, parts[1])
		var prepared_imported: Texture2D = Cache.texture(key, path, signature, imported)
		assert(prepared_imported != null and prepared_imported.get_image().get_data() == expected_imported.get_data(), "Imported source must preserve every fallback pixel")
		assert(Cache.texture(key, path, signature, source) == prepared, "Imported lookup must not replace the raw variant")
		var unknown: Image = source.duplicate()
		unknown.set_pixel(0, 0, Color.MAGENTA)
		assert(Cache.texture(key, path, signature, unknown) == null, "Unrecognized import processing must use live fallback")
		assert(Cache.texture(key, path, "changed algorithm") == null, "Changed transform signature must fall back")
		checked += 1
	var key: String = "res://assets/art/ui/card_frame_rarity_common.png|fire"
	var path: String = key.split("|")[0]
	var saved: Resource = Cache._loaded
	var changed: Resource = saved.duplicate(true)
	changed.source_sha256[path] = "stale source"
	Cache._loaded = changed
	Cache._valid_sources.clear()
	assert(Cache.texture(key, path, card.call("_frame_transform_signature", "fire")) == null, "Stale source art must never use generated pixels")
	changed = saved.duplicate(true)
	changed.version = Cache.VERSION + 1
	Cache._loaded = changed
	Cache._valid_sources.clear()
	assert(Cache.texture(key, path, card.call("_frame_transform_signature", "fire")) == null, "Unknown artifact versions must fall back")
	changed = saved.duplicate(true)
	changed.entries[key]["png"] = PackedByteArray([0, 1, 2, 3, 4, 5, 6, 7])
	Cache._loaded = changed
	Cache._textures.erase(key)
	assert(Cache.texture(key, path, card.call("_frame_transform_signature", "fire")) == null, "Corrupt PNG headers must fall back")
	changed = saved.duplicate(true)
	changed.entries[key]["imported_png"] = PackedByteArray([0, 1, 2, 3, 4, 5, 6, 7])
	Cache._loaded = changed
	Cache._textures.erase(key + "|imported")
	var imported_source: Image = Image.load_from_file(path)
	imported_source.fix_alpha_edges()
	assert(Cache.texture(key, path, card.call("_frame_transform_signature", "fire"), imported_source) == null, "Corrupt imported PNG headers must fall back")
	Cache._loaded = null
	assert(Cache.texture(key, path, card.call("_frame_transform_signature", "fire")) == null, "Missing artifact must fall back")
	var fallback: Texture2D = card.call("_card_frame_texture", "common", "fire")
	var source_texture: Texture2D = preload("res://scripts/asset_loader.gd").load_texture(path)
	var expected_fallback: Image = card.call("_build_elemental_frame_image", source_texture.get_image(), "fire")
	assert(fallback.get_image().get_data() == expected_fallback.get_data(), "Missing artifact must still produce exact authored frame pixels")
	Cache._loaded = saved
	Cache._valid_sources.clear()
	assert(Cache.texture("new ungenerated image", path, "frame_v1") == null, "New art must retain live generation fallback")
	card.free()
	emblem.free()
	print("TEST RESULT: PASS card presentation cache %d raw and imported byte-identical images, source and algorithm invalidation" % checked)
	quit()

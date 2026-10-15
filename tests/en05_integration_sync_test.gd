extends SceneTree

const Cache = preload("res://scripts/unit_shadow_cache_resource.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Data = preload("res://scripts/game_data.gd")
const Hero = preload("res://scripts/protagonist_cutout/renderer.gd")
const CACHE_PATH: String = "res://assets/generated/unit_shadow_cache.res"
const BASE_PATH: String = "user://en05_integration_shadow_base.res"
const MERGED_ENEMIES: Array = ["briar_weaver", "slag_mortar", "glacial_mirror", "gust_shrike", "storm_capacitor", "hollow_mimic"]
const EN05_SOURCES: Array = ["res://assets/art/enemies/glacial_mirror.png", "res://assets/art/enemies/gust_shrike.png"]
const EN05_ADDITIONS: int = 2
var _failures: Array[String]

func _initialize() -> void:
	var staged: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://spec/peer_benchmark/staged/enemies/wave_e2.json"))
	var production: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	for id: String in MERGED_ENEMIES:
		var expected: Dictionary = staged[id].duplicate(true)
		if id == "gust_shrike":
			# Art-04's approved presentation delta; every other field stays exact.
			expected["art_scale"] = 0.75
			expected["art_rear_path"] = "res://assets/art/enemies/gust_shrike_rear.png"
		if id == "storm_capacitor":
			for intent: Dictionary in expected["intents"]:
				if intent["id"] == "discharge": intent["name"] = "Arc Burst"
		if production.get(id) != expected: _failures.append("Protected merged enemy data changed: " + id)
	var cache: Resource = load(CACHE_PATH)
	# Rebuild from registered source images, never by copying the cache under test.
	# Current presentation (including art-04 rear views) replaces the lost one-off
	# integration snapshot; only the two original en-05 front sources are omitted.
	var base: Resource = _regenerate_base()
	if ResourceSaver.save(base, BASE_PATH, ResourceSaver.FLAG_COMPRESS) != OK:
		_failures.append("Cannot save regenerated integration shadow fixture")
	else:
		base = ResourceLoader.load(BASE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if cache == null or base == null:
		_failures.append("Integration shadow cache evidence cannot load")
	else:
		if cache.schema_version != Cache.SCHEMA_VERSION or cache.extraction_signature != Cache.expected_extraction_signature():
			_failures.append("Integration shadow schema or extraction signature is stale")
		for key: String in base.entries:
			if cache.entries.get(key, {}) != base.entries[key]: _failures.append("Integration shadow entry changed: " + key)
		for source: String in base.source_sha256:
			if cache.source_sha256.get(source, "") != base.source_sha256[source]: _failures.append("Integration shadow source changed: " + source)
		for id: String in MERGED_ENEMIES:
			var path: String = "res://assets/art/enemies/%s.png" % id
			if cache.source_sha256.get(path, "") != FileAccess.get_sha256(path): _failures.append("Merged shadow source missing or stale: " + id)
		var board: Control = Board.new()
		for path: String in EN05_SOURCES:
			if cache.entries.get(path, {}) != board._compute_unit_shadow_data_for_image(Image.load_from_file(path)):
				_failures.append("En-05 shadow entry missing or stale: " + path)
		board.free()
		if cache.entries.size() != base.entries.size() + EN05_ADDITIONS: _failures.append("Expected two en-05 shadow additions after regeneration")
	for failure: String in _failures: push_error(failure)
	print("EN05 INTEGRATION SYNC: %s (six protected enemy entries; integration shadows preserved; two en-05 additions)" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)

func _regenerate_base() -> Resource:
	var base: Resource = Cache.new()
	base.extraction_signature = Cache.expected_extraction_signature()
	var board: Control = Board.new()
	var unit_types: Array[String]
	unit_types.append("player")
	for id: String in Data.enemies():
		unit_types.append(id)
	for id: String in Data.npcs():
		if not unit_types.has(id): unit_types.append(id)
	unit_types.sort()
	var textures: Array[Texture2D]
	textures.append(Assets.load_texture_source_first(Hero.REST_PATH))
	if FileAccess.file_exists(Hero.DEFAULT_GEAR_REST_PATH):
		textures.append(Assets.load_texture_source_first(Hero.DEFAULT_GEAR_REST_PATH))
	for id: String in unit_types:
		board._ensure_unit_assets_for_type(id)
		textures.append(board._unit_textures.get(id))
		textures.append(board._unit_rear_textures.get(id))
		for field: String in ["_idle_frames_by_type", "_death_frames_by_type"]:
			for texture: Texture2D in board.get(field).get(id, []):
				textures.append(texture)
	var images: Dictionary = {}
	for texture: Texture2D in textures:
		var key: String = Cache.texture_key(texture)
		var source: String = Cache.source_path(texture)
		if key.is_empty() or base.entries.has(key) or source in EN05_SOURCES: continue
		if not images.has(source): images[source] = Image.load_from_file(source)
		var image: Image = images[source]
		if image == null or image.is_empty():
			_failures.append("Cannot decode integration shadow source: " + source)
			continue
		if texture is AtlasTexture:
			if texture.margin != Rect2(): _failures.append("Unsupported shadow atlas margin: " + key)
			image = image.get_region(Rect2i(texture.region))
		base.entries[key] = board._compute_unit_shadow_data_for_image(image)
		base.source_sha256[source] = FileAccess.get_sha256(source)
	board.free()
	return base

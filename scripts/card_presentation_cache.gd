extends Resource

# Generated, lossless results of CardWidget's authored pixel transforms. Decode
# only the requested image; never allocate every cached GPU texture at startup.
# Regenerate with tools/generate_card_presentation_cache.gd after art or formula
# edits. Bump frame_v1/emblem_v1 when any transform formula or hardcoded
# coefficient changes; parameter/source fingerprints alone cannot detect code edits.
# The equivalence test checks every cached byte against the live fallback.
const PATH: String = "res://assets/generated/card_presentation_cache.res"
const VERSION: int = 2
@export var version: int = VERSION
@export var entries: Dictionary = {}
@export var source_sha256: Dictionary = {}
@export var source_image_sha256: Dictionary = {}

static var _loaded: Resource
static var _load_attempted: bool = false
static var _valid_sources: Dictionary = {}
static var _textures: Dictionary = {}

static func texture(key: String, source_path: String, signature: String, source_image: Image = null) -> Texture2D:
	if not _load_attempted:
		_load_attempted = true
		if ResourceLoader.exists(PATH): _loaded = load(PATH)
	if _loaded == null or int(_loaded.get("version")) != VERSION: return null
	var entry: Dictionary = (_loaded.get("entries") as Dictionary).get(key, {}) as Dictionary
	if str(entry.get("signature", "")) != signature: return null
	if not _valid_sources.has(source_path):
		# Source files are available in repository launches. Exported imports can
		# omit them, in which case the packaged, versioned artifact is authoritative.
		var expected: String = str((_loaded.get("source_sha256") as Dictionary).get(source_path, ""))
		_valid_sources[source_path] = not expected.is_empty() and (not FileAccess.file_exists(source_path) or FileAccess.get_sha256(source_path) == expected)
	if not bool(_valid_sources[source_path]): return null
	if source_image == null and not FileAccess.file_exists(source_path): return null
	var variant: String = "raw"
	if source_image != null:
		var fingerprints: Dictionary = (_loaded.get("source_image_sha256") as Dictionary).get(source_path, {}) as Dictionary
		var fingerprint: String = image_fingerprint(source_image)
		if fingerprint == str(fingerprints.get("raw", "")):
			variant = "raw"
		elif fingerprint == str(fingerprints.get("imported", "")):
			variant = "imported"
		else:
			# Different import processing/compression must retain the live transform.
			return null
	var texture_key: String = key if variant == "raw" else key + "|imported"
	if _textures.has(texture_key): return _textures[texture_key] as Texture2D
	# Identical raw/imported results share one PNG (all current role emblems).
	var bytes: PackedByteArray = entry.get("imported_png", entry.get("png", PackedByteArray())) if variant == "imported" else entry.get("png", PackedByteArray())
	# Reject missing/truncated/corrupt header bytes without invoking the decoder.
	if bytes.size() < 8 or bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]): return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK or image.is_empty(): return null
	var prepared: Texture2D = ImageTexture.create_from_image(image)
	_textures[texture_key] = prepared
	return prepared

static func image_fingerprint(image: Image) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes([image.get_width(), image.get_height(), image.get_format(), image.has_mipmaps()]))
	context.update(image.get_data())
	return context.finish().hex_encode()

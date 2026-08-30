class_name UnitShadowCacheResource
extends Resource

const SCHEMA_VERSION: int = 2
const EXTRACTION_ALGORITHM_VERSION: String = "alpha_polygon_local_bounds_v1"
const ALPHA_THRESHOLD: float = 0.08
const SIMPLIFY_EPSILON: float = 3.0
const RETRY_SIMPLIFY_EPSILON: float = 0.75
const MIN_ALPHA_POLYGON_AREA: float = 8.0

@export var schema_version: int = SCHEMA_VERSION
@export var extraction_signature: String = ""
@export var entries: Dictionary = {}
@export var source_sha256: Dictionary = {}

static func expected_extraction_signature() -> String:
	return "%s|alpha=%.3f|simplify=%.3f|retry=%.3f|min_area=%.3f" % [
		EXTRACTION_ALGORITHM_VERSION,
		ALPHA_THRESHOLD,
		SIMPLIFY_EPSILON,
		RETRY_SIMPLIFY_EPSILON,
		MIN_ALPHA_POLYGON_AREA,
	]

static func texture_key(texture: Texture2D) -> String:
	if texture == null:
		return ""
	if texture is AtlasTexture:
		var atlas_texture: AtlasTexture = texture as AtlasTexture
		var atlas: Texture2D = atlas_texture.atlas
		var atlas_path: String = _texture_source_identity(atlas)
		var region: Rect2 = atlas_texture.region
		var margin: Rect2 = atlas_texture.margin
		return "%s|atlas:%.3f,%.3f,%.3f,%.3f|margin:%.3f,%.3f,%.3f,%.3f" % [
			atlas_path,
			region.position.x,
			region.position.y,
			region.size.x,
			region.size.y,
			margin.position.x,
			margin.position.y,
			margin.size.x,
			margin.size.y,
		]
	return _texture_source_identity(texture)

static func source_path(texture: Texture2D) -> String:
	if texture == null:
		return ""
	if texture is AtlasTexture:
		var atlas: Texture2D = (texture as AtlasTexture).atlas
		return _texture_source_identity(atlas)
	return _texture_source_identity(texture)

static func _texture_source_identity(texture: Texture2D) -> String:
	if texture == null:
		return ""
	var tagged_path: String = str(texture.get_meta("asset_source_path", ""))
	return tagged_path if not tagged_path.is_empty() else texture.resource_path

extends SceneTree

## Refresh only rr-01 crawler sources, including any existing atlas records.
## Run again after native rest rebake. --check is read-only.
const Cache = preload("res://scripts/unit_shadow_cache_resource.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const CACHE_PATH: String = "res://assets/generated/unit_shadow_cache.res"
# Proof-only original cache exported from the fixed Git baseline.
const PROOF_BEFORE_CACHE: String = "res://output/rr-01/before/unit_shadow_cache.res"
const OWNED_SOURCES = [
	"res://assets/units/crawler_cutout/front/rest.png",
	"res://assets/units/crawler_cutout/rear/rest.png",
	"res://assets/placeholders/units/crawler_anime_trial.png",
	"res://assets/placeholders/units/crawler_anime_trial_idle.png",
]
var _errors: Array[String]

func _initialize() -> void:
	var cache: Resource = load(CACHE_PATH)
	if cache == null:
		push_error("Crawler shadow cache is missing")
		quit(1)
		return
	var check_only: bool = OS.get_cmdline_user_args().has("--check")
	var board: Control = Board.new()
	var before: Dictionary = cache.entries.duplicate(true)
	var before_sources: Dictionary = cache.source_sha256.duplicate(true)
	var expected: Dictionary = {}
	var expected_sources: Dictionary = {}
	for key: String in before:
		var path: String = key.get_slice("|", 0)
		if not OWNED_SOURCES.has(path):
			continue
		var image: Image = Image.load_from_file(path)
		if image == null:
			_errors.append("Missing crawler shadow source: " + path)
			continue
		if key.contains("|atlas:"):
			var rect: PackedStringArray = key.get_slice("|atlas:", 1).get_slice("|", 0).split(",")
			if rect.size() != 4 or not key.ends_with("|margin:0.000,0.000,0.000,0.000"):
				_errors.append("Unsupported crawler atlas key: " + key)
				continue
			image = image.get_region(Rect2i(roundi(float(rect[0])), roundi(float(rect[1])),
				roundi(float(rect[2])), roundi(float(rect[3]))))
		expected[key] = board.call("_compute_unit_shadow_data_for_image", image)
		expected_sources[path] = FileAccess.get_sha256(path)
	# Rest silhouettes are the current cutout's cache sources; add rear coverage
	# without regenerating any other unit or obsolete crawler animation family.
	for path: String in OWNED_SOURCES.slice(0, 2):
		var image: Image = Image.load_from_file(path)
		if image == null:
			_errors.append("Missing crawler rest: " + path)
			continue
		expected[path] = board.call("_compute_unit_shadow_data_for_image", image)
		expected_sources[path] = FileAccess.get_sha256(path)
	if check_only:
		for key: String in expected:
			if cache.entries.get(key) != expected[key]: _errors.append("Stale crawler shadow entry: " + key)
		for path: String in expected_sources:
			if cache.source_sha256.get(path) != expected_sources[path]: _errors.append("Stale crawler shadow source: " + path)
	else:
		cache.entries.merge(expected, true)
		cache.source_sha256.merge(expected_sources, true)
		for key: String in before:
			if not expected.has(key) and cache.entries[key] != before[key]: _errors.append("Unrelated cache entry changed: " + key)
		for path: String in before_sources:
			if not expected_sources.has(path) and cache.source_sha256[path] != before_sources[path]: _errors.append("Unrelated cache source changed: " + path)
		if _errors.is_empty() and ResourceSaver.save(cache, CACHE_PATH, ResourceSaver.FLAG_COMPRESS) != OK:
			_errors.append("Could not save crawler shadow cache")
	if FileAccess.file_exists(PROOF_BEFORE_CACHE):
		var baseline: Resource = load(PROOF_BEFORE_CACHE)
		var shipped: Resource = ResourceLoader.load(CACHE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		_expect_unrelated_unchanged(baseline, shipped)
	board.free()
	for message: String in _errors: push_error(message)
	print("RR01 CRAWLER SHADOW CACHE: %s (%s; %d entries; unrelated records preserved)" %
		["PASS" if _errors.is_empty() else "FAIL", "check" if check_only else "refresh", expected.size()])
	quit(0 if _errors.is_empty() else 1)

func _expect_unrelated_unchanged(baseline: Resource, shipped: Resource) -> void:
	if baseline == null or shipped == null:
		_errors.append("Could not load original/shipped shadow cache comparison")
		return
	if baseline.schema_version != shipped.schema_version or baseline.extraction_signature != shipped.extraction_signature:
		_errors.append("Shadow cache schema or extraction changed")
	for field: String in ["entries", "source_sha256"]:
		var original: Dictionary = baseline.get(field) as Dictionary
		var current: Dictionary = shipped.get(field) as Dictionary
		for key: String in original:
			if not OWNED_SOURCES.has(key.get_slice("|", 0)) and current.get(key) != original[key]:
				_errors.append("Unrelated shipped %s changed: %s" % [field, key])
		for key: String in current:
			if not original.has(key) and not OWNED_SOURCES.has(key.get_slice("|", 0)):
				_errors.append("Unrelated shipped %s added: %s" % [field, key])

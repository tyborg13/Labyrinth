extends RefCounted

## Frozen launch choice. No filtering, hashing or work in the draw/pose loop.
## The generated manifest is the single scope authority shared with the builder.
static var mode: String = _launch_mode()
static var _warned: bool = false
static var _files: Dictionary = _read_manifest()

static func _launch_mode() -> String:
	var value: String = OS.get_environment("LABYRINTH_CEL_LOOK")
	if not OS.has_environment("LABYRINTH_CEL_LOOK"): return "all"
	return value if value in ["actors", "all"] else "off"

static func _read_manifest() -> Dictionary:
	if mode == "off": return {}
	var path: String = "res://cel_look_variants/manifest.json"
	if not FileAccess.file_exists(path):
		warn_missing("manifest.json; run python3 tools/cel_look.py build")
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		warn_missing("invalid manifest.json")
		return {}
	return data.get("files", {})

static func variant_path(path: String) -> String:
	if mode == "off" or not path.begins_with("res://"): return ""
	var relative: String = path.trim_prefix("res://")
	var scope: String = str(_files.get(relative, "off"))
	if scope == "off" or (scope == "all" and mode != "all"): return ""
	var variant: String = "res://cel_look_variants/" + relative + ".celpng"
	if FileAccess.file_exists(variant): return variant
	warn_missing(relative)
	return ""

static func warn_missing(path: String) -> void:
	if _warned: return
	_warned = true
	push_warning("Cel look variant unavailable (%s); using original art." % path)

extends RefCounted

## Mirrors the Python input manifest, never hashes proof outputs into themselves.
static func for_case(directory: String) -> Dictionary:
	var result: Dictionary = {}
	_collect(directory, directory, "", result, ["json", "png"])
	for folder: String in ["tools/humanoid_cutout", "scripts/maquette_cutout_runtime", "tests/rr10"]:
		_collect("res://" + folder, "res://", "runtime:", result, ["gd", "py", "json"])
	return result

static func _collect(directory: String, base: String, prefix: String, result: Dictionary, extensions: Array) -> void:
	var access := DirAccess.open(directory)
	for name: String in access.get_files():
		if name.get_extension() in extensions:
			var path: String = directory.path_join(name)
			result[prefix + path.trim_prefix(base.trim_suffix("/") + "/")] = FileAccess.get_sha256(path)
	for name: String in access.get_directories():
		if name in ["proof", "__pycache__"]: continue
		_collect(directory.path_join(name), base, prefix, result, extensions)

extends RefCounted

## Mirrors the Python input manifest, never hashes proof outputs into themselves.
static func for_case(directory: String) -> Dictionary:
	var result: Dictionary = {}
	var anatomy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("anatomy.json")))
	var integration: Dictionary = anatomy["integration"]
	_collect(directory, directory, "", result, ["json", "png"])
	for folder: String in integration["binding_folders"]:
		_collect("res://" + folder, "res://", "runtime:", result, ["gd", "py", "json"])
	if integration["production_root"] == null: return result
	var production: String = "res://" + str(integration["production_root"])
	_collect(production.path_join(integration["rig_directory"]), "res://", "production:", result, ["json", "png"])
	for name: String in integration["binding_files"]:
		var path: String = production.path_join(name)
		result["production:" + path.trim_prefix("res://")] = FileAccess.get_sha256(path)
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

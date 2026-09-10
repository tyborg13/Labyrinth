extends RefCounted

## Bind native gameplay/assembly evidence to the complete production render inputs.
static func capture() -> Dictionary:
	var result: Dictionary = {}
	for folder: String in ["scripts", "scenes", "data", "shaders", "assets"]:
		_collect("res://" + folder, result)
	for path: String in ["res://project.godot", "res://tests/chainbound_gaoler_cutout_gameplay_probe.gd", "res://tests/chainbound_gaoler_cutout_asset_probe.gd", "res://tests/chainbound_gaoler_proof_inputs.gd"]:
		result[path] = FileAccess.get_sha256(path)
	return result

static func _collect(folder: String, result: Dictionary) -> void:
	for file: String in DirAccess.get_files_at(folder):
		if file.get_extension() in ["gd", "tscn", "json", "gdshader", "png", "ttf", "otf", "res", "import"]:
			var path: String = folder.path_join(file)
			result[path] = FileAccess.get_sha256(path)
	for child: String in DirAccess.get_directories_at(folder):
		_collect(folder.path_join(child), result)

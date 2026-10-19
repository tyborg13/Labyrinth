extends "res://tests/rr11/native_capture.gd"

## Thrall-only evidence extension; rendering stays in the shared probe.
func _run() -> void:
	await super._run()
	if OS.get_cmdline_user_args().has("--validate-only") or DisplayServer.get_name() == "headless":
		return
	if output.is_empty() or not FileAccess.file_exists(output.path_join("frames.json")):
		return
	var manifest_path: String = output.path_join("frames.json")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	for piece: Dictionary in manifest["pieces"]:
		piece["sha256"] = FileAccess.get_sha256(path(str(piece["file"])))
		piece["checks_sha256"] = FileAccess.get_sha256(path(str(piece["checks"])))
	var evidence := FileAccess.open(manifest_path, FileAccess.WRITE)
	evidence.store_string(JSON.stringify(manifest))

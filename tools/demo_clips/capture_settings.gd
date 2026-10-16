extends RefCounted

static func snapshot() -> Dictionary:
	# Godot 4.6 renamed the active AVI quality setting. Both keys are set in
	# the startup override, before the built-in writer caches its settings.
	var version: Dictionary = Engine.get_version_info()
	var key: String = "editor/movie_writer/video_quality" if int(version["minor"]) >= 6 else "editor/movie_writer/mjpeg_quality"
	return {
		"engine": version["string"],
		"mjpeg_quality": ProjectSettings.get_setting("editor/movie_writer/mjpeg_quality", -1.0),
		"effective_quality_setting": key,
		"effective_quality": ProjectSettings.get_setting(key, -1.0),
		"override_path": ProjectSettings.globalize_path("res://override.cfg"),
	}

static func verified(settings: Dictionary) -> bool:
	return float(settings["mjpeg_quality"]) == 1.0 and float(settings["effective_quality"]) == 1.0

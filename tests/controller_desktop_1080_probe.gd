extends "res://tests/steam_deck_compat_probe.gd"

func _probe_output_dir() -> String:
	return "user://probes/controller_desktop_1080_v1"

func _probe_physical_size() -> Vector2i:
	return Vector2i(1920, 1080)

func _probe_logical_size() -> Vector2i:
	return Vector2i(1920, 1080)

func _probe_requires_handheld_output() -> bool:
	return false

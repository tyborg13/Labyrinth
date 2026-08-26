extends "res://tests/steam_deck_compat_probe.gd"

func _probe_output_dir() -> String:
	return "user://probes/steam_deck_720p_stress_v1"

func _probe_physical_size() -> Vector2i:
	return Vector2i(1280, 720)

func _probe_logical_size() -> Vector2i:
	return Vector2i(1670, 939)

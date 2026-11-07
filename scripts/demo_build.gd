extends RefCounted

const DEMO_APP_NAME := "Escape the Umbra Demo"

static func is_demo() -> bool:
	return OS.has_feature("demo") or (OS.has_feature("editor") and OS.get_environment("LABYRINTH_DEMO") == "1")

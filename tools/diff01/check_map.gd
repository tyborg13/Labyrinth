extends SceneTree
const AUDIT_SEED: int = 7
const AUDIT_SECTION: int = 3
const AUDIT_DEPTH_BAND: int = 2
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var state: Dictionary = preload("res://scripts/run_engine.gd").new().create_new_run(AUDIT_SEED, preload("res://scripts/progression_store.gd").default_data(), true)
	for room: Dictionary in state["rooms"].values():
		if int(room.get("section_index", -1)) == AUDIT_SECTION and (int(room["depth"]) - 1) % 4 + 1 == AUDIT_DEPTH_BAND: print(room)
	quit()

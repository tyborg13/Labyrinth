extends "res://tools/ptf09/real_fixture.gd"

# The shared installer intentionally accepts combat only. Keep its canonical
# canvas/resume path and install the equivalent certified real-arena save here.
static func install_dragon(path: String) -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(manifest.get("verified", false) and manifest.get("scenario", "") == "dragon")
	var run_id: String = manifest.run_id
	var source: String = str(manifest.verification.godot_home_root).path_join(run_id).path_join("Library/Application Support/Escape the Umbra Parallel " + run_id)
	Store.set_storage_path("user://progression.json")
	Store.set_run_storage_path("user://current_run.save")
	for name: String in ["progression.json", "current_run.save"]:
		assert(DirAccess.copy_absolute(source.path_join(name), ProjectSettings.globalize_path("user://" + name)) == OK)
	var state: Dictionary = Store.load_saved_run()
	assert(state.get("inspection_fixture", {}).get("scenario", "") == "dragon")
	var settings: Dictionary = Settings.default_settings()
	settings.ui_scale = 1.0
	settings.reduced_motion = false
	Settings.save_settings(settings)

static func open_composition(board: Control) -> Dictionary:
	var hero_clear: bool = false
	var clear_foes: int = 0
	var foes: int = 0
	var grid: Array = board.combat_state.get("grid", [])
	for unit: Dictionary in board.call("_visible_units"):
		var role: String = str(unit.get("role", ""))
		if role not in ["player", "enemy"]: continue
		var blocked: bool = false
		for tile: Vector2i in board.call("_unit_footprint_tiles", unit):
			# Both screen-forward neighbors use the existing fixture vocabulary.
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var front: Vector2i = tile + offset
				if front.y >= 0 and front.y < grid.size() and front.x >= 0 and front.x < grid[front.y].size() and str(grid[front.y][front.x]) in ["pillar", "wall"]: blocked = true
		if role == "player": hero_clear = not blocked
		else:
			foes += 1
			if not blocked: clear_foes += 1
	return {"hero_clear": hero_clear, "clear_foes": clear_foes, "foes": foes}

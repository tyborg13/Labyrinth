extends "res://tests/map_03_probe.gd"

# Reuse the existing map probe's viewport, settings, dimensions and capture
# implementation. Only proof fixtures differ: Section I for three fixed seeds.
const PROOF_SEEDS: Array = [83, 307, 90429]
const CelLook = preload("res://scripts/cel_look.gd")
const CAPTURE_DIR: String = "/private/tmp/labyrinth_codex/ptf-02/captures"

func _run() -> void:
	Settings.set_storage_path("user://ptf02-map-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	if not _logic_only:
		_check(CelLook.mode == "all" and not CelLook._files.is_empty(), "Cel look is enabled and its generated manifest is present")
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(PROOF_SIZE)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = PROOF_SIZE
	root.size = PROOF_SIZE
	_viewport = CaptureViewport.create(root)
	panel = MapPanelScript.new()
	panel.position = PANEL_POSITION
	panel.size = PANEL_SIZE
	_viewport.add_child(panel)
	for seed_value: int in PROOF_SEEDS:
		var state: Dictionary = {"seed": seed_value, "current_room": Vector2i.ZERO, "mode": "room"}
		Graph.initialize(state)
		panel.set_run_state(state)
		await _capture("ptf02_seed_%d_section_i_start.png" % seed_value)
		# Center the existing scrolling map on the actual band-2 Hearth.
		for node: Dictionary in state["rooms"].values():
			if int(node["section_index"]) != 0 or int(node["map_step"]) != Graph.V7_MID_HEARTH_STEP: continue
			_check(node["type"] == "campfire" and int(node["depth"]) == 2, "Section I midpoint is an Ember Hearth at depth 2")
			state["current_room"] = node["coord"]
			Graph.refresh_knowledge(state)
			panel.set_run_state(state)
			await _capture("ptf02_seed_%d_section_i_mid_hearth.png" % seed_value)
			break
		panel.scroll_to(panel.scroll_limit())
		await _capture("ptf02_seed_%d_section_i_preboss.png" % seed_value)
	if not _logic_only: print("PTF02 map captures: " + CAPTURE_DIR)
	print("PTF02 MAP PROBE: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)

func _capture(filename: String, settle: bool = true) -> void:
	# The inherited probe performs viewport readback and exact-size validation.
	# Its output is copied into the unit's requested proof directory.
	await super._capture(filename, settle)
	if _logic_only: return
	DirAccess.make_dir_recursive_absolute(CAPTURE_DIR)
	_check(DirAccess.copy_absolute(ProjectSettings.globalize_path(OUTPUT.path_join(filename)), CAPTURE_DIR.path_join(filename)) == OK, "Task-local capture copy: " + filename)

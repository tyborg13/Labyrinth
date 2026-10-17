extends SceneTree

const Graph = preload("res://scripts/section_map_graph.gd")
const MapPanel = preload("res://scripts/section_map_panel.gd")
const Settings = preload("res://scripts/settings_store.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const PROOF_SIZE: Vector2i = Vector2i(1920, 1080)
const PROOF_PANEL_SIZE: Vector2 = Vector2(1864, 1024)
const PROOF_PANEL_POSITION: Vector2 = Vector2(28, 28)
const PROOF_FIELD_SIZE: Vector2 = Vector2(1864, 823)
const PROOF_SEEDS: Array[int] = [1, 83, 200]
const PROOF_SECTIONS: Array[int] = [0, 2, 4]
const OUTPUT: String = "user://map_02_variety"
var panel: Control
var viewport: SubViewport
var setup_only: bool = false

func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--debug-reveal-section"):
		push_error("Proof requires --debug-reveal-section; reveal is confined to this probe")
		quit(2)
		return
	setup_only = OS.get_cmdline_user_args().has("--setup-only")
	if DisplayServer.get_name() == "headless" and not setup_only:
		push_error("Map 02 visual proof requires a windowed renderer; use --setup-only for the headless setup regression")
		quit(2)
		return
	ParallelRuntime.apply_from_environment()
	Settings.set_storage_path("user://map_02_proof_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["fullscreen"] = false
	Settings.save_settings(settings)
	_run.call_deferred()

func _run() -> void:
	if not setup_only:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(PROOF_SIZE)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = PROOF_SIZE
	root.size = PROOF_SIZE
	viewport = SubViewport.new()
	viewport.size = PROOF_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	panel = MapPanel.new()
	panel.position = PROOF_PANEL_POSITION
	panel.size = PROOF_PANEL_SIZE
	viewport.add_child(panel)
	if not panel.is_node_ready(): await panel.ready
	await process_frame
	await process_frame
	if not panel.get("_built") or not is_instance_valid(panel.get("_field")) or not is_instance_valid(panel.get("_tabs")):
		_fail("Panel ready completed without building the field and section tabs")
		return
	if (panel.get("_field") as Control).size != PROOF_FIELD_SIZE:
		_fail("Panel layout did not settle to the expected 1864x823 field at 100% UI scale")
		return
	var signatures: Dictionary = {}
	for seed_value: int in PROOF_SEEDS:
		var state: Dictionary = {"seed": seed_value, "current_room": Vector2i.ZERO, "mode": "room"}
		Graph.initialize(state)
		for index: int in PROOF_SECTIONS:
			var info: Dictionary = Graph.section(state, index)
			var signature: String = var_to_str(info["walks"])
			if signatures.has(signature):
				_fail("Proof seeds repeat generating walks at seed %d section %d" % [seed_value, index + 1])
				return
			signatures[signature] = true
			state["current_room"] = info["entry"]
			for node: Dictionary in state["rooms"].values():
				if int(node["section_index"]) == index:
					node["revealed"] = true
					node["map_outline"] = true
			panel.set_run_state(state)
			panel.select_section(index)
			await process_frame
			await process_frame
			if panel.node_buttons.size() != Graph.descendants(state, info["entry"]).size():
				_fail("Whole section was not built at seed %d section %d" % [seed_value, index + 1])
				return
			if setup_only: continue
			await RenderingServer.frame_post_draw
			var path: String = OUTPUT.path_join("seed_%03d_section_%d.png" % [seed_value, index + 1])
			var directory_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
			if directory_error != OK:
				_fail("Cannot create capture directory: %s" % error_string(directory_error))
				return
			var capture: Image = viewport.get_texture().get_image()
			if capture == null or capture.get_size() != PROOF_SIZE:
				_fail("Renderer did not provide a 1920x1080 image for " + path)
				return
			var capture_error: Error = capture.save_png(path)
			if capture_error != OK:
				_fail("Cannot write %s: %s" % [path, error_string(capture_error)])
				return
	if setup_only:
		print("Map 02 probe setup: PASS (9 full-visibility sections; no captures)")
	else:
		print("Map 02 visual proof: 9 full-visibility captures at 1920x1080, 100% UI scale")
		print(ProjectSettings.globalize_path(OUTPUT))
	panel.free()
	quit()

func _fail(message: String) -> void:
	push_error("Map 02 visual proof failed: " + message)
	quit(1)

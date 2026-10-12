extends "res://tests/board_density_probe.gd"
## Eight native stills through the existing real RunScene density stage.
## --headless-check validates fixtures without claiming renderer pixels.

const Biomes = preload("res://scripts/biome_library.gd")
const GALLERY_TYPES: PackedStringArray = ["crawler", "cinder_droplet", "lightning_wisp"]
const GALLERY_POSITIONS: Array = [Vector2i(2, 4), Vector2i(6, 3), Vector2i(2, 7)]
const GALLERY_OUTPUT: String = "user://probes/biome_gallery"
const GALLERY_SETTLE_FRAMES: int = 6
const GALLERY_PROOF_CONTRACT_PATH: String = "/private/tmp/biome-01-gallery-proof.json"
var _gallery_biome: String = "stone"
var _gallery_headless: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_gallery_headless = OS.get_cmdline_user_args().has("--headless-check")
	call_deferred("_gallery_run")

func _gallery_run() -> void:
	if DisplayServer.get_name() == "headless" and not _gallery_headless:
		push_error("Biome gallery needs a native renderer; use --headless-check for structural proof only")
		quit(1)
		return
	_density_output = GALLERY_OUTPUT
	_write_proof_contract()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_density_output))
	ProgressionStore.set_storage_path("user://biome_gallery_progression.json")
	ProgressionStore.set_run_storage_path("user://biome_gallery_run.save")
	DensitySettings.set_storage_path("user://biome_gallery_settings.json")
	ProgressionStore.clear_saved_run()
	var settings: Dictionary = DensitySettings.default_settings()
	settings["display_mode"] = DensitySettings.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	DensitySettings.save_settings(settings)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = DENSITY_SIZE
	root.size = DENSITY_SIZE
	if not _gallery_headless: DisplayServer.window_set_size(DENSITY_SIZE)
	_density_viewport = SubViewport.new()
	_density_viewport.size = DENSITY_SIZE
	_density_viewport.disable_3d = true
	_density_viewport.world_2d = World2D.new()
	_density_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_density_viewport.gui_disable_input = true
	root.add_child(_density_viewport)
	_options = {"seed": DENSITY_SEED, "notice": ""}
	var captures: Array[Dictionary]
	for biome: String in Biomes.ids():
		_gallery_biome = biome
		await _gallery_capture("props", "combat_" + biome, settings, captures)
	_gallery_biome = "iskaldra"
	await _gallery_capture("campfire", "hearth_iskaldra", settings, captures)
	var file := FileAccess.open(_density_output.path_join("gallery.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 1, "size": [1920, 1080], "ui_scale": 1.0,
		"native": not _gallery_headless, "captures": captures, "errors": _density_errors}, "\t"))
	_density_viewport.queue_free()
	await process_frame
	for error: String in _density_errors: push_error(error)
	print("BIOME GALLERY %s: %s (%d cases)" % ["HEADLESS CHECK" if _gallery_headless else "PROBE", "PASS" if _density_errors.is_empty() else "FAIL", captures.size()])
	print(ProjectSettings.globalize_path(_density_output))
	quit(0 if _density_errors.is_empty() else 1)

func _gallery_capture(scenario: String, label: String, settings: Dictionary, captures: Array[Dictionary]) -> void:
	if not await _density_prepare_fixture(scenario, settings): return
	var board: Control = _density_scene.get_node("BoardUnderlay/CombatBoard")
	var state: Dictionary = board.get("combat_state")
	var presentation: Dictionary = (board.get("presentation") as Dictionary).duplicate(true)
	presentation["biome_id"] = _gallery_biome
	board.call("set_combat_state", state, [], [], board.get("selected_tile"), board.get("status_label"), board.get("status_detail"), board.get("exit_tiles"), board.get("exit_icon_ids"), presentation)
	_density_scene.get_node("BoardUnderlay/BoardBackdrop").modulate = Biomes.backdrop_modulate(_gallery_biome)
	var atmosphere: Control = _density_scene.get("_combat_atmosphere")
	atmosphere.call("set_biome", _gallery_biome)
	_density_check(board.get("_biome_id") == _gallery_biome, label + ": board domain")
	_density_check(atmosphere.get("_biome_id") == _gallery_biome, label + ": atmosphere domain")
	var pillars: int = 0
	for row: Array in state.get("grid", []): pillars += row.count("pillar")
	if scenario == "props":
		_density_check((state.get("enemies", []) as Array).size() == 3 and pillars == 2, label + ": fixed three-enemy/two-pillar stage")
		_density_check(not (state.get("terrain", []) as Array).is_empty(), label + ": crates present")
	for frame: int in range(GALLERY_SETTLE_FRAMES): await process_frame
	if not _gallery_headless:
		await RenderingServer.frame_post_draw
		var image: Image = _density_viewport.get_texture().get_image()
		_density_check(image != null and image.get_size() == DENSITY_SIZE, label + ": native image size")
		if image != null: _density_check(image.save_png(_density_output.path_join(label + ".png")) == OK, label + ": save capture")
	captures.append({"image": label + ".png" if not _gallery_headless else "", "biome": _gallery_biome,
		"scenario": scenario, "pillars": pillars, "light_color": str(board.get("_biome_light_color")),
		"lighting": str((board.get("_art_treatment") as RefCounted).get("_parameters")),
		"mote_preset": Biomes.atmosphere(_gallery_biome)["motes"]})
	_density_scene.queue_free()
	await process_frame

func _density_roster_run(scene_name: String, progression: Dictionary) -> Dictionary:
	var run: Dictionary = super._density_roster_run(scene_name, progression)
	var layout: Dictionary = run["current_room_layout"]
	var enemies: Array[Dictionary]
	for index: int in range(GALLERY_TYPES.size()):
		var definition: Dictionary = GameData.enemy_def(GALLERY_TYPES[index])
		enemies.append({"id": index + 1, "type": GALLERY_TYPES[index], "pos": GALLERY_POSITIONS[index],
			"hp": definition["max_hp"], "max_hp": definition["max_hp"], "block": 0})
	layout["enemies"] = enemies
	layout["traps"] = []
	layout["loot"] = []
	run["combat_state"] = _combat_engine.create_combat(DENSITY_SEED, layout, _run_engine.call("_player_snapshot", run))
	run["combat_state"]["current_actor"] = {"kind": "player", "key": "player"}
	return run

func _write_proof_contract() -> void:
	var required: Array[Dictionary]
	var names: Array[String]
	for id: String in Biomes.ids(): names.append("combat_" + id)
	names.append("hearth_iskaldra")
	for label: String in names:
		required.append({"pattern": "*" + label + ".png", "width": 1920, "height": 1080,
			"regions": [{"rect": [320, 120, 1280, 650], "min_luma_range": 40, "min_luma_stdev": 3}]})
	var file := FileAccess.open(GALLERY_PROOF_CONTRACT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"min_images": 8, "expected_sizes": ["1920x1080"], "required_images": required}, "\t"))

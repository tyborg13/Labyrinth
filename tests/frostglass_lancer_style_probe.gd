extends SceneTree

## Actual RunScene art gate; candidate paint is injected only in this probe.
const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Store = preload("res://scripts/progression_store.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Loader = preload("res://scripts/asset_loader.gd")
const CASE: String = "res://experiments/cutouts/frostglass_lancer/v01"
const OUTPUT: String = "user://probes/frostglass_lancer_style_v03"
const SIZE := Vector2i(1920, 1080)
var _viewport: SubViewport
var _run_scene: Node
var _board: Control
var _errors: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = SIZE
	root.size = SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	Store.set_storage_path("user://frostglass_style_progression.json")
	Store.set_run_storage_path("user://frostglass_style_run.save")
	Store.clear_saved_run()
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.disable_3d = true
	_viewport.world_2d = World2D.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_run_scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_viewport.add_child(_run_scene)
	await _settle()
	_board = _run_scene.get("board_view") as Control
	_fixture()
	await _settle()
	var images: Array[String]
	for version: String in ["original_front", "front_registered"]:
		var textures: Dictionary = _board.get("_unit_textures")
		var idles: Dictionary = _board.get("_idle_frames_by_type")
		var source: String = CASE + "/source/" + version + ".png"
		textures["frostglass_lancer"] = Loader.load_texture_source_first(source)
		idles.erase("frostglass_lancer")
		# The native sheet uses these same static references. Keep their board
		# drawings still so idle-sheet variants cannot disguise the style match.
		for type: String in ["crawler", "harrier", "grave_surgeon"]:
			textures[type] = Loader.load_texture_source_first(str(GameData.enemy_def(type)["art_path"]))
			idles.erase(type)
		_board.call("_invalidate_board_layout_cache", true)
		_run_scene.call("_refresh_ui")
		_board.call("_sync_dynamic_render_assets")
		_board.call("_queue_dynamic_redraw")
		await _settle()
		Input.warp_mouse(Vector2(960, 80))
		await _settle()
		var captured: Image = _viewport.get_texture().get_image()
		_check(captured.get_size() == SIZE, "Native 1920x1080 RunScene capture")
		var filename: String = version + "_board.png"
		_check(captured.save_png(OUTPUT.path_join(filename)) == OK, "Saved " + filename)
		images.append(filename)
		_check((_run_scene.get("_combat_state") as Dictionary)["enemies"].size() == 5, "Five real reference actors remain in combat")
		_check((_run_scene.get("_settings") as Dictionary)["ui_scale"] == 1.0, "UI scale is exactly 100 percent")
	var manifest := {"ok": _errors.is_empty(), "errors": _errors, "size": [1920, 1080], "ui_scale": 1.0,
		"surface": "actual RunScene with candidate static paint injected before cutout authoring",
		"images": images, "reference_types": ["frostglass_lancer", "warden", "crawler", "harrier", "grave_surgeon"]}
	var file := FileAccess.open(OUTPUT.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	_run_scene.queue_free()
	_viewport.queue_free()
	await process_frame
	for error: String in _errors:
		push_error(error)
	print("Saved " + ProjectSettings.globalize_path(OUTPUT))
	print("FROSTGLASS STYLE PROBE: " + ("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)

func _fixture() -> void:
	var grid: Array = []
	for y: int in range(10):
		var row: Array = []
		for x: int in range(10):
			row.append("wall" if x == 0 or y == 0 or x == 9 or y == 9 else "stone")
		grid.append(row)
	var hand: Array = ["quick_stab", "brace", "sidestep_slash", "bone_dart", "patch_up"]
	var actors: Array = []
	var types: Array[String]
	types.assign(["frostglass_lancer", "warden", "crawler", "harrier", "grave_surgeon"])
	var positions: Array[Vector2i]
	positions.assign([Vector2i(3, 3), Vector2i(6, 3), Vector2i(2, 6), Vector2i(5, 6), Vector2i(7, 5)])
	for index: int in range(types.size()):
		var hp: int = int(GameData.enemy_def(types[index])["max_hp"])
		actors.append({"id": index + 1, "type": types[index], "pos": positions[index], "hp": hp, "max_hp": hp, "block": 0})
	var layout: Dictionary = {"name": "Frostglass Lancer Style Trial", "coord": Vector2i(4, 3), "type": "combat", "grid": grid,
		"player_start": Vector2i(4, 5), "enemies": actors, "traps": [], "terrain": [], "element": "none"}
	var engine := CombatEngine.new()
	var state: Dictionary = engine.create_combat(260909, layout, {"hp": 40, "max_hp": 40, "deck_cards": hand.duplicate(), "relics": [], "hand_size": 5})
	state["deck"] = {"hand": hand.duplicate(), "draw": [], "discard": [], "burned": []}
	state["current_actor"] = {"kind": "player", "key": "player"}
	state = engine.normalize_player_movement_pool(state)
	var progression: Dictionary = (_run_scene.get("_progression") as Dictionary).duplicate(true)
	for prompt: String in Tutorial.prompt_ids():
		progression = Tutorial.resolve_progression(progression, prompt)
	var run: Dictionary = (_run_scene.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["current_room"] = layout["coord"]
	run["current_room_layout"] = layout
	run["combat_state"] = state.duplicate(true)
	run["progression"] = progression.duplicate(true)
	_run_scene.set("_progression", progression)
	_run_scene.set("_run_state", run)
	var settings: Dictionary = (_run_scene.get("_settings") as Dictionary).duplicate(true)
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	_run_scene.set("_settings", settings)
	_run_scene.call("_sync_combat_state_from_run")
	_run_scene.set("_animation_lock", false)
	_run_scene.call("_refresh_ui")

func _settle() -> void:
	for index: int in range(8):
		await process_frame
	await RenderingServer.frame_post_draw

func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)

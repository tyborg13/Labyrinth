extends SceneTree

## Compare registered source paintings inside the real RunScene before rigging.
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const SOURCE: String = "res://experiments/cutouts/chainbound_gaoler/v01/source/"
const OUTPUT: String = "user://probes/chainbound_gaoler_style_v03"
const SIZE := Vector2i(1920, 1080)
var _errors: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = SIZE
	root.size = SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	ProgressionStore.set_storage_path("user://gaoler_style_progression.json")
	ProgressionStore.set_run_storage_path("user://gaoler_style_run.save")
	ProgressionStore.clear_saved_run()
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	viewport.add_child(scene)
	await _settle()
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	var enemies: Array[Dictionary]
	var types: PackedStringArray = ["warden", "chainbound_gaoler", "grave_surgeon", "harrier", "crawler"]
	var positions: Array[Vector2i]
	positions.assign([Vector2i(2, 2), Vector2i(5, 2), Vector2i(4, 5), Vector2i(6, 4), Vector2i(1, 4)])
	for index: int in range(types.size()):
		var definition: Dictionary = GameData.enemy_def(types[index])
		enemies.append({"id": index + 1, "type": types[index], "pos": positions[index], "hp": definition["max_hp"], "max_hp": definition["max_hp"], "block": 0})
	var layout: Dictionary = {"name": "Gaoler Roster Paint Comparison", "coord": Vector2i(4, 3), "type": "combat", "grid": grid,
		"player_start": Vector2i(3, 5), "enemies": enemies, "traps": [], "terrain": [], "element": "none"}
	var hand: Array = ["quick_stab", "brace", "sidestep_slash", "bone_dart", "patch_up"]
	var combat := CombatEngine.new()
	var state: Dictionary = combat.create_combat(260909, layout, {"hp": 40, "max_hp": 40, "deck_cards": hand.duplicate(), "relics": [], "hand_size": 5, "heal_bonus": 0})
	state["deck"] = {"hand": hand.duplicate(), "draw": [], "discard": [], "burned": []}
	state["current_actor"] = {"kind": "player", "key": "player"}
	state = combat.normalize_player_movement_pool(state)
	var progression: Dictionary = (scene.get("_progression") as Dictionary).duplicate(true)
	for prompt: String in Tutorial.prompt_ids():
		progression = Tutorial.resolve_progression(progression, prompt)
	var run: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["current_room"] = layout["coord"]
	run["current_room_layout"] = layout
	run["combat_state"] = state.duplicate(true)
	run["progression"] = progression.duplicate(true)
	scene.set("_progression", progression)
	scene.set("_run_state", run)
	var settings: Dictionary = (scene.get("_settings") as Dictionary).duplicate(true)
	settings["reduced_motion"] = true
	settings["ui_scale"] = 1.0
	scene.set("_settings", settings)
	scene.call("_sync_combat_state_from_run")
	scene.set("_animation_lock", false)
	scene.call("_refresh_ui")
	await _settle()
	var board: Control = scene.get("board_view") as Control
	for enemy_type: String in ["crawler", "harrier", "grave_surgeon"]:
		(board.get("_idle_frames_by_type") as Dictionary).erase(enemy_type)
		(board.get("_unit_textures") as Dictionary)[enemy_type] = AssetLoader.load_texture_source_first(str(GameData.enemy_def(enemy_type)["art_path"]))
	for entry: Array in [["original", "gaoler_original.png"], ["repaint", "front_registered.png"]]:
		var texture: Texture2D = AssetLoader.load_texture_source_first(SOURCE + str(entry[1]))
		if texture == null:
			_errors.append("Missing registered " + str(entry[1]))
			continue
		(board.get("_unit_textures") as Dictionary)["chainbound_gaoler"] = texture
		(board.get("_idle_frames_by_type") as Dictionary).erase("chainbound_gaoler")
		scene.call("_refresh_ui")
		board.call("_sync_dynamic_render_assets")
		board.call("_sync_dynamic_render_state", true, true)
		for layer: Control in board.call("_retained_render_layers"):
			layer.queue_redraw()
		board.queue_redraw()
		var actual: Texture2D = board.call("_texture_for_unit", {"type": "chainbound_gaoler", "id": 2})
		if actual != texture:
			_errors.append("Gaoler is not using comparison texture " + str(entry[0]))
		Input.warp_mouse(Vector2(960, 86))
		await _settle()
		var picture: Image = viewport.get_texture().get_image()
		if picture.save_png(OUTPUT.path_join(str(entry[0]) + "_board.png")) != OK:
			_errors.append("Could not save " + str(entry[0]))
	var manifest := FileAccess.open(OUTPUT.path_join("manifest.json"), FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"ok": _errors.is_empty(), "size": [1920, 1080], "ui_scale": 1.0,
		"surface": "actual RunScene; Gaoler source texture overridden for pre-rig art comparison", "errors": _errors}, "\t"))
	manifest.close()
	scene.queue_free()
	viewport.queue_free()
	await process_frame
	for error: String in _errors:
		push_error(error)
	print("Saved " + ProjectSettings.globalize_path(OUTPUT))
	print("GAOLER STYLE PROBE: " + ("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)

func _settle() -> void:
	for index: int in range(8):
		await process_frame
	await RenderingServer.frame_post_draw

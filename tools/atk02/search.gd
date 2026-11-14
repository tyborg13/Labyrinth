extends SceneTree
## atk-02 proof helper (headless): for each real save under --root, resume it in
## the production scene, walk the hero two tiles (all movement), then select
## each hand card and hover each of its targets. Prints one JSON line per hover
## with the forecast panel's rows and whether trigger (c) fired, so a native
## proof can pick a real "move, then the last card" turn.
## Usage (after --): --root <dir with */repro/*/run.save> [--walks]
## --walks hovers only the hero's walk destinations (no card is played).
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Presentation = preload("res://scripts/pass_forecast_presentation.gd")
const SIZE := Vector2i(1920, 1080)
var canvas: SubViewport
var scene: Node

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if DisplayServer.get_name() == "headless": process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var root_dir: String = args[args.find("--root") + 1]
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	root.size = SIZE
	root.content_scale_size = SIZE
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	root.add_child(container)
	canvas = SubViewport.new()
	canvas.size = SIZE
	container.add_child(canvas)
	for seed_dir: String in DirAccess.get_directories_at(root_dir):
		var repro: String = root_dir.path_join(seed_dir).path_join("repro")
		if not DirAccess.dir_exists_absolute(repro): continue
		for point: String in DirAccess.get_directories_at(repro):
			await _search(repro.path_join(point))
	print("ATK02 SEARCH done")
	quit(0)

func _load(save_dir: String) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await process_frame
		await process_frame
	Store.set_storage_path("user://progression.json")
	Store.set_run_storage_path("user://current_run.save")
	DirAccess.copy_absolute(save_dir.path_join("progression.json"), ProjectSettings.globalize_path("user://progression.json"))
	DirAccess.copy_absolute(save_dir.path_join("run.save"), ProjectSettings.globalize_path("user://current_run.save"))
	root.set_meta("labyrinth_resume_saved_run", true)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	for frame: int in range(60): await process_frame
	await create_timer(1.0).timeout

func _search(save_dir: String) -> void:
	await _load(save_dir)
	var engine: RefCounted = scene.get("_combat_engine")
	var state: Dictionary = scene.get("_combat_state")
	if str((scene.get("_run_state") as Dictionary).get("mode", "")) != "combat" or not engine.is_player_turn(state): return
	var hero: Vector2i = state["player"]["pos"]
	if OS.get_cmdline_user_args().has("--walks"):
		# Walk destinations only: what the panel shows for each, card plays untouched.
		scene.call("_begin_player_movement_selection")
		for tile: Vector2i in scene.get("_player_movement_target_tiles"):
			scene.call("_on_board_tile_hovered", tile)
			scene.call("_refresh_board_hover_presentation")
			var walk_chip: Button = scene.find_child("PassPreviewChip", true, false) as Button
			var walk_rows: Array = []
			for row: Dictionary in walk_chip.get_meta("forecast_rows", []):
				for part: Dictionary in row.get("parts", []): walk_rows.append("%s %s" % [part.get("icon", ""), part.get("text", "")])
			print("ATK02 SEARCH " + JSON.stringify({"save": save_dir, "hp": int(state["player"]["hp"]), "cards": engine.cards_remaining_this_turn(state), "moves": engine.player_movement_remaining(state), "walk": [tile.x, tile.y], "ends_turn": Presentation.ends_turn(scene), "active": bool(walk_chip.get_meta("pass_forecast_active", false)), "rows": walk_rows}))
		scene.call("_cancel_player_movement_selection")
		return
	scene.call("_begin_player_movement_selection")
	var destinations: Array[Vector2i]
	for tile: Vector2i in scene.get("_player_movement_target_tiles"):
		if absi(tile.x - hero.x) + absi(tile.y - hero.y) == engine.player_movement_remaining(state): destinations.append(tile)
	scene.call("_cancel_player_movement_selection")
	for tile: Vector2i in destinations:
		await _load(save_dir)
		scene.call("_begin_player_movement_selection")
		await scene.call("_commit_player_movement", tile)
		for frame: int in range(400):
			await process_frame
			if not bool(scene.get("_animation_lock")): break
		state = scene.get("_combat_state")
		if not engine.is_player_turn(state) or engine.player_movement_remaining(state) != 0 or engine.cards_remaining_this_turn(state) != 1:
			print("ATK02 SEARCH skip %s move %s hero=%s moves=%d cards=%d" % [save_dir, str(tile), str(state["player"]["pos"]), engine.player_movement_remaining(state), engine.cards_remaining_this_turn(state)])
			continue
		var hand: Array = state["deck"]["hand"]
		for index: int in range(hand.size()):
			if not engine.hand_card_has_play_budget(state, index): continue
			scene.call("_on_card_pressed", index)
			await process_frame
			if int(scene.get("_selected_card_index")) != index: continue
			var targets: Array = (scene.get("_pending_target_tiles") as Array).duplicate()
			if bool(scene.call("_pending_card_requires_confirmation")): targets = [Vector2i(-1, -1)]
			# Move-and-strike cards also take a foe directly (a shortcut plan).
			var preview: Dictionary = scene.call("_active_card_preview")
			for enemy: Dictionary in state.get("enemies", []):
				if int(enemy.get("hp", 0)) > 0 and not targets.has(enemy["pos"]) and not (scene.call("_shortcut_plan_for_tile", preview, enemy["pos"]) as Dictionary).is_empty(): targets.append(enemy["pos"])
			for target: Vector2i in targets:
				scene.call("_on_board_tile_hovered", target)
				scene.call("_refresh_board_hover_presentation")
				scene.call("_refresh_selected_card_forecast")
				var chip: Button = scene.find_child("PassPreviewChip", true, false) as Button
				var shown: Array = []
				for row: Dictionary in chip.get_meta("forecast_rows", []):
					for part: Dictionary in row.get("parts", []): shown.append("%s %s" % [part.get("icon", ""), part.get("text", "")])
				var enemy_here: bool = false
				for enemy: Dictionary in state.get("enemies", []):
					if int(enemy.get("hp", 0)) > 0 and enemy.get("pos") == target: enemy_here = true
				print("ATK02 SEARCH " + JSON.stringify({"save": save_dir, "hp": int(state["player"]["hp"]), "move": [tile.x, tile.y], "card": hand[index], "index": index, "target": [target.x, target.y], "enemy": enemy_here, "ends_turn": Presentation.ends_turn(scene), "active": bool(chip.get_meta("pass_forecast_active", false)), "rows": shown}))
			scene.call("_cancel_card_selection")
			await process_frame

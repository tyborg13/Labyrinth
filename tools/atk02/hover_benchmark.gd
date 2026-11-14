extends SceneTree
## atk-02 hover cost (headless): resume a real save, walk the hero (--move),
## select the last card (--card), warm its targets, then time pointer hovers
## alternating between them (input dispatch plus the coalesced presentation
## flush, as ptf-08 measured). Runs unchanged on the pre-atk-02 baseline.
## Usage (after --): --save-dir <dir> --move x,y --card <id> --targets x,y;x,y --output <json>
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const SAMPLE_COUNT: int = 400
const WARMUP_COUNT: int = 40
const SIZE := Vector2i(1920, 1080)
var scene: Node

class CountedCombat extends CombatEngine:
	var forecasts: int = 0
	func begin_revealed_enemy_actions_preview(state: Dictionary, losses_only: bool = false) -> Dictionary:
		forecasts += 1
		return super.begin_revealed_enemy_actions_preview(state, losses_only)
	func preview_revealed_enemy_actions_before_player_turn_with_steps(state: Dictionary, losses_only: bool = false) -> Dictionary:
		forecasts += 1
		return super.preview_revealed_enemy_actions_before_player_turn_with_steps(state, losses_only)

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if DisplayServer.get_name() == "headless": process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _arg(name: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	return args[args.find(name) + 1]

static func _tile(text: String) -> Vector2i:
	return Vector2i(int(text.get_slice(",", 0)), int(text.get_slice(",", 1)))

func _run() -> void:
	var save_dir: String = _arg("--save-dir")
	Store.set_storage_path("user://progression.json")
	Store.set_run_storage_path("user://current_run.save")
	DirAccess.copy_absolute(save_dir.path_join("progression.json"), ProjectSettings.globalize_path("user://progression.json"))
	DirAccess.copy_absolute(save_dir.path_join("run.save"), ProjectSettings.globalize_path("user://current_run.save"))
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.set_meta("labyrinth_resume_saved_run", true)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	for frame: int in range(60): await process_frame
	await create_timer(1.0).timeout
	scene.call("_begin_player_movement_selection")
	await scene.call("_commit_player_movement", _tile(_arg("--move")))
	for frame: int in range(400):
		await process_frame
		if not bool(scene.get("_animation_lock")): break
	var moved: Dictionary = scene.get("_combat_state")
	if moved["player"]["pos"] != _tile(_arg("--move")) or scene.get("_combat_engine").player_movement_remaining(moved) != 0:
		push_error("ATK02 HOVER: the walk did not spend all movement")
		quit(1)
		return
	var counted := CountedCombat.new()
	scene.set("_combat_engine", counted)
	var state: Dictionary = scene.get("_combat_state")
	scene.call("_on_card_pressed", (state["deck"]["hand"] as Array).find(_arg("--card")))
	for frame: int in range(6): await process_frame
	var tiles: Array[Vector2i]
	for text: String in _arg("--targets").split(";", false): tiles.append(_tile(text))
	var rows: Array = []
	for tile: Vector2i in tiles:
		scene.call("_on_board_tile_hovered", tile)
		scene.call("_refresh_board_hover_presentation")
		var chip: Button = scene.find_child("PassPreviewChip", true, false) as Button
		var shown: Array = []
		for row: Dictionary in chip.get_meta("forecast_rows", []):
			for part: Dictionary in row.get("parts", []): shown.append("%s %s" % [part.get("icon", ""), part.get("text", "")])
		rows.append(shown)
	var forecasts_before: int = counted.forecasts
	var samples: Array[int]
	for index: int in range(WARMUP_COUNT + SAMPLE_COUNT):
		var started: int = Time.get_ticks_usec()
		scene.call("_on_board_tile_hovered", tiles[index % tiles.size()])
		scene.call("_refresh_board_hover_presentation")
		var elapsed: int = Time.get_ticks_usec() - started
		if index >= WARMUP_COUNT: samples.append(elapsed)
	samples.sort()
	var result: Dictionary = {"samples": SAMPLE_COUNT, "warmups": WARMUP_COUNT, "tiles": tiles.size(), "rows": rows, "simulations_during_samples": counted.forecasts - forecasts_before, "median_usec": samples[samples.size() / 2], "p99_usec": samples[ceili(samples.size() * 0.99) - 1]}
	var file := FileAccess.open(_arg("--output"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("ATK02 HOVER " + JSON.stringify(result))
	scene.queue_free()
	await process_frame
	quit()

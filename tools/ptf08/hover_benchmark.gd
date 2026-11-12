extends SceneTree

const SAMPLE_COUNT: int = 200
const WARMUP_COUNT: int = 20
const VIEWPORT := Vector2i(1920, 1080)
const OUTPUT: String = "/private/tmp/labyrinth_codex/ptf-08"
var scene: Node

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	root.mode = Window.MODE_WINDOWED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = VIEWPORT
	root.content_scale_size = VIEWPORT
	var settings: Dictionary = preload("res://scripts/settings_store.gd").default_settings()
	settings["ui_scale"] = 1.0
	preload("res://scripts/settings_store.gd").save_settings(settings)
	scene = preload("res://scenes/run_scene.tscn").instantiate()
	if not scene.has_method("_load_run_state"):
		print("PTF08 BENCHMARK: FAIL scene did not compile")
		quit(1)
		return
	root.add_child(scene)
	await process_frame
	await process_frame
	var run_engine := preload("res://scripts/run_engine.gd").new()
	var state: Dictionary = run_engine.create_new_run(123, preload("res://scripts/progression_store.gd").default_data())
	state["mode"] = "combat"
	state["combat_state"] = preload("res://tools/ptf07/forecast_cases.gd").fixture("second_move")
	scene.call("_load_run_state", state)
	scene.set("_animation_lock", false)
	scene.call("_reset_card_resolution")
	scene.call("_refresh_ui")
	for _frame: int in range(10): await process_frame
	var chip: Control = scene.find_child("PassPreviewChip", true, false) as Control
	var geometry: Dictionary = {"pass": rect(chip.get_global_rect()), "parent": rect((chip.get_parent() as Control).get_global_rect())}
	scene.call("_on_card_pressed", 0)
	for _frame: int in range(6): await process_frame
	var tiles: Array = scene.get("_pending_target_tiles")
	if tiles.is_empty():
		print("PTF08 BENCHMARK: FAIL no destinations")
		quit(1)
		return
	# Warm every destination once. Samples include input dispatch and its normal
	# coalesced presentation flush; the deferred empty flush is outside timing.
	for tile: Vector2i in tiles:
		scene.call("_on_board_tile_hovered", tile)
		scene.call("_refresh_board_hover_presentation")
	var samples: Array[int]
	for index: int in range(WARMUP_COUNT + SAMPLE_COUNT):
		var started: int = Time.get_ticks_usec()
		scene.call("_on_board_tile_hovered", tiles[index % tiles.size()])
		scene.call("_refresh_board_hover_presentation")
		var elapsed: int = Time.get_ticks_usec() - started
		if index >= WARMUP_COUNT: samples.append(elapsed)
	samples.sort()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var stem: String = args[args.find("--output") + 1]
	var result: Dictionary = {"geometry": geometry, "samples": SAMPLE_COUNT, "warmups": WARMUP_COUNT, "tiles": tiles.size(), "median_usec": samples[samples.size()/2], "p99_usec": samples[ceili(samples.size()*0.99)-1]}
	FileAccess.open(OUTPUT.path_join(stem + ".json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("PTF08 HOVER " + stem + ": " + JSON.stringify(result))
	scene.queue_free()
	await process_frame
	quit()

static func rect(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]

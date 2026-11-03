extends SceneTree

# Director captures of the Warband markers: first turn of fixed Warband fixtures at 1920x1080.
const Fixture = preload("res://tools/warband_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Suite = preload("res://tests/suites/warband_orders_suite.gd")
const SIZE := Vector2i(1920, 1080)
const OUTPUT: String = "user://wbv-captures"
const FRAMES: int = 72
const FRAME_REGION := Rect2i(500, 160, 960, 540)
var canvas: SubViewport
const CASES: Array = [
	{"name": "air_t2", "biome": "air", "tier": 2},
	{"name": "lightning_t3", "biome": "lightning", "tier": 3},
	{"name": "fire_t1", "biome": "fire", "tier": 1},
	{"name": "air_held_wind", "held_wind": true},
]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	Settings.set_storage_path("user://wbv-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = SIZE
	root.content_scale_size = SIZE
	canvas = SubViewport.new()
	canvas.size = SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.path_join("frames")))
	for item: Dictionary in CASES:
		await _capture(item)
	print("WBV captures: " + ProjectSettings.globalize_path(OUTPUT))
	quit()

func _capture(item: Dictionary) -> void:
	var state: Dictionary = _held_wind_run() if item.has("held_wind") else _fixture_run(item)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await process_frame
	scene.call("_load_run_state", state)
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	if item.has("held_wind"):
		scene.call("_set_show_all_enemy_intents", true)
		scene.call("_render_board_state", state["combat_state"], {})
	await create_timer(2.5).timeout
	await RenderingServer.frame_post_draw
	var image: Image = canvas.get_texture().get_image()
	image.save_png(OUTPUT.path_join("%s.png" % item["name"]))
	if item.has("held_wind") and OS.get_cmdline_user_args().has("--frames"):
		# Wind drift stepped at 24 fps through the board's presentation clock.
		var board: Control = scene.get("board_view")
		for frame: int in range(FRAMES):
			board.presentation["en02_wind_time_seconds"] = float(frame) / 24.0
			board.call("_queue_dynamic_redraw")
			await RenderingServer.frame_post_draw
			await process_frame
			await RenderingServer.frame_post_draw
			canvas.get_texture().get_image().get_region(FRAME_REGION).save_png(OUTPUT.path_join("frames/%03d.png" % frame))
	scene.queue_free()
	await process_frame
	await process_frame

func _fixture_run(item: Dictionary) -> Dictionary:
	var engine := Run.new()
	var state: Dictionary = engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data())
	return Fixture.build(engine, Combat.new(), state, {"warband_biome": item["biome"], "warband_tier": item["tier"]})

# The orders suite's air battle after the Stormcaller's wind has blown once (held wind active).
func _held_wind_run() -> Dictionary:
	var engine := Combat.new()
	var state: Dictionary = Suite.battle("air")
	state["umbra"] = {"stage": "clear"}
	var intent: Dictionary = {}
	for candidate: Dictionary in Suite.Data.enemy_def(str(state["enemies"][0]["type"]))["intents"]:
		if str(candidate["actions"][0]["type"]) == "call_wind": intent = candidate.duplicate(true); break
	state["enemies"][0]["intent"] = intent
	state = Suite.Wind.resolve(engine, state, 0, intent["actions"][0])
	var runs := Run.new()
	var run: Dictionary = Suite.Warbands.Fixture.build(runs, Combat.new(), runs.create_new_run(Fixture.FIXTURE_SEED, Store.default_data()), {"warband_biome": "air", "warband_tier": 3})
	run["combat_state"] = state
	run["current_room_layout"]["grid"] = state["grid"]
	run["current_room_layout"]["enemies"] = state["enemies"]
	return run

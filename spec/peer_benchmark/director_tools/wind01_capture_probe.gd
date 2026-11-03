extends SceneTree

# Director captures of the wind presentation (wind-01): air Warband and air Snare at 1920x1080.
const Fixture = preload("res://tools/warband_inspection.gd")
const SnareFixture = preload("res://tools/snare_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Suite = preload("res://tests/suites/warband_orders_suite.gd")
const SIZE := Vector2i(1920, 1080)
const OUTPUT: String = "user://wind01-captures"
const FRAMES: int = 72
const FRAME_REGION := Rect2i(500, 160, 960, 540)
var canvas: SubViewport
const CASES: Array = [
	{"name": "warband_air_t2", "biome": "air", "tier": 2},
	{"name": "warband_air_held", "held_wind": true},
	{"name": "warband_air_push", "held_wind": true, "push": true},
	{"name": "snare_air_t2", "snare": "first_turn"},
	{"name": "snare_air_t2_turn3", "snare": "pressure_turn3"},
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
	var state: Dictionary = _held_wind_run() if item.has("held_wind") else (_snare_run(item) if item.has("snare") else _fixture_run(item))
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
	if item.has("push"):
		await _capture_push(scene, item)
		scene.queue_free()
		await process_frame
		return
	var image: Image = canvas.get_texture().get_image()
	image.save_png(OUTPUT.path_join("%s.png" % item["name"]))
	if (item.has("held_wind") or str(item.get("snare", "")) == "first_turn") and OS.get_cmdline_user_args().has("--frames"):
		# Wind drift stepped at 24 fps through the board's presentation clock.
		var board: Control = scene.get("board_view")
		for frame: int in range(FRAMES):
			board.presentation["en02_wind_time_seconds"] = float(frame) / 24.0
			board.presentation["ambient_time_seconds"] = 10.0 + float(frame) / 24.0
			board.call("_queue_dynamic_redraw")
			await RenderingServer.frame_post_draw
			await process_frame
			await RenderingServer.frame_post_draw
			canvas.get_texture().get_image().get_region(FRAME_REGION).save_png(OUTPUT.path_join("frames/%s_%03d.png" % [item["name"], frame]))
	scene.queue_free()
	await process_frame
	await process_frame

# The wind's push rendered at fixed progress, as WindView.animate draws it.
func _capture_push(scene: Node, item: Dictionary) -> void:
	var engine := Combat.new()
	var before: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	var value: Dictionary = Suite.Wind.active(engine, before)
	var after: Dictionary = Suite.Wind.push_all(engine, before.duplicate(true), value)
	var source_index: int = engine._enemy_index_for_id(before, int(value["source_id"]))
	var step: Dictionary = Suite.Wind.animation_step(engine, before, after, source_index, {"type": "wind_push"})
	var board: Control = scene.get("board_view")
	var count: int = 24 if OS.get_cmdline_user_args().has("--frames") else 0
	for index: int in range(count + 2):
		var progress: float = [0.35, 0.65][index] if index < 2 else float(index - 2) / float(count - 1)
		var positions: Dictionary = {}
		for actor: Dictionary in Suite.Wind.actors(before, value["direction"]):
			var key: String = engine._surface_actor_key(str(actor["kind"]), int(actor["id"]))
			var start: Vector2 = board._tile_center(actor["unit"]["pos"])
			var finish: Vector2 = board._tile_center(engine._surface_actor(after, str(actor["kind"]), int(actor["id"])).get("pos", actor["unit"]["pos"]))
			positions[key] = start.lerp(finish, progress)
		scene.call("_render_board_state", before, {"effect": step, "effect_progress": progress, "unit_world_positions": positions})
		board.presentation["en02_wind_time_seconds"] = 3.0 + float(index) / 24.0
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
		if index < 2: canvas.get_texture().get_image().save_png(OUTPUT.path_join("%s_%d.png" % [item["name"], index]))
		else: canvas.get_texture().get_image().get_region(FRAME_REGION).save_png(OUTPUT.path_join("frames/%s_%03d.png" % [item["name"], index - 2]))

func _snare_run(item: Dictionary) -> Dictionary:
	var engine := Run.new()
	return SnareFixture.build(engine, Combat.new(), engine.create_new_run(SnareFixture.FIXTURE_SEED, Store.default_data()), {"snare_biome": "air", "snare_tier": 2, "snare_case": item["snare"]})

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

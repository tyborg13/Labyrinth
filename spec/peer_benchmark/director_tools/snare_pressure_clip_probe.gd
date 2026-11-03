extends SceneTree

# Director gameplay clip of one Umbral Snare pressure: the tier-2 fixture of a biome
# on its first turn, the hero passing three turns so the pressure resolves each time.
# Run under Godot's movie writer; START/END lines mark the clip's frames.
const Fixture = preload("res://tools/snare_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const TIER: int = 2
const ROUNDS: int = 3
const SETTLE_SECONDS: float = 1.0
const OPEN_SECONDS: float = 2.5
const HOLD_SECONDS: float = 1.2
const ROUND_LIMIT_FRAMES: int = 60 * 40
const IDLE_FRAMES: int = 20

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var biome: String = "fire"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--biome="): biome = argument.trim_prefix("--biome=")
	Settings.set_storage_path("user://snare-clip-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	settings["combat_speed"] = "normal"
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.content_scale_size = Vector2i(1920, 1080)
	var engine := Run.new()
	var run: Dictionary = Fixture.build(engine, Combat.new(), engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data()), {"snare_biome": biome, "snare_tier": TIER, "snare_case": "first_turn"})
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.call("_load_run_state", run)
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	await create_timer(SETTLE_SECONDS).timeout
	print("ORDERS CLIP START_FRAME=%d" % Engine.get_frames_drawn())
	await create_timer(OPEN_SECONDS).timeout
	for round: int in range(ROUNDS):
		scene.call("_on_pass_turn_pressed")
		await process_frame
		var frames: int = 0
		var idle: int = 0
		while idle < IDLE_FRAMES and frames < ROUND_LIMIT_FRAMES:
			await process_frame
			frames += 1
			idle = 0 if bool(scene.get("_animation_lock")) else idle + 1
		print("SNARE CLIP ROUND %d mode=%s hero_hp=%d" % [round, str((scene.get("_run_state") as Dictionary).get("mode", "")), int((scene.get("_combat_state") as Dictionary).get("player", {}).get("hp", -1))])
		if str((scene.get("_run_state") as Dictionary).get("mode", "")) != "combat": break
		await create_timer(HOLD_SECONDS).timeout
	print("ORDERS CLIP END_FRAME=%d" % Engine.get_frames_drawn())
	quit()

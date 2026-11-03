extends SceneTree

# Director gameplay clip of one Warband order: the tier-3 fixture of a biome, the
# captain opening on its order, two enemy rounds played out in real time.
# Run under Godot's movie writer; START/END lines mark the clip's frames.
const Fixture = preload("res://tools/warband_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Data = preload("res://scripts/game_data.gd")
const Rules = preload("res://scripts/warband_combat_rules.gd")
const ORDER_VERBS: Dictionary = {"earth": "grow_bramble", "fire": "lob_mark", "air": "call_wind", "ice": "icefall_mark", "lightning": "gain_charge", "shadow": "ranged"}
const TIER: int = 3
const ROUNDS: int = 3
const SETTLE_SECONDS: float = 1.0
const OPEN_SECONDS: float = 2.5
const HOLD_SECONDS: float = 1.2
const ROUND_LIMIT_FRAMES: int = 60 * 40
const IDLE_FRAMES: int = 20
const CLIP_HERO_HP: int = 120

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var biome: String = "air"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--biome="): biome = argument.trim_prefix("--biome=")
	Settings.set_storage_path("user://orders-clip-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	settings["combat_speed"] = "normal"
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.content_scale_size = Vector2i(1920, 1080)
	var engine := Run.new()
	var run: Dictionary = Fixture.build(engine, Combat.new(), engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data()), {"warband_biome": biome, "warband_tier": TIER})
	var state: Dictionary = run["combat_state"]
	# The hero only passes in these clips; extra health lets four rounds play out.
	state["player"]["hp"] = CLIP_HERO_HP
	state["player"]["max_hp"] = CLIP_HERO_HP
	var captain_id: int = int(Rules.captain(state)["id"])
	for enemy: Dictionary in state["enemies"]:
		if int(enemy["id"]) != captain_id: continue
		for candidate: Dictionary in Data.enemy_def(str(enemy["type"]))["intents"]:
			if str(candidate["actions"][0]["type"]) == str(ORDER_VERBS[biome]):
				enemy["intent"] = candidate.duplicate(true)
				break
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.call("_load_run_state", run)
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	# Park the pointer on empty backdrop so no board tooltip covers the clip.
	root.warp_mouse(Vector2(1100, 90))
	await create_timer(SETTLE_SECONDS).timeout
	print("ORDERS CLIP START_FRAME=%d" % Engine.get_frames_drawn())
	await create_timer(OPEN_SECONDS).timeout
	for round: int in range(ROUNDS):
		scene.call("_on_pass_turn_pressed")
		await process_frame
		# The turn clock can hand the hero a turn mid-round; wait until the board
		# has been idle for a moment before the next pass.
		var frames: int = 0
		var idle: int = 0
		while idle < IDLE_FRAMES and frames < ROUND_LIMIT_FRAMES:
			await process_frame
			frames += 1
			idle = 0 if bool(scene.get("_animation_lock")) else idle + 1
		print("ORDERS CLIP ROUND %d frames=%d mode=%s lock=%s hero_hp=%d" % [round, frames, str((scene.get("_run_state") as Dictionary).get("mode", "")), str(scene.get("_animation_lock")), int((scene.get("_combat_state") as Dictionary).get("player", {}).get("hp", -1))])
		if str((scene.get("_run_state") as Dictionary).get("mode", "")) != "combat": break
		await create_timer(HOLD_SECONDS).timeout
	print("ORDERS CLIP END_FRAME=%d" % Engine.get_frames_drawn())
	quit()

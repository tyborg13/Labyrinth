extends SceneTree

# pol-27: a real dragon room's fight preview, then Begin, recorded through the opening of the fight.
const Dragon = preload("res://tools/dragon_boss_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")

func _initialize() -> void:
	call_deferred("_run")

func _value(name: String, fallback: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--%s=" % name): return argument.trim_prefix("--%s=" % name)
	return fallback

func _cue(id: String, result: String) -> void:
	print("CUE f=%d %s %s" % [Engine.get_frames_drawn(), id, result])

func _run() -> void:
	Settings.set_storage_path("user://pol27-clip-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	settings["combat_speed"] = "normal"
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.content_scale_size = Vector2i(1920, 1080)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var options: Dictionary = {"dragon_id": _value("dragon", "tharokh"), "dragon_depth": int(_value("depth", "4")), "dragon_case": "pre_battle", "seed": 7262026}
	var seed: int = Dragon.seed_for_options(options)
	options["seed"] = seed
	var engine := Run.new()
	var run: Dictionary = Dragon.build(engine, Combat.new(), engine.create_new_run(seed, Store.default_data()), options)
	scene.call("_load_run_state", run)
	await create_timer(0.5).timeout
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	await process_frame
	scene.call("_close_large_map")
	await create_timer(0.3).timeout
	scene.call("_sync_pre_battle_preview_after_refresh")
	scene.call("_ensure_sfx_bank")
	(scene.get("_sfx_bank") as Object).connect("cue_requested", _cue)
	await create_timer(2.5).timeout
	Input.warp_mouse(Vector2(110, 520))
	print("POL27 CLIP START_FRAME=%d mode=%s" % [Engine.get_frames_drawn(), str((scene.get("_run_state") as Dictionary).get("mode", ""))])
	await create_timer(1.2).timeout
	print("POL27 BEGIN f=%d" % Engine.get_frames_drawn())
	scene.call("_on_pre_battle_start_pressed")
	var frames: int = 0
	var layer: CanvasLayer = (scene.get("board_view") as Node).get_parent() as CanvasLayer
	var largest: float = 0.0
	var music_id: String = str(scene.get("_active_music_id"))
	while bool(scene.get("_animation_lock")) and frames < 60 * 20:
		await process_frame
		frames += 1
		if layer != null: largest = maxf(largest, layer.offset.length())
		if str(scene.get("_active_music_id")) != music_id:
			music_id = str(scene.get("_active_music_id"))
			print("POL27 MUSIC CHANGE f=%d music=%s" % [Engine.get_frames_drawn(), music_id])
	print("POL27 OPENING DONE f=%d music=%s max_board_offset=%.1f" % [Engine.get_frames_drawn(), str(scene.get("_active_music_id")), largest])
	var tail_end: int = Time.get_ticks_msec() + int(float(_value("tail", "4.0")) * 1000.0)
	while Time.get_ticks_msec() < tail_end:
		await process_frame
		if str(scene.get("_active_music_id")) != music_id:
			music_id = str(scene.get("_active_music_id"))
			print("POL27 MUSIC CHANGE f=%d music=%s" % [Engine.get_frames_drawn(), music_id])
	print("POL27 CLIP END_FRAME=%d" % Engine.get_frames_drawn())
	if _value("pass", "0") == "1":
		print("POL27 PASS f=%d" % Engine.get_frames_drawn())
		scene.call("_on_pass_turn_pressed")
		await process_frame
		frames = 0
		var idle: int = 0
		while idle < 30 and frames < 60 * 25:
			await process_frame
			frames += 1
			idle = 0 if bool(scene.get("_animation_lock")) else idle + 1
		for line: Variant in ((scene.get("_combat_state") as Dictionary).get("log", []) as Array).slice(-6): print("POL27 LOG ", str(line).substr(0, 110))
		print("POL27 PASS DONE f=%d" % Engine.get_frames_drawn())
	quit()

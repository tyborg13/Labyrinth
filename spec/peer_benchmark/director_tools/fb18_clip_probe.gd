extends SceneTree

# Director gameplay clips for the owner's inbox, from a real RunScene under Godot's movie writer.
# --mode=burst: a Hoarder room with three Ticks beside the hero, dying from Bleed on the enemy phase.
# --mode=event --event=<id> --choice=<n>: open an event, hover the choice, take it, watch its beats.
const Hoarder = preload("res://tools/hoarder_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Events = preload("res://scripts/event_rules.gd")
const IDLE_FRAMES: int = 30
const ROUND_LIMIT_FRAMES: int = 60 * 20

func _initialize() -> void:
	call_deferred("_run")

func _value(name: String, fallback: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--%s=" % name): return argument.trim_prefix("--%s=" % name)
	return fallback

func _run() -> void:
	Settings.set_storage_path("user://fb18-clip-settings.json")
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
	if _value("mode", "burst") == "burst":
		await _burst(scene)
	else:
		await _event(scene)
	print("FB18 CLIP END_FRAME=%d" % Engine.get_frames_drawn())
	quit()

func _burst(scene: Node) -> void:
	var engine := Run.new()
	var run: Dictionary = Hoarder.build(engine, Combat.new(), engine.create_new_run(83, Store.default_data()), {"hoarder_biome": "fire", "hoarder_tier": 2, "hoarder_case": "encounter", "seed": 83})
	var state: Dictionary = run["combat_state"]
	state["player"]["hp"] = 60
	state["player"]["max_hp"] = 60
	var hero: Vector2i = state["player"]["pos"]
	var spots: Array[Vector2i] = []
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(0, 1)]:
		var tile: Vector2i = hero + offset
		if tile.y >= 0 and tile.y < state["grid"].size() and tile.x >= 0 and tile.x < (state["grid"][tile.y] as Array).size():
			state["grid"][tile.y][tile.x] = "stone"
			spots.append(tile)
	var ticks: int = 0
	for enemy: Dictionary in state["enemies"]:
		if str(enemy["type"]) != "ember_tick" or ticks >= spots.size(): continue
		enemy["pos"] = spots[ticks]
		enemy["hp"] = 1
		enemy["bleed"] = 3
		enemy["bleed_stacks"] = 3
		ticks += 1
	scene.call("_load_run_state", run)
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	await create_timer(1.0).timeout
	print("FB18 CLIP START_FRAME=%d" % Engine.get_frames_drawn())
	await create_timer(1.2).timeout
	scene.call("_on_pass_turn_pressed")
	await _settle(scene)
	await create_timer(1.2).timeout

func _event(scene: Node) -> void:
	var engine := Run.new()
	var state: Dictionary = engine.create_new_run(83, Store.default_data())
	for room: Dictionary in (state["rooms"] as Dictionary).values():
		if str(room.get("type", "")) != "event": continue
		state["current_room"] = room["coord"]
		room["event_id"] = _value("event", "hanged_knight")
		state["mode"] = "event"
		break
	state = Events.enter_event(state)
	state["player_hp"] = 24
	state["player_max_hp"] = 30
	state["held_embers"] = 120
	state["unbanked_embers"] = 120
	scene.call("_load_run_state", state)
	await create_timer(1.0).timeout
	print("FB18 CLIP START_FRAME=%d" % Engine.get_frames_drawn())
	var view: Control = scene.get("_event_view")
	var choice: Button = view.get("choices")[int(_value("choice", "0"))]
	await create_timer(0.8).timeout
	choice.mouse_entered.emit()
	await create_timer(1.8).timeout
	choice.mouse_exited.emit()
	view.call("activate_choice", int(_value("choice", "0")), true)
	await create_timer(3.4).timeout

func _settle(scene: Node) -> void:
	await process_frame
	var frames: int = 0
	var idle: int = 0
	while idle < IDLE_FRAMES and frames < ROUND_LIMIT_FRAMES:
		await process_frame
		frames += 1
		idle = 0 if bool(scene.get("_animation_lock")) else idle + 1
	print("FB18 CLIP SETTLED frames=%d hero_hp=%d enemies=%d" % [frames, int((scene.get("_combat_state") as Dictionary).get("player", {}).get("hp", -1)), ((scene.get("_combat_state") as Dictionary).get("enemies", []) as Array).size()])

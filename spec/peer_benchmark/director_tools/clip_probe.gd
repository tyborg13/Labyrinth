extends "res://tests/fix18/real_fight_capture_probe.gd"

# Real fight: play the first hand card through the normal click flow, press Pass, log every sound request with its frame.
const CLIP_SETTLE_LIMIT_FRAMES: int = 60 * 25
const CLIP_IDLE_FRAMES: int = 30

func _parse_capture_args(args: PackedStringArray) -> Dictionary:
	var supplied: PackedStringArray = args.duplicate()
	if not supplied.has("--label"): supplied.append_array(PackedStringArray(["--label", "clip"]))
	return super._parse_capture_args(supplied)

func _build_run_state(scenario: String, progression: Dictionary) -> Dictionary:
	var run: Dictionary = super._build_run_state(scenario, progression)
	if _failed: return run
	var battle: Dictionary = run["combat_state"]
	var tiles: Array[Vector2i]
	for entry: String in (str(_options.get("enemy_positions", "")) + "," + str(_options.get("player_position", ""))).split(",", false):
		var pair: PackedStringArray = entry.split(":")
		var tile := Vector2i(int(pair[0]), int(pair[1]))
		battle["grid"][tile.y][tile.x] = "stone"
		tiles.append(tile)
	run["combat_state"] = _clear_fixture_occupant_tiles(battle, tiles)
	return run

func _cue(id: String, result: String) -> void:
	var enemies: Array = []
	for e: Dictionary in (_capture_scene.get("_combat_state") as Dictionary).get("enemies", []): enemies.append(int(e.get("hp", 0)))
	print("CUE f=%d %s %s hp=%s" % [Engine.get_frames_drawn(), id, result, str(enemies)])

func _sample_frames() -> void:
	await super._sample_frames()
	_capture_scene.call("_ensure_sfx_bank")
	(_capture_scene.get("_sfx_bank") as Object).connect("cue_requested", _cue)
	await create_timer(0.8).timeout
	print("REAL FIGHT CLIP START_FRAME=%d" % Engine.get_frames_drawn())
	await create_timer(0.5).timeout
	print("CLIP CARD f=%d" % Engine.get_frames_drawn())
	await _capture_scene.call("_on_card_pressed", 0)
	await create_timer(0.5).timeout
	if OS.has_environment("CLIP_TARGET"):
		var t: PackedStringArray = OS.get_environment("CLIP_TARGET").split(":")
		var tile := Vector2i(int(t[0]), int(t[1]))
		_capture_scene.call("_on_board_tile_hovered", tile)
		await create_timer(0.2).timeout
		await _capture_scene.call("_on_board_tile_clicked", tile)
		await create_timer(0.3).timeout
		if bool(_capture_scene.get("_animation_lock")) == false and int(_capture_scene.get("_selected_card_index")) >= 0:
			await _capture_scene.call("_on_board_tile_clicked", tile)
	else:
		await _capture_scene.call("_on_card_pressed", 0)
	await _settle()
	await create_timer(0.5).timeout
	for round_index: int in range(int(OS.get_environment("CLIP_ROUNDS") if OS.has_environment("CLIP_ROUNDS") else "1")):
		print("CLIP PASS f=%d" % Engine.get_frames_drawn())
		_capture_scene.call("_on_pass_turn_pressed")
		await process_frame
		await _settle()
		await create_timer(0.4).timeout
		var st: Dictionary = _capture_scene.get("_combat_state")
		print("CLIP STATE player=%s enemies=%s" % [str(st.get("player", {}).get("pos")), str((st.get("enemies", []) as Array).map(func(e: Dictionary) -> String: return "%s@%s hp%d" % [e.get("type"), e.get("pos"), e.get("hp")]))])
		for line: Variant in (st.get("log", []) as Array).slice(-8): print("CLIP LOG ", str(line).substr(0, 110))
	for e: Dictionary in (_capture_scene.get("_combat_state") as Dictionary).get("enemies", []): print("CLIP ENEMY %s hp=%d" % [str(e.get("type", "")), int(e.get("hp", 0))])
	await create_timer(0.8).timeout
	print("REAL FIGHT CLIP END_FRAME=%d" % Engine.get_frames_drawn())

func _settle() -> void:
	var frames: int = 0
	var idle: int = 0
	while idle < CLIP_IDLE_FRAMES and frames < CLIP_SETTLE_LIMIT_FRAMES:
		await process_frame
		frames += 1
		idle = 0 if bool(_capture_scene.get("_animation_lock")) else idle + 1
	print("CLIP SETTLED f=%d frames=%d" % [Engine.get_frames_drawn(), frames])

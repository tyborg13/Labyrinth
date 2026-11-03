extends "res://tests/fix18/real_fight_capture_probe.gd"

## Persisted combat -> MainMenu Continue -> normal Pass -> real resolver and
## presentation clock. Only the fixture lane is cleared. Never time-step poses,
## redirect rendering, or resize a frame for the director's motion evidence.
const PROOF_ORIGIN := Vector2i(2, 4)
const PROOF_SEED: int = 7262026
const PROOF_MOVES := {"ember_tick": {"intent": "scuttle", "tiles": 3}, "burrow_grub": {"intent": "gnaw", "tiles": 2}}
const PROOF_CAPTURE_FPS: float = 60.0
var proof_type: String
var proof_recording: bool = false
var proof_frames: Array[Dictionary]
var proof_started_usec: int

func _parse_capture_args(args: PackedStringArray) -> Dictionary:
	var supplied: PackedStringArray = args.duplicate()
	if not supplied.has("--label"): supplied.append_array(PackedStringArray(["--label", "mv01"]))
	var parsed: Dictionary = super._parse_capture_args(supplied)
	proof_type = str(parsed.get("enemy_types", ""))
	if not PROOF_MOVES.has(proof_type):
		_fail("mv-01 requires --enemy-types ember_tick|burrow_grub")
		return parsed
	var target: Vector2i = PROOF_ORIGIN + Vector2i.RIGHT * (int(PROOF_MOVES[proof_type]["tiles"]) + 1)
	parsed.merge({"seed": PROOF_SEED, "scenario": "combat", "enemy_intents": PROOF_MOVES[proof_type]["intent"],
		"enemy_positions": "%d:%d" % [PROOF_ORIGIN.x, PROOF_ORIGIN.y], "player_position": "%d:%d" % [target.x, target.y]}, true)
	_capture_label = "mv01_" + proof_type
	return parsed

func _build_run_state(scenario: String, progression: Dictionary) -> Dictionary:
	var run: Dictionary = super._build_run_state(scenario, progression)
	if _failed: return run
	var battle: Dictionary = run["combat_state"]
	var lane: Array[Vector2i]
	for index: int in range(int(PROOF_MOVES[proof_type]["tiles"]) + 2):
		var tile: Vector2i = PROOF_ORIGIN + Vector2i.RIGHT * index
		battle["grid"][tile.y][tile.x] = "stone"
		lane.append(tile)
	battle = _clear_fixture_occupant_tiles(battle, lane)
	run["combat_state"] = battle
	return run

func _sample_frames() -> void:
	await super._sample_frames()
	var battle: Dictionary = _capture_scene._combat_state
	var planned: Dictionary = _combat_engine.resolve_enemy_phase_with_steps(battle.duplicate(true))
	var found: bool = false
	for step: Dictionary in planned.get("steps", []):
		if step.get("kind", "") != "move" or step.get("actor_key", "") != "enemy_1": continue
		_check((step.get("path", []) as Array).size() - 1 == int(PROOF_MOVES[proof_type]["tiles"]), "Real resolver supplies requested path length")
		found = true
	_check(found, "Real intent contains movement")
	if not _capture_errors.is_empty(): return
	if _validate_only:
		print("MV01 FIGHT PLAN: PASS (%s; %d tiles; real Continue boot; 1920x1080/100%% requested; native_pixels=false)" % [proof_type, PROOF_MOVES[proof_type]["tiles"]])
		return
	print("MV01 root viewport %s" % root.size)
	if not _capture_errors.is_empty(): return
	proof_started_usec = Time.get_ticks_usec()
	proof_recording = true
	_record_movement()
	await _capture_scene._on_pass_turn_pressed()
	proof_recording = false
	await process_frame
	_check(not proof_frames.is_empty(), "Real Pass emitted move frames")
	var endpoint: Vector2i = PROOF_ORIGIN + Vector2i.RIGHT * int(PROOF_MOVES[proof_type]["tiles"])
	_check(_capture_scene._combat_state["enemies"][0]["pos"] == endpoint, "Real fight reaches requested move endpoint")
	FileAccess.open(_capture_output.path_join("recording.json"), FileAccess.WRITE).store_string(JSON.stringify({
		"type": proof_type, "intent": PROOF_MOVES[proof_type]["intent"], "tiles": PROOF_MOVES[proof_type]["tiles"],
		"native_pixels": true, "size": [root.size.x, root.size.y], "ui_scale": 1.0, "frames": proof_frames}, "\t"))
	print(ProjectSettings.globalize_path(_capture_output))

func _record_movement() -> void:
	var last_capture: int = -1
	while proof_recording:
		await RenderingServer.frame_post_draw
		if not proof_recording: break
		var elapsed: int = Time.get_ticks_usec() - proof_started_usec
		if last_capture >= 0 and elapsed - last_capture < 1000000.0 / PROOF_CAPTURE_FPS: continue
		var shown: Dictionary = _capture_board.presentation
		var motion: Dictionary = shown.get(proof_type + "_motion", {}).get("enemy_1", {})
		if motion.get("clip", "") != "move": continue
		last_capture = elapsed
		var filename: String = "move_%04d.png" % proof_frames.size()
		var image: Image = root.get_texture().get_image()
		_check(image.get_size() == root.size, "Every recorded frame matches the window")
		_check(image.save_png(_capture_output.path_join(filename)) == OK, "Save native movement frame")
		var actor: Dictionary = _capture_scene._combat_state["enemies"][0].duplicate(false)
		actor.merge({"key": "enemy_1", "role": "enemy"}, true)
		var center: Vector2 = _capture_board._unit_center(actor)
		var rect: Rect2 = _capture_board._unit_draw_rect_for_texture(actor, center, _capture_board._unit_hud_anchor_texture(actor))
		proof_frames.append({"file": filename, "elapsed_seconds": elapsed / 1000000.0, "phase": motion.get("phase", 0.0),
			"motion": motion, "world": shown.get("unit_world_positions", {}).get("enemy_1"),
			"actor_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})

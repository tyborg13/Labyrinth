extends "res://tests/fix18/real_fight_capture_probe.gd"

# Director real-time clips of a real fight for the owner's inbox: persisted combat through the normal Continue boot, then
# normal Pass presses and the real resolver, under Godot's movie writer. CLIP_ROUNDS sets how many enemy phases to record.
const CLIP_SETTLE_LIMIT_FRAMES: int = 60 * 25
const CLIP_IDLE_FRAMES: int = 30

func _parse_capture_args(args: PackedStringArray) -> Dictionary:
	var supplied: PackedStringArray = args.duplicate()
	if not supplied.has("--label"): supplied.append_array(PackedStringArray(["--label", "clip"]))
	return super._parse_capture_args(supplied)

# Fixture rooms may hold walls or props on the tiles asked for, so the clip's actors stand on cleared floor.
func _build_run_state(scenario: String, progression: Dictionary) -> Dictionary:
	var run: Dictionary = super._build_run_state(scenario, progression)
	if _failed: return run
	var battle: Dictionary = run["combat_state"]
	for row: Array in battle["grid"]: print("CLIP GRID ", " ".join(row.map(func(cell: Variant) -> String: return str(cell).substr(0, 1))))
	var tiles: Array[Vector2i]
	for entry: String in (str(_options.get("enemy_positions", "")) + "," + str(_options.get("player_position", ""))).split(",", false):
		var pair: PackedStringArray = entry.split(":")
		var tile := Vector2i(int(pair[0]), int(pair[1]))
		battle["grid"][tile.y][tile.x] = "stone"
		tiles.append(tile)
	run["combat_state"] = _clear_fixture_occupant_tiles(battle, tiles)
	return run

func _sample_frames() -> void:
	await super._sample_frames()
	await create_timer(0.8).timeout
	print("REAL FIGHT CLIP START_FRAME=%d" % Engine.get_frames_drawn())
	for round_index: int in range(int(OS.get_environment("CLIP_ROUNDS") if OS.has_environment("CLIP_ROUNDS") else "2")):
		await create_timer(0.8).timeout
		_capture_scene.call("_on_pass_turn_pressed")
		await process_frame
		var frames: int = 0
		var idle: int = 0
		while idle < CLIP_IDLE_FRAMES and frames < CLIP_SETTLE_LIMIT_FRAMES:
			await process_frame
			frames += 1
			idle = 0 if bool(_capture_scene.get("_animation_lock")) else idle + 1
		print("REAL FIGHT CLIP ROUND %d frames=%d" % [round_index, frames])
	await create_timer(0.8).timeout
	print("REAL FIGHT CLIP END_FRAME=%d" % Engine.get_frames_drawn())

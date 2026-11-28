extends "probe.gd"

const Data = preload("res://scripts/game_data.gd")
const Sequence = preload("res://scripts/maquette_cutout_runtime/death_sequence.gd")
const Burst = preload("res://scripts/enemy_mechanics/death_burst_view.gd")
const PIXEL_THRESHOLD := 8
const RELEASE_SETTLE_USEC := 40000
const MAX_POST_VISIBILITY_USEC := 100000
const DRAW_FRAME_USEC := 1000000.0 / FPS
const STRIP_WINDOW_USEC := 300000
const CROP_HALF_WIDTH := 180
const CROP_HEIGHT := 340
const CROP_BELOW_FEET := 65
const EDGE := 2

func _run() -> void:
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("set FEL28_OUTPUT to a writable directory")
		return
	fixtures = load(tool_root.path_join("fel28/fixtures.gd"))
	var inventory: Array[String]
	inventory.assign(Data.enemies().keys())
	inventory.append_array(fixtures.DESTRUCTIBLES)
	var only: String = OS.get_environment("FEL28_DEATH_SUBJECT")
	if not only.is_empty():
		inventory.clear()
		inventory.append(only)
	var rows: Array[Dictionary]
	for mood: String in ["normal", "reduced"]:
		var directory: String = output.path_join(mood)
		DirAccess.make_dir_recursive_absolute(directory)
		inputs = load(tool_root.path_join("fel20/input_driver.gd")).new(root)
		var scene: Node = await _setup(mood, directory)
		if scene == null:
			_fail("could not open death test combat")
			return
		for subject: String in inventory:
			var row: Dictionary = await _sample_subject(scene, subject, mood == "reduced")
			rows.append(row)
		await scene.prepare_application_quit("fel28_deaths")
		scene.queue_free()
		await process_frame
	var file := FileAccess.open(output.path_join("deaths.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t") + "\n")
	if native:
		var passed: bool = rows.all(func(row: Dictionary) -> bool: return row["pass"])
		quit(0 if passed else 1)
	else:
		print("FEL28 DEATH CLOCKS rows=", rows.size())
		quit()

func _sample_subject(scene: Node, subject: String, reduced: bool) -> Dictionary:
	fixtures.stage(scene, "inventory", subject)
	await RenderingServer.frame_post_draw
	var board: Control = scene.board_view
	var before: Dictionary = scene._combat_state
	var after: Dictionary = before.duplicate(true)
	var prop: bool = subject in fixtures.DESTRUCTIBLES
	if prop: after["terrain"].clear()
	else: after["enemies"].clear()
	var units: Array[Dictionary] = scene._defeated_enemy_units_between_states(before, after)
	var terrain: Array[Dictionary] = scene._destroyed_terrain_units_between_states(before, after)
	var count: int = scene.ENEMY_DEATH_MIN_FRAMES
	var period: float = scene.ENEMY_DEATH_FALLBACK_FRAME_SECONDS
	for unit: Dictionary in units:
		count = maxi(count, scene._enemy_death_frame_count_for_unit(unit))
		period = minf(period, scene._enemy_death_frame_seconds_for_unit(unit))
	for item: Dictionary in terrain:
		count = maxi(count, scene._terrain_destruction_frame_count_for_unit(item))
		period = minf(period, scene._terrain_destruction_frame_seconds_for_unit(item))
	var clock: Dictionary = Burst.timing(before, after, count, period, scene, units)
	Sequence.configure(clock, scene, units)
	var period_usec: int = roundi(period * 1000000.0)
	var playback_end: int = int(clock.get("hold_end_usec", count * period_usec))
	var wait_usec: int = playback_end + RELEASE_SETTLE_USEC
	var label: String = subject + ("/reduced" if reduced else "/normal")
	var row: Dictionary = {"type": label, "wait_ms": wait_usec / 1000.0}
	var schedule: Array = clock.get("schedule_usec", [])
	if schedule.is_empty():
		for i: int in range(count): schedule.append(i * period_usec)
	var roster: Array[Dictionary]
	var progress_key: String = "destruction_progress" if prop else "death_progress"
	var frame_key: String = "destruction_frame" if prop else "death_frame"
	var presentation_key: String = "terrain_destruction_units" if prop else "death_animation_units"
	var source: Dictionary = terrain[0] if prop else units[0]
	var frames: int = scene._terrain_destruction_frame_count_for_unit(source) if prop else scene._enemy_death_frame_count_for_unit(source)
	for index: int in range(schedule.size()):
		var elapsed: int = int(schedule[index])
		var progress: float = float(index) / maxi(1, schedule.size() - 1)
		if clock.has("unit_clocks"): progress = elapsed / 1000000.0 / float(clock["duration"])
		var dying: Dictionary = source.duplicate()
		dying[progress_key] = progress
		dying[frame_key] = roundi(progress * (frames - 1))
		if not prop: Sequence.sample(dying, elapsed / 1000000.0, clock)
		roster.append(dying)
	row["schedule_sha256"] = JSON.stringify([clock, schedule, roster, wait_usec]).sha256_text()
	if not native: return row

	# Compare the reference before and after each sample. The paired range
	# removes background-only drift from the pixel test.
	var tile: Vector2i = fixtures.NORTH if prop else fixtures.EAST
	var world: Vector2 = board.get_global_transform_with_canvas() * board.world_position_for_tile(tile)
	var region := Rect2i(int(world.x) - CROP_HALF_WIDTH, int(world.y) - CROP_HEIGHT,
		2 * CROP_HALF_WIDTH, CROP_HEIGHT + CROP_BELOW_FEET)
	region = region.intersection(Rect2i(Vector2i.ZERO, SIZE))
	var tail: Array[Image]
	var visible_end: int = -1
	var stable: bool = true
	var base: Dictionary = {"board_backdrop_visible": false}
	for index: int in range(schedule.size()):
		var elapsed: int = int(schedule[index])
		await _submit(scene, after, base)
		var blank: Image = root.get_texture().get_image().get_region(region)
		var shown: Dictionary = base.duplicate()
		shown[presentation_key] = [roster[index]]
		await _submit(scene, after, shown)
		var frame: Image = root.get_texture().get_image().get_region(region)
		await _submit(scene, after, base)
		var control: Image = root.get_texture().get_image().get_region(region)
		stable = stable and not _differs(blank, control, control)
		if _differs(frame, blank, control):
			visible_end = int(schedule[index + 1]) if index + 1 < schedule.size() else playback_end
		if elapsed >= wait_usec - STRIP_WINDOW_USEC: tail.append(frame)
	var destination: String = output.path_join("reduced" if reduced else "normal")
	_write_strip(destination.path_join(subject + "-tail.png"), tail)
	if not FileAccess.file_exists(output.path_join("renderer-proof.png")):
		var proof: String = output.path_join("renderer-proof.png")
		root.get_texture().get_image().save_png(proof)
		print(proof)
	row["visible_end_ms"] = visible_end / 1000.0
	row["stable_reference"] = stable
	var post_visible_usec: int = wait_usec - visible_end
	row["pass"] = visible_end >= 0 and post_visible_usec >= 0 and post_visible_usec <= MAX_POST_VISIBILITY_USEC + DRAW_FRAME_USEC
	print("FEL28 DEATH %s wait_ms=%d visible_end_ms=%d %s" %
		[label, roundi(row["wait_ms"]), roundi(row["visible_end_ms"]), "PASS" if row["pass"] else "FAIL"])
	return row

func _submit(scene: Node, state: Dictionary, shown: Dictionary) -> void:
	scene._render_board_state(state, shown)
	await process_frame
	await RenderingServer.frame_post_draw

func _differs(sample: Image, before: Image, after: Image) -> bool:
	sample.convert(Image.FORMAT_RGBA8)
	before.convert(Image.FORMAT_RGBA8)
	after.convert(Image.FORMAT_RGBA8)
	var value: PackedByteArray = sample.get_data()
	var early: PackedByteArray = before.get_data()
	var late: PackedByteArray = after.get_data()
	if value == early or value == late: return false
	for offset: int in range(0, value.size(), 4):
		for color: int in range(3):
			var channel: int = offset + color
			var low: int = mini(early[channel], late[channel]) - PIXEL_THRESHOLD
			var high: int = maxi(early[channel], late[channel]) + PIXEL_THRESHOLD
			if value[channel] < low or value[channel] > high: return true
	return false

func _write_strip(path: String, frames: Array[Image]) -> void:
	if frames.is_empty(): return
	var frame_size: Vector2i = frames[0].get_size()
	var strip := Image.create((frame_size.x + EDGE) * frames.size() - EDGE, frame_size.y, false, Image.FORMAT_RGBA8)
	for index: int in range(frames.size()):
		strip.blit_rect(frames[index], Rect2i(Vector2i.ZERO, frame_size), Vector2i(index * (frame_size.x + EDGE), 0))
	strip.save_png(path)

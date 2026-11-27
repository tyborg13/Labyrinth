extends RefCounted
## The proof drives the normal tile-click and Pass handlers. MovieWriter records
## the root viewport and game mix at a fixed rate. Dry runs use real transitions.

const FPS := 30
const MOVE_FRAMES := 300
const TURN_FRAMES := 600
const LEAD_FRAMES := 24
const PERF_WARMUP_FRAMES := 180
const PERF_SAMPLE_FRAMES := 600
const PERF_FIXTURE := "01-s0-seed1-0-4_0-t9"
const CASES := {
	"M1a": ["P3", Vector2i(4, 2)],
	"M1b": ["P1", Vector2i(1, 2)],
	"M2": ["P8", Vector2i(-1, -1)],
	"M3": ["P5", Vector2i(-1, -1)],
}

func run(session: SceneTree, mode: String) -> void:
	if mode == "perf":
		await _perf(session)
		return
	var id: String = OS.get_environment("FEL13_MOTION")
	if not CASES.has(id):
		session.fail("unknown motion case " + id)
		return
	var fixture: String = CASES[id][0]
	var target: Vector2i = CASES[id][1]
	if not session.dry:
		session.root.mode = Window.MODE_WINDOWED
		session.root.size = session.SIZE
	if not await session.open_fixture(fixture, not session.dry):
		session.quit(1)
		return
	if not session.dry: await session.point(session.NO_POINTER)
	var scene: Node = session.scene
	var initial: Dictionary = _positions(scene)
	var start: int = Engine.get_process_frames()
	print("FEL13 MOTION START ", id, " ", start)
	if not session.dry: await _wait_frames(session, LEAD_FRAMES)
	if target.x >= 0:
		var player_tile: Vector2i = initial["player"]
		await scene.call("_on_board_tile_clicked", player_tile)
		var legal: Array = scene.get("_player_movement_target_tiles")
		if not legal.has(target):
			session.fail("%s motion target %s unavailable from %s, targets=%s" % [id, target, player_tile, str(legal)])
			return
		await scene.call("_on_board_tile_clicked", target)
		if _positions(scene)["player"] != target:
			session.fail(id + " did not walk to the requested tile")
			return
	else:
		await scene.call("_on_pass_turn_pressed")
		var final: Dictionary = _positions(scene)
		var moved: bool = false
		for actor: Variant in initial:
			if not actor is int or (id == "M3" and actor != 1): continue
			if final.has(actor) and initial[actor] != final[actor]: moved = true
		if not moved:
			session.fail("%s no expected enemy displacement: %s -> %s" % [id, initial, final])
			return
		print("FEL13 MOTION POSITIONS ", id, " ", initial, " -> ", final)
	if not session.dry:
		var frames: int = MOVE_FRAMES if target.x >= 0 else TURN_FRAMES
		await _wait_frames(session, maxi(0, start + frames + 2 - Engine.get_process_frames()))
		await RenderingServer.frame_post_draw
		var image: Image = session.viewport.get_texture().get_image()
		var destination: String = OS.get_environment("FEL13_CAPTURE_DIR").path_join(id + "-motion-proof.png")
		if image == null or image.get_size() != session.SIZE or image.save_png(destination) != OK:
			session.fail("failed to read motion frame " + destination)
			return
		print(destination)
	print("FEL13 MOTION %s PASS %s" % ["DRY" if session.dry else "CAPTURE", id])
	await session.close_fixture()
	session.quit()

func _positions(scene: Node) -> Dictionary:
	var state: Dictionary = scene.get("_combat_state")
	var positions: Dictionary = {"player": state["player"]["pos"]}
	for enemy: Dictionary in state["enemies"]:
		if int(enemy["hp"]) > 0: positions[int(enemy["id"])] = enemy["pos"]
	return positions

func _wait_frames(session: SceneTree, frames: int) -> void:
	for frame: int in frames: await session.process_frame

func _perf(session: SceneTree) -> void:
	if not await session.open_fixture(PERF_FIXTURE):
		session.quit(1)
		return
	Engine.max_fps = 0
	if not session.dry: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _wait_frames(session, PERF_WARMUP_FRAMES)
	var times := PackedFloat64Array()
	var previous: int = Time.get_ticks_usec()
	for frame: int in PERF_SAMPLE_FRAMES:
		await session.process_frame
		var now: int = Time.get_ticks_usec()
		times.append(float(now - previous) / 1000.0)
		previous = now
	times.sort()
	print("FEL13 PERF fixture=%s side=%s renderer=%s frames=%d p50=%.3f p99=%.3f max=%.3f" %
		[PERF_FIXTURE, OS.get_environment("FEL13_SIDE"), DisplayServer.get_name(), times.size(),
		_percentile(times, 0.50), _percentile(times, 0.99), times[-1]])
	if not session.dry:
		await RenderingServer.frame_post_draw
		var path: String = OS.get_environment("FEL13_CAPTURE_DIR").path_join("perf.png")
		var image: Image = session.viewport.get_texture().get_image()
		if image == null or image.get_size() != session.SIZE or image.save_png(path) != OK:
			session.fail("failed to read performance fixture " + path)
			return
		print(path)
	await session.close_fixture()
	session.quit()

func _percentile(sorted: PackedFloat64Array, fraction: float) -> float:
	return sorted[clampi(ceili(sorted.size() * fraction) - 1, 0, sorted.size() - 1)]

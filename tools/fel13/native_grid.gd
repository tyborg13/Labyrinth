extends "res://tools/fel13/native_content.gd"
## Verify the overlay material and board grid on P1 before auditing content pixels.

const Alpha = preload("res://scripts/board_occlusion_alpha.gd")
const TRAP_TILE := Vector2i(2, 2)
const TINT_DELTA := 32
const GRID_PASS_SHARE := 0.90

func run(session: SceneTree) -> void:
	var success: bool = false
	if await session.open_fixture(DEBUG_CASE):
		await session.settle()
		success = await _probe(session)
		await session.close_fixture()
	else:
		_print_result(false, Vector2.ZERO)
	session.quit(0 if success else 1)

func _probe(session: SceneTree) -> bool:
	var overlay: Node = session.board.get("_occlusion_silhouettes")
	var screen: Dictionary = overlay.get("_content_tiles").get(TRAP_TILE, {})
	if screen.is_empty(): return _fail(session, "missing trap overlay")
	var sources: Array[Dictionary] = overlay.current_sources()
	begin(session.board, session.SIZE, overlay._board_fill_grid(), Alpha)
	var audit: Dictionary = {}
	for index: int in sources.size():
		var source: Dictionary = sources[index]
		if source.get("key") == DEBUG_SOURCE:
			audit = _sample_hidden(overlay.alpha_masks.fill_geometry(source), _later_blockers(source, sources, index), true)
			break
	var on: PackedInt32Array = audit.get("on", PackedInt32Array())
	var off: PackedInt32Array = audit.get("off", PackedInt32Array())
	if on.is_empty() or off.is_empty(): return _fail(session, "empty CPU grid samples")
	var original: ShaderMaterial = screen["ink"]
	var diagnostic: ShaderMaterial = original.duplicate()
	diagnostic.set_shader_parameter("grid_probe", true)
	if session.dry:
		print("FEL13 NATIVE GRID PLAN P1 side=branch samples_on=%d samples_off=%d capture=branch/P1-shader-grid.png" %
			[on.size(), off.size()])
		return true
	session.paused = true
	overlay.content_show_through_enabled = false
	var baseline: Image = await _frame(session)
	var painter: Control = screen["painter"]
	var parent: Node = painter.get_parent()
	var patch := Node2D.new()
	patch.material = diagnostic
	patch.draw.connect(func() -> void: patch.draw_rect(screen["bounds"], Color.WHITE))
	parent.add_child(patch)
	parent.move_child(patch, painter.get_index())
	var marked: Image = await _frame(session)
	patch.queue_free()
	overlay.content_show_through_enabled = true
	session.paused = false
	var destination: String = OS.get_environment("FEL13_CAPTURE_DIR")
	var saved: bool = _save(marked, destination.path_join(DEBUG_CASE + "-shader-grid.png"), session)
	var cells: Array[PackedInt32Array]
	cells.assign([on, off])
	var shares: Vector2 = _tint_shares(baseline, marked, cells)
	var passed: bool = saved and shares.x >= GRID_PASS_SHARE and shares.y >= GRID_PASS_SHARE
	_print_result(passed, shares)
	return passed

func _tint_shares(baseline: Image, marked: Image, cells: Array[PackedInt32Array]) -> Vector2:
	if baseline == null or marked == null: return Vector2.ZERO
	var before: PackedByteArray = baseline.get_data()
	var after: PackedByteArray = marked.get_data()
	var matched := Vector2i.ZERO
	for offset: int in cells[0]:
		if _red_green_shift(before, after, offset) >= TINT_DELTA: matched.x += 1
	for offset: int in cells[1]:
		if _red_green_shift(before, after, offset) <= -TINT_DELTA: matched.y += 1
	return Vector2(float(matched.x) / cells[0].size(), float(matched.y) / cells[1].size())

func _red_green_shift(before: PackedByteArray, after: PackedByteArray, offset: int) -> int:
	return (after[offset] - after[offset + 1]) - (before[offset] - before[offset + 1])

func _print_result(ok: bool, shares: Vector2) -> void:
	print("FEL13 NATIVE GRID %s red_in_on=%.6f green_in_off=%.6f" %
		["PASS" if ok else "FAIL", shares.x, shares.y])

func _fail(session: SceneTree, message: String) -> bool:
	_print_result(false, Vector2.ZERO)
	return session.fixture_failure(DEBUG_CASE + " " + message)

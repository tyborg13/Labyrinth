extends RefCounted
## Probe the same Continue snapshots on release and the implementation.
## Footprint shares describe board-local mask samples, independent of the HUD.

const EXPECTED_FIXTURES := 20

var _failure_count: int = 0
var _tested: int = 0
var _states: int = 0
var _required: int = 0
var _hidden: int = 0
var _source_script: Script
var _alpha_script: Script
var _added_subjects: Script

func run(session: SceneTree, mode: String) -> void:
	if mode in ["motion", "perf"]:
		await load(session.tool_dir.path_join("motion.gd")).new().run(session, mode)
		return
	var source_root: String = session.tool_dir.path_join("../..").simplify_path()
	_source_script = load(source_root.path_join("scripts/board_occlusion_sources.gd"))
	_alpha_script = load(source_root.path_join("scripts/board_occlusion_alpha.gd"))
	_added_subjects = load(session.tool_dir.path_join("added_subjects.gd"))
	var edge_probe: RefCounted
	if OS.get_environment("FEL26_AUDIT") == "1":
		edge_probe = load(session.tool_dir.path_join("../fel26/edge_probe.gd").simplify_path()).new()
	var native_probe: RefCounted = load(session.tool_dir.path_join("native_content.gd")).new()
	var branch: bool = OS.get_environment("FEL13_SIDE") == "branch"
	var ids: PackedStringArray = session.fixtures()
	var single: String = OS.get_environment("FEL13_FIXTURE")
	if not single.is_empty(): ids = PackedStringArray([single])
	elif ids.size() != EXPECTED_FIXTURES:
		session.fixture_failure("expected %d fixtures, got %d" % [EXPECTED_FIXTURES, ids.size()])
		_failure_count += 1
	for fixture: String in ids:
		if not await session.open_fixture(fixture):
			_failure_count += 1
			continue
		if edge_probe != null or mode in ["still", "dry", "content"]: await session.settle()
		var report: Dictionary = inspect(session.board, fixture, mode == "witness")
		if edge_probe != null and not edge_probe.audit(session.board, fixture): _failure_count += 1
		if mode in ["still", "dry", "content"]:
			if not await _stills(session, fixture, report, native_probe, branch, mode == "content"): _failure_count += 1
		else:
			if _added_subjects.REQUIRED.has(fixture):
				await _check_added_subject(session, fixture)
			if fixture == "P8": await _check_privacy(session, report["tile"])
		await session.close_fixture()
		_states += 1
	if mode != "witness":
		var stage: String = "DRY RUN" if session.dry else "STILLS"
		if branch:
			if native_probe.subjects_checked == 0 and single.is_empty():
				session.fixture_failure("native content audit found no checker subjects")
				_failure_count += 1
			var pixel_stage: String = "PLAN" if session.dry else ("PASS" if _failure_count == 0 else "FAIL")
			if native_probe.invalid_cases > 0:
				pixel_stage = "INVALID"
			print("FEL16 NATIVE CONTENT %s cases=%d subjects=%d" %
				[pixel_stage, native_probe.cases_checked, native_probe.subjects_checked])
		if _failure_count == 0:
			print("FEL13 %s PASS fixtures=%d" % [stage, _states])
		else:
			print("FEL13 %s FAIL fixtures=%d failures=%d" % [stage, _states, _failure_count])
		session.quit(0 if _failure_count == 0 else 1)
		return
	var label: String = OS.get_environment("FEL13_SIDE")
	print("FEL13 WITNESS %s side=%s fixtures=%d subjects=%d required=%d umbra_hidden=%d failures=%d" %
		["PASS" if _failure_count == 0 else "FAIL", label, _states, _tested, _required, _hidden, _failure_count])
	session.quit(0 if _failure_count == 0 else 1)

func inspect(board: Control, fixture: String, require_show: bool = true, only: String = "") -> Dictionary:
	var overlay: Node = board.get("_occlusion_silhouettes")
	var entries: Dictionary = overlay.get("entries")
	var content: Dictionary = overlay.get("_content_entries") if overlay.has_method("redraw_content_for_layer") else {}
	var alpha: RefCounted = _alpha_script.new()
	var sources: Array[Dictionary] = _source_script.collect(board)
	alpha.prepare(sources)
	var content_sources: Array[Dictionary]
	for source: Dictionary in sources:
		content_sources.append(_source_script.static_content_geometry(board, source, alpha) if source["kind"] in ["prop", "terrain"] else source)
	var fill_grid: Vector4 = overlay._board_fill_grid() if overlay.has_method("_board_fill_grid") else _legacy_grid(board)
	var best := {"tile": Vector2i(-1, -1), "share": -1.0}
	var eligible_cover: Dictionary = {}
	for index: int in sources.size():
		var source: Dictionary = sources[index]
		if not source["eligible"]: continue
		var key: String = source["key"]
		if not only.is_empty() and key != only: continue
		var subject: Dictionary = entries.get(key, {})
		var paint: Dictionary = content.get(key, {})
		var rim: bool = bool(subject.get("on", false))
		var checker: bool = bool(paint.get("on", false)) or (rim and not subject.get("fill_blockers", []).is_empty())
		var counts: Vector3 = _shares(alpha, sources if source["kind"] == "unit" else content_sources, index, checker, fill_grid)
		var hidden: float = counts.x
		var eligible: float = counts.y
		eligible_cover[key] = eligible
		var shown: float = counts.z
		var on: bool = rim or checker
		_tested += 1
		var fills: bool = source.get("fill", false)
		if eligible >= 0.30 and (fills or source["kind"] == "unit"):
			_required += 1
			if require_show and only.is_empty() and not on: _failure_count += 1
		if require_show and only.is_empty() and not fills and source["kind"] != "unit" and on:
			_failure_count += 1
		if hidden > best["share"]:
			best = {"tile": source["tile"], "share": hidden, "eligible": eligible, "rim": rim, "checker": checker}
		print("FEL13 SUBJECT ", JSON.stringify({"fixture": fixture, "key": key, "tile": str(source["tile"]),
			"hidden": snappedf(hidden, 0.000001), "eligible_hidden": snappedf(eligible, 0.000001),
			"fill": fills, "surface_kind": source.get("surface_kind", ""), "on": on, "rim": rim, "checker": checker, "shown": snappedf(shown, 0.000001)}))
	best["sources"] = content_sources
	best["grid"] = fill_grid
	best["content"] = content
	best["eligible_cover"] = eligible_cover
	best["alpha"] = alpha
	return best

func _check_added_subject(session: SceneTree, fixture: String) -> void:
	var key: String = _added_subjects.REQUIRED[fixture]
	_added_subjects.present(session.board, fixture)
	await session.settle()
	var result: Dictionary = inspect(session.board, fixture, true, key)
	var ok: bool = float(result.get("eligible", 0.0)) >= 0.30 and bool(result.get("checker", false))
	if key == _added_subjects.DEATH_SITE: ok = ok and bool(result.get("rim", false))
	print("FEL13 REQUIRED SUBJECT %s fixture=%s key=%s covered=%.6f" %
		["PASS" if ok else "FAIL", fixture, key, float(result.get("eligible", 0.0))])
	if not ok: _failure_count += 1

func _shares(alpha: RefCounted, sources: Array[Dictionary], index: int, checker: bool, grid: Vector4) -> Vector3:
	var source: Dictionary = sources[index]
	var points: PackedVector2Array = source.get("mask", {}).get("points", PackedVector2Array())
	if points.is_empty(): return Vector3(0.0, 0.0, 1.0)
	var bounds: Rect2 = source["rect"]
	var sample_size: Vector2 = bounds.size / Vector2(source["mask"]["size"])
	var flip: bool = source.get("mask_flip", false)
	var blockers: Array[Dictionary]
	for later: int in range(index + 1, sources.size()):
		var blocker: Dictionary = sources[later]
		if blocker["kind"] in ["prop", "terrain", "unit"] and bounds.intersects(blocker["rect"]): blockers.append(blocker)
	var hidden: int = 0
	var eligible_hidden: int = 0
	var shown: float = 0.0
	for point: Vector2 in points:
		if flip: point.x = 1.0 - point.x
		var world: Vector2 = bounds.position + bounds.size * point
		var static_cover: bool = false
		var actor_cover: bool = false
		for blocker: Dictionary in blockers:
			if not alpha.opaque_at(blocker, world): continue
			if blocker["kind"] == "unit": actor_cover = true
			else: static_cover = true
		var covered: bool = static_cover or actor_cover
		if covered: hidden += 1
		var accepts_actor: bool = source["kind"] in ["unit", "trap", "loot"]
		if static_cover or (accepts_actor and actor_cover): eligible_hidden += 1
		if not covered:
			shown += 1.0
		elif checker and static_cover and (source["kind"] == "unit" or not actor_cover):
			shown += _checker_fraction(world, sample_size, grid)
	return Vector3(hidden, eligible_hidden, shown) / float(points.size())

# Integrate the checker within an alpha sample. A center-only test aliases
# when the quarter-scale mask stride is a multiple of the checker period.
func _checker_fraction(point: Vector2, sample_size: Vector2, grid: Vector4) -> float:
	var cell_size := Vector2(grid.z, grid.w)
	var lower: Vector2 = (point - sample_size * 0.5 - Vector2(grid.x, grid.y)) / cell_size
	var span: Vector2 = sample_size / cell_size
	var upper: Vector2 = lower + span
	var even_x: float = (_even_area(upper.x) - _even_area(lower.x)) / span.x
	var even_y: float = (_even_area(upper.y) - _even_area(lower.y)) / span.y
	return even_x * even_y + (1.0 - even_x) * (1.0 - even_y)

func _even_area(axis: float) -> float:
	var periods: float = floorf(axis * 0.5)
	return periods + minf(axis - periods * 2.0, 1.0)

func _legacy_grid(board: Control) -> Vector4:
	var viewport: Viewport = board.get_viewport()
	var stretch: Vector2 = viewport.get_stretch_transform().get_scale()
	var scale: Vector2 = board.get_global_transform().get_scale().abs() * stretch
	var height: int = roundi(viewport.get_visible_rect().size.y * stretch.y)
	var fit: Vector2i = preload("res://scripts/tile_burst_fx.gd").choice_for(board._tile_width() * scale.x, height)
	var cell: Vector2 = Vector2.ONE * float(fit.x) / scale
	var origin: Vector2 = board._board_origin()
	return Vector4(origin.x, origin.y, cell.x, cell.y)

func _check_privacy(session: SceneTree, tile: Vector2i) -> void:
	var board: Control = session.board
	var shown: Dictionary = board.presentation.duplicate(false)
	var allowed: Array[Vector2i] = board._rendered_tiles_in_draw_order()
	var before: Array[Dictionary] = _source_script.collect(board)
	var hidden_tiles: Dictionary = {tile: true}
	for source: Dictionary in before:
		if source["eligible"] and source["kind"] in ["loot", "trap", "surface"]:
			hidden_tiles[source["tile"]] = true
	for hidden_tile: Vector2i in hidden_tiles: allowed.erase(hidden_tile)
	for source: Dictionary in before:
		if source["eligible"] and hidden_tiles.has(source["tile"]): _hidden += 1
	shown["umbra_visible_tiles"] = allowed
	board.set_combat_state(board.combat_state, [], [], Vector2i(-1, -1), "", "", board.exit_tiles, board.exit_icon_ids, shown)
	await session.settle()
	var overlay: Node = board.get("_occlusion_silhouettes")
	var entries: Dictionary = overlay.get("entries")
	for entry: Dictionary in entries.values():
		if hidden_tiles.has(entry["source"]["tile"]): _failure_count += 1
	if overlay.has_method("redraw_content_for_layer"):
		for entry: Dictionary in overlay.get("_content_entries").values():
			if hidden_tiles.has(entry["source"]["tile"]): _failure_count += 1
	for source: Dictionary in _source_script.collect(board):
		if source["eligible"] and hidden_tiles.has(source["tile"]): _failure_count += 1

func _stills(session: SceneTree, fixture: String, report: Dictionary, native_probe: RefCounted, branch: bool, content_only: bool) -> bool:
	var tile: Vector2i = report["tile"]
	if tile.x < 0:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(session.fixture_root.path_join(fixture).path_join("score.json")))
		var fallback: Array = data["focus"]["tile"]
		tile = Vector2i(fallback[0], fallback[1])
	var destination: String = OS.get_environment("FEL13_CAPTURE_DIR")
	session.paused = true
	# Keep the full stills path's frame boundary even without a rest PNG.
	if content_only and not session.dry: await RenderingServer.frame_post_draw
	var rest_ok: bool = content_only or session.dry or await _save_frame(session, destination.path_join(fixture + "-rest.png"))
	native_probe.begin(session.board, session.SIZE, report["grid"], _alpha_script)
	var content_ok: bool = await native_probe.capture(session, fixture, destination, report, branch)
	session.paused = false
	if content_only: return content_ok
	await session.point(session.tile_point(tile))
	await session.settle()
	var hovered: Vector2i = session.scene.get("_hovered_board_tile")
	if hovered != tile:
		var reveal: Node = session.board.get("_occlusion_reveal")
		# Covered or UI-overlapped tiles can be focused through the same board
		# hover signal without moving the operating-system pointer.
		session.board.emit_signal("tile_hovered", tile)
		await session.settle()
		if reveal.focus_tile != tile: return session.fixture_failure("%s could not hover %s" % [fixture, tile])
	if not session.dry and not await _save_frame(session, destination.path_join(fixture + "-hover.png")):
		return false
	print("FEL13 STILL PHASES ", fixture, " hover=", tile)
	return rest_ok and content_ok

func _save_frame(session: SceneTree, path: String) -> bool:
	await RenderingServer.frame_post_draw
	var image: Image = session.viewport.get_texture().get_image()
	if image == null or image.get_size() != session.SIZE or image.save_png(path) != OK:
		return session.fixture_failure("could not save 1920x1080 frame " + path)
	print(path)
	return true

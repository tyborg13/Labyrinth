extends RefCounted
## The on, off and clear frames share a frozen presentation and the CPU masks.

const ON_DELTA := 16
const CONTENT_ALPHA := 0.75
const MAX_FORBIDDEN_SHARE := 0.0
const OFF_DELTA := 12
const MIN_ON_SHARE := 0.90
const MAX_OFF_SHARE := 0.02
const EDGE_SAMPLES := [0.125, 0.375, 0.625, 0.875]
const STATIC_KINDS := ["prop", "terrain"]
const DEBUG_CASE := "P1"
const DEBUG_SOURCE := "trap:fel13_trap:(2, 2)"

var subjects_checked: int = 0
var excluded_checked: int = 0
var cases_checked: int = 0
var invalid_cases: int = 0
var _projection: Transform2D
var _unproject: Transform2D
var _frame_size: Vector2i
var _grid: Vector4
var _alpha: Script

func begin(board: Control, size: Vector2i, grid: Vector4, alpha: Script) -> void:
	_projection = board.get_viewport().get_stretch_transform() * board.get_global_transform_with_canvas()
	_unproject = _projection.affine_inverse()
	_frame_size = size
	_grid = grid
	_alpha = alpha

func capture(session: SceneTree, fixture: String, destination: String, report: Dictionary, branch: bool) -> bool:
	var sources: Array[Dictionary] = report["sources"]
	var content: Dictionary = report["content"]
	var eligible_cover: Dictionary = report["eligible_cover"]
	var alpha_masks: RefCounted = report["alpha"]
	var crops: Dictionary = {}
	var audits: Dictionary = {}
	var excluded: Dictionary = {}
	var blocker_tiles: Dictionary = {}
	var allowed_on: Dictionary = {}
	var pathological: bool = fixture.begins_with("P")
	for index: int in sources.size():
		var source: Dictionary = sources[index]
		if not source["eligible"]: continue
		var key: String = source["key"]
		var fills: bool = source.get("fill", false)
		var candidate: bool = branch and source["kind"] != "unit"
		# Measure subjects the geometry calls for even if the painter failed to
		# attach or its fade never started.
		var expected: bool = candidate and fills and (content.get(key, {}).get("on", false) or eligible_cover[key] >= 0.30)
		var forbidden: bool = candidate and not fills
		if not pathological and not expected and not forbidden: continue
		var blockers: Array[Dictionary] = _later_blockers(source, sources, index)
		if blockers.is_empty(): continue
		var geometry: Dictionary = alpha_masks.fill_geometry(source) if fills else source
		var retained: Dictionary = content.get(key, {})
		if expected and retained.has("fill_geometry"):
			geometry = retained["fill_geometry"]
		var claim: Dictionary = _sample_hidden(geometry, blockers, expected or forbidden)
		if pathological and claim["hidden"].has_area():
			var center: Vector2 = Rect2(claim["hidden"]).get_center()
			crops[key] = [center.x, center.y]
		if expected and claim["static_pixels"] > 0:
			audits[key] = claim
			claim["geometry"] = geometry
			claim["blockers"] = blockers
			claim["fade"] = float(content.get(key, {}).get("alpha", 1.0))
			blocker_tiles.merge(claim["blocker_tiles"], true)
			for pixel: int in claim["on"]: allowed_on[pixel] = true
		elif forbidden and not claim["hidden_pixels"].is_empty():
			excluded[key] = claim["hidden_pixels"]
	if branch:
		cases_checked += 1
		subjects_checked += audits.size()
		excluded_checked += excluded.size()
	if session.dry:
		print("FEL16 NATIVE CONTENT PLAN ", fixture, " subjects=", audits.size(), " excluded=", excluded.size(),
			" clear_blocker_tiles=", blocker_tiles.size(), " crops=", crops.size())
		if not branch: return true
		var overlay: Node = session.board.get("_occlusion_silhouettes")
		overlay.content_show_through_enabled = false
		var clear_paint: RefCounted = load(session.tool_dir.path_join("clear_frame.gd")).new()
		var installed: int = clear_paint.install(session.board, blocker_tiles)
		var clear_submitted: bool = await clear_paint.submit(session, "clear")
		var off_restored: bool = await clear_paint.submit(session, "off")
		overlay.content_show_through_enabled = true
		if installed != blocker_tiles.size() or not clear_submitted or not off_restored:
			return _invalid(fixture, "prop submission did not change and restore")
		print("FEL16 CLEAR COMMANDS PASS ", fixture, " subjects=", audits.size(),
			" blockers=", installed, " slices=", clear_paint.changed_slices())
		return true
	var ok: bool = true
	if pathological and OS.get_environment("FEL13_MODE") != "content":
		var metadata := FileAccess.open(destination.path_join(fixture + "-crops.json"), FileAccess.WRITE)
		if metadata == null:
			ok = session.fixture_failure(fixture + " could not write crop coordinates")
		else:
			metadata.store_string(JSON.stringify(crops))
	if not branch: return ok
	var overlay: Node = session.board.get("_occlusion_silhouettes")
	var shipped: Image = await _frame(session)
	ok = _save(shipped, destination.path_join(fixture + "-content-on.png"), session) and ok
	overlay.content_show_through_enabled = false
	var disabled: Image = await _frame(session)
	ok = _save(disabled, destination.path_join(fixture + "-content-off.png"), session) and ok
	var clear_paint: RefCounted = load(session.tool_dir.path_join("clear_frame.gd")).new()
	var installed: int = clear_paint.install(session.board, blocker_tiles)
	var clear_submitted: bool = await clear_paint.submit(session, "clear")
	var clear: Image = await _frame(session)
	var off_restored: bool = await clear_paint.submit(session, "off")
	overlay.content_show_through_enabled = true
	ok = _save(clear, destination.path_join(fixture + "-content-clear.png"), session) and ok
	if installed != blocker_tiles.size() or not clear_submitted or not off_restored:
		return _invalid(fixture, "prop submission did not change and restore")
	if shipped == null or disabled == null or clear == null: return _invalid(fixture, "frame missing")
	var on: PackedByteArray = shipped.get_data()
	var off: PackedByteArray = disabled.get_data()
	var clear_pixels: PackedByteArray = clear.get_data()
	var unchanged: PackedStringArray = unchanged_subjects(off, clear_pixels, audits)
	if not unchanged.is_empty():
		print("FEL16 CLEAR UNCHANGED ", fixture, " subjects=", ", ".join(unchanged))
		return _invalid(fixture, "clear==off")
	_attribute_approved_edges(fixture, on, off, excluded, audits, allowed_on)
	ok = _compare_reference(session, fixture, on, audits) and ok
	for key: String in audits:
		var audit: Dictionary = audits[key]
		var shares: Vector2 = compare(on, off, clear_pixels, audit["on"], audit["off"], audit["fade"])
		if shares.x >= MIN_ON_SHARE and shares.y <= MAX_OFF_SHARE: continue
		printerr("FEL16 NATIVE CONTENT FAIL %s %s on=%.6f off=%.6f" % [fixture, key, shares.x, shares.y])
		ok = false
	for key: String in excluded:
		var share: float = forbidden_share(on, off, excluded[key], allowed_on)
		if share <= MAX_FORBIDDEN_SHARE: continue
		printerr("FEL16 NATIVE CONTENT FAIL %s %s forbidden=%.6f" % [fixture, key, share])
		ok = false
	return ok

func _invalid(fixture: String, reason: String) -> bool:
	invalid_cases += 1
	printerr("FEL16 NATIVE CONTENT INVALID ", fixture, " ", reason)
	return false


static func unchanged_subjects(off: PackedByteArray, clear: PackedByteArray, audits: Dictionary) -> PackedStringArray:
	var unchanged := PackedStringArray()
	for key: String in audits:
		var audit: Dictionary = audits[key]
		if not _has_rgb_change(off, clear, audit["on"]) and not _has_rgb_change(off, clear, audit["off"]):
			unchanged.append(key)
	return unchanged


static func _has_rgb_change(off: PackedByteArray, clear: PackedByteArray, cells: PackedInt32Array) -> bool:
	for pixel: int in cells:
		if _rgb_difference(off, clear, pixel) > 0: return true
	return false


func _attribute_approved_edges(fixture: String, on: PackedByteArray, off: PackedByteArray,
		excluded: Dictionary, audits: Dictionary, allowed_on: Dictionary) -> void:
	# A pixel at a sprite or diamond edge can contain checker coverage even
	# when its centre is outside the approved shape. Resolve that shared
	# pixel by sampling inside its own area and checking actual blocker order.
	for key: String in excluded:
		for offset: int in excluded[key]:
			if allowed_on.has(offset) or _rgb_difference(on, off, offset) <= OFF_DELTA * 3: continue
			var pixel := Vector2i(offset / 4 % _frame_size.x, offset / 4 / _frame_size.x)
			var approved: String = _approved_edge_subject(pixel, audits)
			if approved.is_empty(): continue
			var cells: PackedInt32Array = audits[approved]["on"]
			cells.append(offset)
			audits[approved]["on"] = cells
			allowed_on[offset] = true
			print("FEL16 NATIVE CONTENT EDGE ", fixture, " pixel=", pixel, " subject=", approved, " overlaps=", key)


func _approved_edge_subject(pixel: Vector2i, audits: Dictionary) -> String:
	var framebuffer_pixel := Rect2(Vector2(pixel), Vector2.ONE)
	for key: String in audits:
		var audit: Dictionary = audits[key]
		var geometry: Dictionary = audit["geometry"]
		if not (_projection * (geometry["rect"] as Rect2)).intersects(framebuffer_pixel): continue
		for y: float in EDGE_SAMPLES:
			for x: float in EDGE_SAMPLES:
				var point: Vector2 = _unproject * (framebuffer_pixel.position + Vector2(x, y))
				if not on_cell(point, _grid) or not _alpha.fill_contains(geometry, point): continue
				var static_cover: bool = false
				var actor_cover: bool = false
				for blocker: Dictionary in audit["blockers"]:
					if not _alpha.opaque_at(blocker, point): continue
					if blocker["kind"] == "unit": actor_cover = true
					else: static_cover = true
				if static_cover and not actor_cover: return key
	return ""


func _compare_reference(session: SceneTree, fixture: String, on: PackedByteArray, audits: Dictionary) -> bool:
	var directory: String = OS.get_environment("FEL16_REFERENCE_DIR")
	if directory.is_empty() or audits.is_empty(): return true
	var path: String = directory.path_join(fixture + "-content-on.png")
	var reference: Image = Image.load_from_file(path)
	if reference == null or reference.get_size() != _frame_size:
		return session.fixture_failure(fixture + " missing reference on frame " + path)
	reference.convert(Image.FORMAT_RGBA8)
	var pixels: PackedByteArray = reference.get_data()
	var passed: bool = true
	for key: String in audits:
		var cells: PackedInt32Array = audits[key]["on"]
		var matches: int = 0
		for pixel: int in cells:
			if _rgb_difference(on, pixels, pixel) <= ON_DELTA * 3: matches += 1
		var share: float = float(matches) / maxf(1, cells.size())
		if share >= MIN_ON_SHARE: continue
		printerr("FEL16 NATIVE REFERENCE FAIL %s %s on=%.6f" % [fixture, key, share])
		passed = false
	if passed: print("FEL16 NATIVE REFERENCE PASS ", fixture, " subjects=", audits.size())
	return passed


func _later_blockers(source: Dictionary, sources: Array[Dictionary], index: int) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for later: int in range(index + 1, sources.size()):
		var blocker: Dictionary = sources[later]
		if blocker["kind"] not in STATIC_KINDS and blocker["kind"] != "unit": continue
		if (source["rect"] as Rect2).intersects(blocker["rect"]): result.append(blocker)
	return result

func _sample_hidden(source: Dictionary, blockers: Array[Dictionary], audit: bool) -> Dictionary:
	var bounds: Rect2 = _projection * (source["rect"] as Rect2)
	var start := Vector2i(bounds.position.floor())
	var projected := Rect2i(start, Vector2i(bounds.end.ceil()) - start)
	var view := Rect2i(Vector2i.ZERO, _frame_size)
	projected = projected.intersection(view)
	var hidden := Rect2i()
	var static_pixels: int = 0
	var on := PackedInt32Array()
	var off := PackedInt32Array()
	var hidden_pixels := PackedInt32Array()
	var blocker_tiles: Dictionary = {}
	for y: int in range(projected.position.y, projected.end.y):
		for x: int in range(projected.position.x, projected.end.x):
			var point: Vector2 = _unproject * Vector2(x + 0.5, y + 0.5)
			var inside: bool = _alpha.fill_contains(source, point) if source.get("fill", false) else _alpha.opaque_at(source, point)
			if not inside: continue
			var covers: Array[Vector2i]
			var actor_cover: bool = false
			for blocker: Dictionary in blockers:
				if not _alpha.opaque_at(blocker, point): continue
				if blocker["kind"] == "unit": actor_cover = true
				else: covers.append(blocker["tile"])
			if covers.is_empty() and not actor_cover: continue
			var pixel := Rect2i(x, y, 1, 1)
			hidden = hidden.merge(pixel) if hidden.has_area() else pixel
			var offset: int = (y * _frame_size.x + x) * 4
			if audit: hidden_pixels.append(offset)
			if covers.is_empty() or actor_cover: continue
			static_pixels += 1
			if not audit: continue
			for tile: Vector2i in covers: blocker_tiles[tile] = true
			if on_cell(point, _grid): on.append(offset)
			else: off.append(offset)
	return {"hidden": hidden, "static_pixels": static_pixels, "on": on, "off": off,
		"blocker_tiles": blocker_tiles, "hidden_pixels": hidden_pixels}

static func on_cell(point: Vector2, grid: Vector4) -> bool:
	var cell: Vector2 = ((point - Vector2(grid.x, grid.y)) / Vector2(grid.z, grid.w)).floor()
	return posmod(int(cell.x) + int(cell.y), 2) == 0

static func compare(on: PackedByteArray, off: PackedByteArray, clear: PackedByteArray,
		on_cells: PackedInt32Array, off_cells: PackedInt32Array, fade: float) -> Vector2:
	var matched_on: int = 0
	var altered_off: int = 0
	var amount: float = CONTENT_ALPHA * fade
	for pixel: int in on_cells:
		var difference: float = 0.0
		for channel: int in 3:
			var index: int = pixel + channel
			difference += absf(float(on[index]) - lerpf(off[index], clear[index], amount))
		if difference <= ON_DELTA * 3: matched_on += 1
	for pixel: int in off_cells:
		if _rgb_difference(on, off, pixel) > OFF_DELTA * 3: altered_off += 1
	return Vector2(float(matched_on) / maxf(1, on_cells.size()),
		float(altered_off) / maxf(1, off_cells.size()))

static func forbidden_share(on: PackedByteArray, off: PackedByteArray,
		pixels: PackedInt32Array, allowed_on: Dictionary) -> float:
	var tested: int = 0
	var changed: int = 0
	for pixel: int in pixels:
		# A permitted exit can share a floor diamond with excluded rubble.
		# That on-cell belongs to the positive audit for the exit.
		if allowed_on.has(pixel): continue
		tested += 1
		if _rgb_difference(on, off, pixel) > OFF_DELTA * 3: changed += 1
	return float(changed) / maxf(1, tested)

static func _rgb_difference(on: PackedByteArray, off: PackedByteArray, offset: int) -> int:
	return absi(on[offset] - off[offset]) + absi(on[offset + 1] - off[offset + 1]) + absi(on[offset + 2] - off[offset + 2])

func _frame(session: SceneTree) -> Image:
	# Wait for changes submitted from the previous frame_post_draw callback.
	await session.process_frame
	await RenderingServer.frame_post_draw
	var image: Image = session.viewport.get_texture().get_image()
	if image == null or image.get_size() != _frame_size: return null
	image.convert(Image.FORMAT_RGBA8)
	return image

func _save(image: Image, path: String, session: SceneTree) -> bool:
	if image == null or image.save_png(path) != OK:
		return session.fixture_failure("could not save 1920x1080 frame " + path)
	print(path)
	return true

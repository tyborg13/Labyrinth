extends RefCounted

## Disk representation only. All render targets, clocks and texture hashes stay
## with their existing owners. Logical PNG names stay stable in proof manifests;
## the index points to the chosen lossless payload's real extension.
const MARGIN_PX: int = 16
const DEFAULT_ENCODING: String = "png"
const RAW_MAGIC: String = "UCAPRGBA"
const INDEX_NAME: String = "native_storage.json"
static var directory: String
static var encoding: String = DEFAULT_ENCODING
static var legacy: bool = false
static var board_crop: Rect2i
static var production_planning: bool = false
static var production_bounds: Rect2
static var production_fixture_bounds: Rect2
static var production_board_transforms: Array[Transform2D]
static var entries: Dictionary = {}
static var references: Dictionary = {}

static func setup(output: String) -> void:
	directory = output
	entries = {}
	references = {}
	board_crop = Rect2i()
	production_planning = false
	production_bounds = Rect2()
	production_fixture_bounds = Rect2()
	production_board_transforms.clear()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	legacy = args.has("--legacy-full-frames")
	encoding = DEFAULT_ENCODING
	if args.has("--capture-encoding"):
		encoding = args[args.find("--capture-encoding") + 1]
	if args.has("--capture-encoding-file"):
		var report_path: String = args[args.find("--capture-encoding-file") + 1]
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(report_path))
		assert(report.get("ok", false), "Encoding benchmark did not select a lossless candidate")
		encoding = str(report.get("selected_codec", ""))
	assert(encoding in ["png", "webp", "rgba"], "Unknown lossless capture encoding")

static func clamp_crop(bounds: Rect2, size: Vector2i) -> Rect2i:
	var start := Vector2i(floori(bounds.position.x) - MARGIN_PX, floori(bounds.position.y) - MARGIN_PX)
	var end := Vector2i(ceili(bounds.end.x) + MARGIN_PX, ceili(bounds.end.y) + MARGIN_PX)
	start = start.clamp(Vector2i.ZERO, size)
	end = end.clamp(start, size)
	assert(end.x > start.x and end.y > start.y, "Action canvas outside frame")
	return Rect2i(start, end - start)

static func begin_production() -> void:
	assert(entries.is_empty(), "Production crop must be planned before writing frames")
	production_planning = true
	production_bounds = Rect2()
	production_fixture_bounds = Rect2()
	production_board_transforms.clear()
	board_crop = Rect2i()

static func include_production_board_position(board: Control, position: Vector2) -> void:
	assert(production_planning, "Production crop is already fixed")
	if not position.is_finite(): return
	# Scene recreation can sample the room-to-combat centering tween earlier
	# than the logic pass. Reserve its existing room endpoint, not an estimated
	# duration or a larger margin. The cubic easing stays between its endpoints.
	var parent_transform: Transform2D = board.get_global_transform_with_canvas() * board.get_transform().affine_inverse()
	var local: Transform2D = board.get_transform()
	local.origin += position - board.position
	production_board_transforms.append(parent_transform * local)

static func record_production_canvas(board: Control, unit: Dictionary) -> void:
	assert(production_planning, "Production crop is already fixed")
	var bounds: Rect2 = production_canvas(board, unit)
	production_bounds = production_bounds.merge(bounds) if production_bounds.has_area() else bounds
	if production_fixture_bounds.has_area():
		# The fixture envelope is board-local too: an entrance/pan transform
		# must not strand even its unused facing bounds at the first position.
		production_bounds = production_bounds.merge(board.get_global_transform_with_canvas() * production_fixture_bounds)

static func finish_production(size: Vector2i) -> void:
	assert(production_planning and production_bounds.has_area(), "Missing production action canvas")
	assert(entries.is_empty(), "Production crop must be fixed before writing frames")
	board_crop = clamp_crop(production_bounds, size)
	production_planning = false

static func plan_production(board: Control, _actor_type: String, data: Dictionary, make_fixture: Callable, contact_tile: Vector2i) -> void:
	if legacy: return
	var states: Array[Dictionary]
	for clip: String in data["clips"]:
		for selector: String in data["clips"][clip].get("intents", []):
			states.append(make_fixture.call(selector.get_slice(":", 0)))
	# Hit/death use the capture owner's existing contact tile.
	var contact: Dictionary = make_fixture.call("")
	states.append(contact.duplicate(true))
	contact["enemies"][0]["pos"] = contact_tile
	states.append(contact)
	var engine := preload("res://scripts/combat_engine.gd").new()
	var bounds := Rect2()
	for state: Dictionary in states:
		var unit: Dictionary = state["enemies"][0]
		bounds = _include_unit(board, unit, bounds)
		var context: Dictionary = engine.enemy_intent_plan(state, 0)
		for action: Dictionary in unit.get("intent", {}).get("actions", []):
			var after: Dictionary = engine._resolve_enemy_action(state.duplicate(true), 0, action, null, {}, engine._dictionary_values([]), context)
			if not after.get("enemies", []).is_empty(): bounds = _include_unit(board, after["enemies"][0], bounds)
		# Some proof owners demonstrate a move directly instead of resolving it.
		if data["clips"].get("move", {}).get("intents", []).is_empty():
			for delta: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0)]:
				var moved: Dictionary = unit.duplicate(true)
				moved["pos"] += delta
				bounds = _include_unit(board, moved, bounds)
	assert(bounds.has_area(), "Missing production action canvas")
	# Keep cap-01's conservative fixture envelope, including unused facings.
	# It is only a seed: the complete capture pass adds the real screen canvas
	# at every frame, including board entrance motion and texture-origin travel.
	production_fixture_bounds = board.get_global_transform_with_canvas().affine_inverse() * bounds
	production_bounds = production_bounds.merge(bounds) if production_bounds.has_area() else bounds
	for transform: Transform2D in production_board_transforms:
		production_bounds = production_bounds.merge(transform * production_fixture_bounds)

static func _include_unit(board: Control, unit: Dictionary, bounds: Rect2) -> Rect2:
	var center: Vector2 = board.world_position_for_unit_origin(unit, unit["pos"])
	var body: Rect2 = board._unit_draw_rect_for_texture(unit, center, board._unit_hud_anchor_texture(unit))
	var Presentation = preload("res://scripts/actor_presentation.gd")
	for view: String in ["front", "rear"]:
		for mirrored: bool in [false, true]:
			var source_position: Vector2 = body.position
			if Presentation.has_profile(str(unit["type"])):
				var anchor: Vector2 = Presentation.floor_anchor(str(unit["type"]), view, mirrored)
				source_position = center - anchor * body.size / 255.0
			var canvas := Rect2(source_position - Vector2(128, 128) * body.size / 255.0, body.size * Vector2(512, 512) / 255.0)
			canvas = board.get_global_transform_with_canvas() * canvas
			bounds = bounds.merge(canvas) if bounds.has_area() else canvas
	return bounds

static func set_crop(bounds: Rect2, size: Vector2i) -> void:
	if not legacy: board_crop = clamp_crop(bounds, size)

static func metadata() -> Dictionary:
	if legacy or not board_crop.has_area(): return {}
	return {"crop": rect_values(board_crop), "encoding": encoding, "full_references": references.duplicate()}

static func rect_values(rect: Rect2i) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

static func save(image: Image, path: String, clip: String = "") -> void:
	assert(not production_planning, "Cannot write frames before completing the production crop plan")
	if legacy:
		_check_write(image.save_png(path), path)
		return
	var size: Vector2i = image.get_size()
	var crop := Rect2i(Vector2i.ZERO, size)
	# 512-square isolated layers already are the full action canvas. Rest crops
	# and composed review canvases retain their own image spaces without fitting.
	if size == Vector2i(1920, 1080) and board_crop.has_area(): crop = board_crop
	var reference: String = ""
	if clip.is_empty() and crop != Rect2i(Vector2i.ZERO, size):
		var logical: String = _relative(path)
		clip = logical.get_slice("/", 0).trim_prefix("pair_").get_basename()
	if not clip.is_empty() and crop != Rect2i(Vector2i.ZERO, size):
		reference = "full_" + clip + ".png"
		if not references.has(clip):
			_check_write(image.save_png(directory.path_join(reference)), reference)
			references[clip] = reference
	var cropped: Image = image.get_region(crop)
	cropped.convert(Image.FORMAT_RGBA8)
	var stored: String = path.get_basename() + "." + encoding
	_check_write(write_image(cropped, stored, encoding), stored)
	var logical: String = _relative(path)
	entries[logical] = {"stored_file": _relative(stored), "size": [size.x, size.y], "crop": rect_values(crop), "encoding": encoding}
	if not reference.is_empty(): entries[logical]["reference"] = reference

static func write_image(image: Image, path: String, codec: String) -> Error:
	match codec:
		"png": return image.save_png(path)
		"webp": return image.save_webp(path, false)
		"rgba":
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null: return FileAccess.get_open_error()
			file.store_buffer(RAW_MAGIC.to_ascii_buffer())
			file.store_32(image.get_width())
			file.store_32(image.get_height())
			file.store_buffer(image.get_data())
			return file.get_error()
	return ERR_INVALID_PARAMETER

static func file_hash(path: String) -> String:
	var record: Dictionary = entries.get(_relative(path), {})
	return FileAccess.get_sha256(directory.path_join(str(record["stored_file"])) if not record.is_empty() else path)

static func proof_png(path: String) -> String:
	# Existing visual contracts inspect real PNGs at full capture resolution.
	# These few proof exports do not replace or re-render captured actor pixels.
	var record: Dictionary = entries.get(_relative(path), {})
	if record.is_empty(): return path
	var image: Image = load_image(directory.path_join(str(record["stored_file"])), str(record["encoding"]))
	var values: Array = record["crop"]
	var crop := Rect2i(values[0], values[1], values[2], values[3])
	var size := Vector2i(record["size"][0], record["size"][1])
	var full: Image = Image.load_from_file(directory.path_join(record["reference"])) if record.has("reference") else Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	full.convert(Image.FORMAT_RGBA8)
	full.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), crop.position)
	var target: String = directory.path_join("proof_exports").path_join(_relative(path))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target.get_base_dir()))
	_check_write(full.save_png(target), target)
	return target

static func load_image(path: String, codec: String) -> Image:
	if codec != "rgba": return Image.load_from_file(path)
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file.get_buffer(8).get_string_from_ascii() == RAW_MAGIC)
	var width: int = file.get_32()
	var height: int = file.get_32()
	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, file.get_buffer(width * height * 4))

static func finish() -> void:
	if legacy: return
	var file := FileAccess.open(directory.path_join(INDEX_NAME), FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "files": entries}))

static func _relative(path: String) -> String:
	return path.trim_prefix(directory.trim_suffix("/") + "/")

static func _check_write(error: Error, path: String) -> void:
	if error != OK:
		push_error("Could not write native frame: " + path + " (" + error_string(error) + ")")
		assert(false, "Native frame write failed")

static func annotate(manifest: Dictionary, size: Vector2i = Vector2i(1920, 1080)) -> Dictionary:
	if not legacy:
		manifest["size"] = [size.x, size.y]
		manifest["crop"] = rect_values(board_crop) if size == Vector2i(1920, 1080) and board_crop.has_area() else [0, 0, size.x, size.y]
		manifest["encoding"] = encoding
	return manifest

static func production_canvas(board: Control, unit: Dictionary) -> Rect2:
	return board.get_global_transform_with_canvas() * board._unit_texture_draw_rect(unit, board._unit_center(unit))

static func production_canvas_error(bounds: Rect2, scenario: String, clip: String, frame: int) -> String:
	var context: String = "scenario=%s clip=%s frame=%d" % [scenario, clip, frame]
	if not board_crop.has_area(): return "Missing production crop plan: " + context
	# Verify the current full canvas is contained, not just the painted bbox.
	var start := Vector2i(floori(bounds.position.x), floori(bounds.position.y)).clamp(Vector2i.ZERO, Vector2i(1920, 1080))
	var end := Vector2i(ceili(bounds.end.x), ceili(bounds.end.y)).clamp(start, Vector2i(1920, 1080))
	if not board_crop.encloses(Rect2i(start, end - start)):
		return "Production action canvas escaped the fixed run crop: %s canvas=%s crop=%s" % [context, bounds, board_crop]
	return ""

static func check_production_canvas(board: Control, unit: Dictionary, scenario: String, clip: String, frame: int) -> bool:
	if legacy: return true
	var error: String = production_canvas_error(production_canvas(board, unit), scenario, clip, frame)
	if error.is_empty(): return true
	push_error(error)
	return false

static func plan_review(canvas: SubViewport) -> void:
	if legacy: return
	var bounds := Rect2()
	for child: Node in canvas.get_children():
		if not child is Sprite2D: continue
		var display: Sprite2D = child
		var rect: Rect2 = display.transform * display.get_rect()
		bounds = bounds.merge(rect) if bounds.has_area() else rect
		# Idle comparisons add the second display after the rest still. Reserve
		# its existing symmetric slot now, keeping one rect for the entire run.
		var opposite := Rect2(Vector2(canvas.size.x - rect.end.x, rect.position.y), rect.size)
		bounds = bounds.merge(opposite)
	assert(bounds.has_area(), "Review action canvases missing")
	board_crop = clamp_crop(bounds, canvas.size)

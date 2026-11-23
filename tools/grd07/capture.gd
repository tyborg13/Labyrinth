extends SceneTree
## Capture two matched contact studies with one still per ground and actor.

const Board = preload("res://scripts/combat_board_view.gd")
const Cel = preload("res://scripts/cel_look.gd")
const Fixture = preload("res://tools/grd07/fixture.gd")
const Order = preload("res://tools/grd07/draw_order.gd")
const Images = preload("res://tools/grd07/images.gd")
const Metrics = preload("res://tools/grd07/native_metrics.gd")
const MODES: PackedStringArray = ["off", "pixel"]
const SETTLE_FRAMES: int = 4
const READBACK_DRAWS: int = 2
const BASE_OUTPUT: String = "/private/tmp/labyrinth_codex/grd-09"
const BASELINE_ARG: String = "--baseline="
const LEGACY_BASELINE_ARG: String = "--r2-baseline="

var _view: SubViewport
var _dry: bool
var _output: String
var _baseline: String
var _baseline_label: String = "baseline"
var _legacy_crops: Dictionary = {}
var _native_metrics: Dictionary = {}

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_dry = args.has("--dry-run")
	if _dry != (DisplayServer.get_name() == "headless"):
		push_error("GRD-09 requires --dry-run headless or the native visual runner.")
		quit(1)
		return
	assert(Cel.mode == "all" and not Cel._files.is_empty(), "Prepare the approved cel variants and set LABYRINTH_CEL_LOOK=all")
	assert(OS.get_environment("LABYRINTH_GRD03_FIXTURE_ATLASES") != "1", "Use the production ground atlases")
	_output = BASE_OUTPUT.path_join("dry" if _dry else "native").path_join(str(OS.get_process_id()))
	for arg: String in args:
		if arg.begins_with(BASELINE_ARG):
			_baseline = arg.trim_prefix(BASELINE_ARG)
			_baseline_label = "baseline"
		elif arg.begins_with(LEGACY_BASELINE_ARG):
			_baseline = arg.trim_prefix(LEGACY_BASELINE_ARG)
			_baseline_label = "r2"
		elif arg != "--dry-run":
			_output = arg
	assert(_output.is_absolute_path() and not FileAccess.file_exists(_output.path_join("manifest.json")))
	assert(DirAccess.make_dir_recursive_absolute(_output) == OK)
	root.content_scale_factor = 1.0
	_view = Fixture.Gallery.make_view(Fixture.SIZE, Fixture.SIZE, Viewport.MSAA_4X)
	root.add_child(_view)
	if not _dry:
		root.mode = Window.MODE_WINDOWED
		root.size = Fixture.SIZE
		root.content_scale_size = Fixture.SIZE
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		var preview := Sprite2D.new()
		preview.centered = false
		preview.texture = _view.get_texture()
		root.add_child(preview)
	assert(Images.check_pack())
	var styles: Dictionary = {}
	for mode: String in MODES:
		OS.set_environment(Order.PixelGround.MODE_ENV, mode)
		var result: Dictionary = await _study(mode)
		if result.is_empty():
			quit(1)
			return
		styles[mode] = result
	_verify_matching_layouts(styles)
	if not _write_manifest(styles) or (not _dry and not _write_metrics()):
		quit(1)
		return
	print(_output)
	if _dry:
		print("GRD-09 DRY RUN: PASS (2 styles, 7 columns, 52 body/footprint checks, occupied and empty stills, 2x2 Fire and Ice regions)")
	else:
		print("GRD-09 NATIVE CAPTURE: COMPLETE (2 grids, 52 still crops, 7 contact sheets, native-metrics.json)")
	quit()

func _study(mode: String) -> Dictionary:
	var grid: Image = null if _dry else Image.create_empty(Fixture.SIZE.x, Fixture.SIZE.y, false, Image.FORMAT_RGBA8)
	var columns: Array[Dictionary]
	var next_band_start: int = 0
	for column: int in Fixture.GROUNDS.size():
		var result: Dictionary = await _capture_column(mode, column, grid)
		if result.is_empty(): return {}
		var band: Array = result["screen_band_px"]
		assert(band[0] == next_band_start)
		next_band_start += int(band[2])
		columns.append(result)
	assert(next_band_start == Fixture.SIZE.x)
	var path: String = "grid-" + mode + ".png"
	if not _dry and not _save(grid, path): return {}
	return {"ground_surface_style": mode, "grid": path, "columns": columns}

func _capture_column(mode: String, column: int, grid: Image) -> Dictionary:
	var ground: String = Fixture.GROUNDS[column]
	var state: Dictionary = Fixture.state_for(column)
	var board: Control = _study_board(state)
	var pixel: Order.PixelGround = board.get_node_or_null("PixelGround")
	if pixel != null:
		pixel.sync_contacts(board, true)
	await _settle()
	var band: Rect2i = Fixture.band_for(board, column)
	return await _still_column(board, state, band, mode, column, ground, grid)

func _study_board(state: Dictionary) -> Control:
	var board := Board.new()
	board.name = "StudyBoard"
	board.size = Vector2(Fixture.SIZE)
	board.process_mode = Node.PROCESS_MODE_DISABLED
	_view.add_child(board)
	Fixture.frame_room(board, state)
	Fixture.submit(board, state)
	return board

func _still_column(board: Control, state: Dictionary, band: Rect2i, mode: String, column: int, ground: String, grid: Image) -> Dictionary:
	var units: Array[Dictionary] = board.call("_visible_units")
	var rows: PackedInt32Array = Fixture.roster_rows(column)
	assert(units.size() == rows.size())
	var expected_tiles: int = 0 if ground == "plain" else (rows.size() * Fixture.MERGED_SIZE.x * Fixture.MERGED_SIZE.y if ground == "merged" else rows.size())
	assert(Fixture.Ground.tiles(state).size() == expected_tiles)
	assert(board.get("_biome_id") == "stone" and state["room_element"] == "none")
	assert(state["terrain"].is_empty() and state["traps"].is_empty())
	assert((board.get_node("HudRenderLayer") as CanvasItem).is_visible_in_tree())
	var records: Array[Dictionary]
	var stills: Array[Image]
	var source: Image
	if not _dry:
		source = _capture_image()
		grid.blit_rect(source, band, band.position)
	for i: int in units.size():
		var unit: Dictionary = units[i]
		var row: int = rows[i]
		var occupied: String = Fixture.MERGED_GROUNDS[i] if ground == "merged" else ground
		var tile: Vector2i = Fixture.tile_at(column, row)
		assert(unit["type"] == Fixture.UNITS[row] and unit["pos"] == tile)
		assert(board.call("_unit_footprint_tiles", unit).size() == 1)
		assert(board.call("_board_tile_is_visible_to_player", tile))
		assert(Fixture.Ground.has_surface(state, tile, "fire" if occupied == "stormcoal" else occupied) == (occupied != "plain"))
		assert(Fixture.Ground.is_conductive(state, tile) == (occupied in ["stormcoal", "electrified"]))
		var record: Dictionary = Order.unit_record(board, unit, occupied, mode)
		if record.is_empty(): return {}
		var crop_tiles: Array[Vector2i] = board.call("_unit_footprint_tiles", unit)
		if ground == "merged": crop_tiles = Fixture.merged_tiles(column, row)
		var rect: Rect2i = Fixture.crop_for(board, crop_tiles)
		assert(band.encloses(rect), "Footprint crop must fit in its screen column: %s / %s" % [band, rect])
		var body_clear: Rect2 = board.call("_enemy_hud_actor_clear_rect", unit, board.call("_unit_center", unit))
		assert(Rect2(band).encloses(body_clear), "The actor must fit in its screen column")
		record["ground"] = occupied
		record["crop_rect_px"] = Fixture.rect_pixels(Rect2(rect))
		record["crop_size_px"] = Fixture.xy(Vector2(rect.size * Images.ZOOM))
		record["crop"] = "%s/%s/%s-crop.png" % [mode, ground, occupied if ground == "merged" else unit["type"]]
		if ground == "merged": record["region"] = Order.merged_region(board, crop_tiles, occupied, mode)
		records.append(record)
		if not _dry: stills.append(Images.crop(source, rect))
	var sheet: String = "contact-" + ground + ".png"
	if not _dry:
		if not _write_panels(mode, ground, sheet, records, stills): return {}
		if not _native_metrics.has(mode): _native_metrics[mode] = {}
		_native_metrics[mode][ground] = await Metrics.column(board, mode, units, records, source, _read_diagnostic_frame)
	var raised: Array[Dictionary] = Order.raised_stills(board)
	board.queue_free()
	await process_frame
	return {"ground": ground, "screen_band_px": Fixture.rect_pixels(Rect2(band)), "units": records,
		"raised_stills": raised, "contact_sheet": sheet}

func _capture_image() -> Image:
	var image: Image = _view.get_texture().get_image()
	assert(image != null and image.get_size() == Fixture.SIZE)
	image.convert(Image.FORMAT_RGBA8)
	return image

func _read_diagnostic_frame() -> Image:
	await RenderingServer.frame_post_draw
	return _capture_image()

func _settle() -> void:
	for frame: int in SETTLE_FRAMES:
		await process_frame
	for draw: int in READBACK_DRAWS:
		if _dry:
			await process_frame
		else:
			await RenderingServer.frame_post_draw

func _write_panels(mode: String, ground: String, sheet: String, records: Array[Dictionary], stills: Array[Image]) -> bool:
	assert(DirAccess.make_dir_recursive_absolute(_output.path_join(mode).path_join(ground)) == OK)
	var sheet_rows: Array[Array]
	for row: int in records.size():
		if not _save(stills[row], records[row]["crop"]): return false
		if mode == "pixel":
			var panels: Array = [_legacy_crops[ground][row], stills[row]]
			assert(panels.size() == Images.CONTACT_COLUMNS)
			sheet_rows.append(panels)
	if mode == "off":
		_legacy_crops[ground] = stills
	else:
		if not _save(Images.pack(sheet_rows), sheet): return false
		_legacy_crops.erase(ground)
	return true

func _verify_matching_layouts(styles: Dictionary) -> void:
	var off_columns: Array = styles["off"]["columns"]
	var pixel_columns: Array = styles["pixel"]["columns"]
	for column: int in Fixture.GROUNDS.size():
		var old: Dictionary = off_columns[column]
		var new: Dictionary = pixel_columns[column]
		assert(old["screen_band_px"] == new["screen_band_px"])
		for row: int in old["units"].size():
			var a: Dictionary = old["units"][row]
			var b: Dictionary = new["units"][row]
			assert(a["tile"] == b["tile"] and a["crop_rect_px"] == b["crop_rect_px"])
			assert(a["body_placement"] == b["body_placement"])
			assert(a["shadow_and_contact"]["mesh_submissions"] == b["shadow_and_contact"]["mesh_submissions"])

func _write_manifest(styles: Dictionary) -> bool:
	var receipt: Dictionary = {
		"schema": 3, "capture_mode": "headless_dry_run" if _dry else "native",
		"images_written": not _dry, "native_metrics": "" if _dry else "native-metrics.json", "display": DisplayServer.get_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"size_px": Fixture.xy(Vector2(_view.size)), "ui_scale": root.content_scale_factor,
		"msaa_2d": "4x", "cel_look": Cel.mode, "biome": "stone",
		"board_passes_per_style": Fixture.GROUNDS.size(),
		"assembly": "unscaled screen bands from matched full combat board passes",
		"crop_zoom": Images.ZOOM, "crop_interpolation": "nearest",
		"column_order": Array(Fixture.GROUNDS), "row_order": Array(Fixture.UNITS),
		"merged_row_order": Array(Fixture.MERGED_GROUNDS), "sheet_columns": ["off_crop", "pixel_crop"],
		"styles": styles,
	}
	return _write_json("manifest.json", receipt)

func _write_metrics() -> bool:
	var comparison: Dictionary = {}
	for ground: String in Fixture.GROUNDS:
		comparison[ground] = Metrics.pair(_native_metrics["off"][ground], _native_metrics["pixel"][ground])
	var payload := {
		"schema": 3, "size_px": Fixture.xy(Vector2(_view.size)), "ui_scale": root.content_scale_factor,
		"luminance": "Rec.601 RGB, 0-255, from matched native framebuffer readbacks",
		"coverage": "Changed pixels inside the projected footprint, floor-only against bare floor",
		"outline_coverage": "Curved mask pixels from a separate solid-fill readback, allowing for transparent atlas gaps",
		"accent_share": "Historical diagnostic: ground pixels brighter than 110% of the measured unit mean",
		"front_texels": "Native pixels changed by hiding front layers, inside each layer's rectangle within the footprint crop",
		"styles": _native_metrics, "columns": comparison,
	}
	if not _baseline.is_empty():
		payload[_baseline_label + "_comparison"] = _compare_baseline()
	return _write_json("native-metrics.json", payload)

func _compare_baseline() -> Dictionary:
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_baseline.path_join("native-metrics.json")))
	var pixel: Dictionary = old["styles"]["pixel"]
	var contacts: Dictionary = {}
	for ground: String in ["fire", "stormcoal", "electrified", "merged"]:
		var entries: Array[Dictionary]
		for i: int in pixel[ground]["regions"].size():
			var previous: Dictionary = pixel[ground]["regions"][i]
			var current: Dictionary = _native_metrics["pixel"][ground]["regions"][i]
			assert(previous["unit"] == current["unit"] and previous["ground"] == current["ground"])
			var entry := {"unit": current["unit"], "ground": current["ground"],
				"current_front_pixels": current["front_layer_texels_at_feet"],
				"current_fire_front_pixels": current["fire_front_layer_pixels_at_feet"]}
			entry[_baseline_label + "_front_pixels"] = previous["front_layer_texels_at_feet"]
			entries.append(entry)
		contacts[ground] = entries
	var unchanged: Dictionary = {}
	for path: String in ["grid-off.png", "pixel/merged/ice-crop.png"]:
		unchanged[path] = _same_pixels(path)
	for ground: String in ["ice", "rubble", "plain"]:
		for unit: String in Fixture.UNITS:
			var path: String = "pixel/%s/%s-crop.png" % [ground, unit]
			unchanged[path] = _same_pixels(path)
	return {"baseline_dir": _baseline, "contacts": contacts, "unchanged_pixels": unchanged,
		"electrified_region_mean": {
			"baseline": pixel["electrified"]["region"]["region_mean_luminance"],
			"current": _native_metrics["pixel"]["electrified"]["region"]["region_mean_luminance"],
		}}

func _same_pixels(path: String) -> bool:
	var old: Image = Image.load_from_file(_baseline.path_join(path))
	var current: Image = Image.load_from_file(_output.path_join(path))
	assert(old != null and current != null)
	old.convert(Image.FORMAT_RGBA8)
	current.convert(Image.FORMAT_RGBA8)
	return old.get_size() == current.get_size() and old.get_data() == current.get_data()

func _write_json(path: String, payload: Dictionary) -> bool:
	var file := FileAccess.open(_output.path_join(path), FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(payload, "\t") + "\n")
	var ok: bool = file.get_error() == OK
	file.close()
	return ok

func _save(image: Image, path: String) -> bool:
	var error: Error = image.save_png(_output.path_join(path))
	if error != OK: push_error("Could not save %s: %s" % [path, error_string(error)])
	return error == OK

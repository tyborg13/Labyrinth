extends SceneTree

const Board = preload("res://scripts/combat_board_view.gd")
const Fixture = preload("res://tools/grd01/fixtures.gd")
const Metrics = preload("res://tools/grd01/surface_metrics.gd")
const Pixel = preload("res://scripts/pixel_fx_layer.gd")
const GroundLayer = preload("res://scripts/board_pixel_surface_layer.gd")
const Cel = preload("res://scripts/cel_look.gd")
const SETTLE_FRAMES: int = 4
const ZOOM: int = 3
const NAVIGATION_PROOF_ZOOM: float = 1.25
const FEEDBACK_PROOF_PROGRESS: float = 0.5
const CROP_SIDE_PAD_IN_TILES: float = 0.64
const CROP_TOP_PAD_IN_TILES: float = 1.10
const CROP_BOTTOM_PAD_IN_TILES: float = 0.38
const OUTPUT_ROOT: String = "/private/tmp/labyrinth_codex/grd-02/gallery"

var _view: SubViewport
var _board: Control
var _pixel: bool
var _check_only: bool

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	_check_only = "--check-fixtures" in OS.get_cmdline_user_args()
	_pixel = GroundLayer.enabled()
	var mode: String = "pixel" if _pixel else "legacy"
	var native: bool = DisplayServer.get_name() != "headless"
	assert(_check_only or native, "Use the visual runner with a real renderer, or --check-fixtures for headless semantics")
	assert(Cel.mode == "all", "Run with LABYRINTH_CEL_LOOK=all")
	assert(Pixel.enabled(), "The comparison uses the production pixel layer")
	var output_root: String = OS.get_environment("LABYRINTH_GRD01_OUTPUT")
	output_root = OUTPUT_ROOT if output_root.is_empty() else output_root.path_join("gallery")
	var output: String = output_root.path_join(mode).path_join(str(OS.get_process_id()) + "-" + str(int(Time.get_unix_time_from_system())))
	if not _check_only:
		assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	root.content_scale_factor = 1.0
	_view = Fixture.make_view(Fixture.SIZE, Fixture.SIZE, Viewport.MSAA_4X)
	root.add_child(_view)
	var cases: Array[Dictionary] = Fixture.gallery_cases()
	var manifest: Array[Dictionary]
	var crop_count: int = 0
	for sample: Dictionary in cases:
		_board = Board.new()
		_board.size = Vector2(Fixture.SIZE)
		_view.add_child(_board)
		_board.process_mode = Node.PROCESS_MODE_DISABLED
		Fixture.submit(_board, sample["state"], sample["shown"])
		for frame: int in range(SETTLE_FRAMES):
			await process_frame
		if not _check_only:
			await RenderingServer.frame_post_draw
		var entry: Dictionary = _verify(sample)
		if not _check_only:
			_capture(output, sample, entry)
			if _pixel and sample["id"] == "stone_ice_empty" and _fixture_atlases_enabled():
				await _verify_fixture_ice_glint(_board.get_node("PixelGround"))
			if _pixel and sample["id"] == "stone_electrified_empty":
				entry["electrified_pulse_frames"] = await _verify_electrified_pulse(_board.get_node("PixelGround"))
		else:
			for tiles: Array in sample["crops"].values():
				assert(_crop_bounds(tiles).has_area())
		crop_count += sample["crops"].size()
		manifest.append(entry)
		_board.queue_free()
		await process_frame
	assert(manifest.size() == 24 and crop_count == 35)
	if _pixel:
		await _verify_pixel_lifecycle()
	if _check_only:
		print("GRD-04 GALLERY FIXTURES: PASS (%s, 24 cases, 35 crop rectangles, headless semantics)" % mode)
	else:
		var file := FileAccess.open(output.path_join("gallery.json"), FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"size": [1920, 1080], "ui_scale": 1.0, "cel_look": Cel.mode,
			"ground_fx": mode, "zoom": ZOOM, "cases": manifest}, "	"))
		file.close()
		print(output)
		print("GRD-04 GALLERY: PASS (%s, 24 frames, 35 nearest-neighbor crops)" % mode)
	_view.queue_free()
	await process_frame
	quit()

func _verify(sample: Dictionary) -> Dictionary:
	var id: String = sample["id"]
	var state: Dictionary = sample["state"]
	var shown: Dictionary = sample["shown"]
	var expected_surfaces: Dictionary = Fixture.counts(state)
	var inventory: Dictionary = Metrics.inventory(_board)
	var floor_layers: Dictionary = inventory["surface_layers"]
	var pixel_ground: Dictionary = {}
	if _pixel:
		pixel_ground = _verify_pixel_field(state, expected_surfaces)
	var pixel_runs: Array[Dictionary]
	if id.begins_with("attack_"):
		var element: String = shown["effect"]["element"]
		_count_pixel_runs(_board, pixel_runs)
		assert(pixel_runs.any(func(run: Dictionary) -> bool: return run["element"] == element and int(run["commands"]) > 0),
			"%s must submit commands to the designated pixel ramp" % id)
		assert(inventory["surface_roots"] == 0)
	elif id == "mixed_umbra":
		assert(_board.get("presentation")["umbra_stage"] == "pressing")
		if not _pixel: assert(inventory["surface_roots"] == Fixture.MIXED_CLEAR.get_area())
		for tile: Vector2i in sample["crops"]["fog"]:
			assert(not bool(_board.call("_board_tile_is_visible_to_player", tile)))
			assert(not Fixture.Ground.surface_at(state, tile).is_empty())
		for tile: Vector2i in sample["crops"]["clear"]:
			assert(bool(_board.call("_board_tile_is_visible_to_player", tile)))
		for kind: String in Fixture.KINDS:
			assert(expected_surfaces[kind] == 2 * Fixture.MIXED_BLOCK.x * Fixture.MIXED_BLOCK.y)
		# Pairs share a full edge in both visibility groups.
		for area: Rect2i in [Fixture.MIXED_CLEAR, Fixture.MIXED_HIDDEN]:
			var border: Vector2i = area.position + Vector2i(Fixture.MIXED_BLOCK.x - 1, 0)
			assert(Fixture.Ground.element_at(state, border) == "fire")
			assert(Fixture.Ground.element_at(state, border + Vector2i.RIGHT) == "ice")
			border += Vector2i(0, Fixture.MIXED_BLOCK.y)
			assert(Fixture.Ground.element_at(state, border) == "electrified")
			assert(Fixture.Ground.has_rubble(state, border + Vector2i.RIGHT))
	elif id == "shared_ground":
		for kind: String in ["fire", "ice", "electrified"]:
			assert(expected_surfaces[kind] == Fixture.SHARED_PATCH.get_area())
		assert(expected_surfaces["rubble"] == 3 * Fixture.SHARED_PATCH.get_area())
		if not _pixel: assert(inventory["surface_roots"] == 7 * Fixture.SHARED_PATCH.get_area())
	elif id == "stormcoal":
		assert(expected_surfaces["fire"] == Fixture.SHARED_PATCH.get_area())
		assert(expected_surfaces["electrified"] == Fixture.SHARED_PATCH.get_area())
		if _pixel:
			assert(pixel_ground["stormcoal_tiles"] == expected_surfaces["fire"])
		else:
			assert(floor_layers["SurfaceFire"]["roots"] == expected_surfaces["fire"])
			assert(floor_layers["SurfaceElectric"]["roots"] == expected_surfaces["fire"] + expected_surfaces["electrified"])
	else:
		if not _pixel: assert(inventory["surface_roots"] == Fixture.PATCH.get_area() and floor_layers.size() == 1)
		if id.ends_with("_occupied"):
			assert(_board.call("_visible_units").size() == 2)
			assert(not Fixture.Ground.surface_at(state, state["player"]["pos"]).is_empty())
			assert(not Fixture.Ground.surface_at(state, state["enemies"][0]["pos"]).is_empty())
		else:
			assert(_board.call("_visible_units").is_empty())
	assert(_board.get("_biome_id") == shown["biome_id"])
	return {"id": id, "biome": shown["biome_id"], "surface_counts": expected_surfaces,
		"visible_surface_roots": inventory["surface_roots"], "pixel_ground": pixel_ground, "pixel_fx_runs": pixel_runs,
		"effect_progress": shown.get("effect_progress"), "umbra_stage": shown.get("umbra_stage", "clear")}

func _verify_pixel_field(state: Dictionary, expected_surfaces: Dictionary) -> Dictionary:
	var layer: GroundLayer = _board.get_node("PixelGround")
	var retained: Dictionary = Metrics.inventory(_board)["surface_layers"]
	for kind: String in Metrics.LAYERS:
		assert(not retained.has(kind))
	assert(layer.get_index() < _board.get_node("GroundRenderLayer").get_index())
	var visible_counts: Dictionary = {}
	var stormcoal_tiles: int = 0
	var visible_tiles: Array[Vector2i]
	for tile: Vector2i in Fixture.Ground.tiles(state):
		if not _board.call("_board_tile_is_visible_to_player", tile):
			assert(not layer.field.tiles.has(tile))
			continue
		visible_tiles.append(tile)
		var element: String = Fixture.Ground.element_at(state, tile)
		var rubble: bool = Fixture.Ground.has_rubble(state, tile)
		var address: Vector2i = layer.field.address_of(tile)
		var record: Color = layer.field.image.get_pixelv(address)
		var conductive: bool = Fixture.Ground.is_conductive(state, tile)
		var stormcoal: bool = element == "fire" and conductive
		var flags: int = layer.Field.ELEMENT_IDS.get(element, 0)
		if rubble:
			flags |= layer.Field.RUBBLE
		if stormcoal:
			flags |= layer.Field.STORMCOAL
			stormcoal_tiles += 1
		assert(int(record.r) == flags)
		if not element.is_empty():
			visible_counts[element] = int(visible_counts.get(element, 0)) + 1
		if element == "electrified":
			assert(int(record.g) == 0)
		elif not element.is_empty():
			for i: int in layer.Field.NEIGHBORS.size():
				var adjacent: Vector2i = tile + layer.Field.NEIGHBORS[i]
				var connected: bool = _board.call("_board_tile_is_visible_to_player", adjacent) and Fixture.Ground.has_surface(state, adjacent, element)
				assert(bool(int(record.g) & (1 << i)) == connected, "An edge must follow visible patch membership")
		if rubble:
			visible_counts["rubble"] = int(visible_counts.get("rubble", 0)) + 1
	assert(layer.field.tiles.size() == visible_tiles.size())
	if visible_tiles.is_empty():
		assert(layer.target == null and not layer.visible)
		return {}
	assert(layer.grid == 2 and layer.target.size == layer.cell_rect.size)
	assert(layer.target.get_child_count() == 1 and layer.get_child_count() == 2)
	for kind: String in visible_counts:
		assert(visible_counts[kind] <= expected_surfaces[kind])
	var electrified_decals: int = _electrified_decal_count(layer)
	assert(electrified_decals == (int(visible_counts.get("electrified", 0)) + stormcoal_tiles) *
		int(layer._style["electrified"]["decals_per_tile"]))
	var palette_cells: Dictionary = {} if _check_only else _verify_cell_readback(layer, visible_counts, stormcoal_tiles)
	return {"visible_tiles": visible_tiles.size(), "visible_counts": visible_counts, "stormcoal_tiles": stormcoal_tiles,
		"electrified_decals": electrified_decals, "grid": layer.grid, "cell_size": [layer.target.size.x, layer.target.size.y],
		"steps": [layer.steps.x, layer.steps.y, layer.steps.z], "palette_cells": palette_cells}

func _verify_cell_readback(layer: GroundLayer, visible_counts: Dictionary, stormcoal_tiles: int) -> Dictionary:
	var image: Image = layer.target.get_texture().get_image()
	assert(image != null and image.get_size() == layer.cell_rect.size)
	image.convert(Image.FORMAT_RGBA8)
	var colors: Dictionary = {}
	var counts: Dictionary = {}
	var decal_cells: Dictionary = {}
	var base_indices: Dictionary = {"fire": 0, "ice": 1, "rubble": 1}
	var palette_kinds: Array = visible_counts.keys()
	if stormcoal_tiles > 0 and not palette_kinds.has("electrified"):
		palette_kinds.append("electrified")
	for kind: String in palette_kinds:
		counts[kind] = 0
		var ramp: PackedColorArray = Pixel.ramp_for(GroundLayer.ramp_id(kind))
		for index: int in ramp.size():
			colors[ramp[index].to_rgba32()] = {"kind": kind, "index": index}
	var data: PackedByteArray = image.get_data()
	var transparent: int = 0
	var stormcoal_overlay_cells: int = 0
	var stormcoal_coverage: float = layer._style["fire"]["stormcoal_overlay_coverage"]
	for i: int in range(0, data.size(), 4):
		var alpha: int = data[i + 3]
		if alpha == 0:
			transparent += 1
			continue
		assert(alpha == 255, "Ground cells have binary alpha")
		var rgba: int = (data[i] << 24) | (data[i + 1] << 16) | (data[i + 2] << 8) | alpha
		assert(colors.has(rgba), "Ground cells use the element ramps verbatim")
		var kind: String = colors[rgba]["kind"]
		var kind_id: int = GroundLayer.Field.ELEMENT_IDS.get(kind, GroundLayer.Field.RUBBLE)
		@warning_ignore("integer_division")
		var cell := Vector2((i / 4) % image.get_width(), i / 4 / image.get_width()) + Vector2.ONE * 0.5
		var tile := Vector2i((layer._cell_to_tile * cell + Vector2.ONE * 0.5).floor())
		var flags: int = layer.field.tiles.get(tile, 0)
		if kind == "electrified" and (flags & GroundLayer.Field.STORMCOAL) != 0:
			var screen_cell: Vector2i = Vector2i(cell) + layer.cell_rect.position
			var bayer: float = float(Pixel.BAYER[(screen_cell.y & 3) * 4 + (screen_cell.x & 3)]) / 16.0
			assert(bayer < stormcoal_coverage, "Stormcoal overlay pixels must pass the Bayer coverage")
			stormcoal_overlay_cells += 1
		else:
			assert(GroundLayer.Field.tile_kind(flags, kind_id),
				"%s may render only over visible tiles of that kind" % kind)
		counts[kind] += 1
		if colors[rgba]["index"] != base_indices.get(kind, -1):
			decal_cells[kind] = int(decal_cells.get(kind, 0)) + 1
	assert(transparent > 0)
	for kind: String in counts:
		assert(counts[kind] > 0, "%s must render at least one cell" % kind)
		if base_indices.has(kind) and _fixture_atlases_enabled():
			assert(decal_cells.get(kind, 0) > 0, "%s fixture must render indexed decal pixels" % kind)
	if stormcoal_tiles > 0:
		assert(stormcoal_overlay_cells > 0, "Stormcoal must render Electrified decal pixels over Fire tiles")
		counts["stormcoal_overlay"] = stormcoal_overlay_cells
	return counts

func _verify_pixel_lifecycle() -> void:
	_board = Board.new()
	_board.size = Vector2(Fixture.SIZE)
	_view.add_child(_board)
	var sample: Dictionary = Fixture.gallery_cases()[0]
	var state: Dictionary = sample["state"]
	var shown: Dictionary = sample["shown"].duplicate()
	Fixture.submit(_board, state, shown)
	await process_frame
	var layer: GroundLayer = _board.get_node("PixelGround")
	var fire_fps: int = int(layer._style["fire"]["cycle_fps"]) if layer._atlases.has(1) else 0
	assert(layer.steps.x == floori(Fixture.PROOF_SECONDS * fire_fps) and not layer.is_processing())
	if not _check_only and _fixture_atlases_enabled():
		await _verify_fixture_fire_cycle(layer, fire_fps)
	var conductive: Dictionary = state.duplicate()
	conductive["surface_rule_overrides"] = {"conductive_fire": true}
	Fixture.submit(_board, conductive, shown)
	assert(_electrified_decal_count(layer) == Fixture.PATCH.get_area())
	assert((int(layer.field.tiles[Fixture.PATCH.position]) & GroundLayer.Field.STORMCOAL) != 0)
	Fixture.submit(_board, state, shown)
	assert(_electrified_decal_count(layer) == 0 and layer.steps.z == 0)
	var image: Image = layer.field.image
	var previous_cells: Rect2i = layer.cell_rect
	_board.call("set_navigation_zoom", NAVIGATION_PROOF_ZOOM)
	assert(layer.field.image == image and layer.cell_rect != previous_cells)
	shown["reduced_motion"] = true
	Fixture.submit(_board, state, shown)
	assert(layer.steps == Vector3i.ZERO and not layer.is_processing())
	shown["umbra_visible_tiles"] = []
	Fixture.submit(_board, state, shown)
	assert(layer.field.tiles.is_empty() and not layer.visible)
	shown.erase("umbra_visible_tiles")
	Fixture.submit(_board, state, shown)
	assert(layer.field.tiles.size() == Fixture.PATCH.get_area() and layer.visible)
	shown["surface_feedback_events"] = [{
		"kind": "surface_replaced", "tile": Fixture.PATCH.position, "surface": "fire", "feedback_element": "fire", "break_surface": "ice",
	}]
	shown["surface_feedback_progress"] = FEEDBACK_PROOF_PROGRESS
	Fixture.submit(_board, state, shown)
	await process_frame
	var feedback_runs: Array[Dictionary]
	_count_pixel_runs(_board, feedback_runs)
	for element: String in ["ice", "fire"]:
		assert(feedback_runs.any(func(run: Dictionary) -> bool: return run["element"] == element and int(run["commands"]) > 0),
			"The pixel prototype must keep %s surface feedback on the existing VFX route" % element)
	var changed: Dictionary = state.duplicate(true)
	changed["surfaces"].clear()
	Fixture.submit(_board, changed, shown)
	assert(layer.field.tiles.is_empty() and not layer.visible and not layer.is_processing())
	_board.queue_free()
	await process_frame

static func _fixture_atlases_enabled() -> bool:
	return OS.get_environment(GroundLayer.Decals.FIXTURE_FLAG) == "1"

static func _electrified_decal_count(layer: GroundLayer) -> int:
	var count: int = 0
	for decal: Dictionary in layer.decals.placements:
		if decal["kind"] == GroundLayer.Field.ELEMENT_IDS["electrified"]:
			count += 1
	return count

func _verify_electrified_pulse(layer: GroundLayer) -> int:
	var config: Dictionary = layer._style["electrified"]
	var fps: int = layer._fps.z
	assert(fps == int(config["fps"]), "The Electrified atlas must have a pulse sweep axis")
	var period: int = ceili(float(config["pulse_interval_seconds"]) * fps)
	layer.present_clock(true, 0.0)
	await RenderingServer.frame_post_draw
	var frozen: Image = layer.target.get_texture().get_image()
	frozen.convert(Image.FORMAT_RGBA8)
	var frozen_data: PackedByteArray = frozen.get_data()
	var ramp: PackedColorArray = Pixel.ramp_for(GroundLayer.ramp_id("electrified"))
	var frames: Dictionary = {}
	for step: int in range(2 * period):
		layer.present_clock(false, (step + 0.5) / fps)
		await RenderingServer.frame_post_draw
		var current: Image = layer.target.get_texture().get_image()
		current.convert(Image.FORMAT_RGBA8)
		var current_data: PackedByteArray = current.get_data()
		if current_data == frozen_data:
			continue
		frames[hash(current_data)] = true
		for y: int in current.get_height():
			for x: int in current.get_width():
				var color: Color = current.get_pixel(x, y)
				var before: Color = frozen.get_pixel(x, y)
				assert(color == before or (before.to_rgba32() == ramp[3].to_rgba32() and color.to_rgba32() == ramp[4].to_rgba32()),
					"The Electrified pulse may only lift index 3 to 4")
	assert(frames.size() >= int(config["pulse_steps"]), "The Electrified pulse must shift across the decals")
	return frames.size()

func _verify_fixture_ice_glint(layer: GroundLayer) -> void:
	var config: Dictionary = layer._style["ice"]
	var fps: int = config["fps"]
	var period: int = roundi(float(config["glint_interval_seconds"]) * fps)
	layer.present_clock(true, Fixture.PROOF_SECONDS)
	await RenderingServer.frame_post_draw
	var frozen: Image = layer.target.get_texture().get_image()
	frozen.convert(Image.FORMAT_RGBA8)
	var ramp: PackedColorArray = Pixel.ramp_for(GroundLayer.ramp_id("ice"))
	var changed: bool = false
	for step: int in range(1, period + 1):
		layer.present_clock(false, (step + 0.5) / fps)
		await RenderingServer.frame_post_draw
		var current: Image = layer.target.get_texture().get_image()
		current.convert(Image.FORMAT_RGBA8)
		for y: int in current.get_height():
			for x: int in current.get_width():
				var color: Color = current.get_pixel(x, y)
				var before: Color = frozen.get_pixel(x, y)
				if color != before:
					assert(before.to_rgba32() == ramp[3].to_rgba32() and color.to_rgba32() == ramp[4].to_rgba32(),
						"Ice glints lift index 3 to 4")
					changed = true
	assert(changed, "The fixture Ice atlas must glint within a full interval")

func _verify_fixture_fire_cycle(layer: GroundLayer, fps: int) -> void:
	await RenderingServer.frame_post_draw
	var first: PackedByteArray = layer.target.get_texture().get_image().get_data()
	layer.present_clock(false, Fixture.PROOF_SECONDS + 1.0 / fps)
	await RenderingServer.frame_post_draw
	assert(layer.target.get_texture().get_image().get_data() != first, "Fire must change its ramp indices on the next step")
	layer.present_clock(true, Fixture.PROOF_SECONDS)
	await RenderingServer.frame_post_draw
	var frozen: PackedByteArray = layer.target.get_texture().get_image().get_data()
	layer.present_clock(true, Fixture.PROOF_SECONDS + 1.0 / fps)
	await RenderingServer.frame_post_draw
	assert(layer.target.get_texture().get_image().get_data() == frozen, "Reduced motion must hold the Fire atlas at step zero")
	layer.present_clock(false, Fixture.PROOF_SECONDS)

func _count_pixel_runs(node: Node, result: Array[Dictionary]) -> void:
	if node is Pixel:
		for run: Dictionary in node.snapshot():
			result.append({"element": run["element"], "commands": run["commands"], "grid": run["grid"]})
	for child: Node in node.get_children():
		_count_pixel_runs(child, result)

func _capture(output: String, sample: Dictionary, entry: Dictionary) -> void:
	var id: String = sample["id"]
	var screenshot: Image = _view.get_texture().get_image()
	assert(screenshot != null and screenshot.get_size() == Fixture.SIZE, "Expected an exact 1920x1080 renderer image")
	entry["image"] = id + ".png"
	assert(screenshot.save_png(output.path_join(entry["image"])) == OK)
	var crops: Dictionary = {}
	for label: String in sample["crops"]:
		var rect: Rect2i = _crop_bounds(sample["crops"][label])
		var crop: Image = screenshot.get_region(rect)
		crop.resize(rect.size.x * ZOOM, rect.size.y * ZOOM, Image.INTERPOLATE_NEAREST)
		var filename: String = "%s_%s_3x.png" % [id, label]
		assert(crop.get_size() == rect.size * ZOOM)
		assert(crop.save_png(output.path_join(filename)) == OK)
		crops[label] = {"image": filename, "source_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]}
	entry["crops"] = crops

func _crop_bounds(tiles: Array) -> Rect2i:
	var transform: Transform2D = _board.get_global_transform_with_canvas()
	var tile_width: float = _board.call("_tile_width")
	var bounds := Rect2(transform * (_board.call("_tile_center", tiles[0]) as Vector2), Vector2.ZERO)
	for tile: Vector2i in tiles:
		var local: Vector2 = _board.call("_tile_center", tile)
		bounds = bounds.expand(transform * local)
	var side: float = tile_width * CROP_SIDE_PAD_IN_TILES
	var first := Vector2i((bounds.position - Vector2(side, tile_width * CROP_TOP_PAD_IN_TILES)).floor())
	var last := Vector2i((bounds.end + Vector2(side, tile_width * CROP_BOTTOM_PAD_IN_TILES)).ceil())
	var full := Rect2i(Vector2i.ZERO, Fixture.SIZE)
	var rect := Rect2i(first, last - first)
	assert(full.encloses(rect), "Crop extends beyond the capture: %s" % rect)
	return rect

extends SceneTree
## Headless checks of the retained playback path and existing ground suites.

const Board = preload("res://scripts/combat_board_view.gd")
const Gallery = preload("res://tools/grd01/fixtures.gd")
const Order = preload("res://tools/grd07/draw_order.gd")
const Sheet = preload("res://scripts/board_ground_fx_sheet.gd")
const SizeProof = preload("res://tools/grd11/size_proof.gd")
const Layer = preload("res://scripts/board_pixel_surface_layer.gd")
const TILES := Rect2i(1, 1, 8, 5)
const HERO := Vector2i(3, 3)
const CLOSE_UNIT := Vector2i(3, 4)
const PROP := Vector2i(4, 3)
const FLOOR_MARKER := Vector2i(2, 3)
const FLIER := Vector2i(5, 4)
const ILLUSION := Vector2i(2, 4)
const HIDDEN := Vector2i(6, 3)
const LARGE := Rect2i(6, 5, 2, 2)
const ELECTRIC := Vector2i(5, 6)
const SEED: int = 617
const BENCH_WARMUP: int = 120
const BENCH_TICKS: int = 1200
const CPU_LIMIT_MS: float = 0.15
const TEST_DELTA: float = 1.0 / 60.0

var _rows: Dictionary
var _board: Board
var _ground: Layer
var _draws: int
var _failed: int

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	_check_seeding()
	OS.set_environment(Layer.MODE_ENV, "pixel")
	var view: SubViewport = Gallery.make_view(Gallery.SIZE, Gallery.SIZE, Viewport.MSAA_4X)
	root.add_child(view)
	_board = Board.new()
	_board.size = Vector2(Gallery.SIZE)
	_board.process_mode = Node.PROCESS_MODE_DISABLED
	view.add_child(_board)
	_ground = _board.get_node("PixelGround")
	_check_atlases()
	_check_selector()
	_check_rows_and_depth()
	await _check_sizes(view)
	await _benchmark()
	view.free()
	await process_frame
	_run_existing_suites()
	quit(0 if _failed == 0 else 1)

func _check_atlases() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Sheet.DATA_PATH))
	_rows = data["rows"]
	assert(int(data["fps"]) == 12 and int(data["frames"]) == 16 and _rows.size() == 18)
	assert(_ground.sheet.ink == null and Sheet._textures.size() == 7)
	var bytes: int = 0
	for index: int in data["sizes"].size():
		var info: Dictionary = data["sizes"][index]
		var path: String = Sheet.ATLAS_DIR.path_join(info["atlas"])
		var imported: Texture2D = load(path)
		assert(Sheet._textures[index] == imported, "The board prepared the imported texture")
		var image: Image = imported.get_image()
		assert(image.get_format() == Image.FORMAT_L8 and not image.has_mipmaps(), path + " must stay single channel")
		assert(image.get_size() == Vector2i(_pair(info["frame_cells"])) * Vector2i(16, 18))
		var pixels: PackedByteArray = image.get_data()
		assert(pixels.size() == image.get_width() * image.get_height())
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(pixels)
		assert(digest.finish().hex_encode() == info["sha256_pixels"], "Imported indices must match " + path)
		bytes += pixels.size()
	assert(data["palette"].size() <= Sheet.PALETTE_CAPACITY)
	for index: int in data["palette"].size():
		assert(Sheet._palette[index].to_html() == data["palette"][index])
	print("GRD-11 IMPORTED ATLASES: PASS (7 L8 sheets preloaded, no mipmaps, %d index bytes matched)" % bytes)

static func _pair(values: Array) -> Vector2:
	return Vector2(values[0], values[1])

func _check_selector() -> void:
	var widths: PackedInt32Array = Sheet._sheet_tile_widths
	# Exercise each side of both limits in addition to the production layout tests.
	assert(SizeProof.Pixel.choose_sheet_size(96.0, 800, widths) == Vector2i(1, 6))
	assert(SizeProof.Pixel.choose_sheet_size(97.0, 800, widths) == Vector2i(2, 1))
	assert(SizeProof.Pixel.choose_sheet_size(80.0, 1080, widths) == Vector2i(2, 0))
	assert(SizeProof.Pixel.choose_sheet_size(79.0, 1080, widths) == Vector2i(1, 4))
	assert(SizeProof.Pixel.choose_sheet_size(159.0, 2160, widths) == Vector2i(3, 1))
	print("GRD-11 CELL SELECTOR: PASS (native grid, 40-cell minimum, 96-cell maximum)")

func _check_seeding() -> void:
	var phases: Dictionary = {}
	var variants: Dictionary = {}
	var changed_seed: bool = false
	for tile: Vector2i in Gallery.tiles_in(Rect2i(-8, -8, 16, 16)):
		var offset: int = Sheet.phase(SEED, tile)
		var variant: int = Sheet.variant_for(SEED, tile)
		assert(offset == Sheet.phase(SEED, tile) and offset >= 0 and offset < 16)
		assert(variant == Sheet.variant_for(SEED, tile))
		changed_seed = changed_seed or offset != Sheet.phase(SEED + 1, tile)
		phases[offset] = true
		variants[variant] = true
		for neighbor: Vector2i in Layer.Field.NEIGHBORS:
			assert(offset != Sheet.phase(SEED, tile + neighbor))
	assert(changed_seed and phases.size() == 16 and variants.size() == 2)
	print("GRD-11 SEEDING: PASS (both variants, all phases, eight-neighbour separation)")

func _check_rows_and_depth() -> void:
	var state: Dictionary = _state()
	state["player"]["pos"] = HERO
	var enemies: Array[Dictionary]
	enemies.append(_enemy(1, "crawler", CLOSE_UNIT))
	enemies.append(_enemy(2, "gust_shrike", FLIER))
	enemies.append(_enemy(3, "crawler", HIDDEN))
	enemies.append(_enemy(4, "iskaldra", LARGE.position, LARGE.size))
	state["enemies"] = enemies
	state["illusions"] = [{"id": 1, "hp": 10, "pos": ILLUSION}]
	var enemy_ids: Array[int] = [1, 2, 4]
	var shown: Dictionary = {"biome_id": "stone", "visible_enemy_ids": enemy_ids,
		"scene_props": [{"kind": "relic_chest", "tile": PROP}, {"kind": "relic_chest", "tile": FLOOR_MARKER, "x_offset_scale": 1.0}]}
	for tile: Vector2i in [HERO, PROP, FLOOR_MARKER, FLIER, HIDDEN, ILLUSION]:
		Gallery.Ground.place(state, tile, "fire")
	Gallery.Ground.place(state, ELECTRIC, "electrified")
	Gallery.Ground.place(state, CLOSE_UNIT, "electrified")
	Gallery.place_rect(state, LARGE, "fire")
	Gallery.submit(_board, state, shown)
	_ground.set_motion_time(0.0)
	_expect_rows(HERO, "fire_full_rear", "fire_full_front")
	_expect_rows(PROP, "fire_full_rear", "fire_full_front")
	_expect_rows(ILLUSION, "fire_full_rear", "fire_full_front")
	for tile: Vector2i in [FLIER, HIDDEN, FLOOR_MARKER]:
		_expect_rows(tile, "fire_low_rear", "fire_low_front")
	_expect_rows(ELECTRIC, "electrified_rear", "electrified_front_quiet")
	_expect_rows(CLOSE_UNIT, "electrified_rear", "electrified_front")
	for tile: Vector2i in Gallery.tiles_in(LARGE):
		_expect_rows(tile, "fire_full_rear", "fire_full_front")
	_check_depth()
	var front: Node2D = _stamp(HERO, true)
	var orig_pos: Vector2 = front.position
	var offset: int = Sheet.phase(SEED, HERO)
	var rows: Vector2i = front.rows_at(_ground.sheet.tick)
	var next_state: Dictionary = state.duplicate(true)
	next_state["player"]["pos"] = HERO + Vector2i.LEFT
	Gallery.submit(_board, next_state, shown)
	_ground.set_motion_time(1.0 / 24.0)
	assert(front == _stamp(HERO, true) and front.position == orig_pos)
	assert(front.rows_at(_ground.sheet.tick) == rows and _ground.sheet.frame_at(offset) == offset)
	_ground.set_motion_time(1.0 / 12.0)
	_expect_rows(HERO, "fire_low_rear", "fire_low_front")
	assert(_ground.sheet.frame_at(offset) == (offset + 1) % 16)
	state["surface_rule_overrides"] = {"conductive_fire": true}
	Gallery.submit(_board, state, shown)
	_expect_rows(HERO, "fire_full_rear", "fire_full_front", "electrified_storm_rear", "electrified_storm_front")
	_expect_rows(HIDDEN, "fire_low_rear", "fire_low_front", "electrified_storm_rear", "electrified_storm_front")
	shown["reduced_motion"] = true
	Gallery.submit(_board, state, shown)
	_ground.set_motion_time(2.9)
	assert(not _ground.is_processing() and _ground.sheet.ink.get_shader_parameter("tick") == -1)
	assert(_ground._material.get_shader_parameter("motion_seconds") == -1.0)
	assert(_ground._material.get_shader_parameter("electric_pulse") == Vector2(1.2, 0.15))
	assert(_ground._material.get_shader_parameter("fire_scroll_step") == 0.25)
	assert(_ground._material.get_shader_parameter("ice_glint") == Vector2(2.4, 0.35))
	assert(_ground.sheet.frame_at(offset) == 3 and _ground.sheet.frame_at(offset + 3) == 3)
	_check_depth()
	shown["umbra_visible_tiles"] = [HERO, CLOSE_UNIT, PROP, HIDDEN]
	shown["umbra_action_actor_clips"] = {"enemy_3": {"hidden_tile": FLIER, "visible_tile": HIDDEN}}
	shown["visible_enemy_ids"] = [1, 3]
	Gallery.submit(_board, state, shown)
	assert(not _ground.field.tiles.has(FLIER) and not _ground.sheet.stamps.has(Vector3i(FLIER.x, FLIER.y, 1)))
	_expect_rows(HIDDEN, "fire_low_rear", "fire_low_front", "electrified_storm_rear", "electrified_storm_front")
	print("GRD-11 ROWS AND DEPTH: PASS (visibility, flight, 2×2 footprint, illusions, props, frame-boundary switch, reduced motion, closer painters and HUD)")

func _check_sizes(view: SubViewport) -> void:
	var state: Dictionary = _state()
	state["player"]["pos"] = HERO
	state["enemies"] = []
	Gallery.Ground.place(state, HERO, "fire")
	var shown: Dictionary = {"biome_id": "stone", "board_framing_mode": "combat"}
	Gallery.submit(_board, state, shown)
	var sheet = _ground.sheet
	_ground.set_motion_time(0.5)
	var initial_tick: int = sheet.tick
	var front: Node2D = _stamp(HERO, true)
	var initial_phase_and_switch: Vector2i = front.get_instance_shader_parameter("phase_and_switch")
	var initial_pairs: Vector4i = front.get_instance_shader_parameter("row_pairs")
	var indices: Dictionary = {}
	for target: int in SizeProof.TARGET_WIDTHS:
		SizeProof.fit(_board, target)
		var choice := Vector2i(sheet.cell_px, sheet.sheet_index)
		var width: float = SizeProof.physical_tile_width(_board)
		_check_render_size(front, width)
		assert(front == _stamp(HERO, true) and sheet.tick == initial_tick)
		assert(front.get_instance_shader_parameter("row_pairs") == initial_pairs)
		assert(front.get_instance_shader_parameter("phase_and_switch") == initial_phase_and_switch)
		indices[choice.y] = true
	assert(indices.size() >= 3)
	var before_pan := Vector2i(sheet.cell_px, sheet.sheet_index)
	_board.set_navigation_pan(Vector2(47.5, -13.5))
	_board.position += Vector2(0.3, -2.7)
	assert(before_pan == Vector2i(sheet.cell_px, sheet.sheet_index))
	_board.reset_navigation()
	SizeProof.fit(_board, 126)
	var before_zoom: int = sheet.sheet_index
	_board.set_navigation_zoom(1.25)
	_check_render_size(front, SizeProof.physical_tile_width(_board))
	assert(sheet.sheet_index != before_zoom and sheet.tick == initial_tick and front == _stamp(HERO, true))
	view.size = Vector2i(2560, 1440)
	await process_frame
	assert(sheet.cell_px == 3 and front == _stamp(HERO, true) and sheet.tick == initial_tick)
	_check_render_size(front, SizeProof.physical_tile_width(_board))
	view.size = Gallery.SIZE
	_board.reset_navigation()
	print("GRD-11 SIZE CHANGES: PASS (100/126/147/184px, zoom and viewport resize retained node, phase and frame)")

func _check_render_size(stamp: Node2D, width: float) -> void:
	var sheet = _ground.sheet
	var cell_px: float = sheet.ink.get_shader_parameter("cell_px")
	var atlas_cells: Vector2i = sheet.ink.get_shader_parameter("frame_cells")
	var center_cells: Vector2i = sheet.ink.get_shader_parameter("centre_cell")
	var sheet_info: Dictionary = Sheet._data["sizes"][sheet.sheet_index]
	assert(cell_px == sheet.cell_px and atlas_cells == Vector2i(_pair(sheet_info["frame_cells"])))
	var ratio: float = float(sheet_info["tile_cells"][0]) * cell_px / width
	assert(ratio >= SizeProof.MIN_RATIO and ratio <= SizeProof.MAX_RATIO)
	var viewport: Viewport = stamp.get_viewport()
	var to_fb: Transform2D = viewport.get_stretch_transform() * stamp.get_global_transform_with_canvas()
	var rect: Rect2 = sheet.framebuffer_rect(to_fb.origin)
	assert(rect.position == to_fb.origin.round() - Vector2(center_cells) * cell_px)
	assert(rect.size == Vector2(atlas_cells) * cell_px and (to_fb * stamp.get("_cull_bounds")).grow(0.001).encloses(rect))

func _check_depth() -> void:
	var layers: Dictionary = _board.get("_scene_render_layers_by_tile")
	var hero: CanvasItem = layers[HERO].get_node("UnitBody_player")
	var outline: CanvasItem = hero.get_node("TeamOutline")
	var closer: CanvasItem = layers[CLOSE_UNIT].get_node("UnitBody_enemy_1")
	var front: Node2D = _stamp(HERO, true)
	assert(Order._draws_after(hero, _stamp(HERO, false)))
	assert(Order._draws_after(front, outline) and Order._draws_after(front, hero))
	assert(Order._draws_after(closer, front) and Order._draws_after(layers[PROP], front))
	for layer: String in ["ForegroundRenderLayer", "EffectsTelegraphs", "EffectsRenderLayer", "HudRenderLayer"]:
		assert(Order._draws_after(_board.get_node(layer), front))
	assert(_board.get("_lifted_ground_focus"))
	var large: CanvasItem = layers[LARGE.end - Vector2i.ONE].get_node("UnitBody_enemy_4")
	for tile: Vector2i in Gallery.tiles_in(LARGE):
		var large_front: Node2D = _stamp(tile, true)
		assert(Order._draws_after(large, _stamp(tile, false)))
		assert(Order._draws_after(large_front, large.get_node("TeamOutline")))

func _expect_rows(tile: Vector2i, rear: String, front: String, storm_rear: String = "", storm_front: String = "") -> void:
	var suffix: String = "_%d" % Sheet.variant_for(SEED, tile)
	var back_ink: Vector2i = _stamp(tile, false).rows_at(_ground.sheet.tick)
	var front_ink: Vector2i = _stamp(tile, true).rows_at(_ground.sheet.tick)
	if front.begins_with("electrified"):
		assert(back_ink == Vector2i(-1, _rows[rear + suffix]) and front_ink == Vector2i(-1, _rows[front + suffix]))
	else:
		assert(back_ink == Vector2i(_rows[rear + suffix], _rows.get(storm_rear + suffix, -1)), "Rear rows at %s: %s" % [tile, back_ink])
		assert(front_ink == Vector2i(_rows[front + suffix], _rows.get(storm_front + suffix, -1)), "Front rows at %s: %s" % [tile, front_ink])

func _stamp(tile: Vector2i, front: bool) -> Node2D:
	return _ground.sheet.stamps[Vector3i(tile.x, tile.y, int(front))]

func _benchmark() -> void:
	var state: Dictionary = _state()
	state["surface_rule_overrides"] = {"conductive_fire": true}
	var enemies: Array[Dictionary]
	var index: int = 1
	for tile: Vector2i in Gallery.tiles_in(TILES):
		enemies.append(_enemy(index, "crawler", tile))
		index += 1
	state["enemies"] = enemies
	state["player"] = {}
	Gallery.place_rect(state, TILES, "fire")
	Gallery.submit(_board, state, {"biome_id": "stone"})
	assert(_ground.field.tiles.size() == 40 and _ground.sheet.stamps.size() == 80)
	assert(_ground.depth.occupied_tiles.size() == 40 and _ground.is_processing())
	for stamp: Node2D in _ground.sheet.stamps.values():
		assert(stamp.material == _ground.sheet.ink)
		stamp.draw.connect(func() -> void: _draws += 1)
	await process_frame
	await process_frame
	var before: int = _draws
	var tile_texture: Texture2D = _ground._tile_data
	var decal_texture: Texture2D = _ground._material.get_shader_parameter("decal_data")
	for frame: int in BENCH_WARMUP:
		_ground._process(TEST_DELTA)
	var started: int = Time.get_ticks_usec()
	for frame: int in BENCH_TICKS:
		_ground._process(TEST_DELTA)
	var mean_ms: float = (Time.get_ticks_usec() - started) / (1000.0 * BENCH_TICKS)
	await process_frame
	assert(_draws == before and _ground._tile_data == tile_texture)
	assert(_ground._material.get_shader_parameter("decal_data") == decal_texture)
	assert(mean_ms <= CPU_LIMIT_MS)
	print("GRD-11 40-TILE CPU: PASS (%.6f ms/frame, %d samples, 1 sheet material, 0 clock-driven redraws)" % [mean_ms, BENCH_TICKS])

func _run_existing_suites() -> void:
	var suites: Dictionary = {
		"board_surface": preload("res://tests/suites/board_surface_suite.gd"),
		"ground_targeting": preload("res://tests/suites/ground_targeting_suite.gd"),
		"surface_core_review": preload("res://tests/suites/surface_core_review_suite.gd"),
		"enemy_surface_acceptance": preload("res://tests/suites/enemy_surface_acceptance_suite.gd"),
		"card_mechanics_surfaces": preload("res://tests/suites/card_mechanics_surfaces_suite.gd"),
		"surface_relic": preload("res://tests/suites/surface_relic_suite.gd"),
	}
	for key: String in suites:
		var previous: int = _failed
		suites[key].run(_check)
		print("GRD-11 SURFACE SUITE %s: %s" % [key, "PASS" if previous == _failed else "FAIL"])

func _check(ok: bool, label: String) -> void:
	if not ok:
		_failed += 1
		push_error(label)

static func _state() -> Dictionary:
	var state: Dictionary = Gallery.Attack.combat_state()
	var grid: Array = []
	for y: int in 10:
		var row: Array = []
		row.resize(10)
		row.fill("stone")
		grid.append(row)
	state["grid"] = grid
	state["surfaces"] = {}
	state["fight_seed"] = SEED
	return state

static func _enemy(id: int, type: String, tile: Vector2i, footprint: Vector2i = Vector2i.ONE) -> Dictionary:
	var hp: int = int(GameData.enemies()[type]["max_hp"])
	return {"id": id, "type": type, "pos": tile, "hp": hp, "max_hp": hp, "footprint": footprint}

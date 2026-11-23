extends SceneTree
## Focused ground geometry evidence at the original desktop and Deck sizes.

const Board = preload("res://scripts/combat_board_view.gd")
const Decals = preload("res://scripts/board_pixel_surface_decals.gd")
const Field = preload("res://scripts/board_pixel_surface_field.gd")
const Layer = preload("res://scripts/board_pixel_surface_layer.gd")
const Fixture = preload("res://tools/grd01/fixtures.gd")
const Baseline = preload("res://tools/grd01/baseline.gd")
const MotionProof = preload("res://tools/grd05/motion_proof.gd")
const SEEDS: PackedInt32Array = [129, 738]
const EPSILON: float = 0.0002
const Stills = preload("res://scripts/board_pixel_surface_stills.gd")

var _placements: int
var _shared_edges: int
var _base_decals: int

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	_check_default_mode()
	var samples: Array[Dictionary] = Fixture.baseline_cases()
	var mixed: Dictionary = samples.back()["state"]
	mixed["player"] = Fixture.Attack.combat_state()["player"]
	mixed["player"]["pos"] = Fixture.MIXED_CLEAR.position
	var atlas_reports: PackedStringArray
	for resolution: Vector2i in [Fixture.SIZE, Baseline.DECK_SIZE]:
		var scale: float = minf(float(resolution.x) / Fixture.SIZE.x, float(resolution.y) / Fixture.SIZE.y)
		if resolution == Baseline.DECK_SIZE:
			scale *= Baseline.DECK_UI_SCALE
		var logical := Vector2i((Vector2(resolution) / scale).round())
		var view: SubViewport = Fixture.make_view(resolution, logical, Viewport.MSAA_DISABLED)
		root.add_child(view)
		var board := Board.new()
		board.size = Vector2(logical)
		view.add_child(board)
		var layer: Layer = board.get_node("PixelGround")
		var previous: Array[Dictionary]
		for seed: int in SEEDS:
			mixed["fight_seed"] = seed
			mixed["surface_rule_overrides"] = {"conductive_fire": seed == SEEDS[1]}
			Fixture.submit(board, mixed, Baseline.BOARD_STATE)
			await process_frame
			assert(layer.field.seed == seed and layer._atlases.size() == Decals.DRAW_ORDER.size())
			assert(layer.depth.occupied_tiles.has(Fixture.MIXED_CLEAR.position))
			if atlas_reports.is_empty():
				atlas_reports = MotionProof.check_atlases(layer)
			_check_region(layer)
			_check_placements(layer)
			_check_base_atlas(layer)
			var original: Array[Dictionary] = layer.depth.placements.duplicate()
			assert(previous.is_empty() or previous != original)
			previous = original
			var zoom: float = board.get("_navigation_zoom")
			for extreme: float in [Board.BOARD_MIN_NAVIGATION_ZOOM, Board.BOARD_MAX_NAVIGATION_ZOOM, zoom]:
				board.set_navigation_zoom(extreme)
				_check_density(board, layer)
				assert(layer.depth.placements == original, "Zoom must preserve board-space anchors")
			var stamps: Dictionary = layer.depth.stamps.duplicate()
			var next: Dictionary = Baseline.BOARD_STATE.duplicate()
			next["ambient_time_seconds"] = Fixture.PROOF_SECONDS + 1.5
			next["reduced_motion"] = true
			Fixture.submit(board, mixed, next)
			assert(layer.depth.placements == original and layer.depth.stamps == stamps and not layer.is_processing())
		var moved: Dictionary = mixed.duplicate(true)
		var first_fire: Vector2i = Fixture.MIXED_CLEAR.position
		var electrified: Vector2i = first_fire + Vector2i(0, Fixture.MIXED_BLOCK.y)
		assert(Field.tile_kind(layer.field.tiles[electrified], Stills.ELECTRIFIED))
		moved["player"]["pos"] = electrified
		Fixture.submit(board, moved, Baseline.BOARD_STATE)
		await process_frame
		assert(not layer.depth.occupied_tiles.has(first_fire) and layer.depth.occupied_tiles.has(electrified))
		_check_placements(layer)
		view.queue_free()
		await process_frame
	assert(_shared_edges > 0)
	print("GRD-09 RUBBLE: PASS (%d atlas elements, deterministic anchors, tile budgets, zoom-stable density)" % _placements)
	print("GRD-08 REGION: PASS (%d same-kind shared edges, rounded outline parameters, 2-texel fringe)" % _shared_edges)
	print("GRD-08 BASE ATLAS: PASS (%d GRD-07 decals bound to the still field)" % _base_decals)
	print("GRD-09 STILL: PASS (clock and reduced motion retain stamps, moving a unit updates Fire and Electrified occupancy)")
	for report: String in atlas_reports:
		print(report)
	quit()

static func _check_default_mode() -> void:
	var flag: String = Layer.MODE_ENV
	var previous: String = OS.get_environment(flag)
	assert(previous == "pixel", "Run with LABYRINTH_GROUND_FX=pixel")
	OS.unset_environment(flag)
	assert(Layer.enabled() and Layer._style["default_mode"] == "pixel")
	OS.set_environment(flag, "off")
	assert(not Layer.enabled())
	Layer._style["default_mode"] = "off"
	OS.unset_environment(flag)
	assert(not Layer.enabled())
	OS.set_environment(flag, "pixel")
	assert(Layer.enabled())
	Layer._style["default_mode"] = "pixel"
	OS.set_environment(flag, previous)
	print("GRD-06 GROUND DEFAULT: PASS (pixel ships by default, off data flip, pixel and off environment overrides)")

func _check_region(layer: Layer) -> void:
	assert(is_equal_approx(pow(1.0 - 2.0 * layer.edge_inset(), 2), 0.8))
	assert(Layer.FRINGE_TEXELS == 2.0)
	assert(Layer.EDGE_AMPLITUDE_TEXELS >= 2.0 and Layer.EDGE_AMPLITUDE_TEXELS <= 4.0)
	assert(Layer.EDGE_LOBES_PER_SIDE >= 1.0 and Layer.EDGE_LOBES_PER_SIDE <= 2.0)
	for tile: Vector2i in layer.field.tiles:
		var flags: Color = layer.field.image.get_pixelv(layer.field.address_of(tile))
		var kind: int = int(flags.r) & 3
		var rubble: bool = (int(flags.r) & Field.RUBBLE) != 0
		for i: int in Field.NEIGHBORS.size():
			var neighbor: Vector2i = tile + Field.NEIGHBORS[i]
			var neighbor_flags: int = layer.field.tiles.get(neighbor, 0)
			var shared: bool = kind != 0 and Field.tile_kind(neighbor_flags, kind)
			assert(bool(int(flags.g) & (1 << i)) == shared)
			assert(bool(int(flags.b) & (1 << i)) == (rubble and Field.tile_kind(neighbor_flags, Field.RUBBLE)))
			if shared and i < 4:
				_shared_edges += 1
				assert(layer.region_inset(tile, kind) == layer.region_inset(neighbor, kind))
		for cap: float in [flags.r, flags.g, flags.b]:
			assert(is_finite(cap))

func _check_placements(layer: Layer) -> void:
	var counts: Dictionary = {}
	var halves: Dictionary = {}
	var anchors: Dictionary = {}
	var last_y: float = -INF
	var projected: Transform2D = layer._tile_projection
	var cells_per_tile: float = Field.HERO_TEXELS_PER_TILE / (projected.x.x * 2.0)
	for placement: Dictionary in layer.depth.placements:
		var tile: Vector2i = placement["tile"]
		var kind: int = placement["kind"]
		var center: Vector2 = placement["center"]
		var local: Vector2 = center - Vector2(tile)
		var size: Vector2i = placement["size"]
		assert(local.abs().x < 0.5 and local.abs().y < 0.5)
		assert(kind == Field.RUBBLE and Field.tile_kind(layer.field.tiles[tile], kind))
		assert(center.x + center.y + EPSILON >= last_y)
		last_y = center.x + center.y
		assert((layer._atlases[kind]["rects"] as Array).has(placement["rect"]))
		assert(size == (placement["rect"] as Rect2i).size)
		counts[tile] = int(counts.get(tile, 0)) + 1
		halves[tile] = int(halves.get(tile, 0)) | (1 if local.x + local.y < 0 else 2)
		var same_kind: Array = anchors.get(tile, [])
		var spacing: float = layer._style[Decals.KIND_NAMES[kind]]["min_spacing_cells"]
		for other: Vector2 in same_kind:
			assert(((projected * center) - (projected * other)).length() * cells_per_tile + EPSILON >= spacing)
		same_kind.append(center)
		anchors[tile] = same_kind
		_placements += 1
	for tile: Vector2i in layer.field.tiles:
		if Field.tile_kind(layer.field.tiles[tile], Field.RUBBLE):
			assert(counts[tile] == int(layer._style["rubble"]["decals_per_tile"]) and halves[tile] == 3)

func _check_base_atlas(layer: Layer) -> void:
	var data: ImageTexture = layer._material.get_shader_parameter("decal_data")
	assert(data != null and Vector2i(data.get_size()) == layer.decals.image.get_size())
	for kind: int in Decals.DRAW_ORDER:
		var atlas: Texture2D = layer._material.get_shader_parameter(Decals.KIND_NAMES[kind] + "_atlas")
		assert(atlas == layer._atlases[kind]["texture"])
		assert(layer.decals.placements.any(func(entry: Dictionary) -> bool: return entry["kind"] == kind))
	for placement: Dictionary in layer.decals.placements:
		if placement["kind"] == Stills.ELECTRIFIED:
			assert(not (int(layer.field.tiles[placement["tile"]]) & Field.STORMCOAL))
	_base_decals += layer.decals.placements.size()

static func _check_density(board: Board, layer: Layer) -> void:
	assert(layer.texel > 0.0)
	assert(layer.render_texel == maxf(layer.texel, layer.framebuffer_pixel))
	assert(layer.texel * Field.HERO_TEXELS_PER_TILE <= board._tile_width() + EPSILON)
	var units: Array[Dictionary] = board.call("_visible_units")
	for unit: Dictionary in units:
		if not layer.Depth.visible_actor(board, unit):
			continue
		var body: Texture2D = board.call("_texture_for_unit", unit)
		if body == null: continue
		var drawn: Rect2 = board.call("_unit_texture_draw_rect", unit, board.call("_unit_center", unit))
		var ratio: Vector2 = drawn.size / body.get_size()
		assert(layer.texel <= minf(ratio.x, ratio.y) + EPSILON)
		assert(layer.render_texel <= maxf(minf(ratio.x, ratio.y), layer.framebuffer_pixel) + EPSILON)
	for placement: Dictionary in layer.depth.placements:
		var stamp: Node2D = layer.depth.stamps[placement["key"]]
		var stamp_rect: Rect2 = stamp.get("rect")
		assert(stamp_rect.size.is_equal_approx(Vector2(placement["size"]) * layer.render_texel))

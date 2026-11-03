extends RefCounted
## Export-aware unit facings and the static, gear-independent hero coverage.
const Solver = preload("res://scripts/intent_chip_placement.gd")
const HeroRest = preload("res://scripts/intent_chip_hero_rest.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Cases = preload("res://tests/fixtures/intent_chip_cases.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const PACKED_REAR: String = "res://tests/pt14_01_packed/rear/fixture.png"
const PACKED_RESOURCE: String = "res://tests/pt14_01_packed/rear.res"
const PACK_ROOT: String = "user://pt14_01_source_regression"
const GEAR_CASES: Array = [{}, {"offhand": "splintered_shield"}, {"trinket": "cracked_lantern"}, {"weapon": "war_maul"}]
const IDLE_PHASES: Array = [0.0, 0.53]
const REFLECTION_QUERY_GRID: int = 8
const COVERAGE_AREA_EPSILON: float = 0.05
const COVERAGE_QUERY_PADDING: float = 1.0

class RestSource extends Node:
	var layout: Dictionary = {"rest_source": PACKED_REAR}
	func _resolve(path: String) -> String: return path

class RearRenderer extends Node:
	var facing: String = "rear"
	var mirrored: bool = false
	var rigs: Dictionary = {}

class SourceBoard extends Board:
	var source_renderer: Node
	var source_key: String = "player"
	func unit_cutout_renderer(unit: Dictionary) -> Node:
		return source_renderer if str(unit.get("key", "")) == source_key else super.unit_cutout_renderer(unit)

static func prepare_fixtures(_tree: SceneTree) -> void:
	# Compatibility entry point for the existing intent suite. Static data is
	# immediately usable by detached boards; there is no preparation to await.
	pass

static func _board() -> SourceBoard:
	var board := SourceBoard.new()
	board.size = Cases.SIZE
	board.set_combat_state(Cases.owner_state())
	return board

static func _packed_rear(expect: Callable) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PACK_ROOT))
	var asset: Texture2D = Assets.load_texture_source_first("res://assets/units/crawler_cutout/rear/rest.png")
	var resource_path: String = PACK_ROOT.path_join("rear.res")
	expect.call(ResourceSaver.save(asset, resource_path) == OK, "Packed rear regression saves approved texture resource")
	var remap_path: String = PACK_ROOT.path_join("fixture.png.remap")
	var remap: FileAccess = FileAccess.open(remap_path, FileAccess.WRITE)
	remap.store_string('[remap]\npath="%s"\n' % PACKED_RESOURCE)
	remap.close()
	var pack := PCKPacker.new()
	var pack_path: String = ProjectSettings.globalize_path(PACK_ROOT.path_join("rear.pck"))
	expect.call(pack.pck_start(pack_path) == OK, "Packed rear regression opens PCK")
	expect.call(pack.add_file(PACKED_RESOURCE, resource_path) == OK, "Packed rear regression packs texture resource")
	expect.call(pack.add_file(PACKED_REAR + ".remap", remap_path) == OK, "Packed rear regression packs PNG remap only")
	expect.call(pack.flush() == OK and ProjectSettings.load_resource_pack(pack_path), "Packed rear regression mounts PCK")
	expect.call(not FileAccess.file_exists(PACKED_REAR) and ResourceLoader.exists(PACKED_REAR), "Packed rear regression: raw_exists=false resource_exists=true")
	var packed: Texture2D = Assets.load_texture_source_first(PACKED_REAR)
	expect.call(packed != null, "Packed rear regression loads through export-aware asset loader")
	if packed == null: return
	var board: SourceBoard = _board()
	board.source_key = "enemy_1"
	var renderer := RearRenderer.new()
	var source := RestSource.new()
	renderer.add_child(source)
	renderer.rigs["rear"] = source
	board.add_child(renderer)
	board.source_renderer = renderer
	var unit: Dictionary = board._units_by_key(board._visible_units())["enemy_1"]
	var actual: Dictionary = Solver.unit_rest_silhouette(board, unit)
	board._unit_textures["crawler"] = packed
	var expected: Dictionary = Solver.unit_rest_silhouette(board, unit)
	expect.call(actual == expected, "Packed-rear mutation: resource-only rear silhouette matches rear art")
	print("PT14 PACKED REAR: raw_exists=%s resource_exists=%s rear_matches=%s" % [FileAccess.file_exists(PACKED_REAR), ResourceLoader.exists(PACKED_REAR), actual == expected])
	board.free()

static func runtime(_tree: SceneTree, expect: Callable) -> void:
	_packed_rear(expect)
	var board: SourceBoard = _board()
	var renderer := RearRenderer.new()
	board.add_child(renderer)
	board.source_renderer = renderer
	var state: Dictionary = Cases.owner_state()
	var badges: Array = Badges.build(Cases.Combat.new(), state, state)["badges"]
	board.prepare_unit_assets_for_state(state)
	var presentation: Dictionary = {"threats_at_rest": {"badges": badges}}
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
	presentation.merge(Cases.owner_presentation(board), true)
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
	var unit: Dictionary = board._units_by_key(board._visible_units())["player"]
	for facing: String in ["front", "rear"]:
		renderer.facing = facing
		var unmirrored: Dictionary = {}
		var unmirrored_draw := Rect2()
		for mirrored: bool in [false, true]:
			renderer.mirrored = mirrored
			var baseline: Dictionary = Solver.unit_rest_silhouette(board, unit)
			var layouts: Array[Dictionary] = Badges.layouts(board, badges)
			for loadout: Dictionary in GEAR_CASES:
				board.presentation["equipped_equipment"] = loadout
				for phase: float in IDLE_PHASES:
					board._idle_elapsed = phase
					expect.call(Solver.unit_rest_silhouette(board, unit) == baseline, "Static hero coverage ignores gear and animation: " + facing)
					expect.call(Badges.layouts(board, badges) == layouts, "Static hero layout ignores gear and animation: " + facing)
			var texture: Texture2D = board._unit_textures["player"]
			var draw: Rect2 = board._unit_draw_rect_for_texture(unit, board._unit_center(unit), texture)
			if Solver.Actor.has_profile("player"): draw.position = board._unit_center(unit) - Solver.Actor.floor_anchor("player", facing, mirrored) * draw.size / Solver.Actor.SOURCE_SIZE
			var first: Vector2 = HeroRest.data_for(facing)["polygons"][0][0]
			if mirrored: first.x = texture.get_width() - first.x
			var projected: Array = baseline.get("polygons", [])
			var matches: bool = not projected.is_empty() and (projected[0][0] as Vector2).is_equal_approx(draw.position + first * draw.size / texture.get_size())
			expect.call(matches, "Static-hero mutation: logical polygons use facing and reflection")
			if not projected.is_empty():
				expect.call((baseline["rect"] as Rect2).is_equal_approx(_polygon_bounds(projected)), "Mirrored-bounds mutation: reflected bounds enclose projected polygons")
				var area: float = _opaque_area(projected) - _opaque_area(baseline.get("holes", []))
				var coverage: float = Solver.coverage((baseline["rect"] as Rect2).grow(COVERAGE_QUERY_PADDING), [baseline])
				expect.call(absf(coverage - area * 2.0) < COVERAGE_AREA_EPSILON, "Hole-subtraction mutation: coverage equals opaque area minus transparent holes")
			if not mirrored:
				unmirrored = baseline
				unmirrored_draw = draw
			else:
				_reflection_queries(unmirrored, baseline, unmirrored_draw, draw, texture.get_size(), facing, expect)
		print("PT14 STATIC HERO: facing=%s gear_independent=true animation_stable=true both_mirrors=true" % facing)
	board.free()

static func _reflection_queries(unmirrored: Dictionary, reflected: Dictionary, first_draw: Rect2, second_draw: Rect2, texture_size: Vector2, facing: String, expect: Callable) -> void:
	# Query the entire footprint, including the edge that reflection moves
	# outside the original bounds. A correct first vertex alone cannot prove
	# that the broad-phase bounds permit those polygon intersections.
	var logical: Rect2 = HeroRest.data_for(facing)["bounds"]
	var cell_size: Vector2 = logical.size / float(REFLECTION_QUERY_GRID)
	var first_scale: Vector2 = first_draw.size / texture_size
	var second_scale: Vector2 = second_draw.size / texture_size
	var positive_queries: int = 0
	for y: int in range(REFLECTION_QUERY_GRID):
		for x: int in range(REFLECTION_QUERY_GRID):
			var cell := Rect2(logical.position + Vector2(x, y) * cell_size, cell_size)
			var first := Rect2(first_draw.position + cell.position * first_scale, cell.size * first_scale)
			var second := Rect2(second_draw.position + Vector2(texture_size.x - cell.end.x, cell.position.y) * second_scale, cell.size * second_scale)
			var first_coverage: float = Solver.coverage(first, [unmirrored])
			var second_coverage: float = Solver.coverage(second, [reflected])
			if first_coverage > COVERAGE_AREA_EPSILON: positive_queries += 1
			expect.call(absf(first_coverage - second_coverage) < COVERAGE_AREA_EPSILON, "Mirrored-bounds mutation: reflected query coverage is equivalent")
	expect.call(positive_queries > 0, "Reflected query fixture includes opaque hero coverage")

static func _polygon_bounds(polygons: Array) -> Rect2:
	var result := Rect2(polygons[0][0], Vector2.ZERO)
	for polygon: PackedVector2Array in polygons:
		for point: Vector2 in polygon: result = result.expand(point)
	return result

static func _opaque_area(polygons: Array) -> float:
	var area: float = 0.0
	for polygon: PackedVector2Array in polygons:
		var twice: float = 0.0
		for index: int in range(polygon.size()):
			var point: Vector2 = polygon[index]
			var next: Vector2 = polygon[(index + 1) % polygon.size()]
			twice += float(point.x) * float(next.y) - float(point.y) * float(next.x)
		area += absf(twice) * 0.5
	return area

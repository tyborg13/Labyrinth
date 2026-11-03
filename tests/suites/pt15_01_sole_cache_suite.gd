extends RefCounted
const Board = preload("res://scripts/combat_board_view.gd")
const Cases = preload("res://tests/fixtures/intent_chip_cases.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const Solver = preload("res://scripts/intent_chip_placement.gd")
const Sources = preload("res://tests/pt14_01_source_suite.gd")
const WARM_LAYOUTS: int = 20
const MOVED_TILE := Vector2i(3, 3)
const SECOND_TILE := Vector2i(3, 2)

class CacheBoard extends Board:
	var source_scans: int = 0
	func _unit_shadow_data_for_texture_with_simplify(texture: Texture2D, epsilon: float) -> Dictionary:
		source_scans += 1
		return super._unit_shadow_data_for_texture_with_simplify(texture, epsilon)

static func run(expect: Callable) -> void:
	var board := CacheBoard.new()
	board.size = Cases.SIZE
	var state: Dictionary = Cases.owner_state()
	var badges: Array = Badges.build(Cases.Combat.new(), state, state)["badges"]
	board.set_combat_state(state)
	var baseline: PackedByteArray = var_to_bytes(Badges.layouts(board, badges))
	var clips: int = Solver.sole_clip_count
	var builds: int = Solver.rest_silhouette_build_count
	var scans: int = board.source_scans
	for _sample: int in range(WARM_LAYOUTS):
		expect.call(var_to_bytes(Badges.layouts(board, badges)) == baseline, "Sole cache preserves byte-identical warm chip layouts")
	expect.call(Solver.sole_clip_count == clips, "Sole-cache mutation: warm identical layouts perform zero sole clips")
	expect.call(Solver.rest_silhouette_build_count == builds, "Rest-cache mutation: warm identical layouts perform zero projection rebuilds")
	expect.call(board.source_scans == scans, "Board-silhouette-cache mutation: warm identical layouts perform zero source rescans")
	print("PT15 SOLE CACHE: %d warm layouts; clips=%d projections=%d source_scans=%d" % [WARM_LAYOUTS, Solver.sole_clip_count - clips, Solver.rest_silhouette_build_count - builds, board.source_scans - scans])
	# Changing the projection must invalidate the shape and sole together.
	var moved: Dictionary = state.duplicate(true)
	moved["enemies"][0]["pos"] = MOVED_TILE
	board.set_combat_state(moved)
	Badges.layouts(board, badges)
	expect.call(Solver.sole_clip_count > clips and Solver.rest_silhouette_build_count > builds, "Moving a unit invalidates its projected silhouette and sole")
	# Replacing the board's alpha data invalidates derived geometry even when
	# texture, world position and shape contents happen to remain identical.
	baseline = var_to_bytes(Badges.layouts(board, badges))
	clips = Solver.sole_clip_count
	builds = Solver.rest_silhouette_build_count
	board._unit_shadow_polygon_cache.clear()
	var rebuilt: PackedByteArray = var_to_bytes(Badges.layouts(board, badges))
	expect.call(Solver.sole_clip_count > clips and Solver.rest_silhouette_build_count > builds, "Clearing board silhouette data invalidates its derived sole cache")
	expect.call(rebuilt == baseline, "Rebuilt source/sole geometry preserves accepted chip positions")
	var crowded: Dictionary = moved.duplicate(true)
	crowded["enemies"].append(Cases.Groups._foe("crawler", 2, SECOND_TILE))
	board.set_combat_state(crowded)
	var units: Dictionary = board._units_by_key(board._visible_units())
	var first: Dictionary = Solver.unit_rest_silhouette(board, units["enemy_1"])
	var second: Dictionary = Solver.unit_rest_silhouette(board, units["enemy_2"])
	expect.call(not is_same(first, second) and first["rect"] != second["rect"], "Two owners sharing a texture keep separate projected sole entries")
	board.set_combat_state(state)
	Solver.rest_silhouettes(board, board._visible_units())
	var entries: Dictionary = board.get_meta(Solver.REST_CACHE_META, {})
	expect.call(not entries.has("enemy_2"), "Removed units release their projected silhouette and sole entries")
	board.free()
	_facings(expect)

static func _facings(expect: Callable) -> void:
	var board: Control = Sources._board()
	var renderer := Sources.RearRenderer.new()
	board.add_child(renderer)
	board.source_key = "enemy_1"
	board.source_renderer = renderer
	var unit: Dictionary = board._units_by_key(board._visible_units())["enemy_1"]
	for facing: String in ["front", "rear"]:
		for mirrored: bool in [false, true]:
			renderer.facing = facing
			renderer.mirrored = mirrored
			var cached: PackedByteArray = var_to_bytes(Solver.unit_rest_silhouette(board, unit))
			board.remove_meta(Solver.REST_CACHE_META)
			expect.call(var_to_bytes(Solver.unit_rest_silhouette(board, unit)) == cached, "Facing/reflection cache invalidation matches a fresh projection and sole: " + facing + " mirrored=" + str(mirrored))
	board.free()

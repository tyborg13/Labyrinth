extends RefCounted
## Independent reference groups and a count of the real medallion hit regions.
## In both revisions each painter registers its icon rect immediately after
## drawing the medallion. Count those rects and exclude number-only regions.

const Areas = preload("res://scripts/boss_area_marks.gd")
const Lob = preload("res://scripts/enemy_mechanics/lob_view.gd")
const Icefall = preload("res://scripts/enemy_mechanics/icefall_view.gd")
const Burrow = preload("res://scripts/enemy_mechanics/burrow_view.gd")
const TileTooltip = preload("res://scripts/board_tile_tooltip.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")

const EDGE_FLOOR := Vector2i(4, 4)
const EDGE_RIGHT := Vector2i(5, 4)
const EDGE_LEFT := Vector2i(4, 5)
const EDGE_FRONT := Vector2i(5, 5)
const EDGE_OUTSIDE := Vector2i(7, 4)
const EDGE_COVER := Vector2i(6, 6)
const EDGE_MARK_TILES := [EDGE_FLOOR, EDGE_RIGHT, EDGE_LEFT, EDGE_FRONT]
const EDGE_DAMAGE: int = 5
const EDGE_SETTLE_FRAMES: int = 4
const STANDING_LINE: String = "\nYou are standing on it."

static func inspect(board: Control) -> Dictionary:
	var sources: Dictionary = _sources(board)
	var expected: Dictionary = {}
	var hovered_tiles: Dictionary = {}
	var all_tile_tooltips: bool = true
	for source: Vector3i in sources:
		var spec: Dictionary = sources[source]
		for group: Array in _components(spec["tiles"]):
			var visible: Array[Vector2i]
			for tile: Vector2i in group:
				if not board._board_tile_is_visible_to_player(tile): continue
				var icon: String = spec["icon"]
				var controller: String = board.controller_tooltip_for_tile(tile)
				all_tile_tooltips = _has_icon(controller, icon) and all_tile_tooltips
				visible.append(tile)
				hovered_tiles[tile] = icon
			if visible.is_empty(): continue
			visible.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _anchor_before(board, a, b))
			var anchor: Vector2i = visible[0]
			expected[anchor] = int(expected.get(anchor, 0)) + 1
	var drawn: Dictionary = {}
	for region: Dictionary in badge_regions(board, hovered_tiles):
		var tile: Vector2i = region["tile"]
		drawn[tile] = int(drawn.get(tile, 0)) + 1
	return {"groups": _count(expected), "medallions": _count(drawn), "anchors": drawn,
		"expected": expected, "all_tile_tooltips": all_tile_tooltips, "anchors_match": expected == drawn}

static func _sources(board: Control) -> Dictionary:
	var result: Dictionary = {}
	var state: Dictionary = board.combat_state
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0: continue
		for tile: Vector2i in Areas.tiles(state, enemy):
			if Paths.is_in_bounds(state["grid"], tile):
				_append(result, Vector3i(0, int(enemy["id"]), 0), tile, "marked")
	var lob: Dictionary = Lob.floor_marks(board)
	for tile: Vector2i in lob:
		var mark: Dictionary = lob[tile]
		_append(result, Vector3i(1, int(mark["enemy"]["id"]), int(mark["damage"])), tile, "lob")
	var ice: Dictionary = Icefall.marks(board)
	for tile: Vector2i in ice:
		var enemy: Dictionary = ice[tile]
		_append(result, Vector3i(2, int(enemy["id"]), Icefall.landing_damage(state, enemy)), tile, "icefall")
	for mark: Dictionary in Burrow.marks(state):
		_append(result, Vector3i(3, int(mark["enemy_id"]), int(mark["damage"])), mark["tile"], "erupt")
	var meteors: Array = state.get("meteor_marks", [])
	var totals: Dictionary = {}
	for mark: Dictionary in meteors:
		var tiles: Array = mark["tiles"]
		for tile: Vector2i in tiles:
			totals[tile] = int(totals.get(tile, 0)) + int(mark.get("damage", 0))
	for index: int in range(meteors.size()):
		for tile: Vector2i in meteors[index]["tiles"]:
			_append(result, Vector3i(4, index, maxi(totals[tile], 0)), tile, "cinder_marks")
	return result

static func _append(sources: Dictionary, source: Vector3i, tile: Vector2i, icon: String) -> void:
	if not sources.has(source): sources[source] = {"tiles": {}, "icon": icon}
	sources[source]["tiles"][tile] = true

# Build components by growing the set of tiles one edge at a time.
static func _components(tiles: Dictionary) -> Array[Array]:
	var groups: Array[Array]
	var remaining: Array = tiles.keys()
	while not remaining.is_empty():
		var group: Array = [remaining.pop_front()]
		var added: bool = true
		while added:
			added = false
			for index: int in range(remaining.size() - 1, -1, -1):
				var tile: Vector2i = remaining[index]
				if group.any(func(member: Vector2i) -> bool: return Paths.manhattan(tile, member) == 1):
					group.append(tile)
					remaining.remove_at(index)
					added = true
		groups.append(group)
	return groups

static func _anchor_before(board: Control, a: Vector2i, b: Vector2i) -> bool:
	var a_class: int = _anchor_class(board, a)
	var b_class: int = _anchor_class(board, b)
	if a_class != b_class: return a_class < b_class
	var a_center: Vector2 = board._tile_center(a)
	var b_center: Vector2 = board._tile_center(b)
	return a_center.y > b_center.y if a_center.y != b_center.y else a_center.x < b_center.x

static func _anchor_class(board: Control, tile: Vector2i) -> int:
	if _occupied(board, tile): return 2
	for y: int in range(tile.y, tile.y + 2):
		for x: int in range(tile.x, tile.x + 2):
			var neighbor := Vector2i(x, y)
			if neighbor != tile and _occupied(board, neighbor, true): return 1
	return 0

static func _occupied(board: Control, tile: Vector2i, standing_only: bool = false) -> bool:
	for unit: Dictionary in board._visible_units():
		if int(unit.get("hp", 1)) <= 0 or unit.get("death_animation", false) or board._unit_is_preview_echo(unit): continue
		if board._unit_footprint_tiles(unit).has(tile): return true
	var state: Dictionary = board.combat_state
	if Paths.tile_id(state["grid"], tile) in Paths.BLOCKING_TILES: return true
	for entry: Dictionary in state.get("terrain", []):
		if entry.get("pos") == tile and Surface.terrain_is_live(entry): return true
	for entry: Dictionary in board.presentation.get("scene_props", []):
		if entry.get("tile") == tile: return true
	if standing_only: return false
	for entry: Dictionary in state.get("loot", []):
		if entry.get("pos") == tile and not entry.get("claimed", false): return true
	for field: String in ["traps", "guardian_braziers"]:
		for entry: Dictionary in state.get(field, []):
			if entry.get("pos") == tile: return true
	return false

static func badge_regions(board: Control, tiles: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for layer: Control in board._retained_render_layers():
		if not layer.visible or layer.get("_render_layer_kind") != "effects": continue
		var size: float = clampf(layer._tile_width() * 0.22, 24.0, 40.0)
		var offset := Vector2(-layer._tile_width() * 0.16, layer._tile_height() * 0.22)
		var regions: Array = layer.get("_tooltip_regions")
		var tile_regions: Dictionary = layer.get("_tile_tooltip_regions")
		for index: int in tile_regions:
			var tile: Vector2i = tile_regions[index]["tile"]
			if not tiles.has(tile): continue
			var rect: Rect2 = regions[index]["rect"]
			if rect.size.is_equal_approx(Vector2.ONE * size) and rect.get_center().is_equal_approx(layer._tile_center(tile) + offset):
				result.append(tile_regions[index])
	return result

static func _has_icon(encoded: String, icon: String) -> bool:
	return TileTooltip.decode(encoded).any(func(entry: Dictionary) -> bool: return entry["icon"] == icon)

static func _count(counts: Dictionary) -> int:
	var total: int = 0
	for count: int in counts.values(): total += count
	return total

static func edge_probe(tree: SceneTree) -> int:
	var size := Vector2i(1920, 1080)
	tree.root.size = size
	var board: Control = load("res://scripts/combat_board_view.gd").new()
	board.size = size
	tree.root.add_child(board)
	var engine: RefCounted = load("res://scripts/combat_engine.gd").new()
	var state: Dictionary = load("res://tests/suites/en02_enemies_suite.gd").fixture(engine)
	state["player"]["pos"] = EDGE_OUTSIDE
	state["enemies"][0]["icefall_tiles"] = EDGE_MARK_TILES.duplicate()
	state["meteor_marks"] = [{"tiles": EDGE_MARK_TILES.duplicate(), "damage": EDGE_DAMAGE, "surface": "fire"}]
	# The real RunScene uses retained effects slices for threat isolation.
	var shown: Dictionary = {"isolated_enemy_actor_keys": []}
	_submit(board, state, shown)
	for frame: int in range(EDGE_SETTLE_FRAMES): await tree.process_frame
	var before: Dictionary = _edge_badges(board)
	var outside_before: bool = _edge_badges_match(before, EDGE_FRONT, false)

	state = state.duplicate(true)
	state["player"]["pos"] = EDGE_FRONT
	var submitted: int = Engine.get_process_frames()
	_submit(board, state, shown)
	await tree.process_frame
	var moved: Dictionary = _edge_badges(board)
	var elapsed: int = Engine.get_process_frames() - submitted
	var inside: bool = _edge_badges_match(moved, EDGE_LEFT, true)
	print("FEL04 EDGE MOVE frame_delta=%d hero=%s before=%s after=%s" % [elapsed, EDGE_FRONT, before, moved])
	var hero_detail: String = board.controller_tooltip_for_tile(EDGE_FRONT)
	var anchor_detail: String = board.controller_tooltip_for_tile(EDGE_LEFT)
	var tile_copy: bool = (
		TileTooltip.plain_text(TileTooltip.decode(hero_detail)).contains(STANDING_LINE)
		and not TileTooltip.plain_text(TileTooltip.decode(anchor_detail)).contains(STANDING_LINE)
		and board._get_tooltip(board._tile_center(EDGE_FRONT)).is_empty()
	)

	state = state.duplicate(true)
	state["player"]["pos"] = EDGE_OUTSIDE
	_submit(board, state, shown)
	await tree.process_frame
	var exited: Dictionary = _edge_badges(board)
	var outside_after: bool = _edge_badges_match(exited, EDGE_FRONT, false)
	print("FEL04 EDGE STANDING inside=%s outside=%s tile_index_and_pointer=%s" % [inside, outside_after, tile_copy])

	state = state.duplicate(true)
	state["terrain"] = [{"pos": EDGE_COVER, "hp": 1, "max_hp": 1, "kind": "outcrop", "blocking": true}]
	_submit(board, state, shown)
	await tree.process_frame
	var covered: Dictionary = _edge_badges(board)
	var object_reanchor: bool = _edge_badges_match(covered, EDGE_LEFT, false)
	print("FEL04 EDGE OBJECT cover=%s anchors=%s" % [EDGE_COVER, covered])

	state = state.duplicate(true)
	state["meteor_marks"] = []
	state["enemies"][0].erase("icefall_tiles")
	_submit(board, state, shown)
	await tree.process_frame
	var idle: bool = _edge_badges(board).is_empty() and not board.call("_last_effect_draw_has_mark_badges")
	print("FEL04 EDGE CLEARED repaint_flag=%s" % board.call("_last_effect_draw_has_mark_badges"))

	state = state.duplicate(true)
	state["enemies"][0]["intent"] = {"name": "Groundsplit", "actions": [
		{"type": "terrain_burst", "damage": EDGE_DAMAGE, "area_fixed_tiles": [EDGE_FLOOR]},
	]}
	_submit(board, state, shown)
	await tree.process_frame
	var single: Array[Dictionary] = badge_regions(board, {EDGE_FLOOR: true})
	var generic: String = preload("res://scripts/action_icon_library.gd").tooltip("marked")
	var entries: Array[Dictionary] = TileTooltip.decode(board.controller_tooltip_for_tile(EDGE_FLOOR))
	var single_match: bool = single.size() == 1 and single[0]["tooltip"] == generic and entries.has(TileTooltip.from_text(generic, "marked"))
	print("FEL04 EDGE SINGLETON generic_unchanged=%s" % single_match)

	var source_filter: bool = await _check_intent_source_filter(tree, board, engine)
	var failures: int = 0
	for passed: bool in [outside_before, elapsed == 1, inside, tile_copy, outside_after, object_reanchor, idle, single_match, source_filter]:
		if not passed: failures += 1
	board.queue_free()
	await tree.process_frame
	print("FEL04 EDGE PROBE %s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	return 0 if failures == 0 else 1

static func _check_intent_source_filter(tree: SceneTree, board: Control, engine: RefCounted) -> bool:
	var fixture: GDScript = load("res://tests/suites/en02_enemies_suite.gd")
	var state: Dictionary = fixture.fixture(engine)
	state["player"]["pos"] = EDGE_OUTSIDE
	state["enemies"][0]["intent"] = fixture.intent("hoarfrost_seer", "icefall_land")
	state["enemies"][0]["icefall_tiles"] = EDGE_MARK_TILES.duplicate()
	state["meteor_marks"] = [{"tiles": [EDGE_FLOOR], "damage": EDGE_DAMAGE, "surface": "fire"}]
	var shown: Dictionary = {"expanded_enemy_actor_keys": ["enemy_1"]}
	_submit(board, state, shown)
	await tree.process_frame
	var tile_text: String = board.controller_tooltip_for_tile(EDGE_FLOOR)
	var visible: bool = board.enemy_intent_visual_global_rect("enemy_1").has_area()
	var player_kept: bool = visible and _has_icon(tile_text, "cinder_marks") and not _has_icon(tile_text, "icefall")

	state = state.duplicate(true)
	state["meteor_marks"][0]["source"] = {"actor_kind": "enemy", "actor_id": 1}
	_submit(board, state, shown)
	await tree.process_frame
	var enemy_removed: bool = board.controller_tooltip_for_tile(EDGE_FLOOR).is_empty()

	shown = shown.duplicate(false)
	shown["visible_enemy_ids"] = []
	_submit(board, state, shown)
	await tree.process_frame
	tile_text = board.controller_tooltip_for_tile(EDGE_FLOOR)
	var hidden_kept: bool = not board.enemy_intent_visual_global_rect("enemy_1").has_area() and _has_icon(tile_text, "icefall") and _has_icon(tile_text, "cinder_marks")

	state = state.duplicate(true)
	state["meteor_marks"] = []
	var enemy: Dictionary = state["enemies"][0]
	enemy.erase("icefall_tiles")
	enemy["type"] = "briar_weaver"
	enemy["intent"] = fixture.intent("briar_weaver", "lash_of_thorns")
	enemy["upheaval_pending"] = {"marks": EDGE_MARK_TILES.duplicate(), "dials": {"health": EDGE_DAMAGE}}
	shown = shown.duplicate(false)
	shown.erase("visible_enemy_ids")
	_submit(board, state, shown)
	await tree.process_frame
	var pending_kept: bool = board.enemy_intent_visual_global_rect("enemy_1").has_area() and _has_icon(board.controller_tooltip_for_tile(EDGE_FLOOR), "marked")
	print("FEL04 EDGE SOURCES player_kept=%s enemy_removed=%s hidden_kept=%s pending_wall_kept=%s" %
		[player_kept, enemy_removed, hidden_kept, pending_kept])
	return player_kept and enemy_removed and hidden_kept and pending_kept

static func _submit(board: Control, state: Dictionary, shown: Dictionary) -> void:
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, shown)

static func _edge_badges(board: Control) -> Dictionary:
	var result: Dictionary = {}
	var tiles: Dictionary = {}
	for tile: Vector2i in EDGE_MARK_TILES: tiles[tile] = true
	for region: Dictionary in badge_regions(board, tiles):
		var tooltip: String = region["tooltip"]
		var title: String = tooltip.get_slice("\n", 0)
		if title not in ["Icefall", "Meteorfall"]: continue
		if not result.has(title): result[title] = []
		result[title].append({"anchor": region["tile"], "standing": tooltip.ends_with(STANDING_LINE)})
	return result

static func _edge_badges_match(badges: Dictionary, anchor: Vector2i, standing: bool) -> bool:
	var record: Dictionary = {"anchor": anchor, "standing": standing}
	return badges.get("Meteorfall") == [record] and badges.get("Icefall") == [record]

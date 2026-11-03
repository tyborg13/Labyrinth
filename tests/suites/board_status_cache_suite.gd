extends RefCounted

const Board = preload("res://scripts/combat_board_view.gd")
const Cache = preload("res://scripts/board_status_layout_cache.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const Fixture = preload("res://tests/suites/threats_at_rest_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const FRAME := Rect2(100, 100, 138, 34)
const COMPACT_TEST_COUNT: int = 100
const COMPACT_SLIVER_WIDTH: float = 8.0
const COMPACT_SLIVER_GAP: float = 1.0
const HISTORY_PAINT_FRAMES: int = 3
const HISTORY_ROUND_TRIPS: int = 2
const Crowded = preload("res://tests/suites/board_hud_group_suite.gd")
const Maneuver = preload("res://scripts/maneuver_rules.gd")

static func run(expect: Callable) -> void:
	var board := Board.new()
	board.size = Vector2(1920, 1080)
	var unit: Dictionary = {"key": "stable", "role": "player", "type": "player", "hp": 24}
	_compare(board, unit, FRAME, "empty", expect)
	var transitions: Dictionary = {"freeze": [1, 2, 0], "petrify": [1, 2, 0], "shock": [1, 2, 0], "immobilize": [true, false], "chilled": [true, false], "bleed": [2, 5, 0], "expose": [1, 4, 0], "frost_armor": [1, 3, 0], "block": [1, 12, 0], "stoneskin": [1, 15, 0], "veiled": [true, false], "burrowed": [true, false], "death_animation": [true, false], "hp": [0, 24], "is_leader": [true, false], "role": ["enemy", "illusion", "player"], "type": ["gale_herald", "storm_capacitor", "ember_tick", "player"]}
	for field: String in transitions:
		var present: bool = unit.has(field)
		var original: Variant = unit.get(field)
		for value: Variant in transitions[field]:
			unit[field] = value
			_compare(board, unit, FRAME, field + "=" + str(value), expect)
		if present: unit[field] = original
		else: unit.erase(field)
		_compare(board, unit, FRAME, "remove " + field, expect)
	unit["keyword_badges"] = [{"icon": "retaliate", "count": 2, "tooltip": "Reactive A"}]
	_compare(board, unit, FRAME, "keyword add", expect)
	unit["keyword_badges"][0]["count"] = 18
	unit["keyword_badges"][0]["tooltip"] = "Reactive B"
	_compare(board, unit, FRAME, "nested keyword count and tooltip change", expect)
	unit["keyword_badges"].append({"icon": "shock", "tooltip": "Reactive Shock"})
	_compare(board, unit, FRAME, "keyword append", expect)
	unit["keyword_badges"].clear()
	_compare(board, unit, FRAME, "keyword clear", expect)
	unit.erase("keyword_badges")
	_compare(board, unit, FRAME, "keyword remove", expect)
	for duration: int in [2, -1, 0]:
		board.presentation["umbra_truesight_activations"] = duration
		_compare(board, unit, FRAME, "Truesight duration " + str(duration), expect)
	for conditional: bool in [true, false]:
		board.presentation["umbra_truesight_conditional"] = conditional
		_compare(board, unit, FRAME, "conditional Truesight " + str(conditional), expect)
	board.presentation.clear()
	_compare(board, unit, FRAME, "Truesight remove", expect)
	var neighbour: Array[Rect2]
	neighbour.append(FRAME)
	board._status_plate_layout.group_obstacles["stable"] = neighbour
	_compare(board, unit, FRAME, "neighbour HUD added", expect)
	neighbour[0] = Rect2(FRAME.position, FRAME.size * 2.0)
	_compare(board, unit, FRAME, "neighbour HUD changed in place", expect)
	board._status_plate_layout.group_obstacles.clear()
	_compare(board, unit, FRAME, "neighbour HUD removed", expect)
	board.free()
	_live_transitions(expect)
	_compact_envelope(expect)
	await _history_transitions(expect)
	await _keyword_badge_repaints(expect)

static func _compare(board: Control, unit: Dictionary, frame: Rect2, label: String, expect: Callable) -> void:
	var actual: Dictionary = board._status_plate_layout.resolve(board, unit, frame)
	var fresh := Cache.new()
	fresh.fixed_order_rects.assign(board._status_plate_layout.fixed_order_rects)
	fresh.board_area = board._status_plate_layout.board_area
	fresh.reserved_ui.assign(board._status_plate_layout.reserved_ui)
	fresh.group_obstacles = board._status_plate_layout.group_obstacles.duplicate(true)
	var expected: Dictionary = fresh.resolve(board, unit, frame)
	for field: String in ["frame", "defenses", "statuses", "defense_rects", "status_rects", "pip_rects", "group_rects"]:
		expect.call(actual[field] == expected[field], "Stable-key cache equals a fresh resolver: " + label + "/" + field)

static func _live_transitions(expect: Callable) -> void:
	var board := Board.new()
	board.size = Vector2(1920, 1080)
	(Engine.get_main_loop() as SceneTree).root.add_child(board)
	var state: Dictionary = Fixture.staged_state(Combat.new())
	state["enemies"] = []
	var frame := Rect2()
	for field: String in ["freeze", "block", "stoneskin"]:
		for value: int in [0, 1, 12, 0]:
			state["player"][field] = value
			var submitted: Dictionary = state.duplicate(true)
			board.set_combat_state(submitted)
			var player: Dictionary = board._hud_layout_units()[0]
			var current: Rect2 = Badges.health_rect(board, player)
			if not frame.has_area(): frame = current
			expect.call(current == frame and player["key"] == "player", "Live add/change/remove test retains its frame and actor key")
			_compare(board, player, current, "live " + field + "=" + str(value), expect)
	for amount: int in [2, 5, 0]:
		state["retaliate"] = {"amount": amount} if amount > 0 else {}
		board.set_combat_state(state.duplicate(true))
		var player: Dictionary = board._hud_layout_units()[0]
		_compare(board, player, Badges.health_rect(board, player), "live keyword " + str(amount), expect)
	for duration: int in [2, -1, 0]:
		board.set_combat_state(state.duplicate(true), [], [], Vector2i(-1, -1), "", "", {}, {}, {"umbra_truesight_activations": duration})
		var player: Dictionary = board._hud_layout_units()[0]
		_compare(board, player, Badges.health_rect(board, player), "live Truesight " + str(duration), expect)
	board.free()

static func _compact_envelope(expect: Callable) -> void:
	var board := Board.new()
	var cache := Cache.new()
	var unit: Dictionary = {"key": "wide", "role": "enemy", "hp": 24, "freeze": 1, "immobilize": true,
		"bleed": COMPACT_TEST_COUNT, "expose": COMPACT_TEST_COUNT, "frost_armor": COMPACT_TEST_COUNT}
	var group: Dictionary = cache.resolve(board, unit, FRAME)
	var raw: Dictionary = group["raw"]
	var normal: Rect2 = cache.Groups.pieces_bounds(raw["pieces"])
	var compact: Rect2 = cache.Groups.pieces_bounds(raw["compact_pieces"])
	expect.call(compact.end.x > normal.end.x, "Compact packing fixture extends beyond the normal word-row bounds")
	var reach: Rect2 = normal.grow_individual(cache.Groups.MAX_HORIZONTAL, FRAME.size.y + cache.Groups.ROW_GAP, cache.Groups.MAX_HORIZONTAL, FRAME.size.y + cache.Groups.ROW_GAP)
	var last_pill: Rect2 = raw["compact_pieces"].back()
	var sliver := Rect2(Vector2(reach.end.x + COMPACT_SLIVER_GAP, last_pill.position.y), Vector2(COMPACT_SLIVER_WIDTH, last_pill.size.y))
	var obstacles: Array[Rect2]
	obstacles.assign([reach, sliver])
	cache.group_obstacles["wide"] = obstacles
	group = cache.resolve(board, unit, FRAME)
	var actual_area: float = cache.Groups.overlap_area(group["group_rects"], Vector2.ZERO, obstacles)
	expect.call(group["compacted"] and is_equal_approx(actual_area, group["placement"]["overlap_area"]), "Compact solve scores every obstacle beyond the normal candidate envelope")
	for rect: Rect2 in group["group_rects"]: expect.call(not rect.intersects(sliver, false), "Compact fallback clears the sliver via another bounded row")
	var other_rects: Array[Rect2]
	other_rects.append(sliver)
	cache._actors["other"] = {"group_bounds": sliver, "group_rects": other_rects}
	cache._group_order.assign(["other", "wide"])
	expect.call(cache._other_groups("wide").has(sliver), "Incremental neighbor prefilter includes the compact candidate envelope")
	board.free()

# Port of the review's cache_paint reproduction: production descriptors stay
# fixed while Freeze is added and removed, with real retained HUD redraws.
static func _history_transitions(expect: Callable) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var original_size: Vector2i = tree.root.size
	tree.root.size = Vector2i(1920, 1080)
	for fixture: String in ["mixed", "air"]:
		var state: Dictionary = Crowded.mixed_state() if fixture == "mixed" else Crowded.warband_run(fixture)["combat_state"]
		var shown: Dictionary = {"reduced_motion": true, "threats_at_rest": Badges.build(Combat.new(), state, state)}
		var cold := Board.new()
		cold.size = Vector2(1920, 1080)
		tree.root.add_child(cold)
		cold.set_combat_state(state.duplicate(true), [], [], Vector2i(-1, -1), "", "", {}, {}, shown)
		await _history_redraw(cold, expect)
		var expected: Dictionary = {"groups": {}, "entries": cold._hud_layout_entries_cache.duplicate(true), "health": cold._hud_health_rects_cache.duplicate(true), "tooltips": cold._hud_render_layer._tooltip_regions.duplicate(true)}
		for unit: Dictionary in cold._hud_layout_units():
			expected["groups"][unit["key"]] = cold._status_plate_layout.cached_group(unit["key"]).duplicate(true)
		var board := Board.new()
		board.size = Vector2(1920, 1080)
		tree.root.add_child(board)
		board.set_combat_state(state.duplicate(true), [], [], Vector2i(-1, -1), "", "", {}, {}, shown)
		await _history_redraw(board, expect)
		_history_check(board, expected, fixture + "/initial A", expect)
		var original_entries: Array = board._hud_layout_entries_cache
		for cycle: int in range(HISTORY_ROUND_TRIPS):
			var changed: Dictionary = state.duplicate(true)
			changed["enemies"][0]["freeze"] = 1
			board.set_combat_state(changed, [], [], Vector2i(-1, -1), "", "", {}, {}, shown)
			_history_check(board, {}, fixture + "/Freeze before paint", expect)
			await _history_redraw(board, expect)
			_history_check(board, {}, fixture + "/Freeze after paint", expect)
			board.set_combat_state(state.duplicate(true), [], [], Vector2i(-1, -1), "", "", {}, {}, shown)
			expect.call(is_same(original_entries, board._hud_layout_entries_cache), "Historical A uses its existing LRU entry: " + fixture)
			_history_check(board, expected, fixture + "/restored A before paint", expect)
			await _history_redraw(board, expect)
			_history_check(board, expected, fixture + "/restored A after paint", expect)
			expect.call(board._hud_render_layer._tooltip_regions == expected["tooltips"], "Historical painted tooltip rects equal cold A: " + fixture)
		board.free()
		cold.free()
		print("HUD HISTORY ROUND TRIP: %s (%d cycles; real redraws; cold geometry)" % [fixture, HISTORY_ROUND_TRIPS])
	tree.root.size = original_size

# pol-29: the hero's keyword badges read top-level combat keys, not the player
# dictionary. A card step that only adds Retaliate, Quicken, a next-attack bonus
# or a self flag must repaint the status row in that beat, not at the card's end.
static func _keyword_badge_repaints(expect: Callable) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var board := Board.new()
	board.size = Vector2(1920, 1080)
	tree.root.add_child(board)
	var state: Dictionary = Fixture.staged_state(Combat.new())
	state["enemies"] = []
	board.set_combat_state(state.duplicate(true))
	for frame: int in range(HISTORY_PAINT_FRAMES): await tree.process_frame
	var layer: Control = board._hud_render_layer
	var draws: int = layer._dynamic_draw_count
	board.set_combat_state(state.duplicate(true))
	for frame: int in range(HISTORY_PAINT_FRAMES): await tree.process_frame
	expect.call(layer._dynamic_draw_count == draws, "Control: an unchanged hero leaves the status row unpainted")
	var changes: Array = [
		["retaliate", {"amount": 3, "sources": ["Spike Check"]}],
		["turn_flags", {"quicken_pending": 2}],
		["turn_flags", {"quicken_pending": 2, "next_attack_buffs": [{"damage": 3}]}],
		[Maneuver.FLAGS_KEY, {Maneuver.FLAG_FIRE_IMMUNE: {"sources": ["Test"]}}],
	]
	for change: Array in changes:
		state[change[0]] = change[1]
		draws = layer._dynamic_draw_count
		board.set_combat_state(state.duplicate(true))
		for frame: int in range(HISTORY_PAINT_FRAMES): await tree.process_frame
		expect.call(layer._dynamic_draw_count > draws, "Hero status row repaints when only %s changes: %s" % [change[0], str(change[1])])
	board.free()

static func _history_redraw(board: Control, expect: Callable) -> void:
	var layer: Control = board._hud_render_layer
	var before: int = layer._dynamic_draw_count
	layer.queue_redraw()
	for frame: int in range(HISTORY_PAINT_FRAMES): await (Engine.get_main_loop() as SceneTree).process_frame
	expect.call(layer._dynamic_draw_count > before, "History regression executes a real retained HUD draw")

static func _history_check(board: Control, expected: Dictionary, phase: String, expect: Callable) -> void:
	expect.call(board._hud_render_layer._hud_layout_entries_cache == board._hud_layout_entries_cache and board._hud_render_layer._hud_health_rects_cache == board._hud_health_rects_cache, "History retained bindings match board: " + phase)
	var units: Dictionary = board._units_by_key(board._hud_layout_units())
	for entry: Dictionary in board._hud_layout_entries_cache:
		var key: String = str(entry["actor_key"])
		var group: Dictionary = board._status_plate_layout.cached_group(key)
		if group.is_empty() or not entry.has("health_rect"): continue
		var anchor: Rect2 = board._unit_health_bar_rect(units[key], board._unit_center(units[key]))
		var frame: Rect2 = group["frame"]
		var delta: Vector2 = frame.position - anchor.position
		expect.call(entry["health_rect"] == frame and board._hud_health_rects_cache[key] == frame, "History entries, focus and plan agree: " + phase + "/" + key)
		expect.call(group["anchor_frame"] == anchor and group["offset"] == delta, "History group retains its true actor anchor: " + phase + "/" + key)
		expect.call(absf(delta.x) <= 24.0 and absf(delta.y) <= anchor.size.y + 4.0, "History draw stays bounded: %s/%s anchor=%s frame=%s delta=%s" % [phase, key, anchor, frame, delta])
		if expected.is_empty(): continue
		for field: String in ["frame", "group_rects", "defense_rects", "status_rects", "pip_rects"]:
			expect.call(group[field] == expected["groups"][key][field], "History drawn rects equal cold A: " + phase + "/" + key + "/" + field)
	if not expected.is_empty():
		expect.call(board._hud_layout_entries_cache == expected["entries"] and board._hud_health_rects_cache == expected["health"], "History derived geometry equals cold A: " + phase)

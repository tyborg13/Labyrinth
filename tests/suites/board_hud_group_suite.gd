extends RefCounted

const Board = preload("res://scripts/combat_board_view.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Fixture = preload("res://tests/suites/threats_at_rest_suite.gd")
const Warband = preload("res://tools/warband_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const SIZE := Vector2(1920, 1080)
const CREST_GUARD_INTENT_GAP: float = 6.0
const CREST_GUARD_INTENT_SIZE := Vector2.ONE
const BOSS_HEADER := Rect2(570, 28, 780, 90)

static func run(expect: Callable) -> void:
	_placement_rules(expect)
	_crest_guard(expect)
	_draw_order(expect)
	_motion_oracle(expect)
	_motion_with_discs(expect)
	var combat := Combat.new()
	var cases: Array[Dictionary]
	var surgeon: Dictionary = Fixture.staged_state(combat)
	surgeon["player"].merge({"block": 6, "stoneskin": 4}, true)
	surgeon["enemies"] = [_foe("grave_surgeon", 1, Vector2i(5, 3))]
	cases.append({"name": "Grave Surgeon defense/disc", "state": surgeon})
	var run_engine := Run.new()
	for biome: String in ["air", "earth", "fire", "ice", "lightning", "shadow"]:
		var options: Dictionary = {"warband_biome": biome, "warband_tier": 2}
		expect.call(Warband.validate(options).is_empty(), "Crowded sweep biome is a production Warband: " + biome)
		var run: Dictionary = Warband.build(run_engine, combat, run_engine.create_new_run(83, Store.default_data()), options)
		_decorate(run["combat_state"])
		cases.append({"name": "Warband " + biome + " seed 83 with crests", "state": run["combat_state"]})
	var crowded: Dictionary = boss_state()
	cases.append({"name": "2x2 boss and neighbours", "state": crowded, "boss": true})
	var mixed: Dictionary = mixed_state()
	cases.append({"name": "Illusions, burrowed units and mixed mechanics", "state": mixed})
	var dragon: Dictionary = crowded.duplicate(true)
	dragon["enemies"][0] = _foe("vyraketh", 1, Vector2i(2, 2))
	dragon["enemies"][0]["footprint"] = Vector2i(2, 2)
	_decorate(dragon)
	cases.append({"name": "Dragon and neighbours", "state": dragon, "boss": true})
	for fixture: Dictionary in cases:
		for expanded: bool in [false, true]: _sweep(fixture, expanded, expect)

static func warband_run(biome: String) -> Dictionary:
	var engine := Run.new()
	var run: Dictionary = Warband.build(engine, Combat.new(), engine.create_new_run(83, Store.default_data()), {"warband_biome": biome, "warband_tier": 2})
	_decorate(run["combat_state"])
	return run

static func boss_state() -> Dictionary:
	var crowded: Dictionary = Fixture.staged_state(Combat.new())
	crowded["enemies"] = [_foe("tharokh", 1, Vector2i(2, 2)), _foe("crawler", 2, Vector2i(4, 2)), _foe("grave_surgeon", 3, Vector2i(5, 3))]
	crowded["enemies"][0]["footprint"] = Vector2i(2, 2)
	crowded["enemies"][1]["is_leader"] = true
	_decorate(crowded)
	return crowded

static func mixed_state() -> Dictionary:
	var mixed: Dictionary = Fixture.staged_state(Combat.new())
	var roster: Array = ["crawler", "burrow_grub", "gale_herald", "gust_shrike", "storm_capacitor", "veilbound_acolyte", "glacial_mirror", "ember_tick"]
	var positions: Array = [Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(3, 4), Vector2i(5, 4), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5)]
	var enemies: Array[Dictionary]
	for index: int in range(roster.size()):
		var enemy: Dictionary = _foe(roster[index], index + 1, positions[index])
		enemy.merge({"burrowed": roster[index] == "burrow_grub", "charge": 2, "is_leader": index == 0})
		enemies.append(enemy)
	mixed["enemies"] = enemies
	mixed["illusions"] = [{"id": 1, "pos": Vector2i(2, 4), "hp": 3, "max_hp": 3, "block": 4, "stoneskin": 3, "chilled": true, "source_name": "Ball Lightning", "on_damaged": {"damage": 4, "element": "lightning", "shock": 1}}]
	_decorate(mixed)
	return mixed

static func _foe(type: String, id: int, tile: Vector2i) -> Dictionary:
	return {"id": id, "type": type, "pos": tile, "hp": 24, "max_hp": 24, "intent": Data.enemy_def(type)["intents"][0]}

static func _decorate(state: Dictionary) -> void:
	state["player"].merge({"block": 6, "stoneskin": 4, "freeze": 1, "shock": 1, "immobilize": true, "bleed": 2, "expose": 1, "frost_armor": 3}, true)
	for enemy: Dictionary in state["enemies"]: enemy.merge({"block": 8, "stoneskin": 3, "immobilize": true, "bleed": 3, "expose": 2}, true)

static func _sweep(fixture: Dictionary, expanded: bool, expect: Callable) -> void:
	var board := Board.new()
	board.size = SIZE
	(Engine.get_main_loop() as SceneTree).root.add_child(board)
	var state: Dictionary = fixture["state"].duplicate(true)
	var rest: Dictionary = Badges.build(Combat.new(), state, state)
	var presentation: Dictionary = {"threats_at_rest": rest, "show_all_enemy_intents": expanded, "reduced_motion": true}
	if fixture.get("boss", false): presentation["boss_health_frame_global_rect"] = BOSS_HEADER
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
	var floor_points: Array[Vector2]
	for polygon: PackedVector2Array in board._board_layout_cache_tile_polygons.values(): floor_points.append_array(polygon)
	var floor_bounds := Rect2(floor_points[0], Vector2.ZERO)
	for point: Vector2 in floor_points: floor_bounds = floor_bounds.expand(point)
	var expected_area := Rect2(floor_bounds.position.x - 160.0, 96.0, floor_bounds.size.x + 320.0, floor_bounds.end.y - 96.0)
	expect.call(board._status_plate_layout.board_area.is_equal_approx(expected_area), "Board area follows director's floor sides, 96px top and floor bottom")
	var elements: Array[Dictionary]
	var units: Array[Dictionary] = board._hud_layout_units()
	var by_key: Dictionary = {}
	for unit: Dictionary in units:
		var key: String = str(unit["key"])
		by_key[key] = unit
		var frame: Rect2 = Badges.health_rect(board, unit)
		if not unit.get("boss_bar", false):
			var group: Dictionary = board._status_plate_layout.resolve(board, unit, frame)
			_add(elements, key, "bar", group["frame"])
			for entry: Dictionary in group["defenses"]: _add(elements, key, entry["icon"], entry["rect"])
			for entry: Dictionary in group["statuses"]: _add(elements, key, entry["icon"], entry["rect"])
			for rect: Rect2 in group["pip_rects"]: _add(elements, key, "charge pip", rect)
			var anchor: Rect2 = board._unit_health_bar_rect(unit, board._unit_center(unit))
			var offset: Vector2 = frame.position - anchor.position
			var ordinary: Array[Dictionary] = board.StatusPlates.defense_entries(unit, anchor, board._unit_damage_preview(unit))
			for index: int in range(ordinary.size()): expect.call((group["defenses"][index]["rect"] as Rect2).position == (ordinary[index]["rect"] as Rect2).position + offset, "Complete HUD group preserves bar/plate spacing")
		else: _add(elements, key, "boss bar", frame)
	for hud: Dictionary in board.get("_hud_layout_entries_cache"):
		var key: String = str(hud["actor_key"])
		var layout: Dictionary = hud.get("layout", {})
		for line: Rect2 in layout.get("line_rects", []): _add(elements, key, "intent", line)
		if by_key.has(key): _add(elements, key, "crest", board._leader_marker_rect(by_key[key], Badges.health_rect(board, by_key[key]), layout.get("intent_rect", Rect2())))
	for layout: Dictionary in Badges.layouts(board, rest["badges"]):
		_add(elements, layout["key"], "chip", layout["rect"])
		if bool(layout["above_everything"]): elements.back()["chip_fallback"] = true
		_add(elements, layout["key"], "disc", layout["order_rect"])
		var unit: Dictionary = by_key[layout["key"]]
		expect.call(layout["order_rect"] == Badges.order_rect(Badges.order_anchor_rect(board, unit), str(layout["order"]), preload("res://scripts/ui_typography.gd").ui_font()), "Order discs remain fixed while complete HUD groups move")
	var compacted: Array[String]
	var forced: Array[String]
	for unit: Dictionary in units:
		if unit.get("boss_bar", false): continue
		var group: Dictionary = board._status_plate_layout.cached_group(str(unit["key"]))
		_check_group(board, unit, group, expect)
		if group["compacted"]: compacted.append(str(unit["key"]))
		expect.call(group["placement"]["legal"], "Every fixture has a director-allowed bounded placement")
		if float(group["placement"]["overlap_area"]) > 0: forced.append(str(unit["key"]))
	var overlaps: int = 0
	for i: int in range(elements.size()):
		for j: int in range(i + 1, elements.size()):
			if elements[i]["key"] == elements[j]["key"]: continue
			var hit: bool = (elements[i]["rect"] as Rect2).intersects(elements[j]["rect"], false)
			if hit: overlaps += 1
			var bounded_forced: bool = forced.has(str(elements[i]["key"])) or forced.has(str(elements[j]["key"]))
			var chip_fallback: bool = elements[i].get("chip_fallback", false) or elements[j].get("chip_fallback", false)
			expect.call(not hit or bounded_forced or chip_fallback, "%s expanded=%s: %s/%s %s crosses %s/%s %s" % [fixture["name"], expanded, elements[i]["key"], elements[i]["kind"], elements[i]["rect"], elements[j]["key"], elements[j]["kind"], elements[j]["rect"]])
	print("HUD GROUP SWEEP: %s expanded=%s (%d elements; %d overlaps; compact=%s; bounded_forced=%s)" % [fixture["name"], expanded, elements.size(), overlaps, compacted, forced])
	board.free()

static func _add(elements: Array[Dictionary], key: String, kind: String, rect: Rect2) -> void:
	if rect.has_area(): elements.append({"key": key, "kind": kind, "rect": rect})

static func _check_group(board: Control, unit: Dictionary, group: Dictionary, expect: Callable) -> void:
	var anchor: Rect2 = group["anchor_frame"]
	var offset: Vector2 = group["offset"]
	expect.call(absf(offset.x) <= 24.0 and absf(offset.y) <= anchor.size.y + 4.0, "HUD stays within one row and 24 px of " + str(unit["key"]))
	for rect: Rect2 in group["group_rects"]:
		expect.call(board._status_plate_layout.board_area.encloses(rect) or offset == Vector2.ZERO, "HUD stays inside floor bounds plus head-room: %s rect=%s bounds=%s anchor=%s placement=%s" % [unit["key"], rect, board._status_plate_layout.board_area, group["anchor_frame"], group["placement"]])
		for reserved: Rect2 in board._status_plate_layout.reserved_ui:
			expect.call(not rect.intersects(reserved, false) or offset == Vector2.ZERO, "HUD stays off reserved live screen UI: " + str(unit["key"]))
	var obstacles: Array[Rect2] = board._status_plate_layout.fixed_order_rects.duplicate()
	obstacles.append_array(board._status_plate_layout.group_obstacles.get(str(unit["key"]), []))
	var ordinary: Array[Rect2]
	ordinary.append(anchor)
	ordinary.append_array(board.StatusPlates.rects(board.StatusPlates.defense_entries(unit, anchor, board._unit_damage_preview(unit))))
	var badges: Array[Dictionary] = board._unit_status_presentation_badges(unit)
	var fill: Rect2 = board._health_bar_content_rect(unit, anchor).grow(-1.0)
	ordinary.append_array(board.StatusPlates.rects(board.StatusPlates.status_entries(badges, fill, str(unit["role"]) in ["player", "illusion"])))
	ordinary.append_array(board._unit_hud_pip_rects(unit, anchor))
	var crest: Rect2 = board._leader_marker_rect(unit, anchor)
	if crest.has_area(): ordinary.append(crest)
	var first_clear: Variant = null
	for y: float in [0.0, -(anchor.size.y + 4.0), anchor.size.y + 4.0]:
		var xs: Array[float]
		xs.assign([0.0, 4.0, 8.0, 12.0, 16.0, 20.0, 24.0, -4.0, -8.0, -12.0, -16.0, -20.0, -24.0])
		for x: float in xs:
			var candidate := Vector2(x, y)
			if _legal_clear(ordinary, candidate, obstacles, board):
				first_clear = candidate
				break
		if first_clear != null: break
	if first_clear != null:
		expect.call(not group["compacted"] and offset == first_clear, "First free bounded normal spot wins before compaction")
	else:
		expect.call(group["compacted"], "All normal candidates exhausted before compact fallback")
		for entry: Dictionary in group["statuses"]:
			if not str(entry.get("status_word", "")).is_empty(): expect.call(not str(entry["label"]).contains(str(entry["status_word"])), "Compact pill drops words")
		var chosen_area: float = _area(group["group_rects"], Vector2.ZERO, obstacles)
		for y: float in [0.0, -(anchor.size.y + 4.0), anchor.size.y + 4.0]:
			for x: float in [0.0, 4.0, 8.0, 12.0, 16.0, 20.0, 24.0, -4.0, -8.0, -12.0, -16.0, -20.0, -24.0]:
				var delta := Vector2(x, y) - offset
				if _legal(group["group_rects"], delta, board, offset): expect.call(chosen_area <= _area(group["group_rects"], delta, obstacles), "Compact placement minimizes overlap within hard limits")

static func _legal(rects: Array[Rect2], offset: Vector2, board: Control, anchor_offset: Vector2 = Vector2.ZERO) -> bool:
	if offset + anchor_offset == Vector2.ZERO: return true
	for rect: Rect2 in rects:
		var placed := Rect2(rect.position + offset, rect.size)
		if not board._status_plate_layout.board_area.encloses(placed): return false
		for reserved: Rect2 in board._status_plate_layout.reserved_ui:
			if placed.intersects(reserved, false): return false
	return true

static func _legal_clear(rects: Array[Rect2], offset: Vector2, obstacles: Array[Rect2], board: Control) -> bool:
	return _legal(rects, offset, board) and _area(rects, offset, obstacles) == 0.0

static func _area(rects: Array[Rect2], offset: Vector2, obstacles: Array[Rect2]) -> float:
	var result: float = 0.0
	for rect: Rect2 in rects:
		var placed := Rect2(rect.position + offset, rect.size)
		for obstacle: Rect2 in obstacles:
			if placed.intersects(obstacle, false): result += placed.intersection(obstacle).get_area()
	return result

static func _placement_rules(expect: Callable) -> void:
	var solver = preload("res://scripts/board_hud_group_placement.gd")
	var pieces: Array[Rect2]
	pieces.append(Rect2(100, 100, 40, 20))
	var obstacles: Array[Rect2]
	var reserved_anchor: Array[Rect2]
	reserved_anchor.append(pieces[0])
	var anchored: Dictionary = solver.choose(pieces, obstacles, Rect2(500, 500, 10, 10), reserved_anchor, 20)
	expect.call(anchored["offset"] == Vector2.ZERO and anchored["legal"], "Own anchored spot is always allowed outside board and reserved UI")
	obstacles.append(Rect2(90, 100, 80, 20))
	var reserved: Array[Rect2]
	var placed: Dictionary = solver.choose(pieces, obstacles, Rect2(100, 100, 64, 44), reserved, 20)
	expect.call(placed["offset"] == Vector2(0, 24), "Board bounds reject the otherwise free row above")
	reserved.append(Rect2(100, 124, 64, 20))
	placed = solver.choose(pieces, obstacles, Rect2(76, 66, 88, 78), reserved, 20)
	expect.call(placed["offset"] == Vector2(0, -24), "Reserved screen UI rejects row below")
	reserved.append(Rect2(76, 76, 88, 20))
	placed = solver.choose(pieces, obstacles, Rect2(76, 66, 88, 78), reserved, 20)
	expect.call(absf(placed["offset"].y) <= 24 and absf(placed["offset"].x) <= 24, "Exhausted search stays bounded instead of cascading")
	# Both clear rows must be unavailable for different reasons. A reservation
	# ablation must expose the lower row, rather than leave the free upper row.
	obstacles.clear()
	obstacles.append(Rect2(76, 76, 88, 44))
	reserved.clear()
	reserved.append(Rect2(76, 124, 88, 20))
	placed = solver.choose(pieces, obstacles, Rect2(76, 66, 88, 78), reserved, 20)
	expect.call(placed["offset"] == Vector2.ZERO and placed["overlap_area"] > 0, "Reserved UI blocks the only otherwise clear bounded row")


static func _crest_guard(expect: Callable) -> void:
	var board := Board.new()
	board.size = SIZE
	(Engine.get_main_loop() as SceneTree).root.add_child(board)
	var state: Dictionary = Fixture.staged_state(Combat.new())
	state["enemies"] = [_foe("crawler", 1, Vector2i(4, 3)), _foe("crawler", 2, Vector2i(2, 6)), _foe("crawler", 3, Vector2i(6, 6))]
	state["enemies"][1]["is_leader"] = true
	state["enemies"][2]["is_leader"] = true
	var badge: Dictionary = {"key": "enemy_1", "icon": "melee", "number": "5", "order": "1"}
	board.set_combat_state(state)
	var units: Array[Dictionary] = board._hud_layout_units()
	var by_key: Dictionary = board._units_by_key(units)
	var center: Vector2 = board._unit_center(by_key["enemy_1"])
	var font: Font = preload("res://scripts/ui_typography.gd").ui_font()
	var positions: Dictionary = {}
	var candidates: Array[Rect2]
	for direction: float in [1.0, -1.0]:
		candidates.append(Badges.chip_rect(center + Vector2(direction * Badges.FEET_OFFSET.x, Badges.FEET_OFFSET.y), badge, font))
	for index: int in range(2):
		var unit: Dictionary = by_key["enemy_%d" % (index + 2)]
		var frame: Rect2 = board._unit_health_bar_rect(unit, board._unit_center(unit))
		var crest: Rect2 = board._leader_marker_rect(unit, frame)
		var target := Vector2(candidates[index].get_center().x - crest.size.x * 0.5, candidates[index].end.y + 1.0 - crest.size.y + board.LEADER_CREST_SEAT)
		positions[unit["key"]] = board._unit_center(unit) + target - crest.position
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"unit_world_positions": positions})
	units = board._hud_layout_units()
	by_key = board._units_by_key(units)
	# Fixture-only expanded lines seat the second crest above its displaced bar.
	# Both real bars and lines stay below the chip candidates, making crest
	# obstacles alone decisive. The production crest query reads these placed
	# cached intent bounds exactly as it does after expanded intent placement.
	var crests: Array[Rect2]
	for entry: Dictionary in board._hud_layout_entries_cache:
		var key: String = str(entry["actor_key"])
		if key not in ["enemy_2", "enemy_3"]: continue
		var health: Rect2 = Badges.health_rect(board, by_key[key])
		var line := Rect2(Vector2(health.end.x, candidates[0].end.y + CREST_GUARD_INTENT_GAP), CREST_GUARD_INTENT_SIZE)
		entry["layout"]["intent_rect"] = line
		var lines: Array[Rect2]
		lines.append(line)
		entry["layout"]["line_rects"] = lines
	for key: String in ["enemy_2", "enemy_3"]:
		var health: Rect2 = Badges.health_rect(board, by_key[key])
		var intent := Rect2()
		for entry: Dictionary in board._hud_layout_entries_cache:
			if entry["actor_key"] == key: intent = entry["layout"]["intent_rect"]
		crests.append(board._leader_marker_rect(by_key[key], health, intent))
	for index: int in range(2): expect.call(candidates[index].intersects(crests[index], false), "Both default chip candidates collide with placed leader crests: %s vs %s" % [candidates[index], crests[index]])
	var badges: Array[Dictionary]
	badges.append(badge)
	var layouts: Array[Dictionary] = Badges.layouts(board, badges)
	expect.call(layouts.size() == 1, "Crest fixture exposes its threat chip")
	for layout: Dictionary in layouts:
		for crest: Rect2 in crests: expect.call(bool(layout["above_everything"]) or not (layout["rect"] as Rect2).intersects(crest, false), "Production chip search avoids decisive placed crest obstacles")
	board.free()

static func _draw_order(expect: Callable) -> void:
	var board := Board.new()
	board.size = SIZE
	(Engine.get_main_loop() as SceneTree).root.add_child(board)
	board.set_combat_state(mixed_state())
	var units: Array[Dictionary] = board._hud_layout_units()
	var by_key: Dictionary = board._units_by_key(units)
	var previous_y: float = -INF
	var previous_column: int = -1
	for entry: Dictionary in board._hud_group_draw_entries(units):
		var unit: Dictionary = by_key[entry["actor_key"]]
		var y: float = board._unit_center(unit).y
		var column: int = unit["pos"].x
		if unit.get("role") == "player": continue
		expect.call(y > previous_y or (is_equal_approx(y, previous_y) and column >= previous_column), "Non-hero group draw order follows floor y, then column")
		previous_y = y
		previous_column = column
	expect.call(board._hud_group_draw_entries(units).back()["actor_key"] == "player", "Hero draws above every unfocused group")
	for key: String in ["player", "enemy_1"]:
		board.set_controller_focus_tile(by_key[key]["pos"])
		expect.call(board._hud_group_draw_entries(units).back()["actor_key"] == key, "Controller-focused group draws last")
	board.set_controller_focus_tile(Vector2i(-1, -1))
	board._hover_tile = by_key["enemy_1"]["pos"]
	expect.call(board._hud_group_draw_entries(units).back()["actor_key"] == "enemy_1", "Hovered group draws last")
	board.free()

static func _motion_oracle(expect: Callable) -> void:
	var solver = preload("res://scripts/board_hud_group_placement.gd")
	var pieces: Array[Rect2]
	pieces.append(Rect2(100, 100, 138, 34))
	pieces.append(Rect2(100, 134, 120, 22))
	pieces.append(Rect2(242, 105, 46, 24))
	var base: Array[Rect2]
	base.append(Rect2(120, 90, 130, 34))
	base.append(Rect2(240, 130, 80, 22))
	var reserved: Array[Rect2]
	reserved.append(Rect2(0, 190, 400, 40))
	for moving_owner: bool in [true, false]:
		var memo: Dictionary = {}
		for sample: int in range(240):
			# Both motion directions, edge crossings, ties and winner crossings.
			var x: float = (sample if sample < 120 else 240 - sample) * 0.123
			var rects: Array[Rect2] = solver.translate_rects(pieces, Vector2(x, 0) if moving_owner else Vector2.ZERO)
			var obstacles: Array[Rect2] = solver.translate_rects(base, Vector2.ZERO if moving_owner else Vector2(x, 0))
			var actual: Dictionary = solver.choose_incremental(rects, obstacles, Rect2(80, 50, 280, 180), reserved, 34, memo)
			var expected: Dictionary = solver.choose(rects, obstacles, Rect2(80, 50, 280, 180), reserved, 34)
			expect.call(actual["offset"] == expected["offset"] and actual["legal"] == expected["legal"], "Incremental collision cell equals exhaustive bounded solve, sample %d owner=%s" % [sample, moving_owner])

static func _motion_with_discs(expect: Callable) -> void:
	var board := Board.new()
	board.size = SIZE
	(Engine.get_main_loop() as SceneTree).root.add_child(board)
	var state: Dictionary = mixed_state()
	var rest: Dictionary = Badges.build(Combat.new(), state, state)
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"threats_at_rest": rest})
	var units: Array[Dictionary] = board._hud_layout_units()
	var by_key: Dictionary = board._units_by_key(units)
	var center: Vector2 = board._unit_center(by_key["enemy_1"])
	var lru_size: int = board._hud_layout_cache_by_signature.size()
	for sample: int in range(1, 5):
		var before: Dictionary = {}
		for unit: Dictionary in units: before[unit["key"]] = board._status_plate_layout.cached_group(unit["key"])
		board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"threats_at_rest": rest, "unit_world_positions": {"enemy_1": center + Vector2(sample * 0.123, 0)}})
		units = board._hud_layout_units()
		var builds: int = board._status_plate_layout.rebuilds
		var reused: int = 0
		for unit: Dictionary in units:
			var key: String = str(unit["key"])
			if board._status_plate_layout.last_updated_keys.has(key): continue
			var drawn: Dictionary = board._status_plate_layout.resolve(board, unit, Badges.health_rect(board, unit))
			expect.call(is_same(before[key], drawn), "Paint reuses untouched groups even when a fixed order disc moves")
			reused += 1
		expect.call(reused > 0 and board._status_plate_layout.rebuilds == builds, "Untouched paint queries allocate no new group layouts")
		expect.call(board._hud_layout_cache_by_signature.size() == lru_size, "Disc interpolation inserts no deep full-layout LRU entries")
	board.free()

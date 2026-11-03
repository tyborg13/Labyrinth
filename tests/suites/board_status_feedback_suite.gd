extends RefCounted

const Board = preload("res://scripts/combat_board_view.gd")
const Groups = preload("res://scripts/board_hud_group_placement.gd")
const Plates = preload("res://scripts/board_status_plates.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Elements = preload("res://scripts/element_data.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Fixture = preload("res://tests/suites/threats_at_rest_suite.gd")
const Warband = preload("res://tools/warband_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const VIEWPORT := Vector2(1920, 1080)
const CACHE_FRAME := Rect2(100, 100, 138, 34)

static func run(expect: Callable) -> void:
	_test_illusion_source(expect)
	_test_live_charge_and_cache(expect)
	_test_palette_and_styles(expect)
	_test_real_collision_cases(expect)
	_test_disc_adjustment(expect)
	_test_chip_search_extent(expect)

static func _test_illusion_source(expect: Callable) -> void:
	var state: Dictionary = Fixture.staged_state(Combat.new())
	state["illusions"] = [{"id": 1, "pos": Vector2i(2, 4), "hp": 3, "max_hp": 3, "source_name": "Ball Lightning", "on_damaged": {"damage": 4, "element": "lightning", "shock": 1}}]
	var board := Board.new()
	board.size = VIEWPORT
	board.set_combat_state(state)
	var found: bool = false
	for unit: Dictionary in board._hud_layout_units():
		if unit.get("role") != "illusion": continue
		found = true
		expect.call(int(unit["shock"]) == 0, "Ball Lightning's healthy illusion has no Shock restriction")
		var badges: Array[Dictionary] = board._unit_status_presentation_badges(unit)
		expect.call(badges.size() == 1 and badges[0]["icon"] == "shock", "Ball Lightning retains its approved retaliation icon")
		expect.call(badges[0]["status_class"] == "buff" and badges[0]["label"] == "" and badges[0]["presentation_border"] == Palette.GOLD_BRIGHT, "Retaliatory Shock is an icon-only gold buff, never a false Shocked restriction")
		expect.call(str(badges[0]["tooltip"]).contains("Enemies that damage this illusion"), "Ball Lightning keeps its reactive effect tooltip")
		unit["shock"] = 1
		badges = board._unit_status_presentation_badges(unit)
		expect.call(badges.size() == 2 and badges[0]["label"] == "Shocked" and badges[1]["label"] == "", "An actually Shocked illusion distinguishes holder restriction from reactive buff")
	expect.call(found, "Ball Lightning regression traverses live illusion projection")
	board.free()

static func _test_live_charge_and_cache(expect: Callable) -> void:
	var state: Dictionary = Fixture.staged_state(Combat.new())
	state["enemies"] = [{"id": 1, "type": "storm_capacitor", "pos": Vector2i(4, 3), "hp": 24, "max_hp": 24, "charge": 2, "intent": Data.enemy_def("storm_capacitor")["intents"][0]}]
	var board := Board.new()
	board.size = VIEWPORT
	board.set_combat_state(state)
	var unit: Dictionary = {}
	for candidate: Dictionary in board._hud_layout_units():
		if candidate.get("type") == "storm_capacitor": unit = candidate
	expect.call(int(unit.get("charge", -1)) == 2, "Positive charge propagates through the live unit projection")
	var pills: Array[Dictionary] = board._unit_status_pill_entries(unit, CACHE_FRAME)
	expect.call(pills.size() == 1 and pills[0]["label"] == "2" and pills[0]["presentation_border"] == Palette.TEXT_2, "Live positive charge appears as a counted trait")
	var cached: Dictionary = board._status_plate_layout.resolve(board, unit, CACHE_FRAME)
	var rebuilds: int = board._status_plate_layout.rebuilds
	for _repeat: int in range(12):
		expect.call(is_same(cached, board._status_plate_layout.resolve(board, unit, CACHE_FRAME)), "Unchanged status signature reuses the laid-out entry dictionaries and labels")
	expect.call(board._status_plate_layout.rebuilds == rebuilds, "Repeated unchanged redraws rebuild no status layouts")
	pills.clear()
	expect.call(board._unit_status_pill_entries(unit, CACHE_FRAME).size() == 1, "Caller mutations cannot poison cached layout arrays")
	unit["charge"] = 1
	expect.call(board._unit_status_pill_entries(unit, CACHE_FRAME)[0]["label"] == "1", "Charge changes invalidate cached labels")
	var before: Rect2 = board._unit_status_pill_entries(unit, CACHE_FRAME)[0]["rect"]
	var moved := Rect2(CACHE_FRAME.position + Vector2.ONE, CACHE_FRAME.size)
	expect.call((board._unit_status_pill_entries(unit, moved)[0]["rect"] as Rect2).position == before.position + Vector2.ONE, "Frame motion invalidates cached rectangles")
	board.presentation["surface_status_preview"] = {str(unit["key"]): {"freeze": 1}}
	expect.call(board._unit_status_pill_entries(unit, CACHE_FRAME).any(func(entry: Dictionary) -> bool: return entry["label"] == "→ Frozen"), "Predicted statuses invalidate cached pills")
	board.presentation["surface_status_preview"][str(unit["key"])] = {"shock": 1}
	expect.call(board._unit_status_pill_entries(unit, CACHE_FRAME).any(func(entry: Dictionary) -> bool: return entry["label"] == "→ Shocked"), "In-place prediction changes are compared against an owned signature")
	board.presentation["damage_preview"] = {str(unit["key"]): {"block": 4, "block_loss": 2}}
	board.set("_submission_cache_valid", false)
	expect.call(board._unit_defense_plate_entries(unit, CACHE_FRAME)[0]["label"] == "4", "Defense previews invalidate cached plate amounts")
	var disc_unit: Dictionary = {"key": "disc_cache", "role": "enemy", "type": "crawler", "hp": 10, "bleed": 3}
	var original: Rect2 = board._unit_status_pill_entries(disc_unit, CACHE_FRAME)[0]["rect"]
	board._status_plate_layout.fixed_order_rects.append(Rect2(original.position + Vector2(20, 0), Vector2(24, 24)))
	var moved_group: Dictionary = board._status_plate_layout.resolve(board, disc_unit, CACHE_FRAME)
	expect.call((moved_group["frame"] as Rect2).position != CACHE_FRAME.position and (moved_group["statuses"][0]["rect"] as Rect2).position - original.position == (moved_group["frame"] as Rect2).position - CACHE_FRAME.position, "Changed fixed discs move the complete cached group even when holder statuses are unchanged")
	board._status_plate_layout.fixed_order_rects.clear()
	expect.call(board._unit_status_pill_entries(disc_unit, CACHE_FRAME)[0]["rect"] == original, "Removing a fixed disc restores the approved default row anchor")
	board.free()

static func _test_palette_and_styles(expect: Callable) -> void:
	var defenses: Array[Dictionary] = Plates.defense_entries({"block": 8, "stoneskin": 3}, CACHE_FRAME)
	expect.call(defenses[0]["presentation_border"] == Palette.STEEL, "Block border uses the independently approved STEEL token")
	expect.call(defenses[1]["presentation_border"] == Elements.accent(Elements.EARTH), "Stoneskin border uses the existing Earth element accent")
	for border: Color in [Palette.EMBER, Palette.DANGER_BRIGHT, Palette.GOLD_BRIGHT, Palette.TEXT_2, Palette.STEEL, Elements.accent(Elements.EARTH)]:
		var first: StyleBoxFlat = Plates._style(border, 11, 1.0)
		var count: int = Plates._styles.size()
		var second: StyleBoxFlat = Plates._style(border, 11, 1.0)
		expect.call(is_same(first, second) and Plates._styles.size() == count, "Style identity and cache size remain stable after warmup")
		expect.call(first.border_color == border, "Cached style retains the approved border token")

static func _test_real_collision_cases(expect: Callable) -> void:
	var combat := Combat.new()
	var burrowed: Dictionary = Fixture.staged_state(combat)
	burrowed["enemies"] = [{"id": 1, "type": "burrow_grub", "pos": Vector2i(4, 3), "hp": 10, "max_hp": 10, "burrowed": true, "immobilize": true, "bleed": 3, "expose": 2, "intent": Data.enemy_def("burrow_grub")["intents"][0]}]
	_check_collision_case(burrowed, "burrowed grub", expect)
	var engine := Run.new()
	var run: Dictionary = Warband.build(engine, combat, engine.create_new_run(83, Store.default_data()), {"warband_biome": "air", "warband_tier": 2})
	for enemy: Dictionary in run["combat_state"]["enemies"]: enemy.merge({"block": 8, "stoneskin": 3, "immobilize": true, "bleed": 3, "expose": 2}, true)
	_check_collision_case(run["combat_state"], "Air Warband seed 83", expect)
	var boss: Dictionary = Fixture.staged_state(combat)
	boss["enemies"] = [{"id": 1, "type": "tharokh", "pos": Vector2i(2, 2), "hp": 100, "max_hp": 100, "footprint": Vector2i(2, 2), "intent": Data.enemy_def("tharokh")["intents"][0]}, {"id": 2, "type": "crawler", "pos": Vector2i(4, 2), "hp": 20, "max_hp": 20, "intent": Data.enemy_def("crawler")["intents"][0]}]
	boss["player"].merge({"block": 6, "stoneskin": 4, "freeze": 1, "shock": 1, "immobilize": true, "bleed": 2, "expose": 1, "frost_armor": 3}, true)
	for enemy: Dictionary in boss["enemies"]: enemy.merge({"block": 8, "stoneskin": 3, "immobilize": true, "bleed": 3, "expose": 2}, true)
	_check_collision_case(boss, "crowded 2x2 boss", expect)

static func _check_collision_case(state: Dictionary, label: String, expect: Callable) -> void:
	var board := Board.new()
	board.size = VIEWPORT
	(Engine.get_main_loop() as SceneTree).root.add_child(board)
	var rest: Dictionary = Badges.build(Combat.new(), state, state)
	var presentation: Dictionary = {"threats_at_rest": rest, "reduced_motion": true}
	if label == "crowded 2x2 boss": presentation["boss_health_frame_global_rect"] = Rect2(570, 28, 780, 90)
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
	var layouts: Array[Dictionary] = Badges.layouts(board, rest["badges"])
	expect.call(not layouts.is_empty(), label + " has production threat chips and order discs")
	for layout: Dictionary in layouts:
		for unit: Dictionary in board._hud_layout_units():
			if unit.get("boss_bar", false): continue
			var frame: Rect2 = Badges.health_rect(board, unit)
			var entries: Array[Dictionary] = board._unit_status_pill_entries(unit, frame)
			entries.append_array(board._unit_defense_plate_entries(unit, frame))
			for entry: Dictionary in entries:
				expect.call(bool(layout["above_everything"]) or not (layout["rect"] as Rect2).intersects(entry["rect"], false), label + ": threat chip avoids " + str(entry["icon"]))
				expect.call(not (layout["order_rect"] as Rect2).intersects(entry["rect"], false) or _bounded_overlap(board, unit), label + ": pill avoids fixed disc or exhausts compact bounded candidates " + str(entry["icon"]))
		var owner: Dictionary = {}
		for unit: Dictionary in board._hud_layout_units():
			if unit.get("key") == layout["key"]: owner = unit
		expect.call(layout["order_rect"] == Badges.order_rect(Badges.order_anchor_rect(board, owner), str(layout["order"]), preload("res://scripts/ui_typography.gd").ui_font()), label + ": disc keeps its approved position")
	board.free()

static func _test_disc_adjustment(expect: Callable) -> void:
	var pieces: Array[Rect2]
	pieces.append(Rect2(100, 100, 40, 22))
	var discs: Array[Rect2]
	discs.append(Rect2(80, 100, 24, 24))
	expect.call(Groups.offset_for(pieces, discs) == Vector2(4, 0), "A complete HUD group takes the exact clear right shift within 24 px")
	discs[0] = Rect2(120, 100, 24, 24)
	expect.call(Groups.offset_for(pieces, discs) == Vector2(-20, 0), "The bounded search tries left before changing rows")

static func _test_chip_search_extent(expect: Callable) -> void:
	# A single clear 32x32 corner is outside both original feet candidates.
	var bounds := Rect2(0, 0, 128, 96)
	var obstacles: Array[Rect2]
	obstacles.append(Rect2(0, 0, 96, 96))
	obstacles.append(Rect2(96, 0, 32, 64))
	var badge: Dictionary = {"icon": "melee", "number": ""}
	var font: Font = preload("res://scripts/ui_typography.gd").ui_font()
	var placed: Dictionary = Badges.place_chip(Vector2(32, 32), badge, font, obstacles, [], bounds)
	expect.call(placed["rect"] == Badges.chip_rect(Vector2(32, 32) + Badges.FEET_OFFSET, badge, font) and placed["above_everything"], "A clear diagonal pocket beyond 24px cannot detach a chip from its owner")
	obstacles.clear()
	obstacles.append(bounds)
	placed = Badges.place_chip(Vector2(32, 32), badge, font, obstacles, [], bounds)
	expect.call(placed["above_everything"], "A fully obstructed bounded search draws above HUD at home")

static func _bounded_overlap(board: Control, unit: Dictionary) -> bool:
	var group: Dictionary = board._status_plate_layout.cached_group(str(unit["key"]))
	return bool(group.get("compacted", false)) and float(group.get("placement", {}).get("overlap_area", 0.0)) > 0.0

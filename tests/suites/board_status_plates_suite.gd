extends RefCounted

const Plates = preload("res://scripts/board_status_plates.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const ThreatFixture = preload("res://tests/suites/threats_at_rest_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const CalloutLayout = preload("res://scripts/intent_callout_layout.gd")
const EXPECTED_WORDS: Dictionary = {"freeze": "Frozen", "petrify": "Petrified", "shock": "Shocked", "immobilize": "Immobilized", "chilled": "Chilled"}
const EXPECTED_CLASS_BORDERS: Dictionary = {"control": Palette.EMBER, "vulnerable": Palette.DANGER_BRIGHT, "buff": Palette.GOLD_BRIGHT, "trait": Palette.TEXT_2}
const ThreatBadges = preload("res://scripts/intent_badges.gd")
# Test-only geometry; no production tuning.
const TEST_FRAME := Rect2(100, 100, 140, 24)
const TEST_WRAP_FRAME := Rect2(100, 100, 60, 24)
const TEST_THREAT_ANCHOR := Vector2(600, 500)
const TEST_OFFSCREEN_FRAME := Rect2(-1000, -1000, 138, 34)
const TEST_CARRIER_FRAME := Rect2(0, 0, 8, 32)
const TEST_OBSTACLE_INSET := Vector2.ONE

# Isolate HUD collision from actor art and scenery while running the production
# badge placement and production plate/pill geometry without a renderer.
class ThreatGeometryBoard extends Board:
	var fixture_units: Array[Dictionary]
	var fixture_frames: Dictionary
	func _visible_units() -> Array[Dictionary]: return fixture_units
	func _hud_layout_units() -> Array[Dictionary]: return fixture_units
	func _unit_center(unit: Dictionary) -> Vector2: return unit.get("proof_center", Vector2.ZERO)
	func _unit_draw_rect(_unit: Dictionary) -> Rect2: return TEST_OFFSCREEN_FRAME
	func _unit_health_bar_rect(unit: Dictionary, _center: Vector2) -> Rect2: return fixture_frames[str(unit["key"])]
	func _foreground_obstruction_candidates() -> Array[Dictionary]:
		var result: Array[Dictionary]
		return result

class PaintRecorder extends RefCounted:
	var styles: Array[Dictionary]
	var regions: Array[Dictionary]
	var textures: Array[Dictionary]
	var labels: Array[Dictionary]
	func draw_style_box(style: StyleBox, rect: Rect2) -> void: styles.append({"style": style, "rect": rect})
	func draw_line(_from: Vector2, _to: Vector2, _color: Color, _width: float, _antialiased: bool) -> void: pass
	func draw_texture_rect_region(texture: Texture2D, rect: Rect2, source: Rect2, color: Color) -> void:
		textures.append({"texture": texture, "rect": rect, "source": source, "color": color})
	func draw_string_outline(_font: Font, _pos: Vector2, _text: String, _align: int, _width: float, _size: int, _outline: int, _color: Color) -> void: pass
	func draw_string(font: Font, pos: Vector2, text: String, _align: int, _width: float, size: int, color: Color) -> void:
		labels.append({"font": font, "pos": pos, "text": text, "size": size, "color": color})
	func _register_tooltip(rect: Rect2, tooltip: String) -> void: regions.append({"rect": rect, "tooltip": tooltip})

static func run(expect: Callable) -> void:
	_test_classes_and_labels(expect)
	_test_burst_total(expect)
	_test_prediction(expect)
	_test_geometry_and_paint(expect)
	_test_collision_consumers(expect)
	_test_threat_marker_hud_avoidance(expect)
	preload("res://tests/suites/board_status_icon_fit_suite.gd").run(expect)

static func _test_classes_and_labels(expect: Callable) -> void:
	var board := Board.new()
	board.presentation = {"umbra_truesight_activations": -1}
	var unit: Dictionary = {"role": "player", "type": "glacial_mirror", "freeze": 1, "petrify": 1, "shock": 1, "immobilize": true,
		"bleed": 2, "expose": 3, "frost_armor": 4, "keyword_badges": [{"icon": "retaliate", "count": 5}, {"icon": "quicken", "count": 6}, {"icon": "next_attack", "count": 7}, {"icon": "anchored", "count": 0}]}
	var badges: Array[Dictionary] = board._unit_status_presentation_badges(unit)
	var icons: Array[String]
	for badge: Dictionary in badges: icons.append(str(badge["icon"]))
	expect.call(icons == _strings(["freeze", "petrify", "shock", "immobilize", "bleed", "expose", "truesight", "frost_armor", "retaliate", "quicken", "next_attack", "anchored", "reflect"]), "Classes are stable-partitioned control / vulnerable / buff / trait without changing within-class order")
	for badge: Dictionary in badges:
		var kind: String = str(badge["status_class"])
		expect.call(badge["presentation_border"] == EXPECTED_CLASS_BORDERS[kind], "Class border uses the approved palette token: " + str(badge["icon"]))
		if EXPECTED_WORDS.has(badge["icon"]):
			expect.call(badge["label"] == EXPECTED_WORDS[badge["icon"]] and badge["label_font_size"] == 14, "Control status has its exact word at 14 px")
	expect.call(badges[4]["label"] == "2" and badges[5]["label"] == "3" and badges[4]["label_font_size"] == 15, "Bleed and Expose show counts at 15 px")
	expect.call(badges[6]["label"] == "∞" and badges[6]["label_font_size"] == 15, "Permanent Truesight preserves infinity")
	expect.call(badges[7]["label"] == "4" and badges[8]["label"] == "5" and badges[9]["label"] == "6" and badges[10]["label"] == "7", "Crystal Mantle and keyword buffs preserve counts")
	expect.call(badges[11]["label"] == "" and badges[12]["label"] == "", "Uncounted buffs and traits are icon only")
	var chilled: Array[Dictionary] = board._unit_status_presentation_badges({"chilled": true})
	expect.call(chilled[0]["label"] == "Chilled" and chilled[0]["status_class"] == "vulnerable", "Chilled is a vulnerable word pill")
	var trait_icons: Dictionary = {"gale_herald": "wind", "gust_shrike": "flying", "storm_capacitor": "charge", "burrow_grub": "burrow", "ember_tick": "burst"}
	for type: String in trait_icons:
		var traits: Array[Dictionary] = board._unit_status_presentation_badges({"type": type, "burrowed": true, "hp": 10, "charge": 2})
		expect.call(traits.any(func(badge: Dictionary) -> bool: return badge["icon"] == trait_icons[type]), "Trait fixture exposes its specific mechanic badge: " + type)
		for badge: Dictionary in traits: expect.call(badge["status_class"] == "trait", "Enemy mechanic is a trait, including wind Anchored: " + str(badge["icon"]))
	var empty_charge: Array[Dictionary] = board._unit_status_presentation_badges({"type": "storm_capacitor", "charge": 0})
	expect.call(empty_charge[0]["label"] == "0", "Zero Capacitor charge remains an explicit counted trait")
	board.free()

static func _test_prediction(expect: Callable) -> void:
	var board := Board.new()
	for frozen: bool in [false, true]:
		board.presentation = {"surface_status_preview": {"player": {"freeze": 1 if frozen else 0, "chilled": true, "shock": 1}}}
		var badges: Array[Dictionary] = board._unit_status_presentation_badges({"key": "player"})
		expect.call(badges.size() == 2, "Preview retains both its cold and Shock statuses")
		for badge: Dictionary in badges:
			expect.call(badge["label"] == "→ " + str(EXPECTED_WORDS[badge["icon"]]) and is_equal_approx(badge["presentation_alpha"], 0.7), "Prediction prefixes the exact word and fades the whole pill")
			expect.call(str(badge["tooltip"]) == "After this action: " + str(EXPECTED_WORDS[badge["icon"]]), "Prediction keeps its existing tooltip")
	board.free()

static func _test_geometry_and_paint(expect: Callable) -> void:
	var font: Font = Typography.heavy_ui_font()
	var defenses: Array[Dictionary] = Plates.defense_entries({"block": 6, "stoneskin": 4}, TEST_FRAME)
	var block: Rect2 = defenses[0]["rect"]
	var stone: Rect2 = defenses[1]["rect"]
	expect.call(defenses[0]["icon"] == "block" and defenses[1]["icon"] == "stoneskin", "Block precedes Stoneskin")
	expect.call(block.position.x == TEST_FRAME.end.x + 2.0 and block.get_center().y == TEST_FRAME.get_center().y and block.size.y == 24.0, "Defense attaches 2 px after the frame, vertically centered, 24 px tall")
	expect.call(is_equal_approx(block.size.x, 36.0 + font.get_string_size("6", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17).x) and stone.position.x == block.end.x + 3.0, "Defense width uses 20 px icon, exact number width and specified padding/gap")
	var spent: Array[Dictionary] = Plates.defense_entries({"block": 6}, TEST_FRAME, {"block": -2, "block_loss": 8})
	expect.call(spent.size() == 1 and spent[0]["label"] == "-2" and spent[0]["presentation_border"] == Palette.DANGER, "Spent/negative defense retains a plate and danger border")
	var ordered: Array[Dictionary] = Plates.ordered_badges(_holder_badges([{"icon": "bleed", "count": 2}, {"icon": "expose", "count": 1}, {"icon": "chilled"}]))
	var pills: Array[Dictionary] = Plates.status_entries(ordered, TEST_FRAME, true)
	var first: Rect2 = pills[0]["rect"]
	var second: Rect2 = pills[1]["rect"]
	expect.call(first.position == Vector2(TEST_FRAME.position.x - 4.0, TEST_FRAME.end.y + 9.0) and first.size.y == 22.0, "Hero status row uses the mock's fill-left minus 4 and fill-bottom plus 9")
	expect.call(second.position.x == first.end.x + 4.0 and first.size.x == 32.0 + font.get_string_size("2", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15).x, "Pills retain label at x+24 and use the mock's outer padding with four-pixel separation")
	var enemies: Array[Dictionary] = Plates.status_entries(ordered, TEST_FRAME, false)
	expect.call((enemies[0]["rect"] as Rect2).position == Vector2(TEST_FRAME.position.x - 10.0, TEST_FRAME.end.y + 9.0), "Enemy row uses the mock's fill-left minus 10")
	var crowded: Array[Dictionary] = Plates.ordered_badges(_holder_badges([{"icon": "freeze"}, {"icon": "shock"}, {"icon": "immobilize"}, {"icon": "bleed", "count": 2}, {"icon": "expose", "count": 1}, {"icon": "retaliate", "count": 3}]))
	var wrapped: Array[Dictionary] = Plates.status_entries(crowded, TEST_WRAP_FRAME, true)
	expect.call((wrapped[2]["rect"] as Rect2).position == Vector2(TEST_WRAP_FRAME.position.x - 4.0, first.position.y + 22.0 + 3.0), "A row wider than 260 px wraps with the approved three-pixel row gap")
	var enlarged: Array[Dictionary] = Plates.status_entries(ordered, TEST_WRAP_FRAME, true)
	expect.call((enlarged[1]["rect"] as Rect2).position.y == first.position.y, "Wrap is independent of the fill width and defense plates' right end")
	for entry: Dictionary in wrapped:
		expect.call((entry["rect"] as Rect2).end.x <= TEST_WRAP_FRAME.position.x - 4.0 + 260.0, "Each wrapped row stays within the approved 260 px")
	var top_enemy: Array[Dictionary] = Plates.status_entries(Plates.ordered_badges(_holder_badges([{"icon": "immobilize"}, {"icon": "bleed", "count": 3}, {"icon": "expose", "count": 2}])), TEST_WRAP_FRAME, false)
	expect.call((top_enemy[0]["rect"] as Rect2).position.y == (top_enemy[2]["rect"] as Rect2).position.y, "Immobilized, Bleed 3 and Expose 2 stay on one row")
	var recorder := PaintRecorder.new()
	var entries: Array[Dictionary] = defenses.duplicate()
	entries.append_array(pills)
	for entry: Dictionary in entries:
		var texture: Texture2D = Assets.load_texture(Icons.icon_path(str(entry["icon"])))
		Plates.draw_entry(recorder, entry, texture)
		var region: Dictionary = recorder.regions.back()
		expect.call(region["rect"] == entry["rect"] and region["tooltip"] == entry["tooltip"], "Tooltip covers the whole plate/pill using its unchanged rules text")
		var rendered: Dictionary = recorder.textures.back()
		var rect: Rect2 = rendered["rect"]
		var side: float = 20.0 if entry.get("defense_plate", false) else 18.0
		expect.call(maxf(rect.size.x, rect.size.y) <= side and rendered["source"] == Rect2(Assets.texture_used_rect(texture)) and rendered["color"] == Color.WHITE, "Full-color painted icon retains its source crop and never exceeds its nominal scale")
		var style: StyleBoxFlat = recorder.styles.back()["style"]
		expect.call(style.bg_color.is_equal_approx(Color(Palette.INK_1, 0.93)) and style.border_width_left == 2 and style.corner_radius_top_left == (5 if entry.get("defense_plate", false) else 11), "Shared style has approved ink fill, two-pixel border and radius")
	expect.call(recorder.labels[0]["font"] == font and recorder.labels[0]["size"] == 17, "Defense numbers use the heavy UI font at 17 px")

static func _test_collision_consumers(expect: Callable) -> void:
	var board := Board.new()
	board.size = Vector2(1920, 1080)
	var state: Dictionary = ThreatFixture.staged_state(Combat.new())
	state["player"].merge({"block": 6, "stoneskin": 4, "bleed": 2, "expose": 1}, true)
	state["enemies"][0].merge({"block": 8, "stoneskin": 3, "freeze": 1, "bleed": 2, "expose": 2}, true)
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"show_all_enemy_intents": true, "reduced_motion": true})
	var units: Array[Dictionary] = board._hud_layout_units()
	var reserved: Array[Rect2] = board._enemy_hud_reserved_rects(units, font_for_tests())
	for unit: Dictionary in units:
		if unit.get("role") == "npc" or unit.get("boss_bar", false): continue
		var frame: Rect2 = board._unit_health_bar_rect(unit, board._unit_center(unit))
		var geometry: Array[Rect2] = board._health_bar_collision_rects(unit, frame)
		var entries: Array[Dictionary] = board._unit_defense_plate_entries(unit, frame)
		entries.append_array(board._unit_status_pill_entries(unit, frame))
		if unit.get("key") == "player" or unit.get("id") == state["enemies"][0]["id"]:
			expect.call(entries.any(func(entry: Dictionary) -> bool: return entry["icon"] == "expose"), "Expose reaches the live hero/enemy pills from combat state")
		for entry: Dictionary in entries:
			expect.call(geometry.has(entry["rect"]) and reserved.has(entry["rect"]), "Every painted plate/pill enters the shared HUD obstacle geometry")
			var callout: Dictionary = CalloutLayout.place({"text": "Frozen", "actor_key": unit.get("key", "")}, frame, [], geometry, font_for_tests(), 20, 2.0)
			expect.call(not (callout["rect"] as Rect2).intersects(entry["rect"], false), "Callout avoids plate/pill obstacles")
		if unit.get("role") == "enemy":
			var layout: Dictionary = board._enemy_hud_layout(unit, board._unit_center(unit), reserved, font_for_tests())
			for line: Rect2 in layout["line_rects"]:
				for entry: Dictionary in entries: expect.call(not line.intersects(entry["rect"], false), "Expanded intent avoids its own plates and pills")
	var source_before: Dictionary = board._hud_layout_source(units)
	board.presentation["surface_status_preview"] = {"player": {"freeze": 1}}
	expect.call(source_before != board._hud_layout_source(units), "Predicted-status geometry invalidates cached HUD layout")
	board.free()

static func _test_threat_marker_hud_avoidance(expect: Callable) -> void:
	var font: Font = Typography.ui_font()
	var badge: Dictionary = {"key": "enemy_1", "order": "1", "icon": "melee", "number": "5"}
	var default_rect: Rect2 = ThreatBadges.place_chip(TEST_THREAT_ANCHOR, badge, font, [], [])["rect"]
	for defense: bool in [true, false]:
		var board := ThreatGeometryBoard.new()
		board.size = Vector2(1920, 1080)
		var carrier: Dictionary = {"key": "carrier", "role": "player", "type": "player", "block": 6 if defense else 0, "bleed": 0 if defense else 2}
		board.fixture_units = _badges([{"key": "enemy_1", "role": "enemy", "type": "crawler", "proof_center": TEST_THREAT_ANCHOR}, carrier])
		var prototype: Array[Dictionary] = board._unit_defense_plate_entries(carrier, TEST_CARRIER_FRAME) if defense else board._unit_status_pill_entries(carrier, TEST_CARRIER_FRAME)
		var frame := Rect2(TEST_CARRIER_FRAME.position + default_rect.position + TEST_OBSTACLE_INSET - (prototype[0]["rect"] as Rect2).position, TEST_CARRIER_FRAME.size)
		board.fixture_frames = {"enemy_1": TEST_OFFSCREEN_FRAME, "carrier": frame}
		var entries: Array[Dictionary] = board._unit_defense_plate_entries(carrier, frame) if defense else board._unit_status_pill_entries(carrier, frame)
		var obstacle: Rect2 = entries[0]["rect"]
		expect.call(default_rect.intersects(obstacle), "Threat fixture puts a real %s in the chip's original placement" % ("plate" if defense else "pill"))
		var placed: Array[Dictionary] = ThreatBadges.layouts(board, [badge])
		# pt15-01: slide on the preferred side before trying the opposite side.
		# The contract is a clear alternate, including a same-side slide.
		expect.call(placed.size() == 1 and not placed[0]["above_everything"] and placed[0]["rect"] != default_rect, "Threat marker chooses its clear alternate placement around a %s" % ("plate" if defense else "pill"))
		expect.call(not (placed[0]["rect"] as Rect2).intersects(obstacle), "Threat marker avoids the whole %s rect" % ("plate" if defense else "pill"))
		board.free()

static func font_for_tests() -> Font: return Typography.heavy_ui_font()
static func _badges(values: Array) -> Array[Dictionary]:
	var result: Array[Dictionary]
	result.assign(values)
	return result
static func _strings(values: Array) -> Array[String]:
	var result: Array[String]
	result.assign(values)
	return result

# Explicit holder-status source annotations for pure geometry fixtures.
static func _holder_badges(values: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = _badges(values)
	for badge: Dictionary in result:
		var icon: String = str(badge["icon"])
		badge["status_class"] = "control" if icon in ["freeze", "petrify", "shock", "immobilize"] else "vulnerable" if icon in ["chilled", "bleed", "expose"] else "buff"
		badge["status_word"] = str(EXPECTED_WORDS.get(icon, ""))
	return result

static func _test_burst_total(expect: Callable) -> void:
	var board := Board.new()
	var unit: Dictionary = {"key": "tick", "role": "enemy", "type": "ember_tick", "hp": 24, "max_hp": 24, "freeze": 1, "bleed": 2}
	for bonus: int in [0, 2, 0]:
		unit["kindled_bonus"] = bonus
		var source: Array[Dictionary] = board._unit_status_badges(unit)
		var burst: Dictionary = source.filter(func(badge: Dictionary) -> bool: return badge.get("icon") == "burst")[0]
		expect.call(burst["count"] == 4 + bonus and burst["status_class"] == "trait" and not burst.has("label"), "Burst raw source retains its total and source contract")
		var entries: Array[Dictionary] = board._unit_status_pill_entries(unit, TEST_FRAME)
		expect.call(entries.back()["icon"] == "burst" and entries.back()["label"] == str(4 + bonus), "Burst total survives normal/Kindled pill layout and cache changes")
		expect.call(entries[0]["icon"] == "freeze" and entries[1]["icon"] == "bleed" and entries.back()["status_class"] == "trait", "Burst retains trait class and follows control/vulnerable pills")
		var recorder := PaintRecorder.new()
		Plates.draw_entry(recorder, entries.back(), Assets.load_texture(Icons.icon_path("burst")))
		expect.call(recorder.labels[0]["text"] == str(4 + bonus) and str(recorder.regions[0]["tooltip"]).ends_with("%d damage" % (4 + bonus)), "The drawn Burst number and tooltip both show its complete total")
	unit["hp"] = 0
	expect.call(not board._unit_status_badges(unit).any(func(badge: Dictionary) -> bool: return badge.get("icon") == "burst"), "Dead ticks omit the living Burst trait")
	board.free()

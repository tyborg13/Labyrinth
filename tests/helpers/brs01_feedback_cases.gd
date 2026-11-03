extends RefCounted

const Board = preload("res://scripts/combat_board_view.gd")
const Data = preload("res://scripts/game_data.gd")
const Fixture = preload("res://tests/suites/en01_enemies_suite.gd")
const Text = preload("res://scripts/enemy_mechanics/burst_trait_text.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const BurstFx = preload("res://scripts/enemy_mechanics/burst_fx.gd")
const Kindle = preload("res://scripts/enemy_mechanics/kindle_view.gd")
const Inspection = preload("res://scripts/pre_battle_inspection_view.gd")
const Capacitor = preload("res://scripts/enemy_mechanics/capacitor_view.gd")
const SOURCE_TILE := Vector2i(3, 3)
const RAIL_PROOF_RECT := Rect2(1250, 100, 640, 700)
const POP_SAMPLE_SECONDS: float = 0.125

static func run(check: Callable) -> void:
	_approved_values(check)
	_rows_and_roster(check)
	await _wrapping_and_anchor(check)

static func _approved_values(check: Callable) -> void:
	check.call(is_equal_approx(BurstFx.RIBBON_WIDTH_RATIO, 0.07) and is_equal_approx(BurstFx.RIBBON_ALPHA, 0.85), "Director's ribbon width and opacity")
	check.call(is_equal_approx(BurstFx.SMOKE_SIZE_RATIO, 0.22) and is_equal_approx(BurstFx.SMOKE_ALPHA, 0.55) and is_equal_approx(BurstFx.SMOKE_SECONDS, 0.30), "Director's smoke size, opacity and lifetime")
	check.call(is_equal_approx(BurstFx.GLOW_CORNER_ALPHA, 0.12) and is_equal_approx(Kindle.BADGE_POP_PEAK_PROGRESS, 0.5) and is_equal_approx(Board.FORCE_TILE_GLOW_ALPHA, 0.30), "Director's remaining glow/pop values")
	var board := Board.new()
	var sink := board.WarbandView.CommandCapture.new()
	preload("res://scripts/tile_glow.gd").draw_wash(sink, board._tile_polygon(SOURCE_TILE), Color.WHITE, 0.20)
	check.call(sink.triangles.size() == 4 and is_equal_approx(sink.triangles[0][1][1].a, 0.06), "Other wash corners keep 30% of centre alpha")
	board.free()

static func _rows_and_roster(check: Callable) -> void:
	var definition: Dictionary = Data.enemy_def("storm_capacitor")
	var charge: Dictionary = definition["intents"][0]
	var burst: Dictionary = definition["intents"][1]
	var charge_token: Dictionary = Capacitor.rows(charge)[0][0]
	var burst_token: Dictionary = Capacitor.rows(burst)[0][0]
	check.call(charge_token["icon"] == "charge" and charge_token["value"] == "Charge +1" and charge_token["tooltip"] == "At 3 Charge it fires Arc Burst. Shocking it removes 1 Charge.", "Exact director Charge row and tooltip")
	check.call(burst_token["icon"] == "chain" and burst_token["value"] == "Arc 6, range 4, 3 jumps" and burst_token["tooltip"] == "Hits the nearest target within 4 for 6, then jumps to up to 3 more beside each hit, losing 1 per jump.", "Exact director Arc Burst row and tooltip")
	var altered: Dictionary = burst.duplicate(true)
	altered["actions"][0].merge({"damage": 9, "first_range": 7, "jumps": 2, "falloff": 4}, true)
	var live: Dictionary = Capacitor.rows(altered)[0][0]
	check.call(live["value"] == "Arc 9, range 7, 2 jumps" and live["tooltip"] == "Hits the nearest target within 7 for 9, then jumps to up to 2 more beside each hit, losing 4 per jump.", "Every Arc Burst number follows its action data")
	var host := preload("res://scripts/run_scene.gd").new()
	for intent: Dictionary in [charge, burst]:
		var plate: Control = Inspection.build_move(host, intent)
		var token: Dictionary = Capacitor.rows(intent)[0][0]
		check.call(plate.find_child("PreBattleMoveEffect", true, false).text == str(token["value"]) and plate.tooltip_text == str(token["tooltip"]), "Actual pre-battle move uses Capacitor tokens: " + str(intent["name"]))
		check.call(plate.find_child("PreBattleKnownMoveIcon", true, false).get_meta("icon_key") == token["icon"], "Actual move icon identity: " + str(intent["name"]))
		plate.free()
	host.free()
	var audit: Dictionary = preload("res://tools/brs01_roster_rows.gd").audit()
	check.call(int(audit["enemy_count"]) == Data.enemies().size() and int(audit["intent_count"]) > 0 and int(audit["flagged"]) == 0, "Complete production roster has zero moves without a number or tooltip")

static func _wrapping_and_anchor(check: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var board := Board.new()
	board.size = Vector2(1920, 1080)
	board.hide()
	tree.root.add_child(board)
	var state: Dictionary = Fixture.fixture(["ember_tick", "ember_tick", "ember_tick", "crawler", "crawler"])
	state["enemies"][0]["pos"] = SOURCE_TILE
	state["enemies"][1]["pos"] = Vector2i(4, 3)
	state["enemies"][2]["pos"] = Vector2i(5, 3)
	state["enemies"][3]["pos"] = Vector2i(3, 4)
	state["enemies"][4]["pos"] = Vector2i(5, 4)
	state["enemies"][0]["kindled_bonus"] = 2
	state["enemies"][0]["intent"] = Data.enemy_def("ember_tick")["intents"][0].duplicate(true)
	board.set_combat_state(state)
	var unit: Dictionary = board._visible_units().filter(func(value: Dictionary) -> bool: return str(value.get("key", "")) == "enemy_1")[0]
	var rows: Array = board._intent_rows_for_unit(unit, unit["intent"])
	var title_index: int = Text.title_index(rows)
	var joined := PackedStringArray()
	check.call(title_index > 2, "Burst rules wrap over multiple lines")
	for index: int in range(1, title_index):
		var line: String = str(rows[index][0]["value"])
		joined.append(line)
		check.call(board.get_theme_default_font().get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, board.INTENT_POPUP_ROW_FONT_SIZE).x <= Text.WIDTH, "Every drawn Burst line fits 420 px with the board font")
	check.call(" ".join(joined) == "When it dies, it hits every unit next to it for 6 and leaves Fire.", "Wrapping preserves exact live rules")
	var line_rects: Array[Rect2] = board._enemy_intent_contour_line_rects(Rect2(400, 200, 100, 150), rows, "Scuttle", Typography.ui_font(), "right")
	for index: int in range(1, title_index): check.call(is_equal_approx(line_rects[index].position.x, line_rects[0].position.x + board.INTENT_POPUP_ICON_SIZE + 3.0), "Wrapped rules align with Bursts title glyphs")
	board.presentation["burst_intent_obstacle_global_rect"] = RAIL_PROOF_RECT
	var layout: Dictionary = board._enemy_intent_contour_layout(unit, board._unit_center(unit), rows, "Scuttle", [], Typography.ui_font())
	var local_rail: Rect2 = board.get_global_transform_with_canvas().affine_inverse() * RAIL_PROOF_RECT
	for rect: Rect2 in layout["line_rects"]: check.call(not rect.intersects(local_rail), "Expanded Burst display clears turn-order portraits")
	var trait_row: Control = Inspection.build_trait(preload("res://scripts/enemy_mechanics/death_burst_view.gd").trait_token(unit))
	trait_row.size = Vector2(600, 200)
	tree.root.add_child(trait_row)
	await tree.process_frame
	await tree.process_frame
	var rules: Label = trait_row.find_child("EnemyBurstTraitRules", true, false)
	var title: Label = trait_row.find_child("EnemyBurstTraitTitle", true, false)
	check.call(rules.size.x <= Text.WIDTH and rules.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT and is_equal_approx(rules.global_position.x, title.global_position.x), "Actual pre-battle rules wrap at 420 and align with their title")
	trait_row.free()
	state["enemies"][0]["kindled_bonus"] = 0
	state["enemies"][0]["intent"] = Data.enemy_def("ember_tick")["intents"][1].duplicate(true)
	var phase: Dictionary = preload("res://scripts/combat_engine.gd").new().resolve_enemy_turn_with_steps(state, 0)
	for step: Dictionary in phase["steps"]:
		if str(step.get("action_type", "")) != "kindle": continue
		var texts: Array[Dictionary] = Kindle.texts(step)
		check.call(texts[0]["tile"] == step["enemy_after"]["pos"] and texts[0]["anchor_id"] == step["actor_key"] and texts[0]["automatic_anchor"], "Kindle status text uses the resolved source unit anchor")
		var shown: Array[Dictionary] = preload("res://scripts/floating_combat_text.gd").animate_entries(texts, POP_SAMPLE_SECONDS, false)
		board.set_combat_state(phase["state"], [], [], Vector2i(-1, -1), "", "", {}, {}, {"floating_texts": shown})
		var popups: Array[Dictionary] = board._floating_text_screen_layout(Typography.ui_font())
		check.call(popups.size() == 1 and popups[0].has("actor_association"), "Kindle popup keeps the ordinary unit association during screen placement")
		if popups.size() == 1:
			var target: Vector2 = popups[0]["actor_association"]["target"]
			var position: Vector2 = (popups[0]["rendered_rect"] as Rect2).get_center() + popups[0]["layout_offset"]
			for neighbor: Vector2 in popups[0]["actor_association"]["neighbors"]:
				if not neighbor.is_equal_approx(target): check.call(position.distance_to(target) <= position.distance_to(neighbor), "Kindle text remains associated with its own Tick in the crowded native fixture")
		print("BRS01 KINDLE ANCHOR: source %s; resolved %s" % [SOURCE_TILE, texts[0]["tile"]])
	board.free()

extends RefCounted

const Base = preload("res://tests/suites/en04_enemies_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Lob = preload("res://scripts/enemy_mechanics/marked_strike.gd")
const View = preload("res://scripts/enemy_mechanics/lob_view.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const Metrics = preload("res://tools/enc03_measurement_engine.gd")
const Compass = preload("res://scripts/enemy_intent_compass.gd")
const CaptionScrim = preload("res://scripts/action_caption_scrim.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const AIM_TEXT: String = "Marks your tile and the 4 around it. Next turn: 5 in the centre, 3 around it, and they become Fire."
const LAND_TEXT: String = "Marked tiles take the hit: 5 in the centre, 3 around it, and they become Fire."
const AI_SEEDS: int = 32
const SCRIM_TEST_TEXT_SIZE := Vector2(661.0, 30.0)

static func _caption_scrim_geometry(expect: Callable) -> void:
	var scrim := CaptionScrim.new()
	scrim.size = SCRIM_TEST_TEXT_SIZE
	expect.call(scrim.caption_scrim_rect() == Rect2(-48.0, -10.0, 757.0, 50.0), "Scrim extends 48px horizontally and 10px vertically from the caption text rect")
	var samples: Dictionary = {}
	var palette_only: bool = true
	var core_dense: bool = true
	var text_rect: Rect2 = scrim.caption_text_rect()
	for patch: Dictionary in scrim.caption_patches():
		var rect: Rect2 = patch["rect"]
		var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
		for index: int in range(points.size()):
			var colour: Color = patch["colours"][index]
			samples[points[index]] = colour.a
			palette_only = palette_only and Color(colour, 1.0).is_equal_approx(Palette.INK_0)
		if rect.intersects(text_rect):
			for colour: Color in patch["colours"]:
				core_dense = core_dense and is_equal_approx(colour.a, 0.85)
	expect.call(palette_only and scrim.material == null, "Caption uses INK_0 and the existing polygon scrim, with no new material")
	expect.call(core_dense, "The complete caption text rectangle has 0.85 alpha")
	for point: Vector2 in [Vector2(-48.0, -4.0), Vector2(709.0, 34.0), Vector2(0.0, -10.0), Vector2(661.0, 40.0)]:
		expect.call(is_zero_approx(float(samples[point])), "Scrim dissolves completely at outer edge %s" % point)
	for point: Vector2 in [Vector2(-24.0, -4.0), Vector2(685.0, 34.0), Vector2(0.0, -7.0), Vector2(661.0, 37.0)]:
		expect.call(is_equal_approx(float(samples[point]), 0.85 * pow(0.5, 2.2)), "Scrim uses the existing 2.2 falloff at half of the authored fade %s" % point)
	for point: Vector2 in [Vector2(0.0, -4.0), Vector2(661.0, 34.0)]:
		expect.call(is_equal_approx(float(samples[point]), 0.85), "Scrim stays dense through the inner 4px of vertical padding")
	scrim.free()

static func run(expect: Callable) -> void:
	_caption_scrim_geometry(expect)
	var engine := Combat.new()
	var definition: Dictionary = Data.enemy_def("slag_mortar")
	expect.call(int(Base.intent("slag_mortar", "lob_slag")["weight"]) == 4, "Lob weight is exactly 4")
	for distance: int in range(1, 8):
		for seed_value: int in range(AI_SEEDS):
			var state: Dictionary = Base.fixture(engine, "slag_mortar")
			state["enemies"][0]["pos"] = Vector2i(1, 2)
			state["player"]["pos"] = Vector2i(1 + distance, 2)
			state["enemies"][0]["intent"] = {}
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			engine._assign_enemy_intent(state, 0, rng)
			var id: String = str(state["enemies"][0]["intent"].get("id", ""))
			if distance >= 2 and distance <= 6: expect.call(id == "lob_slag", "Distance %d seed %d lobs" % [distance, seed_value])
			if distance == 1: expect.call(id in ["brace", "scatter_shot"], "Adjacent only Scatter or Brace")
			for entry: Dictionary in definition["intents"]:
				if str(entry["id"]) in ["brace", "scatter_shot"]:
					expect.call(Lob.available(engine, state, state["enemies"][0], entry) == (distance == 1), "Adjacent defensive availability")
	var state: Dictionary = Base.fixture(engine, "slag_mortar")
	state["enemies"][0]["intent"] = Base.intent("slag_mortar", "brace")
	var before: Vector2i = state["enemies"][0]["pos"]
	var resolved: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0)
	expect.call(resolved["state"]["enemies"][0]["pos"] == before, "Ordinary Brace never retreats")
	expect.call(Base.intent("slag_mortar", "brace")["actions"] == [{"type": "block", "amount": 6}], "Brace contains only block 6")
	state = Base.fixture(engine, "slag_mortar")
	state["enemies"][0]["intent"] = Base.intent("slag_mortar", "lob_slag")
	var board := Board.new()
	board.combat_state = state
	var original: Dictionary = state.duplicate(true)
	var marks: Dictionary = View.marks(board)
	expect.call(marks.size() == 5 and bool(marks[Base.FIXTURE_HERO]["center"]), "Aiming turn already marks a plus and stronger centre")
	expect.call(not bool(marks[Base.FIXTURE_HERO + Vector2i.UP]["center"]), "Arms retain ordinary danger style")
	expect.call(state == original, "Preview does not change RNG, marks, saves or gameplay state")
	for id: String in ["lob_slag", "slag_lands"]:
		var intent: Dictionary = Base.intent("slag_mortar", id)
		state["enemies"][0]["intent"] = intent
		var action: Dictionary = Lob.presentation_action(engine, state, state["enemies"][0], intent["actions"][0])
		var expected: String = AIM_TEXT if id == "lob_slag" else LAND_TEXT
		board.combat_state = state
		expect.call(board.enemy_intent_tooltip("enemy_1") == expected, "Complete intent tooltip uses the exact approved sentence")
		var tokens: Array = Icons.tokens_for_action(action)
		expect.call(tokens.size() == 1 and tokens[0]["icon"] == "lob" and Icons.token_value_text(tokens[0]) == "5", "Both lob rows have only lob 5; no range or ratio")
		expect.call(Icons.token_tooltip(tokens[0]) == expected and tokens[0]["plain_text"] == expected, "Exact lob token tooltip and plain text")
		expect.call(View.callout(state, "enemy_1", "fallback") == expected, "Exact lob callout")
		expect.call(View.mark_tooltip(state, state["enemies"][0]) == expected, "Exact tile tooltip")
		var badge: Dictionary = Badges.descriptor(action, intent)
		expect.call(badge["icon"] == "lob" and badge["number"] == "5" and badge["secondary_icon"] == "" and badge["secondary_number"] == "", "Both feet badges have only lob 5")
	state["enemies"][0]["intent"] = Base.intent("slag_mortar", "lob_slag")
	state = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	board.combat_state = state
	var landed_marks: Dictionary = View.marks(board)
	expect.call(landed_marks.keys() == marks.keys(), "Aiming plus equals committed landing plus")
	state["player"]["pos"] = Vector2i(2, 6)
	expect.call(View.marks(board).keys() == marks.keys(), "Landing marks stay fixed after hero moves")
	board.free()
	_scaled_presentation(engine, expect)
	_cross_count_copy(engine, expect)
	var counts: Dictionary = Metrics.empty_mix()
	Metrics.count_steps([{"enemy_type": "crawler", "kind": "block", "intent_id": "brace"}, {"enemy_type": "slag_mortar", "en04_mechanic": "lob_mark"}, {"enemy_type": "slag_mortar", "en04_mechanic": "lob_land"}, {"enemy_type": "slag_mortar", "kind": "block", "intent_id": "brace"}, {"enemy_type": "slag_mortar", "kind": "attack", "intent_id": "scatter_shot"}, {"enemy_type": "slag_mortar", "kind": "move", "label": "Retreat"}], counts)
	expect.call(counts == {"lob": 2, "lob_mark": 1, "lob_land": 1, "brace": 1, "scatter": 1, "retreat": 1}, "Measurement counts only Slag Mortar action steps")
	Metrics.count_steps([{"actor_key": "enemy_1", "kind": "move", "label": "Retreat"}, {"actor_key": "enemy_2", "kind": "move", "label": "Retreat"}], counts, PackedStringArray(["enemy_1"]))
	expect.call(counts["retreat"] == 2, "Unannotated captain retreat counts once; other actors do not count")
	var measured_engine := Metrics.new()
	state = Base.fixture(measured_engine, "slag_mortar")
	state["enemies"][0]["intent"] = Base.intent("slag_mortar", "lob_slag")
	measured_engine.preview_revealed_enemy_actions_before_player_turn_with_steps(measured_engine.finish_player_activation(state))
	expect.call(measured_engine.action_mix == Metrics.empty_mix(), "Speculative enemy previews never change action mix")

static func _scaled_presentation(engine: RefCounted, expect: Callable) -> void:
	# Test-only depths exercise two distinct production scaling bands.
	for depth: int in [6, 18]:
		var state: Dictionary = Base.fixture(engine, "slag_mortar")
		state["room_depth"] = depth
		state["enemies"][0]["intent"] = engine._scale_enemy_intent(Base.intent("slag_mortar", "lob_slag"), depth, state, state["enemies"][0])
		var expected_center: int = 6 if depth == 6 else 7
		var expected_arm: int = 4 if depth == 6 else 5
		var board := Board.new()
		for landing: bool in [false, true]:
			if landing:
				state = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
			var enemy: Dictionary = state["enemies"][0]
			var action: Dictionary = Lob.presentation_action(engine, state, enemy, enemy["intent"]["actions"][0])
			var expected: String = ("Marked tiles take the hit: %d in the centre, %d around it, and they become Fire." if landing else "Marks your tile and the 4 around it. Next turn: %d in the centre, %d around it, and they become Fire.") % [expected_center, expected_arm]
			expect.call(int(action["center_damage"]) == expected_center and int(action["arm_damage"]) == expected_arm, "Depth %d resolves scaled landing values" % depth)
			board.combat_state = state
			var rows: Array = View.rows(board, enemy, enemy["intent"])
			expect.call(rows.size() == 1 and rows[0].size() == 1 and Icons.token_value_text(rows[0][0]) == str(expected_center), "Scaled HUD row contains only lob and actual centre damage")
			expect.call(Icons.token_tooltip(rows[0][0]) == expected and rows[0][0]["plain_text"] == expected and board.enemy_intent_tooltip("enemy_1") == expected, "Scaled row and full tooltip use approved Marked copy")
			expect.call(View.callout(state, "enemy_1", "fallback") == expected and View.mark_tooltip(state, enemy) == expected, "Scaled callout and tile tooltip use the same resolved copy")
			var badge: Dictionary = Badges.build(engine, state, state)["badges"][0]
			expect.call(badge["icon"] == "lob" and badge["number"] == str(expected_center) and badge["secondary_icon"] == "", "Live badge uses scaled centre damage on both turns")
			expect.call(Compass.descriptors_for_state(state)["enemy_1"]["value"] == expected_center, "Compass matches scaled preview on both turns")
			var marks: Dictionary = View.marks(board)
			expect.call(int(marks[Base.FIXTURE_HERO]["damage"]) == expected_center and int(marks[Base.FIXTURE_HERO + Vector2i.UP]["damage"]) == expected_arm, "Danger preview agrees with all displayed scaled values")
			if landing:
				var preview: Dictionary = engine.enemy_threat_tiles(state, 0)["projected_attack_action"]
				expect.call(int(preview["center_damage"]) == expected_center and int(preview["arm_damage"]) == expected_arm, "Landing uses the damage preview's resolved action")
				var centre_hit: Dictionary = engine._resolve_enemy_action(state.duplicate(true), 0, preview)
				expect.call(int(state["player"]["hp"]) - int(centre_hit["player"]["hp"]) == expected_center, "Actual centre damage equals displayed centre damage")
				var arm_state: Dictionary = state.duplicate(true)
				arm_state["player"]["pos"] = Base.FIXTURE_HERO + Vector2i.UP
				var arm_hit: Dictionary = engine._resolve_enemy_action(arm_state, 0, preview)
				expect.call(int(state["player"]["hp"]) - int(arm_hit["player"]["hp"]) == expected_arm, "Actual arm damage equals displayed arm damage")
		board.free()

static func _cross_count_copy(engine: RefCounted, expect: Callable) -> void:
	for count: int in [1, 2]:
		var state: Dictionary = Base.fixture(engine, "slag_mortar")
		state["room_depth"] = 6
		if count == 2:
			state["objective"] = preload("res://tests/suites/warband_orders_suite.gd").battle("fire")["objective"].duplicate(true)
			state["objective"]["leader_id"] = state["enemies"][0]["id"]
			state["enemies"][0]["is_leader"] = true
		state["enemies"][0]["intent"] = engine._scale_enemy_intent(Base.intent("slag_mortar", "lob_slag"), 6, state, state["enemies"][0])
		var board := Board.new()
		for landing: bool in [false, true]:
			if landing: state = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
			var enemy: Dictionary = state["enemies"][0]
			var action: Dictionary = Lob.presentation_action(engine, state, enemy, enemy["intent"]["actions"][0])
			var expected: String
			if count == 2:
				expected = "Marked tiles take the hit: 6 in each centre, 4 around them, and they become Fire." if landing else "Marks 2 crosses. Next turn: 6 in each centre, 4 around them, and they become Fire."
			else:
				expected = "Marked tiles take the hit: 6 in the centre, 4 around it, and they become Fire." if landing else "Marks your tile and the 4 around it. Next turn: 6 in the centre, 4 around it, and they become Fire."
			board.combat_state = state
			var expected_intent: String = expected
			if count == 2: expected_intent += "\n" + preload("res://scripts/warband_combat_rules.gd").order_line(state["objective"])
			expect.call(int(action["lob_cross_count"]) == count, "Copy counts the actual aiming or held landing crosses")
			expect.call(View.callout(state, "enemy_1", "fallback") == expected, "Exact one/two-cross callout on both turns")
			expect.call(board.enemy_intent_tooltip("enemy_1") == expected_intent, "Exact one/two-cross full tooltip preserves phase, damage and captain Order")
			expect.call(View.mark_tooltip(state, enemy) == expected, "Exact one/two-cross tile tooltip on both turns")
			var tokens: Array = Icons.tokens_for_action(action)
			expect.call(tokens.size() == 1 and Icons.token_value_text(tokens[0]) == "6" and Icons.token_tooltip(tokens[0]) == expected and tokens[0]["plain_text"] == expected, "Exact phase/barrage tooltip and plain text; badge retains centre damage")
		board.free()

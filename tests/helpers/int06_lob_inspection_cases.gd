extends RefCounted

const Base = preload("res://tests/suites/en04_enemies_suite.gd")
const Orders = preload("res://tests/suites/warband_orders_suite.gd")
const Scene = preload("res://scripts/run_scene.gd")
const Inspection = preload("res://scripts/pre_battle_inspection_view.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Lob = preload("res://scripts/enemy_mechanics/marked_strike.gd")
const TEST_DEPTHS = [6, 18] # Existing enc-03 scaling bands, not tuning.

static func run(expect: Callable) -> void:
	var engine := Combat.new()
	for count: int in [1, 2]:
		for depth: int in TEST_DEPTHS:
			var state: Dictionary = Base.fixture(engine, "slag_mortar")
			state["room_depth"] = depth
			if count == 2:
				state["objective"] = Orders.battle("fire")["objective"].duplicate(true)
				state["objective"]["leader_id"] = state["enemies"][0]["id"]
				state["enemies"][0]["is_leader"] = true
			# The known move must work before it is the declared intent.
			state["enemies"][0]["intent"] = Base.intent("slag_mortar", "brace")
			var aimed: Dictionary = state.duplicate(true)
			aimed["enemies"][0]["intent"] = engine._scale_enemy_intent(Base.intent("slag_mortar", "lob_slag"), depth, state, state["enemies"][0])
			var landed: Dictionary = engine.resolve_enemy_turn_with_steps(aimed, 0)["state"]
			var expected_center: int = 6 if depth == 6 else 7
			var expected_arm: int = expected_center - 2
			_check_panel(engine, state, aimed, landed, expected_center, expected_arm, count, expect)
			# A held landing keeps its resolved values even if the scaling context
			# subsequently changes. It must not be re-scaled from catalog damage.
			landed["room_depth"] = TEST_DEPTHS.back() if depth == TEST_DEPTHS.front() else TEST_DEPTHS.front()
			_check_panel(engine, landed, {}, landed, expected_center, expected_arm, count, expect)
	print("INT06 LOB INSPECTION: one/two crosses; raw known moves; scaled and held values checked")

static func _check_panel(engine: RefCounted, state: Dictionary, aimed: Dictionary, landed: Dictionary, center: int, arm: int, count: int, expect: Callable) -> void:
	var before: Dictionary = state.duplicate(true)
	var host := Scene.new()
	host.set("_pre_battle_preview_run_state", {"combat_state": state})
	var panel: Control = Inspection.build(host, state["enemies"][0])
	var moves: Node = panel.find_child("PreBattleKnownMoves", true, false)
	var known: Array = host.call("_pre_battle_known_enemy_intents", "slag_mortar")
	var board := Board.new()
	for index: int in range(known.size()):
		var id: String = str(known[index]["id"])
		if id not in ["lob_slag", "slag_lands"] or (id == "lob_slag" and aimed.is_empty()): continue
		board.combat_state = landed if id == "slag_lands" else aimed
		var enemy: Dictionary = board.combat_state["enemies"][0]
		var resolved: Dictionary = Lob.presentation_action(engine, board.combat_state, enemy, enemy["intent"]["actions"][0])
		expect.call(int(resolved["center_damage"]) == center and int(resolved["arm_damage"]) == arm, "Inspection fixture uses resolved centre/arm damage")
		expect.call(int(resolved["lob_cross_count"]) == count, "Inspection fixture exercises the requested cross count")
		var effect: Label = moves.get_child(index).find_child("PreBattleMoveEffect", true, false) as Label
		var expected: String = Icons.lob_text(resolved)
		var order: String = preload("res://scripts/warband_combat_rules.gd").order_line(board.combat_state.get("objective", {})) if bool(enemy.get("is_leader", false)) else ""
		var tooltip: String = expected + ("\n" + order if not order.is_empty() else "")
		expect.call(board.enemy_intent_tooltip("enemy_%d" % int(enemy["id"])) == tooltip, "Board tooltip keeps exact Lob copy and the separate captain order")
		expect.call(effect != null and effect.text == expected, "Known %s shows the board's exact %d-cross centre/arm copy" % [id, count])
		var rows: Array = board.call("_intent_rows_for_unit", enemy, enemy["intent"])
		expect.call(Icons.plain_text_for_rows(rows) == expected, "Lob plain text retains the resolved centre, arm and cross count")
	expect.call(state == before, "Known-move formatting preserves the combat state, declared intent and RNG")
	board.free()
	panel.free()
	host.free()

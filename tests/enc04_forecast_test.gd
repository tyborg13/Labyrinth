extends SceneTree

const Combat = preload("res://scripts/combat_engine.gd")
const Fixture = preload("res://tests/suites/warband_orders_suite.gd")
const Base = preload("res://tests/suites/en04_enemies_suite.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const View = preload("res://scripts/enemy_mechanics/lob_view.gd")
const Lob = preload("res://scripts/enemy_mechanics/marked_strike.gd")
const Warband = preload("res://scripts/warband_combat_rules.gd")
const Cases = preload("res://tests/enc04_lob_cases.gd")
const TEST_CAPTAIN := Vector2i(5, 5)
const REVIEW_DELTAS = [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
const MATRIX_VARIANTS = ["open", "blocked", "terrain", "clipped", "immobilized", "ordinary"]
const CLIPPED_CAPTAIN_LOW: int = 3
const CLIPPED_CAPTAIN_HIGH: int = 7
const FORCED_HERO_DISTANCE: int = 2
var checks: int = 0
var cases: int = 0
var failures: Array[String]
var retreat_directions: Dictionary = {}
var cross_counts: Dictionary = {}

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var engine := Combat.new()
	# Geometry cases vary only their deep copies of this production-built battle.
	var fixture_base: Dictionary = Fixture.battle("fire")
	# The reviewer's 8 bearings x both saved barrage sides, then blocked,
	# terrain-blocked, edge-clipped and movement-disabled variants of each.
	for delta: Vector2i in REVIEW_DELTAS:
		for side: int in [-1, 1]:
			for variant: String in MATRIX_VARIANTS:
				var state: Dictionary = fixture_base.duplicate(true)
				state["enemies"].resize(1)
				var enemy: Dictionary = state["enemies"][0]
				enemy["pos"] = TEST_CAPTAIN
				state["player"]["pos"] = TEST_CAPTAIN + delta
				if variant == "clipped":
					enemy["pos"] = Vector2i(CLIPPED_CAPTAIN_LOW if delta.x < 0 else CLIPPED_CAPTAIN_HIGH, CLIPPED_CAPTAIN_LOW if delta.y < 0 else CLIPPED_CAPTAIN_HIGH)
					state["player"]["pos"] = enemy["pos"] + delta
				if variant == "immobilized": enemy["immobilize"] = true
				if variant == "ordinary":
					state["objective"] = {}
					enemy["is_leader"] = false
				var retreat: Array[Vector2i] = Warband.retreat_path(engine, state, enemy)
				var projected: Vector2i = retreat.back() if retreat.size() > 1 and variant != "immobilized" else enemy["pos"]
				var axis: Vector2i = Warband.order_axis(engine, Vector2i(state["player"]["pos"]) - projected)
				if variant in ["blocked", "terrain"]:
					for sign_value: int in [-1, 1]:
						var tile: Vector2i = state["player"]["pos"] + axis * sign_value * 2
						if variant == "blocked": state["grid"][tile.y][tile.x] = "wall"
						else: state["terrain"].append(Base.terrain(tile))
				# Select the real scaled action, preserving the declared side.
				enemy["intent"] = Fixture.authored(state, "lob_slag")
				enemy["intent"]["barrage_side"] = side
				_compare(engine, state, "%s delta=%s side=%d" % [variant, delta, side])
	# Force every retreat direction; the default path tie-break normally uses
	# only a subset of the four directions on an open board.
	for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		for side: int in [-1, 1]:
			var state: Dictionary = fixture_base.duplicate(true)
			state["enemies"].resize(1)
			state["enemies"][0]["pos"] = TEST_CAPTAIN
			state["player"]["pos"] = TEST_CAPTAIN - direction * FORCED_HERO_DISTANCE
			for other: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				if other != direction:
					var tile: Vector2i = TEST_CAPTAIN + other
					state["grid"][tile.y][tile.x] = "wall"
			state["enemies"][0]["intent"] = Fixture.authored(state, "lob_slag")
			state["enemies"][0]["intent"]["barrage_side"] = side
			_compare(engine, state, "forced retreat=%s side=%d" % [direction, side])
	for direction: Vector2i in Cases.ADJACENT_DIRECTIONS:
		for side: int in [-1, 1]:
			for blockers: String in ["", "wall", "terrain"]:
				var approach: Dictionary = Cases.revealed_adjacent(engine, direction, side, blockers, fixture_base)
				_expect(approach["declared"]["enemies"][0]["intent"]["id"] == "lob_slag", "Adjacent case first reveals a legal Lob at distance 2")
				_expect(approach["adjacent"]["player"]["pos"] == Cases.CAPTAIN + direction, "Hero legally walks adjacent after the Lob is revealed")
				_expect(approach["adjacent"]["enemies"][0]["intent"] == approach["declared"]["enemies"][0]["intent"], "Approach preserves the revealed intent and barrage side")
				_compare(engine, approach["adjacent"], "revealed Lob, adjacent=%s side=%d blockers=%s" % [direction, side, blockers])
	_expect(retreat_directions.size() == 4, "Matrix exercises every retreat direction")
	_expect(cross_counts.has(1) and cross_counts.has(2), "Matrix commits both one and two crosses")
	for failure: String in failures: push_error(failure)
	print("ENC04 FORECAST TEST: %s (%d configurations; %d checks; %d failures)" % ["PASS" if failures.is_empty() else "FAIL", cases, checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _compare(engine: RefCounted, state: Dictionary, label: String) -> void:
	cases += 1
	var original: Dictionary = state.duplicate(true)
	var board := Board.new()
	board.combat_state = state
	var marks: Dictionary = View.marks(board)
	var aiming_copy: String = View.callout(state, "enemy_%d" % int(state["enemies"][0]["id"]), "fallback")
	var aiming_tooltip: String = View.mark_tooltip(state, state["enemies"][0])
	var projected: Dictionary = engine.enemy_intent_plan(state, 0, {}, bool(state["enemies"][0].get("immobilize", false)))
	_expect(state == original, label + ": preview preserves state and RNG")
	var resolution: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0)
	var committed: Dictionary = resolution["state"]
	var enemy: Dictionary = committed["enemies"][0]
	var tiles: Array = enemy.get("lob_tiles", [])
	var centers: Array = enemy.get("lob_centers", [enemy.get("lob_center")])
	var count: int = centers.size()
	cross_counts[count] = true
	var moved: Vector2i = enemy["pos"] - state["enemies"][0]["pos"]
	if moved != Vector2i.ZERO: retreat_directions[moved] = true
	_expect(marks.size() == tiles.size() and tiles.all(func(tile: Vector2i) -> bool: return marks.has(tile)), label + ": aiming tiles equal committed tiles")
	_expect(projected["projected_attack"] == tiles, label + ": planner and production agree")
	var stronger: Array
	for tile: Vector2i in marks:
		if bool(marks[tile]["center"]): stronger.append(tile)
	_expect(stronger.size() == count and centers.all(func(tile: Vector2i) -> bool: return stronger.has(tile)), label + ": stronger centres equal committed centres")
	var action: Dictionary = Lob.landing_action(engine, committed, enemy)
	var numbers: Array = [int(action["center_damage"]), int(action["arm_damage"])]
	var aiming_expected: String = "Marks %d crosses. Next turn: %d in each centre, %d around them, and they become Fire." % ([count] + numbers) if count > 1 else "Marks your tile and the 4 around it. Next turn: %d in the centre, %d around it, and they become Fire." % numbers
	var landing_expected: String = ("Marked tiles take the hit: %d in each centre, %d around them, and they become Fire." if count == 2 else "Marked tiles take the hit: %d in the centre, %d around it, and they become Fire.") % numbers
	_expect(aiming_copy == aiming_expected and aiming_tooltip == aiming_expected, label + ": aiming copy counts what commits")
	var order: String = preload("res://scripts/warband_combat_rules.gd").order_line(state.get("objective", {})) if bool(state["enemies"][0].get("is_leader", false)) else ""
	_expect(board.enemy_intent_tooltip("enemy_%d" % int(enemy["id"])) == aiming_expected + ("\n" + order if not order.is_empty() else ""), label + ": full tooltip counts what commits and retains its separate order")
	for step: Dictionary in View.caption_steps(resolution["steps"]):
		if str(step.get("kind", "")) != "intent": continue
		_expect(step.get("turn_caption", "") == aiming_expected, label + ": playback copy counts committed crosses without re-forecasting")
		_expect(step.get("lob_geometry", {}) == {"tiles": tiles, "centers": centers, "cross_count": count}, label + ": intent carries the committed tiles and cross count")
	board.combat_state = committed
	_expect(View.callout(committed, "enemy_%d" % int(enemy["id"]), "fallback") == landing_expected, label + ": landing copy counts held crosses")
	var held: Dictionary = View.marks(board)
	_expect(held.size() == marks.size() and marks.keys().all(func(tile: Vector2i) -> bool: return held.has(tile) and held[tile]["center"] == marks[tile]["center"] and held[tile]["damage"] == marks[tile]["damage"]), label + ": held marks preserve geometry and damage")
	board.free()

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

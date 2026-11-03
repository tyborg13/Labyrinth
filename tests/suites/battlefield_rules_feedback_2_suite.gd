extends RefCounted
## Review round 2: complete activation preparation and ordinary hit compatibility.
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Data = preload("res://scripts/game_data.gd")
# Reviewer-owned fixture values, never gameplay tuning.
const SOURCE_HP: int = 1
const SOURCE_BLOCK: int = 10
const ILLUSION: Dictionary = {"id": 1, "pos": Vector2i(4, 5), "hp": 50, "max_hp": 50}
const ARC_SOURCE: Vector2i = Vector2i(4, 4)
const Wind = preload("res://scripts/enemy_mechanics/wind.gd")
const WindView = preload("res://scripts/enemy_mechanics/wind_view.gd")
const Warbands = preload("res://tests/suites/warband_suite.gd")
const En02 = preload("res://tests/suites/en02_enemies_suite.gd")
const Outcomes = preload("res://scripts/battlefield_rules/outcomes.gd")
# Test-only reach, matching the existing wind-lock movement fixture.
const GUST_PROOF_MOVE_RANGE: int = 20

class ForecastBoard extends Control:
	var combat_state: Dictionary = {}

static func run(engine: RefCounted, battle: Callable, rule: Callable, compare: Callable, expect: Callable) -> void:
	_block_fire(engine, battle, rule, expect)
	_illusion_hits(engine, battle, rule, compare, expect)
	_anchored_upheaval(engine, battle, rule, compare, expect)
	_anchored_shadowstep(engine, battle, rule, compare, expect)
	_initialized_gust(engine, expect)

static func _block_fire(engine: RefCounted, battle: Callable, rule: Callable, expect: Callable) -> void:
	for petrified: bool in [false, true]:
		var state: Dictionary = battle.call(engine)
		state["enemies"][0]["hp"] = SOURCE_HP
		state["enemies"][0]["block"] = SOURCE_BLOCK
		if petrified: state["enemies"][0]["petrify"] = 1
		Surfaces.place(state, state["enemies"][0]["pos"], "fire")
		var instance: Dictionary = rule.call("lightning_storm", {"damage": 0, "chain": 0}, true)
		instance["cadence"] = {"anchor": "on_intent", "intent": "test_wait"}
		Rules.install(engine, state, instance)
		var before: Dictionary = state.duplicate(true)
		var availability: Dictionary = engine.EnemyActivationRules.forecast(engine, state, 0)
		var projected: bool = engine.current_turn_order(state).any(func(entry: Dictionary) -> bool: return str(entry["kind"]) == "beat")
		expect.call(state == before, "Activation-start projection keeps the caller's board unchanged")
		expect.call(not bool(availability["available"]) and not projected, "Block/Fire source projects no intent beat, including Petrify")
		for legacy_phase: bool in [false, true]:
			var after: Dictionary = engine.resolve_enemy_phase_with_steps(state)["state"] if legacy_phase else engine.resolve_enemy_turn_with_steps(state, 0)["state"]
			var fired: bool = after.get("surface_events", []).any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "battlefield_rule_fired")
			var source: Dictionary = after["enemies"][0]
			expect.call(not fired and int(source["hp"]) == (SOURCE_HP if petrified else 0), "Block/Fire shared start matches actual source survival in both turn paths")
			expect.call(int(source["block"]) == (SOURCE_BLOCK - Surfaces.FIRE_START_DAMAGE if petrified else 0), "Activation start clears ordinary Block and preserves conditional Petrify Block")
			if not petrified and not legacy_phase: print("BLOCK FIRE REPRO: availability=%s projected=%s fired=%s source_hp=%d source_block=%d" % [availability, projected, fired, source["hp"], source["block"]])

static func _illusion_hits(engine: RefCounted, battle: Callable, rule: Callable, compare: Callable, expect: Callable) -> void:
	var state: Dictionary = battle.call(engine)
	state["enemies"][0]["type"] = "arc_thrall"
	state["enemies"][0]["pos"] = ARC_SOURCE
	state["illusions"] = [ILLUSION.duplicate(true)]
	var arc: Dictionary = Data.enemy_def("arc_thrall")["intents"][1]["actions"][1]
	var after: Dictionary = engine._resolve_enemy_action(state.duplicate(true), 0, arc)
	expect.call(int(after["illusions"][0]["hp"]) == int(ILLUSION["hp"]) - int(arc["damage"]) and not after["illusions"][0].has("shock"), "Authored Arc Jab retains ordinary illusion damage without a Shock field")
	# An installed rule does not turn an ordinary attack into a rule hit.
	state = battle.call(engine)
	state["illusions"] = [ILLUSION.duplicate(true)]
	Surfaces.place(state, ILLUSION["pos"], "ice")
	state = engine._surface_contact(state, "illusion", int(ILLUSION["id"]), engine.INVALID_TILE, true)
	Rules.install(engine, state, rule.call("frostbite", {"damage": 0}))
	var action: Dictionary = {"type": "ranged", "damage": 0, "element": "ice"}
	after = engine._resolve_board_attack(state.duplicate(true), action, ILLUSION["pos"], "enemy", 1)
	expect.call(after["illusions"] == state["illusions"] and after["surfaces"] == state["surfaces"], "Ordinary zero-damage Ice preserves a Chilled illusion and its Ice even with an active rule")
	for id: String in ["frostbite", "lightning_storm"]:
		state = battle.call(engine)
		state["illusions"] = [ILLUSION.duplicate(true)]
		Surfaces.place(state, ILLUSION["pos"], "ice" if id == "frostbite" else "electrified")
		state = engine._surface_contact(state, "illusion", int(ILLUSION["id"]), engine.INVALID_TILE, true)
		Rules.install(engine, state, rule.call(id, {"damage": 0, "chain": 0}))
		after = compare.call(engine, state, expect)
		expect.call(int(after["illusions"][0].get("freeze" if id == "frostbite" else "shock", 0)) == 1, "Zero-damage battlefield hit retains its illusion status: " + id)
		if id == "frostbite": expect.call(not Surfaces.has_surface(after, ILLUSION["pos"], "ice"), "Zero-damage battlefield Ice hit expends the illusion's Ice")

# el-02 feedback: each Anchored case has an otherwise identical movable control.
static func _anchored_upheaval(engine: RefCounted, battle: Callable, rule: Callable, compare: Callable, expect: Callable) -> void:
	for kind: String in ["player", "enemy"]:
		var state: Dictionary = battle.call(engine)
		Rules.install(engine, state, rule.call("upheaval", {"pattern": "line_between", "length": 3, "health": 3}, true))
		var tile: Vector2i = state["battlefield_rule"]["marks"][0]
		var actor: Dictionary = state["player"] if kind == "player" else state["enemies"][0]
		actor["pos"] = tile
		actor["anchored"] = true
		var after: Dictionary = compare.call(engine, state, expect)
		var held: Dictionary = after["player"] if kind == "player" else after["enemies"][0]
		expect.call(held == actor and engine._terrain_index_at_tile(after, tile) < 0, "Upheaval cannot displace or bury an Anchored occupant: " + kind)
		expect.call(after["terrain"].size() == state["battlefield_rule"]["marks"].size() - 1, "Anchored occupant blocks only its own rising tile: " + kind)
		actor["anchored"] = false
		after = compare.call(engine, state, expect)
		var moved: Dictionary = after["player"] if kind == "player" else after["enemies"][0]
		expect.call(moved["pos"] != tile and engine._terrain_index_at_tile(after, tile) >= 0, "The same Upheaval tile can displace an unanchored occupant: " + kind)

static func _anchored_shadowstep(engine: RefCounted, battle: Callable, rule: Callable, compare: Callable, expect: Callable) -> void:
	var state: Dictionary = battle.call(engine)
	state["umbra"] = {"stage": "heart", "vision_bonus": 0, "stage_reduction": 0}
	state["enemies"][0]["pos"] = Vector2i(5, 1)
	state["enemies"][0]["anchored"] = true
	Rules.install(engine, state, rule.call("shadowstep", {"blink": 3}))
	expect.call(not engine.is_enemy_visible_to_player(state, state["enemies"][0]), "Anchored Shadowstep fixture is hidden in the dark")
	var after: Dictionary = compare.call(engine, state, expect)
	expect.call(after["enemies"] == state["enemies"], "Shadowstep preserves the complete hidden Anchored enemy")
	state["enemies"][0]["anchored"] = false
	after = compare.call(engine, state, expect)
	expect.call(after["enemies"][0]["pos"] != state["enemies"][0]["pos"] and engine.is_enemy_visible_to_player(after, after["enemies"][0]), "The same hidden enemy Blinks into view without Anchored")

# Actual Warband creation installs D0 before the captain's first intent selection.
static func _initialized_gust(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = Warbands.battle("air", 2)
	var initial: Vector2i = state["battlefield_rule"]["locked_direction"]
	expect.call(state["battlefield_rule"]["rule"] == "gust" and state["battlefield_rule"]["beats_fired"] == 0 and state["wind"]["direction"] == initial, "Warband initialize installs the opening Gust before any beat")
	state["enemies"][0]["intent"] = En02.intent("gale_herald", "still_air")
	var moved: bool = false
	for y: int in range(state["grid"].size()):
		for x: int in range(state["grid"][y].size()):
			var tile := Vector2i(x, y)
			if engine.PathUtils.manhattan(tile, state["enemies"][0]["pos"]) <= int(state["objective"]["keep_distance"]["trigger_range"]): continue
			var candidate: Dictionary = engine.apply_player_action(state, {"type": "move", "range": GUST_PROOF_MOVE_RANGE}, tile)
			if candidate["player"]["pos"] == tile and Wind.direction(engine, candidate, candidate["enemies"][0]) != initial:
				state = candidate
				moved = true
				break
		if moved: break
	expect.call(moved, "Real player movement makes the next announcement differ from the initialized Gust")
	var call: Dictionary = engine._surface_prepare_enemy_intent(state, state["enemies"][0], En02.intent("gale_herald", "call_the_wind"))
	var announced: Vector2i = call["actions"][0]["_wind_direction"]
	expect.call(announced != initial, "Production intent preparation announces D1 distinct from opening D0")
	for pending: bool in [true, false]:
		var source: Dictionary = state.duplicate(true)
		source["enemies"][0]["intent"] = call.duplicate(true) if pending else En02.intent("gale_herald", "still_air")
		var expected: Vector2i = announced if pending else initial
		var before: Dictionary = source.duplicate(true)
		var forecast: Dictionary = Rules.forecast(engine, source)
		var value: Dictionary = Wind.active(engine, source)
		var plan: Dictionary = Wind.preview(engine, source, value)
		var board := ForecastBoard.new()
		board.combat_state = source
		var shown: Dictionary = WindView.forecast(board)
		expect.call(value["direction"] == expected and forecast.get("direction", Vector2i.ZERO) == expected, "Shared Gust value and next-beat forecast use the pending lock, otherwise D0")
		expect.call(shown["layers"][0]["wind"]["direction"] == expected, "Wind view reads the shared next-beat direction")
		if pending:
			expect.call(engine.enemy_intent_plan(source, 0)["wind"]["direction"] == expected, "Announced Call's intent plan agrees with the next Gust beat")
		else:
			expect.call(engine.enemy_intent_plan(source, 0).get("wind", {}).is_empty(), "Still Air has no pending Call to replace D0")
		expect.call(source == before and source["battlefield_rule"]["locked_direction"] == initial, "Direction projections preserve the saved opening lock and whole caller state")
		var turn: Dictionary = engine.resolve_enemy_turn_with_steps(source, 0)
		var beats: Array = turn["steps"].filter(func(step: Dictionary) -> bool: return str(step.get("en02_mechanic", "")) == "wind_push")
		expect.call(beats.size() == 1 and beats[0]["action_direction"] == expected, "Actual initialized Stormcaller turn blows in the projected direction")
		if not beats.is_empty():
			var comparable: Dictionary = forecast.duplicate(true)
			comparable.erase("direction")
			expect.call(comparable == Outcomes.project(engine, beats[0]["en02_state_before"], beats[0]["en02_state_after"]), "Shared next-beat forecast equals the real source-turn Gust outcome")
			expect.call(plan["state"]["player"] == beats[0]["en02_state_after"]["player"], "Shared Gust movement plan equals real player displacement and damage")
		print("INITIALIZED GUST REPRO: pending_call=%s D0=%s D1=%s shared=%s view=%s resolved=%s" % [pending, initial, announced, forecast.get("direction"), shown["layers"][0]["wind"]["direction"], beats[0]["action_direction"] if not beats.is_empty() else Vector2i.ZERO])
		board.free()

	for status: String in ["freeze", "shock"]:
		var source: Dictionary = state.duplicate(true)
		source["enemies"][0]["intent"] = call.duplicate(true)
		source["enemies"][0][status] = 1
		var before: Dictionary = source.duplicate(true)
		expect.call(Wind.active(engine, source)["direction"] == initial and Rules.forecast(engine, source)["direction"] == initial, "A skipped Call keeps D0 in shared projections: " + status)
		expect.call(source == before, "Skipped-Call projection leaves status consumption to resolution: " + status)
		var turn: Dictionary = engine.resolve_enemy_turn_with_steps(source, 0)
		var beats: Array = turn["steps"].filter(func(step: Dictionary) -> bool: return str(step.get("en02_mechanic", "")) == "wind_push")
		expect.call(beats.size() == 1 and beats[0]["action_direction"] == initial, "A skipped Call really blows the existing D0: " + status)

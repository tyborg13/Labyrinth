extends RefCounted
## Rule strikes select the entire live Electrified field. Card Chain stays.
const Combat = preload("res://scripts/combat_engine.gd")
const Base = preload("res://tests/suites/battlefield_rules_suite.gd")
const Boss = preload("res://tests/suites/dragon_boss_suite.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const PROOF_DAMAGE: int = 5
const ZEKARION_PHASES: int = 6
const FIRST_TILE := Vector2i(3, 5)
const RELAY_TILE := Vector2i(4, 5)
const HERO_TILE := Vector2i(5, 5)

static func run(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = Base.battle(engine)
	Rules.install(engine, state, Base.rule("lightning_storm", {"damage": PROOF_DAMAGE, "chain": 0}, true))
	Surface.place(state, FIRST_TILE, "electrified", {"actor_kind": "enemy"})
	state = engine.finish_player_activation(state)
	for tile: Vector2i in [RELAY_TILE, HERO_TILE]: Surface.place(state, tile, "electrified", {"actor_kind": "enemy"})
	var before: Dictionary = state.duplicate(true)
	var forecast: Dictionary = Rules.forecast(engine, state)
	var after: Dictionary = Rules.fire(engine, state.duplicate(true))
	expect.call(state == before, "Live storm forecast never mutates its source")
	expect.call(after["player"]["hp"] == state["player"]["hp"] - PROOF_DAMAGE, "Storm strikes newly laid Electrified tiles as primaries")
	expect.call(forecast["tiles"]["strike"] == [FIRST_TILE, RELAY_TILE, HERO_TILE] and forecast == Rules.Outcomes.project(engine, state, after), "Live strike red and committed projection agree")
	# Ordinary lightning still conducts through the same field.
	var action: Dictionary = {"type": "lightning_strikes", "element": "lightning", "damage": PROOF_DAMAGE, "chain": 0}
	var ordinary: Dictionary = engine._resolve_board_attack(state.duplicate(true), action, engine.INVALID_TILE, "enemy", 1, {}, engine._vector2i_values([FIRST_TILE]))
	expect.call(state["player"]["hp"] - ordinary["player"]["hp"] == PROOF_DAMAGE, "Ordinary lightning still conducts immediately through new ground")
	ordinary = state.duplicate(true)
	ordinary["player"]["pos"] = Vector2i(5, 6)
	ordinary["enemies"][0]["pos"] = Vector2i(7, 5)
	ordinary["enemies"].append(preload("res://tests/suites/en02_enemies_suite.gd").enemy(2, FIRST_TILE))
	action["chain"] = 2
	var plan: Dictionary = engine._board_attack_plan(ordinary, action, engine._vector2i_values([FIRST_TILE]), "player")
	expect.call(not plan["used_conductors"].is_empty(), "Player Chain keeps the shared relay planner in a fight with live storm tiles")
	_zekarion(expect)

static func _zekarion(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = Boss._boss_combat_state("zekarion")
	var accepted: Callable = _refresh_fresh_candidate.bind(engine)
	var witnessed: bool = false
	for phase: int in range(ZEKARION_PHASES):
		var result: Dictionary = engine.advance_to_next_player_turn_with_steps(engine.finish_player_activation(state, accepted), accepted)
		state = result["state"]
		for step: Dictionary in result["steps"]:
			if not bool(step.get("battlefield_rule_step", false)) or step.get("rule") != "lightning_storm": continue
			var before: Dictionary = step["before"]
			for tile: Vector2i in Surface.tiles(before, "electrified"):
				if not Surface.can_place(before, tile): continue
				var source: Dictionary = Surface.surface_at(before, tile).get("elemental_source", {})
				if Surface.BeatFuel.eligible(before, source): continue
				witnessed = true
				expect.call(step["tiles"].has(tile), "Scheduled Overload strikes newly laid Electrified ground")
			expect.call(before["battlefield_rule"]["dials"]["chain"] == 0, "Scheduled Overload uses Chain 0")
	expect.call(witnessed, "Zekarion's production scheduler reaches Overload with fresh Electrified ground")

static func _refresh_fresh_candidate(state: Dictionary, engine: RefCounted) -> void:
	for tile: Vector2i in engine._all_passable_tiles(state):
		if not Surface.can_place(state, tile): continue
		Surface.remove(state, tile, "electrified", "test_refresh")
		Surface.place(state, tile, "electrified", {"actor_kind": "player", "actor_id": -1})
		return

extends RefCounted

const Base = preload("res://tests/suites/fix_12_suite.gd")
const Mimic = preload("res://tests/suites/fix_12_mimic_suite.gd")
const Rite = preload("res://scripts/rite_rules.gd")
# Historical debug fixture helpers; Tether/Mirror case factories are retired.
const OWNERS: Array = ["arrival", "move_bleed", "attack_bleed", "action", "retaliate", "reflection"]
const OUTCOMES: Array = ["no_death", "owner_lethal", "hero_terminal"]
const HEALTHY_HP: int = 30
const PAYMENT: int = 2
const REWARD_DAMAGE: int = 1
const BURST_DAMAGE: int = 4
const TICK_ID: int = 3
const RETREAT_BREAK_LINE: String = "Test retreat break"
const ACTOR := Vector2i(2, 4)
const HERO := Vector2i(3, 4)
const TICK := Vector2i(2, 5)

static func _tick(state: Dictionary, tile: Vector2i, hp: int) -> void:
	var tick: Dictionary = Base.Fixtures.enemy("ember_tick", TICK_ID, tile)
	tick["hp"] = hp
	state["enemies"].append(tick)

static func _reward(state: Dictionary, source: String = "direct_attack", id: String = "matrix_death_reward") -> void:
	Rite.start(state, id + "_" + source, {"name": "Test death reward", "rite": {"effects": [{"type": "enemy_death_reward", "damage_sources": [source], "rewards": [{"type": "cross_damage", "damage": REWARD_DAMAGE}]}]}})

static func _stationary(_mimic: bool, card: String = "quick_stab") -> Dictionary:
	return Mimic.Fixtures.mirror(card, ACTOR, HERO)

static func generated(_mimic: bool, owner: String, outcome: String) -> Dictionary:
	var lethal: bool = outcome != "no_death"
	var state: Dictionary = _stationary(true, "whirlwind_slash" if owner in ["action", "reflection"] else "quick_stab")
	var tile: Vector2i = TICK
	var source: String = "direct_attack"
	var cause: String = "beam"
	match owner:
		"arrival":
			state = Mimic.state_for("firing", false)
			var trap: Vector2i = Vector2i(4, 4)
			tile = Vector2i(4, 3)
			state["traps"] = [{"id": "matrix_arrival", "pos": trap, "element": "earth", "damage": REWARD_DAMAGE}]
			state["enemies"][0]["hp"] = REWARD_DAMAGE if lethal else HEALTHY_HP
			source = "trap"
			cause = "move"
		"activation_fire":
			state["enemies"][0]["hp"] = REWARD_DAMAGE if lethal else HEALTHY_HP
			preload("res://scripts/board_surface_rules.gd").place(state, ACTOR, "fire", {})
			source = "surface_fire"
			cause = "activation_fire"
		"move_bleed":
			state = Mimic.state_for("firing", false)
			state["player"]["pos"] = Vector2i(3, 3)
			tile = Vector2i(3, 4)
			state["enemies"][0]["hp"] = PAYMENT if lethal else HEALTHY_HP
			state["enemies"][0]["bleed"] = PAYMENT
			cause = "bleed_move"
		"attack_bleed":
			state["enemies"][0]["hp"] = PAYMENT if lethal else HEALTHY_HP
			state["enemies"][0]["bleed"] = PAYMENT
			cause = "bleed_attack"
		"action":
			state["illusions"] = [{"id": 1, "pos": Vector2i(2, 3), "hp": REWARD_DAMAGE if lethal else HEALTHY_HP, "max_hp": HEALTHY_HP}]
			Rite.start(state, "matrix_shatter", {"name": "Test shatter", "rite": {"effects": [{"type": "illusion_death_damage", "damage": REWARD_DAMAGE}]}})
			tile = Vector2i(3, 3)
		"retaliate":
			state["enemies"][0]["hp"] = PAYMENT if lethal else HEALTHY_HP
			state["retaliate"] = {"amount": PAYMENT}
			source = "retaliate"
			cause = "retaliate"
		"reflection":
			var damage: int = Mimic.copied_damage(state)
			state["enemies"][0]["hp"] = damage if lethal else HEALTHY_HP
			state["illusions"] = [{"id": 1, "pos": Vector2i(2, 3), "hp": HEALTHY_HP, "max_hp": HEALTHY_HP, "reflect": true}]
			source = "illusion_retort"
			cause = "illusion_retort"
	_tick(state, tile, REWARD_DAMAGE if lethal else HEALTHY_HP)
	if owner != "action": _reward(state, source)
	if outcome == "hero_terminal":
		var hit: int = 0
		if owner in ["action", "retaliate", "reflection"]: hit = Mimic.copied_damage(state)
		state["player"]["hp"] = BURST_DAMAGE + hit
	for index: int in range(1, state["enemies"].size()): state["enemies"][index]["intent"] = {"id": "matrix_idle", "name": "Test idle", "actions": []}
	var deaths: Dictionary = {}
	if lethal:
		deaths["enemy_3"] = "beam" if owner == "action" else "surface_death"
		if owner != "action": deaths["enemy_1"] = cause
		else: deaths["illusion_1"] = "beam"
		if outcome == "hero_terminal": deaths["player"] = "death_burst"
	return {"name": "matrix_%s_%s_%s" % ["mimic", owner, outcome], "state": state, "matrix": true, "owner": owner, "outcome": outcome, "expected_deaths": deaths, "expected_bursts": [TICK_ID] if lethal else []}

static func cases() -> Array[Dictionary]:
	# Both Tether and Mirror compound fixtures are retired.
	var result: Array[Dictionary]
	return result

static func review_cases() -> Array[Dictionary]:
	# Both Tether and Mirror compound fixtures are retired.
	var result: Array[Dictionary]
	return result

static func _review_tick_id(case: Dictionary) -> void:
	case["state"]["enemies"][-1]["id"] = 2
	case["expected_deaths"]["enemy_2"] = case["expected_deaths"]["enemy_3"]
	case["expected_deaths"].erase("enemy_3")
	case["expected_bursts"] = [2]

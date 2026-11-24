extends RefCounted

const Fight = preload("res://tests/suites/sta01_mechanics_suite.gd")
const Guardians = preload("res://scripts/guardian_combat_rules.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const OUTCROPS := [Vector2i(4, 2), Vector2i(5, 6)]
const OUTCROP_HP: int = 1
const OUTCROP_HIT: int = 1
const OUTCROP_ATTACK_RANGE: int = 6
const CRAG_HERO := Vector2i(4, 3)
const SHRIKE_WALL := Vector2i(4, 4)

static func crag(engine: RefCounted) -> Dictionary:
	var state: Dictionary = Fight.state("craghide", "groundsplit")
	state["player"]["pos"] = CRAG_HERO
	state["terrain"] = []
	for index: int in OUTCROPS.size():
		state["terrain"].append({"id": index + 1, "pos": OUTCROPS[index], "hp": OUTCROP_HP,
			"max_hp": OUTCROP_HP, "kind": "crag_outcrop", "owner_id": 1})
	state["enemies"][0]["intent"] = Guardians.commit(engine, state, 0, Fight.enemy("craghide", 1, state["enemies"][0]["pos"], "groundsplit")["intent"])
	return state

static func destroy_outcrop(engine: RefCounted, state: Dictionary) -> Dictionary:
	return engine.apply_player_action(state, {"type": "ranged", "damage": OUTCROP_HIT, "range": OUTCROP_ATTACK_RANGE}, OUTCROPS[0])

static func mirror_chip(action: Dictionary) -> Dictionary:
	for token: Dictionary in Icons.tokens_for_action(action, {"actor_kind": "enemy"}):
		if token.get("kind") == "aoe_pattern": return token
	return {}

static func same_tiles(left: Array, right: Array) -> bool:
	return left.size() == right.size() and left.all(func(tile: Vector2i) -> bool: return right.has(tile))

static func impact(engine: RefCounted, state: Dictionary, action_type: String) -> Array:
	var resolved: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0)
	for step: Dictionary in resolved["steps"]:
		if step.get("action_type") == action_type and not bool(step.get("cancelled", false)):
			return step.get("tiles", [])
	return []

extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")

static func run(expect: Callable) -> void:
	var combat := Combat.new()
	var state: Dictionary = fixture(combat)
	var original: Dictionary = state.duplicate(true)
	var action: Dictionary = {"type": "ranged", "damage": 4, "range": 7, "chain": 2}
	var result: Dictionary = combat.resolve_player_action_for_presentation(state, action, Vector2i(4, 4))
	var hits: Array = result.get("chain_hits", [])
	expect.call(result.get("state") == combat.apply_player_action(state, action, Vector2i(4, 4)), "Chain trace must preserve the exact ordinary action result")
	expect.call(state == original, "Chain presentation must not mutate its input or persist visual metadata")
	expect.call(hits.size() == 3, "Chain trace must include the primary hit and the two reachable neighbors only")
	if hits.size() == 3:
		expect.call(int(hits[0].get("enemy_id")) == 1 and int(hits[1].get("enemy_id")) == 3 and int(hits[2].get("enemy_id")) == 2, "Chain must retain engine tie order, rather than sorting by ID or display position")
		expect.call(hp(hits[0].get("state"), 3) == hp(state, 3) and hp(hits[0].get("state"), 2) == hp(state, 2), "Primary contact must leave future targets' health unchanged")
		expect.call(hp(hits[1].get("state"), 3) == hp(state, 3) - 4 and hp(hits[1].get("state"), 2) == hp(state, 2), "Second contact must change only the reached target")
		expect.call(hits[1].get("from") == Vector2i(4, 4) and hits[1].get("to") == Vector2i(5, 3), "First hop must connect actual enemy positions")
	var lethal: Dictionary = action.duplicate(true)
	lethal["damage"] = 30
	var lethal_result: Dictionary = combat.resolve_player_action_for_presentation(state, lethal, Vector2i(4, 4))
	expect.call((lethal_result.get("chain_hits", []) as Array).size() == 3, "A lethal primary hit must still forward its chain")
	expect.call(lethal_result.get("state") == combat.apply_player_action(state, lethal, Vector2i(4, 4)), "Lethal chain presentation must preserve death rewards and objective outcomes")
	var pushed: Dictionary = action.duplicate(true)
	pushed["push"] = 1
	var pushed_result: Dictionary = combat.resolve_player_action_for_presentation(state, pushed, Vector2i(4, 4))
	var pushed_hits: Array = pushed_result.get("chain_hits", [])
	expect.call(pushed_result.get("state") == combat.apply_player_action(state, pushed, Vector2i(4, 4)), "Chain trace must preserve forced movement and its effect on route selection")
	if pushed_hits.size() > 1:
		expect.call(pushed_hits[1].get("from") == Vector2i(4, 3), "A pushed primary target must launch its next hop from its resolved tile")
	else:
		expect.call(false, "Push fixture must contain a reachable next target")
	var hidden: Dictionary = state.duplicate(true)
	hidden["umbra"]["stage"] = "heart"
	var hidden_result: Dictionary = combat.resolve_player_action_for_presentation(hidden, action, Vector2i(4, 4))
	expect.call((hidden_result.get("chain_hits", []) as Array).size() <= 1, "Chain trace must not expose or strike hidden secondary targets")
	var trapped: Dictionary = trap_fixture(combat)
	var trap_action: Dictionary = razor_action()
	var trap_result: Dictionary = combat.resolve_player_action_for_presentation(trapped, trap_action, Vector2i(4, 4))
	var trap_hits: Array = trap_result.get("chain_hits", [])
	expect.call(trap_result.get("state") == combat.apply_player_action(trapped, trap_action, Vector2i(4, 4)), "Brightglass Lens and Razor Gale must preserve trap, relic and terrain outcomes")
	expect.call(trap_hits.size() == 2, "The real light relic must add a hop to Razor Gale after it pushes into a trap")
	if trap_hits.size() == 2:
		expect.call((trap_hits[0].get("state").get("traps") as Array).is_empty(), "Primary chain snapshot must include its forced trap activation")
		expect.call((trap_hits[0].get("state").get("terrain") as Array).all(func(prop: Dictionary) -> bool: return int(prop.get("hp", 0)) <= 0), "Primary chain snapshot must include trap-destroyed terrain")
		expect.call(trap_hits[1].get("from") == Vector2i(5, 4), "Relic chain must leave from the selected push destination")
	var single: Dictionary = action.duplicate(true)
	single.erase("chain")
	expect.call((combat.resolve_player_action_for_presentation(state, single, Vector2i(4, 4)).get("chain_hits", []) as Array).is_empty(), "Ordinary attacks must not allocate chain snapshots")
	expect.call((combat.resolve_player_action_for_presentation(state, action, Vector2i(1, 1)).get("chain_hits", []) as Array).is_empty(), "Rejected targets must not produce phantom chain effects")

static func fixture(combat: RefCounted) -> Dictionary:
	var grid: Array = []
	for y: int in range(10):
		var row: Array = []
		for x: int in range(11):
			row.append("wall" if x == 0 or y == 0 or x == 10 or y == 9 else "stone")
		grid.append(row)
	var layout: Dictionary = {
		"name": "Chain feedback proof", "type": "combat", "coord": Vector2i(3, 2),
		"element": "lightning", "umbra_stage": "clear", "grid": grid,
		"player_start": Vector2i(2, 4), "terrain": [], "traps": [], "loot": [],
		"enemies": [
			{"id": 1, "type": "crawler", "pos": Vector2i(4, 4), "hp": 14, "max_hp": 14},
			{"id": 3, "type": "harrier", "pos": Vector2i(5, 3), "hp": 10, "max_hp": 10},
			{"id": 2, "type": "acolyte", "pos": Vector2i(6, 4), "hp": 12, "max_hp": 12},
			{"id": 4, "type": "crawler", "pos": Vector2i(8, 7), "hp": 14, "max_hp": 14},
		],
	}
	var state: Dictionary = combat.create_combat(84301, layout, {"hp": 24, "max_hp": 24, "deck_cards": ["chain_bolt"], "hand_size": 1, "relics": []})
	for enemy: Dictionary in state.get("enemies", []):
		enemy["block"] = 0
		enemy["intent"] = {}
	return state

static func hp(state: Dictionary, id: int) -> int:
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("id", -1)) == id:
			return int(enemy.get("hp", 0))
	return -1

static func razor_action() -> Dictionary:
	var action: Dictionary = (preload("res://scripts/game_data.gd").card_def("razor_gale").get("actions", [])[0] as Dictionary).duplicate(true)
	action["_card_element"] = "air"
	action["_card_action_types"] = ["ranged"]
	action["force_direction"] = Vector2i.RIGHT
	return action

static func trap_fixture(combat: RefCounted) -> Dictionary:
	var state: Dictionary = fixture(combat)
	state["relics"] = ["ember_lens"]
	state["enemies"] = (state.get("enemies", []) as Array).slice(0, 2)
	state["traps"] = [{"id": "chain_fire", "element": "fire", "pos": Vector2i(5, 4), "damage": 4, "armed": true}]
	state["terrain"] = [{"id": "chain_crate", "kind": "wooden_crate", "pos": Vector2i(6, 4), "hp": 3, "max_hp": 3}]
	state = combat.apply_player_action(state, {"type": "illuminate", "range": 5, "radius": 1, "duration": 2}, Vector2i(4, 4))
	return state

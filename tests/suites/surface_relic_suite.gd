extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Base = preload("res://tests/suites/board_surface_suite.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const Relics = preload("res://scripts/surface_relic_rules.gd")
const GameData = preload("res://scripts/game_data.gd")

static func run(check: Callable) -> void:
	var engine: Combat = Combat.new()
	var state: Dictionary = fixture(engine, ["coalheart_crucible"])
	state["enemies"].append(Base.enemy(2, Vector2i(6, 3)))
	for x: int in range(4, 7):
		Ground.place(state, Vector2i(x, 3), "fire")
	Ground.place(state, Vector2i(5, 3), "rubble")
	state = engine.apply_player_action(state, {"type": "ranged", "range": 6, "damage": 5, "element": "lightning"}, Vector2i(4, 3))
	check.call(int(state["enemies"][0]["hp"]) == 995 and int(state["enemies"][1]["hp"]) == 995, "Stormcoal Fire connects ordinary Lightning")
	check.call(Ground.tiles(state, "fire").is_empty() and Ground.has_rubble(state, Vector2i(5, 3)), "Conducting consumes Fire itself, preserves Rubble")
	state = fixture(engine, ["updraft_bottle"])
	Ground.place(state, Vector2i(4, 3), "ice")
	Ground.place(state, Vector2i(4, 3), "rubble")
	Ground.place(state, Vector2i(5, 3), "fire")
	state = engine.apply_player_action(state, {"type": "push", "amount": 1, "range": 5, "damage": 0, "force_direction": Vector2i.RIGHT, "_surface_relic_modes": ["transport"]}, Vector2i(4, 3))
	check.call(state["enemies"][0]["pos"] == Vector2i(5, 3) and int(state["enemies"][0]["hp"]) == 998, "Transport first resolves the landing Fire contact")
	check.call(Ground.element_at(state, Vector2i(4, 3)).is_empty() and Ground.element_at(state, Vector2i(5, 3)) == "ice" and Ground.has_rubble(state, Vector2i(4, 3)), "Updraft moves one elemental layer, leaves Rubble")
	check.call(not bool(state["enemies"][0].get("chilled", false)), "Transporting Ice beneath an occupant is placement, not immediate Chill")
	state = fixture(engine, ["briar_winch"])
	Ground.place(state, Vector2i(4, 3), "rubble")
	state = engine.apply_player_action(state, {"type": "pull", "range": 5, "amount": 1, "force_direction": Vector2i.DOWN, "_surface_relic_modes": ["redirect"]}, Vector2i(4, 3))
	check.call(state["enemies"][0]["pos"] == Vector2i(4, 4) and not Ground.has_rubble(state, Vector2i(4, 3)), "Quarry Winch spends Rubble to pull sideways")
	state = fixture(engine, ["thornmail_brooch"])
	state["player"]["pos"] = Vector2i(3, 3)
	state["player"]["stoneskin"] = 4
	state["enemies"].append(Base.enemy(2, Vector2i(4, 4)))
	state = engine.apply_player_action(state, {"type": "melee", "range": 1, "damage": 5, "_surface_relic_modes": ["cross"]}, Vector2i(4, 3))
	check.call(int(state["player"]["stoneskin"]) == 0 and int(state["enemies"][0]["hp"]) == 995 and int(state["enemies"][1]["hp"]) == 995, "Faultline spends four Stoneskin on one cross attack")
	check.call(Ground.tiles(state, "rubble").size() == 5, "Faultline leaves its paid cross as Rubble")
	state = fixture(engine, ["frost_prism"])
	state["enemies"][0]["hp"] = 8
	state["enemies"][0]["freeze"] = 1
	Ground.place(state, Vector2i(4, 3), "fire")
	state = engine.apply_player_action(state, {"type": "ranged", "range": 5, "damage": 4}, Vector2i(4, 3))
	check.call(Ground.tiles(state, "rubble").size() == 5 and Ground.element_at(state, Vector2i(4, 3)) == "fire", "Shatterglass direct Frozen kill leaves cardinal Rubble, keeps elemental ground")
	state = fixture(engine, ["rimecatcher_vial"])
	Ground.place(state, Vector2i(4, 3), "ice")
	state = engine.surface_actor_arrival(state, "enemy", 1, Vector2i(4, 2))
	state = engine.apply_player_action(state, {"type": "ranged", "range": 5, "damage": 2, "element": "ice", "_ice_spill_direction": Vector2i.DOWN}, Vector2i(4, 3))
	check.call(int(state["enemies"][0].get("freeze", 0)) == 1 and Ground.element_at(state, Vector2i(4, 3)).is_empty() and Ground.element_at(state, Vector2i(4, 4)) == "ice", "Rimecatcher spills one consumed Freeze tile outside the body")
	state = fixture(engine, ["worldroot_idol"])
	state["enemies"][0]["pos"] = Vector2i(6, 3)
	for x: int in range(2, 6):
		Ground.place(state, Vector2i(x, 3), "rubble")
	state = engine.apply_player_action(state, {"type": "melee", "range": 1, "damage": 5, "_surface_relic_modes": ["remote"], "_origin_tile": Vector2i(5, 3)}, Vector2i(6, 3))
	check.call(int(state["enemies"][0]["hp"]) == 995 and state["player"]["pos"] == Vector2i(2, 3) and not Ground.has_rubble(state, Vector2i(5, 3)), "Worldroot strikes from and consumes a connected remote origin without moving player")
	state = fixture(engine, ["basalt_calendar"])
	Ground.place(state, Vector2i(4, 3), "rubble")
	state = engine.apply_player_action(state, {"type": "detonate", "damage": 6, "range": 5, "pattern": [[0, 0]], "_surface_relic_modes": ["crush"]}, Vector2i(4, 3))
	check.call(int(state["enemies"][0]["hp"]) == 994 and not Ground.has_rubble(state, Vector2i(4, 3)) and Ground.element_at(state, Vector2i(4, 3)) == "fire", "Basalt Kiln crushes Rubble and paints spent tiles after damage")
	state = fixture(engine, ["thunder_relay"])
	state["enemies"].append(Base.enemy(2, Vector2i(5, 3)))
	state["enemies"].append(Base.enemy(3, Vector2i(6, 3)))
	state = engine.apply_player_action(state, {"type": "ranged", "range": 5, "damage": 2, "chain": 1, "_surface_relic_modes": ["swap"]}, Vector2i(4, 3))
	check.call(state["enemies"][0]["pos"] == Vector2i(6, 3) and state["enemies"][2]["pos"] == Vector2i(4, 3) and state["enemies"][1]["pos"] == Vector2i(5, 3), "Thunder Relay exchanges first and last native Chain targets")
	# A stale/forged optional technique cannot spend free virtual resources.
	state = fixture(engine, [])
	var before: Dictionary = state.duplicate(true)
	state = engine.apply_player_action(state, {"type": "detonate", "range": 5, "damage": 10, "_surface_relic_modes": ["crush"]}, Vector2i(4, 3))
	check.call(state == before, "A relic mode cannot execute without its owning relic")
	_test_faultline_native_primary(engine, check)
	_test_black_sun_event_time_underlay(engine, check)
	_test_updraft_original_ground_survival(engine, check)
	_test_stormcoal_mixed_reuse(engine, check)
	_test_ion_spool_reuse_limit(engine, check)

static func _test_faultline_native_primary(engine: Combat, check: Callable) -> void:
	var state: Dictionary = fixture(engine, ["thornmail_brooch"])
	state["player"]["stoneskin"] = 4
	var action: Dictionary = {"type": "melee", "range": 1, "damage": 5, "_surface_relic_modes": ["cross"]}
	var before: Dictionary = state.duplicate(true)
	var target: Vector2i = Vector2i(3, 3)
	check.call(not engine.valid_targets_for_player_action(state, action).has(target), "Faultline cannot center on empty adjacent floor to reach an enemy two tiles away")
	check.call(engine.apply_player_action(state, action, target) == before, "Invalid Faultline primary changes no resources, ground, or combat state")
	check.call(engine.apply_prevalidated_player_action(state, action, target) == before, "Faultline's prevalidated preview path still rejects an invalid paid primary")
	check.call(engine.surface_preview_for_player_action(state, action, target)["state"] == before, "Faultline invalid target preview matches resolution without payment")
	# Native melee can hit props and any tile of a body with an in-range edge.
	# Expanding the footprint must retain all of those legal primary choices.
	for primary_kind: String in ["trap", "terrain", "large_enemy"]:
		state = fixture(engine, ["thornmail_brooch"])
		state["player"]["stoneskin"] = 4
		target = Vector2i(3, 3)
		if primary_kind == "trap":
			state["traps"] = [{"id": "faultline_trap", "pos": target, "element": "fire", "damage": 0}]
		elif primary_kind == "terrain":
			state["terrain"] = [{"id": "faultline_box", "kind": "wooden_box", "pos": target, "hp": 30, "max_hp": 30}]
		else:
			state["enemies"][0]["pos"] = Vector2i(3, 3)
			state["enemies"][0]["footprint"] = Vector2i(2, 2)
			state["enemies"].append(Base.enemy(2, Vector2i(5, 3)))
			target = Vector2i(4, 3)
		check.call(engine.valid_targets_for_player_action(state, {"type": "melee", "range": 1, "damage": 5}).has(target), "Faultline %s fixture has a legal native primary" % primary_kind)
		check.call(engine.valid_targets_for_player_action(state, action).has(target), "Faultline preserves native %s primary targeting" % primary_kind)
		var preview: Dictionary = engine.surface_preview_for_player_action(state, action, target)["state"]
		state = engine.apply_player_action(state, action, target)
		check.call(preview == state, "Faultline %s preview and committed expansion agree" % primary_kind)
		check.call(int(state["player"]["stoneskin"]) == 0 and int(state["enemies"][-1]["hp"]) == 995, "Faultline %s primary spends four Stoneskin and hits the cross's secondary actor" % primary_kind)
		if primary_kind == "trap":
			check.call((state["traps"] as Array).is_empty(), "Faultline's legal trap primary triggers the trap")
		elif primary_kind == "terrain":
			check.call(int(state["terrain"][0]["hp"]) == 25, "Faultline's legal terrain primary receives its direct hit")

static func _test_black_sun_event_time_underlay(engine: Combat, check: Callable) -> void:
	for surviving_underlay: bool in [false, true]:
		var state: Dictionary = fixture(engine, ["worldroot_idol", "black_sun_dial", "coalheart_crucible"])
		state["enemies"][0]["pos"] = Vector2i(6, 3)
		for x: int in range(2, 5):
			Ground.place(state, Vector2i(x, 3), "rubble")
		for x: int in range(4, 7):
			Ground.place(state, Vector2i(x, 3), "fire")
		if surviving_underlay:
			Ground.place(state, Vector2i(5, 3), "rubble")
		var action: Dictionary = {"type": "ranged", "range": 2, "damage": 5, "element": "lightning", "_surface_relic_modes": ["remote"], "_origin_tile": Vector2i(4, 3)}
		state = engine.apply_player_action(state, action, Vector2i(6, 3))
		check.call(not Ground.has_rubble(state, Vector2i(4, 3)) and Ground.tiles(state, "fire").is_empty(), "Worldroot spends origin Rubble before the remote Lightning consumes conductive Fire")
		var origin_fact_seen: bool = false
		var surviving_fact_seen: bool = false
		for event: Dictionary in state.get("surface_events", []):
			if str(event.get("kind", "")) != "surface_removed" or str(event.get("surface", "")) != "fire":
				continue
			if event.get("tile") == Vector2i(4, 3):
				origin_fact_seen = event.has("rubble_underlay") and not bool(event["rubble_underlay"])
			if event.get("tile") == Vector2i(5, 3):
				surviving_fact_seen = bool(event.get("rubble_underlay", false)) == surviving_underlay
		check.call(origin_fact_seen and surviving_fact_seen, "Surface consumption records the actual underlay after earlier technique payment")
		var reward: int = GameData.fixed_point_amount(6) if surviving_underlay else 0
		check.call(int(state["player"].get("stoneskin", 0)) == reward, "Black Sun only grants Stoneskin when consumed elemental ground still has Rubble")
		check.call(int(state["enemies"][0]["hp"]) == 995 - reward, "Black Sun pulses around the real layered consumption tile, never an already-spent Worldroot origin")

static func _test_updraft_original_ground_survival(engine: Combat, check: Callable) -> void:
	# Exercise the before/after boundary with identical source metadata. A later
	# trap or repeated painter can recreate the same kind; it is still new ground.
	for replace_original: bool in [false, true]:
		var state: Dictionary = fixture(engine, ["updraft_bottle"])
		var source: Dictionary = {"kind": "trap", "trap_id": "repeat_source"}
		Ground.place(state, Vector2i(4, 3), "fire", source)
		var before: Dictionary = state.duplicate(true)
		var action: Dictionary = {"type": "push", "range": 5, "amount": 1, "_surface_relic_modes": ["transport"]}
		Relics.before_action(engine, state, action, Vector2i(4, 3))
		if replace_original:
			Ground.remove(state, Vector2i(4, 3), "fire", "conduction")
		Ground.place(state, Vector2i(4, 3), "fire", source)
		Ground.place(state, Vector2i(4, 3), "rubble")
		state["enemies"][0]["pos"] = Vector2i(5, 3)
		state = Relics.apply_events(engine, before, state, action, Vector2i(4, 3))
		check.call(Ground.element_at(state, Vector2i(4, 3)) == ("fire" if replace_original else "") and Ground.element_at(state, Vector2i(5, 3)) == ("" if replace_original else "fire"), "Updraft transports surviving ground, never removed-and-recreated ground with identical source metadata")
		check.call(Ground.has_rubble(state, Vector2i(4, 3)), "Ground-layer creation does not invalidate or travel with Updraft's original elemental layer")

static func fixture(engine: Combat, relics: Array) -> Dictionary:
	var result: Dictionary = Base.fixture(engine)
	result["relics"] = relics.duplicate()
	Relics.configure(result)
	return result


static func _test_stormcoal_mixed_reuse(engine: Combat, check: Callable) -> void:
	var state: Dictionary = fixture(engine, ["coalheart_crucible"])
	state["enemies"].append(Base.enemy(2, Vector2i(6,3)))
	Ground.place(state, Vector2i(4,3), "electrified")
	Ground.place(state, Vector2i(5,3), "fire")
	Ground.place(state, Vector2i(5,3), "rubble")
	Ground.place(state, Vector2i(6,3), "electrified")
	var attack: Dictionary = {"type":"ranged", "range":5, "damage":5, "element":"lightning"}
	state = engine.apply_player_action(state, attack, Vector2i(4,3))
	check.call(int(state["enemies"][0]["hp"]) == 995 and int(state["enemies"][1]["hp"]) == 995, "A mixed Fire/Electrified component conducts across Stormcoal's bridge")
	check.call(Ground.tiles(state, "electrified").size() == 2 and Ground.tiles(state, "fire").is_empty() and Ground.has_rubble(state, Vector2i(5,3)), "Stormcoal consumes only Fire from a mixed network and preserves Electrified/Rubble")
	state = engine.apply_player_action(state, attack, Vector2i(4,3))
	check.call(int(state["enemies"][0]["hp"]) == 990 and int(state["enemies"][1]["hp"]) == 995, "The next ordinary Lightning attack cannot reuse the consumed Fire bridge")

static func _test_ion_spool_reuse_limit(engine: Combat, check: Callable) -> void:
	var state: Dictionary = fixture(engine, ["ion_spool"])
	state["deck"]["hand"] = ["quick_stab"]
	state["deck"]["draw"] = ["brace", "brace", "brace", "brace"]
	state["enemies"].append(Base.enemy(2, Vector2i(6,3)))
	for x: int in range(4,7): Ground.place(state, Vector2i(x,3), "electrified")
	var attack: Dictionary = {"type":"ranged", "range":5, "damage":5, "element":"lightning"}
	var hand_count: int = (state["deck"]["hand"] as Array).size()
	state = engine.apply_player_action(state, {"type":"ranged", "range":5, "damage":5, "element":"none", "chain":1}, Vector2i(4,3))
	check.call((state["deck"]["hand"] as Array).size() == hand_count, "Neutral Chain's use of relays does not claim Ion Spool's Lightning reward")
	state = engine.apply_player_action(state, attack, Vector2i(4,3))
	check.call((state["deck"]["hand"] as Array).size() == hand_count + 1, "Ion Spool draws once when Lightning uses at least two conductive tiles")
	state = engine.apply_player_action(state, attack, Vector2i(4,3))
	check.call((state["deck"]["hand"] as Array).size() == hand_count + 1 and Ground.tiles(state, "electrified").size() == 3, "Reusing the same network cannot farm Ion Spool twice in a turn")
	state["turn"] = int(state["turn"]) + 1
	state = engine.apply_player_action(state, attack, Vector2i(4,3))
	check.call((state["deck"]["hand"] as Array).size() == hand_count + 2, "Ion Spool can reward the same surviving network on the following turn")
	state = fixture(engine, ["ion_spool"])
	for x: int in range(2,5): Ground.place(state, Vector2i(x,3), "electrified")
	hand_count = (state["deck"]["hand"] as Array).size()
	state = engine._resolve_enemy_action(state, 0, attack)
	check.call((state["deck"]["hand"] as Array).size() == hand_count and not (state.get("surface_relic_flags", {}) as Dictionary).has("ion_spool:surface_conduction_reward"), "Enemy use of the shared network neither draws for the player nor claims their Ion Spool")

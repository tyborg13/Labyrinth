extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Base = preload("res://tests/suites/forced_movement_suite.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Terrain = preload("res://scripts/combat_terrain_rules.gd")
const Store = preload("res://scripts/progression_store.gd")
const Data = preload("res://scripts/game_data.gd")
const Retaliate = preload("res://scripts/retaliate_rules.gd")
const Scene = preload("res://scripts/run_scene.gd")
const RIGHT := Vector2i.RIGHT

static func run(expect: Callable) -> void:
	var combat := Combat.new()
	_test_recoil_mover_and_blocker(combat, expect)
	_test_millstone_sources_and_footprint(combat, expect)
	_test_yoke_chain_and_action_limit(combat, expect)
	_test_yoke_galehook_outside_blocker(combat, expect)
	_test_fetter_both_parties(combat, expect)
	_test_mason_ownership_and_health(combat, expect)
	_test_siege_defenses_dragons_and_resume(combat, expect)
	_test_wheel_layers_and_immunity(combat, expect)
	_test_quarry_all_damage_sources(combat, expect)
	_test_pinion_collision_and_resume(combat, expect)
	_test_combined_order_and_death_credit(combat, expect)

static func fixture(combat: Combat, relics: Array, enemies: Array, terrain: Array = [], player: Vector2i = Vector2i(2, 4)) -> Dictionary:
	var state: Dictionary = Base._state(combat, enemies, terrain, player)
	state["relics"] = relics.duplicate()
	state["turn_flags"] = {}
	state["combat_flags"] = {}
	state["turn_queue"] = []
	for enemy: Dictionary in enemies:
		state["turn_queue"].append({"kind": "enemy", "key": "enemy_%d" % int(enemy["id"]), "enemy_id": enemy["id"], "time": 15, "seq": int(enemy["id"])})
	return state

static func enemy(id: int, tile: Vector2i, hp: int = 60) -> Dictionary:
	return Base._enemy(id, tile, hp)

static func _push(amount: int = 2) -> Dictionary:
	return {"type": "push", "amount": amount, "range": 9, "damage": 0}

static func _unit(state: Dictionary, id: int = 1) -> Dictionary:
	return Base._unit(state, id)

static func _hp(state: Dictionary, id: int = 1) -> int:
	return int(_unit(state, id).get("hp", 0))

static func _forecast(combat: Combat, expect: Callable, state: Dictionary, action: Dictionary, tile: Vector2i, label: String) -> Dictionary:
	var original: Dictionary = state.duplicate(true)
	var preview: Dictionary = combat.apply_prevalidated_player_action(state, action, tile)
	var commit: Dictionary = combat.apply_player_action(state, action, tile)
	expect.call(preview == commit, "%s preview equals commit, including damage, paths, surfaces, statuses and rewards" % label)
	expect.call(state == original and not commit.has("_forced_relic_knocked"), "%s preview preserves input and action-local knock state is discarded" % label)
	return commit

static func _resume(expect: Callable, combat_state: Dictionary) -> Dictionary:
	var previous: String = Store._run_storage_path
	Store.set_run_storage_path("user://relic_u3_resume.save")
	expect.call(Store.save_run_state({"mode": "combat", "combat_state": combat_state}), "U3 combat saves through production run storage")
	var loaded: Dictionary = Store.load_saved_run().get("combat_state", {})
	expect.call(loaded == combat_state, "U3 combat, turn flags, status limits and events survive resume")
	Store.clear_saved_run()
	Store.set_run_storage_path(previous)
	return loaded

static func _delay(state: Dictionary, id: int = 1) -> int:
	return int((state.get("turn_flags", {}) as Dictionary).get("stagger_applied", {}).get(str(id), 0))

static func _test_recoil_mover_and_blocker(combat: Combat, expect: Callable) -> void:
	var state: Dictionary = fixture(combat, ["recoil_plates"], [enemy(1, Vector2i(8, 4))], [], Vector2i(9, 4))
	state["player"]["block"] = 1
	var action: Dictionary = {"type": "melee", "push": 3, "_enemy_id": 1}
	var after: Dictionary = combat._apply_action_keywords_to_player(state.duplicate(true), action, Vector2i(8, 4))
	expect.call(int(after["player"]["hp"]) == 38 and int(after["player"]["block"]) == 3, "Recoil mover takes 1 per lost tile and gains Block after damage")
	var events: Array[Dictionary] = Base._collisions(state, after)
	expect.call(events.size() == 1 and int(events[0]["damage"]) == 3, "Recoil event forecasts the reduced hero collision amount")
	var resumed: Dictionary = _resume(expect, after)
	resumed = combat._apply_action_keywords_to_player(resumed, action, Vector2i(8, 4))
	expect.call(int(resumed["player"]["hp"]) == 38 and int(resumed["player"]["block"]) == 3, "Recoil grants Block once on each new collision after resume")

	var threat: Dictionary = {"projected_attack_action": action, "projected_attack_tiles": [Vector2i(9, 4)], "projected_target_key": "player", "projected_destination": Vector2i(8, 4)}
	var projection: Dictionary = combat.projected_player_force(state, 1, threat)
	expect.call(int((projection.get("collision", {}) as Dictionary).get("damage", 0)) == 3, "Recoil enemy intent cue uses real reduced collision damage")
	state = fixture(combat, ["recoil_plates"], [enemy(1, Vector2i(3, 4))])
	state["damage_context"] = {"actor_kind": "enemy", "player_card": false}
	after = combat._force_move_actor(state.duplicate(true), "enemy", 1, Vector2i.LEFT, 2, {}, true)
	expect.call(_hp(after) == 56 and int(after["player"]["hp"]) == 38 and int(after["player"]["block"]) == 3, "Recoil hero blocker takes reduced damage and receives one reward")
	var redirect: Dictionary = _push()
	redirect["_allow_sideways_force"] = true
	redirect["force_direction"] = Vector2i.LEFT
	after = _forecast(combat, expect, state, redirect, Vector2i(3, 4), "Recoil hero blocker")
	expect.call(int(after["player"]["hp"]) == 38 and int(after["player"]["block"]) == 3, "Recoil hero blocker forecast includes post-collision Block")

	state = fixture(combat, ["recoil_plates"], [enemy(1, Vector2i(4, 4))])
	after = _forecast(combat, expect, state, _push(), Vector2i(4, 4), "Recoil idle")
	expect.call(int(after["player"]["block"]) == 0 and int(after["player"]["hp"]) == 40, "Recoil stays idle when hero is not in a collision")

static func _test_millstone_sources_and_footprint(combat: Combat, expect: Callable) -> void:
	var state: Dictionary = fixture(combat, ["millstone_fob"], [enemy(1, Vector2i(4, 4))], [Base._crate("stop", Vector2i(5, 4))])
	var after: Dictionary = _forecast(combat, expect, state, _push(), Vector2i(4, 4), "Millstone blocked push")
	expect.call(Surface.has_rubble(after, Vector2i(4, 4)), "Millstone fully blocked hero push creates Rubble at the anchor")
	var large: Dictionary = enemy(1, Vector2i(4, 4))
	large["footprint"] = Vector2i(2, 2)
	state = fixture(combat, ["millstone_fob"], [large], [Base._crate("stop", Vector2i(6, 5))])
	after = _forecast(combat, expect, state, _push(), Vector2i(4, 4), "Millstone large footprint")
	expect.call(Surface.tiles(after, "rubble").size() == 4, "Millstone paints every footprint tile once")
	for source: String in ["enemy", "trap"]:
		state = fixture(combat, ["millstone_fob"], [enemy(1, Vector2i(4, 4))], [Base._crate("stop", Vector2i(5, 4))])
		state["damage_context"] = {"actor_kind": "player" if source == "trap" else "enemy", "player_card": true, "source_kind": source}
		after = combat._force_move_actor(state.duplicate(true), "enemy", 1, RIGHT, 2, {}, true)
		expect.call(Surface.tiles(after, "rubble").is_empty(), "Millstone excludes %s-caused collision even inside a card" % source)
	state = fixture(combat, ["millstone_fob"], [enemy(1, Vector2i(6, 4))], [Base._crate("stop", Vector2i(4, 4))])
	after = _forecast(combat, expect, state, {"type": "pull", "amount": 3, "range": 8}, Vector2i(6, 4), "Millstone pull")
	expect.call(Surface.has_rubble(after, Vector2i(5, 4)), "Millstone paints the final anchor of a pull")
	state = fixture(combat, ["millstone_fob"], [enemy(1, Vector2i(4, 4))])
	expect.call(Surface.tiles(combat.apply_player_action(state, _push(), Vector2i(4, 4)), "rubble").is_empty(), "Millstone stays idle on free displacement")

static func _test_yoke_chain_and_action_limit(combat: Combat, expect: Callable) -> void:
	var state: Dictionary = fixture(combat, ["battering_yoke"], [enemy(1, Vector2i(4, 4)), enemy(2, Vector2i(5, 4)), enemy(3, Vector2i(6, 4))])
	state["grid"][4][7] = "wall"
	var after: Dictionary = _forecast(combat, expect, state, _push(), Vector2i(4, 4), "Yoke chain")
	var events: Array[Dictionary] = Base._collisions(state, after)
	expect.call(events.size() == 3 and int(events[0]["id"]) == 1 and int(events[1]["id"]) == 2 and int(events[2]["id"]) == 3, "Yoke records original then knock-on collisions in line order")
	expect.call(_hp(after, 1) == 56 and _hp(after, 2) == 54 and _hp(after, 3) == 56, "Yoke knocked blockers use ordinary 2 per lost tile damage")
	var scene := Scene.new()
	var presentation: Dictionary = {}
	scene._append_forced_displacement_preview(presentation, state, after)
	expect.call(presentation.get("collision_markers", []).size() == 3, "Yoke preview retains one marker for each collision")
	scene.free()
	state["grid"][4][7] = "stone"
	after = _forecast(combat, expect, state, _push(), Vector2i(4, 4), "Yoke free last member")
	expect.call(_unit(after, 3)["pos"] == Vector2i(7, 4) and _unit(after, 2)["pos"] == Vector2i(5, 4), "Yoke last member travels one tile; earlier blocked knocks do not retry")
	# Two targets in one area action both collide with the same 2x2 blocker.
	var large: Dictionary = enemy(3, Vector2i(6, 4))
	large["footprint"] = Vector2i(2, 2)
	state = fixture(combat, ["battering_yoke"], [enemy(1, Vector2i(4, 4)), enemy(2, Vector2i(4, 5)), large], [], Vector2i(2, 4))
	after = _forecast(combat, expect, state, {"type": "aoe", "range": 8, "pattern": [[0, 0], [0, 1]], "push": 3}, Vector2i(4, 4), "Yoke once per action")
	expect.call(_unit(after, 3)["pos"] == Vector2i(7, 4), "Yoke knocks a shared large blocker at most once per area action")
	var resumed: Dictionary = _resume(expect, after)
	resumed["damage_context"] = {"actor_kind": "player", "player_card": true}
	resumed = combat._force_move_actor(resumed, "enemy", 1, RIGHT, 3, {}, true)
	expect.call(_unit(resumed, 3)["pos"] == Vector2i(8, 4), "Yoke next action may knock the same enemy again after resume")
	state = fixture(combat, ["battering_yoke"], [enemy(1, Vector2i(4, 4)), enemy(2, Vector2i(5, 4))])
	state["damage_context"] = {"actor_kind": "enemy", "player_card": false}
	after = combat._force_move_actor(state.duplicate(true), "enemy", 1, RIGHT, 2, {}, true)
	expect.call(_unit(after, 2)["pos"] == Vector2i(5, 4), "Yoke stays idle on enemy-caused force")
	state["damage_context"] = {"actor_kind": "player", "player_card": true, "source_kind": "trap"}
	after = combat._force_move_actor(state.duplicate(true), "enemy", 1, RIGHT, 2, {}, true)
	expect.call(_unit(after, 2)["pos"] == Vector2i(5, 4), "Yoke stays idle on trap force inside a hero action")

static func _test_yoke_galehook_outside_blocker(combat: Combat, expect: Callable) -> void:
	var front: Dictionary = enemy(2, Vector2i(5, 4))
	front["footprint"] = Vector2i(2, 2)
	var state: Dictionary = fixture(combat, ["battering_yoke", "galehook_talon"], [enemy(1, Vector2i(4, 4)), front, enemy(3, Vector2i(7, 5))])
	var after: Dictionary = _forecast(combat, expect, state, _push(), Vector2i(4, 4), "Yoke Galehook outside blocker")
	var events: Array[Dictionary] = Base._collisions(state, after)
	expect.call(events.size() == 1 and int(events[0]["id"]) == 2 and _unit(after, 3)["pos"] == Vector2i(8, 5), "Galehook front collision knocks an enemy outside the group")
	expect.call(_hp(after, 1) == 60, "Galehook rear member does not receive front collision damage")

static func _test_fetter_both_parties(combat: Combat, expect: Callable) -> void:
	var state: Dictionary = fixture(combat, ["fetter_spikes"], [enemy(1, Vector2i(4, 4)), enemy(2, Vector2i(5, 4))])
	state["enemies"][0]["immobilize"] = true
	state["enemies"][1]["immobilize"] = true
	var after: Dictionary = _forecast(combat, expect, state, _push(), Vector2i(4, 4), "Fetter mover and blocker")
	expect.call(_hp(after, 1) == 52 and _hp(after, 2) == 52, "Fetter doubles collision damage independently for immobilized mover and blocker")
	state["enemies"][0]["immobilize"] = false
	state["enemies"][1]["immobilize"] = false
	state["enemies"][0]["freeze"] = 1
	after = _forecast(combat, expect, state, _push(), Vector2i(4, 4), "Fetter idle")
	expect.call(_hp(after, 1) == 56 and _hp(after, 2) == 56, "Fetter requires Immobilize, not Frozen")

static func _test_mason_ownership_and_health(combat: Combat, expect: Callable) -> void:
	var state: Dictionary = fixture(combat, ["masons_plumb"], [enemy(1, Vector2i(4, 4))])
	var after: Dictionary = _forecast(combat, expect, state, {"type": "outcrop", "range": 8, "health": 3}, Vector2i(5, 4), "Mason outcrop health")
	expect.call(int(after["terrain"][0]["hp"]) == 5 and int(after["terrain"][0]["max_hp"]) == 5, "Mason hero outcrop gains two health")
	after = _forecast(combat, expect, after, _push(), Vector2i(4, 4), "Mason collision guard")
	expect.call(_hp(after) == 54 and int(after["terrain"][0]["hp"]) == 5, "Mason adds two enemy collision damage and protects the hero outcrop")
	var resumed: Dictionary = _resume(expect, after)
	after = combat.apply_player_action(resumed, _push(), Vector2i(4, 4))
	expect.call(_hp(after) == 48 and int(after["terrain"][0]["hp"]) == 5, "Mason outcrop ownership and extra health survive resume")
	state = fixture(combat, ["masons_plumb"], [enemy(1, Vector2i(4, 4))])
	Terrain.raise_outcrop(combat, state, Vector2i(5, 4), 10, {"actor_kind": "enemy"})
	after = _forecast(combat, expect, state, _push(), Vector2i(4, 4), "Mason enemy outcrop idle")
	expect.call(int(state["terrain"][0]["max_hp"]) == 10 and int(after["terrain"][0]["hp"]) == 6 and _hp(after) == 56, "Mason excludes enemy-owned outcrops")
	state = fixture(combat, ["masons_plumb"], [enemy(1, Vector2i(4, 4))], [Base._crate("crate", Vector2i(5, 4), 10)])
	after = combat.apply_player_action(state, _push(), Vector2i(4, 4))
	expect.call(_hp(after) == 56 and int(after["terrain"][0]["hp"]) == 6, "Mason excludes ordinary crates")
	var large: Dictionary = enemy(1, Vector2i(4, 4))
	large["footprint"] = Vector2i(2, 2)
	state = fixture(combat, ["masons_plumb"], [large])
	Terrain.raise_outcrop(combat, state, Vector2i(6, 4), 3, {"actor_kind": "player"})
	Terrain.raise_outcrop(combat, state, Vector2i(6, 5), 3, {"actor_kind": "player"})
	after = _forecast(combat, expect, state, _push(), Vector2i(4, 4), "Mason two outcrop blockers")
	expect.call(_hp(after) == 54 and int(after["terrain"][0]["hp"]) == 5 and int(after["terrain"][1]["hp"]) == 5, "Mason grants one damage rider per collision and protects every outcrop blocker")
	for kind: String in ["worldspine", "powder_keg"]:
		state = fixture(combat, ["masons_plumb"], [enemy(1, Vector2i(4, 4))])
		Terrain.raise_outcrop(combat, state, Vector2i(5, 4), 4, {"actor_kind": "player"}, {"kind": kind})
		after = _forecast(combat, expect, state, _push(), Vector2i(4, 4), "Mason %s variant" % kind)
		expect.call(int(after["terrain"][0]["hp"]) == 6 and _hp(after) == 54, "Mason includes player-raised %s as an offensive outcrop variant" % kind)


static func _test_siege_defenses_dragons_and_resume(combat: Combat, expect: Callable) -> void:
	var state: Dictionary = fixture(combat, ["siege_ram_totem", "venom_signet"], [enemy(1, Vector2i(4, 4)), enemy(2, Vector2i(5, 4))])
	state["enemies"][0]["block"] = 20
	state["enemies"][1]["stoneskin"] = 20
	Surface.place(state, Vector2i(4, 4), "rubble")
	var after: Dictionary = _forecast(combat, expect, state, _push(), Vector2i(4, 4), "Siege pre-defense stagger")
	expect.call(_delay(after, 1) == 5 and _delay(after, 2) == 4 and _hp(after, 1) == 60 and _hp(after, 2) == 60, "Siege staggers both enemies by full damage before Block/Stoneskin, including Quarry")
	after = _resume(expect, after)
	after = combat.apply_player_action(after, _push(), Vector2i(4, 4))
	expect.call(_delay(after, 1) == 6 and _delay(after, 2) == 6, "Siege shares the normal six-delay cap across save/resume")
	after["turn_flags"] = {}
	after = combat.apply_player_action(after, _push(), Vector2i(4, 4))
	expect.call(_delay(after, 1) == 5, "Siege limit resets with the next player activation")
	state = fixture(combat, ["siege_ram_totem"], [enemy(1, Vector2i(4, 4))], [Base._crate("stop", Vector2i(5, 4), 40)])
	state["enemies"][0]["type"] = "vaeloryx"
	state["enemies"][0]["footprint"] = Vector2i.ONE
	after = _forecast(combat, expect, state, _push(), Vector2i(4, 4), "Siege dragon halving")
	expect.call(_delay(after) == 2, "Siege uses the normal dragon half-Stagger rule")
	state = fixture(combat, ["siege_ram_totem"], [enemy(1, Vector2i(4, 4)), enemy(2, Vector2i(5, 4))])
	state["damage_context"] = {"actor_kind": "enemy", "player_card": false}
	after = combat._force_move_actor(state.duplicate(true), "enemy", 1, RIGHT, 2, {}, true)
	expect.call(_delay(after, 1) == 4 and _delay(after, 2) == 4, "Siege also applies to enemy-caused collisions")
	after = combat.apply_player_action(state, {"type": "ranged", "damage": 4, "range": 6}, Vector2i(4, 4))
	expect.call(_delay(after) == 0, "Siege stays idle on ordinary attack damage")

static func _test_wheel_layers_and_immunity(combat: Combat, expect: Callable) -> void:
	for element: String in ["fire", "ice", "electrified"]:
		var state: Dictionary = fixture(combat, ["breaking_wheel"], [enemy(1, Vector2i(4, 4)), enemy(2, Vector2i(5, 4))])
		Surface.place(state, Vector2i(4, 4), element)
		Surface.place(state, Vector2i(4, 4), "rubble")
		var after: Dictionary = _forecast(combat, expect, state, _push(), Vector2i(4, 4), "Wheel %s plus Rubble" % element)
		expect.call(Surface.surface_at(after, Vector2i(4, 4)).is_empty() and _delay(after) == 3, "Wheel consumes both layers and Rubble Staggers three with %s" % element)
		if element == "fire":
			expect.call(_hp(after) == 53 and _hp(after, 2) == 56, "Wheel Fire adds three collision damage only to the mover")
		elif element == "ice":
			expect.call(int(_unit(after).get("freeze", 0)) == 1 and _hp(after) == 56, "Wheel Ice applies normal Freeze even on a fully blocked, un-Chilled target")
			var resumed: Dictionary = _resume(expect, after)
			expect.call(int(_unit(resumed).get("freeze", 0)) == 1, "Wheel Freeze survives save/resume")
		else:
			expect.call(int(_unit(after).get("shock", 0)) == 1 and int(_unit(after, 2).get("shock", 0)) == 1, "Wheel Electrified Shocks mover and enemy blocker")
	var state: Dictionary = fixture(combat, ["breaking_wheel"], [enemy(1, Vector2i(4, 4))], [Base._crate("stop", Vector2i(5, 4), 40)])
	state["enemies"][0]["type"] = "frostbound_guardian"
	# Use an actual content immunity rather than an invented actor field.
	for type: String in Data.enemies():
		if (Data.enemy_def(type).get("status_immunities", []) as Array).has("freeze"):
			state["enemies"][0]["type"] = type
			break
	Surface.place(state, Vector2i(4, 4), "ice")
	var after: Dictionary = _forecast(combat, expect, state, _push(), Vector2i(4, 4), "Wheel Freeze immunity")
	expect.call(int(_unit(after).get("freeze", 0)) == 0 and not Surface.has_surface(after, Vector2i(4, 4), "ice"), "Wheel respects Freeze immunity and still consumes the broken Ice")
	state = fixture(combat, ["breaking_wheel"], [enemy(1, Vector2i(4, 4))])
	Surface.place(state, Vector2i(4, 4), "ice")
	after = combat.apply_player_action(state, _push(), Vector2i(4, 4))
	expect.call(Surface.has_surface(after, Vector2i(4, 4), "ice") and int(_unit(after).get("freeze", 0)) == 0, "Wheel stays idle when there is no collision")
	state = fixture(combat, ["breaking_wheel"], [enemy(1, Vector2i(4, 4)), enemy(2, Vector2i(5, 4))])
	Surface.place(state, Vector2i(5, 4), "fire")
	after = combat.apply_player_action(state, _push(), Vector2i(4, 4))
	expect.call(Surface.has_surface(after, Vector2i(5, 4), "fire") and _hp(after) == 56, "Wheel reads the mover's contact tile, not its blocker tile")

static func _test_quarry_all_damage_sources(combat: Combat, expect: Callable) -> void:
	var state: Dictionary = fixture(combat, ["venom_signet"], [enemy(1, Vector2i(4, 4))])
	Surface.place(state, Vector2i(4, 4), "rubble")
	var after: Dictionary = _forecast(combat, expect, state, {"type": "ranged", "damage": 3, "range": 8}, Vector2i(4, 4), "Quarry attack")
	expect.call(_hp(after) == 56, "Quarry replaces the old attack-only +2 with +1")
	state["enemies"][0]["freeze"] = 1
	after = combat.apply_player_action(state, {"type": "ranged", "damage": 3, "range": 8}, Vector2i(4, 4))
	expect.call(_hp(after) == 50, "Quarry is one per damage event after Frozen multiplies the attack")
	state["enemies"][0]["freeze"] = 0
	for source: String in ["force_collision", "surface_fire", "trap", "bleed", "retaliate", "relic"]:
		var trial: Dictionary = state.duplicate(true)
		trial["damage_context"] = {"actor_kind": "enemy", "source_kind": source, "player_card": false}
		trial = combat._surface_damage_actor(trial, "enemy", 1, 3, false)
		expect.call(_hp(trial) == 56, "Quarry central damage path adds one to %s events" % source)
	# Exercise the distinct live sources as well as the common endpoint.
	Surface.place(state, Vector2i(4, 4), "fire")
	after = combat._surface_contact(state.duplicate(true), "enemy", 1, Vector2i(-1, -1), true)
	expect.call(_hp(after) == 60 - Surface.FIRE_START_DAMAGE - 1, "Quarry amplifies actual Fire contact")
	state["enemies"][0]["bleed"] = 2
	after = combat._trigger_enemy_bleed_for_action(state.duplicate(true), 0, {"type": "move_toward"})["state"]
	expect.call(_hp(after) == 57, "Quarry amplifies actual Bleed damage")
	state["retaliate"] = {"amount": 2}
	after = Retaliate.after_enemy_hit(combat, state.duplicate(true), 1, {"type": "melee", "damage": 1})
	expect.call(_hp(after) == 57, "Quarry amplifies actual Retaliate damage")
	state["traps"] = [{"pos": Vector2i(4, 4), "element": "earth", "damage": 2}]
	after = combat._trigger_trap_at_index(state.duplicate(true), 0)
	expect.call(_hp(after) == 60 - combat.trap_damage(state, state["traps"][0]) - 1, "Quarry amplifies actual trap damage")
	var large: Dictionary = enemy(1, Vector2i(4, 4))
	large["footprint"] = Vector2i(2, 2)
	state = fixture(combat, ["venom_signet"], [large])
	Surface.place(state, Vector2i(5, 5), "rubble")
	after = combat._surface_damage_actor(state.duplicate(true), "enemy", 1, 3)
	expect.call(_hp(after) == 56, "Quarry sees Rubble under any footprint tile and adds only once")
	Surface.remove(state, Vector2i(5, 5))
	after = combat._surface_damage_actor(state.duplicate(true), "enemy", 1, 3)
	expect.call(_hp(after) == 57, "Quarry stays idle when Rubble was removed before damage")
	after = combat._surface_damage_actor(state.duplicate(true), "enemy", 1, 0)
	expect.call(_hp(after) == 60, "Quarry does not create a damage event from zero")

static func _test_pinion_collision_and_resume(combat: Combat, expect: Callable) -> void:
	var state: Dictionary = fixture(combat, ["unbound_pinion"], [enemy(1, Vector2i(4, 4))], [Base._crate("stop", Vector2i(5, 4), 40)])
	state["player_movement_remaining"] = 0
	state["deck"]["hand"] = []
	state["deck"]["draw"] = ["quick_stab", "quick_stab", "quick_stab"]
	var after: Dictionary = _forecast(combat, expect, state, _push(), Vector2i(4, 4), "Pinion fully blocked collision")
	expect.call(int(after["player_movement_remaining"]) == combat.player_movement_capacity(after) and after["deck"]["hand"].size() == 1, "Pinion triggers on a card collision with zero moved tiles")
	after = _resume(expect, after)
	after["player_movement_remaining"] = 0
	after = combat.apply_player_action(after, _push(), Vector2i(4, 4))
	expect.call(int(after["player_movement_remaining"]) == 0 and after["deck"]["hand"].size() == 1, "Pinion cannot trigger again in the resumed turn")
	after["turn_flags"] = {}
	after["turn"] = int(after.get("turn", 0)) + 1
	after = combat.apply_player_action(after, _push(), Vector2i(4, 4))
	expect.call(int(after["player_movement_remaining"]) == combat.player_movement_capacity(after) and after["deck"]["hand"].size() == 2, "Pinion collision reward resets next turn")
	state["terrain"] = []
	after = _forecast(combat, expect, state, _push(1), Vector2i(4, 4), "Pinion short free displacement idle")
	expect.call(int(after["player_movement_remaining"]) == 0 and after["deck"]["hand"].is_empty(), "Pinion stays idle after one free tile with no collision")
	state["terrain"] = [Base._crate("stop", Vector2i(6, 4), 40)]
	after = _forecast(combat, expect, state, _push(), Vector2i(4, 4), "Pinion one moved tile plus collision")
	expect.call(_unit(after)["pos"] == Vector2i(5, 4) and int(after["player_movement_remaining"]) == combat.player_movement_capacity(after), "Pinion also triggers when one travelled tile ends in a collision")
	state["terrain"] = []
	after = _forecast(combat, expect, state, _push(), Vector2i(4, 4), "Pinion existing distance trigger")
	expect.call(int(after["player_movement_remaining"]) == combat.player_movement_capacity(after) and after["deck"]["hand"].size() == 1, "Pinion retains its two-tile movement trigger")
	state["terrain"] = [Base._crate("stop", Vector2i(5, 4), 40)]
	state["damage_context"] = {"actor_kind": "enemy", "player_card": false}
	after = combat._force_move_actor(state.duplicate(true), "enemy", 1, RIGHT, 2, {}, true)
	expect.call(int(after["player_movement_remaining"]) == 0 and after["deck"]["hand"].is_empty(), "Pinion stays idle on enemy-caused collisions")

static func _test_combined_order_and_death_credit(combat: Combat, expect: Callable) -> void:
	var state: Dictionary = fixture(combat, ["millstone_fob", "breaking_wheel", "fetter_spikes", "venom_signet", "siege_ram_totem"], [enemy(1, Vector2i(4, 4))], [Base._crate("stop", Vector2i(5, 4), 40)])
	state["enemies"][0]["immobilize"] = true
	Surface.place(state, Vector2i(4, 4), "fire")
	Surface.place(state, Vector2i(4, 4), "rubble")
	var after: Dictionary = _forecast(combat, expect, state, _push(), Vector2i(4, 4), "Combined collision order")
	expect.call(_hp(after) == 45 and _delay(after) == 6, "Fetter doubles base plus Wheel Fire; Quarry adds one; Siege shares the Stagger cap")
	expect.call(Surface.has_rubble(after, Vector2i(4, 4)) and Surface.element_at(after, Vector2i(4, 4)).is_empty(), "Wheel consumes old layers before Millstone replaces Rubble")
	state = fixture(combat, ["millstone_fob", "venom_signet"], [enemy(1, Vector2i(4, 4))], [Base._crate("stop", Vector2i(5, 4), 40)])
	after = combat.apply_player_action(state, _push(), Vector2i(4, 4))
	expect.call(_hp(after) == 56, "New Millstone Rubble does not retroactively amplify its creating collision")
	state = fixture(combat, ["battering_yoke", "millstone_fob"], [enemy(1, Vector2i(4, 4)), enemy(2, Vector2i(5, 4), 5)], [Base._crate("stop", Vector2i(6, 4), 40)])
	after = combat.apply_player_action(state, _push(), Vector2i(4, 4))
	expect.call(_hp(after, 2) == 0 and int(after["death_bonus_card_plays_this_turn"]) == 1, "A Yoke knock-on collision kill retains card credit through the death batch")
	expect.call(Surface.has_rubble(after, Vector2i(5, 4)), "A lethal hero-caused knock collision still paints the stopped footprint")

extends RefCounted
const Combat = preload("res://scripts/combat_engine.gd")
const TestClock = preload("res://tests/helpers/presentation_test_clock.gd")
const Data = preload("res://scripts/game_data.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Rules = preload("res://scripts/surface_variety_relic_rules.gd")
const Tempo = preload("res://scripts/tempo_rules.gd")
const Fixture = preload("res://tests/suites/surface_relic_suite.gd")
const Base = preload("res://tests/suites/board_surface_suite.gd")
const Store = preload("res://scripts/progression_store.gd")

static func run(check: Callable) -> void:
	await TestClock.run_scoped(null, func(scope: TestClock.GlobalScope) -> void:
		await _run_scoped(scope, check)
	)

static func _run_scoped(_globals: TestClock.GlobalScope, check: Callable) -> void:
	preload("res://tests/suites/snare_regression_suite.gd").run_vault(check)
	var engine := Combat.new()
	_test_ember(engine, check)
	_test_overflow(engine, check)
	preload("res://tests/suites/black_sun_dial_suite.gd").run(check)
	_test_knots(engine, check)
	_test_chorus(engine, check)
	_test_bonded(engine, check)
	_test_gale(engine, check)
	_test_beacon(engine, check)
	_test_vault(engine, check)
	_test_sun(engine, check)
	_test_funeral(engine, check)
	_test_funeral_petrify(engine, check)
	_test_funeral_petrify_reapplication(engine, check)
	_test_review_regressions(engine, check)
	_test_navigation_performance(engine, check)
	_test_navigation_preferences(engine, check)

static func _state(engine: Combat, ids: Array) -> Dictionary:
	return Fixture.fixture(engine, ids)

static func _preview(engine: Combat, state: Dictionary, action: Dictionary, target: Vector2i, check: Callable, name: String) -> Dictionary:
	var before: Dictionary = state.duplicate(true)
	var forecast: Dictionary = engine.surface_preview_for_player_action(state, action, target)["state"]
	var after: Dictionary = engine.apply_player_action(state, action, target)
	check.call(forecast == after and state == before, name + ": forecast equals commit; preview leaves source unchanged")
	return after

static func _resume(state: Dictionary, check: Callable) -> Dictionary:
	var old_path: String = Store._run_storage_path
	Store.set_run_storage_path("user://relic_u7_resume.save")
	check.call(Store.save_run_state({"combat_state": state}), "U7 combat save succeeds")
	var saved: Dictionary = Store.load_saved_run()
	Store.clear_saved_run()
	Store.set_run_storage_path(old_path)
	check.call(saved.get("combat_state", {}) == state, "U7 combat state survives the real save/resume serializer")
	return saved.get("combat_state", {}) as Dictionary

static func _test_ember(engine: Combat, check: Callable) -> void:
	for owner: String in ["player", "enemy"]:
		var state: Dictionary = _state(engine, ["ember_siphon"])
		state["enemies"][0]["footprint"] = Vector2i(2, 2)
		state["enemies"][0]["hp"] = 1
		Surface.place(state, Vector2i(5, 4), "fire", {"actor_kind": owner})
		Surface.place(state, Vector2i(3, 3), "ice")
		Surface.place(state, Vector2i(4, 2), "rubble")
		state["enemies"].append(Base.enemy(2, Vector2i(6, 3)))
		state = _preview(engine, state, {"type": "ranged", "range": 6, "damage": 1}, Vector2i(4, 3), check, "Ember Siphon")
		check.call(Surface.tiles(state, "fire").size() == 8 and Surface.element_at(state, Vector2i(3, 3)) == "ice", "Ember Siphon spreads around the full footprint without replacing elemental ground")
		check.call(int(state["enemies"][1]["hp"]) == 1000 and str(Surface.surface_at(state, Vector2i(6, 3))["elemental_source"]["actor_kind"]) == "player", "Ember Siphon owns its spread; placement deals no contact damage")
	var idle: Dictionary = _state(engine, ["ember_siphon"])
	idle["enemies"][0]["hp"] = 1
	idle = engine.apply_player_action(idle, {"type": "ranged", "range": 5, "damage": 1}, Vector2i(4, 3))
	check.call(Surface.tiles(idle, "fire").is_empty(), "Ember Siphon is idle on a death without Fire")
	var passive: Dictionary = _state(engine, ["ember_siphon"])
	passive["enemies"][0]["hp"] = 1
	passive["enemies"][0]["summoned"] = true
	Surface.place(passive, Vector2i(4, 3), "fire", {"actor_kind": "enemy"})
	passive = (engine.call("_resolve_enemy_start_of_turn", passive, 0) as Dictionary)["state"]
	check.call(Surface.tiles(passive, "fire").size() == 5, "Ember Siphon also triggers on passive and summoned enemy deaths")

static func _test_overflow(engine: Combat, check: Callable) -> void:
	var state: Dictionary = _state(engine, ["overflow_censer"])
	Surface.place(state, Vector2i(4, 3), "fire")
	Surface.place(state, Vector2i(4, 2), "rubble")
	Surface.place(state, Vector2i(5, 3), "electrified")
	state = _preview(engine, state, {"type": "surface", "surface": "ice", "range": 5}, Vector2i(4, 3), check, "Overflow Censer")
	check.call(Surface.tiles(state, "ice").size() == 4 and Surface.has_rubble(state, Vector2i(4, 2)), "Overflow spreads onto Rubble, preserves occupied elemental neighbors and does not chain")
	check.call(not bool(state["enemies"][0].get("chilled", false)), "Overflow Ice placement does not Chill occupants")
	for original: String in ["ice", "rubble", ""]:
		state = _state(engine, ["overflow_censer"])
		if not original.is_empty(): Surface.place(state, Vector2i(4, 3), original)
		state = engine.apply_player_action(state, {"type": "surface", "surface": "ice", "range": 5}, Vector2i(4, 3))
		check.call(Surface.tiles(state, "ice").size() == 1, "Overflow ignores repaint, Rubble underlay and bare floor")
	state = _state(engine, ["overflow_censer"])
	Surface.place(state, Vector2i(4, 3), "fire")
	Surface.place(state, Vector2i(4, 3), "ice", {"actor_kind": "enemy"})
	check.call(Surface.tiles(state, "ice").size() == 1, "Overflow ignores enemy surface placement")
	state = _state(engine, ["overflow_censer"])
	Surface.place(state, Vector2i(4, 3), "fire")
	Surface.place(state, Vector2i(4, 3), "ice", {"actor_kind": "relic", "causal_owner": "player"})
	check.call(Surface.tiles(state, "ice").size() == 5, "Overflow includes explicitly hero-owned relic placement")

static func _play_element(engine: Combat, state: Dictionary, element: String) -> Dictionary:
	Rules.finish_card(state, element, Data.relic_effects_for_state(state))
	return state

static func _test_knots(engine: Combat, check: Callable) -> void:
	var state: Dictionary = _state(engine, ["fivefold_knot"])
	var attack: Dictionary = {"type": "ranged", "range": 5, "damage": 1}
	check.call(not bool(engine.call("_resolved_surface_action", state, attack).get("pierce", false)), "Fivefold starts idle with no knots")
	for element: String in ["fire", "ice", "air"]: state = _play_element(engine, state, element)
	state = _resume(state, check)
	state = engine.prepare_next_player_turn(state)
	var resolved: Dictionary = engine.call("_resolved_surface_action", state, attack)
	check.call(bool(resolved.get("pierce", false)) and int(resolved.get("chain", 0)) == 0, "Three knots persist across turns and grant Pierce only")
	state["enemies"][0]["block"] = 10
	state = _preview(engine, state, attack, Vector2i(4, 3), check, "Fivefold Pierce")
	check.call(int(state["enemies"][0]["hp"]) == 999 and int(state["enemies"][0]["block"]) == 10, "Fivefold Pierce bypasses Block")
	state = _play_element(engine, state, "earth")
	state["enemies"].append(Base.enemy(2, Vector2i(5, 3)))
	state = _preview(engine, state, attack, Vector2i(4, 3), check, "Fivefold Chain")
	check.call(int(state["enemies"][1]["hp"]) == 999, "Four knots grant Chain 1")
	state = _play_element(engine, state, "lightning")
	state = _play_element(engine, state, "fire")
	check.call(Rules.knots(state).size() == 5, "Fivefold ties each element once per combat")
	state["deck"]["hand"] = ["brace"]
	var card: Dictionary = Data.card_def_for_progression("brace", state)
	check.call(card["actions"].size() == Data.card_def("brace")["actions"].size() + 1, "All five knots append 3 Block to every card, including none cards")
	for action: Dictionary in card["actions"]: state = engine.apply_player_action(state, action)
	check.call(int(state["player"]["block"]) == int(Data.card_def("brace")["actions"][0]["amount"]) + 3, "Fivefold's fifth threshold grants exactly 3 extra Block")
	state = _resume(state, check)
	check.call(Rules.knots(state).size() == 5, "All five knots survive resume")
	var actual: Dictionary = _state(engine, ["fivefold_knot"])
	for id: String in ["frostbolt", "gust_step", "worldroot_stride"]:
		actual["deck"]["hand"] = [id]
		actual = engine.finish_player_card(actual, 0)
	check.call(Rules.knots(actual).size() == 3, "Actual finish_player_card ties distinct elemental cards")
	var third: Dictionary = _state(engine, ["fivefold_knot"])
	third[Rules.KNOTS] = ["fire", "air"]
	var third_card: Dictionary = Data.card_def_for_progression("frostbolt", third)
	check.call(bool(third_card["actions"][0].get("pierce", false)) and Rules.knots(third).size() == 2, "The third elemental card gains Pierce while previewing without prematurely tying its knot")

static func _test_chorus(engine: Combat, check: Callable) -> void:
	var state: Dictionary = _state(engine, ["chorus_mask"])
	state = _play_element(engine, state, "fire")
	var base: Dictionary = Data.card_def_for_progression("frostbolt", {})
	var card: Dictionary = Data.card_def_for_progression("frostbolt", state)
	check.call(int(card["actions"][0]["damage"]) == int(base["actions"][0]["damage"]) + 2 and int(card["actions"][-1]["amount"]) == 2, "Chorus alternation boosts damage and grants Block")
	state = _preview(engine, state, card["actions"][0], Vector2i(4, 3), check, "Chorus")
	state = _play_element(engine, state, "ice")
	card = Data.card_def_for_progression("frostbolt", state)
	check.call(int(card["actions"][0]["damage"]) == int(base["actions"][0]["damage"]), "Chorus skips the same element")
	state = _play_element(engine, state, "none")
	check.call(Data.card_def_for_progression("frostbolt", state)["actions"] == base["actions"], "A none card breaks Chorus's sequence")
	state = _play_element(engine, state, "fire")
	state = engine.prepare_next_player_turn(state)
	check.call(Data.card_def_for_progression("frostbolt", state)["actions"] == base["actions"], "Chorus does not carry its sequence into the next turn")
	state["deck"]["hand"] = ["gust_step"]
	state = engine.finish_player_card(state, 0)
	check.call(int(Data.card_def_for_progression("frostbolt", state)["actions"][0]["damage"]) == int(base["actions"][0]["damage"]) + 2, "Actual card play sets Chorus's previous element")
	var combined: Dictionary = _state(engine, ["chorus_mask", "fivefold_knot"])
	combined[Rules.KNOTS] = Rules.ELEMENTS.duplicate()
	combined = _play_element(engine, combined, "fire")
	var combo_card: Dictionary = Data.card_def_for_progression("frostbolt", combined)
	for action: Dictionary in combo_card["actions"]:
		if str(action["type"]) == "block": combined = _preview(engine, combined, action, Vector2i.ZERO, check, "Chorus and Fivefold Block")
	check.call(int(combined["player"]["block"]) == 5, "Chorus's 2 Block and Fivefold's 3 Block both apply to a card without native Block")

static func _test_bonded(engine: Combat, check: Callable) -> void:
	var state: Dictionary = {"equipped_equipment": {"weapon": "a", "boots": "b"}}
	var gear: Dictionary = {"a": {"element": "fire"}, "b": {"element": "fire"}}
	var card: Dictionary = {"id": "gear_card", "actions": [{"type": "melee", "damage": 3}, {"type": "block", "amount": 3}]}
	var effects: Array = Data.relic_effects("bonded_set")
	var matched: Dictionary = Rules.modify_card(card, state, effects, gear, {"a": ["gear_card"]})
	check.call(int(matched["actions"][0]["damage"]) == 4 and int(matched["actions"][1]["amount"]) == 4, "Bonded Set uses matching equipment elements and the piece's granted cards")
	gear["b"]["element"] = "ice"
	check.call(Rules.modify_card(card, state, effects, gear, {"a": ["gear_card"]}) == card, "Bonded Set ignores mismatched pieces")
	gear["a"]["element"] = "none"
	gear["b"]["element"] = "none"
	check.call(Rules.modify_card(card, state, effects, gear, {"a": ["gear_card"]}) == card, "Bonded Set never matches none")
	gear["a"]["element"] = "fire"
	gear["b"]["element"] = "fire"
	check.call(Rules.modify_card(card, state, effects, gear, {}) == card, "Bonded Set does not improve cards from outside the equipped piece")
	check.call(Data.card_def_for_progression("quick_stab", {"relics": ["bonded_set"], "equipped_equipment": Data.starting_equipped_equipment()})["actions"] == Data.card_def_for_progression("quick_stab", {})["actions"], "Neutral starting equipment keeps Bonded Set idle")
	# Production gear: a piece's element is the one element all its elemental cards share.
	var fire_set: Dictionary = {"relics": ["bonded_set"], "equipped_equipment": {"armor": "cinderweave_mail", "boots": "emberstriders"}}
	var mail_card: String = str((Data.equipment()["cinderweave_mail"]["cards"] as Array)[0])
	check.call(str(Data.equipment()["cinderweave_mail"].get("element", "")) == "fire" and str(Data.equipment()["emberstriders"].get("element", "")) == "fire", "Elemental equipment carries its element in data")
	check.call(Data.card_def_for_progression(mail_card, fire_set) != Data.card_def_for_progression(mail_card, {}), "Two equipped Fire pieces bond their granted cards")
	# Supply element metadata in memory only; production gear data stays untouched.
	var production_gear: Dictionary = Data.equipment()
	var weapon: Dictionary = production_gear["training_sword"].duplicate(true)
	var shield: Dictionary = production_gear["splintered_shield"].duplicate(true)
	production_gear["training_sword"]["element"] = "fire"
	production_gear["splintered_shield"]["element"] = "fire"
	var live: Dictionary = Data.card_def_for_progression("quick_stab", {"relics": ["bonded_set"], "equipped_equipment": Data.starting_equipped_equipment()})
	check.call(int(live["actions"][0]["damage"]) == int(Data.card_def("quick_stab")["actions"][0]["damage"]) + 1, "Bonded Set is wired through GameData's live card definition hook")
	var combat: Dictionary = _state(engine, ["bonded_set"])
	combat["equipped_equipment"] = Data.starting_equipped_equipment()
	combat["enemies"][0]["pos"] = Vector2i(3, 3)
	for action: Dictionary in live["actions"]:
		combat = _preview(engine, combat, action, Vector2i(3, 3), check, "Bonded Set granted card")
	check.call(int(combat["player"]["block"]) == 1, "Bonded Set grants its Block bonus through normal card resolution")
	production_gear["training_sword"] = weapon
	production_gear["splintered_shield"] = shield

static func _test_gale(engine: Combat, check: Callable) -> void:
	var state: Dictionary = _state(engine, ["gale_tabi"])
	var attack: Dictionary = {"type": "ranged", "range": 8, "damage": 1}
	check.call(engine.final_damage_for_player_action(state, attack) == 1, "Gale is idle before Blink")
	state = engine.apply_player_action(state, {"type": "blink", "range": 5}, Vector2i(6, 4))
	check.call(engine.final_damage_for_player_action(state, attack) == 5 and Tempo.next_attack_buffs(state).size() == 1, "Gale uses Manhattan distance capped at four through the next-attack badge")
	state = _resume(state, check)
	state = _preview(engine, state, attack, Vector2i(4, 3), check, "Gale")
	check.call(int(state["enemies"][0]["hp"]) == 995 and engine.final_damage_for_player_action(state, attack) == 1, "Gale applies to the next attack and is then spent")
	state = engine.apply_player_action(state, {"type": "blink", "range": 5}, Vector2i(6, 3))
	check.call(engine.final_damage_for_player_action(state, attack) == 2, "A short Blink also grants Gale's bonus")
	state = engine.prepare_next_player_turn(state)
	check.call(engine.final_damage_for_player_action(state, attack) == 1, "Gale expires at the next turn")

static func _light(state: Dictionary, tile: Vector2i, owner: String = "player", radius: int = 0) -> void:
	state["umbra"]["light_sources"].append({"pos": tile, "radius": radius, "owner": owner, "remaining_activations": 3})

static func _test_beacon(engine: Combat, check: Callable) -> void:
	var state: Dictionary = _state(engine, ["beaconrunner_spurs"])
	_light(state, Vector2i(3, 3))
	_light(state, Vector2i(3, 4))
	var move: Dictionary = {"type": "move", "range": 2}
	check.call(engine.valid_targets_for_player_action(state, move).has(Vector2i(5, 4)), "Beacon's refunds extend reachable targets")
	state = _preview(engine, state, move, Vector2i(5, 4), check, "Beacon")
	check.call(int(state["turn_flags"].get(Rules.REFUNDS, 0)) == 2, "Beacon refunds at most two actual Light entries")
	state = _resume(state, check)
	check.call(Rules.refund_available(state, Data.relic_effects_for_state(state)) == 0, "Beacon's per-turn cap survives resume")
	var idle: Dictionary = _state(engine, ["beaconrunner_spurs"])
	_light(idle, Vector2i(3, 3), "enemy")
	check.call(not engine.valid_targets_for_player_action(idle, move).has(Vector2i(5, 4)), "Beacon ignores enemy Light and dark tiles")
	idle = engine.apply_player_action(idle, {"type": "blink", "range": 4}, Vector2i(3, 3))
	check.call(int(idle["turn_flags"].get(Rules.REFUNDS, 0)) == 0, "Beacon never refunds Blink")
	state = engine.prepare_next_player_turn(state)
	check.call(Rules.refund_available(state, Data.relic_effects_for_state(state)) == 2, "Beacon refreshes its cap next turn")
	var pool: Dictionary = _state(engine, ["beaconrunner_spurs"])
	_light(pool, Vector2i(3, 3))
	pool = engine.apply_player_movement(pool, Vector2i(3, 3))
	check.call(int(pool["player_movement_remaining"]) == 2 and int(pool["last_player_movement"]["spent"]) == 0 and int(pool["last_player_movement"]["light_refunds"]) == 1, "Beacon refunds the independent Move pool and records a resolved zero-net-cost Move")

static func _test_vault(engine: Combat, check: Callable) -> void:
	var state: Dictionary = _state(engine, ["vaulting_sigil"])
	state["enemies"][0]["pos"] = Vector2i(3, 3)
	state["enemies"][0]["footprint"] = Vector2i(2, 1)
	state["enemies"].append(Base.enemy(2, Vector2i(5, 3)))
	var move: Dictionary = {"type": "move", "range": 4, "straight_line": false}
	var path: Array[Vector2i] = engine.path_for_player_action(state, move, Vector2i(6, 3))
	check.call(path.has(Vector2i(3, 3)) and path.has(Vector2i(5, 3)) and not engine.valid_targets_for_player_action(state, move).has(Vector2i(3, 3)), "Vault path passes through both footprints and cannot end on an enemy")
	state = _preview(engine, state, move, Vector2i(6, 3), check, "Vault")
	var delays: Dictionary = engine.stagger_delays_between({}, state)
	check.call(int(delays.get(1, 0)) == 2 and int(delays.get(2, 0)) == 2, "Vault applies Stagger once per enemy per Move, including large footprints")
	var idle: Dictionary = _state(engine, ["vaulting_sigil"])
	idle = engine.apply_player_action(idle, {"type": "move", "range": 1}, Vector2i(2, 4))
	check.call(engine.stagger_delays_between({}, idle).is_empty(), "Vault is idle on paths without enemies")
	idle = engine.apply_player_action(idle, {"type": "blink", "range": 5}, Vector2i(6, 3))
	check.call(engine.stagger_delays_between({}, idle).is_empty(), "Vault does not affect Blink")
	var straight: Dictionary = _state(engine, ["vaulting_sigil"])
	straight["enemies"][0]["pos"] = Vector2i(3, 3)
	var line: Dictionary = {"type": "move", "range": 3, "straight_line": true}
	check.call(engine.valid_targets_for_player_action(straight, line).has(Vector2i(5, 3)) and not engine.valid_targets_for_player_action(straight, line).has(Vector2i(4, 4)), "Vault preserves a straight-line Move's direction while traversing an enemy")
	straight = _preview(engine, straight, line, Vector2i(5, 3), check, "Vault straight Move")
	check.call(int(engine.stagger_delays_between({}, straight).get(1, 0)) == 2, "A straight-line Move also staggers the enemy crossed")

static func _test_sun(engine: Combat, check: Callable) -> void:
	var state: Dictionary = _state(engine, ["unclouded_sun"])
	_light(state, Vector2i(2, 3))
	_light(state, Vector2i(6, 4))
	Surface.place(state, Vector2i(6, 4), "fire", {"actor_kind": "enemy"})
	var move: Dictionary = {"type": "move", "range": 1}
	var path: Array[Vector2i] = engine.path_for_player_action(state, move, Vector2i(6, 4))
	check.call(path.size() == 2 and engine.movement_cost_for_path(state, path) == 1, "Sun connects nonadjacent hero Light tiles for exactly one movement")
	var segments: Array[Dictionary] = preload("res://scripts/run_scene.gd").player_move_segments(state, path, {})
	check.call(segments.size() == 1 and segments[0].get("blink_from") == path[0] and segments[0].get("blink_to") == Vector2i(6, 4), "A Sun Light link is presented as a blink, not a walk")
	var walked: Array[Vector2i] = engine.path_for_player_action(state, {"type": "move", "range": 2}, Vector2i(2, 5))
	var walk_segments: Array[Dictionary] = preload("res://scripts/run_scene.gd").player_move_segments(state, walked, {})
	check.call(walked.size() == 3 and walk_segments.size() == 1 and walk_segments[0].has("walk"), "Ordinary adjacent steps still walk")
	# Light sources are the relays: a jump lands on a source and walks on from it.
	var relay: Dictionary = _state(engine, ["unclouded_sun"])
	_light(relay, Vector2i(2, 3), "player", 1)
	_light(relay, Vector2i(6, 4), "player", 1)
	var onward: Array[Vector2i] = engine.path_for_player_action(relay, {"type": "move", "range": 2}, Vector2i(6, 5))
	var onward_segments: Array[Dictionary] = preload("res://scripts/run_scene.gd").player_move_segments(relay, onward, {})
	check.call(onward.size() == 3 and onward[1] == Vector2i(6, 4) and engine.movement_cost_for_path(relay, onward) == 2, "A Sun jump lands on the far relay and walks on from it")
	check.call(onward_segments.size() == 2 and onward_segments[0].get("blink_to") == Vector2i(6, 4) and onward_segments[1].has("walk"), "The relay jump blinks between sources, then the hero walks")
	check.call(not Rules.is_light_link(relay, Vector2i(2, 4), Vector2i(6, 5)) and Rules.is_light_link(relay, Vector2i(2, 3), Vector2i(6, 4)), "Only Light sources link; other lit tiles are walked")
	var hp: int = int(state["player"]["hp"])
	state = _preview(engine, state, move, Vector2i(6, 4), check, "Sun")
	check.call(state["player"]["pos"] == Vector2i(6, 4) and int(state["player"]["hp"]) == hp - 2, "Sun enters only the landing tile and applies its hazards")
	var idle: Dictionary = _state(engine, ["unclouded_sun"])
	_light(idle, Vector2i(2, 3), "enemy")
	_light(idle, Vector2i(6, 4))
	check.call(not engine.valid_targets_for_player_action(idle, move).has(Vector2i(6, 4)), "Sun never links enemy Light")
	check.call(not engine.valid_targets_for_player_action(state, {"type": "blink", "range": 1}).has(Vector2i(2, 3)), "Sun leaves Blink range unchanged")
	var combo: Dictionary = _state(engine, ["unclouded_sun", "beaconrunner_spurs", "vaulting_sigil"])
	_light(combo, Vector2i(2, 3))
	_light(combo, Vector2i(6, 4))
	combo = _preview(engine, combo, {"type": "move", "range": 1}, Vector2i(6, 4), check, "Sun and Beacon")
	check.call(int(combo["turn_flags"].get(Rules.REFUNDS, 0)) == 1 and engine.stagger_delays_between({}, combo).is_empty(), "A Light jump refunds its landing but never passes through intervening enemies")

static func _test_funeral(engine: Combat, check: Callable) -> void:
	var state: Dictionary = _state(engine, ["funeral_bell"])
	state["enemies"][0]["hp"] = 1
	state["enemies"][0]["bleed"] = 2
	state["enemies"][0]["expose"] = 3
	state["enemies"][0]["shock"] = 1
	state["enemies"][0]["footprint"] = Vector2i(2, 1)
	state["enemies"].append(Base.enemy(2, Vector2i(6, 3)))
	state["enemies"][1]["bleed"] = 1
	state["enemies"][1]["expose"] = 5
	state["enemies"][1]["shock"] = 2
	state["enemies"].append(Base.enemy(3, Vector2i(7, 4)))
	state = _preview(engine, state, {"type": "ranged", "range": 5, "damage": 1}, Vector2i(4, 3), check, "Funeral")
	check.call(int(state["enemies"][1]["bleed"]) == 3 and int(state["enemies"][1]["expose"]) == 5 and int(state["enemies"][1]["shock"]) == 2, "Funeral spreads all statuses to footprint neighbors; Bleed adds and Expose/Shock take the larger value")
	check.call(int(state["enemies"][2].get("bleed", 0)) == 0, "Funeral does not spread beyond adjacent enemies")
	var idle: Dictionary = _state(engine, ["funeral_bell"])
	idle["enemies"][0]["hp"] = 1
	idle["enemies"][0]["bleed"] = 2
	idle["enemies"].append(Base.enemy(2, Vector2i(5, 3)))
	idle = engine.apply_player_action(idle, {"type": "ranged", "range": 5, "damage": 1}, Vector2i(4, 3))
	check.call(int(idle["enemies"][1].get("bleed", 0)) == 0, "Funeral is idle below two different statuses")
	var passive: Dictionary = _state(engine, ["funeral_bell"])
	passive["enemies"][0]["hp"] = 1
	passive["enemies"][0]["chilled"] = true
	passive["enemies"][0]["relic_chilled"] = true
	passive["enemies"][0]["immobilize"] = true
	passive["enemies"].append(Base.enemy(2, Vector2i(5, 3)))
	Surface.place(passive, Vector2i(4, 3), "fire", {"actor_kind": "enemy"})
	passive = (engine.call("_resolve_enemy_start_of_turn", passive, 0) as Dictionary)["state"]
	check.call(bool(passive["enemies"][1]["chilled"]) and bool(passive["enemies"][1]["immobilize"]), "Funeral also spreads boolean statuses on passive deaths without requiring supporting Ice")

static func _test_funeral_petrify(engine: Combat, check: Callable) -> void:
	var state: Dictionary = _state(engine, ["funeral_bell"])
	state["enemies"][0]["hp"] = 1
	state["enemies"][0]["petrify"] = 1
	state["enemies"][0]["expose"] = 1
	state["enemies"][0]["footprint"] = Vector2i(2, 1)
	state["enemies"].append(Base.enemy(2, Vector2i(6, 3)))
	state["enemies"].append(Base.enemy(3, Vector2i(4, 4)))
	state["enemies"][2]["type"] = "tharokh"
	state["enemies"].append(Base.enemy(4, Vector2i(7, 4)))
	var after: Dictionary = _preview(engine, state, {"type": "ranged", "range": 5, "damage": 1}, Vector2i(4, 3), check, "Funeral Petrify")
	check.call(int(after["enemies"][1].get("petrify", 0)) == 1 and int(after["enemies"][1].get("block", 0)) == 5, "Funeral spreads the full Petrify keyword with 5 Block to an adjacent enemy")
	check.call(int(after["enemies"][2].get("petrify", 0)) == 0 and int(after["enemies"][2].get("block", 0)) == 0, "Dragons remain immune to Funeral Petrify and gain no Block")
	check.call(int(after["enemies"][3].get("petrify", 0)) == 0 and int(after["enemies"][3].get("block", 0)) == 0, "Funeral Petrify does not reach a nonadjacent enemy")
	var events: Array = []
	for event: Dictionary in after.get("surface_events", []):
		if event.get("kind") == "petrified": events.append(event)
	check.call(events.size() == 1, "Funeral records exactly one petrified event for the eligible adjacent enemy")
	if events.size() == 1:
		var source: Dictionary = events[0].get("source", {}) as Dictionary
		check.call(int(events[0].get("enemy_id", -1)) == 2 and int(events[0].get("block", 0)) == 5 and source.get("relic_id") == "funeral_bell" and source.get("source_kind") == "relic" and not bool(source.get("player_card", true)), "Funeral Petrify event attributes the status and Block to the relic")

static func _funeral_petrify_reapplication_state(engine: Combat) -> Dictionary:
	var state: Dictionary = _state(engine, ["funeral_bell"])
	state["enemies"][0]["hp"] = 1
	state["enemies"][0]["petrify"] = 1
	state["enemies"][0]["expose"] = 1
	state["enemies"].append(Base.enemy(2, Vector2i(5, 3)))
	return state

static func _test_funeral_petrify_reapplication(engine: Combat, check: Callable) -> void:
	var state: Dictionary = _funeral_petrify_reapplication_state(engine)
	var petrify: Dictionary = engine.card_play_actions("petrify", state)[0]
	state = _preview(engine, state, petrify, Vector2i(5, 3), check, "Petrify before Funeral spread")
	check.call(int(state["enemies"][1].get("block", 0)) == 5 and int(state["enemies"][1].get("petrify", 0)) == 1, "The card newly Petrifies Funeral's adjacent target with 5 Block")
	var kill: Dictionary = {"type": "ranged", "range": 5, "damage": 1}
	state = _preview(engine, state, kill, Vector2i(4, 3), check, "Funeral after card Petrify")
	check.call(int(state["enemies"][1].get("block", 0)) == 5 and int(state["enemies"][1].get("petrify", 0)) == 1, "Card then Funeral spread keeps the same enemy at 5 Block")
	state = _funeral_petrify_reapplication_state(engine)
	var second_source: Dictionary = Base.enemy(3, Vector2i(6, 3))
	second_source["hp"] = 1
	second_source["petrify"] = 1
	second_source["expose"] = 1
	state["enemies"].append(second_source)
	var turn: int = int(state.get("turn", 0))
	state = _preview(engine, state, kill, Vector2i(4, 3), check, "First Funeral Petrify spread")
	check.call(int(state["enemies"][1].get("block", 0)) == 5, "The first Funeral spread grants 5 Block")
	state = _preview(engine, state, kill, Vector2i(6, 3), check, "Second Funeral Petrify spread")
	check.call(int(state.get("turn", 0)) == turn and int(state["enemies"][1].get("block", 0)) == 5 and int(state["enemies"][1].get("petrify", 0)) == 1, "Two Funeral spreads in one turn keep the same enemy at 5 Block")
	state = _funeral_petrify_reapplication_state(engine)
	state["enemies"][1]["block"] = 7
	state = _preview(engine, state, kill, Vector2i(4, 3), check, "Funeral Petrify with unrelated Block")
	check.call(int(state["enemies"][1].get("block", 0)) == 12 and int(state["enemies"][1].get("petrify", 0)) == 1, "New Funeral Petrify adds 5 to 7 unrelated Block without overwriting it")

static func _test_review_regressions(engine: Combat, check: Callable) -> void:
	var state: Dictionary = _state(engine, ["beaconrunner_spurs"])
	_light(state, Vector2i(3, 3))
	Surface.place(state, Vector2i(3, 3), "ice")
	state = engine.apply_player_action(state, {"type": "self_flag", "flag": "ice_skate"})
	var path: Array[Vector2i]
	path.append(Vector2i(2, 3))
	path.append(Vector2i(3, 3))
	check.call(engine.movement_cost_for_path(state, path) == 0, "Beacon cannot refund a free Skate step in the movement forecast")
	state = _preview(engine, state, {"type": "move", "range": 1}, Vector2i(3, 3), check, "Beacon with Skate")
	check.call(int(state["turn_flags"].get(Rules.REFUNDS, 0)) == 0, "A free Skate entry spends no Beacon refund")
	state["player"]["pos"] = Vector2i(2, 3)
	state = engine.apply_player_movement(state, Vector2i(3, 3))
	check.call(int(state["player_movement_remaining"]) == engine.player_movement_capacity(state) and int(state["last_player_movement"]["spent"]) == 0, "Beacon and Skate cannot increase the movement pool above capacity")
	var combo: Dictionary = _state(engine, ["beaconrunner_spurs", "unclouded_sun", "vaulting_sigil", "glassway_compass"])
	combo["enemies"][0]["pos"] = Vector2i(3, 3)
	_light(combo, Vector2i(4, 3))
	combo = engine._create_illusion(combo, Vector2i(5, 3), 2)
	var straight: Dictionary = {"type": "move", "range": 2, "straight_line": true}
	check.call(not engine.valid_targets_for_player_action(combo, straight).has(Vector2i(5, 3)), "A Glassway trade gets no Beacon refund from the Light it skips, so Move 2 cannot reach an Illusion three tiles away")
	straight["range"] = 3
	check.call(engine.valid_targets_for_player_action(combo, straight).has(Vector2i(5, 3)), "Glassway straight Move reaches the Illusion through Vault's enemy tile")
	combo = _preview(engine, combo, straight, Vector2i(5, 3), check, "Glassway straight with U7 relics")
	check.call(engine.stagger_delays_between({}, combo).is_empty() and int(combo["turn_flags"].get(Rules.REFUNDS, 0)) == 0 and combo["illusions"][0]["pos"] == Vector2i(2, 3), "A Glassway straight trade teleports: no Vault Stagger or refund for the tiles it skips")
	var blocked: Dictionary = _state(engine, ["unclouded_sun", "glassway_compass"])
	blocked = engine._create_illusion(blocked, Vector2i(3, 3), 2)
	blocked = engine._create_illusion(blocked, Vector2i(5, 3), 2)
	for y: int in range(1, 8):
		if y != 3: blocked["grid"][y][3] = "wall"
	check.call(not engine.valid_targets_for_player_action(blocked, {"type": "move", "range": 4}).has(Vector2i(5, 3)), "One Glassway search opens endpoints without allowing traversal through illusions")
	var throne: Dictionary = _state(engine, ["chorus_mask", "fivefold_knot", "briar_throne"])
	throne[Rules.KNOTS] = Rules.ELEMENTS.duplicate()
	throne["turn_flags"][Rules.LAST] = "fire"
	var lash: Dictionary = Data.card_def_for_progression("lash", throne)
	var tokens: Array = preload("res://scripts/action_icon_library.gd").rows_for_card(lash)
	check.call(not lash["actions"].any(func(a: Dictionary) -> bool: return str(a.get("type", "")) == "block") and not str(tokens).contains('"icon": "block"'), "Throne prevents Chorus and Fivefold from appending a Block 0 row to Lash")
	var gear: Dictionary = {"a": {"element": "air"}, "b": {"element": "air"}}
	var bonded: Dictionary = Rules.modify_card(Data.card_def("lash"), {"equipped_equipment": {"weapon": "a", "boots": "b"}}, Data.relic_effects_for_ids(["bonded_set", "briar_throne"]), gear, {"a": ["lash"]})
	check.call(not bonded["actions"].any(func(a: Dictionary) -> bool: return str(a.get("type", "")) == "block"), "Throne also prevents Bonded Set from appending card Block")
	var original: Dictionary = {"actions": [{"type": "block", "amount": 1}]}
	var untouched: Dictionary = Rules.modify_card(original, {}, [], {}, {})
	check.call(is_same(original, untouched), "SurfaceVariety returns the original card without copying when no modifier is owned")
	var scene := preload("res://scripts/run_scene.gd").new()
	var custom: Dictionary = {"max_knots": 8, "pierce_threshold": 2, "chain_threshold": 3, "chain": 4, "block_threshold": 4, "block": 9}
	var detail: String = scene.call("_relic_knots_tooltip", custom, ["fire", "ice", "earth", "air"])
	check.call(detail.contains("4 of 8") and detail.contains("attacks Pierce and Chain 4; every card grants 9 Block"), "Fivefold tooltip reads all thresholds and amounts from its effect")
	scene.free()

static func _test_navigation_performance(engine: Combat, check: Callable) -> void:
	var state: Dictionary = _state(engine, ["beaconrunner_spurs", "unclouded_sun", "vaulting_sigil", "glassway_compass"])
	_light(state, Vector2i(2, 3), "player", 3)
	_light(state, Vector2i(6, 4), "player", 3)
	for tile: Vector2i in [Vector2i(3, 4), Vector2i(5, 4), Vector2i(7, 4)]: state = engine._create_illusion(state, tile, 2)
	var best_usec: int = 2147483647
	var targets: Array[Vector2i]
	for _attempt: int in range(5):
		var start: int = Time.get_ticks_usec()
		targets = engine.valid_targets_for_player_action(state, {"type": "move", "range": 4})
		best_usec = mini(best_usec, Time.get_ticks_usec() - start)
	print("R1 dense-Light navigation best of 5: %0.3f ms" % (best_usec / 1000.0))
	check.call(targets.has(Vector2i(7, 4)), "Two radius-three Light patches, Move 4 and all four relics retain the distant endpoint")
	if preload("res://tests/helpers/perf_group.gd").enabled():
		check.call(best_usec < 40000, "Two radius-three Light patches, Move 4 and all four relics search in under 40 ms")

static func _test_navigation_preferences(engine: Combat, check: Callable) -> void:
	var state: Dictionary = _state(engine, ["beaconrunner_spurs"])
	state["enemies"][0]["pos"] = Vector2i(8, 7)
	Surface.place(state, Vector2i(3, 3), "fire")
	var move: Dictionary = {"type": "move", "range": 4}
	var target := Vector2i(4, 3)
	var path: Array[Vector2i] = engine.path_for_player_action(state, move, target)
	check.call(not path.has(Vector2i(3, 3)) and engine.movement_cost_for_path(state, path) == 4, "Cost search retains a longer safe route instead of the shorter hazardous route")
	var before_hp: int = state["player"]["hp"]
	state = _preview(engine, state, move, target, check, "Safe predecessor route")
	check.call(state["player"]["hp"] == before_hp, "Safe predecessor path commits without Fire contact")
	state = _state(engine, ["beaconrunner_spurs"])
	state["enemies"][0]["pos"] = Vector2i(8, 7)
	state["loot"] = [{"id": "r1_pickup", "pos": Vector2i(3, 2), "kind": "dropped_embers", "claimed": false}]
	path = engine.path_for_player_action(state, move, target)
	check.call(path.has(Vector2i(3, 2)) and path.size() == 5, "Predecessor search preserves the preferred pickup detour without repeated tiles")
	var winter: Dictionary = _state(engine, ["beaconrunner_spurs", "winters_spur"])
	winter["enemies"][0]["pos"] = Vector2i(8, 7)
	for x: int in range(2, 7): Surface.place(winter, Vector2i(x, 3), "ice")
	path = engine.path_for_player_action(winter, {"type": "move", "range": 1}, Vector2i(6, 3))
	check.call(path.size() == 5 and engine.movement_cost_for_path(winter, path) == 1, "Incoming direction is retained when Winter's Spur genuinely changes step cost")
	winter = _preview(engine, winter, {"type": "move", "range": 1}, Vector2i(6, 3), check, "Winter direction with Beacon")

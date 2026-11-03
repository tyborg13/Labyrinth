extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Rules = preload("res://scripts/surface_variety_relic_rules.gd")
const Tempo = preload("res://scripts/tempo_rules.gd")
const Fixture = preload("res://tests/suites/surface_relic_suite.gd")
const Store = preload("res://scripts/progression_store.gd")
const Expend = preload("res://scripts/surface_expend_rules.gd")
const Echoes = preload("res://scripts/illusion_relic_rules.gd")
const Base = preload("res://tests/suites/board_surface_suite.gd")
const TARGET := Vector2i(4, 3)
const ECHO_TARGET := Vector2i(4, 5)
const ECHO_ORIGIN := Vector2i(3, 5)
const ECHO_ILLUSION_HEALTH: int = 10
const TRAP_TILE := Vector2i(3, 3)
const TRAP_WALL := Vector2i(5, 3)
const ATTACK := {"type": "ranged", "damage": 1, "range": 5}
const NON_EXPEND_CONDUCTOR_COPY: String = "Fire conducts Lightning."
const EXPEND_CARDS := ["spike_mantle", "grounding", "flashsteam", "frost_heave", "plasma_arc", "pyroclasm", "dust_devil", "magma_vent", "cinder_patch"]

class TrayHarness extends "res://scripts/run_scene.gd":
	func _layout_header_hud() -> void: pass
	func _layout_combat_objective_hud() -> void: pass
	func _request_skill_event_analytics() -> void: pass
	func _request_run_skill_event_analytics() -> void: pass

static func run(check: Callable) -> void:
	var engine := Combat.new()
	_test_growth(engine, check)
	_test_expend_cards(engine, check)
	_test_excluded_removals(engine, check)
	_test_relic_sources(engine, check)
	_test_echo_expend(engine, check)
	_test_player_triggered_trap(engine, check)
	_test_old_save(engine, check)
	_test_tray(engine, check)

static func _state(engine: Combat, ids: Array = ["black_sun_dial"]) -> Dictionary:
	return Fixture.fixture(engine, ids)

static func _finish(engine: Combat, state: Dictionary, card_id: String = "brace") -> Dictionary:
	state["deck"]["hand"] = [card_id]
	return engine.finish_player_card(state, 0)

static func _test_growth(engine: Combat, check: Callable) -> void:
	var state: Dictionary = _state(engine)
	var initial_id: int = -1
	for index: int in range(4):
		var surface: String = ["fire", "ice", "electrified", "rubble"][index]
		Surface.place(state, Vector2i(3, 3), surface)
		var before: Dictionary = state.duplicate(true)
		var action: Dictionary = {"type": "consume_surface", "surface": surface, "range": 5}
		var forecast: Dictionary = engine.surface_preview_for_player_action(state, action, Vector2i(3, 3))["state"]
		check.call(state == before, "Dial previews preserve the input state and event history")
		state = engine.apply_player_action(state, action, Vector2i(3, 3))
		check.call(state == forecast and before != state, "Dial Expend preview equals commit for tile %d" % (index + 1))
		var expected: int = mini((index + 1) * 3, 9)
		check.call(Rules.pending_dial_damage(state) == expected and Tempo.next_attack_buffs(state).size() == 1, "Dial tiles 1/2/3/4 grant 3/6/9/9 in one buff: tile %d" % (index + 1))
		var buff: Dictionary = Rules.dial_buff(state)
		if index == 0: initial_id = int(buff.get("id", -1))
		check.call(int(buff.get("id", -1)) == initial_id and str(buff.get("source", "")) == "Black Sun Dial", "Dial grows the existing named next-attack entry")
		var events: Array = state.get("surface_events", [])
		check.call(int((events.back() as Dictionary).get("damage_added", -1)) == (0 if index == 3 else 3), "Dial removal analytics records actual damage_added including the cap")
		check.call(engine.final_damage_for_player_action(state, ATTACK) == (10 if index == 3 else 1), "New Expend damage waits for a later card; an already capped bonus stays eligible")
		state = _finish(engine, state)
		check.call(engine.final_damage_for_player_action(state, ATTACK) == 1 + expected, "Later-card damage preview includes the pending Dial value")
	check.call(not state.has("relic_stored_surfaces"), "Dial never creates the old capacity-limited storage")
	var other: Dictionary = state.duplicate(true)
	Tempo.gain_next_attack(other, {"damage": 2}, "Other source")
	other = _finish(engine, other)
	check.call(engine.final_damage_for_player_action(other, ATTACK) == 12, "Dial composes with other next-attack sources")
	var after: Dictionary = engine.apply_player_action(state, ATTACK, TARGET)
	check.call(int(after["enemies"][0]["hp"]) == 990 and Rules.pending_dial_damage(after) == 0, "One attack receives and consumes the +9 Dial bonus")
	check.call(engine.final_damage_for_player_action(after, ATTACK) == 1, "The following attack receives no Dial damage")
	check.call(Surface.element_at(after, TARGET).is_empty() and not bool(after["enemies"][0].get("chilled", false)) and int(after["enemies"][0].get("shock", 0)) == 0 and engine.stagger_delays_between(state, after).is_empty(), "Dial has no Fire, Chilled, Shock or Stagger riders")
	var invalid: Dictionary = engine.apply_player_action(state, {"type": "melee", "range": 1, "damage": 1}, TARGET)
	check.call(Rules.pending_dial_damage(invalid) == 9, "Invalid attacks leave the pending Dial bonus intact")

static func _test_expend_cards(engine: Combat, check: Callable) -> void:
	for card_id: String in EXPEND_CARDS:
		var state: Dictionary = _state(engine)
		var card: Dictionary = Data.card_def_for_progression(card_id, state)
		var action: Dictionary = card["actions"][0]
		for candidate: Dictionary in card["actions"]:
			if str(candidate.get("type", "")) == "consume_surface" or candidate.has("consume") or candidate.has("clear_surface"):
				action = candidate
				break
		action["_card_id"] = card_id
		var surface: String = str((action.get("consume", {}) as Dictionary).get("surface", action.get("consume_center", action.get("clear_surface", action.get("detonate_surface", action.get("surface", ""))))))
		var target: Vector2i = Vector2i(3, 3) if card_id in ["spike_mantle", "dust_devil"] else (Vector2i(2, 3) if card_id in ["grounding", "cinder_patch"] else TARGET)
		Surface.place(state, target, surface)
		state = engine.apply_player_action(state, action, Vector2i(2, 3) if card_id == "spike_mantle" else target)
		check.call(Rules.pending_dial_damage(state) == 3, "Expend card feeds the Dial: " + card_id)
		var counted: int = 0
		for event: Dictionary in state.get("surface_events", []):
			if str(event.get("kind", "")) != "surface_removed": continue
			var reason: String = {"dust_devil": "consumed", "magma_vent": "detonate", "cinder_patch": "clear"}.get(card_id, "consume")
			check.call(str(event.get("reason", "")) == reason and bool(event["source"].get(Expend.KEYWORD, false)), "Expend card removal carries its source tag and original reason: " + card_id)
			check.call(int(event.get("damage_added", 0)) == 3, "Expend source records damage_added: " + card_id)
			counted += 1
		check.call(counted == 1, "Expend fixture removes exactly one tile: " + card_id)
		check.call(engine.final_damage_for_player_action(state, ATTACK) == 1, "Expend during an attacking card cannot boost that card: " + card_id)
		state = _finish(engine, state, card_id)
		check.call(engine.final_damage_for_player_action(state, ATTACK) == 4, "Expend bonus becomes eligible after the card finishes: " + card_id)
	var flint: Dictionary = _state(engine, ["black_sun_dial", "flint_edge"])
	flint["player"]["pos"] = Vector2i(3, 3)
	Surface.place(flint, TARGET, "fire")
	flint = engine.apply_player_action(flint, {"type": "melee", "range": 1, "damage": 1}, TARGET)
	check.call(Rules.pending_dial_damage(flint) == 3 and int(flint["enemies"][0]["hp"]) == 996, "Flint Edge's explicit Expend grants +3 for a later card only")
	var area: Dictionary = _state(engine)
	for tile: Vector2i in [Vector2i(2, 3), Vector2i(3, 3), Vector2i(2, 2), Vector2i(2, 4)]:
		Surface.place(area, tile, "electrified")
	area = engine.apply_player_action(area, Data.card_def_for_progression("grounding", area)["actions"][0], Vector2i(2, 3))
	check.call(Rules.pending_dial_damage(area) == 9 and Tempo.next_attack_buffs(area).size() == 1, "One Grounding Expending four tiles grows one buff to +9")

static func _test_excluded_removals(engine: Combat, check: Callable) -> void:
	for reason: String in ["consume", "consumed", "detonate", "chain", "conduction", "freeze", "clear", "force_collision", "discharge", "relic_redirect", "relic_attack_origin"]:
		for tagged: bool in [false, true]:
			var state: Dictionary = _state(engine)
			Surface.place(state, TARGET, "fire")
			var before: Dictionary = state.duplicate(true)
			var card_id: String = "magma_vent" if tagged else "brace"
			state["damage_context"] = Expend.card_source({"actor_kind": "player", "card_id": card_id}, Data.card_def(card_id), {})
			Surface.remove(state, TARGET, "fire", reason)
			Rules.collect_removals(state, int(before.get("surface_event_sequence", 0)), Data.relic_effects_for_state(state))
			check.call(Rules.pending_dial_damage(state) == (3 if tagged else 0), "Dial follows the removing source's Expend identity, independent of reason %s (tagged=%s)" % [reason, tagged])
	for actor: String in ["enemy"]:
		var state: Dictionary = _state(engine)
		Surface.place(state, TARGET, "fire")
		var before: Dictionary = state.duplicate(true)
		state["damage_context"] = {"actor_kind": actor, Expend.KEYWORD: true}
		Surface.remove(state, TARGET, "fire", "consume")
		Rules.collect_removals(state, int(before.get("surface_event_sequence", 0)), Data.relic_effects_for_state(state))
		check.call(Rules.pending_dial_damage(state) == 0, "Dial ignores non-player Expend: " + actor)
	var det: Dictionary = _state(engine)
	Surface.place(det, TARGET, "fire")
	det = engine.apply_player_action(det, {"type": "detonate", "range": 5, "damage": 1}, TARGET)
	check.call(Rules.pending_dial_damage(det) == 0, "Real Detonate cannot feed the Dial")
	var conduction: Dictionary = _state(engine, ["black_sun_dial", "coalheart_crucible"])
	var original: Dictionary = (Data.relics()["coalheart_crucible"] as Dictionary).duplicate(true)
	Data.relics()["coalheart_crucible"]["description"] = NON_EXPEND_CONDUCTOR_COPY
	Surface.place(conduction, TARGET, "fire")
	conduction = engine.apply_player_action(conduction, {"type": "ranged", "range": 5, "damage": 1, "element": "lightning"}, TARGET)
	Data.relics()["coalheart_crucible"] = original
	check.call(Rules.pending_dial_damage(conduction) == 0 and Surface.element_at(conduction, TARGET).is_empty(), "Fire conduction from a non-Expend source cannot feed the Dial")
	var frozen: Dictionary = _state(engine)
	Surface.place(frozen, TARGET, "ice")
	frozen = engine.surface_actor_arrival(frozen, "enemy", 1, Vector2i(4, 2))
	frozen = engine.apply_player_action(frozen, {"type": "ranged", "range": 5, "damage": 1, "element": "ice"}, TARGET)
	check.call(Rules.pending_dial_damage(frozen) == 0, "Real Freeze cannot feed the Dial")

static func _test_relic_sources(engine: Combat, check: Callable) -> void:
	for relic_id: String in ["coalheart_crucible", "briar_winch", "worldroot_idol", "basalt_calendar", "ashen_brand", "breaking_wheel"]:
		var state: Dictionary = _state(engine, ["black_sun_dial", relic_id])
		var action: Dictionary = {"type": "ranged", "range": 5, "damage": 1}
		match relic_id:
			"coalheart_crucible":
				Surface.place(state, TARGET, "fire")
				action["element"] = "lightning"
			"briar_winch":
				Surface.place(state, TARGET, "rubble")
				action = {"type": "push", "range": 5, "amount": 1, "force_direction": Vector2i.DOWN, "_surface_relic_modes": ["redirect"]}
			"worldroot_idol":
				for tile: Vector2i in [Vector2i(2, 3), Vector2i(3, 3)]: Surface.place(state, tile, "rubble")
				action["_surface_relic_modes"] = ["remote"]
				action["_origin_tile"] = Vector2i(3, 3)
			"basalt_calendar":
				Surface.place(state, TARGET, "rubble")
				action = {"type": "detonate", "range": 5, "damage": 1, "_surface_relic_modes": ["crush"]}
			"ashen_brand":
				Surface.place(state, TARGET, "fire")
				action = {"type": "detonate", "range": 5, "damage": 1}
			"breaking_wheel":
				Surface.place(state, TARGET, "fire")
				state["grid"][3][5] = "wall"
				action = {"type": "push", "range": 5, "amount": 1}
		state = engine.apply_player_action(state, action, TARGET)
		check.call(Rules.pending_dial_damage(state) == 3, "Expend-tagged removing relic feeds Dial despite a non-Expend triggering card: " + relic_id)
		var attributed: bool = false
		for event: Dictionary in state.get("surface_events", []):
			if str(event.get("kind", "")) == "surface_removed" and str((event.get("source", {}) as Dictionary).get("removal_relic_id", "")) == relic_id:
				attributed = bool(event["source"].get(Expend.KEYWORD, false))
		check.call(attributed, "Removal identifies its actual Expend relic: " + relic_id)
	var transport: Dictionary = _state(engine, ["black_sun_dial", "updraft_bottle"])
	Surface.place(transport, TARGET, "ice")
	transport = engine.apply_player_action(transport, {"type": "push", "range": 5, "amount": 1, "_card_id": "dust_devil", "_surface_relic_modes": ["transport"]}, TARGET)
	check.call(Rules.pending_dial_damage(transport) == 0 and Surface.element_at(transport, TARGET).is_empty(), "A non-Expend removing relic does not inherit its triggering card's Expend tag")

static func _test_echo_expend(engine: Combat, check: Callable) -> void:
	# Review reproduction: Jolt cannot reach the second enemy's Fire from the
	# hero, but Mirror Triptych's nearby illusion Expends it through Coalheart.
	# The second case also spends primary fuel to catch overlapping collectors.
	for primary_fire: bool in [false, true]:
		var state: Dictionary = _state(engine, ["black_sun_dial", "coalheart_crucible", "mirror_triptych"])
		state["enemies"].append(Base.enemy(2, ECHO_TARGET))
		state = engine._create_illusion(state, ECHO_ORIGIN, ECHO_ILLUSION_HEALTH)
		Surface.place(state, ECHO_TARGET, "fire")
		if primary_fire: Surface.place(state, TARGET, "fire")
		state["deck"]["hand"] = ["jolt"]
		state = engine.prepare_player_card(state, 0)
		var action: Dictionary = engine.card_play_actions("jolt", state)[0]
		var source: Dictionary = state.duplicate(true)
		var forecast: Dictionary = engine.surface_preview_for_player_action(state, action, TARGET)["state"]
		state = engine.apply_player_action(state, action, TARGET)
		check.call(forecast == state and source != state, "Dial echo setup uses matching action preview and commit")
		check.call(Rules.pending_dial_damage(state) == (3 if primary_fire else 0) and Surface.element_at(state, ECHO_TARGET) == "fire", "Echo fuel is still unspent before card end")
		var before_finish: Dictionary = state.duplicate(true)
		var trace: Dictionary = {"echoes": []}
		forecast = Echoes.finish_echoes(engine, state.duplicate(true), trace)
		var committed: Dictionary = engine.finish_player_card(state, 0)
		var expected: int = 6 if primary_fire else 3
		check.call(state == before_finish, "Echo preview and card commit leave their input state unchanged")
		check.call(Rules.pending_dial_damage(forecast) == expected and Rules.pending_dial_damage(committed) == expected, "Card-end Expend grants Dial damage in both echo preview and commit")
		check.call(Surface.element_at(committed, ECHO_TARGET).is_empty() and forecast["surface_events"] == committed["surface_events"], "Echo preview and commit agree on spent Fire and analytics")
		check.call(not trace["echoes"].is_empty() and Rules.pending_dial_damage(trace["echoes"].back()["state"]) == expected, "Echo animation snapshot includes collected Dial damage")
		var echo_tiles: int = 0
		for event: Dictionary in committed.get("surface_events", []):
			if str(event.get("kind", "")) != "surface_removed" or event.get("tile") != ECHO_TARGET: continue
			echo_tiles += 1
			check.call(str(event["source"].get("source_kind", "")) == "illusion_echo" and bool(event["source"].get(Expend.KEYWORD, false)) and int(event.get("damage_added", 0)) == 3, "Echo removal retains its Expend source and records damage_added once")
		check.call(echo_tiles == 1, "The echoed Jolt Expends exactly one Fire tile")
		Rules.collect_removals(committed, 0, Data.relic_effects_for_state(committed))
		committed = Echoes.finish_echoes(engine, committed)
		committed = engine.apply_player_action(committed, {"type": "block", "amount": 1})
		check.call(Rules.pending_dial_damage(committed) == expected, "Repeated collection and later utility do not duplicate echo fuel")
		committed = engine.apply_player_action(committed, ATTACK, TARGET)
		Rules.collect_removals(committed, 0, Data.relic_effects_for_state(committed))
		check.call(Rules.pending_dial_damage(committed) == 0, "After consumption, old echo events cannot grant the Dial bonus again")

static func _test_player_triggered_trap(engine: Combat, check: Callable) -> void:
	var state: Dictionary = _state(engine, ["black_sun_dial", "breaking_wheel"])
	state["grid"][TRAP_WALL.y][TRAP_WALL.x] = "wall"
	state["traps"] = [{"id": "dial_air_trap", "pos": TRAP_TILE, "element": "air", "damage": 0}]
	Surface.place(state, TARGET, "fire")
	state["deck"]["hand"] = ["pale_spark"]
	state = engine.prepare_player_card(state, 0)
	var attack: Dictionary = engine.card_play_actions("pale_spark", state)[0]
	var source: Dictionary = state.duplicate(true)
	var forecast: Dictionary = engine.surface_preview_for_player_action(state, attack, TRAP_TILE)["state"]
	state = engine.apply_player_action(state, attack, TRAP_TILE)
	check.call(state == forecast and source != state, "Real player-triggered Air trap has matching preview and commit")
	check.call(state["traps"].is_empty() and Surface.element_at(state, TARGET).is_empty(), "Air trap triggers and the blocked enemy's Fire is Expended by Wheel")
	var removal_seen: bool = false
	for event: Dictionary in state.get("surface_events", []):
		if str(event.get("kind", "")) != "surface_removed" or event.get("tile") != TARGET: continue
		removal_seen = true
		var cause: Dictionary = event.get("source", {})
		check.call(str(cause.get("actor_kind", "")) == "player" and str(cause.get("source_kind", "")) == "force_collision" and str(cause.get("causal_source_kind", "")) == "trap", "Collision retains player attribution and trap causality independently")
		check.call(bool(cause.get(Expend.KEYWORD, false)) and str(cause.get("removal_relic_id", "")) == "breaking_wheel" and not event.has("damage_added"), "Trap exclusion rejects a real Expend-tagged Wheel removal")
	check.call(removal_seen and Rules.pending_dial_damage(state) == 0, "A real player-triggered trap collision never feeds the Dial")
	# A later hero force must not inherit the completed trap's causality.
	Surface.place(state, TARGET, "fire")
	state = engine.apply_player_action(state, {"type": "push", "range": 5, "amount": 1}, TARGET)
	check.call(Rules.pending_dial_damage(state) == 3, "A later direct player collision still feeds Dial through Wheel")

static func _test_old_save(engine: Combat, check: Callable) -> void:
	var state: Dictionary = _state(engine)
	state["relic_stored_surfaces"] = ["fire", "ice", "electrified", "rubble"]
	var old_path: String = Store._run_storage_path
	Store.set_run_storage_path("user://pt13_01_old_dial.save")
	check.call(Store.save_run_state({"combat_state": state}), "Old Dial fixture saves through the real serializer")
	var resumed: Dictionary = Store.load_saved_run().get("combat_state", {})
	Store.clear_saved_run()
	Store.set_run_storage_path(old_path)
	check.call(not resumed.is_empty() and Rules.pending_dial_damage(resumed) == 0 and engine.final_damage_for_player_action(resumed, ATTACK) == 1, "Old stored-surface save loads and grants nothing")
	resumed = engine.apply_player_action(resumed, ATTACK, TARGET)
	check.call(Surface.element_at(resumed, TARGET).is_empty() and not bool(resumed["enemies"][0].get("chilled", false)) and int(resumed["enemies"][0].get("shock", 0)) == 0 and engine.stagger_delays_between(state, resumed).is_empty(), "Old saves cannot restore removed Dial riders")

static func _test_tray(engine: Combat, check: Callable) -> void:
	var scene := TrayHarness.new()
	scene.relic_bar = VBoxContainer.new()
	scene._relic_utility_bar = HBoxContainer.new()
	scene._relic_icon_grid = GridContainer.new()
	scene.add_child(scene.relic_bar)
	scene.relic_bar.add_child(scene._relic_utility_bar)
	scene.relic_bar.add_child(scene._relic_icon_grid)
	scene._card_focus_tooltip_stack = preload("res://scripts/card_focus_tooltip_stack.gd").new()
	scene.add_child(scene._card_focus_tooltip_stack)
	scene._run_state = {"mode": "combat", "relics": ["black_sun_dial"]}
	var state: Dictionary = _state(engine)
	for value: int in [0, 3, 6, 9]:
		if value > 0:
			if Rules.dial_buff(state).is_empty(): Tempo.gain_next_attack(state, {"damage": value}, "Black Sun Dial")
			else: Rules.dial_buff(state)["damage"] = value
		scene._combat_state = state
		scene._refresh_relic_bar()
		var counter: Label = scene._relic_icon_grid.find_child("RelicDialDamage", true, false) as Label
		check.call((counter == null if value == 0 else counter != null and counter.text == str(value)), "Actual Dial tray counter displays pending %d" % value)
	state = _finish(engine, state)
	state = engine.apply_player_action(state, ATTACK, TARGET)
	scene._combat_state = state
	scene._refresh_relic_bar()
	check.call(scene._relic_icon_grid.find_child("RelicDialDamage", true, false) == null, "Actual tray invalidates its cache and clears the consumed bonus")
	scene.free()

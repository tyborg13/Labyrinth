extends SceneTree

const Combat = preload("res://scripts/combat_engine.gd")
const BossSuite = preload("res://tests/suites/dragon_boss_suite.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const MoveSuite = preload("res://tests/suites/move_attack_shortcut_suite.gd")
var failed: int = 0

func _initialize() -> void:
	_run.call_deferred()

func expect(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)

func _run() -> void:
	_test_summon_reaction()
	_test_player_relights()
	_test_mantle_event()
	MoveSuite._test_every_move_then_attack_card_builds_enemy_shortcut(expect)
	MoveSuite._test_every_card_has_one_player_target_decision(expect)
	await MoveSuite._test_live_single_click_sequence(self, expect, "gust_step", "clear", Vector2i(5, 4), "Gust Step must finish its move and pull from one enemy click")
	if failed == 0: print("Dragon feedback mechanics passed.")
	quit(1 if failed else 0)

func _test_summon_reaction() -> void:
	var combat := Combat.new()
	for boss_id: String in ["zekarion", "noctyrax"]:
		var state: Dictionary = BossSuite._boss_combat_state(boss_id)
		var minion_type: String = "lightning_wisp" if boss_id == "zekarion" else "veilbound_acolyte"
		for enemy: Dictionary in state["enemies"]:
			if str(enemy["type"]) != boss_id: enemy["hp"] = 0
		state["initiative_clock"] = 20
		state["current_actor"] = combat._enemy_actor_entry(state, state["enemies"][0], 20, 0)
		state["turn_queue"] = [combat._player_actor_entry(80, 1)]
		state = combat._enemy_summon_minions(state, 0, {"type": "summon_minions", "minion_type": minion_type, "count": 2, "summon_cap": 2})
		var spawned: Dictionary = {}
		for enemy: Dictionary in state["enemies"]:
			if bool(enemy.get("summoned", false)) and int(enemy["hp"]) > 0: spawned[int(enemy["id"])] = enemy.duplicate(true)
		expect(spawned.size() == 2, "Reaction fixture must summon two helpers")
		for id: int in spawned:
			var entries: Array = (state["turn_queue"] as Array).filter(func(entry: Dictionary) -> bool: return int(entry.get("enemy_id", -1)) == id)
			expect(entries.size() == 1 and int(entries[0]["time"]) > 80, "Each summoned helper must wait beyond the booked player activation, even during a long delay")
		var restored: Dictionary = bytes_to_var(var_to_bytes(state))
		expect(restored["turn_queue"] == state["turn_queue"], "The reaction delay must survive serialization")
		state = combat.advance_to_next_player_turn_with_steps(restored)["state"]
		expect(combat.is_player_turn(state) and int(state["initiative_clock"]) == 80, "The player must receive the next activation before any summoned helper")
		for enemy: Dictionary in state["enemies"]:
			if spawned.has(int(enemy["id"])):
				expect(enemy["pos"] == spawned[int(enemy["id"])]["pos"], "The summoned helper cannot move before the player can react")
		state = combat.finish_player_activation(state)
		state = combat.advance_one_activation_with_steps(state)["state"]
		expect(int(state["initiative_clock"]) == 81, "After the reaction window the first summoned helper must act normally")

func _test_player_relights() -> void:
	var combat := Combat.new()
	var state: Dictionary = BossSuite._boss_combat_state("noctyrax")
	state["terrain"] = []
	state["traps"] = []
	var brazier: Dictionary = state["guardian_braziers"][0]
	brazier["lit"] = false
	var tile: Vector2i = brazier["pos"]
	state["player"]["pos"] = tile + Vector2i.LEFT
	state = combat.apply_player_action(state, {"type": "move", "range": 1}, tile)
	expect(state["player"]["pos"] == tile and bool(state["guardian_braziers"][0]["lit"]), "Walking onto an extinguished brazier relights it")
	var events: Array = (state.get("surface_events", []) as Array).filter(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "dragon_light_restored")
	expect(events.size() == 1 and str(events[0].get("trigger", "")) == "player_arrival", "Relighting records one player-arrival event")
	state = combat.surface_actor_arrival(state, "player", -1, tile + Vector2i.LEFT)
	var after: Array = (state.get("surface_events", []) as Array).filter(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "dragon_light_restored")
	expect(after.size() == 1, "Already-lit arrival does not repeat the relight event")
	state["guardian_braziers"][0]["lit"] = false
	state["player"]["pos"] = tile + Vector2i.LEFT
	state = combat.apply_player_action(state, {"type": "blink", "range": 2}, tile)
	expect(bool(state["guardian_braziers"][0]["lit"]), "Blink arrival supports the same relight interaction")

func _test_mantle_event() -> void:
	var combat := Combat.new()
	var state: Dictionary = BossSuite._boss_combat_state("iskaldra")
	state["enemies"][0]["frost_armor"] = 2
	var hp: int = int(state["enemies"][0]["hp"])
	state = combat._damage_enemy(state, 0, 7)
	expect(int(state["enemies"][0]["hp"]) == hp and int(state["enemies"][0]["frost_armor"]) == 1, "One positive hit spends one layer and prevents its damage")
	var events: Array = (state.get("surface_events", []) as Array).filter(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "crystal_mantle_broken")
	expect(events.size() == 1 and int(events[0].get("prevented_damage", 0)) == 7 and int(events[0].get("layers_remaining", -1)) == 1, "Mantle feedback records the prevented hit and exact remaining layers")
	state = combat._damage_enemy(state, 0, 0)
	expect(int(state["enemies"][0]["frost_armor"]) == 1, "Zero damage cannot waste a mantle layer")

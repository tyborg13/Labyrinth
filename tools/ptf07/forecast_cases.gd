extends SceneTree

const Combat = preload("res://scripts/combat_engine.gd")
const Fixtures = preload("res://tools/ptf07/fixtures.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const CASES = ["safe", "danger", "defiance", "defiance_twice", "defiance_umbra", "fatigue", "fatigue_lethal", "fatigue_defiance", "fatigue_full_hand", "fatigue_empty", "fatigue_cycles", "fatigue_heal", "block_start", "expose", "chilled", "bleed", "burn", "reinforcements", "reinforcements_after", "summon", "death_spawn", "safety_limit", "second_move", "many_repeats", "later_known", "meteor", "activation_end", "activation_end_lethal", "dead_queue", "dead_actor", "missing_intent", "player_tie", "umbra"]
const TEST_SECOND_LETHAL_DAMAGE: int = 7
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var scene: Node = preload("res://scripts/run_scene.gd").new()
	var engine := Combat.new()
	for kind: String in CASES:
		var source: Dictionary = fixture(kind)
		var unchanged: Dictionary = source.duplicate(true)
		var scheduled: Dictionary = engine.finish_player_activation(source)
		var forecast: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(scheduled, true)
		var summary: Dictionary = scene.call("_pass_preview_summary_for_phase_result", source, forecast)
		var turn_before: Dictionary = forecast.get("player_turn_before_state", {})
		if not turn_before.is_empty():
			var frozen_before: Dictionary = turn_before.duplicate(true)
			var production_start: Dictionary = engine.prepare_next_player_turn(turn_before)
			for field: String in ["hp", "max_hp", "block", "stoneskin"]:
				check(int(forecast["state"]["player"].get(field, 0)) == int(production_start["player"].get(field, 0)), kind + ": optimized start matches production " + field)
			check(int(forecast["state"].get("deck", {}).get("cycles", 0)) == int(production_start.get("deck", {}).get("cycles", 0)), kind + ": optimized draw cycles match production")
			check(turn_before == frozen_before, kind + ": turn-start receipt snapshot is retained unchanged")
		var actual: Dictionary = engine.advance_to_next_player_turn_with_steps(scheduled)
		var after: Dictionary = actual["state"]
		var uncertain: bool = bool(summary["unrevealed_before_player"]) or bool(summary["umbra_unknown_before_player"])
		check(source == unchanged, kind + ": forecast preserves source")
		if not uncertain:
			check(int(summary["projected_hp"]) == maxi(0, int(after["player"]["hp"])), kind + ": projected Health equals live resolution")
			check(int(forecast["state"].get("defiance_remaining", 0)) == int(after.get("defiance_remaining", 0)), kind + ": Defiance equals live resolution")
			check(bool(summary["defeat"]) == (engine.combat_outcome(after) == "defeat"), kind + ": DEFEAT equals live resolution")
		else:
			check(str(summary["tone"]) != "safe", kind + ": incomplete forecast warns")
		if kind in ["fatigue", "fatigue_lethal", "fatigue_defiance"]:
			check(int(summary["fatigue_loss"]) == 15, kind + ": exact next-draw cost")
			check(int(summary["hp_loss"]) > 0, kind + ": Fatigue included in loss")
			check(str(scene.call("_pass_preview_tooltip", summary)).ends_with("Fatigue: lose 15 Health at your next draw."), kind + ": tooltip draw explanation")
		if kind in ["fatigue_full_hand", "fatigue_empty"]: check(int(summary["fatigue_loss"]) == 0, kind + ": no shuffle means no Fatigue")
		if kind == "fatigue_cycles": check(int(summary["fatigue_loss"]) == 17, "Fatigue includes prior deck cycles")
		if kind == "many_repeats":
			check((summary["repeated_enemy_names"] as Array).size() == 3, "All repeating foes recorded")
			check(str(scene.call("_pass_preview_tooltip", summary)).contains("+1 more foes act twice."), "Multiple repeating foes use approved capped wording")
		if kind == "fatigue_heal": check(int(summary["hp_loss"]) == 15 and int(summary["projected_hp"]) == 24 and str(summary["tone"]) == "danger", "Recovery cannot erase Fatigue from the gross loss warning")
		if kind == "fatigue_lethal": check(bool(summary["defeat"]), "Fatigue warns DEFEAT")
		if kind == "fatigue_defiance": check(int(summary["defiance_spent"]) == 1, "Fatigue warns Defiance")
		if kind in ["second_move", "later_known"]:
			check((summary["repeated_enemy_names"] as Array).size() == 1, kind + ": second activation warning")
			var entries: Array[Dictionary] = scene.call("_pass_preview_forecast_entries", summary)
			check(str(entries.back()["text"]) == "+ ? 2ND MOVE", kind + ": explicit label suffix")
		if kind == "safety_limit": check(bool(summary["forecast_limit_reached"]) and str(scene.call("_pass_preview_tooltip", summary)).contains("Too many moves ahead to forecast them all."), "Bounded partial result cannot claim SAFE")
		if kind == "later_known": check(int(summary["hp_loss"]) == 7, "A repeat cannot hide another foe's announced attack")
		if kind == "activation_end": check(int(summary["hp_loss"]) > 5, "Activation-end pressure included before the announced attack")
		if kind == "block_start": check(int(summary["hp_loss"]) > 0, "Block expires before turn-start fire")
		if kind in ["reinforcements", "death_spawn", "safety_limit", "umbra"]:
			check(uncertain, kind + ": unavailable intent flagged")
		if kind == "defiance":
			check(str(scene.call("_pass_preview_tooltip", summary)) == "Ending now leaves 2 card plays unused: +10 Time.\nBefore your next turn: −7 Health\nDefiance: spend 1 charge and return at 4/24 Health.", "Defiance end state follows the loss line with exact singular copy")
		if kind == "defiance_twice":
			check(int(summary["defiance_spent"]) == 2, "Both actual Defiance charges counted")
			check(str(scene.call("_pass_preview_tooltip", summary)) == "Ending now leaves 2 card plays unused: +10 Time.\nBefore your next turn: −11 Health\nDefiance: spend 2 charges and return at 6/24 Health.", "Two Defiance saves use actual projected Health and plural copy")
		if kind == "defiance_umbra":
			check(str(scene.call("_pass_preview_tooltip", summary)).contains("Defiance: spend 1 charge and return at ?/? Health.\nFoes hidden in the Umbra may act first."), "Hidden ending Health stays unknown after the visible Defiance save")
		if kind in ["defiance", "defiance_twice", "defiance_umbra", "fatigue_defiance"]:
			print("DEFIANCE TOOLTIP %s:\n%s" % [kind, str(scene.call("_pass_preview_tooltip", summary))])
		print("CASE %s: forecast_hp=%d actual_hp=%d loss=%d uncertain=%s" % [kind, int(summary["projected_hp"]), int(after["player"]["hp"]), int(summary["hp_loss"]), str(uncertain)])
	var text: String = scene.call("_pass_preview_tooltip", {"wait_time": 5, "block_loss": 2, "hp_loss": 3, "repeated_enemy_names": ["A", "B", "C", "D"], "umbra_unknown_before_player": true, "fatigue_loss": 15})
	check(text == "Ending now leaves 1 card play unused: +5 Time.\nBefore your next turn: −2 Block, −3 Health\nA acts twice before you. Its second move is hidden.\nB acts twice before you. Its second move is hidden.\n+2 more foes act twice.\nFoes hidden in the Umbra may act first.\nFatigue: lose 15 Health at your next draw.", "Exact tooltip order, cap and wording")
	check(str(scene.call("_pass_preview_tooltip", {"wait_time": 0, "hp_loss": 0, "block_loss": 0})) == "Before your next turn: no damage", "SAFE tooltip")
	check(str(scene.call("_pass_preview_risk_tooltip", {"hp_loss": 5})) == "Before your next turn: −5 Health", "Health-only tooltip omits zero Block")
	check(str(scene.call("_pass_preview_risk_tooltip", {"block_loss": 5})) == "Before your next turn: −5 Block", "Block-only tooltip omits zero Health")
	scene.free()
	print("PTF07 RESULT: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)

static func fixture(kind: String) -> Dictionary:
	if kind in ["defiance", "defiance_twice", "defiance_umbra"]:
		var state: Dictionary = Fixtures._pass_preview_chip_state("defiance_umbra" if kind == "defiance_umbra" else "defiance_followup")
		if kind == "defiance_twice":
			state["defiance_capacity"] = 2
			state["defiance_remaining"] = 2
			state["enemies"][1]["intent"]["actions"][0]["damage"] = TEST_SECOND_LETHAL_DAMAGE
		return state
	var base_kind: String = "safe" if kind in ["safe", "fatigue", "fatigue_lethal", "fatigue_defiance", "block_start", "burn", "reinforcements"] else "danger"
	var state: Dictionary = Fixtures._pass_preview_chip_state(base_kind)
	# Debug-only fixtures use a single announced activation before the player.
	state["player_turn_time_spent"] = 0
	if kind.begins_with("fatigue"):
		state["deck"]["draw"] = []
		state["player"]["block"] = 50
		if kind in ["fatigue_lethal", "fatigue_defiance"]: state["player"]["hp"] = 5
		if kind == "fatigue_defiance":
			state["defiance_remaining"] = 1
			state["defiance_capacity"] = 1
	if kind == "fatigue_heal": state["active_rites"] = [{"card_id": "test_recovery", "effects": [{"type": "turn_start_reward", "rewards": [{"type": "heal", "amount": 15}]}]}]
	if kind == "fatigue_full_hand": state["deck"]["hand"] = ["quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab"]
	if kind == "fatigue_empty": state["deck"]["discard"] = []
	if kind == "fatigue_cycles": state["deck"]["cycles"] = 2
	if kind == "many_repeats":
		state["turn_queue"][0]["time"] = 1
		for id: int in [2, 3]:
			var foe: Dictionary = state["enemies"][0].duplicate(true)
			foe["id"] = id
			foe["pos"] = Vector2i(2, 3) if id == 2 else Vector2i(2, 5)
			state["enemies"].append(foe)
			var entry: Dictionary = state["turn_queue"][0].duplicate(true)
			entry["enemy_id"] = id
			entry["actor_key"] = "enemy_%d" % id
			entry["time"] = id
			state["turn_queue"].append(entry)
	if kind in ["block_start", "burn"]:
		Ground.place(state, state["player"]["pos"], "fire")
		if kind == "block_start": state["player"]["block"] = 50
	if kind.begins_with("activation_end"):
		if kind == "activation_end_lethal": state["player"]["hp"] = 2
		Ground.place(state, state["player"]["pos"], "ice")
		state["player"]["chilled"] = true
		var rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
		rules.install(Combat.new(), state, {"rule": "frostbite", "source": {"kind": "room"}, "cadence": {"anchor": "after_player_turn", "every": 1}, "dials": {"damage": 2}, "sentence": "Test battlefield rule."})
	if kind == "meteor":
		state["meteor_marks"] = [{"tiles": [state["player"]["pos"]], "damage": 4, "element": "fire", "surface": "", "placed_turn": int(state.get("turn", 1))}]
	if kind == "expose": state["player"]["expose"] = 3
	if kind == "chilled":
		Ground.place(state, state["player"]["pos"], "ice")
		state["player"]["chilled"] = true
	if kind == "bleed":
		state["player"]["bleed"] = 3
		state["enemies"][0]["bleed"] = 3
	if kind in ["reinforcements", "reinforcements_after"]:
		if kind == "reinforcements": state["player_turn_time_spent"] = 12
		state["objective"] = {"type": "survive", "target_clock": 100, "reinforcement_interval": 10, "next_reinforcement_clock": 10, "reinforcement_pool": ["crawler"]}
	if kind == "death_spawn":
		state["enemies"][0]["type"] = "cinder_ooze"
		state["enemies"][0]["hp"] = 5
		state["enemies"][0]["bleed"] = 5
		state["player_turn_time_spent"] = 20
	if kind == "safety_limit":
		state["player_turn_time_spent"] = 1000
		state["enemies"] = []
		state["turn_queue"] = []
		for id: int in range(1, 102):
			var enemy: Dictionary = Fixtures._pass_preview_chip_state("safe")["enemies"][0].duplicate(true)
			enemy["id"] = id
			enemy["intent"] = {"name": "Test Wait", "time": 1, "actions": []}
			state["enemies"].append(enemy)
			state["turn_queue"].append({"kind": "enemy", "enemy_id": id, "time": id, "seq": id})
	if kind == "summon":
		state["enemies"][0]["intent"] = {"name": "Summon", "time": 1, "actions": [{"type": "summon_minions", "minion_type": "crawler", "count": 1}]}
	if kind in ["second_move", "later_known"]:
		state["turn_queue"][0]["time"] = 1
		if kind == "later_known":
			var second: Dictionary = state["enemies"][0].duplicate(true)
			second["id"] = 2
			second["pos"] = Vector2i(2, 3)
			second["intent"]["actions"][0]["damage"] = 2
			state["enemies"].append(second)
			var queued: Dictionary = state["turn_queue"][0].duplicate(true)
			queued["enemy_id"] = 2
			queued["actor_key"] = "enemy_2"
			queued["time"] = 12
			state["turn_queue"].append(queued)
	if kind == "missing_intent": state["enemies"][0]["intent"] = {}
	if kind == "dead_actor":
		var dead: Dictionary = state["enemies"][0].duplicate(true)
		dead["id"] = 2
		dead["hp"] = 0
		state["enemies"].append(dead)
		state["turn_queue"].push_front({"kind": "enemy", "enemy_id": 2, "time": 1})
	if kind == "dead_queue":
		state["turn_queue"].push_front({"kind": "enemy", "enemy_id": 999, "time": 1})
	if kind == "player_tie": state["turn_queue"][0]["time"] = 19
	if kind == "umbra": state = Fixtures._pass_preview_chip_state("umbra")
	return state

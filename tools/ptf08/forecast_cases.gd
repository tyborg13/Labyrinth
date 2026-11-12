extends SceneTree

const Combat = preload("res://scripts/combat_engine.gd")
const CASES = ["safe", "danger", "defiance", "defiance_twice", "defiance_umbra", "fatigue", "fatigue_lethal", "fatigue_defiance", "fatigue_full_hand", "fatigue_empty", "fatigue_cycles", "fatigue_heal", "block_start", "expose", "chilled", "bleed", "burn", "reinforcements", "reinforcements_after", "summon", "death_spawn", "safety_limit", "second_move", "many_repeats", "later_known", "meteor", "activation_end", "activation_end_lethal", "dead_queue", "dead_actor", "missing_intent", "player_tie", "umbra"]
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
			if not preload("res://scripts/pass_forecast_turn_start.gd")._can_project_draw_only(engine, {"state": turn_before}):
				check(forecast["state"] == production_start, kind + ": full receipt path exactly matches production preparation")
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
			check(row_text(scene, summary).contains("fatigue:−15"), kind + ": tooltip draw explanation")
		if kind in ["fatigue_full_hand", "fatigue_empty"]: check(int(summary["fatigue_loss"]) == 0, kind + ": no shuffle means no Fatigue")
		if kind == "fatigue_cycles": check(int(summary["fatigue_loss"]) == 17, "Fatigue includes prior deck cycles")
		if kind == "many_repeats":
			check((summary["repeated_enemy_names"] as Array).size() == 3, "All repeating foes recorded")
			check((summary["repeated_enemy_names"] as Array).size() == 3, "Multiple repeating foes use approved capped wording")
		if kind == "fatigue_heal": check(int(summary["hp_loss"]) == 15 and int(summary["projected_hp"]) == 24 and str(summary["tone"]) == "danger", "Recovery cannot erase Fatigue from the gross loss warning")
		if kind == "fatigue_lethal": check(bool(summary["defeat"]), "Fatigue warns DEFEAT")
		if kind == "fatigue_defiance": check(int(summary["defiance_spent"]) == 1, "Fatigue warns Defiance")
		if kind in ["second_move", "later_known"]:
			check((summary["repeated_enemy_names"] as Array).size() == 1, kind + ": second activation warning")
			var entries: Array[Dictionary] = scene.call("_pass_preview_forecast_entries", summary)
			check(str(entries.back()["text"]) == "+ ? 2ND MOVE", kind + ": explicit label suffix")
		if kind == "safety_limit": check(bool(summary["forecast_limit_reached"]) and row_text(scene, summary).contains("turn_clock:?"), "Bounded partial result cannot claim SAFE")
		if kind == "later_known": check(int(summary["hp_loss"]) == 7, "A repeat cannot hide another foe's announced attack")
		if kind == "activation_end": check(int(summary["hp_loss"]) > 5, "Activation-end pressure included before the announced attack")
		if kind == "block_start": check(int(summary["hp_loss"]) > 0, "Block expires before turn-start fire")
		if kind in ["reinforcements", "death_spawn", "safety_limit", "umbra"]:
			check(uncertain, kind + ": unavailable intent flagged")
		if kind == "defiance":
			check(row_text(scene, summary).contains("defiance:−1 → 4/24"), "Defiance icon and projected Health")
		if kind == "defiance_twice":
			check(int(summary["defiance_spent"]) == 2, "Both actual Defiance charges counted")
			check(row_text(scene, summary).contains("defiance:−2 → 6/24"), "Defiance icon and projected Health")
		if kind == "defiance_umbra":
			check(row_text(scene, summary).contains("defiance:−1 → ?/?") and row_text(scene, summary).contains("umbra:?"), "Hidden ending Health stays unknown after the visible Defiance save")
		if kind in ["defiance", "defiance_twice", "defiance_umbra", "fatigue_defiance"]:
			print("DEFIANCE TOOLTIP %s:\n%s" % [kind, str(scene.call("_pass_preview_tooltip", summary))])
		print("CASE %s: forecast_hp=%d actual_hp=%d loss=%d uncertain=%s" % [kind, int(summary["projected_hp"]), int(after["player"]["hp"]), int(summary["hp_loss"]), str(uncertain)])
	var run_engine := preload("res://scripts/run_engine.gd").new()
	var fixture_run: Dictionary = run_engine.create_new_run(123, preload("res://scripts/progression_store.gd").default_data())
	var defiance_state: Dictionary = fixture("defiance")
	preload("res://tools/ptf08/forecast_probe.gd").apply_defiance_fixture(fixture_run, defiance_state)
	fixture_run["combat_state"] = defiance_state
	var repaired_run: Dictionary = run_engine.repair_loaded_run_state(fixture_run)
	check(int(repaired_run["defiance_capacity"]) == int(defiance_state["defiance_capacity"]) and int(repaired_run["defiance_remaining"]) == int(defiance_state["defiance_remaining"]), "Defiance capture run retains fixture capacity and charges after load repair")
	var repaired_combat: Dictionary = repaired_run["combat_state"]
	var scheduled: Dictionary = engine.finish_player_activation(repaired_combat)
	var forecast: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(scheduled, true)
	var summary: Dictionary = scene.call("_pass_preview_summary_for_phase_result", repaired_combat, forecast)
	check(int(summary["defiance_spent"]) == 1 and row_text(scene, summary).contains("defiance:−1 → 4/24"), "Repaired Defiance capture fixture projects the expected save row")
	preload("res://tools/ptf08/row_tests.gd").run(scene, Callable(self, "check"))
	scene.free()
	print("PTF08 CASES RESULT: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)

static func fixture(kind: String) -> Dictionary:
	return preload("res://tools/ptf07/forecast_cases.gd").fixture(kind)

func row_text(scene: Node, summary: Dictionary) -> String:
	return preload("res://tools/ptf08/row_tests.gd").text(scene, summary)

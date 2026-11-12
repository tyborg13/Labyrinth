extends SceneTree
const Combat = preload("res://scripts/combat_engine.gd")
const Fixtures = preload("res://tools/ptf07/fixtures.gd")
const OUTPUT_DIR: String = "/private/tmp/labyrinth_codex/ptf-07"
const SAMPLE_COUNT: int = 1000
const WARMUP_COUNT: int = 20
const PAIR_ORDERS = ["A/B", "B/A", "A/B"]
var turn_start_samples: Array[int]
var before_samples: Array[int]
var after_samples: Array[int]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var baseline_script := GDScript.new()
	baseline_script.source_code = FileAccess.get_file_as_string(OUTPUT_DIR.path_join("baseline_preview.gd"))
	if baseline_script.reload() != OK:
		print("PTF07 COST RESULT: FAIL (baseline compile)")
		quit(1)
		return
	var before: RefCounted = baseline_script.new()
	var after := Combat.new()
	var state: Dictionary = after.finish_player_activation(Fixtures._pass_preview_chip_state("danger"))
	var diagnostic: Dictionary = after.begin_revealed_enemy_actions_preview(state, true)
	while not bool(diagnostic.get("complete", false)):
		after.advance_revealed_enemy_actions_preview(diagnostic)
	print("PTF07 COST FIXTURE: " + JSON.stringify({"path": diagnostic.get("turn_start_path", ""), "choose_next_intents": diagnostic.get("choose_next_intents"), "room_type": state.get("room_type"), "battlefield_rule": state.get("battlefield_rule", {}), "equipment": state.get("equipped_equipment"), "guard": preload("res://scripts/combat_preview_known_losses.gd").can_defer_unrevealed_selection(after, state)}))
	before.set_runtime_performance_instrumentation_enabled(true)
	after.set_runtime_performance_instrumentation_enabled(true)
	before.set_runtime_performance_interval_sink(func(phase: String, start: int, end: int, _overhead: bool) -> void:
		if phase == "engine_enemy_preview_total": before_samples.append(end - start))
	after.set_runtime_performance_interval_sink(func(phase: String, start: int, end: int, _overhead: bool) -> void:
		if phase == "engine_enemy_preview_total": after_samples.append(end - start)
		if phase == "engine_pass_forecast_turn_start": turn_start_samples.append(end - start))
	var pairs: Array[Dictionary]
	for order: String in PAIR_ORDERS:
		before_samples.clear()
		after_samples.clear()
		turn_start_samples.clear()
		for index: int in range(WARMUP_COUNT + SAMPLE_COUNT):
			if order == "A/B":
				before.preview_revealed_enemy_actions_before_player_turn_with_steps(state, true)
				after.preview_revealed_enemy_actions_before_player_turn_with_steps(state, true)
			else:
				after.preview_revealed_enemy_actions_before_player_turn_with_steps(state, true)
				before.preview_revealed_enemy_actions_before_player_turn_with_steps(state, true)
			if index == WARMUP_COUNT - 1:
				before_samples.clear()
				after_samples.clear()
				turn_start_samples.clear()
		var base: Dictionary = describe(before_samples)
		var candidate: Dictionary = describe(after_samples)
		var pair: Dictionary = {"order": order, "before": base, "after": candidate, "turn_start": describe(turn_start_samples),
			"median_delta_usec": int(candidate["median_usec"]) - int(base["median_usec"]),
			"p99_delta_usec": int(candidate["p99_usec"]) - int(base["p99_usec"])}
		pairs.append(pair)
		print("PTF07 PAIR %d %s: A median=%dus p99=%dus; B median=%dus p99=%dus; delta median=%+dus p99=%+dus; turn-start median=%dus p99=%dus" % [pairs.size(), order, base["median_usec"], base["p99_usec"], candidate["median_usec"], candidate["p99_usec"], pair["median_delta_usec"], pair["p99_delta_usec"], pair["turn_start"]["median_usec"], pair["turn_start"]["p99_usec"]])
	var medians_ok: bool = true
	var p99_min: int = int(pairs[0]["p99_delta_usec"])
	var p99_max: int = p99_min
	for pair: Dictionary in pairs:
		medians_ok = medians_ok and int(pair["median_delta_usec"]) <= 300
		p99_min = mini(p99_min, int(pair["p99_delta_usec"]))
		p99_max = maxi(p99_max, int(pair["p99_delta_usec"]))
	var neutral: bool = medians_ok and p99_min <= 0 and p99_max >= 0
	var report: Dictionary = {"pairs": pairs, "sample_count_per_arm_per_pair": SAMPLE_COUNT, "warmup_count": WARMUP_COUNT, "median_gate": medians_ok, "p99_straddles_zero": p99_min <= 0 and p99_max >= 0, "neutral_gate": neutral}
	var file := FileAccess.open(OUTPUT_DIR.path_join("cost_pairs.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	print("PTF07 COST GATE: %s (median <= +300us in every pair; p99 deltas straddle zero)" % ("PASS" if neutral else "FAIL"))
	quit()

func describe(samples: Array[int]) -> Dictionary:
	var sorted: Array[int] = samples.duplicate()
	sorted.sort()
	return {"median_usec": sorted[sorted.size() / 2], "p99_usec": sorted[ceili(sorted.size() * 0.99) - 1], "samples_usec": samples}

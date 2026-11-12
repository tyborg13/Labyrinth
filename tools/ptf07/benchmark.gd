extends SceneTree
const Combat = preload("res://scripts/combat_engine.gd")
const Fixtures = preload("res://tools/ptf07/fixtures.gd")
const SAMPLE_COUNT: int = 200
const WARMUP_COUNT: int = 10
var samples: Array[int]
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var engine := Combat.new()
	var state: Dictionary = engine.finish_player_activation(Fixtures._pass_preview_chip_state("danger"))
	engine.set_runtime_performance_instrumentation_enabled(true)
	engine.set_runtime_performance_interval_sink(func(phase: String, start: int, end: int, _overhead: bool) -> void:
		if phase == "engine_enemy_preview_total": samples.append(end - start))
	for index: int in range(WARMUP_COUNT + SAMPLE_COUNT):
		engine.preview_revealed_enemy_actions_before_player_turn_with_steps(state, true)
		if index == WARMUP_COUNT - 1: samples.clear()
	samples.sort()
	print("FORECAST COST: n=%d median=%dus p99=%dus" % [samples.size(), samples[samples.size()/2], samples[ceili(samples.size()*0.99)-1]])
	quit()

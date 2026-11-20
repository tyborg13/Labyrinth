extends SceneTree

const Combat = preload("res://scripts/combat_engine.gd")
const Schedule = preload("res://scripts/pass_forecast_red_tiles.gd")
const Fixtures = preload("res://tools/ptf07/forecast_cases.gd")
const Unseen = preload("res://scripts/pass_forecast_unseen_ground.gd")
const Rows = preload("res://tools/ptf08/row_tests.gd")

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var engine := Combat.new()
	var scene: Node = preload("res://scripts/run_scene.gd").new()
	var failures: int = 0
	for sight: String in ["visible", "hidden"]:
		var source: Dictionary = Fixtures.fixture("death_spawn")
		if sight == "hidden": source[Unseen.VISIBLE_KEY] = {}
		var scheduled: Dictionary = Schedule.schedule(engine, source)
		var phase: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(scheduled, true)
		var summary: Dictionary = scene._pass_preview_summary_for_phase_result(source, phase)
		var rows: String = Rows.text(scene, summary)
		var clock: bool = rows.contains("turn_clock:?")
		var umbra: bool = bool(summary.get("umbra_unknown_before_player", false)) and rows.contains("umbra:?")
		if clock != (sight == "visible") or umbra != (sight == "hidden") or scheduled.has(Unseen.BOUNDARY_ARRIVALS):
			failures += 1
		print("QA102 ENEMY-ACTION ARRIVAL sight=%s clock=%s umbra=%s" % [sight, clock, umbra])
	scene.free()
	print("QA102 ENEMY-ACTION ARRIVALS: %d failures" % failures)
	quit(0 if failures == 0 else 1)

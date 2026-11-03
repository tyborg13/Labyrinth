extends "res://tools/encounter_measurement_bot.gd"
## Same revision-7 sampler, tier-3 deck and committed policy v2; observation only.
const DragonObserver = preload("res://tools/dragon_rule_measurement_engine.gd")

func measured_result(policy, measurement_engine, room: Dictionary, sample: Dictionary, presets: Dictionary, measure_usage: bool) -> Dictionary:
	var observer := DragonObserver.new()
	policy.engine = observer
	var result: Dictionary = super.measured_result(policy, measurement_engine, room, sample, presets, measure_usage)
	result["dragon_metrics"] = observer.dragon_metrics()
	return result

extends "res://tools/dragon_rule_measurement.gd"
## Same committed policy and natural revision-7 Warband samples; stratify by rule.
const RUNS_PER_RULE: int = 30

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var tier: int = int(Sweep.option(args,"--tier","1"))
	var selected_rule: String = Sweep.option(args,"--rule","")
	var output: String = Sweep.option(args,"--output","user://bos04_warband.json")
	var policy := CommittedPolicy.new()
	var measurement_engine := MeasurementEngine.new()
	var presets: Dictionary = deck_presets()
	var counts: Dictionary = {}
	var results: Array[Dictionary]
	var seed_value: int = 1
	while results.size() < RUNS_PER_RULE * (6 if selected_rule.is_empty() else 1):
		assert(seed_value < Sweep.MAX_SEED_SCAN)
		var map: Dictionary = Sweep.map_for_seed(seed_value,7)
		for sample: Dictionary in Sweep.samples(map,PackedStringArray(["warband"])):
			if int(sample["tier"]) != tier: continue
			var room: Dictionary = Sweep.layout(sample,map)
			var instance: String = str(room.get("battlefield_rule",{}).get("rule",""))
			# Warband instances install during create_combat, from the order.
			if instance.is_empty():
				var order: Dictionary = preload("res://scripts/warband_combat_rules.gd").order_for_objective(room["objective"])
				instance = str(preload("res://scripts/battlefield_rules/dispatcher.gd").instance_for(str(order["battlefield_instance"]))["rule"])
			if not selected_rule.is_empty() and instance != selected_rule: continue
			if int(counts.get(instance,0)) >= RUNS_PER_RULE: continue
			var result: Dictionary = measured_result(policy,measurement_engine,room,sample,presets,false)
			result["rule"] = instance
			results.append(result)
			counts[instance] = int(counts.get(instance,0))+1
			write_report(output,7,"warband",presets,results)
		seed_value += 1
	print("BOS04 WARBAND MEASUREMENT: PASS (%d runs; tier %d; %s)" % [results.size(),tier,counts])
	quit()

extends "res://tools/encounter_bot.gd"
## meas-02 policy v2, revision-7 selection, stratified by Guardian and natural tier.
const GuardianPolicy = preload("res://scripts/battlefield_rules/bot_policy.gd")
const Adapter = preload("res://tools/guardian_rules_measurement_engine.gd")
const RUNS_PER_TIER: int = 30
const FIRST_SEED: int = 1
const Guardians = preload("res://scripts/guardian_library.gd")

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var variant: String = Sweep.option(args,"--variant","after")
	assert(variant in ["before","pace_only","after"])
	var id: String = Sweep.option(args,"--guardian","ashen_reaver")
	assert(not Guardians.for_guardian(id).is_empty())
	var selected_tier: int = int(Sweep.option(args,"--tier","0"))
	assert(selected_tier in [0,1,2,3])
	var count: int = int(Sweep.option(args,"--runs-per-tier",str(RUNS_PER_TIER)))
	var output: String = Sweep.option(args,"--output","user://guardian_rules_measurement.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var adapter := Adapter.new()
	adapter.configure(variant)
	var tuning_rung: int = int(Sweep.option(args,"--tuning-rung","0"))
	var tuning_round: int = int(Sweep.option(args,"--tuning-round","1"))
	assert(tuning_round in [1,2,3])
	if tuning_rung > 0:
		assert(variant=="after")
		if tuning_round==3: preload("res://tools/guardian_tuning_ladders.gd").apply_final(id,tuning_rung)
		elif tuning_round==2: preload("res://tools/guardian_tuning_ladders.gd").apply_extended(id,tuning_rung)
		else: preload("res://tools/guardian_tuning_ladders.gd").apply(id,tuning_rung)
	var policy := GuardianPolicy.new()
	policy.engine = adapter
	var presets: Dictionary = deck_presets()
	var results: Array[Dictionary]
	var counts: Dictionary = {1:0,2:0,3:0}
	var seed_value: int = FIRST_SEED
	while results.size() < count * (3 if selected_tier==0 else 1):
		assert(seed_value < Sweep.MAX_SEED_SCAN)
		var map: Dictionary = Sweep.map_for_seed(seed_value,7)
		for sample: Dictionary in Sweep.samples(map,PackedStringArray(["guardian"])):
			var tier: int = int(sample["tier"])
			if (selected_tier!=0 and tier!=selected_tier) or counts[tier] >= count: continue
			var room: Dictionary = Sweep.layout(sample,map)
			if room.get("guardian_id","") != id: continue
			var result: Dictionary = policy.run_room(seed_value,room,presets[str(tier)])
			result.merge({"variant":variant,"guardian_id":id,"revision":7,"tier":tier,"biome":sample["biome"],"section_index":sample["section_index"],"coord":Store._sanitize_variant(sample["room"]["coord"]),"travel_dir":Store._sanitize_variant(sample["travel_dir"]),"metrics":adapter.final_metrics.duplicate(true)})
			if tuning_rung>0: result["tuning_rung"] = tuning_rung
			if tuning_rung>0 and tuning_round>=2: result["tuning_round"] = tuning_round
			results.append(result)
			counts[tier] += 1
			write_report(output,7,"guardian",presets,results)
			print("GUARDIAN MEASUREMENT RUN: ",JSON.stringify(result))
		seed_value += 1
	print("GUARDIAN MEASUREMENT: PASS (%s %s; %d runs)" % [variant,id,results.size()])
	quit()

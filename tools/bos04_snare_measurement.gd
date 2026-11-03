extends "res://tools/dragon_rule_measurement.gd"
## Natural revision-7 lightning Snares; unchanged committed policy and tier decks.
const RUNS_PER_TIER: int = 30

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var output: String = Sweep.option(OS.get_cmdline_user_args(),"--output","user://bos04_snare.json")
	var policy := CommittedPolicy.new()
	var measurement_engine := MeasurementEngine.new()
	var presets: Dictionary = deck_presets()
	var results: Array[Dictionary]
	var counts: Dictionary = {1:0,2:0,3:0}
	var seed_value: int = 1
	while results.size() < RUNS_PER_TIER * 3:
		assert(seed_value < Sweep.MAX_SEED_SCAN)
		var map: Dictionary = Sweep.map_for_seed(seed_value,7)
		for sample: Dictionary in _samples(map):
			var tier: int = int(sample["tier"])
			if counts[tier] >= RUNS_PER_TIER: continue
			var room: Dictionary = Sweep.layout(sample,map)
			assert(room["special_type"]=="umbral_snare" and room["special_variant"]=="lightning")
			results.append(measured_result(policy,measurement_engine,room,sample,presets,false))
			counts[tier] += 1
			write_report(output,7,"snare",presets,results)
		seed_value += 1
	print("BOS04 SNARE MEASUREMENT: PASS (%d runs; %s)" % [results.size(),counts])
	quit()

func _samples(map: Dictionary) -> Array[Dictionary]:
	# Sweep's standard cohorts omit Snares. Retain its natural map-room order,
	# tier calculation and first actual incoming edge, without rewriting a room.
	var result: Array[Dictionary]
	for room: Dictionary in map["rooms"].values():
		if room.get("special_type","")!="umbral_snare" or room.get("special_variant","")!="lightning": continue
		var tier: int = Sweep.sample_tier(room)
		if tier not in [1,2,3]: continue
		var travel: Vector2i = Vector2i.ZERO
		for parent: Dictionary in map["rooms"].values():
			for edge: Dictionary in parent.get("connections",[]):
				if edge.get("coord")==room["coord"] and int(parent.get("map_step",-1))<int(room["map_step"]) and parent["section_index"]==room["section_index"]:
					travel = edge["door_dir"]
					break
			if travel!=Vector2i.ZERO: break
		assert(travel!=Vector2i.ZERO,"Snare sample has a real incoming map edge")
		result.append({"seed":int(map["seed"]),"revision":7,"cohort":"snare","tier":tier,"biome":"lightning","section_index":int(room["section_index"]),"room":room.duplicate(true),"travel_dir":travel})
	return result

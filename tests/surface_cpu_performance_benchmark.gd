extends "res://tests/performance_benchmark.gd"

const SurfaceRelics = preload("res://scripts/surface_relic_rules.gd")
const Data = preload("res://scripts/game_data.gd")
const RELIC_LOADOUT: Array = ["ember_lens", "pilgrim_boots", "mirror_shard", "storm_capacitor", "frost_prism", "gale_tabi", "anchor_chain", "venom_signet", "basalt_calendar", "bloodglass_knife", "borrowed_hourglass", "cinderbrand_tongs", "cold_mirror", "dawnstitch_cord", "fivefold_knot", "thunder_relay"]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	var combat := CombatEngine.new()
	var state: Dictionary = _benchmark_combat_state(combat)
	state["relics"] = RELIC_LOADOUT.duplicate()
	state["surfaces"] = {}
	for y: int in range(2, 7):
		for x: int in range(2, 7):
			state["surfaces"]["%d,%d" % [x, y]] = {"elemental": "electrified", "rubble": false}
	var source: Dictionary = state.duplicate(true)
	var errors: Array[String]
	var results: Dictionary = {"schema_version": 1, "workload_id": "surface_relic_and_attack_resolution_v1", "relic_count": RELIC_LOADOUT.size(), "cases": {}}
	_record_metric(results, "relic_expansion_usec", _measure_samples(40, func() -> void:
		Data.relic_effects_for_ids(RELIC_LOADOUT)
	))
	_record_metric(results, "surface_relic_lookup_usec", _measure_samples(40, func() -> void:
		SurfaceRelics.has_effect(state, "conductive_fire")
	))
	var cases: Dictionary = {
		"ranged": {"type": "ranged", "damage": 20, "range": 6},
		"conduction": {"type": "ranged", "damage": 20, "range": 6, "element": "lightning"},
		"chain": {"type": "ranged", "damage": 20, "range": 6, "element": "lightning", "chain": 4},
		"area": {"type": "aoe", "damage": 20, "range": 6, "element": "fire", "surface": "fire", "pattern": [[0,0],[1,0],[-1,0],[0,1],[0,-1]], "rotate": false},
	}
	for name: String in cases:
		var action: Dictionary = cases[name] as Dictionary
		var target := Vector2i(6, 2)
		if not combat.valid_targets_for_player_action(state, action).has(target):
			errors.append("%s target must be legal" % name)
		var reference: Dictionary = combat.resolve_player_action_for_presentation(state, action, target)
		var preview: Dictionary = combat.surface_preview_for_player_action(state, action, target)
		if preview.get("state") != reference.get("state"): errors.append("%s surface preview final state differs" % name)
		if _route_digest(preview.get("chain_hits", [])) != _route_digest(reference.get("chain_hits", [])): errors.append("%s surface preview route differs" % name)
		var entry: Dictionary = {"state_digest": hash(preview.get("state")), "route_digest": _route_digest(preview.get("chain_hits", [])), "route_hits": (preview.get("chain_hits", []) as Array).size()}
		_record_metric(entry, "preview_usec", _measure_samples(8, func() -> void:
			combat.surface_preview_for_player_action(state, action, target)
		))
		_record_metric(entry, "apply_usec", _measure_samples(8, func() -> void:
			combat.apply_prevalidated_player_action(state, action, target)
		))
		combat.set_runtime_performance_instrumentation_enabled(true)
		combat.surface_preview_for_player_action(state, action, target)
		entry["profile"] = combat.runtime_performance_instrumentation_snapshot()
		combat.set_runtime_performance_instrumentation_enabled(false)
		(results["cases"] as Dictionary)[name] = entry
	if state != source: errors.append("surface CPU benchmark mutated its source state")
	results["semantic_errors"] = errors
	results["static_memory_bytes"] = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	print("SURFACE CPU PERF RESULT: %s" % JSON.stringify(results))
	quit(0 if errors.is_empty() else 1)

func _route_digest(hits: Array) -> int:
	var metadata: Array = []
	for hit: Dictionary in hits:
		var entry: Dictionary = hit.duplicate(false)
		entry.erase("state")
		metadata.append(entry)
	return hash(metadata)

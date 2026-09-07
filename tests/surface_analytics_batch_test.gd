extends SceneTree

const Store = preload("res://scripts/analytics_store.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")

class CountingStore:
	extends "res://scripts/analytics_store.gd"
	var batches: int = 0
	var singles: int = 0
	var fail_after_prefix: bool = false
	func write_event(event_type: String, context: Dictionary = {}, payload: Dictionary = {}, key: String = "") -> bool:
		singles += 1
		return super.write_event(event_type, context, payload, key)
	func write_events(events: Array) -> bool:
		batches += 1
		if fail_after_prefix:
			fail_after_prefix = false
			super.write_events(events.slice(0, 2))
			return false
		return super.write_events(events)

class CountingScene:
	extends "res://scripts/run_scene.gd"
	var contexts: int = 0
	func _analytics_context_from_states(run: Dictionary, combat: Dictionary = {}, card_id: String = "", instance_id: String = "") -> Dictionary:
		contexts += 1
		return super._analytics_context_from_states(run, combat, card_id, instance_id)

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Store.set_storage_dir("user://surface_batch_proof")
	Store.clear_storage()
	var combat := preload("res://scripts/combat_engine.gd").new()
	var state: Dictionary = preload("res://tests/suites/chain_attack_suite.gd").fixture(combat)
	state["analytics"] = {"combat_id": "surface_batch_proof"}
	for y: int in range(1, 8):
		for x: int in range(1, 8): Ground.place(state, Vector2i(x, y), "fire", {"card_id": "wildfire_halo", "player_card": true})
	var run: Dictionary = Run.new().create_new_run(4399, Progression.default_data())
	run["combat_state"] = state
	run["mode"] = "combat"
	run["relics"] = ["ember_lens", "pilgrim_boots", "mirror_shard", "storm_capacitor", "frost_prism", "gale_tabi", "anchor_chain", "venom_signet", "basalt_calendar", "bloodglass_knife", "borrowed_hourglass", "cinderbrand_tongs", "cold_mirror", "dawnstitch_cord", "fivefold_knot", "thunder_relay"]
	state["relics"] = run["relics"].duplicate()
	var source: Dictionary = state.duplicate(true)
	var scene := CountingScene.new()
	var store := CountingStore.new()
	scene.set("_analytics_store", store)
	var samples: Array[float]
	for trial: int in range(7):
		state["analytics"]["combat_id"] = "surface_batch_%d" % trial
		var started: int = Time.get_ticks_usec()
		scene.call("_analytics_flush_surface_events", state, run)
		samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
	var events: Array = Store.load_all_events()
	var count: int = (state.get("surface_events", []) as Array).size()
	assert(count >= 30 and events.size() == count * 7, "Every authored event at every committed boundary must append")
	assert(state["surface_events"] == source["surface_events"], "Flush must not mutate source event payloads")
	for i: int in range(events.size()):
		var expected: Dictionary = state["surface_events"][i % count]
		assert(events[i]["payload"]["sequence"] == expected["sequence"], "JSONL preserves event order")
		assert(int(events[i]["payload"]["tile"]["x"]) == expected["tile"].x and int(events[i]["payload"]["tile"]["y"]) == expected["tile"].y, "JSONL preserves each event tile")
	print("SURFACE ANALYTICS PERF RESULT: %s" % JSON.stringify({"workload_id": "committed_surface_batch_v1", "event_count": count, "samples_ms": samples, "context_builds": scene.contexts, "batch_writes": store.batches, "single_writes": store.singles, "semantic_errors": []}))
	if OS.get_environment("LABYRINTH_SURFACE_ANALYTICS_BENCHMARK_ONLY") == "1":
		scene.free()
		quit()
		return
	assert(scene.contexts == 7 and store.batches == 7 and store.singles == 0, "One committed boundary builds one context and performs one batch append")
	var previous_contexts: int = scene.contexts
	scene.call("_analytics_flush_surface_events", state, run)
	assert(scene.contexts == previous_contexts and store.batches == 7, "Repeated snapshots must avoid context and I/O work")
	# Simulate a disk error after an append prefix. Cursor cannot acknowledge a
	# failed batch; retry and a new scene both deduplicate the durable prefix.
	state["analytics"]["combat_id"] = "surface_partial_append"
	store.fail_after_prefix = true
	scene.call("_analytics_flush_surface_events", state, run)
	assert(not (scene.get("_surface_analytics_revisions") as Dictionary).has("surface_partial_append"), "Partial append must not advance the cursor")
	assert(Store.load_all_events().size() == count * 7 + 2)
	scene.call("_analytics_flush_surface_events", state, run)
	assert(Store.load_all_events().size() == count * 8, "Retry must complete the entire batch without duplicates")
	scene.free()
	var resumed := CountingScene.new()
	resumed.call("_analytics_flush_surface_events", state, run)
	assert(Store.load_all_events().size() == count * 8, "Restart replay must remain idempotent")
	resumed.free()
	print("TEST RESULT: PASS surface analytics batch and partial append recovery")
	quit()

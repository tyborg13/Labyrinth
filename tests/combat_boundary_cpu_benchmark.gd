extends SceneTree
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const Fixture = preload("res://tests/suites/card_playability_summary_suite.gd")
const HAND: Array = ["threaded_path", "sidestep_slash", "pale_spark", "wildfire_halo", "shadow_step", "gust_step", "thunderline"]
const RELICS: Array = ["ember_lens", "pilgrim_boots", "mirror_shard", "storm_capacitor", "frost_prism", "gale_tabi", "anchor_chain", "venom_signet", "basalt_calendar", "bloodglass_knife", "borrowed_hourglass", "cinderbrand_tongs", "cold_mirror", "dawnstitch_cord", "fivefold_knot", "thunder_relay"]
const SKILLS: Array = ["quick_wits", "encore", "prismatic_instinct", "rehearsed_escape", "makeshift_tool", "carry_the_guard", "sure_footed", "afterimage", "borrowed_time", "last_reserve", "plunderers_step", "living_shadow", "open_arsenal", "confluence", "long_dawn", "witchlight", "dawnbrand"]
func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	var scene := RunScene.new()
	var combat := CombatEngine.new()
	var engine := RunEngine.new()
	var profile: Dictionary = ProgressionStore.default_data()
	profile["level"] = 14
	profile["skill_ids"] = SKILLS.duplicate()
	var run: Dictionary = engine.create_new_run(20260917, profile)
	var results: Dictionary = {}
	for fixture: String in ["open", "dense", "surface_ready", "heart"]:
		var state: Dictionary = Fixture._fixture(combat, fixture)
		state["relics"] = RELICS.duplicate()
		state["skill_ids"] = SKILLS.duplicate()
		Fixture._set_hand(state, HAND)
		scene.set("_combat_state", state)
		run["mode"] = "combat"
		run["combat_state"] = state.duplicate(true)
		scene.set("_run_state", run)
		scene.set("_progression", profile)
		var case: Dictionary = {}
		case["hand_flags"] = measure(func():
			scene.call("_mark_combat_preview_state_changed")
			for i: int in range(HAND.size()): scene.call("_card_playability_for_index", i))
		case["hand_display"] = measure(func():
			for card: String in HAND: scene.call("_card_widget_display", card, state))
		case["context"] = measure(func(): scene.call("_analytics_context_from_states", run, state))
		case["checkpoint_sync"] = measure(func(): engine.set_combat_state(run, state))
		case["profile_normalize"] = measure(func(): ProgressionStore.normalized_data(profile))
		results[fixture] = case
	scene.free()
	print("BOUNDARY CPU PERF RESULT: " + JSON.stringify({"workload_id": "seven_card_boundary_cpu_v1", "iterations": 24, "metric": "synchronous CPU microseconds; not rendered frame time", "cases": results}))
	quit()
func measure(action: Callable) -> Dictionary:
	action.call()
	var values: Array[int]
	for repeat: int in range(24):
		var start: int = Time.get_ticks_usec()
		action.call()
		values.append(Time.get_ticks_usec() - start)
	values.sort()
	return {"median_usec": values[12], "p95_usec": values[22], "max_usec": values[23], "samples_usec": values}

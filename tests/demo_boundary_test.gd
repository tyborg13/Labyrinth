extends "res://tests/run_tests.gd"

const DemoGraph = preload("res://scripts/section_map_graph.gd")
const DemoChronicle = preload("res://scripts/chronicle_rules.gd")
const DemoRules = preload("res://scripts/demo_rules.gd")
const DemoBuild = preload("res://scripts/demo_build.gd")
const DemoSnapshots = preload("res://scripts/analytics_snapshots.gd")
const DemoSkills = preload("res://scripts/skill_tree_library.gd")
const DemoTypedArrays = preload("res://scripts/typed_arrays.gd")
const DemoScore = preload("res://scripts/run_score_rules.gd")
const DemoBosses = preload("res://scripts/dragon_boss_library.gd")
const DemoRecap = preload("res://scripts/run_end_recap_overlay.gd")
const DemoRunScene = preload("res://scripts/run_scene.gd")
const DemoChronicleSuite = preload("res://tests/suites/chronicle_suite.gd")
const DemoSkillSuite = preload("res://tests/suites/skill_tree_suite.gd")
const FIXTURE_SEED: int = 2902
const FIXTURE_LOW_HP: int = 9
const PROMPT_FIXTURE_RUN_INDEX: int = 50
const DEMO_ENV: String = "LABYRINTH_DEMO"
# Run goldens re-captured on codex/release d6e088d7a (no demo code) when release was merged in;
# profile goldens unchanged from 76664b3e2. Profile save/load
# goldens captured by executing that revision's original store source. Hash the complete Variant bytes,
# including field order and nested values; full-game zero-depth stays sparse.
const FULL_GOLDEN := {
	"saved_profile_json": "73d6d7544b1b04d75f88b7ae9d51427dd51a92dae0392d135647821348d02389",
	"resumed_profile": "c23ced3bfa78be966eefa10ff3ab7b78e832624c2f6eaebe6eb342fd75504a68",
	"profile": "55cf35f832e2e7ecb29c52f8397498e1e6440dd818508ae2abc9bdb6d3929d99",
	"new_run": "d520c7c0457c7007becfd1ecc5e90c117d2815e1dddfb2767354ba3889ebbbbb",
	"resumed_run": "c2ac2b53c65eae33430c92de413f180ea71cddebd76ee9e22a6f6c030e686a4e",
	"continued": "49b978daaf2ff6c1d1478150d7033da0ce04fa13fdd65cdbdde448905a2616b5",
	"continued_mode": "room", "continued_section": 0,
	"next_section": "3616399da1a22e27a6248b2b2343509f53cde6e246a07c8af18cd16a339a77e0",
	"next_mode": "room", "next_section_index": 1,
}

func _initialize() -> void:
	_initialize_test_storage()
	var had_flag: bool = OS.has_environment(DEMO_ENV)
	var previous_flag: String = OS.get_environment(DEMO_ENV)
	_set_demo(false)
	if OS.get_cmdline_user_args().has("--existing-core"):
		DemoChronicleSuite.run(_assert)
		DemoSkillSuite.run(_assert)
		_test_progression_save_and_purchase(ProgressionStore.default_data())
	else:
		_test_full_golden()
		_set_demo(true)
		_test_config_and_cutoff()
		_test_demo_clear()
		_test_save_guard()
		_test_prompt_rule()
		_test_interrupted_embrace_prompt_receipt()
		_test_demo_chronicle_location()
		_test_keystones()
	if had_flag:
		OS.set_environment(DEMO_ENV, previous_flag)
	else:
		OS.unset_environment(DEMO_ENV)
	for failure: String in _failures:
		push_error(failure)
	var label: String = "DMO-02 EXISTING CORE" if OS.get_cmdline_user_args().has("--existing-core") else "DEMO BOUNDARY"
	print("%s TEST RESULT: %s (%d assertions)" % [label, "PASS" if _failures.is_empty() else "FAIL", _assertion_count])
	quit(0 if _failures.is_empty() else 1)

func _set_demo(enabled: bool) -> void:
	OS.set_environment(DEMO_ENV, "1" if enabled else "0")
	_assert(DemoBuild.is_demo() == enabled, "dmo-01 editor env hook selects the requested build")

func _test_full_golden() -> void:
	var engine := RunEngine.new()
	var profile: Dictionary = ProgressionStore.default_data()
	var state: Dictionary = engine.create_new_run(FIXTURE_SEED, profile)
	_assert(_fingerprint(profile) == FULL_GOLDEN["profile"], "Full new profile bytes match the before-change golden")
	_assert(_fingerprint(state) == FULL_GOLDEN["new_run"], "Full new run bytes match the before-change golden")
	_assert(_fingerprint(engine.repair_loaded_run_state(state)) == FULL_GOLDEN["resumed_run"], "Full resumed run bytes match the before-change golden")
	_assert(not state.has("build_kind") and not profile.has("build_kind") and not profile.has(DemoRules.LINKS_PROMPT_RUN_KEY), "Full state has no new demo fields")
	_assert(ProgressionStore.save_data(profile), "Full profile saves")
	_assert(FileAccess.get_file_as_string(ProgressionStore._storage_path).sha256_text() == FULL_GOLDEN["saved_profile_json"], "Full saved profile JSON bytes match the original store golden")
	_assert(_fingerprint(ProgressionStore.load_data()) == FULL_GOLDEN["resumed_profile"], "Full resumed profile Variant bytes match the original store golden")
	_assert(not ProgressionStore.load_data().has("build_kind"), "Full save does not stamp a profile")
	_assert(ProgressionStore.save_run_state(state) and _fingerprint(ProgressionStore.load_saved_run()) == FULL_GOLDEN["new_run"], "Full run round-trips with identical bytes")
	var resumed: Dictionary = engine.repair_loaded_run_state(ProgressionStore.load_saved_run())
	_assert(_fingerprint(resumed) == FULL_GOLDEN["resumed_run"], "Full save resume keeps golden bytes")
	_test_analytics(engine, state, "full")
	state = _dragon_fixture(engine, profile)
	state = engine.finish_combat(state, state["combat_state"])
	state = engine.continue_dragon_reward(state)
	_assert(state["mode"] == FULL_GOLDEN["continued_mode"] and DemoGraph.active_section(state) == FULL_GOLDEN["continued_section"], "Full dragon Continue keeps its original mode and section")
	_assert(_fingerprint(state) == FULL_GOLDEN["continued"], "Full dragon reward/Continue bytes match the before-change golden")
	for coord: Vector2i in engine.available_moves(state):
		if int(engine.room_metadata(state, coord).get("section_index", 0)) == 1:
			state = engine.move_to_room(state, coord)
			break
	_assert(state["mode"] == FULL_GOLDEN["next_mode"] and DemoGraph.active_section(state) == FULL_GOLDEN["next_section_index"], "Full first dragon opens section 2 exactly as before")
	_assert(_fingerprint(state) == FULL_GOLDEN["next_section"], "Full section transition bytes match the before-change golden")

func _test_config_and_cutoff() -> void:
	var config: Dictionary = DemoRules.config()
	_assert(config == JSON.parse_string(FileAccess.get_file_as_string(DemoRules.CONFIG_PATH)), "Config loads director data verbatim")
	config["last_section_index"] = 99
	config["text"]["wishlist"] = "fixture mutation"
	_assert(DemoRules.last_section_index() == 0 and DemoRules.config()["text"]["wishlist"] != "fixture mutation", "Config returns deep owned copies")
	_assert(not DemoRules.is_past_cutoff(_hearth_state(0, false)), "First-section run is within cutoff")
	_assert(DemoRules.is_past_cutoff(_hearth_state(1, true)), "Second-section run is past cutoff")
	_assert(not DemoRules.reached_hearth(_hearth_state(0, false)), "Unvisited Hearth does not qualify")
	_assert(not DemoRules.reached_hearth(_hearth_state(1, true)), "Hearth beyond cutoff does not qualify")

func _test_demo_clear() -> void:
	var engine := RunEngine.new()
	var original: Dictionary = _dragon_fixture(engine, ProgressionStore.default_data())
	_assert(original.get("build_kind") == "demo", "Demo new run is stamped")
	var state: Dictionary = engine.finish_combat(original, original["combat_state"])
	var reward: Dictionary = state["pending_reward"]
	_assert(engine.is_dragon_reward(state) and bool(reward["final_boss"]), "Cutoff dragon holds the final reward")
	_assert((state["relics"] as Array).has(DemoBosses.relic_for_boss(str(reward["boss_id"]))), "Cutoff dragon still grants its relic")
	_assert(int(state["progression"]["moltshards"]) == 1 and int(reward["moltshards"]) == 1, "Cutoff dragon grants one Moltshard")
	_assert(int(state["player_hp"]) == FIXTURE_LOW_HP + ceili(float(state["player_max_hp"]) * RunEngine.BOSS_VICTORY_HEAL_FRACTION), "Demo keeps the existing dragon victory heal")
	_assert(engine.finish_combat(state, original["combat_state"]) == state, "Stale combat cannot duplicate dragon rewards")
	state = engine.continue_dragon_reward(state)
	_assert(state["mode"] == "victory" and bool(state["victory"]), "Cutoff reward Continue ends the demo in victory")
	_assert(DemoGraph.active_section(state) == 0 and (state["chronicle_path"] as Array).size() == 1, "Demo never enters section 1")
	for room: Dictionary in state["rooms"].values():
		_assert(int(room.get("section_index", 0)) == 0 or not bool(room.get("visited", false)), "No later-section room is visited")
	_assert(engine.move_to_room(state, DemoGraph.section(state, 1)["entry"]) == state, "Demo terminal refuses travel into the next section")
	_assert(engine.continue_dragon_reward(state) == state, "Demo Continue is idempotent")
	_assert(DemoRules.is_demo_clear(state, "victory") and not DemoRules.is_demo_clear(state, "embrace"), "Demo clear predicate follows build and outcome")
	_assert(DemoRules.end_panel_kind(state, "victory", {}) == "full", "Demo victory always gets the full panel")
	var profile: Dictionary = ProgressionStore.default_data()
	profile["umbra_depth_unlocked"] = 3
	profile["chronicle_totals"] = {"runs": 4, "escapes": 2, "deepest_depth": 2}
	var result_id: String = RunEngine.run_result_id(state)
	var recorded: Dictionary = ProgressionStore.record_run_result(profile, result_id, state["run_stats"], state, "victory")
	var totals: Dictionary = ProgressionStore.chronicle_totals(recorded["data"])
	_assert(recorded["recorded"] and recorded["data"]["umbra_depth_unlocked"] == 3, "Demo clear leaves Depth unlock unchanged")
	_assert(totals["escapes"] == 2 and totals["deepest_depth"] == 2 and totals["demo_clears"] == 1, "Demo clear counts separately from escapes and deepest Depth")
	_assert(ProgressionStore.chronicle_totals(ProgressionStore.record_run_result(recorded["data"], result_id, {}, state, "victory")["data"]) == totals, "Demo clear replay cannot duplicate totals")
	var record: Dictionary = ProgressionStore.chronicle_records(recorded["data"])[0]
	_assert(DemoChronicle.result_word(record) == DemoScore.seeded_text(result_id, "demo_clear")["title"], "Chronicle label comes from approved demo_clear title")
	_assert(DemoScore.score(state, "victory") == DemoScore.score(state, "embrace"), "Demo scores like Embrace, including dragon rows")
	for row: Dictionary in recorded["result"]["lines"] + recorded["result"]["feats"]:
		_assert(str(row["id"]) not in ["escaped", "swift", "ascetic", "last_light"], "Demo score excludes victory-only rows")
	# Exercise both depth-unlock gates even with edited late-game stats, and the
	# production score-only adapter used by RunScene (which is not modified).
	for depth: int in [0, 20]:
		var edited: Dictionary = state.duplicate(true)
		edited["run_index"] += depth + 1
		edited["umbra_depth"] = depth
		edited["run_stats"]["dragons_slain"] = ["noctyrax"]
		edited["run_stats"]["defiance_spent"] = 1
		var fresh: Dictionary = ProgressionStore.default_data()
		fresh["umbra_depth_unlocked"] = depth
		var adapter: Dictionary = ProgressionStore.record_run_result(fresh, RunEngine.run_result_id(edited), DemoRecap.result_stats(edited))
		_assert(adapter["data"]["umbra_depth_unlocked"] == depth and not bool(adapter["data"].get("umbra_depth_twenty_escaped", false)), "Demo cannot unlock Depths even with Noctyrax stats")
		_assert(not ProgressionStore.chronicle_totals(adapter["data"]).has("deepest_depth") and ProgressionStore.chronicle_totals(adapter["data"])["demo_clears"] == 1, "Production adapter does not manufacture a deepest escape")
		_assert(not DemoScore.score(edited, "victory")["feats"].any(func(row: Dictionary) -> bool: return str(row["id"]) in ["swift", "ascetic", "last_light"]), "Qualifying demo stats still earn no victory-only feats")
	_assert(ProgressionStore.save_data(recorded["data"]), "Demo profile transaction saves")
	var saved: Dictionary = ProgressionStore.load_data()
	_assert(saved["build_kind"] == "demo" and saved["chronicle_totals"]["demo_clears"] == 1, "Demo profile stamp and sparse totals survive reload")
	_assert(not recorded["data"].has("build_kind"), "Saving does not mutate caller data")
	_test_analytics(engine, state, "demo")

func _test_save_guard() -> void:
	var engine := RunEngine.new()
	var state: Dictionary = engine.create_new_run(FIXTURE_SEED, ProgressionStore.default_data())
	_assert(ProgressionStore.save_run_state(state) and ProgressionStore.load_saved_run() == state, "Legal demo save round-trips")
	state["current_room"] = DemoGraph.section(state, 1)["entry"]
	_assert(ProgressionStore.save_run_state(state), "Edited section-1 fixture writes")
	var saved_bytes: PackedByteArray = FileAccess.get_file_as_bytes(ProgressionStore._run_storage_path)
	_assert(ProgressionStore.load_saved_run().is_empty(), "Demo rejects a save past cutoff")
	_assert(FileAccess.get_file_as_bytes(ProgressionStore._run_storage_path) == saved_bytes, "Rejected save is not deleted or rewritten")
	var legal_backup: Dictionary = state.duplicate(true)
	legal_backup["current_room"] = Vector2i.ZERO
	var backup: FileAccess = FileAccess.open(ProgressionStore._run_backup_path(), FileAccess.WRITE)
	backup.store_var(legal_backup)
	backup.close()
	_assert(ProgressionStore.load_saved_run().is_empty(), "Rejected live save cannot fall back to an older legal backup")
	state["current_room"] = Vector2i.ZERO
	state.erase("build_kind")
	_assert(ProgressionStore.save_run_state(state) and ProgressionStore.load_saved_run().is_empty(), "Demo rejects an unstamped save")
	state["build_kind"] = "demo"
	_assert(ProgressionStore.save_run_state(state), "Demo-stamped fixture writes")
	_set_demo(false)
	_assert(ProgressionStore.load_saved_run().is_empty(), "Full build rejects a demo-stamped save")
	_set_demo(true)
	# Recovery still selects a valid backup for a corrupt live file, then guards it.
	var file: FileAccess = FileAccess.open(ProgressionStore._run_backup_path(), FileAccess.WRITE)
	file.store_var(state)
	file.close()
	file = FileAccess.open(ProgressionStore._run_storage_path, FileAccess.WRITE)
	file.store_var([])
	file.close()
	_assert(ProgressionStore.load_saved_run() == state, "Demo preserves torn-write backup recovery for a legal save")
	_set_demo(false)
	_assert(ProgressionStore.load_saved_run().is_empty(), "Full guard also rejects a recovered demo backup")
	_set_demo(true)
	ProgressionStore.clear_saved_run()

func _test_prompt_rule() -> void:
	var state: Dictionary = _hearth_state(0, false)
	_assert(DemoRules.end_panel_kind(state, "defeat", {}) == "none", "Death before Hearth gives no prompt")
	state = _hearth_state(0, true)
	var before: Dictionary = state.duplicate(true)
	_assert(DemoRules.end_panel_kind(state, "defeat", {}) == "links" and state == before, "First post-Hearth death gives links without mutating state")
	var result_id: String = RunEngine.run_result_id(state)
	var recorded: Dictionary = ProgressionStore.record_run_result(ProgressionStore.default_data(), result_id, {}, state, "defeat")
	var profile: Dictionary = recorded["data"]
	_assert(profile[DemoRules.LINKS_PROMPT_RUN_KEY] == result_id, "Recording links stamps the terminal ID in the same transaction")
	_assert(ProgressionStore.save_data(profile) and ProgressionStore.load_data()[DemoRules.LINKS_PROMPT_RUN_KEY] == result_id, "Prompt flag survives restart")
	_assert(DemoRules.end_panel_kind(state, "defeat", profile) == "links", "Same terminal replay retains links")
	_assert(ProgressionStore.record_run_result(profile, result_id, {}, state, "defeat")["data"] == profile, "Same terminal recording is idempotent")
	state["run_index"] += 1
	_assert(DemoRules.end_panel_kind(state, "defeat", profile) == "none", "Later post-Hearth death gets no links")
	_assert(DemoRules.end_panel_kind(state, "embrace", profile) == "none", "Later Embrace also respects the prompt receipt")
	_assert(DemoRules.end_panel_kind(state, "embrace", {}) == "links", "Fresh-profile Embrace gets links")
	_assert(DemoRules.end_panel_kind(state, "victory", profile) == "full", "Clear panel ignores an earlier links receipt")
	_assert(DemoRules.end_panel_kind(state, "room", {}) == "none", "Nonterminal mode gets no links")
	# Test the actual score-only terminal recording convention, including a
	# pre-Chronicle run with no path marker.
	for outcome: String in ["defeat", "embrace"]:
		state["mode"] = outcome
		state.erase(DemoChronicle.PATH_KEY)
		var adapter_id: String = RunEngine.run_result_id(state)
		var adapter: Dictionary = ProgressionStore.record_run_result(ProgressionStore.default_data(), adapter_id, DemoRecap.result_stats(state))
		_assert(adapter["data"][DemoRules.LINKS_PROMPT_RUN_KEY] == adapter_id, "Production %s adapter records the prompt receipt" % outcome)
		_assert(not str(adapter["data"]).contains("_demo_links_eligible"), "Transient prompt metadata never enters the profile")
	_set_demo(false)
	_assert(DemoRules.end_panel_kind(state, "victory", {}) == "none" and DemoRules.end_panel_kind(state, "defeat", {}) == "none", "Full builds never show demo panels")
	_assert(not DemoRules.is_demo_clear(state, "victory"), "Full victory is not a demo clear")
	_set_demo(true)

func _hearth_state(section_index: int, visited: bool) -> Dictionary:
	return {"seed": FIXTURE_SEED, "run_index": PROMPT_FIXTURE_RUN_INDEX, "mode": "defeat", "current_room": Vector2i.ZERO, "rooms": {"0,0": {"type": "campfire", "section_index": section_index, "visited": visited}}}

func _test_interrupted_embrace_prompt_receipt() -> void:
	var engine := RunEngine.new()
	var profile: Dictionary = ProgressionStore.default_data()
	var campfire: Dictionary = engine.create_new_run(FIXTURE_SEED, profile)
	for room: Dictionary in campfire["rooms"].values():
		if str(room.get("type", "")) == "campfire" and int(room.get("section_index", -1)) == 0:
			campfire["current_room"] = room["coord"]
			room["visited"] = true
			room["revealed"] = true
			break
	campfire["mode"] = "campfire"
	_assert(DemoRules.reached_hearth(campfire), "Interrupted Embrace fixture has visited the first Hearth")
	_assert(ProgressionStore.save_data(profile) and ProgressionStore.save_run_state(campfire), "Original campfire profile and snapshot save")
	# Interrupt exactly between Embrace's successful profile save and run clear.
	var withdrawal: Dictionary = DemoRecap.embrace_state(campfire, ProgressionStore.mark_rested_at_fire(profile))
	var receipt_id: String = RunEngine.run_result_id(withdrawal)
	_assert(ProgressionStore.save_data(withdrawal["progression"]), "Embrace profile commits before the interruption")
	var committed: Dictionary = ProgressionStore.load_data()
	_assert(str(committed.get(DemoRules.LINKS_PROMPT_RUN_KEY, "")) == receipt_id, "Interrupted Embrace has a durable prompt receipt")
	_assert(int(committed["progression_revision"]) == int(profile["progression_revision"]) + 1, "First links receipt advances progression revision once")
	var replay: Dictionary = ProgressionStore.record_run_result(committed, receipt_id, DemoRecap.result_stats(withdrawal))
	_assert(replay["data"]["progression_revision"] == committed["progression_revision"], "Terminal replay does not advance the receipt revision again")
	# Exercise Continue's production merge, revision reconciliation, sync and
	# inverse repair helpers without constructing or rendering the scene's UI.
	var host := DemoRunScene.new()
	var resumed: Dictionary = _resume_receipt_fixture(host, ProgressionStore.load_saved_run())
	_assert(str(resumed["progression"].get(DemoRules.LINKS_PROMPT_RUN_KEY, "")) == receipt_id, "Continue keeps the newer profile's receipt over the stale campfire snapshot")
	# Save & Quit writes this active profile before its explicit run checkpoint.
	_assert(ProgressionStore.save_data(host.get("_progression")) and ProgressionStore.save_run_state(resumed), "Save & Quit persists the resumed profile and checkpoint")
	var after_quit: Dictionary = ProgressionStore.load_data()
	_assert(str(after_quit.get(DemoRules.LINKS_PROMPT_RUN_KEY, "")) == receipt_id, "Save & Quit cannot overwrite the durable prompt receipt")
	var later: Dictionary = _hearth_state(0, true)
	later["run_index"] = int(campfire["run_index"]) + 1
	_assert(DemoRules.end_panel_kind(later, "defeat", after_quit) == "none", "Interrupted Embrace, Continue and Save & Quit leave later deaths ineligible for links")
	# The inverse torn write keeps the receipt in a newer embedded profile while
	# the old standalone profile remains authoritative for banked currency.
	resumed = engine.apply_progression_update(resumed, ProgressionStore.add_moltshards(resumed["progression"]))
	_assert(ProgressionStore.save_run_state(resumed) and ProgressionStore.save_data(profile), "Run-first repair fixture saves a newer run beside the old profile")
	resumed = _resume_receipt_fixture(host, ProgressionStore.load_saved_run())
	var repaired: Dictionary = ProgressionStore.load_data()
	_assert(str(repaired.get(DemoRules.LINKS_PROMPT_RUN_KEY, "")) == receipt_id, "Newer embedded progression backfills its receipt after an interrupted profile write")
	_assert(int(repaired["embers"]) == int(profile["embers"]) and int(repaired["moltshards"]) == int(resumed["progression"]["moltshards"]), "Receipt recovery preserves existing banked-currency and newer-progression repair rules")
	_assert(DemoRules.end_panel_kind(later, "defeat", repaired) == "none", "Run-first repair also keeps later deaths ineligible for links")
	host.free()
	ProgressionStore.clear_saved_run()

func _resume_receipt_fixture(host: Node, saved_run: Dictionary) -> Dictionary:
	host.set("_progression", ProgressionStore.load_data())
	var merged: Dictionary = preload("res://scripts/loaded_room_state.gd").merge_profile(saved_run, host.get("_progression"))
	var engine: RefCounted = host.get("_run_engine")
	var resumed: Dictionary = engine.repair_loaded_run_state(engine.reconcile_progression_revision(merged, host.get("_progression")))
	host.set("_run_state", resumed)
	host.call("_sync_progression_from_run")
	host.call("_repair_profile_progression_from_run")
	return resumed

func _test_demo_chronicle_location() -> void:
	var engine := RunEngine.new()
	var state: Dictionary = _dragon_fixture(engine, ProgressionStore.default_data())
	state = engine.continue_dragon_reward(engine.finish_combat(state, state["combat_state"]))
	var record: Dictionary = DemoChronicle.build_record(state, "victory", DemoScore.score(state, "victory"))
	var first_dragon: String = str(DemoGraph.section(state, 0)["boss_id"])
	var expected: String = "%s falls" % DemoScore.dragon_name(first_dragon)
	_assert(DemoChronicle.where_text(record) == expected, "Demo history row names the run's section-0 dragon")
	_assert(DemoChronicle.subline(record).begins_with(expected + " · "), "Demo detail subline names the same section-0 dragon")
	_assert(record["killer_text"] == expected, "Demo clear record stores its actual dragon's terminal cause")
	# Already-saved records contain the first boss id but the old Noctyrax text.
	var old_demo: Dictionary = {"outcome": "victory", "demo_clear": true, "dragon_ids": ["vyraketh", "noctyrax"], "killer_text": "Noctyrax falls", "run_seconds": 120.0}
	old_demo = DemoChronicle.normalized_record(old_demo.merged({"run_id": "demo-chronicle-location-fixture"}))
	_assert(DemoChronicle.where_text(old_demo) == "Vyraketh falls", "Stored demo history uses the first dragon's short name and no period")
	_assert(DemoChronicle.subline(old_demo) == "Vyraketh falls · 2 min", "Stored demo detail uses the approved first-dragon copy")
	_set_demo(false)
	var full: Dictionary = old_demo.duplicate(true)
	full.erase("demo_clear")
	_assert(DemoChronicle.where_text(full) == "Noctyrax falls", "Full-game victory history text stays unchanged")
	_assert(DemoChronicle.subline(full) == "Noctyrax falls · 2 min", "Full-game victory detail text stays unchanged")
	_assert(DemoChronicle.where_text(old_demo) == "Vyraketh falls", "Persisted demo identity controls its label even outside demo mode")
	_set_demo(true)

func _test_keystones() -> void:
	_set_demo(false)
	var samples: Array = [[], ["quick_wits"], ["measured_breath", "rehearsed_escape"], DemoSkills.repaired_selection([], 18)]
	for selected: Array in samples:
		var full_availability: Dictionary = {}
		for id: String in DemoSkills.ordered_ids():
			full_availability[id] = DemoSkills.is_available(id, selected)
		_set_demo(true)
		for id: String in DemoSkills.ordered_ids():
			if DemoSkills.tier(id) in ["root", "branch", "junction"]:
				_assert(DemoSkills.is_available(id, selected) == full_availability[id], "Demo keeps full reachability for non-keystone %s" % id)
		_set_demo(false)
	for id: String in DemoSkills.ordered_ids():
		if not DemoSkills.is_keystone(id): continue
		var profile: Dictionary = ProgressionStore.default_data()
		profile["level"] = 20
		var preference: Array[String] = DemoSkillSuite._recursive_prerequisites(id)
		for candidate: String in DemoSkills.ordered_ids():
			if not DemoSkills.is_keystone(candidate) and not preference.has(candidate): preference.append(candidate)
		var build: Array[String] = DemoSkills.repaired_selection([], 18, preference)
		build.append(id)
		_assert(build.has(id), "Keystone fixture builds a legal selection for %s" % id)
		var prerequisites: Array[String] = DemoTypedArrays.strings(build.duplicate())
		prerequisites.erase(id)
		profile["skill_ids"] = prerequisites
		_assert(DemoSkills.is_available(id, prerequisites) and ProgressionStore.can_learn_skill(profile, id), "Full build can learn legal keystone %s" % id)
		var owned: Dictionary = profile.duplicate(true)
		owned["skill_ids"] = build
		# Warm repair cache in full mode before testing exactly the same inputs.
		_assert(ProgressionStore.normalized_data(owned)["skill_ids"].has(id), "Full normalization retains its legal keystone")
		_set_demo(true)
		_assert(DemoSkills.is_demo_locked(id) and not DemoSkills.is_available(id, prerequisites) and not ProgressionStore.can_learn_skill(profile, id), "Demo locks keystone %s with all points and prerequisites" % id)
		_assert(DemoSkills.locked_reason(id, prerequisites) == DemoRules.config()["text"]["keystone_tooltip"], "Keystone lock uses director-authored tooltip")
		_assert(not ProgressionStore.normalized_data(owned)["skill_ids"].any(func(skill: String) -> bool: return DemoSkills.is_keystone(skill)), "Demo normalization removes an existing keystone despite warmed full cache")
		owned["progression_schema"] = 3
		_assert(not ProgressionStore.normalized_data(owned)["skill_ids"].any(func(skill: String) -> bool: return DemoSkills.is_keystone(skill)), "Legacy demo migration never adds a keystone")
		_set_demo(false)
		_assert(ProgressionStore.can_learn_skill(profile, id), "Demo repair cannot poison the full-build cache")
	_set_demo(true)

func _test_analytics(engine: RunEngine, state: Dictionary, build_kind: String) -> void:
	var started: Dictionary = DemoSnapshots.run_started(state, state["progression"])
	var ended: Dictionary = DemoSnapshots.run_ended(engine, state, str(state["mode"]))
	_assert(started["build_kind"] == build_kind and ended["build_kind"] == build_kind, "Both terminal analytics snapshots identify the %s build" % build_kind)
	_assert(started["seed"] == state["seed"] and started["starting_deck"] == state["deck_cards"] and started["equipped_equipment"] == state["equipped_equipment"], "Existing run_started fields remain intact")
	_assert(ended["enemies_killed"] == state["run_stats"]["enemies_killed"] and ended["held_embers"] == engine.held_embers(state), "Existing run_ended fields remain intact")

func _dragon_fixture(engine: RunEngine, profile: Dictionary) -> Dictionary:
	var state: Dictionary = engine.create_new_run(FIXTURE_SEED, profile)
	var coord: Vector2i = DemoGraph.section(state, 0)["boss"]
	state["current_room"] = coord
	var room: Dictionary = DemoGraph.room(state, coord)
	room["visited"] = true
	room["revealed"] = true
	state["mode"] = "combat"
	DemoChronicle.enter_room(state, room)
	var layout: Dictionary = engine.call("_combat_layout_for_room", room, Vector2i.RIGHT, state)
	state["current_room_layout"] = layout
	state["combat_state"] = CombatEngine.new().create_combat(FIXTURE_SEED, layout, engine.call("_player_snapshot", state))
	state["combat_state"]["player"]["hp"] = FIXTURE_LOW_HP
	for enemy: Dictionary in state["combat_state"]["enemies"]:
		enemy["hp"] = 0
	return state

func _fingerprint(value: Variant) -> String:
	return var_to_bytes(value).hex_encode().sha256_text()

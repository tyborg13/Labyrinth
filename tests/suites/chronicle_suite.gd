extends RefCounted

const Rules = preload("res://scripts/chronicle_rules.gd")
const Store = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const Recap = preload("res://scripts/run_end_recap_overlay.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const TEST_PROFILE: String = "user://chronicle_suite_profile.json"
const TEST_RUN: String = "user://chronicle_suite_run.save"
const FIXTURE_SEED: int = 8821
const CAP_ADDITIONAL_RUNS: int = 55
const OVERFLOW_PROOF_WIDTH: float = 80.0

static func run(check: Callable) -> void:
	var previous_profile_path: String = Store._storage_path
	var previous_run_path: String = Store._run_storage_path
	var engine := RunEngine.new()
	var state: Dictionary = engine.create_new_run(FIXTURE_SEED, Store.default_data())
	check.call(state[Rules.PATH_KEY] == [[]], "Chronicle excludes the entry threshold")
	var coord: Vector2i = engine.available_moves(state)[0]
	var key: String = Graph.key(coord)
	state["rooms"][key]["type"] = "mystery"
	state["rooms"][key]["mystery_type"] = "combat"
	state = engine.move_to_pre_battle(state, coord)
	check.call(state[Rules.PATH_KEY] == [["combat"]], "Chronicle pre-battle records revealed mystery combat once")
	state = engine.begin_pre_battle_combat(state)
	check.call(state[Rules.PATH_KEY] == [["combat"]], "Starting the fight does not enter a second room")
	var event_state: Dictionary = engine.create_new_run(FIXTURE_SEED, Store.default_data())
	event_state["rooms"][key]["type"] = "mystery"
	event_state["rooms"][key]["mystery_type"] = "event"
	event_state = engine.move_to_room(event_state, coord)
	check.call(event_state[Rules.PATH_KEY] == [["event"]], "Chronicle mystery events retain event identity")
	Rules.enter_room(state, {"type": "guardian", "section_index": 0})
	Rules.enter_room(state, {"type": "campfire", "section_index": 0})
	Rules.enter_room(state, {"type": "start", "section_index": 1})
	Rules.enter_room(state, {"type": "scavenger", "section_index": 1})
	check.call(state[Rules.PATH_KEY] == [["combat", "guardian", "campfire"], ["scavenger"]], "Chronicle retains entered room order across sections, excluding thresholds")
	var killer: Dictionary = {"enemy_type": "frostglass_lancer", "intent_id": "glass_lunge"}
	state["run_stats"]["killer"] = killer
	state["run_stats"]["run_seconds"] = 2460.0
	state["run_stats"]["dragons_slain"] = ["tharokh", "vyraketh"]
	state["umbra_depth"] = 2
	var profile: Dictionary = Store.default_data()
	var first: Dictionary = {}
	for outcome: String in ["defeat", "victory", "embrace"]:
		state["run_index"] = int(state.get("run_index", 0)) + 1
		var record: Dictionary = Rules.build_record(state, outcome, Rules.Score.score(state, outcome), {"day": 12, "month": 10})
		check.call(record["ended_at"] == "12 Oct" and record["run_seconds"] == 2460, "Chronicle preserves local date and elapsed time")
		check.call(not (record["gear"] as Array).is_empty() and not (record["deck"] as Array).is_empty(), "Chronicle stores final equipped gear and compiled deck")
		var stored: Dictionary = Store.record_run_result(profile, record["run_id"], state["run_stats"], state, outcome)
		profile = stored["data"]
		var duplicate: Dictionary = Store.record_run_result(profile, record["run_id"], state["run_stats"], state, outcome)
		check.call(not duplicate["recorded"] and Store.chronicle_totals(duplicate["data"])["runs"] == Store.chronicle_totals(profile)["runs"], "Chronicle %s is idempotent" % outcome)
		if first.is_empty():
			first = record
	var adapter_profile: Dictionary = Store.default_data()
	for outcome: String in ["defeat", "victory", "embrace"]:
		state["run_index"] += 1
		state["mode"] = outcome
		var adapter_result: Dictionary
		if outcome == "embrace":
			var embraced: Dictionary = Recap.embrace_state(state, adapter_profile)
			adapter_profile = embraced["progression"]
		else:
			# This is the unchanged production terminal adapter calling convention.
			var metrics: Dictionary = Recap.result_stats(state)
			var result_id: String = RunEngine.run_result_id(state)
			adapter_result = Store.record_run_result(adapter_profile, result_id, metrics)
			adapter_profile = adapter_result["data"]
		var latest: Dictionary = Store.chronicle_records(adapter_profile)[0]
		check.call(latest["outcome"] == outcome and latest["run_seconds"] == 2460 and latest["path"] == state[Rules.PATH_KEY] and latest["deck"] == Rules.deck_counts(state["deck_cards"]), "Production %s terminal adapter records the exact snapshot" % outcome)
	check.call(Store.chronicle_totals(adapter_profile)["runs"] == 3, "Production terminal adapters include all three outcomes once")
	check.call(Store.chronicle_records(profile).size() == 3 and Store.chronicle_records(profile)[0]["outcome"] == "embrace", "Chronicle records every outcome newest first")
	check.call(Store.chronicle_totals(profile)["runs"] == 3 and Store.chronicle_totals(profile)["escapes"] == 1 and Store.chronicle_totals(profile)["dragons_slain"] == 6 and Store.chronicle_totals(profile)["deepest_depth"] == 2, "Chronicle lifetime totals include all outcomes and only escaped depth")
	Store.set_storage_path(TEST_PROFILE)
	check.call(Store.save_data(profile), "Chronicle profile saves")
	var restarted: Dictionary = Store.load_data()
	check.call(Store.chronicle_records(restarted) == Store.chronicle_records(profile) and Store.chronicle_totals(restarted) == Store.chronicle_totals(profile), "Chronicle survives profile restart")
	Store.set_run_storage_path(TEST_RUN)
	check.call(Store.save_run_state(state), "Chronicle path save succeeds")
	check.call(Store.load_saved_run()[Rules.PATH_KEY] == state[Rules.PATH_KEY], "Chronicle active path survives run restart")
	for index: int in range(CAP_ADDITIONAL_RUNS):
		var record: Dictionary = first.duplicate(true)
		record["run_id"] = "cap-%d" % index
		profile = Store.record_chronicle(profile, record)
	check.call(Store.chronicle_records(profile).size() == 50 and Store.chronicle_records(profile)[0]["run_id"] == "cap-54" and Store.chronicle_records(profile)[49]["run_id"] == "cap-5", "Chronicle drops only the oldest records at 50")
	check.call(Store.chronicle_totals(profile)["runs"] == 58 and Store.chronicle_totals(profile)["dragons_slain"] == 116, "Chronicle lifetime totals outlive the cap")
	var replay: Dictionary = Store.record_chronicle(profile, first)
	check.call(Store.chronicle_totals(replay)["runs"] == 58 and Store.chronicle_records(replay).size() == 50, "Dropped records remain idempotent through lifetime receipts")
	Store.save_data(profile)
	check.call(Store.chronicle_totals(Store.record_chronicle(Store.load_data(), first))["runs"] == 58, "Dropped-record receipts survive restart")
	var legacy: Dictionary = Store.normalized_data({"embers": 12, "progression_schema": 7, "last_run_result": {"result_id": "old", "stats": {"depth": 4}}})
	check.call(Store.chronicle_records(legacy).is_empty() and Store.chronicle_totals(legacy)["runs"] == 0, "Old profiles and stored results never fabricate Chronicle records")
	var legacy_state: Dictionary = state.duplicate(true)
	legacy_state.erase(Rules.PATH_KEY)
	check.call(Rules.build_record(legacy_state, "defeat", {}) == {}, "Pre-Chronicle runs do not create incomplete histories")
	check.call(Store.chronicle_records({"chronicle_records": [null, 1, {}, {"run_id": "bad", "outcome": "bad"}]}).is_empty(), "Malformed history rows are safe")
	check.call(Rules.killer_text(killer, "defeat") == "Felled by a Frostglass Lancer's Glass Lunge", "Chronicle enemy killer omits damage")
	check.call(Rules.killer_text({"cause": "fatigue"}, "defeat") == "Worn down by fatigue", "Chronicle fatigue copy")
	check.call(Rules.killer_text({"cause": "surface", "surface": "fire"}, "defeat") == "Slain by Fire", "Chronicle surface copy")
	check.call(Rules.killer_text({"cause": "trap", "name": "Fire trap"}, "defeat") == "Slain by Fire trap", "Chronicle named trap copy")
	check.call(Rules.killer_text({"cause": "trap", "element": "fire"}, "defeat") == "Slain by Fire Trap", "Chronicle uses the existing elemental trap name")
	check.call(Rules.killer_text({}, "victory") == "Noctyrax falls" and Rules.killer_text({}, "embrace") == "Withdrew at the Ember Hearth", "Chronicle terminal copy")
	check.call(Rules.subline(first).contains("Umbra Depth 2") and Rules.subline(first).contains("41 min"), "Chronicle subline includes time and positive depth")
	first.erase("umbra_depth")
	check.call(not Rules.subline(first).contains("Umbra Depth"), "Chronicle absent depth is omitted")
	first["umbra_depth"] = 0
	check.call(not Rules.subline(first).contains("Umbra Depth"), "Chronicle depth zero is omitted")
	check.call(Rules.deck_counts(["pale_spark", "waning_pulse", "pale_spark"]) == [["pale_spark", 2], ["waning_pulse", 1]], "Chronicle duplicate deck counts retain first occurrence order")
	var deck: Array = []
	for index: int in range(30):
		deck.append(["fixture_spell_%d" % index, 1])
	var overflow: String = Rules.spells_text(deck, Typography.text_font(), OVERFLOW_PROOF_WIDTH)
	check.call(overflow.split("\n").size() == 8 and overflow.ends_with("+23 more"), "Chronicle spell overflow counts omitted entries and caps at eight lines")
	check.call(Rules.spells_text([["pale_spark", 2]], Typography.text_font(), 358) == "Pale Spark ×2", "Chronicle spells use exact card names and duplicate suffix")
	check.call(Rules.Score.grouped_number(1240) == "1,240", "Chronicle thousands separators")
	var absent: Dictionary = first.duplicate(true)
	absent.erase("umbra_depth")
	check.call(not Rules.add_to_totals({}, absent).has("deepest_depth"), "Lifetime depth chip stays absent without meta-03 data")
	var deep_loss: Dictionary = first.duplicate(true)
	deep_loss["umbra_depth"] = 8
	check.call(Rules.add_to_totals({"deepest_depth": 2}, deep_loss)["deepest_depth"] == 2, "Defeated depth never raises escaped-depth best")
	Store.set_storage_path(previous_profile_path)
	Store.set_run_storage_path(previous_run_path)

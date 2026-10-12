extends RefCounted

const Score = preload("res://scripts/run_score_rules.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Overlay = preload("res://scripts/run_end_recap_overlay.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const COUNTER_RUN_SEED: int = 6101
const EVENT_RUN_SEED: int = 6111
const PERSISTENCE_RUN_SEED: int = 512
const Graph = preload("res://scripts/section_map_graph.gd")

static func run(expect: Callable) -> void:
	_score_table(expect)
	_boundaries(expect)
	_counters(expect)
	_persistence(expect)
	_text(expect)

static func _row(result: Dictionary, id: String) -> Dictionary:
	for list: String in ["lines", "feats"]:
		for row: Dictionary in result[list]:
			if str(row["id"]) == id:
				return row
	return {}

static func _score_table(expect: Callable) -> void:
	var state: Dictionary = {"run_stats": {"rooms_explored": 29, "enemies_slain": 61, "guardians_slain": 2, "dragons_slain": ["tharokh", "vyraketh"], "dragons_flawless": ["vyraketh"], "max_kills_one_card": 3, "max_single_hit": 22}, "relics": []}
	var result: Dictionary = Score.score(state, "defeat")
	expect.call(int(result["total"]) == 567, "Approved mockup score must total 567")
	var ids: Array[String]
	for list: String in ["lines", "feats"]:
		for row: Dictionary in result[list]: ids.append(str(row["id"]))
	expect.call(ids == Score.string_ids(["rooms_explored", "enemies_slain", "guardians_slain", "dragons_slain", "flawless", "overkill", "chain_reaction"]), "Brief order supersedes mockup order")
	expect.call(_row(result, "dragons_slain")["detail"] == "Tharokh, Vyraketh", "Dragon names retain slain order")
	expect.call(_row(result, "flawless")["label"] == "Flawless" and _row(result, "flawless")["detail"] == "Vyraketh without losing Health", "Single Flawless keeps the original label and detail")
	var one_guardian: Dictionary = _row(Score.score({"run_stats": {"guardians_unscathed": ["craghide"]}}, "defeat"), "unscathed")
	expect.call(one_guardian["label"] == "Unscathed" and one_guardian["detail"] == "Craghide without losing Health", "Single Unscathed keeps the original label and detail")
	var empty: Dictionary = Score.score({}, "defeat")
	expect.call(empty["lines"].is_empty() and empty["feats"].is_empty() and empty["total"] == 0, "Zero-point rows are omitted")
	var dragons: Array[String]
	for id: String in ["tharokh", "vyraketh", "vaeloryx", "iskaldra", "zekarion", "noctyrax"]:
		dragons.append(id)
		var points: int = int(_row(Score.score({"run_stats": {"dragons_slain": dragons}}, "defeat"), "dragons_slain")["points"])
		expect.call(points == 25 * dragons.size() * (dragons.size() + 1), "Cumulative dragon score at count %d" % dragons.size())
	var stats: Dictionary = {"guardians_unscathed": ["craghide", "rimejaw"], "dragons_flawless": ["tharokh", "vyraketh"], "max_single_hit": 20, "max_kills_one_card": 3, "mystery_rooms_entered": 10, "events_resolved": 8, "max_held_embers": 1200, "defiance_spent": 1, "run_seconds": 2699}
	var all: Dictionary = Score.score({"run_stats": stats, "relics": ["worldheart", "winters_hour", "crowncoal_heart"]}, "victory")
	expect.call(int(all["total"]) == 675, "Full feat table awards independently, once per qualifying guardian/dragon")
	expect.call(all["feats"].size() == 10, "Guardian and dragon awards each aggregate into one of ten feat rows")
	expect.call(_row(all, "unscathed")["label"] == "Unscathed ×2" and _row(all, "unscathed")["detail"] == "Craghide, Rimejaw" and _row(all, "unscathed")["points"] == 50, "Unscathed aggregates names and points")
	expect.call(_row(all, "flawless")["label"] == "Flawless ×2" and _row(all, "flawless")["detail"] == "Tharokh, Vyraketh" and _row(all, "flawless")["points"] == 100, "Flawless aggregates names and points")
	var six_flawless: Dictionary = _row(Score.score({"run_stats": {"dragons_flawless": dragons}}, "defeat"), "flawless")
	expect.call(six_flawless["detail"] == "Tharokh, Vyraketh, Vaeloryx +3" and six_flawless["points"] == 300, "More than three names retain the first three and remaining count")
	for feat: Dictionary in all["feats"]:
		expect.call(bool(feat["feat"]) and not str(feat["detail"]).is_empty(), "Every feat has its gold marker and exact detail")
	for outcome: String in ["defeat", "embrace"]:
		var restricted: Dictionary = Score.score({"run_stats": stats}, outcome)
		for id: String in ["escaped", "last_light", "swift", "ascetic"]:
			expect.call(_row(restricted, id).is_empty(), "%s is victory-only on %s" % [id, outcome])
	expect.call(_row(Score.score({"relics": ["a", "b", "c", "d"]}, "victory"), "ascetic").is_empty(), "Four relics exclude Ascetic")

static func _boundaries(expect: Callable) -> void:
	for pair: Array in [[599, 0], [600, 25], [1199, 25], [1200, 50]]:
		var row: Dictionary = _row(Score.score({"run_stats": {"max_held_embers": pair[0]}}, "defeat"), "ember_hoard")
		expect.call(int(row.get("points", 0)) == int(pair[1]), "Ember Hoard boundary %d" % int(pair[0]))
	for pair: Array in [[2699, 50], [2700, 25], [3599, 25], [3600, 0]]:
		var row: Dictionary = _row(Score.score({"run_stats": {"run_seconds": pair[0]}}, "victory"), "swift")
		expect.call(int(row.get("points", 0)) == int(pair[1]), "Swift boundary %d" % int(pair[0]))
	for pair: Array in [[59, "0 minutes"], [60, "1 minute"], [119, "1 minute"], [120, "2 minutes"], [2699, "44 minutes"]]:
		expect.call(_row(Score.score({"run_stats": {"run_seconds": pair[0]}}, "victory"), "swift")["detail"] == "Escaped in %s" % pair[1], "Swift floors whole minutes and uses singular at one")
	for spec: Array in [["max_single_hit", "overkill", 19, 20], ["max_kills_one_card", "chain_reaction", 2, 3], ["mystery_rooms_entered", "seeker", 9, 10], ["events_resolved", "bargainer", 7, 8]]:
		for value: int in [int(spec[2]), int(spec[3])]:
			var row: Dictionary = _row(Score.score({"run_stats": {str(spec[0]): value}}, "defeat"), str(spec[1]))
			expect.call(int(row.get("points", 0)) == (25 if value == int(spec[3]) else 0), "%s threshold %d" % [spec[1], value])

static func _combat_fixture() -> Dictionary:
	return {"run_stats": Combat.default_run_stats(), "player": {"pos": Vector2i(1, 1), "hp": 30, "max_hp": 30, "block": 0, "stoneskin": 0}, "enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(2, 1), "hp": 3, "max_hp": 3}, {"id": 2, "type": "crawler", "pos": Vector2i(3, 1), "hp": 3, "max_hp": 3}, {"id": 3, "type": "crawler", "pos": Vector2i(4, 1), "hp": 3, "max_hp": 3}, {"id": 4, "type": "crawler", "pos": Vector2i(5, 1), "hp": 3, "max_hp": 3, "summoned": true}], "relics": [], "log": [], "deck": {"hand": ["quick_stab"]}, "room_embers": 0, "current_actor": {"kind": "player"}, "death_rewards": []}

static func _counters(expect: Callable) -> void:
	var combat := Combat.new()
	var state: Dictionary = combat.prepare_player_card(_combat_fixture(), 0)
	state["score_wallet_base"] = 590
	state["damage_context"] = {"actor_kind": "player", "source_kind": "direct_attack", "player_card": true}
	for index: int in range(4):
		state = combat._damage_enemy(state, index, 22, false, true)
	expect.call(state["run_stats"]["max_held_embers"] == 590 + int(state["room_embers"]), "Pending combat Embers count toward the HUD wallet peak before the room ends")
	expect.call(state["run_stats"]["enemies_slain"] == 3, "Summons do not count as slain")
	expect.call(state["run_stats"]["enemies_killed"] == 4, "Legacy kill stat remains unchanged")
	expect.call(state["run_stats"]["max_single_hit"] == 22, "Largest resolved player hit includes overkill")
	expect.call(state["run_stats"]["max_kills_one_card"] == 4, "One card counts all deaths across its resolution, including summons")
	var previous: Dictionary = state["run_stats"].duplicate(true)
	state = combat._damage_enemy(state, 0, 100, false, true)
	expect.call(state["run_stats"] == previous, "Already dead enemies do not award new counters")
	state = combat.prepare_player_card(state, 0)
	expect.call(state["run_stats"]["card_resolution_kills"] == 0 and state["run_stats"]["max_kills_one_card"] == 4, "Next card resets its own count, retaining run max")
	state["damage_context"] = {"actor_kind": "enemy", "source_kind": "direct_attack", "enemy_type": "frostglass_lancer", "intent_id": "glass_lunge"}
	state = combat._damage_player(state, 40, true, false)
	expect.call(state["run_stats"]["killer"] == {"enemy_type": "frostglass_lancer", "intent_id": "glass_lunge", "damage": 40}, "Lethal enemy/intent/damage are saved")
	for cause: String in ["fatigue", "surface", "trap"]:
		var fresh: Dictionary = _combat_fixture()
		fresh["damage_context"] = {"source_kind": "surface_fire" if cause == "surface" else "trap", "trap_element": "ice"}
		fresh = combat._damage_player(fresh, 40, true, false, "fatigue" if cause == "fatigue" else "damage")
		expect.call(fresh["run_stats"]["killer"]["cause"] == cause, "Lethal %s cause is attributed" % cause)
	var saved: Dictionary = _combat_fixture()
	saved["defiance_capacity"] = 1
	saved["defiance_remaining"] = 1
	saved = combat._damage_player(saved, 40, true, false)
	expect.call(saved["run_stats"]["defiance_spent"] == 1 and saved["run_stats"]["killer"].is_empty(), "Defiance counts once without reporting a killer")
	var engine := Run.new()
	var run_state: Dictionary = engine.create_new_run(COUNTER_RUN_SEED, Store.set_embers(Store.default_data(), 600))
	expect.call(run_state["run_stats"]["max_held_embers"] == 600 and run_state["run_stats"]["rooms_explored"] == 0, "Starting wallet counts; Threshold does not")
	var entry_fixture: Dictionary = engine.create_new_run(COUNTER_RUN_SEED, Store.default_data())
	var entry_destination: Vector2i = engine.available_moves(entry_fixture)[0]
	Graph.room(entry_fixture, entry_destination)["type"] = "start"
	entry_fixture = engine.move_to_room(entry_fixture, entry_destination)
	expect.call(entry_fixture["run_stats"]["rooms_explored"] == 1, "A non-Threshold section entry counts even when its type is start")
	var destination: Vector2i = engine.available_moves(run_state)[0]
	var node: Dictionary = Graph.room(run_state, destination)
	node["type"] = "mystery"
	node["mystery_type"] = "treasure"
	run_state = engine.move_to_room(run_state, destination)
	expect.call(run_state["run_stats"]["rooms_explored"] == 1 and run_state["run_stats"]["mystery_rooms_entered"] == 1, "First room entry and original mystery kind are counted")
	var again: Dictionary = engine.move_to_room(run_state, destination)
	expect.call(again["run_stats"] == run_state["run_stats"], "No-op travel does not count")
	run_state = engine.add_held_embers(run_state, 600)
	run_state = engine.spend_held_embers(run_state, 1100)
	expect.call(run_state["run_stats"]["max_held_embers"] == 1200, "Wallet maximum survives spending")
	Run.advance_play_time(run_state, 10.5)
	Run.advance_play_time(run_state, 90, true)
	expect.call(run_state["run_stats"]["run_seconds"] == 10.5, "Paused time is excluded")
	for kind: String in ["guardian", "boss"]:
		var room: Dictionary = Graph.room(run_state, destination)
		room["type"] = kind
		room["cleared"] = false
		room["boss_id"] = "tharokh"
		room["guardian_id"] = "craghide"
		var win: Dictionary = _combat_fixture()
		win["run_stats"] = run_state["run_stats"].duplicate(true)
		win["score_health_loss_at_start"] = 0
		for enemy: Dictionary in win["enemies"]: enemy["hp"] = 0
		var finished: Dictionary = engine.finish_combat(run_state, win)
		var stats: Dictionary = finished["run_stats"]
		expect.call(stats["guardians_slain"] == 1 if kind == "guardian" else stats["dragons_slain"].has("tharokh"), "%s victory is counted" % kind)
		expect.call(stats["guardians_unscathed"].has("craghide") if kind == "guardian" else stats["dragons_flawless"].has("tharokh"), "%s without Health loss is counted" % kind)
		var replay: Dictionary = engine.finish_combat(finished, win)
		expect.call(replay["run_stats"] == stats, "Finished %s cannot award twice" % kind)
		win["run_stats"]["damage_received"] = 1
		var hurt: Dictionary = engine.finish_combat(run_state, win)
		expect.call((hurt["run_stats"]["guardians_unscathed"] if kind == "guardian" else hurt["run_stats"]["dragons_flawless"]).is_empty(), "Health loss prevents %s feat even after healing" % kind)
	# Use an actual event transaction; replaying its result cannot award twice.
	var event_state: Dictionary = engine.create_new_run(EVENT_RUN_SEED, Store.default_data())
	var event_coord: Vector2i = engine.available_moves(event_state)[0]
	var event_room: Dictionary = Graph.room(event_state, event_coord)
	event_room["type"] = "event"
	event_room["cleared"] = false
	event_state = engine.move_to_room(event_state, event_coord)
	var choices: Array = preload("res://scripts/game_data.gd").event_def(preload("res://scripts/event_rules.gd").current_id(event_state)).get("choices", [])
	if not choices.is_empty():
		event_state = engine.resolve_map_event(event_state, str(choices[0]["id"]))
		expect.call(event_state["run_stats"]["events_resolved"] == 1, "Resolved event counts once")
		var repeat: Dictionary = engine.resolve_map_event(event_state, str(choices[0]["id"]))
		expect.call(repeat["run_stats"]["events_resolved"] == 1, "Event result replay cannot count again")
	else:
		expect.call(false, "Event fixture must have a choice")
	expect.call(Store.save_run_state(run_state), "Counters save mid-run")
	var restored: Dictionary = engine.repair_loaded_run_state(Store.load_saved_run())
	expect.call(restored["run_stats"] == run_state["run_stats"], "Every score counter survives save/resume")
	Store.clear_saved_run()

static func _persistence(expect: Callable) -> void:
	var old: Dictionary = Store.normalized_data({"progression_schema": 7, "last_run_result": {"result_id": "old", "stats": {"depth": 1}}, "completed_run_results": [{"result_id": "older", "stats": {"depth": 2}}]})
	expect.call(Store.last_run_result(old)["score"] == null, "Old score stays null, never a fabricated zero")
	expect.call(Store.completed_run_results(old)[0]["score"] == null and old["best_score"] == 0, "Old ledger and missing best score load")
	var engine := Run.new()
	var state: Dictionary = engine.create_new_run(PERSISTENCE_RUN_SEED, old)
	state["run_stats"]["rooms_explored"] = 3
	state["run_stats"]["killer"] = {"enemy_type": "frostglass_lancer", "intent_id": "glass_lunge", "damage": 6}
	var first: Dictionary = Store.record_run_result(old, Run.run_result_id(state), Overlay.result_stats(state), state, "defeat")
	expect.call(first["result"]["score"] == 15 and first["data"]["best_score"] == 15 and first["result"]["new_best_score"], "First positive score beats stored zero")
	expect.call(first["result"]["killer"] == state["run_stats"]["killer"] and first["result"].has("section") and first["result"].has("biome"), "Result stores killer and location")
	var second: Dictionary = Store.record_run_result(first["data"], "tie", {}, state, "defeat")
	expect.call(not second["result"]["new_best_score"], "Ties do not show NEW BEST")
	state["run_stats"]["rooms_explored"] = 100
	var replay: Dictionary = Store.record_run_result(second["data"], Run.run_result_id(state), {}, state, "victory")
	expect.call(not replay["recorded"] and replay["result"] == first["result"] and replay["data"]["best_score"] == 15, "Replay returns original score, feats and strict-best decision")
	expect.call(Store.save_data(replay["data"]), "Score result saves")
	expect.call(Store.last_run_result(Store.load_data()) == first["result"], "Score result survives profile reload")
	var outbox: Array[Dictionary] = Store.progression_analytics_outbox(first["data"])
	expect.call(outbox.size() == 1 and outbox[0]["event_type"] == "run_scored", "One additive run_scored event is staged")
	expect.call(outbox[0]["payload"]["total"] == 15 and outbox[0]["payload"].has("lines") and outbox[0]["payload"].has("feats"), "run_scored carries the exact table")
	var embrace: Dictionary = Overlay.embrace_state(state, Store.default_data())
	expect.call(embrace["mode"] == "embrace" and embrace["run_result"]["score"] == 500 and embrace["run_result"]["killer"].is_empty(), "Embrace terminal preparation stores score without changing recovery or currency")
	expect.call(embrace["progression"]["embers"] == Store.default_data()["embers"], "Embrace helper preserves the already committed wallet")
	Analytics.clear_storage()
	var analytics := Analytics.new()
	for index: int in range(2):
		expect.call(analytics.write_event("run_scored", outbox[0]["context"], outbox[0]["payload"], str(outbox[0]["idempotency_key"])), "Scored outbox can be retried")
	expect.call(Analytics.load_all_events().size() == 1, "JSONL score event appends exactly once")

static func _text(expect: Callable) -> void:
	for outcome: String in ["defeat", "victory", "embrace"]:
		var first: Dictionary = Score.seeded_text("stable-run-id", outcome)
		for index: int in range(5):
			expect.call(Score.seeded_text("stable-run-id", outcome) == first, "Seeded %s copy is stable" % outcome)
	expect.call(Score.cause_text({"enemy_type": "frostglass_lancer", "intent_id": "glass_lunge", "damage": 6}, "defeat", 0) == "Felled by a Frostglass Lancer's Glass Lunge, 6 damage.", "Approved killer copy uses enemy/intent data")
	expect.call(Score.cause_text({"cause": "fatigue"}, "defeat", 0) == "Fatigue took your last breath.", "Fatigue cause copy")
	expect.call(Score.cause_text({"cause": "surface", "surface": "fire"}, "defeat", 0) == "Fire took your last breath.", "Surface cause copy")
	expect.call(Score.cause_text({"cause": "trap", "element": "ice"}, "defeat", 0) == "A ice trap took your last breath.", "Trap cause follows brief wording literally")
	expect.call(Score.cause_text({}, "defeat", 0) == "The Umbra took your last breath.", "Unknown killer fallback")
	expect.call(Score.cause_text({"enemy_type": "frostglass_lancer", "damage": 6}, "defeat", 0) == "Felled by a Frostglass Lancer, 6 damage.", "Missing intent fallback")
	expect.call(Score.cause_text({"cause": "surface"}, "defeat", 0) == "The ground itself took your last breath.", "Missing surface fallback")
	expect.call(Score.cause_text({"cause": "trap"}, "defeat", 0) == "A trap took your last breath.", "Missing trap element fallback")
	for outcome: String in ["defeat", "victory", "embrace"]:
		var fallback: Dictionary = Score.text_from_data("stable-run-id", outcome, {})
		expect.call(fallback["title"] == Score.DEFAULT_TITLES[outcome] and fallback["quip"] == "", "Missing lists use first approved title and omit quip")
	var legacy: Dictionary = Overlay.build_model({"current_room": Vector2i(4, 0)}, Store.default_data(), "defeat", 37)
	expect.call(legacy["eyebrow"] == "Depth 4", "Legacy location uses global depth")
	expect.call(legacy["embers_text"] == "EMBERS LOST 37\nNo recovery marker created", "Legacy recovery retains original label and recovery copy")
	var unnamed_section: Dictionary = Overlay.build_model({"map_sections": [{"room_count": 11}], "rooms": {"0,0": {"section_index": 0, "map_step": 7}}}, {}, "defeat", 0)
	expect.call(unnamed_section["eyebrow"] == "Section I · Room 7 of 11", "Unnamed section omits the biome segment")

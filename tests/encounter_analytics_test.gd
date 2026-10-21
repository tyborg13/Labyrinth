extends SceneTree
const Store = preload("res://scripts/analytics_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Scene = preload("res://scripts/run_scene.gd")
const Headless = preload("res://tools/headless_playtest.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const CALLER_FIXTURE_SEED: int = 421
const CALLER_RUN_ID: String = "encounter_caller_fixture"
const CALLER_MILESTONE_ID: String = "encounter_caller_boss_claim"
const BOUNDARY_EVENTS: PackedStringArray = ["combat_started", "combat_ended", "reward_offered", "reward_choice"]
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: " + message)

func check_boundary_events(label: String, expected: Dictionary, with_claim: bool) -> void:
	var event_types: PackedStringArray = BOUNDARY_EVENTS.duplicate()
	if with_claim: event_types.append("reward_claimed")
	var records: Array[Dictionary] = Store.load_all_events()
	for event_type: String in event_types:
		var matches: Array[Dictionary]
		for event: Dictionary in records:
			if event.get("event_type") == event_type: matches.append(event)
		check(matches.size() == 1, "%s emits exactly one %s" % [label, event_type])
		if matches.size() != 1: continue
		# Expected values come from the generated room/section/layout below,
		# never from either analytics caller or EncounterAnalyticsContext.
		for key: String in expected:
			check(matches[0].get(key) == expected[key], "%s %s metadata.%s expected %s, got %s" % [label, event_type, key, expected[key], matches[0].get(key)])

func check_caller_boundaries(run: Dictionary, combat: Dictionary, expected: Dictionary, boss_id: String) -> void:
	var ended: Dictionary = combat.duplicate(true)
	for enemy: Dictionary in ended["enemies"]: enemy["hp"] = 0
	var reward: Dictionary = {"cards": ["quick_stab"], "boss_id": boss_id, "milestone_id": CALLER_MILESTONE_ID}
	# Exercise the shared reward logger with each room identity, including an
	# empty combat snapshot at choice/claim time. No renderer or REPL is started.
	var after: Dictionary = run.duplicate(true)
	after["mode"] = "reward"
	after["combat_state"] = {}
	after["pending_reward"] = reward
	for caller: String in ["UI", "headless"]:
		Store.clear_storage()
		var store := Store.new()
		var host = Scene.new() if caller == "UI" else Headless.new()
		host.set("_analytics_store", store)
		host.set("_progression", run["progression"].duplicate(true))
		host.set("_run_state", run.duplicate(true))
		host.set("_combat_state", combat.duplicate(true))
		if caller == "UI": host._analytics_log_combat_started("caller_fixture")
		else: host._log_combat_started("caller_fixture")
		host.set("_run_state", after.duplicate(true))
		host.set("_combat_state", {})
		if caller == "UI":
			host._analytics_log_combat_transition(run, "caller_fixture", ended)
			host._analytics_log_reward_choice("card", reward, "quick_stab", run["player_hp"], run["player_hp"])
		else:
			host._log_combat_transition(run, "caller_fixture", ended)
			host._log_reward_choice("card", "quick_stab", reward, run["player_hp"], run["player_hp"])
		var with_claim: bool = caller == "UI" and expected["room_type"] == "boss"
		if with_claim:
			var staged: Dictionary = host._stage_dragon_reward_claim(after, reward)
			check(store.write_events(Progression.progression_analytics_outbox(staged["progression"])), "UI boss staged reward_claimed appends")
		check_boundary_events("%s %s" % [caller, expected["room_type"]], expected, with_claim)
		host.free()

func test_caller_metadata() -> void:
	var previous_failures: int = failures
	var engine := Run.new()
	for room_type: String in ["combat", "guardian", "boss"]:
		var run: Dictionary = engine.create_new_run(CALLER_FIXTURE_SEED, Progression.default_data())
		var room: Dictionary = {}
		for candidate: Dictionary in run["rooms"].values():
			if candidate["type"] == room_type:
				room = candidate
				break
		check(not room.is_empty(), "generated caller fixture has room type " + room_type)
		if room.is_empty(): continue
		run["current_room"] = room["coord"]
		var layout: Dictionary = engine._combat_layout_for_room(room, Vector2i.RIGHT, run)
		engine._record_encounter_pick(run, layout)
		run["current_room_layout"] = layout
		run["analytics"] = {"run_id": CALLER_RUN_ID}
		run["mode"] = "combat"
		var combat: Dictionary = Combat.new().create_combat(CALLER_FIXTURE_SEED, layout, run)
		combat["analytics"] = {"combat_id": CALLER_RUN_ID + "_" + room_type}
		run["combat_state"] = combat.duplicate(true)
		var section: Dictionary = run["map_sections"][int(room["section_index"])]
		var expected: Dictionary = {
			"room_type": room_type, "guardian_id": room.get("guardian_id", ""),
			"encounter_id": layout.get("encounter_id", ""),
			"biome": Bosses.element_for_boss(section["boss_id"]), "section_index": room["section_index"],
			"special_type": "", "special_variant": ""
		}
		if room_type == "guardian": check(not str(expected["guardian_id"]).is_empty(), "Guardian oracle has an authored Guardian id")
		if room_type == "combat": check(not str(expected["encounter_id"]).is_empty(), "normal fight oracle has an authored encounter id")
		if room_type == "boss": check(not str(room.get("boss_id", "")).is_empty(), "boss oracle has an authored boss id")
		var before: Dictionary = run.duplicate(true)
		check_caller_boundaries(run, combat, expected, room.get("boss_id", ""))
		check(run == before, "caller events preserve source run and combat: " + room_type)
	print("ENCOUNTER CALLER METADATA: %s (UI/headless; combat, Guardian, boss; start/end/rewards)" % ["PASS" if failures == previous_failures else "FAIL"])

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Store.set_storage_dir("user://encounter-context")
	Store.clear_storage()
	var store := Store.new()
	var context: Dictionary = {"run_id": "run", "combat_id": "combat", "turn": 3, "room_type": "guardian", "guardian_id": "rimejaw", "encounter_id": "tier2_fixture", "biome": "ice", "section_index": 2, "special_type": "", "special_variant": ""}
	for event_type: String in ["combat_started", "combat_ended", "reward_offered", "reward_choice", "reward_claimed"]:
		check(store.write_event(event_type, context, {"existing": true}), "event append succeeds")
		check(store.write_events([{ "event_type": event_type, "context": context, "payload": {"existing": true}}]), "batch append succeeds")
	var events: Array[Dictionary] = Store.load_all_events()
	check(events.size() == 10, "all existing event boundaries retained")
	for event: Dictionary in events:
		for key: String in context:
			check(event.get(key) == context[key], "%s retains %s" % [event["event_type"], key])
		check(event["schema_version"] == 1 and event["payload"] == {"existing": true}, "schema and payload preserved")
	var empty: Dictionary = store._event_record("legacy", {}, {}, "")
	check(empty.get("section_index") == -1, "unknown section is distinct from section zero")
	for key: String in ["room_type", "guardian_id", "encounter_id", "biome", "special_type", "special_variant"]:
		check(empty.get(key) == "", "legacy empty default: " + key)
	var run: Dictionary = preload("res://scripts/run_engine.gd").new().create_new_run(421, preload("res://scripts/progression_store.gd").default_data())
	var room: Dictionary = {}
	for candidate: Dictionary in run["rooms"].values():
		if candidate["type"] == "guardian":
			room = candidate
			break
	run["current_room"] = room["coord"]
	var inferred: Dictionary = preload("res://scripts/encounter_analytics_context.gd").fields(run, {}, room)
	var section: Dictionary = preload("res://scripts/section_map_graph.gd").section(run, int(room["section_index"]))
	check(inferred["biome"] == preload("res://scripts/dragon_boss_library.gd").element_for_boss(section["boss_id"]), "Guardian biome comes from the actual section boss")
	room["encounter_id"] = "retained_reward_encounter"
	room["biome"] = "ice"
	var scene = preload("res://scripts/run_scene.gd").new()
	var before: Dictionary = run.duplicate(true)
	var combat: Dictionary = {"room_type": "guardian", "guardian_id": room["guardian_id"]}
	var started: Dictionary = scene._analytics_context_from_states(run, combat)
	var reward: Dictionary = scene._analytics_context_from_states(run, {})
	for key: String in ["room_type", "guardian_id", "encounter_id", "biome", "section_index", "special_type", "special_variant"]:
		check(started.has(key) and reward.has(key) and started.get(key) == reward.get(key), "context survives combat clearing: " + key)
	check(reward.get("encounter_id") == "retained_reward_encounter" and reward.get("biome") == "ice" and reward.get("section_index") == room["section_index"], "caller uses persisted room metadata")
	check(run == before, "context construction leaves run and saves unchanged")
	scene.free()
	test_caller_metadata()
	print("ENCOUNTER ANALYTICS: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)

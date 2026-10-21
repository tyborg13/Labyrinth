extends SceneTree
const Store = preload("res://scripts/analytics_store.gd")
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: " + message)

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
		check(started[key] == reward[key], "context survives combat clearing: " + key)
	check(reward["encounter_id"] == "retained_reward_encounter" and reward["biome"] == "ice" and reward["section_index"] == room["section_index"], "caller uses persisted room metadata")
	check(run == before, "context construction leaves run and saves unchanged")
	scene.free()
	print("ENCOUNTER ANALYTICS: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)

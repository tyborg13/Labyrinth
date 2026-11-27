extends RefCounted
## Compare live combat with the installed combat after a production Continue.

const Store = preload("res://scripts/progression_store.gd")
const CardDrag = preload("res://scripts/card_drag_play_rules.gd")
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const RUN_FILE := "run.save"
const PROFILE_FILE := "progression.json"
const WITNESS_FILE := "combat.witness"


static func snapshot(scene: Node) -> Dictionary:
	var run: Dictionary = scene.get("_run_state")
	var combat: Dictionary = scene.get("_combat_state")
	var units: Dictionary = {"player": combat.get("player", {})}
	var positions: Dictionary = {"player": units["player"].get("pos")}
	var intents: Dictionary = {}
	for collection: String in ["enemies", "illusions", "summons"]:
		for actor: Dictionary in combat.get(collection, []):
			var key: String = "%s:%s" % [collection, actor.get("id")]
			var unit: Dictionary = actor.duplicate(true)
			unit.erase("intent")
			units[key] = unit
			positions[key] = actor.get("pos")
			if actor.has("intent"): intents[key] = actor["intent"]
	var deck: Dictionary = combat.get("deck", {})
	return {
		"boundary": [run.get("mode"), run.get("seed"), run.get("current_room"),
			combat.get("turn"), combat.get("current_actor")],
		"units": units, "positions": positions, "intents": intents,
		"surfaces": combat.get("surfaces", {}),
		"hand": [deck.get("hand", [])],
	}.duplicate(true)


static func save(scene: Node, source: String, destination: String) -> bool:
	var expected: Dictionary = snapshot(scene)
	scene.call("_save_run_progress")
	if DirAccess.make_dir_recursive_absolute(destination) != OK: return false
	for name: String in [RUN_FILE, PROFILE_FILE]:
		if DirAccess.copy_absolute(source.path_join(name), destination.path_join(name)) != OK: return false
	var file := FileAccess.open(destination.path_join(WITNESS_FILE), FileAccess.WRITE)
	if file == null: return false
	return file.store_var(expected, false)


static func stage(source: String, destination: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(destination) != OK: return false
	for name: String in [RUN_FILE, PROFILE_FILE]:
		if DirAccess.copy_absolute(source.path_join(name), destination.path_join(name)) != OK: return false
	Store.set_run_storage_path(destination.path_join(RUN_FILE))
	Store.set_storage_path(destination.path_join(PROFILE_FILE))
	return true


static func compare(scene: Node, directory: String) -> Dictionary:
	var file := FileAccess.open(directory.path_join(WITNESS_FILE), FileAccess.READ)
	if file == null: return {"witness": {"expected": WITNESS_FILE, "actual": "missing"}}
	var stored: Variant = file.get_var(false)
	if not stored is Dictionary: return {"witness": {"expected": "Dictionary", "actual": typeof(stored)}}
	var expected: Dictionary = stored
	# The first diagnostic witness used a second, empty hand slot.
	if expected.get("hand", []).size() == 2 and expected["hand"][1].is_empty():
		expected["hand"].resize(1)
	var actual: Dictionary = snapshot(scene)
	var differences: Dictionary = {}
	for field: String in actual:
		if not expected.has(field) or expected[field] != actual[field]:
			differences[field] = {"expected": expected.get(field), "actual": actual[field]}
	return differences



static func first_targeted_card(scene: Node) -> int:
	var combat: Dictionary = scene.get("_combat_state")
	for index: int in range((combat["deck"]["hand"] as Array).size()):
		if not scene.call("_guided_tutorial_card_allowed", index): continue
		var options: Dictionary = scene.call("_card_play_options_for_index", index)
		if options.get("printed_playable", false) and CardDrag.preview_requires_target(options.get("play", {})):
			return index
	return -1

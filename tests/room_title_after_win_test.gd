extends SceneTree
# A won room keeps its name in the header: the reward and the cleared room read as the fight did, not "Chamber".
# A room without a fight is named for what it holds, on arrival and once its screen closes.

const GameData = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const NON_FIGHT_TITLES: Dictionary = {
	"scavenger": "Scavenger's Nook",
	"campfire": "Ember Hearth",
	"treasure": "Relic Cache",
	"graftwright": "Graftwright's Workshop",
	"event": "",
}

var _scene: Node
var _failures: int = 0

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://room_title_after_win_test/progression.json")
	ProgressionStore.set_run_storage_path("user://room_title_after_win_test/current_run.save")
	SettingsStore.set_storage_path("user://room_title_after_win_test/settings.json")
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	var engine: RunEngine = RunEngine.new()
	var start: Dictionary = engine.create_new_run(31233, ProgressionStore.default_data())
	var destination: Vector2i = engine.available_moves(start)[0]
	var run: Dictionary = engine.move_to_room(start, destination)
	var combat: Dictionary = run.get("combat_state", {})
	_scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	await process_frame
	await _expect_title(start, "Central Waypoint", "start room")
	var room_name: String = str(combat.get("room_name", ""))
	if room_name.is_empty():
		_fail("the first room should be a fight, mode %s" % str(run.get("mode")))
	for enemy: Dictionary in combat.get("enemies", []): enemy["hp"] = 0
	await _expect_title(engine.finish_combat(run, combat), room_name, "won fight")
	var key: String = "%d,%d" % [destination.x, destination.y]
	for kind: String in NON_FIGHT_TITLES.keys():
		var before: Dictionary = start.duplicate(true)
		var room: Dictionary = (before["rooms"] as Dictionary)[key]
		room["type"] = kind
		room["merchant_kind"] = "scavenger" if kind == "scavenger" else ""
		room["npcs"] = [{"id": "scavenger", "pos": Vector2i(3, 4)}] if kind == "scavenger" else []
		room["cleared"] = false
		var arrived: Dictionary = engine.move_to_room(before, destination)
		var expected: String = str(NON_FIGHT_TITLES[kind])
		if kind == "event":
			expected = str(GameData.event_def(str((arrived["rooms"] as Dictionary)[key].get("event_id", ""))).get("title", ""))
			if expected.is_empty(): _fail("the event room picked no titled event")
		await _expect_title(arrived, expected, "%s arrival (mode %s)" % [kind, str(arrived.get("mode"))])
		var returned: Dictionary = arrived.duplicate(true)
		(returned["rooms"] as Dictionary)[key]["cleared"] = true
		returned["mode"] = "room"
		await _expect_title(returned, expected, "%s after its screen closes" % kind)
	print("ROOM TITLE AFTER WIN: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(1 if _failures > 0 else 0)

func _expect_title(state: Dictionary, expected: String, label: String) -> void:
	_scene.call("_load_run_state", state)
	await process_frame
	var title: String = str((_scene.get("room_title") as Label).text)
	if title != expected:
		_fail("%s: header reads %s, expected %s" % [label, title, expected])

func _fail(message: String) -> void:
	_failures += 1
	print("FAIL: %s" % message)

extends RefCounted
## The same combat scene and settings for the headless checks and native proof.

const RunScene = preload("res://scenes/run_scene.tscn")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")

const RESOLUTION := Vector2i(1920, 1080)
const UI_SCALE := 1.0
const READY_FRAMES := 600
const SETTLE_FRAMES := 5
const ROOM_COORD := Vector2i(1, 0)
const ROOM_DEPTH := 1
const SETTINGS_PATH := "user://crd33-settings.json"
const PROGRESSION_PATH := "user://crd33-progression.json"
const RUN_PATH := "user://crd33-run.save"

var tree: SceneTree
var viewport: SubViewport
var scene: Node
var progression: Dictionary


func start(scene_tree: SceneTree) -> bool:
	tree = scene_tree
	Runtime.apply_from_environment()
	Settings.set_storage_path(SETTINGS_PATH)
	Store.set_storage_path(PROGRESSION_PATH)
	Store.set_run_storage_path(RUN_PATH)
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	settings["reduced_motion"] = true
	Settings.save_settings(settings)
	Settings.apply_settings(settings, tree.root, false)
	tree.root.size = RESOLUTION
	viewport = SubViewport.new()
	viewport.size = RESOLUTION
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(viewport)
	scene = RunScene.instantiate()
	viewport.add_child(scene)
	progression = Store.default_data()
	for id: String in Tutorial.prompt_ids():
		progression = Tutorial.resolve_progression(progression, id)
	for frame: int in range(READY_FRAMES):
		if scene.call("initial_presentation_is_ready"): return true
		await tree.process_frame
	return false


func install(state: Dictionary) -> void:
	var room: Dictionary = {
		"name": "Surface Test", "coord": ROOM_COORD, "depth": ROOM_DEPTH, "type": "combat",
		"umbra_stage": state["umbra"]["stage"], "grid": state["grid"], "player_start": state["player"]["pos"],
		"loot": [], "traps": [], "enemies": state["enemies"],
	}
	var run: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["current_room"] = ROOM_COORD
	run["current_room_layout"] = room
	run["progression"] = progression.duplicate(true)
	run["combat_state"] = state
	run["notice"] = ""
	scene.call("_load_run_state", run)
	await settle()


func settle() -> void:
	for frame: int in range(SETTLE_FRAMES):
		await tree.process_frame


func close() -> void:
	viewport.queue_free()
	await tree.process_frame


static func visible_text(node: Node) -> PackedStringArray:
	var result := PackedStringArray()
	if node is Label and node.is_visible_in_tree():
		result.append(node.text)
	elif node is RichTextLabel and node.is_visible_in_tree():
		result.append(node.get_parsed_text())
	for child: Node in node.get_children():
		result.append_array(visible_text(child))
	return result

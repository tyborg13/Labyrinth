extends RefCounted

const Fixture = preload("res://tools/gfix30/fixture.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const TUTORIAL = preload("res://scripts/contextual_combat_tutorial.gd")
const UI_SCALE: float = 1.0
const RUN_SCENE: String = "res://scenes/run_scene.tscn"
const INSTALL_TIMEOUT_MSEC: int = 20000

static func install(tree: SceneTree) -> Control:
	tree.root.size = Fixture.RESOLUTION
	tree.root.content_scale_size = Fixture.RESOLUTION
	tree.root.content_scale_factor = UI_SCALE
	tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	OS.set_environment("LABYRINTH_PROBE_WINDOW", "1")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	var state: Dictionary = Fixture.ash_starter()
	if state.is_empty():
		print("GFIX30: Missing Ash Confessional fixture room")
		return null
	state["progression"] = TUTORIAL.complete_tutorial(state["progression"])
	if not Settings.save_settings(settings) or not Store.save_data(state["progression"]) or not Store.save_run_state(state):
		print("GFIX30: Could not save the isolated RunScene fixture")
		return null
	tree.root.set_meta("labyrinth_resume_saved_run", true)
	if tree.change_scene_to_file(RUN_SCENE) != OK: return null
	await tree.scene_changed
	var deadline: int = Time.get_ticks_msec() + INSTALL_TIMEOUT_MSEC
	var scene: Node = tree.current_scene
	while Time.get_ticks_msec() < deadline:
		var view: Control = scene.get("_event_view")
		if scene.has_installed_run() and is_instance_valid(view) and view.is_visible_in_tree() and not view.choices.is_empty():
			return view
		await tree.process_frame
	print("GFIX30: RunScene did not install the event")
	return null

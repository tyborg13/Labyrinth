extends SceneTree

const InitialGraph = preload("res://scripts/initial_run_graph.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Progression = preload("res://scripts/progression_store.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const Scenario = preload("res://scripts/guided_combat_scenario.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Shutdown = preload("res://scripts/application_shutdown.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")

const VIEWPORT_SIZE := Vector2i(1920, 1080)
const UI_SCALE: float = 1.0
const FIXTURE_SEED: int = 90211
const WAIT_MSEC: int = 20000
const PICKUP_CAPTURE_ALPHA: float = 0.9
const OUTPUT: String = "res://.godot/tut01/native"
const RELEASE_MOVE_SAVE: String = "res://.godot/tut01/release-saves/choose_move.save"
const RELEASE_MOVE_TEXT: String = "You begin each turn with 2 Movement. Use 1 to move onto the glowing tile."
const MOVE_TEXT: String = "You begin each turn with 2 Movement. Use 1 to step onto the gear."
const LOOT_TEXT: String = "Gear and items appear on tiles. Step onto them before combat ends, or they crumble."

var _dry_run: bool
var _release_move: bool


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_dry_run = OS.get_cmdline_user_args().has("--dry-run")
	_release_move = OS.get_cmdline_user_args().has("--release-move")
	_run_capture.call_deferred()


func _run_capture() -> void:
	var ready: bool = await _record_new_run()
	var mode: String = "RELEASE MOVE COPY" if _release_move else ("DRY RUN" if _dry_run else "NATIVE")
	print("TUT-01 %s: %s" % [mode, "PASS" if ready else "FAIL"])
	Shutdown.request(self, "tut01_proof", 0 if ready else 1)


func _record_new_run() -> bool:
	if not _require(_dry_run == (DisplayServer.get_name() == "headless"), "Use --dry-run for a headless proof"):
		return false
	if not _require(not _release_move or _dry_run, "The release checkpoint check runs headless"):
		return false
	if not _require(OS.get_environment("LABYRINTH_CEL_LOOK") == "all", "Proof must use the production cel look"):
		return false
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	if not _require(Settings.save_settings(settings), "Save the 100% windowed settings"):
		return false
	if not _dry_run:
		root.mode = Window.MODE_WINDOWED
		DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_factor = UI_SCALE
	root.set_meta(InitialGraph.SEED_OVERRIDE, FIXTURE_SEED)
	if not _require(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT)) == OK, "Create the proof output directory"):
		return false
	if not _require(not Progression.has_saved_run() and Progression.load_data().get("run_counter") == 0, "Start with a fresh process-local profile"):
		return false
	if _release_move and not _copy_release_checkpoint():
		return false
	var scene: Node = await _open_run_from_menu(_release_move)
	if scene == null:
		return false
	root.remove_meta(InitialGraph.SEED_OVERRIDE)
	if _release_move:
		return await _check_release_move_copy(scene)
	var state: Dictionary = scene.get("_run_state")
	if not _require(state.get("seed") == FIXTURE_SEED and state.get("run_index") == 1, "The menu starts the seeded first run"):
		return false
	if not await _enter_teaching_room(scene, state):
		return false
	return await _record_first_step(scene)


func _open_run_from_menu(continue_run: bool) -> Node:
	if not _require(change_scene_to_file("res://scenes/main_menu.tscn") == OK, "Open the production main menu"):
		return null
	await scene_changed
	var menu_id: int = current_scene.get_instance_id()
	var run_button: Button = current_scene.get_node("MenuColumn/ContinueButton" if continue_run else "MenuColumn/StartButton")
	if not _require(not run_button.disabled, "The main menu action is available"):
		return null
	run_button.pressed.emit()
	if not await _wait_until(func() -> bool: return is_instance_valid(current_scene) and current_scene.get_instance_id() != menu_id and current_scene.has_method("has_installed_run"), "run scene"):
		return null
	var scene: Node = current_scene
	if not await _wait_until(func() -> bool: return scene.call("has_installed_run") and not scene.get("_animation_lock"), "run installation"):
		return null
	return scene


func _copy_release_checkpoint() -> bool:
	Progression.set_run_storage_path(RELEASE_MOVE_SAVE)
	var checkpoint: Dictionary = Progression.load_saved_run()
	Progression.set_run_storage_path("")
	return _require(not checkpoint.is_empty() and Progression.save_run_state(checkpoint), "Copy the release move checkpoint into the isolated profile")


func _check_release_move_copy(scene: Node) -> bool:
	if not await _wait_until(func() -> bool: return _phase_is_visible(scene, Tutorial.PHASE_SELECT_PLAYER), "release move selection"):
		return false
	var fight: Dictionary = scene.get("_combat_state")
	var tile: Vector2i = Scenario.move_tile(fight)
	var gear: Dictionary = {}
	for loot: Dictionary in fight["loot"]:
		if loot.get("kind") == "equipment" and not loot.get("claimed", false):
			gear = loot
			break
	if not _require(not gear.is_empty() and gear["pos"] != tile, "Continue preserves the off-step gear from release"):
		return false
	await scene.call("_on_board_tile_clicked", fight["player"]["pos"])
	if not _check_move_copy(scene, RELEASE_MOVE_TEXT, "release save"):
		return false
	await scene.call("_on_board_tile_clicked", tile)
	return _require(_phase_is_visible(scene, Tutorial.PHASE_FLOOR_LOOT), "Finishing the release save's first move reaches the new lesson")


func _enter_teaching_room(scene: Node, state: Dictionary) -> bool:
	while scene.get("_dialogue_active"):
		scene.call("_advance_dialogue")
		if scene.call("_has_current_dialogue_options"):
			var line: Dictionary = scene.call("_current_dialogue_line")
			var exits: Array = (line.get("options", []) as Array).filter(func(option: Dictionary) -> bool: return option.get("action") == "close" and not option.get("disabled", false))
			if not _require(not exits.is_empty(), "The opening dialogue offers its usual exit"):
				return false
			scene.call("_on_dialogue_option_pressed", exits[0])
		await process_frame
	var map: Control = scene.get("_large_map_scrim")
	if not map.visible:
		scene.call("_open_large_map")
	if not await _wait_until(func() -> bool: return map.visible, "first room's map"):
		return false
	var engine = scene.get("_run_engine")
	for destination: Vector2i in engine.available_moves(state):
		if engine.room_metadata(state, destination).get("type") != "combat":
			continue
		await scene.call("_on_large_map_room_selected", destination)
		if scene.get("_run_state").get("mode") == "pre_battle":
			await scene.call("_on_pre_battle_start_pressed")
		return await _wait_until(func() -> bool: return _phase_is_visible(scene, Tutorial.PHASE_SELECT_PLAYER), "first authored prompt")
	return _require(false, "The seeded run offers a combat room from the opening map")


func _record_first_step(scene: Node) -> bool:
	var fight: Dictionary = scene.get("_combat_state")
	var tile: Vector2i = Scenario.move_tile(fight)
	if not _require(Scenario.is_authored(fight), "The first combat is the teaching room"):
		return false
	await scene.call("_on_board_tile_clicked", fight["player"]["pos"])
	var prompt: Control = scene.get("_contextual_combat_prompt")
	if not _check_move_copy(scene, MOVE_TEXT, "fresh run"):
		return false
	if not _require(scene.call("_guided_tutorial_allowed_board_tiles") == [tile] and prompt.get_meta("attention_pulse", false), "Only the authored gear tile is highlighted"):
		return false
	var gear_id: String
	for loot: Dictionary in fight.get("loot", []):
		if loot.get("kind") == "equipment" and loot.get("pos") == tile and not loot.get("claimed", false):
			gear_id = loot["equipment_id"]
			break
	if not _require(not gear_id.is_empty(), "Reserved gear is visible on the highlighted step"):
		return false
	if not await _capture("01_move_step"):
		return false

	# Leave the live movement coroutine running while the existing feedback animates.
	scene.call("_on_board_tile_clicked", tile)
	if not await _wait_until(func() -> bool: return _pickup_is_visible(scene), "normal GEAR FOUND feedback"):
		return false
	if not _require(not _phase_is_visible(scene, Tutorial.PHASE_FLOOR_LOOT), "The new lesson waits for the pickup presentation"):
		return false
	if not await _capture("02_pickup_feedback"):
		return false
	var movement_checkpoint: Dictionary = Progression.load_checkpoint_for_resume()
	if not await _wait_until(func() -> bool: return not scene.get("_animation_lock"), "end of the pickup presentation"):
		return false
	var resumed: bool = _check_checkpoint(movement_checkpoint, Tutorial.PHASE_SELECT_PLAYER, "during pickup")
	var lesson_visible: bool = _require(_phase_is_visible(scene, Tutorial.PHASE_FLOOR_LOOT), "Loot on the Floor must follow the pickup presentation")
	if not resumed or not lesson_visible:
		return false
	if not _check_checkpoint(Progression.load_checkpoint_for_resume(), Tutorial.PHASE_FLOOR_LOOT, "during the loot lesson"):
		return false
	var continue_button: Button = prompt.get("_continue_button")
	var title: Label = prompt.get("_title")
	if not _require(title.text == "Loot on the Floor" and prompt.get_meta("prompt_text", "") == LOOT_TEXT
		and continue_button.visible and continue_button.text == "Continue", "The authored loot title, sentence and Continue are visible"):
		return false
	var after: Dictionary = scene.get("_combat_state")
	var run_state: Dictionary = scene.get("_run_state")
	if not _require(after["player"]["pos"] == tile and run_state["equipment_inventory"].has(gear_id), "The normal walk delivered the gear to inventory"):
		return false
	print("TUT-01 native sequence: gear=%s collected=true tile=%s pickup_feedback=shown lesson=%s" % [
		gear_id, after["player"]["pos"], scene.get("_guided_tutorial_phase_id"),
	])
	if not await _capture("03_loot_on_the_floor"):
		return false
	if _dry_run:
		scene = await _open_run_from_menu(true)
		if scene == null or not await _wait_until(func() -> bool: return _phase_is_visible(scene, Tutorial.PHASE_FLOOR_LOOT), "loot lesson after Continue Run"):
			return false
		print("TUT-01 Continue Run during lesson: %s" % scene.get("_guided_tutorial_phase_id"))
		prompt = scene.get("_contextual_combat_prompt")
		continue_button = prompt.get("_continue_button")
	continue_button.pressed.emit()
	if not await _wait_until(func() -> bool: return _phase_is_visible(scene, Tutorial.PHASE_INSPECT_ENEMY), "Continue leads to the enemy prompt"):
		return false
	return _check_checkpoint(Progression.load_checkpoint_for_resume(), Tutorial.PHASE_INSPECT_ENEMY, "after Continue")


func _check_move_copy(scene: Node, expected: String, label: String) -> bool:
	var prompt: Control = scene.get("_contextual_combat_prompt")
	var definition: Dictionary = prompt.get("_definition")
	var text: String = prompt.get_meta("prompt_text", "")
	print("TUT-01 move copy (%s): %s" % [label, text])
	return _require(_phase_is_visible(scene, Tutorial.PHASE_CHOOSE_MOVE) and text == expected
		and definition.get("pointer_text") == expected and definition.get("controller_text") == expected,
		"The exact move sentence is configured for both inputs")


func _check_checkpoint(checkpoint: Dictionary, expected: String, label: String) -> bool:
	if not _require(not checkpoint.is_empty(), "Load the saved run " + label):
		return false
	var scene := RunScene.new()
	scene.set("_run_state", checkpoint)
	scene.set("_combat_state", checkpoint["combat_state"])
	scene.set("_progression", checkpoint["progression"])
	scene.call("_guided_tutorial_reconcile_phase")
	var phase: String = scene.get("_guided_tutorial_phase_id")
	scene.free()
	print("TUT-01 branch save: %s -> %s" % [label, phase])
	return _require(phase == expected, "%s must resume at %s" % [label, expected])


func _phase_is_visible(scene: Node, phase: String) -> bool:
	var host: Control = scene.get("_contextual_combat_prompt_host")
	return is_instance_valid(host) and host.is_visible_in_tree() and scene.get("_guided_tutorial_phase_id") == phase


func _pickup_is_visible(scene: Node) -> bool:
	var layer: Control = scene.get("_card_fx_layer")
	var banner := layer.get_node_or_null("LoadoutAcquisitionBanner") as Label
	var icon := layer.get_node_or_null("EquipmentAcquisitionIcon") as Control
	return (
		is_instance_valid(banner) and banner.is_visible_in_tree() and banner.text == "GEAR FOUND"
		and banner.modulate.a >= PICKUP_CAPTURE_ALPHA
		and is_instance_valid(icon) and icon.is_visible_in_tree() and icon.modulate.a >= PICKUP_CAPTURE_ALPHA
	)


func _capture(name: String) -> bool:
	if _dry_run:
		print("TUT-01 planned PNG: %s/%s.png" % [OUTPUT, name])
		return true
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if not _require(image != null and image.get_size() == VIEWPORT_SIZE and root.content_scale_factor == UI_SCALE, "Capture must be 1920×1080 at 100%"):
		return false
	var path: String = ProjectSettings.globalize_path(OUTPUT.path_join(name + ".png"))
	if not _require(image.save_png(path) == OK, "Write " + path):
		return false
	print(path)
	return true


func _wait_until(condition: Callable, label: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + WAIT_MSEC
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	return _require(false, "Timed out waiting for " + label)


func _require(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
	return condition

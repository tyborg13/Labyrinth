extends SceneTree
## Drive RunScene's real door and reward handlers in an isolated proof run.

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const Route = preload("res://tools/scn02/entry_route.gd")
const StageState = preload("res://tools/scn02/stage_state.gd")

const SEED: int = 7262026
const SIZE: Vector2i = Vector2i(1920, 1080)
const FPS: int = 60
const READY_MSEC: int = 12000
const FINISHER_CARD: String = "pale_spark"
const FINISHER_TARGET_HP: int = 1
const FINISHER_TARGET_TILE: Vector2i = Vector2i(3, 6)
const CASES: Dictionary = {
	"campfire": Vector2i(-2, 1),
	"treasure": Vector2i(-2, -1),
	"reward": Vector2i(1, -1),
	"scavenger": Vector2i(2, -1),
}

var _engine := RunEngine.new()
var _screen: Control


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if DisplayServer.get_name() != "headless" or args.size() != 1 or not CASES.has(args[0]):
		_fail("Expected one headless case: campfire, treasure, reward, or scavenger.")
		return
	if Runtime.apply_from_environment().is_empty():
		_fail("Expected a task-local user directory.")
		return
	Engine.max_fps = FPS
	process_frame.connect(func() -> void: RenderingServer.force_draw(false))

	var scenario: String = args[0]
	var destination: Vector2i = CASES[scenario]
	var expected_mode: String = "room" if scenario == "scavenger" else scenario
	var settings: Dictionary = Settings.load_settings()
	settings["ui_scale"] = 1.0
	var profile: Dictionary = Store.load_data()
	var run: Dictionary = _engine.create_new_run(SEED, profile)
	var path: Array[Vector2i] = Route.find(run, destination)
	var previous: Dictionary = Route.before_last(_engine, run, path)
	if previous.is_empty() or not Settings.save_settings(settings) or not Store.save_run_state(previous):
		_fail("Could not prepare the cleared predecessor of %s." % destination)
		return

	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.msaa_2d = int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d")) as Viewport.MSAA
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	_resume(viewport)
	if not await _wait(func() -> bool: return _screen.call("initial_presentation_is_ready")):
		_fail("The predecessor did not load.")
		return
	var before: Dictionary = _screen.get("_run_state")
	if not _engine.room_metadata(before, before["current_room"]).get("cleared", false):
		_fail("The live door must start in a cleared room.")
		return
	if _screen.get("_dialogue_active"):
		_screen.call("_close_dialogue")
	if (_screen.get("_large_map_scrim") as Control).visible:
		_screen.call("_close_large_map")
	var door: Vector2i = _screen.call("_door_tile_for_destination", destination)
	if door.x < 0:
		_fail("The destination is missing a live board door.")
		return
	print("LIVE_ENTRY_DOOR %s %s via %s to %s" % [scenario, before["current_room"], door, destination])
	_screen.get("board_view").emit_signal("tile_clicked", door)
	if scenario == "reward":
		if not await _wait(_entered.bind(destination, RunEngine.MODE_PRE_BATTLE)) or not await _win():
			_fail("Could not win the live combat through the card and board handlers.")
			return
	if not await _settled(destination, expected_mode, scenario):
		_fail("The live transition did not present %s." % scenario)
		return
	print("LIVE_ENTRY_RESULT %s" % JSON.stringify(StageState.read(_screen)))
	_screen.queue_free()
	await process_frame
	_resume(viewport)
	if not await _settled(destination, expected_mode, scenario):
		_fail("Continue did not present the game-written %s checkpoint." % scenario)
		return
	print("LIVE_RESUME_RESULT %s" % JSON.stringify(StageState.read(_screen)))
	viewport.queue_free()
	await process_frame
	quit(0)


func _resume(viewport: SubViewport) -> void:
	var scene: PackedScene = load("res://scenes/run_scene.tscn")
	_screen = scene.instantiate() as Control
	root.set_meta("labyrinth_resume_saved_run", true)
	viewport.add_child(_screen)


func _settled(destination: Vector2i, mode: String, scenario: String) -> bool:
	if not await _wait(func() -> bool: return _screen.call("initial_presentation_is_ready")):
		return false
	if not await _wait(_presented.bind(destination, mode, scenario)):
		return false
	return await _wait(func() -> bool: return not _has_running_tweens())


func _win() -> bool:
	await _screen.call("_on_pre_battle_start_pressed")
	if not await _wait(func() -> bool: return not _screen.get("_animation_lock") and _screen.get("_run_state").get("mode") == "combat"):
		return false
	# Prepare the last hit in the generated encounter. Damage, the combat
	# outcome, commitment and the reward sequence still run through production.
	var run: Dictionary = _screen.get("_run_state")
	var combat: Dictionary = run["combat_state"].duplicate(true)
	var enemies: Array = combat["enemies"]
	if enemies.is_empty(): return false
	for enemy: Dictionary in enemies:
		enemy["hp"] = 0
	var target: Dictionary = enemies[0]
	target["pos"] = FINISHER_TARGET_TILE
	target["hp"] = FINISHER_TARGET_HP
	target["block"] = 0
	combat["deck"]["hand"] = [FINISHER_CARD]
	_screen.call("_load_run_state", _engine.set_combat_state(run, combat))
	await process_frame
	await _screen.call("_on_card_pressed", 0)
	var tile: Vector2i = target["pos"]
	if not (_screen.get("_pending_target_tiles") as Array).has(tile):
		print("LIVE_ENTRY_TARGET_REJECTED %s (%s)" % [tile, _screen.get("_pending_target_tiles")])
		return false
	_screen.get("board_view").emit_signal("tile_clicked", tile)
	return true


func _entered(destination: Vector2i, mode: String) -> bool:
	var state: Dictionary = _screen.get("_run_state")
	return state.get("current_room") == destination and state.get("mode") == mode and not _screen.get("_animation_lock")


func _presented(destination: Vector2i, mode: String, scenario: String) -> bool:
	if not _entered(destination, mode): return false
	if scenario == "reward":
		var row: Control = _screen.find_child("RewardCardRow", true, false)
		return row != null and row.is_visible_in_tree() and not _screen.get("_reward_intro_in_progress")
	if scenario == "treasure":
		return not _screen.call("_treasure_presentation_busy") and (_screen.get("_relic_choice_bar") as Control).is_visible_in_tree()
	if scenario == "scavenger":
		return (_screen.get("_scavenger_shop_view") as Control).is_visible_in_tree()
	return (_screen.get("_relic_choice_bar") as Control).is_visible_in_tree()


func _has_running_tweens() -> bool:
	for tween: Tween in get_processed_tweens():
		if tween.is_running(): return true
	return false


func _wait(ready: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec() + READY_MSEC
	while not ready.call():
		if Time.get_ticks_msec() >= deadline: return false
		await process_frame
	return true


func _fail(reason: String) -> void:
	printerr("LIVE_ENTRY_ERROR %s" % reason)
	quit(1)

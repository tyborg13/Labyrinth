extends SceneTree

const Combat = preload("res://scripts/combat_engine.gd")
const Fixture = preload("res://tests/suites/player_movement_suite.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const OUTPUT := "user://probes/player_movement_outcome"
var failures: Array[String]
var scene: Node
var view: SubViewport
var combat := Combat.new()

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Progression.set_storage_path("user://movement_outcome_progression.json")
	Progression.set_run_storage_path("user://movement_outcome_run.save")
	Progression.clear_saved_run()
	Settings.set_storage_path("user://movement_outcome_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["music_volume"] = 0.0
	settings["sfx_volume"] = 0.0
	Settings.save_settings(settings)
	Analytics.set_storage_dir("user://movement_outcome_analytics")
	Analytics.clear_storage()
	if _capture_requested(): DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	view = SubViewport.new()
	view.size = Vector2i(1920, 1080)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.msaa_2d = Viewport.MSAA_4X
	root.add_child(view)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	view.add_child(scene)
	await create_timer(0.2).timeout
	await _test_stale_requests()
	await _test_hidden_collision()
	await _test_bleed(false)
	await _test_bleed(true)
	scene.queue_free()
	view.queue_free()
	await process_frame
	for failure: String in failures: push_error(failure)
	print("PLAYER MOVEMENT OUTCOME: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	if _capture_requested(): print(ProjectSettings.globalize_path(OUTPUT))
	quit(0 if failures.is_empty() else 1)

func _load_fixture(state: Dictionary) -> void:
	scene.call("_cancel_player_movement_selection", false)
	scene.call("_reset_card_resolution")
	var progression: Dictionary = Progression.default_data()
	for prompt_id: String in Tutorial.prompt_ids():
		progression = Tutorial.resolve_progression(progression, prompt_id)
	var run: Dictionary = preload("res://scripts/run_engine.gd").new().create_new_run(260907, progression)
	run["mode"] = "combat"
	run["combat_state"] = state.duplicate(true)
	run["current_room_layout"] = Fixture._room()
	run["current_room"] = Vector2i(1, 0)
	scene.set("_progression", progression)
	scene.set("_run_state", run)
	scene.call("_sync_combat_state_from_run")
	scene.set("_animation_lock", false)
	scene.call("_refresh_ui")
	await create_timer(0.12).timeout

func _test_stale_requests() -> void:
	var state: Dictionary = Fixture._state(combat)
	await _load_fixture(state)
	scene.call("_begin_player_movement_selection")
	var before: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	await scene.call("_commit_player_movement", Vector2i.ZERO)
	_expect(scene.get("_combat_state") == before and not bool(scene.get("_animation_lock")), "Invalid movement does not commit or animate")
	# Keep a formerly legal target selected while the authoritative actor changes.
	before["player_turn_restrictions"]["immobilized"] = true
	scene.set("_combat_state", before.duplicate(true))
	await scene.call("_commit_player_movement", Vector2i(3, 4))
	_expect(scene.get("_combat_state") == before and not bool(scene.get("_animation_lock")), "Stale movement while Immobilized is rejected without feedback or outcome")
	var rejected: Dictionary = combat.apply_player_movement(before, Vector2i(3, 4))
	_expect(not bool((rejected.get("last_player_movement", {}) as Dictionary).get("resolved", false)), "Core distinguishes unvalidated request from interrupted movement")

func _test_hidden_collision() -> void:
	var room: Dictionary = Fixture._room()
	room["umbra_stage"] = "eclipse"
	room["enemies"][0]["pos"] = Vector2i(4, 4)
	var state: Dictionary = combat.create_combat(260907, room, {"hp": 30, "max_hp": 30, "deck_cards": ["brace"], "hand_size": 1})
	_expect(combat.player_movement_targets(state).has(Vector2i(4, 4)), "Hidden occupancy does not leak into movement targets")
	await _load_fixture(state)
	scene.call("_begin_player_movement_selection")
	await scene.call("_commit_player_movement", Vector2i(4, 4))
	var after: Dictionary = scene.get("_combat_state") as Dictionary
	_expect(after["player"]["pos"] == Vector2i(3, 4), "Hidden collision commits the actual traversed endpoint")
	_expect(int(after["umbra"].get("movement_interrupted_total", 0)) == 1, "Hidden collision accounting survives UI commit")
	_expect(int(after["last_player_movement"].get("spent", 0)) == 1, "Hidden collision spends only the traversed step")

func _test_bleed(lethal: bool) -> void:
	var state: Dictionary = Fixture._state(combat)
	state["player"]["hp"] = 1 if lethal else 8
	state["player"]["bleed"] = 1
	await _load_fixture(state)
	scene.call("_begin_player_movement_selection")
	scene.call("_on_board_tile_hovered", Vector2i(3, 4))
	if lethal: await _capture("lethal_bleed_before.png")
	var before_events: int = Analytics.load_all_events().size()
	var completion: Dictionary = {"done": false}
	_commit_and_complete(completion)
	await create_timer(0.16).timeout
	if lethal:
		var board: Node = scene.get("board_view") as Node
		var presentation: Dictionary = board.get("presentation") as Dictionary
		_expect(not (presentation.get("floating_texts", []) as Array).is_empty(), "Lethal pre-step Bleed displays player damage in place")
		await _capture("lethal_bleed_feedback.png")
	while not bool(completion["done"]): await process_frame
	var run: Dictionary = scene.get("_run_state") as Dictionary
	if lethal:
		_expect(str(run.get("mode")) == "defeat" and int(run.get("player_hp", -1)) == 0, "Pre-step Bleed defeat commits despite zero movement spent")
		_expect(not bool(scene.get("_player_movement_selected")) and not bool(scene.get("_animation_lock")), "Interrupted movement clears selection and completes animation")
		await _capture("lethal_bleed_defeat.png")
	else:
		var after: Dictionary = scene.get("_combat_state") as Dictionary
		_expect(after["player"]["hp"] == 7 and after["player"]["pos"] == Vector2i(3, 4), "Surviving Bleed retains damage and ordinary movement")
		await _capture("surviving_bleed_after.png")
	var events: Array = Analytics.load_all_events().slice(before_events)
	var movement_events: Array = events.filter(func(event: Dictionary) -> bool: return str(event.get("event_type")) in ["player_moved", "player_movement_interrupted"])
	_expect(movement_events.size() == 1, "Each movement outcome emits one movement event")
	if not movement_events.is_empty():
		_expect(str(movement_events[0].get("event_type")) == ("player_movement_interrupted" if lethal else "player_moved"), "Interrupted attempts are separate from completed moves in analytics")

func _commit_and_complete(completion: Dictionary) -> void:
	await scene.call("_commit_player_movement", Vector2i(3, 4))
	completion["done"] = true

func _capture(filename: String) -> void:
	if not _capture_requested(): return
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(OUTPUT.path_join(filename))

func _capture_requested() -> bool:
	return false

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

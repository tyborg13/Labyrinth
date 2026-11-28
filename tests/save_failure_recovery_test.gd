extends SceneTree

const Analytics = preload("res://scripts/analytics_store.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Disk = preload("res://scripts/persistence_disk_worker.gd")
const Dragon = preload("res://tools/dragon_boss_inspection.gd")
const EventFixture = preload("res://tests/suites/event_view_suite.gd")
const Fight = preload("res://tools/fel28/fixtures.gd")
const Guardian = preload("res://tools/guardian_inspection.gd")
const InputDriver = preload("res://tools/fel20/input_driver.gd")
const InputRouter = preload("res://scripts/input_router.gd")
const Notifications = preload("res://scripts/run_notification_queue.gd")
const Persistence = preload("res://scripts/run_persistence.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Run = preload("res://scripts/run_engine.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Shutdown = preload("res://scripts/application_shutdown.gd")
const Store = preload("res://scripts/progression_store.gd")
const SurfaceMigration = preload("res://scripts/surface_save_migration.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")

const FIXTURE_SEED := 90217
const ORDINARY_COMBAT_SEED := 88100
const COMBAT_SEED_ATTEMPTS := 40
const DRAGON_DEPTH := 4
const SIZE := Vector2i(1920, 1080)
const UI_SCALE := 1.0
const WAIT_MSEC := 45000
const TOOLTIP_SECONDS := 2.0
const POINTER_REST := Vector2(8, 8)
const TOOLTIP := "Your rewards have been saved."
const VICTORY_NOTICE := "Could not save. Your rewards are still here; try Continue again."
const DEPARTURE_NOTICE := "Could not save. Try again before leaving."
const STAGED_CARD := "qa145_staged_card"
const TITLE := "res://scenes/main_menu.tscn"
const RUN_SCENE := "res://scenes/run_scene.tscn"
const RETRY_EMBERS := 7
const PLAYBACK_ANALYTICS := "user://qa145_playback_analytics"
const PLAYBACK_WRITE_DELAY_MSEC := 100
const HANDOFF_DRAIN_DELAY_MSEC := 200

var _input: RefCounted
var _capture_dir: String
var _fixture_ok := true

func _initialize() -> void:
	Runtime.apply_from_environment()
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = SIZE
	root.size = SIZE
	_input = InputDriver.new(root)
	if DisplayServer.get_name() == "headless": process_frame.connect(_headless_draw.call_deferred)
	_capture_dir = OS.get_environment("QA145_CAPTURE_DIR")
	_run.call_deferred()

func _headless_draw() -> void:
	RenderingServer.frame_pre_draw.emit()
	RenderingServer.frame_post_draw.emit()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--round-two"):
		await _test_recap_departure()
		await _test_title_load_failure()
		quit(0 if _fixture_ok else 1)
		return
	if args.has("--round-four"):
		await _test_recap_departure_race()
		await _test_reward_notice_after_title_failure()
		await _test_chronicle_notice_restore()
		if _fixture_ok: print("QA145R4 PASS findings=3")
		quit(0 if _fixture_ok else 1)
		return
	if args.has("--close-during-title"):
		await _test_close_during_title()
		return
	if args.has("--enemy-playback"):
		await _test_enemy_playback()
		quit(0 if _fixture_ok else 1)
		return
	var scene := await _open_fight()
	if scene == null:
		quit(1)
		return
	if not _check(Store.flush_pending_run_saves(), "settle the fixture checkpoint before injecting failure"):
		quit(1)
		return
	var blocker := _block_write(Store._run_storage_path)
	await scene._resolve_enemy_round("pass")
	if not _check(scene._run_engine.is_dragon_reward(scene._run_state), "lethal fire reached the dragon reward"):
		_unblock_write(blocker)
		quit(1)
		return
	var button := _continue_button(scene)
	if not _check(button != null, "dragon reward has a Continue button"):
		_unblock_write(blocker)
		quit(1)
		return
	var failed_text := button.get_tooltip()
	var shown: bool = scene.log_overlay.is_visible_in_tree() and scene.log_label.text.contains(VICTORY_NOTICE)
	var preceding: Dictionary = Store._inspect_run_file(Store._run_storage_path).get("state", {})
	_check(preceding.get("mode") == "combat", "failed victory kept the preceding fight checkpoint")
	_test_reward_identity(scene)
	await _capture("01-reward-save-failed", button)
	scene._run_state = scene._run_engine.add_held_embers(scene._run_state, RETRY_EMBERS)
	var expected_embers: int = scene._run_engine.held_embers(scene._run_state)
	_check(not scene._persist_committed_boundary("reward_intro_complete"), "retry-specific reward is queued behind the blocker")
	_unblock_write(blocker)
	var retry_saved := await _wait_for(func() -> bool:
		return _continue_button(scene).get_tooltip() == TOOLTIP and _disk_state().get("held_embers") == expected_embers
	)
	_check(not _victory_notice_visible(scene) and not scene._has_victory_save_notice(scene._run_state),
		"background retry clears the persistent victory notice")
	var saved_text := _continue_button(scene).get_tooltip()
	await _capture("02-reward-save-succeeded", _continue_button(scene))
	print("QA145 TOOLTIP failed=%s saved=%s" % [failed_text, saved_text])
	print("QA145 VICTORY_NOTICE shown=%s retry_saved=%s" % [shown, retry_saved])
	print("QA145 BACKGROUND_RETRY saved=%s notice_cleared=%s" % [retry_saved, not _victory_notice_visible(scene)])
	var departure := await _test_departure(scene)
	var passed := int(failed_text.is_empty() and saved_text == TOOLTIP) + int(shown and retry_saved) + int(departure)
	if departure:
		var capture_only := args.has("--capture-only")
		if not capture_only:
			await _test_resume_migration()
			await _test_guardian()
		await _test_event_departure()
		await _test_recap_departure()
		if not capture_only:
			await _test_enemy_playback()
			await _test_title_load_failure()
	var ok := passed == 3 and _fixture_ok
	print("QA145 %s cases=%d" % ["PASS" if ok else "FAIL", passed])
	quit(0 if ok else 1)

func _open_fight(fight: String = "enemy_turn", guardian: bool = false) -> RunScene:
	var profile := _profile()
	var state := _ordinary_combat(profile) if fight == "midfight" else _dragon_state(profile, "encounter")
	if not _check(not state.is_empty(), "find a production combat fixture"): return null
	if guardian:
		state = Guardian.build(Run.new(), Combat.new(), state, {"guardian_case": "encounter"})
	var scene := await _open_state(state, profile)
	if scene == null: return null
	Fight.stage(scene, fight)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_check(Store.flush_pending_run_saves(), "settle the staged combat")
	return scene

func _profile() -> Dictionary:
	return Tutorial.complete_tutorial(Store.default_data())

func _ordinary_combat(profile: Dictionary) -> Dictionary:
	var engine := Run.new()
	for seed: int in range(ORDINARY_COMBAT_SEED, ORDINARY_COMBAT_SEED + COMBAT_SEED_ATTEMPTS):
		var run := engine.create_new_run(seed, profile)
		for room: Vector2i in engine.available_moves(run):
			var moved := engine.move_to_room(run, room)
			if moved.get("mode") == "combat" and not moved.get("combat_state", {}).is_empty():
				return moved
	return {}

func _dragon_state(profile: Dictionary, phase: String) -> Dictionary:
	var engine := Run.new()
	return Dragon.build(engine, Combat.new(), engine.create_new_run(FIXTURE_SEED, profile, true), {
		"dragon_id": Bosses.boss_id_for_depth(FIXTURE_SEED, DRAGON_DEPTH),
		"dragon_depth": DRAGON_DEPTH, "dragon_case": phase,
	})

func _open_state(state: Dictionary, profile: Dictionary, block_resume: bool = false) -> RunScene:
	var preferences := Settings.default_settings()
	preferences["ui_scale"] = UI_SCALE
	preferences["display_mode"] = Settings.DISPLAY_WINDOWED
	preferences["reduced_motion"] = false
	Settings.save_settings(preferences)
	if not _check(Store.save_data(profile) and Store.save_run_state(state), "save the fixture"): return null
	var blocker := _block_write(Store._run_storage_path) if block_resume else ""
	root.set_meta("labyrinth_resume_saved_run", true)
	if not _check(change_scene_to_file(RUN_SCENE) == OK, "open the production run scene"):
		if block_resume: _unblock_write(blocker)
		return null
	if not await _wait_for(func() -> bool:
		return is_instance_valid(current_scene) and current_scene.has_method("has_installed_run") and current_scene.initial_presentation_is_ready()
	):
		_check(false, "run scene ready")
		if block_resume: _unblock_write(blocker)
		return null
	return current_scene as RunScene

func _test_departure(scene: RunScene) -> bool:
	var original_mode := scene.process_mode
	var pending_card := func(_state: Dictionary) -> void:
		scene._analytics_store.write_event("card_played", {"card_id": STAGED_CARD}, {})
	scene._pending_card_play_analytics = pending_card
	var blocker := _block_write(Store._run_storage_path)
	await _press_save_quit(scene)
	var settled := await _wait_for(func() -> bool: return not Shutdown.departure_requested(self))
	var failed_stays: bool = settled and is_instance_valid(scene) and current_scene == scene and not scene._leaving_tree
	var input_ok := false
	var retry_leaves := false
	if failed_stays:
		var restored: bool = scene.process_mode == original_mode and not root.gui_disable_input and not scene.has_meta(Persistence.DEPARTURE_META)
		_check(_continue_button(scene).get_tooltip().is_empty(), "a failed departure checkpoint clears the saved tooltip")
		var notice: bool = scene.log_overlay.is_visible_in_tree() and scene.log_label.text.contains(DEPARTURE_NOTICE)
		_check(notice, "failed departure displays the existing notice")
		await _capture("03-save-quit-failed")
		_unblock_write(blocker)
		_input.send(_input.key(KEY_ESCAPE))
		input_ok = restored and await _wait_for(func() -> bool: return scene._menu_scrim.is_visible_in_tree())
		if input_ok and await _test_profile_write_failure(scene):
			scene._run_state = scene._run_engine.add_held_embers(scene._run_state, RETRY_EMBERS)
			var expected_embers: int = scene._run_engine.held_embers(scene._run_state)
			_check(_disk_state().get("held_embers") != expected_embers, "retry-specific state is initially only in memory")
			await _press_save_quit(scene)
			retry_leaves = await _wait_for(_at_title)
			var disk := _disk_state()
			retry_leaves = retry_leaves and disk.get("mode") == "reward" and disk.get("held_embers") == expected_embers
	else:
		_unblock_write(blocker)
	var count := 0
	for row: Dictionary in Analytics.load_all_events():
		if row.get("event_type") == "card_played" and row.get("card_id") == STAGED_CARD: count += 1
	print("QA145 SAVE_QUIT failed_stays=%s input_ok=%s retry_leaves=%s analytics_dupes=%d" % [
		failed_stays, input_ok, retry_leaves, maxi(0, count - 1),
	])
	if retry_leaves: await _capture("04-save-quit-retried")
	return failed_stays and input_ok and retry_leaves and count == 1

func _test_profile_write_failure(scene: RunScene) -> bool:
	_check(Store.flush_pending_run_saves(), "settle the previous retry before staging the persistent notice")
	var run_blocker := _block_write(Store._run_storage_path)
	_check(not scene._persist_committed_boundary("reward_intro_complete"), "failed reveal stages a persistent notice")
	_check(scene._has_victory_save_notice(scene._run_state), "victory notice is pending behind the pause menu")
	var blocker := _block_write(Store._storage_path)
	_unblock_write(run_blocker)
	_save_quit_button(scene).pressed.emit()
	var settled := await _wait_for(func() -> bool: return not Shutdown.departure_requested(self))
	_unblock_write(blocker)
	var stayed: bool = settled and is_instance_valid(scene) and current_scene == scene and not scene._leaving_tree
	if stayed:
		var queue := scene.get_node(Notifications.NODE_NAME)
		var toast_visible: bool = scene.log_overlay.visible and scene.log_label.text == DEPARTURE_NOTICE
		queue.advance(scene.COMBAT_LOG_TRANSIENT_SECONDS)
		var stale := _victory_notice_visible(scene)
		_check(toast_visible and not stale and not scene._has_victory_save_notice(scene._run_state),
			"persistent victory notice stays cleared after the departure toast")
		print("QA145 PROFILE_FAILURE stayed=%s toast=%s stale_notice=%s" % [stayed, toast_visible, stale])
	return _check(stayed and _continue_button(scene).get_tooltip() == TOOLTIP,
		"failed profile write keeps the run open even when the reward checkpoint saves")

func _test_reward_identity(scene: RunScene) -> void:
	var other := scene._run_state.duplicate(true)
	other["analytics"]["run_id"] = "qa145_other_run"
	scene._record_reward_checkpoint(Persistence.reward_checkpoint_key(other), true, false)
	other = scene._run_state.duplicate(true)
	other["pending_reward"]["milestone_id"] = "qa145_other_reward"
	scene._record_reward_checkpoint(Persistence.reward_checkpoint_key(other), true, false)
	var isolated: bool = _continue_button(scene).get_tooltip().is_empty() and _victory_notice_visible(scene)
	_check(isolated, "completion for another run or reward cannot clear this failure")
	print("QA145 REWARD_IDENTITY isolated=%s" % isolated)

func _test_resume_migration() -> void:
	var profile := _profile()
	var state := _dragon_state(profile, "reward")
	state[SurfaceMigration.VERSION_KEY] = 0
	state["pending_reward"]["intro_pending"] = false
	var scene := await _open_state(state, profile, true)
	if scene == null: return
	var button := _continue_button(scene)
	var announced_failure: bool = button != null and button.get_tooltip().is_empty() and _victory_notice_visible(scene)
	var old_disk: bool = _disk_state().get(SurfaceMigration.VERSION_KEY) == 0
	_unblock_write(ProjectSettings.globalize_path(Store._run_storage_path + ".tmp"))
	var migrated := await _wait_for(func() -> bool:
		return _disk_state().get(SurfaceMigration.VERSION_KEY, 0) > 0 and _continue_button(scene).get_tooltip() == TOOLTIP
	)
	var cleared := not _victory_notice_visible(scene)
	_check(announced_failure and old_disk and migrated and cleared, "resume confirms the reward only after the migrated write")
	print("QA145 RESUME_MIGRATION failed_shown=%s old_disk=%s migrated=%s notice_cleared=%s" % [
		announced_failure, old_disk, migrated, cleared,
	])

func _test_guardian() -> void:
	var scene := await _open_fight("enemy_turn", true)
	if scene == null: return
	var blocker := _block_write(Store._run_storage_path)
	await scene._resolve_enemy_round("pass")
	var trophy: bool = scene._run_state.get("mode") == "treasure" and not scene._run_state.get("guardian_reward", {}).is_empty()
	var shown := _victory_notice_visible(scene)
	_unblock_write(blocker)
	var recovered := await _wait_for(func() -> bool:
		return not _victory_notice_visible(scene) and _disk_state().get("guardian_reward") == scene._run_state.get("guardian_reward")
	)
	_check(trophy and shown and recovered, "failed Guardian trophy save shows the victory notice until its background retry")
	print("QA145 GUARDIAN trophy=%s notice=%s recovered=%s" % [trophy, shown, recovered])

func _test_enemy_playback() -> void:
	Analytics.set_storage_dir(PLAYBACK_ANALYTICS)
	var scene := await _open_fight("midfight")
	if scene == null: return
	scene._combat_state["skill_event_revision"] = 1
	scene._combat_state["skill_events"] = [{"revision": 1, "skill_id": "afterimage", "turn": int(scene._combat_state.get("turn", 1))}]
	scene._run_engine._record_run_skill_event(scene._run_state, "true_bearing")
	var action_count_before := _enemy_action_count()
	var expected_phase: Dictionary = scene._combat_engine.advance_to_next_player_turn_with_steps(
		scene._combat_engine.finish_player_activation(scene._combat_state))
	var expected_actions := scene._analytics_enemy_action_events(expected_phase, {}).size()
	scene._resolve_enemy_round("pass")
	if not await _wait_for(func() -> bool: return scene._committed_run_state_override.has(scene.COMBAT_CONTINUATION_KEY)):
		_check(false, "Pass holds a resumable enemy round (mode=%s lock=%s expected_actions=%d)" % [
			scene._run_state.get("mode"), scene._animation_lock, expected_actions,
		])
		return
	# Dispatch the connected menu action while the held Pass is between slices.
	scene._open_menu_overlay()
	scene._request_skill_event_analytics()
	scene._request_run_skill_event_analytics()
	var both_pending: bool = scene._skill_analytics_queue.busy() and scene._run_skill_analytics_queue.busy()
	var blocker := _block_write(Store._storage_path)
	Store._run_writer.probe_delay_msec = PLAYBACK_WRITE_DELAY_MSEC
	_save_quit_button(scene).pressed.emit()
	var waiting: bool = Shutdown.departure_requested(self)
	var cancelled := await _wait_for(func() -> bool: return not Shutdown.departure_requested(self))
	_unblock_write(blocker)
	Store._run_writer.probe_delay_msec = 0
	var unlocked := await _wait_for(func() -> bool: return is_instance_valid(scene) and current_scene == scene and not scene._animation_lock)
	var actions := _enemy_action_count() - action_count_before
	var adopted: bool = unlocked and scene._committed_run_state_override.is_empty() and scene._combat_engine.is_player_turn(scene._combat_state)
	var input_ok := false
	if adopted:
		var pass_button := scene.find_child("PassPreviewChip", true, false) as Button
		var target: Dictionary = _input.control(pass_button)
		if _check(not target.is_empty(), "restored Pass chip accepts pointer input"):
			_input.prepare(target)
			_input.send(target)
			input_ok = scene._animation_lock
			if input_ok: await _wait_for(func() -> bool: return not scene._animation_lock)
	_check(waiting and cancelled and both_pending and adopted and input_ok and expected_actions > 0 and actions == expected_actions,
		"failed departure resumes the held Pass, drains exactly the expected enemy actions, and accepts the next Pass")
	print("QA145 ENEMY_PLAYBACK cancelled=%s queues_pending=%s adopted=%s input_ok=%s enemy_actions=%d expected=%d" % [
		cancelled, both_pending, adopted, input_ok, actions, expected_actions,
	])

func _test_event_departure() -> void:
	var profile := _profile()
	var state := EventFixture.fixture("hanged_knight", false, Run.new().create_new_run(FIXTURE_SEED, profile, true))
	var scene := await _open_state(state, profile)
	if scene == null: return
	var event_open: bool = scene._event_view != null and scene._event_view.is_visible_in_tree()
	var z_before := scene.log_overlay.z_index
	var notice_home := await _measure_departure_notice_home(scene)
	var mouse_before := scene.log_overlay.mouse_behavior_recursive
	scene._show_combat_log_message(VICTORY_NOTICE)
	var ordinary_suppressed := not scene.log_overlay.visible
	var menu := InputEventAction.new()
	menu.action = InputRouter.ACTION_MENU
	menu.pressed = true
	root.push_input(menu)
	if not _check(event_open and scene._menu_scrim.visible, "menu opens over the event"): return
	_check(Store.flush_pending_run_saves(), "settle the event before injection")
	var blocker := _block_write(Store._run_storage_path)
	await _press_save_quit(scene)
	var cancelled := await _wait_for(func() -> bool: return not Shutdown.departure_requested(self))
	_unblock_write(blocker)
	var visible: bool = cancelled and scene._event_view.is_visible_in_tree() and scene.log_overlay.is_visible_in_tree() and scene.log_label.text == DEPARTURE_NOTICE
	var above_event: bool = visible and not scene.log_overlay.z_as_relative and scene.log_overlay.z_index > scene._event_view.z_index
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var position_unchanged := scene.log_overlay.get_global_rect().position.is_equal_approx(notice_home.position)
	var ignores_mouse := _notice_ignores_mouse(scene.log_overlay)
	await _capture("05-event-save-quit-failed")
	var queue := scene.get_node(Notifications.NODE_NAME)
	queue.advance(scene.COMBAT_LOG_TRANSIENT_SECONDS)
	var suppressed_again: bool = not scene.log_overlay.visible and scene.log_overlay.z_index == z_before
	_check(ordinary_suppressed and above_event and suppressed_again, "departure toast alone paints above the event, then restores suppression")
	_check(position_unchanged and ignores_mouse and scene.log_overlay.mouse_behavior_recursive == mouse_before,
		"event departure notice preserves position and restores its mouse behavior")
	print("QA145 EVENT_DEPARTURE shown=%s above_event=%s other_notices_suppressed=%s" % [
		visible, above_event, ordinary_suppressed and suppressed_again,
	])
	print("QA145 EVENT_NOTICE_INPUT position_unchanged=%s ignores_mouse=%s" % [position_unchanged, ignores_mouse])

func _open_defeat_recap() -> RunScene:
	var scene := await _open_fight("midfight")
	if scene == null: return null
	var defeated := scene._combat_state.duplicate(true)
	defeated["player"]["hp"] = 0
	scene._load_run_state(scene._run_engine.finish_combat(scene._run_state, defeated))
	var recap := scene._run_end_recap
	var ready := await _wait_for(func() -> bool:
		return recap.is_visible_in_tree() and not recap.is_processing()
	)
	if not _check(ready and scene._run_state.get("mode") == "defeat", "the defeat recap finishes presenting"): return null
	if not _check(Store.flush_pending_run_saves(), "settle the terminal fixture before blocking the profile"): return null
	return scene

func _test_recap_departure() -> void:
	var scene := await _open_defeat_recap()
	if scene == null: return
	var recap := scene._run_end_recap
	var original_mode := scene.process_mode
	var z_before := scene.log_overlay.z_index
	var relative_before := scene.log_overlay.z_as_relative
	var notice_home := await _measure_departure_notice_home(scene)
	var notice_home_offsets := Vector2(scene.log_overlay.offset_top, scene.log_overlay.offset_bottom)
	var mouse_before := scene.log_overlay.mouse_behavior_recursive
	scene._show_combat_log_message(VICTORY_NOTICE)
	var ordinary_suppressed := not scene.log_overlay.is_visible_in_tree()
	var profile_before := FileAccess.get_sha256(Store._storage_path)
	var blocker := _block_write(Store._storage_path)
	await _press_save_quit(scene)
	var settled := await _wait_for(func() -> bool: return not Shutdown.departure_requested(self))
	_unblock_write(blocker)
	var stayed: bool = settled and current_scene == scene and recap.is_visible_in_tree() and not scene._menu_scrim.visible
	var shown := stayed and scene.log_overlay.is_visible_in_tree() and scene.log_label.text == DEPARTURE_NOTICE
	var above_recap := shown and scene.log_overlay.z_as_relative == recap.z_as_relative and scene.log_overlay.z_index > recap.z_index
	var expired := false
	var input_ok := false
	var click_reached := false
	var retry_leaves := false
	if stayed:
		_check(FileAccess.get_sha256(Store._storage_path) == profile_before, "failed departure keeps the durable profile")
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		_check_recap_notice_clearance(scene, notice_home)
		await _capture("06-recap-save-quit-failed")
		var queue := scene.get_node(Notifications.NODE_NAME)
		queue.advance(scene.COMBAT_LOG_TRANSIENT_SECONDS)
		expired = not scene.log_overlay.is_visible_in_tree() and scene.log_overlay.z_index == z_before and scene.log_overlay.z_as_relative == relative_before and queue.get("_departure_notice") == ""
		var restored_offsets := Vector2(scene.log_overlay.offset_top, scene.log_overlay.offset_bottom)
		_check(restored_offsets.is_equal_approx(notice_home_offsets) and scene.log_overlay.mouse_behavior_recursive == mouse_before,
			"recap expiry restores the notice position and mouse behavior")
		_input.send(_input.key(KEY_ESCAPE))
		await RenderingServer.frame_post_draw
		input_ok = scene._menu_scrim.is_visible_in_tree() and scene.process_mode == original_mode and not root.gui_disable_input
		if input_ok:
			# Raise the toast again so the Main Menu click occurs while it is visible.
			blocker = _block_write(Store._storage_path)
			await _press_save_quit(scene)
			var raised_again := await _wait_for(func() -> bool: return not Shutdown.departure_requested(self))
			_unblock_write(blocker)
			if _check(raised_again and current_scene == scene and scene.log_overlay.is_visible_in_tree(),
					"recap toast is visible during the retry click"):
				var main_menu := recap.find_child("MainMenuButton", true, false) as Button
				var clicks := [0]
				main_menu.pressed.connect(func() -> void: clicks[0] += 1, CONNECT_ONE_SHOT)
				var centre: Vector2 = main_menu.get_global_transform_with_canvas() * (main_menu.size * 0.5)
				var click: Dictionary = _input.point(centre)
				_input.prepare(click)
				_input.send(click)
				click_reached = clicks[0] == 1
				if click_reached: retry_leaves = await _wait_for(_at_title)
	_check(stayed and above_recap and ordinary_suppressed and expired and input_ok and click_reached and retry_leaves,
		"the recap shows only the departure toast and can retry")
	print("QA145 RECAP_DEPARTURE stayed=%s shown=%s above_recap=%s expired=%s ordinary_suppressed=%s input_ok=%s retry_leaves=%s" % [
		stayed, shown, above_recap, expired, ordinary_suppressed, input_ok, retry_leaves,
	])
	print("QA145 RECAP_MENU_CLICK reached=%s retry_leaves=%s" % [click_reached, retry_leaves])

func _measure_departure_notice_home(scene: RunScene) -> Rect2:
	# Compare the same text after container layout in both positions.
	var label_text := scene.log_label.text
	var was_visible := scene.log_overlay.visible
	scene.log_label.text = DEPARTURE_NOTICE
	scene.log_overlay.show()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var rect := scene.log_overlay.get_global_rect()
	scene.log_overlay.visible = was_visible
	scene.log_label.text = label_text
	return rect

func _check_recap_notice_clearance(scene: RunScene, notice_home: Rect2) -> void:
	var notice := scene.log_overlay.get_global_rect()
	var clear := true
	var highest_top: float = INF
	for button_name: String in ["NewRunButton", "ChronicleButton", "MainMenuButton"]:
		var button := scene._run_end_recap.find_child(button_name, true, false) as Button
		if not _check(button != null and button.is_visible_in_tree(), "recap button is visible: " + button_name): return
		var rect := button.get_global_rect()
		if button_name != "ChronicleButton": highest_top = minf(highest_top, rect.position.y)
		clear = clear and not notice.intersects(rect)
	var gap := highest_top - notice.end.y
	var size_and_right := notice.size.is_equal_approx(notice_home.size) and is_equal_approx(notice.end.x, notice_home.end.x)
	var ignores_mouse := _notice_ignores_mouse(scene.log_overlay)
	_check(clear and is_equal_approx(gap, 16.0) and size_and_right,
		"recap notice sits 16 pixels above the button row, clear of the Chronicle link, and retains its size and right edge")
	_check(ignores_mouse, "recap departure notice and its children ignore mouse input")
	print("QA145 RECAP_NOTICE_LAYOUT clear=%s gap=%.2f size_and_right=%s ignores_mouse=%s" % [clear, gap, size_and_right, ignores_mouse])

func _notice_ignores_mouse(panel: Control) -> bool:
	if panel.get_mouse_filter_with_override() != Control.MOUSE_FILTER_IGNORE: return false
	for control: Control in panel.find_children("*", "Control", true, false):
		if control.get_mouse_filter_with_override() != Control.MOUSE_FILTER_IGNORE: return false
	return true

func _test_title_load_failure() -> void:
	var scene := await _open_fight()
	if scene == null: return
	var original_mode := scene.process_mode
	var expected_embers: int = scene._run_engine.held_embers(scene._run_state) + RETRY_EMBERS
	scene._run_state = scene._run_engine.add_held_embers(scene._run_state, RETRY_EMBERS)
	var cursor := root.get_node("CursorFeedback")
	var generation: int = cursor.get("_transition_generation")
	var broken_title := PackedScene.new()
	var title := _break_title(broken_title)
	if title == null: return
	await _press_save_quit(scene)
	var attempted := await _wait_for(func() -> bool:
		return cursor.get("_transition_generation") != generation and not cursor.is_loading()
	)
	title.take_over_path(TITLE)
	var state: Shutdown.QuitState = root.get_meta(Shutdown.STATE_META)
	var saved: bool = _disk_state().get("held_embers") == expected_embers
	var guard_released: bool = not Shutdown.departure_requested(self) and not state.title_handoff_pending
	var watchdog_disarmed: bool = not state.watchdog.is_started()
	var stayed: bool = current_scene == scene and not scene._leaving_tree and not scene.has_meta(Persistence.DEPARTURE_META)
	var quiet: bool = stayed and scene.get_node(Notifications.NODE_NAME).get("_departure_notice") == ""
	_input.send(_input.key(KEY_ESCAPE))
	await RenderingServer.frame_post_draw
	var input_ok: bool = stayed and scene._menu_scrim.is_visible_in_tree() and scene.process_mode == original_mode and not root.gui_disable_input
	_check(attempted and saved and guard_released and watchdog_disarmed and stayed and quiet and input_ok,
		"an uninstantiable title releases the guard and restores the saved run without a toast")
	print("QA145 TITLE_LOAD_FAILURE attempted=%s saved=%s stayed=%s guard_released=%s watchdog_disarmed=%s input_ok=%s quiet=%s" % [
		attempted, saved, stayed, guard_released, watchdog_disarmed, input_ok, quiet,
	])

func _break_title(broken_title: PackedScene) -> PackedScene:
	var title := load(TITLE) as PackedScene
	if not _check(title != null and title.can_instantiate(), "title resource is valid before injection"): return null
	# Substitute an empty PackedScene in the resource cache. The real cursor
	# transition reaches SceneTree's instantiation failure without editing assets.
	broken_title.take_over_path(TITLE)
	return title

func _test_recap_departure_race() -> void:
	var scene := await _open_defeat_recap()
	if scene == null: return
	var cursor := root.get_node("CursorFeedback")
	var generation: int = cursor.get("_transition_generation")
	var menu := scene._run_end_recap.find_child("MainMenuButton", true, false) as Button
	var blocker := _block_write(Store._storage_path)
	menu.pressed.emit()
	_unblock_write(blocker)
	var failed_released: bool = _title_guard_clear() and cursor.get("_transition_generation") == generation

	var broken_title := PackedScene.new()
	var title := _break_title(broken_title)
	if title == null: return
	menu.pressed.emit()
	var load_recovered := await _wait_for(func() -> bool:
		return cursor.get("_transition_generation") != generation and not cursor.is_loading()
	)
	title.take_over_path(TITLE)
	failed_released = failed_released and load_recovered and current_scene == scene and _title_guard_clear()
	generation = cursor.get("_transition_generation")

	menu.pressed.emit()
	var menu_started: bool = cursor.get("_transition_generation") == generation + 1
	var menu_guarded := Shutdown.departure_requested(self) and not Shutdown.title_save_pending(self)
	# Hold disk I/O beyond the cursor lead so a second save cannot settle before title opens.
	Disk.submit(func() -> bool: return true, HANDOFF_DRAIN_DELAY_MSEC)
	# Deliver Camp's action in the same frame, even if its signal was already queued.
	var save_quit := _save_quit_button(scene)
	save_quit.pressed.emit()
	var save_ignored: bool = not scene._leaving_tree and not Shutdown.title_save_pending(self)
	var reached_title := await _wait_for(_title_loaded)
	var title_ready := reached_title and _title_guard_clear()
	var one_transition: bool = cursor.get("_transition_generation") == generation + 1
	if not _title_guard_clear(): Shutdown.cancel_save_to_title(self)
	var reverse_ignored := await _test_recap_save_quit_first()
	var passed := _check(failed_released and menu_started and menu_guarded and save_ignored and title_ready and one_transition and reverse_ignored,
		"recap title actions share the guard in both orders and leave title input ready")
	print("QA145R4 RECAP_DEPARTURE_RACE before=menu_started:%s,guarded:%s,failed_released:%s after=save_ignored:%s,title_ready:%s,one_transition:%s,menu_ignored:%s %s" % [
		menu_started, menu_guarded, failed_released, save_ignored, title_ready, one_transition, reverse_ignored, "PASS" if passed else "FAIL",
	])

func _test_recap_save_quit_first() -> bool:
	var scene := await _open_defeat_recap()
	if scene == null: return false
	var cursor := root.get_node("CursorFeedback")
	var generation: int = cursor.get("_transition_generation")
	await _press_save_quit(scene)
	var saving := Shutdown.title_save_pending(self)
	var menu := scene._run_end_recap.find_child("MainMenuButton", true, false) as Button
	menu.pressed.emit()
	var menu_ignored: bool = cursor.get("_transition_generation") == generation
	var reached_title := await _wait_for(_title_loaded)
	var title_ready: bool = reached_title and _title_guard_clear() and cursor.get("_transition_generation") == generation + 1
	if not _title_guard_clear(): Shutdown.cancel_save_to_title(self)
	return saving and menu_ignored and title_ready

func _title_loaded() -> bool:
	return is_instance_valid(current_scene) and current_scene.scene_file_path == TITLE

func _title_guard_clear() -> bool:
	var state: Shutdown.QuitState = root.get_meta(Shutdown.STATE_META)
	return not Shutdown.departure_requested(self) and not state.title_handoff_pending and not state.watchdog.is_started() and not root.gui_disable_input

func _test_reward_notice_after_title_failure() -> void:
	var scene := await _open_fight()
	if scene == null: return
	var broken_title := PackedScene.new()
	var title := _break_title(broken_title)
	if title == null: return
	var blocker := _block_write(Store._run_storage_path)
	await scene._resolve_enemy_round("pass")
	var button := _continue_button(scene)
	var failed := button != null and button.get_tooltip().is_empty() and _victory_notice_visible(scene)
	scene._run_state = scene._run_engine.add_held_embers(scene._run_state, RETRY_EMBERS)
	var expected_embers: int = scene._run_engine.held_embers(scene._run_state)
	var cursor := root.get_node("CursorFeedback")
	var generation: int = cursor.get("_transition_generation")
	_input.send(_input.key(KEY_ESCAPE))
	await RenderingServer.frame_post_draw
	_unblock_write(blocker)
	# Start departure before a frame can confirm the queued retry outside the guard.
	_save_quit_button(scene).pressed.emit()
	var recovered := await _wait_for(func() -> bool:
		return cursor.get("_transition_generation") != generation and not cursor.is_loading()
	)
	title.take_over_path(TITLE)
	button = _continue_button(scene)
	var tooltip_saved := button != null and button.get_tooltip() == TOOLTIP
	var stored: bool = _disk_state().get("held_embers") == expected_embers
	var stale := _victory_notice_visible(scene)
	var stayed := recovered and current_scene == scene and not scene._leaving_tree and _title_guard_clear()
	var passed := _check(failed and stayed and stored and tooltip_saved and not stale, "title-load recovery clears the confirmed reward's failure notice")
	print("QA145R4 REWARD_NOTICE before=failed_notice:%s after=stored:%s,tooltip_saved:%s,stale_notice:%s,recovered:%s %s" % [
		failed, stored, tooltip_saved, stale, stayed, "PASS" if passed else "FAIL",
	])

func _test_chronicle_notice_restore() -> void:
	var scene := await _open_defeat_recap()
	if scene == null: return
	var panel := scene.log_overlay
	var home := await _measure_departure_notice_home(scene)
	var z_before := panel.z_index
	var relative_before := panel.z_as_relative
	var mouse_before := panel.mouse_behavior_recursive
	var blocker := _block_write(Store._storage_path)
	await _press_save_quit(scene)
	var settled := await _wait_for(func() -> bool: return not Shutdown.departure_requested(self))
	_unblock_write(blocker)
	if not _check(settled and current_scene == scene, "failed Save and Quit returns to the recap"): return
	var queue := scene.get_node(Notifications.NODE_NAME)
	queue.fixed_clock = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var raised := panel.is_visible_in_tree() and panel.z_index > z_before and _notice_ignores_mouse(panel)
	var recap := scene._run_end_recap
	var link := recap.find_child("ChronicleButton", true, false) as Button
	var click: Dictionary = _input.control(link)
	if not _check(not click.is_empty(), "the Chronicle link accepts a click"): return
	_input.prepare(click)
	_input.send(click)
	var chronicle := recap.get_node_or_null("RunEndChronicle") as Control
	var opened := chronicle != null and chronicle.is_visible_in_tree() and not link.is_visible_in_tree()
	var at_home := panel.get_global_rect().is_equal_approx(home)
	var layer_restored := panel.z_index == z_before and panel.z_as_relative == relative_before
	var mouse_restored := panel.mouse_behavior_recursive == mouse_before
	if opened: chronicle.close()
	var passed := _check(raised and opened and at_home and layer_restored and mouse_restored,
		"opening the Chronicle immediately restores the notice's position, layer and mouse behavior")
	print("QA145R4 CHRONICLE_NOTICE before=raised:%s after=opened:%s,home:%s,layer:%s,mouse:%s %s" % [
		raised, opened, at_home, layer_restored, mouse_restored, "PASS" if passed else "FAIL",
	])

func _test_close_during_title() -> void:
	var scene := await _open_fight()
	if scene == null:
		quit(1)
		return
	var cursor := root.get_node("CursorFeedback")
	var generation: int = cursor.get("_transition_generation")
	await _press_save_quit(scene)
	if not await _wait_for(func() -> bool: return cursor.get("_transition_generation") != generation):
		_check(false, "Save and Quit reaches the cursor handoff")
		quit(1)
		return
	var guarded := Shutdown.departure_requested(self) and not Shutdown.title_save_pending(self) and current_scene == scene
	var observation := {"title_changed": false}
	scene_changed.connect(func() -> void: observation["title_changed"] = true)
	var completed: int = Store._run_writer.completed
	# Keep the desktop drain alive past the cursor lead so a stray title
	# transition would be observable before the process exits.
	Store._run_writer.probe_delay_msec = HANDOFF_DRAIN_DELAY_MSEC
	Store._run_writer.submit(func() -> bool: return true)
	root.tree_exiting.connect(func() -> void:
		var saves: int = Store._run_writer.completed - completed - 1
		var drained := Persistence.application_drained()
		var ok: bool = _fixture_ok and guarded and not observation["title_changed"] and drained and saves == 0
		print("QA145 CLOSE_DURING_TITLE guarded=%s title_changed=%s drained=%s extra_saves=%d %s" % [
			guarded, observation["title_changed"], drained, saves, "PASS" if ok else "FAIL",
		])
		if not ok:
			push_error("TEST RESULT: FAIL — qa-145 desktop close during title handoff")
			quit(1)
	)
	root.close_requested.emit()

func _victory_notice_visible(scene: RunScene) -> bool:
	return scene.log_overlay.is_visible_in_tree() and scene.log_label.text.contains(VICTORY_NOTICE)

func _disk_state() -> Dictionary:
	return Store._inspect_run_file(Store._run_storage_path).get("state", {})

func _enemy_action_count() -> int:
	return Analytics.load_all_events().filter(func(row: Dictionary) -> bool:
		return row.get("event_type") == "enemy_action_resolved"
	).size()

func _press_save_quit(scene: RunScene) -> void:
	if not scene._menu_scrim.visible: _input.send(_input.key(KEY_ESCAPE))
	await RenderingServer.frame_post_draw
	var target: Dictionary = _input.control(_save_quit_button(scene))
	if not _check(not target.is_empty(), "Save and Quit accepts pointer input"): return
	_input.prepare(target)
	_input.send(target)

func _save_quit_button(scene: RunScene) -> Button:
	for button: Button in scene._menu_dialog.find_children("*", "Button", true, false):
		if button.text == "Save and Quit": return button
	_check(false, "find the Save and Quit button")
	return null

func _continue_button(scene: RunScene) -> Button:
	return scene.find_child("DragonRewardContinue", true, false) as Button

# Use the gfix-24/25 boundary tests' blocked temporary file, keeping the
# previous checkpoint intact and the actual writer and retry path in play.
func _block_write(path: String) -> String:
	var blocker := ProjectSettings.globalize_path(path + ".tmp")
	_check(DirAccess.make_dir_absolute(blocker) == OK, "block the checkpoint temp file")
	return blocker

func _unblock_write(blocker: String) -> void:
	_check(DirAccess.remove_absolute(blocker) == OK, "restore checkpoint writes")

func _at_title() -> bool:
	return _title_loaded() and not root.gui_disable_input

func _wait_for(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + WAIT_MSEC
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await RenderingServer.frame_post_draw
	return predicate.call()

func _capture(label: String, hover: Button = null) -> void:
	if _capture_dir.is_empty(): return
	if not _check(DisplayServer.get_name() != "headless", "capture needs the native renderer"): return
	root.warp_mouse(POINTER_REST)
	_input.motion(POINTER_REST)
	if is_instance_valid(hover):
		await RenderingServer.frame_post_draw
		var point: Vector2 = hover.get_global_transform_with_canvas() * (hover.size * 0.5)
		root.warp_mouse(point)
		await process_frame
		_input.motion(point)
		await create_timer(TOOLTIP_SECONDS).timeout
		_check(root.gui_get_hovered_control() == hover, "native pointer reaches the dragon reward button")
		var tooltip: WeakRef = hover.get("_active_tooltip")
		var popup_visible: bool = tooltip != null and is_instance_valid(tooltip.get_ref()) and tooltip.get_ref().is_visible_in_tree()
		_check(popup_visible == (not hover.get_tooltip().is_empty()), "native tooltip matches the checkpoint result")
	await RenderingServer.frame_post_draw
	var path := _capture_dir.path_join(label + ".png")
	var image := root.get_texture().get_image()
	if _check(is_equal_approx(root.content_scale_factor, UI_SCALE) and image.get_size() == SIZE and image.save_png(path) == OK, "save " + path):
		print("QA145 CAPTURE ", path)
		print(path)

func _check(ok: bool, message: String) -> bool:
	if not ok:
		_fixture_ok = false
		printerr("QA145 CHECK FAILED: ", message)
	return ok

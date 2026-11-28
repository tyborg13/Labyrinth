extends SceneTree
## Real run scene and title Continue around the qa-144 victory cuts.

const Store = preload("res://scripts/progression_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Recent = preload("res://scripts/recent_event_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Shutdown = preload("res://scripts/application_shutdown.gd")
const Fixture = preload("res://tools/qa147/fixture.gd")

const SIZE := Vector2i(1920, 1080)
const UI_SCALE := 1.0
const TIME_SCALE := 4.0
const DEADLINE_MS := 40000
const SEED := 144201

var output: String = OS.get_environment("QA147_OUTPUT")
var kind: String = OS.get_environment("QA147_KIND")
var cut: String = OS.get_environment("QA147_CUT")
var scene: Node

func _initialize() -> void:
	Runtime.apply_from_environment()
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("QA147_OUTPUT must name a writable directory")
		return
	Store.set_storage_path(output.path_join("progression.json"))
	Store.set_run_storage_path(output.path_join("run.save"))
	Analytics.set_storage_dir(output.path_join("analytics"))
	Recent.set_storage_path(output.path_join("recent_events.json"))
	Settings.set_storage_path(output.path_join("settings.json"))
	if cut != "continue":
		var settings := Settings.default_settings()
		settings.merge({"ui_scale": UI_SCALE, "display_mode": "windowed"}, true)
		Settings.save_settings(settings)
		Store.save_data(Tutorial.complete_tutorial(Store.load_data()))
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.gui_embed_subwindows = true
	root.size = SIZE
	root.content_scale_size = SIZE
	root.set_meta("labyrinth_performance_probe_seed", SEED)
	if DisplayServer.get_name() == "headless":
		Engine.time_scale = TIME_SCALE
		process_frame.connect(_draw)
	_run.call_deferred()

func _draw() -> void:
	RenderingServer.frame_post_draw.emit()

func _run() -> void:
	Shutdown.install(root)
	if cut == "continue":
		change_scene_to_file("res://scenes/main_menu.tscn")
		await _continue_from_title()
		return
	change_scene_to_file("res://scenes/run_scene.tscn")
	var deadline := Time.get_ticks_msec() + DEADLINE_MS
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.initial_presentation_is_ready(): break
	if Time.get_ticks_msec() >= deadline:
		_fail("run boot")
		return
	scene = current_scene
	Fixture.install(scene, SEED, kind)
	while (scene._animation_lock or scene._dialogue_active or scene._hand_layout_pending_revision >= 0) and Time.get_ticks_msec() < deadline:
		await process_frame
	var combat_id: String = str(scene._combat_state.get("analytics", {}).get("combat_id", ""))
	if scene._animation_lock or combat_id.is_empty() or not Store.flush_pending_run_saves():
		_fail("fixture checkpoint")
		return
	_record("combat_id", combat_id)
	print("QA147 INPUT seed=%d decision=1 action=%s" % [SEED, "pass" if kind in ["fire", "burst", "turn_start"] else Fixture.CARD])
	if kind in ["fire", "burst", "turn_start"]:
		scene._on_pass_turn_pressed()
	else:
		scene._on_card_pressed(0)
		scene._on_board_tile_clicked(Fixture.HERO)
		if scene._selected_card_index >= 0 and not scene._animation_lock: scene._on_confirm_card_play_pressed()
	await _observe_cut()

func _observe_cut() -> void:
	var deadline := Time.get_ticks_msec() + DEADLINE_MS
	var saw_death := false
	var saw_burst := false
	var native: bool = DisplayServer.get_name() != "headless"
	while Time.get_ticks_msec() < deadline:
		await RenderingServer.frame_post_draw
		var victory: bool = scene._post_combat_victory_overlay.visible
		var revealing: bool = scene._reward_reveal_pending and scene._relic_choice_overlay.visible
		var ready := _reward_ready(scene)
		var deaths: Array = scene.board_view.presentation.get("death_animation_units", [])
		saw_death = saw_death or not deaths.is_empty()
		saw_burst = saw_burst or not scene._settled_playback_combat_state.get("death_burst_events", []).is_empty()
		var disk := _disk_state()
		var disk_won: bool = disk.get("mode") in ["reward", "treasure"]
		# qa-144 cuts between the last death frame and the victory transition.
		# The before-write case also requires a durable enemy continuation.
		var before_write: bool = saw_death and deaths.is_empty() and not disk_won and not disk.get(scene.COMBAT_CONTINUATION_KEY, []).is_empty()
		var after_write: bool = disk_won and (victory or not ready)
		if (cut == "kill_before_write" and before_write) or (cut == "kill_after_write" and after_write):
			if kind == "burst" and not saw_burst:
				_fail("Burst did not resolve before the cut")
				return
			var combat_id := FileAccess.get_file_as_string(output.path_join("combat_id.txt")).strip_edges()
			if Analytics._read_all_events().any(func(row: Dictionary) -> bool:
				return row.get("combat_id") == combat_id and row.get("event_type") in ["combat_ended", "reward_offered"]
			):
				_fail("kill boundary followed a live closing append")
				return
			_record("cut", "%s disk_mode=%s" % [cut, disk.get("mode")])
			OS.kill(OS.get_process_id())
			_fail("self SIGKILL")
			return
		if (cut.ends_with("_victory") and victory) or (cut.ends_with("_intro") and revealing) or (cut.ends_with("_ready") and ready):
			_record("cut", "%s disk_mode=%s" % [cut, disk.get("mode")])
			if native and victory and not _capture("victory"): return
			if cut.begins_with("close_"):
				if cut == "close_victory" and disk_won and DirAccess.copy_absolute(
					output.path_join("run.save"), output.path_join("before-close.save")
				) != OK:
					_fail("copy first VICTORY checkpoint")
					return
				root.close_requested.emit()
			else:
				scene._on_save_and_quit_pressed()
				await _continue_from_title()
			return
		if cut == "control" and ready:
			if not _record_ready(): return
			if native and not _capture("reward"): return
			quit()
			return
	_fail("requested boundary " + cut)

func _continue_from_title() -> void:
	var deadline := Time.get_ticks_msec() + DEADLINE_MS
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var menu := current_scene
		if not is_instance_valid(menu) or not menu.has_method("_on_continue_button_pressed") or menu.continue_button.disabled: continue
		menu.continue_button.pressed.emit()
		while Time.get_ticks_msec() < deadline:
			await RenderingServer.frame_post_draw
			if not _reward_ready(current_scene): continue
			scene = current_scene
			if not _record_ready(): return
			if DisplayServer.get_name() != "headless" and not _capture("reward"): return
			if OS.get_environment("QA147_SAVE_AGAIN") == "1": scene._on_save_and_quit_pressed()
			else: quit()
			if OS.get_environment("QA147_SAVE_AGAIN") != "1": return
			while Time.get_ticks_msec() < deadline:
				await process_frame
				if is_instance_valid(current_scene) and current_scene.has_method("_on_continue_button_pressed"):
					_record("saved_again", str(_disk_state().get("mode")))
					quit()
					return
			_fail("second Save & Quit")
			return
		break
	_fail("title Continue to ready reward")

func _reward_ready(owner: Node) -> bool:
	return is_instance_valid(owner) and owner.has_method("has_installed_run") and owner.has_installed_run() \
		and owner._run_state.get("mode") in ["reward", "treasure"] and not owner._animation_lock and not owner._reward_intro_pending()

func _record_ready() -> bool:
	if not Store.flush_pending_run_saves() or not Analytics.flush_pending_events():
		_fail("final persistence barrier")
		return false
	var reward: Dictionary = scene._run_state.get("pending_reward", {})
	var kind_name: String = "final_dragon" if reward.get("final_boss", false) else reward.get("kind", "combat")
	if scene._run_state.get("mode") == "treasure": kind_name = "guardian"
	_record("ready", kind_name)
	return true

func _capture(name: String) -> bool:
	var path := output.path_join(name + ".png")
	var image := root.get_texture().get_image()
	if (
		DisplayServer.window_get_size(root.get_window_id()) != SIZE
		or not is_equal_approx(root.content_scale_factor, UI_SCALE)
		or image == null or image.get_size() != SIZE or image.save_png(path) != OK
	):
		_fail("capture " + path)
		return false
	print(path)
	return true

func _disk_state() -> Dictionary:
	# qa-144's unflushed reader observes the active run without dispatching I/O.
	var file := FileAccess.open(output.path_join("run.save"), FileAccess.READ)
	if file == null or file.get_length() < 4: return {}
	var length := file.get_32()
	if length < 4 or length > file.get_length() - 4: return {}
	var state: Variant = bytes_to_var(file.get_buffer(length))
	return state if state is Dictionary else {}

func _record(name: String, value: String) -> void:
	var file := FileAccess.open(output.path_join(name + ".txt"), FileAccess.WRITE)
	file.store_line(value)
	file.close()
	print("QA147 %s %s" % [name.to_upper(), value])

func _fail(message: String) -> void:
	push_error("QA147 " + message)
	quit(1)

extends SceneTree
## Director round-two repros for a sample-count change and sustained input.

const Warm = preload("res://scripts/canvas_pipeline_prewarm.gd")
const Loads = preload("res://scripts/menu_run_preload.gd")
const Retry = preload("load_retry.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const TITLE_SCENE := "res://scenes/main_menu.tscn"
const FIXTURE_SEED := 165
const WATCH_NAME := "RunSceneIdlePreload"
const SAMPLE_FRAME_LIMIT := 120

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Engine.max_fps = SAMPLE_FRAME_LIMIT
	Input.use_accumulated_input = false
	var ok: bool
	if "--smoothing" in OS.get_cmdline_user_args():
		ok = await _smoothing()
	else:
		ok = await _active_input()
	quit(0 if ok else 1)

func _smoothing() -> bool:
	Settings.set_storage_path("user://perf165-r2-settings.json")
	Store.set_storage_path("user://perf165-r2-profile.json")
	Store.set_run_storage_path("user://perf165-r2-run.save")
	var settings := Settings.default_settings()
	settings["edge_smoothing"] = Settings.EDGE_SMOOTHING_HIGH
	settings["reduced_motion"] = true
	var profile := Store.default_data()
	if not Settings.save_settings(settings) or not Store.save_data(profile): return false
	if not Store.save_run_state(RunEngine.new().create_new_run(FIXTURE_SEED, profile)): return false
	change_scene_to_file("res://scenes/startup.tscn")
	if not await _await_title(): return false
	var menu := current_scene
	var watch := menu.get_node(WATCH_NAME)
	var deadline := _deadline()
	while (watch._armed or menu.has_node(Warm.NODE_NAME)) and Time.get_ticks_msec() < deadline:
		await process_frame
	var idle_finished: bool = not watch._armed and not menu.has_node(Warm.NODE_NAME) and Loads.has_requested_run_scene(self)
	var watched_load: Variant = root.get_meta(Loads.REQUESTS_META, {}).get(Loads.RUN_SCENE_PATH)
	var banner: Dictionary = Warm.Recipes.COVER_INTRO[0]
	var warmed: Dictionary = root.get_meta(Warm.WARMED_META, {})
	var high_key := Warm._key(root, banner)
	var high_ready := root.msaa_2d == Viewport.MSAA_4X and warmed.has(high_key)
	menu.settings_button.pressed.emit()
	var option := menu.find_child("EdgeSmoothingOption", true, false) as OptionButton
	var off_index: int = -1
	for index: int in option.item_count:
		if option.get_item_metadata(index) == Settings.EDGE_SMOOTHING_OFF: off_index = index
	if off_index < 0: return false
	var changed_usec := Time.get_ticks_usec()
	option.select(off_index)
	option.item_selected.emit(off_index)
	var off_key := Warm._key(root, banner)
	var changed_to_off := root.msaa_2d == Viewport.MSAA_DISABLED and off_key != high_key and not warmed.has(off_key)
	deadline = _deadline()
	while not warmed.has(off_key) and Time.get_ticks_msec() < deadline: await process_frame
	var waited_usec := Time.get_ticks_usec() - changed_usec
	var off_ready := warmed.has(off_key) and warmed.has(high_key)
	var same_load := is_same(watched_load, root.get_meta(Loads.REQUESTS_META, {}).get(Loads.RUN_SCENE_PATH))
	menu.settings_back_button.pressed.emit()
	menu.get_node("MenuColumn/ContinueButton").pressed.emit()
	var cover := current_scene
	var first_cover := cover != menu and cover.name == &"MenuRunTransition" and not cover.has_node(Warm.NODE_NAME)
	var shared_shader: bool = first_cover and off_ready and cover.message_label.material.shader == warmed[off_key].shader
	if cover != menu: cover.cancel_loading_for_quit()
	await process_frame
	var ok := idle_finished and high_ready and changed_to_off and off_ready and waited_usec >= Loads.IDLE_USEC and same_load and shared_shader
	print("PERF165 SMOOTHING REARM: %s (high_ready=%s; off_ready=%s; idle_usec=%d; same_preload=%s; first_cover_uses_warmed_shader=%s)" % [
		"PASS" if ok else "FAIL", high_ready, off_ready, waited_usec, same_load, shared_shader])
	return ok

func _active_input() -> bool:
	change_scene_to_file(TITLE_SCENE)
	if not await _await_title(): return false
	var title := current_scene
	var watch := title.get_node(WATCH_NAME)
	var loader := Retry.SlowFog.new()
	ResourceLoader.add_resource_format_loader(loader, true)
	var requested := ResourceLoader.load_threaded_request(Retry.FOG, "Shader")
	# Let the existing watch fire while the dependency is still being loaded.
	watch._last_input_usec = Time.get_ticks_usec() - Loads.IDLE_USEC
	watch._process(0.0)
	var worker := title.get_node(Warm.NODE_NAME)
	worker._process(0.0)
	var viewport := worker.get_node("OffscreenSamples") as SubViewport
	var queued: bool = viewport.render_target_update_mode == SubViewport.UPDATE_ONCE
	var witness := {"latest_input": 0, "fog": 0, "early": 0}
	node_added.connect(func(child: Node) -> void:
		if child is CanvasItem and child.get_parent().name == &"OffscreenSamples":
			var stamp := Time.get_ticks_usec()
			if stamp - int(witness.latest_input) < Loads.IDLE_USEC: witness.early += 1
			if child.material != null and child.material.resource_name == "section map fog": witness.fog = stamp
	)
	_send_down(true, witness)
	var cancelled: bool = not worker.is_processing() and viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED
	var deadline := _deadline()
	var down := false
	while ResourceLoader.get_cached_ref(Retry.FOG) == null and Time.get_ticks_msec() < deadline:
		_send_down(down, witness)
		down = not down
		await process_frame
	var cached_under_input: bool = ResourceLoader.get_cached_ref(Retry.FOG) != null and witness.fog == 0
	_send_down(false, witness)
	deadline = _deadline()
	while witness.fog == 0 and Time.get_ticks_msec() < deadline: await process_frame
	var idle_usec: int = witness.fog - witness.latest_input
	var interactive := current_scene == title and not root.gui_disable_input
	while Loads.status_for(self, Loads.RUN_SCENE_PATH) == ResourceLoader.THREAD_LOAD_IN_PROGRESS: await process_frame
	var packed := Loads.take_for(self, Loads.RUN_SCENE_PATH) as PackedScene
	var fog: Resource
	if ResourceLoader.load_threaded_get_status(Retry.FOG) == ResourceLoader.THREAD_LOAD_LOADED:
		fog = ResourceLoader.load_threaded_get(Retry.FOG)
	ResourceLoader.remove_resource_format_loader(loader)
	var ok: bool = requested == OK and queued and cancelled and cached_under_input and witness.early == 0 and idle_usec >= Loads.IDLE_USEC and interactive and packed != null and fog != null
	print("PERF165 TITLE INPUT: %s (pending_batch_cancelled=%s; cached_under_input=%s; early_submissions=%d; idle_usec=%d; interactive=%s)" % [
		"PASS" if ok else "FAIL", cancelled, cached_under_input, witness.early, idle_usec, interactive])
	return ok

func _send_down(pressed: bool, witness: Dictionary) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_DOWN
	event.pressed = pressed
	witness.latest_input = Time.get_ticks_usec()
	Input.parse_input_event(event)

func _await_title() -> bool:
	var deadline := _deadline()
	while Time.get_ticks_msec() < deadline:
		if current_scene != null and current_scene.scene_file_path == TITLE_SCENE and not root.gui_disable_input:
			return true
		await process_frame
	push_error("Timed out waiting for the interactive title")
	return false

func _deadline() -> int:
	return Time.get_ticks_msec() + Retry.WAIT_LIMIT_MS

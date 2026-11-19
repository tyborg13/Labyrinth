extends RefCounted

## The root exits after scenes and autoloads, including their persistence and
## telemetry barriers. Release cross-script Callables here, while every script's
## update mutex is still alive, rather than in GDScriptLanguage::finish().
const Disk = preload("res://scripts/persistence_disk_worker.gd")
const Persistence = preload("res://scripts/run_persistence.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Bindings = preload("res://scripts/card_display_bindings.gd")
const Measurements = preload("res://scripts/card_summary_measurements.gd")
const Recovery = preload("res://scripts/opening_boon_recovery.gd")
const DemoEnd = preload("res://scripts/demo_end_panel.gd")
const Clock = preload("res://scripts/presentation_clock.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const SceneLoads = preload("res://scripts/menu_run_preload.gd")
const STATE_META := &"labyrinth_application_shutdown"
# Leave time for the watchdog thread and OS process exit under throttling.
const QUIT_DEADLINE_USEC := 2500000
const WATCHDOG_POLL_MSEC := 5
const AUDIO_DRAIN_USEC := 100000
const AUDIO_DRAIN_MIXES := 2

class QuitState extends RefCounted:
	signal preparation_frame
	var requested_usec: int
	var exit_code: int
	var watchdog := Thread.new()
	var finished := Assets.PreparationCancellation.new()
	var deadline_usec: int
	var deadline_mutex := Mutex.new()
	var saving_to_title: bool = false

	func arm() -> void:
		if watchdog.is_started(): return
		finished = Assets.PreparationCancellation.new()
		deadline_usec = Time.get_ticks_usec() + Disk.SAVE_DEADLINE_USEC
		if watchdog.start(guard_exit) != OK:
			push_error("Could not start the application quit watchdog.")

	func begin_cleanup() -> void:
		deadline_mutex.lock()
		deadline_usec = Time.get_ticks_usec() + QUIT_DEADLINE_USEC
		deadline_mutex.unlock()

	func guard_exit() -> void:
		while not finished.is_cancelled():
			deadline_mutex.lock()
			var expired: bool = Time.get_ticks_usec() >= deadline_usec
			deadline_mutex.unlock()
			if expired:
				if not finished.is_cancelled(): OS.kill(OS.get_process_id())
				return
			OS.delay_msec(WATCHDOG_POLL_MSEC)

	func disarm() -> void:
		finished.cancel()
		if watchdog.is_started(): watchdog.wait_to_finish()

static func install(root: Window) -> void:
	if not root.tree_exiting.is_connected(finish):
		root.tree_exiting.connect(finish, CONNECT_ONE_SHOT)
	if root.has_meta(STATE_META): return
	var state := QuitState.new()
	root.set_meta(STATE_META, state)
	var tree := root.get_tree()
	tree.set_auto_accept_quit(false)
	root.close_requested.connect(request.bind(tree, "window_close"))
	if DisplayServer.get_name() != "headless":
		RenderingServer.frame_post_draw.connect(state.preparation_frame.emit)
	root.tree_exiting.connect(_release_frame_signal.bind(state), CONNECT_ONE_SHOT)

static func _release_frame_signal(state: QuitState) -> void:
	if RenderingServer.frame_post_draw.is_connected(state.preparation_frame.emit):
		RenderingServer.frame_post_draw.disconnect(state.preparation_frame.emit)
	state.disarm()

static func present_preparation(tree: SceneTree) -> void:
	if DisplayServer.get_name() == "headless":
		await tree.process_frame
	else:
		var state: QuitState = tree.root.get_meta(STATE_META)
		await state.preparation_frame

static func begin_save_to_title(tree: SceneTree) -> bool:
	install(tree.root)
	var state: QuitState = tree.root.get_meta(STATE_META)
	if state.requested_usec > 0 or state.saving_to_title: return false
	state.arm()
	state.saving_to_title = true
	tree.root.gui_disable_input = true
	return true

static func departure_requested(tree: SceneTree) -> bool:
	if not tree.root.has_meta(STATE_META): return false
	var state: QuitState = tree.root.get_meta(STATE_META)
	return state.requested_usec > 0 or state.saving_to_title

static func finish_save_to_title(tree: SceneTree) -> bool:
	var state: QuitState = tree.root.get_meta(STATE_META)
	state.saving_to_title = false
	if state.requested_usec > 0: return false
	tree.scene_changed.connect(_release_title_guard.bind(tree, state), CONNECT_ONE_SHOT)
	return true

static func _release_title_guard(tree: SceneTree, state: QuitState) -> void:
	if state.requested_usec > 0: return
	state.disarm()
	tree.root.gui_disable_input = false

static func request(tree: SceneTree, reason: String, exit_code: int = 0) -> void:
	install(tree.root)
	var state: QuitState = tree.root.get_meta(STATE_META)
	if state.requested_usec > 0: return
	state.requested_usec = Time.get_ticks_usec()
	state.exit_code = exit_code
	# The engine can block in a synchronous filesystem call. The watchdog
	# owns the deadline independently of the disk worker and the main loop.
	state.arm()
	tree.root.gui_disable_input = true
	# Godot cannot hide the primary Window. Minimization dismisses the native
	# window while the event loop keeps pumping pending cleanup.
	if DisplayServer.get_name() != "headless": tree.root.mode = Window.MODE_MINIMIZED
	Assets.cancel_preparation_for(tree.root)
	var scene := tree.current_scene
	for child: Node in tree.root.get_children():
		if child.has_method("cancel_loading_for_quit"): child.cancel_loading_for_quit()
	_stop_voices(tree.root)
	_drain.call_deferred(tree, state, scene, reason, state.saving_to_title)

static func _drain(tree: SceneTree, state: QuitState, scene: Node, reason: String, joining_title_save: bool) -> void:
	var previous_mix := _last_mix_usec()
	var mixes: int = 0
	if joining_title_save:
		while state.saving_to_title: await tree.process_frame
	elif is_instance_valid(scene) and scene.has_method("prepare_application_quit"):
		await scene.prepare_application_quit(reason)
	if is_instance_valid(scene): scene.process_mode = Node.PROCESS_MODE_DISABLED
	# The shorter cleanup budget starts after scene and global save barriers.
	# Keep it armed through the final barriers in the root exit hook.
	await Persistence.flush_in_tree(tree)
	Persistence.set_application_drained()
	state.begin_cleanup()
	# Draw pulses stop when the main window is minimized. Resume the loading
	# continuations from process frames so cancellation releases their state.
	while true:
		await tree.process_frame
		state.preparation_frame.emit()
		var mix := _last_mix_usec()
		if mix > previous_mix:
			mixes += 1
			previous_mix = mix
		var audio_settled: bool = mixes >= AUDIO_DRAIN_MIXES or Time.get_ticks_usec() - state.requested_usec >= AUDIO_DRAIN_USEC
		var resources_settled := SceneLoads.drain_for_shutdown(tree)
		if audio_settled and resources_settled and not Assets.has_preparation_drains(tree.root): break
	tree.quit(state.exit_code)

static func _last_mix_usec() -> int:
	return Time.get_ticks_usec() - roundi(AudioServer.get_time_since_last_mix() * 1000000.0)

static func _stop_voices(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D: node.stop()
	for child: Node in node.get_children(): _stop_voices(child)

static func finish() -> bool:
	# Scene-owned barriers keep their original ordering and retry policy. This
	# final barrier also covers direct SceneTree.quit() from automation/startup.
	var flushed: bool = Persistence.application_drained() or Persistence.flush()
	# Failed I/O already preserves the preceding durable checkpoint and reports
	# its original failure. At final root exit there can be no further retry;
	# release even failed jobs, never cancel them before the last flush attempt.
	Progression._run_writer.cancel_pending()
	Analytics._writer.cancel_pending()
	for writer: RefCounted in Analytics._writers_by_directory.values():
		writer.cancel_pending()
	Analytics._writers_by_directory.clear()
	Disk.join()
	Bindings.reset_cache()
	Measurements.release_shutdown_connections()
	Recovery.release_shutdown_callables()
	DemoEnd.release_shutdown_callables()
	Clock.release_shutdown_callables()
	return flushed

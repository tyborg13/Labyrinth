extends "res://tests/pre_battle_fixture.gd"

const Notifications = preload("res://scripts/run_notification_queue.gd")
const HeirloomFixture = preload("res://tests/helpers/heirloom_fixture.gd")
const FIRST_NOTICE: String = "Notification regression fixture: first notice"
const SECOND_NOTICE: String = "Notification regression fixture: second notice"
const PERSISTENT_NOTICE: String = "Notification regression fixture: underlying notice"
const LOAD_TIMEOUT_MSEC: int = 30000
const CLEANUP_FRAMES: int = 600
var _retired_queue_ids: PackedInt64Array

class NoticeHost extends Node:
	const COMBAT_LOG_TRANSIENT_SECONDS: float = 3.0
	var _run_state: Dictionary = {"mode": "defeat"}
	var log_overlay := PanelContainer.new()
	var log_label := RichTextLabel.new()
	var released: Array[String]
	func _init() -> void:
		add_child(log_overlay)
		var margin := MarginContainer.new()
		margin.name = "LogMargin"
		log_overlay.add_child(margin)
		log_label.name = "Log"
		margin.add_child(log_label)
	func _show_combat_log_message(message: String) -> void:
		released.append(message)
		log_label.text = message
		Notifications.refresh(self, true)
	func _refresh_log_overlay_visibility() -> void:
		Notifications.refresh(self)

class NoticeOwner extends Node:
	var host: Node
	func _exit_tree() -> void:
		Notifications.release(host, self)

func _initialize() -> void:
	_setup()
	Settings.set_storage_path("user://heirloom_notification_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = "windowed"
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	Settings.apply_settings(settings, null, false)
	root.mode = Window.MODE_WINDOWED
	root.size = PROBE_VIEWPORT
	call_deferred("_run")

func _run() -> void:
	_retirement_checks()
	_departure_release_guard()
	await _save_and_quit()
	await _rapid_continue_and_quit()
	await _interrupted_load()
	ProgressionStore.clear_saved_run()
	Settings.clear_storage()
	_viewport.queue_free()
	await process_frame
	_expect(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Notification regressions leave zero orphan nodes")
	print("HEIRLOOM NOTIFICATION TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _retirement_checks() -> void:
	var host := NoticeHost.new()
	root.add_child(host)
	var owner := Node.new()
	host.add_child(owner)
	host.log_label.text = PERSISTENT_NOTICE
	host.log_overlay.show()
	Notifications.hold(host, owner)
	var queue: Node = host.get_node(Notifications.NODE_NAME)
	queue.fixed_clock = true
	for text: String in [FIRST_NOTICE, SECOND_NOTICE]:
		host.log_label.text = text
		Notifications.refresh(host, true)
	Notifications.release(host, owner)
	for text: String in [PERSISTENT_NOTICE, FIRST_NOTICE, SECOND_NOTICE]:
		_expect(host.log_label.text == text and host.log_overlay.visible, "Held notices play in FIFO order before expiration")
		queue.advance(NoticeHost.COMBAT_LOG_TRANSIENT_SECONDS)
	_expect(queue.queued.is_empty() and queue.get("_current").is_empty(), "Exhaustion retires every queued notice")
	_expect(host.log_label.text == PERSISTENT_NOTICE and host.log_overlay.visible, "Expired transient text is replaced by the underlying persistent notice")
	Notifications.hold(host, owner)
	_expect(not host.log_overlay.visible and queue.queued.size() == 1 and queue.queued[0]["text"] == PERSISTENT_NOTICE, "A later hold pauses only persistent paint, never expired transient text")
	Notifications.release(host, owner)
	_expect(queue.queued.is_empty() and queue.get("_current").is_empty() and host.log_label.text == PERSISTENT_NOTICE and host.log_overlay.visible, "Holding and releasing an exhausted queue replays nothing and restores persistent paint")
	# Clearing the persistent notice leaves no stale transient label to capture.
	host.log_label.text = ""
	Notifications.refresh(host)
	Notifications.hold(host, owner)
	for text: String in [FIRST_NOTICE, SECOND_NOTICE]:
		host.log_label.text = text
		Notifications.refresh(host, true)
	Notifications.release(host, owner)
	queue.advance(NoticeHost.COMBAT_LOG_TRANSIENT_SECONDS)
	queue.advance(NoticeHost.COMBAT_LOG_TRANSIENT_SECONDS)
	_expect(host.log_label.text.is_empty() and not host.log_overlay.visible, "An exhausted toast-only queue clears and hides its surface")
	Notifications.hold(host, owner)
	Notifications.release(host, owner)
	_expect(queue.queued.is_empty() and queue.get("_current").is_empty() and not host.log_overlay.visible, "Another hold/release cannot resurrect the final expired toast")
	host.queue_free()
	print("HEIRLOOM NOTIFICATION RETIREMENT CHECKS: %s" % ("FAIL" if _failed else "PASS"))

func _departure_release_guard() -> void:
	var host := NoticeHost.new()
	root.add_child(host)
	var owner := NoticeOwner.new()
	owner.host = host
	host.add_child(owner)
	host.log_label.text = PERSISTENT_NOTICE
	Notifications.hold(host, owner)
	var queue: Node = host.get_node(Notifications.NODE_NAME)
	queue.fixed_clock = true
	# Retain a different underlying notice to expose a late release restoring
	# stale paint after the two transient requests have been handed back.
	queue.set("_last_persistent", PERSISTENT_NOTICE)
	queue.queued.clear()
	for text: String in [FIRST_NOTICE, SECOND_NOTICE]: host._show_combat_log_message(text)
	host.released.clear()
	root.remove_child(host)
	_expect(host.released == [FIRST_NOTICE, SECOND_NOTICE], "Departure synchronously releases every held request through the normal path in FIFO order")
	_expect(host.log_label.text == SECOND_NOTICE, "Departed release guard prevents late owner exit from restoring stale paint")
	_expect(queue.queued.is_empty() and queue.get("_current").is_empty() and not queue.is_processing() and queue.get_incoming_connections().is_empty(), "Departure stops replay and retains no signal connections or pending work")
	host.free()
	print("HEIRLOOM NOTIFICATION DEPARTURE GUARD CHECKS: %s" % ("FAIL" if _failed else "PASS"))

func _save_and_quit() -> void:
	var scene: Node = await _open_run()
	var view: Control = scene.get("_opening_boon_flow").overlay
	_expect(view != null, "Save and Quit fixture opens the actual heirloom prompt")
	if view == null: return
	_reset_queue(scene)
	view.call("_choose", 0)
	view.ceremony.fixed_clock = true
	view.ceremony.seek(HeirloomFixture.BURN_CLOCK_SECONDS)
	for text: String in [FIRST_NOTICE, SECOND_NOTICE]: scene.call("_show_combat_log_message", text)
	_expect(scene.get_node(Notifications.NODE_NAME).queued.size() == 2 and not scene.get("log_overlay").visible, "Two notices remain held during the real ceremony")
	await _quit_to_menu(scene)
	await _assert_reclaimed()
	print("HEIRLOOM NOTIFICATION SAVE AND QUIT CHECKS: %s" % ("FAIL" if _failed else "PASS"))

func _rapid_continue_and_quit() -> void:
	var scene: Node = await _open_run()
	_reset_queue(scene)
	for text: String in [FIRST_NOTICE, SECOND_NOTICE]: scene.call("_show_combat_log_message", text)
	await _quit_to_menu(scene)
	# No toast-duration wait: take the public Continue route while departed-run
	# cleanup can still be draining the previous scene.
	var transition: Node = _begin_continue()
	if transition == null: return
	var deadline: int = Time.get_ticks_msec() + LOAD_TIMEOUT_MSEC
	while is_instance_valid(transition) and current_scene == transition and Time.get_ticks_msec() < deadline: await process_frame
	_expect(current_scene != null and current_scene.scene_file_path == "res://scenes/run_scene.tscn", "Rapid public Continue reaches the saved run")
	if current_scene == null or current_scene.scene_file_path != "res://scenes/run_scene.tscn": return
	scene = current_scene
	_expect(scene.get("_opening_boon_flow").active(), "Rapid Continue resumes the unanswered heirloom prompt")
	_reset_queue(scene)
	scene.call("_show_combat_log_message", SECOND_NOTICE)
	await _quit_to_menu(scene)
	await _assert_reclaimed()
	print("HEIRLOOM NOTIFICATION RAPID CONTINUE CHECKS: %s" % ("FAIL" if _failed else "PASS"))

func _interrupted_load() -> void:
	var state: Dictionary = HeirloomFixture.terminal()
	ProgressionStore.save_data(state["progression"])
	ProgressionStore.save_run_state(state)
	var transition: Node = _begin_continue()
	if transition == null: return
	var destination: Node
	var queue: Node
	var deadline: int = Time.get_ticks_msec() + LOAD_TIMEOUT_MSEC
	while is_instance_valid(transition) and Time.get_ticks_msec() < deadline:
		destination = transition.destination
		if is_instance_valid(destination) and destination.is_inside_tree():
			queue = destination.get_node_or_null(Notifications.NODE_NAME)
			if _has_grimoire_notice(queue) and not destination.initial_presentation_is_ready(): break
		await process_frame
	var interrupted: bool = is_instance_valid(destination) and _has_grimoire_notice(queue) and not destination.initial_presentation_is_ready()
	_expect(interrupted, "Interrupted Continue reaches the natural queued Grimoire notice before presentation completes")
	if not interrupted: return
	_retired_queue_ids.append(queue.get_instance_id())
	var destination_id: int = destination.get_instance_id()
	var transition_id: int = transition.get_instance_id()
	transition.free()
	await _settle()
	_expect(not is_instance_id_valid(destination_id) and not is_instance_id_valid(transition_id), "Interrupting loading frees the incomplete destination and its transition")
	await _assert_reclaimed()
	_expect(not root.gui_disable_input, "Interrupted loading restores input without a notification continuation")
	print("HEIRLOOM NOTIFICATION INTERRUPTED LOAD CHECKS: %s" % ("FAIL" if _failed else "PASS"))

func _has_grimoire_notice(queue: Node) -> bool:
	if queue == null: return false
	for notice: Dictionary in queue.queued:
		if "Grimoire" in str(notice["text"]): return true
	return false

func _open_run() -> Node:
	if current_scene != null:
		current_scene.free()
		current_scene = null
	var state: Dictionary = HeirloomFixture.terminal()
	ProgressionStore.save_data(state["progression"])
	ProgressionStore.save_run_state(state)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _settle()
	scene.call("_load_run_state", state)
	scene.call("_refresh_ui")
	scene.call("_complete_current_dialogue_line")
	await _settle()
	return scene

func _reset_queue(scene: Node) -> void:
	var queue: Node = scene.get_node(Notifications.NODE_NAME)
	queue.fixed_clock = true
	queue.queued.clear()
	queue.set("_current", {})
	queue.set("_last_persistent", "")
	queue.set("_last_requested", "")
	scene.get("log_label").text = ""

func _quit_to_menu(scene: Node) -> void:
	var queue: Node = scene.get_node(Notifications.NODE_NAME)
	_retired_queue_ids.append(queue.get_instance_id())
	var expected: String = str(queue.queued.back()["text"])
	var released: Array[String]
	scene.tree_exiting.connect(func() -> void:
		released.append(str(scene.get("log_label").text))
		_expect(queue.queued.is_empty() and queue.get("_current").is_empty() and not queue.is_processing(), "Real departure drains held notices synchronously and stops replay")
		_expect(queue.get_incoming_connections().is_empty(), "The departing queue has zero incoming signal connections")
	, CONNECT_ONE_SHOT)
	var old_id: int = scene.get_instance_id()
	scene.call("_on_save_and_quit_pressed")
	await scene_changed
	await process_frame
	_expect(current_scene != null and current_scene.scene_file_path == "res://scenes/main_menu.tscn" and not is_instance_id_valid(old_id), "Save and Quit reaches the public menu after the old scene is freed")
	_expect(not is_instance_id_valid(_retired_queue_ids[-1]), "The notification queue is gone by menu readiness")
	_expect(released == [expected], "Late view teardown leaves the synchronous normal-path release intact")
	_expect(root.find_children("DeferredNotification*", "", true, false).is_empty(), "Save and Quit leaves zero cross-scene notification presenters")

func _begin_continue() -> Node:
	_expect(current_scene != null and current_scene.scene_file_path == "res://scenes/main_menu.tscn", "Continue starts from the public menu")
	if current_scene == null: return null
	current_scene.get_node("MenuColumn/ContinueButton").pressed.emit()
	var transition: Node = root.get_node_or_null("MenuRunTransition")
	_expect(transition != null, "Public Continue starts the actual loading transition")
	return transition

func _assert_reclaimed() -> void:
	for frame: int in range(CLEANUP_FRAMES):
		if root.get_node_or_null("DepartedRunCleanup") == null: break
		await process_frame
	await process_frame
	await process_frame
	for id: int in _retired_queue_ids: _expect(not is_instance_id_valid(id), "Departed notification queues are reclaimed with their scene")
	var remaining: int = root.find_children("Deferred*Notification*", "", true, false).size()
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_expect(remaining == 0, "No notification queue or presenter survives scene teardown")
	_expect(orphans == 0, "Completed and interrupted departures leave zero orphan nodes")
	print("HEIRLOOM NOTIFICATION LIFECYCLE: surviving_queues_or_presenters=%d orphan_nodes=%d" % [remaining, orphans])

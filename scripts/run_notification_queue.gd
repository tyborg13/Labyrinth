extends Node

## The shared run-log surface is the game's toast/notification presenter.
## Hold requests synchronously, then replay FIFO at its existing 3s duration.
const NODE_NAME: String = "DeferredRunNotifications"
var fixed_clock: bool = false
var queued: Array[Dictionary]
var _owners: Dictionary = {}
var _host: Node
var _current: Dictionary = {}
var _remaining: float = 0.0
var _last_persistent: String = ""
var _last_requested: String = ""
var _departed: bool = false

static func hold(host: Node, owner: Node) -> void:
	var queue: Node = host.get_node_or_null(NODE_NAME)
	if queue == null:
		queue = new()
		queue.name = NODE_NAME
		queue.process_mode = Node.PROCESS_MODE_ALWAYS
		queue._host = host
		host.add_child(queue)
	queue._owners[owner.get_instance_id()] = true
	if queue._current.is_empty() and bool(host.get("log_overlay").visible):
		queue._capture(str(host.get("log_label").text), false, true)
	host.get("log_overlay").hide()

static func release(host: Node, owner: Node) -> void:
	if not is_instance_valid(host): return
	var queue: Node = host.get_node_or_null(NODE_NAME)
	if queue == null or queue._departed: return
	queue._owners.erase(owner.get_instance_id())
	if queue._owners.is_empty() and host.is_inside_tree() and not host.is_queued_for_deletion(): queue._show_next()

static func refresh(host: Node, transient: bool = false) -> void:
	var panel: Control = host.get("log_overlay")
	var label: RichTextLabel = host.get("log_label")
	if panel == null: return
	var queue: Node = host.get_node_or_null(NODE_NAME)
	if queue != null and not queue._departed and (not queue._owners.is_empty() or not queue._current.is_empty()):
		queue._capture("" if label == null else label.text, transient)
		if not queue._owners.is_empty(): panel.hide()
		else: queue._paint_current()
		return
	if queue != null and not queue._departed and not transient:
		queue._last_persistent = "" if label == null else label.text
		queue._last_requested = queue._last_persistent
	panel.visible = not _full_panel_open(host) and label != null and not label.text.is_empty() and (transient or str(host.get("_run_state").get("mode", "room")) != "combat")

static func _full_panel_open(host: Node) -> bool:
	if str(host.get("_run_state").get("mode", "room")) == "event": return true
	for field: String in ["_event_view", "_magic_purge_overlay"]:
		var panel: Control = host.get(field) as Control
		if is_instance_valid(panel) and panel.is_visible_in_tree(): return true
	return false

func _capture(message: String, transient: bool, resume_visible: bool = false) -> void:
	if message.is_empty():
		if not transient: _last_persistent = ""
		return
	# Visibility-only refreshes can echo either a persistent notice or the last
	# explicit toast. Neither echo is a new request. Explicit repeated toasts
	# remain distinct, and an already-visible notice resumes after a hold.
	if not transient and not resume_visible and (message == _last_persistent or message == _last_requested or message == str(_current.get("text", ""))): return
	_last_requested = message
	if not transient: _last_persistent = message
	queued.append({"text": message, "transient": transient, "resume_visible": resume_visible})

func _process(delta: float) -> void:
	if not fixed_clock: advance(delta)

func advance(seconds: float) -> void:
	if not _owners.is_empty() or _current.is_empty() or _full_panel_open(_host): return
	_remaining -= seconds
	if _remaining > 0.0: return
	_current = {}
	_show_next()

func _show_next() -> void:
	if not _owners.is_empty(): return
	# With no new notices, resuming persistent paint needs no timed replay.
	if _current.is_empty() and queued.size() == 1 and bool(queued[0].get("resume_visible", false)):
		queued.clear()
	if _current.is_empty() and not queued.is_empty():
		_current = queued.pop_front()
		_remaining = float(_host.get_script().get_script_constant_map()["COMBAT_LOG_TRANSIENT_SECONDS"])
	if not _current.is_empty(): _paint_current()
	else: _restore_persistent()

func _paint_current() -> void:
	if _current.is_empty(): return
	_host.get("log_label").text = str(_current["text"])
	_host.get("log_overlay").visible = not _full_panel_open(_host)

func _restore_persistent() -> void:
	# A completed transient is no longer a notice. Leaving it in the label
	# would make the next hold mistake stale paint for a fresh request.
	_last_requested = _last_persistent
	_host.get("log_label").text = _last_persistent
	_host.get("log_overlay").visible = not _full_panel_open(_host) and not _last_persistent.is_empty() and str(_host.get("_run_state").get("mode", "room")) != "combat"

func _exit_tree() -> void:
	_departed = true
	set_process(false)
	_owners.clear()
	# Deliver held requests synchronously through the ordinary scene path.
	# refresh() bypasses this departed queue; later view exit callbacks cannot
	# restart replay. No timer, external signal or destination observer is owned.
	while not queued.is_empty():
		var notice: Dictionary = queued.pop_front()
		if bool(notice["transient"]):
			_host.call("_show_combat_log_message", str(notice["text"]))
		else:
			_host.get("log_label").text = str(notice["text"])
			_host.call("_refresh_log_overlay_visibility")
	_current = {}
	_remaining = 0.0
	# Departed-run cleanup may slice other children over subsequent frames.
	# This small scene-owned queue needs no such continuation.
	queue_free()

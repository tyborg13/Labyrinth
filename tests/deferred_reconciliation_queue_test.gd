extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ReconciliationQueue = preload("res://scripts/deferred_reconciliation_queue.gd")

class RenderPulse:
	extends Control
	var tick: bool = false
	func pulse() -> void:
		tick = not tick
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2.ONE), Color.WHITE if tick else Color.BLACK)

var _queue: ReconciliationQueue
var _pulse: RenderPulse
var _ready_flag: bool = true
var _scope_token: Dictionary = {"run": 1, "combat": 1}
var _log: Array[String]
var _frames_seen: Array[int]
var _checks: int = 0
var _errors: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	if DisplayServer.get_name() == "headless":
		push_error("This queue test requires a native rendering backend for frame_post_draw")
		quit(1)
		return
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(640, 360)
	create_timer(15.0).timeout.connect(func() -> void: push_error("Deferred queue test exceeded its bounded frame guard"); quit(1))
	call_deferred("_run")

func _run() -> void:
	_pulse = RenderPulse.new()
	_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_pulse)
	_queue = ReconciliationQueue.new()

	_queue.request(_steps(["one", "two", "three"]), _ready_now, _scope_now)
	_expect(_log.is_empty() and _queue.busy(), "request waits before its first step")
	await _frames(1)
	_expect(_log == _strings(["one"]), "one step executes per rendered frame")
	await _frames(1)
	_expect(_log == _strings(["one", "two"]), "second step has its own frame")
	await _frames(1)
	_expect(_log == _strings(["one", "two", "three"]) and not _queue.busy(), "completed cycle releases its owner")
	_expect(_frames_seen[0] < _frames_seen[1] and _frames_seen[1] < _frames_seen[2], "steps execute in distinct process frames")

	_reset()
	_queue.request(_steps(["old"]), _ready_now, _scope_now)
	_queue.request(_steps(["latest"]), _ready_now, _scope_now)
	await _frames(2)
	_expect(_log == _strings(["latest"]), "requests before stage zero coalesce to latest callbacks")

	_reset()
	_queue.request(_steps(["a", "b"]), _ready_now, _scope_now)
	await _frames(1)
	_queue.request(_steps(["discarded"]), _ready_now, _scope_now)
	_queue.request(_steps(["latest"]), _ready_now, _scope_now)
	await _frames(3)
	_expect(_log == _strings(["a", "b", "latest"]), "requests during a cycle become one latest rerun")
	_expect(not _queue.busy(), "coalesced rerun releases its owner")

	_reset()
	_ready_flag = false
	_queue.request(_steps(["a", "b"]), _ready_now, _scope_now)
	await _frames(2)
	_expect(_log.is_empty() and _queue.busy(), "unready job waits without performing work")
	_ready_flag = true
	await _frames(1)
	_ready_flag = false
	await _frames(1)
	_ready_flag = true
	await _frames(2)
	_expect(_log == _strings(["a", "a", "b"]), "readiness loss restarts from stage zero")

	_reset()
	_queue.request(_steps(["a", "b"]), _ready_now, _scope_now)
	await _frames(1)
	_scope_token["combat"] = 2
	await _frames(3)
	_expect(_log == _strings(["a", "a", "b"]), "in-place scope change restarts stage zero before acknowledgment")

	_reset()
	_queue.request(_steps(["a", "failure", "never"], "failure"), _ready_now, _scope_now)
	await _frames(4)
	_expect(_log == _strings(["a", "failure"]) and not _queue.busy(), "failed step stops without automatic retry")
	_queue.request(_steps(["retry"]), _ready_now, _scope_now)
	await _frames(1)
	_expect(_log == _strings(["a", "failure", "retry"]), "later explicit request can retry after failure")

	_reset()
	_queue.request(_steps(["cancelled"]), _ready_now, _scope_now)
	_queue.cancel()
	_queue.request(_steps(["new"]), _ready_now, _scope_now)
	await _frames(2)
	_expect(_log == _strings(["new"]) and not _queue.busy(), "cancelled sleeping owner cannot drain a replacement job")

	_reset()
	var cancel_steps: Array[Callable]
	cancel_steps.append(_cancel_during_step)
	cancel_steps.append(_record.bind("never", true))
	_queue.request(cancel_steps, _ready_now, _scope_now)
	await _frames(2)
	_expect(_log == _strings(["cancel"]) and not _queue.busy(), "cancellation inside a synchronous step makes its continuation inert")

	_reset()
	var invalid_steps: Array[Callable]
	invalid_steps.append(Callable())
	_queue.request(invalid_steps, _ready_now, _scope_now)
	await _frames(1)
	_expect(_log.is_empty() and not _queue.busy(), "invalid step stops safely")
	_queue.request(_steps(["never"]), Callable(), _scope_now)
	await _frames(1)
	_expect(_log.is_empty() and not _queue.busy(), "invalid readiness callback stops safely")
	_queue.request(_steps(["never"]), _ready_now, Callable())
	await _frames(1)
	_expect(_log.is_empty() and not _queue.busy(), "invalid scope callback stops safely")

	_reset()
	_queue.request(_steps(["cancelled"]), _ready_now, _scope_now)
	_expect(_queue.flush(_steps(["flush_a", "flush_b"])), "explicit flush succeeds synchronously")
	_expect(_log == _strings(["flush_a", "flush_b"]) and not _queue.busy(), "flush requires no rendered frame")
	await _frames(2)
	_expect(_log == _strings(["flush_a", "flush_b"]), "old sleeper remains inert after flush")
	_expect(not _queue.flush(_steps(["failure", "never"], "failure")), "flush reports a failed step")
	_expect(_log == _strings(["flush_a", "flush_b", "failure"]), "flush stops at failure")

	_reset()
	var request_steps: Array[Callable]
	request_steps.append(_request_during_flush)
	_expect(_queue.flush(request_steps), "flush may request a later cycle")
	_expect(_log == _strings(["flush"]) and _queue.busy(), "request inside flush cannot drain synchronously")
	await _frames(1)
	_expect(_log == _strings(["flush", "later"]) and not _queue.busy(), "request inside flush starts once on a later frame")

	_queue.cancel()
	print("DEFERRED RECONCILIATION QUEUE RESULT: " + JSON.stringify({"checks": _checks, "errors": _errors}))
	print("TEST RESULT: " + ("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)

func _reset() -> void:
	_queue.cancel()
	_log.clear()
	_frames_seen.clear()
	_ready_flag = true
	_scope_token = {"run": 1, "combat": 1}

func _frames(count: int) -> void:
	for index: int in range(count):
		_pulse.pulse()
		await RenderingServer.frame_post_draw
		await process_frame

func _ready_now() -> bool:
	return _ready_flag

func _scope_now() -> Dictionary:
	return _scope_token

func _record(label: String, success: bool = true) -> bool:
	_log.append(label)
	_frames_seen.append(Engine.get_process_frames())
	return success

func _cancel_during_step() -> bool:
	_record("cancel")
	_queue.cancel()
	return true

func _request_during_flush() -> bool:
	_record("flush")
	_queue.request(_steps(["later"]), _ready_now, _scope_now)
	return true

func _steps(labels: Array, failure_label: String = "") -> Array[Callable]:
	var steps: Array[Callable]
	for label: Variant in labels:
		steps.append(_record.bind(str(label), str(label) != failure_label))
	return steps

func _strings(values: Array) -> Array[String]:
	var result: Array[String]
	result.assign(values)
	return result

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_errors.append(message)
		push_error(message)

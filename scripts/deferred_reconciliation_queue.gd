extends RefCounted
class_name DeferredReconciliationQueue

const Writer = preload("res://scripts/ordered_background_writer.gd")
const Disk = preload("res://scripts/persistence_disk_worker.gd")

# Main-thread reconciliation starts at most one step per rendered frame.
# This schedules work; callbacks own the storage protocol and authoritative
# state. A false step result leaves recovery/retry to a later explicit request.
var _generation: int = 0
var _active: bool = false
var _flushing: bool = false
var _requested: bool = false
var _steps: Array[Callable]
var _ready: Callable
var _scope: Callable
var _cycle_steps: Array[Callable]
var _cycle_ready: Callable
var _cycle_scope: Callable
var _captured_scope: Variant
var _step_index: int
var _receipt: Writer.Receipt
var _receipt_tree: SceneTree
var _receipt_deadline: int

func request(steps: Array[Callable], ready: Callable, scope: Callable) -> void:
	_steps.assign(steps)
	_ready = ready
	_scope = scope
	_requested = true
	_start_if_requested()

func busy() -> bool:
	return _active or _flushing

func cancel() -> void:
	_generation += 1
	_active = false
	_requested = false
	_clear_callbacks()

func flush(steps: Array[Callable]) -> bool:
	# A synchronous callback may request later work, but cannot recursively drain
	# the same coordinator while its explicit checkpoint is still executing.
	if _flushing:
		return false
	cancel()
	_flushing = true
	var generation: int = _generation
	var succeeded: bool = true
	var flush_steps: Array[Callable]
	flush_steps.assign(steps)
	for step: Callable in flush_steps:
		if not step.is_valid() or not bool(step.call()):
			succeeded = false
			break
		if generation != _generation:
			succeeded = false
			break
	_flushing = false
	_start_if_requested()
	return succeeded

func _start_if_requested() -> void:
	if not _requested or _active or _flushing:
		return
	_active = true
	_step_index = 0
	RenderingServer.frame_post_draw.connect(_advance)

func _advance() -> void:
	if _receipt != null:
		return
	var generation: int = _generation
	if _step_index == 0:
		# All requests received while waiting to start collapse into the most
		# recent callback set. Requests during a cycle request one later cycle.
		_requested = false
		_cycle_steps.assign(_steps)
		_cycle_ready = _ready
		_cycle_scope = _scope
	if _cycle_steps.is_empty() or not _cycle_ready.is_valid() or not _cycle_scope.is_valid():
		_finish(generation)
		return
	var ready_now: bool = bool(_cycle_ready.call())
	if not _owns(generation):
		return
	if not ready_now:
		_step_index = 0
		return
	var scope_now: Variant = _cycle_scope.call()
	if not _owns(generation):
		return
	if _step_index == 0:
		_captured_scope = _copy_scope(scope_now)
	elif scope_now != _captured_scope:
		_step_index = 0
		return
	var step: Callable = _cycle_steps[_step_index]
	if not step.is_valid():
		_finish(generation)
		return
	var result: Variant = step.call()
	if not _owns(generation):
		return
	if result is Writer.Receipt:
		# Watch the background write without keeping the scene's step suspended.
		# A scene can leave while the writer still owns its checkpoint.
		_receipt = result
		_receipt_tree = Engine.get_main_loop() as SceneTree
		_receipt_deadline = Time.get_ticks_usec() + Disk.SAVE_DEADLINE_USEC
		_receipt_tree.process_frame.connect(_poll_receipt)
		_poll_receipt()
		return
	_complete_step(generation, bool(result))

func _poll_receipt() -> void:
	# Teardown can clear the receipt while process_frame is still emitting.
	if _receipt == null:
		return
	if not _receipt.finished:
		Disk.Job.enforce_wait_deadline(_receipt_deadline)
		return
	var succeeded: bool = _receipt.succeeded
	_clear_receipt()
	_complete_step(_generation, succeeded)

func _complete_step(generation: int, succeeded: bool) -> void:
	if not succeeded:
		_finish(generation)
		return
	_step_index += 1
	if _step_index == _cycle_steps.size():
		if _requested:
			_step_index = 0
		else:
			_finish(generation)

func _clear_receipt() -> void:
	if _receipt_tree != null:
		_receipt_tree.process_frame.disconnect(_poll_receipt)
	_receipt_tree = null
	_receipt = null

func _owns(generation: int) -> bool:
	return _active and not _flushing and generation == _generation

func _finish(generation: int) -> void:
	if not _owns(generation):
		return
	_active = false
	_requested = false
	_clear_callbacks()

func _clear_callbacks() -> void:
	if RenderingServer.frame_post_draw.is_connected(_advance):
		RenderingServer.frame_post_draw.disconnect(_advance)
	_clear_receipt()
	_steps.clear()
	_cycle_steps.clear()
	_ready = Callable()
	_scope = Callable()
	_cycle_ready = Callable()
	_cycle_scope = Callable()
	_captured_scope = null

func _copy_scope(value: Variant) -> Variant:
	# Scope tokens may be structured, mutable dictionaries. Keep the stage-zero
	# value independent so an in-place update is still detected after a yield.
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return value

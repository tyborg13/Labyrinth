extends RefCounted
class_name DeferredReconciliationQueue

# Main-thread reconciliation with one synchronous step per rendered frame.
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
	_drain(_generation)

func _drain(generation: int) -> void:
	var step_index: int = 0
	while _owns(generation):
		# call_deferred alone can run inside the requesting completion frame.
		# Cross a real render boundary before every disk/analytics stage.
		await RenderingServer.frame_post_draw
		if not _owns(generation):
			return
		if step_index == 0:
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
			step_index = 0
			continue
		var scope_now: Variant = _cycle_scope.call()
		if not _owns(generation):
			return
		if step_index == 0:
			_captured_scope = _copy_scope(scope_now)
		elif scope_now != _captured_scope:
			step_index = 0
			continue
		var step: Callable = _cycle_steps[step_index]
		if not step.is_valid():
			_finish(generation)
			return
		var succeeded: bool = bool(step.call())
		if not _owns(generation):
			return
		if not succeeded:
			_finish(generation)
			return
		step_index += 1
		if step_index == _cycle_steps.size():
			if _requested:
				step_index = 0
			else:
				_finish(generation)
				return

func _owns(generation: int) -> bool:
	return _active and not _flushing and generation == _generation

func _finish(generation: int) -> void:
	if not _owns(generation):
		return
	_active = false
	_requested = false
	_clear_callbacks()

func _clear_callbacks() -> void:
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

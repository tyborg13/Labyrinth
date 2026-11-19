extends RefCounted
## One FIFO across checkpoint, profile and analytics file transactions.
## A pool task drains the queue and exits when it becomes empty.

class Job extends RefCounted:
	var write: Callable
	var delay_msec: int
	var _result: Dictionary
	var _started_usec: int = 0
	var _mutex := Mutex.new()
	var _done := Semaphore.new()

	func _init(operation: Callable, probe_delay_msec: int) -> void:
		write = operation
		delay_msec = probe_delay_msec

	func execute() -> void:
		var started: int = Time.get_ticks_usec()
		_mutex.lock()
		_started_usec = started
		_mutex.unlock()
		if delay_msec > 0: OS.delay_msec(delay_msec)
		var succeeded: bool = bool(write.call())
		write = Callable()
		var elapsed: int = Time.get_ticks_usec() - started
		_mutex.lock()
		_result = {"succeeded": succeeded, "started_usec": started, "elapsed_usec": elapsed}
		_mutex.unlock()
		_done.post()

	func has_started() -> bool:
		_mutex.lock()
		var started: bool = _started_usec > 0
		_mutex.unlock()
		return started

	func result(wait: bool) -> Dictionary:
		if wait: _done.wait()
		_mutex.lock()
		var value: Dictionary = _result
		_mutex.unlock()
		return value

static var _queue: Array[Job]
static var _mutex := Mutex.new()
static var _running: bool = false
static var _tasks: Array[int]

static func submit(operation: Callable, probe_delay_msec: int = 0) -> Job:
	var job := Job.new(operation, probe_delay_msec)
	_reap_finished_tasks()
	_mutex.lock()
	_queue.append(job)
	if not _running:
		_running = true
		_tasks.append(WorkerThreadPool.add_task(_drain, true, "Persistence disk transactions"))
	_mutex.unlock()
	return job

static func run(operation: Callable) -> bool:
	var job := submit(operation)
	return bool(job.result(true)["succeeded"])

static func join() -> void:
	# Shutdown has settled the stores, including failed transactions.
	for task: int in _tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	_tasks.clear()

static func _reap_finished_tasks() -> void:
	for index: int in range(_tasks.size() - 1, -1, -1):
		if WorkerThreadPool.is_task_completed(_tasks[index]):
			WorkerThreadPool.wait_for_task_completion(_tasks[index])
			_tasks.remove_at(index)

static func _drain() -> void:
	while true:
		_mutex.lock()
		if _queue.is_empty():
			_running = false
			_mutex.unlock()
			return
		var job: Job = _queue.pop_front()
		_mutex.unlock()
		job.execute()

extends RefCounted
## One FIFO across checkpoint, profile and analytics file transactions.
## A pool task drains the queue and exits when it becomes empty.

const SAVE_DEADLINE_USEC := 8_000_000
const WAIT_POLL_USEC := 250

class Job extends RefCounted:
	var write: Callable
	var delay_msec: int
	var _result: Dictionary
	var _started_usec: int = 0
	var _mutex := Mutex.new()
	var _done := Semaphore.new()

	static func enforce_wait_deadline(deadline: int) -> void:
		if Time.get_ticks_usec() < deadline: return
		# An OS write can still commit after a timeout. Returning failure would
		# let gameplay proceed while that transaction can still replace the save.
		var message := "Persistence did not settle within the save deadline."
		push_error(message)
		if OS.kill(OS.get_process_id()) != OK: OS.crash(message)

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
		if wait:
			var deadline := Time.get_ticks_usec() + SAVE_DEADLINE_USEC
			while not _done.try_wait():
				enforce_wait_deadline(deadline)
				OS.delay_usec(WAIT_POLL_USEC)
		_mutex.lock()
		var value: Dictionary = _result
		_mutex.unlock()
		return value

	func wait_in_tree(tree: SceneTree) -> Dictionary:
		var deadline := Time.get_ticks_usec() + SAVE_DEADLINE_USEC
		var value := result(false)
		while value.is_empty():
			enforce_wait_deadline(deadline)
			await tree.process_frame
			value = result(false)
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

static func run_in_tree(tree: SceneTree, operation: Callable) -> bool:
	var job := submit(operation)
	var result := await job.wait_in_tree(tree)
	return bool(result["succeeded"])

static func join() -> void:
	# Shutdown has settled the stores, including failed transactions.
	var deadline := Time.get_ticks_usec() + SAVE_DEADLINE_USEC
	for task: int in _tasks:
		while not WorkerThreadPool.is_task_completed(task):
			Job.enforce_wait_deadline(deadline)
			OS.delay_usec(WAIT_POLL_USEC)
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

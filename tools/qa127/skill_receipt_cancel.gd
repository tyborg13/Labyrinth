extends SceneTree
## Hold the first background receipt while unloading the scene that awaits it.

class Host extends "res://scripts/run_scene.gd":
	var receipt_ref: WeakRef
	var appends: int

	func _ready() -> void:
		set_process(false)

	func _notification(_what: int) -> void:
		pass

	func _exit_tree() -> void:
		_cancel_deferred_skill_analytics()

	func _stage_skill_analytics_outbox() -> bool:
		return true

	func _persist_committed_boundary(boundary: String = "") -> bool:
		if boundary == "combat_skill_event_outbox":
			_deferred_checkpoint_receipt.queued = true
			receipt_ref = weakref(_deferred_checkpoint_receipt)
		return true

	func _append_and_acknowledge_skill_analytics() -> bool:
		appends += 1
		return true

const SETTLE_FRAMES: int = 4
const WATCHDOG_SECONDS: float = 10.0
var _failures: int

func _initialize() -> void:
	create_timer(WATCHDOG_SECONDS).timeout.connect(func() -> void:
		push_error("QA127 skill receipt test did not complete")
		quit(1)
	)
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	for succeeded: bool in [true, false]:
		var host: Host = _start_outbox(packed)
		var receipt: RefCounted = host.receipt_ref.get_ref()
		receipt.resolve(succeeded)
		await process_frame
		for frame: int in range(SETTLE_FRAMES):
			RenderingServer.frame_post_draw.emit()
			await process_frame
		_expect(host.appends == int(succeeded), "The append follows only a successful receipt")
		_expect(not host._skill_analytics_queue.busy(), "Queue stops after either receipt result")
		host.free()

	var departing: Host = _start_outbox(packed)
	var receipt_ref: WeakRef = departing.receipt_ref
	_expect(receipt_ref.get_ref() != null, "The departing scene is awaiting a receipt")
	departing.free()
	for frame: int in range(SETTLE_FRAMES): await process_frame
	_expect(receipt_ref.get_ref() == null, "Freeing the scene releases its pending receipt")
	# Let an unfixed waiter finish after recording the failure.
	var leftover: RefCounted = receipt_ref.get_ref()
	if leftover != null: leftover.resolve(false)
	await process_frame
	print("QA127 SKILL RECEIPT TEST RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(int(_failures > 0))

func _start_outbox(packed: PackedScene) -> Host:
	var host: Node = packed.instantiate()
	host.set_script(Host)
	# Opt into the asynchronous path without installing a real disk worker.
	var persistence := Node.new()
	persistence.name = "RunPersistence"
	host.add_child(persistence)
	root.add_child(host)
	host._run_state = {"mode": "combat"}
	host._request_skill_event_analytics()
	RenderingServer.frame_post_draw.emit()
	return host

func _expect(condition: bool, message: String) -> void:
	if condition: return
	_failures += 1
	push_error(message)

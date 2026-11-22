extends "res://tools/perf134/probe.gd"
## Model a route that leaves an unowned draw observer after reporting success.
## A lambda that does not capture self holds the script, even without an await.

func _run() -> void:
	RenderingServer.frame_post_draw.connect(func() -> void: pass)
	RenderingServer.frame_pre_draw.connect(func() -> void: pass)
	RenderingServer.frame_post_draw.connect(_owned_observer)
	root.tree_exiting.connect(_assert_observers_released, CONNECT_ONE_SHOT)
	print("QA124 DRAW SHUTDOWN: armed both renderer signals")
	_finish()

func _owned_observer() -> void:
	pass

func _assert_observers_released() -> void:
	var count: int = _script_observer_count(RenderingServer.frame_pre_draw)
	count += _script_observer_count(RenderingServer.frame_post_draw)
	var owned: bool = RenderingServer.frame_post_draw.is_connected(_owned_observer)
	if owned: RenderingServer.frame_post_draw.disconnect(_owned_observer)
	var passed: bool = count == 0 and owned
	print("QA124 DRAW SHUTDOWN TEST RESULT: %s (%d retained script callbacks, owned observer=%s)" % [
		"PASS" if passed else "FAIL", count, owned])
	if not passed: quit(1)

func _script_observer_count(draw: Signal) -> int:
	var count: int = 0
	for connection: Dictionary in draw.get_connections():
		var callback: Callable = connection["callable"]
		if callback.get_object() is GDScript: count += 1
	return count

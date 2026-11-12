extends SceneTree

const Clock = preload("res://scripts/presentation_clock.gd")
const FPS: int = 30

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if Clock._read_movie_fps() != FPS:
		push_error("Script-visible fixed rate must be 30 fps")
		quit(1)
		return
	var synthetic := GDScript.new()
	# Same isolated clock seam as ptf09/flicker_check.gd: no renderer or movie
	# writer is launched headlessly. Only engine mode discovery is substituted.
	var original: Script = Clock
	synthetic.source_code = original.source_code.replace('Engine.get_write_movie_path()', '"movie.png"')
	if synthetic.reload() != OK:
		quit(1)
		return
	var previous: int = -1
	var failures: int = 0
	for frame: int in range(5):
		await process_frame
		var now: int = synthetic.call("ticks_usec")
		if previous >= 0 and absi(now - previous - 33333) > 1:
			failures += 1
			push_error("Movie clock step: %d usec, expected 33333 +/-1" % (now - previous))
		previous = now
	synthetic.call("release_shutdown_callables")
	print("RD02 MOVIE CLOCK: %s (script-visible 30 fps, four fixed clock steps; no MovieWriter/headless pixels)" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

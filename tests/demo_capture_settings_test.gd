extends SceneTree

const CaptureSettings = preload("res://tools/demo_clips/capture_settings.gd")
const Sources = preload("res://tests/sfx_sync_sources.gd")

func _initialize() -> void:
	var settings: Dictionary = CaptureSettings.snapshot()
	print("DEMO CAPTURE SETTINGS ", JSON.stringify(settings))
	if not CaptureSettings.verified(settings):
		push_error("Capture quality override was not loaded at startup")
		quit(1)
		return
	print("DEMO CAPTURE SETTINGS TEST: PASS")
	if OS.get_cmdline_user_args().has("--verify-movie-guard"):
		# Exercise the actual scene guard with engine-path values. The installed
		# dummy renderer crashes in MovieWriter::add_frame, so inject only this
		# getter; leave OS.get_cmdline_args() real and without --write-movie.
		var source: String = FileAccess.get_file_as_string("res://tools/demo_clips/demo_clip.gd")
		var begin: int = source.find("func _ready() -> void:")
		var end: int = source.find("\tParallel.apply_from_environment()", begin)
		assert(begin >= 0 and end > begin)
		var guard: String = source.substr(begin, end - begin).replace("func _ready()", "func verify_movie_guard()")
		guard = guard.replace("Engine.get_write_movie_path()", "movie_path_getter.call()")
		var script: GDScript = Sources.compile_script("tests/demo_capture_settings_test.gd", 'extends Node\nvar movie_path_getter: Callable\nconst CaptureSettings = preload("res://tools/demo_clips/capture_settings.gd")\n' + guard)
		assert(script != null)
		var node := Node.new()
		node.set_script(script)
		root.add_child(node)
		node.set("movie_path_getter", func() -> String: return "")
		node.call("verify_movie_guard")
		node.set("movie_path_getter", func() -> String: return "/test-only/movie.avi")
		node.call("verify_movie_guard")
		node.free()
		print("DEMO MOVIE GUARD TEST: PASS")
	quit()

extends SceneTree

# Deterministic adaptation of the director's before/switch/after reproduction.
# No warmup, random source, cache deletion, or hidden extra draw.
const Fixture = preload("res://tests/helpers/steam_cache_switch_fixture.gd")
const Counters = preload("res://tests/helpers/pipeline_counter_snapshot.gd")
const SIZE := Vector2i(1920, 1080)
const QUAD_SIZE := Vector2(64, 64)
const BEFORE_POSITION := Vector2(20, 20)
const AFTER_POSITION := Vector2(120, 20)
const SETTLE_FRAMES: int = 12
const DRAW_FRAMES: int = 10
const MIN_AFTER_BLUE: float = 0.6
const BEFORE_CODE: String = "shader_type canvas_item;\nuniform float shader01_before = 2.0;\nvoid fragment() { COLOR = vec4(UV, shader01_before * 0.25, 1.0); }\n"
const AFTER_CODE: String = "shader_type canvas_item;\nuniform float shader01_after = 3.0;\nvoid fragment() { COLOR = vec4(UV, shader01_after * 0.25, 1.0); }\n"
var output: String = "res://output/shader-01/shader-session/report.json"
var session: int = 1
var backend: String = ""
var failures: Array[String]
var _capture_viewport: SubViewport

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--cache-session="): session = int(arg.trim_prefix("--cache-session="))
		if arg.begins_with("--cache-backend="): backend = arg.trim_prefix("--cache-backend=")
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("SHADER CACHE NATIVE RESULT: FAIL (requires real renderer)")
		quit(1)
		return
	if backend not in ["metal", "vulkan"]:
		print("SHADER CACHE NATIVE RESULT: FAIL (requires --cache-backend=metal or vulkan)")
		quit(1)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(SIZE)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	_setup_capture_viewport()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	for frame: int in range(SETTLE_FRAMES): await RenderingServer.frame_post_draw
	var report: Dictionary = {"session": session, "backend": backend, "godot": Engine.get_version_info()["string"], "renderer": RenderingServer.get_current_rendering_method(), "api": RenderingServer.get_video_adapter_api_version(), "ui_scale": 1.0, "viewport": "1920x1080"}
	report["before_shader"] = await _draw_shader("before", BEFORE_CODE, BEFORE_POSITION)
	report["switch"] = Fixture.switch_user_directory()
	for state: Dictionary in report["switch"]["folders"].values():
		_expect(state["linked"] and state["shared"], "Native proof shares every cache directory")
	for frame: int in range(SETTLE_FRAMES): await RenderingServer.frame_post_draw
	report["after_shader"] = await _draw_shader("after", AFTER_CODE, AFTER_POSITION)
	if session == 2 and backend == "vulkan":
		_expect(Counters.total(report["after_shader"]["pipeline_delta"]) == 0, "Second-session deterministic shader compiles zero pipelines")
	var capture: String = output.get_base_dir().path_join("shader_cache_switch.png")
	var rendered: Image = _capture_viewport.get_texture().get_image()
	report["capture_size"] = {"width": rendered.get_width(), "height": rendered.get_height()}
	_expect(rendered.get_size() == SIZE, "Capture has the fixed 1920x1080 proof resolution")
	var sample_point := Vector2i(AFTER_POSITION + QUAD_SIZE * 0.5)
	if rendered.get_size() == SIZE:
		_expect(rendered.get_pixelv(sample_point).b > MIN_AFTER_BLUE, "Deterministic after-switch shader actually rendered at its expected pixel")
	_expect(rendered.save_png(ProjectSettings.globalize_path(capture)) == OK, "Native capture saved")
	print(ProjectSettings.globalize_path(capture))
	report["failures"] = failures
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	for failure: String in failures: push_error(failure)
	print("SHADER CACHE NATIVE RESULT: %s backend=%s session=%d after_pipeline_compilations=%d report=%s" % ["PASS" if failures.is_empty() else "FAIL", backend, session, Counters.total(report["after_shader"]["pipeline_delta"]), output])
	quit(0 if failures.is_empty() else 1)

func _draw_shader(tag: String, code: String, position: Vector2) -> Dictionary:
	print("SHADER01 %s_SHADER_BEGIN" % tag.to_upper())
	var before: Dictionary = Counters.read()
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	var quad := ColorRect.new()
	quad.size = QUAD_SIZE
	quad.position = position
	quad.material = material
	_capture_viewport.add_child(quad)
	var samples: Array[Dictionary]
	var previous: Dictionary = before
	for frame: int in range(DRAW_FRAMES):
		quad.queue_redraw()
		await RenderingServer.frame_post_draw
		var current: Dictionary = Counters.read()
		var sample: Dictionary = {"frame": Engine.get_process_frames(), "pipelines": Counters.difference(previous, current)}
		samples.append(sample)
		previous = current
		print("SHADER01 SHADER FRAME: " + JSON.stringify(sample))
	var result: Dictionary = {"source_sha256": code.sha256_text(), "pipeline_delta": Counters.difference(before, Counters.read()), "frames": samples}
	print("SHADER01 %s_SHADER_END" % tag.to_upper())
	return result

func _setup_capture_viewport() -> void:
	# Follow ui03_capture_viewport's fixed texture/display separation. Desktop
	# and Retina window dimensions cannot change proof coordinates or pixels.
	_capture_viewport = SubViewport.new()
	_capture_viewport.name = "EngineCacheCaptureViewport"
	_capture_viewport.size = SIZE
	_capture_viewport.disable_3d = true
	_capture_viewport.gui_disable_input = true
	_capture_viewport.msaa_2d = root.msaa_2d
	_capture_viewport.use_hdr_2d = root.use_hdr_2d
	_capture_viewport.canvas_item_default_texture_filter = root.canvas_item_default_texture_filter
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_capture_viewport)
	var display := TextureRect.new()
	display.name = "EngineCacheCaptureDisplay"
	display.texture = _capture_viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(display)
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

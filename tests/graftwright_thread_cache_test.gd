extends SceneTree

const Parallel = preload("res://scripts/parallel_runtime.gd")
const View = preload("res://scripts/graftwright_view.gd")
const Suite = preload("res://tests/suites/graftwright_suite.gd")

class CountingThread extends "res://scripts/graftwright_thread_effect.gd":
	var mesh_builds: int = 0
	var occlusion_builds: int = 0
	var occlusion_checks: int = 0
	func _mesh(strand: int) -> ArrayMesh:
		mesh_builds += 1
		return super._mesh(strand)
	func _preview_occlusion(start: Vector2, end: Vector2, start_weight: float, end_weight: float) -> Color:
		occlusion_builds += 1
		return super._preview_occlusion(start, end, start_weight, end_weight)
	func segment_occluded(start: Vector2, end: Vector2) -> bool:
		occlusion_checks += 1
		return super.segment_occluded(start, end)

var failed: bool = false

func _initialize() -> void:
	Parallel.apply_from_environment()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	root.add_child(viewport)
	var view := View.new()
	viewport.add_child(view)
	view.size = Vector2(viewport.size)
	await process_frame
	view.configure(Suite.fixture(), false)
	view.begin_work()
	view.select_donor("training_sword")
	view.select_recipient("iron_cleaver")
	view.select_source(0)
	view.select_target(2)
	var selected: Control = view.find_child("GraftPreviewThread", true, false) as Control
	var thread := CountingThread.new()
	thread.preview = true
	thread.origin = selected.get("origin")
	thread.destination = selected.get("destination")
	thread.occlusion_rects.assign(selected.get("occlusion_rects"))
	var host := Control.new()
	viewport.add_child(host)
	host.add_child(thread)
	check(thread.mesh_builds == 1 and thread.occlusion_builds == thread.SEGMENTS, "Layout builds one mesh and one set of occlusion ranges")
	var ribbon: MeshInstance2D = thread._ribbons[0]
	var mesh_id: int = ribbon.mesh.get_instance_id()
	var shader: ShaderMaterial = ribbon.material as ShaderMaterial
	var start: Vector2 = thread.point(0.5)
	var begin: int = Time.get_ticks_usec()
	for i: int in range(600): thread._process(1.0 / 60.0)
	print("GRAFTWRIGHT PREVIEW UPDATE: %.3f ms/frame (600 cached updates)" % (float(Time.get_ticks_usec() - begin) / 600000.0))
	check(thread.mesh_builds == 1 and thread.occlusion_builds == thread.SEGMENTS and thread.occlusion_checks == 0 and ribbon.mesh.get_instance_id() == mesh_id, "Sway never rebuilds geometry or tests layout occlusion")
	check(thread.point(0.5) != start and is_equal_approx(shader.get_shader_parameter("bob"), sin(thread.elapsed * 0.9) * 4.0), "Shader retains the existing gentle sway")
	check(thread.point(0.0) == thread.origin and thread.point(1.0).is_equal_approx(thread.destination), "Sway leaves card endpoints anchored")
	check_occlusion(thread, ribbon.mesh as ArrayMesh)
	thread.hide()
	check(not thread.is_processing(), "Direct hiding stops thread processing")
	var elapsed: float = thread.elapsed
	thread._process(1.0)
	check(thread.elapsed == elapsed, "Hidden thread does no animation work")
	thread.show()
	check(thread.is_processing(), "Showing restores normal sway")
	host.hide()
	check(not thread.is_processing(), "Hiding a parent also stops processing")
	host.show()
	check(thread.is_processing(), "Showing a parent restores normal sway")
	thread.reduced_motion = true
	check(not thread.is_processing() and shader.get_shader_parameter("bob") == 0.0, "Reduced motion stops processing and restores the static thread")
	thread.hide()
	thread.show()
	check(not thread.is_processing(), "Showing never restarts reduced-motion processing")
	thread._process(1.0)
	check(thread.elapsed == elapsed, "Reduced motion does no animation work")
	thread.reduced_motion = false
	check(thread.is_processing() and ribbon.mesh.get_instance_id() == mesh_id, "Restoring motion reuses the cached mesh")
	host.queue_free()
	view.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame
	for node: Node in root.get_node("CursorFeedback").find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()
	await process_frame
	print("GRAFTWRIGHT THREAD CACHE TEST: " + ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)

func check_occlusion(thread: CountingThread, mesh: ArrayMesh) -> void:
	var elapsed: float = thread.elapsed
	var arrays: Array = mesh.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for step: int in range(81):
		var bob: float = -4.0 + step * 0.1
		thread.elapsed = (asin(bob / 4.0) + TAU) / 0.9
		for i: int in range(thread.SEGMENTS):
			var mask: Color = colors[i * 4]
			var cached: bool = (bob > mask.r * 10.0 - 5.0 and bob < mask.g * 10.0 - 5.0) or (bob > mask.b * 10.0 - 5.0 and bob < mask.a * 10.0 - 5.0)
			var live: bool = thread.segment_occluded(thread.point(float(i) / thread.SEGMENTS), thread.point(float(i + 1) / thread.SEGMENTS))
			check(cached == live, "Cached clipping matches the existing thread at bob %.1f, segment %d" % [bob, i])
	thread.elapsed = elapsed

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

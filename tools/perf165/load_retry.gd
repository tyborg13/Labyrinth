extends SceneTree

const Warm = preload("res://scripts/canvas_pipeline_prewarm.gd")
const SceneLoads = preload("res://scripts/menu_run_preload.gd")
const FOG := "res://shaders/section_map_fog.gdshader"
const INJECTED_LOAD_MS := 600
const MAX_IDLE_BATCH_MS := 150
const WAIT_LIMIT_MS := 30000

class SlowFog extends ResourceFormatLoader:
	var entered := Semaphore.new()
	var finished := Semaphore.new()
	var loading_thread: int

	func _get_recognized_extensions() -> PackedStringArray:
		return PackedStringArray(["gdshader"])

	func _recognize_path(path: String, _hint: StringName) -> bool:
		return path == FOG

	func _handles_type(_type: StringName) -> bool:
		return true

	func _get_resource_type(path: String) -> String:
		return "Shader" if path == FOG else ""

	func _load(path: String, _original: String, _subthreads: bool, _cache: int) -> Variant:
		loading_thread = OS.get_thread_caller_id()
		entered.post()
		OS.delay_msec(INJECTED_LOAD_MS)
		var shader := Shader.new()
		shader.code = FileAccess.get_file_as_string(path)
		finished.post()
		return shader

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var owner := Control.new()
	root.add_child(owner)
	var loader := SlowFog.new()
	ResourceLoader.add_resource_format_loader(loader, true)
	# Claim the dependency first so the collision is deterministic even if
	# the run scene takes longer to parse before reaching the fog shader.
	var request := ResourceLoader.load_threaded_request(FOG, "Shader")
	SceneLoads._request_idle(self, owner)
	var worker := owner.get_node(Warm.NODE_NAME)
	worker.set_process(false)
	var deadline := Time.get_ticks_msec() + WAIT_LIMIT_MS
	var entered := false
	while not entered and Time.get_ticks_msec() < deadline:
		entered = loader.entered.try_wait()
		if not entered: await process_frame
	var started := Time.get_ticks_msec()
	worker._process(0.0)
	var elapsed := Time.get_ticks_msec() - started
	var still_loading := entered and not loader.finished.try_wait()
	var fog_pending := _fog_pending(worker)
	var other_submitted: bool = not worker._batch.is_empty()
	var background := entered and loader.loading_thread != OS.get_main_thread_id()
	while SceneLoads.status_for(self, SceneLoads.RUN_SCENE_PATH) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await process_frame
	var packed := SceneLoads.take_for(self, SceneLoads.RUN_SCENE_PATH) as PackedScene
	var fog: Resource
	if ResourceLoader.load_threaded_get_status(FOG) == ResourceLoader.THREAD_LOAD_LOADED:
		fog = ResourceLoader.load_threaded_get(FOG)
	ResourceLoader.remove_resource_format_loader(loader)
	deadline = Time.get_ticks_msec() + WAIT_LIMIT_MS
	while _fog_pending(worker) and Time.get_ticks_msec() < deadline:
		worker._process(0.0)
		await process_frame
	worker._process(0.0)
	var warmed: Dictionary = root.get_meta(Warm.WARMED_META, {})
	var material: ShaderMaterial = warmed.get(Warm._key(root, {"name": "section map fog"}))
	var reused: bool = fog != null and material != null and material.shader == fog
	var ok := request == OK and background and still_loading and fog_pending and other_submitted and elapsed < MAX_IDLE_BATCH_MS and packed != null and reused
	print("PERF165 CACHE RETRY: %s (idle_batch_ms=%d; pending=%s; other_submitted=%s; shared_shader=%s; entered=%s; background=%s; still_loading=%s; packed=%s)" % ["PASS" if ok else "FAIL", elapsed, fog_pending, other_submitted, reused, entered, background, still_loading, packed != null])
	quit(0 if ok else 1)

func _fog_pending(worker: Node) -> bool:
	for recipe: Dictionary in worker._recipes:
		if recipe.get("path") == FOG: return true
	return false

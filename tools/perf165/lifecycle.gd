extends SceneTree

const Warm = preload("res://scripts/canvas_pipeline_prewarm.gd")
const FRAME_LIMIT := 60
const Menu = preload("res://scenes/main_menu.tscn")
const Run = preload("res://scenes/run_scene.tscn")
var _failures: Array[String]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.msaa_2d = Viewport.MSAA_DISABLED
	var owner := Node.new()
	root.add_child(owner)
	Warm.start(owner, Warm.Recipes.Phase.LOADING_COVER, true)
	var worker := owner.get_node_or_null(Warm.NODE_NAME)
	if worker == null:
		push_error("Prewarm did not create an owner")
		quit(1)
		return
	var viewport: SubViewport = worker.get_node("OffscreenSamples")
	var viewport_id := viewport.get_instance_id()
	_expect(viewport.world_2d != root.world_2d, "Offscreen viewport owns a separate canvas")
	_expect(viewport.gui_disable_input and viewport.size == Warm.VIEWPORT_SIZE, "Offscreen viewport is small and input-disabled")
	await process_frame
	Warm.stop(owner)
	await process_frame
	_expect(not is_instance_id_valid(viewport_id), "Cancellation frees the offscreen viewport")
	_expect(root.get_meta(Warm.WARMED_META, {}).is_empty(), "Cancellation before a completed draw marks no variants")
	Warm.start(owner, Warm.Recipes.Phase.LOADING_COVER, true)
	worker = owner.get_node(Warm.NODE_NAME)
	viewport_id = worker.get_node("OffscreenSamples").get_instance_id()
	for frame: int in FRAME_LIMIT:
		if not is_instance_id_valid(viewport_id): break
		await process_frame
	_expect(not is_instance_id_valid(viewport_id), "Completed warmup frees the offscreen viewport")
	var warmed: Dictionary = root.get_meta(Warm.WARMED_META, {})
	_expect(warmed.size() == Warm.Recipes.for_phase(Warm.Recipes.Phase.LOADING_COVER, true).size(), "Complete cover runs every applicable recipe")
	Warm.start(owner, Warm.Recipes.Phase.LOADING_COVER, true)
	_expect(not owner.has_node(Warm.NODE_NAME), "An identical repeat creates no viewport")
	root.msaa_2d = Viewport.MSAA_4X
	Warm.start(owner, Warm.Recipes.Phase.TITLE_IDLE)
	_expect(owner.has_node(Warm.NODE_NAME), "A different render-target sample count can warm again")
	worker = owner.get_node(Warm.NODE_NAME)
	viewport_id = worker.get_node("OffscreenSamples").get_instance_id()
	owner.queue_free()
	await process_frame
	_expect(not is_instance_id_valid(viewport_id), "Owner teardown frees unfinished work")
	print("PERF165 LIFECYCLE: %s (%d failures; %d warmed recipes)" % ["PASS" if _failures.is_empty() else "FAIL", _failures.size(), warmed.size()])
	quit(0 if _failures.is_empty() else 1)

func _expect(value: bool, message: String) -> void:
	if value: return
	_failures.append(message)
	push_error(message)

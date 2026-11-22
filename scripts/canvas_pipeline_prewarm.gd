extends Node
## Best-effort work owned by an existing idle/cover window. The owner never
## waits for a batch and cancels before returning input or revealing a room.

const Recipes = preload("res://scripts/canvas_pipeline_recipes.gd")
const Sample = preload("res://scripts/canvas_pipeline_sample.gd")
const NODE_NAME := "CanvasPipelinePrewarm"
const VIEWPORT_SIZE := Vector2i(64, 48)
const RECIPES_PER_FRAME := 2
const WARMED_META := &"labyrinth_warmed_canvas_pipelines"
const ACTIVE_GROUP := &"labyrinth_canvas_pipeline_workers"
const DEPARTURE_CHECK_META := &"labyrinth_pipeline_departure_check"

var _source: Viewport
var _viewport: SubViewport
var _recipes: Array[Dictionary]
var _batch: Dictionary
var _warmed: Dictionary
var _sample_texture: Texture2D
var _rendered: bool
var _headless: bool
var _stopped: bool
var _submission_allowed: Callable

static func departure_requested(tree: SceneTree) -> bool:
	var check: Callable = tree.root.get_meta(DEPARTURE_CHECK_META, Callable())
	return check.is_valid() and bool(check.call())

static func start(owner: Node, phase: Recipes.Phase, continuing: bool = false, submission_allowed: Callable = Callable()) -> void:
	stop(owner)
	if departure_requested(owner.get_tree()): return
	var source := owner.get_viewport()
	var warmed: Dictionary = source.get_meta(WARMED_META, {})
	var pending: Array[Dictionary] = preload("res://scripts/typed_arrays.gd").dictionaries([])
	for recipe: Dictionary in Recipes.for_phase(phase, continuing):
		if recipe.get("smoothing_off", false) and (source.msaa_2d != Viewport.MSAA_DISABLED or source.transparent_bg or source.use_hdr_2d):
			continue
		if not warmed.has(_key(source, recipe)): pending.append(recipe)
	if pending.is_empty(): return
	source.set_meta(WARMED_META, warmed)
	var worker := new()
	worker.name = NODE_NAME
	worker._source = source
	worker._recipes = pending
	worker._warmed = warmed
	worker._submission_allowed = submission_allowed
	owner.add_child(worker)
	# A prepared title can present in the same frame as _ready. Submit known
	# cover materials immediately so even the direct-title path primes them.
	if phase == Recipes.Phase.COVER_INTRO: worker._process(0.0)

static func stop(owner: Node) -> void:
	var worker := owner.get_node_or_null(NODE_NAME)
	if worker == null: return
	worker.cancel()
	# Remove the name immediately so a replacement can claim the same window.
	owner.remove_child(worker)

static func _key(source: Viewport, recipe: Dictionary) -> String:
	return "%s/%d/%s/%s/%d" % [recipe["name"], _msaa(source, recipe), source.use_hdr_2d,
		_transparent(source, recipe), source.canvas_item_default_texture_filter]

static func _transparent(source: Viewport, recipe: Dictionary) -> bool:
	return source.transparent_bg or recipe.has("target")

static func _msaa(source: Viewport, recipe: Dictionary) -> Viewport.MSAA:
	return Viewport.MSAA_DISABLED if recipe.get("target") == "no_msaa_alpha" else source.msaa_2d

func _ready() -> void:
	add_to_group(ACTIVE_GROUP)
	_headless = DisplayServer.get_name() == "headless"
	_viewport = SubViewport.new()
	_viewport.name = "OffscreenSamples"
	_viewport.size = VIEWPORT_SIZE
	_viewport.world_2d = World2D.new()
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	_viewport.handle_input_locally = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_sample_texture = Sample.texture_for_samples()

func _process(_delta: float) -> void:
	if _stopped: return
	if departure_requested(get_tree()):
		cancel()
		return
	if _submission_allowed.is_valid() and not bool(_submission_allowed.call()): return
	if not _batch.is_empty():
		if _headless: _after_draw()
		if not _rendered: return
		_batch.clear()
		for child: Node in _viewport.get_children():
			_viewport.remove_child(child)
			child.queue_free()
	if _recipes.is_empty():
		cancel()
		return
	_rendered = false
	# A cache miss stays pending, and doesn't prevent other ready entries
	# from using this frame. Take only one render-target configuration per batch.
	var next: Array[Dictionary] = preload("res://scripts/typed_arrays.gd").dictionaries([])
	for recipe: Dictionary in _recipes:
		var key := _key(_source, recipe)
		if _warmed.has(key): continue
		if _batch.size() >= RECIPES_PER_FRAME or (not _batch.is_empty() and not _matches_target(recipe)):
			next.append(recipe)
			continue
		var sample := Sample.build(recipe, _sample_texture)
		if sample == null:
			next.append(recipe)
			continue
		if _batch.is_empty(): _apply_target(recipe)
		if sample.material != null: sample.material.resource_name = recipe["name"]
		_viewport.add_child(sample)
		# Tree callbacks can request departure during add_child itself.
		if _stopped: return
		_batch[key] = sample.material
	_recipes = next
	if not _batch.is_empty(): _viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _matches_target(recipe: Dictionary) -> bool:
	return _msaa(_source, recipe) == _viewport.msaa_2d and _transparent(_source, recipe) == _viewport.transparent_bg

func _apply_target(recipe: Dictionary) -> void:
	_viewport.msaa_2d = _msaa(_source, recipe)
	_viewport.use_hdr_2d = _source.use_hdr_2d
	_viewport.transparent_bg = _transparent(_source, recipe)
	_viewport.canvas_item_default_texture_filter = _source.canvas_item_default_texture_filter
	_viewport.canvas_item_default_texture_repeat = _source.canvas_item_default_texture_repeat
	_viewport.snap_2d_vertices_to_pixel = _source.snap_2d_vertices_to_pixel
	_viewport.snap_2d_transforms_to_pixel = _source.snap_2d_transforms_to_pixel

# ApplicationShutdown acknowledges the real draw before it emits the
# preparation signal that can stop and free this worker during reveal.
func _after_draw() -> void:
	if _batch.is_empty() or _stopped or _rendered: return
	_rendered = true
	# Retain each program and the representative CanvasItemMaterial behind its
	# RID. CanvasItemMaterial releases its shared program at zero users.
	_warmed.merge(_batch)

func cancel() -> void:
	if _stopped: return
	_stopped = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	set_process(false)
	queue_free()

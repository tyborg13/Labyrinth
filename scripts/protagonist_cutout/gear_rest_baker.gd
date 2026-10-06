extends Node

## A dedicated neutral canvas never interrupts the live action. Shared jobs and
## textures bound GPU readback to once per resolved loadout, including illusions.
signal baked(signature: String, texture: Texture2D)

const Rig = preload("res://scripts/protagonist_cutout/rig.gd")
const GearVisuals = preload("res://scripts/protagonist_cutout/gear_visuals.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const BARE_PATH: String = "res://assets/units/protagonist_cutout/front/front_assembled_rest_v9.png"
const DEFAULT_PATH: String = "res://assets/units/protagonist_cutout/front/front_default_gear_rest.png"
static var _cache: Dictionary = {}
static var _jobs: Dictionary = {}
static var _readbacks: Dictionary = {}

static func cached(signature: String) -> Texture2D:
	if _cache.has(signature):
		return _cache[signature]
	var path: String = ""
	if signature == GearVisuals.signature({}):
		path = BARE_PATH
	elif signature == GearVisuals.signature(GearVisuals.DEFAULTS) and FileAccess.file_exists(DEFAULT_PATH):
		path = DEFAULT_PATH
	if not path.is_empty():
		_cache[signature] = AssetLoader.load_texture_source_first(path)
		return _cache[signature]
	return null

static func request(tree: SceneTree, signature: String, equipped: Dictionary) -> Node:
	if _jobs.has(signature):
		return _jobs[signature]
	# The dummy renderer has no pixels or post-draw event. Source-only tests use
	# the documented fallback; the real-renderer suite exercises the bake itself.
	if DisplayServer.get_name() == "headless":
		return null
	var job := new()
	_jobs[signature] = job
	tree.root.add_child(job)
	job._bake.call_deferred(signature, equipped.duplicate())
	return job

func _bake(signature: String, equipped: Dictionary) -> void:
	var canvas := SubViewport.new()
	canvas.size = Vector2i(255, 255)
	canvas.transparent_bg = true
	canvas.disable_3d = true
	canvas.world_2d = World2D.new()
	canvas.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(canvas)
	var rig := Rig.new()
	canvas.add_child(rig)
	if not rig.load_rig():
		push_error("Cannot bake protagonist gear rest: " + str(rig.load_errors))
		_finish(signature, null)
		return
	rig.apply_gear(GearVisuals.ops_for_facing(equipped, "front"))
	rig.apply_pose("rest", 0.0)
	# Bone skinning needs one synchronization frame before its first draw.
	await get_tree().process_frame
	canvas.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image: Image = canvas.get_texture().get_image()
	_readbacks[signature] = int(_readbacks.get(signature, 0)) + 1
	var texture: Texture2D = null
	if image != null and not image.is_empty():
		texture = ImageTexture.create_from_image(image)
		texture.set_meta("gear_rest_image", image)
		AssetLoader.cache_texture_used_rect(texture, image.get_used_rect())
		_cache[signature] = texture
	else:
		push_error("Cannot read protagonist gear rest canvas")
	_finish(signature, texture)

func _finish(signature: String, texture: Texture2D) -> void:
	_jobs.erase(signature)
	baked.emit(signature, texture)
	queue_free()

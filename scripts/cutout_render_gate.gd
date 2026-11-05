extends RefCounted

## Private hero/Maquette canvases: compare submitted pose/paint, never clocks.
## Rig.load_rig/_build_mesh own the immutable skin weights, topology and native
## canvas setup. Gear rebuilds and new paint nodes invalidate that declaration.
## Pose writers change transforms/visibility/tint/depth, Sprite2D paint fields,
## and Polygon2D geometry. Keep this list in step with those owning writers.
## Re-reading immutable skin arrays on every pose costs more CPU than a capture.
const ITEM_CLASSES: PackedStringArray = ["Node2D", "Skeleton2D", "Bone2D", "Sprite2D", "Polygon2D"]
const VIEWPORT_FIELDS: PackedStringArray = ["size", "size_2d_override", "size_2d_override_stretch", "transparent_bg", "canvas_transform", "global_canvas_transform", "canvas_cull_mask", "canvas_item_default_texture_filter", "canvas_item_default_texture_repeat", "msaa_2d", "use_hdr_2d", "snap_2d_transforms_to_pixel", "snap_2d_vertices_to_pixel", "render_target_clear_mode", "oversampling_override"]
static var _paint_fields_by_class: Dictionary = {}

# Probe-only bypass for paired native measurements of the original requests.
var enabled: bool = true
var _viewport: SubViewport
var _scene_tree: SceneTree
var _groups: Array[Dictionary]
var _bindings_dirty: bool = true
var _last_inputs: Array = []
var _resource_revisions: Dictionary = {}
var _safe_textures: Dictionary = {}
var _resources: Array[Resource]
var _unsafe: bool = false

func _init(target: SubViewport) -> void:
	_viewport = target
	_scene_tree = target.get_tree()
	RenderingServer.frame_pre_draw.connect(_before_draw)
	target.tree_exiting.connect(_disconnect)
	target.size_changed.connect(invalidate_geometry)
	_scene_tree.node_added.connect(_node_added)

func _disconnect() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_before_draw): RenderingServer.frame_pre_draw.disconnect(_before_draw)
	# A viewport may leave, re-enter and leave the tree again before it is freed.
	# Disconnect the original subscriptions while that first exit is in progress.
	if _scene_tree != null and _scene_tree.node_added.is_connected(_node_added): _scene_tree.node_added.disconnect(_node_added)
	_scene_tree = null
	if is_instance_valid(_viewport):
		if _viewport.tree_exiting.is_connected(_disconnect): _viewport.tree_exiting.disconnect(_disconnect)
		if _viewport.size_changed.is_connected(invalidate_geometry): _viewport.size_changed.disconnect(invalidate_geometry)
	for resource: Resource in _resources:
		resource.changed.disconnect(_resource_changed.bind(resource.get_instance_id()))
	_resources.clear()
	_groups.clear()
	_viewport = null

## Gear can replace existing geometry without adding a node. Its owning writer
## calls this before applying the new loadout. Structural changes force a capture.
func invalidate_geometry() -> void:
	_bindings_dirty = true
	_last_inputs.clear()
	if is_instance_valid(_viewport): _viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _node_added(node: Node) -> void:
	if is_instance_valid(_viewport) and _viewport.is_ancestor_of(node): invalidate_geometry()

func _before_draw() -> void:
	if not enabled or not is_instance_valid(_viewport): return
	# All private canvas writes come through pose/gear writers and already
	# request UPDATE_ONCE. Board flash/dissolve/tint is outside this World2D.
	if _viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED: return
	if _bindings_dirty: _bind_nodes()
	_unsafe = false
	var inputs: Array = []
	for field: String in VIEWPORT_FIELDS: inputs.append(_viewport.get(field))
	inputs.append(_viewport.world_2d.get_instance_id())
	for group: Dictionary in _groups:
		var rig: Node = group["root"]
		if not is_instance_valid(rig):
			invalidate_geometry()
			return
		if not rig is Node2D:
			_unsafe = true
			continue
		inputs.append(rig.visible)
		if not rig.visible: continue
		if bool(group["unsafe"]): _unsafe = true
		for item: Node2D in group["items"]:
			if not is_instance_valid(item):
				invalidate_geometry()
				return
			# Hidden bones still skin visible meshes parented outside the bone.
			# Never prune a hidden bone (or its descendants) from this signature.
			inputs.append_array([item.transform, item.visible, item.modulate, item.self_modulate, item.show_behind_parent, item.top_level, item.clip_children, item.light_mask, item.visibility_layer, item.z_index, item.z_as_relative, item.y_sort_enabled, item.texture_filter, item.texture_repeat, item.use_parent_material])
			if item.material != null or (item is Skeleton2D and item.get("modification_stack") != null): _unsafe = true
		for paint: Node2D in group["paint"]:
			for field: String in _paint_fields(paint.get_class()):
				var value: Variant = paint.get(field)
				if value is Resource: _append_texture(value, inputs)
				else: inputs.append(value)
	if _unsafe:
		# Unknown shaders (TIME/globals/samplers), textures or custom draw/process
		# code must render continuously, even when the sampled pose is held.
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_last_inputs.clear()
	elif inputs == _last_inputs:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	else:
		# Exact Variant equality, with copy-on-write native arrays. No hash and
		# no var_to_bytes alignment padding in the equality decision.
		_last_inputs = inputs
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _bind_nodes() -> void:
	_groups.clear()
	for root: Node in _viewport.get_children():
		var group: Dictionary = {"root": root, "items": [], "paint": [], "unsafe": not root is Node2D}
		_collect(root, group)
		_groups.append(group)
	_bindings_dirty = false

func _collect(node: Node, group: Dictionary) -> void:
	if node is Node2D:
		group["items"].append(node)
		if not ITEM_CLASSES.has(node.get_class()) or node.has_method("_draw") or node.has_method("_process") or node.has_method("_physics_process"): group["unsafe"] = true
		if node is Sprite2D or node is Polygon2D: group["paint"].append(node)
	else: group["unsafe"] = true
	for child: Node in node.get_children(): _collect(child, group)

static func _paint_fields(native_class: String) -> PackedStringArray:
	if _paint_fields_by_class.has(native_class): return _paint_fields_by_class[native_class]
	var fields := PackedStringArray()
	for property: Dictionary in ClassDB.class_get_property_list(native_class, true):
		var field: String = str(property["name"])
		# Skin bindings are constructed once by Rig._build_mesh. They do not
		# animate; new/changed gear invalidates the entire declaration above.
		if int(property["usage"]) & PROPERTY_USAGE_STORAGE and field != "bones": fields.append(field)
	_paint_fields_by_class[native_class] = fields
	return fields

func _append_texture(resource: Resource, inputs: Array) -> void:
	var id: int = resource.get_instance_id()
	if not _resource_revisions.has(id):
		_resource_revisions[id] = 0
		_resources.append(resource)
		resource.changed.connect(_resource_changed.bind(id))
		# AssetLoader's approved source textures are immutable during playback.
		# Unidentified/runtime textures and scripted resources have no such proof.
		_safe_textures[id] = resource is Texture2D and resource.get_script() == null and not str(resource.get_meta("asset_source_path", "")).is_empty() and (resource is ImageTexture or resource is CompressedTexture2D)
	inputs.append(id)
	inputs.append(_resource_revisions[id])
	if not _safe_textures[id]: _unsafe = true

func _resource_changed(id: int) -> void:
	_resource_revisions[id] = int(_resource_revisions.get(id, 0)) + 1
	invalidate_geometry()

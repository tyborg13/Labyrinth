extends Node

# The load cover owns this job. CPU decoding can overlap the scene request;
# textures/cache entries are still published by the existing main-thread APIs.
const Assets = preload("res://scripts/asset_loader.gd")
const RigData = preload("res://scripts/protagonist_cutout/rig_data.gd")
const ComponentSurface = preload("res://scripts/ui_component_surface.gd")
const SurfaceFinish = preload("res://scripts/ui_surface_finish.gd")
const MapSkin = preload("res://scripts/section_map_skin.gd")
const RunSfx = preload("res://scripts/run_sfx_library.gd")

var _initial_cpu_asset_holds: Array[RefCounted]
var complete: bool = false

static func owner_is_active(owner: Variant, still_active: Callable) -> bool:
	return is_instance_valid(owner) and not owner.is_queued_for_deletion() and bool(still_active.call())

static func start_for(cover: Node, present_frame: Callable, still_active: Callable) -> Node:
	var job := new()
	job.name = "InitialRunCpuAssets"
	job.process_mode = Node.PROCESS_MODE_ALWAYS
	cover.add_child(job)
	_prepare_for.call_deferred(job, cover.get_tree().root, present_frame, still_active)
	return job

static func _prepare_for(job: Node, root: Node, present_frame: Callable, still_active: Callable) -> void:
	# Previously these sources were published by the scene/board manifests before
	# CPU preparation. Keep their decode off the main thread when starting early.
	var manifest: Dictionary = {}
	for name: String in ["action_frame", "medallion", "panel_frame"]:
		manifest[MapSkin.ART + name + ".png"] = false
	for id: String in MapSkin.Icons.all_icon_ids():
		var path: String = MapSkin.Icons.icon_path(id)
		if not path.is_empty(): manifest[path] = false
	preload("res://scripts/run_loading_texture_manifest.gd").add_to(manifest)
	await Assets.prepare_textures_for(root, manifest, present_frame, still_active)
	if not owner_is_active(job, still_active): return
	await prepare_cpu_assets_for(job, root, present_frame, still_active)
	if owner_is_active(job, still_active): job.complete = true

static func finish_for(job: Node, scene: Node, present_frame: Callable, still_active: Callable) -> void:
	while owner_is_active(job, still_active) and not job.complete:
		await present_frame.call()
	if not owner_is_active(job, still_active): return
	scene._initial_cpu_asset_holds.append_array(job._initial_cpu_asset_holds)
	job._initial_cpu_asset_holds.clear()
	job.queue_free()

static func prepare_cpu_assets_for(scene: Node, root: Node, present_frame: Callable, still_active: Callable) -> void:
	var texture_manifest: Dictionary = {}
	for path: String in ["res://assets/units/protagonist_cutout/front.json", "res://assets/units/protagonist_cutout/rear.json", "res://assets/units/scavenger_cutout/front.json"]:
		var prepared: RefCounted = (await Assets.prepare_cpu_value_for(root, RigData.prepare_owned_source.bind(path), present_frame, still_active)) as RefCounted
		if not owner_is_active(scene, still_active): return
		var published: RefCounted = RigData.publish_owned_source(path, prepared)
		if published != null:
			scene._initial_cpu_asset_holds.append(published)
			texture_manifest.merge(RigData.source_texture_manifest(published, path))
	await Assets.prepare_textures_for(root, texture_manifest, present_frame, still_active)
	if not owner_is_active(scene, still_active): return
	await ComponentSurface.prepare_initial_assets_for(root, present_frame, still_active)
	if not owner_is_active(scene, still_active): return
	await SurfaceFinish.prepare_initial_assets_for(root, present_frame, still_active)
	if not owner_is_active(scene, still_active): return
	await MapSkin.prepare_initial_assets_for(root, present_frame, still_active)
	if not owner_is_active(scene, still_active): return
	var paths := PackedStringArray()
	for mode: String in ["room", "campfire"]:
		var ambient: Dictionary = RunSfx.ambient_entry_for_mode(mode)
		var path: String = str(ambient.get("path", ""))
		if not path.is_empty() and not paths.has(path): paths.append(path)
	await Assets.prepare_audio_for(root, paths, present_frame, still_active, true)

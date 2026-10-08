extends SceneTree

const Assets = preload("res://scripts/asset_loader.gd")
const Component = preload("res://scripts/ui_component_surface.gd")
const Surface = preload("res://scripts/ui_surface_finish.gd")
const RigData = preload("res://scripts/protagonist_cutout/rig_data.gd")
const MapSkin = preload("res://scripts/section_map_skin.gd")
const RoomIcons = preload("res://scripts/room_icon_library.gd")
const RunSfx = preload("res://scripts/run_sfx_library.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const SOURCE: String = "res://assets/art/ui/section_map/medallion.png"
var _errors: Array[String]
var _active: bool = true
var _present_count: int = 0
var _cancel_next_frame: bool = false
var _remove_next_frame: Node

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var original: Texture2D = Assets.load_texture_source_first(SOURCE)
	var expected: PackedByteArray = original.get_image().get_data()
	Assets._texture_cache.erase(SOURCE)
	var before: int = _present_count
	await Assets.prepare_textures_for(root, {SOURCE: true}, _present, _alive)
	var prepared: Texture2D = Assets.load_texture_source_first(SOURCE)
	_expect(prepared.get_image().get_data() == expected, "Source decoding on a worker must preserve every pixel and image format")
	_expect(prepared.get_size() == original.get_size() and str(prepared.get_meta("asset_source_path", "")) == SOURCE, "Publication must preserve dimensions and logical source identity")
	_expect(_present_count > before, "Cold preparation must present frames while the worker decodes")
	before = _present_count
	await Assets.prepare_textures_for(root, {SOURCE: true}, _present, _alive)
	_expect(Assets.load_texture(SOURCE) == prepared and _present_count == before, "A warm preparation must retain texture identity and perform no waiting")
	var value: Variant = await Assets.prepare_cpu_value_for(root, _produce, _present, _alive)
	_expect(value is Dictionary and int(value.get("worker_task", -1)) >= 0, "CPU factories must actually execute on an owned worker task")
	_expect(value.get("pixels") is Image and (value["pixels"] as Image).get_size() == Vector2i(384, 384), "Joined results must retain the complete generated CPU image")
	_expect(WorkerThreadPool.get_caller_task_id() == -1, "Result consumption must remain on the main thread")
	await _test_owned_rig_sources()
	await _test_component_images()
	await _test_map_images()
	await _test_audio()
	Assets._texture_cache.erase(SOURCE)
	_cancel_next_frame = true
	await Assets.prepare_textures_for(root, {SOURCE: true}, _present, _alive)
	_expect(not Assets._texture_cache.has(SOURCE), "Cancelled preparation must join its worker without publishing a texture")
	_active = true
	_cancel_next_frame = true
	value = await Assets.prepare_cpu_value_for(root, _produce, _present, _alive)
	_expect(value == null, "Cancelled CPU generation must discard its private result")
	_active = true
	var host := Node.new()
	root.add_child(host)
	_remove_next_frame = host
	await Assets.prepare_textures_for(host, {SOURCE: true}, _present, _alive)
	_expect(not is_instance_valid(host) and not Assets._texture_cache.has(SOURCE), "Host teardown must join and discard the worker without resuming a freed node or publishing")
	await process_frame
	var drains: Array[Node] = root.find_children("*Drain*", "Node", true, false)
	_expect(drains.is_empty(), "Completed, cancelled and interrupted jobs must leave no drain nodes")
	print("OWNED CPU ASSET PREPARATION RESULT: %s" % JSON.stringify({"errors": _errors, "presented_frames": _present_count, "orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}))
	quit(0 if _errors.is_empty() else 1)

static func _produce() -> Dictionary:
	return {"worker_task": WorkerThreadPool.get_caller_task_id(), "pixels": Surface._paper_grain_image()}

func _alive() -> bool:
	return _active

func _present() -> void:
	_present_count += 1
	if _cancel_next_frame:
		_cancel_next_frame = false
		_active = false
	if is_instance_valid(_remove_next_frame):
		_remove_next_frame.free()
		_remove_next_frame = null
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition: _errors.append(message)

func _test_owned_rig_sources() -> void:
	for path: String in ["res://assets/units/protagonist_cutout/front.json", "res://assets/units/protagonist_cutout/rear.json", "res://assets/units/scavenger_cutout/front.json"]:
		var original: RefCounted = RigData.prepare_owned_source(path)
		var prepared: Variant = await Assets.prepare_cpu_value_for(root, RigData.prepare_owned_source.bind(path), _present, _alive)
		_expect(prepared != null and prepared.error.is_empty(), "Worker must prepare actual production rig " + path)
		if prepared == null: continue
		_expect(prepared.layout == original.layout and prepared.meshes == original.meshes, "Every joint, vertex, UV, triangle and influence must match " + path)
		RigData._sources.erase(path)
		var published: RefCounted = RigData.publish_owned_source(path, prepared)
		_expect(published == prepared and RigData.load_source(path) == published, "Publication must retain the exact prepared rig source identity")
		_expect(RigData.publish_owned_source(path, original) == published, "A competing main-thread publication must keep the live rig's identity")
		_expect(RigData.source_texture_manifest(prepared, path) == RigData.source_texture_manifest(original, path), "Prepared rigs must use the original complete texture manifest")

func _test_map_images() -> void:
	var originals: Dictionary = {}
	for name: String in ["action_frame", "medallion", "panel_frame"]:
		originals[name] = MapSkin._texture(name).get_image().get_data()
	for id: String in RoomIcons.all_icon_ids():
		var texture: Texture2D = MapSkin.icon_texture(id)
		if texture != null: originals["icon_" + id] = texture.get_image().get_data()
	MapSkin._textures.clear()
	await MapSkin.prepare_initial_assets_for(root, _present, _alive)
	for key: String in originals:
		_expect(MapSkin._textures.has(key) and MapSkin._textures[key].get_image().get_data() == originals[key], "Worker map resize and mip chain must preserve every byte for " + key)
	var before: int = _present_count
	var identities: Dictionary = MapSkin._textures.duplicate()
	await MapSkin.prepare_initial_assets_for(root, _present, _alive)
	_expect(MapSkin._textures == identities and _present_count == before, "Warm map preparation must retain identities without waiting")

func _test_audio() -> void:
	for mode: String in ["room", "campfire"]:
		var path: String = str(RunSfx.ambient_entry_for_mode(mode).get("path", ""))
		var original: AudioStream = Assets.load_audio_stream(path)
		var expected: AudioStream = _reference_loop(original)
		Assets._audio_cache.erase(path)
		Assets._looping_audio_cache.erase(original)
		await Assets.prepare_audio_for(root, PackedStringArray([path]), _present, _alive, true)
		var prepared: AudioStream = Assets.load_audio_stream(path)
		var looped: AudioStream = Assets.looping_audio_copy(prepared)
		_expect(_audio_payload(prepared) == _audio_payload(original), "Worker must preserve every source audio sample and property for " + mode)
		_expect(_audio_payload(looped) == _audio_payload(expected), "Worker must preserve original loop markers and samples for " + mode)
		_expect(prepared != looped, "Loop markers must remain isolated from the source stream")
		var before: int = _present_count
		await Assets.prepare_audio_for(root, PackedStringArray([path]), _present, _alive, true)
		_expect(Assets.load_audio_stream(path) == prepared and Assets.looping_audio_copy(prepared) == looped and _present_count == before, "Warm audio must retain source and looped identities")
		Assets._audio_cache.erase(path)
		Assets._looping_audio_cache.erase(prepared)
		_cancel_next_frame = true
		await Assets.prepare_audio_for(root, PackedStringArray([path]), _present, _alive, true)
		_expect(not Assets._audio_cache.has(path), "Cancelled audio must drain without publishing its private source")
		_active = true

static func _reference_loop(resource: AudioStream) -> AudioStream:
	var looped: AudioStream = resource.duplicate() as AudioStream
	if looped is AudioStreamWAV:
		looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
		looped.loop_begin = 0
		looped.loop_end = maxi(1, int(round(looped.get_length() * float(looped.mix_rate))))
	return looped

static func _audio_payload(stream: AudioStream) -> Dictionary:
	if stream is AudioStreamWAV:
		return {"data": stream.data, "format": stream.format, "mix_rate": stream.mix_rate, "stereo": stream.stereo, "loop_mode": stream.loop_mode, "loop_begin": stream.loop_begin, "loop_end": stream.loop_end}
	return {"length": stream.get_length(), "loop": stream.get("loop")}

func _test_component_images() -> void:
	var path: String = "res://assets/art/ui/visual_pass_4/medallion_ring.png"
	var fill: PackedByteArray = Component.socket_fill().get_image().get_data()
	var ring: PackedByteArray = Component.mipmapped_texture(path).get_image().get_data()
	Component._socket_fill = null
	Component._mipmapped_textures.erase(path)
	await Component.prepare_initial_assets_for(root, _present, _alive)
	_expect(Component.socket_fill().get_image().get_data() == fill and Component.mipmapped_texture(path).get_image().get_data() == ring, "Worker socket fill and ring mipmaps must preserve every pixel")

extends "res://tests/runtime_frame_performance_benchmark.gd"

# Causal reproduction, not a gameplay performance acceptance lane. Draw one
# production shader at a time to distinguish a single native compilation from
# several first-use pipelines submitted in the same startup frame.
const Dissolve = preload("res://scripts/enemy_shadow_dissolve_effect.gd")
const Art = preload("res://scripts/combat_art_treatment.gd")
const Typography = preload("res://scripts/ui_typography.gd")
var _held: Array[Node]
var _held_sources: Array[RefCounted]
var _prepared_scene: Control

class TexturedDraw extends Control:
	var texture: Texture2D
	func _draw() -> void:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, Vector2(4, 4)), false)

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	var settings_store: Script = preload("res://scripts/settings_store.gd")
	settings_store.set_storage_path("user://runtime_performance_settings.json")
	var settings: Dictionary = settings_store.default_settings()
	settings["display_mode"] = "windowed"
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	settings_store.save_settings(settings)
	settings_store.apply_settings(settings, root)
	OS.low_processor_usage_mode = false
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920, 1080)
	_render_pulse = RenderPulse.new()
	_render_pulse.size = Vector2.ONE
	_render_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_render_pulse)
	await _acquire_probe_window_focus()
	await _settle_render_frames(4)
	_clear_probe_output(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var pixels := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(pixels)
	var sampler := FrameSampler.new()
	sampler.request_render = _render_pulse.pulse
	sampler.observe_frame = _observe_probe_focus
	root.add_child(sampler)
	if OS.get_environment("LABYRINTH_CANVAS_PIPELINE_ACTUAL_RIG") == "1":
		var assets: Script = preload("res://scripts/asset_loader.gd")
		var data: Script = preload("res://scripts/protagonist_cutout/rig_data.gd")
		var manifest: Dictionary = {}
		for path: String in ["res://assets/units/protagonist_cutout/front.json", "res://assets/units/protagonist_cutout/rear.json"]:
			var prepared: RefCounted = await assets.prepare_cpu_value_for(root, data.prepare_owned_source.bind(path), _await_render_frame, _owner_alive)
			_held_sources.append(data.publish_owned_source(path, prepared))
			manifest.merge(data.source_texture_manifest(prepared, path))
		await assets.prepare_textures_for(root, manifest, _await_render_frame, _owner_alive)
		await _settle_render_frames(4)
	if OS.get_environment("LABYRINTH_CANVAS_PIPELINE_RAW_SCENE") == "1":
		_prepared_scene = load("res://scenes/run_scene.tscn").instantiate() as Control
		_prepared_scene.call("request_staged_initial_ui")
		var assets: Script = preload("res://scripts/asset_loader.gd")
		await assets.prepare_textures_for(root, _prepared_scene.call("initial_texture_preparation_manifest"), _await_render_frame, _owner_alive)
		var board: Control = _prepared_scene.call("initial_asset_preparation_target")
		await board.get_script().call("prepare_initial_assets_for", board, _await_render_frame, true, root)
		await _prepared_scene.get_script().call("prepare_initial_cpu_assets_for", _prepared_scene, root, _await_render_frame, _owner_alive)
		await _settle_render_frames(4)
	await _acquire_probe_window_focus()
	await _settle_render_frames(4)
	var results: Array[Dictionary]
	var modes := PackedStringArray(["basic_texture", "dissolve", "stone_text", "combat_art", "floor_light", "skinned_polygon"])
	if OS.get_environment("LABYRINTH_CANVAS_PIPELINE_BATCHED") == "1": modes = PackedStringArray(["batch"])
	if OS.get_environment("LABYRINTH_CANVAS_PIPELINE_ACTUAL_RIG") == "1": modes = PackedStringArray(["actual_protagonist"])
	if OS.get_environment("LABYRINTH_CANVAS_PIPELINE_RAW_SCENE") == "1":
		modes = PackedStringArray(["raw_scene_hidden", "raw_scene_board", "raw_scene_ui", "raw_scene_all"]) if OS.get_environment("LABYRINTH_CANVAS_PIPELINE_SPLIT_SCENE") == "1" else PackedStringArray(["raw_scene"])
	for mode: String in modes:
		await _settle_render_frames(4)
		var before: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS)
		sampler.begin()
		var started: int = Time.get_ticks_usec()
		var node: CanvasItem = _make_draw(mode, texture)
		_held.append(node)
		if node.get_parent() == null: root.add_child(node)
		if mode in ["raw_scene", "raw_scene_hidden"]: node.call("_apply_style")
		var handler_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
		await _settle_render_frames(8)
		var result: Dictionary = _sampler_phase_result(sampler.finish())
		result["mode"] = mode
		result["handler_ms"] = handler_ms
		result["canvas_compilations"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS) - before
		results.append(result)
		node.hide()
	await _save_root_screenshot("canvas_pipeline_native.png")
	print("CANVAS PIPELINE DETAIL RESULT: " + JSON.stringify({"results": results, "semantic_errors": _errors, "renderer": RenderingServer.get_video_adapter_name(), "viewport": "1920x1080", "focus_observations": _focus_observation_count, "unfocused_observations": _unfocused_observation_count}))
	for node: Node in _held: node.queue_free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)

func _owner_alive() -> bool:
	return true

func _make_draw(mode: String, texture: Texture2D) -> CanvasItem:
	if mode.begins_with("raw_scene"):
		if mode != "raw_scene":
			_prepared_scene.visible = mode != "raw_scene_hidden"
			(_prepared_scene.get_node("BoardUnderlay") as CanvasLayer).visible = mode in ["raw_scene_board", "raw_scene_all"]
			(_prepared_scene.get_node("UiLayer/UiRoot") as CanvasItem).visible = mode in ["raw_scene_ui", "raw_scene_all"]
		return _prepared_scene
	if mode == "actual_protagonist":
		var holder := Node2D.new()
		var renderer: Node = preload("res://scripts/protagonist_cutout/renderer.gd").new()
		renderer.set("active", false)
		renderer.process_mode = Node.PROCESS_MODE_DISABLED
		holder.add_child(renderer)
		return holder
	if mode == "batch":
		var holder := Node2D.new()
		for kind: String in ["basic_texture", "dissolve", "stone_text", "combat_art", "floor_light", "skinned_polygon"]:
			holder.add_child(_make_draw(kind, texture))
		return holder
	if mode == "dissolve":
		var effect := Dissolve.new()
		effect.configure(texture, Rect2(Vector2(10, 10), Vector2(4, 4)), 0.46, 0.137, false)
		return effect
	if mode == "stone_text":
		var label := Label.new()
		label.text = "Way of the Labyrinth"
		label.position = Vector2(10, 10)
		Typography.apply_label_role(label, Typography.ROLE_BANNER)
		Typography.apply_stone_text(label)
		return label
	if mode == "skinned_polygon":
		var holder := Node2D.new()
		var skeleton := Skeleton2D.new()
		var bone := Bone2D.new()
		bone.set_autocalculate_length_and_angle(false)
		bone.set_length(2.0)
		bone.rest = bone.transform
		skeleton.add_child(bone)
		holder.add_child(skeleton)
		var mesh := Polygon2D.new()
		mesh.polygon = PackedVector2Array([Vector2(10, 10), Vector2(14, 10), Vector2(10, 14)])
		mesh.uv = mesh.polygon
		mesh.texture = texture
		holder.add_child(mesh)
		mesh.skeleton = mesh.get_path_to(skeleton)
		mesh.add_bone(skeleton.get_path_to(bone), PackedFloat32Array([1.0, 1.0, 1.0]))
		return holder
	var draw := TexturedDraw.new()
	draw.position = Vector2(10, 10)
	draw.size = Vector2(4, 4)
	draw.texture = texture
	if mode in ["combat_art", "floor_light"]:
		var art := Art.new()
		draw.material = art.material if mode == "combat_art" else art.floor_material
	return draw

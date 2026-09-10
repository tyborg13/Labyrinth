extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Cutout = preload("res://scripts/lightning_wisp_cutout/renderer.gd")
const ProductionRig = preload("res://scripts/lightning_wisp_cutout/rig.gd")
const CaseRig = preload("res://tools/cutout_pipeline/rig.gd")
const OUTPUT: String = "user://probes/lightning_wisp_cutout_assets"
var _errors: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var actual: SubViewport = _viewport()
	var accepted: SubViewport = _viewport()
	var compared: int = 0
	for facing: String in ["front", "rear"]:
		var production := ProductionRig.new()
		production.facing = facing
		actual.add_child(production)
		_check(production.load_rig(), "Production rig loads " + facing)
		var reference := CaseRig.new()
		accepted.add_child(reference)
		_check(reference.configure("res://experiments/cutouts/lightning_wisp/v01/cutout.json"), "Reviewed case loads")
		_check(reference.set_facing(facing), "Reviewed facing loads")
		production.position = Vector2(128, 128)
		reference.position = Vector2(128, 128)
		for mirrored: bool in [false, true]:
			production.position = Vector2(383, 128) if mirrored else Vector2(128, 128)
			reference.position = production.position
			production.scale = Vector2(-1, 1) if mirrored else Vector2.ONE
			reference.scale = production.scale
			for clip: String in ["rest", "idle", "walk", "attack", "cast"]:
				var frames: int = 1 if clip == "rest" else 24 if clip == "idle" else 32
				for index: int in range(frames):
					var phase: float = float(index) / float(frames - 1 if clip in ["attack", "cast"] else frames)
					production.apply_pose(clip, phase)
					reference.apply_pose(clip, phase)
					await _draw()
					var image: Image = actual.get_texture().get_image()
					_check(image.get_data() == accepted.get_texture().get_image().get_data(), "%s %s %d remains pixel-identical" % [facing, clip, index])
					compared += 1
					if clip in ["attack", "cast"] and index in [10, 13, 17, 21]:
						image.save_png(OUTPUT.path_join("%s_%s_%s_%02d.png" % [facing, "reflected" if mirrored else "painted", clip, index]))
					if clip == "rest" and not mirrored:
						var baked: Image = Image.load_from_file("res://assets/units/lightning_wisp_cutout/" + facing + "/rest.png")
						_check(image.get_region(Rect2i(128, 128, 255, 255)).get_data() == baked.get_data(), "Shipped rest silhouette matches the current assembly")
						_check(image.save_png(OUTPUT.path_join(facing + "_canvas.png")) == OK, "Save native rest canvas")
						_check(image.get_region(Rect2i(128, 128, 255, 255)).save_png(OUTPUT.path_join(facing + "_rest.png")) == OK, "Save logical rest silhouette")
		production.free()
		reference.free()
	var alpha_report: Dictionary = await _verify_original_alpha()
	var output := FileAccess.open(OUTPUT.path_join("comparison.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"ok": _errors.is_empty(), "native_identical_frames": compared, "original_paint_composite": alpha_report, "errors": _errors}, "\t"))
	output.close()
	actual.free()
	accepted.free()
	for error: String in _errors:
		push_error(error)
	print("Saved " + ProjectSettings.globalize_path(OUTPUT))
	print("LIGHTNING WISP ASSET PROBE: " + ("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)

func _viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport

func _draw() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)

func _verify_original_alpha() -> Dictionary:
	var renderer := Cutout.new()
	root.add_child(renderer)
	renderer.set_process(false)
	renderer.present({"direction": Vector2i(0, 1)}, true)
	var live: SubViewport = _viewport()
	var source: SubViewport = _viewport()
	for viewport: SubViewport in [live, source]:
		var background := ColorRect.new()
		background.size = Vector2(512, 512)
		background.color = Color(.10, .08, .06, 1.0)
		viewport.add_child(background)
	var actual := Sprite2D.new()
	actual.centered = false
	actual.texture = renderer.texture()
	live.add_child(actual)
	var expected := Sprite2D.new()
	expected.centered = false
	expected.position = Vector2(128, 128)
	expected.texture = preload("res://scripts/asset_loader.gd").load_texture_source_first("res://assets/placeholders/units/lightning_wisp.png")
	source.add_child(expected)
	await _draw()
	await _draw()
	var a: Image = live.get_texture().get_image()
	var b: Image = source.get_texture().get_image()
	var maximum: int = 0
	var changed: int = 0
	var actual_bytes: PackedByteArray = a.get_data()
	var expected_bytes: PackedByteArray = b.get_data()
	for index: int in range(actual_bytes.size()):
		var difference: int = absi(int(actual_bytes[index]) - int(expected_bytes[index]))
		maximum = maxi(maximum, difference)
		if difference > 0:
			changed += 1
	_check(maximum <= 2, "Gameplay composite preserves accepted translucent front paint (at most two 8-bit quantization levels)")
	a.save_png(OUTPUT.path_join("front_gameplay_alpha.png"))
	b.save_png(OUTPUT.path_join("front_accepted_alpha.png"))
	renderer.free()
	live.free()
	source.free()
	return {"maximum_channel_error": maximum, "different_channels": changed, "threshold": 2, "background": "opaque dark brown", "source": "assets/placeholders/units/lightning_wisp.png"}

extends SceneTree

const ProductionRig = preload("res://scripts/vaeloryx_cutout/rig.gd")
const CaseRig = preload("res://tools/cutout_pipeline/rig.gd")
const OUTPUT: String = "user://probes/vaeloryx_cutout_assets"
var _errors: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var actual: SubViewport = _viewport()
	var accepted: SubViewport = _viewport()
	var records: Array[Dictionary]
	for facing: String in ["front", "rear"]:
		var production := ProductionRig.new()
		production.facing = facing
		actual.add_child(production)
		_check(production.load_rig(), "Production rig loads " + facing)
		var reference := CaseRig.new()
		accepted.add_child(reference)
		_check(reference.configure("res://experiments/cutouts/vaeloryx/v01/cutout.json"), "Case loads")
		_check(reference.set_facing(facing), "Facing loads")
		for mirrored: bool in [false, true]:
			production.position = Vector2(383, 128) if mirrored else Vector2(128, 128)
			reference.position = production.position
			production.scale = Vector2(-1, 1) if mirrored else Vector2.ONE
			reference.scale = production.scale
			for clip: String in ["rest", "idle", "walk", "dive", "gale", "pull", "guard"]:
				var frames: int = 1 if clip == "rest" else 24 if clip in ["idle", "guard"] else 36
				for index: int in range(frames):
					var phase: float = float(index) / float(frames if clip in ["idle", "walk"] else maxi(1, frames - 1))
					production.apply_pose(clip, phase)
					reference.apply_pose(clip, phase)
					await _draw()
					var painted: Image = actual.get_texture().get_image()
					var label: String = "%s_%s_%s_%02d" % [facing, "mirror" if mirrored else "direct", clip, index]
					_check(painted.get_data() == accepted.get_texture().get_image().get_data(), label + " native production/case equality")
					var bounds: Rect2i = painted.get_used_rect()
					_check(bounds.position.x >= 3 and bounds.position.y >= 3 and bounds.end.x <= 509 and bounds.end.y <= 509, label + " fixed canvas bounds")
					painted.save_png(OUTPUT.path_join(label + ".png"))
					records.append({"label": label, "facing": facing, "mirrored": mirrored, "clip": clip, "phase": phase, "bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y]})
					if clip == "rest" and not mirrored:
						var baked: Image = Image.load_from_file("res://assets/units/vaeloryx_cutout/" + facing + "/rest.png")
						var logical: Image = painted.get_region(Rect2i(128, 128, 255, 255))
						_check(logical.get_data() == baked.get_data(), facing + " shipped rest equals current assembly")
						logical.save_png(OUTPUT.path_join(facing + "_rest.png"))
		production.free()
		reference.free()
	var output := FileAccess.open(OUTPUT.path_join("comparison.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"ok": _errors.is_empty(), "native_identical_frames": records.size(), "records": records, "errors": _errors}, "\t"))
	output.close()
	actual.free()
	accepted.free()
	for error: String in _errors:
		push_error(error)
	print("Saved " + ProjectSettings.globalize_path(OUTPUT))
	print("VAELORYX ASSET PROBE: " + ("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)

func _viewport() -> SubViewport:
	var canvas := SubViewport.new()
	canvas.size = Vector2i(512, 512)
	canvas.transparent_bg = true
	canvas.disable_3d = true
	canvas.world_2d = World2D.new()
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	return canvas

func _draw() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)

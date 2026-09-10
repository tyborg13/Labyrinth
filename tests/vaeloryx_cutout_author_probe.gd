extends SceneTree

## Native anatomy iteration, before full case/runtime proof. Does not resolve
## actions or substitute synthetic poses for production gameplay evidence.
const CaseRig = preload("res://tools/cutout_pipeline/rig.gd")
const OUTPUT: String = "user://probes/vaeloryx_cutout_author"
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var canvas := SubViewport.new()
	canvas.size = Vector2i(512, 512)
	canvas.transparent_bg = true
	canvas.disable_3d = true
	canvas.world_2d = World2D.new()
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var rig := CaseRig.new()
	canvas.add_child(rig)
	_check(rig.configure("res://experiments/cutouts/vaeloryx/v01/cutout.json"), "Case loads")
	rig.position = Vector2(128, 128)
	var records: Array[Dictionary] = _records()
	for facing: String in ["front", "rear"]:
		_check(rig.set_facing(facing), "Facing loads")
		for clip: String in ["rest", "idle", "walk", "dive", "gale", "pull", "guard"]:
			var phases: Array[float] = _phases(clip)
			for index: int in range(phases.size()):
				rig.apply_pose(clip, phases[index])
				await _draw()
				var painted: Image = canvas.get_texture().get_image()
				var bounds: Rect2i = painted.get_used_rect()
				_check(bounds.position.x >= 3 and bounds.position.y >= 3 and bounds.end.x <= 509 and bounds.end.y <= 509, "Padded bounds")
				var name: String = "%s_%s_%02d.png" % [facing, clip, index]
				_check(painted.save_png(OUTPUT.path_join(name)) == OK, "Save native pose")
				records.append({"facing": facing, "clip": clip, "phase": phases[index], "image": name,
					"bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y]})
				if clip == "rest":
					painted.get_region(Rect2i(128, 128, 255, 255)).save_png(OUTPUT.path_join(facing + "_rest.png"))
		var saved_path: String = OUTPUT.path_join(facing + ".tscn")
		_check(rig.save_editable(saved_path) == OK, "Save editable preliminary scene")
	var file := FileAccess.open(OUTPUT.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": failures.is_empty(), "records": records, "failures": failures}, "\t"))
	file.close()
	print("Saved " + ProjectSettings.globalize_path(OUTPUT))
	print("VAELORYX AUTHOR PROBE: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _phases(clip: String) -> Array[float]:
	var values: Array[float]
	if clip == "rest":
		values.append(0.0)
	elif clip == "idle" or clip == "walk":
		values.assign([0.0, 0.25, 0.5, 0.75])
	else:
		values.assign([0.0, 0.28, 0.42, 0.72, 1.0])
	return values

func _records() -> Array[Dictionary]:
	var values: Array[Dictionary]
	return values

func _draw() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

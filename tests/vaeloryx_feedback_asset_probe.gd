extends SceneTree

## Current feedback-case/production comparison, including fractional root
## translations and mirrored views. The legacy v01 probe remains historical.
const ProductionRig = preload("res://scripts/vaeloryx_cutout/rig.gd")
const CaseRig = preload("res://tools/cutout_pipeline/rig.gd")
const Silhouette = preload("res://tests/helpers/silhouette_match.gd")
const OUTPUT: String = "user://probes/vaeloryx_feedback_assets"
var _errors: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var actual: SubViewport = _viewport()
	var expected: SubViewport = _viewport()
	var records: Array[Dictionary]
	var rest_matches: Dictionary = {}
	var prepare_bake: bool = OS.get_environment("LABYRINTH_VAEL_PREPARE_REST_BAKE") == "1"
	for facing: String in ["front", "rear"]:
		var production := ProductionRig.new()
		production.facing = facing
		actual.add_child(production)
		_check(production.load_rig(), "Production loads " + facing)
		var reference := CaseRig.new()
		expected.add_child(reference)
		_check(reference.configure("res://experiments/cutouts/vaeloryx/feedback_v02/cutout.json"), "Current feedback case loads")
		_check(reference.set_facing(facing), "Case facing loads")
		for mirrored: bool in [false, true]:
			production.position = Vector2(383, 128) if mirrored else Vector2(128, 128)
			reference.position = production.position
			production.scale = Vector2(-1, 1) if mirrored else Vector2.ONE
			reference.scale = production.scale
			for clip: String in ["rest", "idle", "walk", "dive", "gale", "pull", "guard"]:
				var phases := PackedFloat32Array([0.0]) if clip == "rest" else PackedFloat32Array([0.0, 0.25, 0.42, 11.0/24.0, 0.5, 0.556493506493506, 0.75, 1.0])
				for index: int in range(phases.size()):
					var phase: float = phases[index]
					production.apply_pose(clip, phase)
					reference.apply_pose(clip, phase)
					await process_frame
					await process_frame
					await RenderingServer.frame_post_draw
					var painted: Image = actual.get_texture().get_image()
					var label: String = "%s_%s_%s_%02d" % [facing, "mirror" if mirrored else "direct", clip, index]
					_check(Silhouette.same_silhouette(painted, expected.get_texture().get_image()), label + " production keeps the case silhouette (paint is density-treated)")
					var bounds: Rect2i = painted.get_used_rect()
					_check(bounds.position.x >= 3 and bounds.position.y >= 3 and bounds.end.x <= 509 and bounds.end.y <= 509, label + " canvas bounds")
					painted.save_png(OUTPUT.path_join(label + ".png"))
					records.append({"label": label, "phase": phase, "bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y]})
					if clip == "rest" and not mirrored:
						var native_rest: Image = painted.get_region(Rect2i(128, 128, 255, 255))
						native_rest.save_png(OUTPUT.path_join(facing + "_rest.png"))
						var shipped: Image = Image.load_from_file("res://assets/units/vaeloryx_cutout/" + facing + "/rest.png")
						rest_matches[facing] = native_rest.get_data() == shipped.get_data()
						if not prepare_bake:
							_check(rest_matches[facing], facing + " shipped rest equals current native assembly")
		production.free()
		reference.free()
	var report := FileAccess.open(OUTPUT.path_join("comparison.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"ok": _errors.is_empty(), "native_identical_frames": records.size(), "records": records, "rest_bake_preparation": prepare_bake, "rest_matches_shipped": rest_matches, "errors": _errors}, "\t"))
	report.close()
	actual.free()
	expected.free()
	for error: String in _errors:
		push_error(error)
	print("Saved " + ProjectSettings.globalize_path(OUTPUT))
	print("VAELORYX FEEDBACK ASSET PROBE: " + ("PASS" if _errors.is_empty() else "FAIL"))
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

func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)

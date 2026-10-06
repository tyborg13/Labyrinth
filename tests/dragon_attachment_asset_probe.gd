extends SceneTree

## Bind the accepted attachment cases to the shipped rigs at native pixels.
## Fractional phases include the former Breath/Walk seams; mirrors also exercise
## the production transform path without changing the authored articulation.
const CaseRig = preload("res://tools/cutout_pipeline/rig.gd")
const Silhouette = preload("res://tests/helpers/silhouette_match.gd")
const PROFILES = [
	{"id": "vyraketh", "rig": preload("res://scripts/vyraketh_cutout/rig.gd"), "clips": ["idle", "walk", "maw", "kindle", "crownfire", "cinderfall"]},
	{"id": "tharokh", "rig": preload("res://scripts/tharokh_cutout/rig.gd"), "clips": ["idle", "walk", "claw", "brace", "breath", "faultline"]},
]
const OUTPUT: String = "user://probes/dragon_attachment_assets"
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
	for profile: Dictionary in PROFILES:
		var character: String = str(profile["id"])
		for facing: String in ["front", "rear"]:
			var production: Node2D = profile["rig"].new()
			production.set("facing", facing)
			actual.add_child(production)
			_check(bool(production.call("load_rig")), "Production loads " + character + "/" + facing)
			var reference := CaseRig.new()
			expected.add_child(reference)
			_check(reference.configure("res://experiments/cutouts/" + character + "/feedback_seams_v03/cutout.json"), "Accepted attachment case loads " + character)
			_check(reference.set_facing(facing), "Case facing loads " + facing)
			var clips: Array[String]
			clips.append("rest")
			clips.append_array(profile["clips"])
			for mirrored: bool in [false, true]:
				production.position = Vector2(383, 128) if mirrored else Vector2(128, 128)
				reference.position = production.position
				production.scale = Vector2(-1, 1) if mirrored else Vector2.ONE
				reference.scale = production.scale
				for clip: String in clips:
					var phases := PackedFloat32Array([0.0]) if clip == "rest" else PackedFloat32Array([0.0, 0.25, 0.42, 0.5, 0.558704061895551, 0.725, 0.75, 1.0])
					for index: int in range(phases.size()):
						var phase: float = phases[index]
						production.call("apply_pose", clip, phase)
						reference.apply_pose(clip, phase)
						await process_frame
						await process_frame
						await RenderingServer.frame_post_draw
						var painted: Image = actual.get_texture().get_image()
						var label: String = "%s_%s_%s_%s_%02d" % [character, facing, "mirror" if mirrored else "direct", clip, index]
						_check(Silhouette.same_silhouette(painted, expected.get_texture().get_image()), label + " production keeps the case silhouette (paint is density-treated)")
						var bounds: Rect2i = painted.get_used_rect()
						_check(bounds.position.x >= 3 and bounds.position.y >= 3 and bounds.end.x <= 509 and bounds.end.y <= 509, label + " canvas bounds")
						painted.save_png(OUTPUT.path_join(label + ".png"))
						records.append({"label": label, "phase": phase, "bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y]})
						if clip == "rest" and not mirrored:
							var native_rest: Image = painted.get_region(Rect2i(128, 128, 255, 255))
							native_rest.save_png(OUTPUT.path_join(character + "_" + facing + "_rest.png"))
							var shipped: Image = Image.load_from_file("res://assets/units/" + character + "_cutout/" + facing + "/rest.png")
							var key: String = character + "/" + facing
							rest_matches[key] = native_rest.get_data() == shipped.get_data()
							_check(rest_matches[key], key + " shipped rest equals current native assembly")
			production.free()
			reference.free()
	_check(records.size() == 392, "Both rigs cover both facings, mirrors, rest and all six clips")
	var report := FileAccess.open(OUTPUT.path_join("comparison.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"ok": _errors.is_empty(), "native_identical_frames": records.size(), "records": records, "rest_matches_shipped": rest_matches, "errors": _errors}, "\t"))
	report.close()
	actual.free()
	expected.free()
	for error: String in _errors:
		push_error(error)
	print("Saved " + ProjectSettings.globalize_path(OUTPUT))
	print("DRAGON ATTACHMENT ASSET PROBE: " + ("PASS" if _errors.is_empty() else "FAIL"))
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

extends SceneTree

## Bone oracle samples and sequential presented transforms, including texture
## identities. This program makes no native-pixel claim.
const Rig = preload("res://scripts/maquette_cutout_runtime/rig.gd")
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const Pixels = preload("res://tests/maquette_cutout/pixel_samples.gd")
const CASE: String = "res://experiments/cutouts/storm_capacitor/mq5"
const FPS: float = 60.0
var rows: Array[Dictionary]
var authored: Array[Dictionary]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var data: Dictionary = Motion.data_for({"motion_data": CASE.path_join("compiled_motion.json")})
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CASE.path_join("director_motion.json")))
	for view: String in ["front", "rear"]:
		var rig := Rig.new()
		rig.case_directory = CASE
		rig.facing = view
		root.add_child(rig)
		if not rig.load_rig():
			push_error(str(rig.load_errors))
			quit(1)
			return
		for clip: String in data["clips"]:
			var phases: Array[float]
			phases.assign([0.0, 1.0])
			var definition: Dictionary = source["storm_capacitor"]["clips"][clip]
			if definition.has("contact"): phases.append(float(definition["contact"]))
			for track: Array in definition["keys"].values():
				for index: int in range(track.size()):
					phases.append(float(track[index][0]))
					if index > 0: phases.append((float(track[index][0]) + float(track[index - 1][0])) / 2.0)
			phases.sort()
			for phase: float in phases:
				rig.apply_authored_pose(clip, phase)
				authored.append({"view": view, "clip": clip, "phase": phase, "bones": bones_for(rig), "glow_sha256": glow_digest(rig)})
			var count: int = roundi(float(definition["seconds"]) * FPS)
			for frame: int in range(count):
				var phase: float = float(frame) / float(count if bool(definition.get("loop", false)) else count - 1)
				rig.apply_pose(clip, phase)
				rows.append({"view": view, "clip": clip, "frame": frame, "phase": phase,
					"presented_phase": rig.Pixels.phase_for(data, clip, phase),
					"bones": bones_for(rig), "parts": Pixels.parts_for(rig), "glow_sha256": glow_digest(rig)})
		rig.free()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output: String = args[args.find("--output") + 1] if args.has("--output") else CASE.path_join("proof/samples.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": true, "native_pixels": false, "fps": FPS,
		"inputs": preload("res://tests/maquette_cutout/proof_inputs.gd").bindings(CASE), "authored": authored, "samples": rows}))
	print("RR17 SAMPLES: PASS (%d authored bone poses; %d sequential poses; headless transforms only)" % [authored.size(), rows.size()])
	quit()

static func bones_for(rig: Node2D) -> Dictionary:
	var result: Dictionary = {}
	for name: String in rig.bones:
		var bone: Bone2D = rig.bones[name]
		result[name] = {"local": Pixels.values(bone.transform), "global": Pixels.values(rig.global_transform.affine_inverse() * bone.global_transform)}
	return result

static func glow_digest(rig: Node2D) -> String:
	var texture: Texture2D = rig.bones["column"].get_node("column").texture
	var image: Image = texture.get_image()
	image.convert(Image.FORMAT_RGBA8)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	return hash.finish().hex_encode()

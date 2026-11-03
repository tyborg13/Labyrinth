extends SceneTree

const Rig = preload("res://assets/units/storm_cantor_cutout/rig.gd")
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const CASE: String = "res://experiments/cutouts/storm_cantor/mq26"
const WITNESS_VIEW: String = "rear"
const WITNESS_CLIP: String = "move"
const WITNESS_FRAME: int = 26
const SEARCH_DENOMINATOR: int = 60
const MINIMUM_NUMERATOR: int = 36

func values(t: Transform2D) -> Array:
	return [t.x.x, t.x.y, t.y.x, t.y.y, t.origin.x, t.origin.y]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var geometry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CASE.path_join("proof/samples.json")))
	var data: Dictionary = Motion.data_for({"motion_data": CASE.path_join("compiled_motion.json")})
	var original: Array = data["view_tracks"][WITNESS_VIEW][WITNESS_CLIP].duplicate(true)
	var rig: Node2D = Rig.new()
	rig.case_directory = CASE
	rig.facing = WITNESS_VIEW
	rig.position = Vector2(192, 192)
	root.add_child(rig)
	assert(rig.load_rig(), str(rig.load_errors))
	rig.layout["screen_pixel_scale"] = geometry["screen_pixel_scale"]
	rig.layout["step_distance_px"] = geometry["step_distance_px"]
	var count: int = roundi(float(data["clips"][WITNESS_CLIP]["seconds"]) * 60.0)
	var phase: float = float(WITNESS_FRAME) / float(count - 1)
	var rows: Array[Dictionary]
	for numerator: int in range(SEARCH_DENOMINATOR, MINIMUM_NUMERATOR - 1, -1):
		var ratio: float = float(numerator) / SEARCH_DENOMINATOR
		var tracks: Array = original.duplicate(true)
		for track: Dictionary in tracks:
			if track["bone"] not in ["cloak_mid", "cloak_tip", "tabard_mid", "tabard_tip"]: continue
			for key: Dictionary in track["keys"]: key["value"] = float(key["value"]) * ratio
		data["view_tracks"][WITNESS_VIEW][WITNESS_CLIP] = tracks
		rig.apply_pose(WITNESS_CLIP, phase)
		var bones: Dictionary = {}
		var parts: Dictionary = {}
		var inverse: Transform2D = rig.global_transform.affine_inverse()
		for name: String in rig.bones:
			var bone: Bone2D = rig.bones[name]
			bones[name] = {"global": values(inverse * bone.global_transform), "local": values(bone.transform)}
		for part: Dictionary in rig.layout["parts"]:
			var node: Node2D = rig.get_node_or_null(NodePath(part["name"])) as Node2D
			if node == null: node = rig.bones[part["bone"]].get_node(NodePath(part["name"])) as Node2D
			parts[part["name"]] = {"transform": values(inverse * node.global_transform), "z_index": node.z_index}
		rows.append({"view": WITNESS_VIEW, "clip": WITNESS_CLIP, "frame": WITNESS_FRAME, "phase": phase,
			"kind": "presented", "bones": bones, "parts": parts, "budget_ratio": ratio})
	data["view_tracks"][WITNESS_VIEW][WITNESS_CLIP] = original
	rig.free()
	FileAccess.open(CASE.path_join("proof/budget_samples.json"), FileAccess.WRITE).store_string(JSON.stringify({
		"samples": rows, "native_pixels": false, "budget_probe": true,
		"inputs": preload("res://tests/rr10/bindings.gd").for_case(CASE),
		"compiled_sha256": FileAccess.get_sha256(CASE.path_join("compiled_motion.json"))}))
	print("RR56 CLOTH BUDGET POSES: PASS (%d candidates; 60-100%%; director motion unchanged)" % rows.size())
	quit()

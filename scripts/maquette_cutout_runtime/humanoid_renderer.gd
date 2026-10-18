extends "renderer.gd"

## Candidate/authoring adapter. Production may select this only when the owner
## promotes both approved views. Uses the existing board/portrait playback API.
var humanoid_case: String = ""

func _rig_views() -> Array[String]:
	var result: Array[String]
	result.assign(motion_data()["view_tracks"].keys())
	return result

func _new_rig() -> Node2D:
	var rig: Node2D = super._new_rig()
	rig.case_directory = humanoid_case
	return rig

func motion_data() -> Dictionary:
	return Motion.data_for({"motion_data": humanoid_case.path_join("compiled_motion.json")})

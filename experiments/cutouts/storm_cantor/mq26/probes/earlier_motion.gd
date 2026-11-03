extends SceneTree
const Current = preload("res://scripts/maquette_cutout_runtime/humanoid_motion.gd")
const Before = preload("res://experiments/cutouts/storm_cantor/mq26/baseline/humanoid_motion_before.gd")
const Presentation = preload("res://scripts/maquette_cutout_runtime/presentation.gd")
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const PROOF_STEP_DISTANCE: float = 96.0
const PROOF_PIXEL_SCALE: float = 2.0
var errors: Array[String]
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var checks: int = 0
	var rigs: int = 0
	for type: String in Presentation.CREATURES:
		if type=="storm_cantor":continue
		var data: Dictionary = Action.data_for(type)
		if data.get("rig", "")!="humanoid_v2":continue
		rigs+=1
		for view: String in data["view_tracks"]:
			var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Presentation.asset_directory(type).path_join(view+".json")))
			layout["step_distance_px"]=PROOF_STEP_DISTANCE
			layout["screen_pixel_scale"]=PROOF_PIXEL_SCALE
			for clip: String in data["clips"]:
				var count: int = roundi(float(data["clips"][clip]["seconds"])*60)
				for frame: int in range(count):
					var phase: float = float(frame)/maxi(1,count-1)
					var a: Dictionary = Before.world_transforms(data,clip,phase,layout,view)
					var b: Dictionary = Current.world_transforms(data,clip,phase,layout,view)
					checks+=1
					if a!=b:errors.append("Earlier exact transforms changed: %s/%s/%s/%d"%[type,view,clip,frame])
	for error: String in errors.slice(0,10):push_error(error)
	print("RR56 EARLIER MOTION: %s (%d rigs; %d frames; exact transform equality)"%["PASS" if errors.is_empty() else "FAIL",rigs,checks])
	quit(0 if errors.is_empty() else 1)

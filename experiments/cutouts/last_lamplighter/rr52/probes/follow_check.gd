extends SceneTree

const Motion = preload("res://assets/units/last_lamplighter_cutout/held_contract.gd")
const Tracks = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const CASE: String = "res://experiments/cutouts/last_lamplighter/rr52"
const ROOT_TRAVEL_MUTATION: float = 3.0
const ANGLE_TOLERANCE: float = 0.00001

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CASE.path_join("compiled_motion.json")))
	var moved: Dictionary = data.duplicate(true)
	var legacy: Dictionary = data.duplicate(true)
	legacy["clips"]["move"]["held_follow"]["reference_frame"] = "world"
	for view: String in moved["view_tracks"]:
		for track: Dictionary in moved["view_tracks"][view]["move"]:
			if track["bone"]=="root" and track["channel"]=="forward_px":
				for key: Dictionary in track["keys"]:key["value"]+=ROOT_TRAVEL_MUTATION
	var checks: int = 0
	var errors: Array[String]
	var raw_mutation_detected: bool = false
	for view: String in data["view_tracks"]:
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CASE.path_join("layouts/"+view+".json")))
		layout["step_distance_px"]=96.0;layout["screen_pixel_scale"]=2.0
		for frame: int in range(101):
			var phase: float = float(frame)/100.0
			var before: Dictionary = Motion.world_transforms(data,"move",phase,layout,view)
			var after: Dictionary = Motion.world_transforms(moved,"move",phase,layout,view)
			var raw: Dictionary = Motion.world_transforms(legacy,"move",phase,layout,view)
			var angle: float = (before["lantern"] as Transform2D).get_rotation()
			if absf(angle-(after["lantern"] as Transform2D).get_rotation())>ANGLE_TOLERANCE:errors.append(view+" root travel tilted item")
			if absf(angle)>deg_to_rad(25.0)+ANGLE_TOLERANCE:errors.append(view+" exceeded 25 degrees")
			if frame==100 and absf(angle)>ANGLE_TOLERANCE:errors.append(view+" end is not zero")
			if absf(angle-(raw["lantern"] as Transform2D).get_rotation())>ANGLE_TOLERANCE:raw_mutation_detected=true
			checks+=1
	if not raw_mutation_detected:errors.append("source-space reference mutation escaped")
	for error: String in errors:printerr(error)
	print("RR52 ROOT-RELATIVE FOLLOW: %s (%d phases; root-travel mutation rejected; both endpoints zero)"%["PASS" if errors.is_empty() else "FAIL",checks])
	quit(0 if errors.is_empty() else 1)

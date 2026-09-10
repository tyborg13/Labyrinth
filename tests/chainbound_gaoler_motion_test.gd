extends SceneTree

const Motion = preload("res://experiments/cutouts/chainbound_gaoler/v01/motion.gd")
var _errors: Array[String]

func _initialize() -> void:
	for facing: String in ["front","rear"]:
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://experiments/cutouts/chainbound_gaoler/v01/layouts/"+facing+"_skinned.json"))
		var rest: Dictionary = Motion.sample_pose("rest",0.0,layout,facing)
		var max_bob: float = 0.0
		for index: int in range(61):
			var phase: float = float(index)/60.0
			var idle: Dictionary = Motion.sample_pose("idle",phase,layout,facing)
			var bob: Vector2 = Motion._world(idle,layout,"torso").origin-Motion._world(rest,layout,"torso").origin
			max_bob=maxf(max_bob,-bob.y)
			for name: String in layout["joints"]:
				var actual: Transform2D = Motion._world(idle,layout,name)
				var neutral: Transform2D = Motion._world(rest,layout,name)
				_check(actual.x.is_equal_approx(neutral.x) and actual.y.is_equal_approx(neutral.y),"Idle basis remains fixed: "+facing+"/"+name)
				var fixed: bool = name=="root" or name.begins_with("thigh_") or name.begins_with("shin_") or name.begins_with("foot_")
				_check((actual.origin-neutral.origin-(Vector2.ZERO if fixed else bob)).length()<0.0001,"Coordinated bob and fixed support: "+facing+"/"+name)
			for clip: String in ["walk","chain_reel","manacle_pin","strike"]:
				var pose: Dictionary = Motion.sample_pose(clip,phase,layout,facing)
				for name: String in ["head","hand_hook","hand_fist","hook","foot_hook","foot_fist"]:
					var world: Transform2D = Motion._world(pose,layout,name)
					_check(absf(world.x.length()-1.0)<0.0001 and absf(world.y.length()-1.0)<0.0001 and absf(world.x.dot(world.y))<0.0001,"Terminal drawing remains rigid: "+facing+"/"+clip+"/"+name)
				for side: String in ["hook","fist"]:
					var foot: String = "foot_"+side
					var target: Vector2 = Motion._point(layout,foot)
					if clip=="walk":target=Motion.walk_foot_state(phase,foot,layout,facing)["target"]
					_check(Motion._world(pose,layout,foot).origin.distance_to(target)<0.001,"Grounded action/contact target: "+facing+"/"+clip+"/"+foot)
		_check(absf(max_bob-1.2)<0.001,"Exact accepted idle amplitude "+facing)
	for error: String in _errors:push_error(error)
	print("GAOLER MOTION TEST: "+("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)

func _check(value: bool, message: String) -> void:
	if not value and not _errors.has(message):_errors.append(message)

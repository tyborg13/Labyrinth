extends SceneTree

const Motion = preload("res://experiments/cutouts/frostglass_lancer/v01/motion.gd")
const CASE: String = "res://experiments/cutouts/frostglass_lancer/v01/"
var _failures: Array[String]
var _checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CASE+"cutout.json"))
	var max_stretch: float = 1.0
	for facing: String in ["front","rear"]:
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CASE+str(config["layouts"][facing])))
		var rest: Dictionary = Motion.sample_pose("rest",0.0,layout,facing)
		var direction: Vector2 = Motion.walk_cycle_info(layout,facing)["direction"]
		var travel: Vector2 = Motion.walk_cycle_info(layout,facing)["travel_per_cycle"]
		_check(travel.length() > 80.0,"Stride has meaningful displacement")
		for index: int in range(121):
			var phase: float = float(index)/120.0
			var idle: Dictionary = Motion.sample_pose("idle",phase,layout,facing)
			for bone: String in layout["joints"]:
				var neutral: Transform2D = Motion.world(rest,layout,bone)
				var actual: Transform2D = Motion.world(idle,layout,bone)
				_check(actual.x.distance_to(neutral.x)<0.0001 and actual.y.distance_to(neutral.y)<0.0001,"Idle does not ripple or rotate armor")
				if bone.begins_with("thigh_") or bone.begins_with("shin_") or bone.begins_with("foot_"):
					_check(actual.origin.distance_to(neutral.origin)<0.0001,"Idle legs and boots remain fixed")
				elif bone != "root":
					var torso_bob: Vector2 = Motion.world(idle,layout,"pelvis").origin-Motion.world(rest,layout,"pelvis").origin
					_check((actual.origin-neutral.origin).distance_to(torso_bob)<0.0001,"Upper body shares one coordinated bob")
			for clip: String in ["walk","thrust","cast","pin"]:
				var pose: Dictionary = Motion.sample_pose(clip,phase,layout,facing)
				for rigid: String in ["head","hand_r","hand_l","lance","foot_r","foot_l"]:
					var transform: Transform2D = Motion.world(pose,layout,rigid)
					_check(absf(transform.x.length()-1)<0.001 and absf(transform.y.length()-1)<0.001 and absf(transform.x.dot(transform.y))<0.001,"Terminal paint remains rigid: "+rigid)
				for side: String in ["r","l"]:
					var foot: Transform2D = Motion.world(pose,layout,"foot_"+side)
					if clip != "walk":
						_check(foot.origin.distance_to(Motion.point(layout,"foot_"+side))<0.001,"Attack feet stay grounded")
					for bone: String in ["upper_"+side,"fore_"+side,"thigh_"+side,"shin_"+side]:
						var child: String = "fore_"+side if bone.begins_with("upper_") else "hand_"+side if bone.begins_with("fore_") else "shin_"+side if bone.begins_with("thigh_") else "foot_"+side
						var axis: Vector2 = (Motion.point(layout,child)-Motion.point(layout,bone)).normalized()
						var world: Transform2D = Motion.world(pose,layout,bone)
						var width: Vector2 = world.basis_xform(axis.orthogonal())
						_check(absf(width.length()-1.0)<0.001,"Projected articulation preserves painted limb width")
						if bone.begins_with("upper_") or bone.begins_with("fore_"):
							max_stretch = maxf(max_stretch,world.basis_xform(axis).length())
				var hand: Transform2D = Motion.world(pose,layout,"hand_r")
				var lance: Transform2D = Motion.world(pose,layout,"lance")
				_check(lance.origin.distance_to(hand*(Motion.point(layout,"lance")-Motion.point(layout,"hand_r")))<0.001,"Lance grip stays in the hand")
		for clip: String in ["thrust","cast","pin"]:
			var release: Dictionary = Motion.sample_pose(clip,0.50,layout,facing)
			var lance: Transform2D = Motion.world(release,layout,"lance")
			var tip: Vector2 = lance*(Motion.landmark(layout,"weapon_tip")-Motion.point(layout,"lance"))
			_check((tip-lance.origin).normalized().dot(direction)>0.99,"Lance release aims down the resolved isometric lane: "+clip)
		for side: String in ["r","l"]:
			var previous: Dictionary = {}
			for index: int in range(240):
				var phase: float = float(index)/240.0
				var foot: Dictionary = Motion.walk_foot_state(phase,"foot_"+side,layout,facing)
				var world_contact: Vector2 = Vector2(foot["ground_contact"])+travel*phase
				if not previous.is_empty() and bool(foot["contact"]) and bool(previous["contact"]) and float(foot["cycle_phase"])>float(previous["cycle_phase"]):
					_check(world_contact.distance_to(previous["world_contact"])<0.001,"Walking contact cancels actual root travel")
				previous = {"contact":foot["contact"],"cycle_phase":foot["cycle_phase"],"world_contact":world_contact}
	_check(max_stretch < 1.25,"Arms stay within the allowed modest projected reach")
	print("FROSTGLASS MOTION: checks=%d max_arm_projection=%.5f failures=%d" % [_checks,max_stretch,_failures.size()])
	for failure: String in _failures:
		push_error(failure)
	print("FROSTGLASS MOTION TEST: "+("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition and not _failures.has(label):
		_failures.append(label)

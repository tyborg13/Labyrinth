extends RefCounted

const FPS: float = 60.0
const EPSILON: float = 0.0001
const GROUPS := {
	"upper_body": ["torso","head","upper_near","fore_near","hand_near"],
	"still_staff_arm": ["upper_far","fore_far","hand_far","staff"],
	"still_lower_body": ["root","pelvis","hem_near","hem_far","foot_near","foot_far"]}

static func run(renderer: Node, expect: Callable) -> void:
	var count: int = roundi(float(renderer.motion_data()["clips"]["idle"]["seconds"])*FPS)
	for view: String in renderer.rigs:
		var rig: Node2D = renderer.rigs[view]
		var source: Transform2D = rig.global_transform.affine_inverse()
		for frame: int in range(count):
			rig.apply_pose("idle",float(frame)/count)
			for group: String in GROUPS:
				var first: Vector2
				var seen: bool = false
				for name: String in GROUPS[group]:
					var pose: Transform2D = source * rig.bones[name].global_transform
					var bind: Array = rig.layout["joints"][name]["position"]
					var delta: Vector2 = pose.origin-Vector2(bind[0],bind[1])
					expect.call(pose.x.distance_to(Vector2.RIGHT)<EPSILON and pose.y.distance_to(Vector2.DOWN)<EPSILON,view+": idle basis is rigid")
					expect.call(delta.distance_to(delta.round())<EPSILON,view+": idle offset is whole pixels")
					if seen: expect.call(delta.distance_to(first)<EPSILON,view+": group moves as one cutout")
					else:
						first=delta
						seen=true
					if group!="upper_body": expect.call(delta.length()<EPSILON,view+": staff arm and lower body are byte-still")

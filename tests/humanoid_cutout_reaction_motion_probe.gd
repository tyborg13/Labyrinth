extends SceneTree
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok and not failures.has(message): failures.append(message)
func point(layout: Dictionary, name: String) -> Vector2:
	if name.is_empty(): return Vector2.ZERO
	var v: Array = layout.joints[name].position
	return Vector2(v[0],v[1])
func world(pose: Dictionary, layout: Dictionary, name: String) -> Transform2D:
	if name.is_empty(): return Transform2D.IDENTITY
	var d: Dictionary = layout.joints[name]
	var parent: String = "" if d.parent == null else str(d.parent)
	var p: Dictionary = pose.get(name,{})
	return world(pose,layout,parent)*Transform2D(float(p.get("rotation",0)),p.get("scale",Vector2.ONE),float(p.get("skew",0)),p.get("position",point(layout,name)-point(layout,parent)))
func _initialize() -> void:
	var actors: Array[String] = ["protagonist", "acolyte", "veilbound_acolyte", "grave_surgeon", "chainbound_gaoler", "frostglass_lancer"]
	actors.append_array(preload("res://scripts/guardian_cutout/renderer.gd").ACTOR_IDS)
	for id: String in actors:
		var guardian: bool = id in preload("res://scripts/guardian_cutout/renderer.gd").ACTOR_IDS
		var base: String = "res://assets/units/guardians/"+id if guardian else "res://assets/units/"+id+"_cutout"
		var motion: Script = load("res://scripts/guardian_cutout/motion.gd" if guardian else "res://scripts/"+id+"_cutout/motion.gd")
		var clips: Array[String] = ["hit", "death"]
		if id == "protagonist": clips.append("block")
		for facing: String in ["front", "rear"]:
			var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base.path_join(facing+".json")))
			var supports: Array[String] = []
			if id == "acolyte": supports.assign(["hem_l", "hem_r"])
			elif id == "veilbound_acolyte": supports.assign(["support_l", "support_r"])
			elif id == "chainbound_gaoler": supports.assign(["foot_hook", "foot_fist"])
			elif guardian:
				for chain: Dictionary in layout.chains:
					if chain.kind == "leg": supports.append(str(chain.bones[2]))
			else: supports.assign(["foot_l", "foot_r"])
			var terminals: Array[String] = supports.duplicate()
			for joint: String in layout.joints:
				if joint.begins_with("hand_") or joint.begins_with("wrist_") or joint in ["head", "hood", "cast_hand", "rest_hand", "strike_hand"]: terminals.append(joint)
			var rest: Dictionary = motion.sample_pose("rest",0,layout,facing)
			if id == "bell_tender":
				for action: String in ["walk", "strike", "cast", "brace", "hit", "death"]:
					for frame: int in range(41):
						var grip_pose: Dictionary = motion.sample_pose(action,float(frame)/40.0,layout,facing)
						var staff: Transform2D = world(grip_pose,layout,"spear")
						var expected_grip: Vector2 = staff*(point(layout,"hand_far")-point(layout,"spear"))
						check(world(grip_pose,layout,"hand_far").origin.distance_to(expected_grip)<.01,"Bell Tender "+facing+" "+action+" keeps both hands on staff")
			for clip: String in clips:
				for index: int in range(41):
					var phase: float = float(index)/40.0
					var pose: Dictionary = motion.sample_pose(clip,phase,layout,facing)
					for name: String in layout.joints:
						var transform: Transform2D = world(pose,layout,name)
						check(transform.is_finite(),id+" "+facing+" "+clip+" finite transform "+name)
						if clip in ["hit","death","block"] and name in terminals:
							check(absf(transform.x.length()-1)<.001 and absf(transform.y.length()-1)<.001 and absf(transform.x.dot(transform.y))<.001,id+" "+facing+" "+clip+" rigid "+name)
						if clip in ["hit","death","block"] and name in supports:
							check(transform.origin.distance_to(point(layout,name))<.2,id+" "+facing+" "+clip+" planted "+name)
				if clip in ["hit","block"]:
					var end: Dictionary = motion.sample_pose(clip,1.0,layout,facing)
					for name: String in layout.joints:
						check(world(rest,layout,name).is_equal_approx(world(end,layout,name)),id+" "+facing+" "+clip+" fully recovers "+name)
				if clip=="death":
					var dead: Dictionary = motion.sample_pose(clip,.82,layout,facing)
					var held: Dictionary = motion.sample_pose(clip,1.0,layout,facing)
					var body: String = "hips" if id == "protagonist" else "torso" if id in ["acolyte", "veilbound_acolyte"] else "pelvis"
					check(world(held,layout,body).origin.y-world(rest,layout,body).origin.y>10.0,id+" "+facing+" defeat lowers supported body")
					for name: String in layout.joints:
						check(world(dead,layout,name).is_equal_approx(world(held,layout,name)),id+" "+facing+" death holds "+name)
		print("Audited ",id)
	for npc: String in ["scavenger", "graftwright"]:
		var motion: Script = load("res://scripts/"+npc+"_cutout/motion.gd")
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/units/"+npc+"_cutout/front.json"))
		for frame: int in range(41):
			var pose: Dictionary = motion.sample_pose("idle",float(frame)/40.0,layout,"front")
			for name: String in layout.joints:
				var parent: String = "" if layout.joints[name].parent == null else str(layout.joints[name].parent)
				var transform: Transform2D = world(pose,layout,parent).affine_inverse()*world(pose,layout,name)
				check(transform.x.is_equal_approx(Vector2.RIGHT) and transform.y.is_equal_approx(Vector2.DOWN),npc+" idle has no independent rotation or scale in "+name)
				if name != "chest": check(transform.origin.distance_to(point(layout,name)-point(layout,parent))<.001,npc+" idle has no independent offset in "+name)
	for error: String in failures: push_error(error)
	print("HUMANOID REACTION MOTION: ", "PASS" if failures.is_empty() else "FAIL", " ", failures.size())
	quit(0 if failures.is_empty() else 1)

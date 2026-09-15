extends SceneTree
const Motion = preload("res://scripts/guardian_cutout/motion.gd")
const Actors = preload("res://scripts/guardian_cutout/renderer.gd")
var failures: Array[String] = []
func check(ok: bool, text: String) -> void:
	if not ok and not failures.has(text): failures.append(text)
func _initialize() -> void:
	for id: String in Actors.ACTOR_IDS:
		var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://experiments/cutouts/%s/v02/cutout.json" % id))
		for facing: String in ["front", "rear"]:
			var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://experiments/cutouts/%s/v02/" % id+str(config["layouts"][facing])))
			var rest: Dictionary = Motion.sample_pose("rest",0,layout,facing)
			for clip: String in ["idle", "walk", "strike", "cast", "brace"]:
				for frame: int in range(41):
					var t: float = float(frame)/40.0
					var pose: Dictionary = Motion.sample_pose(clip,t,layout,facing)
					for name: String in pose:
						var transform: Transform2D = Motion._world(pose,layout,name)
						check(transform.is_finite(),id+" finite joints throughout "+facing+" "+clip)
					if clip=="idle":
						for name: String in ["head","drape","tail","throat","blade","spear","lantern","wing_near","wing_far"]:
							if not pose.has(name): continue
							var transform: Transform2D = Motion._world(pose,layout,name)
							var neutral: Transform2D = Motion._world(rest,layout,name)
							check(transform.x.is_equal_approx(neutral.x) and transform.y.is_equal_approx(neutral.y),id+" idle has no independent ripple, rotation or stretch in "+name)
					for chain: Dictionary in layout["chains"]:
						if chain["kind"]!="leg": continue
						var foot: String = str(chain["bones"][2])
						var world: Transform2D = Motion._world(pose,layout,foot)
						check(absf(world.x.length()-1)<.001 and absf(world.y.length()-1)<.001,id+" soles and claws retain rigid paint")
						var striking_claw: bool = str(chain["name"]) in ["fore_near","front_near"] and id in ["craghide","stoneback_mite","rimejaw","rime_whelp"] and clip in ["strike","cast","brace"] and not bool(chain.get("occluded",false))
						if striking_claw: continue
						var target: Vector2 = Motion.walk_foot_state(t,foot,layout,facing)["target"] if clip=="walk" else Motion._point(layout,foot)
						check(world.origin.distance_to(target)<.2,id+" non-attacking supports stay planted "+clip)
			var prep: Dictionary = Motion.sample_pose("strike",.26,layout,facing)
			var hit: Dictionary = Motion.sample_pose("strike",.46,layout,facing)
			var recovered: Dictionary = Motion.sample_pose("strike",1,layout,facing)
			for name: String in rest:
				check(Motion._world(rest,layout,name).is_equal_approx(Motion._world(recovered,layout,name)),id+" strike completely recovers")
			if id=="ashen_reaver":
				check(absf(float(prep["blade"]["rotation"])-float(hit["blade"]["rotation"]))>1.7,"Reaver sword has a readable cutting arc "+facing)
			elif id in ["gallows_roc","roc_fledgling","ash_hound","rime_spitter"]:
				check(Motion._world(prep,layout,"head").origin.distance_to(Motion._world(hit,layout,"head").origin)>25,id+" drives beak or jaws visibly to contact "+facing)
			elif id in ["rimejaw","rime_whelp","craghide","stoneback_mite"]:
				var raised: bool = false
				for chain: Dictionary in layout["chains"]:
					if chain["kind"]=="leg" and str(chain["name"]) in ["fore_near","front_near"]:
						var foot: String = chain["bones"][2]
						raised=Motion._world(prep,layout,foot).origin.distance_to(Motion._world(hit,layout,foot).origin)>20
				check(raised,id+" lifts and swipes a foreclaw "+facing)
		print("Guardian motion sampled: ",id)
	for error: String in failures: push_error(error)
	print("GUARDIAN MOTION: ","PASS" if failures.is_empty() else "FAIL"," ",failures.size())
	quit(0 if failures.is_empty() else 1)

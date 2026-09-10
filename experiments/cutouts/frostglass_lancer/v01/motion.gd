extends RefCounted

## Frostglass Lancer: narrow armored stride, grounded bob and aimed lance work.
## All points are this creature's registered landmarks, never Warden pose keys.
const STRIDE: float = 60.0
const STANCE: float = 0.62

static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		pose[name] = {"position": point(layout,name)-point(layout,parent(layout,name)),
			"rotation": 0.0, "scale": Vector2.ONE, "skew": 0.0}
	var t: float = clampf(phase,0.0,1.0)
	var rear: bool = facing == "rear"
	if clip == "idle":
		var bob := Vector2(0,-1.15*(0.5-0.5*cos(TAU*t)))
		pose["pelvis"]["position"] += bob
		pose["thigh_r"]["position"] -= bob
		pose["thigh_l"]["position"] -= bob
		return pose
	if clip == "walk":
		pose["pelvis"]["position"] += Vector2(0,1.5*(1.0-cos(TAU*2.0*t)))
		pose["upper_r"]["rotation"] = 0.025*sin(TAU*t)
		pose["upper_l"]["rotation"] = -0.11*sin(TAU*t)
		pose["cloak"]["rotation"] = 0.018*sin(TAU*t-0.4)
		pose["tabard"]["rotation"] = -0.02*sin(TAU*t)
		for side: String in ["r","l"]:
			var foot: Dictionary = walk_foot_state(t,"foot_"+side,layout,facing)
			solve_leg(pose,layout,side,foot["target"],float(foot["lift_px"]),rear)
		return pose
	if not clip in ["thrust","cast","pin"] or t <= 0.000001 or t >= 0.999999:
		return pose
	var aim: float = curve(t,PackedVector2Array([Vector2(0,0),Vector2(0.22,1),Vector2(0.65,1),Vector2(1,0)]))
	var prepare: float = curve(t,PackedVector2Array([Vector2(0,0),Vector2(0.30,1),Vector2(0.37,1),Vector2(0.50,0),Vector2(1,0)]))
	var release: float = curve(t,PackedVector2Array([Vector2(0,0),Vector2(0.37,0),Vector2(0.50,1),Vector2(0.63,1),Vector2(1,0)]))
	var direction := Vector2(1,-0.5).normalized() if rear else Vector2(-1,0.5).normalized()
	var body: Vector2 = direction*(-2.0*prepare+(7.0 if clip=="thrust" else 3.0)*release)
	pose["pelvis"]["position"] += body
	var hand: Vector2 = point(layout,"hand_r")+body
	var angle: float = (0.88 if rear else -1.84)*aim
	if clip == "thrust":
		hand += (Vector2(-3,1) if rear else Vector2(5,-10))*aim
		hand += (Vector2(-6,5) if rear else Vector2(6,-3))*prepare
		hand += (Vector2(14,-7) if rear else Vector2(-10,5))*release
	elif clip == "cast":
		# Draw the spear hand back, then drive it through a casting release.
		hand += (Vector2(-7,-4) if rear else Vector2(12,-18))*aim
		hand += (Vector2(-6,7) if rear else Vector2(9,-3))*prepare
		hand += (Vector2(23,-6) if rear else Vector2(-23,9))*release
		angle += (0.12 if rear else -0.10)*prepare
		# The free arm stays braced at the belt. Folding the complete painted
		# shoulder exposed the cape's arm-shaped opening during this one-hand cast.
	else:
		# Frost Pin holds a steady sight line; a compact pulse releases the ice.
		hand += (Vector2(2,-4) if rear else Vector2(-1,-9))*aim
		hand += (Vector2(-3,2) if rear else Vector2(3,-1))*prepare
		hand += direction*7.0*release
	solve_arm(pose,layout,"r",hand,angle)
	for side: String in ["r","l"]:
		solve_leg(pose,layout,side,point(layout,"foot_"+side),0.0,rear)
	return pose

static func walk_cycle_info(_layout: Dictionary, facing: String) -> Dictionary:
	var direction := Vector2(1,-0.5).normalized() if facing=="rear" else Vector2(-1,0.5).normalized()
	return {"direction":direction,"stride_px":STRIDE,"stance_fraction":STANCE,
		"travel_per_cycle":direction*STRIDE/STANCE,"foot_lift_px":6.0}

static func walk_foot_state(phase: float, foot: String, layout: Dictionary, facing: String) -> Dictionary:
	var t: float = fposmod(phase+(0.5 if foot=="foot_l" else 0.0),1.0)
	var contact: bool = t <= STANCE
	var distance: float = STRIDE*(0.5-t/STANCE)
	var lift: float = 0.0
	if not contact:
		var u: float = (t-STANCE)/(1.0-STANCE)
		var tangent: float = -STRIDE*(1.0-STANCE)/STANCE
		distance = lerpf(-STRIDE*0.5,STRIDE*0.5,u*u*(3-2*u))+tangent*(2*u*u*u-3*u*u+u)
		lift = 6.0*pow(sin(PI*u),1.5)
	var sole_r: Vector2 = landmark(layout,"sole_r")
	var sole_l: Vector2 = landmark(layout,"sole_l")
	var sole: Vector2 = sole_r if foot=="foot_r" else sole_l
	var center: Vector2 = (sole_r+sole_l)*0.5
	var offset: Vector2 = sole-center
	# Keep most of this slim figure's painted stance width while alternating
	# along the actual 2:1 travel axis. Boots retain their painted rigid basis.
	var lateral: Vector2 = Vector2(1,0.5)*(0.5*offset.x+offset.y)*0.85
	var ground: Vector2 = center+lateral+Vector2(walk_cycle_info(layout,facing)["direction"])*distance
	return {"target":ground-(sole-point(layout,foot))-Vector2(0,lift),"ground_contact":ground,
		"contact":contact,"cycle_phase":t,"lift_px":lift,"angle":0.0}

static func sample_draw_order(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	if clip != "walk":
		return {}
	var right: Dictionary = walk_foot_state(phase,"foot_r",layout,facing)
	var left: Dictionary = walk_foot_state(phase,"foot_l",layout,facing)
	var right_near: bool = Vector2(right["ground_contact"]).y >= Vector2(left["ground_contact"]).y
	var result: Dictionary = {}
	for side: String in ["r","l"]:
		var near: bool = right_near if side=="r" else not right_near
		result["Skin_thigh_cover_"+side] = 3 if near else 0
		result["Skin_leg_"+side] = 4 if near else 1
		result["foot_"+side] = 5 if near else 2
	return result

static func solve_arm(pose: Dictionary, layout: Dictionary, side: String, target: Vector2, angle: float) -> void:
	var upper: String = "upper_"+side
	var lower: String = "fore_"+side
	var hand: String = "hand_"+side
	var a: Vector2 = point(layout,upper)
	var b: Vector2 = point(layout,lower)
	var c: Vector2 = point(layout,hand)
	var shoulder: Vector2 = world(pose,layout,upper).origin
	var delta: Vector2 = target-shoulder
	var distance: float = maxf(delta.length(),0.001)
	var upper_length: float = a.distance_to(b)
	var lower_length: float = b.distance_to(c)
	var stretch: float = maxf(1.0,distance/(upper_length+lower_length)*1.00001)
	upper_length *= stretch
	lower_length *= stretch
	var along: float = (upper_length*upper_length-lower_length*lower_length+distance*distance)/(2.0*distance)
	var height: float = sqrt(maxf(0.0,upper_length*upper_length-along*along))
	var bend: float = signf((c-a).cross(b-a))
	var elbow: Vector2 = shoulder+delta.normalized()*along+delta.normalized().orthogonal()*height*bend
	var upper_world: Transform2D = segment(b-a,elbow-shoulder,shoulder)
	var lower_world: Transform2D = segment(c-b,target-elbow,elbow)
	store_transform(pose,upper,world(pose,layout,parent(layout,upper)).affine_inverse()*upper_world)
	store_transform(pose,lower,upper_world.affine_inverse()*lower_world)
	store_transform(pose,hand,lower_world.affine_inverse()*Transform2D(angle,target))

static func solve_leg(pose: Dictionary, layout: Dictionary, side: String, target: Vector2, lift: float, rear: bool) -> void:
	var upper: String = "thigh_"+side
	var lower: String = "shin_"+side
	var foot: String = "foot_"+side
	var a: Vector2 = point(layout,upper)
	var b: Vector2 = point(layout,lower)
	var c: Vector2 = point(layout,foot)
	var hip: Vector2 = world(pose,layout,upper).origin
	var knee: Vector2 = b+(hip-a)*0.48+(target-c)*0.52+Vector2(-0.28 if rear else 0.28,-0.22)*lift
	var upper_world: Transform2D = segment(b-a,knee-hip,hip)
	var lower_world: Transform2D = segment(c-b,target-knee,knee)
	store_transform(pose,upper,world(pose,layout,parent(layout,upper)).affine_inverse()*upper_world)
	store_transform(pose,lower,upper_world.affine_inverse()*lower_world)
	store_transform(pose,foot,lower_world.affine_inverse()*Transform2D(0,target))

static func segment(original: Vector2, projected: Vector2, origin: Vector2) -> Transform2D:
	var a: Vector2 = original.normalized()
	var b: Vector2 = projected.normalized()
	var result: Transform2D = Transform2D(projected/original.length(),b.orthogonal(),Vector2.ZERO)*Transform2D(a,a.orthogonal(),Vector2.ZERO).affine_inverse()
	result.origin = origin
	return result

static func store_transform(pose: Dictionary, name: String, transform: Transform2D) -> void:
	pose[name] = {"position":transform.origin,"rotation":transform.get_rotation(),"scale":transform.get_scale(),"skew":transform.get_skew()}

static func point(layout: Dictionary, name: String) -> Vector2:
	if name.is_empty(): return Vector2.ZERO
	var value: Array = layout["joints"][name]["position"]
	return Vector2(float(value[0]),float(value[1]))

static func landmark(layout: Dictionary, name: String) -> Vector2:
	var value: Array = layout["landmarks"][name]
	return Vector2(float(value[0]),float(value[1]))

static func parent(layout: Dictionary, name: String) -> String:
	var value: Variant = layout["joints"][name]["parent"]
	return "" if value==null else str(value)

static func world(pose: Dictionary, layout: Dictionary, name: String) -> Transform2D:
	if name.is_empty(): return Transform2D.IDENTITY
	var p: Dictionary = pose[name]
	return world(pose,layout,parent(layout,name))*Transform2D(float(p["rotation"]),Vector2(p["scale"]),float(p["skew"]),Vector2(p["position"]))

static func curve(t: float, keys: PackedVector2Array) -> float:
	for index: int in range(1,keys.size()):
		if t <= keys[index].x:
			var u: float = inverse_lerp(keys[index-1].x,keys[index].x,t)
			return lerpf(keys[index-1].y,keys[index].y,u*u*(3-2*u))
	return keys[-1].y

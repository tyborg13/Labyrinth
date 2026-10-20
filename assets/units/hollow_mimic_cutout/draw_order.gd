extends RefCounted

## Front camera rule from rr29. The far wrist crosses the torso's projected
## midline before its sleeve/hand become camera-side. Rest and rear keep paint
## order. Recompute from the current pose: no clip-name/frame exceptions.
static func node_for(rig: Node2D, part: Dictionary) -> Node2D:
	var mesh: Node2D = rig.get_node_or_null(NodePath(str(part["name"]))) as Node2D
	if mesh != null: return mesh
	return rig.bones[part["bone"]].get_node_or_null(NodePath(str(part["name"]))) as Node2D

static func projected_box(rig: Node2D, part: Dictionary) -> Rect2:
	var bind: Vector2 = rig._vector(rig.layout["joints"][part["bone"]]["position"])
	var transform: Transform2D = rig.global_transform.affine_inverse() * (rig.bones[part["bone"]] as Bone2D).global_transform
	var box: Array = part["bbox"]
	var points: Array[Vector2]
	points.assign([Vector2(box[0],box[1]),Vector2(box[2],box[1]),Vector2(box[0],box[3]),Vector2(box[2],box[3])])
	var result := Rect2(transform * (points[0] - bind), Vector2.ZERO)
	for point: Vector2 in points: result = result.expand(transform * (point - bind))
	return result

static func camera_sides(rig: Node2D) -> Dictionary:
	var result: Dictionary = {"near":false,"far":false}
	if rig.facing != "front": return result
	var torso: Dictionary
	for part: Dictionary in rig.layout["parts"]:
		if part["name"] == "torso": torso = part
	if torso.is_empty(): return result
	var torso_box: Rect2 = projected_box(rig, torso)
	var middle: float = (rig.global_transform.affine_inverse() * (rig.bones["torso"] as Bone2D).global_transform).origin.x
	var far_rest_x: float = float(rig.layout["joints"]["hand_far"]["position"][0])
	var torso_rest_x: float = float(rig.layout["joints"]["torso"]["position"][0])
	for part: Dictionary in rig.layout["parts"]:
		if part["name"] not in ["hand_near","hand_far"]: continue
		var side: String = "near" if part["name"] == "hand_near" else "far"
		var wrist: Vector2 = (rig.global_transform.affine_inverse() * (rig.bones[part["bone"]] as Bone2D).global_transform).origin
		result[side] = projected_box(rig, part).intersects(torso_box) and (side == "near" or (wrist.x - middle) * (far_rest_x - torso_rest_x) <= 0.0)
	return result

static func apply(rig: Node2D, clip: String) -> void:
	var sides: Dictionary = camera_sides(rig) if clip != "rest" else {"near":false,"far":false}
	var torso_depth: int = 0
	for part: Dictionary in rig.layout["parts"]:
		if part["name"] == "torso": torso_depth = int(part["z_index"])
	for part: Dictionary in rig.layout["parts"]:
		var node: Node2D = node_for(rig, part)
		if node == null: continue
		var side: String = "near" if str(part["name"]).ends_with("near") else "far"
		var in_front: bool = bool(sides[side]) and (str(part["name"]).begins_with("sleeve_") or str(part["name"]).begins_with("hand_")) and not bool(part.get("hidden_material", false))
		node.z_index = maxi(int(part["z_index"]), torso_depth + 1) if in_front else int(part.get("z_index", 0))

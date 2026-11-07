extends RefCounted

## Optional v2 held-item strike sampler. Undeclared renderers retain the legacy
## sampler; this follows the existing effect clock and protected source tracks.
const Action = preload("action.gd")
const Facing = preload("res://scripts/enemy_cutout_facing.gd")
const Trail = preload("res://scripts/strike_trail_fx.gd")

static func samples(renderer: Node, actor: Dictionary, effect: Dictionary, delta: Vector2i, settings: Dictionary, boundary: float, item: String) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var direction: Dictionary = Facing.direction_for_delta(delta)
	var view: String = direction["facing"]
	if not renderer.rigs.has(view): return result
	var type: String = str(actor["type"])
	var clip: String = Action.clip_for(effect, actor)
	if clip.is_empty(): return result
	var data: Dictionary = Action.data_for(type)
	var contact: float = float(data["clips"][clip]["contact"])
	var window: Vector2 = settings["window"]
	var times: Array[float]
	for index: int in range(ceili((window.y - window.x) / Trail.SAMPLE_STEP) + 1):
		times.append(minf(window.x + float(index) * Trail.SAMPLE_STEP, window.y))
	if not times.has(boundary) and boundary >= window.x and boundary <= window.y:
		times.append(boundary)
		times.sort()
	var rig: Node2D = renderer.rigs[view]
	var saved_view: String = renderer.facing
	var saved_mirror: bool = renderer.mirrored
	var saved_nodes: Array[Dictionary] = save_nodes(rig)
	var saved_angles: Dictionary = rig.precise_angles.duplicate(true)
	renderer.facing = view
	renderer.mirrored = bool(direction["mirrored"])
	var old_transform: Transform2D = rig.transform
	rig.transform = preload("pixel_presentation.gd").canvas_transform(renderer.canvas_geometry()["offset"], renderer.SOURCE_SIZE, renderer.mirrored)
	for progress: float in times:
		var phase: float = Action.contact_phase(progress, boundary, contact)
		rig.apply_pose(clip, phase)
		var tip: Vector2 = preload("posed_points.gd").source_point(renderer, item)
		var grip: Vector2 = rig.bones[item].global_position - (renderer.canvas_geometry()["offset"] as Vector2)
		var inner: Vector2 = tip.lerp(grip, float(settings.get("reach", 0.55)))
		result.append({"progress": progress, "tip": tip, "inner": inner})
	restore_nodes(saved_nodes)
	rig.precise_angles = saved_angles
	rig.transform = old_transform
	renderer.facing = saved_view
	renderer.mirrored = saved_mirror
	return result


## Sampling must leave the exact live transforms/textures in place. Reapplying a
## phase is insufficient: idle cache clocks and reflected float32 snap ties can
## differ from the last submitted pose while the render signature stays held.
static func save_nodes(rig: Node2D) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for node: Node in rig.find_children("*", "Node2D", true, false):
		var row: Dictionary = {"node": node, "transform": node.transform, "modulate": node.modulate,
			"self_modulate":node.self_modulate,"visible":node.visible,"z_index":node.z_index,"z_as_relative":node.z_as_relative,
			"material":node.material}
		if node is Sprite2D or node is Polygon2D: row["texture"] = node.texture
		# Exact-source paint submits posed vertices independently of bones.
		# Restoring only transforms would leave the sampled contact body drawn.
		if node is Polygon2D:
			row["polygon"] = node.polygon
			row["uv"] = node.uv
			row["skeleton"] = node.skeleton
		result.append(row)
	return result

static func restore_nodes(rows: Array[Dictionary]) -> void:
	for row: Dictionary in rows:
		var node: Node2D = row["node"]
		node.transform = row["transform"]
		node.modulate = row["modulate"]
		node.self_modulate = row["self_modulate"]
		node.visible = row["visible"]
		node.z_index = row["z_index"]
		node.z_as_relative = row["z_as_relative"]
		# Shaft layering swaps sprite materials while posed (Lancer tail).
		node.material = row["material"]
		if row.has("texture"): node.texture = row["texture"]
		if node is Polygon2D:
			node.polygon = row["polygon"]
			node.uv = row["uv"]
			node.skeleton = row["skeleton"]

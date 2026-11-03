extends RefCounted

## rr-05 presentation only. The director sampler remains continuous and keeps
## every authored amplitude. Snap the final painted transform in source space,
## after the entire bone hierarchy, so fractional pivots cannot reintroduce crawl.
const LOOP_FPS: float = 10.0
const ROTATION_STEP: float = PI / 120.0 # 1.5 degrees, specified by the director.
const CLOCK_EPSILON: float = 0.00000001

## Assign the full basis: decomposing an X reflection can represent it as a
## half-turn plus negative Y scale. Partial position/scale setters retain that
## rotation after a sampled transform is restored.
static func canvas_transform(offset: Vector2, source_size: Vector2, mirrored: bool) -> Transform2D:
	return Transform2D(Vector2.LEFT if mirrored else Vector2.RIGHT, Vector2.DOWN,
		offset + Vector2(source_size.x, 0.0) if mirrored else offset)

static func phase_for(data: Dictionary, clip: String, phase: float) -> float:
	var definition: Dictionary = data.get("clips", {}).get(clip, {})
	if not bool(definition.get("loop", false)): return phase
	var seconds: float = float(definition["seconds"])
	var elapsed: float = fposmod(phase, 1.0) * seconds
	var held_seconds: float = floorf(elapsed * LOOP_FPS + CLOCK_EPSILON) / LOOP_FPS
	return fposmod(held_seconds, seconds) / seconds

static func snapped_transform(source: Transform2D, authored_angle: float = NAN, travel: Vector2 = Vector2.ZERO) -> Transform2D:
	if is_nan(authored_angle):
		return Transform2D(snappedf(source.get_rotation(), ROTATION_STEP), source.get_scale(), source.get_skew(), (source.origin - travel).round() + travel)
	var angle: float = authored_angle
	var snapped: float = signf(angle) * floorf(absf(angle / ROTATION_STEP) + 0.5) * ROTATION_STEP
	return Transform2D(snapped, source.get_scale(), source.get_skew(), (source.origin - travel).round() + travel)

## Snap the pose around the continuous root, never the path's translation.
static func movement_offset(layout: Dictionary, clip: String) -> Vector2:
	var override: Dictionary = layout.get("root_forward_override", {})
	if clip != "move" or override.is_empty(): return Vector2.ZERO
	return (override["axis"] as Vector2) * float(override["forward_px"]) / maxf(float(layout.get("screen_pixel_scale", 1.0)), 0.000001)

static func shared_anchors(layout: Dictionary) -> Dictionary:
	# Every crop on a bone shares its owner transform: visible paint, features,
	# painted details and joint support must not acquire independent snap offsets.
	var shared: Dictionary = {}
	for part: Dictionary in layout["parts"]:
		shared[part["bone"]] = int(shared.get(part["bone"], 0)) + 1
	var anchors: Dictionary = {}
	for part: Dictionary in layout["parts"]:
		if part["name"] == part["bone"] and (int(shared[part["bone"]]) > 1 or part.has("presentation_anchor")): anchors[part["bone"]] = part
	for bone: String in shared:
		assert(int(shared[bone]) == 1 or anchors.has(bone), "Shared painted bone requires its owner crop")
	return anchors

static func apply(rig: Node2D, clip: String = "") -> void:
	var to_source: Transform2D = rig.global_transform.affine_inverse()
	var travel: Vector2 = movement_offset(rig.layout, clip)
	var anchors: Dictionary = shared_anchors(rig.layout)
	for part: Dictionary in rig.layout["parts"]:
		var bone: Bone2D = rig.bones[part["bone"]]
		var sprite: Sprite2D = bone.get_node(NodePath(part["name"]))
		var bone_pose: Transform2D = to_source * bone.global_transform
		var offset := Vector2(float(part["offset"][0]), float(part["offset"][1]))
		var pivot := Vector2(float(rig.layout["joints"][part["bone"]]["position"][0]), float(rig.layout["joints"][part["bone"]]["position"][1]))
		var painted: Transform2D = bone_pose * Transform2D(0.0, offset - pivot)
		var angle: float = rig.precise_angles.get(part["bone"], NAN)
		var presented: Transform2D = snapped_transform(painted, angle, travel)
		if anchors.has(part["bone"]):
			var anchor: Dictionary = anchors[part["bone"]]
			# Growing storage bounds for joint bleed must not move existing paint.
			var reference: Array = anchor.get("presentation_anchor", anchor["offset"])
			var anchor_offset := Vector2(float(reference[0]), float(reference[1]))
			var owner_paint: Transform2D = bone_pose * Transform2D(0.0, anchor_offset - pivot)
			presented = snapped_transform(owner_paint, angle, travel) * Transform2D(0.0, offset - anchor_offset)
		sprite.transform = bone_pose.affine_inverse() * presented

## Pixel alignment is derived geometry, never an authored travel override.
## Roster sync can precede layout invalidation (and resize need not sync a rig).
## Baking the old layout's absolute position into the caller's presentation
## made every later draw prefer it over the current tile. Resolve through the
## retained layer's current geometry instead; HUD/shadows share the correction.
static func board_center(board: Control, unit: Dictionary, center: Vector2) -> Vector2:
	var rect: Rect2 = board._unit_texture_draw_rect(unit, center, 1.0, false)
	return center + rect.position.round() - rect.position

static func board_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position.round(), rect.size)

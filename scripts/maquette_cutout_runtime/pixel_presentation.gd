extends RefCounted

## rr-05 presentation only. The director sampler remains continuous and keeps
## every authored amplitude. Snap the final painted transform in source space,
## after the entire bone hierarchy, so fractional pivots cannot reintroduce crawl.
const LOOP_FPS: float = 10.0
const ROTATION_STEP: float = PI / 120.0 # 1.5 degrees, specified by the director.
const CLOCK_EPSILON: float = 0.00000001

static func phase_for(data: Dictionary, clip: String, phase: float) -> float:
	var definition: Dictionary = data.get("clips", {}).get(clip, {})
	if not bool(definition.get("loop", false)): return phase
	var seconds: float = float(definition["seconds"])
	var elapsed: float = fposmod(phase, 1.0) * seconds
	var held_seconds: float = floorf(elapsed * LOOP_FPS + CLOCK_EPSILON) / LOOP_FPS
	return fposmod(held_seconds, seconds) / seconds

static func snapped_transform(source: Transform2D) -> Transform2D:
	return Transform2D(snappedf(source.get_rotation(), ROTATION_STEP), source.get_scale(), source.get_skew(), source.origin.round())

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

static func apply(rig: Node2D) -> void:
	var to_source: Transform2D = rig.global_transform.affine_inverse()
	var anchors: Dictionary = shared_anchors(rig.layout)
	for part: Dictionary in rig.layout["parts"]:
		var bone: Bone2D = rig.bones[part["bone"]]
		var sprite: Sprite2D = bone.get_node(NodePath(part["name"]))
		var bone_pose: Transform2D = to_source * bone.global_transform
		var offset := Vector2(float(part["offset"][0]), float(part["offset"][1]))
		var pivot := Vector2(float(rig.layout["joints"][part["bone"]]["position"][0]), float(rig.layout["joints"][part["bone"]]["position"][1]))
		var painted: Transform2D = bone_pose * Transform2D(0.0, offset - pivot)
		var presented: Transform2D = snapped_transform(painted)
		if anchors.has(part["bone"]):
			var anchor: Dictionary = anchors[part["bone"]]
			# Growing storage bounds for joint bleed must not move existing paint.
			var reference: Array = anchor.get("presentation_anchor", anchor["offset"])
			var anchor_offset := Vector2(float(reference[0]), float(reference[1]))
			var owner_paint: Transform2D = bone_pose * Transform2D(0.0, anchor_offset - pivot)
			presented = snapped_transform(owner_paint) * Transform2D(0.0, offset - anchor_offset)
		sprite.transform = bone_pose.affine_inverse() * presented

## The board already supports texture-only origins for root travel. Align the
## final padded rectangle through that path. Presentation anchors follow the same
## subpixel correction; logical tiles, resolver travel and saves remain intact.
static func align_on_board(board: Control, unit: Dictionary, key: String, presentation: Dictionary) -> void:
	var keyed: Dictionary = unit.duplicate(false)
	keyed["key"] = key
	var center: Vector2 = board._unit_center(keyed)
	var rect: Rect2 = board._unit_texture_draw_rect(keyed, center)
	var origins: Dictionary = (presentation.get("unit_texture_origins", {}) as Dictionary).duplicate(false)
	var correction: Vector2 = rect.position.round() - rect.position
	origins[key] = (origins.get(key, center) as Vector2) + correction
	presentation["unit_texture_origins"] = origins
	var positions: Dictionary = (presentation.get("unit_world_positions", {}) as Dictionary).duplicate(false)
	positions[key] = center + correction
	presentation["unit_world_positions"] = positions

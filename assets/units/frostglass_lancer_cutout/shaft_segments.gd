extends RefCounted

## rr-59: keep the approved point-side drawing and every non-thrust
## pose. Re-submit only the butt-side texels at the required body depth. Both
## submissions use the original full quad, texture and rigid transform, so no
## independently snapped cut edge can reopen rr-43's grip seam.
const SegmentShader = preload("shaft_segment.gdshader")
const THRUST_CLIPS: Array = ["jab", "lunge", "pin"]
# Feedback 2: minimize the union of opaque tail/crossed-paint pixels, excluding
# paint above both depths (the gripping hand stays in front). Entry candidates
# are at/before contact, return candidates at/after it. Equal counts choose the
# earlier entry and later return. Return is the first frame back at source depth.
# The former front switches exceeded the director's 1% limit, so both facings
# use the measured minimum-change frames. Geometry, clips and timing stay exact.
const FRONT_DEPTH_TRANSITION_FRAMES: Dictionary = {
	"jab": {"entry": 0, "return": 35, "frames": 36},
	"lunge": {"entry": 12, "return": 65, "frames": 66},
	"pin": {"entry": 0, "return": 71, "frames": 72},
}
const REAR_DEPTH_TRANSITION_FRAMES: Dictionary = {
	"jab": {"entry": 1, "return": 34, "frames": 36},
	"lunge": {"entry": 0, "return": 63, "frames": 66},
	"pin": {"entry": 3, "return": 69, "frames": 72},
}

var _facing: String = ""
var _pieces: Array[Dictionary]

func restore() -> void:
	for piece: Dictionary in _pieces:
		if not is_instance_valid(piece["source"]): continue
		(piece["source"] as Sprite2D).material = piece["original_material"]
		(piece["rear"] as Sprite2D).hide()

func apply(rig: Node2D, clip: String, phase: float) -> void:
	if _facing != rig.facing:
		_setup(rig)
	var crossings: Dictionary = FRONT_DEPTH_TRANSITION_FRAMES if rig.facing == "front" else REAR_DEPTH_TRANSITION_FRAMES
	if clip not in THRUST_CLIPS or not crossings.has(clip): return
	var interval: Dictionary = crossings[clip]
	# Use scalar floats: Vector2 would round the boundary to float32 and can
	# skip the first crossing when the caller supplies an exact 60 Hz phase.
	var denominator: float = float(int(interval["frames"]) - 1)
	if phase < float(interval["entry"]) / denominator or phase >= float(interval["return"]) / denominator: return
	for piece: Dictionary in _pieces:
		var source: Sprite2D = piece["source"]
		var rear: Sprite2D = piece["rear"]
		source.material = piece["front_material"]
		rear.texture = source.texture # Includes the current clip's hidden-material continuation.
		rear.transform = source.transform
		rear.modulate = source.modulate
		rear.show()

func _setup(rig: Node2D) -> void:
	_facing = rig.facing
	_pieces.clear()
	var item: Dictionary = rig.layout["held_items"]["spear"]
	var grip := Vector2(float(item["source_grip"][0]), float(item["source_grip"][1]))
	var butt := Vector2(float(item["floor_end"][0]), float(item["floor_end"][1]))
	var body_layer: int = RenderingServer.CANVAS_ITEM_Z_MAX
	var hand_layer: int = RenderingServer.CANVAS_ITEM_Z_MAX
	for part: Dictionary in rig.layout["parts"]:
		if part.get("logical_part", "") != "spear": body_layer = mini(body_layer, int(part["z_index"]))
		if part["name"] == item["hand"]: hand_layer = int(part["z_index"])
	for part: Dictionary in rig.layout["parts"]:
		if part.get("logical_part", "") != "spear": continue
		var source: Sprite2D = rig.bones[part["bone"]].get_node(NodePath(str(part["name"]))) as Sprite2D
		var rear := Sprite2D.new()
		rear.name = "SpearRear_" + str(part["name"])
		rear.centered = source.centered
		rear.texture_filter = source.texture_filter
		rear.texture_repeat = source.texture_repeat
		rear.z_as_relative = false
		var hidden: bool = bool(part.get("hidden_material", false))
		rear.z_index = body_layer - (2 if hidden else 1) if _facing == "front" else hand_layer - (2 if hidden else 1)
		rear.material = _material(part, grip, butt, true)
		rear.set_meta("shaft_segment", "rear")
		source.get_parent().add_child(rear)
		rear.hide()
		_pieces.append({"source": source, "rear": rear, "original_material": source.material,
			"front_material": _material(part, grip, butt, false)})

func _material(part: Dictionary, grip: Vector2, butt: Vector2, rear: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SegmentShader
	material.set_shader_parameter("rear_segment", rear)
	material.set_shader_parameter("source_offset", Vector2(float(part["offset"][0]), float(part["offset"][1])))
	material.set_shader_parameter("source_grip", grip)
	material.set_shader_parameter("toward_butt", (butt - grip).normalized())
	return material

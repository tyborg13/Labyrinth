extends RefCounted
## Presentation only: carry depth and a shaft between the palm and fingers.
## Keep these sprites on the existing bones so poses, sockets and visibility
## (including the hidden weapon during a generic crossbow shot) stay inherited.
const USE_CLIPS: PackedStringArray = ["attack", "attack_heavy", "attack_stab", "attack_thrust", "attack_lash", "block", "shoot", "shoot_bow", "shoot_repeater"]

var grip: Sprite2D
var fingers: Sprite2D

static func weapon_depth(facing: String, clip: String, motion: String) -> int:
	if facing == "front":
		return 66 if clip in USE_CLIPS else 8
	var shot: bool = motion in ["bow", "repeater"] and clip in ["shoot", "shoot_bow", "shoot_repeater"]
	return 66 if shot else 5

static func base_depth(part: String, facing: String, authored: int) -> int:
	match part:
		"weapon_r": return weapon_depth(facing, "rest", "sword")
		"hand_r": return 65
		"crossbow": return 66
	return authored

func setup(rig: Node2D) -> void:
	var weapon: Sprite2D = rig._gear_base_parts["weapon_r"]["node"]
	var glove: Sprite2D = rig._gear_base_parts["hand_r"]["node"]
	grip = _overlay(rig, weapon, "weapon_r_grip", 66)
	fingers = _overlay(rig, glove, "hand_r_fingers", 67)
	fingers.texture = rig._texture(rig.facing + "/hand_r_fingers.png")
	refresh(rig)

func _overlay(rig: Node2D, body: Sprite2D, node_name: String, depth: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.centered = false
	sprite.z_index = depth
	sprite.z_as_relative = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.get_parent().add_child(sprite)
	sprite.owner = rig
	return sprite

func refresh(rig: Node2D) -> void:
	var weapon: Sprite2D = rig._gear_base_parts["weapon_r"]["node"]
	var glove: Sprite2D = rig._gear_base_parts["hand_r"]["node"]
	var path: String = str(weapon.texture.get_meta("asset_source_path", ""))
	grip.texture = rig._texture(path.get_basename() + "_grip.png")
	grip.position = weapon.position
	fingers.position = glove.position

func apply_depth(rig: Node2D, clip: String, motion: String) -> void:
	var weapon: Sprite2D = rig._gear_base_parts["weapon_r"]["node"]
	weapon.z_index = weapon_depth(rig.facing, clip if rig.visible else "rest", motion)
	# At use depth the full texture supplies the same handle pixels. During
	# carry only its handle is above the palm; its butt stays behind the leg.
	grip.visible = weapon.z_index != 66

extends Node
## Entry scene for the isolated PCK test, run by an unmodified export template.
func _ready() -> void:
	var renderer_script: Script = load("res://scripts/protagonist_cutout/renderer.gd") as Script
	var renderer: Node = renderer_script.new()
	add_child(renderer)
	var passed: bool = not OS.has_feature("editor")
	var carry_passed: bool = true
	var shot_passed: bool = true
	var layers_passed: bool = true
	var rules_free: bool = not FileAccess.file_exists("res://scripts/game_data.gd") and not FileAccess.file_exists("res://scripts/visual_equipment.gd")
	passed = passed and rules_free
	print("PROTAGONIST CUTOUT RULES-FREE PACKAGE: " + ("PASS" if rules_free else "FAIL"))
	for facing: String in ["front", "rear"]:
		var rig: Node = renderer.get("rigs")[facing]
		passed = passed and (rig.get("load_errors") as PackedStringArray).is_empty() and (rig.get("bones") as Dictionary).size() == 22
		passed = passed and (rig.get("bones") as Dictionary).has("crossbow_r") and rig.bones["crossbow_r"].get_parent() == rig.bones["hand_r"]
		carry_passed = _check_depth(rig) and carry_passed
		layers_passed = _check_layers(rig) and layers_passed
		for clip: String in ["idle", "walk", "attack", "attack_heavy", "attack_stab", "attack_thrust", "attack_lash", "block_shield", "cast", "shoot", "shoot_bow", "shoot_repeater"]:
			rig.call("apply_pose", clip, 0.42)
			layers_passed = _check_layers(rig) and layers_passed
	var gear: Script = load("res://scripts/protagonist_cutout/gear_visuals.gd")
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/units/protagonist_cutout/gear_visuals.json"))
	passed = passed and gear != null and not registry.is_empty()
	if gear != null:
		for item_id: String in registry.get("items", {}):
			var slot: String = str(registry["items"][item_id]["slot"])
			var equipped: Dictionary = gear.DEFAULTS.duplicate()
			equipped[slot] = item_id
			passed = passed and gear.resolve(equipped)[slot] == item_id
			renderer.call("set_gear", equipped)
			for facing: String in ["front", "rear"]:
				var rig: Node = renderer.get("rigs")[facing]
				passed = passed and (rig.get("load_errors") as PackedStringArray).is_empty()
				carry_passed = _check_depth(rig) and _check_carry(rig) and carry_passed
				layers_passed = _check_layers(rig) and layers_passed
				for kind: String in ["replace", "attach"]:
					for op: Dictionary in gear.ops_for_facing(equipped, facing)[kind]:
						passed = passed and FileAccess.file_exists("res://assets/units/protagonist_cutout/" + str(op["file"]))
				shot_passed = _check_main_hand_shot(renderer, facing) and shot_passed
				shot_passed = _check_main_hand_shot(renderer, facing, true) and shot_passed
		passed = passed and gear._items.size() == registry["items"].size()
		print("PROTAGONIST ONE-ARM SHOT EXPORT: " + ("PASS" if shot_passed else "FAIL"))
		passed = passed and shot_passed
		print("PROTAGONIST GEAR EXPORT ASSETS: " + ("PASS" if passed else "FAIL") + " (editor=" + str(OS.has_feature("editor")) + ")")
		for facing: String in ["front", "rear"]:
			var rig: Node = renderer.get("rigs")[facing]
			var ops: Dictionary = gear.ops_for_facing({"weapon": "war_maul"}, facing)
			ops["replace"][0]["z_index"] = 12
			rig.call("apply_gear", ops)
			carry_passed = _check_depth(rig) and _check_layers(rig) and carry_passed
			rig.call("apply_gear", {})
			carry_passed = _check_depth(rig) and not rig.layout.has("weapon_carry") and carry_passed
		print("PROTAGONIST GEAR GRIP LAYERS EXPORT: " + ("PASS" if layers_passed else "FAIL"))
		passed = passed and layers_passed
		print("PROTAGONIST GEAR CARRY EXPORT: " + ("PASS" if carry_passed else "FAIL"))
		passed = passed and carry_passed
		renderer.call("set_gear", gear.DEFAULTS)
		var rest: Texture2D = renderer.call("rest_texture")
		var default_rest_passed: bool = rest != null and rest.get_size() == Vector2(255, 255) and str(rest.get_meta("asset_source_path", "")) == renderer_script.DEFAULT_GEAR_REST_PATH
		print("PROTAGONIST DEFAULT GEAR REST ASSET: " + ("PASS" if default_rest_passed else "FAIL"))
		passed = passed and default_rest_passed
	passed = passed and not FileAccess.file_exists("res://experiments/protagonist_2d/README.md")
	renderer.queue_free()
	await get_tree().process_frame
	print("PROTAGONIST CUTOUT EXPORT RUNTIME: " + ("PASS" if passed else "FAIL") + " (editor=" + str(OS.has_feature("editor")) + ")")
	get_tree().quit(0 if passed else 1)

func _check_depth(rig: Node) -> bool:
	var z: int = 5 if rig.facing == "rear" else 8
	return rig._gear_base_parts["weapon_r"]["node"].z_index == z and rig._gear_base_parts["crossbow"]["node"].z_index == 66

func _check_layers(rig: Node) -> bool:
	var weapon: Sprite2D = rig._gear_base_parts["weapon_r"]["node"]
	var glove: Sprite2D = rig._gear_base_parts["hand_r"]["node"]
	var grip: Sprite2D = rig._gear_layers.grip
	var fingers: Sprite2D = rig._gear_layers.fingers
	if grip.texture == null or fingers.texture == null:
		return false
	var path: String = str(weapon.texture.get_meta("asset_source_path"))
	return glove.z_index == 65 and grip.z_index == 66 and fingers.z_index == 67 \
		and grip.get_parent() == weapon.get_parent() and grip.position == weapon.position \
		and fingers.get_parent() == glove.get_parent() and fingers.position == glove.position \
		and str(grip.texture.get_meta("asset_source_path")) == path.get_basename() + "_grip.png" \
		and str(fingers.texture.get_meta("asset_source_path")) == "res://assets/units/protagonist_cutout/" + rig.facing + "/hand_r_fingers.png" \
		and grip.visible == (weapon.z_index != 66) \
		and grip.is_visible_in_tree() == (weapon.is_visible_in_tree() and weapon.z_index != 66)

func _check_carry(rig: Node) -> bool:
	if not rig.layout.has("weapon_carry"):
		return true
	var motion: Script = load("res://scripts/protagonist_cutout/motion.gd")
	for clip: String in ["rest", "idle", "walk", "attack_thrust" if rig.layout["weapon_carry"]["motion"] == "thrust" else "shoot_bow"]:
		for phase: float in [0.0, 0.20, 0.42, 0.75, 1.0]:
			var pose: Dictionary = motion.sample_pose(clip, phase, rig.layout, rig.facing)
			var grip: Vector2 = motion._gear_vector(rig.layout["weapon_grip"]["assembled"])
			var palm: Vector2 = motion._world_transform(pose, rig.layout, "hand_r") * (grip - motion._joint_position(rig.layout, "hand_r"))
			var weapon: Vector2 = motion._world_transform(pose, rig.layout, "weapon_r") * (grip - motion._joint_position(rig.layout, "weapon_r"))
			if palm.distance_to(weapon) >= 0.001:
				return false
			if clip in ["rest", "idle"]:
				var axis: Vector2 = motion._world_transform(pose, rig.layout, "weapon_r").basis_xform(motion._gear_axis(rig.layout)).normalized()
				if axis.distance_to(motion._gear_axis(rig.layout)) >= 0.001:
					return false
	return true

func _check_main_hand_shot(renderer: Node, facing: String, mirrored: bool = false) -> bool:
	var direction := Vector2i(0, -1) if facing == "rear" else Vector2i(0, 1)
	if mirrored:
		direction = Vector2i(-1, 0) if facing == "rear" else Vector2i(1, 0)
	renderer.call("present", {"clip": "shoot", "phase": 0.42, "direction": direction}, false)
	var snapshot: Dictionary = renderer.call("snapshot")
	var rig: Node = renderer.get("rigs")[facing]
	var mode: String = renderer.call("ranged_motion")
	var generic: bool = mode.is_empty()
	var passed: bool = bool(snapshot["crossbow_visible"]) == generic and rig.bones["weapon_r"].visible == not generic and bool(snapshot["offhand_visible"])
	var motion: Script = load("res://scripts/protagonist_cutout/motion.gd")
	var bone: String = "crossbow_r" if generic else "weapon_r"
	var offset: Vector2 = motion._gear_vector(rig.layout["ranged_attachment"]["muzzle_offset"]) if generic else motion._gear_vector(rig.layout["weapon_grip"]["assembled" if mode == "bow" else "tip"]) - motion._joint_position(rig.layout, bone)
	var muzzle: Vector2 = rig.to_local(rig.bones[bone].to_global(offset))
	if mode == "bow":
		muzzle += (Vector2(1, -0.3) if facing == "rear" else Vector2(-1, -0.2)).normalized() * 6.0
	if mirrored:
		muzzle.x = 255.0 - muzzle.x
	passed = passed and (renderer.call("source_socket", true) as Vector2).distance_to(muzzle) < 0.001
	passed = passed and (renderer.call("source_socket", true, true, direction) as Vector2).distance_to(muzzle) < 0.001
	var weapon_z: int = 66 if facing == "front" or not generic else 5
	passed = rig._gear_base_parts["weapon_r"]["node"].z_index == weapon_z and _check_layers(rig) and passed
	if not generic:
		var shoot: Dictionary = motion.sample_pose("shoot", 0.42, rig.layout, facing)
		for limb_bone: String in ["arm_r", "forearm_r", "hand_r", "arm_l", "forearm_l", "hand_l"]:
			var value: Dictionary = shoot[limb_bone]
			var expected := Transform2D(float(value["rotation"]), value["scale"], float(value["skew"]), value["position"])
			passed = rig.bones[limb_bone].transform == expected and passed
	renderer.call("present", {"clip": "cast", "phase": 0.42, "direction": direction}, false)
	passed = _check_depth(rig) and _check_layers(rig) and passed
	passed = passed and not rig.bones["crossbow_r"].visible and rig.bones["weapon_r"].visible and bool(renderer.call("snapshot")["offhand_visible"])
	renderer.call("present", {"clip": "shoot", "phase": 0.42, "direction": direction}, false)
	renderer.call("present", {"clip": "shoot", "phase": 1.0, "direction": direction}, false)
	passed = _check_depth(renderer.get("rigs")["rear"]) and passed
	return passed

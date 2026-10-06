extends Node
## Entry scene for the isolated PCK test, run by an unmodified export template.
func _ready() -> void:
	var renderer_script: Script = load("res://scripts/protagonist_cutout/renderer.gd") as Script
	var renderer: Node = renderer_script.new()
	add_child(renderer)
	var passed: bool = not OS.has_feature("editor")
	var rules_free: bool = not FileAccess.file_exists("res://scripts/game_data.gd") and not FileAccess.file_exists("res://scripts/visual_equipment.gd")
	passed = passed and rules_free
	print("PROTAGONIST CUTOUT RULES-FREE PACKAGE: " + ("PASS" if rules_free else "FAIL"))
	for facing: String in ["front", "rear"]:
		var rig: Node = renderer.get("rigs")[facing]
		passed = passed and (rig.get("load_errors") as PackedStringArray).is_empty() and (rig.get("bones") as Dictionary).size() == 22
		passed = passed and (rig.get("bones") as Dictionary).has("crossbow_r") and rig.bones["crossbow_r"].get_parent() == rig.bones["hand_r"]
		for clip: String in ["idle", "walk", "attack", "attack_heavy", "attack_stab", "attack_thrust", "attack_lash", "block_shield", "cast", "shoot", "shoot_bow", "shoot_repeater"]:
			rig.call("apply_pose", clip, 0.42)
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
				for kind: String in ["replace", "attach"]:
					for op: Dictionary in gear.ops_for_facing(equipped, facing)[kind]:
						passed = passed and FileAccess.file_exists("res://assets/units/protagonist_cutout/" + str(op["file"]))
				passed = _check_main_hand_shot(renderer, facing) and passed
		passed = passed and gear._items.size() == registry["items"].size()
		print("PROTAGONIST GEAR EXPORT ASSETS: " + ("PASS" if passed else "FAIL") + " (editor=" + str(OS.has_feature("editor")) + ")")
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

func _check_main_hand_shot(renderer: Node, facing: String) -> bool:
	var direction := Vector2i(0, -1) if facing == "rear" else Vector2i(0, 1)
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
	passed = passed and (renderer.call("source_socket", true) as Vector2).distance_to(muzzle) < 0.001
	passed = passed and (renderer.call("source_socket", true, true, direction) as Vector2).distance_to(muzzle) < 0.001
	renderer.call("present", {"clip": "cast", "phase": 0.42, "direction": direction}, false)
	passed = passed and not rig.bones["crossbow_r"].visible and rig.bones["weapon_r"].visible and bool(renderer.call("snapshot")["offhand_visible"])
	return passed

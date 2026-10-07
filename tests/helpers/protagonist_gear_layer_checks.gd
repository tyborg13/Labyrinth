extends RefCounted
## Layer contracts independent of the production depth helper.
const Gear = preload("res://scripts/protagonist_cutout/gear_visuals.gd")
const Motion = preload("res://scripts/protagonist_cutout/motion.gd")
const Renderer = preload("res://scripts/protagonist_cutout/renderer.gd")
const CARRY: PackedStringArray = ["rest", "idle", "walk", "hit", "death", "cast", "block_shield"]
const USE: PackedStringArray = ["attack", "attack_heavy", "attack_stab", "attack_thrust", "attack_lash", "block", "shoot", "shoot_bow", "shoot_repeater"]

static func depth(facing: String, clip: String, motion: String, phase: float = 0.0) -> int:
	if facing == "front":
		if clip == "attack_thrust":
			return 38 if phase >= 0.20 and phase <= 0.62 else 8
		return 8 if clip in CARRY else 66
	return 66 if motion in ["bow", "repeater"] and clip in ["shoot", "shoot_bow", "shoot_repeater"] else 5

static func overlays(rig: Node2D, expect: Callable) -> void:
	var weapon: Sprite2D = rig._gear_base_parts["weapon_r"]["node"]
	var glove: Sprite2D = rig._gear_base_parts["hand_r"]["node"]
	var grip: Sprite2D = rig._gear_layers.grip
	var fingers: Sprite2D = rig._gear_layers.fingers
	expect.call(grip.get_parent() == rig.bones["weapon_r"] and grip.position == weapon.position, "Grip shares the weapon bone and exact texture offset")
	expect.call(fingers.get_parent() == rig.bones["hand_r"] and fingers.position == glove.position, "Fingers share the glove bone and exact texture offset")
	var path: String = str(weapon.texture.get_meta("asset_source_path"))
	expect.call(str(grip.texture.get_meta("asset_source_path")) == path.get_basename() + "_grip.png", "Grip follows the active replacement's derived texture, including default/clear")
	expect.call(str(fingers.texture.get_meta("asset_source_path")) == Gear.BASE.path_join(rig.facing + "/hand_r_fingers.png"), "Fingers use the committed facing art")
	expect.call(grip.texture.get_size() == weapon.texture.get_size() and fingers.texture.get_size() == glove.texture.get_size(), "Overlay crops remain pixel-aligned")
	expect.call(glove.z_index == 65 and grip.z_index == 66 and fingers.z_index == 67 and rig._gear_base_parts["crossbow"]["node"].z_index == 66, "Palm/grip/crossbow/fingers have the approved depths in both facings")
	expect.call(not grip.z_as_relative and not fingers.z_as_relative and not grip.centered and not fingers.centered, "Overlays use absolute depth and uncentred source pixels")
	expect.call(grip.visible == (weapon.z_index != 66), "Every weapon body below the palm needs the visible grip overlay")
	expect.call(grip.is_visible_in_tree() == (weapon.is_visible_in_tree() and weapon.z_index != 66), "Grip inherits hidden weapon/rig visibility without a ghost handle")
	for point: Vector2 in [Vector2.ZERO, Vector2(3, 7), weapon.texture.get_size()]:
		expect.call(grip.to_global(point).distance_to(weapon.to_global(point)) < 0.001, "Grip pixels follow the complete weapon transform, including mirrored and moving rigs")
		expect.call(fingers.to_global(point).distance_to(glove.to_global(point)) < 0.001, "Finger pixels follow the complete glove transform")

static func rig_contracts(rig: Node2D, expect: Callable) -> void:
	var weapon: Sprite2D = rig._gear_base_parts["weapon_r"]["node"]
	var ids: Array[String]
	ids.append("")
	for id: String in Gear._items:
		if Gear._items[id]["slot"] == "weapon":
			ids.append(id)
	var clips: Array[String]
	for clip: String in CARRY:
		clips.append(clip)
	for clip: String in USE:
		clips.append(clip)
	var poses: int = 0
	for id: String in ids:
		rig.apply_pose("rest", 0.0)
		rig.apply_gear({} if id.is_empty() else Gear.ops_for_facing({"weapon": id, "offhand": "ward_kite"}, rig.facing))
		var motion: String = "sword" if id.is_empty() else str(Gear._items[id]["motion"])
		for clip: String in clips:
			for phase: float in [0.0, 0.14, 0.42, 0.94, 1.0]:
				rig.apply_pose(clip, phase)
				expect.call(weapon.z_index == depth(rig.facing, clip, motion, phase), "Carry/use body depth: " + rig.facing + "/" + id + "/" + clip)
				overlays(rig, expect)
				var before: Dictionary = {}
				for bone: String in rig.bones:
					before[bone] = rig.bones[bone].transform
				# Depth changes alone never touch a sampled bone or landmark.
				rig._update_weapon_depth("rest")
				rig._update_weapon_depth(clip)
				for bone: String in before:
					expect.call(before[bone] == rig.bones[bone].transform, "Layer changes preserve every legacy bone transform")
				poses += 1
		rig.apply_pose("shoot" if motion in ["bow", "repeater"] else "attack", 0.42)
		rig.hide()
		expect.call(weapon.z_index == depth(rig.facing, "rest", motion), "Direct rig hide restores carry depth")
		overlays(rig, expect)
		# Re-equipping a hidden rig must not revive its previous use depth.
		rig.apply_gear({} if id.is_empty() else Gear.ops_for_facing({"weapon": id}, rig.facing))
		expect.call(weapon.z_index == depth(rig.facing, "rest", motion), "Hidden gear changes stay at carry depth")
		rig.show()
		# Clear an active use pose, not just an already-carried weapon.
		rig.apply_pose("shoot_bow" if motion == "bow" else "shoot_repeater" if motion == "repeater" else "attack", 0.42)
		rig.apply_gear({})
		expect.call(weapon.z_index == depth(rig.facing, "rest", "sword"), "Clearing any active weapon restores default carry depth")
		overlays(rig, expect)
	# Registry overrides still apply to other sprites and meshes. The weapon
	# body is governed by the clip, not an old replacement override.
	rig.apply_pose("rest", 0.0)
	var ops: Dictionary = Gear.ops_for_facing({"weapon": "war_maul", "boots": "ironshod_sabatons"}, rig.facing)
	for op: Dictionary in ops["replace"]:
		op["z_index"] = 12
		if op["part"] == "weapon_r":
			op["offset"] = [111, 139]
	rig.apply_gear(ops)
	overlays(rig, expect)
	for op: Dictionary in ops["replace"]:
		var wanted: int = depth(rig.facing, "rest", "heavy") if op["part"] == "weapon_r" else 12
		expect.call(rig._gear_base_parts[op["part"]]["node"].z_index == wanted, "Clip policy owns the weapon; replacement z still works on other sprites/meshes")
	for op: Dictionary in ops["replace"]:
		op.erase("z_index")
	rig.apply_gear(ops)
	for base: Dictionary in rig._gear_base_parts.values():
		expect.call(base["node"].z_index == base["z_index"], "A replacement without z restores the base depth")
	rig.apply_gear({})
	overlays(rig, expect)
	for base: Dictionary in rig._gear_base_parts.values():
		expect.call(base["node"].z_index == base["z_index"], "Clearing restores all base depths")
	expect.call(rig.bones["weapon_r"].get_child_count() == 2 and rig.bones["hand_r"].get_child_count() == 4, "Repeated gear switches retain exactly one grip and finger sprite")
	print("PROTAGONIST GEAR LAYERS %s: %d weapons, %d unchanged poses; depth/overlays/offsets/clear checked" % [rig.facing, ids.size(), poses])

static func renderer_contracts(tree: SceneTree, expect: Callable) -> void:
	var renderer := Renderer.new()
	tree.root.add_child(renderer)
	await tree.process_frame
	renderer.set_process(false)
	for weapon: String in ["training_sword", "hunting_spear", "dawnlight_censer", "stormstring_bow", "windlass_repeater"]:
		renderer.set_gear({"weapon": weapon, "offhand": "parrying_dagger"})
		for direction: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			for reduced: bool in [false, true]:
				for clip: String in ["walk", "attack", "block", "shoot", "cast", "death"]:
					renderer.present({"clip": clip, "phase": 0.42, "direction": direction}, reduced)
					var snapshot: Dictionary = renderer.snapshot()
					for facing: String in ["front", "rear"]:
						var rig: Node2D = renderer.rigs[facing]
						var shown: String = str(snapshot["clip"]) if snapshot["facing"] == facing else "rest"
						expect.call(rig._gear_base_parts["weapon_r"]["node"].z_index == depth(facing, shown, Gear.weapon_motion({"weapon": weapon}), float(snapshot["phase"])), "Shown clip and hidden rig determine depth, including reduced stills and reflection")
						overlays(rig, expect)
				# A generic rear shot hides both the low body and its high grip;
				# switching to the front resets the previously shown rear rig.
				renderer.present({"clip": "shoot", "phase": 0.42, "direction": direction}, reduced)
				renderer.present({"clip": "idle", "phase": 0.0}, reduced)
				for facing: String in ["front", "rear"]:
					expect.call(renderer.rigs[facing]._gear_base_parts["weapon_r"]["node"].z_index == depth(facing, "rest", "sword"), "Shot exit restores carry on both visible and hidden rigs")
					overlays(renderer.rigs[facing], expect)
	renderer.free()
	_check_enemy_layers(tree, expect)
	print("PROTAGONIST GEAR LAYER PRESENTATION: reduced/mirrored/shot exit/hidden rig checked")

static func _check_enemy_layers(tree: SceneTree, expect: Callable) -> void:
	for path: String in ["res://scripts/crawler_cutout/rig.gd", "res://scripts/frostglass_lancer_cutout/rig.gd"]:
		var script: Script = load(path)
		for facing: String in ["front", "rear"]:
			var rig: Node2D = script.new()
			if not rig.has_facing(facing):
				rig.free()
				continue
			rig.facing = facing
			tree.root.add_child(rig)
			expect.call(rig.load_rig() and rig._gear_layers == null, "Shared-loader enemy rigs do not acquire protagonist layers")
			var authored: Dictionary = {}
			for part: Dictionary in rig.layout["parts"]:
				authored[str(part["name"])] = int(part.get("z_index", 0))
			for mesh: Dictionary in rig.layout.get("joint_meshes", []):
				authored[str(mesh.get("replaces_part", ""))] = int(mesh.get("z_index", 3))
			for name: String in rig._gear_base_parts:
				expect.call(rig._gear_base_parts[name]["node"].z_index == authored[name], "Shared-loader enemies retain every authored sprite and mesh depth")
			rig.free()
	print("PROTAGONIST GEAR LAYER ENEMY ISOLATION: checked")

extends RefCounted
## Rear ordering and authored carry axes, including the pending steep paint's
## landmarks in memory. No generated textures or rules-layer dependencies.
const Gear = preload("res://scripts/protagonist_cutout/gear_visuals.gd")
const Rig = preload("res://scripts/protagonist_cutout/rig.gd")
const Motion = preload("res://scripts/protagonist_cutout/motion.gd")
const Reaction = preload("res://scripts/cutout_reaction_playback.gd")
const CARRY_WEAPONS: PackedStringArray = ["hunting_spear", "tourney_lance", "hookspine_halberd", "stormstring_bow"]
const CARRY_CLIPS: PackedStringArray = ["rest", "idle", "walk", "block", "block_shield", "hit", "death"]

static func run(tree: SceneTree, expect: Callable) -> void:
	Gear.resolve({})
	_check_z_validation(expect)
	for facing: String in ["front", "rear"]:
		var rig := Rig.new()
		rig.facing = facing
		tree.root.add_child(rig)
		expect.call(rig.load_rig(), "Carry/order rig loads: " + facing)
		var shared: Dictionary = rig.layout
		var original: Dictionary = shared.duplicate(true)
		_check_depth(rig, expect)
		_check_legacy(rig, expect)
		for weapon: String in CARRY_WEAPONS:
			for steep: bool in [false, true]:
				var ops: Dictionary = Gear.ops_for_facing({"weapon": weapon, "offhand": "ward_kite"}, facing)
				if steep:
					_steep_landmarks(ops, facing)
				rig.apply_gear(ops)
				_check_carry(rig, weapon, steep, expect)
				_check_action(rig, weapon, steep, expect)
				expect.call(shared == original, "Carry metadata never changes the cached sword layout")
			rig.apply_gear({})
			expect.call(is_same(rig.layout, shared), "Clear restores the exact shared layout and removes carry metadata")
		rig.free()
	print("PROTAGONIST GEAR CARRY CONTRACTS: checked")

static func _check_z_validation(expect: Callable) -> void:
	var layouts: Dictionary = {}
	for facing: String in ["front", "rear"]:
		layouts[facing] = JSON.parse_string(FileAccess.get_file_as_string(Gear.BASE.path_join(facing + ".json")))
	var entry: Dictionary = Gear._items["war_maul"].duplicate(true)
	for facing: String in ["front", "rear"]:
		for op: Dictionary in entry["facings"][facing]["replace"]:
			op.erase("z_index")
	expect.call(Gear._valid_entry(entry, layouts), "Replacement z remains optional")
	for value: int in [RenderingServer.CANVAS_ITEM_Z_MIN, 5, 66, RenderingServer.CANVAS_ITEM_Z_MAX]:
		entry["facings"]["rear"]["replace"][0]["z_index"] = value
		expect.call(Gear._valid_entry(entry, layouts), "Replacement accepts integer canvas z: " + str(value))
	entry["facings"]["rear"]["replace"][0]["z_index"] = 5.0
	expect.call(Gear._valid_entry(entry, layouts), "JSON's integral float z is valid")
	for value: Variant in [null, "5", false, 5.5, RenderingServer.CANVAS_ITEM_Z_MIN - 1, RenderingServer.CANVAS_ITEM_Z_MAX + 1]:
		entry["facings"]["rear"]["replace"][0]["z_index"] = value
		expect.call(not Gear._valid_entry(entry, layouts), "Replacement rejects invalid z: " + str(value))

static func _check_depth(rig: Node2D, expect: Callable) -> void:
	var wanted: int = 5 if rig.facing == "rear" else 66
	var weapon: Node2D = rig._gear_base_parts["weapon_r"]["node"]
	var crossbow: Node2D = rig._gear_base_parts["crossbow"]["node"]
	expect.call(weapon.z_index == wanted and crossbow.z_index == wanted, "Default sword/crossbow depth: " + rig.facing)
	var clips: Array = Motion.clip_specs().keys()
	clips.append("rest")
	var count: int = 0
	for id: String in Gear._items:
		if Gear._items[id]["slot"] != "weapon":
			continue
		rig.apply_gear(Gear.ops_for_facing({"weapon": id, "offhand": "ward_kite"}, rig.facing))
		expect.call(weapon.z_index == wanted, "Every main-hand weapon uses facing depth: " + rig.facing + "/" + id)
		if rig.facing == "rear":
			expect.call(weapon.z_index < rig._gear_attachments[0].z_index and weapon.z_index < rig._gear_base_parts["arm_r"]["node"].z_index, "Rear weapon is below the offhand and far arm")
		for clip: String in clips:
			for reduced: bool in [false, true]:
				for phase: float in [0.0, 0.14, 0.42, 0.94, 1.0]:
					Reaction.apply_pose(rig, clip, phase, reduced)
					expect.call(weapon.z_index == wanted and crossbow.z_index == wanted, "Clips/reduced motion never change weapon z: " + clip)
		count += 1
	# Exercise an actual override and both reset paths, independent of whether
	# the owner has already supplied explicit rear z entries in the registry.
	var ops: Dictionary = Gear.ops_for_facing({"weapon": "war_maul", "boots": "ironshod_sabatons"}, rig.facing)
	for op: Dictionary in ops["replace"]:
		op["z_index"] = 12
	rig.apply_gear(ops)
	for op: Dictionary in ops["replace"]:
		expect.call(rig._gear_base_parts[op["part"]]["node"].z_index == 12, "Replacement override applies to sprites and skinned parts")
	for op: Dictionary in ops["replace"]:
		op.erase("z_index")
	rig.apply_gear(ops)
	for base: Dictionary in rig._gear_base_parts.values():
		expect.call(base["node"].z_index == base["z_index"], "Replacement without z restores the base instead of retaining an old override")
	for op: Dictionary in ops["replace"]:
		op["z_index"] = 12
	rig.apply_gear(ops)
	rig.apply_gear({})
	for base: Dictionary in rig._gear_base_parts.values():
		expect.call(base["node"].z_index == base["z_index"], "Clearing gear restores every base z")
	print("PROTAGONIST GEAR DEPTH %s: %d weapons, sword/crossbow z=%d, overrides/reset checked" % [rig.facing, count, wanted])

static func _steep_landmarks(ops: Dictionary, facing: String) -> void:
	var grip: Dictionary = ops["weapon_grip"]
	var original: Vector2 = Motion._gear_vector(grip["assembled"])
	var tip_length: float = original.distance_to(Motion._gear_vector(grip["tip"]))
	var butt_length: float = original.distance_to(Motion._gear_vector(grip["pommel"]))
	# Also vary the grip: a hardcoded sword-pivot rotation would drift here.
	var assembled: Vector2 = original + Vector2(3 if facing == "rear" else -3, 2)
	var axis: Vector2 = (Vector2(0.30, -0.95) if facing == "rear" else Vector2(-0.30, -0.95)).normalized()
	grip["assembled"] = _point(assembled)
	grip["tip"] = _point(assembled + axis * tip_length)
	grip["pommel"] = _point(assembled - axis * butt_length)

static func _point(value: Vector2) -> Array:
	return [value.x, value.y]

static func _uncarried(layout: Dictionary) -> Dictionary:
	var result: Dictionary = layout.duplicate()
	result.erase("weapon_carry")
	return result

static func _axis(pose: Dictionary, layout: Dictionary) -> Vector2:
	return Motion._world_transform(pose, layout, "weapon_r").basis_xform(Motion._gear_axis(layout)).normalized()

static func _grip_error(pose: Dictionary, layout: Dictionary) -> float:
	var grip: Vector2 = Motion._gear_vector(layout["weapon_grip"]["assembled"])
	var palm: Vector2 = Motion._world_transform(pose, layout, "hand_r") * (grip - Motion._joint_position(layout, "hand_r"))
	var weapon: Vector2 = Motion._world_transform(pose, layout, "weapon_r") * (grip - Motion._joint_position(layout, "weapon_r"))
	return palm.distance_to(weapon)

static func _check_carry(rig: Node2D, weapon: String, steep: bool, expect: Callable) -> void:
	var before: Dictionary = _uncarried(rig.layout)
	var delta: float = wrapf(Motion._gear_axis(rig.layout).angle() - (rig.layout["weapon_carry"]["sword_axis"] as Vector2).angle(), -PI, PI)
	var max_grip: float = 0.0
	var max_axis: float = 0.0
	for clip: String in CARRY_CLIPS:
		for sample: int in range(201):
			var phase: float = float(sample) / 200.0
			var pose: Dictionary = Motion.sample_pose(clip, phase, rig.layout, rig.facing)
			var old: Dictionary = Motion.sample_pose(clip, phase, before, rig.facing)
			max_grip = maxf(max_grip, _grip_error(pose, rig.layout))
			max_axis = maxf(max_axis, _axis(pose, rig.layout).distance_to(_axis(old, before)))
			expect.call(absf(float(pose["hand_r"]["rotation"]) - float(old["hand_r"]["rotation"]) - delta * 0.15) < 0.00001, "Carry turns the glove by 15% of the landmark/sword delta: " + clip)
			for bone: String in pose:
				if bone not in ["hand_r", "weapon_r"]:
					expect.call(pose[bone] == old[bone], "Carry preserves body, wrists and foot targets: " + clip + "/" + bone)
			# The painted steep axis follows the original gait/reaction attitude;
			# it must not receive the sword-to-pole delta a second time.
			if clip in ["rest", "idle"]:
				expect.call(_axis(pose, rig.layout).distance_to(Motion._gear_axis(rig.layout)) < 0.001, "Rest/idle read the painted landmark direction")
	expect.call(max_grip < 0.001 and max_axis < 0.001, "Carry keeps the authored axis and grip within .001px through idle/walk/reactions")
	print("PROTAGONIST GEAR CARRY %s/%s/%s: grip_error=%.6f axis_error=%.6f glove_delta=%.6f" % [rig.facing, weapon, "steep" if steep else "authored", max_grip, max_axis, delta * 0.15])

static func _check_action(rig: Node2D, weapon: String, steep: bool, expect: Callable) -> void:
	var bow: bool = weapon == "stormstring_bow"
	var clip: String = "shoot_bow" if bow else "attack_thrust"
	var max_grip: float = 0.0
	for sample: int in range(201):
		var phase: float = float(sample) / 200.0
		var pose: Dictionary = Motion.sample_pose(clip, phase, rig.layout, rig.facing)
		max_grip = maxf(max_grip, _grip_error(pose, rig.layout))
		if not bow and phase >= 0.20 and phase <= 0.62:
			var line: Vector2 = (Vector2(0.894, -0.447) if rig.facing == "rear" else Vector2(-0.894, 0.447)).normalized()
			expect.call(_axis(pose, rig.layout).distance_to(line) < 0.001, "Steep thrust lowers to level by .20 and stays on the cock/drive line")
		if bow and phase >= 0.24 and phase <= 0.62:
			var aim: Vector2 = preload("res://scripts/protagonist_cutout/full_gear_motion.gd").aim_for_facing(rig.facing)
			expect.call(absf(_axis(pose, rig.layout).dot(aim)) < 0.001 and _axis(pose, rig.layout).y < 0, "Steep bow raises perpendicular to aim with its upper limb up")
	var rest: Dictionary = Motion.sample_pose("rest", 0.0, rig.layout, rig.facing)
	for phase: float in [0.0, 1.0]:
		var pose: Dictionary = Motion.sample_pose(clip, phase, rig.layout, rig.facing)
		expect.call(_axis(pose, rig.layout).distance_to(Motion._gear_axis(rig.layout)) < 0.001, "Thrust/bow returns to the authored steep rest axis by 1.0")
		expect.call(pose["hand_r"] == rest["hand_r"] and pose["weapon_r"] == rest["weapon_r"], "Action endpoints return to the complete carry grip without a wrist snap")
	expect.call(max_grip < 0.001, "Carry/action transition keeps the grip within .001px")
	print("PROTAGONIST GEAR CARRY ACTION %s/%s/%s: grip_error=%.6f rest/recovery checked" % [rig.facing, clip, "steep" if steep else "authored", max_grip])

static func _check_legacy(rig: Node2D, expect: Callable) -> void:
	var clips: Array = Motion.clip_specs().keys()
	clips.append("rest")
	var comparisons: int = 0
	for id: String in Gear._items:
		if Gear._items[id]["slot"] != "weapon" or Gear._items[id]["motion"] not in ["sword", "heavy", "stab"]:
			continue
		rig.apply_gear(Gear.ops_for_facing({"weapon": id}, rig.facing))
		expect.call(not rig.layout.has("weapon_carry"), "Legacy weapons do not acquire carry metadata: " + id)
		for clip: String in clips:
			if clip in ["attack_thrust", "attack_lash", "shoot_bow", "shoot_repeater"]:
				continue
			for phase: float in [0.0, 0.14, 0.30, 0.36, 0.42, 0.54, 0.62, 0.80, 0.94, 1.0]:
				var old: Dictionary = Motion._sample_pose(clip, phase, rig.layout, rig.facing)
				expect.call(Motion.sample_pose(clip, phase, rig.layout, rig.facing) == old, "Legacy sword/heavy/stab poses bypass carry unchanged: " + id + "/" + clip)
				comparisons += 1
	print("PROTAGONIST GEAR CARRY LEGACY %s: %d unchanged poses" % [rig.facing, comparisons])

extends RefCounted

const Motion = preload("res://scripts/protagonist_cutout/motion.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const Rig = preload("res://scripts/protagonist_cutout/rig.gd")
const Gear = preload("res://scripts/protagonist_cutout/gear_visuals.gd")
const Renderer = preload("res://scripts/protagonist_cutout/renderer.gd")
const Reaction = preload("res://scripts/cutout_reaction_playback.gd")
const Fx = preload("res://scripts/attack_fx_library.gd")

static func run(tree: SceneTree, expect: Callable) -> void:
	for facing: String in ["front", "rear"]:
		var rig := Rig.new()
		rig.facing = facing
		tree.root.add_child(rig)
		expect.call(rig.load_rig(), "Motion rig loads: " + facing)
		_check_layout(rig, expect)
		for clip: String in ["attack_heavy", "attack_stab", "block_shield"]:
			var weapon: String = "war_maul" if clip == "attack_heavy" else "sawtooth_knife" if clip == "attack_stab" else "training_sword"
			rig.apply_gear(Gear.ops_for_facing({"weapon": weapon, "offhand": "splintered_shield"}, facing))
			_check_support_and_lengths(rig.layout, facing, clip, expect)
			if clip == "attack_heavy":
				_check_heavy(rig.layout, facing, expect)
			if clip == "attack_stab":
				_check_stab(rig.layout, facing, expect)
			if clip == "block_shield":
				rig.apply_pose(clip, 0.25)
				var shield: Sprite2D = rig._gear_attachments[0]
				var basis: Transform2D = rig.global_transform.affine_inverse() * shield.global_transform
				expect.call(absf(basis.get_rotation()) <= 0.15001, "Shield guard stays upright about its painted centre: " + facing)
		_check_attachment_basis(rig, expect)
		rig.free()
	await _check_renderer(tree, expect)
	_check_timing(expect)
	await preload("res://tests/suites/protagonist_full_gear_motion_suite.gd").run(tree, expect)
	print("PROTAGONIST GEAR MOTION CONTRACTS: checked")

static func _check_layout(rig: Node, expect: Callable) -> void:
	var shared: Dictionary = rig.layout
	var before: Dictionary = shared.duplicate(true)
	var ops: Dictionary = Gear.ops_for_facing({"weapon": "war_maul"}, rig.facing)
	var authored: Dictionary = ops["weapon_grip"].duplicate(true)
	rig.apply_gear(ops)
	expect.call(not is_same(rig.layout, shared) and rig.layout["weapon_grip"] == authored, "Weapon landmarks use a per-rig layout copy: " + rig.facing)
	ops["weapon_grip"]["tip"][0] += 50
	expect.call(rig.layout["weapon_grip"] == authored and shared == before, "Gear never mutates shared layout or retains mutable input landmarks: " + rig.facing)
	var other := Rig.new()
	other.facing = rig.facing
	rig.get_parent().add_child(other)
	expect.call(other.load_rig() and is_same(other.layout, shared) and other.layout == before, "Another rig sees the unchanged cached source: " + rig.facing)
	other.free()
	rig.apply_gear({})
	expect.call(is_same(rig.layout, shared) and rig.layout == before, "No landmark override restores the shared base unchanged: " + rig.facing)

static func _check_support_and_lengths(layout: Dictionary, facing: String, clip: String, expect: Callable) -> void:
	var max_foot_error: float = 0.0
	var max_length_error: float = 0.0
	var max_basis_error: float = 0.0
	var max_boot_error: float = 0.0
	for sample: int in range(201):
		var phase: float = float(sample) / 200.0
		var pose: Dictionary = Motion.sample_pose(clip, phase, layout, facing)
		for side: String in ["r", "l"]:
			var foot: Transform2D = Motion._world_transform(pose, layout, "foot_" + side)
			var target: Vector2 = Motion._joint_position(layout, "foot_" + side)
			if clip == "attack_stab" and side == "r":
				target += _stab_step_offset(phase, facing)
			max_foot_error = maxf(max_foot_error, foot.origin.distance_to(target))
			if clip == "attack_stab":
				max_boot_error = maxf(max_boot_error, maxf(foot.x.distance_to(Vector2.RIGHT), foot.y.distance_to(Vector2.DOWN)))
			for chain: Array in [["arm_", "forearm_", "hand_"], ["thigh_", "shin_", "foot_"]]:
				for index: int in range(2):
					var start_name: String = str(chain[index]) + side
					var end_name: String = str(chain[index + 1]) + side
					var start: Transform2D = Motion._world_transform(pose, layout, start_name)
					var end: Transform2D = Motion._world_transform(pose, layout, end_name)
					var painted: float = Motion._joint_position(layout, start_name).distance_to(Motion._joint_position(layout, end_name))
					max_length_error = maxf(max_length_error, absf(start.origin.distance_to(end.origin) - painted))
					max_basis_error = maxf(max_basis_error, maxf(absf(start.x.length() - 1.0), absf(start.y.length() - 1.0)))
			for terminal: String in ["hand_", "foot_"]:
				var world: Transform2D = Motion._world_transform(pose, layout, terminal + side)
				max_basis_error = maxf(max_basis_error, maxf(absf(world.x.length() - 1.0), absf(world.y.length() - 1.0)))
		expect.call(not bool(pose["crossbow_r"]["visible"]), "Gear melee/guard does not reveal the crossbow")
	expect.call(max_foot_error < 0.15, "%s/%s feet follow their support targets (max %.6f px)" % [facing, clip, max_foot_error])
	expect.call(max_length_error < 0.15 and max_basis_error < 0.001, "%s/%s preserves painted lengths and rigid terminals (length %.6f, basis %.6f)" % [facing, clip, max_length_error, max_basis_error])
	if clip == "attack_stab":
		expect.call(max_boot_error < 0.001, "Stab boots retain their rigid bind basis throughout the step: " + facing)
	print("GEAR MOTION %s/%s: foot_error=%.6f length_error=%.6f basis_error=%.6f" % [facing, clip, max_foot_error, max_length_error, max_basis_error])

static func _stab_step_offset(phase: float, facing: String) -> Vector2:
	var line := Vector2(0.894, -0.447) if facing == "rear" else Vector2(-0.894, 0.447)
	var advance: float = smoothstep(0.30, 0.40, phase) * (1.0 - smoothstep(0.62, 0.88, phase))
	var lift: float = smoothstep(0.30, 0.35, phase) * (1.0 - smoothstep(0.35, 0.40, phase)) \
		+ smoothstep(0.62, 0.75, phase) * (1.0 - smoothstep(0.75, 0.88, phase))
	return line.normalized() * 8.0 * advance + Vector2(0, -2.0 * lift)

static func _weapon_direction(pose: Dictionary, layout: Dictionary) -> Vector2:
	var weapon: Transform2D = Motion._world_transform(pose, layout, "weapon_r")
	return weapon.basis_xform(Motion._gear_axis(layout)).normalized()

static func _check_heavy(layout: Dictionary, facing: String, expect: Callable) -> void:
	var max_grip_error: float = 0.0
	for sample: int in range(201):
		var phase: float = float(sample) / 200.0
		var pose: Dictionary = Motion.sample_pose("attack_heavy", phase, layout, facing)
		var wrist: Transform2D = Motion._world_transform(pose, layout, "hand_r")
		var weapon: Transform2D = Motion._world_transform(pose, layout, "weapon_r")
		var grip: Vector2 = Motion._gear_vector(layout["weapon_grip"]["assembled"])
		var palm: Vector2 = wrist * (grip - Motion._joint_position(layout, "hand_r"))
		var registered: Vector2 = weapon * (grip - Motion._joint_position(layout, "weapon_r"))
		max_grip_error = maxf(max_grip_error, registered.distance_to(palm))
	expect.call(max_grip_error < 0.001, "The right fist alone registers on the maul grip throughout the slam: " + facing)
	var front_keys: Array = [[0.12, Vector2(106, 118)], [0.30, Vector2(104, 78)], [0.36, Vector2(104, 78)],
		[0.42, Vector2(96, 134)], [0.48, Vector2(96, 134)], [0.58, Vector2(96, 134)], [0.72, Vector2(94, 130)]]
	var rear_keys: Array = [[0.12, Vector2(145, 114)], [0.30, Vector2(150, 80)], [0.36, Vector2(150, 80)],
		[0.42, Vector2(155, 130)], [0.48, Vector2(155, 130)], [0.58, Vector2(155, 130)], [0.72, Vector2(157, 126)]]
	var keys: Array = rear_keys if facing == "rear" else front_keys
	for key: Array in keys:
		var pose: Dictionary = Motion.sample_pose("attack_heavy", key[0], layout, facing)
		var actual: Vector2 = Motion._world_transform(pose, layout, "hand_r").origin
		var shift: float = actual.distance_to(key[1])
		expect.call(shift < 0.15, "One-handed heavy retains its requested wrist at %.2f: %s" % [key[0], facing])
		print("GEAR HEAVY REACH %s %.2f: wrist=%s shift=%.6f grip_error=%.6f" % [facing, key[0], actual, shift, max_grip_error])
	var contact: Dictionary = Motion.sample_pose("attack_heavy", 0.42, layout, facing)
	var contact_dir := Vector2(0.60, 0.80) if facing == "rear" else Vector2(-0.60, 0.80)
	expect.call(_weapon_direction(contact, layout).distance_to(contact_dir) < 0.001, "Heavy lands its slam at .42: " + facing)
	expect.call(is_equal_approx(float(contact["forearm_l"]["rotation"]), 0.12 if facing == "rear" else -0.12), "The free left forearm braces its shield at contact: " + facing)
	var recovered: Dictionary = Motion.sample_pose("attack_heavy", 0.80, layout, facing)
	expect.call(is_zero_approx(float(recovered["forearm_l"]["rotation"])), "The shield brace recovers by .80: " + facing)
	for phase: float in [0.30, 0.36]:
		var pose: Dictionary = Motion.sample_pose("attack_heavy", phase, layout, facing)
		# The rear apex sits lower so the hammer head stays below the board HP bar.
		var apex := Vector2(0.60, -0.80) if facing == "rear" else Vector2(-0.35, -0.94)
		expect.call(_weapon_direction(pose, layout).distance_to(apex.normalized()) < 0.001, "Heavy apex still aims beside the head: " + facing)
		var weapon: Transform2D = Motion._world_transform(pose, layout, "weapon_r")
		var tip: Vector2 = weapon * (Motion._gear_vector(layout["weapon_grip"]["tip"]) - Motion._joint_position(layout, "weapon_r"))
		var head_bounds: Rect2 = _head_alpha_bounds(pose, layout)
		var clearance: float = tip.x - head_bounds.end.x if facing == "rear" else head_bounds.position.x - tip.x
		expect.call(head_bounds.has_area() and clearance >= 8.0, "Heavy hammer head clears the posed hair bounds by at least 8px at %.2f: %s (%.6fpx)" % [phase, facing, clearance])
		print("GEAR HEAVY APEX %s %.2f: tip=%s hair_clearance=%.6f" % [facing, phase, tip, clearance])
	var downstroke: Dictionary = Motion.sample_pose("attack_heavy", 0.39, layout, facing)
	var chop_direction: Vector2 = _weapon_direction(downstroke, layout)
	expect.call(chop_direction.x > 0.98 if facing == "rear" else chop_direction.x < -0.98, "Heavy downstroke passes through horizontal on the weapon side: " + facing)

static func _head_alpha_bounds(pose: Dictionary, layout: Dictionary) -> Rect2:
	for part: Dictionary in layout["parts"]:
		if str(part["name"]) != "head":
			continue
		var texture: Texture2D = AssetLoader.load_texture_source_first(str(part["file"]))
		var image: Image = AssetLoader.texture_source_image(texture)
		if image == null:
			return Rect2()
		var alpha: Rect2 = Rect2(image.get_used_rect())
		if not alpha.has_area():
			return Rect2()
		# Source pixels are offset from the head joint, then inherit its posed
		# transform. The enclosing rectangle conservatively includes all hair.
		var offset: Vector2 = Motion._gear_vector(part["offset"]) - Motion._joint_position(layout, str(part["bone"]))
		var head: Transform2D = Motion._world_transform(pose, layout, str(part["bone"]))
		var bounds := Rect2(head * (alpha.position + offset), Vector2.ZERO)
		for corner: Vector2 in [alpha.position + Vector2(alpha.size.x, 0), alpha.end, alpha.position + Vector2(0, alpha.size.y)]:
			bounds = bounds.expand(head * (corner + offset))
		return bounds
	return Rect2()

static func _check_stab(layout: Dictionary, facing: String, expect: Callable) -> void:
	var direction: float = -1.0 if facing == "rear" else 1.0
	var line: Vector2 = (Vector2(0.894, -0.447) if facing == "rear" else Vector2(-0.894, 0.447)).normalized()
	for phase: float in [0.30, 0.42, 0.54]:
		var pose: Dictionary = Motion.sample_pose("attack_stab", phase, layout, facing)
		var root: Vector2 = Motion._world_transform(pose, layout, "root").origin - Motion._joint_position(layout, "root")
		var root_target: Vector2 = Vector2(direction * 2.0, 0) if phase == 0.30 else line * 10.0
		expect.call(root.distance_to(root_target) < 0.0001, "Stab root retains the cock and commits to the 10px lunge: " + facing)
		expect.call(is_equal_approx(float(pose["torso"]["rotation"]), direction * (0.06 if phase == 0.30 else -0.10)), "Stab torso commits to its new key: " + facing)
		var target: Vector2
		if facing == "rear":
			target = Vector2(160, 135) if phase == 0.30 else Vector2(182 if phase == 0.42 else 181, 112)
		else:
			target = Vector2(100, 126) if phase == 0.30 else Vector2(66 if phase == 0.42 else 67, 121)
		expect.call(Motion._world_transform(pose, layout, "hand_r").origin.distance_to(target) < 0.15, "Stab wrist stays as authored: " + facing)
		if phase != 0.30:
			var drop: float = (pose["hips"]["position"] as Vector2).y - Motion._local_position(layout, "hips").y
			print("GEAR STAB KEY %s %.2f: hips_drop=%.6f" % [facing, phase, drop])
			var expected_drop: float = 7.822047 if facing == "rear" else 0.0
			expect.call(absf(drop - expected_drop) < 0.0001, "Stab hips use only the minimum planted trailing-leg correction: " + facing)
	# Explicit landing, hold and recovery keys, independent of the sampled curve.
	for key: Vector3 in [Vector3(0.30, 0, 0), Vector3(0.35, 4, -2), Vector3(0.40, 8, 0),
			Vector3(0.42, 8, 0), Vector3(0.54, 8, 0), Vector3(0.56, 8, 0), Vector3(0.62, 8, 0),
			Vector3(0.75, 4, -2), Vector3(0.88, 0, 0), Vector3(0.90, 0, 0)]:
		var pose: Dictionary = Motion.sample_pose("attack_stab", key.x, layout, facing)
		var right: Transform2D = Motion._world_transform(pose, layout, "foot_r")
		var target: Vector2 = Motion._joint_position(layout, "foot_r") + line * key.y + Vector2(0, key.z)
		expect.call(right.origin.distance_to(target) < 0.15, "Stab leading foot lands, holds and returns at %.2f: %s" % [key.x, facing])
	for key: Vector2 in [Vector2(0.48, 10), Vector2(0.90, 0)]:
		var pose: Dictionary = Motion.sample_pose("attack_stab", key.x, layout, facing)
		var root: Vector2 = Motion._world_transform(pose, layout, "root").origin - Motion._joint_position(layout, "root")
		expect.call(root.distance_to(line * key.y) < 0.0001, "Stab root holds then returns by .90: " + facing)

static func _check_attachment_basis(rig: Node2D, expect: Callable) -> void:
	rig.apply_gear(Gear.ops_for_facing(Gear.DEFAULTS, rig.facing))
	for mirrored: bool in [false, true]:
		rig.scale = Vector2(-1, 1) if mirrored else Vector2.ONE
		for clip: String in ["cast", "shoot"]:
			rig.apply_pose(clip, 0.42)
			for shield: Sprite2D in rig.get("_gear_attachments"):
				var world: Transform2D = shield.global_transform
				expect.call(absf(world.x.length() - 1.0) < 0.0001 and absf(world.y.length() - 1.0) < 0.0001 and absf(world.x.dot(world.y)) < 0.0001, "Rigid attachments reject bone scale/skew: " + rig.facing + "/" + clip)
				expect.call(is_equal_approx(world.determinant(), -1.0 if mirrored else 1.0), "Attachment retains effective (+/-1, 1) scale and reflection")
		# Interrupt a foreshortened pose: the final reaction blend must also be
		# compensated, including the first frame with blend weight zero.
		Reaction.apply_pose(rig, "block_shield", 0.0, false)
		Reaction.apply_pose(rig, "block_shield", 0.04, false)
		for shield: Sprite2D in rig.get("_gear_attachments"):
			var world: Transform2D = shield.global_transform
			expect.call(absf(world.x.length() - 1.0) < 0.0001 and absf(world.y.length() - 1.0) < 0.0001, "Interrupted reaction also keeps attachments rigid")
	rig.scale = Vector2.ONE

static func _check_renderer(tree: SceneTree, expect: Callable) -> void:
	var renderer := Renderer.new()
	tree.root.add_child(renderer)
	await tree.process_frame
	renderer.set_process(false)
	for weapon: String in ["training_sword", "war_maul", "sawtooth_knife"]:
		renderer.set_gear({"weapon": weapon, "offhand": "splintered_shield"})
		var expected: String = "attack_heavy" if weapon == "war_maul" else "attack_stab" if weapon == "sawtooth_knife" else "attack"
		for delta: Vector2i in [Vector2i(0, 1), Vector2i(0, -1)]:
			renderer.present({"clip": "attack", "phase": 0.30, "direction": delta}, false)
			expect.call(renderer.snapshot()["clip"] == expected, "Renderer selects weapon clip: " + weapon)
			var phase: float = Renderer.attack_pose_phase(0.30) if expected == "attack" else 0.30
			expect.call(is_equal_approx(float(renderer.snapshot()["phase"]), phase), "Only sword retains its historical phase remap")
			renderer.present({"clip": "block", "phase": 0.25}, false)
			expect.call(renderer.snapshot()["clip"] == "block_shield", "Every one-handed loadout with a shield uses the shield reaction path")
			expect.call(renderer.snapshot()["facing"] == ("rear" if delta.y < 0 else "front"), "Guard retains interrupted action facing")
			renderer.present({"clip": "attack", "phase": 1.0, "direction": delta}, false)
			expect.call(renderer.snapshot()["clip"] == "idle" and renderer.snapshot()["facing"] == "front" and not renderer.snapshot()["mirrored"], "Every completed archetype returns to front idle")
			renderer.present({"clip": "attack", "phase": 0.42, "direction": delta}, true)
			expect.call(renderer.snapshot()["clip"] == "rest" and is_zero_approx(float(renderer.snapshot()["phase"])) and renderer.snapshot()["gear"] == Gear.signature({"weapon": weapon, "offhand": "splintered_shield"}), "Reduced motion keeps the neutral still with current gear")
	for offhand: String in ["parrying_dagger", ""]:
		renderer.set_gear({"weapon": "training_sword", "offhand": offhand})
		renderer.present({"clip": "block", "phase": 0.25}, false)
		expect.call(renderer.snapshot()["clip"] == "block", "A held or empty offhand retains the sword guard")
	renderer.free()

static func _check_timing(expect: Callable) -> void:
	var scene: Node = load("res://scripts/run_scene.gd").new()
	var specs: Dictionary = Motion.clip_specs()
	expect.call(specs["attack_heavy"]["frames"] == 43 and is_equal_approx(float(specs["attack_heavy"]["duration"]), 0.72), "Heavy authoring metadata is 43 frames / .72s")
	expect.call(specs["attack_stab"]["frames"] == 24 and is_equal_approx(float(specs["attack_stab"]["duration"]), 0.40), "Stab authoring metadata is 24 frames / .40s")
	expect.call(specs["block_shield"]["frames"] == 25 and is_equal_approx(float(specs["block_shield"]["duration"]), 0.30), "Shield guard metadata is 25 frames / .30s")
	for archetype: String in ["sword", "heavy", "stab"]:
		var effect: Dictionary = {"kind": "melee", "protagonist_melee": true, "protagonist_weapon_motion": archetype, "from": Vector2i(3, 3), "to": Vector2i(3, 4)}
		var frames: int = 43 if archetype == "heavy" else 24 if archetype == "stab" else 30
		expect.call(Fx.animation_frame_count(effect, 6, false) == frames and is_equal_approx(Fx.animation_frame_seconds(effect, 0.04, false), 1.0 / 60.0), "Melee clock follows archetype: " + archetype)
		expect.call(Fx.animation_frame_count(effect, 6, true) == 1 and is_zero_approx(Fx.animation_frame_seconds(effect, 0.04, true)), "Reduced melee keeps one zero-duration frame")
		expect.call(is_equal_approx(float(scene.call("_attack_feedback_start_progress", effect)), 0.42), "All melee damage boundaries remain .42")
		expect.call(float(scene.call("_attack_feedback_elapsed_seconds", effect, 0.419, frames, 1.0 / 60.0, false)) < 0.0 and is_zero_approx(float(scene.call("_attack_feedback_elapsed_seconds", effect, 0.42, frames, 1.0 / 60.0, false))), "Melee result switches at contact once")
		effect["kind"] = "aoe"
		effect["range"] = 0
		effect["to"] = effect["from"]
		expect.call(Fx.animation_frame_count(effect, 6, false) == 6 and is_equal_approx(Fx.animation_frame_seconds(effect, 0.04, false), 0.04), "Sweeps retain .24s for every archetype")
		expect.call(is_equal_approx(float(scene.call("_protagonist_attack_motion", effect, 0.38)["phase"]), 0.42), "Sweeps retime each archetype contact to .38")
	scene.free()

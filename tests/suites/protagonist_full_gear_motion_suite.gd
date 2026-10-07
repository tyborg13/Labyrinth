extends RefCounted

const Motion = preload("res://scripts/protagonist_cutout/motion.gd")
const Gear = preload("res://scripts/protagonist_cutout/gear_visuals.gd")
const Rig = preload("res://scripts/protagonist_cutout/rig.gd")
const Renderer = preload("res://scripts/protagonist_cutout/renderer.gd")
const Fx = preload("res://scripts/attack_fx_library.gd")
const LayerChecks = preload("res://tests/helpers/protagonist_gear_layer_checks.gd")

static func run(tree: SceneTree, expect: Callable) -> void:
	for facing: String in ["front", "rear"]:
		var rig := Rig.new()
		rig.facing = facing
		tree.root.add_child(rig)
		expect.call(rig.load_rig(), "Full-pass rig loads: " + facing)
		for weapon: String in ["hunting_spear", "tourney_lance", "hookspine_halberd", "galewhip", "stormstring_bow", "windlass_repeater"]:
			var motion: String = Gear.weapon_motion({"weapon": weapon})
			var clip: String = "shoot_" + motion if motion in ["bow", "repeater"] else "attack_" + motion
			expect.call(Gear.resolve({"weapon": weapon})["weapon"] == weapon, "Full-pass weapon resolves: " + weapon)
			for offhand: String in ["ward_kite", "parrying_dagger"]:
				rig.apply_gear(Gear.ops_for_facing({"weapon": weapon, "offhand": offhand}, facing))
				_check_rigid_motion(rig, clip, expect)
				_check_keys(rig.layout, facing, clip, expect)
		rig.free()
	await _check_renderer(tree, expect)
	_check_clocks(expect)
	print("PROTAGONIST FULL GEAR MOTION CONTRACTS: checked")
	print("PROTAGONIST ONE-ARM SHOT CONTRACTS: checked")

static func _check_rigid_motion(rig: Node2D, clip: String, expect: Callable) -> void:
	var max_grip: float = 0.0
	var max_length: float = 0.0
	var max_foot: float = 0.0
	var max_basis: float = 0.0
	for sample: int in range(201):
		var phase: float = float(sample) / 200.0
		var pose: Dictionary = Motion.sample_pose(clip, phase, rig.layout, rig.facing)
		if clip in ["shoot_bow", "shoot_repeater"]:
			var shoot: Dictionary = Motion.sample_pose("shoot", phase, rig.layout, rig.facing)
			for bone: String in ["arm_r", "forearm_r", "hand_r", "arm_l", "forearm_l", "hand_l"]:
				expect.call(pose[bone] == shoot[bone], "One-arm shot retains the exact crossbow aim/recoil and resting offhand through every phase: " + bone)
		var grip: Vector2 = Motion._gear_vector(rig.layout["weapon_grip"]["assembled"])
		var palm: Vector2 = Motion._world_transform(pose, rig.layout, "hand_r") * (grip - Motion._joint_position(rig.layout, "hand_r"))
		var weapon_grip: Vector2 = Motion._world_transform(pose, rig.layout, "weapon_r") * (grip - Motion._joint_position(rig.layout, "weapon_r"))
		max_grip = maxf(max_grip, palm.distance_to(weapon_grip))
		for side: String in ["r", "l"]:
			for chain: Array in [["arm_", "forearm_", "hand_"], ["thigh_", "shin_", "foot_"]]:
				for index: int in range(2):
					var a: String = chain[index] + side
					var b: String = chain[index + 1] + side
					var world: Transform2D = Motion._world_transform(pose, rig.layout, a)
					var painted: float = Motion._joint_position(rig.layout, a).distance_to(Motion._joint_position(rig.layout, b))
					max_length = maxf(max_length, absf(world.origin.distance_to(Motion._world_transform(pose, rig.layout, b).origin) - painted))
					max_basis = maxf(max_basis, maxf(absf(world.x.length() - 1), absf(world.y.length() - 1)))
			var foot: Transform2D = Motion._world_transform(pose, rig.layout, "foot_" + side)
			var target: Vector2 = Motion._joint_position(rig.layout, "foot_" + side)
			if clip == "attack_thrust" and side == "r":
				var line: Vector2 = (Vector2(0.894, -0.447) if rig.facing == "rear" else Vector2(-0.894, 0.447)).normalized()
				var step: float = smoothstep(0.30, 0.40, phase) * (1.0 - smoothstep(0.62, 0.88, phase))
				var lift: float = Motion._pulse(phase, 0.30, 0.35, 0.40) + Motion._pulse(phase, 0.62, 0.75, 0.88)
				target += line * 8.0 * step + Vector2(0, -2.0 * lift)
			max_foot = maxf(max_foot, foot.origin.distance_to(target))
			for terminal: String in ["hand_" + side, "foot_" + side]:
				var world: Transform2D = Motion._world_transform(pose, rig.layout, terminal)
				max_basis = maxf(max_basis, maxf(absf(world.x.length() - 1), absf(world.y.length() - 1)))
		rig.apply_pose(clip, phase)
		for attachment: Sprite2D in rig._gear_attachments:
			expect.call(attachment.visible, "Offhand stays visible throughout " + clip)
		expect.call(not rig.bones["crossbow_r"].visible and rig.bones["weapon_r"].visible, "Equipped full-pass weapon stays visible instead of the generic crossbow")
	expect.call(max_grip < 0.001, "%s/%s palm registration %.6fpx" % [rig.facing, clip, max_grip])
	expect.call(max_length < 0.001 and max_basis < 0.001, "%s/%s preserves painted lengths and rigid terminals" % [rig.facing, clip])
	expect.call(max_foot < 0.15, "%s/%s follows planted/stepping foot targets %.6fpx" % [rig.facing, clip, max_foot])
	print("FULL GEAR %s/%s: grip_error=%.6f length_error=%.6f foot_error=%.6f basis_error=%.6f" % [rig.facing, clip, max_grip, max_length, max_foot, max_basis])

static func _axis(pose: Dictionary, layout: Dictionary) -> Vector2:
	return Motion._world_transform(pose, layout, "weapon_r").basis_xform(Motion._gear_axis(layout)).normalized()

static func _check_keys(layout: Dictionary, facing: String, clip: String, expect: Callable) -> void:
	var rear: bool = facing == "rear"
	var line: Vector2 = (Vector2(0.894, -0.447) if rear else Vector2(-0.894, 0.447)).normalized()
	if clip == "attack_thrust":
		for sample: int in range(20, 63):
			var pose: Dictionary = Motion.sample_pose(clip, float(sample) / 100.0, layout, facing)
			expect.call(_axis(pose, layout).distance_to(line) < 0.001, "Pole is level along the attack line from .20 to .62")
		var lowered := Vector2(158, 128) if rear else Vector2(100, 130)
		for key: Vector2 in [Vector2(0.20, 0), Vector2(0.30, -8), Vector2(0.42, 18), Vector2(0.56, 18)]:
			var pose: Dictionary = Motion.sample_pose(clip, key.x, layout, facing)
			var wrist: Vector2 = Motion._world_transform(pose, layout, "hand_r").origin
			var shift: float = wrist.distance_to(lowered + line * key.y)
			expect.call(shift < 0.15, "Thrust wrist lowers, cocks 8px and drives 26px at %.2f" % key.x)
			print("FULL GEAR THRUST REACH %s %.2f: wrist=%s shift=%.6f" % [facing, key.x, wrist, shift])
		var contact: Dictionary = Motion.sample_pose(clip, 0.42, layout, facing)
		expect.call(is_equal_approx(float(contact["forearm_l"]["rotation"]), 0.10 if rear else -0.10), "Polearm offhand braces at contact")
		var root: Vector2 = Motion._world_transform(contact, layout, "root").origin - Motion._joint_position(layout, "root")
		expect.call(root.distance_to(line * 10.0) < 0.001, "Thrust commits the root 10px along its attack line")
	elif clip == "attack_lash":
		var apex: Dictionary = Motion.sample_pose(clip, 0.30, layout, facing)
		var overhead := Vector2(0.30, -0.95) if rear else Vector2(-0.30, -0.95)
		expect.call(_axis(apex, layout).distance_to(overhead.normalized()) < 0.001, "Lash gathers above the weapon-side shoulder")
		var snap: Dictionary = Motion.sample_pose(clip, 0.42, layout, facing)
		expect.call(_axis(snap, layout).distance_to(line) < 0.001, "Lash snaps forward along the attack line at .42")
		var wrist: Vector2 = Motion._world_transform(snap, layout, "hand_r").origin
		expect.call(absf(wrist.y - Motion._joint_position(layout, "arm_r").y) < 0.15, "Lash snap reaches shoulder height")
		var shoulder: Vector2 = Motion._joint_position(layout, "arm_r")
		var direction: float = -1.0 if rear else 1.0
		for key: Vector3 in [Vector3(0.30, direction * 6.0, -20), Vector3(0.42, -direction * 26.0, 0), Vector3(0.58, -direction * 22.0, 31)]:
			var pose: Dictionary = Motion.sample_pose(clip, key.x, layout, facing)
			var actual: Vector2 = Motion._world_transform(pose, layout, "hand_r").origin
			var shift: float = actual.distance_to(shoulder + Vector2(key.y, key.z))
			expect.call(shift < 0.15, "Lash retains the authored wrist target at %.2f" % key.x)
			print("FULL GEAR LASH REACH %s %.2f: wrist=%s shift=%.6f" % [facing, key.x, actual, shift])
	else:
		var aim: Vector2 = (Vector2(1, -0.3) if rear else Vector2(-1, -0.2)).normalized()
		for phase: float in [0.24, 0.38, 0.42]:
			var pose: Dictionary = Motion.sample_pose(clip, phase, layout, facing)
			var axis: Vector2 = _axis(pose, layout)
			if clip == "shoot_repeater":
				expect.call(axis.distance_to(aim) < 0.001, "Repeater muzzle follows its authored aim")
			else:
				expect.call(absf(axis.dot(aim)) < 0.001 and axis.y < 0, "Bow limbs are perpendicular to aim with the upper limb upward")
				var string_side := Vector2(axis.y, -axis.x) if rear else Vector2(-axis.y, axis.x)
				expect.call(string_side.distance_to(-aim) < 0.001, "Bow string side faces the hero")
				var shoulder: Vector2 = Motion._joint_position(layout, "arm_r")
				var reach: float = shoulder.distance_to(Motion._joint_position(layout, "forearm_r")) + Motion._joint_position(layout, "forearm_r").distance_to(Motion._joint_position(layout, "hand_r"))
				var wrist: Vector2 = Motion._world_transform(pose, layout, "hand_r").origin
				expect.call(wrist.distance_to(shoulder + aim * (reach - 0.04)) < 0.001, "Bow aims at painted arm's length by .24 through release")
				print("FULL GEAR BOW AIM %s %.2f: wrist=%s reach=%.6f" % [facing, phase, wrist, reach])
	for phase: float in [0.0, 1.0]:
		var pose: Dictionary = Motion.sample_pose(clip, phase, layout, facing)
		expect.call(_axis(pose, layout).distance_to(Motion._gear_axis(layout)) < 0.001, "Every full-pass clip returns to its landmark-defined rest axis")

static func _check_renderer(tree: SceneTree, expect: Callable) -> void:
	var renderer := Renderer.new()
	tree.root.add_child(renderer)
	await tree.process_frame
	renderer.set_process(false)
	for weapon: String in ["hunting_spear", "galewhip", "stormstring_bow", "windlass_repeater"]:
		var motion: String = Gear.weapon_motion({"weapon": weapon})
		for offhand: String in ["ward_kite", "parrying_dagger"]:
			renderer.set_gear({"weapon": weapon, "offhand": offhand})
			for delta: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
				renderer.present({"clip": "attack", "phase": 0.42, "direction": delta}, false)
				expect.call(renderer.snapshot()["clip"] == ("attack_" + motion if motion in ["thrust", "lash"] else "attack"), "Full-pass melee routing selects the equipped archetype or ranged-weapon bash")
				for clip: String in ["shoot", "cast"]:
					renderer.present({"clip": clip, "phase": 0.42, "direction": delta}, false)
					var expected_clip: String = "shoot_" + motion if clip == "shoot" and motion in ["bow", "repeater"] else clip
					expect.call(renderer.snapshot()["clip"] == expected_clip and bool(renderer.snapshot()["offhand_visible"]), "Ranged variant keeps its equipped offhand; magic keeps cast")
					if clip == "shoot" and motion in ["bow", "repeater"]:
						_check_socket(renderer, motion, delta, expect)
					renderer.present({"clip": clip, "phase": 1.0, "direction": delta}, false)
					expect.call(renderer.snapshot()["clip"] == "idle" and renderer.facing == "front" and not renderer.mirrored, "Full-pass ranged action returns to front idle")
					renderer.present({"clip": clip, "phase": 0.42, "direction": delta}, true)
					expect.call(renderer.snapshot()["clip"] == expected_clip and renderer.snapshot()["phase"] == 0.4 and bool(renderer.snapshot()["offhand_visible"]), "Full-pass ranged reduced-motion still retains its weapon and offhand")
					_check_depth(renderer, expect)
				renderer.present({"clip": "attack", "phase": 0.42, "direction": delta}, true)
				expect.call(renderer.snapshot()["clip"] == "rest" and bool(renderer.snapshot()["offhand_visible"]), "Full-pass melee reduced motion keeps neutral equipped art")
				_check_depth(renderer, expect)
		if motion in ["bow", "repeater"]:
			renderer.set_gear({"weapon": weapon})
			for exit_clip: String in ["idle", "walk", "cast", "hit", "block", "death"]:
				renderer.present({"clip": "shoot", "phase": 0.42, "direction": Vector2i(0, -1)}, false)
				_check_depth(renderer, expect)
				renderer.present({"clip": exit_clip, "phase": 0.0, "direction": Vector2i(0, -1)}, false)
				_check_depth(renderer, expect)
	renderer.free()

static func _check_depth(renderer: Node, expect: Callable) -> void:
	var snapshot: Dictionary = renderer.snapshot()
	var shot: bool = snapshot["facing"] == "rear" and snapshot["clip"] in ["shoot_bow", "shoot_repeater"]
	expect.call(renderer.rigs["rear"]._gear_base_parts["weapon_r"]["node"].z_index == (66 if shot else 5), "Rear equipped shot depth restores on every exit, including hidden rear rig and bare offhand")
	expect.call(renderer.rigs["front"]._gear_base_parts["weapon_r"]["node"].z_index == LayerChecks.depth("front", str(snapshot["clip"]) if snapshot["facing"] == "front" else "rest", renderer.weapon_motion(), float(snapshot["phase"])), "Front use depth restores to carry on exit, hidden rigs and reduced melee stills")

static func _check_socket(renderer: Node, motion: String, delta: Vector2i, expect: Callable) -> void:
	var snapshot: Dictionary = renderer.snapshot()
	var rig: Node2D = renderer.rigs[snapshot["facing"]]
	var landmark: String = "assembled" if motion == "bow" else "tip"
	var local: Vector2 = Motion._gear_vector(rig.layout["weapon_grip"][landmark]) - Motion._joint_position(rig.layout, "weapon_r")
	var muzzle: Vector2 = rig.to_local(rig.bones["weapon_r"].to_global(local))
	if motion == "bow":
		var aim: Vector2 = (Vector2(1, -0.3) if snapshot["facing"] == "rear" else Vector2(-1, -0.2)).normalized()
		muzzle += aim * 6.0
	if bool(snapshot["mirrored"]):
		muzzle.x = 255.0 - muzzle.x
	expect.call(renderer.source_socket(true).distance_to(muzzle) < 0.001 and renderer.source_socket(true, true, delta).distance_to(muzzle) < 0.001, "Equipped bow/repeater live and released projectile origins match the registered grip/muzzle, including reflection")
	expect.call(not rig.bones["crossbow_r"].visible and rig.bones["weapon_r"].visible, "Generic crossbow never replaces the equipped bow/repeater")
	_check_depth(renderer, expect)
	var released: Vector2 = renderer.source_socket(true, true, delta)
	for phase: float in [0.24, 0.49, 0.85, 1.0]:
		renderer.present({"clip": "shoot", "phase": phase, "direction": delta}, false)
		_check_depth(renderer, expect)
		expect.call(renderer.source_socket(true, true, delta).distance_to(released) < 0.001, "Equipped released origin stays fixed through recoil, recovery and idle reset")

static func _check_clocks(expect: Callable) -> void:
	var specs: Dictionary = Motion.clip_specs()
	var scene: Node = load("res://scripts/run_scene.gd").new()
	for motion: String in ["thrust", "lash", "bow", "repeater"]:
		var effect: Dictionary = {"kind": "melee", "protagonist_melee": true, "protagonist_weapon_motion": motion, "from": Vector2i(3, 3), "to": Vector2i(3, 4)}
		var frames: int = 34 if motion == "thrust" else 29 if motion == "lash" else 30
		expect.call(Fx.animation_frame_count(effect, 6, false) == frames and is_equal_approx(Fx.animation_frame_seconds(effect, 0.04, false), 1.0 / 60.0), "Full-pass single-target melee cadence follows clip_specs")
		expect.call(is_equal_approx(float(scene.call("_attack_feedback_start_progress", effect)), 0.42), "Full-pass melee keeps its .42 damage boundary")
		expect.call(Fx.animation_frame_count(effect, 6, true) == 1, "Full-pass reduced motion keeps the single resolved frame")
		effect.merge({"kind": "aoe", "range": 0, "to": effect["from"]}, true)
		expect.call(Fx.animation_frame_count(effect, 6, false) == 6 and is_equal_approx(Fx.animation_frame_seconds(effect, 0.04, false), 0.04), "Full-pass sweeps keep .24s")
		expect.call(is_equal_approx(float(scene.call("_attack_feedback_start_progress", effect)), 0.38) and is_equal_approx(float(scene.call("_protagonist_attack_motion", effect, 0.38)["phase"]), 0.42), "Full-pass sweeps keep their .38 boundary and retime pose contact")
	expect.call(specs["attack_thrust"]["frames"] == 34 and specs["attack_thrust"]["duration"] == 0.56 and specs["attack_lash"]["frames"] == 29 and specs["attack_lash"]["duration"] == 0.48, "Full-pass authored melee metadata matches the brief")
	scene.free()

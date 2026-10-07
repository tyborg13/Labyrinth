extends RefCounted

const Motion = preload("res://scripts/protagonist_cutout/motion.gd")
const Gear = preload("res://scripts/protagonist_cutout/gear_visuals.gd")
const RangedAction = preload("res://scripts/protagonist_cutout/ranged_action.gd")
const AttackFxLibrary = preload("res://scripts/attack_fx_library.gd")
const AcceptedMotion = preload("res://experiments/cutouts/protagonist_ranged/v01/source/accepted_motion.gd")
const AcceptedRangedMotion = preload("res://experiments/cutouts/protagonist_ranged/v03/motion.gd")

static func run(renderer: Node, scene: Node, expect: Callable) -> void:
	renderer.set_gear(Gear.DEFAULTS)
	for element: String in ["fire", "earth", "air", "lightning", "ice"]:
		for kind: String in ["ranged", "aoe"]:
			expect.call(RangedAction.clip_for_action({"type": kind, "element": element, "range": 3}) == "cast", "Elemental targeted attacks raise the casting hand: " + element + "/" + kind)
	for kind: String in ["ranged", "push", "pull", "aoe"]:
		expect.call(RangedAction.clip_for_action({"type": kind, "range": 3, "element": "none"}) == "shoot", "Physical ranged actions use the crossbow: " + kind)
	for kind: String in ["melee", "block", "heal", "move", "blink", "detonate"]:
		expect.call(RangedAction.clip_for_action({"type": kind}) == "", "Unrelated actions do not equip a crossbow or cast: " + kind)
	for face: String in ["front", "rear"]:
		var rig: Node2D = renderer.get("rigs")[face]
		var layout: Dictionary = rig.get("layout")
		for clip: String in ["idle", "walk", "attack", "cast"]:
			for sample: int in range(25):
				var t: float = float(sample) / 24.0
				var before: Dictionary = AcceptedRangedMotion.sample_pose(clip, t, layout, face) if clip == "cast" else AcceptedMotion.sample_pose(clip, t, layout, face)
				var after: Dictionary = Motion.sample_pose(clip, t, layout, face)
				for bone: String in before:
					if bone == "crossbow_r": continue
					expect.call(before[bone] == after[bone], "Accepted %s/%s/%s pose is byte-for-byte unchanged" % [face, clip, bone])
		expect.call(layout["joints"]["crossbow_r"]["parent"] == "hand_r" and layout["joints"]["crossbow_r"]["position"] == layout["joints"]["weapon_r"]["position"], "The crossbow registers on the main weapon joint: " + face)
		for part: Dictionary in layout["parts"]:
			if part["name"] == "crossbow":
				var attachment: Dictionary = layout["ranged_attachment"]
				var grip: Vector2 = Motion._gear_vector(part["offset"]) + Motion._gear_vector(attachment["source_grip"])
				expect.call(part["bone"] == "crossbow_r" and part["equipment_slot"] == "weapon" and grip.is_equal_approx(Motion._joint_position(layout, "weapon_r")), "Existing painted crossbow grip sits exactly on the right fist: " + face)
		for clip: String in ["cast", "shoot"]:
			var side: String = "r" if clip == "shoot" else "l"
			var pose: Dictionary = Motion.sample_pose(clip, 0.4, layout, face)
			var shoulder: Transform2D = Motion._world_transform(pose, layout, "arm_" + side)
			var elbow: Transform2D = Motion._world_transform(pose, layout, "forearm_" + side)
			var hand: Transform2D = Motion._world_transform(pose, layout, "hand_" + side)
			var upper: Vector2 = elbow.origin - shoulder.origin
			var lower: Vector2 = hand.origin - elbow.origin
			expect.call(upper.normalized().dot(lower.normalized()) > 0.99, "The user-requested reach lifts a nearly straight arm: " + face + "/" + clip)
			expect.call(hand.origin.y < Motion._joint_position(layout, "hand_" + side).y - 15.0, "The action hand rises visibly above its resting position")
			if clip == "shoot":
				var aim := Vector2(-1, -0.2) if face == "front" else Vector2(1, -0.3)
				expect.call((hand.origin - shoulder.origin).normalized().distance_to(aim.normalized()) < 0.001, "The main-hand shot retains its authored aim: " + face)
			for bone: String in ["hand_" + side, "crossbow_r" if clip == "shoot" else "hand_l"]:
				var world: Transform2D = Motion._world_transform(pose, layout, bone)
				expect.call(absf(world.x.length()-1.0) < 0.001 and absf(world.y.length()-1.0) < 0.001 and absf(world.x.dot(world.y)) < 0.001, "Straight reach retains rigid, unstretched glove and weapon paint")
			for pair: Array in [["arm_" + side, "forearm_" + side], ["forearm_" + side, "hand_" + side]]:
				var perpendicular: Vector2 = (Motion._joint_position(layout, pair[1]) - Motion._joint_position(layout, pair[0])).normalized().orthogonal()
				var transform: Transform2D = Motion._world_transform(pose, layout, pair[0])
				expect.call(absf((transform.basis_xform(perpendicular)).length() - 1.0) < 0.001, "Ranged reach preserves painted sleeve width")
			var preserved: Array = ["arm_l", "forearm_l", "hand_l", "foot_l", "foot_r"] if clip == "shoot" else ["arm_r", "forearm_r", "hand_r", "weapon_r", "foot_l", "foot_r"]
			for bone: String in preserved:
				expect.call(pose[bone] == Motion.sample_pose("rest", 0.0, layout, face)[bone], "Ranged actions preserve the unused arm and planted feet")
	for clip: String in ["cast", "shoot"]:
		for delta: Vector2i in [Vector2i(0,2),Vector2i(2,0),Vector2i(0,-2),Vector2i(-2,0)]:
			var effect: Dictionary = {"kind":"ranged", "action_type":"ranged", "element":"fire" if clip == "cast" else "none", "protagonist_ranged":clip, "from":Vector2i(3,3), "protagonist_origin":Vector2i(3,3), "to":Vector2i(3,3)+delta}
			renderer.call("present", {"clip":clip, "phase":0.42, "direction":delta}, false)
			if clip == "shoot":
				_check_live_muzzle(renderer, expect)
			var release: Vector2 = renderer.call("source_socket", clip == "shoot", true, delta)
			var hand_socket: Vector2 = renderer.call("source_socket", clip == "shoot")
			expect.call(release.distance_to(hand_socket) < 0.001, "Projectile origin exactly matches the visible hand/muzzle at release in each facing")
			var sample: Dictionary = renderer.call("snapshot")
			expect.call(bool(sample["crossbow_visible"]) == (clip == "shoot"), "Only shooting equips the temporary crossbow")
			var style: String = AttackFxLibrary.style_for_effect(effect)
			var contact: float = 0.66 if clip == "shoot" else AttackFxLibrary.travel_end_progress(style)
			var before: float = float(scene.call("_attack_feedback_start_progress", effect))
			expect.call(is_equal_approx(before, contact), "Preparation does not change the existing effect/contact boundary")
			for t: float in [0.0,0.4,0.7,1.0]:
				renderer.call("present", RangedAction.motion_for_effect(effect,t), false)
				if clip == "shoot":
					_check_live_muzzle(renderer, expect)
				expect.call((renderer.call("source_socket", clip == "shoot", true, delta) as Vector2).distance_to(release) < 0.001, "Released origin remains fixed through recoil, recovery, and idle facing reset")
			renderer.call("present", {"clip":clip,"phase":1.0,"direction":delta}, true)
			sample = renderer.call("snapshot")
			expect.call(sample["clip"] == clip and is_equal_approx(float(sample["phase"]),0.4) and bool(sample["crossbow_visible"]) == (clip == "shoot"), "Reduced motion uses a still raised hand or aimed crossbow")
			if clip == "shoot":
				_check_live_muzzle(renderer, expect)
				expect.call(not renderer.rigs[sample["facing"]].bones["weapon_r"].visible and bool(sample["offhand_visible"]), "Reduced-motion main-hand shot keeps its equipped offhand")
			renderer.call("present", {}, true)
			expect.call(not bool(renderer.call("snapshot")["crossbow_visible"]), "Returning to idle removes temporary equipment")

	print("PROTAGONIST RANGED CONTRACTS: checked")

static func _check_live_muzzle(renderer: Node, expect: Callable) -> void:
	var snapshot: Dictionary = renderer.snapshot()
	var rig: Node2D = renderer.rigs[snapshot["facing"]]
	var offset: Vector2 = Motion._gear_vector(rig.layout["ranged_attachment"]["muzzle_offset"])
	var actual: Vector2 = rig.to_local(rig.bones["crossbow_r"].to_global(offset))
	if bool(snapshot["mirrored"]):
		actual.x = 255.0 - actual.x
	expect.call(renderer.source_socket(true).distance_to(actual) < 0.001, "The live projectile socket follows the visible right-hand muzzle, including reflection and recoil")

extends RefCounted
## Static carry views on the real combat board, through the production rig.
const Gear = preload("res://scripts/protagonist_cutout/gear_visuals.gd")
const Layers = preload("res://tests/helpers/protagonist_gear_layer_checks.gd")
const Motion = preload("res://scripts/protagonist_cutout/motion.gd")

static func run(scene: Node, expect: Callable, capture: Callable) -> Array:
	var host: Script = load("res://tests/helpers/protagonist_gear_motion_scenarios.gd")
	var checks: Array = []
	var cases: Array = []
	for weapon: String in ["training_sword", "war_maul", "hunting_spear", "stormstring_bow"]:
		for clip: String in ["idle", "walk"]:
			cases.append({"weapon": weapon, "facing": "rear", "clip": clip})
	for weapon: String in ["training_sword", "war_maul", "hunting_spear", "tourney_lance", "hookspine_halberd", "stormstring_bow", "dawnlight_censer"]:
		for clip: String in ["idle", "walk"]:
			cases.append({"weapon": weapon, "facing": "front", "clip": clip})
	for case: Dictionary in cases:
		var rear: bool = case["facing"] == "rear"
		var delta := Vector2i(0, -1) if rear else Vector2i(0, 1)
		var equipped: Dictionary = Gear.DEFAULTS.duplicate()
		equipped["weapon"] = case["weapon"]
		equipped["offhand"] = "ward_kite"
		await host._fixture(scene, equipped, "quick_stab", delta)
		var renderer: Node = scene.board_view.get("_protagonist_renderer")
		renderer.present({"clip": "walk", "phase": 0.25, "direction": delta}, false)
		if case["clip"] == "idle":
			# Explicit rear idle is an inspection view only. Production still
			# returns the hero to unmirrored camera-facing idle after an action.
			renderer.clip = "idle"
			renderer._idle_seconds = 0.40 * renderer.IDLE_CYCLE_SECONDS
			renderer._apply_pose()
		for frame: int in range(2):
			await scene.get_tree().process_frame
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
		var snapshot: Dictionary = renderer.snapshot()
		var rig: Node2D = renderer.rigs[case["facing"]]
		var weapon: Node2D = rig._gear_base_parts["weapon_r"]["node"]
		var z: int = 5 if rear else 8
		expect.call(snapshot["facing"] == case["facing"] and snapshot["clip"] == case["clip"] and not snapshot["mirrored"], "Carry probe retains the requested facing/clip")
		expect.call(weapon.z_index == z and rig._gear_base_parts["crossbow"]["node"].z_index == 66, "Carry probe body is behind the legs; crossbow stays over the palm")
		Layers.overlays(rig, expect)
		var pose: Dictionary = Motion.sample_pose(case["clip"], snapshot["phase"], rig.layout, case["facing"])
		var axis: Vector2 = Motion._world_transform(pose, rig.layout, "weapon_r").basis_xform(Motion._gear_axis(rig.layout)).normalized()
		var grip: Vector2 = Motion._gear_vector(rig.layout["weapon_grip"]["assembled"])
		var palm: Vector2 = rig.to_local(rig.bones["hand_r"].to_global(grip - Motion._joint_position(rig.layout, "hand_r")))
		var weapon_grip: Vector2 = rig.to_local(rig.bones["weapon_r"].to_global(grip - Motion._joint_position(rig.layout, "weapon_r")))
		expect.call(palm.distance_to(weapon_grip) < 0.001, "Carry probe's actual bones keep the registered grip")
		var label: String = "carry_%s_%s_%s" % [case["facing"], case["clip"], case["weapon"]]
		var metadata: Dictionary = {"label": label, "hero": snapshot, "weapon_z": weapon.z_index,
			"rest_axis": [Motion._gear_axis(rig.layout).x, Motion._gear_axis(rig.layout).y],
			"posed_axis": [axis.x, axis.y], "grip_error": palm.distance_to(weapon_grip)}
		checks.append(metadata)
		if capture.is_valid():
			await capture.call(scene, label, metadata)
	print("PROTAGONIST GEAR CARRY PROBE CHECKPOINTS: %d" % checks.size())
	return checks

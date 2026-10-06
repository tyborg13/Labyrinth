extends RefCounted
## Full-pass additions use the existing real-card fixture and deterministic
## production-frame probe clock. They never resolve or inject an action twice.
const Gear = preload("res://scripts/protagonist_cutout/gear_visuals.gd")
const Fx = preload("res://scripts/attack_fx_library.gd")

static func run(scene: Node, expect: Callable) -> Array:
	# Runtime loading avoids a circular preload with the shared scenario host.
	var host: Script = load("res://tests/helpers/protagonist_gear_motion_scenarios.gd")
	var checks: Array = []
	var captures: int = 0
	for weapon: String in ["hunting_spear", "tourney_lance", "hookspine_halberd", "galewhip", "worldbreaker", "duelist_rapier"]:
		for delta: Vector2i in [Vector2i(0, 1), Vector2i(0, -1)]:
			var equipped: Dictionary = Gear.DEFAULTS.duplicate()
			equipped["weapon"] = weapon
			equipped["offhand"] = "parrying_dagger" if weapon == "duelist_rapier" else "ward_kite"
			var card: String = "crushing_blow" if weapon == "worldbreaker" else "quick_stab"
			await host._fixture(scene, equipped, card, delta)
			scene.proof_mode = "attack"
			scene.proof_label = weapon + ("_rear_northeast" if delta.y < 0 else "_front_southwest")
			var motion: String = Gear.weapon_motion(equipped)
			scene.proof_checkpoints = [0.20, 0.30, 0.42, 0.58] if motion == "thrust" else [0.20, 0.36, 0.42, 0.58] if motion == "lash" else [0.42]
			checks.append(await host._play_card(scene, card, delta, expect))
			expect.call(scene.proof_captures.size() == scene.proof_checkpoints.size(), "Full-pass melee captures every requested checkpoint: " + weapon)
			for hit: Dictionary in scene.proof_hits:
				expect.call(hit["frames"] == Fx.animation_frame_count({"kind": "melee", "protagonist_melee": true, "protagonist_weapon_motion": motion}, 6, false), "Actual full-pass melee uses the authored frame clock")
			captures += scene.proof_captures.size()
	for weapon: String in ["stormstring_bow", "windlass_repeater"]:
		for delta: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0)]:
			var equipped: Dictionary = Gear.DEFAULTS.duplicate()
			equipped["weapon"] = weapon
			equipped["offhand"] = "parrying_dagger" if weapon == "stormstring_bow" else "ward_kite"
			await host._fixture(scene, equipped, "bone_dart", delta)
			scene.proof_mode = "ranged"
			scene.proof_label = weapon + ("_rear_northeast" if delta.y < 0 else "_mirrored_southeast" if delta.x > 0 else "_front_southwest")
			scene.proof_ranged_release = 0.18
			scene.proof_ranged_pose_checkpoints = [0.24, 0.42]
			checks.append(await host._play_card(scene, "bone_dart", delta, expect))
			expect.call(scene.proof_captures.has(scene.proof_label + "_phase_024") and scene.proof_captures.has(scene.proof_label + "_phase_042"), "Full-pass physical shot captures preparation and release: " + weapon)
			captures += scene.proof_captures.size()
	print("PROTAGONIST FULL GEAR GAMEPLAY CHECKPOINTS: %d" % captures)
	return checks

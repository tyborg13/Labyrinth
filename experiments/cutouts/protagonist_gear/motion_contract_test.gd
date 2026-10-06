extends SceneTree

const BASE := "res://experiments/cutouts/protagonist_gear/"
var failures: Array[String]
var metrics: Dictionary = {}


func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")


func _run() -> void:
	for record: Array in [["heavy_v01", "attack_heavy"], ["stab_v01", "attack_stab"], ["shield_v01", "block_shield"]]:
		var case_path: String = BASE + str(record[0]) + "/"
		var sampler: Script = load(case_path + "motion.gd")
		var original: Script = load(case_path + "source/seed_motion.gd")
		var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(case_path + "cutout.json"))
		var clip: String = record[1]
		var case_metrics: Dictionary = {}
		_check(config["clips"][clip]["phase_curve"] == [[0.0, 0.0], [1.0, 1.0]], clip + " uses identity phase")
		_check(config["clips"][clip]["frames"] == sampler.clip_specs()[clip]["frames"] and config["clips"][clip]["duration"] == sampler.clip_specs()[clip]["duration"], clip + " sampler and playback metadata agree")
		for facing: String in ["front", "rear"]:
			var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(case_path + config["layouts"][facing]))
			for part: Dictionary in layout["parts"]:
				part["file"] = case_path + str(part["file"])
			var max_segment_error := 0.0
			var max_rigid_error := 0.0
			var max_foot_error := 0.0
			var max_grip_error := 0.0
			var max_torso_shift := 0.0
			var max_torso_shift_phase := 0.0
			var max_shield_tilt := 0.0
			var existing_offhand: Dictionary = {}
			for index: int in range(201):
				var phase: float = float(index) / 200.0
				# Compare all accepted samplers, including clips absent from the
				# seed's initial selector. This catches accidental common edits.
				for accepted: String in original.clip_specs():
					_check(sampler.sample_pose(accepted, phase, layout, facing) == original.sample_pose(accepted, phase, layout, facing),
						str(record[0]) + "/" + facing + "/" + accepted + " accepted pose changed")
					if clip == "block_shield" and accepted in ["cast", "shoot", "walk", "hit", "attack"]:
						var accepted_pose: Dictionary = sampler.sample_pose(accepted, phase, layout, facing)
						var shield: Transform2D = sampler._world_transform(accepted_pose, layout, "gear_offhand_mount")
						var basis_error: float = maxf(absf(shield.x.length() - 1.0), maxf(absf(shield.y.length() - 1.0), absf(shield.x.dot(shield.y))))
						existing_offhand[accepted] = maxf(float(existing_offhand.get(accepted, 0.0)), basis_error)
				var pose: Dictionary = sampler.sample_pose(clip, phase, layout, facing)
				for side: String in ["r", "l"]:
					for chain: Array in [["arm_", "forearm_", "hand_"], ["thigh_", "shin_", "foot_"]]:
						for segment: int in range(2):
							var a: String = str(chain[segment]) + side
							var b: String = str(chain[segment + 1]) + side
							var rest_length: float = sampler._joint_position(layout, a).distance_to(sampler._joint_position(layout, b))
							var length: float = sampler._world_transform(pose, layout, a).origin.distance_to(sampler._world_transform(pose, layout, b).origin)
							max_segment_error = maxf(max_segment_error, absf(length - rest_length))
				for terminal: String in ["hand_r", "hand_l", "weapon_r", "foot_r", "foot_l"]:
					var matrix: Transform2D = sampler._world_transform(pose, layout, terminal)
					_check(matrix.is_finite(), clip + "/" + facing + " finite " + terminal)
					max_rigid_error = maxf(max_rigid_error, maxf(absf(matrix.x.length() - 1.0), maxf(absf(matrix.y.length() - 1.0), absf(matrix.x.dot(matrix.y)))))
				for foot: String in ["foot_r", "foot_l"]:
					max_foot_error = maxf(max_foot_error, sampler._world_transform(pose, layout, foot).origin.distance_to(sampler._joint_position(layout, foot)))
				var shift: Vector2 = Vector2(pose["torso"]["position"]) - sampler._local_position(layout, "torso")
				if absf(shift.x) > max_torso_shift:
					max_torso_shift = absf(shift.x)
					max_torso_shift_phase = phase
				if clip == "attack_heavy" and phase >= 0.08 and phase <= 0.68:
					var right: Vector2 = sampler._world_transform(pose, layout, "hand_r").origin
					var left: Vector2 = sampler._world_transform(pose, layout, "hand_l").origin
					var axis: Vector2 = sampler._gear_axis(layout)
					var weapon: Transform2D = sampler._world_transform(pose, layout, "weapon_r")
					var direction: Vector2 = weapon.basis_xform(axis).normalized()
					max_grip_error = maxf(max_grip_error, left.distance_to(right - direction * 9.0))
				if clip == "block_shield":
					for sword_bone: String in ["arm_r", "forearm_r", "hand_r", "weapon_r"]:
						var matrix: Transform2D = sampler._world_transform(pose, layout, sword_bone)
						_check(matrix.origin.distance_to(sampler._joint_position(layout, sword_bone)) < 0.001 and absf(matrix.get_rotation()) < 0.001, "Shield guard keeps sword at bind")
					var shield: Transform2D = sampler._world_transform(pose, layout, "gear_offhand_mount")
					max_shield_tilt = maxf(max_shield_tilt, absf(shield.get_rotation()))
					_check(absf(shield.x.length() - 1.0) < 0.001 and absf(shield.y.length() - 1.0) < 0.001, "Shield remains rigid")
			_check(max_segment_error < 0.001, clip + "/" + facing + " painted segment lengths")
			_check(max_rigid_error < 0.001, clip + "/" + facing + " rigid terminals")
			_check(max_foot_error < 0.001, clip + "/" + facing + " planted feet")
			_check(max_grip_error < 0.05, clip + "/" + facing + " both hands on haft")
			_check(max_torso_shift <= 6.0, clip + "/" + facing + " torso correction within 6px")
			_check(max_shield_tilt <= 0.15001, clip + "/" + facing + " shield tilt within 0.15rad")
			var key_phases: Array = [0.0, 0.12, 0.30, 0.36, 0.42, 0.48, 0.58, 0.72, 0.90, 1.0] if clip == "attack_heavy" else ([0.0, 0.30, 0.42, 0.54, 0.90] if clip == "attack_stab" else [0.0, 0.14, 0.25, 0.32])
			var keys: Array = []
			for phase: float in key_phases:
				var pose: Dictionary = sampler.sample_pose(clip, phase, layout, facing)
				var right: Vector2 = sampler._world_transform(pose, layout, "hand_r").origin
				var left: Vector2 = sampler._world_transform(pose, layout, "hand_l").origin
				var torso_shift: Vector2 = Vector2(pose["torso"]["position"]) - sampler._local_position(layout, "torso")
				var hips_shift: Vector2 = Vector2(pose["hips"]["position"]) - sampler._local_position(layout, "hips")
				var key: Dictionary = {"phase": phase, "right": [right.x, right.y], "left": [left.x, left.y], "torso_dx": torso_shift.x, "hips_dy": hips_shift.y}
				if clip != "block_shield":
					var tip: Vector2 = sampler._world_transform(pose, layout, "weapon_r") * (sampler._gear_vector(layout["weapon_grip"]["tip"]) - sampler._joint_position(layout, "weapon_r"))
					key["tip"] = [tip.x, tip.y]
				keys.append(key)
				if clip == "block_shield" and phase >= 0.14:
					var target := Vector2(98, 120) if facing == "rear" else Vector2(146, 116)
					_check(left.distance_to(target) < 0.001, facing + " full guard wrist")
			var contact: Dictionary = sampler.sample_pose(clip, 0.42, layout, facing)
			if clip == "attack_stab":
				var wrist := Vector2(182, 112) if facing == "rear" else Vector2(66, 121)
				var aim := Vector2(0.894, -0.447) if facing == "rear" else Vector2(-0.894, 0.447)
				var weapon: Transform2D = sampler._world_transform(contact, layout, "weapon_r")
				_check(sampler._world_transform(contact, layout, "hand_r").origin.distance_to(wrist) < 0.001, facing + " contact wrist at 0.42")
				_check(weapon.basis_xform(sampler._gear_axis(layout)).normalized().distance_to(aim.normalized()) < 0.001, facing + " projected stab direction")
			case_metrics[facing] = {"segment_error": max_segment_error, "rigid_error": max_rigid_error, "foot_error": max_foot_error, "grip_error": max_grip_error, "torso_shift_max": max_torso_shift, "torso_shift_phase": max_torso_shift_phase, "shield_tilt_max": max_shield_tilt, "existing_offhand_basis_error": existing_offhand, "keys": keys}
		metrics[record[0]] = case_metrics
	var file := FileAccess.open(BASE + "motion_contract_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"metrics": metrics, "failures": failures}, "\t"))
	file.close()
	for failure: String in failures:
		print("GEAR_MOTION_FAILURE: " + failure)
	print("GEAR_ACCEPTED_POSES: " + ("PASS" if failures.filter(func(s: String) -> bool: return s.contains("accepted pose changed")).is_empty() else "FAIL") + " (8 clips × 2 facings × 201 phases × 3 cases)")
	print("GEAR_MOTION_CONTRACTS: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)

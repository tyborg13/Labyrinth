extends "res://scripts/run_scene.gd"

## Probe-only clock: real card handlers/resolvers run unchanged, while each
## authored frame waits for a render. Requested fractional checkpoints retime
## only the submitted effect/pose, using a production frame on the same side of
## contact for its before/after display state. This makes .42 exact even with
## 43 frames, without inventing an action or applying a result again.
const CHECKPOINTS: Array = [0.12, 0.30, 0.36, 0.42, 0.58, 0.85]
var proof_mode: String = ""
var proof_label: String = ""
var proof_capture: Callable
var proof_expect: Callable
var proof_ranged_release: float = 0.18
var proof_hits: Array[Dictionary]
var proof_captures: PackedStringArray = []
var _proof_checkpoint: float = -1.0
var _proof_applied: bool = false
var _proof_effect: Dictionary = {}
var _proof_state: Dictionary = {}

func _render_board_state(display_state: Dictionary, presentation: Dictionary, stable: bool = false) -> void:
	var shown: Dictionary = presentation
	_proof_applied = false
	_proof_effect = presentation.get("effect", {})
	_proof_state = display_state
	if _proof_checkpoint >= 0.0 and float(presentation.get("effect_progress", 1.0)) < 1.0 and ((proof_mode == "attack" and bool(_proof_effect.get("protagonist_melee", false))) or (proof_mode == "ranged" and not str(_proof_effect.get("protagonist_ranged", "")).is_empty())):
		shown = presentation.duplicate(false)
		shown["effect_progress"] = _proof_checkpoint
		_proof_applied = true
	super._render_board_state(display_state, shown, stable)

func _play_timed_animation_frames(frame_count: int, frame_seconds: float, render_frame: Callable) -> void:
	if frame_count <= 0 or not render_frame.is_valid():
		return
	var primary: bool = false
	var previous_hp: int = -1
	var initial_hp: int = -1
	var hp_changes: int = 0
	var hit_index: int = proof_hits.size() + 1
	var first: int = frame_count if frame_seconds <= 0.0 else 1
	for frame: int in range(first, frame_count + 1):
		_proof_checkpoint = -1.0
		if (primary or frame == 1) and frame_seconds > 0.0:
			var targets: Array = CHECKPOINTS if proof_mode == "attack" else [proof_ranged_release]
			for target: float in targets:
				# Preserve the production before/after result classification.
				var chosen: int = maxi(1, floori(target * frame_count)) if target < 0.42 else ceili(target * frame_count)
				if frame == chosen:
					_proof_checkpoint = target
		_proof_effect = {}
		render_frame.call(frame)
		if frame == first:
			var progress: float = float(board_view.presentation.get("effect_progress", 1.0))
			primary = (proof_mode == "attack" and bool(_proof_effect.get("protagonist_melee", false)) or proof_mode == "ranged" and not str(_proof_effect.get("protagonist_ranged", "")).is_empty()) and (progress < 0.2 or frame_seconds <= 0.0)
			initial_hp = _proof_enemy_hp()
			previous_hp = initial_hp
		if primary:
			var hp: int = _proof_enemy_hp()
			if hp < previous_hp:
				hp_changes += 1
			previous_hp = hp
		await get_tree().process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		if primary and _proof_applied:
			var suffix: String = "hit_%02d_progress_%03d" % [hit_index, roundi(_proof_checkpoint * 100)] if proof_mode == "attack" else "phase_042"
			await _proof_save(proof_label + "_" + suffix)
		elif primary and frame_seconds <= 0.0:
			await _proof_save(proof_label + "_reduced_motion")
		elif proof_mode == "block" and not proof_captures.has(proof_label):
			var snapshot: Dictionary = board_view.protagonist_animation_snapshot()
			if str(snapshot.get("clip", "")) in ["block", "block_shield"] and float(snapshot.get("phase", 0.0)) >= 0.14:
				await _proof_save(proof_label)
	_proof_checkpoint = -1.0
	if primary and proof_mode == "attack":
		# Reduced motion submits just the already-resolved contact still.
		proof_expect.call(hp_changes == 1 if frame_seconds > 0.0 else hp_changes == 0, "One presentation HP transition per melee attack: " + proof_label)
		proof_hits.append({"initial_hp": initial_hp, "final_hp": previous_hp, "hp_changes": hp_changes,
			"frames": frame_count, "frame_seconds": frame_seconds})

func _proof_enemy_hp() -> int:
	var enemies: Array = _proof_state.get("enemies", [])
	return int(enemies[0]["hp"]) if not enemies.is_empty() else 0

func _proof_save(label: String) -> void:
	if proof_captures.has(label):
		return
	proof_captures.append(label)
	var snapshot: Dictionary = board_view.protagonist_animation_snapshot()
	var renderer: Node = board_view.get("_protagonist_renderer")
	if proof_mode == "attack":
		var expected_clip: String = "attack_heavy" if renderer.weapon_motion() == "heavy" else "attack_stab" if renderer.weapon_motion() == "stab" else "attack"
		proof_expect.call(snapshot["clip"] == ("rest" if _reduced_motion_enabled() else expected_clip), "Actual card play renders its equipped weapon clip")
		var direction: Vector2i = _proof_effect.get("to", Vector2i.ZERO) - _proof_effect.get("from", Vector2i.ZERO)
		proof_expect.call(snapshot["facing"] == ("rear" if direction.y < 0 else "front") and not snapshot["mirrored"], "Actual attack faces its adjacent southwest/northeast target")
		if renderer.weapon_motion() == "heavy":
			proof_expect.call(not bool(snapshot["offhand_visible"]), "A two-hander keeps the equipped offhand hidden")
	if proof_mode == "block":
		var expected_guard: String = "block_shield" if renderer.offhand_kind() == "shield" else "block"
		proof_expect.call(snapshot["clip"] == expected_guard, "An absorbed enemy hit selects the correct guard")
		proof_expect.call(bool(snapshot["offhand_visible"]) == (expected_guard == "block_shield"), "Shield guard is visible; two-handed guard has no offhand")
	if proof_mode == "ranged":
		proof_expect.call(is_equal_approx(float(snapshot["phase"]), 0.42) and snapshot["facing"] == "rear", "Rear ranged checkpoint is exactly phase .42")
		var rig: Node2D = board_view.get("_protagonist_renderer").rigs["rear"]
		for attachment: Sprite2D in rig.get("_gear_attachments"):
			var basis: Transform2D = rig.global_transform.affine_inverse() * attachment.global_transform
			proof_expect.call(absf(basis.x.length() - 1.0) < 0.0001 and absf(basis.y.length() - 1.0) < 0.0001, "Rear ranged gear stays at native pixel size")
	if proof_capture.is_valid():
		await proof_capture.call(self, label, {"effect": _proof_effect, "effect_progress": board_view.presentation.get("effect_progress", 1.0), "hero": snapshot})

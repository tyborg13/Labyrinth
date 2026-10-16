extends "res://scripts/run_scene.gd"

## Probe-only frame clock, following protagonist_gear_motion_run_scene.gd.
## Resolvers and real action callbacks are unchanged. Each submitted frame waits
## for capture; explicit preparation/recovery endpoints use that action's actual
## before/after display state. No gameplay clock or director value is changed.
const ProofMotion = preload("res://scripts/gust_shrike_cutout/motion.gd")
var proof_clip: String = ""
var proof_capture: Callable
var _proof_state: Dictionary
var _proof_presentation: Dictionary
var _float_sampled: bool = false

func begin_proof(clip: String) -> void:
	proof_clip = clip
	_float_sampled = false

func _render_board_state(state: Dictionary, presentation: Dictionary, stable: bool = false) -> void:
	_proof_state = state
	_proof_presentation = presentation
	super._render_board_state(state, presentation, stable)

func _play_timed_animation_frames(count: int, seconds: float, render_frame: Callable) -> void:
	if count <= 0 or not render_frame.is_valid(): return
	# Movement and melee callbacks use frame/count, so frame zero is their
	# preparation state. Dive/death already submit zero at frame one.
	var first: int = 0 if proof_clip in ["move", "talon_rake"] else 1
	for frame: int in range(first, count + 1):
		render_frame.call(frame)
		await get_tree().process_frame
		if proof_clip not in ["hit", "hover"]: await _capture_current()
	var renderer: Node = board_view.unit_cutout_renderer({"type": "gust_shrike", "id": 1})
	if proof_clip == "dive" and renderer != null:
		var snapshot: Dictionary = renderer.snapshot()
		if snapshot["clip"] == "dive" and float(snapshot["phase"]) > GustShrikeAction.Data.CONTACT_PHASES["dive"]:
			# Frame six reaches the held recovered pose; show its phase-one end.
			_seek_pose(1.0)
			await _capture_current()

func _animate_floating_text_presentation(state: Dictionary, base: Dictionary, initial: float = 0.0, overlap: bool = false, companion: Dictionary = {}) -> void:
	var matches: bool = false
	if proof_clip == "hover":
		matches = GustShrikeAction.action_for_effect(base.get("effect", {}), GustShrikeAction.actor_for(state, "enemy_1")) == "hover"
	elif proof_clip == "hit":
		for entry: Dictionary in base.get("floating_texts", []):
			if entry.get("reaction_actor_key", "") == "enemy_1" and entry.get("reaction", "") == "hit": matches = true
	if not matches or _float_sampled:
		await super._animate_floating_text_presentation(state, base, initial, overlap, companion)
		return
	_float_sampled = true
	# Real resolved popup payload, sampled at authored keys and midpoints. This
	# avoids losing short reactions to disk IO or wall-clock frame skipping.
	var phases: Array[float]
	for track: Dictionary in ProofMotion.tracks_for(proof_clip, "front"):
		var keys: Array = track["keys"]
		for index: int in range(keys.size()):
			var phase: float = float(keys[index]["at"])
			if not phases.has(phase): phases.append(phase)
			if index > 0:
				var middle: float = (phase + float(keys[index - 1]["at"])) / 2.0
				if not phases.has(middle): phases.append(middle)
	phases.sort()
	for phase: float in phases:
		var shown: Dictionary = base.duplicate(true)
		var duration: float = preload("res://scripts/cutout_context.gd").HIT_SECONDS if proof_clip == "hit" else FloatingCombatText.ANIMATION_DURATION_SECONDS
		shown["floating_texts"] = FloatingCombatText.animate_entries(base.get("floating_texts", []), phase * duration, false)
		shown["effect_progress"] = phase
		_render_board_state(state, shown)
		_seek_pose(phase)
		await _capture_current()
	_render_board_state(state, {})

func _seek_pose(phase: float) -> void:
	var shown: Dictionary = _proof_presentation.duplicate(true)
	var current: Dictionary = (board_view.presentation.get("gust_shrike_motion", {}) as Dictionary).get("enemy_1", {}).duplicate(true)
	current["clip"] = proof_clip
	current["phase"] = phase
	shown["gust_shrike_motion"] = {"enemy_1": current}
	_render_board_state(_proof_state, shown, true)

func _capture_current() -> void:
	var renderer: Node = board_view.unit_cutout_renderer({"type": "gust_shrike", "id": 1})
	if renderer == null: return
	var snapshot: Dictionary = renderer.snapshot()
	if snapshot["clip"] != proof_clip: return
	if proof_clip == "dive" and float(snapshot["phase"]) < 1.0 and float(snapshot["phase"]) >= GustShrikeAction.dive_recovery_phase(6, GustShrikeAction.Data.CONTACT_PHASES["dive"]): return
	if proof_capture.is_valid(): await proof_capture.call()

extends "res://scripts/run_scene.gd"
## Observe semantic presentation phases independently of CombatPacing flags.
var action_scales: Array[float]
var movement_scales: Array[float]
var effect_scales: Dictionary = {}
var timed_presentations: Array[Dictionary]
var record_clocks: bool = false
func _render_board_state(state: Dictionary, presentation: Dictionary, stable: bool = false) -> void:
	var effect: Dictionary = presentation.get("effect",{})
	if _combat_pacing.enemies_active and bool(_combat_pacing.get("_enemy_action_active")) and Engine.time_scale > 0.0:
		action_scales.append(Engine.time_scale)
	if record_clocks and Engine.time_scale > 0.0:
		# Dive flight also submits unit positions; only the effect-free approach
		# belongs to travel. Classify from the submission, never the clock flag.
		if presentation.has("unit_world_positions") and effect.is_empty(): movement_scales.append(Engine.time_scale)
		if not effect.is_empty():
			var kind: String = str(effect.get("action_type",effect.get("kind","")))
			if not effect_scales.has(kind): effect_scales[kind] = []
			effect_scales[kind].append(Engine.time_scale)
	super._render_board_state(state, presentation, stable)
func _play_timed_animation_frames(count: int, seconds: float, render_frame: Callable) -> void:
	var began: int = _combat_pacing.presentation_usec()
	var frames: Array[int]
	await super._play_timed_animation_frames(count, seconds, func(frame: int) -> void:
		frames.append(frame)
		render_frame.call(frame))
	if record_clocks:
		timed_presentations.append({"count":count,"seconds":seconds,"frames":frames,"elapsed":float(_combat_pacing.presentation_usec()-began)/1000000.0})


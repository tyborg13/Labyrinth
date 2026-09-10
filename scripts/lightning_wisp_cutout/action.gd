extends RefCounted

## Presentation-only anticipation precedes the existing lightning effect.
## The caller still owns the single outcome application and existing FX timing.
const PREPARE_SECONDS: float = .22
const PREPARE_FRAMES: int = 14

static func prepare(scene: Node, before_state: Dictionary, effect: Dictionary) -> void:
	if scene.call("_reduced_motion_enabled"):
		return
	var actor_key: String = str(effect.get("actor_key", ""))
	var direction: Vector2i = (effect.get("to", Vector2i.ZERO) as Vector2i) - (effect.get("from", Vector2i.ZERO) as Vector2i)
	await scene.call("_play_timed_animation_frames", PREPARE_FRAMES, PREPARE_SECONDS / PREPARE_FRAMES, func(frame: int) -> void:
		var phase: float = .36 * float(frame) / PREPARE_FRAMES
		scene.call("_render_board_state", before_state, {"focus_actor_keys": [actor_key],
			"lightning_wisp_motion": {actor_key: {"clip": "attack", "action": "cast", "phase": 0.0,
				"authored_phase": phase, "direction": direction}}}, true)
	)

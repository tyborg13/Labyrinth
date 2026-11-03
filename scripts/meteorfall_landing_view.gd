extends RefCounted

## The Meteorfall card's turn-start landing. Vyraketh's meteor falls on each
## marked tile; the impact sound, the damage, the Fire and the cleared marks all
## arrive on its contact frame. Presentation only: the resolver already committed
## the outcome, and the step carries each tile's committed ground.
const Dragon = preload("res://scripts/dragon_presentation.gd")
const FloatingCombatText = preload("res://scripts/floating_combat_text.gd")

const FRAME_SECONDS: float = 1.0 / 60.0
## Same clock as Vyraketh's 66-frame area spell, entered just before its release.
const FX_FRAME_PROGRESS: float = 1.0 / 66.0
const START_PROGRESS: float = 0.22

static func handles(step: Dictionary) -> bool:
	return str(step.get("trigger", "")) == "meteor_marks"

static func animate(scene: Node, animated_state: Dictionary, step: Dictionary) -> void:
	var before: Dictionary = animated_state.duplicate(true)
	var effect: Dictionary = {"kind": "aoe", "enemy_type": "vyraketh", "action_type": "cinder_marks", "tiles": step.get("focus_tiles", []), "from": Vector2i(-1, -1)}
	var reduced: bool = scene._reduced_motion_enabled()
	var contact_frame: int = 0 if reduced else ceili((Dragon.CONTACT - START_PROGRESS) / FX_FRAME_PROGRESS)
	var base: Dictionary = scene._enemy_phase_status_presentation(step)
	var texts: Array = base.get("floating_texts", [])
	base["effect"] = effect
	var settle_seconds: float = scene._combat_pacing.feedback_duration(texts, FloatingCombatText.total_duration(texts), 0.0)
	var frames: int = contact_frame + ceili(maxf(settle_seconds, (1.0 - Dragon.CONTACT) / FX_FRAME_PROGRESS * FRAME_SECONDS) / FRAME_SECONDS)
	var landed: Dictionary = {}
	scene._set_action_banner("%s: %s" % [str(step.get("actor_name", "Meteorfall")), str(step.get("label", ""))])
	await scene._play_timed_animation_frames(frames, FRAME_SECONDS, func(frame: int) -> void:
		var progress: float = minf(START_PROGRESS + frame * FX_FRAME_PROGRESS, 1.0)
		if frame < contact_frame:
			scene._render_board_state(before, {"effect": effect, "effect_progress": progress})
			return
		if landed.is_empty():
			scene._apply_animation_step(animated_state, step)
			_land_ground(animated_state, step)
			# The rock's slam now, the fire's bloom peaking 0.14 s later: one impact.
			scene._sfx_router.request("push.collision")
			scene._sfx_router.request("spell.fire", {"gain_db": 3.0})
			landed.merge(scene._death_hold_presentation(before, animated_state, base))
		var shown: Dictionary = landed.duplicate(false)
		shown["effect_progress"] = progress
		shown["floating_texts"] = FloatingCombatText.animate_entries(texts, (frame - contact_frame) * FRAME_SECONDS, reduced)
		scene._render_board_state(animated_state, shown)
	)
	await scene._animate_turn_order_alongside_defeats(before, animated_state)

static func _land_ground(state: Dictionary, step: Dictionary) -> void:
	var surfaces: Dictionary = (state.get("surfaces", {}) as Dictionary).duplicate(true)
	var landed: Dictionary = step.get("meteor_surfaces", {})
	for key: String in landed:
		if (landed[key] as Dictionary).is_empty(): surfaces.erase(key)
		else: surfaces[key] = (landed[key] as Dictionary).duplicate(true)
	state["surfaces"] = surfaces
	var marks: Array = (state.get("meteor_marks", []) as Array).duplicate(true)
	for index: int in marks.size():
		if marks[index].get("tiles", []) == step.get("focus_tiles", []):
			marks.remove_at(index)
			break
	state["meteor_marks"] = marks

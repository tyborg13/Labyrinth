extends RefCounted

const Facing = preload("res://scripts/hero_facing_state.gd")
var current: Dictionary = Facing.FRONT.duplicate()
var enabled: bool = true
var enemy_step: Dictionary = {}

func reset(state: Dictionary, persist: bool) -> void:
	enabled = persist
	enemy_step = {}
	current = Facing.ensure(state).duplicate() if enabled and not state.is_empty() else Facing.FRONT.duplicate()

func begin_action(engine: RefCounted, state: Dictionary, action: Dictionary, target: Vector2i) -> void:
	if enabled and str(action.get("type", "")) != "move":
		current = Facing.direction(Facing.action_delta(engine, state, action, target), current)

func move_step(delta: Vector2i) -> void:
	if enabled: current = Facing.direction(delta, current)

func decorate(state: Dictionary, presentation: Dictionary, fresh_feedback: Variant = null) -> void:
	if not enabled: return
	var motion: Dictionary = presentation.get("protagonist_motion", {}).duplicate(false)
	if str(motion.get("clip", "")) == "walk":
		move_step(motion.get("direction", Vector2i.ZERO))
	# Pacing retains old popups across actions. They must never lend the next
	# source an early impact; read only this submission's unmerged feedback.
	var feedback: Dictionary = presentation if fresh_feedback == null else fresh_feedback
	var contact: bool = (feedback.get("impact_actor_keys", []) as Array).has("player")
	for text: Dictionary in feedback.get("floating_texts", []):
		if text.get("reaction_actor_key", "") == "player" and text.get("reaction", "") in ["hit", "block"] and text.has("animation_progress"): contact = true
	if contact:
		var effect: Dictionary = feedback.get("effect", {})
		current = Facing.direction(Facing.source_delta(state, enemy_step if effect.is_empty() else effect), current)
	motion["hero_facing"] = current.duplicate()
	presentation["protagonist_motion"] = motion

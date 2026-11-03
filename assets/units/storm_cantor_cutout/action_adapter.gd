extends RefCounted

## Peal's rule owns its independent strike timing. Place the gesture after its
## steps, before that existing presentation; a stationary Peal still gestures.
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")

static func presentation_steps(actor: Dictionary, steps: Array) -> Array:
	var key: String = "enemy_%d" % int(actor.get("id", -1))
	var intent: String = str(actor.get("intent", {}).get("id", ""))
	var insertion: int = -1
	var owns_activation: bool = false
	for index: int in range(steps.size()):
		var step: Dictionary = steps[index]
		if str(step.get("actor_key", "")) != key: continue
		if str(step.get("kind", "")) == "cutout_gesture": return steps
		if bool(step.get("cancelled", false)) or bool(step.get("hidden_by_umbra", false)): continue
		if not str(step.get("no_action_reason", "")).is_empty(): continue
		if str(step.get("kind", "")) in ["intent", "move"]:
			owns_activation = true
			intent = str(step.get("intent_id", intent))
			insertion = index + 1
	if intent != "peal" or not owns_activation: return steps
	# A source activation can have no move at all. Its ordinary rule steps are
	# still present, so the gesture precedes them without creating a rule beat.
	if insertion < 0: insertion = 0
	var result: Array = steps.duplicate(false)
	result.insert(insertion, {"kind":"cutout_gesture", "actor_key":key,
		"action_type":"move_toward", "intent_id":"peal"})
	return result

static func handles(step: Dictionary, actor: Dictionary) -> bool:
	return (str(step.get("kind", "")) == "cutout_gesture" and str(step.get("intent_id", "")) == "peal") or (str(step.get("kind", "")) == "summon" and Action.clip_for(step, actor) == "call_the_spark")

static func animate(scene: Control, state: Dictionary, step: Dictionary, actor: Dictionary) -> void:
	if str(step.get("kind", "")) == "summon":
		await preload("res://scripts/maquette_cutout_runtime/contact_actions.gd").animate(scene, state, step, actor)
		# The contact route precedes the legacy summon dispatcher. Retain its
		# existing reward feedback after the authored summon completes.
		await preload("res://scripts/summon_card_play_rules.gd").present(scene, state, step)
		return
	var reduced: bool = scene._reduced_motion_enabled()
	var count: int = 1 if reduced else Action.frames_for("storm_cantor", "peal")
	var contact: float = float(Action.data_for("storm_cantor")["clips"]["peal"]["contact"])
	var key: String = str(step["actor_key"])
	actor = Action.actor_for(state, key)
	if actor.is_empty() or int(actor.get("hp", 0)) <= 0: return
	var direction: Vector2i = state["player"]["pos"] - actor["pos"]
	await scene._play_timed_animation_frames(count, 0.0 if reduced else 1.0 / Action.FPS, func(frame: int) -> void:
		var intervals: int = maxi(1, count - 1)
		var phase: float = 1.0 if reduced else Action.contact_phase(float(frame - 1) / intervals, ceilf(contact * intervals) / intervals, contact)
		scene._render_board_state(state, {"maquette_explicit_clip":true,
			"storm_cantor_motion":{key:{"clip":"peal", "phase":phase, "direction":direction}}}, true)
	)

extends RefCounted
## Presentation-only reconciliation at a completed turn; never changes resolved rules.

# atk-12: the first step past an enemy's completed turn: its intent refresh, or
# the rail's reschedule when the source has no next intent. The engine appends
# these only once the turn (and any battlefield beat it triggers) has resolved.
static func completion_step(steps: Array) -> Variant:
	var found: Variant = null
	for index: int in range(steps.size() - 1, -1, -1):
		var step: Dictionary = steps[index]
		var kind: String = str(step.get("kind", ""))
		if kind == "commit": continue
		if kind == "intent_refresh" or (kind == "turn_order" and str(step.get("label", "")) == "reschedule"):
			found = step
			continue
		break
	return found

# atk-12: a hero loss the engine dealt with no step of its own: a battlefield
# rule beat as its source's turn completes (Zekarion's Lightning Storm on
# Overload, Iskaldra's Frostbite on Rime Talon) or right after the hero's turn
# (a room's Frostbite). Playback has applied every step's loss; what the
# resolved state adds plays the existing hero-loss beat (number, Health bar,
# hit reaction). `animated_state` is the shown state; its hero is updated.
static func present(scene: Node, animated_state: Dictionary, resolved_state: Dictionary) -> void:
	# The Burst journal owns its own hero numbers. Reconcile only the state
	# before the first still-unconsumed Burst, leaving that presenter's loss intact.
	resolved_state = preload("res://scripts/enemy_mechanics/burst_playback.gd").before_bursts(animated_state, resolved_state)
	var shown: Dictionary = animated_state.get("player", {})
	var resolved: Dictionary = resolved_state.get("player", {})
	var player: Dictionary = shown.duplicate(true)
	for field: String in ["hp", "block", "stoneskin"]:
		player[field] = mini(int(shown.get(field, 0)), int(resolved.get(field, 0)))
	var after_state: Dictionary = animated_state.duplicate(false)
	after_state["player"] = player
	if not scene._player_took_loss(animated_state, after_state):
		return
	await scene._animate_floating_text_presentation(after_state, scene._death_hold_presentation(animated_state, after_state, {
		"floating_texts": scene._player_loss_floating_texts(animated_state, after_state),
		"impact_actor_keys": ["player"]
	}))
	animated_state["player"] = player


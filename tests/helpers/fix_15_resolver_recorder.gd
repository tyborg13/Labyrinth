extends "res://scripts/combat_engine.gd"

# Independent oracle: record raw resolver-owned states at existing resolver
# boundaries, before presentation builders can omit or rewrite any field.
const OrderedJournal = preload("res://tests/helpers/fix_15_ordered_journal.gd")
var journal := OrderedJournal.new()
var journal_active: bool = false
var journal_live_state: Dictionary
var journal_bleed_stopped: bool = false

var resolved_states: Array[Dictionary]

func _init() -> void:
	journal.encode = Callable(load("res://tests/helpers/fix_15_state_invariant.gd"), "serialized")
	set_meta("resolver_journal_observer", observe_resolver)
	set_meta("reaction_state_observer", remember)

func remember(state: Dictionary) -> int:
	resolved_states.append(state.duplicate(true))
	return resolved_states.size() - 1

func _resolve_enemy_start_of_turn(state: Dictionary, index: int) -> Dictionary:
	journal_active = preload("res://scripts/enemy_mechanics/reaction_loss_ownership.gd").traced_intent(state["enemies"][index].get("intent", {}))
	journal_live_state = state
	var result: Dictionary = super._resolve_enemy_start_of_turn(state, index)
	journal_active = false
	if preload("res://scripts/enemy_mechanics/reaction_loss_ownership.gd").traced_intent(result["state"]["enemies"][index].get("intent", {})):
		for step: Dictionary in result["steps"]:
			if step.get("label", "") in ["Frozen", "Petrified", "Shocked", "Immobilized"]: step["_resolver_boundary_id"] = remember(result["state"])
	return result

func _enemy_intent_step_for_player(state: Dictionary, enemy: Dictionary, intent: Dictionary) -> Dictionary:
	if preload("res://scripts/enemy_mechanics/reaction_loss_ownership.gd").traced_intent(intent): journal.instant(state, {"kind": "intent", "id": enemy["id"]})
	var step: Dictionary = super._enemy_intent_step_for_player(state, enemy, intent)
	if preload("res://scripts/enemy_mechanics/reaction_loss_ownership.gd").traced_intent(intent): step["_resolver_boundary_id"] = remember(state)
	return step

func resolve_enemy_turn_with_steps(state: Dictionary, index: int, commits: bool = true, choose: bool = true, accepted: Callable = Callable()) -> Dictionary:
	return _completion(super.resolve_enemy_turn_with_steps(state, index, commits, choose, accepted))

func resolve_enemy_phase_with_steps(state: Dictionary) -> Dictionary:
	return _completion(super.resolve_enemy_phase_with_steps(state))

func _completion(phase: Dictionary) -> Dictionary:
	journal.instant(phase["state"], {"kind": "complete"}, true)
	var steps: Array = phase["steps"]
	if not steps.is_empty() and bool(steps.back().get("trace_state_complete", false)): steps.back()["_resolver_boundary_id"] = remember(phase["state"])
	return phase

func _enemy_action_step(before: Dictionary, after: Dictionary, index: int, action: Dictionary, context: Dictionary = {}) -> Dictionary:
	var step: Dictionary = super._enemy_action_step(before, after, index, action, context)
	var trace: Dictionary = context.get("reaction_trace", {})
	if trace.has("action_boundary_id"):
		step["_resolver_boundary_id"] = trace["action_boundary_id"]
	elif not step.is_empty() and (step.has("en03_after") or step.has("en06_after")): step["_resolver_boundary_id"] = remember(after)
	if step.has("move_step"): step["move_step"]["_resolver_boundary_id"] = remember(context["move_state"])
	return step

func observe_resolver(event: String, state: Dictionary, owner: Dictionary) -> void:
	if journal_active and is_same(state, journal_live_state): journal.observe(event, state, owner)

func _resolve_enemy_action(state: Dictionary, index: int, action: Dictionary, rng: RandomNumberGenerator = null, followup: Dictionary = {}, bleed_steps: Array[Dictionary] = [], context: Dictionary = {}) -> Dictionary:
	journal_active = preload("res://scripts/enemy_mechanics/reaction_loss_ownership.gd").traced_intent(state["enemies"][index].get("intent", {}))
	journal_live_state = state
	journal.bleed_paid = false
	journal_bleed_stopped = false
	var previous_actions: int = journal.action_count
	var result: Dictionary = super._resolve_enemy_action(state, index, action, rng, followup, bleed_steps, context)
	if journal_active and journal.action_count == previous_actions and not journal_bleed_stopped:
		journal.instant(result, {"kind": "action"}) # Resolver cancellation, not a returned-step inspection.
	journal_active = false
	return result

func _trigger_enemy_bleed_for_resolved_action(state: Dictionary, index: int, action: Dictionary, steps: Array[Dictionary]) -> Dictionary:
	journal_active = preload("res://scripts/enemy_mechanics/reaction_loss_ownership.gd").traced_intent(state["enemies"][index].get("intent", {}))
	journal_live_state = state
	var enemy: Dictionary = state["enemies"][index]
	var pays: bool = _enemy_action_triggers_bleed(action) and int(enemy.get("bleed", 0)) > 0 and int(enemy.get("hp", 0)) > 0
	var result: Dictionary = super._trigger_enemy_bleed_for_resolved_action(state, index, action, steps)
	if pays and _enemy_cannot_continue_after_bleed(result, index): journal_bleed_stopped = true
	if journal_active: journal_live_state = result # This resolver helper returns an owned duplicate.
	return result

func _move_enemy_along_planned_path(state: Dictionary, index: int, path: Array[Vector2i], context: Dictionary, allowance: int = -1) -> Dictionary:
	var first: int = journal.events.size()
	var paid: bool = journal.bleed_paid
	var result: Dictionary = super._move_enemy_along_planned_path(state, index, path, context, allowance)
	if journal_active: journal.finish_movement(first, paid)
	return result

extends "res://scripts/combat_engine.gd"

## Presentation adapter used by the live scene and playtest console. The base
## resolver stays unchanged; previews receive their own additive facing field.
const HeroFacing = preload("res://scripts/hero_facing_state.gd")
var persist_hero_facing: bool = true
var _direct_hit_context: Dictionary = {}

func _resolve_enemy_action(state: Dictionary, index: int, action: Dictionary, rng: RandomNumberGenerator = null, followup: Dictionary = {}, bleed: Array[Dictionary] = TypedArrays.dictionaries([]), context: Dictionary = {}) -> Dictionary:
	if not persist_hero_facing: return super._resolve_enemy_action(state, index, action, rng, followup, bleed, context)
	var previous: Dictionary = _direct_hit_context
	_direct_hit_context = context
	_direct_hit_context["direct_player_hits"] = []
	var result: Dictionary = super._resolve_enemy_action(state, index, action, rng, followup, bleed, context)
	_direct_hit_context = previous
	return result

func _damage_player(state: Dictionary, damage: int, bypass: bool, incoming: bool = true, cause: String = "damage", defer_defiance: bool = false) -> Dictionary:
	var source: Dictionary = state.get("damage_context", {})
	# Trap/surface/status damage can inherit an enemy id. Only an executed
	# direct hit owns facing; aggregate step loss cannot establish that cause.
	if not _direct_hit_context.is_empty() and damage > 0 and incoming and str(source.get("actor_kind", "")) == "enemy" and str(source.get("source_kind", "")) == "direct_attack":
		var index: int = _enemy_index_for_id(state, int(source.get("actor_id", -1)))
		if index >= 0:
			_direct_hit_context["direct_player_hits"].append({"source_actor_key": _enemy_key(state["enemies"][index]), "source_tile": state["enemies"][index]["pos"], "target_key": "player", "target_tile": state["player"]["pos"], "damage": damage})
	return super._damage_player(state, damage, bypass, incoming, cause, defer_defiance)

func _enemy_action_step(before: Dictionary, after: Dictionary, index: int, action: Dictionary, context: Dictionary = {}) -> Dictionary:
	var step: Dictionary = super._enemy_action_step(before, after, index, action, context)
	if persist_hero_facing and not step.is_empty():
		# An explicit empty list is significant: this attack may only have
		# triggered a trap, even though its aggregate player losses are nonzero.
		step["direct_player_hits"] = context.get("direct_player_hits", []).duplicate(true)
	return step

func _apply_player_action(state: Dictionary, action: Dictionary, target: Vector2i, validate: bool, trace: Dictionary = {}) -> Dictionary:
	var result: Dictionary = super._apply_player_action(state, action, target, validate, trace)
	if persist_hero_facing and result != state:
		HeroFacing.player_action(self, state, result, _resolved_surface_action(state, action), target)
	return result

func resolve_enemy_turn_with_steps(state: Dictionary, index: int, commits: bool = true, next_intent: bool = true, accepted: Callable = Callable()) -> Dictionary:
	var result: Dictionary = super.resolve_enemy_turn_with_steps(state, index, commits, next_intent, accepted)
	if persist_hero_facing: HeroFacing.enemy_result(state, result)
	return result

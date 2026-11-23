extends "res://scripts/combat_engine.gd"

## Facing adapter used by the live scene and playtest console.
const HeroFacing = preload("res://scripts/hero_facing_state.gd")
var persist_hero_facing: bool = true:
	set(value):
		if persist_hero_facing != value: _threat_preview_cache.clear()
		persist_hero_facing = value
var _direct_hit_context: Dictionary = {}

func _preview_facing_mode() -> Variant:
	return persist_hero_facing if _cursor_facing_mode == null else _cursor_facing_mode

func hero_facing_direction(state: Dictionary) -> Vector2i:
	if not bool(_preview_facing_mode()):
		return HeroFacing.tile_direction(HeroFacing.FRONT)
	return super.hero_facing_direction(state)

func _compact_enemy_action_step(before: Dictionary, after: Dictionary, index: int, action: Dictionary, context: Dictionary) -> Dictionary:
	var compact: Dictionary = super._compact_enemy_action_step(before, after, index, action, context)
	if bool(_preview_facing_mode()) and not (context.get("direct_player_hits", []) as Array).is_empty():
		# Keep the regular step's hit attribution even when PASS only collects losses.
		compact["hero_facing_delta"] = HeroFacing.source_delta(before, _enemy_action_step(before, after, index, action, context))
	return compact

func _resolve_enemy_action(state: Dictionary, index: int, action: Dictionary, rng: RandomNumberGenerator = null, followup: Dictionary = {}, reserved_status_steps: Array[Dictionary] = TypedArrays.dictionaries([]), context: Dictionary = {}) -> Dictionary:
	if not bool(_preview_facing_mode()): return super._resolve_enemy_action(state, index, action, rng, followup, reserved_status_steps, context)
	var previous: Dictionary = _direct_hit_context
	_direct_hit_context = context
	_direct_hit_context["direct_player_hits"] = []
	var result: Dictionary = super._resolve_enemy_action(state, index, action, rng, followup, reserved_status_steps, context)
	_direct_hit_context = previous
	return result

func _damage_player(state: Dictionary, damage: int, bypass: bool, incoming: bool = true, cause: String = "damage", defer_defiance: bool = false, apply_expose: bool = true) -> Dictionary:
	var source: Dictionary = state.get("damage_context", {})
	# Trap/surface/status damage can inherit an enemy id. Only an executed
	# direct hit owns facing; aggregate step loss cannot establish that cause.
	if not _direct_hit_context.is_empty() and damage > 0 and incoming and str(source.get("actor_kind", "")) == "enemy" and str(source.get("source_kind", "")) == "direct_attack":
		var index: int = _enemy_index_for_id(state, int(source.get("actor_id", -1)))
		if index >= 0:
			_direct_hit_context["direct_player_hits"].append({"source_actor_key": _enemy_key(state["enemies"][index]), "source_tile": state["enemies"][index]["pos"], "target_key": "player", "target_tile": state["player"]["pos"], "damage": damage})
	return super._damage_player(state, damage, bypass, incoming, cause, defer_defiance, apply_expose)

func _enemy_action_step(before: Dictionary, after: Dictionary, index: int, action: Dictionary, context: Dictionary = {}) -> Dictionary:
	var step: Dictionary = super._enemy_action_step(before, after, index, action, context)
	if bool(_preview_facing_mode()) and not step.is_empty():
		# An explicit empty list is significant: this attack may only have
		# triggered a trap, even though its aggregate player losses are nonzero.
		step["direct_player_hits"] = context.get("direct_player_hits", []).duplicate(true)
	return step

func _apply_player_action(state: Dictionary, action: Dictionary, target: Vector2i, validate: bool, trace: Dictionary = {}) -> Dictionary:
	var result: Dictionary = super._apply_player_action(state, action, target, validate, trace)
	if bool(_preview_facing_mode()) and result != state:
		HeroFacing.player_action(self, state, result, _resolved_surface_action(state, action), target)
	return result

func resolve_enemy_turn_with_steps(state: Dictionary, index: int, commits: bool = true, next_intent: bool = true, accepted: Callable = Callable()) -> Dictionary:
	var result: Dictionary = super.resolve_enemy_turn_with_steps(state, index, commits, next_intent, accepted)
	if bool(_preview_facing_mode()): HeroFacing.enemy_result(state, result)
	return result

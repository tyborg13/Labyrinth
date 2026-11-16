extends "res://tools/zek01/measurement_combat.gd"
## Extra audit-only route metadata; the measured sweep keeps its original tracer.
func _board_attack_plan(state: Dictionary, action: Dictionary, impact: Array[Vector2i], actor_kind: String) -> Dictionary:
	var plan: Dictionary = super._board_attack_plan(state, action, impact, actor_kind)
	var kinds: Dictionary = {}
	for hit: Dictionary in plan.get("hits", []):
		if str(hit.get("kind", "")) not in ["player", "enemy"]: continue
		var key: String = "player" if str(hit["kind"]) == "player" else str(hit.get("id", -1))
		kinds[key] = str(hit.get("kind_trace", ""))
	state["_zek01_hit_kinds"] = kinds
	return plan

func _receipt(state: Dictionary, target: String, hp_before: int, block_before: int, context: Dictionary, cause: String, damage: int, pos: Vector2i) -> void:
	context = context.duplicate(true)
	context["hit_kind"] = str(state.get("_zek01_hit_kinds", {}).get(target, ""))
	super._receipt(state, target, hp_before, block_before, context, cause, damage, pos)

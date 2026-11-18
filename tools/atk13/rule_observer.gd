extends "res://scripts/combat_engine.gd"
## Opt-in resolver receipts; only the actual primitive arguments are observed.
var impacts: Array[Dictionary]
var fatigue_hp_loss: int = 0

func _resolve_board_attack(state: Dictionary, action: Dictionary, target: Vector2i, actor_kind: String = "player", actor_id: int = -1, trace: Dictionary = {}, supplied_impact: Array[Vector2i] = TypedArrays.vector2i([])) -> Dictionary:
	if bool(action.get("_battlefield_all_units", false)):
		impacts.append({"rule": state["battlefield_rule"]["rule"], "clock": state.get("initiative_clock", 0), "sequence": state.get("surface_event_sequence", 0), "beat": state["battlefield_rule"].get("beats_fired", 0), "tiles": supplied_impact.duplicate()})
	return super._resolve_board_attack(state, action, target, actor_kind, actor_id, trace, supplied_impact)

func _draw_cards_in_place(state: Dictionary, count: int) -> Dictionary:
	var before: int = int(state.get("run_stats", {}).get(RUN_STAT_DAMAGE_RECEIVED, 0))
	var after: Dictionary = super._draw_cards_in_place(state, count)
	fatigue_hp_loss += maxi(0, int(after.get("run_stats", {}).get(RUN_STAT_DAMAGE_RECEIVED, 0)) - before)
	return after

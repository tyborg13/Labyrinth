extends "res://tools/atk13/observed_engine.gd"
const Areas = preload("res://scripts/boss_area_rules.gd")
func _resolve_enemy_action(state: Dictionary, index: int, action: Dictionary, rng: RandomNumberGenerator = null, followup: Dictionary = {}, bleed: Array[Dictionary] = TypedArrays.dictionaries([]), context: Dictionary = {}) -> Dictionary:
	if not observing: return super._resolve_enemy_action(state,index,action,rng,followup,bleed,context)
	var before: Dictionary = state.duplicate(true)
	var result: Dictionary = super._resolve_enemy_action(state,index,action,rng,followup,bleed,context)
	if Areas.held(action):
		var record: Dictionary = receipts.back()
		# The real resolved animation/effect receipt, including empty areas,
		# rather than the warning queried again after the board has changed.
		var step: Dictionary = _enemy_action_step(before,result,index,action,context)
		record["area_shown"] = Areas.shown(action)
		record["area_kind"] = str(action.get("area_targeting", Areas.FIXED_KIND))
		record["area_anchor"] = before["enemies"][index]["pos"]
		record["area_planned_origin"] = action.get("area_planned_origin", before["enemies"][index]["pos"])
		record["area_expected"] = Areas.at_anchor(action, before["enemies"][index]["pos"])
		record["area_struck"] = step.get("tiles", [])
		record["area_inert"] = Areas.at_anchor(action, before["enemies"][index]["pos"]).filter(func(tile: Vector2i) -> bool: return not Areas.strike_tiles(self,before,action).has(tile))
	if str(action.get("type", "")) == "erupt":
		var record: Dictionary = receipts.back()
		var step: Dictionary = _enemy_action_step(before,result,index,action,context)
		record["marked_landing"] = before["enemies"][index].get("erupt_tile", before["enemies"][index]["pos"])
		record["surface_landing"] = result["enemies"][index]["pos"]
		record["marked_player_hits"] = step.get("direct_player_hits", [])
	return result

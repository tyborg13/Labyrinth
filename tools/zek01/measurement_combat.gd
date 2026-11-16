extends "res://scripts/combat_engine.gd"
## Measurement-only damage receipts live on candidate states. The bot discards
## speculative candidates normally, so only accepted-state receipts survive.
func _receipt(state: Dictionary, target: String, hp_before: int, block_before: int, context: Dictionary, cause: String, damage: int, pos: Vector2i) -> void:
	var unit: Dictionary = state["player"] if target == "player" else _surface_actor(state, "enemy", int(target))
	var hp_loss: int = maxi(0, hp_before - int(unit.get("hp", 0)))
	var defense_loss: int = maxi(0, block_before - int(unit.get("block", 0)))
	if hp_loss <= 0 and defense_loss <= 0 and damage <= 0: return
	if not state.has("_zek01_receipts"): state["_zek01_receipts"] = []
	state["_zek01_receipts"].append({"turn":state["turn"], "clock":state.get("initiative_clock", 0), "phase":state.get("_zek01_phase", ""), "target":target, "tile":pos, "hp_loss":hp_loss, "block_loss":defense_loss, "raw_damage":damage, "cause":cause, "source":context})

func _damage_player(state: Dictionary, damage: int, bypass_block: bool, apply_incoming_hit_effects: bool = true, cause: String = "damage", defer_defiance: bool = false) -> Dictionary:
	var hp: int = int(state["player"]["hp"])
	var block: int = int(state["player"].get("block", 0))
	var context: Dictionary = state.get("damage_context", {}).duplicate(true)
	var pos: Vector2i = state["player"]["pos"]
	var result: Dictionary = super._damage_player(state, damage, bypass_block, apply_incoming_hit_effects, cause, defer_defiance)
	_receipt(result, "player", hp, block, context, cause, damage, pos)
	return result

func _damage_enemy(state: Dictionary, enemy_index: int, damage: int, apply_freeze_multiplier: bool = true, bypass_defense: bool = false, apply_relic_bonus: bool = true, apply_direct_amplification: bool = true) -> Dictionary:
	var enemy: Dictionary = state["enemies"][enemy_index]
	var hp: int = int(enemy["hp"])
	var block: int = int(enemy.get("block", 0))
	var id: String = str(enemy["id"])
	var pos: Vector2i = enemy["pos"]
	var context: Dictionary = state.get("damage_context", {}).duplicate(true)
	var result: Dictionary = super._damage_enemy(state, enemy_index, damage, apply_freeze_multiplier, bypass_defense, apply_relic_bonus, apply_direct_amplification)
	_receipt(result, id, hp, block, context, "damage", damage, pos)
	return result

extends RefCounted
const CombatEngine = preload("res://scripts/combat_engine.gd")

static func _simple_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array[String]
		for x: int in range(8):
			if x == 0 or y == 0 or x == 7 or y == 7:
				row.append("wall")
			else:
				row.append("stone")
		grid.append(row)
	return grid

static func _simple_room_layout() -> Dictionary:
	return {
		"name": "Test Room",
		"coord": Vector2i(1, 0),
		"type": "combat",
		"grid": _simple_grid(),
		"player_start": Vector2i(2, 4),
		"enemies": [
			{
				"id": 1,
				"type": "crawler",
				"pos": Vector2i(5, 2),
				"hp": 14,
				"max_hp": 14,
				"block": 0
			}
		],
		"loot": []
	}

static func _pass_preview_chip_state(kind: String) -> Dictionary:
	var combat: CombatEngine = CombatEngine.new()
	var has_defiance_followup: bool = kind in ["defiance_followup", "defiance_umbra"]
	var starting_hp: int = 5 if has_defiance_followup else 24
	var state: Dictionary = combat.create_combat(7826, _simple_room_layout(), {
		"hp": starting_hp,
		"max_hp": 24,
		"deck_cards": ["guarded_step", "quick_stab", "patch_up", "bone_dart"],
		"relics": [],
		"hand_size": 2,
		"heal_bonus": 0,
		"defiance_capacity": 1 if has_defiance_followup else 0,
		"defiance_remaining": 1 if has_defiance_followup else 0
	})
	var enemy_pos: Vector2i = Vector2i(3, 4)
	var enemy_intent: Dictionary = {"name": "Claw", "time": 1, "actions": [{"type": "melee", "damage": 5, "range": 1}]}
	if kind == "safe":
		enemy_pos = Vector2i(6, 4)
	elif kind == "layered":
		enemy_intent = {"name": "Crush", "time": 1, "actions": [{"type": "melee", "damage": 12, "range": 1}]}
	elif kind == "lethal":
		enemy_intent = {"name": "Crush", "time": 1, "actions": [{"type": "melee", "damage": 30, "range": 1}]}
	elif has_defiance_followup:
		enemy_intent = {"name": "Lethal Claw", "time": 1, "actions": [{"type": "melee", "damage": 6, "range": 1}]}
	elif kind == "unrevealed":
		enemy_pos = Vector2i(6, 4)
	elif kind == "umbra":
		enemy_pos = Vector2i(6, 4)
	state["player"] = {
		"pos": Vector2i(2, 4),
		"hp": starting_hp,
		"max_hp": 24,
		"block": 3 if kind == "layered" else 0,
		"stoneskin": 4 if kind == "layered" else 0,
		"burn": 0,
		"bleed": 0,
		"expose": 0,
		"freeze": 0,
		"shock": 0,
		"immobilize": false,
		"poison": {"damage": 0, "trigger": 0, "stacks": []}
	}
	state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": enemy_pos,
		"hp": 14,
		"max_hp": 14,
		"block": 0,
		"stoneskin": 0,
		"burn": 0,
		"bleed": 0,
		"expose": 0,
		"freeze": 0,
		"shock": 0,
		"immobilize": false,
		"poison": {"damage": 0, "trigger": 0, "stacks": []},
		"intent": enemy_intent
	}]
	if has_defiance_followup:
		var followup_pos := Vector2i(6, 4) if kind == "defiance_umbra" else Vector2i(2, 3)
		state["enemies"].append({
			"id": 2,
			"type": "crawler",
			"pos": followup_pos,
			"hp": 14,
			"max_hp": 14,
			"block": 0,
			"stoneskin": 0,
			"burn": 0,
			"bleed": 0,
			"expose": 0,
			"freeze": 0,
			"shock": 0,
			"immobilize": false,
			"poison": {"damage": 0, "trigger": 0, "stacks": []},
			"intent": {"name": "Follow-up", "time": 1, "actions": [{"type": "melee", "damage": 2, "range": 1}]}
		})
	state["illusions"] = []
	state["traps"] = []
	state["terrain"] = []
	state["deck"] = {
		"hand": ["guarded_step", "quick_stab"],
		"draw": ["patch_up", "bone_dart"],
		"discard": ["sidestep_slash"],
		"burned": [],
		"cycles": 0,
		"fatigue_base": 15
	}
	state["cards_per_turn"] = 2
	state["draw_per_turn"] = 2
	state["cards_played_this_turn"] = 0
	state["death_bonus_card_plays_this_turn"] = 0
	state["card_play_bonus_this_turn"] = 0
	state["player_turn_time_spent"] = 20 if kind == "unrevealed" else 0
	state["player_turn_restrictions"] = {"frozen": false, "shocked": false, "immobilized": false}
	state["pending_player_trap_restriction"] = ""
	state["turn_flags"] = {"first_attack_bonus_used": false, "first_move_bonus_used": false}
	state["initiative_clock"] = 0
	state["activation_seq"] = 1
	state["current_actor"] = {
		"kind": "player",
		"actor_key": "player",
		"name": "Reaver",
		"type": "player",
		"team": "player",
		"time": 0,
		"seq": 0
	}
	state["turn_queue"] = [{
		"kind": "enemy",
		"actor_key": "enemy_1",
		"enemy_id": 1,
		"type": "crawler",
		"name": "Tunnel Crawler",
		"team": "enemy",
		# Crawler repeats after 8 + 1 Time: 11 -> 20, after the +19 pass.
		# Only the isolated Wait-lapping case keeps the fast 1 -> 10 schedule.
		"time": 1 if kind == "wait_lapping" else 11,
		"seq": 1,
		"pos": enemy_pos
	}]
	if has_defiance_followup:
		var followup_queue_pos := Vector2i(6, 4) if kind == "defiance_umbra" else Vector2i(2, 3)
		state["turn_queue"].append({
			"kind": "enemy",
			"actor_key": "enemy_2",
			"enemy_id": 2,
			"type": "crawler",
			"name": "Tunnel Crawler",
			"team": "enemy",
			"time": 12,
			"seq": 2,
			"pos": followup_queue_pos
		})
	if kind in ["umbra", "defiance_umbra"]:
		var umbra: Dictionary = (state.get("umbra", {}) as Dictionary).duplicate(true)
		umbra["stage"] = "eclipse"
		umbra["stage_reduction"] = 0
		state["umbra"] = umbra
	return state

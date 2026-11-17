extends RefCounted
## Export the production row builders, preserving text/icons/tooltip wording.
const Icons = preload("res://scripts/action_icon_library.gd")
const Inspection = preload("res://scripts/pre_battle_inspection_view.gd")
const Data = preload("res://scripts/game_data.gd")
const Library = preload("res://scripts/guardian_library.gd")

static func collect(scene: Node, state: Dictionary) -> Dictionary:
	var board: Control = scene.get("board_view")
	var engine: RefCounted = scene.get("_combat_engine")
	var moves: Array[Dictionary]
	for type: String in ["storm_cantor", "lightning_wisp", "bell_tender"]:
		var unit: Dictionary = {}
		for enemy: Dictionary in state.get("enemies", []):
			if str(enemy["type"]) == type:
				unit = enemy
				break
		if unit.is_empty(): continue
		var intents: Array = engine._scaled_enemy_intents(Data.enemy_def(type)["intents"], int(state.get("room_depth", 1)), state, unit)
		for intent: Dictionary in intents:
			var combat_rows: Array = board.call("_move_rows_for_unit", unit, intent)
			var pre_rows: Array = Inspection.move_rows(intent, {"type": type})
			moves.append({"enemy": type, "id": intent["id"], "name": intent["name"], "actions": intent["actions"],
				"combat_text": Icons.plain_text_for_rows(combat_rows), "combat_rows": combat_rows,
				"prebattle_text": Icons.plain_text_for_rows(pre_rows), "prebattle_tooltip": Inspection.move_tooltip(pre_rows), "prebattle_rows": pre_rows,
				"compact": preload("res://scripts/intent_badges.gd").descriptor(preload("res://scripts/intent_badges.gd").primary_action(intent), intent), "notes": Library.intent_notes(intent)})
	var panel: Dictionary = preload("res://scripts/battlefield_rules/dispatcher.gd").panel(state)
	return {"moves": moves, "rule": panel, "rule_tooltip": Icons.tooltip("lightning_storm"), "lightning_tooltip": Icons.tooltip("lightning_strikes"), "chain_tooltip": Icons.tooltip("chain")}

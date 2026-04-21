extends RefCounted
class_name DialogueEngine

const GameData = preload("res://scripts/game_data.gd")

func build_room_dialogue(room: Dictionary, run_state: Dictionary, progression: Dictionary) -> Dictionary:
	var npcs: Array = room.get("npcs", [])
	for npc_var: Variant in npcs:
		if typeof(npc_var) != TYPE_DICTIONARY:
			continue
		var dialogue: Dictionary = _dialogue_for_npc(npc_var as Dictionary, room, run_state, progression)
		if not dialogue.is_empty():
			return dialogue
	return {}

func _dialogue_for_npc(npc: Dictionary, room: Dictionary, run_state: Dictionary, progression: Dictionary) -> Dictionary:
	var npc_id: String = str(npc.get("id", ""))
	match npc_id:
		"emaciated_man":
			return _emaciated_man_dialogue(npc, room, run_state, progression)
		_:
			return {}

func _emaciated_man_dialogue(npc: Dictionary, room: Dictionary, _run_state: Dictionary, progression: Dictionary) -> Dictionary:
	var npc_id: String = str(npc.get("id", "emaciated_man"))
	var npc_def: Dictionary = GameData.npc_def(npc_id)
	var speaker: String = str(npc_def.get("name", npc.get("name", "Emaciated Man")))
	if bool(progression.get("rested_at_fire", false)):
		return {
			"id": "room_%d_%d_%s_awakened" % [int(room.get("coord", Vector2i.ZERO).x), int(room.get("coord", Vector2i.ZERO).y), npc_id],
			"npc_id": npc_id,
			"speaker": speaker,
			"accent": str(npc_def.get("accent", npc.get("accent", "#b8aa90"))),
			"lines": [
				{
					"speaker": speaker,
					"text": "Hmmmm…Rested by the fire, I see."
				},
				{
					"speaker": speaker,
					"bbcode": "I understand. the warmth is…[i]intoxicating[/i]"
				},
				{
					"speaker": speaker,
					"text": "Your freedom has been delayed, aye, but some power you have gained."
				},
				{
					"speaker": speaker,
					"text": "Much of my essence has been stolen by this accursed place."
				},
				{
					"speaker": speaker,
					"text": "Locked away, lest I tear the walls asunder."
				},
				{
					"speaker": speaker,
					"text": "Yet…something remains."
				},
				{
					"speaker": speaker,
					"text": "Let me but touch upon this newfound power and I will grant you magicks that may yet win your freedom.",
					"options": [
						{
							"label": "[touch the emaciated man]",
							"action": "open_card_upgrades"
						},
						{
							"label": "[begin your journey again]",
							"action": "close"
						}
					]
				}
			]
		}
	return {
		"id": "room_%d_%d_%s" % [int(room.get("coord", Vector2i.ZERO).x), int(room.get("coord", Vector2i.ZERO).y), npc_id],
		"npc_id": npc_id,
		"speaker": speaker,
		"accent": str(npc_def.get("accent", npc.get("accent", "#b8aa90"))),
		"lines": [
			{
				"speaker": speaker,
				"text": "Hehehe. You're back...so soon."
			},
			{
				"speaker": speaker,
				"text": "His creations got the best of you again."
			},
			{
				"speaker": speaker,
				"text": "Maybe this time's the one. Then again...probably not."
			}
		]
	}

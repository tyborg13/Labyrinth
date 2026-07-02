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
		"blacksmith", "arcanist", "scavenger":
			return _default_npc_dialogue(npc, room, run_state, progression)
		_:
			return {}

func _default_npc_dialogue(npc: Dictionary, room: Dictionary, _run_state: Dictionary, _progression: Dictionary) -> Dictionary:
	var npc_id: String = str(npc.get("id", ""))
	var npc_def: Dictionary = GameData.npc_def(npc_id)
	if npc_def.is_empty():
		return {}
	var speaker: String = str(npc_def.get("name", npc.get("name", npc_id)))
	var lines: Array = []
	for text_var: Variant in npc_def.get("default_dialogue", []):
		var text: String = str(text_var)
		if text.strip_edges().is_empty():
			continue
		lines.append({
			"speaker": speaker,
			"text": text
		})
	if lines.is_empty():
		lines.append({
			"speaker": speaker,
			"text": "There is business to settle before the path continues."
		})
	return {
		"id": "room_%d_%d_%s" % [int(room.get("coord", Vector2i.ZERO).x), int(room.get("coord", Vector2i.ZERO).y), npc_id],
		"npc_id": npc_id,
		"speaker": speaker,
		"accent": str(npc_def.get("accent", npc.get("accent", "#b8aa90"))),
		"lines": lines
	}

func _emaciated_man_dialogue(npc: Dictionary, room: Dictionary, _run_state: Dictionary, _progression: Dictionary) -> Dictionary:
	var npc_id: String = str(npc.get("id", "emaciated_man"))
	var npc_def: Dictionary = GameData.npc_def(npc_id)
	var speaker: String = str(npc_def.get("name", npc.get("name", "Emaciated Man")))
	var lines: Array = [
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
	return {
		"id": "room_%d_%d_%s" % [int(room.get("coord", Vector2i.ZERO).x), int(room.get("coord", Vector2i.ZERO).y), npc_id],
		"npc_id": npc_id,
		"speaker": speaker,
		"accent": str(npc_def.get("accent", npc.get("accent", "#b8aa90"))),
		"lines": lines
	}

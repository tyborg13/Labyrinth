extends RefCounted
class_name DialogueEngine

const GameData = preload("res://scripts/game_data.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")

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
			var dialogue: Dictionary = _emaciated_man_dialogue(npc, room, run_state, progression)
			var service: Dictionary = emaciated_service_dialogue(progression)
			if bool(run_state.get("emaciated_service_seen", false)) and not bool(dialogue.get("marks_umbra_warning_seen", false)):
				return service
			(dialogue["lines"] as Array).append(service["lines"][0])
			return dialogue
		"scavenger":
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

func _emaciated_man_dialogue(npc: Dictionary, room: Dictionary, run_state: Dictionary, progression: Dictionary) -> Dictionary:
	var npc_id: String = str(npc.get("id", "emaciated_man"))
	var npc_def: Dictionary = GameData.npc_def(npc_id)
	var speaker: String = str(npc_def.get("name", npc.get("name", "Emaciated Man")))
	var run_index: int = int(run_state.get("run_index", progression.get("run_counter", 0)))
	if ProgressionStore.umbra_warning_is_due(progression, run_index):
		return {
			"id": "room_%d_%d_%s_umbra_warning" % [int(room.get("coord", Vector2i.ZERO).x), int(room.get("coord", Vector2i.ZERO).y), npc_id],
			"npc_id": npc_id,
			"speaker": speaker,
			"accent": str(npc_def.get("accent", npc.get("accent", "#b8aa90"))),
			"marks_umbra_warning_seen": true,
			"lines": [
				{
					"speaker": speaker,
					"text": "You reached his shadow. It will only get stronger the further you stray from this place.",
					"bbcode": "You reached [i]his[/i] shadow. It will only get stronger the further you stray from this place."
				},
				{
					"speaker": speaker,
					"text": "Once, long ago, I was nearly a match for his power.",
					"bbcode": "Once, long ago, I was nearly a match for [i]his[/i] power."
				},
				{
					"speaker": speaker,
					"text": "After all this time, I can but provide this small measure of safety. The rest is up to you..."
				}
			]
		}
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

# Offers remain available while the player is at the entrance. Costs and disabled
# reasons use the same profile wallet as the actual transaction.
func emaciated_service_dialogue(progression: Dictionary, notice: String = "") -> Dictionary:
	var shards: int = ProgressionStore.moltshard_count(progression)
	var cost: int = ProgressionStore.next_level_cost(progression)
	var maximum: bool = ProgressionStore.is_max_level(progression)
	var summary: String = "%d %s · %d Embers · Level %d" % [shards, "Moltshard" if shards == 1 else "Moltshards", int(progression.get("embers", 0)), int(progression.get("level", 1))]
	var speech: String = "A dragon's cast-off scale still holds power. I can turn it to Embers... or help you grow stronger."
	if not notice.is_empty(): speech = notice
	return {"id":"emaciated_services", "npc_id":"emaciated_man", "speaker":"Emaciated Man", "accent":"#b8aa90", "lines":[{
		"speaker":"Emaciated Man", "service":true, "text":"%s\n%s" % [speech, summary],
		"options":[
			{"label":"Trade 1 Shard → %d Embers" % ProgressionStore.MOLT_EXCHANGE_EMBERS, "action":"exchange_moltshard", "disabled":shards < 1, "tooltip":"Exchange one Moltshard for %d Embers." % ProgressionStore.MOLT_EXCHANGE_EMBERS if shards > 0 else "You need 1 Moltshard. The first dragon defeated each run grants one."},
			{"label":"Maximum Level" if maximum else "Level Up · %d Embers" % cost, "action":"emaciated_level_up", "disabled":not ProgressionStore.can_level_up(progression), "tooltip":"Maximum level reached." if maximum else "Spend %d Embers to gain a level and a skill point." % cost},
			{"label":"Leave", "action":"close"}
		]
	}]}

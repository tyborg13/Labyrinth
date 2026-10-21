extends RefCounted
## Additive encounter dimensions shared by the UI and offline console. Room
## metadata survives combat-state clearing, including the reward choice boundary.
const Graph = preload("res://scripts/section_map_graph.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")

static func fields(run_state: Dictionary, combat: Dictionary, room: Dictionary) -> Dictionary:
	var layout: Dictionary = run_state.get("current_room_layout", {})
	var section_index: int = int(room.get("section_index", combat.get("section_index", -1)))
	var section: Dictionary = Graph.section(run_state, section_index)
	var biome: String = str(combat.get("biome", room.get("biome", layout.get("biome", ""))))
	if biome.is_empty() and not section.is_empty(): biome = Bosses.element_for_boss(str(section.get("boss_id", "")))
	return {
		"room_type": str(combat.get("room_type", room.get("type", ""))),
		"guardian_id": str(combat.get("guardian_id", room.get("guardian_id", ""))),
		"encounter_id": str(combat.get("encounter_id", room.get("encounter_id", layout.get("encounter_id", "")))),
		"biome": biome,
		"section_index": section_index,
		"special_type": str(room.get("special_type", "")),
		"special_variant": str(room.get("special_variant", ""))
	}

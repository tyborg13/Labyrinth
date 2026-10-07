extends RefCounted

## The protagonist cutout draws only items in their native slot. Open Arsenal can
## put another slot's item in the trinket slot; that slot then draws nothing
## rather than a misleading default. Kept outside the cutout runtime so the rig
## and renderer stay independent of the rules/data layer.
const GameData = preload("res://scripts/game_data.gd")

static func native_slot_loadout(equipped: Dictionary) -> Dictionary:
	var visible: Dictionary = {}
	for slot: Variant in equipped:
		var item_id: String = str(equipped[slot])
		if not item_id.is_empty() and GameData.equipment_slot(item_id) == str(slot):
			visible[str(slot)] = item_id
	return visible

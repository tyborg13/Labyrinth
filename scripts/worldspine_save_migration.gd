extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Rites = preload("res://scripts/rite_rules.gd")
const CARD_ID: String = "worldspine"

static func migrate(run: Dictionary) -> void:
	var previous: Dictionary = {}
	var carries_rite: bool = false
	if run.get("combat_state") is Dictionary:
		previous = run["combat_state"]
		carries_rite = _migrate_combat(previous, false)
	for checkpoint: Variant in run.get("pending_combat_checkpoints", []):
		if checkpoint is Dictionary and checkpoint.get("state") is Dictionary:
			var state: Dictionary = checkpoint["state"]
			carries_rite = _migrate_combat(state, carries_rite and _same_combat(previous, state))
			previous = state

static func _same_combat(previous: Dictionary, state: Dictionary) -> bool:
	return (
		(previous.has("fight_seed") or previous.has("room_coord"))
		and previous.get("fight_seed") == state.get("fight_seed")
		and previous.get("room_coord") == state.get("room_coord")
	)

static func _migrate_combat(state: Dictionary, carries_rite: bool) -> bool:
	for terrain: Dictionary in state.get("terrain", []):
		if terrain.get("kind") != CARD_ID or terrain.get("owner_kind") != "player":
			continue
		carries_rite = carries_rite or int(terrain.get("hp", 0)) > 0
		terrain["kind"] = "crag_outcrop"
		terrain["blocks_sight"] = true
		terrain.erase("pulse_damage")
	var already_active: bool = Rites.active_rites(state).any(func(rite: Variant) -> bool: return rite is Dictionary and rite.get("card_id") == CARD_ID)
	# The retired rule could deal at most one pulse even after several casts.
	if carries_rite and not already_active:
		Rites.start(state, CARD_ID, Data.card_def(CARD_ID))
	return carries_rite or already_active

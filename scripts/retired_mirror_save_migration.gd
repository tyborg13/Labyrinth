extends RefCounted

## Only live/resumable combat snapshots are content-migrated. Saved analytics,
## history, layout templates and arbitrary embedded dictionaries are archival.
static func migrate(run: Dictionary, convert_intents: bool = true) -> void:
	if run.get("combat_state") is Dictionary: _migrate_combat(run["combat_state"], convert_intents)
	for checkpoint: Variant in run.get("pending_combat_checkpoints", []):
		if checkpoint is Dictionary and checkpoint.get("state") is Dictionary: _migrate_combat(checkpoint["state"], convert_intents)

static func _migrate_combat(state: Dictionary, convert_intents: bool) -> void:
	if not state.get("player") is Dictionary or not state.get("enemies") is Array: return
	state.erase("last_hero_attack_card")
	if not convert_intents: return # Normalize legacy tenfold units first.
	for enemy: Dictionary in state.get("enemies", []):
		if str(enemy.get("type", "")) != "hollow_mimic" or str((enemy.get("intent", {}) as Dictionary).get("id", "")) != "mirror": continue
		for intent: Dictionary in preload("res://scripts/game_data.gd").enemy_def("hollow_mimic")["intents"]:
			if str(intent["id"]) == "echo": enemy["intent"] = intent.duplicate(true)

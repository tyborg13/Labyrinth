extends RefCounted

const ProgressionStore = preload("res://scripts/progression_store.gd")
const GrimoireLibrary = preload("res://scripts/grimoire_library.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")

# Loading merges only the embedded profile. Copy that branch, not the complete
# map/board/checkpoint history: reconcile and repair below each return their own
# deep snapshot before any other run field is mutated.
static func merge_profile(next_run_state: Dictionary, _progression: Dictionary) -> Dictionary:
	if _progression.is_empty():
		return next_run_state
	var state: Dictionary = next_run_state.duplicate(false)
	var embedded_progression: Dictionary = (state.get("progression", {}) as Dictionary).duplicate(true)
	if embedded_progression.is_empty():
		embedded_progression = _progression.duplicate(true)
	embedded_progression = ProgressionStore.merge_progression_analytics_outbox(embedded_progression, _progression)
	for key: String in [GrimoireLibrary.UNLOCKED_KEY, GrimoireLibrary.UNREAD_KEY]:
		var merged: Array[String]
		for entry_id: String in GrimoireLibrary.normalize_entry_ids(embedded_progression.get(key, [])):
			if not merged.has(entry_id):
				merged.append(entry_id)
		for entry_id: String in GrimoireLibrary.normalize_entry_ids(_progression.get(key, [])):
			if not merged.has(entry_id):
				merged.append(entry_id)
		embedded_progression[key] = GrimoireLibrary.ordered_entry_ids(merged)
	for profile_key: String in [ProgressionStore.RUN_BESTS_KEY, ProgressionStore.LAST_RUN_RESULT_KEY]:
		if _progression.has(profile_key) and typeof(_progression.get(profile_key)) == TYPE_DICTIONARY:
			embedded_progression[profile_key] = (_progression.get(profile_key) as Dictionary).duplicate(true)
	if _progression.has(ProgressionStore.RUN_RESULT_LEDGER_KEY) and typeof(_progression.get(ProgressionStore.RUN_RESULT_LEDGER_KEY)) == TYPE_ARRAY:
		embedded_progression[ProgressionStore.RUN_RESULT_LEDGER_KEY] = (_progression.get(ProgressionStore.RUN_RESULT_LEDGER_KEY) as Array).duplicate(true)
	for profile_key: String in [ProgressionStore.UMBRA_WARNING_AVAILABLE_RUN_KEY, ProgressionStore.UMBRA_WARNING_SEEN_KEY]:
		if _progression.has(profile_key):
			embedded_progression[profile_key] = _progression.get(profile_key)
	embedded_progression[ContextualCombatTutorial.PROGRESSION_KEY] = ContextualCombatTutorial.merged_state(
		_progression,
		embedded_progression
	)
	embedded_progression.erase(ContextualCombatTutorial.LEGACY_PROGRESSION_KEY)
	state["progression"] = embedded_progression
	return state


# repair_loaded_run_state returned exclusive ownership. Normalize the same
# analytics and Grimoire fields without duplicating the entire repaired room
# twice more. Keep the original metadata builder and its random-ID boundary.
static func finish_repair(scene: Node, owned: Dictionary) -> Dictionary:
	if not owned.is_empty():
		var metadata: Dictionary = scene._ensure_run_analytics_metadata({"analytics": owned.get("analytics", {})})
		owned["analytics"] = metadata["analytics"]
	GrimoireLibrary._ensure_run_state_in_place(owned)
	return owned

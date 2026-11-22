extends RefCounted

const ProgressionStore = preload("res://scripts/progression_store.gd")
const GrimoireLibrary = preload("res://scripts/grimoire_library.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Chronicle = preload("res://scripts/chronicle_rules.gd")

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
	if ProgressionStore.terminal_profile_write_pending(state, _progression):
		_retain_pending_terminal_result(state, embedded_progression)
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


static func _retain_pending_terminal_result(state: Dictionary, profile: Dictionary) -> void:
	# A run-first heirloom commit can be the only durable copy of this result.
	# Keep the disk history and restore the checkpoint's missing entry before
	# profile repair publishes the wallet, completion and outbox together.
	var result_id := Chronicle.record_id(state)
	var result := ProgressionStore.run_result_for_id(state["progression"], result_id)
	if result.is_empty() or not ProgressionStore.run_result_for_id(profile, result_id).is_empty(): return
	var ledger := ProgressionStore.completed_run_results(profile)
	ledger.append(result)
	profile[ProgressionStore.RUN_RESULT_LEDGER_KEY] = ledger
	profile[ProgressionStore.LAST_RUN_RESULT_KEY] = result
	var bests := ProgressionStore.run_bests(profile)
	var stats: Dictionary = result["stats"]
	for stat: String in ProgressionStore.BEST_ELIGIBLE_STAT_IDS:
		if stats.has(stat): bests[stat] = maxi(int(bests.get(stat, 0)), int(stats[stat]))
	profile[ProgressionStore.RUN_BESTS_KEY] = bests


# repair_loaded_run_state returned exclusive ownership. Normalize the same
# analytics and Grimoire fields without duplicating the entire repaired room
# twice more. Keep the original metadata builder and its random-ID boundary.
static func finish_repair(scene: Node, owned: Dictionary) -> Dictionary:
	if not owned.is_empty():
		var minted: bool = str((owned.get("analytics", {}) as Dictionary).get("run_id", "")).is_empty()
		var metadata: Dictionary = scene._ensure_run_analytics_metadata({"analytics": owned.get("analytics", {})})
		# A checkpoint saved without a run ID gets a new one on every load, so
		# that ID cannot tell a cloned run from a reload of the same run.
		if minted: metadata["analytics"]["run_id_minted_on_load"] = true
		owned["analytics"] = metadata["analytics"]
	GrimoireLibrary._ensure_run_state_in_place(owned)
	return owned

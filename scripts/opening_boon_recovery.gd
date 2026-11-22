extends RefCounted

## A run may be the only durable owner of a consumed heirloom or undelivered
## receipt. Transfer both before replacing or clearing that save.
const Store = preload("res://scripts/progression_store.gd")
const Rules = preload("res://scripts/opening_boon_rules.gd")
const Run = preload("res://scripts/run_engine.gd")
# Keep acknowledgment persistence injectable without changing other profile
# writes; focused recovery tests replace this for exactly one failed attempt.
static var profile_writer: Callable = Store.save_data

static func release_shutdown_callables() -> void:
	profile_writer = Callable()

static func retaining_events(host: Node, state: Dictionary, profile: Dictionary) -> Dictionary:
	var disk := Store.load_data()
	var next: Dictionary = Store.merge_progression_analytics_outbox(profile, disk)
	Store.merge_run_completion_ids(next, disk)
	if host.get("_opening_boon_flow").flush_events(host, state): return next
	return retain_pending_events(host, state, next)

static func retain_pending_events(host: Node, state: Dictionary, profile: Dictionary) -> Dictionary:
	var events: Array = state.get(Rules.EVENTS_KEY, [])
	if events.is_empty(): return profile
	var next := profile
	var context: Dictionary = host.call("_analytics_context_from_states", state)
	var analytics: RefCounted = host.get("_analytics_store")
	for index: int in range(events.size()):
		var event: Dictionary = events[index]
		var key: String = Rules.event_key(context, index, event)
		if not analytics.has_idempotency_key(key):
			next = Store.queue_progression_analytics_event(next, str(event["type"]), key, context, event["payload"])
	return next

static func persist_held_prompt_before_quit(host: Node, state: Dictionary) -> bool:
	# The held animation snapshot is already settled. Keep the original
	# unprocessed fallback until its profile is durable, matching the ordinary
	# terminal Quit ordering and its exact-fallback recovery contract.
	var retained: Dictionary = retaining_events(host, state, host.get("_progression"))
	if not Store.save_data(retained):
		push_error("Failed to persist terminal progression; the resumable fallback remains intact.")
		return false
	host.set("_progression", retained)
	return true

static func acknowledge_before_replacement(host: Node, state: Dictionary) -> bool:
	var disk: Dictionary = Store.load_data()
	var embedded: Dictionary = Store.normalized_data(state.get("progression", {}))
	# On a tie the profile may already hold a terminal wallet/recovery marker
	# newer than an active save. Only a strictly newer run supersedes its fields.
	var profile: Dictionary = embedded if int(embedded.get("progression_revision", 0)) > int(disk.get("progression_revision", 0)) else disk
	profile = Store.merge_progression_analytics_outbox(profile, embedded)
	Store.merge_run_completion_ids(profile, disk)
	Store.merge_run_completion_ids(profile, embedded)
	# Held run currency is not banked on abandonment. A terminal save's wallet
	# has already settled, so its newer profile balance is authoritative too.
	var mode: String = str(state.get("mode", ""))
	var settled_loss: bool = mode == "defeat" and not Store.has_completed_run(disk, state)
	if settled_loss and Store.completion_run_id(state).is_empty():
		settled_loss = not _recorded(disk, Run.run_result_id(state))
	if mode in ["victory", "defeat"]:
		profile = _terminal_profile(host, state, profile, embedded, disk)
	elif Store.embrace_settlement_pending(state, disk):
		# Without a synced profile, the terminal checkpoint owns the whole
		# settled progression, including its run counter and heirloom.
		if disk == Store.default_data():
			profile = embedded.duplicate(true)
		profile = Store.set_embers(profile, int(embedded.get("embers", 0)))
		profile["run_counter"] = maxi(int(profile.get("run_counter", 0)), int(embedded.get("run_counter", 0)))
		profile = Store.record_run_completion(profile, state)
		# A freshly synced terminal checkpoint can be the only copy of the
		# bank and result if the profile was still in rotation.
		if Store.run_result_for_id(profile, Run.run_result_id(state)).is_empty():
			for key: String in [Store.RUN_RESULT_LEDGER_KEY, Store.LAST_RUN_RESULT_KEY, Store.RUN_BESTS_KEY,
					Store.CHRONICLE_RECORDS_KEY, Store.CHRONICLE_TOTALS_KEY, Store.CHRONICLE_RECEIPTS_KEY]:
				if embedded.has(key): profile[key] = embedded[key]
	else:
		profile = Store.set_embers(profile, int(disk.get("embers", 0)))
	Store.reconcile_descent_reservation(profile, disk, state, settled_loss)
	Store.merge_depth_progress(profile, disk)
	Store.merge_depth_progress(profile, embedded)
	Store.merge_synced_profile(profile, disk, state)
	profile["run_counter"] = maxi(int(profile.get("run_counter", 0)), int(embedded.get("run_counter", 0)))
	profile = retaining_events(host, state, profile)
	if profile != disk and not profile_writer.call(profile): return false
	host.set("_progression", profile)
	return true

static func _recorded(profile: Dictionary, id: String) -> bool:
	return (profile.get(Store.CHRONICLE_RECEIPTS_KEY, []) as Array).has(id) or not Store.run_result_for_id(profile, id).is_empty()

static func _terminal_profile(host: Node, state: Dictionary, profile: Dictionary, embedded: Dictionary, disk: Dictionary) -> Dictionary:
	var id: String = Run.run_result_id(state)
	var acknowledged: bool = Store.has_completed_run(disk, state)
	if Store.completion_run_id(state).is_empty(): acknowledged = _recorded(disk, id)
	var settled: bool = state.has("heirloom_terminal_wallet") or (_recorded(embedded, id) and host.get("_run_engine").held_embers(state) == 0)
	if settled and not acknowledged:
		# A failed profile write can leave already-settled currency in a fallback
		# without its marker. Recover only wallet fields, preserving newer skills.
		profile = Store.set_embers(profile, int(embedded.get("embers", 0)))
		profile["recovery_marker"] = (embedded.get("recovery_marker", {}) as Dictionary).duplicate(true)
	var before: Dictionary = {}
	for field: String in ["_progression", "_victory_carry_processed", "_defeat_loss_processed", "_victory_carry_amount", "_defeat_lost_amount"]:
		before[field] = host.get(field)
	var wallet: Dictionary = state.get("heirloom_terminal_wallet", {})
	host.set("_progression", profile)
	host.set("_victory_carry_processed", acknowledged or settled)
	host.set("_defeat_loss_processed", acknowledged or settled)
	host.set("_victory_carry_amount", int(wallet.get("victory_carry", 0)))
	host.set("_defeat_lost_amount", int(wallet.get("defeat_lost", 0)))
	# Reuse the normal terminal accounting/result receipts for an unprocessed
	# fallback. No presentation or old live scene bookkeeping escapes this stage.
	var choice_pending_profile: bool = settled and int(embedded.get("progression_revision", 0)) > int(disk.get("progression_revision", 0))
	var settlement: Dictionary = host.call("_prepare_terminal_settlement", state, choice_pending_profile)
	for field: String in before: host.set(field, before[field])
	return settlement["state"]["progression"]

extends RefCounted

## A run may be the only durable owner of a consumed heirloom or undelivered
## receipt. Transfer both before replacing or clearing that save.
const Store = preload("res://scripts/progression_store.gd")
const Rules = preload("res://scripts/opening_boon_rules.gd")
const Run = preload("res://scripts/run_engine.gd")

static func retaining_events(host: Node, state: Dictionary, profile: Dictionary) -> Dictionary:
	var next: Dictionary = Store.merge_progression_analytics_outbox(profile, Store.load_data())
	if host.get("_opening_boon_flow").flush_events(host, state): return next
	var context: Dictionary = host.call("_analytics_context_from_states", state)
	var events: Array = state.get(Rules.EVENTS_KEY, [])
	for index: int in range(events.size()):
		var event: Dictionary = events[index]
		next = Store.queue_progression_analytics_event(next, str(event["type"]), Rules.event_key(context, index, event), context, event["payload"])
	return next

static func acknowledge_before_replacement(host: Node, state: Dictionary) -> bool:
	var disk: Dictionary = Store.load_data()
	var embedded: Dictionary = Store.normalized_data(state.get("progression", {}))
	# On a tie the profile may already hold a terminal wallet/recovery marker
	# newer than an active save. Only a strictly newer run supersedes its fields.
	var profile: Dictionary = embedded if int(embedded.get("progression_revision", 0)) > int(disk.get("progression_revision", 0)) else disk
	profile = Store.merge_progression_analytics_outbox(profile, embedded)
	# Held run currency is not banked on abandonment. A terminal save's wallet
	# has already settled, so its newer profile balance is authoritative too.
	if str(state.get("mode", "")) in ["victory", "defeat"]:
		profile = _terminal_profile(host, state, profile, embedded, disk)
	else:
		profile = Store.set_embers(profile, int(disk.get("embers", 0)))
	profile = retaining_events(host, state, profile)
	if profile != disk and not Store.save_data(profile): return false
	host.set("_progression", profile)
	return true

static func _recorded(profile: Dictionary, id: String) -> bool:
	return (profile.get(Store.CHRONICLE_RECEIPTS_KEY, []) as Array).has(id) or not Store.run_result_for_id(profile, id).is_empty()

static func _terminal_profile(host: Node, state: Dictionary, profile: Dictionary, embedded: Dictionary, disk: Dictionary) -> Dictionary:
	var id: String = Run.run_result_id(state)
	var acknowledged: bool = _recorded(disk, id)
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
	var finalized: Dictionary = host.call("_finalize_terminal_committed_state", state)
	for field: String in before: host.set(field, before[field])
	return finalized.get("progression", profile)

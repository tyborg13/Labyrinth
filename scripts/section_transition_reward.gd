extends RefCounted
## Presentation-only migration. Never replays combat, grants or claim receipts.

const Graph = preload("res://scripts/section_map_graph.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const KEY: String = "section_transition_reward"

static func migrate(state: Dictionary) -> bool:
	if not (state.get(KEY, {}) as Dictionary).is_empty(): return false
	var room: Dictionary = Graph.room(state, state.get("current_room", Graph.INVALID))
	if str(room.get("type", "")) != "boss" or not bool(room.get("cleared", false)): return false
	var milestone: String = str(state.get("last_dragon_milestone", ""))
	var boss: String = str(room.get("boss_id", ""))
	var relic_id: String = Bosses.relic_for_boss(boss)
	var recorded_relic: String = relic_id if (state.get("relics", []) as Array).has(relic_id) else ""
	var reward: Dictionary = {
		"kind": "dragon", "milestone_id": milestone, "boss_id": boss,
		"relic_id": recorded_relic, "final_boss": false, "legacy_summary": true,
		"next_descent": boss == Bosses.SHADOW_BOSS_ID, "intro_pending": false,
	}
	# Old Continue discarded the offer, but its append-only local event retains
	# the exact totals. Match its durable milestone, never another run's boss.
	if not milestone.is_empty():
		for event: Dictionary in Analytics.load_all_events():
			var payload: Dictionary = event.get("payload", {})
			if str(event.get("event_type", "")) != "reward_offered" or str(payload.get("milestone_id", "")) != milestone: continue
			if str(payload.get("boss_id", "")) != boss: continue
			if not str(payload.get("relic_id", "")).is_empty(): reward["relic_id"] = str(payload["relic_id"])
			for key: String in ["ember_amount", "healed_amount", "moltshards"]:
				if payload.has(key): reward[key] = payload[key]
			break
	# Reconstructed legacy screens show only recorded identities. The owner
	# omits both totals rows, even when the local offer retains exact deltas.
	state[KEY] = reward
	return true

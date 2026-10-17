extends RefCounted
## Presentation-only migration. Never replays combat, grants or claim receipts.

const Graph = preload("res://scripts/section_map_graph.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const KEY: String = "section_transition_reward"
const TODO_DESIGN_LEGACY_REWARD_PAYOUT: String = "TODO_DESIGN_LEGACY_REWARD_PAYOUT"
const TODO_DESIGN_LEGACY_REWARD_SHARDS: String = "TODO_DESIGN_LEGACY_REWARD_SHARDS"

static func migrate(state: Dictionary) -> bool:
	if not (state.get(KEY, {}) as Dictionary).is_empty(): return false
	var room: Dictionary = Graph.room(state, state.get("current_room", Graph.INVALID))
	if str(room.get("type", "")) != "boss" or not bool(room.get("cleared", false)): return false
	var milestone: String = str(state.get("last_dragon_milestone", ""))
	var boss: String = str(room.get("boss_id", ""))
	var reward: Dictionary = {
		"kind": "dragon", "milestone_id": milestone, "boss_id": boss,
		"relic_id": Bosses.relic_for_boss(boss), "final_boss": false,
		"next_descent": boss == Bosses.SHADOW_BOSS_ID, "intro_pending": false,
	}
	# Old Continue discarded the offer, but its append-only local event retains
	# the exact totals. Match its durable milestone, never another run's boss.
	var recovered: bool = false
	if not milestone.is_empty():
		for event: Dictionary in Analytics.load_all_events():
			var payload: Dictionary = event.get("payload", {})
			if str(event.get("event_type", "")) != "reward_offered" or str(payload.get("milestone_id", "")) != milestone: continue
			if str(payload.get("boss_id", "")) != boss: continue
			if not payload.has("ember_amount") or not payload.has("healed_amount") or not payload.has("moltshards"): continue
			for key: String in ["ember_amount", "healed_amount", "moltshards"]: reward[key] = payload[key]
			recovered = true
			break
	if not recovered:
		# These historical deltas were erased from the old save. Preserve known
		# identities and a working retry; never fabricate numeric reward totals.
		reward["payout_text"] = TODO_DESIGN_LEGACY_REWARD_PAYOUT
		reward["shard_text"] = TODO_DESIGN_LEGACY_REWARD_SHARDS
	state[KEY] = reward
	return true

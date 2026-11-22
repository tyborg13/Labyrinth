extends RefCounted
## Isolate Stagger on the production rail after Crushing Blow's Time is projected.
const Data = preload("res://scripts/game_data.gd")
const Combat = preload("res://scripts/hero_facing_combat.gd")
const Committed = preload("res://scripts/battlefield_rules/committed.gd")
const Tip06 = preload("res://tools/tooltip_loops/tip06_fixture.gd")

const STAGGER: String = "stagger"
const CARD: String = "crushing_blow"
const IDS: Array = [STAGGER]
const ENTRIES: Dictionary = {STAGGER: "keyword:stagger"}
const CRAWLER: String = "crawler"
const CRAWLER_LEAD_TIME: int = 1
const HERO := Tip06.SWAP_HERO
const TARGET := Vector2i(2, 2)
const CAMERA_TILES := Rect2i(0, 0, 3, 3)

static func configure(layout: Dictionary) -> Dictionary:
	layout["player_start"] = HERO
	layout["element"] = "none"
	layout["umbra_stage"] = Combat.UMBRA_STAGE_CLEAR
	layout.erase("umbra")
	return {"card": CARD, "units": [[CRAWLER, TARGET]]}

static func prepare(state: Dictionary) -> Dictionary:
	var engine := Combat.new()
	var plays: int = engine.card_plays_spent(CARD, state)
	var priced: Dictionary = engine.finish_player_card(state, 0, plays)
	var hero: Dictionary = next_turn(engine.current_turn_order(priced), "player")
	if not hero.is_empty():
		# Match the confirmed card's rail: its Time is accounted for before
		# the hit so the only order change in the clip comes from Stagger.
		for entry: Dictionary in state["turn_queue"]:
			if entry["kind"] == "enemy":
				entry["time"] = int(hero["time"]) - CRAWLER_LEAD_TIME
	return state

static func source(_id: String) -> Dictionary:
	return {"kind": "hero_card", "id": CARD}

static func plan(fixture: Dictionary, engine: RefCounted) -> Dictionary:
	var state: Dictionary = fixture["state"]
	var prepared: Dictionary = engine.prepare_player_card(state, 0)
	var actions: Array = engine.card_play_actions(CARD, prepared)
	var beats: Array[Dictionary]
	if actions.size() != 1 or not engine.valid_targets_for_player_action(prepared, actions[0]).has(TARGET):
		return {"beats": beats, "final": state}
	var action: Dictionary = actions[0]
	var resolved: Dictionary = engine.resolve_player_action_for_presentation(prepared, action, TARGET)
	var targets: Array[Vector2i]
	targets.append(TARGET)
	var paid: Dictionary = Committed.player_card(engine, state, resolved["state"], 0, actions, targets)
	var projected: Dictionary = engine.finish_player_card(prepared, 0, engine.card_plays_spent_for_actions(actions))
	beats.append({"kind": "player", "before": prepared, "after": resolved["state"], "action": action,
		"target": TARGET, "chain_hits": resolved.get("chain_hits", []), "card": CARD,
		"turn_order": true, "rail_before": projected, "rail_after": paid})
	return {"beats": beats, "final": paid}

static func next_turn(entries: Array, kind: String) -> Dictionary:
	for entry: Dictionary in entries:
		if entry.get("kind") == kind and not entry.get("active", false): return entry
	return {}

static func with_intent(state: Dictionary, intent_id: String) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	for intent: Dictionary in Data.enemy_def(next["enemies"][0]["type"])["intents"]:
		if intent["id"] == intent_id:
			next["enemies"][0]["intent"] = intent.duplicate(true)
			break
	return next

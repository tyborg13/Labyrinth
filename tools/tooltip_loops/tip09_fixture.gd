extends RefCounted
## Production actions isolated on the existing plain-floor recording patch.
const Data = preload("res://scripts/game_data.gd")
const Combat = preload("res://scripts/hero_facing_combat.gd")
const Tip06 = preload("res://tools/tooltip_loops/tip06_fixture.gd")

const REFLECT: String = "reflect"
const PIERCE: String = "pierce"
const IDS: Array = [REFLECT, PIERCE]
const CARDS: Dictionary = {REFLECT: "shiver_shot", PIERCE: "bodkin_arrow"}
const ENTRIES: Dictionary = {REFLECT: "keyword:reflect", PIERCE: "keyword:pierce"}
const MIRROR: String = "glacial_mirror"
const CRAWLER: String = "crawler"
const CRAWLER_GUARD: String = "coil"
const TARGET_KEY: String = "enemy_1"
# Fixture coordinates inside the inherited 4×3 patch.
const HERO := Tip06.SWAP_HERO
const REFLECT_HERO := Vector2i(0, 2)
const REFLECT_TARGET := Vector2i(3, 2)
const PIERCE_TARGET := Vector2i(2, 2)

static func configure(layout: Dictionary, id: String) -> Dictionary:
	layout["player_start"] = REFLECT_HERO if id == REFLECT else HERO
	layout["element"] = "none"
	layout["umbra_stage"] = Combat.UMBRA_STAGE_CLEAR
	layout.erase("umbra")
	var units: Array = [[MIRROR if id == REFLECT else CRAWLER, _target(id)]]
	return {"card": CARDS[id], "units": units}

static func prepare(state: Dictionary, id: String) -> void:
	if id != PIERCE: return
	# The Crawler starts with the Block from its authored Coil defense.
	for intent: Dictionary in Data.enemy_def(CRAWLER)["intents"]:
		if intent["id"] != CRAWLER_GUARD: continue
		for action: Dictionary in intent["actions"]:
			if action["type"] == "block":
				state["enemies"][0]["block"] = action["amount"]

static func source(fixture: Dictionary) -> Dictionary:
	if fixture["id"] == REFLECT: return {"kind": "enemy", "id": MIRROR}
	return {"kind": "hero_card", "id": fixture["card"]}

static func plan(fixture: Dictionary, engine: RefCounted) -> Dictionary:
	var before: Dictionary = fixture["state"]
	var beats: Array[Dictionary]
	var actions: Array = engine.card_play_actions(fixture["card"], before)
	if actions.size() != 1: return {"beats": beats, "final": before}
	var action: Dictionary = actions[0]
	var target: Vector2i = _target(fixture["id"])
	if not engine.valid_targets_for_player_action(before, action).has(target):
		return {"beats": beats, "final": before}
	var resolved: Dictionary = engine.resolve_player_action_for_presentation(before, action, target)
	var after: Dictionary = resolved["state"]
	beats.append({"kind": REFLECT if fixture["id"] == REFLECT else "player", "before": before, "after": after, "action": action, "target": target, "chain_hits": resolved.get("chain_hits", []), "card": fixture["card"]})
	return {"beats": beats, "final": after}

static func _target(id: String) -> Vector2i:
	return REFLECT_TARGET if id == REFLECT else PIERCE_TARGET

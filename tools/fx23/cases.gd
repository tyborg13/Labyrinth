extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Dragon = preload("res://scripts/dragon_presentation.gd")
const HERO := Vector2i(4, 4)
const TARGET := Vector2i(4, 2)
const EMPTY_TARGET := Vector2i(3, 3)
const CHAIN_TARGET := Vector2i(5, 2)
const FIXTURE_HP: int = 30
const FULL_BLOCK: int = 20
const FIRE_CARD: String = "scorch"
const LIGHTNING_CARD: String = "arc_flash"
const HERO_CASES: Dictionary = {
	"fire_hit": [FIRE_CARD, "ember", "ranged"],
	"fire_blocked": [FIRE_CARD, "ember", "ranged"],
	"fire_floor": [FIRE_CARD, "ember", "ranged"],
	"lightning_hit": [LIGHTNING_CARD, "spark", "ranged"],
	"fire_area": ["cinder_bloom", "ember", "aoe"],
	"lightning_area": ["volt_surge", "spark", "aoe"],
	"lightning_chain": ["chain_bolt", "spark", "ranged"],
}
const RECORDING: String = "recording"
const ARC_BOLT: String = "arc_thrall_arc_bolt"
const SHOT_FOR: Dictionary = {"fire": "ember", "lightning": "spark"}
const DRAGON_CASES: Dictionary = {
	"vyraketh_kindle_ground": "meteorfall_followup",
	"vyraketh_cinderfall": "cinder_breath",
	"zekarion_storm_claw": "storm_lash",
	"zekarion_tempest_breath": "overload",
	"zekarion_call_wisps": "call_wisps",
}

static func inventory() -> Dictionary:
	var cases: Dictionary = {}
	for enemy: String in Data.enemies():
		var definition: Dictionary = Data.enemies()[enemy]
		for intent: Dictionary in definition.get("intents", []):
			for action: Dictionary in intent.get("actions", []):
				var element: String = str(action.get("element", definition.get("element", "none")))
				var type: String = str(action["type"])
				if not SHOT_FOR.has(element) or type not in ["ranged", "aoe", "terrain_burst"] or int(action.get("range", 0)) <= 0:
					continue
				var key: String = enemy + "_" + str(intent["id"])
				var descriptor: Dictionary = {"enemy_type": enemy, "intent_id": intent["id"],
					"kind": "ranged" if type == "ranged" else "aoe", "action_type": type, "element": element}
				var shot: String = SHOT_FOR[element] if Dragon.profile(descriptor).is_empty() else ""
				cases[key] = [enemy, intent["id"], type, shot]
	return cases

static func enemy_step(combat: RefCounted, state: Dictionary, type: String) -> Dictionary:
	var enemy: Dictionary = state["enemies"][0]
	for action: Dictionary in enemy["intent"]["actions"]:
		if action["type"] != type: continue
		var context: Dictionary = {}
		var events: Array[Dictionary]
		var after: Dictionary = combat._resolve_enemy_action(state.duplicate(true), 0, action, null, {}, events, context)
		var step: Dictionary = combat._enemy_action_step(state, after, 0, action, context)
		return combat._umbra_marked_enemy_action_step(state, after, step, int(enemy["id"]))
	return {}

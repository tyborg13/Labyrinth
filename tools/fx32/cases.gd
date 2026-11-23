extends RefCounted
## Fixed proof placements. Each beat uses an authored resolver action.

const ShadowCases = preload("res://tools/fx25/cases.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const HERO := Vector2i(4, 4)
const NEAR := Vector2i(4, 3)
const FAR := Vector2i(4, 2)
const END := Vector2i(4, 1)
const DIAGONAL := Vector2i(5, 2)
const REEL_WEAVER := Vector2i(7, 4)
const HERO_HP := 30
const TARGET_HP := 30
const STRIPS: Array[String] = ["lodestone_reversal", "cold_shoulder", "root_snare", "lash_hidden"]
const REEL := "recording"
const CASES := {
	"lodestone_reversal": {"card": "lodestone_reversal", "tile": FAR},
	"cold_shoulder": {"card": "cold_shoulder", "tile": NEAR},
	"cold_shoulder_ice": {"card": "cold_shoulder", "tile": NEAR, "ice": true},
	"cold_shoulder_collision": {"card": "cold_shoulder", "tile": NEAR, "wall": true},
	"sleet_squall_floor": {"card": "sleet_squall", "tile": NEAR},
	"rooted_kick": {"card": "rooted_kick", "tile": NEAR},
	"hurricane_palm": {"card": "hurricane_palm", "tile": NEAR},
	"haft_shove": {"card": "haft_shove", "tile": NEAR},
	"yank": {"card": "yank", "tile": FAR},
	"gust_step": {"card": "gust_step", "tile": FAR},
	"root_snare": {"card": "root_snare", "tile": END},
	"root_snare_diagonal": {"card": "root_snare", "tile": DIAGONAL},
	"lash_visible": {"enemy": "briar_weaver", "intent": "lash_of_thorns", "tile": END},
	"lash_hidden": {"enemy": "briar_weaver", "intent": "lash_of_thorns", "tile": END, "fog": true},
	"area_ranged": {"enemy": "hollow_mimic", "intent": "shade_bolt", "tile": FAR},
	REEL: {"card": "lodestone_reversal", "tile": FAR},
}

static func cell(tile: Vector2i) -> String:
	return "%d:%d" % [tile.x, tile.y]

static func options(id: String, seed: int, filler: String, draw: String) -> Dictionary:
	var config: Dictionary = CASES[id]
	var enemies: String = config.get("enemy", "crawler")
	var intents: String = config.get("intent", "coil")
	var positions: String = cell(config["tile"])
	var hand: String = config.get("card", filler)
	if id == REEL:
		enemies += ",briar_weaver"
		intents += ",lash_of_thorns"
		positions += "," + cell(REEL_WEAVER)
		hand = "lodestone_reversal,cold_shoulder,root_snare"
	return {"scenario": "combat", "seed": seed, "hand": hand, "draw": draw,
		"player_hp": HERO_HP, "player_max_hp": HERO_HP, "player_position": cell(HERO),
		"enemy_types": enemies, "enemy_intents": intents, "enemy_positions": positions,
		"umbra_stage": "clear"}

static func configure(id: String, state: Dictionary) -> void:
	state.erase("battlefield_rule")
	state["terrain"] = []
	state["traps"] = []
	state["surfaces"] = {}
	for y: int in range(1, 7):
		for x: int in range(2, 8):
			state["grid"][y][x] = "stone"
	var hp: int = GameData.fixed_point_amount(TARGET_HP)
	for enemy: Dictionary in state["enemies"]:
		enemy["hp"] = hp
		enemy["max_hp"] = hp
	if CASES[id].get("ice", false):
		# Put Ice both under the target and on the first forced landing.
		Surfaces.place(state, NEAR, "ice")
		Surfaces.place(state, FAR, "ice")
	if CASES[id].get("wall", false): state["grid"][FAR.y][FAR.x] = "wall"
	if CASES[id].get("fog", false): fog(state)

static func fog(state: Dictionary) -> void:
	state["umbra"]["stage"] = "eclipse"
	state["umbra"]["stage_reduction"] = 0
	state["umbra"]["light_sources"] = []

static func resolve_player(id: String, combat: RefCounted, state: Dictionary, aim: Vector2i) -> Dictionary:
	var card: String = CASES[id]["card"]
	for original: Dictionary in GameData.card_def(card)["actions"]:
		if original.get("type") not in ["push", "pull", "ranged"]: continue
		var action: Dictionary = original.duplicate(true)
		action["_card_id"] = card
		if not combat.valid_targets_for_player_action(state, action).has(aim): return {}
		var resolved: Dictionary = combat.resolve_player_action_for_presentation(state, action, aim)
		return {"action": action, "after": resolved["state"], "chain_hits": resolved.get("chain_hits", [])}
	return {}

static func resolve_enemy(id: String, combat: RefCounted, state: Dictionary, index: int) -> Dictionary:
	if id == "area_ranged":
		var area: Dictionary = ShadowCases.step(id, combat, state, index)
		area["steps"] = [area["step"]]
		return area
	var resolved: Dictionary = combat.resolve_enemy_turn_with_steps(state, index)
	var attack: Dictionary
	for candidate: Dictionary in resolved["steps"]:
		if candidate.get("kind") == "ranged" and candidate.get("intent_id") == "lash_of_thorns":
			attack = candidate
			break
	if attack.is_empty(): return {}
	return {"steps": resolved["steps"], "step": attack, "after": resolved["state"]}

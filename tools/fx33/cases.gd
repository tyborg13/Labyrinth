extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const HERO := Vector2i(4, 4)
const TICK := Vector2i(4, 3)
const PRIMARY := Vector2i(6, 4)
const CHAIN_TILES: Array[Vector2i] = [PRIMARY, Vector2i(6, 5), Vector2i(5, 5)]
const PROOF_HP: int = 30
const KILL_HP: int = 1
const BLOCK: int = 20
const FULL_CHARGE: int = 3
const STORM_DAMAGE: int = 2
const CAPACITOR_TILE := Vector2i(4, 1)
const THIRD_CAPACITOR_TARGET := Vector2i(5, 4)
const HIDDEN_SOURCE := Vector2i(3, 3)
const HIDDEN_WITNESS := Vector2i(3, 4)
const HIDDEN_HERO := Vector2i(3, 5)
const CONDUCTION_TARGET := Vector2i(6, 1)
const RELAY_TILES: Array[Vector2i] = [Vector2i(6, 3), Vector2i(6, 2)]
const STRIPS: Array[String] = ["tick", "chain_bolt", "storm_relay", "capacitor", "spark_conduction"]
const CASES: Array[String] = ["tick", "kindled_tick", "hoarder", "enemy_kill", "warden_trap", "hidden", "hidden_trace", "chain_bolt", "storm_salvo",
	"chain_conduction", "spark_conduction", "storm_relay", "capacitor", "skybreak", "lightning_storm", "immolation",
	"root_snare", "thorn_lash", "lodestone_reversal", "volt_surge", "recording"]

static func options(id: String, seed: int) -> Dictionary:
	var names: Array[String] = ["crawler"]
	var positions: Array[Vector2i] = [PRIMARY]
	var hero: Vector2i = HERO
	match id:
		"tick", "kindled_tick", "hoarder", "hidden":
			names.assign(["ember_hoarder" if id == "hoarder" else "ember_tick", "crawler"])
			positions.assign([TICK, TICK + Vector2i.RIGHT])
		"hidden_trace":
			names.assign(["ember_tick", "crawler"])
			positions.assign([HIDDEN_SOURCE, HIDDEN_WITNESS])
			hero = HIDDEN_HERO
		"recording":
			names.assign(["ember_tick", "crawler", "crawler", "crawler"])
			positions.assign([TICK] + CHAIN_TILES)
		"enemy_kill":
			names.assign(["storm_capacitor", "ember_tick"])
			positions.assign([CAPACITOR_TILE, TICK])
		"warden_trap":
			names.assign(["warden", "ember_tick"])
			positions.assign([HERO, TICK])
			hero = Vector2i(3, 4)
		"chain_bolt", "storm_salvo":
			names.assign(["crawler", "crawler", "crawler"])
			positions.assign(CHAIN_TILES)
		"chain_conduction", "spark_conduction", "storm_relay":
			names.assign(["crawler", "crawler", "crawler"])
			positions.assign([PRIMARY, Vector2i(6, 5), CONDUCTION_TARGET])
		"capacitor":
			names.assign(["storm_capacitor", "crawler", "crawler"])
			positions.assign([CAPACITOR_TILE, TICK, THIRD_CAPACITOR_TARGET])
		"skybreak":
			names.assign(["zekarion"])
			positions.assign([Vector2i(4, 1)])
		"thorn_lash":
			names.assign(["briar_weaver"])
	return {"scenario": "combat", "seed": seed, "hand": "quick_stab,chain_bolt", "draw": "quick_stab,chain_bolt",
		"player_hp": PROOF_HP, "player_max_hp": PROOF_HP, "player_position": coord(hero), "enemy_types": ",".join(names),
		"enemy_positions": ",".join(positions.map(coord)), "umbra_stage": "clear"}

static func configure(id: String, state: Dictionary) -> void:
	state.erase("battlefield_rule")
	state["terrain"] = []
	state["traps"] = []
	state["surfaces"] = {}
	for y: int in range(1, 7):
		for x: int in range(2, 8): state["grid"][y][x] = "stone"
	var enemy: Dictionary = state["enemies"][0]
	for unit: Dictionary in state["enemies"]: unit["intent"] = {"id": "fx33_idle", "actions": []}
	if id in ["tick", "kindled_tick", "hoarder", "hidden", "recording"]:
		enemy["hp"] = KILL_HP
		state["player"]["block"] = BLOCK
	match id:
		"kindled_tick": _intent(enemy, "kindle")
		"hidden", "hidden_trace":
			if id == "hidden_trace": enemy["hp"] = KILL_HP
			state["umbra"]["stage"] = "eclipse"
			state["umbra"]["light_sources"] = []
		"enemy_kill":
			_intent(enemy, "discharge")
			enemy["charge"] = FULL_CHARGE
			state["enemies"][1]["hp"] = KILL_HP
		"warden_trap":
			_intent(enemy, "crushing_step")
			state["enemies"][1]["hp"] = KILL_HP
			state["traps"] = [{"id": "fx33_warden_fire", "pos": TICK, "element": "fire", "damage": KILL_HP}]
		"capacitor":
			_intent(enemy, "discharge")
			enemy["charge"] = FULL_CHARGE
		"skybreak": _intent(enemy, "skybreak")
		"thorn_lash": _intent(enemy, "lash_of_thorns")
		"chain_conduction", "spark_conduction", "storm_relay":
			for tile: Vector2i in [PRIMARY, CONDUCTION_TARGET] + RELAY_TILES:
				Surface.place(state, tile, "electrified")
		"lightning_storm": Surface.place(state, HERO, "electrified")
		"immolation": Surface.place(state, HERO + Vector2i.RIGHT, "fire")

static func _intent(enemy: Dictionary, id: String) -> void:
	for intent: Dictionary in Data.enemy_def(enemy["type"])["intents"]:
		if intent["id"] == id:
			enemy["intent"] = intent.duplicate(true)
			return

static func coord(tile: Vector2i) -> String:
	return "%d:%d" % [tile.x, tile.y]

extends RefCounted

const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const FIXTURE_SEED: int = 1016
const FULL_HEALTH: int = 24
const INJURED_HEALTH: int = 12
const COMBAT_SEED_LIMIT: int = 120
const FIXTURE_CARD: String = "nail_bomb"
const FIXTURE_RELICS: Array = ["quartermasters_ledger", "alchemists_retort"]
const SHOP_STOCK: Array = ["grave_mortar", "icicle_lance", "stonefist", "boiled_leather", "dust_tabi", "ward_kite", "nail_bomb", "crimson_draught", "smoke_bomb"]

static func modifiers() -> Dictionary:
	return {"relics": FIXTURE_RELICS.duplicate(), "equipped_equipment": preload("res://scripts/game_data.gd").starting_equipped_equipment()}

static func profile() -> Dictionary:
	return Tutorial.complete_tutorial(Store.default_data())

static func apply_modifiers(state: Dictionary) -> Dictionary:
	state["relics"] = FIXTURE_RELICS.duplicate()
	state["equipped_items"] = [FIXTURE_CARD]
	state["item_inventory"] = [FIXTURE_CARD]
	return state

static func shop(engine: RefCounted) -> Dictionary:
	var state: Dictionary = engine.create_new_run(FIXTURE_SEED, profile())
	for room: Dictionary in state["rooms"].values():
		if room.get("type") != "scavenger": continue
		state["current_room"] = room["coord"]
		room[Run.MERCHANT_STOCK_KEY] = SHOP_STOCK.duplicate()
		room["visited"] = true
		room["revealed"] = true
		break
	return engine.repair_loaded_run_state(apply_modifiers(state))

static func bloodglass_shop(engine: RefCounted, health: int, max_health: int = FULL_HEALTH) -> Dictionary:
	var state: Dictionary = shop(engine)
	state["relics"] = ["bloodglass_knife"]
	state["player_hp"] = health
	state["player_max_hp"] = max_health
	var coord: Vector2i = state["current_room"]
	var stock: Array = SHOP_STOCK.duplicate()
	stock[3] = "training_sword"
	state["rooms"]["%d,%d" % [coord.x, coord.y]][Run.MERCHANT_STOCK_KEY] = stock
	return state

static func combat(engine: RefCounted) -> Dictionary:
	for seed_value: int in range(1, COMBAT_SEED_LIMIT):
		var state: Dictionary = engine.repair_loaded_run_state(apply_modifiers(engine.create_new_run(seed_value, profile())))
		for coord: Vector2i in engine.available_moves(state):
			var candidate: Dictionary = engine.move_to_room(state, coord)
			if candidate.get("mode") == "pre_battle": candidate = engine.begin_pre_battle_combat(candidate)
			if candidate.get("mode") == "combat" and (candidate.get("combat_state", {}).get("deck", {}).get("hand", []) as Array).has(FIXTURE_CARD): return candidate
	return {}

static func campfire(engine: RefCounted) -> Dictionary:
	var state: Dictionary = apply_modifiers(engine.create_new_run(FIXTURE_SEED, profile()))
	for room: Dictionary in state["rooms"].values():
		if room.get("type") != "campfire": continue
		state["current_room"] = room["coord"]
		state["mode"] = "campfire"
		room["visited"] = true
		room["revealed"] = true
		break
	return engine.repair_loaded_run_state(state)

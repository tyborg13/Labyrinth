extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Warbands = preload("res://tests/suites/warband_suite.gd")
const Lob = preload("res://scripts/enemy_mechanics/marked_strike.gd")
const Veil = preload("res://scripts/enemy_mechanics/veil.gd")
const BIOMES = ["earth", "fire", "air", "ice", "lightning", "shadow"]
const FIXTURE_SIZE: int = 11
const FIXTURE_HP: int = 100
const FIXTURE_CAPTAIN := Vector2i(5, 2)
const FIXTURE_PLAYER := Vector2i(5, 6)
const FIXTURE_FOLLOWER_A := Vector2i(3, 5)
const FIXTURE_FOLLOWER_B := Vector2i(7, 5)
const FIXTURE_BARRAGE_CENTER := Vector2i(3, 6)
const FIXTURE_BARRAGE_OTHER_CENTER := Vector2i(7, 6)
const FIXTURE_BARRAGE_OUTER_ARM := Vector2i(2, 6)
const STORMCALLER_ORDER_LINE: String = "Order: Its wind never drops: a gust slides everyone else 1 tile every round."
const FIXTURE_PRIOR_NEAR_HERO := Vector2i(3, 7)
const FIXTURE_RNG_SEED_FIRST: int = 1
const FIXTURE_RNG_SEED_COUNT: int = 32
const FIXTURE_LIGHT_RADIUS: int = 1
const FIXTURE_REVEAL_ACTIVATIONS: int = 2
const FIXTURE_AXIS_CAPTAIN := Vector2i(5, 5)
const FIXTURE_AXIS_BEARINGS = [
	{"delta": Vector2i(2, 2), "axis": Vector2i.DOWN},
	{"delta": Vector2i(2, -2), "axis": Vector2i.DOWN},
	{"delta": Vector2i(-2, 2), "axis": Vector2i.UP},
	{"delta": Vector2i(-2, -2), "axis": Vector2i.UP},
	{"delta": Vector2i(1, 3), "axis": Vector2i.LEFT},
	{"delta": Vector2i(-1, -3), "axis": Vector2i.RIGHT},
	{"delta": Vector2i(3, -1), "axis": Vector2i.DOWN},
	{"delta": Vector2i(-3, 1), "axis": Vector2i.UP},
]
const SAVE_PATH: String = "user://spx04-mid-order.save"

static func battle(biome: String) -> Dictionary:
	var state: Dictionary = Warbands.battle(biome, 3)
	var grid: Array
	for y: int in range(FIXTURE_SIZE):
		var row: Array
		for x: int in range(FIXTURE_SIZE): row.append("wall" if x == 0 or y == 0 or x == FIXTURE_SIZE - 1 or y == FIXTURE_SIZE - 1 else "stone")
		grid.append(row)
	state["grid"] = grid
	state["terrain"] = []
	state["traps"] = []
	state["surfaces"] = {}
	state["illusions"] = []
	state.erase("umbra")
	state["enemies"].resize(3)
	var positions: Array[Vector2i]
	positions.assign([FIXTURE_CAPTAIN, FIXTURE_FOLLOWER_A, FIXTURE_FOLLOWER_B])
	for index: int in range(3):
		state["enemies"][index]["pos"] = positions[index]
		state["enemies"][index]["hp"] = FIXTURE_HP
		state["enemies"][index]["max_hp"] = FIXTURE_HP
		state["enemies"][index]["stoneskin"] = 0
		state["enemies"][index]["block"] = 0
	state["player"]["pos"] = FIXTURE_PLAYER
	state["player"]["hp"] = FIXTURE_HP
	state["player"]["max_hp"] = FIXTURE_HP
	state["player"]["block"] = 0
	state["player"]["stoneskin"] = 0
	return state

static func authored(state: Dictionary, id: String) -> Dictionary:
	var enemy: Dictionary = state["enemies"][0]
	var engine := Combat.new()
	return engine._intent_by_id(engine._scaled_enemy_intents(Data.enemy_def(str(enemy["type"]))["intents"], int(state["room_depth"]), state, enemy), id)

static func run(expect: Callable) -> void:
	preload("res://tests/suites/element_retrofit_suite.gd").run_orders(expect)
	_order_axes(expect)
	_slagmaster(expect)
	_prior(expect)
	_save_load(expect)


static func _order_axes(expect: Callable) -> void:
	var engine := Combat.new()
	for fixture: Dictionary in FIXTURE_AXIS_BEARINGS:
		expect.call(preload("res://scripts/warband_combat_rules.gd").order_axis(engine, fixture["delta"]) == fixture["axis"], "Order axis projects dominant cardinal with x on exact diagonals")
		var state: Dictionary = battle("fire")
		state["enemies"][0]["pos"] = FIXTURE_AXIS_CAPTAIN
		state["player"]["pos"] = FIXTURE_AXIS_CAPTAIN + Vector2i(fixture["delta"])
		state["enemies"][0]["intent"] = authored(state, "lob_slag")
		state["enemies"][0]["intent"]["barrage_side"] = 1
		var centers: Array[Vector2i] = Lob.centers(engine, state, state["enemies"][0])
		expect.call(centers.size() == 2 and centers[1] == state["player"]["pos"] + Vector2i(fixture["axis"]) * 2, "Barrage side uses approved dominant-cardinal orientation")

	print("Barrage axes: exact diagonals and dominant axes checked")

static func _slagmaster(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = battle("fire")
	var intent: Dictionary = authored(state, "lob_slag")
	if intent.is_empty():
		for candidate: Dictionary in Data.enemy_def("slag_mortar")["intents"]:
			if str(candidate["actions"][0]["type"]) == "lob_mark": intent = candidate.duplicate(true)
	intent["barrage_side"] = 1
	state["enemies"][0]["intent"] = intent
	var before: Dictionary = state.duplicate(true)
	var plan: Dictionary = engine.enemy_intent_plan(state, 0)
	expect.call(plan["projected_attack"].size() == 9 and plan["projected_attack"].has(FIXTURE_BARRAGE_OUTER_ARM), "Slagmaster preview exposes both plus-shapes before marking")
	expect.call(state == before and engine.enemy_intent_plan(state, 0) == plan, "Barrage previews are deterministic and consume no RNG")
	state["enemies"][1]["pos"] = FIXTURE_BARRAGE_CENTER
	var marked: Dictionary = engine._resolve_enemy_action(state.duplicate(true), 0, intent["actions"][0])
	expect.call(marked["enemies"][0]["lob_centers"].size() == 2 and _same_tiles(marked["enemies"][0]["lob_tiles"], plan["projected_attack"]), "Barrage stores both centers and one union of marks")
	var landing: Dictionary = Lob.landing_action(engine, marked, marked["enemies"][0])
	expect.call(Lob.damage(marked["enemies"][0], landing, FIXTURE_BARRAGE_CENTER) == landing["center_damage"], "Second barrage center uses center damage")
	var land_plan: Dictionary = Lob.plan(engine, marked, 0, {"actions": [landing]}, false)
	expect.call(_same_tiles(land_plan["projected_attack"], plan["projected_attack"]), "Both barrages remain telegraphed before landing")
	var landed: Dictionary = engine._resolve_enemy_action(marked.duplicate(true), 0, landing)
	expect.call(landed["enemies"][1]["hp"] == FIXTURE_HP - int(landing["center_damage"]) and landed["player"]["hp"] == FIXTURE_HP - int(landing["center_damage"]), "Both barrages land together and hit own escort and hero")
	expect.call(not landed["enemies"][0].has("lob_centers") and not landed["enemies"][0].has("lob_tiles"), "Barrage clears held data only after landing")
	state["grid"][FIXTURE_BARRAGE_CENTER.y][FIXTURE_BARRAGE_CENTER.x] = "wall"
	expect.call(Lob.centers(engine, state, state["enemies"][0]).has(FIXTURE_BARRAGE_OTHER_CENTER), "Illegal selected barrage side falls back to other side")
	state["grid"][FIXTURE_BARRAGE_OTHER_CENTER.y][FIXTURE_BARRAGE_OTHER_CENTER.x] = "wall"
	expect.call(Lob.tiles(engine, state, state["enemies"][0], intent["actions"][0]).size() == 5, "Both illegal barrage sides leave only normal plus")
	var sides: Dictionary = {}
	for seed: int in range(FIXTURE_RNG_SEED_FIRST, FIXTURE_RNG_SEED_FIRST + FIXTURE_RNG_SEED_COUNT):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var same := RandomNumberGenerator.new()
		same.seed = seed
		var chosen: Dictionary = Lob.declare(state, state["enemies"][0], intent, rng)
		expect.call(chosen == Lob.declare(state, state["enemies"][0], intent, same), "Barrage room RNG repeatability")
		sides[chosen["barrage_side"]] = true
	expect.call(sides.size() == 2, "Barrage seeded RNG exercises both sides")
	print("Order 2 slagmaster_barrage: preview, seeded side/fallback, simultaneous friendly fire checked")


static func _prior(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = battle("shadow")
	var follower: Dictionary = state["enemies"][1]
	expect.call(Veil.prior_hidden(engine, state, follower) and not engine.is_enemy_visible_to_player(state, follower), "Prior preview hides distant follower before it can act")
	expect.call(not engine.visible_enemy_ids(state).has(int(follower["id"])), "Prior follower uses hidden-enemy presentation/preview rules")
	var before: Dictionary = state.duplicate(true)
	engine.enemy_threat_tiles(state, 1)
	expect.call(state == before, "Prior threat preview never mutates state")
	state["player"]["pos"] = FIXTURE_PRIOR_NEAR_HERO
	expect.call(engine.is_enemy_visible_to_player(state, follower) and not Veil.prior_hidden(engine, state, follower), "Prior follower is revealed at distance two")
	state["player"]["pos"] = FIXTURE_PLAYER
	state["umbra"] = {"truesight_activations": FIXTURE_REVEAL_ACTIVATIONS}
	expect.call(engine.is_enemy_visible_to_player(state, follower), "Existing Truesight reveals Prior followers")
	state["umbra"] = {"light_sources": [{"pos": follower["pos"], "radius": FIXTURE_LIGHT_RADIUS, "remaining_activations": FIXTURE_REVEAL_ACTIVATIONS}]}
	expect.call(engine.is_enemy_visible_to_player(state, follower), "Existing Light reveals Prior followers")
	state["umbra"] = {"stage": "eclipse"}
	expect.call(not engine.is_enemy_visible_to_player(state, follower), "Prior follower is hidden in Eclipse before captain death")
	state["enemies"][0]["hp"] = 0
	expect.call(engine.is_enemy_visible_to_player(state, follower), "Prior death reveals living followers before break removal, even in Eclipse")
	follower["veiled"] = true
	var broken: Dictionary = preload("res://scripts/warband_combat_rules.gd").break_followers(engine, state, 1)
	expect.call(not broken["enemies"][1].has("veiled") and broken["enemies"][1]["warband_fled"], "Prior break clears native veil before fleeing")
	var shown: Dictionary = preload("res://scripts/warband_view.gd").flee_display_state(before, broken)
	for enemy: Dictionary in shown["enemies"]:
		if bool(enemy.get("warband_fled", false)): expect.call(engine.is_enemy_visible_to_player(shown, enemy), "Every Prior follower is visible in pre-break display")
	print("Order 6 prior_veil: hidden preview, range/Light/Truesight reveal and pre-break reveal checked")

static func _same_tiles(a: Array, b: Array) -> bool:
	if a.size() != b.size(): return false
	for tile: Vector2i in a:
		if not b.has(tile): return false
	return true


static func _save_load(expect: Callable) -> void:
	var store: Script = preload("res://scripts/progression_store.gd")
	var engine := Combat.new()
	var previous: String = store._run_storage_path
	store.set_run_storage_path(SAVE_PATH)
	for biome: String in BIOMES:
		var state: Dictionary = battle(biome)
		var intent: Dictionary = {}
		var verb: String = {"earth": "upheaval_mark", "fire": "lob_mark", "air": "call_wind", "ice": "icefall_mark", "lightning": "gain_charge", "shadow": "ranged"}[biome]
		for candidate: Dictionary in Data.enemy_def(str(state["enemies"][0]["type"]))["intents"]:
			if str(candidate["actions"][0]["type"]) == verb: intent = candidate.duplicate(true); break
		state["enemies"][0]["intent"] = intent
		for action: Dictionary in intent["actions"]: state = engine._resolve_enemy_action(state, 0, action)
		expect.call(store.save_run_state({"combat_state": state}), "Order mid-combat save writes: " + biome)
		var loaded: Dictionary = store.load_saved_run()["combat_state"]
		expect.call(loaded == state, "Order mid-combat save restores complete state: " + biome)
		expect.call(engine.resolve_enemy_turn_with_steps(loaded, 0) == engine.resolve_enemy_turn_with_steps(state, 0), "Order deterministic continuation after save: " + biome)
	store.clear_saved_run()
	store.set_run_storage_path(previous)

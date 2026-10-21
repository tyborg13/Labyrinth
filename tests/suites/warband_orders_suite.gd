extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Warbands = preload("res://tests/suites/warband_suite.gd")
const Bramble = preload("res://scripts/enemy_mechanics/bramble.gd")
const Lob = preload("res://scripts/enemy_mechanics/lob.gd")
const Wind = preload("res://scripts/enemy_mechanics/wind.gd")
const Icefall = preload("res://scripts/enemy_mechanics/icefall.gd")
const Capacitor = preload("res://scripts/enemy_mechanics/capacitor.gd")
const Veil = preload("res://scripts/enemy_mechanics/veil.gd")
const BrambleView = preload("res://scripts/enemy_mechanics/bramble_view.gd")
const BIOMES = ["earth", "fire", "air", "ice", "lightning", "shadow"]
const GOLDEN_PATH: String = "res://tests/fixtures/spx04_legacy_golden.json"
const FIXTURE_SIZE: int = 11
const FIXTURE_HP: int = 100
const FIXTURE_CAPTAIN := Vector2i(5, 2)
const FIXTURE_PLAYER := Vector2i(5, 6)
const FIXTURE_FOLLOWER_A := Vector2i(3, 5)
const FIXTURE_FOLLOWER_B := Vector2i(7, 5)
const FIXTURE_WALL_CENTER := Vector2i(5, 4)
const FIXTURE_BRAMBLE_PUSH_START := Vector2i(5, 3)
const FIXTURE_BRAMBLE_BLOCK := Vector2i(3, 4)
const FIXTURE_BARRAGE_CENTER := Vector2i(3, 6)
const FIXTURE_BARRAGE_OTHER_CENTER := Vector2i(7, 6)
const FIXTURE_BARRAGE_OUTER_ARM := Vector2i(2, 6)
const FIXTURE_WIND_HAZARD := Vector2i(6, 6)
const FIXTURE_WIND_EXPECTED = {"player": Vector2i(5, 5), "enemies": [Vector2i(5, 2), Vector2i(3, 4), Vector2i(7, 4)]}
const FIXTURE_WIND_PILLAR := Vector2i(3, 4)
const FIXTURE_WIND_BLOCKED_EXPECTED = {"player": Vector2i(5, 5), "enemies": [Vector2i(5, 2), Vector2i(3, 5), Vector2i(7, 4)]}
const FIXTURE_WIND_COLLISION_DAMAGE: int = 2
const STORMCALLER_ORDER_LINE: String = "Order: Its wind never drops: a gust slides everyone else 1 tile every round."
const FIXTURE_ICE_PUSH_START := Vector2i(4, 3)
const FIXTURE_ODD_MIDPOINT_HERO := Vector2i(5, 7)
const FIXTURE_ODD_MIDPOINT_CENTER := Vector2i(5, 5)
const FIXTURE_PRIOR_NEAR_HERO := Vector2i(3, 7)
const FIXTURE_RNG_SEED_FIRST: int = 1
const FIXTURE_RNG_SEED_COUNT: int = 32
const FIXTURE_PERSISTENCE_BOUNDARIES: int = 5
const FIXTURE_LIGHT_RADIUS: int = 1
const FIXTURE_REVEAL_ACTIVATIONS: int = 2
const FIXTURE_CENTER_TIES = [
	{"rank": "player", "player": Vector2i(5, 6), "captain": Vector2i(5, 2), "candidates": [Vector2i(5, 3), Vector2i(5, 5)], "expected": Vector2i(5, 5)},
	{"rank": "captain", "player": Vector2i(7, 6), "captain": Vector2i(3, 5), "candidates": [Vector2i(5, 3), Vector2i(4, 4)], "expected": Vector2i(4, 4)},
	{"rank": "scan", "player": Vector2i(5, 6), "captain": Vector2i(5, 2), "candidates": [Vector2i(4, 4), Vector2i(6, 4)], "expected": Vector2i(4, 4)},
]
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

static func battle(biome: String, ordinary: bool = false) -> Dictionary:
	var state: Dictionary
	if ordinary:
		var engine := preload("res://scripts/run_engine.gd").new()
		var source: Dictionary = engine.create_new_run(Warbands.Fixture.FIXTURE_SEED, preload("res://scripts/progression_store.gd").default_data())
		var layout: Dictionary = preload("res://scripts/room_generator.gd").new().generate_room(Warbands.Fixture.FIXTURE_SEED, Warbands.Fixture.room_spec(biome, 3), Vector2i.UP)
		layout["objective"] = {"type": "kill_all"}
		for enemy: Dictionary in layout["enemies"]: enemy["is_leader"] = false
		state = Combat.new().create_combat(Warbands.Fixture.FIXTURE_SEED, layout, engine._player_snapshot(source))
	else:
		state = Warbands.battle(biome, 3)
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

# Full Variant snapshots were recorded on the untouched spx-03 base. No Warband
# objective/leader survives into these ordinary-mechanic controls.
static func legacy_snapshots() -> Dictionary:
	var result: Dictionary = {}
	var engine := Combat.new()
	for biome: String in BIOMES:
		var state: Dictionary = battle(biome, true)
		state["objective"] = {"type": "kill_all"}
		for enemy: Dictionary in state["enemies"]: enemy["is_leader"] = false
		var id: String = {"earth": "thornwall", "fire": "lob_slag", "air": "call_wind", "ice": "icefall", "lightning": "charge", "shadow": "shade_bolt"}[biome]
		var intent: Dictionary = authored(state, id)
		# Seer/Mortar authored ids are selected from their mechanic verb.
		var verb: String = {"earth": "grow_bramble", "fire": "lob_mark", "air": "call_wind", "ice": "icefall_mark", "lightning": "gain_charge", "shadow": "ranged"}[biome]
		if intent.is_empty():
			for candidate: Dictionary in Data.enemy_def(str(state["enemies"][0]["type"]))["intents"]:
				if str(candidate["actions"][0]["type"]) == verb: intent = candidate.duplicate(true); break
		state["enemies"][0]["intent"] = intent
		var plan: Dictionary = engine.enemy_intent_plan(state, 0)
		for action: Dictionary in intent["actions"]: state = engine._resolve_enemy_action(state, 0, action)
		if biome == "fire": state = engine._resolve_enemy_action(state, 0, Lob.landing_action(engine, state, state["enemies"][0]))
		if biome == "ice": state = engine._resolve_enemy_action(state, 0, authored(state, "icefall_land")["actions"][0])
		var steps: Array[Dictionary]
		state = Bramble.complete_turn(engine, state, steps)
		result[biome] = var_to_bytes({"plan": plan, "state": state, "steps": steps}).hex_encode().sha256_text()
	# Veil's ordinary Fade/Ambush, rather than the Prior's unrelated native bolt.
	var state: Dictionary = battle("shadow", true)
	state["objective"] = {"type": "kill_all"}
	state["enemies"][0]["type"] = "veilbound_acolyte"
	state["enemies"][0]["is_leader"] = false
	var context: Dictionary = {}
	var bleed: Array[Dictionary]
	state = Veil.resolve(engine, state, 0, {"type": "veil_blink", "range": 4}, context, bleed)
	state = Veil.resolve(engine, state, 0, {"type": "melee", "damage": 3, "ends_veil": true}, context, bleed)
	result["veil"] = var_to_bytes(state).hex_encode().sha256_text()
	return result

static func run(expect: Callable) -> void:
	_thornmother(expect)
	_thornmother_centers(expect)
	_order_axes(expect)
	_slagmaster(expect)
	_stormcaller(expect)
	_oracle(expect)
	_dynamo(expect)
	_prior(expect)
	_scope_and_copy(expect)
	_save_load(expect)
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN_PATH))
	var actual: Dictionary = legacy_snapshots()
	for biome: String in golden: expect.call(actual[biome] == golden[biome], "Ordinary mechanic golden: " + biome)

static func _thornmother(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = battle("earth")
	var intent: Dictionary = authored(state, "thornwall")
	state["enemies"][0]["intent"] = intent
	var before: Dictionary = state.duplicate(true)
	var plan: Dictionary = engine.enemy_intent_plan(state, 0)
	var expected: Array[Vector2i]
	for offset: int in range(-2, 3): expected.append(FIXTURE_WALL_CENTER + Vector2i.RIGHT * offset)
	expect.call((plan["projected_attack"] as Array).size() == 5 and _same_tiles(plan["projected_attack"], expected), "Thornmother telegraphs five tiles two shortest-path steps from captain")
	expect.call(state == before, "Thornmother preview never mutates state")
	var result: Dictionary = engine._resolve_enemy_action(state.duplicate(true), 0, intent["actions"][0])
	var grown: Array[Vector2i]
	for terrain: Dictionary in result["terrain"]:
		grown.append(terrain["pos"])
		expect.call(terrain["rounds_left"] == intent["actions"][0]["rounds"] and terrain["pushed_damage"] == 2 and terrain["pushed_bleed"] == 1, "Thornmother preserves authored lifetime/damage/Bleed")
	expect.call(_same_tiles(grown, expected), "Thornmother resolution matches telegraph")
	result["enemies"][1]["pos"] = FIXTURE_BRAMBLE_PUSH_START
	result = engine._force_move_actor(result, "enemy", int(result["enemies"][1]["id"]), Vector2i.DOWN, 1, {}, true)
	expect.call(result["enemies"][1]["hp"] == FIXTURE_HP - 2 and result["enemies"][1]["bleed"] == 1, "Thornmother lever: escort takes Bramble collision damage and Bleed")
	state["enemies"][1]["pos"] = FIXTURE_WALL_CENTER
	state["grid"][FIXTURE_BRAMBLE_BLOCK.y][FIXTURE_BRAMBLE_BLOCK.x] = "wall"
	var legal: Array[Vector2i] = Bramble.tiles(engine, state, state["enemies"][0])
	expect.call(not legal.has(FIXTURE_WALL_CENTER), "Thornmother moves occupied center to nearest legal tile")
	for tile: Vector2i in legal: expect.call(Bramble.legal_tile(engine, state, tile), "Thornmother grows only legal tiles")
	state = battle("earth")
	state["grid"][FIXTURE_BRAMBLE_PUSH_START.y][FIXTURE_BRAMBLE_PUSH_START.x] = "wall"
	var path: Array[Vector2i] = preload("res://scripts/path_utils.gd").find_path(state["grid"], FIXTURE_CAPTAIN, FIXTURE_PLAYER)
	var bent: Array[Vector2i] = Bramble.tiles(engine, state, state["enemies"][0])
	expect.call(bent.has(path[2]), "Thornmother follows shortest path around a blocked direct bearing")
	state["enemies"][0]["hp"] = 0
	expect.call(Bramble.tiles(engine, state, state["enemies"][0]).size() <= 3, "Dead captain has no Thornmother order")
	print("Order 1 thornmother_wall: telegraph, geometry, legality and escort lever checked")

static func _thornmother_centers(expect: Callable) -> void:
	var engine := Combat.new()
	for fixture: Dictionary in FIXTURE_CENTER_TIES:
		var state: Dictionary = battle("earth")
		state["player"]["pos"] = fixture["player"]
		state["enemies"][0]["pos"] = fixture["captain"]
		for row: Array in state["grid"]: row.fill("wall")
		for tile: Vector2i in fixture["candidates"]: state["grid"][tile.y][tile.x] = "stone"
		expect.call(Bramble.nearest_legal_center(engine, state, FIXTURE_WALL_CENTER, state["enemies"][0]) == fixture["expected"], "Thornwall equal-distance center prefers " + str(fixture["rank"]))
	var state: Dictionary = battle("earth")
	state["enemies"][0]["intent"] = authored(state, "thornwall")
	state["enemies"][1]["pos"] = FIXTURE_WALL_CENTER
	var tiles: Array[Vector2i] = Bramble.tiles(engine, state, state["enemies"][0])
	expect.call(tiles.has(FIXTURE_WALL_CENTER + Vector2i.DOWN) and tiles.all(func(tile: Vector2i) -> bool: return tile.y == FIXTURE_WALL_CENTER.y + 1), "Occupied Thornwall center relocates toward player before captain")
	var original: Dictionary = {"threats_at_rest": {"threats": [{"key": "enemy_1", "tiles": [], "alpha": 0.4, "order": "1"}]}}
	var before: Dictionary = original.duplicate(true)
	var presentation: Dictionary = BrambleView.presentation_for(state, original)
	var marked: Dictionary = presentation["threats_at_rest"]["threats"][0]
	expect.call(_same_tiles(marked["tiles"], tiles) and marked["alpha"] == 0.4 and marked["order"] == "1", "Thornwall marked intent preserves existing focus alpha and turn badge")
	expect.call(original == before and BrambleView.presentation_for(state, presentation) == presentation, "Thornwall presentation is immutable and idempotent")
	state["objective"] = {"type": "kill_all"}
	expect.call(BrambleView.presentation_for(state, original) == original, "Ordinary Weaver presentation stays unchanged")
	print("Thornwall center ties: player, captain and scan order checked")

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
		state = battle("ice")
		state["enemies"][0]["pos"] = FIXTURE_AXIS_CAPTAIN
		state["player"]["pos"] = FIXTURE_AXIS_CAPTAIN + Vector2i(fixture["delta"])
		var action: Dictionary = authored(state, "icefall")["actions"][0]
		var tiles: Array[Vector2i] = Icefall.tiles(engine, state, state["enemies"][0], action)
		var delta: Vector2i = fixture["delta"]
		var center: Vector2i = FIXTURE_AXIS_CAPTAIN + Vector2i(signi(delta.x) * ceili(absf(delta.x) * 0.5), signi(delta.y) * ceili(absf(delta.y) * 0.5))
		var expected: Array[Vector2i]
		for offset: int in range(-2, 3): expected.append(center + Vector2i(fixture["axis"]) * offset)
		expect.call(_same_tiles(tiles, expected), "Oracle wall uses approved dominant-cardinal orientation")
	print("Barrage/Oracle axes: exact diagonals and dominant axes checked")

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

static func _stormcaller(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = battle("air")
	var intent: Dictionary = authored(state, "call_the_wind")
	state["enemies"][0]["intent"] = intent
	var before: Dictionary = state.duplicate(true)
	var plan: Dictionary = engine.enemy_intent_plan(state, 0)
	var forecast: Dictionary = plan["wind_preview"]
	expect.call(forecast["displacement_paths"].size() == 3, "Stormcaller wind preview shows hero and both followers sliding")
	expect.call(plan["wind"]["direction"] == Vector2i.UP, "Stormcaller fixture calls northward wind")
	_stormcaller_destinations(forecast["state"], FIXTURE_WIND_EXPECTED, "preview", expect)
	var hero_path: Array[Vector2i] = engine._vector2i_values([FIXTURE_PLAYER, FIXTURE_WIND_EXPECTED["player"]])
	expect.call((forecast["displacement_paths"] as Array).has(hero_path), "Stormcaller previews independent one-tile hero path")
	for index: int in range(1, 3):
		var path: Array[Vector2i] = engine._vector2i_values([before["enemies"][index]["pos"], FIXTURE_WIND_EXPECTED["enemies"][index]])
		expect.call((forecast["displacement_paths"] as Array).has(path), "Stormcaller previews independent one-tile follower path")
	expect.call((forecast["displacement_paths"] as Array).all(func(path: Array) -> bool: return path[0] != FIXTURE_CAPTAIN), "Stormcaller preview contains no captain slide")
	expect.call(state == before, "Stormcaller preview never mutates state")
	state = Wind.resolve(engine, state, 0, intent["actions"][0])
	var steps: Array[Dictionary]
	state = Wind.end_turn(engine, state, steps)
	_stormcaller_destinations(state, FIXTURE_WIND_EXPECTED, "resolution", expect)
	for index: int in range(3): expect.call(state["enemies"][index]["pos"] == forecast["state"]["enemies"][index]["pos"], "Stormcaller real mover matches forecast")
	expect.call(state["player"]["pos"] == forecast["state"]["player"]["pos"], "Stormcaller hero slide matches forecast")
	for boundary: int in range(FIXTURE_PERSISTENCE_BOUNDARIES): state = Wind.end_turn(engine, state, steps)
	expect.call(not Wind.active(engine, state).is_empty() and state["wind"]["rounds_left"] == 2, "Stormcaller wind does not expire across enemy-turn boundaries")
	state = battle("air")
	state = Wind.resolve(engine, state, 0, intent["actions"][0])
	state["grid"][FIXTURE_WIND_HAZARD.y][FIXTURE_WIND_HAZARD.x] = "wall"
	var new_direction: Vector2i = Wind.direction(engine, state, state["enemies"][0])
	state = Wind.resolve(engine, state, 0, intent["actions"][0])
	expect.call(state["wind"]["direction"] == new_direction and new_direction == Vector2i.RIGHT, "A new Call re-aims persistent wind")
	state["enemies"][0]["hp"] = 0
	Wind.clear_dead_source(engine, state)
	expect.call(not state.has("wind"), "Stormcaller death immediately clears wind")
	_stormcaller_collision(expect)
	print("Order 3 stormcaller_wind: independent one-tile destinations, anchored captain, pillar collision, persistence and re-aim checked")

static func _stormcaller_destinations(state: Dictionary, expected: Dictionary, phase: String, expect: Callable) -> void:
	expect.call(state["player"]["pos"] == expected["player"], "Stormcaller %s independent one-tile hero destination" % phase)
	expect.call(state["enemies"][0]["pos"] == expected["enemies"][0], "Stormcaller %s captain stays anchored" % phase)
	for index: int in range(1, 3):
		expect.call(state["enemies"][index]["pos"] == expected["enemies"][index], "Stormcaller %s follower %d independent destination" % [phase, index])

static func _stormcaller_collision(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = battle("air")
	state["enemies"][0]["intent"] = authored(state, "call_the_wind")
	state["grid"][FIXTURE_WIND_PILLAR.y][FIXTURE_WIND_PILLAR.x] = "pillar"
	var before: Dictionary = state.duplicate(true)
	var plan: Dictionary = engine.enemy_intent_plan(state, 0)
	var forecast: Dictionary = plan["wind_preview"]
	_stormcaller_destinations(forecast["state"], FIXTURE_WIND_BLOCKED_EXPECTED, "pillar preview", expect)
	var markers: Array = forecast["collision_markers"]
	expect.call(markers.size() == 1 and markers[0].get("actor_key") == "enemy_2" and markers[0].get("tile") == FIXTURE_FOLLOWER_A and markers[0].get("blocked_tile") == FIXTURE_WIND_PILLAR and int(markers[0].get("damage", 0)) == FIXTURE_WIND_COLLISION_DAMAGE, "Stormcaller preview marks follower stopped by pillar with existing collision damage")
	expect.call((forecast["displacement_paths"] as Array).size() == 2 and not (forecast["displacement_paths"] as Array).any(func(path: Array) -> bool: return path[0] in [FIXTURE_CAPTAIN, FIXTURE_FOLLOWER_A]), "Stormcaller pillar preview omits blocked follower and anchored captain slides")
	expect.call(state == before, "Stormcaller pillar preview never mutates state")
	state = Wind.resolve(engine, state, 0, state["enemies"][0]["intent"]["actions"][0])
	var steps: Array[Dictionary]
	state = Wind.end_turn(engine, state, steps)
	_stormcaller_destinations(state, FIXTURE_WIND_BLOCKED_EXPECTED, "pillar resolution", expect)
	expect.call(int(state["enemies"][1]["hp"]) == FIXTURE_HP - FIXTURE_WIND_COLLISION_DAMAGE and int(forecast["state"]["enemies"][1]["hp"]) == FIXTURE_HP - FIXTURE_WIND_COLLISION_DAMAGE, "Stormcaller pillar stops follower and applies existing two-damage collision")
	var contacts: Array = engine._surface_events_since(before, state).filter(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "force_collision")
	expect.call(contacts.size() == 1 and contacts[0].get("actor_key") == "enemy_2" and contacts[0].get("blocked_tile") == FIXTURE_WIND_PILLAR, "Stormcaller pillar resolution records the existing collision event")

static func _oracle(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = battle("ice")
	var intent: Dictionary = authored(state, "icefall")
	if intent.is_empty():
		for candidate: Dictionary in Data.enemy_def("hoarfrost_seer")["intents"]:
			if str(candidate["actions"][0]["type"]) == "icefall_mark": intent = candidate.duplicate(true)
	state["enemies"][0]["intent"] = intent
	var before: Dictionary = state.duplicate(true)
	var plan: Dictionary = engine.enemy_intent_plan(state, 0)
	var expected: Array[Vector2i]
	for offset: int in range(-2, 3): expected.append(FIXTURE_WALL_CENTER + Vector2i.RIGHT * offset)
	expect.call(_same_tiles(plan["projected_attack"], expected) and state == before, "Oracle telegraphs five-tile midpoint wall without mutating state")
	state = engine._resolve_enemy_action(state, 0, intent["actions"][0])
	expect.call(_same_tiles(state["enemies"][0]["icefall_tiles"], expected), "Oracle stored marks equal preview")
	state["player"]["pos"] = FIXTURE_WALL_CENTER
	var landing: Dictionary = authored(state, "icefall_land")["actions"][0]
	expect.call(_same_tiles(Icefall.plan(engine, state, 0, {"actions": [landing]}, false)["projected_attack"], expected), "Oracle held wall stays telegraphed after movement")
	state = engine._resolve_enemy_action(state, 0, landing)
	expect.call(state["terrain"].size() == 4 and state["player"]["hp"] == FIXTURE_HP - int(landing["damage"]), "Oracle lands existing damage and only empty pillars")
	state["enemies"][1]["pos"] = FIXTURE_ICE_PUSH_START
	state = engine._force_move_actor(state, "enemy", int(state["enemies"][1]["id"]), Vector2i.DOWN, 1, {}, true)
	expect.call(state["terrain"].size() == 3 and state["enemies"][1]["hp"] == FIXTURE_HP - 2, "Oracle pillars retain existing shatter-for-two collision")
	state = battle("ice")
	state["player"]["pos"] = FIXTURE_ODD_MIDPOINT_HERO
	expect.call(Icefall.tiles(engine, state, state["enemies"][0], intent["actions"][0]).has(FIXTURE_ODD_MIDPOINT_CENTER), "Odd midpoint rounds toward player")
	print("Order 4 oracle_icewall: midpoint, held telegraph, damage and pillar shatter checked")

static func _dynamo(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = battle("lightning")
	var enemy: Dictionary = state["enemies"][0]
	enemy["charge"] = 2
	enemy["intent"] = authored(state, "charge")
	var before: Dictionary = state.duplicate(true)
	var plan: Dictionary = engine.enemy_intent_plan(state, 0)
	expect.call(Capacitor.threshold(state, enemy) == 2 and str(plan["attack_action"]["type"]) == "chain_discharge" and not plan["chain_hits"].is_empty(), "Dynamo previews Arc Burst at two Charge while both Thralls live")
	expect.call(state == before, "Dynamo forecast never mutates held intent/state")
	var view: Script = preload("res://scripts/enemy_mechanics/capacitor_view.gd")
	expect.call(view.badges(enemy, state)[0]["tooltip"].ends_with("2/2") and view.pip_centers(Rect2(), Capacitor.threshold(state, enemy)).size() == 2, "Dynamo display shows lower threshold")
	expect.call("At 2," in str(view.badges(enemy, state)[0]["tooltip"]) and "At 2," in str(view.rows(enemy["intent"], state, enemy)[0][0]["tooltip"]), "Dynamo charge badges and intent tooltip use current threshold")
	var result: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0)
	expect.call(result["state"]["player"]["hp"] < FIXTURE_HP and result["state"]["enemies"][0]["charge"] == 0, "Dynamo resolves and resets two-Charge Arc Burst")
	state["enemies"][1]["hp"] = 0
	var restored: Dictionary = engine.enemy_intent_plan(state, 0)
	expect.call(Capacitor.threshold(state, enemy) == 3 and str(restored["attack_action"]["type"]) == "gain_charge", "Killing either Thrall immediately restores threshold and cancels premature Burst")
	expect.call(view.badges(enemy, state)[0]["tooltip"].ends_with("2/3"), "Dynamo display immediately restores three Charge")
	state["enemies"][1]["hp"] = FIXTURE_HP
	state["enemies"][2]["hp"] = 0
	expect.call(Capacitor.threshold(state, enemy) == 3, "Either Thrall independently breaks Dynamo tether")
	print("Order 5 dynamo_tether: two-Charge preview/display, discharge and immediate threshold restoration checked")

static func _prior(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = battle("shadow")
	var follower: Dictionary = state["enemies"][1]
	expect.call(Veil.effective_veiled(state, follower) and not engine.is_enemy_visible_to_player(state, follower), "Prior preview hides distant follower before it can act")
	expect.call(not engine.visible_enemy_ids(state).has(int(follower["id"])), "Prior follower uses hidden-enemy presentation/preview rules")
	var before: Dictionary = state.duplicate(true)
	engine.enemy_threat_tiles(state, 1)
	expect.call(state == before, "Prior threat preview never mutates state")
	state["player"]["pos"] = FIXTURE_PRIOR_NEAR_HERO
	expect.call(engine.is_enemy_visible_to_player(state, follower) and not Veil.effective_veiled(state, follower), "Prior follower is revealed at distance two")
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
	expect.call(not broken["enemies"][1]["veiled"] and broken["enemies"][1]["warband_fled"], "Prior break clears native veil before fleeing")
	var shown: Dictionary = preload("res://scripts/warband_view.gd").flee_display_state(before, broken)
	for enemy: Dictionary in shown["enemies"]:
		if bool(enemy.get("warband_fled", false)): expect.call(engine.is_enemy_visible_to_player(shown, enemy), "Every Prior follower is visible in pre-break display")
	print("Order 6 prior_veil: hidden preview, range/Light/Truesight reveal and pre-break reveal checked")

static func _same_tiles(a: Array, b: Array) -> bool:
	if a.size() != b.size(): return false
	for tile: Vector2i in a:
		if not b.has(tile): return false
	return true

static func _scope_and_copy(expect: Callable) -> void:
	var rules: Script = preload("res://scripts/warband_combat_rules.gd")
	var objectives: Script = preload("res://scripts/combat_objective_rules.gd")
	var library: Script = preload("res://scripts/special_encounter_library.gd")
	var board: Control = preload("res://scripts/combat_board_view.gd").new()
	for biome: String in BIOMES:
		var state: Dictionary = battle(biome)
		var order: Dictionary = library.definition("warband")["variants"][biome]["order"]
		expect.call(rules.order(state, state["enemies"][0], str(order["id"])), "Order active only on matching living captain: " + biome)
		expect.call(not rules.order(state, state["enemies"][1], str(order["id"])), "Order never granted to follower: " + biome)
		var expected: String = "Order: " + str(order["text"])
		if biome == "air": expect.call(expected == STORMCALLER_ORDER_LINE, "Stormcaller protected Order copy says everyone else")
		expect.call(objectives.description_for_objective(state["objective"]).ends_with(expected), "Objective tooltip exact protected order copy: " + biome)
		board.combat_state = state
		expect.call(board.enemy_intent_tooltip("enemy_1").ends_with(expected), "Captain tooltip exact protected order copy: " + biome)
		state["enemies"][0]["hp"] = 0
		expect.call(not rules.order(state, state["enemies"][0], str(order["id"])), "Order ends at captain death: " + biome)
		state["enemies"][0]["hp"] = FIXTURE_HP
		state["objective"].erase("special_type")
		expect.call(not rules.order(state, state["enemies"][0], str(order["id"])), "Leader outside Warband never receives order: " + biome)
	var capacitor_state: Dictionary = battle("lightning")
	capacitor_state["enemies"][0]["charge"] = 2
	board.combat_state = capacitor_state
	var units: Array = board.call("_build_visible_units")
	expect.call(units.any(func(unit: Dictionary) -> bool: return int(unit.get("id", -1)) == 1 and int(unit.get("charge", -1)) == 2), "Dynamo board projection receives saved Charge")
	capacitor_state["objective"] = {"type": "kill_all"}
	board.combat_state = capacitor_state
	units = board.call("_build_visible_units")
	expect.call(units.all(func(unit: Dictionary) -> bool: return not unit.has("charge")), "Ordinary board projection remains unchanged outside Warband")
	board.free()

static func _save_load(expect: Callable) -> void:
	var store: Script = preload("res://scripts/progression_store.gd")
	var engine := Combat.new()
	var previous: String = store._run_storage_path
	store.set_run_storage_path(SAVE_PATH)
	for biome: String in BIOMES:
		var state: Dictionary = battle(biome)
		var intent: Dictionary = {}
		var verb: String = {"earth": "grow_bramble", "fire": "lob_mark", "air": "call_wind", "ice": "icefall_mark", "lightning": "gain_charge", "shadow": "ranged"}[biome]
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

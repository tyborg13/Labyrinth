extends RefCounted
## spx-08 Last Light: independent behavior checks against the authored data,
## with one explicit pin of the director's tuning.
const Rooms = preload("res://scripts/room_generator.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const RunEngineScript = preload("res://scripts/run_engine.gd")
const Progression = preload("res://scripts/progression_store.gd")
const GameData = preload("res://scripts/game_data.gd")
const Specials = preload("res://scripts/special_encounter_library.gd")
const LastLight = preload("res://scripts/last_light_rules.gd")
const Snuff = preload("res://scripts/enemy_mechanics/snuff.gd")
const Objectives = preload("res://scripts/combat_objective_rules.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Guardians = preload("res://scripts/guardian_library.gd")
const BossSuite = preload("res://tests/suites/dragon_boss_suite.gd")
const Fixture = preload("res://tools/last_light_inspection.gd")
const Icons = preload("res://scripts/room_icon_library.gd")
const BIOMES: Array = ["earth", "fire", "air", "ice", "lightning", "shadow"]
const ATTACKERS := {"earth": ["burrow_grub", "stoneback_mite"], "fire": ["ember_tick", "ash_hound"], "air": ["gust_shrike", "gale_herald"],
	"ice": ["rime_whelp", "hoarfrost_seer"], "lightning": ["lightning_wisp", "bell_tender"], "shadow": ["wick_shade", "veilbound_acolyte"]}
const DepthRules = preload("res://scripts/depth_rules.gd")
const SIGHT: int = 3
const BRAZIERS: int = 3
const BRAZIER_DISTANCE: int = 3
const HEAL_PER_BRAZIER: int = 2
const HEAL_CAP: int = 6
const SENTENCE: String = "After each of your turns, every enemy hidden in the dark Blinks 2 tiles toward you."
const TOOLTIP: String = "Brazier: lights 2 tiles around it. A Wick Shade's Snuff puts it out; step onto it to relight it."
const MAP_LINE: String = "Survive until dawn in the dark. Keep the braziers lit."
const REWARD_LINE: String = "+2 Health per brazier still lit at dawn"
const FIXTURE_SEEDS: Array = [83, 7, 19]
const TRAVELS: Array = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const PLAYER_HP: int = 40
const MAP_SCAN_SEEDS: int = 24
# Open-board geometry for the mechanics checks: hero on the south entry, braziers
# as the production placement puts them for that entry.
const HERO := Vector2i(4, 7)
const WEST := Vector2i(2, 6)
const EAST := Vector2i(6, 6)
const CENTER := Vector2i(4, 4)

static func run(expect: Callable) -> void:
	_test_data(expect)
	_test_layouts(expect)
	_test_darkness_and_rule(expect)
	_test_depth_sight(expect)
	_test_snuff(expect)
	_test_relight(expect)
	_test_rewards(expect)
	_test_map_and_fixture(expect)
	print("Last Light: data, %d biome x tier x seed x entry layouts, darkness, Shadowstep, Snuff, relight, reward, map and fixture" % (BIOMES.size() * 3 * FIXTURE_SEEDS.size() * TRAVELS.size()))

static func _test_data(expect: Callable) -> void:
	var raw: String = FileAccess.get_file_as_string("res://data/special_encounters.json")
	var data: Dictionary = JSON.parse_string(raw)["types"]["last_light"]
	expect.call(data["time_target_by_depth"] == _json([60, 66, 72]) and _expected_shade_cycle() == ["grasp", "snuff", "drift", "snuff"], "Director tuning pins Last Light clocks and the interleaved Shade cycle")
	expect.call(bool(data["enabled"]) and Specials.enabled_types().has("last_light"), "Last Light is enabled through the shared placement")
	for stale: String in ["brazier", "hold_player_turns", "flames", "light_radius_by_flames", "fire_relights"]:
		expect.call(not data.has(stale), "The pre-principle single-brazier field is removed: " + stale)
	expect.call(not raw.contains("heal_per_flame") and not raw.contains("\"twist\""), "No stub bonus kind or twist remains in the catalog")
	for biome: String in BIOMES:
		expect.call(data["variants"][biome].keys() == ["attackers"] and data["variants"][biome]["attackers"] == ATTACKERS[biome], "Each section keeps exactly its attackers: " + biome)
	expect.call(data["tooltip_line"] == MAP_LINE and data["emblem"] == "res://assets/art/icons/map/last_light.png", "Map tooltip and existing emblem")
	expect.call(data["bonus"]["kind"] == "heal_per_lit_brazier" and int(data["bonus"]["amount"]) == HEAL_PER_BRAZIER and int(data["bonus"]["max"]) == HEAL_CAP and data["bonus"]["reward_line"] == REWARD_LINE, "Dawn bonus kind, amount, cap and reward line")
	expect.call(int(data["sight_radius"]) == SIGHT and int(data["braziers"]["count"]) == BRAZIERS and int(data["braziers"]["distance_from_start"]) == BRAZIER_DISTANCE and data["braziers"]["tooltip"] == TOOLTIP, "Sight, brazier count, distance and tooltip")
	var staged: String = FileAccess.get_file_as_string("res://spec/peer_benchmark/staged/spx/special_encounters.json")
	expect.call(preload("res://tests/helpers/brs01_catalog.gd").matches(staged, raw), "The staged catalog stays byte-identical except the four brs-01 title fields")
	var instance: Dictionary = Rules.data()["instances"]["last_light"]
	expect.call(instance == _json({"rule": "shadowstep", "source": {"kind": "room"}, "cadence": {"anchor": "after_player_turn", "every": 1}, "dials": {"blink": 2, "who": "all_hidden"}, "sentence": SENTENCE}), "The Last Light Shadowstep instance is exact")
	var intents: Array = _shade_intents()
	var snuff: Dictionary = intents.filter(func(intent: Dictionary) -> bool: return intent["id"] == "snuff")[0]
	expect.call(snuff == _json({"id": "snuff", "name": "Snuff", "time": 4, "weight": snuff["weight"], "actions": [{"type": "move_toward", "range": 2, "snuff_brazier": true}]}), "Snuff keeps move_toward 2 with the existing snuff_brazier flag and Time 4; its weight is pinned by the cycle")
	expect.call(Icons.icon_id_for_room({"type": "special", "special_type": "last_light"}) == "special_last_light", "The map uses the special emblem registry")
	expect.call(Specials.tooltip_line({"type": "special", "special_type": "last_light"}) == MAP_LINE, "The map tooltip reads the catalog")

# Catalog numbers load as JSON floats; compare literals through the same parser.
static func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

static func _target_clock(tier: int) -> int:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/special_encounters.json"))
	return int(data["types"]["last_light"]["time_target_by_depth"][tier - 1])

static func _shade_intents() -> Array:
	return GameData.enemy_def("wick_shade")["intents"]

# Independent oracle: start with the authored non-Snuff order, then insert the
# weighted Snuff slots at every other position (excess slots go at the end).
static func _expected_shade_cycle() -> Array:
	var cycle: Array = []
	var snuff_slots: int = 0
	for intent: Dictionary in _shade_intents():
		if intent["id"] == "snuff": snuff_slots += maxi(1, int(intent.get("weight", 1)))
		else: cycle.append(intent["id"])
	for slot: int in range(snuff_slots): cycle.insert(mini(2 * slot + 1, cycle.size()), "snuff")
	return cycle

static func layout_for(biome: String, tier: int, seed_value: int = 83, travel: Vector2i = Vector2i.UP) -> Dictionary:
	return Rooms.new().generate_room(seed_value, Fixture.room_spec(biome, tier), travel)

static func combat_for(layout: Dictionary, seed_value: int = 83) -> Dictionary:
	return Combat.new().create_combat(seed_value, layout, {"hp": PLAYER_HP, "max_hp": PLAYER_HP, "deck_cards": GameData.starting_deck(), "equipped_equipment": GameData.starting_equipped_equipment(), "relics": []})

static func _edge(grid: Array, tile: Vector2i) -> bool:
	return tile.x == 1 or tile.y == 1 or tile.y == grid.size() - 2 or tile.x == (grid[tile.y] as Array).size() - 2

# Independent oracle: every interior floor tile at distance 3, then every triple
# compared by its smallest pairwise distance; the first best triple in row-major
# order wins.
static func _expected_braziers(grid: Array, start: Vector2i) -> Array:
	var tiles: Array = []
	for y: int in range(1, grid.size() - 1):
		for x: int in range(1, (grid[y] as Array).size() - 1):
			var tile := Vector2i(x, y)
			if absi(tile.x - start.x) + absi(tile.y - start.y) != BRAZIER_DISTANCE or _edge(grid, tile): continue
			if str(grid[y][x]) not in ["stone", "ember"] or Paths.find_path(grid, start, tile).is_empty(): continue
			tiles.append(tile)
	var best: Array = []
	var spread: int = -1
	for a: int in range(tiles.size()):
		for b: int in range(a + 1, tiles.size()):
			for c: int in range(b + 1, tiles.size()):
				var low: int = mini(Paths.manhattan(tiles[a], tiles[b]), mini(Paths.manhattan(tiles[a], tiles[c]), Paths.manhattan(tiles[b], tiles[c])))
				if low > spread:
					spread = low
					best = [tiles[a], tiles[b], tiles[c]]
	return best

static func _test_layouts(expect: Callable) -> void:
	var failures: Dictionary = {}
	for biome: String in BIOMES:
		for tier: int in range(1, 4):
			for seed_value: int in FIXTURE_SEEDS:
				for travel: Vector2i in TRAVELS:
					var layout: Dictionary = layout_for(biome, tier, seed_value, travel)
					var label: String = "%s t%d seed %d %s" % [biome, tier, seed_value, travel]
					var objective: Dictionary = layout["objective"]
					var types: Array = []
					for enemy: Dictionary in layout["enemies"]: types.append(enemy["type"])
					var cast: Array = ["wick_shade", "wick_shade"] + ATTACKERS[biome]
					var unique: Array = []
					for type: String in cast:
						if not unique.has(type): unique.append(type)
					var pool: Array = []
					for type: String in objective["reinforcement_pool"]: pool.append(type)
					var checks: Dictionary = {
						"objective": objective["type"] == "survive" and int(objective["target_clock"]) == _target_clock(tier) and int(objective["reinforcement_interval"]) == 16 and int(objective["next_reinforcement_clock"]) == 16,
						"copy": objective["name"] == "Survive until dawn!" and objective["description"] == "Survive until dawn." and Objectives.title_for_objective(objective) == "Survive until dawn!" and Objectives.description_for_objective(objective) == "Survive until dawn.",
						"goal": bool(objective["goal_met"]) and objective["special_type"] == "last_light" and objective["special_variant"] == biome,
						"cast": types == cast and pool == unique,
						"rule": layout["battlefield_rule"] == Rules.instance_for("last_light"),
						"room": layout["special_type"] == "last_light" and bool(layout["brazier_relight_on_step"]) and layout["umbra_stage"] == "deep",
					}
					var braziers: Array = layout["guardian_braziers"]
					var tiles: Array = []
					for brazier: Dictionary in braziers: tiles.append(brazier["pos"])
					checks["count"] = braziers.size() == BRAZIERS
					checks["oracle"] = tiles == _expected_braziers(layout["grid"], layout["player_start"])
					var occupied: Dictionary = {}
					for list: String in ["enemies", "traps", "loot", "terrain", "npcs"]:
						for entry: Dictionary in layout.get(list, []): occupied[entry.get("pos", Vector2i(-9, -9))] = true
					for index: int in range(braziers.size()):
						var tile: Vector2i = braziers[index]["pos"]
						checks["brazier_%d" % index] = int(braziers[index]["id"]) == index + 1 and bool(braziers[index]["lit"]) and Paths.manhattan(tile, layout["player_start"]) == BRAZIER_DISTANCE and not _edge(layout["grid"], tile) and Paths.is_passable(layout["grid"], tile) and not occupied.has(tile)
					for key: String in checks:
						if not bool(checks[key]): failures[key] = label
	for key: String in ["objective", "copy", "goal", "cast", "rule", "room", "count", "oracle", "brazier_0", "brazier_1", "brazier_2"]:
		expect.call(not failures.has(key), "Last Light layout check %s holds for every biome, tier, seed and entry (first failure: %s)" % [key, failures.get(key, "none")])

# An open interior, the three braziers where production places them for the
# south entry, and one enemy: the rule primitives isolated from template luck.
static func open_state(enemy_type: String = "wick_shade", enemy_tile: Vector2i = Vector2i(4, 1)) -> Dictionary:
	var state: Dictionary = combat_for(layout_for("fire", 1))
	for y: int in range(1, 8):
		for x: int in range(1, 8): state["grid"][y][x] = "stone"
	state["terrain"] = []
	state["traps"] = []
	state["loot"] = []
	state["surfaces"] = {}
	state["player"]["pos"] = HERO
	state["guardian_braziers"] = [{"id": 1, "pos": WEST, "lit": true}, {"id": 2, "pos": EAST, "lit": true}, {"id": 3, "pos": CENTER, "lit": true}]
	var keep: Dictionary = {}
	for enemy: Dictionary in state["enemies"]:
		if keep.is_empty() and str(enemy["type"]) == "wick_shade": keep = enemy
	keep["type"] = enemy_type
	keep["pos"] = enemy_tile
	state["enemies"] = [keep]
	state["turn_queue"] = (state["turn_queue"] as Array).filter(func(entry: Dictionary) -> bool: return str(entry.get("kind", "")) != "enemy" or int(entry.get("enemy_id", -1)) == int(keep["id"]))
	return state

static func _test_darkness_and_rule(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = combat_for(layout_for("earth", 1))
	expect.call(engine.effective_umbra_radius(state) == SIGHT and engine.effective_umbra_stage(state) == "deep", "The player's sight radius is 3 in Last Light")
	for tier: int in range(1, 4):
		for biome: String in ["earth", "shadow"]:
			expect.call(engine.effective_umbra_radius(combat_for(layout_for(biome, tier))) == SIGHT, "Sight stays 3 whatever the section stage: %s t%d" % [biome, tier])
	var open: Dictionary = open_state()
	open["guardian_braziers"] = []
	expect.call(engine.is_tile_visible_to_player(open, HERO + Vector2i(0, -3)) and not engine.is_tile_visible_to_player(open, HERO + Vector2i(0, -4)), "Manhattan sight reaches exactly 3 tiles")
	open = open_state()
	expect.call(engine.is_tile_visible_to_player(open, CENTER + Vector2i(0, -2)) and not engine.is_tile_visible_to_player(open, CENTER + Vector2i(0, -3)), "A lit brazier lights 2 tiles around it")
	open["guardian_braziers"][2]["lit"] = false
	expect.call(not engine.is_tile_visible_to_player(open, CENTER + Vector2i(0, -2)), "A snuffed brazier gives no Light")
	var shade: Dictionary = open["enemies"][0]
	expect.call(not engine.is_enemy_visible_to_player(open, shade), "An enemy past sight and Light is hidden")
	open["umbra"]["truesight_activations"] = 1
	expect.call(engine.is_enemy_visible_to_player(open, shade), "Truesight still reveals hidden enemies")
	var panel: Dictionary = Rules.panel(state)
	var snare: Dictionary = state.duplicate(true)
	snare["battlefield_rule"] = Rules.instance_for("snare_shadow")
	var snare_panel: Dictionary = Rules.panel(snare)
	expect.call(panel["rule"] == "shadowstep" and panel["sentence"] == SENTENCE and panel["name"] == snare_panel["name"] and panel["icon"] == snare_panel["icon"], "The rule panel shows Shadowstep with its sentence, as the Snare's does")
	var order: Array[Dictionary] = engine.current_turn_order(state, 12)
	var beat_after_player: bool = false
	for index: int in range(order.size() - 1):
		if str(order[index].get("kind", "")) == "player" and str(order[index + 1].get("kind", "")) == "beat": beat_after_player = true
	expect.call(beat_after_player, "The turn clock shows the Shadowstep beat right after the player's turn")
	# Shadowstep: a hidden Shade Blinks 2 toward the hero onto the nearest seen tile.
	var blink: Dictionary = open_state("wick_shade", Vector2i(4, 1))
	var forecast: Dictionary = Rules.forecast(engine, blink)
	var after: Dictionary = engine.finish_player_activation(blink)
	expect.call(after["enemies"][0]["pos"] == Vector2i(4, 3), "After your turn a hidden enemy Blinks 2 tiles toward you, into the light")
	expect.call(not forecast.get("emergences", []).is_empty() or not forecast.get("moves", []).is_empty(), "The beat is forecast a round ahead for its ghosts")
	var hud = preload("res://scripts/combat_objective_hud.gd").new()
	expect.call(hud._live_detail(state, state["objective"]) == "Dawn in %d · Reinforcements in 16" % _target_clock(1), "The HUD shows Survive's time and reinforcement count")
	hud.free()
	for tier: int in range(1, 4):
		var outcome: Dictionary = combat_for(layout_for("earth", tier))
		outcome["initiative_clock"] = _target_clock(tier) - 1
		expect.call(engine.combat_outcome(outcome).is_empty(), "Dawn does not win before the target clock: tier %d" % tier)
		outcome["initiative_clock"] = _target_clock(tier)
		expect.call(engine.combat_outcome(outcome) == "victory", "Dawn at the target clock wins: tier %d" % tier)

# int-09 r1: production layout -> combat, including the reviewed section-II /
# Umbra-depth-11 case. All six sections and all selectable depths (0 through 20).
static func _test_depth_sight(expect: Callable) -> void:
	var engine := Combat.new()
	var deep_state: Dictionary = {}
	for section: int in range(Graph.ROOM_COUNTS.size()):
		for umbra_depth: int in range(DepthRules.MAX_DEPTH + 1):
			var room: Dictionary = Fixture.room_spec(str(BIOMES[section]), 2)
			room["section_index"] = section
			room["depth"] = section * Combat.DEPTHS_PER_SEQUENCE + 2
			room[DepthRules.STATE_KEY] = umbra_depth
			var layout: Dictionary = Rooms.new().generate_room(Fixture.FIXTURE_SEED, room, Vector2i.UP)
			var state: Dictionary = combat_for(layout)
			expect.call(DepthRules.depth(state) == umbra_depth and engine.effective_umbra_radius(state) == SIGHT, "Last Light sight stays 3 at every section and Umbra depth: section %d depth %d" % [section + 1, umbra_depth])
			if section == 1 and umbra_depth == 11: deep_state = state
	# Captured Noon is the existing Light -> stage suppression effect. Last
	# Light's three lit braziers supply its three-Light threshold.
	deep_state["relics"] = ["tectonic_abacus"]
	expect.call(engine.effective_light_source_count(deep_state) == 3 and engine.effective_umbra_radius(deep_state) == 4, "Active Light still raises Last Light sight above 3 at Umbra depth 11")
	deep_state = engine._apply_umbra_vision(deep_state, {"amount": 1, "duration": 1})
	expect.call(engine.effective_umbra_radius(deep_state) == 5, "Vision still adds to Light in Last Light")
	print("Last Light depth sight: 126 generated section/depth cases; Light and Vision raise sight")

static func _snuff_intent(engine: RefCounted, state: Dictionary, enemy: Dictionary) -> Dictionary:
	var intents: Array = engine._scaled_enemy_intents(GameData.enemy_def("wick_shade")["intents"], int(state["room_depth"]), state, enemy)
	return Snuff.declare(state, enemy, engine._intent_by_id(intents, "snuff"))

static func _resolve_snuff(engine: RefCounted, state: Dictionary) -> Dictionary:
	state["enemies"][0]["intent"] = _snuff_intent(engine, state, state["enemies"][0])
	return engine.resolve_enemy_turn_with_steps(state, 0)["state"]

static func _ids(intents: Array) -> Array:
	var result: Array = []
	for intent: Dictionary in intents: result.append(intent["id"])
	return result

static func _test_snuff(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = open_state()
	var shade: Dictionary = state["enemies"][0]
	var intents: Array = engine._scaled_enemy_intents(_shade_intents(), 1, state, shade)
	var expected_cycle: Array = _expected_shade_cycle()
	expect.call(_ids(intents) == _ids(_shade_intents()) and _ids(Snuff.cycle_intents(intents)) == expected_cycle, "In Last Light the Shade's cycle interleaves Snuff at its authored weight")
	var cycle: Array = []
	var expected_assignments: Array = []
	shade["guardian_cycle"] = -1
	var rng := RandomNumberGenerator.new()
	for turn: int in range(expected_cycle.size() * 2):
		engine._assign_enemy_intent(state, 0, rng)
		cycle.append(state["enemies"][0]["intent"]["id"])
		expected_assignments.append(expected_cycle[turn % expected_cycle.size()])
	expect.call(cycle == expected_assignments, "Assigned Shade intents follow the weighted cycle")
	var dark: Dictionary = state.duplicate(true)
	for brazier: Dictionary in dark["guardian_braziers"]: brazier["lit"] = false
	var ordinary_ids: Array = _ids(_shade_intents()).filter(func(id: String) -> bool: return id != "snuff")
	expect.call(_ids(engine._scaled_enemy_intents(_shade_intents(), 1, dark, shade)) == ordinary_ids, "With no lit brazier the Shade never picks Snuff")
	# Target: nearest lit brazier to the Shade, ties by brazier index.
	state["enemies"][0]["pos"] = Vector2i(4, 2)
	expect.call(int(_snuff_intent(engine, state, state["enemies"][0])["actions"][0]["brazier_id"]) == 3, "Snuff targets the lit brazier nearest the Shade")
	state["enemies"][0]["pos"] = Vector2i(4, 6)
	expect.call(int(_snuff_intent(engine, state, state["enemies"][0])["actions"][0]["brazier_id"]) == 1, "Equal distances keep the lowest brazier index")
	var plan_state: Dictionary = open_state("wick_shade", Vector2i(4, 1))
	plan_state["enemies"][0]["intent"] = _snuff_intent(engine, plan_state, plan_state["enemies"][0])
	var plan: Dictionary = engine.enemy_intent_plan(plan_state, 0)
	expect.call(plan["target_tile"] == CENTER and plan["destination"] == Vector2i(4, 3) and bool(plan["snuff_lands"]) and int(plan["snuff_brazier_id"]) == 3, "The plan and preview head for the threatened brazier")
	# Move 2, then put it out only if adjacent.
	var near: Dictionary = _resolve_snuff(engine, open_state("wick_shade", Vector2i(4, 1)))
	expect.call(near["enemies"][0]["pos"] == Vector2i(4, 3) and not bool(near["guardian_braziers"][2]["lit"]) and bool(near["guardian_braziers"][0]["lit"]), "A Shade 3 away moves 2 and snuffs its brazier")
	expect.call(int(near["objective"]["brazier_snuffs"]) == 1 and near["surface_events"].any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "brazier_snuffed" and int(event["brazier_id"]) == 3), "A Snuff is counted and recorded")
	var far_state: Dictionary = open_state("wick_shade", Vector2i(1, 2))
	far_state["guardian_braziers"][0]["lit"] = false
	far_state["guardian_braziers"][1]["lit"] = false
	var far: Dictionary = _resolve_snuff(engine, far_state)
	expect.call(Paths.manhattan(far["enemies"][0]["pos"], CENTER) == 3 and bool(far["guardian_braziers"][2]["lit"]) and int(far["objective"]["brazier_snuffs"]) == 0, "A Shade left 3 away does not snuff")
	var rooted: Dictionary = open_state("wick_shade", CENTER + Vector2i.UP)
	rooted["enemies"][0]["immobilize"] = true
	rooted = _resolve_snuff(engine, rooted)
	expect.call(rooted["enemies"][0]["pos"] == CENTER + Vector2i.UP and not bool(rooted["guardian_braziers"][2]["lit"]), "A rooted Shade beside its brazier still snuffs it")
	var rooted_far: Dictionary = open_state("wick_shade", CENTER + Vector2i(0, -2))
	rooted_far["enemies"][0]["immobilize"] = true
	rooted_far = _resolve_snuff(engine, rooted_far)
	expect.call(rooted_far["enemies"][0]["pos"] == CENTER + Vector2i(0, -2) and bool(rooted_far["guardian_braziers"][2]["lit"]), "A rooted Shade cannot reach a brazier 2 away")
	var shocked: Dictionary = open_state("wick_shade", CENTER + Vector2i.UP)
	shocked["enemies"][0]["shock"] = 1
	shocked = _resolve_snuff(engine, shocked)
	expect.call(bool(shocked["guardian_braziers"][2]["lit"]), "A Shocked Shade only moves; it cannot snuff")
	var retarget: Dictionary = open_state("wick_shade", Vector2i(4, 1))
	retarget["enemies"][0]["intent"] = _snuff_intent(engine, retarget, retarget["enemies"][0])
	retarget["guardian_braziers"][2]["lit"] = false
	expect.call(int(Snuff.target(retarget, retarget["enemies"][0], retarget["enemies"][0]["intent"]["actions"][0])["id"]) == 1, "If its brazier is already out, the Shade turns to the nearest lit one")
	# Outside Last Light: the Lamplighter's lit braziers are not relit by stepping, so its Shades keep their exact cycle.
	var lamplighter: Dictionary = _lamplighter()
	var helper: int = -1
	for index: int in range(lamplighter["enemies"].size()):
		if str(lamplighter["enemies"][index]["type"]) == "wick_shade": helper = index
	expect.call(helper >= 0 and not Snuff.lit_braziers(lamplighter).is_empty(), "The Lamplighter fight has a Wick Shade and lit braziers")
	expect.call(_ids(engine._scaled_enemy_intents(_shade_intents(), int(lamplighter["room_depth"]), lamplighter, lamplighter["enemies"][helper])) == ordinary_ids, "Lamplighter Shades are offered no Snuff")
	var lamp_cycle: Array = []
	for turn: int in range(6):
		engine._assign_enemy_intent(lamplighter, helper, rng)
		lamp_cycle.append(lamplighter["enemies"][helper]["intent"]["id"])
	var alternates: bool = not lamp_cycle.has("snuff")
	for index: int in range(lamp_cycle.size() - 1): alternates = alternates and lamp_cycle[index] != lamp_cycle[index + 1]
	expect.call(alternates, "Lamplighter Shades alternate Grasp and Hooking Grasp exactly as before")
	var noctyrax: Dictionary = BossSuite._boss_combat_state("noctyrax")
	expect.call(not Snuff.available(noctyrax) and not Snuff.lit_braziers(noctyrax).is_empty(), "Noctyrax's braziers are not snuffable by Shades")

static func _lamplighter() -> Dictionary:
	var layout: Dictionary = Rooms.new().generate_room(92, {"coord": Vector2i(2, 1), "depth": 2, "type": "guardian", "element": "shadow", "boss_id": "noctyrax"}, Vector2i.ZERO)
	return Combat.new().create_combat(92, layout, {"hp": 24, "max_hp": 24, "deck_cards": ["pale_spark"]})

static func _test_relight(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = open_state()
	state["guardian_braziers"][2]["lit"] = false
	state["player"]["pos"] = CENTER + Vector2i.DOWN
	state = engine.apply_player_action(state, {"type": "move", "range": 1}, CENTER)
	expect.call(state["player"]["pos"] == CENTER and bool(state["guardian_braziers"][2]["lit"]), "Stepping onto an unlit brazier relights it in Last Light")
	expect.call(state["surface_events"].any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "brazier_relit" and int(event["brazier_id"]) == 3), "A room relight records its own event")
	var lamplighter: Dictionary = _lamplighter()
	var brazier: Dictionary = lamplighter["guardian_braziers"][0]
	brazier["lit"] = false
	lamplighter["terrain"] = []
	lamplighter["traps"] = []
	var tile: Vector2i = brazier["pos"]
	var from: Vector2i = tile
	for direction: Vector2i in Paths.DIRS_4:
		if Paths.is_passable(lamplighter["grid"], tile + direction) and engine._enemy_index_at_tile(lamplighter, tile + direction) < 0: from = tile + direction
	lamplighter["player"]["pos"] = from
	lamplighter = engine.apply_player_action(lamplighter, {"type": "move", "range": 1}, tile)
	expect.call(lamplighter["player"]["pos"] == tile and not bool(lamplighter["guardian_braziers"][0]["lit"]), "The Lamplighter's braziers still only relight after Last Procession")
	var dragon: Dictionary = BossSuite._boss_combat_state("noctyrax")
	dragon["terrain"] = []
	dragon["traps"] = []
	var refuge: Dictionary = dragon["guardian_braziers"][0]
	refuge["lit"] = false
	dragon["player"]["pos"] = refuge["pos"] + Vector2i.LEFT
	dragon = engine.apply_player_action(dragon, {"type": "move", "range": 1}, refuge["pos"])
	expect.call(bool(dragon["guardian_braziers"][0]["lit"]) and dragon["surface_events"].any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "dragon_light_restored"), "Noctyrax's relight keeps its exact event")

static func _victory(engine: RunEngineScript, combat: RefCounted, lit: int, hp: int) -> Dictionary:
	var state: Dictionary = Fixture.build(engine, combat, engine.create_new_run(83, Progression.default_data()), {"last_light_biome": "fire", "last_light_tier": 1, "last_light_case": "encounter"})
	var battle: Dictionary = state["combat_state"].duplicate(true)
	for index: int in range(battle["guardian_braziers"].size()): battle["guardian_braziers"][index]["lit"] = index < lit
	battle["initiative_clock"] = int(battle["objective"]["target_clock"])
	battle["player"]["hp"] = hp
	return {"before": state, "after": engine.finish_combat(state, battle), "battle": battle}

static func _test_rewards(expect: Callable) -> void:
	var engine := RunEngineScript.new()
	var combat := Combat.new()
	var maximum: int = int(engine.create_new_run(83, Progression.default_data())["player_max_hp"])
	for lit: int in range(0, BRAZIERS + 1):
		var result: Dictionary = _victory(engine, combat, lit, 5)
		var after: Dictionary = result["after"]
		expect.call(after["mode"] == "reward" and int(after["player_hp"]) == 5 + HEAL_PER_BRAZIER * lit, "Dawn heals 2 Health per lit brazier: %d lit" % lit)
		expect.call(int(after["pending_reward"].get("healed_amount", -1)) == HEAL_PER_BRAZIER * lit, "The reward records the dawn heal: %d lit" % lit)
		expect.call(after["pending_reward"]["cards"].size() == 4, "Last Light pays the shared four-card special offer")
		var room: Dictionary = Graph.room(after, after["current_room"])
		expect.call(bool(room["special_goal_met"]) and int(after["pending_reward"]["ember_amount"]) == Specials.reward_embers(room, result["battle"]), "Last Light pays the shared 1.5x starting-roster Embers")
		expect.call(engine.finish_combat(after, result["battle"]) == after, "The dawn heal cannot be paid twice")
	var capped: Dictionary = _victory(engine, combat, BRAZIERS, maximum - 1)["after"]
	expect.call(int(capped["player_hp"]) == maximum and int(capped["pending_reward"]["healed_amount"]) == 1, "The dawn heal is capped at max Health")
	expect.call(LastLight.dawn_heal({"special_type": "last_light"}, {"guardian_braziers": [{"lit": true}, {"lit": true}, {"lit": true}, {"lit": true}]}) == HEAL_CAP, "The dawn heal is capped at 6")
	var lost: Dictionary = _victory(engine, combat, BRAZIERS, 5)
	var context: Dictionary = combat.last_light_context(lost["battle"])
	expect.call(context == {"braziers_lit_at_dawn": BRAZIERS, "brazier_snuffs": 0}, "Analytics report braziers lit at dawn and Snuffs")
	var defeat_battle: Dictionary = lost["battle"].duplicate(true)
	defeat_battle["initiative_clock"] = 0
	defeat_battle["player"]["hp"] = 0
	var defeat: Dictionary = engine.finish_combat(lost["before"], defeat_battle)
	expect.call(defeat["mode"] == "defeat" and int(defeat["player_hp"]) == 0, "Defeat in Last Light is an ordinary defeat")
	_test_analytics(expect, lost["before"], lost["battle"], lost["after"])
	expect.call(combat.last_light_context(defeat_battle)["braziers_lit_at_dawn"] == 0 and combat.last_light_context({"objective": {"type": "kill_all"}}).is_empty(), "Only a dawn counts lit braziers; other fights add no fields")

# Both the UI and the headless console append the additive fields to the
# existing combat_ended payload; the special type rides in the event context.
static func _test_analytics(expect: Callable, run: Dictionary, battle: Dictionary, result: Dictionary) -> void:
	var Analytics = preload("res://scripts/analytics_store.gd")
	var previous_dir: String = Analytics.storage_dir()
	Analytics.set_storage_dir("user://spx08-analytics")
	var snuffed: Dictionary = battle.duplicate(true)
	snuffed["objective"]["brazier_snuffs"] = 2
	for caller: String in ["UI", "console"]:
		Analytics.clear_storage()
		var store = Analytics.new()
		var host = preload("res://scripts/run_scene.gd").new() if caller == "UI" else preload("res://tools/headless_playtest.gd").new()
		host.set("_analytics_store", store)
		host.set("_progression", run["progression"].duplicate(true))
		host.set("_run_state", result.duplicate(true))
		host.set("_combat_state", {})
		if caller == "UI": host._analytics_log_combat_transition(run, "last_light_test", snuffed)
		else: host._log_combat_transition(run, "last_light_test", snuffed)
		var ended: Array = Analytics.load_all_events().filter(func(event: Dictionary) -> bool: return event["event_type"] == "combat_ended")
		expect.call(ended.size() == 1 and int(ended[0]["payload"]["braziers_lit_at_dawn"]) == BRAZIERS and int(ended[0]["payload"]["brazier_snuffs"]) == 2 and ended[0]["special_type"] == "last_light", "Additive Last Light analytics fields: " + caller)
		host.free()
	Analytics.clear_storage()
	Analytics.set_storage_dir(previous_dir)

static func _test_map_and_fixture(expect: Callable) -> void:
	var found: Dictionary = {}
	for seed_value: int in range(1, MAP_SCAN_SEEDS + 1):
		var state: Dictionary = {"seed": seed_value, "current_room": Vector2i.ZERO, "mode": "room"}
		Graph.initialize(state)
		for node: Dictionary in state["rooms"].values():
			if str(node.get("special_type", "")) != "last_light": continue
			found[node["special_variant"]] = true
	expect.call(found.size() == BIOMES.size(), "Last Light is placed on real revision-%d maps in every section biome" % Graph.LAYOUT_REVISION)
	var older: int = 0
	for seed_value: int in range(1, MAP_SCAN_SEEDS + 1):
		var saved: Dictionary = {"seed": seed_value, "current_room": Vector2i.ZERO, "mode": "room", "section_map_layout_revision": 6}
		Graph.initialize(saved)
		for node: Dictionary in saved["rooms"].values(): older += int(str(node.get("special_type", "")) == "last_light")
	expect.call(older == 0 and int(Specials.definition("last_light")["first_layout_revision"]) == 7, "Last Light joins revision 7 maps only; saved revision-6 maps regenerate unchanged")
	var engine := RunEngineScript.new()
	var combat := Combat.new()
	var pre: Dictionary = Fixture.build(engine, combat, engine.create_new_run(83, Progression.default_data()), {"last_light_biome": "shadow", "last_light_tier": 2, "last_light_case": "pre_battle"})
	expect.call(pre["mode"] == "pre_battle" and bool(pre["pre_battle_pending"]) and pre["current_room_layout"]["special_type"] == "last_light", "The pre-battle fixture opens the Last Light pre-battle")
	var encounter: Dictionary = Fixture.build(engine, combat, engine.create_new_run(83, Progression.default_data()), {"last_light_biome": "shadow", "last_light_tier": 2, "last_light_case": "encounter"})
	expect.call(encounter["mode"] == "combat" and encounter["combat_state"]["guardian_braziers"].size() == BRAZIERS and LastLight.active(encounter["combat_state"]), "The encounter fixture starts the Last Light fight")
	var repaired_rule: Dictionary = encounter["combat_state"].get("battlefield_rule", {})
	expect.call(bool(encounter["combat_state"].get("brazier_relight_on_step", false)) and str(repaired_rule.get("rule", "")) == "shadowstep" and str(repaired_rule.get("sentence", "")) == SENTENCE, "Load repair keeps the room's relight flag and rule")
	expect.call(Fixture.validate({"last_light_biome": "nowhere"}) != "" and Fixture.validate({"last_light_tier": 4}) != "" and Fixture.validate({"last_light_case": "escape"}) != "", "The fixture rejects unknown options")

extends RefCounted

const CombatScript = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Bramble = preload("res://scripts/enemy_mechanics/bramble.gd")
const Lob = preload("res://scripts/enemy_mechanics/lob.gd")
const BrambleView = preload("res://scripts/enemy_mechanics/bramble_view.gd")
const LobView = preload("res://scripts/enemy_mechanics/lob_view.gd")
const Wind = preload("res://scripts/enemy_mechanics/wind.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Store = preload("res://scripts/progression_store.gd")
const Scene = preload("res://scripts/run_scene.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Compass = preload("res://scripts/enemy_intent_compass.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Strikes = preload("res://scripts/enemy_strike_points.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const ThreatTiles = preload("res://scripts/threat_tiles.gd")
const FIXTURE_SEED: int = 20261012
const FIXTURE_BOARD_SIZE: int = 11
const FIXTURE_PLAYER_HP: int = 50
const FIXTURE_HELPER_HP: int = 20
const FIXTURE_TERRAIN_MAX_HP: int = 3
const FIXTURE_REST_QUEUE_TIME: int = 8
const FIXTURE_REST_SPENT_TIME: int = 10
const FIXTURE_REST_CARD_PLAYS: int = 2
const FIXTURE_HERO := Vector2i(5, 5)
const FIXTURE_SOURCE := Vector2i(5, 2)
const SAVE_PATH: String = "user://en04_roundtrip.save"
const AI_ROLL_COUNT: int = 32

static func fixture(engine: RefCounted, type: String = "briar_weaver") -> Dictionary:
	var grid: Array
	for y: int in range(FIXTURE_BOARD_SIZE):
		var row: Array[String]
		for x: int in range(FIXTURE_BOARD_SIZE): row.append("wall" if x == 0 or y == 0 or x == FIXTURE_BOARD_SIZE - 1 or y == FIXTURE_BOARD_SIZE - 1 else "stone")
		grid.append(row)
	var definition: Dictionary = Data.enemy_def(type)
	var room: Dictionary = {"coord": Vector2i(1, 0), "depth": 2, "type": "combat", "grid": grid, "player_start": FIXTURE_HERO, "enemies": [{"id": 1, "type": type, "pos": FIXTURE_SOURCE, "hp": definition["max_hp"], "max_hp": definition["max_hp"]}], "terrain": [], "traps": [], "loot": []}
	var state: Dictionary = engine.create_combat(FIXTURE_SEED, room, {"hp": FIXTURE_PLAYER_HP, "max_hp": FIXTURE_PLAYER_HP, "deck_cards": ["quick_stab", "brace"], "skill_ids": [], "relics": [], "hand_size": 1})
	state.erase("umbra")
	return state

static func intent(type: String, id: String) -> Dictionary:
	for entry: Dictionary in Data.enemy_def(type)["intents"]:
		if str(entry["id"]) == id: return entry.duplicate(true)
	return {}

static func enemy(id: int, pos: Vector2i, hp: int = FIXTURE_HELPER_HP, type: String = "crawler") -> Dictionary:
	return {"id": id, "type": type, "pos": pos, "hp": hp, "max_hp": hp, "block": 0, "stoneskin": 0, "intent": {}}

static func terrain(tile: Vector2i, rounds: int = 3) -> Dictionary:
	return {"id": "proof_bramble", "kind": "bramble", "pos": tile, "rounds_left": rounds, "pushed_damage": 2, "pushed_bleed": 1, "blocks_sight": false}

static func run(expect: Callable) -> void:
	var engine: RefCounted = CombatScript.new()
	_schema(engine, expect)
	_thornwall(engine, expect)
	_collision_and_lifetime(engine, expect)
	_mend(engine, expect)
	_lob(engine, expect)
	_gating(engine, expect)
	_save(engine, expect)
	_presentation(engine, expect)
	_integration_boundaries(engine, expect)
	_bramble_paint(expect)
	_terrain_health_bars(engine, expect)
	_itb03_presentation(engine, expect)
	_shared_animation_hook(expect)

static func _shared_animation_hook(expect: Callable) -> void:
	var scene: Control = Scene.new()
	for field: String in ["en04_state_after", "en06_after"]:
		scene._player_popup_timeline_active = true
		scene._player_popup_timeline_groups.clear()
		var after: Dictionary = {"resolved": true}
		var animated: Dictionary = {"stale": true}
		var step: Dictionary = {"grounded_targets": [{"tile": FIXTURE_SOURCE}]}
		step[field] = after
		scene._apply_animation_step(animated, step)
		expect.call(animated.get("resolved", false) and animated.has("stale") == (field == "en06_after"), "Both waves preserve their snapshot replacement/merge behavior")
		expect.call(scene._player_popup_timeline_groups.size() == 1 and scene._player_popup_timeline_groups[0]["entries"][0]["text"] == "Grounded", "Both waves retain the shared Grounded popup hook")
	scene.free()

static func _rest_clock(state: Dictionary) -> void:
	state["current_actor"] = {"kind": "player"}
	var queue: Array[Dictionary]
	queue.append({"kind": "enemy", "enemy_id": 1, "time": FIXTURE_REST_QUEUE_TIME, "seq": 1})
	state["turn_queue"] = queue
	state["player_turn_time_spent"] = FIXTURE_REST_SPENT_TIME
	state["cards_played_this_turn"] = FIXTURE_REST_CARD_PLAYS

static func _itb03_presentation(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = fixture(engine)
	state["enemies"][0]["intent"] = intent("briar_weaver", "thornwall")
	_rest_clock(state)
	var rest: Dictionary = Badges.build(engine, state, state)
	var chip: Dictionary = rest["badges"][0]
	expect.call(chip["icon"] == "bramble" and chip["number"] == "3", "Thornwall feet chip uses the approved Bramble icon and lifetime")
	expect.call(chip["family"] == Compass.FAMILY_SUPPORT, "Thornwall retains the itb-03 support-chip family")
	expect.call(chip["order"] == "1" and bool(chip["acting"]), "Thornwall has the projected health-bar order disc")
	expect.call(not Badges.details_discloses_compass({"threats_at_rest": rest}, "enemy_1"), "Thornwall has no compass at rest")
	state["enemies"][0]["intent"] = intent("briar_weaver", "root_mend")
	rest = Badges.build(engine, state, state)
	chip = rest["badges"][0]
	expect.call(chip["icon"] == Icons.action_icon_key(intent("briar_weaver", "lash_of_thorns")["actions"][0]) and chip["number"] == "3" and chip["secondary_icon"] == "bleed", "Root Mend fallback is expressed by the actual Lash feet chip")
	state = fixture(engine, "slag_mortar")
	state["enemies"][0]["intent"] = intent("slag_mortar", "lob_slag")
	_rest_clock(state)
	for landing: bool in [false, true]:
		if landing:
			state = engine._resolve_enemy_action(state, 0, intent("slag_mortar", "lob_slag")["actions"][0])
			state["enemies"][0]["intent"] = intent("slag_mortar", "slag_lands")
		var original: Dictionary = state.duplicate(true)
		rest = Badges.build(engine, state, state)
		chip = rest["badges"][0]
		expect.call(chip["icon"] == "lob" and chip["number"] == "5", "Lob mark/landing feet chip uses the real landing damage")
		expect.call(chip["order"] == "1" and bool(chip["danger"]), "Lob owner disc agrees with the clock and hero danger")
		var zone: Dictionary = rest["threats"][0]
		expect.call(bool(zone["area"]) and zone["tiles"] == engine.enemy_threat_tiles(state, 0)["projected_attack"], "Lob mark/landing is an area zone using the resolved plus shape")
		var tags: Array[Dictionary] = ThreatTiles.zone_tags(rest["threats"])
		expect.call(tags.size() == 1, "Lob mark/landing has exactly one owner zone tag")
		expect.call(tags[0]["key"] == "enemy_1" and tags[0]["order"] == chip["order"] and tags[0]["tile"] == FIXTURE_HERO + Vector2i.UP, "Lob zone tag uses the attacker's order on the nearest marked tile")
		expect.call(not Badges.details_discloses_compass({"threats_at_rest": rest}, "enemy_1"), "Lob has no compass at rest")
		expect.call(state == original, "itb-03 Lob presentation preserves combat, marks and schedule")
	var cache: Resource = load("res://assets/generated/unit_shadow_cache.res")
	for type: String in ["briar_weaver", "slag_mortar", "storm_capacitor", "hollow_mimic"]:
		var path: String = "res://assets/art/enemies/%s.png" % type
		expect.call(cache.entries.has(path) and cache.source_sha256.get(path, "") == FileAccess.get_sha256(path), "Both waves retain current shadow entries: %s" % type)

static func _terrain_health_bars(engine: RefCounted, expect: Callable) -> void:
	var board: Control = Board.new()
	board.combat_state = fixture(engine)
	var tile: Vector2i = FIXTURE_HERO + Vector2i.UP
	var non_destructible: Array[Dictionary]
	non_destructible.append(terrain(tile))
	for max_hp: int in [0, -1]:
		var bramble: Dictionary = terrain(tile)
		bramble["max_hp"] = max_hp
		non_destructible.append(bramble)
	var pillar: Dictionary = terrain(tile)
	pillar["kind"] = "ice_pillar"
	non_destructible.append(pillar)
	var pillar_with_hp: Dictionary = pillar.duplicate(true)
	pillar_with_hp.merge({"hp": FIXTURE_TERRAIN_MAX_HP, "max_hp": FIXTURE_TERRAIN_MAX_HP}, true)
	non_destructible.append(pillar_with_hp)
	for entry: Dictionary in non_destructible:
		var label: String = "%s (max_hp %s)" % [entry["kind"], entry.get("max_hp", "absent")]
		board.attack_tiles = engine._vector2i_values([])
		board.presentation = {}
		expect.call(not board._should_show_terrain_health_bar(entry), "%s has no health bar at rest" % label)
		board.attack_tiles = engine._vector2i_values([tile])
		expect.call(not board._should_show_terrain_health_bar(entry), "%s has no health bar in attack tiles" % label)
		board.attack_tiles = engine._vector2i_values([])
		var previews: Dictionary = {}
		previews[board._terrain_key(entry)] = {"hp": 1, "hp_loss": 2, "lethal": false}
		board.presentation = {"effect": {"preview": true, "damage_preview": previews}}
		expect.call(not board._should_show_terrain_health_bar(entry), "%s has no health bar under damage preview" % label)
		expect.call(board._terrain_damage_preview(entry).is_empty(), "%s excludes terrain damage preview bars" % label)
	for kind: String in ["wooden_box", "wooden_crate", "powder_keg"]:
		var entry: Dictionary = {"id": kind, "kind": kind, "pos": tile, "hp": FIXTURE_TERRAIN_MAX_HP, "max_hp": FIXTURE_TERRAIN_MAX_HP}
		board.attack_tiles = engine._vector2i_values([])
		board.presentation = {}
		expect.call(not board._should_show_terrain_health_bar(entry), "Undamaged %s still hides its health bar at rest" % kind)
		entry["hp"] = FIXTURE_TERRAIN_MAX_HP - 1
		expect.call(board._should_show_terrain_health_bar(entry), "Damaged %s still shows its health bar" % kind)
		entry["hp"] = FIXTURE_TERRAIN_MAX_HP
		board.attack_tiles = engine._vector2i_values([tile])
		expect.call(board._should_show_terrain_health_bar(entry), "Attack-highlighted %s still shows its health bar" % kind)
		board.attack_tiles = engine._vector2i_values([])
		var previews: Dictionary = {}
		var damage_preview: Dictionary = {"hp": 1, "hp_loss": 2, "lethal": false}
		previews[board._terrain_key(entry)] = damage_preview
		board.presentation = {"effect": {"preview": true, "damage_preview": previews}}
		expect.call(board._should_show_terrain_health_bar(entry), "%s still shows its health bar under damage preview" % kind)
		expect.call(board._terrain_damage_preview(entry) == damage_preview, "%s retains its terrain damage preview" % kind)
	board.free()

static func _schema(engine: RefCounted, expect: Callable) -> void:
	var staged: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://spec/peer_benchmark/staged/enemies/wave_e2.json"))
	var production: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	for type: String in ["briar_weaver", "slag_mortar"]:
		var expected: Dictionary = staged[type].duplicate(true)
		var presentation = preload("res://scripts/maquette_cutout_runtime/presentation.gd")
		if presentation.handles(type):
			expected["art_path"] = presentation.asset_directory(type).path_join("front/rest.png")
			expected["art_rear_path"] = presentation.asset_directory(type).path_join("rear/rest.png")
		expect.call(production[type] == expected, "%s protected mechanics retained with registered production art" % type)
		var definition: Dictionary = Data.enemy_def(type)
		for field: String in ["name", "max_hp", "base_initiative", "reward_embers", "accent", "art_path", "intents"]: expect.call(definition.has(field), "%s schema: %s" % [type, field])
		var ids: Dictionary = {}
		for entry: Dictionary in definition["intents"]:
			expect.call(not ids.has(entry["id"]) and not str(entry["name"]).is_empty() and int(entry["time"]) > 0 and int(entry["weight"]) >= 0, "%s valid unique intent %s" % [type, entry["id"]])
			ids[entry["id"]] = true
			for action: Dictionary in entry["actions"]: expect.call(str(action["type"]) in ["grow_bramble", "heal_ally", "lob_mark", "lob_land", "ranged", "block", "move_away"], "Supported unit verb")
		expect.call(Assets.load_texture(definition["art_path"]) != null, "%s static art loads" % type)
		var portrait: String = Scene.TURN_ORDER_PORTRAITS.get(type, "")
		expect.call(portrait == "res://assets/art/portraits/%s.png" % type and Assets.load_texture(portrait) != null, "%s registered portrait loads" % type)
		expect.call((type in preload("res://scripts/cutout_context.gd").STATIC_ENEMY_TYPES) != presentation.handles(type), "%s feedback follows the production registration" % type)
		var found: bool = false
		for actor: Dictionary in engine.current_turn_order(fixture(engine, type)):
			if str(actor.get("key", actor.get("actor_key", ""))) == "enemy_1" or str(actor.get("type", actor.get("enemy_type", ""))) == type: found = true
		expect.call(found, "%s present in turn clock" % type)
		expect.call(Strikes.REGISTRY.has(type), "%s static strike registration" % type)
	for concept: String in ["bramble", "lob"]: expect.call(Icons.icon_texture(concept) != null, "%s distinct approved icon loads" % concept)

static func _thornwall(engine: RefCounted, expect: Callable) -> void:
	var grow: Dictionary = intent("briar_weaver", "thornwall")["actions"][0]
	for delta: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var state: Dictionary = fixture(engine)
		state["enemies"][0]["pos"] = FIXTURE_HERO - delta * 3
		state["enemies"][0]["intent"] = intent("briar_weaver", "thornwall")
		var front: Vector2i = FIXTURE_HERO - delta
		var axis := Vector2i.DOWN if delta.y == 0 else Vector2i.RIGHT
		var expected: Array[Vector2i] = engine._vector2i_values([front - axis, front, front + axis])
		expect.call(Bramble.tiles(engine, state, state["enemies"][0]) == expected, "Thornwall front/perpendicular for %s" % delta)
		expect.call(engine.enemy_threat_tiles(state, 0)["projected_attack"] == expected, "Thornwall real projected tiles for %s" % delta)
		var after: Dictionary = engine._resolve_enemy_action(state.duplicate(true), 0, grow)
		for tile: Vector2i in expected: expect.call(engine._terrain_index_at_tile(after, tile) >= 0, "Telegraphed tile grows immediately")
	var state: Dictionary = fixture(engine)
	state["grid"][4][4] = "pillar"
	state["enemies"].append(enemy(2, Vector2i(5, 4)))
	state["terrain"].append({"id": "box", "kind": "wooden_box", "pos": Vector2i(6, 4), "hp": 3})
	expect.call(Bramble.tiles(engine, state, state["enemies"][0]).is_empty(), "Thornwall skips occupied, terrain and impassable tiles")
	state = fixture(engine)
	state["player"]["pos"] = Vector2i(0, 0)
	state["enemies"][0]["pos"] = Vector2i(0, -3)
	expect.call(Bramble.tiles(engine, state, state["enemies"][0]).is_empty(), "Off-board and wall line clips safely")
	state = fixture(engine)
	state["illusions"] = [{"id": 7, "pos": Vector2i(4, 4), "hp": 2}]
	expect.call(not Bramble.tiles(engine, state, state["enemies"][0]).has(Vector2i(4, 4)), "Thornwall skips living illusion")

static func _collision_and_lifetime(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = fixture(engine)
	state["terrain"].append(terrain(Vector2i(6, 5)))
	expect.call(engine.combat_line_of_sight(state, Vector2i(5, 5), Vector2i(7, 5)), "Bramble does not block sight")
	expect.call(not engine.player_movement_targets(state).has(Vector2i(6, 5)), "Bramble blocks voluntary movement")
	expect.call(not Bramble.attackable(state["terrain"][0]) and not Surfaces.can_place(state, Vector2i(6, 5)), "Bramble has no attack durability and occupies terrain")
	var after: Dictionary = engine._force_move_actor(state.duplicate(true), "player", -1, Vector2i.RIGHT, 3, {}, true)
	expect.call(after["player"]["pos"] == FIXTURE_HERO and int(after["player"]["hp"]) == 48 and int(after["player"].get("bleed", 0)) == 1, "Bramble hero push: 2 damage, Bleed 1, no movement")
	expect.call(after["terrain"] == state["terrain"], "Push collision preserves Bramble and lifetime")
	state["enemies"].append(enemy(2, Vector2i(7, 5)))
	after = engine._force_move_actor(state.duplicate(true), "enemy", 2, Vector2i.LEFT, 2, {}, true)
	expect.call(int(after["enemies"][1]["hp"]) == 18 and int(after["enemies"][1].get("bleed", 0)) == 1 and after["enemies"][1]["pos"] == Vector2i(7, 5), "Bramble enemy push has same damage, Bleed and stop")
	state["player"]["block"] = 2
	after = engine._force_move_actor(state.duplicate(true), "player", -1, Vector2i.RIGHT, 1, {}, true)
	expect.call(int(after["player"]["hp"]) == 50 and int(after["player"].get("bleed", 0)) == 1, "Existing defense absorbs collision damage; Bleed remains")
	state = fixture(engine)
	state["enemies"][0]["intent"] = intent("briar_weaver", "thornwall")
	after = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	expect.call(after["terrain"].size() == 3 and int(after["terrain"][0]["rounds_left"]) == 2, "Grow turn consumes first terrain boundary")
	var steps: Array[Dictionary]
	Bramble.end_turn(after, steps)
	expect.call(after["terrain"].size() == 3 and int(after["terrain"][0]["rounds_left"]) == 1, "Bramble remains at second boundary")
	Bramble.end_turn(after, steps)
	expect.call(after["terrain"].is_empty() and str(steps.back()["en04_mechanic"]) == "bramble_expiry", "Third boundary removes Bramble and supplies sink animation")
	state = fixture(engine, "gale_herald")
	state["terrain"].append(terrain(Vector2i(6, 5), 1))
	state["wind"] = {"direction": Vector2i.RIGHT, "rounds_left": 1, "source_id": 1, "push": 1}
	var forecast: Dictionary = Wind.preview(engine, state, state["wind"])
	after = Bramble.complete_turn(engine, state.duplicate(true), steps)
	expect.call(after["player"] == forecast["state"]["player"] and int(after["player"]["hp"]) == 48 and int(after["player"].get("bleed", 0)) == 1, "Last-round Bramble collides with wind before expiry; preview agrees")
	expect.call(after["terrain"].is_empty(), "Terrain expires after wind")
	state = fixture(engine)
	state["enemies"][0]["freeze"] = 1
	state["terrain"].append(terrain(Vector2i(6, 5), 1))
	expect.call(engine.resolve_enemy_turn_with_steps(state, 0)["state"]["terrain"].is_empty(), "Frozen turns still expire terrain")

static func _mend(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = fixture(engine)
	var mend: Dictionary = intent("briar_weaver", "root_mend")["actions"][0]
	state["enemies"].append(enemy(2, Vector2i(6, 2)))
	state["enemies"].append(enemy(3, Vector2i(5, 4)))
	state["enemies"].append(enemy(4, Vector2i(9, 9)))
	state["enemies"][0]["hp"] = 1
	state["enemies"][1]["hp"] = 18
	state["enemies"][2]["hp"] = 10
	state["enemies"][3]["hp"] = 1
	expect.call(engine._enemy_support_target_index(state, 0, mend) == 2, "Root Mend chooses most wounded living other ally within 3")
	var after: Dictionary = engine._resolve_enemy_action(state, 0, mend)
	expect.call(int(after["enemies"][2]["hp"]) == 14 and int(after["enemies"][0]["hp"]) == 1, "Root Mend restores four to ally; never self")
	after["enemies"][2]["hp"] = 20
	after = engine._resolve_enemy_action(after, 0, mend)
	expect.call(int(after["enemies"][1]["hp"]) == 20, "Root Mend caps at max HP")
	state = fixture(engine)
	state["enemies"][0]["intent"] = intent("briar_weaver", "root_mend")
	expect.call(Bramble.effective_intent(engine, state, state["enemies"][0], state["enemies"][0]["intent"])["id"] == "lash_of_thorns", "Missing wounded ally falls back to Lash")
	after = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	expect.call(int(after["player"]["hp"]) == 47 and int(after["player"].get("bleed", 0)) == 1, "Held Root Mend executes Lash fallback with exact damage/Bleed")

static func _lob(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = fixture(engine, "slag_mortar")
	state["enemies"][0]["intent"] = intent("slag_mortar", "lob_slag")
	var marked: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	var expected: Array[Vector2i] = engine._vector2i_values([FIXTURE_HERO, FIXTURE_HERO + Vector2i.UP, FIXTURE_HERO + Vector2i.RIGHT, FIXTURE_HERO + Vector2i.DOWN, FIXTURE_HERO + Vector2i.LEFT])
	expect.call(marked["enemies"][0]["lob_tiles"] == expected and marked["enemies"][0]["lob_center"] == FIXTURE_HERO, "Lob snapshots centre plus board orthogonals")
	expect.call(marked["enemies"][0]["intent"]["id"] == "slag_lands", "next_intent forces zero-weight landing")
	expect.call(engine.enemy_threat_tiles(marked, 0)["projected_attack"] == expected, "Held landing threat equals marked tiles")
	marked["player"]["pos"] = Vector2i(2, 6)
	marked["enemies"].append(enemy(2, FIXTURE_HERO))
	marked["enemies"].append(enemy(3, FIXTURE_HERO + Vector2i.LEFT))
	marked["enemies"].append(enemy(4, FIXTURE_HERO + Vector2i.RIGHT, 2))
	var land: Dictionary = intent("slag_mortar", "slag_lands")["actions"][0]
	var after: Dictionary = engine._resolve_enemy_action(marked.duplicate(true), 0, land)
	expect.call(int(after["enemies"][1]["hp"]) == 15 and int(after["enemies"][2]["hp"]) == 17 and int(after["enemies"][3]["hp"]) == 0, "Centre takes 5, arms 3, enemies included")
	for tile: Vector2i in expected: expect.call(Surfaces.element_at(after, tile) == "fire", "Each marked tile becomes Fire")
	expect.call(not after["enemies"][0].has("lob_tiles") and not after["enemies"][0].has("lob_center"), "Landing clears held mark state")
	expect.call(int(after.get("death_bonus_card_plays_this_turn", 0)) == 0 and int(after["room_embers"]) == int(Data.enemy_def("crawler")["reward_embers"]), "Friendly-fire kill preserves Ember policy and grants no card-play bonus")
	state = fixture(engine, "slag_mortar")
	state["enemies"][0]["lob_tiles"] = expected
	state["enemies"][0]["lob_center"] = FIXTURE_HERO
	after = engine._resolve_enemy_action(state.duplicate(true), 0, land)
	expect.call(int(after["player"]["hp"]) == 45, "Hero centre takes five at landing; surface arrival is separate")
	state["player"]["pos"] = FIXTURE_HERO + Vector2i.DOWN
	after = engine._resolve_enemy_action(state.duplicate(true), 0, land)
	expect.call(int(after["player"]["hp"]) == 47, "Hero on arm takes three")
	state["player"]["pos"] = Vector2i(0, 0)
	var clipped: Array[Vector2i] = Lob.tiles(engine, state, state["enemies"][0], intent("slag_mortar", "lob_slag")["actions"][0])
	expect.call(clipped == engine._vector2i_values([Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN]), "Lob plus clips off-board only")
	state["player"]["pos"] = FIXTURE_HERO
	state["grid"][4][5] = "pillar"
	expect.call(Lob.tiles(engine, state, state["enemies"][0], intent("slag_mortar", "lob_slag")["actions"][0]).has(Vector2i(5, 4)), "Marks include in-board impassable cells; LOS ignored")
	state["enemies"][0]["intent"] = intent("slag_mortar", "lob_slag")
	expect.call(engine.enemy_intent_plan(state, 0)["attack_available"], "Lob ignores intervening pillar LOS")

static func _gating(engine: RefCounted, expect: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = FIXTURE_SEED
	for distance: int in [1, 2, 3, 6, 7]:
		var state: Dictionary = fixture(engine, "slag_mortar")
		state["enemies"][0]["pos"] = Vector2i(1, 2)
		state["player"]["pos"] = Vector2i(1 + distance, 2)
		expect.call(Lob.available(engine, state, state["enemies"][0], intent("slag_mortar", "lob_slag")) == (distance >= 3 and distance <= 6), "Lob legal distance %d" % distance)
		expect.call(Lob.available(engine, state, state["enemies"][0], intent("slag_mortar", "scatter_shot")) == (distance <= 2), "Scatter gating distance %d" % distance)
		for iteration: int in range(AI_ROLL_COUNT):
			state["enemies"][0]["intent"] = {}
			engine._assign_enemy_intent(state, 0, rng)
			var id: String = state["enemies"][0]["intent"]["id"]
			expect.call(id == "brace" or (id == "lob_slag" and distance >= 3 and distance <= 6) or (id == "scatter_shot" and distance <= 2), "Seeded AI never rolls impossible Lob, Scatter or zero-weight landing")
	var state: Dictionary = fixture(engine)
	state["enemies"][0]["intent"] = {}
	for iteration: int in range(AI_ROLL_COUNT):
		engine._assign_enemy_intent(state, 0, rng)
		expect.call(state["enemies"][0]["intent"]["id"] != "root_mend", "No wounded ally excludes random Root Mend")
	state = fixture(engine, "slag_mortar")
	state["enemies"][0]["intent"] = intent("slag_mortar", "lob_slag")
	state = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	state["enemies"][0]["shock"] = 1
	state = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	expect.call(state["enemies"][0]["intent"]["id"] == "slag_lands" and state["enemies"][0].has("lob_tiles"), "Shock skip preserves marks and forced landing")
	state["enemies"][0]["freeze"] = 1
	state = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	expect.call(state["enemies"][0]["intent"]["id"] == "slag_lands" and state["enemies"][0].has("lob_tiles"), "Freeze skip also preserves forced landing")

static func _save(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = fixture(engine, "slag_mortar")
	state["enemies"][0]["intent"] = intent("slag_mortar", "lob_slag")
	state = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	state["terrain"].append(terrain(Vector2i(3, 4), 2))
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_var({"combat_state": state})
	file.close()
	var loaded: Dictionary = Store._load_run_dictionary(SAVE_PATH)["combat_state"]
	expect.call(loaded == state, "Production save decoder round-trips mid-mark and terrain lifetime")
	expect.call(engine.resolve_enemy_turn_with_steps(state, 0)["state"] == engine.resolve_enemy_turn_with_steps(loaded, 0)["state"], "Resumed landing is byte-equivalent Variant state")
	state = fixture(engine)
	file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_var({"combat_state": state})
	file.close()
	expect.call(Store._load_run_dictionary(SAVE_PATH)["combat_state"] == state, "Old saves without mechanic fields load unchanged")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

static func _presentation(engine: RefCounted, expect: Callable) -> void:
	expect.call(Icons.action_icon_key({"type": "grow_bramble"}) == "bramble" and Icons.action_icon_key({"type": "lob_mark"}) == "lob" and Icons.action_icon_key({"type": "lob_land"}) == "lob", "Intent and terrain/mark share concept identities")
	expect.call(BrambleView.tooltip(terrain(Vector2i(6, 5), 2)) == "Bramble\nBlocks movement, not sight, for 3 enemy turns. A unit forced into it takes 2 damage and Bleed 1.\n2 turns left", "Exact Bramble tooltip with remaining lifetime")
	var state: Dictionary = fixture(engine, "slag_mortar")
	state["enemies"][0]["intent"] = intent("slag_mortar", "lob_slag")
	state = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	var board: Control = Board.new()
	board.combat_state = state
	var marks: Dictionary = LobView.marks(board)
	expect.call(marks.size() == 5 and int(marks[FIXTURE_HERO]["damage"]) == 5 and int(marks[FIXTURE_HERO + Vector2i.LEFT]["damage"]) == 3, "At-rest medallions expose real centre/arm values")
	expect.call(LobView.mark_tooltip(state["enemies"][0], FIXTURE_HERO, 5, FIXTURE_HERO) == "Lob Slag\nMarks your tile and the 4 around it. On its next turn, they take the shown damage and become Fire.\n5 damage.\nYou are standing on it.", "Exact Lob delayed tooltip and standing warning")
	expect.call(Compass.descriptor_for_enemy(state["enemies"][0]["intent"])["value"] == 5, "Landing compass exposes centre damage")
	expect.call(Compass.descriptor_for_enemy(intent("briar_weaver", "thornwall"))["family"] == Compass.FAMILY_SUPPORT, "Thornwall compass is terrain support")
	expect.call(LobView.arc_point(Vector2.ZERO, Vector2(100, 0), 50, 0.5) == Vector2(50, -110), "Arc apex is exactly 2.2 tiles over midpoint")
	board.free()

static func _integration_boundaries(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = fixture(engine)
	state["enemies"][0]["intent"] = intent("briar_weaver", "root_mend")
	var compass: Dictionary = Compass.descriptors_for_state(state)
	expect.call(compass["enemy_1"]["action_type"] == "ranged" and int(compass["enemy_1"]["value"]) == 3, "Live Root Mend fallback compass matches Lash")
	var board: Control = Board.new()
	board.combat_state = state
	for unit: Dictionary in board._visible_units():
		if unit.get("key") == "enemy_1": expect.call(unit["intent"]["id"] == "lash_of_thorns", "Visible intent model adopts live fallback name and actions")
	var threats: Dictionary = engine.enemy_threat_tiles(state, 0)
	expect.call(threats["projected_attack_action"]["type"] == "ranged" and (threats["projected_attack"] as Array).has(FIXTURE_HERO), "Fallback threat reflects actual Lash outcome")
	board.free()
	var badges = preload("res://scripts/intent_badges.gd")
	expect.call(badges.is_attack(intent("briar_weaver", "thornwall")["actions"][0]), "Thornwall telegraphs terrain tiles in threats-at-rest")
	expect.call(badges.descriptor(intent("slag_mortar", "slag_lands")["actions"][0])["number"] == "5", "Lob at-rest chip shows landing damage")
	state["enemies"].append(enemy(2, Vector2i(6, 2)))
	state["enemies"].append(enemy(3, Vector2i(5, 4)))
	state["enemies"][1]["hp"] = 18
	state["enemies"][2]["hp"] = 18
	expect.call(engine._enemy_support_target_index(state, 0, intent("briar_weaver", "root_mend")["actions"][0]) == 1, "Equal missing HP uses existing nearest support tie-break")
	state["enemies"][1]["hp"] = 0
	expect.call(engine._enemy_support_target_index(state, 0, intent("briar_weaver", "root_mend")["actions"][0]) == 2, "Mend excludes defeated allies")
	state = fixture(engine, "gale_herald")
	state["terrain"].append(terrain(Vector2i(6, 5), 2))
	state["enemies"].append(enemy(2, Vector2i(7, 5), 1))
	state["damage_context"] = {"actor_kind": "enemy", "actor_id": 1, "player_card": false}
	var after: Dictionary = engine._force_move_actor(state.duplicate(true), "enemy", 2, Vector2i.LEFT, 1, {}, true)
	expect.call(int(after["enemies"][1]["hp"]) == 0 and after["terrain"].size() == 1, "Enemy-caused Bramble collision kills without destroying terrain")
	expect.call(int(after.get("death_bonus_card_plays_this_turn", 0)) == 0 and int(after["room_embers"]) == int(Data.enemy_def("crawler")["reward_embers"]), "Bramble friendly-fire death preserves rewards without card credit")
	state = fixture(engine, "slag_mortar")
	var mark: Dictionary = intent("slag_mortar", "lob_slag")["actions"][0]
	var land: Dictionary = intent("slag_mortar", "slag_lands")["actions"][0]
	state = engine._resolve_enemy_action(state, 0, mark)
	state["player"]["pos"] = Vector2i(2, 6)
	state["enemies"].append(enemy(2, Vector2i(4, 5)))
	state["enemies"][1]["footprint"] = Vector2i(2, 2)
	after = engine._resolve_enemy_action(state.duplicate(true), 0, land)
	expect.call(int(after["enemies"][1]["hp"]) == 15, "Large actor intersecting centre/arms takes one highest-value hit")
	state["enemies"][0]["bleed"] = 1
	after = engine._resolve_enemy_action(state.duplicate(true), 0, land)
	expect.call(int(after["enemies"][0]["hp"]) == 17 and not after["enemies"][0].has("lob_tiles"), "Landing pays existing attack Bleed before firing")
	state["enemies"][0]["hp"] = 1
	after = engine._resolve_enemy_action(state.duplicate(true), 0, land)
	expect.call(int(after["enemies"][0]["hp"]) == 0 and int(after["enemies"][1]["hp"]) == 20 and Surfaces.tiles(after).is_empty(), "Bleed defeat cancels landing before damage or Fire")
	expect.call(Lob.animation_step(engine, state, after, 0, land).is_empty(), "Cancelled landing has no phantom arc/splash")
	for depth: int in [1, 2, 3, 6]:
		var scaled: Dictionary = engine._scale_enemy_action_for_depth(land, depth)
		var mark_state: Dictionary = fixture(engine, "slag_mortar")
		mark_state["room_depth"] = depth
		mark_state["enemies"][0]["intent"] = intent("slag_mortar", "lob_slag")
		expect.call(Compass.descriptors_for_state(mark_state)["enemy_1"]["value"] == scaled["center_damage"], "Mark compass follows real landing damage at depth %d" % depth)
		var ordinary: Dictionary = engine._scale_enemy_action_for_depth({"type": "ranged", "damage": 5, "range": 3}, depth)
		expect.call(int(scaled["center_damage"]) == int(ordinary["damage"]) and int(scaled["arm_damage"]) == int(ordinary["damage"]) - 2, "Lob follows existing local/sequence damage curve at depth %d" % depth)
	state = fixture(engine, "slag_mortar")
	state["room_element"] = "fire"
	state["enemies"][0]["intent"] = intent("slag_mortar", "brace")
	after = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	expect.call(int(after["enemies"][0]["block"]) == 6 and absi(after["enemies"][0]["pos"].x - FIXTURE_SOURCE.x) + absi(after["enemies"][0]["pos"].y - FIXTURE_SOURCE.y) <= 2 and absi(after["enemies"][0]["pos"].x - FIXTURE_HERO.x) + absi(after["enemies"][0]["pos"].y - FIXTURE_HERO.y) > 3, "Brace grants six Block and retreats within two, bounded by board")
	state["enemies"][0]["pos"] = Vector2i(5, 3)
	state["enemies"][0]["intent"] = intent("slag_mortar", "scatter_shot")
	after = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	expect.call(int(after["player"]["hp"]) == 47 and after["player"]["pos"] == Vector2i(5, 6), "Elemental-room Scatter deals three and pushes one")

static func _bramble_paint(expect: Callable) -> void:
	var board: Control = Board.new()
	board.size = Vector2(960, 680) # Existing headless board-consumer fixture size.
	board._load_assets(false)
	var texture: Texture2D = board._terrain_textures.get("bramble", null)
	expect.call(texture != null and Assets.load_texture(BrambleView.PROP_PATH) != null, "Approved thicket loads in the ordinary terrain texture registry")
	if texture == null:
		board.free()
		return
	var tile := Vector2i(5, 4)
	var full: Rect2 = board._terrain_rect_for_tile(tile, texture, "bramble")
	var crate: Texture2D = board._terrain_textures["wooden_crate"]
	var crate_rect: Rect2 = board._terrain_rect_for_tile(tile, crate, "wooden_crate")
	var crate_bounds: Rect2i = board._texture_used_rect(crate)
	var crate_visible_height: float = crate_rect.size.y * float(crate_bounds.size.y) / crate.get_height()
	var outcrop: Rect2 = board._terrain_rect_for_tile(tile, board._terrain_textures["crag_outcrop"], "crag_outcrop")
	expect.call(is_equal_approx(full.size.y / crate_visible_height, 1.1), "Thicket visible height is 1.1 times the existing crate")
	expect.call(full.size.x <= outcrop.size.x and is_equal_approx(full.size.aspect(), texture.get_size().aspect()), "Thicket preserves approved paint aspect and fits the one-tile outcrop footprint")
	expect.call(is_equal_approx(full.end.y, crate_rect.position.y + crate_rect.size.y * float(crate_bounds.end.y) / crate.get_height()), "Thicket base matches the crate's visible ground baseline")
	expect.call(absf((full.size.x / texture.get_width()) / board.protagonist_source_pixel_scale() - 1.0) < 0.01, "Thicket source pixels match hero density within native rounding")
	expect.call(is_equal_approx(BrambleView.BRAMBLE_HEIGHT_TILES, 0.6), "Director's 0.6 rise reference is retained")
	var grow: Dictionary = {"en04_mechanic": "grow_bramble", "tiles": [tile]}
	var expired: Array[Dictionary]
	expired.append(terrain(tile, 0))
	var expiry: Dictionary = {"en04_mechanic": "bramble_expiry", "expired_bramble": expired}
	for progress: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		for expiring: bool in [false, true]:
			var step: Dictionary = expiry if expiring else grow
			board.presentation = BrambleView.presentation_for_step(step, progress)
			var rect: Rect2 = board._terrain_rect_for_tile(tile, texture, "bramble")
			var scale: float = 1.0 - pow(progress, 3.0) if expiring else 1.0 - pow(1.0 - progress, 3.0)
			expect.call(is_equal_approx(rect.end.y, full.end.y) and is_equal_approx(rect.size.x, full.size.x), "Growth and expiry retain the full width and planted base")
			expect.call(is_equal_approx(rect.size.y, full.size.y * scale), "Grow uses ease-out cubic; expiry is its time reverse")
			if expiring: expect.call((board.presentation.get("terrain_destruction_units", []) as Array).size() == 1, "Expiry draws as a depth-sorted terrain ghost, not an effects overlay")
	board.presentation = BrambleView.presentation_for_step(grow, 0.5, true)
	expect.call(board._terrain_rect_for_tile(tile, texture, "bramble").is_equal_approx(full), "Reduced motion grows instantly")
	board.presentation = BrambleView.presentation_for_step(expiry, 0.5, true)
	expect.call(board._terrain_rect_for_tile(tile, texture, "bramble").size.y == 0.0 and not board.presentation.has("terrain_destruction_units"), "Reduced motion expires instantly without a ghost")
	expect.call(BrambleView.fleck_records(Vector2.ZERO, full.size.x, 0.6, 0.5).size() == 3, "Transition has exactly three small dust/leaf flecks")
	expect.call(BrambleView.fleck_records(Vector2.ZERO, full.size.x, 0.6, 0.0).is_empty() and BrambleView.fleck_records(Vector2.ZERO, full.size.x, 0.6, 1.0).is_empty(), "Dust/leaf flecks do not remain at rest")
	board.free()

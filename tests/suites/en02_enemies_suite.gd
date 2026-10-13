extends RefCounted

const EngineScript = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Icefall = preload("res://scripts/enemy_mechanics/icefall.gd")
const Wind = preload("res://scripts/enemy_mechanics/wind.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Store = preload("res://scripts/progression_store.gd")
const SceneScript = preload("res://scripts/run_scene.gd")
const BoardScript = preload("res://scripts/combat_board_view.gd")
const Compass = preload("res://scripts/enemy_intent_compass.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const IcefallView = preload("res://scripts/enemy_mechanics/icefall_view.gd")
const WindView = preload("res://scripts/enemy_mechanics/wind_view.gd")
const FIXTURE_SEED: int = 20261012
const FIXTURE_BOARD_SIZE: int = 11
const FIXTURE_PLAYER_POSITION := Vector2i(5, 5)
const FIXTURE_ENEMY_POSITION := Vector2i(5, 2)
const FIXTURE_PLAYER_HP: int = 50
const FIXTURE_HELPER_HP: int = 20
const CONSTRUCT_FIXTURE_ID: String = "en02_construct_fixture"
const SAVE_PATH: String = "user://en02_roundtrip.save"

static func fixture(engine: RefCounted, type: String = "hoarfrost_seer") -> Dictionary:
	var grid: Array
	for y: int in range(FIXTURE_BOARD_SIZE):
		var row: Array[String]
		for x: int in range(FIXTURE_BOARD_SIZE): row.append("wall" if x == 0 or x == FIXTURE_BOARD_SIZE - 1 or y == 0 or y == FIXTURE_BOARD_SIZE - 1 else "stone")
		grid.append(row)
	var definition: Dictionary = Data.enemy_def(type)
	var room: Dictionary = {"name": "En02 Proof", "coord": Vector2i(1, 0), "depth": 2, "type": "combat", "grid": grid, "player_start": FIXTURE_PLAYER_POSITION, "enemies": [{"id": 1, "type": type, "pos": FIXTURE_ENEMY_POSITION, "hp": definition["max_hp"], "max_hp": definition["max_hp"]}], "terrain": [], "traps": [], "loot": []}
	var state: Dictionary = engine.create_combat(FIXTURE_SEED, room, {"hp": FIXTURE_PLAYER_HP, "max_hp": FIXTURE_PLAYER_HP, "deck_cards": ["quick_stab", "brace"], "skill_ids": [], "relics": [], "hand_size": 1})
	state.erase("umbra")
	return state

static func intent(type: String, id: String) -> Dictionary:
	for entry: Dictionary in Data.enemy_def(type)["intents"]:
		if str(entry["id"]) == id: return entry.duplicate(true)
	return {}

static func enemy(id: int, pos: Vector2i, hp: int = FIXTURE_HELPER_HP, type: String = "crawler") -> Dictionary:
	return {"id": id, "type": type, "pos": pos, "hp": hp, "max_hp": hp, "block": 0, "stoneskin": 0, "intent": intent(type, "claw")}

static func run(expect: Callable) -> void:
	var engine: RefCounted = EngineScript.new()
	_schema(engine, expect)
	_icefall(engine, expect)
	_wind(engine, expect)
	_persistence(engine, expect)
	_presentation(engine, expect)
	_additional_boundaries(engine, expect)
	_director_feedback(engine, expect)

static func _schema(engine: RefCounted, expect: Callable) -> void:
	var staged: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://spec/peer_benchmark/staged/enemies/wave_e1.json"))
	var production: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	for type: String in ["hoarfrost_seer", "gale_herald"]:
		expect.call(production[type] == staged[type], "%s director-owned entry is verbatim" % type)
		var definition: Dictionary = Data.enemy_def(type)
		for field: String in ["name", "max_hp", "base_initiative", "reward_embers", "accent", "art_path", "intents"]:
			expect.call(definition.has(field), "%s schema field %s" % [type, field])
		var ids: Dictionary = {}
		for entry: Dictionary in definition["intents"]:
			expect.call(not ids.has(entry["id"]) and not str(entry["name"]).is_empty() and int(entry["time"]) > 0 and int(entry["weight"]) >= 0, "%s intent schema %s" % [type, entry["id"]])
			ids[entry["id"]] = true
			for action: Dictionary in entry["actions"]:
				expect.call(str(action["type"]) in ["icefall_mark", "icefall_land", "call_wind", "ranged", "move_away", "block"], "Supported en-02 verb")
			expect.call(Assets.load_texture(definition["art_path"]) != null, "%s loads static fallback" % type)
		var portrait_path: String = SceneScript.TURN_ORDER_PORTRAITS.get(type, "")
		expect.call(portrait_path == "res://assets/art/portraits/%s.png" % type and Assets.load_texture(portrait_path) != null, "%s explicit turn-clock portrait" % type)
		var state: Dictionary = fixture(engine, type)
		var found: bool = false
		for actor: Dictionary in engine.current_turn_order(state):
			if str(actor.get("type", actor.get("enemy_type", ""))) == type or str(actor.get("key", "")) == "enemy_1": found = true
		expect.call(found, "%s present in initiative queue" % type)
	for icon: String in ["icefall", "wind"]: expect.call(Icons.icon_texture(icon) != null, "%s approved concept icon loads" % icon)

static func _icefall(engine: RefCounted, expect: Callable) -> void:
	var mark: Dictionary = intent("hoarfrost_seer", "icefall")["actions"][0]
	var land: Dictionary = intent("hoarfrost_seer", "icefall_land")["actions"][0]
	for delta: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var state: Dictionary = fixture(engine)
		state["enemies"][0]["pos"] = Vector2i(5, 5) - delta * 2
		var actual: Array[Vector2i] = Icefall.tiles(engine, state, state["enemies"][0], mark)
		var axis: Vector2i = Vector2i(0, 1) if delta.y == 0 else Vector2i(1, 0)
		expect.call(actual == engine._vector2i_values([Vector2i(5, 5) - axis, Vector2i(5, 5), Vector2i(5, 5) + axis]), "Icefall perpendicular shape for %s" % delta)
	var state: Dictionary = fixture(engine)
	state["player"]["pos"] = Vector2i(1, 1)
	state["enemies"][0]["pos"] = Vector2i(1, 3)
	state["grid"][1][2] = "pillar"
	expect.call(Icefall.tiles(engine, state, state["enemies"][0], mark) == engine._vector2i_values([Vector2i(1, 1)]), "Icefall skips offboard/wall/pillar")
	state = fixture(engine)
	state["enemies"][0]["intent"] = intent("hoarfrost_seer", "icefall")
	var marked: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	expect.call(str(marked["enemies"][0]["intent"]["id"]) == "icefall_land", "Icefall forces its zero-weight following intent")
	var tiles: Array[Vector2i] = engine._vector2i_values(marked["enemies"][0]["icefall_tiles"])
	expect.call(engine.enemy_threat_tiles(marked, 0)["projected_attack"] == tiles, "Held marks are actual threat tiles")
	marked["player"]["pos"] = Vector2i(2, 6)
	marked["enemies"].append(enemy(2, Vector2i(4, 5), 4))
	marked["enemies"].append(enemy(3, Vector2i(6, 5)))
	var landed: Dictionary = engine.resolve_enemy_turn_with_steps(marked, 0)["state"]
	expect.call(int(landed["enemies"][1]["hp"]) == 0 and int(landed["enemies"][2]["hp"]) == 15, "Icefall hits any enemy on its fixed marked tile")
	expect.call(int(landed.get("death_bonus_card_plays_this_turn", 0)) == 0, "Enemy kill never grants a card-play bonus")
	expect.call(int(landed["room_embers"]) == int(Data.enemy_def("crawler")["reward_embers"]), "Enemy kill preserves existing Ember rules")
	expect.call(engine._terrain_index_at_tile(landed, Vector2i(4, 5)) >= 0 and engine._terrain_index_at_tile(landed, Vector2i(5, 5)) >= 0 and engine._terrain_index_at_tile(landed, Vector2i(6, 5)) < 0, "Pillars appear only on tiles unoccupied after damage")
	expect.call(not engine.combat_line_of_sight(landed, Vector2i(4, 4), Vector2i(4, 6)), "Ice Pillar blocks line of sight")
	var pillar_index: int = engine._terrain_index_at_tile(landed, Vector2i(4, 5))
	expect.call(int(landed["terrain"][pillar_index]["rounds_left"]) == 2, "Pillar counts down at the end of the landing turn")
	Icefall.end_turn(landed)
	expect.call(engine._terrain_index_at_tile(landed, Vector2i(4, 5)) >= 0, "Pillar remains for the second turn boundary")
	Icefall.end_turn(landed)
	expect.call(engine._terrain_index_at_tile(landed, Vector2i(4, 5)) < 0 and engine.combat_line_of_sight(landed, Vector2i(4, 4), Vector2i(4, 6)), "Third turn boundary expires the pillar and clears sight")
	state = fixture(engine)
	state["enemies"][0]["icefall_tiles"] = engine._vector2i_values([Vector2i(5, 5)])
	var hero_hit: Dictionary = engine._resolve_enemy_action(state, 0, land)
	expect.call(int(hero_hit["player"]["hp"]) == 45 and engine._terrain_index_at_tile(hero_hit, Vector2i(5, 5)) < 0, "Living hero takes five and receives no pillar underneath")
	hero_hit["terrain"] = [{"id": "proof_pillar", "kind": "ice_pillar", "pos": Vector2i(6, 5), "rounds_left": 3, "shatter_damage": 2, "blocks_sight": true}]
	var shattered: Dictionary = engine._force_move_actor(hero_hit, "player", -1, Vector2i(1, 0), 3, {}, true)
	expect.call(int(shattered["player"]["hp"]) == 43 and engine._terrain_index_at_tile(shattered, Vector2i(6, 5)) < 0 and shattered["player"]["pos"] == Vector2i(5, 5), "Pillar collision takes exactly two, shatters, and stops the push")
	var rng := RandomNumberGenerator.new()
	rng.seed = FIXTURE_SEED
	for iteration: int in range(50):
		state = fixture(engine)
		state["enemies"][0]["pos"] = Vector2i(1, 1)
		state["enemies"][0]["intent"] = {}
		engine._assign_enemy_intent(state, 0, rng)
		expect.call(str(state["enemies"][0]["intent"]["id"]) == "withdraw", "Out-of-range Seer falls back to Withdraw, never random weight-zero landing")

static func _wind(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = fixture(engine, "gale_herald")
	state["enemies"][0]["pos"] = Vector2i(8, 8)
	expect.call(Wind.direction(engine, state, state["enemies"][0]) == Vector2i(1, 0), "No hazards within scan chooses toward Herald (existing cardinal axis)")
	Surfaces.place(state, Vector2i(4, 5), "fire")
	expect.call(Wind.direction(engine, state, state["enemies"][0]) == Vector2i(-1, 0), "Nearest damaging surface determines wind")
	state["enemies"].append(enemy(2, Vector2i(6, 5)))
	expect.call(Wind.direction(engine, state, state["enemies"][0]) == Vector2i(1, 0), "Equal nearest hazards choose direction toward Herald")
	state = fixture(engine, "gale_herald")
	state["grid"][5][4] = "pillar"
	expect.call(Wind.direction(engine, state, state["enemies"][0]) == Vector2i(-1, 0), "Impassable pillar is a wind hazard")
	state = fixture(engine, "gale_herald")
	state["traps"] = [{"id": 1, "pos": Vector2i(5, 6), "damage": 2, "element": "fire", "armed": true}]
	expect.call(Wind.direction(engine, state, state["enemies"][0]) == Vector2i(0, 1), "Trap is a wind hazard")
	state = fixture(engine, "gale_herald")
	state["wind"] = {"direction": Vector2i(1, 0), "rounds_left": 2, "source_id": 1, "push": 1}
	state["enemies"].append(enemy(2, Vector2i(6, 5)))
	state["enemies"].append(enemy(3, Vector2i(7, 5)))
	var forecast: Dictionary = Wind.preview(engine, state, state["wind"])
	var steps: Array[Dictionary]
	var after: Dictionary = Wind.end_turn(engine, state.duplicate(true), steps)
	expect.call(after["player"]["pos"] == Vector2i(6, 5) and after["enemies"][1]["pos"] == Vector2i(7, 5) and after["enemies"][2]["pos"] == Vector2i(8, 5), "Downwind-first ordering opens a packed line without collision")
	expect.call(after["enemies"][0]["pos"] == state["enemies"][0]["pos"], "Herald itself is anchored")
	expect.call(forecast["state"]["player"] == after["player"] and forecast["state"]["enemies"] == after["enemies"], "Wind preview equals actual push resolution")
	expect.call(int(after["wind"]["rounds_left"]) == 1 and int(state["wind"]["rounds_left"]) == 2, "Wind uses one round per enemy turn and preview is pure")
	after = Wind.end_turn(engine, after, steps)
	expect.call(not after.has("wind"), "Two turns exhaust wind")
	state["player"]["pos"] = Vector2i(9, 5)
	forecast = Wind.preview(engine, state, state["wind"])
	after = Wind.end_turn(engine, state.duplicate(true), steps)
	expect.call(int(after["player"]["hp"]) == 48 and forecast["collision_markers"].size() == 1 and int(forecast["collision_markers"][0]["damage"]) == 2, "Wind wall collision uses normal damage and preview marker")
	expect.call(Wind.anchored(state, "enemy", {"type": "zekarion", "hp": 20}) and not Wind.anchored(state, "enemy", {"type": "crawler", "construct": true}) and Wind.anchored(state, "enemy", {"type": "crawler", "anchored": true}), "Bosses and Anchored resist wind; a runtime-only construct flag does not classify an enemy")
	expect.call(Wind.anchored(state, "enemy", {"type": "storm_cantor"}) and not Wind.anchored(state, "enemy", {"type": "roc_fledgling"}) and not Wind.anchored(state, "enemy", {"type": "rime_whelp"}), "Guardian leaders resist wind but their cycle-driven helpers remain pushable")
	state["player"]["anchored"] = true
	expect.call(Wind.anchored(state, "player", state["player"]), "Explicit anchored hero resists wind")
	state = fixture(engine, "gale_herald")
	state["enemies"][0]["intent"] = intent("gale_herald", "call_the_wind")
	var turn: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0)
	after = turn["state"]
	expect.call(int(after["wind"]["rounds_left"]) == 1, "Call's own enemy-turn boundary pushes and spends first round")
	var death: Dictionary = engine._damage_enemy(after, 0, 100, false)
	expect.call(not death.has("wind"), "Killing the Herald immediately clears wind")
	state = fixture(engine, "gale_herald")
	state["wind"] = {"direction": Vector2i(1, 0), "rounds_left": 1, "source_id": 1}
	state = engine._resolve_enemy_action(state, 0, intent("gale_herald", "call_the_wind")["actions"][0])
	expect.call(int(state["wind"]["rounds_left"]) == 2, "A new Call refreshes wind")
	state["enemies"][0]["freeze"] = 1
	var skipped: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	expect.call(int(skipped["wind"]["rounds_left"]) == 1, "Frozen skipped turns still resolve end-of-turn wind")

static func _persistence(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = fixture(engine, "gale_herald")
	state["wind"] = {"direction": Vector2i(1, 0), "rounds_left": 2, "source_id": 1}
	state["enemies"][0]["icefall_tiles"] = engine._vector2i_values([Vector2i(2, 3), Vector2i(3, 3)])
	state["terrain"] = [{"id": "saved_ice", "kind": "ice_pillar", "pos": Vector2i(6, 5), "rounds_left": 2, "blocks_sight": true}]
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_var({"combat_state": state})
	file.close()
	var loaded: Dictionary = Store._load_run_dictionary(SAVE_PATH)["combat_state"]
	expect.call(loaded == state, "Production save decoder round-trips wind, marks and temporary terrain")
	var steps: Array[Dictionary]
	var loaded_steps: Array[Dictionary]
	expect.call(Wind.end_turn(engine, state, steps) == Wind.end_turn(engine, loaded, loaded_steps), "Resumed mid-wind resolution is identical")
	var old: Dictionary = fixture(engine)
	file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_var({"combat_state": old})
	file.close()
	expect.call(Store._load_run_dictionary(SAVE_PATH)["combat_state"] == old and not old.has("wind"), "Old saves load unchanged without new fields")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

static func _presentation(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = fixture(engine)
	state["enemies"][0]["intent"] = intent("hoarfrost_seer", "icefall")
	var descriptor: Dictionary = Compass.descriptor_for_enemy(state["enemies"][0]["intent"])
	expect.call(str(descriptor.get("family", "")) == Compass.FAMILY_ATTACK, "Icefall compass belongs to attack family")
	expect.call(IcefallView.FALL_SECONDS == 0.18, "Landing streak uses exact approved 0.18 seconds")
	var board: Control = BoardScript.new()
	board.combat_state = fixture(engine, "gale_herald")
	board.combat_state["enemies"][0]["intent"] = intent("gale_herald", "call_the_wind")
	var preview: Dictionary = WindView.forecast(board)
	expect.call(bool(preview["dashed"]) and not (preview["wind"] as Dictionary).is_empty(), "Call preview is dashed before wind exists")
	board.combat_state = engine._resolve_enemy_action(board.combat_state, 0, intent("gale_herald", "call_the_wind")["actions"][0])
	expect.call(not bool(WindView.forecast(board)["dashed"]), "Active wind uses solid chevrons")
	board.free()
	state = fixture(engine, "gale_herald")
	var original: Vector2i = state["enemies"][0]["pos"]
	state = engine._force_move_actor(state, "enemy", 1, Vector2i(1, 0), 2, {}, true)
	expect.call(state["enemies"][0]["pos"] == original and int(state["enemies"][0]["hp"]) == 14, "Herald's innate Anchored state also blocks ordinary pushes without collision")
	var push: Dictionary = {"type": "push", "amount": 2, "damage": 0, "range": 5}
	expect.call(not engine.valid_targets_for_player_action(state, push).has(original), "A zero-damage push cannot target an Anchored Herald")
	push["damage"] = 3
	state = engine.apply_player_action(state, push, original)
	expect.call(state["enemies"][0]["pos"] == original and int(state["enemies"][0]["hp"]) == 11, "An attack still damages the Herald while its push rider has zero distance")
	state = fixture(engine, "gale_herald")
	state["enemies"][0]["pos"] = Vector2i(7, 5)
	state["enemies"].append(enemy(2, Vector2i(6, 5)))
	state = engine.GuardianRelicRules.force_group(engine, state, 1, {"type": "push", "push": 1}, Vector2i(5, 5))
	expect.call(state["enemies"][0]["pos"] == Vector2i(7, 5) and state["enemies"][1]["pos"] == Vector2i(6, 5) and int(state["enemies"][0]["hp"]) == 12, "A carried enemy line collides with the Anchored Herald instead of carrying it")
	state = fixture(engine)
	state["terrain"] = [{"id": "aim_blocker", "kind": "ice_pillar", "pos": Vector2i(5, 3), "rounds_left": 3, "blocks_sight": true}]
	var bolt_plan: Dictionary = engine.enemy_intent_plan(state, 0, intent("hoarfrost_seer", "rime_bolt"))
	expect.call(not bool(bolt_plan["attack_available"]) and int(bolt_plan["blocking_terrain_index"]) == -1 and (bolt_plan["projected_attack"] as Array).is_empty(), "Untargetable terrain cannot become an impossible obstacle-clearing bolt")
	expect.call(not engine.valid_targets_for_player_action(state, {"type": "ranged", "damage": 3, "range": 5}).has(Vector2i(5, 3)), "Ice Pillar terrain cannot be targeted by a ranged attack")
	var scene: Control = SceneScript.new()
	scene.ui_root = Control.new()
	scene.add_child(scene.ui_root)
	scene._turn_order_panel = PanelContainer.new()
	scene.ui_root.add_child(scene._turn_order_panel)
	scene._combat_state = fixture(engine, "gale_herald")
	scene._combat_state["wind"] = {"direction": Vector2i(1, 0), "rounds_left": 2, "source_id": 1}
	scene._run_state = {"mode": "combat"}
	WindView.refresh_chip(scene)
	var chip: PanelContainer = scene.ui_root.get_node("En02WindChip")
	expect.call(chip.visible and chip.get_node("Contents/Title").text == "Wind · 2", "Wind HUD shows exact approved rounds text")
	expect.call((chip.get_node("Contents/Direction") as Control).custom_minimum_size == Vector2(12, 12) and chip.get_node("Contents/Direction").heading == WindView.screen_direction(Vector2i(1, 0)), "Wind HUD includes a 12-pixel screen-relative arrow")
	expect.call(chip.tooltip_text == "At the end of each enemy turn, everything not anchored is pushed 1 tile toward the lower right.", "Wind HUD uses exact approved screen-relative direction wording")
	for type: String in ["hoarfrost_seer", "gale_herald"]:
		expect.call(scene._turn_order_portrait_path({"kind": "enemy", "type": type}) == "res://assets/art/portraits/%s.png" % type, "%s actual turn-clock resolver uses explicit portrait" % type)
	scene.free()
	state = fixture(engine, "gale_herald")
	state["wind"] = {"direction": Vector2i(1, 0), "rounds_left": 2, "source_id": 1}
	state["enemies"].append(enemy(2, Vector2i(3, 3)))
	state = engine._clear_remaining_enemies_for_leader_objective(state, 2)
	expect.call(not state.has("wind"), "A Herald cleared by a leader objective ends its wind immediately")
	state = fixture(engine)
	state["player"]["pos"] = Vector2i(2, 6)
	state["enemies"][0]["icefall_tiles"] = engine._vector2i_values([Vector2i(5, 5)])
	state = engine._resolve_enemy_action(state, 0, intent("hoarfrost_seer", "icefall_land")["actions"][0])
	var first_pillar_id: String = str(state["terrain"][0]["id"])
	for boundary: int in range(3): Icefall.end_turn(state)
	state["enemies"][0]["icefall_tiles"] = engine._vector2i_values([Vector2i(5, 5)])
	state = engine._resolve_enemy_action(state, 0, intent("hoarfrost_seer", "icefall_land")["actions"][0])
	expect.call(str(state["terrain"][0]["id"]) != first_pillar_id, "Repeated landing produces unique terrain ids even through the legacy phase API")
	scene = SceneScript.new()
	var animated: Dictionary = fixture(engine)
	scene._apply_animation_step(animated, {"kind": "surface", "hidden_by_umbra": true, "en02_state_after": state})
	expect.call(animated.get("terrain", []) == state["terrain"] and int(animated["enemies"][0]["icefall_serial"]) == 2, "Hidden-action presentation keeps mechanic snapshots and terrain synchronized")
	scene.free()
	board = BoardScript.new()
	expect.call(not board._effect_uses_elemental_scene_depth({"kind": "aoe", "element": "ice", "en02_mechanic": "icefall_land"}), "Icefall never draws a generic impact at the hero's unmarked current tile")
	board.free()

static func _additional_boundaries(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = fixture(engine)
	state["enemies"][0]["intent"] = intent("hoarfrost_seer", "icefall")
	state = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	var marked: Array[Vector2i] = engine._vector2i_values(state["enemies"][0]["icefall_tiles"])
	state["enemies"][0]["shock"] = 1
	state = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	expect.call(state["enemies"][0]["icefall_tiles"] == marked and state["enemies"][0]["intent"]["id"] == "icefall_land", "Shock defers held Icefall without losing marks or forced intent")
	state["enemies"][0]["freeze"] = 1
	state = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	expect.call(state["enemies"][0]["icefall_tiles"] == marked and state["enemies"][0]["intent"]["id"] == "icefall_land", "Freeze preserves held Icefall on its skipped activation")
	var rows: Array = Icons.tokens_for_action(intent("hoarfrost_seer", "icefall")["actions"][0])
	expect.call(rows.size() == 2 and rows[0]["icon"] == "icefall" and int(rows[0]["value"]) == 5 and int(rows[1]["value"]) == 5, "Icefall intent rows show real five damage and range five")
	rows = Icons.tokens_for_action(intent("gale_herald", "call_the_wind")["actions"][0])
	expect.call(rows.size() == 2 and rows[0]["icon"] == "wind" and int(rows[0]["value"]) == 2 and rows[1]["icon"] == "push" and int(rows[1]["value"]) == 1, "Call rows show two rounds and Push one")
	state = fixture(engine, "gale_herald")
	state["enemies"].append(enemy(2, Vector2i(6, 5), 1))
	state["enemies"].append(enemy(3, Vector2i(7, 5)))
	state["enemies"][2]["anchored"] = true
	state["wind"] = {"direction": Vector2i(1, 0), "rounds_left": 2, "source_id": 1}
	var steps: Array[Dictionary]
	var forecast: Dictionary = Wind.preview(engine, state, state["wind"])
	state = Wind.end_turn(engine, state, steps)
	expect.call(int(state["enemies"][1]["hp"]) == 0 and int(state["enemies"][2]["hp"]) == 18, "Wind collisions can kill an enemy and damage its anchored enemy blocker")
	expect.call(int(state.get("death_bonus_card_plays_this_turn", 0)) == 0 and int(state["room_embers"]) == int(Data.enemy_def("crawler")["reward_embers"]), "Wind enemy-vs-enemy kills preserve rewards and grant no player-card bonus")
	expect.call(state["enemies"] == forecast["state"]["enemies"] and state["player"] == forecast["state"]["player"], "Friendly-fire wind forecast exactly matches resolution")
	state = fixture(engine, "gale_herald")
	state["player"]["pos"] = Vector2i(1, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = FIXTURE_SEED
	for iteration: int in range(20):
		engine._assign_enemy_intent(state, 0, rng)
		expect.call(state["enemies"][0]["intent"]["id"] != "gust_bolt", "Herald cannot roll an impossible Gust Bolt")
	state = fixture(engine)
	state["room_element"] = "ice"
	Surfaces.place(state, state["player"]["pos"], "ice")
	state["player"]["chilled"] = true
	state["enemies"][0]["icefall_tiles"] = engine._vector2i_values([state["player"]["pos"]])
	state = engine._resolve_enemy_action(state, 0, intent("hoarfrost_seer", "icefall_land")["actions"][0])
	expect.call(int(state["player"]["freeze"]) == 1 and Surfaces.element_at(state, state["player"]["pos"]).is_empty(), "Elemental-room Icefall preserves existing Chilled to Freeze conversion")
	state = fixture(engine, "gale_herald")
	state["room_element"] = "air"
	state["wind"] = {"direction": Vector2i(1, 0), "rounds_left": 2, "source_id": 1}
	state["enemies"].append(enemy(2, Vector2i(3, 3)))
	state["enemies"][1]["intent"] = {"id": "proof_guard", "name": "Proof", "time": 4, "weight": 1, "actions": [{"type": "block", "amount": 1}]}
	state = engine.resolve_enemy_turn_with_steps(state, 1)["state"]
	expect.call(int(state["wind"]["rounds_left"]) == 1 and state["player"]["pos"] == Vector2i(6, 5), "Wind also resolves after another enemy's turn in an air room")
	state = fixture(engine, "gale_herald")
	state["enemies"][0]["pos"] = Vector2i(4, 8)
	Surfaces.place(state, Vector2i(4, 5), "fire")
	Surfaces.place(state, Vector2i(6, 5), "fire")
	expect.call(Wind.direction(engine, state, state["enemies"][0]) == Vector2i(-1, 0), "A tied minor axis still points toward the Herald")
	state["terrain"] = [{"id": "expiry", "kind": "ice_pillar", "pos": Vector2i(6, 6), "rounds_left": 1, "blocks_sight": true}]
	var before_expiry: Dictionary = state.duplicate(true)
	steps.clear()
	Icefall.end_turn(state, steps)
	expect.call(steps.size() == 1 and steps[0]["en02_mechanic"] == "icefall_expiry" and (steps[0]["en02_state_after"]["terrain"] as Array).is_empty(), "Pillar expiry is presented before the following actor's movement")
	expect.call(engine._terrain_target_losses(before_expiry, state).is_empty(), "Terrain expiry never becomes a displayed HP damage amount")
	var board: Control = BoardScript.new()
	board.combat_state = fixture(engine)
	board.presentation = {"collision_markers": [{"actor_key": "player", "tile": Vector2i(9, 5), "blocked_tile": Vector2i(10, 5), "damage": 2}]}
	expect.call(WindView.collision_markers(board).is_empty(), "No wind never redraws existing card collision markers")
	board.combat_state = fixture(engine, "gale_herald")
	board.combat_state["player"]["pos"] = Vector2i(9, 5)
	board.combat_state["wind"] = {"direction": Vector2i(1, 0), "rounds_left": 2, "source_id": 1}
	expect.call(WindView.collision_markers(board).is_empty(), "Matching card and wind contacts draw one collision marker")
	board.free()
	state = fixture(engine, "gale_herald")
	Surfaces.place(state, Vector2i(6, 5), "fire")
	state["enemies"][0]["intent"] = intent("gale_herald", "call_the_wind")
	var force: Dictionary = engine.projected_player_force(state, 1, engine.enemy_threat_tiles(state, 0))
	expect.call(force.get("path", []) == engine._vector2i_values([Vector2i(5, 5), Vector2i(6, 5)]), "Focused Call uses global hazard direction rather than pushing away from the Herald")
	var scene: Control = SceneScript.new()
	var feedback: Array[Dictionary] = WindView.damage_texts(scene, {"kind": "push", "target_losses": [{"key": "player", "tile": Vector2i(5, 5), "hp_loss": 2}], "enemy_losses": [{"key": "enemy_2", "tile": Vector2i(6, 5), "hp_loss": 5}]})
	expect.call(feedback.size() == 2 and feedback[0]["text"] == "-2" and feedback[1]["text"] == "-5", "Mechanic feedback retains player and friendly-fire damage numbers")
	scene.free()

static func _director_feedback(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = fixture(engine, "gale_herald")
	state["wind"] = {"direction": Vector2i(1, 0), "rounds_left": 2, "source_id": 1}
	state["terrain"] = [{"id": "last_round", "kind": "ice_pillar", "pos": Vector2i(6, 5), "rounds_left": 1, "blocks_sight": true, "shatter_damage": 2}]
	var pillar: Dictionary = state["terrain"][0]
	expect.call(not pillar.has("hp") and not pillar.has("max_hp") and engine._live_terrain(state).size() == 1, "Ice Pillars are live terrain with no hidden HP sentinel")
	expect.call(not Surfaces.can_place(state, Vector2i(6, 5)), "Surface placement respects HP-free Ice Pillar occupancy")
	expect.call(not engine.valid_targets_for_player_action(state, {"type": "melee", "damage": 3, "range": 1}).has(Vector2i(6, 5)), "Melee cannot target Ice Pillar terrain")
	var undamaged: Dictionary = state.duplicate(true)
	undamaged = engine._damage_terrain(undamaged, 0, 99)
	expect.call(undamaged["terrain"] == state["terrain"], "Direct and area attack damage cannot remove an Ice Pillar")
	var preview: Dictionary = Wind.preview(engine, state, state["wind"])
	var steps: Array[Dictionary]
	state = Wind.complete_turn(engine, state, steps)
	expect.call(state["player"]["pos"] == Vector2i(5, 5) and int(state["player"]["hp"]) == 48 and (state["terrain"] as Array).is_empty(), "Last-round Ice Pillar blocks wind, deals two and shatters before terrain expiry")
	expect.call(state["player"] == preview["state"]["player"] and preview["collision_markers"].size() == 1 and int(preview["collision_markers"][0]["damage"]) == 2, "Last-round pillar wind collision forecast equals resolution")
	expect.call(steps.size() == 1 and steps[0]["en02_mechanic"] == "wind_push", "Wind snapshot presents the shatter without a second terrain-expiry step")
	state = fixture(engine, "gale_herald")
	state["wind"] = {"direction": Vector2i(1, 0), "rounds_left": 2, "source_id": 1}
	state["terrain"] = [{"id": "away_from_wind", "kind": "ice_pillar", "pos": Vector2i(6, 6), "rounds_left": 1, "blocks_sight": true}]
	steps.clear()
	state = Wind.complete_turn(engine, state, steps)
	expect.call(steps.size() == 2 and steps[0]["en02_mechanic"] == "wind_push" and steps[1]["en02_mechanic"] == "icefall_expiry", "Uncontacted terrain lifetime counts down after the wind animation snapshot")
	var definitions: Dictionary = Data.enemies()
	var fixture_id: String = CONSTRUCT_FIXTURE_ID
	definitions[fixture_id] = {"construct": true}
	expect.call(Wind.anchored(state, "enemy", {"type": fixture_id}), "Definition construct=true confers wind immunity without runtime flags")
	definitions[fixture_id]["construct"] = false
	expect.call(not Wind.anchored(state, "enemy", {"type": fixture_id}), "Definition construct=false leaves the enemy wind eligible")
	definitions.erase(fixture_id)
	expect.call(IcefallView.PUFF_SECONDS == 0.30, "Frost puff uses approved 0.30 seconds after landing")
	var board: Control = BoardScript.new()
	expect.call(board._terrain_tooltip_text({"kind": "ice_pillar", "rounds_left": 2}) == "Ice Pillar: blocks movement and sight for 2 more round(s). A unit pushed into it shatters it and takes 2 damage.", "Pillar tooltip uses exact lifetime and shatter wording")
	expect.call(not board._should_show_terrain_health_bar({"kind": "ice_pillar", "rounds_left": 2}), "Ice Pillars have no terrain health bar")
	board.free()
	for axis: Vector2i in engine.CARDINAL_DIRECTIONS:
		var heading: Vector2 = WindView.screen_direction(axis)
		var quadrant: String = ("upper" if heading.y < 0 else "lower") + " " + ("right" if heading.x > 0 else "left")
		expect.call(WindView.direction_name(axis) == "toward the " + quadrant, "Wind direction words match the isometric screen quadrant for %s" % axis)
	expect.call(WindView.CHEVRON_HEAD_WIDTH == 14.0 and WindView.CHEVRON_STROKE == 2.0 and WindView.DRIFT_PIXELS_PER_SECOND == 40.0, "Wind chevrons use approved dimensions and drift speed")
	expect.call(WindView.status_badges({"type": "gale_herald"})[0]["tooltip"] == "Anchored: the wind does not move it.", "Herald Anchored tooltip uses exact approved wording")
	expect.call(Icons.KEYWORDS["icefall"]["description"] == "Icefall: icicles fall on the marked tiles on the Seer's next turn.", "Icefall icon description uses approved wording")
	expect.call(Icons.KEYWORDS["wind"]["description"] == "Wind: at the end of each enemy turn, everything not anchored is pushed one tile with the wind.", "Wind icon description uses approved wording")

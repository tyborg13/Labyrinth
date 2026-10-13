extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Burrow = preload("res://scripts/enemy_mechanics/burrow.gd")
const Burst = preload("res://scripts/enemy_mechanics/death_burst.gd")
const Kindle = preload("res://scripts/enemy_mechanics/kindle.gd")
const SceneScript = preload("res://scripts/run_scene.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Store = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const MovementFixture = preload("res://tests/suites/player_movement_suite.gd")

# These coordinates, seed and HP overrides belong only to debug/test fixtures.
const FIXTURE_HERO_TILE: Vector2i = Vector2i(4, 4)
const FIXTURE_GRUB_TILE: Vector2i = Vector2i(2, 4)
const FIXTURE_SEED: int = 611

static func fixture(types: Array = ["burrow_grub"]) -> Dictionary:
	var engine := Combat.new()
	var room: Dictionary = MovementFixture._room()
	var enemies: Array
	for index: int in range(types.size()):
		var definition: Dictionary = Data.enemy_def(str(types[index]))
		enemies.append({"id": index + 1, "type": types[index], "pos": FIXTURE_GRUB_TILE + Vector2i(index, 0), "hp": definition["max_hp"], "max_hp": definition["max_hp"], "block": 0})
	room["enemies"] = enemies
	var state: Dictionary = engine.create_combat(FIXTURE_SEED, room, {"hp": 30, "max_hp": 30, "deck_cards": ["quick_stab", "brace"], "hand_size": 2, "relics": []})
	state["player"]["pos"] = FIXTURE_HERO_TILE
	state["terrain"] = []
	state["traps"] = []
	state["surfaces"] = {}
	for enemy: Dictionary in state["enemies"]:
		enemy["intent"] = Data.enemy_def(str(enemy["type"]))["intents"][0].duplicate(true)
	return state

static func run(check: Callable) -> void:
	_test_data(check)
	_test_burrow(check)
	_test_erupt(check)
	_test_burst(check)
	_test_intents(check)
	_test_previews_and_save(check)
	_test_interruptions_and_normal_attacks(check)

static func _test_data(check: Callable) -> void:
	var staged: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://spec/peer_benchmark/staged/enemies/wave_e1.json"))
	var production: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	for id: String in ["burrow_grub", "ember_tick"]:
		check.call(production[id] == staged[id], "%s preserves protected director data verbatim" % id)
		var definition: Dictionary = Data.enemy_def(id)
		for field: String in ["name", "max_hp", "base_initiative", "reward_embers", "accent", "art_path", "intents"]:
			check.call(definition.has(field), "%s schema has %s" % [id, field])
		check.call(FileAccess.file_exists(definition["art_path"]), "%s approved processed board art exists" % id)
		var portrait: String = "res://assets/art/portraits/%s.png" % id
		check.call(FileAccess.file_exists(portrait), "%s portrait exists" % id)
		var scene := SceneScript.new()
		check.call(scene._turn_order_portrait_path({"kind": "enemy", "type": id}) == portrait, "%s resolves its explicit turn clock portrait" % id)
		scene.free()
		var image := Image.new()
		check.call(image.load(definition["art_path"]) == OK and image.get_size() == Vector2i(255, 255), "%s board texture decodes on static canvas" % id)
		check.call(image.load(portrait) == OK and image.get_size() == Vector2i(128, 128), "%s portrait texture decodes" % id)
		var ids: Dictionary = {}
		for intent: Dictionary in definition["intents"]:
			check.call(not ids.has(intent["id"]) and not str(intent["name"]).is_empty() and int(intent["time"]) > 0 and int(intent["weight"]) >= 0, "%s intent schema" % id)
			ids[intent["id"]] = true

static func _test_burrow(check: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = fixture()
	state = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	var grub: Dictionary = state["enemies"][0]
	check.call(bool(grub.get("burrowed", false)) and grub.get("erupt_tile") == FIXTURE_HERO_TILE, "Burrow commits the hero tile and hidden state")
	check.call(not engine._occupied_enemy_tiles(state).has(FIXTURE_GRUB_TILE), "Burrow leaves occupancy")
	check.call(str(grub["intent"]["id"]) == "erupt", "Burrow forces next Erupt")
	for type: String in ["melee", "ranged", "push", "pull", "swap", "petrify"]:
		var action: Dictionary = {"type": type, "range": 5, "damage": 3, "amount": 1}
		check.call(not engine.valid_targets_for_player_action(state, action).has(FIXTURE_GRUB_TILE), "Burrow rejects single-target %s" % type)
	var walking: Dictionary = state.duplicate(true)
	walking["current_actor"] = {"kind": "player", "key": "player"}
	var walked: Dictionary = engine.apply_player_movement(walking, FIXTURE_GRUB_TILE)
	check.call(walked["player"]["pos"] == FIXTURE_GRUB_TILE, "Hero can walk through and stand on the grub old tile")
	var force_before: Vector2i = grub["pos"]
	engine._force_move_actor(state, "enemy", int(grub["id"]), Vector2i.RIGHT, 1, {}, true)
	check.call(state["enemies"][0]["pos"] == force_before, "Area push cannot move a Burrowed unit")
	var area: Dictionary = {"type": "aoe", "damage": 3, "range": 5, "radius": 1, "element": "none"}
	var after_area: Dictionary = engine.apply_player_action(state, area, FIXTURE_GRUB_TILE)
	check.call(int(after_area["enemies"][0]["hp"]) == 9, "Area damage hits the grub's old tile")
	Surfaces.place(state, FIXTURE_GRUB_TILE, "fire", {})
	var after_ground: Dictionary = engine._surface_contact(state, "enemy", int(grub["id"]), FIXTURE_GRUB_TILE, true)
	check.call(int(after_ground["enemies"][0]["hp"]) == 9, "Ground hits the burrowed grub at its old tile")
	var packed: Variant = var_to_bytes(state)
	var reloaded: Dictionary = bytes_to_var(packed)
	check.call(reloaded == state and reloaded["enemies"][0]["erupt_tile"] == FIXTURE_HERO_TILE, "Mid-burrow state round-trips without derived occupancy")
	var dying: Dictionary = engine.apply_player_action(state, {"type": "aoe", "damage": 99, "range": 5, "radius": 1}, FIXTURE_GRUB_TILE)
	check.call(int(dying["enemies"][0]["hp"]) == 0 and not dying["enemies"][0].has("erupt_tile"), "Area death removes Erupt mark")
	var shared: Dictionary = engine.resolve_enemy_turn_with_steps(fixture(["burrow_grub", "crawler"]), 0)["state"]
	shared["current_actor"] = {"kind": "player", "key": "player"}
	shared["enemies"][1]["pos"] = FIXTURE_GRUB_TILE
	check.call(engine._enemy_index_at_tile(shared, FIXTURE_GRUB_TILE) == 1, "A shared mound tile resolves its visible occupying enemy")
	shared = engine.apply_player_action(shared, {"type": "ranged", "range": 5, "damage": 3}, FIXTURE_GRUB_TILE)
	check.call(int(shared["enemies"][0]["hp"]) == 12 and int(shared["enemies"][1]["hp"]) == 11, "Single-target attack hits the visible occupant, never the buried grub on the same tile")
	var old: Dictionary = fixture()
	check.call(not old["enemies"][0].has("burrowed"), "Old/default states need no mechanic fields")

static func _test_erupt(check: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = fixture(["burrow_grub", "crawler"])
	state["enemies"][1]["pos"] = Vector2i(4, 3)
	state = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	var threat: Dictionary = engine.enemy_threat_tiles(state, 0)
	var force: Dictionary = engine.projected_player_force(state, int(state["enemies"][0]["id"]), threat)
	check.call(force.get("destination") == Vector2i(5, 4), "Erupt displacement preview equals the real resolved destination")
	check.call((threat["projected_attack"] as Array).has(FIXTURE_HERO_TILE), "Erupt telegraphs its resolved center")
	state = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	check.call(int(state["player"]["hp"]) == 24 and state["player"]["pos"] == Vector2i(5, 4), "Erupt deals 6 and displaces away from old tile")
	check.call(state["enemies"][1]["pos"] == Vector2i(4, 2), "Erupt pushes other adjacent units directly away once")
	check.call(state["enemies"][0]["pos"] == FIXTURE_HERO_TILE and not bool(state["enemies"][0].get("burrowed", true)), "Erupt surfaces at mark")
	check.call(Surfaces.has_surface(state, FIXTURE_HERO_TILE, "rubble") and int(state["enemies"][0]["expose"]) == 2, "Erupt leaves Rubble and Expose 2")
	var blocked: Dictionary = fixture()
	blocked = engine.resolve_enemy_turn_with_steps(blocked, 0)["state"]
	blocked["player"]["pos"] = Vector2i(5, 5)
	blocked["grid"][4][4] = "wall"
	var expected: Vector2i = Burrow.landing_tile(engine, blocked, blocked["enemies"][0])
	var blocked_threat: Dictionary = engine.enemy_threat_tiles(blocked, 0)
	check.call(int(blocked_threat["projected_attack_action"]["damage"]) == 0 and blocked_threat["projected_destination"] == expected, "Blocked Erupt preview shows zero center damage at actual fallback")
	var hp: int = int(blocked["player"]["hp"])
	blocked = engine.resolve_enemy_turn_with_steps(blocked, 0)["state"]
	check.call(blocked["enemies"][0]["pos"] == expected and int(blocked["player"]["hp"]) == hp, "Blocked mark uses nearest free landing and no central damage")
	var surrounded: Dictionary = engine.resolve_enemy_turn_with_steps(fixture(["burrow_grub", "crawler"]), 0)["state"]
	for tile: Vector2i in [Vector2i(5, 4), Vector2i(4, 5), Vector2i(3, 4), Vector2i(4, 3)]: surrounded["grid"][tile.y][tile.x] = "wall"
	surrounded["enemies"][1]["pos"] = Vector2i(6, 3)
	var actual_landing: Vector2i = Burrow.landing_tile(engine, surrounded, surrounded["enemies"][0])
	check.call(actual_landing == Vector2i(6, 4), "Surrounded mark chooses nearest free tile in the deterministic search order")
	var fallback_threat: Dictionary = engine.enemy_threat_tiles(surrounded, 0)
	check.call(fallback_threat["projected_destination"] == actual_landing and fallback_threat["attack"].has(FIXTURE_HERO_TILE), "Fallback preview includes actual surfacing tile and the damaged marked tile")
	surrounded = engine.resolve_enemy_turn_with_steps(surrounded, 0)["state"]
	check.call(surrounded["player"]["pos"] == FIXTURE_HERO_TILE and int(surrounded["player"]["hp"]) == 24, "Surrounded central unit takes 6 and remains on the mark")
	check.call(surrounded["enemies"][0]["pos"] == actual_landing and not surrounded["enemies"][0]["burrowed"] and surrounded["enemies"][1]["pos"] == Vector2i(6, 2), "Fallback grub surfaces and pushes from its actual tile")
	check.call(Surfaces.has_surface(surrounded, actual_landing, "rubble") and int(surrounded["enemies"][0]["expose"]) == 2, "Fallback still creates Rubble and Expose 2")
	var clockwise: Dictionary = fixture()
	clockwise["enemies"][0]["burrowed"] = true
	clockwise["grid"][4][5] = "wall"
	check.call(Burrow.adjacent_free(engine, clockwise, FIXTURE_HERO_TILE, FIXTURE_GRUB_TILE, int(clockwise["enemies"][0]["id"])) == Vector2i(4, 5), "Displacement searches clockwise after away tile")

static func _test_burst(check: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = fixture(["ember_tick", "ember_tick", "ember_tick", "crawler"])
	state["enemies"][0]["pos"] = Vector2i(3, 3)
	state["enemies"][1]["pos"] = Vector2i(4, 3)
	state["enemies"][1]["hp"] = 4
	state["enemies"][2]["pos"] = Vector2i(5, 3)
	state["enemies"][2]["hp"] = 4
	state["enemies"][3]["pos"] = Vector2i(5, 4)
	state["enemies"][3]["hp"] = 20
	state["player"]["block"] = 3
	state["damage_context"] = {"actor_kind": "player", "player_card": true}
	var after: Dictionary = engine._damage_enemy(state.duplicate(true), 0, 6)
	check.call(int(after["player"]["hp"]) == 21 and int(after["player"]["block"]) == 0, "Three bursts hit hero through normal Block")
	check.call(int(after["enemies"][3]["hp"]) == 12, "Tick bursts damage nearby enemies including diagonals")
	var events: Array = after.get("death_burst_events", [])
	check.call(events.size() == 3 and int(events[0]["id"]) == int(state["enemies"][0]["id"]) and int(events[2]["id"]) == int(state["enemies"][2]["id"]), "Chain bursts resolve breadth-first once per tick")
	check.call(int(after.get("death_bonus_card_plays_this_turn", 0)) == 1, "Only initiating player-card kill grants card-play bonus")
	var initial_frame: Dictionary = preload("res://scripts/enemy_mechanics/death_burst_view.gd").state_for_frame(state, after, 0.0)
	check.call(int(initial_frame["player"]["hp"]) == 30 and int(initial_frame["enemies"][1]["hp"]) == 4, "Burst presentation starts with original damage withheld while dissolve begins")
	var final_frame: Dictionary = preload("res://scripts/enemy_mechanics/death_burst_view.gd").state_for_frame(state, after, 1.0)
	check.call(final_frame["player"] == after["player"] and final_frame["enemies"] == after["enemies"], "Burst presentation ends on exact resolved FIFO state")
	var burst_view = preload("res://scripts/enemy_mechanics/death_burst_view.gd")
	var clock: Dictionary = {"duration": 1.0, "first_start": 0.01, "death_seconds": 0.64}
	check.call(burst_view.event_slot(state, after, 0.009, clock) == -1, "Burst starts after dissolve begins")
	check.call(burst_view.event_slot(state, after, 0.189, clock) == 0 and burst_view.event_slot(state, after, 0.191, clock) == 1 and burst_view.event_slot(state, after, 0.371, clock) == 2, "Chain bursts start 0.18 seconds apart")
	var sampled: Dictionary = burst_view.timing(state, after, 16, 0.065)
	check.call(is_equal_approx(float(sampled["death_seconds"]), 0.975), "Chain preserves existing dissolve duration")
	for index: int in range(3):
		var boundary: float = float(sampled["first_start"]) + float(index) * burst_view.BURST_CHAIN_SECONDS
		check.call(is_equal_approx(boundary / float(sampled["frame_seconds"]), roundf(boundary / float(sampled["frame_seconds"]))) and burst_view.event_slot(state, after, boundary / float(sampled["duration"]), sampled) == index, "Renderer sampling reaches each 0.18 s chain boundary exactly")
	check.call(int(after.get("room_embers", 0)) == 18, "Burst preserves existing enemy friendly-fire Ember reward policy")
	for index: int in range(3): check.call(Surfaces.has_surface(after, after["enemies"][index]["pos"], "fire"), "Each burst leaves Fire on its own tile")
	var tick_state: Dictionary = fixture(["ember_tick"])
	for _index: int in range(4): Kindle.resolve(tick_state, 0, {"amount": 2})
	check.call(Burst.damage(tick_state["enemies"][0]) == 8 and not Kindle.available(tick_state["enemies"][0]), "Kindle stacks twice to max +4")
	check.call(bytes_to_var(var_to_bytes(tick_state)) == tick_state, "Kindled state persists")

static func _test_intents(check: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = fixture()
	var rng := RandomNumberGenerator.new()
	rng.seed = FIXTURE_SEED
	for _index: int in range(40):
		state["enemies"][0]["intent"] = {}
		engine._assign_enemy_intent(state, 0, rng)
		check.call(str(state["enemies"][0]["intent"]["id"]) != "erupt", "Zero-weight Erupt is never randomly chosen")
	var tick: Dictionary = fixture(["ember_tick"])
	tick["enemies"][0]["kindled_bonus"] = 4
	engine._assign_enemy_intent(tick, 0, rng)
	check.call(str(tick["enemies"][0]["intent"]["id"]) == "scuttle", "AI falls back from impossible Kindle at cap")
	var order: Array = engine.current_turn_order(fixture(["burrow_grub", "ember_tick"]))
	check.call(order.any(func(actor: Dictionary) -> bool: return str(actor.get("enemy_type", actor.get("type", ""))) == "burrow_grub"), "Turn clock contains grub")
	check.call(order.any(func(actor: Dictionary) -> bool: return str(actor.get("enemy_type", actor.get("type", ""))) == "ember_tick"), "Turn clock contains tick")

static func _test_previews_and_save(check: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = fixture(["ember_tick", "crawler"])
	state["enemies"][0]["pos"] = Vector2i(3, 3)
	state["enemies"][1]["pos"] = Vector2i(4, 3)
	var scene := SceneScript.new()
	var action: Dictionary = {"type": "ranged", "range": 5, "damage": 6}
	var preview: Dictionary = scene._preview_damage_for_action(state, action, Vector2i(3, 3))
	check.call(int(preview.get("player", {}).get("hp_loss", 0)) == 4, "Lethal card preview includes tick burst damage to hero")
	check.call(int(preview.get("enemy_2", {}).get("hp_loss", 0)) == 4, "Lethal card preview includes tick burst damage to another enemy")
	check.call(bool(preview.get("enemy_1", {}).get("lethal", false)), "Lethal tick preview uses actual damage")
	var board := Board.new()
	var badges: Array[Dictionary] = board._unit_status_badges(state["enemies"][0])
	check.call(badges.any(func(badge: Dictionary) -> bool: return str(badge.get("icon", "")) == "burst" and int(badge.get("count", 0)) == 4 and not badge.has("label") and str(badge.get("tooltip", "")) == "Bursts: when this dies, it deals 4 damage to everything next to it."), "Every living tick shows its total Burst badge")
	check.call(not board._intent_rows_for_unit({}, Data.enemy_def("burrow_grub")["intents"][0]).is_empty(), "Burrow has visible intent rows")
	check.call(not board._intent_rows_for_unit({}, Data.enemy_def("ember_tick")["intents"][1]).is_empty(), "Kindle has visible intent rows")
	board.combat_state = state
	board.presentation = {"umbra_visible_tiles": [FIXTURE_HERO_TILE]}
	board.set("_hover_tile", state["enemies"][0]["pos"])
	check.call(preload("res://scripts/enemy_mechanics/death_burst_view.gd").focused_tiles(board).is_empty(), "Hovering a hidden tile never reveals an unknown tick burst ring")
	board.presentation["umbra_visible_tiles"].append(state["enemies"][0]["pos"])
	check.call(preload("res://scripts/enemy_mechanics/death_burst_view.gd").focused_tiles(board).size() == 8, "A visible hovered tick shows its eight actual burst tiles")
	board.free()
	scene.free()
	var buried: Dictionary = engine.resolve_enemy_turn_with_steps(fixture(), 0)["state"]
	var saved: Dictionary = {"surface_rules_version": Surfaces.RULES_VERSION, "combat_state": buried}
	var path: String = "user://en01_mid_burrow.save"
	var prior_storage: String = Store._run_storage_path
	Store.set_run_storage_path(path)
	check.call(Store.save_run_state(saved), "Mid-burrow uses the production transactional save writer")
	var loaded: Dictionary = Store.load_saved_run()
	check.call(loaded == saved, "Production save/load preserves marked tiles and Burrowed state")
	var continued: Dictionary = engine.resolve_enemy_turn_with_steps(loaded["combat_state"], 0)["state"]
	check.call(continued == engine.resolve_enemy_turn_with_steps(buried, 0)["state"], "Loaded Erupt resolves identically with seeded state")
	Store.clear_saved_run()
	Store.set_run_storage_path(prior_storage)

static func _test_interruptions_and_normal_attacks(check: Callable) -> void:
	var engine := Combat.new()
	var buried: Dictionary = engine.resolve_enemy_turn_with_steps(fixture(), 0)["state"]
	buried["enemies"][0]["freeze"] = 1
	var frozen: Dictionary = engine.resolve_enemy_turn_with_steps(buried, 0)["state"]
	check.call(bool(frozen["enemies"][0].get("burrowed", false)) and str(frozen["enemies"][0]["intent"].get("id")) == "erupt", "A skipped eruption retains its mark and legal Erupt intent")
	var shocked: Dictionary = fixture()
	shocked["enemies"][0]["shock"] = 1
	shocked = engine.resolve_enemy_turn_with_steps(shocked, 0)["state"]
	check.call(not bool(shocked["enemies"][0].get("burrowed", false)) and str(shocked["enemies"][0]["intent"]["id"]) != "erupt", "A skipped Burrow never forces impossible Erupt")
	var gnaw: Dictionary = fixture()
	gnaw["enemies"][0]["intent"] = Data.enemy_def("burrow_grub")["intents"][2].duplicate(true)
	gnaw = engine.resolve_enemy_turn_with_steps(gnaw, 0)["state"]
	check.call(int(gnaw["player"]["hp"]) == 27, "Gnaw uses standard movement and melee 3")
	var scuttle: Dictionary = fixture(["ember_tick"])
	scuttle = engine.resolve_enemy_turn_with_steps(scuttle, 0)["state"]
	check.call(int(scuttle["player"]["hp"]) == 28, "Scuttle uses standard movement 3 and melee 2")
	var earth: Dictionary = fixture()
	earth["room_element"] = "earth"
	earth = engine.resolve_enemy_turn_with_steps(earth, 0)["state"]
	earth = engine.resolve_enemy_turn_with_steps(earth, 0)["state"]
	check.call(int(earth["player"]["hp"]) == 24, "Earth room preserves authored Erupt damage")
	var fire: Dictionary = fixture(["ember_tick"])
	fire["room_element"] = "fire"
	fire["enemies"][0]["pos"] = Vector2i(3, 3)
	fire["player"]["block"] = 2
	fire = engine._damage_enemy(fire, 0, 6)
	check.call(int(fire["player"]["hp"]) == 28, "Fire room Burst honors normal Block")

	var bleeding: Dictionary = engine.resolve_enemy_turn_with_steps(fixture(), 0)["state"]
	bleeding["enemies"][0]["bleed"] = 12
	var canceled: Dictionary = engine.resolve_enemy_turn_with_steps(bleeding, 0)
	bleeding = canceled["state"]
	check.call(not (canceled["steps"] as Array).any(func(step: Dictionary) -> bool: return str(step.get("kind", "")) == "erupt"), "Canceled Erupt never emits a rising-body animation")
	check.call(int(bleeding["enemies"][0]["hp"]) == 0 and not bleeding["enemies"][0].has("erupt_tile") and int(bleeding["player"]["hp"]) == 30, "Lethal area-applied Bleed cancels Erupt and removes mark before impact")
	var retaliating: Dictionary = engine.resolve_enemy_turn_with_steps(fixture(), 0)["state"]
	preload("res://scripts/retaliate_rules.gd").gain(retaliating, {"amount": 3}, "Test fixture")
	retaliating = engine.resolve_enemy_turn_with_steps(retaliating, 0)["state"]
	check.call(int(retaliating["enemies"][0]["hp"]) == 9, "Erupt preserves existing Retaliate against the surfaced adjacent attacker")

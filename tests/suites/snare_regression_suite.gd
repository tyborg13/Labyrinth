extends RefCounted
## Director feedback: sealed-threshold exploits and final-start placement.
const Combat = preload("res://scripts/combat_engine.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const Rules = preload("res://scripts/snare_room_rules.gd")
const Fixture = preload("res://tools/snare_inspection.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Data = preload("res://scripts/game_data.gd")
const Run = preload("res://scripts/run_engine.gd")
const Skills = preload("res://tests/suites/skill_run_suite.gd")
const TEST_HP: int = 100
const SEALED_TILE := Vector2i(7, 4)
const PLAYER_BESIDE_SEAL := Vector2i(7, 3)
const LEGACY_ILLUSION_ID: int = 10001
const DIRECT_ILLUSION_HP: int = 5
const VAULT_START := Vector2i(7, 5)
const VAULT_DESTINATION := Vector2i(7, 3)
const PUSH_ORIGIN := Vector2i(7, 2)
const FOUR_EDGE_ENTRY := Vector2i(2, 3)
const FIVE_EDGE_ENTRY := Vector2i(1, 3)
const TRUE_BEARING_CASES: Array = [
	{"seed": 83, "room": Vector2i(2, 0), "biome": "lightning"},
	{"seed": 0, "room": Vector2i(3, -2), "biome": "ice"}]
const SELECTED_START := Vector2i(1, 3)
const AUTHORED_ENTRY := Vector2i(1, 4)

class ShortFirstGenerator extends "res://scripts/room_generator.gd":
	const SHORT_THRESHOLD := Vector2i(4, 3)
	var formation_attempts: int = 0
	var template_attempts: int = 0
	var first_path_edges: int = -1
	func _apply_template(_grid: Array, _rng: RandomNumberGenerator) -> void: template_attempts += 1
	func _snare_formation(grid: Array, entry: Vector2i, objective: Dictionary) -> Dictionary:
		formation_attempts += 1
		if formation_attempts == 1:
			var short: Dictionary = objective.duplicate(true)
			short["exits"][0]["target_tile"] = SHORT_THRESHOLD
			first_path_edges = Paths.find_path(grid, entry, SHORT_THRESHOLD).size() - 1
			return super._snare_formation(grid, entry, short)
		return super._snare_formation(grid, entry, objective)

static func run(expect: Callable) -> void:
	run_illusion(expect)
	run_ai(expect)
	run_vault(expect)
	run_forced(expect)
	_true_bearing(expect)
	_path_boundary(expect)

static func _battle(engine: RefCounted) -> Dictionary:
	return engine.create_combat(Fixture.FIXTURE_SEED, Rooms.new().generate_room(Fixture.FIXTURE_SEED, Fixture.room_spec("fire", 2), Vector2i.RIGHT), {"hp": TEST_HP, "max_hp": TEST_HP, "deck_cards": []})

static func _sealed_battle() -> Dictionary:
	var engine := Combat.new()
	var state: Dictionary = _battle(engine)
	for turn: int in range(2): state = engine.advance_to_next_player_turn_with_steps(engine.finish_player_activation(state))["state"]
	return state

static func _play(engine: RefCounted, state: Dictionary, target: Vector2i, expect: Callable) -> Dictionary:
	var card: String = state["deck"]["hand"][0]
	expect.call(engine.hand_card_has_play_budget(state, 0), "Stock card fits the real budget: " + card)
	state = engine.prepare_player_card(state, 0)
	for action: Dictionary in engine.card_play_actions(card, state):
		state = engine.apply_player_action(state, action, target if engine.player_action_needs_target(action) else Vector2i(-1, -1))
	return engine.finish_player_card(state, 0)

static func run_illusion(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = _sealed_battle()
	expect.call(state["turn"] == 3 and state["objective"]["exits"][1]["target_tile"] == SEALED_TILE and state["objective"]["exits"][1]["sealed"], "Stock-card regression reaches the real turn-two seal at (7,4)")
	# Exercise the placement guard independently of card target/commit guards.
	var direct: Dictionary = engine._create_illusion(state.duplicate(true), SEALED_TILE, DIRECT_ILLUSION_HP)
	expect.call(not direct["illusions"].any(func(unit: Dictionary) -> bool: return unit["pos"] == SEALED_TILE), "Direct illusion placement rejects a sealed threshold")
	state["player"]["pos"] = PLAYER_BESIDE_SEAL
	state["deck"]["hand"] = ["mirror_image", "changing_winds"]
	var mirror: Dictionary = Data.card_def("mirror_image")["actions"][0]
	expect.call(not engine.valid_targets_for_player_action(state, mirror).has(SEALED_TILE), "Mirror Image cannot target a sealed threshold")
	state = _play(engine, state, SEALED_TILE, expect)
	expect.call(not state["illusions"].any(func(unit: Dictionary) -> bool: return unit["pos"] == SEALED_TILE), "Mirror Image cannot create an illusion on the seal")
	state = _play(engine, state, SEALED_TILE, expect)
	expect.call(state["player"]["pos"] == PLAYER_BESIDE_SEAL, "Mirror Image then Changing Winds cannot move the player onto the seal")
	# A save/illusion created before sealing can retain an actor on that tile.
	# Swaps must validate the destination even when a live target exists there.
	state["player"]["pos"] = PLAYER_BESIDE_SEAL
	state["illusions"].append({"id": LEGACY_ILLUSION_ID, "pos": SEALED_TILE, "hp": 1, "max_hp": 1})
	var swap: Dictionary = Data.card_def("changing_winds")["actions"][0]
	expect.call(not engine.valid_targets_for_player_action(state, swap).has(SEALED_TILE), "Changing Winds excludes a live illusion on a sealed threshold")
	var swapped: Dictionary = engine.apply_prevalidated_player_action(state, swap, SEALED_TILE)
	expect.call(swapped["player"]["pos"] == PLAYER_BESIDE_SEAL, "Swap resolution rejects a stale sealed destination")
	print("Snare stock cards: Mirror Image and Changing Winds respect sealed thresholds")

static func run_ai(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = _sealed_battle()
	state["player"]["pos"] = Vector2i(7, 5)
	state["enemies"][0]["pos"] = Vector2i(7, 3)
	for intent: Dictionary in Data.enemy_def("chainbound_gaoler")["intents"]:
		if intent["id"] == "cudgel_press": state["enemies"][0]["intent"] = intent.duplicate(true)
	var plan: Dictionary = engine.enemy_intent_plan(state, 0, state["enemies"][0]["intent"])
	expect.call(plan["destination"] != SEALED_TILE and not plan["path"].has(SEALED_TILE), "Cudgel Press future routing never crosses the sealed threshold")
	var resolved: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	expect.call(resolved["enemies"][0]["pos"] != SEALED_TILE, "Cudgel Press resolution never occupies the sealed threshold")
	expect.call(resolved["player"]["hp"] == state["player"]["hp"], "Cudgel Press cannot deal the exploit's six damage through the seal")
	print("Snare stock AI: Cudgel Press cannot route or resolve through (7,4)")

static func run_vault(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = _battle(engine)
	state = engine.advance_to_next_player_turn_with_steps(engine.finish_player_activation(state))["state"]
	# Strand a live Gaoler on the threshold before its real turn-two seal.
	state["player"]["pos"] = VAULT_START
	state["enemies"][0]["pos"] = SEALED_TILE
	state["relics"] = ["vaulting_sigil"]
	for intent: Dictionary in Data.enemy_def("chainbound_gaoler")["intents"]:
		if intent["id"] == "cudgel_press": state["enemies"][0]["intent"] = intent.duplicate(true)
	state = engine.advance_to_next_player_turn_with_steps(engine.finish_player_activation(state))["state"]
	expect.call(state["turn"] == 3 and state["objective"]["exits"][1]["sealed"], "Vaulting Sigil regression reaches turn three after the real turn-two seal")
	expect.call(state["player"]["pos"] == VAULT_START and state["enemies"][0]["pos"] == SEALED_TILE and state["enemies"][0]["hp"] > 0, "Vaulting Sigil reproduction retains the player at (7,5) and live Gaoler at (7,4)")
	expect.call(not engine._tile_is_passable(state, SEALED_TILE) and engine._occupied_actor_tiles(state).has(SEALED_TILE), "Occupied sealed threshold remains actor-impassable")
	expect.call(engine._all_passable_tiles(state).has(SEALED_TILE), "Geometric tile enumeration retains the raw floor beneath a seal")
	var action: Dictionary = {"type": "move", "range": 2}
	var path: Array[Vector2i] = engine.path_for_player_action(state, action, VAULT_DESTINATION)
	expect.call(not path.has(SEALED_TILE), "Vaulting Sigil path cannot traverse occupied sealed (7,4)")
	expect.call(not engine.valid_targets_for_player_action(state, action).has(VAULT_DESTINATION), "Vaulting Sigil cannot offer a two-tile Move across the seal")
	expect.call(not engine.player_movement_targets(state).has(VAULT_DESTINATION), "Vaulting Sigil cannot offer free movement (7,5) through sealed (7,4) to (7,3)")
	var moved: Dictionary = engine.apply_player_movement(state, VAULT_DESTINATION)
	expect.call(moved == state, "Rejected Vaulting Sigil free movement preserves player, movement budget and Gaoler statuses")
	print("Snare Vaulting Sigil: occupied turn-two seal blocks turn-three free movement; geometry stays raw")

static func run_forced(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = _sealed_battle()
	state["player"]["pos"] = PUSH_ORIGIN
	state["enemies"][0]["pos"] = PLAYER_BESIDE_SEAL
	var push: Dictionary = {"type": "push", "range": 1, "amount": 2}
	expect.call(not engine._tile_is_passable(state, SEALED_TILE) and Paths.is_passable(state["grid"], SEALED_TILE), "Forced-movement regression distinguishes the seal from the raw floor")
	expect.call(engine.valid_targets_for_player_action(state, push).has(PLAYER_BESIDE_SEAL), "Push into the sealed threshold is legal through its wall collision")
	var pushed: Dictionary = engine.apply_player_action(state, push, PLAYER_BESIDE_SEAL)
	expect.call(pushed["enemies"][0]["pos"] == PLAYER_BESIDE_SEAL, "Force blocker stops the Gaoler before sealed (7,4)")
	expect.call(pushed["enemies"][0]["hp"] < state["enemies"][0]["hp"], "Push against the seal deals wall collision damage")
	print("Snare forced movement: sealed threshold stops Push and deals wall collision damage")

static func _true_bearing(expect: Callable) -> void:
	var engine := Run.new()
	var combat := Combat.new()
	var profile: Dictionary = Skills._new_run(engine, ["true_bearing"])["progression"]
	for study: Dictionary in TRUE_BEARING_CASES:
		var state: Dictionary = engine.create_new_run(study["seed"], profile)
		var room: Dictionary = engine.room_metadata(state, study["room"])
		expect.call(room.get("special_type") == "umbral_snare" and room["special_variant"] == study["biome"], "True Bearing reproduction uses the exact production Snare")
		var found: bool = false
		for parent: Dictionary in state["rooms"].values():
			for link: Dictionary in parent["connections"]:
				if link["coord"] == study["room"]:
					parent["cleared"] = true
					state["current_room"] = parent["coord"]
					found = true
					break
			if found: break
		state["mode"] = "room"
		var pre: Dictionary = engine.move_to_pre_battle(state, study["room"])
		expect.call(pre["mode"] == "pre_battle" and engine.pre_battle_start_tiles(pre).has(SELECTED_START), "Production True Bearing offers (1,3)")
		var selected: Dictionary = engine.set_pre_battle_start(pre, SELECTED_START)
		var prepared: Dictionary = engine.prepare_pre_battle_combat(selected)
		var begun: Dictionary = engine.begin_pre_battle_combat(selected)
		var battle: Dictionary = begun["combat_state"]
		expect.call(battle["player"]["pos"] == SELECTED_START, "True Bearing retains the selected final player position")
		expect.call(battle["snare_entry"] == AUTHORED_ENTRY, "True Bearing preserves the authored hunter entrance (1,4)")
		if study["biome"] == "lightning":
			var start: Dictionary = combat.finish_player_activation(battle)
			expect.call(start["enemies"].back()["pos"] == AUTHORED_ENTRY, "Seed 83 lightning (2,0): hunter enters on (1,4)")
		else:
			var hunters: int = 0
			for enemy: Dictionary in battle["enemies"]:
				if not enemy.get("snare_hunter", false): continue
				hunters += 1
				expect.call(Paths.manhattan(SELECTED_START, enemy["pos"]) >= 2, "Seed 0 ice (3,-2): every starting hunter is two tiles from final player position")
				expect.call(prepared["combat_state"]["enemies"] == battle["enemies"], "Final-start hunter placement is deterministic between preview and entry")
			expect.call(hunters == 3, "True Bearing retains all three ice starting hunters")
	print("Snare True Bearing: seed 83 lightning entrance and seed 0 ice distance checked")

static func _path_boundary(expect: Callable) -> void:
	var layout: Dictionary = Rooms.new().generate_room(Fixture.FIXTURE_SEED, Fixture.room_spec("fire", 2), Vector2i.RIGHT)
	var grid: Array = layout["grid"].duplicate(true)
	for y: int in range(1, grid.size() - 1):
		for x: int in range(1, grid[y].size() - 1): grid[y][x] = "stone"
	var short: Dictionary = Rules.formation(grid, FOUR_EDGE_ENTRY, layout["objective"])
	var boundary: Dictionary = Rules.formation(grid, FIVE_EDGE_ENTRY, layout["objective"])
	expect.call(Paths.find_path(grid, FOUR_EDGE_ENTRY, Vector2i(4, 1)).size() - 1 == 4 and short.is_empty(), "Four-edge formation is rejected")
	expect.call(not boundary.is_empty() and boundary["exits"][0]["path_tiles"] == 5, "Five-edge formation is accepted")
	var generator := ShortFirstGenerator.new()
	var rerolled: Dictionary = generator.generate_room(Fixture.FIXTURE_SEED, Fixture.room_spec("fire", 2), Vector2i.RIGHT)
	expect.call(generator.first_path_edges == 4 and generator.formation_attempts == 2 and generator.template_attempts == 2, "A four-edge candidate forces a fresh template and formation attempt")
	expect.call(rerolled["objective"]["exits"].all(func(exit: Dictionary) -> bool: return exit["path_tiles"] >= 5), "Rerolled layout retains the five-edge minimum")
	print("Snare path boundary: four edges rejected; five edges accepted; short layout rerolled")

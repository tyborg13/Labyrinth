extends RefCounted

## Wave-4 family A card mechanics: surfaces, selectors and hit results.
## Mechanics are exercised with injected fixture cards (data/cards.json is
## untouched). Rules: spec/card_mechanics_surfaces.md.

const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const GrimoireLibrary = preload("res://scripts/grimoire_library.gd")
const SurfaceCardRules = preload("res://scripts/surface_card_rules.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")

const NO_TARGET: Vector2i = Vector2i(-1, -1)
const PLAYER: Vector2i = Vector2i(2, 4)
const RIGHT: Vector2i = Vector2i(1, 0)
const DOWN: Vector2i = Vector2i(0, 1)
const CROSS: Array = [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]]
const ADJ: Array = [[0, -1], [1, 0], [0, 1], [-1, 0]]
const DIAMOND2: Array = [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1], [2, 0], [-2, 0], [0, 2], [0, -2], [1, 1], [1, -1], [-1, 1], [-1, -1]]
const LINE3: Array = [[0, 0], [1, 0], [2, 0]]

const FIXTURES: Dictionary = {
	"w4a_fx_guard": {"actions": [{"type": "block", "amount": 1}], "time": 2},
	"w4a_fx_ember_ward": {"element": "fire", "actions": [{"type": "block", "amount": 5}, {"type": "surface_adjacent_enemies", "surface": "fire"}], "time": 3},
	"w4a_fx_static_ward": {"element": "lightning", "actions": [{"type": "block", "amount": 5}, {"type": "surface_adjacent_enemies", "surface": "electrified", "include_self": true}], "time": 3},
	"w4a_fx_hoarfrost_ward": {"element": "ice", "actions": [{"type": "block", "amount": 5}, {"type": "surface_adjacent_enemies", "surface": "ice"}], "time": 3},
	"w4a_fx_rime_step": {"element": "ice", "actions": [{"type": "move", "range": 2}, {"type": "surface_adjacent_enemies", "surface": "ice"}], "time": 2},
	"w4a_fx_flashsteam": {"element": "fire", "actions": [{"type": "aoe", "damage": 3, "range": 3, "pattern": CROSS, "rotate": false, "element": "fire", "consume": {"surface": "ice", "bonus_damage": 4}}], "time": 4},
	"w4a_fx_pyroclasm": {"element": "fire", "actions": [{"type": "ranged", "damage": 9, "range": 3, "element": "fire", "consume": {"surface": "fire", "bonus_damage": 6}}], "time": 7},
	"w4a_fx_plasma_arc": {"element": "lightning", "actions": [{"type": "ranged", "damage": 3, "range": 3, "element": "lightning", "chain": 2, "consume": {"surface": "fire", "bonus_damage": 4, "per_hit": true}}], "time": 4},
	"w4a_fx_arc_primary": {"element": "lightning", "actions": [{"type": "ranged", "damage": 3, "range": 3, "element": "lightning", "chain": 2, "consume": {"surface": "fire", "bonus_damage": 4}}], "time": 4},
	"w4a_fx_frost_heave": {"element": "earth", "actions": [{"type": "ranged", "damage": 6, "range": 3, "element": "earth", "immobilize": true, "surface": "rubble", "consume": {"surface": "ice", "required": true}}], "time": 4},
	"w4a_fx_magma_vent": {"element": "fire", "actions": [{"type": "detonate", "damage": 5, "range": 3, "pattern": [[0, 0]], "rotate": false, "element": "fire", "detonate_surface": "rubble", "leave_surface": "fire"}], "time": 5},
	"w4a_fx_immolation": {"element": "fire", "actions": [{"type": "detonate", "damage": 7, "range": 0, "pattern": [[0, 0], [0, -1], [1, 0], [0, 1], [-1, 0]], "rotate": false, "element": "fire", "spare_player": true}], "time": 5, "empower": {"cost": {"health": 2}, "mods": [{"action": 0, "set": {"pattern": DIAMOND2}}]}},
	"w4a_fx_self_blast": {"element": "fire", "actions": [{"type": "detonate", "damage": 7, "range": 0, "pattern": [[0, 0], [0, -1], [1, 0], [0, 1], [-1, 0]], "rotate": false, "element": "fire"}], "time": 5},
	"w4a_fx_frost_circuit": {"element": "ice", "actions": [{"type": "convert_surface", "range": 3, "surface": "ice", "to": "electrified", "connected": true, "damage": 2, "element": "lightning", "shock": 1}], "time": 3},
	"w4a_fx_discharge": {"element": "lightning", "actions": [{"type": "discharge", "range": 4, "damage": 4, "element": "lightning"}], "time": 5},
	"w4a_fx_grounding": {"element": "earth", "actions": [{"type": "consume_surface", "surface": "electrified", "target": "player", "pattern": DIAMOND2, "min_consumed": 1, "rewards": [{"type": "stoneskin", "amount": 2, "per_tile": true, "max": 8}]}], "time": 3},
	"w4a_fx_hush": {"element": "ice", "actions": [{"type": "ranged", "damage": 5, "range": 4, "element": "ice", "on_result": {"when": "froze", "rewards": [{"type": "draw", "amount": 2}]}}], "time": 5},
	"w4a_fx_frozen_bite": {"element": "ice", "actions": [{"type": "melee", "damage": 4, "range": 1, "element": "ice", "on_result": {"when": "froze", "rewards": [{"type": "card_play", "amount": 1}]}}], "time": 3},
	"w4a_fx_headsman": {"actions": [{"type": "ranged", "damage": 3, "range": 3, "element": "none", "on_result": {"when": "killed", "rewards": [{"type": "card_play", "amount": 1}, {"type": "draw", "amount": 1}]}}], "time": 2},
	"w4a_fx_shatter": {"element": "ice", "actions": [{"type": "ranged", "damage": 5, "range": 3, "element": "ice", "frozen_splash": 5}], "time": 5},
	"w4a_fx_shatter_swing": {"actions": [{"type": "melee", "damage": 8, "range": 1, "element": "none", "frozen_splash": 4}], "time": 6},
	"w4a_fx_stoke": {"element": "fire", "actions": [{"type": "all_enemies", "selector": "on_fire", "damage": 3, "element": "fire"}], "time": 4},
	"w4a_fx_white_silence": {"element": "ice", "actions": [{"type": "all_enemies", "selector": "chilled", "damage": 4, "element": "ice"}], "time": 8},
	"w4a_fx_searing": {"actions": [{"type": "all_enemies", "selector": "in_light", "damage": 3}], "time": 5},
	"w4a_fx_glare": {"actions": [{"type": "all_enemies", "selector": "in_light", "range": 4, "damage": 0, "expose": 3}, {"type": "draw", "amount": 1}], "time": 3},
	"w4a_fx_static_sweep": {"element": "lightning", "actions": [{"type": "all_enemies", "selector": "on_electrified", "damage": 2, "element": "lightning"}], "time": 3},
	"w4a_fx_skybolt": {"element": "lightning", "actions": [{"type": "ranged", "damage": 8, "range": 99, "element": "lightning", "ignore_los": true, "shock": 1, "shock_all_hits": true}], "time": 6},
	"w4a_fx_thunderstone": {"element": "lightning", "actions": [{"type": "ranged", "damage": 5, "range": 99, "element": "lightning", "ignore_los": true, "stagger": 2}], "time": 4},
	"w4a_fx_longshot": {"actions": [{"type": "ranged", "damage": 5, "range": 99, "element": "none"}], "time": 4},
	"w4a_fx_meteorfall": {"element": "fire", "actions": [{"type": "meteor_marks", "range": 4, "pattern": LINE3, "rotate": true, "damage": 8, "surface": "fire", "element": "fire"}], "time": 7},
	"w4a_fx_fault_strike": {"element": "earth", "actions": [{"type": "melee", "damage": 9, "range": 1, "element": "earth", "surface": "rubble", "surface_pattern": LINE3, "surface_follows_facing": true}], "time": 6},
	"w4a_fx_fault_plain": {"element": "earth", "actions": [{"type": "melee", "damage": 9, "range": 1, "element": "earth", "surface": "rubble", "surface_pattern": LINE3}], "time": 6},
	"w4a_fx_flash_powder": {"actions": [{"type": "aoe", "damage": 0, "range": 3, "pattern": DIAMOND2, "rotate": false, "element": "none", "expose": 2, "illuminate_radius": 3, "illuminate_duration": 2}], "time": 3},
	"w4a_fx_caltrops": {"element": "earth", "actions": [{"type": "aoe", "damage": 0, "range": 2, "pattern": CROSS, "rotate": false, "element": "earth", "bleed": 2, "surface": "rubble"}], "time": 3},
}

static func run(expect: Callable) -> void:
	# Warm catalog caches before fixtures exist so injected cards never leak.
	GrimoireLibrary.entry_map()
	_install_fixtures()
	var engine: CombatEngine = CombatEngine.new()
	_test_surface_adjacent_enemies(engine, expect)
	_test_consume_single_target(engine, expect)
	_test_consume_area(engine, expect)
	_test_consume_per_hit_chain(engine, expect)
	_test_consume_required(engine, expect)
	_test_detonate_rubble_and_leave_fire(engine, expect)
	_test_detonate_spare_player_and_empower(engine, expect)
	_test_convert_surface(engine, expect)
	_test_discharge(engine, expect)
	_test_consume_surface_per_tile(engine, expect)
	_test_on_result_froze(engine, expect)
	_test_on_result_killed(engine, expect)
	_test_frozen_splash(engine, expect)
	_test_all_enemies_selectors(engine, expect)
	_test_all_enemies_visibility_and_range(engine, expect)
	_test_ignore_los_and_shock_all_hits(engine, expect)
	_test_meteor_marks_place_and_resolve(engine, expect)
	_test_meteor_marks_persistence(engine, expect)
	_test_surface_follows_facing(engine, expect)
	_test_zero_damage_areas(engine, expect)
	_test_presentation_contracts(engine, expect)
	_test_run_scene_contracts(engine, expect)
	_remove_fixtures()

# ------------------------------------------------------------------ fixtures

static func _install_fixtures() -> void:
	var cards: Dictionary = GameData.cards()
	for card_id: String in FIXTURES.keys():
		var card: Dictionary = (FIXTURES[card_id] as Dictionary).duplicate(true)
		card["name"] = card_id.trim_prefix("w4a_fx_").capitalize()
		card["rarity"] = "common"
		if not card.has("burn"):
			card["burn"] = false
		card["description"] = card["name"]
		card["reward_pool"] = false
		cards[card_id] = card

static func _remove_fixtures() -> void:
	var cards: Dictionary = GameData.cards()
	for card_id: String in FIXTURES.keys():
		cards.erase(card_id)

static func _grid() -> Array:
	var grid: Array = []
	for y: int in range(10):
		var row: Array = []
		for x: int in range(11):
			row.append("wall" if x == 0 or y == 0 or x == 10 or y == 9 else "stone")
		grid.append(row)
	return grid

static func _enemy(id: int, pos: Vector2i, hp: int = 30, extra: Dictionary = {}) -> Dictionary:
	var enemy: Dictionary = {"id": id, "type": "crawler", "pos": pos, "hp": hp, "max_hp": maxi(hp, 30), "block": 0, "stoneskin": 0, "intent": {}}
	enemy.merge(extra, true)
	return enemy

static func _large(id: int, pos: Vector2i, hp: int = 40) -> Dictionary:
	return _enemy(id, pos, hp, {"footprint": Vector2i(2, 2)})

static func _state(engine: CombatEngine, enemies: Array, player_pos: Vector2i = PLAYER) -> Dictionary:
	var layout: Dictionary = {
		"name": "Surface family proof", "type": "combat", "coord": Vector2i(1, 1), "depth": 1,
		"element": "none", "umbra_stage": "clear", "grid": _grid(),
		"player_start": player_pos, "terrain": [], "traps": [], "loot": [],
		"enemies": [_enemy(99, Vector2i(9, 8))],
	}
	var state: Dictionary = engine.create_combat(40417, layout, {"hp": 40, "max_hp": 40, "deck_cards": ["w4a_fx_guard", "w4a_fx_guard", "w4a_fx_guard", "w4a_fx_guard", "w4a_fx_guard", "w4a_fx_guard", "w4a_fx_guard", "w4a_fx_guard"], "hand_size": 1, "relics": [], "cards_per_turn": 8})
	state["player"] = {"pos": player_pos, "hp": 40, "max_hp": 40, "block": 0, "stoneskin": 0}
	state["enemies"] = enemies.duplicate(true)
	state["terrain"] = []
	state["traps"] = []
	state["loot"] = []
	state["surfaces"] = {}
	state["current_actor"] = {"kind": "player", "key": "player"}
	state["player_turn_restrictions"] = {}
	state["cards_played_this_turn"] = 0
	state["death_bonus_card_plays_this_turn"] = 0
	state["card_play_bonus_this_turn"] = 0
	var deck: Dictionary = state["deck"] as Dictionary
	deck["hand"] = []
	state["deck"] = deck
	return state

## Resolve every action of `card_id` like a committed hand play and finish it.
static func _play(engine: CombatEngine, state: Dictionary, card_id: String, targets: Array = [], mode: String = "play", orientation: Vector2i = Vector2i.ZERO) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var deck: Dictionary = next_state["deck"] as Dictionary
	var hand: Array = (deck.get("hand", []) as Array).duplicate()
	hand.push_front(card_id)
	deck["hand"] = hand
	next_state["deck"] = deck
	var working: Dictionary = engine.prepare_player_card(next_state, 0, mode)
	var actions: Array = engine.card_play_actions(card_id, working)
	var cursor: int = 0
	for action_var: Variant in actions:
		var action: Dictionary = (action_var as Dictionary).duplicate(true)
		if orientation != Vector2i.ZERO and engine.player_action_needs_orientation(action):
			action["orientation"] = orientation
		var tile: Vector2i = NO_TARGET
		if engine.player_action_needs_target(action):
			tile = targets[cursor] if cursor < targets.size() else NO_TARGET
			cursor += 1
		working = engine.apply_player_action(working, action, tile)
	return engine.finish_player_card(working, 0, engine.card_plays_spent_for_actions(actions), {"play_mode": mode})

static func _action(engine: CombatEngine, card_id: String, index: int = 0, state: Dictionary = {}) -> Dictionary:
	return ((engine.card_play_actions(card_id, state) as Array)[index] as Dictionary).duplicate(true)

static func _unit(state: Dictionary, id: int) -> Dictionary:
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("id", -1)) == id:
			return enemy
	return {}

static func _hp(state: Dictionary, id: int) -> int:
	return int(_unit(state, id).get("hp", -1))

static func _paint(state: Dictionary, tiles: Array, surface: String) -> void:
	for tile_var: Variant in tiles:
		Surface.place(state, tile_var as Vector2i, surface, {"actor_kind": "test"})

static func _hand_size(state: Dictionary) -> int:
	return ((state.get("deck", {}) as Dictionary).get("hand", []) as Array).size()

## Hover forecast and commit share one resolver: compare the board they produce.
static func _preview_matches(engine: CombatEngine, state: Dictionary, action: Dictionary, target: Vector2i) -> bool:
	var preview: Dictionary = engine.surface_preview_for_player_action(state, action, target)["state"] as Dictionary
	var committed: Dictionary = engine.apply_player_action(state, action, target)
	return (
		preview.get("enemies", []) == committed.get("enemies", [])
		and preview.get("player", {}) == committed.get("player", {})
		and preview.get("surfaces", {}) == committed.get("surfaces", {})
		and preview.get("meteor_marks", []) == committed.get("meteor_marks", [])
		and preview.get("illusions", []) == committed.get("illusions", [])
	)

# ---------------------------------------------------- surface_adjacent_enemies

static func _test_surface_adjacent_enemies(engine: CombatEngine, expect: Callable) -> void:
	# (3,4) is adjacent; the 2x2 at (2,2) touches the player only through (2,3).
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(3, 4)), _enemy(2, Vector2i(2, 7)), _large(3, Vector2i(2, 2))])
	var after: Dictionary = _play(engine, state, "w4a_fx_ember_ward")
	expect.call(int((after["player"] as Dictionary).get("block", 0)) == 5, "Ember Ward still grants its Block")
	expect.call(Surface.has_surface(after, Vector2i(3, 4), "fire") and Surface.has_surface(after, Vector2i(2, 3), "fire"), "Fire is placed under each footprint tile next to the player")
	expect.call(not Surface.has_surface(after, Vector2i(3, 3), "fire") and not Surface.has_surface(after, Vector2i(2, 2), "fire"), "A 2x2 enemy's footprint tiles away from the player stay bare")
	expect.call(not Surface.has_surface(after, Vector2i(2, 7), "fire") and not Surface.has_surface(after, PLAYER, "fire"), "Distant enemies and the player's tile stay bare without include_self")
	expect.call(_hp(after, 1) == 30, "Placing Fire is not entry contact: no damage on placement")
	var static_after: Dictionary = _play(engine, state, "w4a_fx_static_ward")
	expect.call(Surface.has_surface(static_after, PLAYER, "electrified") and Surface.has_surface(static_after, Vector2i(3, 4), "electrified"), "include_self also Electrifies the player's tile")
	var icy: Dictionary = _play(engine, state, "w4a_fx_hoarfrost_ward")
	expect.call(Surface.has_surface(icy, Vector2i(3, 4), "ice") and not bool(_unit(icy, 1).get("chilled", false)), "Ice placed under an enemy does not Chill it on placement")
	var lonely: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 6))])
	var lonely_after: Dictionary = _play(engine, lonely, "w4a_fx_ember_ward")
	expect.call((lonely_after.get("surfaces", {}) as Dictionary).is_empty() and int((lonely_after["player"] as Dictionary).get("block", 0)) == 5, "With no adjacent enemy the ward only grants Block")
	var step_state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4))])
	var stepped: Dictionary = _play(engine, step_state, "w4a_fx_rime_step", [Vector2i(4, 4)])
	expect.call(Surface.has_surface(stepped, Vector2i(5, 4), "ice"), "Rime Step leaves Ice under enemies adjacent after the move")
	expect.call(_preview_matches(engine, state, _action(engine, "w4a_fx_ember_ward", 1), NO_TARGET), "Ward preview equals resolution")
	expect.call(not engine.player_action_needs_target(_action(engine, "w4a_fx_ember_ward", 1)), "surface_adjacent_enemies is targetless")

# ------------------------------------------------------------- consume riders

static func _test_consume_single_target(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4))])
	_paint(state, [Vector2i(5, 4)], "fire")
	var action: Dictionary = _action(engine, "w4a_fx_pyroclasm")
	var after: Dictionary = engine.apply_player_action(state, action, Vector2i(5, 4))
	expect.call(_hp(after, 1) == 15 and not Surface.has_surface(after, Vector2i(5, 4), "fire"), "Pyroclasm on a target on Fire deals 9 + 6 and consumes that Fire")
	var bare: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4))])
	_paint(bare, [Vector2i(6, 4)], "fire")
	var bare_after: Dictionary = engine.apply_player_action(bare, action, Vector2i(5, 4))
	expect.call(_hp(bare_after, 1) == 21 and Surface.has_surface(bare_after, Vector2i(6, 4), "fire"), "Without Fire beneath the target: base damage and other Fire is untouched")
	var large_state: Dictionary = _state(engine, [_large(1, Vector2i(5, 3))])
	_paint(large_state, [Vector2i(6, 3)], "fire")
	var large_after: Dictionary = engine.apply_player_action(large_state, action, Vector2i(5, 4))
	expect.call(_hp(large_after, 1) == 25 and not Surface.has_surface(large_after, Vector2i(6, 3), "fire"), "A 2x2 target standing on Fire with any footprint tile takes the bonus and that Fire is consumed")
	expect.call(_preview_matches(engine, state, action, Vector2i(5, 4)), "Consume preview equals resolution")

static func _test_consume_area(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4), 30, {"chilled": true}), _enemy(2, Vector2i(6, 4))])
	_paint(state, [Vector2i(5, 4), Vector2i(5, 5), Vector2i(8, 4)], "ice")
	(state["enemies"][0] as Dictionary)["chilled"] = true
	var action: Dictionary = _action(engine, "w4a_fx_flashsteam")
	var after: Dictionary = engine.apply_player_action(state, action, Vector2i(5, 4))
	expect.call(_hp(after, 1) == 21, "An enemy that stood on consumed Ice takes 3 + 4 (+2 Chilled) from the Fire area")
	expect.call(_hp(after, 2) == 27, "An enemy hit off the Ice takes only the base damage")
	expect.call(not Surface.has_surface(after, Vector2i(5, 4), "ice") and not Surface.has_surface(after, Vector2i(5, 5), "ice"), "The area consumes Ice on every pattern tile, occupied or not")
	expect.call(Surface.has_surface(after, Vector2i(8, 4), "ice"), "Ice outside the pattern stays")
	expect.call(_preview_matches(engine, state, action, Vector2i(5, 4)), "Area consume preview equals resolution")

static func _test_consume_per_hit_chain(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(4, 4)), _enemy(2, Vector2i(6, 4))])
	_paint(state, [Vector2i(4, 4), Vector2i(6, 4)], "fire")
	var after: Dictionary = engine.apply_player_action(state, _action(engine, "w4a_fx_plasma_arc"), Vector2i(4, 4))
	expect.call(_hp(after, 1) == 23 and _hp(after, 2) == 23, "per_hit: the target and the chained enemy on Fire each take 3 + 4")
	expect.call(not Surface.has_surface(after, Vector2i(4, 4), "fire") and not Surface.has_surface(after, Vector2i(6, 4), "fire"), "per_hit consumes the Fire under each enemy hit")
	var primary: Dictionary = engine.apply_player_action(state, _action(engine, "w4a_fx_arc_primary"), Vector2i(4, 4))
	expect.call(_hp(primary, 1) == 23 and _hp(primary, 2) == 27 and Surface.has_surface(primary, Vector2i(6, 4), "fire"), "Without per_hit only the primary target consumes and gains the bonus")
	expect.call(_preview_matches(engine, state, _action(engine, "w4a_fx_plasma_arc"), Vector2i(4, 4)), "per_hit consume preview equals resolution")

static func _test_consume_required(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4)), _enemy(2, Vector2i(3, 6))])
	_paint(state, [Vector2i(5, 4), Vector2i(3, 5)], "ice")
	var action: Dictionary = _action(engine, "w4a_fx_frost_heave")
	var targets: Array[Vector2i] = engine.valid_targets_for_player_action(state, action)
	expect.call(_same_tiles(targets, [Vector2i(5, 4)]), "A required consume targets only enemies standing on the surface (no bare enemies or ground)")
	var after: Dictionary = engine.apply_player_action(state, action, Vector2i(5, 4))
	expect.call(_hp(after, 1) == 24 and bool(_unit(after, 1).get("immobilize", false)), "Frost Heave deals 6 and immobilizes")
	expect.call(not Surface.has_surface(after, Vector2i(5, 4), "ice") and Surface.has_surface(after, Vector2i(5, 4), "rubble"), "The Ice is consumed, then the trailing Rubble rider is placed")
	var refused: Dictionary = engine.apply_player_action(state, action, Vector2i(3, 6))
	expect.call(_hp(refused, 2) == 30 and refused.get("surfaces", {}) == state.get("surfaces", {}), "An enemy off the surface is not a legal target")
	var large_state: Dictionary = _state(engine, [_large(1, Vector2i(5, 3))])
	_paint(large_state, [Vector2i(6, 4)], "ice")
	var large_targets: Array[Vector2i] = engine.valid_targets_for_player_action(large_state, action)
	expect.call(large_targets.size() == 4, "Any footprint tile of a 2x2 enemy on the surface is a legal click")
	expect.call(_preview_matches(engine, state, action, Vector2i(5, 4)), "Required consume preview equals resolution")

# ------------------------------------------------------------ Detonate options

static func _test_detonate_rubble_and_leave_fire(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4)), _large(2, Vector2i(6, 4))])
	_paint(state, [Vector2i(5, 4)], "rubble")
	_paint(state, [Vector2i(5, 6)], "fire")
	var action: Dictionary = _action(engine, "w4a_fx_magma_vent")
	var targets: Array[Vector2i] = engine.valid_targets_for_player_action(state, action)
	expect.call(targets.has(Vector2i(5, 4)) and not targets.has(Vector2i(5, 6)) and not targets.has(Vector2i(4, 4)), "Magma Vent targets Rubble only (not Fire or bare ground)")
	var after: Dictionary = engine.apply_player_action(state, action, Vector2i(5, 4))
	expect.call(_hp(after, 1) == 25, "The enemy on the consumed Rubble takes 5")
	expect.call(_hp(after, 2) == 35, "A 2x2 enemy touching the blast through a neighbor tile takes 5 once")
	expect.call(not Surface.has_surface(after, Vector2i(5, 4), "rubble"), "The Rubble is consumed")
	var fire_tiles: Array = [Vector2i(5, 4), Vector2i(4, 4), Vector2i(6, 4), Vector2i(5, 3), Vector2i(5, 5)]
	var all_fire: bool = true
	for tile: Vector2i in fire_tiles:
		all_fire = all_fire and Surface.has_surface(after, tile, "fire")
	expect.call(all_fire, "leave_surface places Fire on the consumed tile and its four neighbors")
	expect.call(Surface.has_surface(after, Vector2i(5, 6), "fire"), "Unrelated Fire is not detonated by a Rubble Detonate")
	expect.call(_preview_matches(engine, state, action, Vector2i(5, 4)), "Rubble Detonate preview equals resolution")

static func _test_detonate_spare_player_and_empower(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(3, 4)), _enemy(2, Vector2i(2, 6))])
	_paint(state, [PLAYER, Vector2i(3, 4), Vector2i(2, 6)], "fire")
	var after: Dictionary = _play(engine, state, "w4a_fx_immolation")
	expect.call(int((after["player"] as Dictionary).get("hp", 0)) == 40, "Immolation never damages the player, even on their own Fire")
	expect.call(_hp(after, 1) == 23, "Overlapping Fire blasts hit an enemy once")
	expect.call(not Surface.has_surface(after, PLAYER, "fire") and not Surface.has_surface(after, Vector2i(3, 4), "fire"), "Fire in the pattern is consumed")
	expect.call(Surface.has_surface(after, Vector2i(2, 6), "fire") and _hp(after, 2) == 30, "Fire outside the radius-1 pattern does not detonate")
	var self_blast: Dictionary = engine.apply_player_action(state, _action(engine, "w4a_fx_self_blast"), NO_TARGET)
	expect.call(int((self_blast["player"] as Dictionary).get("hp", 0)) < 40, "Without spare_player the player is caught in their own blast")
	var empowered: Dictionary = _play(engine, state, "w4a_fx_immolation", [], "empower")
	expect.call(_hp(empowered, 2) < 30 and not Surface.has_surface(empowered, Vector2i(2, 6), "fire"), "Empowered Immolation widens the pattern to radius 2")
	expect.call(int((empowered["player"] as Dictionary).get("hp", 0)) == 38, "Empower pays its 2 HP but the blast still spares the player")
	expect.call(_preview_matches(engine, state, _action(engine, "w4a_fx_immolation"), NO_TARGET), "Immolation preview equals resolution")

# ---------------------------------------------------------- convert / discharge

static func _test_convert_surface(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4)), _enemy(2, Vector2i(8, 4)), _large(3, Vector2i(5, 1))])
	_paint(state, [Vector2i(4, 4), Vector2i(5, 4), Vector2i(5, 3), Vector2i(5, 2), Vector2i(8, 4), Vector2i(3, 6)], "ice")
	var action: Dictionary = _action(engine, "w4a_fx_frost_circuit")
	var targets: Array[Vector2i] = engine.valid_targets_for_player_action(state, action)
	expect.call(targets.has(Vector2i(4, 4)) and targets.has(Vector2i(3, 6)) and not targets.has(Vector2i(3, 4)) and not targets.has(Vector2i(8, 4)), "Frost Circuit targets Ice within range 3 only")
	var after: Dictionary = engine.apply_player_action(state, action, Vector2i(4, 4))
	var converted: bool = true
	for tile: Vector2i in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(5, 3), Vector2i(5, 2)]:
		converted = converted and Surface.has_surface(after, tile, "electrified")
	expect.call(converted, "The chosen Ice and all cardinally connected Ice become Electrified")
	expect.call(Surface.has_surface(after, Vector2i(8, 4), "ice") and Surface.has_surface(after, Vector2i(3, 6), "ice"), "Disconnected Ice stays Ice")
	expect.call(_hp(after, 1) == 28 and int(_unit(after, 1).get("shock", 0)) == 1, "Each enemy on a converted tile takes 2 Lightning and is Shocked")
	expect.call(_hp(after, 3) == 38 and int(_unit(after, 3).get("shock", 0)) == 1, "A 2x2 enemy on the converted network is struck once")
	expect.call(_hp(after, 2) == 30, "An enemy on disconnected Ice is untouched")
	var refused: Dictionary = engine.apply_player_action(state, action, Vector2i(3, 4))
	expect.call(refused.get("surfaces", {}) == state.get("surfaces", {}), "A bare tile is not a legal Frost Circuit target")
	expect.call(_preview_matches(engine, state, action, Vector2i(4, 4)), "Frost Circuit preview equals resolution")

static func _test_discharge(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4)), _enemy(2, Vector2i(5, 5)), _enemy(3, Vector2i(7, 7)), _large(4, Vector2i(4, 2))])
	_paint(state, [Vector2i(4, 4), Vector2i(5, 4), Vector2i(8, 7)], "electrified")
	var action: Dictionary = _action(engine, "w4a_fx_discharge")
	var targets: Array[Vector2i] = engine.valid_targets_for_player_action(state, action)
	expect.call(targets.has(Vector2i(4, 4)) and targets.has(Vector2i(5, 4)) and not targets.has(Vector2i(3, 4)), "Discharge targets Electrified tiles only")
	var after: Dictionary = engine.apply_player_action(state, action, Vector2i(4, 4))
	expect.call(_hp(after, 1) == 26 and _hp(after, 2) == 26, "Enemies on or next to the network take 4 once")
	expect.call(_hp(after, 4) == 36, "A 2x2 enemy next to the network through two footprint tiles takes 4 once")
	expect.call(_hp(after, 3) == 30, "An enemy next to a different network is untouched")
	expect.call(not Surface.has_surface(after, Vector2i(4, 4), "electrified") and not Surface.has_surface(after, Vector2i(5, 4), "electrified"), "The discharged network is removed")
	expect.call(Surface.has_surface(after, Vector2i(8, 7), "electrified"), "A separate network remains")
	expect.call(_preview_matches(engine, state, action, Vector2i(4, 4)), "Discharge preview equals resolution")

static func _test_consume_surface_per_tile(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(8, 8))])
	_paint(state, [Vector2i(3, 4), Vector2i(2, 6), Vector2i(1, 5), Vector2i(6, 4)], "electrified")
	var after: Dictionary = _play(engine, state, "w4a_fx_grounding")
	expect.call(int((after["player"] as Dictionary).get("stoneskin", 0)) == 6, "Grounding grants 2 Stoneskin per Electrified tile removed within 2")
	expect.call(not Surface.has_surface(after, Vector2i(3, 4), "electrified") and Surface.has_surface(after, Vector2i(6, 4), "electrified"), "Only tiles within 2 of the player are removed")
	var many: Dictionary = _state(engine, [_enemy(1, Vector2i(8, 8))])
	_paint(many, [Vector2i(3, 4), Vector2i(1, 4), Vector2i(2, 3), Vector2i(2, 5), Vector2i(4, 4), Vector2i(3, 3)], "electrified")
	var capped: Dictionary = _play(engine, many, "w4a_fx_grounding")
	expect.call(int((capped["player"] as Dictionary).get("stoneskin", 0)) == 8, "The per-tile reward is capped at its maximum")
	var none: Dictionary = _play(engine, _state(engine, [_enemy(1, Vector2i(8, 8))]), "w4a_fx_grounding")
	expect.call(int((none["player"] as Dictionary).get("stoneskin", 0)) == 0, "With nothing to remove Grounding grants nothing")
	expect.call(_preview_matches(engine, many, _action(engine, "w4a_fx_grounding"), NO_TARGET), "Per-tile reward preview equals resolution")

# ------------------------------------------------------------------ on_result

static func _test_on_result_froze(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4)), _enemy(2, Vector2i(4, 6))])
	_paint(state, [Vector2i(5, 4)], "ice")
	(state["enemies"][0] as Dictionary)["chilled"] = true
	var after: Dictionary = _play(engine, state, "w4a_fx_hush", [Vector2i(5, 4)])
	expect.call(int(_unit(after, 1).get("freeze", 0)) > 0, "Hush of Winter Freezes the Chilled target")
	expect.call(_hand_size(after) == 2, "Freezing the target draws 2")
	var miss: Dictionary = _play(engine, state, "w4a_fx_hush", [Vector2i(4, 6)])
	expect.call(_hand_size(miss) == 0, "A hit that does not Freeze draws nothing")
	var frozen: Dictionary = state.duplicate(true)
	(frozen["enemies"][0] as Dictionary)["freeze"] = 1
	(frozen["enemies"][0] as Dictionary)["chilled"] = false
	var already: Dictionary = _play(engine, frozen, "w4a_fx_hush", [Vector2i(5, 4)])
	expect.call(_hand_size(already) == 0, "A target that was already Frozen does not count as Frozen by this hit")
	var bite_state: Dictionary = _state(engine, [_enemy(1, Vector2i(3, 4))])
	_paint(bite_state, [Vector2i(3, 4)], "ice")
	(bite_state["enemies"][0] as Dictionary)["chilled"] = true
	var bitten: Dictionary = _play(engine, bite_state, "w4a_fx_frozen_bite", [Vector2i(3, 4)])
	expect.call(int(bitten.get("card_play_bonus_this_turn", 0)) == 1, "Frozen Bite grants 1 card play when it Freezes")
	var hush_action: Dictionary = _action(engine, "w4a_fx_hush")
	expect.call(_preview_matches(engine, state, hush_action, Vector2i(5, 4)), "on_result preview equals resolution")
	var events: Array = (after.get("surface_events", []) as Array).filter(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "card_result_reward")
	expect.call(events.size() == 1 and str((events[0] as Dictionary).get("when", "")) == "froze", "The reward records a card_result_reward surface event")

static func _test_on_result_killed(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4), 3), _enemy(2, Vector2i(4, 5), 20)])
	var after: Dictionary = _play(engine, state, "w4a_fx_headsman", [Vector2i(5, 4)])
	expect.call(_hp(after, 1) == 0, "Headsman's Toll kills a 3 HP target")
	expect.call(int(after.get("card_play_bonus_this_turn", 0)) == 1 and int(after.get("death_bonus_card_plays_this_turn", 0)) == 1, "A kill grants the reward play on top of the normal kill play")
	expect.call(_hand_size(after) == 1, "A kill also draws 1")
	var survived: Dictionary = _play(engine, state, "w4a_fx_headsman", [Vector2i(4, 5)])
	expect.call(int(survived.get("card_play_bonus_this_turn", 0)) == 0 and _hand_size(survived) == 0, "No kill, no reward")
	expect.call(_preview_matches(engine, state, _action(engine, "w4a_fx_headsman"), Vector2i(5, 4)), "Kill reward preview equals resolution")

# -------------------------------------------------------------- frozen_splash

static func _test_frozen_splash(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4), 30, {"freeze": 1}), _enemy(2, Vector2i(6, 4), 30, {"freeze": 1}), _enemy(3, Vector2i(5, 5)), _enemy(4, Vector2i(7, 4)), _large(5, Vector2i(3, 2))])
	# The 2x2 at (3,2) covers (4,3): diagonal to (5,4), so it is not adjacent.
	var action: Dictionary = _action(engine, "w4a_fx_shatter")
	var after: Dictionary = engine.apply_player_action(state, action, Vector2i(5, 4))
	expect.call(_hp(after, 1) == 15, "The Frozen target takes the tripled hit")
	expect.call(_hp(after, 2) == 25 and _hp(after, 3) == 25, "Each other enemy next to it takes 5, not tripled even if Frozen")
	expect.call(_hp(after, 4) == 30 and _hp(after, 5) == 40, "Enemies not orthogonally adjacent to the target are untouched")
	var thawed: Dictionary = state.duplicate(true)
	(thawed["enemies"][0] as Dictionary)["freeze"] = 0
	var plain: Dictionary = engine.apply_player_action(thawed, action, Vector2i(5, 4))
	expect.call(_hp(plain, 2) == 30 and _hp(plain, 3) == 30, "No splash when the target was not Frozen before the hit")
	var large_state: Dictionary = _state(engine, [_enemy(1, Vector2i(3, 4), 30, {"freeze": 1}), _large(2, Vector2i(4, 3))])
	var swung: Dictionary = engine.apply_player_action(large_state, _action(engine, "w4a_fx_shatter_swing"), Vector2i(3, 4))
	expect.call(_hp(swung, 2) == 36, "A 2x2 neighbor is splashed once")
	expect.call(_preview_matches(engine, state, action, Vector2i(5, 4)), "Shatter preview equals resolution")

# ------------------------------------------------------------------ selectors

static func _test_all_enemies_selectors(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4)), _enemy(2, Vector2i(7, 6)), _enemy(3, Vector2i(4, 7)), _large(4, Vector2i(7, 1))])
	_paint(state, [Vector2i(5, 4), Vector2i(7, 6), Vector2i(8, 2)], "fire")
	var stoke: Dictionary = _action(engine, "w4a_fx_stoke")
	expect.call(not engine.player_action_needs_target(stoke), "all_enemies is targetless")
	var after: Dictionary = engine.apply_player_action(state, stoke, NO_TARGET)
	expect.call(_hp(after, 1) == 27 and _hp(after, 2) == 27, "Stoke hits each enemy standing on Fire")
	expect.call(_hp(after, 3) == 30, "An enemy off the Fire is untouched")
	expect.call(_hp(after, 4) == 37, "A 2x2 enemy with one footprint tile on Fire is hit once")
	expect.call(_preview_matches(engine, state, stoke, NO_TARGET), "Selector preview equals resolution (every affected enemy appears)")
	var bare: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4))])
	expect.call(not engine.player_action_can_resolve(bare, stoke), "With no matching enemy the selector cannot resolve")
	expect.call(engine.player_action_can_resolve(state, stoke), "With a matching enemy the selector resolves")
	var chill: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4)), _enemy(2, Vector2i(5, 6))])
	_paint(chill, [Vector2i(5, 4)], "ice")
	(chill["enemies"][0] as Dictionary)["chilled"] = true
	var silenced: Dictionary = engine.apply_player_action(chill, _action(engine, "w4a_fx_white_silence"), NO_TARGET)
	expect.call(_hp(silenced, 1) == 24 and int(_unit(silenced, 1).get("freeze", 0)) > 0, "White Silence deals 4 Ice (+2 Chilled) to each Chilled enemy and Freezes it")
	expect.call(_hp(silenced, 2) == 30, "A non-Chilled enemy is untouched")
	expect.call(_preview_matches(engine, chill, _action(engine, "w4a_fx_white_silence"), NO_TARGET), "White Silence preview equals resolution")
	var lit: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 4)), _enemy(2, Vector2i(6, 8))])
	lit = engine._create_umbra_light_source(lit, Vector2i(6, 4), {"radius": 1, "duration": 2})
	var seared: Dictionary = engine.apply_player_action(lit, _action(engine, "w4a_fx_searing"), NO_TARGET)
	expect.call(_hp(seared, 1) == 27 and _hp(seared, 2) == 30, "Searing Light hits only enemies in Light")
	var charged: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 4)), _enemy(2, Vector2i(6, 6))])
	_paint(charged, [Vector2i(6, 4)], "electrified")
	var swept: Dictionary = engine.apply_player_action(charged, _action(engine, "w4a_fx_static_sweep"), NO_TARGET)
	expect.call(_hp(swept, 1) == 28 and _hp(swept, 2) == 30, "on_electrified hits only enemies on Electrified ground (no conduction)")

static func _test_all_enemies_visibility_and_range(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(4, 4)), _enemy(2, Vector2i(8, 4))])
	_paint(state, [Vector2i(4, 4), Vector2i(8, 4)], "fire")
	var umbra: Dictionary = (state.get("umbra", {}) as Dictionary).duplicate(true)
	umbra["stage"] = "heart"
	state["umbra"] = umbra
	expect.call(not engine.is_enemy_visible_to_player(state, _unit(state, 2)), "Fixture: the far enemy is hidden by the Umbra")
	var after: Dictionary = engine.apply_player_action(state, _action(engine, "w4a_fx_stoke"), NO_TARGET)
	expect.call(_hp(after, 1) == 27 and _hp(after, 2) == 30, "An Umbra-hidden enemy is never selected")
	var glare_state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4)), _enemy(2, Vector2i(9, 4))])
	glare_state = engine._create_umbra_light_source(glare_state, Vector2i(5, 4), {"radius": 1, "duration": 2})
	glare_state = engine._create_umbra_light_source(glare_state, Vector2i(9, 4), {"radius": 1, "duration": 2})
	var glared: Dictionary = _play(engine, glare_state, "w4a_fx_glare")
	expect.call(int(_unit(glared, 1).get("expose", 0)) == 3 and _hp(glared, 1) == 30, "Revealing Glare Exposes a lit enemy within 4 without damaging it")
	expect.call(int(_unit(glared, 2).get("expose", 0)) == 0, "A lit enemy beyond range 4 is not selected")
	expect.call(_hand_size(glared) == 1, "Revealing Glare still draws")

# ------------------------------------------------- ignore_los / shock_all_hits

static func _test_ignore_los_and_shock_all_hits(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(8, 4)), _enemy(2, Vector2i(9, 4))])
	var grid: Array = (state["grid"] as Array).duplicate(true)
	for y: int in range(1, 9):
		(grid[y] as Array)[5] = "wall"
	state["grid"] = grid
	var blocked: Array[Vector2i] = engine.valid_targets_for_player_action(state, _action(engine, "w4a_fx_longshot"))
	expect.call(not blocked.has(Vector2i(8, 4)), "Fixture: a wall blocks line of sight to the enemy")
	var skybolt: Dictionary = _action(engine, "w4a_fx_skybolt")
	var targets: Array[Vector2i] = engine.valid_targets_for_player_action(state, skybolt)
	expect.call(targets.has(Vector2i(8, 4)), "ignore_los targets any visible enemy regardless of line of sight")
	var after: Dictionary = engine.apply_player_action(state, skybolt, Vector2i(8, 4))
	expect.call(_hp(after, 1) == 22 and int(_unit(after, 1).get("shock", 0)) == 1, "Skybolt strikes through the wall and Shocks")
	var stone: Dictionary = engine.apply_player_action(state, _action(engine, "w4a_fx_thunderstone"), Vector2i(8, 4))
	expect.call(_hp(stone, 1) == 25, "Thunderstone also ignores line of sight")
	var dark: Dictionary = state.duplicate(true)
	var umbra: Dictionary = (dark.get("umbra", {}) as Dictionary).duplicate(true)
	umbra["stage"] = "heart"
	dark["umbra"] = umbra
	expect.call(not engine.valid_targets_for_player_action(dark, skybolt).has(Vector2i(8, 4)), "ignore_los never reaches an Umbra-hidden enemy")
	var network: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4)), _enemy(2, Vector2i(7, 4))])
	_paint(network, [Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4)], "electrified")
	var conducted: Dictionary = engine.apply_player_action(network, skybolt, Vector2i(5, 4))
	expect.call(int(_unit(conducted, 1).get("shock", 0)) == 1 and int(_unit(conducted, 2).get("shock", 0)) == 1, "shock_all_hits Shocks conducted hits too")
	var unshocked: Dictionary = skybolt.duplicate(true)
	unshocked["shock"] = 0
	var forced: Dictionary = engine.apply_player_action(network, unshocked, Vector2i(5, 4))
	expect.call(int(_unit(forced, 2).get("shock", 0)) == 1, "shock_all_hits Shocks every hit even without a printed Shock")
	expect.call(_preview_matches(engine, state, skybolt, Vector2i(8, 4)), "ignore_los preview equals resolution")
	var walled_large: Dictionary = state.duplicate(true)
	walled_large["enemies"] = [_large(1, Vector2i(7, 2))]
	var large_targets: Array[Vector2i] = engine.valid_targets_for_player_action(walled_large, skybolt)
	expect.call(large_targets.has(Vector2i(7, 2)) and large_targets.has(Vector2i(8, 3)), "Every footprint tile of a 2x2 enemy behind the wall is a legal ignore_los click")

# --------------------------------------------------------------- meteor marks

static func _test_meteor_marks_place_and_resolve(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(4, 4)), _large(2, Vector2i(5, 4)), _enemy(3, Vector2i(4, 6))], Vector2i(3, 4))
	state["terrain"] = [{"id": "crate", "kind": "wooden_crate", "pos": Vector2i(5, 6), "hp": 10, "max_hp": 10}]
	state = engine._create_illusion(state, Vector2i(3, 6), 10)
	var action: Dictionary = _action(engine, "w4a_fx_meteorfall")
	expect.call(engine.player_action_needs_target(action) and engine.player_action_needs_orientation(action), "Meteorfall is aimed with the area Rotate UI")
	var targets: Array[Vector2i] = engine.valid_targets_for_player_action(state, action)
	expect.call(targets.has(Vector2i(4, 5)) and not targets.has(Vector2i(3, 4)), "Meteorfall targets tiles in range, not the player's own tile")
	action["orientation"] = RIGHT
	var marked: Dictionary = engine.apply_player_action(state, action, Vector2i(4, 4))
	var marks: Array = SurfaceCardRules.meteor_marks(marked)
	expect.call(marks.size() == 1 and _same_tiles(SurfaceCardRules.meteor_mark_tiles(engine, marked), [Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4)]), "The oriented three-tile line is marked")
	expect.call(_hp(marked, 1) == 30 and not Surface.has_surface(marked, Vector2i(4, 4), "fire"), "Nothing is damaged or set alight until the next player turn")
	var vertical: Dictionary = action.duplicate(true)
	vertical["orientation"] = DOWN
	var vertical_marked: Dictionary = engine.apply_player_action(state, vertical, Vector2i(4, 5))
	expect.call(_same_tiles(SurfaceCardRules.meteor_mark_tiles(engine, vertical_marked), [Vector2i(4, 4), Vector2i(4, 5), Vector2i(4, 6)]), "Rotation changes the marked line")
	expect.call(_preview_matches(engine, state, action, Vector2i(4, 4)), "Meteorfall placement preview equals resolution")
	# Resolve at the start of the next player turn (before drawing).
	var line: Dictionary = engine.apply_player_action(state, vertical, Vector2i(4, 5))
	var next_turn: Dictionary = engine.prepare_next_player_turn(engine.finish_player_activation(line))
	expect.call(_hp(next_turn, 1) == 22 and _hp(next_turn, 3) == 22, "Each enemy on a marked tile takes 8")
	expect.call(SurfaceCardRules.meteor_marks(next_turn).is_empty(), "Marks clear after landing")
	expect.call(Surface.has_surface(next_turn, Vector2i(4, 5), "fire") and Surface.has_surface(next_turn, Vector2i(4, 6), "fire"), "Each marked tile becomes Fire")
	var big: Dictionary = engine.prepare_next_player_turn(engine.finish_player_activation(marked))
	expect.call(_hp(big, 2) == 32, "A 2x2 enemy covering a marked tile takes 8 once")
	expect.call(int((big["player"] as Dictionary).get("hp", 0)) == 32, "The player standing on a marked tile is struck too")
	var hazard: Dictionary = action.duplicate(true)
	hazard["orientation"] = RIGHT
	var crate_line: Dictionary = engine.apply_player_action(state, hazard, Vector2i(5, 6))
	var crate_after: Dictionary = engine.prepare_next_player_turn(engine.finish_player_activation(crate_line))
	var crate_hp: int = -1
	for terrain: Dictionary in crate_after.get("terrain", []):
		if str(terrain.get("id", "")) == "crate":
			crate_hp = int(terrain.get("hp", 0))
	expect.call(crate_hp == 2, "Terrain on a marked tile takes the damage")
	var illusion_line: Dictionary = engine.apply_player_action(state, vertical, Vector2i(3, 6))
	var illusion_after: Dictionary = engine.prepare_next_player_turn(engine.finish_player_activation(illusion_line))
	var illusion_hp: int = -1
	for illusion: Dictionary in illusion_after.get("illusions", []):
		illusion_hp = int(illusion.get("hp", 0))
	expect.call(illusion_hp == 2, "An illusion on a marked tile takes the damage (10 health leaves 2)")

static func _test_meteor_marks_persistence(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4), 6), _enemy(2, Vector2i(8, 8))])
	var action: Dictionary = _action(engine, "w4a_fx_meteorfall")
	action["orientation"] = RIGHT
	var marked: Dictionary = engine.apply_player_action(state, action, Vector2i(5, 4))
	var scheduled: Dictionary = engine.finish_player_activation(marked)
	expect.call(SurfaceCardRules.meteor_marks(scheduled).size() == 1, "Marks survive the end of the player's activation")
	var enemy_turn: Dictionary = engine.resolve_enemy_turn_with_steps(scheduled, 1)
	expect.call(SurfaceCardRules.meteor_marks(enemy_turn.get("state", {}) as Dictionary).size() == 1, "Marks persist through enemy turns")
	var restored: Dictionary = bytes_to_var(var_to_bytes(scheduled)) as Dictionary
	expect.call(SurfaceCardRules.meteor_marks(restored) == SurfaceCardRules.meteor_marks(scheduled), "Save/resume (store_var round trip) preserves the marks")
	var landed: Dictionary = engine.prepare_next_player_turn(restored)
	expect.call(_hp(landed, 1) == 0, "Restored marks land at the next player turn")
	# The only other enemy dies too: combat ends before the draw.
	var sole: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4), 6)])
	var sole_marked: Dictionary = engine.apply_player_action(sole, action, Vector2i(5, 4))
	var victory: Dictionary = engine.prepare_next_player_turn(engine.finish_player_activation(sole_marked))
	expect.call(engine.combat_outcome(victory) == "victory" and _hand_size(victory) == 0, "Marks land before the draw: a winning impact ends combat with no draw")
	var ended: Dictionary = sole_marked.duplicate(true)
	(ended["enemies"][0] as Dictionary)["hp"] = 0
	var untouched: Dictionary = engine.prepare_next_player_turn(engine.finish_player_activation(ended))
	expect.call(SurfaceCardRules.meteor_marks(untouched).size() == 1 and not Surface.has_surface(untouched, Vector2i(5, 4), "fire"), "Nothing happens if combat ends first")
	# Presentation: the impact animates as a status_damage step at turn start.
	var before_turn: Dictionary = engine.finish_player_activation(engine.apply_player_action(_state(engine, [_enemy(1, Vector2i(5, 4)), _enemy(2, Vector2i(9, 8))]), action, Vector2i(5, 4)))
	var steps: Array[Dictionary] = SurfaceCardRules.turn_start_presentation_steps(engine, before_turn, engine.prepare_next_player_turn(before_turn))
	expect.call(steps.size() == 1 and str(steps[0].get("kind", "")) == "status_damage" and not (steps[0].get("enemy_losses", []) as Array).is_empty(), "The landing presents as a status_damage step carrying losses")

static func _test_surface_follows_facing(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(3, 4)), _enemy(2, Vector2i(2, 3))])
	var action: Dictionary = _action(engine, "w4a_fx_fault_strike")
	var east: Dictionary = engine.apply_player_action(state, action, Vector2i(3, 4))
	expect.call(Surface.has_surface(east, Vector2i(3, 4), "rubble") and Surface.has_surface(east, Vector2i(4, 4), "rubble") and Surface.has_surface(east, Vector2i(5, 4), "rubble") and not Surface.has_surface(east, PLAYER, "rubble"), "Fault Strike leaves Rubble on the target and the two tiles behind it")
	var north: Dictionary = engine.apply_player_action(state, action, Vector2i(2, 3))
	expect.call(Surface.has_surface(north, Vector2i(2, 3), "rubble") and Surface.has_surface(north, Vector2i(2, 2), "rubble") and Surface.has_surface(north, Vector2i(2, 1), "rubble"), "The pattern follows the attack direction")
	var plain: Dictionary = engine.apply_player_action(state, _action(engine, "w4a_fx_fault_plain"), Vector2i(3, 4))
	expect.call(not Surface.has_surface(plain, Vector2i(5, 4), "rubble"), "Without surface_follows_facing the pattern is centred as before")
	var large_state: Dictionary = _state(engine, [_large(1, Vector2i(3, 3))])
	var large: Dictionary = engine.apply_player_action(large_state, action, Vector2i(3, 4))
	expect.call(Surface.has_surface(large, Vector2i(3, 4), "rubble") and Surface.has_surface(large, Vector2i(5, 4), "rubble"), "Against a 2x2 enemy the line starts at the struck footprint tile")
	expect.call(_preview_matches(engine, state, action, Vector2i(2, 3)), "Fault Strike preview equals resolution")

static func _test_zero_damage_areas(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 5)), _enemy(2, Vector2i(9, 8))])
	var flash: Dictionary = _action(engine, "w4a_fx_flash_powder")
	expect.call(engine.valid_targets_for_player_action(state, flash).has(Vector2i(5, 4)), "An empty tile is a legal zero-damage area target")
	var flashed: Dictionary = engine.apply_player_action(state, flash, Vector2i(5, 4))
	expect.call(int(_unit(flashed, 1).get("expose", 0)) == 2 and _hp(flashed, 1) == 30, "Flash Powder Exposes enemies in the area without damage")
	var lit: bool = false
	for source: Dictionary in ((flashed.get("umbra", {}) as Dictionary).get("light_sources", []) as Array):
		lit = lit or (source.get("pos", NO_TARGET) == Vector2i(5, 4) and int(source.get("radius", 0)) == 3)
	expect.call(lit, "Flash Powder creates radius-3 Light at the chosen tile")
	var caltrops: Dictionary = _action(engine, "w4a_fx_caltrops")
	var spike_state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4)), _enemy(2, Vector2i(9, 8))])
	expect.call(engine.valid_targets_for_player_action(spike_state, caltrops).has(Vector2i(4, 4)), "Caltrops can target an empty tile")
	var spiked: Dictionary = engine.apply_player_action(spike_state, caltrops, Vector2i(4, 4))
	expect.call(int(_unit(spiked, 1).get("bleed", 0)) == 2 and _hp(spiked, 1) == 30, "Caltrops Bleeds enemies in the cross without damage")
	expect.call(Surface.has_surface(spiked, Vector2i(4, 4), "rubble") and Surface.has_surface(spiked, Vector2i(5, 4), "rubble") and Surface.has_surface(spiked, Vector2i(4, 3), "rubble"), "Caltrops leaves Rubble across the cross")
	expect.call(_preview_matches(engine, spike_state, caltrops, Vector2i(4, 4)), "Zero-damage area preview equals resolution")

# ------------------------------------------------------------- UI contracts

static func _token_with_icon(rows: Array, icon: String) -> Dictionary:
	for row_var: Variant in rows:
		for token_var: Variant in row_var as Array:
			if typeof(token_var) == TYPE_DICTIONARY and str((token_var as Dictionary).get("icon", "")) == icon:
				return token_var as Dictionary
	return {}

static func _test_presentation_contracts(engine: CombatEngine, expect: Callable) -> void:
	for card_id: String in ["w4a_fx_ember_ward", "w4a_fx_frost_circuit", "w4a_fx_discharge", "w4a_fx_stoke", "w4a_fx_meteorfall"]:
		var action: Dictionary = _action(engine, card_id, 1 if card_id == "w4a_fx_ember_ward" else 0)
		expect.call(not ActionIcons.action_icon_key(action).is_empty(), "%s resolves through ACTION_ICON_ALIASES" % str(action.get("type", "")))
		expect.call(not ActionIcons.tokens_for_action(action).is_empty(), "%s renders icon tokens" % str(action.get("type", "")))
	expect.call(ActionIcons.action_icon_key({"type": "meteor_marks"}) == "cinder_marks", "Meteorfall shares the dragon Meteorfall identity")
	for pair: Array in [["convert_surface", "surface_convert"], ["discharge", "discharge"], ["all_enemies", "all_enemies"]]:
		expect.call(ActionIcons.action_icon_key({"type": pair[0]}) == pair[1], "%s uses its purpose-built %s icon" % [pair[0], pair[1]])
	var discharge_row: Array = ActionIcons.tokens_for_action(_action(engine, "w4a_fx_discharge"))
	expect.call(str((discharge_row[0] as Dictionary).get("icon", "")) == "discharge", "Discharge rows lead with the Discharge icon")
	for role_pair: Array in [["w4a_fx_stoke", "attack_ranged"], ["w4a_fx_discharge", "attack_ranged"], ["w4a_fx_frost_circuit", "attack_ranged"], ["w4a_fx_meteorfall", "attack_ranged"], ["w4a_fx_ember_ward", "block"], ["w4a_fx_rime_step", "mobility"]]:
		expect.call(ActionIcons.card_role_emblem_key(GameData.card_def(str(role_pair[0]))) == str(role_pair[1]), "%s uses the %s role emblem" % [str(role_pair[0]), str(role_pair[1])])
	var ward_row: Array = ActionIcons.tokens_for_action(_action(engine, "w4a_fx_ember_ward", 1))
	expect.call(str((ward_row[0] as Dictionary).get("icon", "")) == "surface_fire", "Ward rows lead with the placed surface")
	var stoke_row: Array = ActionIcons.tokens_for_action(_action(engine, "w4a_fx_stoke"))
	expect.call(str((stoke_row[0] as Dictionary).get("kind", "")) == "surface_condition" and str((stoke_row[0] as Dictionary).get("icon", "")) == "surface_fire", "Selector rows lead with the selector condition")
	var consume_rows: Array = ActionIcons.keyword_rider_rows(_action(engine, "w4a_fx_pyroclasm"))
	expect.call(not _token_with_icon(consume_rows, "surface_consume").is_empty(), "Consume riders render a Consume Surface token")
	var result_rows: Array = ActionIcons.keyword_rider_rows(_action(engine, "w4a_fx_headsman"))
	expect.call(not _token_with_icon(result_rows, "card_play").is_empty() and not _token_with_icon(result_rows, "draw").is_empty(), "on_result rows list their rewards")
	var splash_rows: Array = ActionIcons.keyword_rider_rows(_action(engine, "w4a_fx_shatter"))
	expect.call(not _token_with_icon(splash_rows, "aoe").is_empty(), "frozen_splash renders its splash damage")
	var sky_row: Array = ActionIcons.tokens_for_action(_action(engine, "w4a_fx_skybolt"))
	expect.call(str(_token_with_icon([sky_row], "range").get("value", "")) == "∞", "Unlimited ignore_los range shows as infinite")
	var vent_row: Array = ActionIcons.tokens_for_action(_action(engine, "w4a_fx_magma_vent"))
	expect.call(not _token_with_icon([vent_row], "surface_rubble").is_empty() and not _token_with_icon([vent_row], "surface_fire").is_empty(), "Detonate rows show the Rubble fuel and the Fire left behind")
	var meteor_row: Array = ActionIcons.tokens_for_action(_action(engine, "w4a_fx_meteorfall"))
	var surface_tokens: int = 0
	for token: Dictionary in meteor_row:
		if str(token.get("icon", "")) == "surface_fire":
			surface_tokens += 1
	expect.call(surface_tokens == 1, "Own-surface types render their surface once, not as a trailing rider")
	expect.call(GrimoireLibrary.entry_ids_for_card_def(GameData.card_def("w4a_fx_frost_circuit")).has("combat:surface_techniques"), "Frost Circuit unlocks Surface Techniques")
	expect.call(GrimoireLibrary.entry_ids_for_card_def(GameData.card_def("w4a_fx_discharge")).has("keyword:surface_electrified"), "Discharge unlocks Electrified Tiles")
	expect.call(GrimoireLibrary.entry_ids_for_card_def(GameData.card_def("w4a_fx_white_silence")).has("combat:sweeping_strikes"), "Selector cards unlock Sweeping Strikes")
	expect.call(GrimoireLibrary.entry_ids_for_card_def(GameData.card_def("w4a_fx_meteorfall")).has("combat:cinder_marks"), "Meteorfall unlocks the Meteorfall entry")
	expect.call(GrimoireLibrary.entry_ids_for_card_def(GameData.card_def("w4a_fx_pyroclasm")).has("combat:surface_techniques"), "Consume riders unlock Surface Techniques")
	for entry_id: String in ["combat:surface_techniques", "combat:sweeping_strikes"]:
		expect.call(GrimoireLibrary.entry_map().has(entry_id), "%s exists in the grimoire" % entry_id)

static func _test_run_scene_contracts(engine: CombatEngine, expect: Callable) -> void:
	var scene: Node = RunSceneScript.new()
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4))])
	var stoke_display: Dictionary = scene.call("_card_widget_display", "w4a_fx_stoke", state)
	expect.call(int(_token_with_icon(stoke_display.get("summary_rows", []) as Array, "all_enemies").get("value", 0)) == 3, "The hand row shows the selector damage")
	var discharge_display: Dictionary = scene.call("_card_widget_display", "w4a_fx_discharge", state)
	expect.call(int(_token_with_icon(discharge_display.get("summary_rows", []) as Array, "aoe").get("value", 0)) == 4, "The hand row shows Discharge damage")
	var meteor_display: Dictionary = scene.call("_card_widget_display", "w4a_fx_meteorfall", state)
	expect.call(not _token_with_icon(meteor_display.get("summary_rows", []) as Array, "cinder_marks").is_empty(), "The hand row shows the Meteorfall mark")
	var meteor: Dictionary = _action(engine, "w4a_fx_meteorfall")
	scene.set("_aoe_aim_orientation", DOWN)
	var aimed: Dictionary = scene.call("_action_with_aoe_aim_orientation", meteor)
	expect.call(aimed.get("orientation", Vector2i.ZERO) == DOWN, "Meteorfall takes the area aim orientation (Rotate UI)")
	var hover_tiles: Array = scene.call("_aoe_tiles_for_action", state, aimed, Vector2i(4, 5))
	var committed: Dictionary = engine.apply_player_action(state, aimed, Vector2i(4, 5))
	expect.call(_typed_tiles(hover_tiles) == SurfaceCardRules.meteor_mark_tiles(engine, committed), "The hover footprint equals the committed marks")
	expect.call(str(scene.call("_action_step_action_name", meteor)) == "Meteorfall" and str(scene.call("_action_step_action_name", _action(engine, "w4a_fx_discharge"))) == "Discharge", "Action context names the new steps")
	scene.free()

static func _same_tiles(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for tile: Variant in expected:
		if not actual.has(tile):
			return false
	return true

static func _typed_tiles(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i]
	for value: Variant in values:
		if typeof(value) == TYPE_VECTOR2I:
			result.append(value)
	return result

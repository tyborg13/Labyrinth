extends RefCounted

## Card pool overhaul wave 4, family C: illusion and terrain mechanics, with
## injected fixture cards (data/cards.json is untouched).
## See spec/card_mechanics_illusions_terrain.md.

const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const ElementData = preload("res://scripts/element_data.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const GrimoireLibrary = preload("res://scripts/grimoire_library.gd")
const CardKeywordRules = preload("res://scripts/card_keyword_rules.gd")
const IllusionCardRules = preload("res://scripts/illusion_card_rules.gd")
const TerrainCardRules = preload("res://scripts/terrain_card_rules.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")

const NO_TARGET: Vector2i = Vector2i(-1, -1)
const PLAYER_TILE: Vector2i = Vector2i(2, 4)
const ADJ: Array = [[0, -1], [1, 0], [0, 1], [-1, 0]]
const CROSS: Array = [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]]
const LINE3: Array = [[0, 0], [1, 0], [2, 0]]

const FIXTURES: Dictionary = {
	"w4c_fx_ice_sculpture": {"element": "ice", "time": 5, "actions": [{"type": "illusion", "health": 4, "range": 3, "surface_ring": "ice"}]},
	"w4c_fx_ball_lightning": {"element": "lightning", "time": 4, "actions": [{"type": "illusion", "health": 3, "range": 3, "surface": "electrified", "on_damaged": {"damage": 4, "element": "lightning", "shock": 1}}]},
	"w4c_fx_reflected_threat": {"time": 5, "actions": [{"type": "illusion", "health": 4, "range": 3, "reflect": true}]},
	"w4c_fx_mirror_feint": {"time": 4, "actions": [{"type": "illusion", "health": 3, "range": 3, "place": "adjacent_to_enemy", "expose_adjacent": 3}]},
	"w4c_fx_hall_of_mirrors": {"time": 6, "actions": [{"type": "illusion", "health": 2, "range": 0, "place": "ring_around_self"}, {"type": "block", "amount": 3}]},
	"w4c_fx_doppelganger": {"time": 5, "actions": [{"type": "illusion", "health": 5, "range": 3, "ranged_origin": true}]},
	"w4c_fx_mirror_image": {"time": 3, "actions": [{"type": "illusion", "health": 3, "range": 3}]},
	"w4c_fx_shot": {"time": 3, "actions": [{"type": "ranged", "damage": 4, "range": 3, "element": "none"}]},
	"w4c_fx_empty_husk": {"time": 2, "actions": [{"type": "illusion_swap", "range": 99, "transfer_block": true}]},
	"w4c_fx_shattered_reflection": {"time": 3, "actions": [{"type": "destroy_illusion", "range": 6, "damage": 6, "illuminate_radius": 2, "illuminate_duration": 2}]},
	"w4c_fx_refraction": {"time": 4, "actions": [{"type": "ranged", "damage": 4, "range": 3, "element": "none", "also_hits_near_illusions": true}]},
	"w4c_fx_rockburst": {"element": "earth", "time": 4, "actions": [{"type": "burst_terrain", "range": 3, "damage": 6, "surface": "rubble", "surface_pattern": CROSS}]},
	"w4c_fx_worldbreak": {"element": "earth", "time": 6, "actions": [{"type": "burst_terrain", "range": 1, "owned_outcrop_only": true, "line_damage": 10, "line_length": 3, "stagger": 2}]},
	"w4c_fx_powder_keg": {"element": "fire", "time": 3, "actions": [{"type": "outcrop", "range": 2, "health": 3, "kind": "powder_keg", "burst_damage": 8}]},
	"w4c_fx_worldspine": {"element": "earth", "time": 7, "burn": true, "actions": [{"type": "outcrop", "range": 3, "health": 4, "pattern": ADJ, "around_target": true, "kind": "worldspine", "pulse_damage": 3}]},
	"w4c_fx_rampart": {"element": "earth", "time": 5, "actions": [{"type": "outcrop", "range": 2, "health": 3, "pattern": LINE3, "rotate": true}, {"type": "stoneskin", "amount": 3}]},
	"w4c_fx_raise": {"element": "earth", "time": 2, "actions": [{"type": "outcrop", "range": 1, "health": 3}]},
	"w4c_fx_guard": {"time": 1, "actions": [{"type": "block", "amount": 1}]},
	"w4c_fx_sharpen": {"time": 1, "actions": [{"type": "next_attack", "damage": 3}]}
}

static func run(expect: Callable) -> void:
	# Warm catalogs before fixtures exist so injected cards never leak.
	GrimoireLibrary.entry_map()
	_install_fixtures()
	var engine: CombatEngine = CombatEngine.new()
	_test_surface_ring(engine, expect)
	_test_on_damaged_retort(engine, expect)
	_test_reflect(engine, expect)
	_test_retort_presentation_steps(engine, expect)
	_test_adjacent_to_enemy_placement(engine, expect)
	_test_ring_around_self(engine, expect)
	_test_ranged_origin(engine, expect)
	_test_illusion_swap(engine, expect)
	_test_destroy_illusion(engine, expect)
	_test_refraction(engine, expect)
	_test_burst_terrain(engine, expect)
	_test_worldbreak(engine, expect)
	_test_powder_keg(engine, expect)
	_test_worldspine(engine, expect)
	_test_worldspine_routes(engine, expect)
	_test_rampart_rotation(engine, expect)
	_test_presentation_contracts(engine, expect)
	_test_run_scene_surfaces(engine, expect)
	_remove_fixtures()

# ------------------------------------------------------------------ fixtures

static func _install_fixtures() -> void:
	var cards: Dictionary = GameData.cards()
	for card_id: String in FIXTURES.keys():
		var card: Dictionary = (FIXTURES[card_id] as Dictionary).duplicate(true)
		card["name"] = card_id.trim_prefix("w4c_fx_").capitalize()
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

static func _enemy(id: int, pos: Vector2i, hp: int = 20, footprint: Vector2i = Vector2i.ONE) -> Dictionary:
	var enemy: Dictionary = {"id": id, "type": "crawler", "pos": pos, "hp": hp, "max_hp": hp, "block": 0}
	if footprint != Vector2i.ONE:
		enemy["footprint"] = footprint
	return enemy

static func _state(engine: CombatEngine, enemies: Array, relics: Array = []) -> Dictionary:
	var grid: Array = []
	for y: int in range(9):
		var row: Array[String] = []
		for x: int in range(10):
			row.append("wall" if x == 0 or y == 0 or x == 9 or y == 8 else "stone")
		grid.append(row)
	var room: Dictionary = {
		"name": "Wave 4 Illusion Terrain Room",
		"coord": Vector2i(3, 1),
		"depth": 1,
		"type": "combat",
		"element": ElementData.NONE,
		"grid": grid,
		"player_start": PLAYER_TILE,
		"enemies": _room_enemies(enemies),
		"loot": [],
		"traps": []
	}
	var state: Dictionary = engine.create_combat(4304, room, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["w4c_fx_guard", "w4c_fx_guard", "w4c_fx_guard", "w4c_fx_guard", "w4c_fx_guard", "w4c_fx_guard", "w4c_fx_guard", "w4c_fx_guard"],
		"relics": relics,
		"hand_size": 1,
		"heal_bonus": 0,
		"cards_per_turn": 8
	})
	var deck: Dictionary = state["deck"] as Dictionary
	deck["hand"] = []
	state["deck"] = deck
	# Large footprints are applied after normalization, like other footprint tests.
	for index: int in range(enemies.size()):
		var enemy: Dictionary = enemies[index] as Dictionary
		if enemy.has("footprint"):
			(state["enemies"][index] as Dictionary)["footprint"] = enemy["footprint"]
	return state

static func _room_enemies(enemies: Array) -> Array:
	var result: Array = []
	for enemy_var: Variant in enemies:
		var enemy: Dictionary = (enemy_var as Dictionary).duplicate(true)
		enemy.erase("footprint")
		result.append(enemy)
	return result

## The prepared state and tagged actions of `card_id` played from hand slot 0.
static func _prepared(engine: CombatEngine, state: Dictionary, card_id: String) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var deck: Dictionary = next_state["deck"] as Dictionary
	var hand: Array = (deck.get("hand", []) as Array).duplicate()
	hand.push_front(card_id)
	deck["hand"] = hand
	next_state["deck"] = deck
	var working: Dictionary = engine.prepare_player_card(next_state, 0, "play")
	return {"state": working, "actions": engine.card_play_actions(card_id, working)}

static func _action(engine: CombatEngine, state: Dictionary, card_id: String, index: int = 0) -> Dictionary:
	return (engine.card_play_actions(card_id, state)[index] as Dictionary)

## Resolve every action like a committed play (no finish).
static func _resolve(engine: CombatEngine, state: Dictionary, card_id: String, target: Vector2i = NO_TARGET) -> Dictionary:
	var prepared: Dictionary = _prepared(engine, state, card_id)
	var working: Dictionary = prepared["state"]
	for action_var: Variant in prepared["actions"]:
		var action: Dictionary = action_var as Dictionary
		var tile: Vector2i = target if engine.player_action_needs_target(action) else NO_TARGET
		working = engine.apply_player_action(working, engine.action_with_automatic_origin(working, action, tile), tile)
	return working

## Resolve and commit like a hand play (finish_player_card).
static func _play(engine: CombatEngine, state: Dictionary, card_id: String, target: Vector2i = NO_TARGET) -> Dictionary:
	var prepared: Dictionary = _prepared(engine, state, card_id)
	var working: Dictionary = prepared["state"]
	for action_var: Variant in prepared["actions"]:
		var action: Dictionary = action_var as Dictionary
		var tile: Vector2i = target if engine.player_action_needs_target(action) else NO_TARGET
		working = engine.apply_player_action(working, engine.action_with_automatic_origin(working, action, tile), tile)
	return engine.finish_player_card(working, 0, engine.card_plays_spent_for_actions(prepared["actions"]), {"play_mode": "play"})

static func _preview_matches(engine: CombatEngine, state: Dictionary, action: Dictionary, target: Vector2i) -> bool:
	var before: Dictionary = state.duplicate(true)
	var actual: Dictionary = engine.apply_player_action(state, action, target)
	var presented: Dictionary = engine.resolve_player_action_for_presentation(state, action, target)
	var hover: Dictionary = engine.surface_preview_for_player_action(state, action, target)
	return actual == presented.get("state", {}) and actual == hover.get("state", {}) and state == before

static func _with_illusion(engine: CombatEngine, state: Dictionary, tile: Vector2i, hp: int, traits: Dictionary = {}) -> Dictionary:
	return engine._create_illusion(state.duplicate(true), tile, hp, traits)

static func _with_terrain(state: Dictionary, id: String, tile: Vector2i, kind: String = "wooden_crate", hp: int = 3, extra: Dictionary = {}) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var entry: Dictionary = {"id": id, "kind": kind, "pos": tile, "hp": hp, "max_hp": hp}
	entry.merge(extra, true)
	var terrain: Array = (next_state.get("terrain", []) as Array).duplicate(true)
	terrain.append(entry)
	next_state["terrain"] = terrain
	return next_state

static func _hp(state: Dictionary, enemy_id: int) -> int:
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("id", -1)) == enemy_id:
			return int(enemy.get("hp", 0))
	return -1

static func _enemy_by_id(state: Dictionary, enemy_id: int) -> Dictionary:
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("id", -1)) == enemy_id:
			return enemy
	return {}

static func _illusions(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for illusion: Dictionary in state.get("illusions", []):
		if int(illusion.get("hp", 0)) > 0:
			result.append(illusion)
	return result

static func _illusion_at(state: Dictionary, tile: Vector2i) -> Dictionary:
	for illusion: Dictionary in _illusions(state):
		if illusion.get("pos", NO_TARGET) == tile:
			return illusion
	return {}

static func _terrain_at(state: Dictionary, tile: Vector2i) -> Dictionary:
	for terrain: Dictionary in state.get("terrain", []):
		if terrain.get("pos", NO_TARGET) == tile and int(terrain.get("hp", 0)) > 0:
			return terrain
	return {}

static func _events(before: Dictionary, after: Dictionary, kind: String) -> Array[Dictionary]:
	return IllusionCardRules.events_between(before, after, kind)

static func _same_tiles(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for tile: Variant in expected:
		if not actual.has(tile):
			return false
	return true

static func _enemy_attack(engine: CombatEngine, state: Dictionary, enemy_id: int, action: Dictionary) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	return engine._resolve_enemy_action(next_state, engine._enemy_index_for_id(next_state, enemy_id), action)

# ------------------------------------------------------------------ illusion creation options

static func _test_surface_ring(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4))])
	var after: Dictionary = _resolve(engine, state, "w4c_fx_ice_sculpture", Vector2i(4, 3))
	expect.call(int(_illusion_at(after, Vector2i(4, 3)).get("hp", 0)) == 4, "Ice Sculpture creates a 4-health illusion at its target")
	var iced: Array = []
	for tile: Vector2i in [Vector2i(4, 2), Vector2i(5, 3), Vector2i(4, 4), Vector2i(3, 3)]:
		if Surface.has_surface(after, tile, "ice"):
			iced.append(tile)
	expect.call(iced.size() == 4, "surface_ring leaves Ice on each empty orthogonal neighbor: %s" % str(iced))
	expect.call(not Surface.has_surface(after, Vector2i(4, 3), "ice"), "surface_ring does not paint the illusion's own tile")
	# Negative: the hero and an enemy next to the illusion keep their tiles bare.
	var crowded: Dictionary = _resolve(engine, state, "w4c_fx_ice_sculpture", Vector2i(4, 4))
	expect.call(not Surface.has_surface(crowded, Vector2i(5, 4), "ice"), "surface_ring skips a tile an enemy occupies")
	var beside_hero: Dictionary = _resolve(engine, state, "w4c_fx_ice_sculpture", Vector2i(3, 4))
	expect.call(not Surface.has_surface(beside_hero, PLAYER_TILE, "ice") and Surface.has_surface(beside_hero, Vector2i(3, 3), "ice"), "surface_ring skips the hero's tile but paints the rest")
	# 2x2: no footprint tile receives Ice.
	var large: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 3), 40, Vector2i(2, 2))])
	var large_after: Dictionary = _resolve(engine, large, "w4c_fx_ice_sculpture", Vector2i(4, 4))
	expect.call(not Surface.has_surface(large_after, Vector2i(5, 4), "ice") and Surface.has_surface(large_after, Vector2i(4, 5), "ice"), "surface_ring respects a 2x2 enemy footprint")
	var prepared: Dictionary = _prepared(engine, state, "w4c_fx_ice_sculpture")
	expect.call(_preview_matches(engine, prepared["state"], prepared["actions"][0], Vector2i(4, 3)), "Ice Sculpture preview equals resolution")

static func _test_on_damaged_retort(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4))])
	var created: Dictionary = _resolve(engine, state, "w4c_fx_ball_lightning", Vector2i(4, 4))
	var ball: Dictionary = _illusion_at(created, Vector2i(4, 4))
	expect.call(int(ball.get("hp", 0)) == 3 and Surface.has_surface(created, Vector2i(4, 4), "electrified"), "Ball Lightning creates a 3-health illusion on Electrified ground")
	expect.call((ball.get("on_damaged", {}) as Dictionary).get("damage", 0) == 4 and str(ball.get("source_name", "")) == "Ball Lightning", "The illusion carries its on_damaged trait and source name")
	var struck: Dictionary = _enemy_attack(engine, created, 1, {"type": "melee", "damage": 2, "range": 1})
	expect.call(int(_illusion_at(struck, Vector2i(4, 4)).get("hp", 0)) == 1, "The enemy strike lands on the illusion")
	expect.call(_hp(struck, 1) == 16 and int(_enemy_by_id(struck, 1).get("shock", 0)) == 1, "The attacker takes 4 and is Shocked")
	var events: Array[Dictionary] = _events(created, struck, IllusionCardRules.RETORT_EVENT)
	expect.call(events.size() == 1 and str(events[0].get("trait", "")) == "on_damaged" and str(events[0].get("element", "")) == "lightning", "One illusion_retort event per enemy attack")
	# Non-direct: no Chilled bonus on the attacker.
	var chilled: Dictionary = created.duplicate(true)
	chilled["enemies"][0]["chilled"] = true
	var chilled_after: Dictionary = _enemy_attack(engine, chilled, 1, {"type": "melee", "damage": 2, "range": 1})
	expect.call(_hp(chilled_after, 1) == 16, "The retort is non-direct: Chilled adds nothing")
	# Negative: a zero-damage attack and an attack on the hero do not trigger it.
	var nudge: Dictionary = _enemy_attack(engine, created, 1, {"type": "melee", "damage": 0, "range": 1})
	expect.call(_hp(nudge, 1) == 20, "A zero-damage attack does not trigger the retort")
	var plain: Dictionary = _with_illusion(engine, state, Vector2i(4, 4), 3)
	var plain_after: Dictionary = _enemy_attack(engine, plain, 1, {"type": "melee", "damage": 2, "range": 1})
	expect.call(_hp(plain_after, 1) == 20, "An ordinary illusion never retorts")
	# Kill credit: death rewards but no card play.
	var weak: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4), 4)])
	weak = _resolve(engine, weak, "w4c_fx_ball_lightning", Vector2i(4, 4))
	var bonus_before: int = int(weak.get("death_bonus_card_plays_this_turn", 0))
	var killed: Dictionary = _enemy_attack(engine, weak, 1, {"type": "melee", "damage": 1, "range": 1})
	expect.call(_hp(killed, 1) == 0 and int(killed.get("death_bonus_card_plays_this_turn", 0)) == bonus_before, "A retort kill pays death rewards but no card play")
	var deaths: Array[Dictionary] = _events(weak, killed, "actor_death")
	expect.call(not deaths.is_empty() and str((deaths[0].get("source", {}) as Dictionary).get("causal_owner", "")) == "player", "A retort kill is player-credited")
	# 2x2 attacker takes the retort once.
	var large: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 3), 40, Vector2i(2, 2))])
	large = _resolve(engine, large, "w4c_fx_ball_lightning", Vector2i(4, 4))
	var large_after: Dictionary = _enemy_attack(engine, large, 1, {"type": "melee", "damage": 1, "range": 1})
	expect.call(_hp(large_after, 1) == 36, "A 2x2 attacker takes the retort once")
	var prepared: Dictionary = _prepared(engine, state, "w4c_fx_ball_lightning")
	expect.call(_preview_matches(engine, prepared["state"], prepared["actions"][0], Vector2i(4, 4)), "Ball Lightning preview equals resolution")

static func _test_reflect(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4))])
	var created: Dictionary = _resolve(engine, state, "w4c_fx_reflected_threat", Vector2i(4, 4))
	var struck: Dictionary = _enemy_attack(engine, created, 1, {"type": "melee", "damage": 3, "range": 1})
	expect.call(_hp(struck, 1) == 17 and int(_illusion_at(struck, Vector2i(4, 4)).get("hp", 0)) == 1, "Reflected Threat returns the damage it took")
	var overkill: Dictionary = _enemy_attack(engine, created, 1, {"type": "melee", "damage": 7, "range": 1})
	expect.call(_hp(overkill, 1) == 13 and _illusion_at(overkill, Vector2i(4, 4)).is_empty(), "Reflection returns the whole hit even when it destroys the illusion")
	# Witchglass Carapace caps enemy ranged hits on illusions at 1: reflection follows the cap.
	var capped: Dictionary = _state(engine, [_enemy(1, Vector2i(7, 4))], ["witchglass_carapace"])
	capped = _resolve(engine, capped, "w4c_fx_reflected_threat", Vector2i(4, 4))
	var shot: Dictionary = _enemy_attack(engine, capped, 1, {"type": "ranged", "damage": 3, "range": 4})
	expect.call(int(_illusion_at(shot, Vector2i(4, 4)).get("hp", 0)) == 3 and _hp(shot, 1) == 19, "Reflection returns the capped amount (Witchglass Carapace)")
	# Negative: an attack on the hero is not reflected.
	var on_hero: Dictionary = _state(engine, [_enemy(1, Vector2i(3, 4))])
	on_hero = _with_illusion(engine, on_hero, Vector2i(6, 6), 4, {"reflect": true})
	var hit_hero: Dictionary = _enemy_attack(engine, on_hero, 1, {"type": "melee", "damage": 3, "range": 1})
	expect.call(_hp(hit_hero, 1) == 20, "Hits on the hero are never reflected")
	var large: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 3), 40, Vector2i(2, 2))])
	large = _resolve(engine, large, "w4c_fx_reflected_threat", Vector2i(4, 4))
	expect.call(_hp(_enemy_attack(engine, large, 1, {"type": "melee", "damage": 3, "range": 1}), 1) == 37, "A 2x2 attacker takes the reflection once")
	var prepared: Dictionary = _prepared(engine, state, "w4c_fx_reflected_threat")
	expect.call(_preview_matches(engine, prepared["state"], prepared["actions"][0], Vector2i(4, 4)), "Reflected Threat preview equals resolution")

static func _test_retort_presentation_steps(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4))])
	state = _resolve(engine, state, "w4c_fx_ball_lightning", Vector2i(4, 4))
	state = engine.finish_player_activation(state)
	var enemies: Array = state["enemies"] as Array
	var enemy: Dictionary = (enemies[0] as Dictionary).duplicate(true)
	enemy["intent"] = {"id": "w4c_bite", "name": "Bite", "actions": [{"type": "melee", "damage": 1, "range": 1}]}
	enemies[0] = enemy
	state["enemies"] = enemies
	var result: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0, false)
	var retort_step: Dictionary = {}
	for step_var: Variant in result.get("steps", []):
		var step: Dictionary = step_var as Dictionary
		if str(step.get("trigger", "")) == IllusionCardRules.RETORT_EVENT:
			retort_step = step
	expect.call(str(retort_step.get("kind", "")) == "status_damage" and str(retort_step.get("label", "")) == "Ball Lightning", "A retort adds a status_damage step labelled with its card")
	expect.call(not (retort_step.get("enemy_losses", []) as Array).is_empty() and retort_step.has("enemies_after"), "The retort step carries the attacker's losses and after-state")

static func _test_adjacent_to_enemy_placement(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4)), _enemy(2, Vector2i(7, 6))])
	var action: Dictionary = _action(engine, state, "w4c_fx_mirror_feint")
	var targets: Array[Vector2i] = engine.valid_targets_for_player_action(state, action)
	expect.call(targets.has(Vector2i(5, 4)) and not targets.has(Vector2i(7, 6)), "Mirror Feint targets an enemy within range only: %s" % str(targets))
	expect.call(not targets.has(Vector2i(4, 4)), "Mirror Feint does not target empty floor")
	var after: Dictionary = _resolve(engine, state, "w4c_fx_mirror_feint", Vector2i(5, 4))
	expect.call(int(_illusion_at(after, Vector2i(4, 4)).get("hp", 0)) == 3, "The illusion appears on the free tile next to the enemy nearest the hero")
	expect.call(int(_enemy_by_id(after, 1).get("expose", 0)) == 3, "The chosen enemy is Exposed 3")
	expect.call(engine.illusion_placement_tiles_for_player_action(state, action, Vector2i(5, 4)) == [Vector2i(4, 4)], "The hover ghost uses the same placement tile")
	# Negative: a boxed-in enemy is not a legal target.
	var boxed: Dictionary = _state(engine, [_enemy(1, Vector2i(2, 2))])
	for index: int in range(3):
		boxed = _with_terrain(boxed, "box_%d" % index, [Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 1)][index])
	boxed = _with_terrain(boxed, "box_3", Vector2i(2, 3))
	expect.call(engine.valid_targets_for_player_action(boxed, action).is_empty(), "An enemy with no free neighbor cannot be targeted")
	# 2x2: every footprint tile is legal and all choose the same nearest tile.
	var large: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 3), 40, Vector2i(2, 2))])
	var large_targets: Array[Vector2i] = engine.valid_targets_for_player_action(large, action)
	expect.call(_same_tiles(large_targets, [Vector2i(5, 3), Vector2i(6, 3), Vector2i(5, 4), Vector2i(6, 4)]), "All 2x2 footprint tiles are targets: %s" % str(large_targets))
	var far_click: Dictionary = _resolve(engine, large, "w4c_fx_mirror_feint", Vector2i(6, 3))
	expect.call(not _illusion_at(far_click, Vector2i(4, 4)).is_empty() and int(_enemy_by_id(far_click, 1).get("expose", 0)) == 3, "Any footprint click places the illusion on the nearest free tile and Exposes the 2x2 enemy")
	var prepared: Dictionary = _prepared(engine, state, "w4c_fx_mirror_feint")
	expect.call(_preview_matches(engine, prepared["state"], prepared["actions"][0], Vector2i(5, 4)), "Mirror Feint preview equals resolution")

static func _test_ring_around_self(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 6))])
	var action: Dictionary = _action(engine, state, "w4c_fx_hall_of_mirrors")
	expect.call(not engine.player_action_needs_target(action), "Hall of Mirrors is targetless")
	var after: Dictionary = _resolve(engine, state, "w4c_fx_hall_of_mirrors")
	expect.call(_illusions(after).size() == 4 and int((after["player"] as Dictionary).get("block", 0)) == 3, "Hall of Mirrors creates four 2-health illusions and grants 3 Block")
	for tile: Vector2i in [Vector2i(2, 3), Vector2i(3, 4), Vector2i(2, 5), Vector2i(1, 4)]:
		expect.call(int(_illusion_at(after, tile).get("hp", 0)) == 2, "An illusion stands on %s" % str(tile))
	var crowded: Dictionary = _state(engine, [_enemy(1, Vector2i(3, 4))])
	expect.call(_illusions(_resolve(engine, crowded, "w4c_fx_hall_of_mirrors")).size() == 3, "Occupied neighbors are skipped")
	var large: Dictionary = _state(engine, [_enemy(1, Vector2i(3, 3), 40, Vector2i(2, 2))])
	var large_after: Dictionary = _resolve(engine, large, "w4c_fx_hall_of_mirrors")
	expect.call(_illusions(large_after).size() == 3 and _illusion_at(large_after, Vector2i(3, 4)).is_empty(), "A 2x2 footprint blocks its tile next to the hero")
	var prepared: Dictionary = _prepared(engine, state, "w4c_fx_hall_of_mirrors")
	expect.call(_preview_matches(engine, prepared["state"], prepared["actions"][0], NO_TARGET), "Hall of Mirrors preview equals resolution")

static func _test_ranged_origin(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(7, 4)), _enemy(2, Vector2i(4, 3))])
	var shot: Dictionary = _action(engine, state, "w4c_fx_shot")
	expect.call(not engine.valid_targets_for_player_action(state, shot).has(Vector2i(7, 4)), "Without a Doppelganger the far enemy is out of range")
	var plain: Dictionary = _with_illusion(engine, state, Vector2i(4, 4), 5)
	expect.call(not engine.valid_targets_for_player_action(plain, shot).has(Vector2i(7, 4)), "An ordinary illusion is not a firing position")
	var doppel: Dictionary = _resolve(engine, state, "w4c_fx_doppelganger", Vector2i(4, 4))
	expect.call(bool(_illusion_at(doppel, Vector2i(4, 4)).get("ranged_origin", false)), "Doppelganger's illusion is a ranged origin")
	var targets: Array[Vector2i] = engine.valid_targets_for_player_action(doppel, shot)
	expect.call(targets.has(Vector2i(7, 4)) and targets.has(Vector2i(4, 3)), "Targets reachable from the hero or the Doppelganger are legal: %s" % str(targets))
	var from_illusion: Dictionary = engine.action_with_automatic_origin(doppel, shot, Vector2i(7, 4))
	expect.call(from_illusion.get("_origin_tile", NO_TARGET) == Vector2i(4, 4), "A target only the illusion reaches fires from the illusion's tile")
	var from_hero: Dictionary = engine.action_with_automatic_origin(doppel, shot, Vector2i(4, 3))
	expect.call(not from_hero.has("_origin_tile"), "A target the hero reaches fires from the hero's own tile")
	var after: Dictionary = _resolve(engine, doppel, "w4c_fx_shot", Vector2i(7, 4))
	expect.call(_hp(after, 1) == 16, "The shot from the illusion resolves")
	expect.call(_events(doppel, after, IllusionCardRules.ORIGIN_EVENT).size() == 1, "An illusion_ranged_origin event records the firing position")
	var prepared: Dictionary = _prepared(engine, doppel, "w4c_fx_shot")
	var origin_action: Dictionary = engine.action_with_automatic_origin(prepared["state"], prepared["actions"][0], Vector2i(7, 4))
	expect.call(_preview_matches(engine, prepared["state"], origin_action, Vector2i(7, 4)), "Ranged-origin preview equals resolution")
	# Negative: sight is measured from the illusion; a dead illusion is no origin.
	var blocked: Dictionary = _with_terrain(doppel, "wall_a", Vector2i(5, 4), "crag_outcrop", 3, {"blocks_sight": true})
	expect.call(not engine.valid_targets_for_player_action(blocked, shot).has(Vector2i(7, 4)), "An outcrop between the illusion and the target blocks the shot")
	var illusion_id: int = int(_illusion_at(doppel, Vector2i(4, 4)).get("id", -1))
	var faded: Dictionary = engine._damage_illusion(doppel.duplicate(true), illusion_id, 5)
	expect.call(not engine.valid_targets_for_player_action(faded, shot).has(Vector2i(7, 4)), "A destroyed Doppelganger is no longer a firing position")
	# 2x2: every footprint tile is legal from the illusion; the enemy is hit once.
	var large: Dictionary = _state(engine, [_enemy(1, Vector2i(7, 3), 40, Vector2i(2, 2))])
	large = _resolve(engine, large, "w4c_fx_doppelganger", Vector2i(4, 4))
	var large_targets: Array[Vector2i] = engine.valid_targets_for_player_action(large, shot)
	expect.call(large_targets.has(Vector2i(8, 3)) and large_targets.has(Vector2i(7, 4)), "A 2x2 enemy reached from the illusion exposes every footprint tile")
	var large_after: Dictionary = _resolve(engine, large, "w4c_fx_shot", Vector2i(8, 3))
	expect.call(_hp(large_after, 1) == 36, "The 2x2 enemy takes the shot once")

static func _test_illusion_swap(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(7, 7))])
	var husk: Dictionary = _action(engine, state, "w4c_fx_empty_husk")
	expect.call(engine.valid_targets_for_player_action(state, husk).is_empty(), "Empty Husk has no target without an illusion")
	state = _with_illusion(engine, state, Vector2i(5, 4), 3)
	(state["player"] as Dictionary)["block"] = 5
	Surface.place(state, Vector2i(5, 4), "ice", {"actor_kind": "player"})
	Surface.place(state, PLAYER_TILE, "fire", {"actor_kind": "player"})
	expect.call(engine.valid_targets_for_player_action(state, husk) == [Vector2i(5, 4)], "Empty Husk targets your illusion")
	var after: Dictionary = _resolve(engine, state, "w4c_fx_empty_husk", Vector2i(5, 4))
	var player: Dictionary = after["player"] as Dictionary
	var husk_illusion: Dictionary = _illusion_at(after, PLAYER_TILE)
	expect.call(player.get("pos", NO_TARGET) == Vector2i(5, 4) and not husk_illusion.is_empty(), "The hero and the illusion trade tiles")
	expect.call(int(player.get("block", 0)) == 0 and int(husk_illusion.get("max_hp", 0)) == 8, "transfer_block moves all Block onto the illusion as extra health")
	expect.call(int(husk_illusion.get("hp", 0)) == 8 - Surface.FIRE_ENTRY_DAMAGE, "The illusion's arrival triggers the Fire it lands on")
	expect.call(bool(player.get("chilled", false)), "The hero's arrival triggers the Ice it lands on")
	expect.call(_events(state, after, IllusionCardRules.SWAP_EVENT).size() == 1, "An illusion_swapped event records the swap")
	var prepared: Dictionary = _prepared(engine, state, "w4c_fx_empty_husk")
	expect.call(_preview_matches(engine, prepared["state"], prepared["actions"][0], Vector2i(5, 4)), "Empty Husk preview equals resolution")
	# Negative: Immobilize forbids the swap; enemy tiles are never targets.
	var pinned: Dictionary = state.duplicate(true)
	pinned["player_turn_restrictions"] = {"immobilized": true}
	expect.call(engine.valid_targets_for_player_action(pinned, husk).is_empty(), "An immobilized hero cannot swap")
	expect.call(not engine.valid_targets_for_player_action(state, husk).has(Vector2i(7, 7)), "Enemy tiles are not swap targets")
	# 2x2 enemies do not block a swap onto the illusion beside them.
	var large: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 3), 40, Vector2i(2, 2))])
	large = _with_illusion(engine, large, Vector2i(5, 4), 3)
	var large_after: Dictionary = _resolve(engine, large, "w4c_fx_empty_husk", Vector2i(5, 4))
	expect.call((large_after["player"] as Dictionary).get("pos", NO_TARGET) == Vector2i(5, 4), "The swap lands beside a 2x2 enemy")

static func _test_destroy_illusion(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 4)), _enemy(2, Vector2i(5, 5)), _enemy(3, Vector2i(7, 4))])
	var shatter: Dictionary = _action(engine, state, "w4c_fx_shattered_reflection")
	expect.call(engine.valid_targets_for_player_action(state, shatter).is_empty(), "Shattered Reflection needs one of your illusions")
	state = _with_illusion(engine, state, Vector2i(5, 4), 3)
	state = _with_terrain(state, "crate_a", Vector2i(5, 3))
	expect.call(engine.valid_targets_for_player_action(state, shatter) == [Vector2i(5, 4)], "Shattered Reflection targets your illusion")
	var after: Dictionary = _resolve(engine, state, "w4c_fx_shattered_reflection", Vector2i(5, 4))
	expect.call(_illusion_at(after, Vector2i(5, 4)).is_empty(), "The illusion is destroyed")
	expect.call(_hp(after, 1) == 14 and _hp(after, 2) == 14 and _hp(after, 3) == 20, "Each enemy next to the illusion takes 6; others do not")
	expect.call(int(_terrain_at(after, Vector2i(5, 3)).get("hp", 0)) == 3, "The blast hits enemies only")
	var deaths: Array[Dictionary] = _events(state, after, "actor_death")
	expect.call(deaths.size() >= 1 and str(deaths[0].get("actor_kind", "")) == "illusion", "Destruction fires the normal illusion death hooks")
	var lit: bool = false
	for source: Dictionary in ((after.get("umbra", {}) as Dictionary).get("light_sources", []) as Array):
		if source.get("pos", NO_TARGET) == Vector2i(5, 4) and int(source.get("radius", 0)) == 2:
			lit = true
	expect.call(lit, "Radius-2 Light is created where the illusion stood")
	var prepared: Dictionary = _prepared(engine, state, "w4c_fx_shattered_reflection")
	expect.call(_preview_matches(engine, prepared["state"], prepared["actions"][0], Vector2i(5, 4)), "Shattered Reflection preview equals resolution")
	expect.call(not engine.valid_targets_for_player_action(state, shatter).has(Vector2i(6, 4)), "Enemies are not shatter targets")
	var large: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 3), 40, Vector2i(2, 2))])
	large = _with_illusion(engine, large, Vector2i(5, 4), 3)
	expect.call(_hp(_resolve(engine, large, "w4c_fx_shattered_reflection", Vector2i(5, 4)), 1) == 34, "A 2x2 enemy next to the illusion takes the blast once")
	# A card blast is not an attack for next-attack buffs: it neither uses nor spends one.
	var buffed: Dictionary = _play(engine, _state(engine, [_enemy(1, Vector2i(6, 4)), _enemy(2, Vector2i(3, 3))]), "w4c_fx_sharpen")
	buffed = _with_illusion(engine, buffed, Vector2i(5, 4), 3)
	var blasted: Dictionary = _play(engine, buffed, "w4c_fx_shattered_reflection", Vector2i(5, 4))
	expect.call(_hp(blasted, 1) == 14, "Shattered Reflection ignores a pending next-attack buff")
	var shot_after: Dictionary = _play(engine, blasted, "w4c_fx_shot", Vector2i(3, 3))
	expect.call(_hp(shot_after, 2) == 13, "The buff is still pending for the next real attack")

static func _test_refraction(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(4, 4)), _enemy(2, Vector2i(6, 5)), _enemy(3, Vector2i(7, 6)), _enemy(4, Vector2i(6, 2))])
	var alone: Dictionary = _resolve(engine, state, "w4c_fx_refraction", Vector2i(4, 4))
	expect.call(_hp(alone, 1) == 16 and _hp(alone, 2) == 20, "Without illusions Refraction is an ordinary shot")
	var lens: Dictionary = _with_illusion(engine, state, Vector2i(6, 6), 3)
	lens = _with_illusion(engine, lens, Vector2i(4, 5), 3)
	var after: Dictionary = _resolve(engine, lens, "w4c_fx_refraction", Vector2i(4, 4))
	expect.call(_hp(after, 1) == 16, "The primary target is hit once even beside an illusion")
	expect.call(_hp(after, 2) == 16 and _hp(after, 3) == 16, "Each other enemy next to an illusion takes the same damage")
	expect.call(_hp(after, 4) == 20, "Enemies away from illusions are untouched")
	var prepared: Dictionary = _prepared(engine, lens, "w4c_fx_refraction")
	expect.call(_preview_matches(engine, prepared["state"], prepared["actions"][0], Vector2i(4, 4)), "Refraction preview equals resolution")
	var trace: Dictionary = engine.resolve_player_action_for_presentation(prepared["state"], prepared["actions"][0], Vector2i(4, 4))
	var beams: int = 0
	for hit: Dictionary in trace.get("chain_hits", []):
		if str(hit.get("kind", "")) == IllusionCardRules.REFRACTION_TRACE:
			beams += 1
	expect.call(beams == 2, "Presentation receives one refraction beam per extra enemy")
	var large: Dictionary = _state(engine, [_enemy(1, Vector2i(4, 4)), _enemy(2, Vector2i(6, 5), 40, Vector2i(2, 2))])
	large = _with_illusion(engine, large, Vector2i(5, 6), 3)
	large = _with_illusion(engine, large, Vector2i(8, 5), 3)
	expect.call(_hp(_resolve(engine, large, "w4c_fx_refraction", Vector2i(4, 4)), 2) == 36, "A 2x2 enemy beside two illusions is hit once")

# ------------------------------------------------------------------ terrain

static func _test_burst_terrain(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4)), _enemy(2, Vector2i(4, 5)), _enemy(3, Vector2i(6, 4))])
	var burst: Dictionary = _action(engine, state, "w4c_fx_rockburst")
	expect.call(engine.valid_targets_for_player_action(state, burst).is_empty(), "Rockburst needs terrain")
	state = _with_terrain(state, "crate_a", Vector2i(4, 4))
	state = _with_terrain(state, "crate_b", Vector2i(4, 3))
	expect.call(engine.valid_targets_for_player_action(state, burst).has(Vector2i(4, 4)), "Rockburst targets a crate within range")
	var after: Dictionary = _resolve(engine, state, "w4c_fx_rockburst", Vector2i(4, 4))
	expect.call(_terrain_at(after, Vector2i(4, 4)).is_empty(), "The crate is destroyed")
	expect.call(_hp(after, 1) == 14 and _hp(after, 2) == 14 and _hp(after, 3) == 20, "Each enemy next to the crate takes 6")
	expect.call(int(_terrain_at(after, Vector2i(4, 3)).get("hp", 0)) == 3, "The blast does not damage neighboring terrain")
	expect.call(Surface.has_rubble(after, Vector2i(4, 4)) and Surface.has_rubble(after, Vector2i(3, 4)) and Surface.has_rubble(after, Vector2i(5, 4)), "Rubble is left in a cross")
	var prepared: Dictionary = _prepared(engine, state, "w4c_fx_rockburst")
	expect.call(_preview_matches(engine, prepared["state"], prepared["actions"][0], Vector2i(4, 4)), "Rockburst preview equals resolution")
	# Negative: sight. An outcrop hides the crate behind it but is itself a target.
	var hidden: Dictionary = _state(engine, [_enemy(1, Vector2i(7, 7))])
	hidden = _with_terrain(hidden, "crate_c", Vector2i(5, 4))
	hidden = _with_terrain(hidden, "rock_a", Vector2i(4, 4), "crag_outcrop", 3, {"blocks_sight": true})
	var hidden_targets: Array[Vector2i] = engine.valid_targets_for_player_action(hidden, burst)
	expect.call(hidden_targets.has(Vector2i(4, 4)) and not hidden_targets.has(Vector2i(5, 4)), "Burst targets need line of sight: %s" % str(hidden_targets))
	var large: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 3), 40, Vector2i(2, 2))])
	large = _with_terrain(large, "crate_d", Vector2i(4, 4))
	expect.call(_hp(_resolve(engine, large, "w4c_fx_rockburst", Vector2i(4, 4)), 1) == 34, "A 2x2 enemy next to the crate takes the blast once")

static func _test_worldbreak(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(4, 4)), _enemy(2, Vector2i(5, 4)), _enemy(3, Vector2i(6, 4)), _enemy(4, Vector2i(7, 4))])
	var worldbreak: Dictionary = _action(engine, state, "w4c_fx_worldbreak")
	var crate: Dictionary = _with_terrain(state, "crate_a", Vector2i(3, 4))
	expect.call(engine.valid_targets_for_player_action(crate, worldbreak).is_empty(), "Worldbreak ignores terrain you did not raise")
	var foreign: Dictionary = _with_terrain(state, "rock_e", Vector2i(3, 4), "crag_outcrop", 3, {"owner_kind": "enemy", "blocks_sight": true})
	expect.call(engine.valid_targets_for_player_action(foreign, worldbreak).is_empty(), "Worldbreak ignores an enemy's outcrop")
	var raised: Dictionary = _resolve(engine, state, "w4c_fx_raise", Vector2i(3, 4))
	expect.call(str(_terrain_at(raised, Vector2i(3, 4)).get("owner_kind", "")) == "player", "The hero raised an adjacent outcrop")
	expect.call(engine.valid_targets_for_player_action(raised, worldbreak) == [Vector2i(3, 4)], "Worldbreak targets the adjacent outcrop you raised")
	var after: Dictionary = _resolve(engine, raised, "w4c_fx_worldbreak", Vector2i(3, 4))
	expect.call(_terrain_at(after, Vector2i(3, 4)).is_empty() and Surface.has_rubble(after, Vector2i(3, 4)), "The outcrop is destroyed and leaves Rubble")
	expect.call(_hp(after, 1) == 10 and _hp(after, 2) == 10 and _hp(after, 3) == 10 and _hp(after, 4) == 20, "Each enemy in the three tiles beyond takes 10")
	expect.call(CardKeywordRules.stagger_applied_this_turn(after, 1) == 2 and CardKeywordRules.stagger_applied_this_turn(after, 4) == 0, "The line is Staggered 2")
	var far: Dictionary = _resolve(engine, _state(engine, [_enemy(1, Vector2i(7, 7))]), "w4c_fx_raise", Vector2i(2, 3))
	far = far.duplicate(true)
	(far["player"] as Dictionary)["pos"] = Vector2i(2, 5)
	expect.call(engine.valid_targets_for_player_action(far, worldbreak).is_empty(), "Worldbreak needs the outcrop next to you")
	var prepared: Dictionary = _prepared(engine, raised, "w4c_fx_worldbreak")
	expect.call(_preview_matches(engine, prepared["state"], prepared["actions"][0], Vector2i(3, 4)), "Worldbreak preview equals resolution")
	var large: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4), 40, Vector2i(2, 2))])
	large = _resolve(engine, large, "w4c_fx_raise", Vector2i(3, 4))
	expect.call(_hp(_resolve(engine, large, "w4c_fx_worldbreak", Vector2i(3, 4)), 1) == 30, "A 2x2 enemy across the line is hit once")

static func _test_powder_keg(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4)), _enemy(2, Vector2i(4, 5)), _enemy(3, Vector2i(6, 4)), _enemy(4, Vector2i(5, 3))])
	var placed: Dictionary = _resolve(engine, state, "w4c_fx_powder_keg", Vector2i(4, 4))
	var keg: Dictionary = _terrain_at(placed, Vector2i(4, 4))
	expect.call(str(keg.get("kind", "")) == TerrainCardRules.KEG_KIND and int(keg.get("hp", 0)) == 3 and int(keg.get("burst_damage", 0)) == 8, "Powder Keg places a 3-health keg")
	expect.call(not bool(keg.get("blocks_sight", true)) and engine.combat_line_of_sight(placed, PLAYER_TILE, Vector2i(6, 4)), "A keg does not block sight")
	placed = _with_terrain(placed, "keg_b", Vector2i(4, 3), TerrainCardRules.KEG_KIND, 3, {"burst_damage": 8, "owner_kind": "player"})
	var shot_state: Dictionary = _resolve(engine, placed, "w4c_fx_shot", Vector2i(4, 4))
	expect.call(_terrain_at(shot_state, Vector2i(4, 4)).is_empty() and _terrain_at(shot_state, Vector2i(4, 3)).is_empty(), "Breaking one keg sets off the keg next to it")
	expect.call(_hp(shot_state, 1) == 12 and _hp(shot_state, 2) == 12, "Enemies next to the first keg take 8")
	expect.call(_hp(shot_state, 4) == 12, "An enemy next to the chained keg takes its burst")
	expect.call(_hp(shot_state, 3) == 20, "Enemies outside both blasts are untouched")
	expect.call(_events(placed, shot_state, TerrainCardRules.KEG_EVENT).size() == 2, "Each keg records a powder_keg_burst event")
	var prepared: Dictionary = _prepared(engine, placed, "w4c_fx_shot")
	expect.call(_preview_matches(engine, prepared["state"], prepared["actions"][0], Vector2i(4, 4)), "A keg chain preview equals resolution")
	# Anything breaks it, and the burst is player-credited for a hero-placed keg.
	var weak: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4), 6)])
	weak = _resolve(engine, weak, "w4c_fx_powder_keg", Vector2i(4, 4))
	var enemy_context: Dictionary = weak.duplicate(true)
	enemy_context["damage_context"] = {"actor_kind": "enemy", "actor_id": 1, "player_card": false, "source_kind": "direct_attack"}
	var keg_index: int = engine._terrain_index_at_tile(enemy_context, Vector2i(4, 4))
	var enemy_broken: Dictionary = engine._damage_terrain(enemy_context.duplicate(true), keg_index, 3)
	var deaths: Array[Dictionary] = _events(enemy_context, enemy_broken, "actor_death")
	expect.call(_hp(enemy_broken, 1) == 0 and not deaths.is_empty() and str((deaths[0].get("source", {}) as Dictionary).get("causal_owner", "")) == "player", "An enemy-broken hero keg is player-credited")
	expect.call(int((enemy_broken.get("player", {}) as Dictionary).get("hp", 0)) == 24, "The hero outside the blast is unharmed")
	var close: Dictionary = _resolve(engine, _state(engine, [_enemy(1, Vector2i(7, 7))]), "w4c_fx_powder_keg", Vector2i(3, 4))
	var close_index: int = engine._terrain_index_at_tile(close, Vector2i(3, 4))
	var close_broken: Dictionary = engine._damage_terrain(close.duplicate(true), close_index, 3)
	expect.call(int((close_broken["player"] as Dictionary).get("hp", 0)) == 16, "The burst also hits the hero next to the keg")
	var occupied_targets: Array[Vector2i] = engine.valid_targets_for_player_action(state, _action(engine, state, "w4c_fx_powder_keg"))
	expect.call(not occupied_targets.has(Vector2i(4, 5)), "A keg cannot be placed on an occupied tile")
	var large: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 3), 40, Vector2i(2, 2))])
	large = _resolve(engine, large, "w4c_fx_powder_keg", Vector2i(4, 4))
	expect.call(_hp(_resolve(engine, large, "w4c_fx_shot", Vector2i(4, 4)), 1) == 32, "A 2x2 enemy touching the blast takes it once")

static func _test_worldspine(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4)), _enemy(2, Vector2i(7, 4)), _enemy(3, Vector2i(7, 7))])
	var action: Dictionary = _action(engine, state, "w4c_fx_worldspine")
	expect.call(engine.valid_targets_for_player_action(state, action).has(Vector2i(5, 4)), "Worldspine targets a tile around an enemy")
	var tiles: Array[Vector2i] = engine.outcrop_tiles_for_player_action(state, action, Vector2i(5, 4))
	expect.call(_same_tiles(tiles, [Vector2i(5, 3), Vector2i(6, 4), Vector2i(5, 5), Vector2i(4, 4)]), "Four spires cage the target, sealing only its center: %s" % str(tiles))
	var after: Dictionary = _resolve(engine, state, "w4c_fx_worldspine", Vector2i(5, 4))
	var spire: Dictionary = _terrain_at(after, Vector2i(6, 4))
	expect.call(str(spire.get("kind", "")) == TerrainCardRules.WORLDSPINE_KIND and int(spire.get("hp", 0)) == 4 and int(spire.get("pulse_damage", 0)) == 3, "Worldspines are 4-health spires that pulse for 3")
	var pulsed: Dictionary = TerrainCardRules.apply_player_turn_start(engine, after.duplicate(true))
	expect.call(_hp(pulsed, 1) == 17 and _hp(pulsed, 2) == 17 and _hp(pulsed, 3) == 20, "Each enemy next to a Worldspine takes 3 once")
	expect.call(_events(after, pulsed, TerrainCardRules.PULSE_EVENT).size() == 1, "A worldspine_pulse event records the pulse")
	var next_turn: Dictionary = engine.prepare_next_player_turn(engine.finish_player_activation(after))
	expect.call(_hp(next_turn, 1) == 17, "The pulse happens at the start of the hero's turn")
	var weak: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4), 3)])
	weak = _resolve(engine, weak, "w4c_fx_worldspine", Vector2i(5, 4))
	var weak_bonus: int = int(weak.get("death_bonus_card_plays_this_turn", 0))
	var weak_pulsed: Dictionary = TerrainCardRules.apply_player_turn_start(engine, weak.duplicate(true))
	expect.call(_hp(weak_pulsed, 1) == 0 and int(weak_pulsed.get("death_bonus_card_plays_this_turn", 0)) == weak_bonus, "A pulse kill pays rewards but no card play")
	var crowded: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4)), _enemy(2, Vector2i(6, 4))])
	expect.call(not engine.outcrop_tiles_for_player_action(crowded, action, Vector2i(5, 4)).has(Vector2i(6, 4)), "An occupied neighbor gets no spire")
	var large: Dictionary = _state(engine, [_enemy(1, Vector2i(4, 2), 40, Vector2i(2, 2))])
	var large_tiles: Array[Vector2i] = engine.outcrop_tiles_for_player_action(large, action, Vector2i(4, 3))
	expect.call(_same_tiles(large_tiles, [Vector2i(4, 4), Vector2i(3, 3)]), "A 2x2 target only gets spires on free outer neighbors: %s" % str(large_tiles))
	var large_after: Dictionary = _resolve(engine, large, "w4c_fx_worldspine", Vector2i(4, 3))
	expect.call(_hp(TerrainCardRules.apply_player_turn_start(engine, large_after.duplicate(true)), 1) == 37, "A 2x2 enemy next to two spires takes one pulse")
	var prepared: Dictionary = _prepared(engine, state, "w4c_fx_worldspine")
	expect.call(_preview_matches(engine, prepared["state"], prepared["actions"][0], Vector2i(5, 4)), "Worldspine preview equals resolution")

static func _test_worldspine_routes(engine: CombatEngine, expect: Callable) -> void:
	# Column 6 is a wall with one doorway at (6, 4); the center (5, 4) is its
	# only approach, so sealing it would split the room.
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(8, 7))])
	for y: int in range(1, 8):
		if y != 4:
			state["grid"][y][6] = "wall"
	var action: Dictionary = _action(engine, state, "w4c_fx_worldspine")
	var tiles: Array[Vector2i] = engine.outcrop_tiles_for_player_action(state, action, Vector2i(5, 4))
	expect.call(_same_tiles(tiles, [Vector2i(5, 3), Vector2i(5, 5)]), "A chokepoint center stays open: spires never cut a route: %s" % str(tiles))

static func _test_rampart_rotation(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(8, 7))])
	var rampart: Dictionary = _action(engine, state, "w4c_fx_rampart")
	expect.call(engine.player_action_needs_orientation(rampart), "A rotatable patterned outcrop asks for an aim")
	var east: Dictionary = rampart.duplicate(true)
	east["orientation"] = Vector2i(1, 0)
	var south: Dictionary = rampart.duplicate(true)
	south["orientation"] = Vector2i(0, 1)
	var east_tiles: Array[Vector2i] = engine.outcrop_tiles_for_player_action(state, east, Vector2i(4, 3))
	var south_tiles: Array[Vector2i] = engine.outcrop_tiles_for_player_action(state, south, Vector2i(4, 3))
	expect.call(east_tiles.size() == 3 and south_tiles.size() == 3 and not _same_tiles(east_tiles, south_tiles), "Rotating the rampart changes its line: %s vs %s" % [str(east_tiles), str(south_tiles)])
	var scene: Node = RunSceneScript.new()
	scene.set("_selected_card_index", 0)
	scene.set("_pending_actions", [rampart])
	scene.set("_pending_action_index", 0)
	expect.call(bool(scene.call("_current_action_supports_rotation")), "The Rotate command is offered for a patterned outcrop")
	scene.set("_aoe_aim_orientation", Vector2i(0, 1))
	var oriented: Dictionary = scene.call("_action_with_aoe_aim_orientation", rampart)
	expect.call(oriented.get("orientation", Vector2i.ZERO) == Vector2i(0, 1), "The shared aim orients a patterned outcrop")
	# Negative: single outcrops and the fixed Worldspine cage never offer Rotate.
	var spine: Dictionary = _action(engine, state, "w4c_fx_worldspine")
	expect.call(not engine.player_action_needs_orientation(spine), "A Worldspine cage has one shape")
	scene.set("_pending_actions", [_action(engine, state, "w4c_fx_raise")])
	expect.call(not bool(scene.call("_current_action_supports_rotation")), "A single outcrop offers no Rotate")
	scene.set("_pending_actions", [spine])
	expect.call(not bool(scene.call("_current_action_supports_rotation")), "Worldspine offers no Rotate")
	var rampart_prepared: Dictionary = _prepared(engine, state, "w4c_fx_rampart")
	var rampart_action: Dictionary = (rampart_prepared["actions"][0] as Dictionary).duplicate(true)
	rampart_action["orientation"] = Vector2i(0, 1)
	expect.call(_preview_matches(engine, rampart_prepared["state"], rampart_action, Vector2i(4, 3)), "A rotated rampart preview equals resolution")
	scene.free()

# ------------------------------------------------------------------ presentation

static func _test_presentation_contracts(engine: CombatEngine, expect: Callable) -> void:
	for card_id: String in FIXTURES.keys():
		for action_var: Variant in (FIXTURES[card_id] as Dictionary)["actions"]:
			var row: Array = ActionIcons.tokens_for_action(action_var as Dictionary)
			expect.call(not row.is_empty(), "%s renders an icon row for %s" % [card_id, str((action_var as Dictionary).get("type", ""))])
	for pair: Array in [["burst_terrain", "terrain_burst"], ["illusion_swap", "illusion_swap"], ["destroy_illusion", "shatter_illusion"]]:
		expect.call(ActionIcons.action_icon_key({"type": pair[0]}) == pair[1], "%s resolves through ACTION_ICON_ALIASES" % pair[0])
	var keg_row: Array = ActionIcons.tokens_for_action((FIXTURES["w4c_fx_powder_keg"] as Dictionary)["actions"][0])
	expect.call(_row_has_icon(keg_row, "detonate"), "The keg row shows its burst")
	var spine_row: Array = ActionIcons.tokens_for_action((FIXTURES["w4c_fx_worldspine"] as Dictionary)["actions"][0])
	expect.call(_row_has_icon(spine_row, "terrain_burst"), "The Worldspine row shows its pulse")
	var refraction_row: Array = ActionIcons.tokens_for_action((FIXTURES["w4c_fx_refraction"] as Dictionary)["actions"][0])
	expect.call(_row_has_icon(refraction_row, "illusion"), "Refraction shows its illusion rider")
	expect.call(ActionIcons.card_role_emblem_key(GameData.card_def("w4c_fx_rockburst")) == "attack_ranged" and ActionIcons.card_role_emblem_key(GameData.card_def("w4c_fx_worldbreak")) == "attack_melee", "Terrain bursts are attacks for the role emblem")
	for role_pair: Array in [["w4c_fx_powder_keg", "attack_ranged"], ["w4c_fx_worldspine", "attack_ranged"], ["w4c_fx_rampart", "block"], ["w4c_fx_empty_husk", "illusion"]]:
		expect.call(ActionIcons.card_role_emblem_key(GameData.card_def(str(role_pair[0]))) == str(role_pair[1]), "%s uses the %s role emblem" % [str(role_pair[0]), str(role_pair[1])])
	expect.call(GrimoireLibrary.entry_ids_for_card_def(GameData.card_def("w4c_fx_rockburst")).has("combat:outcrops"), "Burst cards unlock the Outcrops topic")
	expect.call(GrimoireLibrary.entry_ids_for_card_def(GameData.card_def("w4c_fx_empty_husk")).has("keyword:illusion"), "Swap cards unlock the Illusion entry")
	expect.call(GrimoireLibrary.entry_ids_for_card_def(GameData.card_def("w4c_fx_mirror_feint")).has("keyword:expose"), "Mirror Feint unlocks Expose")
	var badges: Array[Dictionary] = IllusionCardRules.illusion_badges({"on_damaged": {"damage": 4, "element": "lightning", "shock": 1}, "source_name": "Ball Lightning"})
	expect.call(badges.size() == 1 and str(badges[0].get("tooltip", "")).contains("Lightning"), "A charged illusion shows a trait badge")
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4))])
	var blast: Dictionary = engine.blast_action_for_player_action(_action(engine, state, "w4c_fx_worldbreak"))
	expect.call(str(blast.get("type", "")) == "aoe" and int(blast.get("damage", 0)) == 10 and int(blast.get("stagger", 0)) == 2, "Worldbreak's blast deals its line damage and Staggers")

static func _test_run_scene_surfaces(engine: CombatEngine, expect: Callable) -> void:
	var scene: Node = RunSceneScript.new()
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4))])
	var display: Dictionary = scene.call("_card_widget_display", "w4c_fx_shattered_reflection", state)
	expect.call(_rows_have_value(display.get("summary_rows", []) as Array, "aoe", 6), "The hand shows Shattered Reflection's blast damage")
	var worldbreak_display: Dictionary = scene.call("_card_widget_display", "w4c_fx_worldbreak", state)
	expect.call(_rows_have_value(worldbreak_display.get("summary_rows", []) as Array, "aoe", 10), "The hand shows Worldbreak's line damage")
	expect.call(str(scene.call("_action_prompt", _action(engine, state, "w4c_fx_mirror_feint"))) == "Target" and str(scene.call("_action_prompt", _action(engine, state, "w4c_fx_hall_of_mirrors"))) == "Resolve", "Prompts name an enemy target or an immediate resolve")
	var with_illusion: Dictionary = _with_illusion(engine, state, Vector2i(4, 4), 3)
	var focus: Array[Vector2i] = scene.call("_illusion_terrain_focus_tiles", with_illusion, _action(engine, with_illusion, "w4c_fx_shattered_reflection"), Vector2i(4, 4))
	expect.call(focus.has(Vector2i(4, 4)) and focus.has(Vector2i(5, 4)) and focus.size() == 5, "Hover focus shows the shattered tile and its neighbors")
	# A shot from a Doppelganger keeps its own arc from the illusion while the hand arrow aims.
	var doppel: Dictionary = _resolve(engine, _state(engine, [_enemy(1, Vector2i(7, 4))]), "w4c_fx_doppelganger", Vector2i(4, 4))
	var shot: Dictionary = _action(engine, doppel, "w4c_fx_shot")
	var origin_shot: Dictionary = engine.action_with_automatic_origin(doppel, shot, Vector2i(7, 4))
	scene.set("_run_state", {"mode": "combat"})
	scene.set("_selected_card_index", 0)
	scene.set("_pending_actions", [origin_shot])
	scene.set("_pending_action_index", 0)
	var pending_tiles: Array[Vector2i]
	pending_tiles.append(Vector2i(7, 4))
	scene.set("_pending_target_tiles", pending_tiles)
	var origin_effect: Dictionary = scene.call("_preview_effect_for_target", doppel, origin_shot.get("_origin_tile", PLAYER_TILE), Vector2i(7, 4), origin_shot)
	expect.call(origin_effect.get("from", NO_TARGET) == Vector2i(4, 4) and bool(origin_effect.get("target_curve_visible", false)), "The hover arc starts at the Doppelganger")
	var hero_effect: Dictionary = scene.call("_preview_effect_for_target", doppel, PLAYER_TILE, Vector2i(7, 4), shot)
	expect.call(not bool(hero_effect.get("target_curve_visible", true)), "An ordinary shot leaves aim to the hand arrow")
	scene.free()

static func _row_has_icon(row: Array, icon: String) -> bool:
	for token_var: Variant in row:
		if typeof(token_var) == TYPE_DICTIONARY and str((token_var as Dictionary).get("icon", "")) == icon:
			return true
	return false

static func _rows_have_value(rows: Array, icon: String, value: int) -> bool:
	for row_var: Variant in rows:
		for token_var: Variant in row_var as Array:
			if typeof(token_var) == TYPE_DICTIONARY and str((token_var as Dictionary).get("icon", "")) == icon and str((token_var as Dictionary).get("value", "")) == str(value):
				return true
	return false

extends RefCounted

## Wave-4 family B: area forces, Squall, Swap, Fire trails, self flags, Cleanse,
## Block to Stoneskin, Move/Blink riders, Petrify and the player's Crystal Mantle.
## Fixture cards copy the shapes in spec/card_pool_overhaul/card_defs.py;
## data/cards.json is untouched. See spec/card_mechanics_maneuver.md.

const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const GrimoireLibrary = preload("res://scripts/grimoire_library.gd")
const ManeuverRules = preload("res://scripts/maneuver_rules.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")

const NO_TARGET: Vector2i = Vector2i(-1, -1)
const PLAYER: Vector2i = Vector2i(2, 5)
const ADJ: Array = [[0, -1], [1, 0], [0, 1], [-1, 0]]
const CROSS: Array = [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]]

const FIXTURES: Dictionary = {
	"w4b_gale_ward": {"actions": [{"type": "block", "amount": 5}, {"type": "force_area", "center": "self", "radius": 1, "push": 1}], "time": 3},
	"w4b_bottled_gale": {"actions": [{"type": "force_area", "center": "self", "radius": 1, "push": 3}], "time": 3},
	"w4b_unsealed_gale": {"actions": [{"type": "force_area", "center": "self", "radius": 3, "push": 3}], "time": 6, "burn": true},
	"w4b_dust_devil": {"actions": [{"type": "force_area", "center": "target", "range": 3, "radius": 1, "push": 2, "expose": 2, "consume_center": "rubble"}], "time": 4},
	"w4b_vortex": {"actions": [{"type": "force_area", "center": "target", "range": 3, "radius": 2, "pull": 1}], "time": 5},
	"w4b_cyclone_seal": {"burn": true, "time": 7, "actions": [
		{"type": "force_area", "center": "target", "range": 3, "radius": 3, "pull": 3},
		{"type": "aoe", "damage": 6, "range": 0, "pattern": ADJ, "rotate": false, "element": "air", "target": "previous_target"}]},
	"w4b_squall": {"actions": [{"type": "aoe", "damage": 2, "range": 3, "pattern": CROSS, "rotate": false, "element": "air", "push": 1, "force_mode": "from_center"}], "time": 5},
	"w4b_changing_winds": {"actions": [{"type": "swap", "range": 3, "targets": ["enemy", "illusion"]}], "time": 3},
	"w4b_fan_the_flames": {"actions": [{"type": "push", "damage": 2, "range": 3, "amount": 2, "element": "air", "trail_surface": "fire"}], "time": 4},
	"w4b_sleet_squall": {"actions": [{"type": "push", "damage": 0, "range": 3, "amount": 2, "element": "ice"}, {"type": "ranged", "damage": 3, "range": 3, "element": "ice", "target": "previous_target"}], "time": 5},
	"w4b_skate": {"actions": [{"type": "self_flag", "flag": "ice_skate"}, {"type": "move", "range": 3}], "time": 2},
	"w4b_rooted_stance": {"actions": [{"type": "stoneskin", "amount": 6}, {"type": "self_flag", "flag": "no_move"}], "time": 3},
	"w4b_windbreak": {"actions": [{"type": "block", "amount": 6}, {"type": "self_flag", "flag": "anchored"}], "time": 3},
	"w4b_cinder_trail": {"actions": [{"type": "self_flag", "flag": "fire_immune_turn"}, {"type": "move", "range": 3, "trail_surface": "fire"}], "time": 3},
	"w4b_unpick": {"actions": [{"type": "cleanse", "statuses": ["bleed", "immobilize", "chilled"]}, {"type": "block", "amount": 4}, {"type": "draw", "amount": 1}], "time": 2},
	"w4b_smelling_salts": {"actions": [{"type": "cleanse", "statuses": ["immobilize", "shock", "chilled"]}, {"type": "move", "range": 2}], "time": 3},
	"w4b_shrug_off": {"actions": [{"type": "convert_block_to_stoneskin"}, {"type": "draw", "amount": 1}], "time": 2},
	"w4b_glide": {"actions": [{"type": "move", "range": 3, "origin_surface": "ice"}], "time": 2},
	"w4b_catch_the_wind": {"actions": [{"type": "move", "range": 3, "block_per_tile": 1}], "time": 2},
	"w4b_hotfoot": {"actions": [{"type": "move", "range": 2, "if_started_on_surface": {"surface": "fire", "rewards": [{"type": "block", "amount": 4}, {"type": "draw", "amount": 1}]}}], "time": 2},
	"w4b_joust": {"actions": [{"type": "move", "range": 4, "straight_line": true}, {"type": "melee", "damage": 6, "range": 1, "element": "none", "required": true}], "time": 5},
	"w4b_sunpath_stride": {"actions": [{"type": "move", "range": 4, "trail_light": {"radius": 1, "duration": 2}}], "time": 3},
	"w4b_seek_the_light": {"actions": [{"type": "blink", "range": 5, "destination_requires_light": true}], "time": 2},
	"w4b_grapple": {"actions": [{"type": "blink", "range": 4, "destination_adjacent_to": ["enemy", "terrain"]}], "time": 3},
	"w4b_voidsilk_molt": {"actions": [{"type": "blink", "range": 3, "illusion_at_origin": 4}, {"type": "draw", "amount": 1}], "time": 4},
	"w4b_cloudstep_loop": {"actions": [{"type": "blink", "range": 3, "if_no_adjacent_enemies": [{"type": "card_play", "amount": 1}]}], "time": 3},
	"w4b_petrify": {"actions": [{"type": "petrify", "range": 3, "block": 8}], "time": 6},
	"w4b_crystal_mantle": {"burn": true, "actions": [{"type": "mantle", "amount": 2}], "time": 6},
}

static func run(expect: Callable) -> void:
	GrimoireLibrary.entry_map()
	_install_fixtures()
	var engine: CombatEngine = CombatEngine.new()
	_test_gale_ward_and_bottled_gale(engine, expect)
	_test_unsealed_gale_farthest_first(engine, expect)
	_test_vortex_targets_and_pull(engine, expect)
	_test_cyclone_seal_nearest_first_and_blast(engine, expect)
	_test_dust_devil_consumes_rubble(engine, expect)
	_test_force_area_large_enemy(engine, expect)
	_test_squall_from_center(engine, expect)
	_test_swap(engine, expect)
	_test_fan_the_flames_trail(engine, expect)
	_test_sleet_squall_ordering(engine, expect)
	_test_skate(engine, expect)
	_test_rooted(engine, expect)
	_test_anchored(engine, expect)
	_test_cinder_trail_fireproof(engine, expect)
	_test_cleanse(engine, expect)
	_test_shrug_off(engine, expect)
	_test_move_riders(engine, expect)
	_test_joust_straight_line(engine, expect)
	_test_sunpath_stride(engine, expect)
	_test_blink_riders(engine, expect)
	_test_petrify(engine, expect)
	_test_player_mantle(engine, expect)
	_test_preview_equals_resolution(engine, expect)
	_test_icons_rows_and_grimoire(engine, expect)
	_test_analytics_fields(engine, expect)
	_test_run_scene_presentation(engine, expect)
	_remove_fixtures()

# ------------------------------------------------------------------ fixtures

static func _install_fixtures() -> void:
	var cards: Dictionary = GameData.cards()
	for card_id: String in FIXTURES.keys():
		var card: Dictionary = (FIXTURES[card_id] as Dictionary).duplicate(true)
		card["name"] = card_id.trim_prefix("w4b_").capitalize()
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
		for x: int in range(12):
			row.append("wall" if x == 0 or y == 0 or x == 11 or y == 9 else "stone")
		grid.append(row)
	return grid

static func _enemy(id: int, pos: Vector2i, hp: int = 30, large: bool = false) -> Dictionary:
	var enemy: Dictionary = {"id": id, "type": "crawler", "pos": pos, "hp": hp, "max_hp": maxi(hp, 30), "block": 0, "stoneskin": 0}
	if large:
		enemy["footprint"] = Vector2i(2, 2)
	return enemy

static func _state(engine: CombatEngine, enemies: Array, player_pos: Vector2i = PLAYER, terrain: Array = []) -> Dictionary:
	var layout: Dictionary = {
		"name": "Maneuver proof", "type": "combat", "coord": Vector2i(1, 1), "depth": 1,
		"element": "air", "umbra_stage": "clear", "grid": _grid(),
		"player_start": player_pos, "terrain": terrain.duplicate(true), "traps": [], "loot": [],
		"enemies": enemies.duplicate(true),
	}
	var state: Dictionary = engine.create_combat(41207, layout, {"hp": 40, "max_hp": 40, "deck_cards": ["w4b_gale_ward", "w4b_gale_ward", "w4b_gale_ward", "w4b_gale_ward"], "hand_size": 0, "relics": [], "cards_per_turn": 8})
	state["player"] = {"pos": player_pos, "hp": 40, "max_hp": 40, "block": 0, "stoneskin": 0}
	var placed: Array = []
	for enemy_var: Variant in state.get("enemies", []):
		var enemy: Dictionary = (enemy_var as Dictionary).duplicate(true)
		for source_var: Variant in enemies:
			if int((source_var as Dictionary).get("id", -1)) == int(enemy.get("id", -2)):
				enemy["pos"] = (source_var as Dictionary).get("pos")
				enemy["hp"] = (source_var as Dictionary).get("hp")
				if (source_var as Dictionary).has("footprint"):
					enemy["footprint"] = (source_var as Dictionary)["footprint"]
		placed.append(enemy)
	state["enemies"] = placed
	state["terrain"] = terrain.duplicate(true)
	state["surfaces"] = {}
	state["player_turn_restrictions"] = {}
	state["cards_played_this_turn"] = 0
	ManeuverRules.record_activation_start(state)
	return state

## Resolve the card's actions like a hand play, consuming one target per targeted action.
static func _resolve(engine: CombatEngine, state: Dictionary, card_id: String, targets: Array = []) -> Dictionary:
	var working: Dictionary = state.duplicate(true)
	var cursor: int = 0
	for action_var: Variant in engine.card_play_actions(card_id, working):
		var action: Dictionary = action_var as Dictionary
		var tile: Vector2i = NO_TARGET
		if engine.player_action_needs_target(action):
			tile = targets[cursor] if cursor < targets.size() else NO_TARGET
			cursor += 1
		working = engine.apply_player_action(working, action, tile)
	return working

static func _action(engine: CombatEngine, card_id: String, index: int = 0) -> Dictionary:
	return engine.card_play_actions(card_id, {})[index] as Dictionary

static func _unit(state: Dictionary, id: int) -> Dictionary:
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("id", -1)) == id:
			return enemy
	return {}

static func _pos(state: Dictionary, id: int) -> Vector2i:
	return _unit(state, id).get("pos", NO_TARGET)

static func _hp(state: Dictionary, id: int) -> int:
	return int(_unit(state, id).get("hp", 0))

static func _player(state: Dictionary) -> Dictionary:
	return state.get("player", {}) as Dictionary

static func _events(before: Dictionary, after: Dictionary, kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in ManeuverRules._events_since(before, after):
		if str(event.get("kind", "")) == kind:
			result.append(event)
	return result

# ------------------------------------------------------------------ force_area

static func _test_gale_ward_and_bottled_gale(engine: CombatEngine, expect: Callable) -> void:
	var walls: Array = [{"id": "crate_a", "kind": "wooden_crate", "pos": Vector2i(2, 3), "hp": 10, "max_hp": 10}]
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(3, 5)), _enemy(2, Vector2i(2, 4)), _enemy(3, Vector2i(5, 5))], PLAYER, walls)
	var after: Dictionary = _resolve(engine, state, "w4b_gale_ward")
	expect.call(int(_player(after).get("block", 0)) == 5, "Gale Ward grants its Block")
	expect.call(_pos(after, 1) == Vector2i(4, 5), "Gale Ward pushes an adjacent enemy one tile straight away from you")
	expect.call(_pos(after, 2) == Vector2i(2, 4) and _hp(after, 2) == 28, "An adjacent enemy pinned against a crate collides (2 damage) instead of moving")
	expect.call(_pos(after, 3) == Vector2i(5, 5) and _hp(after, 3) == 30, "Enemies outside the radius are untouched")
	expect.call(_events(state, after, ManeuverRules.FORCE_AREA_EVENT).size() == 1, "An area force records one force_area board event")
	var lonely: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 5))])
	expect.call(not engine.player_action_can_resolve(lonely, _action(engine, "w4b_bottled_gale")), "Bottled Gale cannot resolve (is unplayable) with no adjacent enemy")
	expect.call(engine.player_action_can_resolve(state, _action(engine, "w4b_bottled_gale")), "Bottled Gale resolves when an adjacent enemy would move or collide")
	expect.call(not engine.player_action_needs_target(_action(engine, "w4b_gale_ward", 1)), "A self-centered area force needs no target")

static func _test_unsealed_gale_farthest_first(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(3, 5)), _enemy(2, Vector2i(4, 5))])
	var after: Dictionary = _resolve(engine, state, "w4b_unsealed_gale")
	expect.call(_pos(after, 2) == Vector2i(7, 5) and _pos(after, 1) == Vector2i(6, 5), "Pushes resolve farthest from the center first, so a line of enemies travels without colliding")
	expect.call(_hp(after, 1) == 30 and _hp(after, 2) == 30, "No collision damage when the farther enemy clears the lane first")

static func _test_vortex_targets_and_pull(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 5)), _enemy(2, Vector2i(4, 3)), _enemy(3, Vector2i(5, 6))], Vector2i(2, 5))
	var action: Dictionary = _action(engine, "w4b_vortex")
	expect.call(engine.player_action_needs_target(action), "A tile-centered area force needs a target tile")
	var targets: Array[Vector2i] = engine.valid_targets_for_player_action(state, action)
	expect.call(targets.has(Vector2i(4, 5)), "Vortex may center on empty floor in range and sight")
	expect.call(not targets.has(Vector2i(2, 2)), "Vortex cannot target a tile whose radius holds no enemy to move")
	var after: Dictionary = _resolve(engine, state, "w4b_vortex", [Vector2i(4, 5)])
	expect.call(_pos(after, 1) == Vector2i(5, 5), "Vortex pulls an aligned enemy one tile straight toward the center")
	expect.call(_pos(after, 2) == Vector2i(4, 4), "Vortex pulls along the default (larger) axis toward the center")
	expect.call(_pos(after, 3) == Vector2i(4, 6) or _pos(after, 3) == Vector2i(5, 5), "Exact diagonals use the forced-movement default direction rule")
	var occupied: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 5)), _enemy(2, Vector2i(7, 5))])
	var pulled: Dictionary = _resolve(engine, occupied, "w4b_vortex", [Vector2i(5, 5)])
	expect.call(_pos(pulled, 1) == Vector2i(5, 5), "A pull never moves the enemy standing on its center")
	expect.call(_pos(pulled, 2) == Vector2i(6, 5) and _hp(pulled, 2) == 30, "A pull stops without collision when it reaches the enemy on the center")
	var blocked_sight: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 5))], Vector2i(2, 5), [{"id": "rock", "kind": "crag_outcrop", "pos": Vector2i(3, 5), "hp": 3, "max_hp": 3, "blocks_sight": true}])
	expect.call(not engine.valid_targets_for_player_action(blocked_sight, action).has(Vector2i(5, 5)), "The chosen center needs line of sight")

static func _test_cyclone_seal_nearest_first_and_blast(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 5)), _enemy(2, Vector2i(7, 5)), _enemy(3, Vector2i(4, 2))], Vector2i(2, 5))
	var center: Vector2i = Vector2i(4, 5)
	var after: Dictionary = _resolve(engine, state, "w4b_cyclone_seal", [center])
	expect.call(_pos(after, 1) == Vector2i(5, 5), "The nearest enemy is pulled first and stops beside the center")
	expect.call(_pos(after, 2) == Vector2i(6, 5), "The farther enemy is pulled behind it and collides")
	expect.call(_pos(after, 3) == Vector2i(4, 4), "A third enemy is pulled straight toward the center")
	expect.call(after.get("last_action_target", NO_TARGET) == center, "Cyclone Seal's previous_target is the chosen center")
	expect.call(_hp(after, 1) == 30 - 4 - 6, "The blast at the center hits enemies next to it (collision 2 x 2 lost tiles + blast 6)")
	expect.call(_hp(after, 3) == 24, "The blast hits every enemy next to the chosen center")
	expect.call(_hp(after, 2) == 26, "An enemy not next to the center takes only its collision damage")

static func _test_dust_devil_consumes_rubble(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 5)), _enemy(2, Vector2i(4, 4))], Vector2i(2, 5))
	var action: Dictionary = _action(engine, "w4b_dust_devil")
	expect.call(not engine.valid_targets_for_player_action(state, action).has(Vector2i(4, 5)), "Dust Devil needs Rubble on the chosen tile")
	Surface.place(state, Vector2i(4, 5), "rubble", {"actor_kind": "player"})
	expect.call(engine.valid_targets_for_player_action(state, action).has(Vector2i(4, 5)), "A Rubble tile within range and sight is a legal center")
	var after: Dictionary = _resolve(engine, state, "w4b_dust_devil", [Vector2i(4, 5)])
	expect.call(not Surface.has_rubble(after, Vector2i(4, 5)), "Dust Devil consumes the Rubble first")
	expect.call(_pos(after, 1) == Vector2i(7, 5) and _pos(after, 2) == Vector2i(4, 2), "Each enemy next to the Rubble is pushed 2 straight away from it")
	expect.call(int(_unit(after, 1).get("expose", 0)) == 2 and int(_unit(after, 2).get("expose", 0)) == 2, "Dust Devil Exposes each affected enemy")

static func _test_force_area_large_enemy(engine: CombatEngine, expect: Callable) -> void:
	# A 2x2 body counts from its footprint tile nearest the center.
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(3, 4), 30, true)], Vector2i(2, 5))
	var after: Dictionary = _resolve(engine, state, "w4b_gale_ward")
	expect.call(_pos(after, 1) == Vector2i(4, 4), "A 2x2 enemy whose nearest footprint tile is adjacent is pushed straight away")
	var far: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 3), 30, true)], Vector2i(2, 5))
	expect.call(engine.valid_targets_for_player_action(far, _action(engine, "w4b_vortex")).has(Vector2i(5, 5)), "A 2x2 enemy within radius by any footprint tile makes the center legal")
	var pulled: Dictionary = _resolve(engine, far, "w4b_vortex", [Vector2i(5, 5)])
	expect.call(_pos(pulled, 1) == Vector2i(5, 3), "A 2x2 enemy is pulled along its own straight line toward the center (exact diagonal: horizontal)")

static func _test_squall_from_center(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 5)), _enemy(2, Vector2i(5, 4)), _enemy(3, Vector2i(6, 5))], Vector2i(2, 5))
	var after: Dictionary = _resolve(engine, state, "w4b_squall", [Vector2i(5, 5)])
	expect.call(_pos(after, 2) == Vector2i(5, 3), "Squall pushes an arm enemy away from the pattern's center")
	expect.call(_pos(after, 3) == Vector2i(7, 5), "Squall pushes every arm enemy away from the center, not from you")
	expect.call(_pos(after, 1) == Vector2i(6, 5), "The enemy on the center is pushed away from you (after the arm cleared)")
	expect.call(_hp(after, 1) == 28 and _hp(after, 3) == 28, "Squall's damage still applies to each enemy in the cross")

static func _test_swap(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(4, 5)), _enemy(2, Vector2i(2, 2), 30, true), _enemy(3, Vector2i(9, 5))], Vector2i(2, 5))
	state["illusions"] = [{"id": 7, "pos": Vector2i(2, 7), "hp": 3, "max_hp": 3}]
	Surface.place(state, Vector2i(4, 5), "ice", {"actor_kind": "player"})
	Surface.place(state, PLAYER, "fire", {"actor_kind": "player"})
	var action: Dictionary = _action(engine, "w4b_changing_winds")
	var targets: Array[Vector2i] = engine.valid_targets_for_player_action(state, action)
	expect.call(targets.has(Vector2i(4, 5)) and targets.has(Vector2i(2, 7)), "Swap targets a one-tile enemy or an illusion within range")
	expect.call(not targets.has(Vector2i(2, 3)) and not targets.has(Vector2i(2, 2)), "A 2x2 enemy cannot be swapped")
	expect.call(not targets.has(Vector2i(9, 5)), "Swap respects its range")
	var after: Dictionary = _resolve(engine, state, "w4b_changing_winds", [Vector2i(4, 5)])
	expect.call(_player(after).get("pos") == Vector2i(4, 5) and _pos(after, 1) == PLAYER, "Swap exchanges the hero and the enemy")
	expect.call(bool(_player(after).get("chilled", false)), "The hero arrives normally (Ice Chills on entry)")
	expect.call(_hp(after, 1) < 30, "The enemy arrives normally (Fire burns on entry)")
	var with_illusion: Dictionary = _resolve(engine, state, "w4b_changing_winds", [Vector2i(2, 7)])
	expect.call(_player(with_illusion).get("pos") == Vector2i(2, 7) and ((with_illusion["illusions"] as Array)[0] as Dictionary).get("pos") == PLAYER, "Swap exchanges the hero and an illusion without dispelling it")
	var anchored: Dictionary = state.duplicate(true)
	ManeuverRules.gain_flag(anchored, {"flag": "anchored"})
	expect.call(_player(_resolve(engine, anchored, "w4b_changing_winds", [Vector2i(4, 5)])).get("pos") == Vector2i(4, 5), "Swap is not forced movement: Anchored does not stop it")

static func _test_fan_the_flames_trail(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(4, 5))], Vector2i(2, 5))
	var after: Dictionary = _resolve(engine, state, "w4b_fan_the_flames", [Vector2i(4, 5)])
	expect.call(_pos(after, 1) == Vector2i(6, 5), "Fan the Flames pushes 2")
	expect.call(Surface.has_surface(after, Vector2i(5, 5), "fire") and Surface.has_surface(after, Vector2i(6, 5), "fire"), "Fire lands on each tile passed through, including the final tile")
	expect.call(not Surface.has_surface(after, Vector2i(4, 5), "fire"), "The start tile gets no Fire")
	var large: Dictionary = _state(engine, [_enemy(1, Vector2i(3, 4), 30, true)], Vector2i(2, 5))
	var large_after: Dictionary = _resolve(engine, large, "w4b_fan_the_flames", [Vector2i(3, 5)])
	expect.call(_pos(large_after, 1) == Vector2i(5, 4) and Surface.has_surface(large_after, Vector2i(6, 4), "fire") and Surface.has_surface(large_after, Vector2i(6, 5), "fire"), "A 2x2 target leaves Fire under every footprint tile it passes through")

static func _test_sleet_squall_ordering(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(4, 5))], Vector2i(2, 5))
	Surface.place(state, Vector2i(6, 5), "ice", {"actor_kind": "player"})
	var after: Dictionary = _resolve(engine, state, "w4b_sleet_squall", [Vector2i(4, 5)])
	expect.call(_pos(after, 1) == Vector2i(6, 5), "Sleet Squall's push resolves first")
	expect.call(int(_unit(after, 1).get("freeze", 0)) > 0, "Shoved onto Ice the target is Chilled on entry, and the Ice hit Freezes it")
	expect.call(_hp(after, 1) == 30 - 3 - 2, "The follow-up hit lands on the pushed target with the Chilled bonus")
	var no_ice: Dictionary = _resolve(engine, _state(engine, [_enemy(1, Vector2i(4, 5))], Vector2i(2, 5)), "w4b_sleet_squall", [Vector2i(4, 5)])
	expect.call(_hp(no_ice, 1) == 27 and int(_unit(no_ice, 1).get("freeze", 0)) == 0, "Without Ice the follow-up still hits the moved target but does not Freeze")

# ------------------------------------------------------------------ self flags

static func _test_skate(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(9, 2))], Vector2i(2, 5))
	for x: int in range(3, 7):
		Surface.place(state, Vector2i(x, 5), "ice", {"actor_kind": "player"})
	var move: Dictionary = _action(engine, "w4b_skate", 1)
	expect.call(not engine.valid_targets_for_player_action(state, move).has(Vector2i(7, 5)), "Without Skate, Move 3 cannot cross four Ice tiles")
	var skating: Dictionary = engine.apply_player_action(state, _action(engine, "w4b_skate", 0))
	expect.call(ManeuverRules.player_skating(skating), "Skate sets its flag")
	expect.call(engine.valid_targets_for_player_action(skating, move).has(Vector2i(8, 5)), "With Skate, stepping onto Ice costs no movement")
	var moved: Dictionary = engine.apply_player_action(skating, move, Vector2i(8, 5))
	expect.call(_player(moved).get("pos") == Vector2i(8, 5) and not bool(_player(moved).get("chilled", false)), "Skate's move ends past the Ice and Ice doesn't Chill")
	var stand: Dictionary = engine.apply_player_action(skating, move, Vector2i(6, 5))
	expect.call(not bool(_player(stand).get("chilled", false)), "Stopping on Ice while skating does not Chill")
	var plain: Dictionary = engine.apply_player_action(state, move, Vector2i(4, 5))
	expect.call(bool(_player(plain).get("chilled", false)), "Without Skate, entering Ice Chills")
	var ended: Dictionary = engine.finish_player_activation(skating)
	expect.call(not ManeuverRules.player_skating(ended), "Skate ends with the activation")

static func _test_rooted(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(9, 2))])
	var rooted: Dictionary = _resolve(engine, state, "w4b_rooted_stance")
	expect.call(int(_player(rooted).get("stoneskin", 0)) == 6 and ManeuverRules.player_rooted(rooted), "Rooted Stance grants Stoneskin and roots you")
	expect.call(not engine.player_action_can_resolve(rooted, {"type": "move", "range": 2}), "Rooted: a card Move cannot resolve")
	expect.call(not engine.player_action_can_resolve(rooted, {"type": "blink", "range": 2}), "Rooted: a card Blink cannot resolve")
	expect.call(engine.player_movement_targets(rooted).is_empty() and not engine.player_has_movement_target(rooted), "Rooted: independent movement is unavailable")
	expect.call(not ManeuverRules.movement_block_reason(rooted).is_empty(), "Rooted gives the movement meter a reason")
	expect.call(engine.player_action_can_resolve(state, {"type": "move", "range": 2}), "Without the flag a Move resolves")
	var next_turn: Dictionary = engine.finish_player_activation(rooted)
	expect.call(not ManeuverRules.player_rooted(next_turn), "Rooted ends with the activation")

static func _test_anchored(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(3, 5))], Vector2i(2, 5))
	var shove: Dictionary = {"type": "push", "amount": 2, "damage": 0, "range": 1}
	var free: Dictionary = engine._resolve_enemy_action(state.duplicate(true), 0, shove)
	expect.call(_player(free).get("pos") != PLAYER, "Without Anchored an enemy push moves you")
	var anchored: Dictionary = _resolve(engine, state, "w4b_windbreak")
	expect.call(int(_player(anchored).get("block", 0)) == 6 and ManeuverRules.player_anchored(anchored), "Windbreak grants Block and Anchored")
	var held: Dictionary = engine._resolve_enemy_action(anchored.duplicate(true), 0, shove)
	expect.call(_player(held).get("pos") == PLAYER, "Anchored: forced movement against you has 0 distance")
	expect.call(int(_player(held).get("block", 0)) == 6 and int(_player(held).get("hp", 0)) == 40, "Anchored: no collision damage")
	var walled: Dictionary = _state(engine, [_enemy(1, Vector2i(2, 4))], Vector2i(2, 8))
	ManeuverRules.gain_flag(walled, {"flag": "anchored"})
	var pinned: Dictionary = engine._resolve_enemy_action(walled, 0, {"type": "push", "amount": 3, "damage": 0, "range": 9})
	expect.call(int(_player(pinned).get("hp", 0)) == 40, "Anchored against a wall still never collides")
	var through_turn: Dictionary = engine.finish_player_activation(anchored)
	expect.call(ManeuverRules.player_anchored(through_turn), "Anchored lasts through the enemy turns")
	var next_turn: Dictionary = engine.prepare_next_player_turn(through_turn)
	expect.call(not ManeuverRules.player_anchored(next_turn), "Anchored ends when your next turn starts")

static func _test_cinder_trail_fireproof(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(9, 2))], Vector2i(2, 5))
	Surface.place(state, Vector2i(3, 5), "fire", {"actor_kind": "enemy"})
	var after: Dictionary = _resolve(engine, state, "w4b_cinder_trail", [Vector2i(5, 5)])
	expect.call(_player(after).get("pos") == Vector2i(5, 5) and int(_player(after).get("hp", 0)) == 40, "Fireproof: walking through Fire deals no damage this turn")
	expect.call(Surface.has_surface(after, PLAYER, "fire") and Surface.has_surface(after, Vector2i(4, 5), "fire"), "Cinder Trail leaves Fire on each tile you leave")
	expect.call(not Surface.has_surface(after, Vector2i(5, 5), "fire"), "Cinder Trail leaves no Fire on the destination")
	var exposed: Dictionary = engine.apply_player_action(state, {"type": "move", "range": 3}, Vector2i(3, 5))
	expect.call(int(_player(exposed).get("hp", 0)) < 40, "Without the flag, entering Fire hurts")
	var ended: Dictionary = engine.finish_player_activation(after)
	expect.call(not ManeuverRules.player_fire_immune(ended), "Fireproof ends with the activation")

# ------------------------------------------------------------------ cleanse / convert

static func _test_cleanse(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(9, 2))], Vector2i(2, 5))
	Surface.place(state, PLAYER, "ice", {"actor_kind": "enemy"})
	var player: Dictionary = _player(state)
	player["bleed"] = 2
	player["chilled"] = true
	player["immobilize"] = true
	state["player"] = player
	state["player_turn_restrictions"] = {"immobilized": true}
	var cleaned: Dictionary = _resolve(engine, state, "w4b_unpick")
	var p: Dictionary = _player(cleaned)
	expect.call(int(p.get("bleed", 0)) == 0 and not bool(p.get("chilled", false)) and not bool(p.get("immobilize", false)), "Unpick removes Bleed, Chilled and Immobilize")
	expect.call(not bool((cleaned.get("player_turn_restrictions", {}) as Dictionary).get("immobilized", false)), "Cleansing Immobilize lifts this turn's restriction")
	expect.call(int(p.get("block", 0)) == 4, "Unpick still grants its Block")
	expect.call(engine.player_action_can_resolve(cleaned, {"type": "move", "range": 2}), "After Unpick you can move again")
	expect.call(Surface.has_surface(cleaned, PLAYER, "ice") and not bool(_player(cleaned).get("chilled", false)), "Removing Chilled on Ice keeps you unchilled while you stay")
	var rechill: Dictionary = cleaned.duplicate(true)
	Surface.place(rechill, Vector2i(2, 4), "ice", {"actor_kind": "enemy"})
	var stepped: Dictionary = engine.apply_player_action(rechill, {"type": "move", "range": 1}, Vector2i(2, 4))
	expect.call(bool(_player(stepped).get("chilled", false)), "Entering Ice again Chills as usual")
	var shocked: Dictionary = state.duplicate(true)
	shocked["player_turn_restrictions"] = {"shocked": true, "immobilized": true}
	var salts: Dictionary = _action(engine, "w4b_smelling_salts", 0)
	expect.call(engine.player_action_can_resolve(shocked, salts), "A cleanse that removes Shock can be played while Shocked")
	expect.call(not engine.player_action_can_resolve(shocked, _action(engine, "w4b_unpick", 0)), "A cleanse without Shock still obeys the Shock restriction")
	var after_salts: Dictionary = _resolve(engine, shocked, "w4b_smelling_salts", [Vector2i(3, 5)])
	expect.call(_player(after_salts).get("pos") == Vector2i(3, 5), "Smelling Salts removes Immobilize and Shock, then its Move resolves")
	var clean_state: Dictionary = _state(engine, [_enemy(1, Vector2i(9, 2))])
	expect.call(_events(clean_state, _resolve(engine, clean_state, "w4b_unpick"), ManeuverRules.CLEANSE_EVENT).is_empty(), "Nothing to cleanse records no cleanse event")

static func _test_shrug_off(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(9, 2))])
	var player: Dictionary = _player(state)
	player["block"] = 7
	player["stoneskin"] = 2
	state["player"] = player
	var after: Dictionary = _resolve(engine, state, "w4b_shrug_off")
	expect.call(int(_player(after).get("block", 0)) == 0 and int(_player(after).get("stoneskin", 0)) == 9, "Shrug Off turns all Block into Stoneskin")
	var none: Dictionary = _resolve(engine, _state(engine, [_enemy(1, Vector2i(9, 2))]), "w4b_shrug_off")
	expect.call(int(_player(none).get("stoneskin", 0)) == 0, "With no Block, Shrug Off converts nothing")

# ------------------------------------------------------------------ move riders

static func _test_move_riders(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(9, 2))], Vector2i(2, 5))
	var glided: Dictionary = _resolve(engine, state, "w4b_glide", [Vector2i(5, 5)])
	expect.call(Surface.has_surface(glided, PLAYER, "ice") and not Surface.has_surface(glided, Vector2i(5, 5), "ice"), "Glide leaves Ice only on the tile you started on")
	var caught: Dictionary = _resolve(engine, state, "w4b_catch_the_wind", [Vector2i(4, 5)])
	expect.call(int(_player(caught).get("block", 0)) == 2, "Catch the Wind grants 1 Block per tile actually moved")
	var cold: Dictionary = _resolve(engine, state, "w4b_hotfoot", [Vector2i(3, 5)])
	expect.call(int(_player(cold).get("block", 0)) == 0, "Hotfoot pays nothing when you did not start the turn on Fire")
	var fire_start: Dictionary = state.duplicate(true)
	Surface.place(fire_start, PLAYER, "fire", {"actor_kind": "enemy"})
	ManeuverRules.record_activation_start(fire_start)
	var deck: Dictionary = fire_start["deck"] as Dictionary
	deck["draw"] = ["w4b_gale_ward", "w4b_gale_ward"]
	deck["hand"] = []
	fire_start["deck"] = deck
	var hot: Dictionary = _resolve(engine, fire_start, "w4b_hotfoot", [Vector2i(3, 5)])
	expect.call(int(_player(hot).get("block", 0)) == 4 and ((hot["deck"] as Dictionary)["hand"] as Array).size() == 1, "Hotfoot: started the turn on Fire, gain 4 Block and draw 1")
	var moved_off: Dictionary = state.duplicate(true)
	Surface.place(moved_off, Vector2i(3, 5), "fire", {"actor_kind": "enemy"})
	moved_off["player"]["pos"] = Vector2i(3, 5)
	expect.call(int(_player(_resolve(engine, moved_off, "w4b_hotfoot", [Vector2i(4, 5)])).get("block", 0)) == 0, "Hotfoot checks where the activation started, not where you stand now")

static func _test_joust_straight_line(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(7, 5))], Vector2i(2, 5))
	var move: Dictionary = _action(engine, "w4b_joust", 0)
	var targets: Array[Vector2i] = engine.valid_targets_for_player_action(state, move)
	expect.call(targets.has(Vector2i(6, 5)) and targets.has(Vector2i(2, 1)), "Joust may end anywhere on a clear straight line within 4")
	expect.call(not targets.has(Vector2i(3, 4)) and not targets.has(Vector2i(4, 6)), "Joust cannot end off its straight lines")
	var path: Array[Vector2i] = engine.path_for_player_action(state, move, Vector2i(6, 5))
	expect.call(path.size() == 5 and path[0] == PLAYER and path[4] == Vector2i(6, 5), "Joust's path is the straight line")
	var plan: Dictionary = engine.movement_plan_for_player_action(state, move)
	expect.call(not (plan.get("target_tiles", []) as Array).has(Vector2i(3, 4)), "The move-then-attack plan uses the same straight lines")
	var blocked: Dictionary = _state(engine, [_enemy(1, Vector2i(4, 5))], Vector2i(2, 5))
	expect.call(not engine.valid_targets_for_player_action(blocked, move).has(Vector2i(5, 5)), "An enemy on the line blocks travel past it")
	var after: Dictionary = _resolve(engine, state, "w4b_joust", [Vector2i(6, 5), Vector2i(7, 5)])
	expect.call(_hp(after, 1) == 24, "Joust's strike lands after the straight move")

static func _test_sunpath_stride(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(9, 2))], Vector2i(2, 5))
	var after: Dictionary = _resolve(engine, state, "w4b_sunpath_stride", [Vector2i(5, 5)])
	var lit: Array = []
	for source: Dictionary in (after.get("umbra", {}) as Dictionary).get("light_sources", []):
		lit.append(source.get("pos"))
	expect.call(lit.has(Vector2i(3, 5)) and lit.has(Vector2i(4, 5)) and lit.has(Vector2i(5, 5)) and not lit.has(PLAYER), "Sunpath Stride leaves Light on each tile entered, not the start")

# ------------------------------------------------------------------ blink riders

static func _test_blink_riders(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 5))], Vector2i(2, 5), [{"id": "crate_b", "kind": "wooden_crate", "pos": Vector2i(2, 2), "hp": 3, "max_hp": 3}])
	var seek: Dictionary = _action(engine, "w4b_seek_the_light")
	expect.call(engine.valid_targets_for_player_action(state, seek).is_empty(), "Seek the Light needs a lit destination")
	var lit: Dictionary = engine._create_umbra_light_source(state.duplicate(true), Vector2i(4, 7), {"radius": 1, "duration": 2, "silent": true})
	var lit_targets: Array[Vector2i] = engine.valid_targets_for_player_action(lit, seek)
	expect.call(lit_targets.has(Vector2i(4, 7)) and lit_targets.has(Vector2i(4, 6)) and not lit_targets.has(Vector2i(3, 5)), "Seek the Light targets only tiles in Light")
	var grapple: Array[Vector2i] = engine.valid_targets_for_player_action(state, _action(engine, "w4b_grapple"))
	expect.call(grapple.has(Vector2i(5, 5)) and grapple.has(Vector2i(2, 3)), "Grapple lands next to an enemy or terrain")
	expect.call(not grapple.has(Vector2i(4, 5)) and not grapple.has(Vector2i(5, 4)), "Grapple rejects tiles next to neither")
	var large: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 4), 30, true)], Vector2i(4, 5))
	expect.call(engine.valid_targets_for_player_action(large, _action(engine, "w4b_grapple")).has(Vector2i(5, 5)), "Grapple counts every footprint tile of a 2x2 enemy")
	var molted: Dictionary = _resolve(engine, state, "w4b_voidsilk_molt", [Vector2i(4, 5)])
	var illusions: Array = molted.get("illusions", []) as Array
	expect.call(illusions.size() == 1 and (illusions[0] as Dictionary).get("pos") == PLAYER and int((illusions[0] as Dictionary).get("hp", 0)) == 4, "Voidsilk Molt leaves a 4-health illusion where you stood")
	var alone: Dictionary = _resolve(engine, state, "w4b_cloudstep_loop", [Vector2i(3, 7)])
	expect.call(int(alone.get("card_play_bonus_this_turn", 0)) == 1, "Cloudstep Loop: no adjacent enemy after the Blink gains 1 card play")
	var crowded: Dictionary = _resolve(engine, state, "w4b_cloudstep_loop", [Vector2i(5, 5)])
	expect.call(int(crowded.get("card_play_bonus_this_turn", 0)) == 0, "Cloudstep Loop: ending next to an enemy gains nothing")

# ------------------------------------------------------------------ petrify

static func _test_petrify(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(4, 5)), _enemy(2, Vector2i(7, 2), 30, true)], Vector2i(2, 5))
	var action: Dictionary = _action(engine, "w4b_petrify")
	var targets: Array[Vector2i] = engine.valid_targets_for_player_action(state, action)
	expect.call(targets.has(Vector2i(4, 5)), "Petrify targets a visible enemy in range")
	var dragon_state: Dictionary = state.duplicate(true)
	dragon_state["enemies"][1]["type"] = "tharokh"
	dragon_state["enemies"][1]["pos"] = Vector2i(4, 3)
	expect.call(not engine.valid_targets_for_player_action(dragon_state, action).has(Vector2i(4, 3)), "Dragons cannot be Petrified")
	var large_state: Dictionary = state.duplicate(true)
	large_state["enemies"][1]["pos"] = Vector2i(3, 2)
	expect.call(engine.valid_targets_for_player_action(large_state, action).has(Vector2i(4, 2)), "A non-dragon 2x2 enemy is targetable by any footprint tile")
	var petrified: Dictionary = _resolve(engine, state, "w4b_petrify", [Vector2i(4, 5)])
	var enemy: Dictionary = _unit(petrified, 1)
	expect.call(int(enemy.get("block", 0)) == 8 and ManeuverRules.is_petrified(enemy), "Petrify grants 8 Block and marks the enemy")
	expect.call(int(enemy.get("freeze", 0)) == 0, "Petrify is not Freeze")
	var entries: Array[Dictionary] = engine.current_turn_order(petrified)
	var marked: bool = false
	for entry: Dictionary in entries:
		if str(entry.get("kind", "")) == "enemy" and int(entry.get("enemy_id", -1)) == 1 and bool(entry.get("petrified", false)):
			marked = true
	expect.call(marked, "The turn order marks the Petrified enemy's next activation")
	var index: int = engine._enemy_index_for_id(petrified, 1)
	var intent_time: int = engine._enemy_intent_time_cost((enemy.get("intent", {}) as Dictionary))
	var skipped: Dictionary = engine.resolve_enemy_turn_with_steps(petrified, index)
	var skipped_state: Dictionary = skipped["state"] as Dictionary
	expect.call(int(skipped.get("time_cost", -1)) == intent_time and intent_time > 0, "A Petrified skip still costs its normal intent Time")
	expect.call(int(_unit(skipped_state, 1).get("block", 0)) == 8 and _hp(skipped_state, 1) == 30, "Petrify Block survives the skipped activation")
	expect.call(not ManeuverRules.is_petrified(_unit(skipped_state, 1)), "Petrify is consumed by the skipped activation")
	expect.call(_player(skipped_state).get("pos") == PLAYER and int(_player(skipped_state).get("hp", 0)) == 40, "The Petrified enemy takes no action")
	var labels: Array = []
	for step: Dictionary in skipped.get("steps", []):
		labels.append(str(step.get("label", "")))
	expect.call(labels.has("Petrified"), "The skipped activation shows a Petrified status step")
	var frozen: Dictionary = state.duplicate(true)
	frozen["enemies"][0]["freeze"] = 1
	var frozen_skip: Dictionary = engine.resolve_enemy_turn_with_steps(frozen, 0)
	expect.call(int(frozen_skip.get("time_cost", -1)) == 0, "Freeze keeps its existing early return (time cost 0)")
	var next_real: Dictionary = engine.resolve_enemy_turn_with_steps(skipped_state, engine._enemy_index_for_id(skipped_state, 1))
	expect.call(int(_unit(next_real["state"] as Dictionary, 1).get("block", 0)) < 8, "The next real activation clears the Petrify Block like any enemy Block")
	var as_frozen: Dictionary = petrified.duplicate(true)
	as_frozen["enemies"][index]["petrify"] = 0
	as_frozen["enemies"][index]["freeze"] = 1
	expect.call(engine.enemy_threat_tiles(petrified, index) == engine.enemy_threat_tiles(as_frozen, index), "A Petrified enemy's threat preview plans like a Frozen one")

# ------------------------------------------------------------------ mantle

static func _test_player_mantle(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(3, 5))], Vector2i(2, 5))
	var mantled: Dictionary = _resolve(engine, state, "w4b_crystal_mantle")
	expect.call(int(_player(mantled).get("frost_armor", 0)) == 2, "Crystal Mantle grants 2 layers")
	var hit: Dictionary = engine._resolve_enemy_action(mantled.duplicate(true), 0, {"type": "melee", "damage": 5, "range": 1})
	expect.call(int(_player(hit).get("hp", 0)) == 40 and int(_player(hit).get("frost_armor", 0)) == 1, "A direct hit breaks one layer instead of dealing damage")
	expect.call(not _events(mantled, hit, "crystal_mantle_broken").is_empty(), "The broken layer records crystal_mantle_broken")
	var losses: Array[Dictionary] = engine._actor_target_losses(mantled, hit)
	expect.call(losses.size() == 1 and int(losses[0].get("mantle_loss", 0)) == 1, "Target losses report the absorbed hit so the attack animation plays")
	var step: Dictionary = engine._enemy_action_step(mantled, hit, 0, {"type": "melee", "damage": 5, "range": 1})
	expect.call(not step.is_empty(), "A fully absorbed hit still produces the enemy attack step")
	var burned: Dictionary = mantled.duplicate(true)
	Surface.place(burned, Vector2i(2, 4), "fire", {"actor_kind": "enemy"})
	burned = engine.apply_player_action(burned, {"type": "move", "range": 1}, Vector2i(2, 4))
	expect.call(int(_player(burned).get("hp", 0)) < 40 and int(_player(burned).get("frost_armor", 0)) == 2, "Fire ignores Mantle")
	var bled: Dictionary = engine._damage_player(mantled.duplicate(true), 3, false, false, "bleed")
	expect.call(int(_player(bled).get("frost_armor", 0)) == 2 and int(_player(bled).get("hp", 0)) == 37, "Bleed ignores Mantle")
	var collided: Dictionary = engine._damage_player(mantled.duplicate(true), 4, false, false, "collision")
	expect.call(int(_player(collided).get("frost_armor", 0)) == 2, "Collision ignores Mantle")
	var fatigue: Dictionary = engine._lose_player_health(mantled.duplicate(true), 2, true, true, "fatigue", true)
	expect.call(int(_player(fatigue).get("frost_armor", 0)) == 2, "Fatigue health loss ignores Mantle")
	var second: Dictionary = engine._resolve_enemy_action(hit.duplicate(true), 0, {"type": "melee", "damage": 5, "range": 1})
	var third: Dictionary = engine._resolve_enemy_action(second.duplicate(true), 0, {"type": "melee", "damage": 5, "range": 1})
	expect.call(int(_player(third).get("hp", 0)) == 35, "Once every layer is broken, hits land normally")
	var next_turn: Dictionary = engine.prepare_next_player_turn(engine.finish_player_activation(mantled))
	expect.call(int(_player(next_turn).get("frost_armor", 0)) == 2, "Mantle lasts until broken (not cleared at turn start)")

# ------------------------------------------------------------------ preview == resolution

static func _test_preview_equals_resolution(engine: CombatEngine, expect: Callable) -> void:
	var cases: Array = [
		["w4b_vortex", Vector2i(4, 5), [_enemy(1, Vector2i(6, 5)), _enemy(2, Vector2i(4, 3))]],
		["w4b_squall", Vector2i(5, 5), [_enemy(1, Vector2i(5, 5)), _enemy(2, Vector2i(5, 4))]],
		["w4b_changing_winds", Vector2i(4, 5), [_enemy(1, Vector2i(4, 5))]],
		["w4b_petrify", Vector2i(4, 5), [_enemy(1, Vector2i(4, 5))]],
		["w4b_fan_the_flames", Vector2i(4, 5), [_enemy(1, Vector2i(4, 5)), _enemy(2, Vector2i(7, 5))]],
		["w4b_cyclone_seal", Vector2i(4, 5), [_enemy(1, Vector2i(6, 5)), _enemy(2, Vector2i(7, 5))]],
	]
	for case_var: Variant in cases:
		var case: Array = case_var as Array
		var state: Dictionary = _state(engine, case[2] as Array, Vector2i(2, 5))
		var action: Dictionary = _action(engine, str(case[0]))
		var preview: Dictionary = engine.surface_preview_for_player_action(state, action, case[1], true)["state"]
		var committed: Dictionary = engine.apply_player_action(state, action, case[1])
		var same: bool = _player(preview).get("pos") == _player(committed).get("pos")
		for enemy: Dictionary in committed.get("enemies", []):
			var id: int = int(enemy.get("id", -1))
			same = same and _pos(preview, id) == enemy.get("pos") and _hp(preview, id) == int(enemy.get("hp", 0)) and int(_unit(preview, id).get("block", 0)) == int(enemy.get("block", 0))
		same = same and (preview.get("surfaces", {}) as Dictionary) == (committed.get("surfaces", {}) as Dictionary)
		expect.call(same, "%s: hover forecast equals the committed result" % str(case[0]))
	var gale: Dictionary = _state(engine, [_enemy(1, Vector2i(3, 5))])
	var gale_action: Dictionary = _action(engine, "w4b_gale_ward", 1)
	expect.call(_pos(engine.surface_preview_for_player_action(gale, gale_action, NO_TARGET)["state"], 1) == _pos(engine.apply_player_action(gale, gale_action), 1), "Self-centered area force: forecast equals commit")

# ------------------------------------------------------------------ icons, rows, grimoire

static func _test_icons_rows_and_grimoire(engine: CombatEngine, expect: Callable) -> void:
	for action_type: String in ["force_area", "swap", "self_flag", "cleanse", "convert_block_to_stoneskin", "mantle", "petrify"]:
		var key: String = str(ActionIcons.ACTION_ICON_ALIASES.get(action_type, ""))
		expect.call(not key.is_empty() and ActionIcons.KEYWORDS.has(key), "%s maps to a registered icon" % action_type)
	expect.call(ActionIcons.action_icon_key(_action(engine, "w4b_vortex")) == "pull", "A pulling area shows the Pull icon")
	expect.call(ActionIcons.action_icon_key(_action(engine, "w4b_gale_ward", 1)) == "push", "A pushing area shows the Push icon")
	for card_id: String in FIXTURES.keys():
		var rows: Array = ActionIcons.rows_for_card(GameData.card_def(card_id))
		var tokens: int = 0
		for row_var: Variant in rows:
			tokens += (row_var as Array).size()
		expect.call(tokens > 0, "%s renders icon rows" % card_id)
	var wanted: Dictionary = {}
	GrimoireLibrary._collect_entry_ids_for_card_def(GameData.card_def("w4b_cyclone_seal"), wanted)
	expect.call(wanted.has("combat:area_force") and wanted.has("keyword:pull"), "Cyclone Seal teaches area forces and Pull")
	for pair: Array in [["w4b_changing_winds", "combat:swap"], ["w4b_skate", "combat:stances"], ["w4b_unpick", "combat:cleanse"], ["w4b_petrify", "combat:petrify"], ["w4b_crystal_mantle", "combat:crystal_armor"], ["w4b_shrug_off", "keyword:stoneskin"], ["w4b_cinder_trail", "keyword:surface_fire"], ["w4b_squall", "combat:area_force"]]:
		var ids: Dictionary = {}
		GrimoireLibrary._collect_entry_ids_for_card_def(GameData.card_def(str(pair[0])), ids)
		expect.call(ids.has(str(pair[1])), "%s links grimoire entry %s" % [str(pair[0]), str(pair[1])])
		expect.call(GrimoireLibrary.entry_map().has(str(pair[1])), "Grimoire entry %s exists" % str(pair[1]))

static func _test_analytics_fields(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(4, 5))], Vector2i(2, 5))
	var swapped: Dictionary = _resolve(engine, state, "w4b_changing_winds", [Vector2i(4, 5)])
	var fields: Dictionary = ManeuverRules.analytics_fields(state, swapped)
	expect.call(str(fields.get("swapped_with", "")) == "enemy", "Analytics records the swap partner kind")
	var petrified: Dictionary = ManeuverRules.analytics_fields(state, _resolve(engine, state, "w4b_petrify", [Vector2i(4, 5)]))
	expect.call((petrified.get("petrified_enemy_ids", []) as Array) == [1], "Analytics records Petrified enemy ids")
	var flagged: Dictionary = ManeuverRules.analytics_fields(state, _resolve(engine, state, "w4b_windbreak"))
	expect.call((flagged.get("self_flags_gained", []) as Array) == ["anchored"], "Analytics records gained self flags")
	var mantle: Dictionary = ManeuverRules.analytics_fields(state, _resolve(engine, state, "w4b_crystal_mantle"))
	expect.call(int(mantle.get("mantle_gained", 0)) == 2, "Analytics records Mantle gained")
	var gust: Dictionary = ManeuverRules.analytics_fields(state, _resolve(engine, _state(engine, [_enemy(1, Vector2i(3, 5))]), "w4b_gale_ward"))
	expect.call(int(gust.get("force_area_displaced", 0)) == 1, "Analytics counts enemies an area force displaced")

# ------------------------------------------------------------------ run scene

static func _test_run_scene_presentation(engine: CombatEngine, expect: Callable) -> void:
	var scene: Node = RunSceneScript.new()
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 5)), _enemy(2, Vector2i(7, 5))], Vector2i(2, 5))
	var after: Dictionary = engine.apply_player_action(state, _action(engine, "w4b_cyclone_seal"), Vector2i(4, 5))
	var result: Dictionary = {}
	scene.call("_append_forced_displacement_preview", result, state, after)
	expect.call((result.get("displacement_paths", []) as Array).size() == 2, "The forced-movement preview draws each pulled enemy's straight path")
	expect.call((result.get("preview_units", []) as Array).size() == 2, "The forced-movement preview shows a ghost at each landing tile")
	expect.call((result.get("collision_markers", []) as Array).size() == 1, "The forced-movement preview shows the collision")
	for card_id: String in ["w4b_vortex", "w4b_petrify", "w4b_skate", "w4b_changing_winds", "w4b_crystal_mantle"]:
		var display: Dictionary = scene.call("_card_widget_display", card_id, state)
		expect.call(not (display.get("summary_rows", []) as Array).is_empty(), "%s shows icon rows in hand" % card_id)
	var rooted: Dictionary = state.duplicate(true)
	ManeuverRules.gain_flag(rooted, {"flag": "no_move"}, "Rooted Stance")
	ManeuverRules.gain_flag(rooted, {"flag": "anchored"}, "Windbreak")
	var badges: Array[Dictionary] = ManeuverRules.player_badges(rooted)
	expect.call(badges.size() == 2 and str(badges[0].get("tooltip", "")).contains("Rooted"), "Active self flags appear as player status badges")
	scene.free()

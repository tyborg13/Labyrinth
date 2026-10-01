extends RefCounted

# Straight-line Push/Pull and collision law (spec/forced_movement.md).
const CombatEngine = preload("res://scripts/combat_engine.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Data = preload("res://scripts/game_data.gd")

const PLAYER := Vector2i(2, 4)
const RIGHT := Vector2i(1, 0)
const LEFT := Vector2i(-1, 0)
const UP := Vector2i(0, -1)
const DOWN := Vector2i(0, 1)


static func run(expect: Callable) -> void:
	var combat := CombatEngine.new()
	_test_aligned_push(combat, expect)
	_test_off_axis_default_and_alternate(combat, expect)
	_test_exact_diagonal_tie(combat, expect)
	_test_push_into_crate(combat, expect)
	_test_push_into_wall(combat, expect)
	_test_push_into_enemy(combat, expect)
	_test_push_blocked_immediately(combat, expect)
	_test_pull_arrives_adjacent(combat, expect)
	_test_pull_blocked_by_crate(combat, expect)
	_test_large_enemy_collision(combat, expect)
	_test_hazard_entry_and_mid_path_death(combat, expect)
	_test_enemy_pushes_player_into_wall(combat, expect)
	_test_enemy_takes_worse_line_for_player(combat, expect)
	_test_air_trap_collision(combat, expect)
	_test_galehook_front_member_collides(combat, expect)
	_test_zero_damage_legality(combat, expect)
	_test_collision_kill_grants_card_play(combat, expect)
	_test_forecast_matches_commit(combat, expect)
	_test_collision_is_non_direct(combat, expect)
	_test_off_axis_pull_stops_level(combat, expect)
	_test_enemy_off_axis_force_uses_default(combat, expect)
	_test_area_attack_pushes_farthest_first(combat, expect)
	_test_enemy_intent_projects_player_force(combat, expect)


static func run_live(tree: SceneTree, expect: Callable) -> void:
	await _test_live_rotate_aim_commits_alternate(tree, expect)


static func _grid() -> Array:
	var grid: Array = []
	for y: int in range(10):
		var row: Array = []
		for x: int in range(11):
			row.append("wall" if x == 0 or y == 0 or x == 10 or y == 9 else "stone")
		grid.append(row)
	return grid


static func _enemy(id: int, pos: Vector2i, hp: int = 30) -> Dictionary:
	return {"id": id, "type": "crawler", "pos": pos, "hp": hp, "max_hp": maxi(hp, 30), "block": 0, "stoneskin": 0, "intent": {}}


static func _crate(id: String, pos: Vector2i, hp: int = 10) -> Dictionary:
	return {"id": id, "kind": "wooden_crate", "pos": pos, "hp": hp, "max_hp": hp}


static func _state(combat: CombatEngine, enemies: Array, terrain: Array = [], player_pos: Vector2i = PLAYER) -> Dictionary:
	var layout: Dictionary = {
		"name": "Forced movement proof", "type": "combat", "coord": Vector2i(1, 1),
		"element": "air", "umbra_stage": "clear", "grid": _grid(),
		"player_start": player_pos, "terrain": [], "traps": [], "loot": [],
		"enemies": [_enemy(99, Vector2i(9, 8))],
	}
	var state: Dictionary = combat.create_combat(73011, layout, {"hp": 40, "max_hp": 40, "deck_cards": ["quick_stab"], "hand_size": 1, "relics": []})
	state["player"] = {"pos": player_pos, "hp": 40, "max_hp": 40, "block": 0, "stoneskin": 0}
	state["enemies"] = enemies.duplicate(true)
	state["terrain"] = terrain.duplicate(true)
	state["traps"] = []
	state["loot"] = []
	state["surfaces"] = {}
	state["current_actor"] = {"kind": "player", "key": "player"}
	state["player_turn_restrictions"] = {}
	state["cards_per_turn"] = 4
	state["cards_played_this_turn"] = 0
	state["death_bonus_card_plays_this_turn"] = 0
	return state


static func _unit(state: Dictionary, id: int) -> Dictionary:
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("id", -1)) == id:
			return enemy
	return {}


static func _terrain_hp(state: Dictionary, id: String) -> int:
	for terrain: Dictionary in state.get("terrain", []):
		if str(terrain.get("id", "")) == id:
			return int(terrain.get("hp", 0))
	return -1


static func _collisions(before: Dictionary, after: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for event: Dictionary in after.get("surface_events", []):
		if int(event.get("sequence", 0)) > int(before.get("surface_event_sequence", 0)) and str(event.get("kind", "")) == "force_collision":
			result.append(event)
	return result


static func _push(amount: int, damage: int = 0, range_value: int = 4) -> Dictionary:
	return {"type": "push", "amount": amount, "damage": damage, "range": range_value}


static func _pull(amount: int, damage: int = 0, range_value: int = 4) -> Dictionary:
	return {"type": "pull", "amount": amount, "damage": damage, "range": range_value}


static func _test_aligned_push(combat: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(combat, [_enemy(1, Vector2i(4, 4))])
	var options: Array[Vector2i] = combat.force_direction_options_for_player_action(state, _push(2), Vector2i(4, 4))
	expect.call(options == _dirs([RIGHT]), "An aligned push offers exactly one straight line away from the player")
	expect.call(combat.forced_movement_tiles_for_player_action(state, _push(2), Vector2i(4, 4)) == _dirs([Vector2i(5, 4), Vector2i(6, 4)]), "Hover path follows the full straight line")
	var after: Dictionary = combat.apply_player_action(state, _push(2), Vector2i(4, 4))
	expect.call(_unit(after, 1).get("pos") == Vector2i(6, 4), "An aligned push travels its full distance")
	expect.call(_collisions(state, after).is_empty() and int(_unit(after, 1).get("hp", 0)) == 30, "A free line records no collision")


static func _test_off_axis_default_and_alternate(combat: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(combat, [_enemy(1, Vector2i(5, 5))])
	var options: Array[Vector2i] = combat.force_direction_options_for_player_action(state, _push(1), Vector2i(5, 5))
	expect.call(options == _dirs([RIGHT, DOWN]), "Off-axis push defaults to the larger axis and offers the other axis second")
	var default_state: Dictionary = combat.apply_player_action(state, _push(1), Vector2i(5, 5))
	expect.call(_unit(default_state, 1).get("pos") == Vector2i(6, 5), "Off-axis push uses the larger-axis default")
	var aimed: Dictionary = _push(1)
	aimed["force_direction"] = DOWN
	expect.call(_unit(combat.apply_player_action(state, aimed, Vector2i(5, 5)), 1).get("pos") == Vector2i(5, 6), "The aimed alternate candidate is the committed line")
	var foreign: Dictionary = _push(1)
	foreign["force_direction"] = UP
	expect.call(combat.valid_targets_for_player_action(state, foreign).has(Vector2i(5, 5)), "A non-candidate stored direction never makes a target illegal")
	expect.call(_unit(combat.apply_player_action(state, foreign, Vector2i(5, 5)), 1).get("pos") == Vector2i(6, 5), "A non-candidate stored direction falls back to the default line")
	var pull_options: Array[Vector2i] = combat.force_direction_options_for_player_action(state, _pull(1), Vector2i(5, 5))
	expect.call(pull_options == _dirs([LEFT, UP]), "Off-axis pull candidates travel toward the player, larger axis first")
	var sideways: Dictionary = _push(1)
	sideways["_allow_sideways_force"] = true
	expect.call(combat.force_direction_options_for_player_action(state, sideways, Vector2i(5, 5)) == _dirs([RIGHT, DOWN, UP, LEFT]), "Sideways force offers all four lines, default first")


static func _test_exact_diagonal_tie(combat: CombatEngine, expect: Callable) -> void:
	var open: Dictionary = _state(combat, [_enemy(1, Vector2i(4, 4))], [], Vector2i(2, 2))
	expect.call(combat.force_direction_options_for_player_action(open, _push(2), Vector2i(4, 4)) == _dirs([RIGHT, DOWN]), "An exact diagonal with equal free travel defaults to the horizontal line")
	var boxed: Dictionary = _state(combat, [_enemy(1, Vector2i(4, 4))], [_crate("tie_box", Vector2i(5, 4))], Vector2i(2, 2))
	expect.call(combat.force_direction_options_for_player_action(boxed, _push(2), Vector2i(4, 4)) == _dirs([DOWN, RIGHT]), "An exact diagonal defaults to the line with more free travel")
	expect.call(_unit(combat.apply_player_action(boxed, _push(2), Vector2i(4, 4)), 1).get("pos") == Vector2i(4, 6), "The more-travel diagonal default resolves")


static func _test_push_into_crate(combat: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(combat, [_enemy(1, Vector2i(4, 4), 20)], [_crate("crate", Vector2i(6, 4), 10)])
	var after: Dictionary = combat.apply_player_action(state, _push(3), Vector2i(4, 4))
	expect.call(_unit(after, 1).get("pos") == Vector2i(5, 4), "A push stops before a crate")
	expect.call(int(_unit(after, 1).get("hp", 0)) == 16, "The pushed target takes 2 per lost tile")
	expect.call(_terrain_hp(after, "crate") == 6, "The crate takes the same collision damage")
	var events: Array[Dictionary] = _collisions(state, after)
	expect.call(events.size() == 1, "A collision records one force_collision event")
	if events.size() == 1:
		var event: Dictionary = events[0]
		expect.call(event.get("tile") == Vector2i(5, 4) and event.get("blocked_tile") == Vector2i(6, 4) and event.get("direction") == RIGHT, "Collision event records contact, blocked tile and direction")
		expect.call(str(event.get("actor_key")) == "enemy_1" and str(event.get("blocker_kind")) == "terrain" and int(event.get("damage", 0)) == 4 and int(event.get("blocker_damage", 0)) == 4 and int(event.get("total_damage", 0)) == 8, "Collision event records both parties and their damage")
	var weak: Dictionary = _state(combat, [_enemy(1, Vector2i(4, 4), 20)], [_crate("weak", Vector2i(5, 4), 3)])
	var broken: Dictionary = combat.apply_player_action(weak, _push(2), Vector2i(4, 4))
	expect.call(_terrain_hp(broken, "weak") <= 0 and _unit(broken, 1).get("pos") == Vector2i(4, 4), "A collision can break the crate without moving the target through it")


static func _test_push_into_wall(combat: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(combat, [_enemy(1, Vector2i(8, 4))], [], Vector2i(7, 4))
	var after: Dictionary = combat.apply_player_action(state, _push(2), Vector2i(8, 4))
	expect.call(_unit(after, 1).get("pos") == Vector2i(9, 4) and int(_unit(after, 1).get("hp", 0)) == 28, "A push into a wall damages only the target")
	var events: Array[Dictionary] = _collisions(state, after)
	expect.call(events.size() == 1 and str(events[0].get("blocker_kind")) == "wall" and int(events[0].get("blocker_damage", -1)) == 0, "Walls block and take nothing")


static func _test_push_into_enemy(combat: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(combat, [_enemy(1, Vector2i(4, 4)), _enemy(2, Vector2i(6, 4))])
	var after: Dictionary = combat.apply_player_action(state, _push(2), Vector2i(4, 4))
	expect.call(_unit(after, 1).get("pos") == Vector2i(5, 4) and _unit(after, 2).get("pos") == Vector2i(6, 4), "A pushed enemy stops against another enemy, which is not displaced")
	expect.call(int(_unit(after, 1).get("hp", 0)) == 28 and int(_unit(after, 2).get("hp", 0)) == 28, "Both enemies take collision damage")


static func _test_push_blocked_immediately(combat: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(combat, [_enemy(1, Vector2i(4, 4))], [_crate("wall_box", Vector2i(5, 4), 10)])
	var after: Dictionary = combat.apply_player_action(state, _push(3), Vector2i(4, 4))
	expect.call(_unit(after, 1).get("pos") == Vector2i(4, 4) and int(_unit(after, 1).get("hp", 0)) == 24 and _terrain_hp(after, "wall_box") == 4, "An immediately blocked push loses its full distance")


static func _test_pull_arrives_adjacent(combat: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(combat, [_enemy(1, Vector2i(5, 4))])
	var after: Dictionary = combat.apply_player_action(state, _pull(3, 1), Vector2i(5, 4))
	expect.call(_unit(after, 1).get("pos") == Vector2i(3, 4), "A pull stops beside its source")
	expect.call(int(_unit(after, 1).get("hp", 0)) == 29 and int((after.get("player", {}) as Dictionary).get("hp", 0)) == 40 and _collisions(state, after).is_empty(), "Reaching the puller is not a collision")


static func _test_pull_blocked_by_crate(combat: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(combat, [_enemy(1, Vector2i(6, 4))], [_crate("mid", Vector2i(4, 4), 10)])
	var after: Dictionary = combat.apply_player_action(state, _pull(3), Vector2i(6, 4))
	expect.call(_unit(after, 1).get("pos") == Vector2i(5, 4) and int(_unit(after, 1).get("hp", 0)) == 26 and _terrain_hp(after, "mid") == 6, "A pull blocked mid-path by a crate collides")


static func _test_large_enemy_collision(combat: CombatEngine, expect: Callable) -> void:
	var large: Dictionary = _enemy(1, Vector2i(4, 4), 40)
	large["footprint"] = Vector2i(2, 2)
	var state: Dictionary = _state(combat, [large], [_crate("low", Vector2i(7, 5), 10)])
	expect.call(combat.force_direction_options_for_player_action(state, _push(2), Vector2i(5, 5)) == _dirs([RIGHT]), "A large target uses its footprint tile nearest the source")
	var after: Dictionary = combat.apply_player_action(state, _push(2), Vector2i(5, 5))
	expect.call(_unit(after, 1).get("pos") == Vector2i(5, 4), "A 2x2 enemy stops when any leading tile is blocked")
	expect.call(int(_unit(after, 1).get("hp", 0)) == 38 and _terrain_hp(after, "low") == 8, "A 2x2 collision damages the target and the blocker")


static func _test_hazard_entry_and_mid_path_death(combat: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(combat, [_enemy(1, Vector2i(4, 4), 20)], [_crate("end", Vector2i(7, 4), 10)])
	Surface.place(state, Vector2i(5, 4), "fire")
	var after: Dictionary = combat.apply_player_action(state, _push(3), Vector2i(4, 4))
	expect.call(_unit(after, 1).get("pos") == Vector2i(6, 4), "Fire never blocks forced movement")
	expect.call(int(_unit(after, 1).get("hp", 0)) == 20 - Surface.FIRE_ENTRY_DAMAGE - 2, "Fire triggers on entry and the stopped line still collides")
	var doomed: Dictionary = _state(combat, [_enemy(1, Vector2i(4, 4), Surface.FIRE_ENTRY_DAMAGE)], [_crate("spared", Vector2i(6, 4), 10)])
	Surface.place(doomed, Vector2i(5, 4), "fire")
	var died: Dictionary = combat.apply_player_action(doomed, _push(3), Vector2i(4, 4))
	expect.call(int(_unit(died, 1).get("hp", 0)) <= 0 and _terrain_hp(died, "spared") == 10 and _collisions(doomed, died).is_empty(), "A target killed mid-path stops and does not collide")


static func _test_enemy_pushes_player_into_wall(combat: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(combat, [_enemy(1, Vector2i(8, 4))], [], Vector2i(9, 4))
	state["player"]["block"] = 3
	var action: Dictionary = {"type": "melee", "damage": 0, "push": 2, "_enemy_id": 1}
	var after: Dictionary = combat._apply_action_keywords_to_player(state.duplicate(true), action, Vector2i(8, 4))
	var player: Dictionary = after.get("player", {})
	expect.call(player.get("pos") == Vector2i(9, 4), "The player is pinned against the wall")
	expect.call(int(player.get("block", 0)) == 0 and int(player.get("hp", 0)) == 39, "Block absorbs collision damage before health")
	var events: Array[Dictionary] = _collisions(state, after)
	expect.call(events.size() == 1 and str(events[0].get("actor_key")) == "player", "Enemy force records the player's collision")


static func _test_enemy_takes_worse_line_for_player(combat: CombatEngine, expect: Callable) -> void:
	# Diagonal from the enemy: free travel prefers DOWN, but RIGHT collides.
	var state: Dictionary = _state(combat, [_enemy(1, Vector2i(6, 5))], [_crate("pin", Vector2i(9, 7), 10)], Vector2i(8, 7))
	var action: Dictionary = {"type": "melee", "damage": 0, "push": 1, "_enemy_id": 1}
	var after: Dictionary = combat._apply_action_keywords_to_player(state, action, Vector2i(6, 5))
	expect.call((after.get("player", {}) as Dictionary).get("pos") == Vector2i(8, 7) and int(after["player"]["hp"]) == 38, "Enemy force takes the straight line worse for the player")
	var large: Dictionary = _enemy(2, Vector2i(3, 3))
	large["footprint"] = Vector2i(2, 2)
	var sourced: Dictionary = _state(combat, [large], [], Vector2i(6, 4))
	var pushed: Dictionary = combat._apply_action_keywords_to_player(sourced, {"type": "melee", "push": 1, "_enemy_id": 2}, Vector2i(3, 3))
	expect.call((pushed.get("player", {}) as Dictionary).get("pos") == Vector2i(7, 4), "Enemy force originates at its footprint tile nearest the target")


static func _test_air_trap_collision(combat: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(combat, [_enemy(1, Vector2i(5, 4))], [_crate("gust", Vector2i(6, 4), 10)])
	state["traps"] = [{"id": "air", "element": "air", "pos": Vector2i(4, 4), "damage": 0}]
	var after: Dictionary = combat._trigger_trap_at_index(state, 0)
	expect.call(_unit(after, 1).get("pos") == Vector2i(5, 4) and int(_unit(after, 1).get("hp", 0)) == 28 and _terrain_hp(after, "gust") == 8, "An Air trap's outward push collides like any forced movement")


static func _test_galehook_front_member_collides(combat: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(combat, [_enemy(1, Vector2i(4, 4)), _enemy(2, Vector2i(5, 4))], [_crate("line_end", Vector2i(7, 4), 10)])
	state["relics"] = ["galehook_talon"]
	var after: Dictionary = combat.apply_player_action(state, _push(3), Vector2i(4, 4))
	expect.call(_unit(after, 1).get("pos") == Vector2i(5, 4) and _unit(after, 2).get("pos") == Vector2i(6, 4), "A Galehook line moves together until its front member is obstructed")
	expect.call(int(_unit(after, 2).get("hp", 0)) == 26 and _terrain_hp(after, "line_end") == 6, "The front member and its blocker take collision damage")
	expect.call(int(_unit(after, 1).get("hp", 0)) == 30, "Other line members take no collision damage")


static func _test_zero_damage_legality(combat: CombatEngine, expect: Callable) -> void:
	var pinned: Dictionary = _state(combat, [_enemy(1, Vector2i(4, 4))], [_crate("pin", Vector2i(5, 4), 10)])
	expect.call(combat.valid_targets_for_player_action(pinned, _push(1, 0, 3)).has(Vector2i(4, 4)), "A zero-damage push on a pinned enemy is legal because it collides")
	var adjacent: Dictionary = _state(combat, [_enemy(1, Vector2i(3, 4))])
	expect.call(not combat.valid_targets_for_player_action(adjacent, _pull(1, 0, 2)).has(Vector2i(3, 4)), "A zero-damage pull on an adjacent enemy does nothing and is illegal")
	expect.call(combat.valid_targets_for_player_action(adjacent, _pull(1, 2, 2)).has(Vector2i(3, 4)), "A damaging pull on an adjacent enemy remains legal")
	expect.call(combat.valid_targets_for_player_action(adjacent, _push(1, 0, 2)).has(Vector2i(3, 4)), "A zero-damage push that moves the target is legal")


static func _test_collision_kill_grants_card_play(combat: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(combat, [_enemy(1, Vector2i(4, 4), 2)], [_crate("anvil", Vector2i(5, 4), 10)])
	var after: Dictionary = combat.apply_player_action(state, _push(1), Vector2i(4, 4))
	expect.call(int(_unit(after, 1).get("hp", 0)) <= 0, "Collision damage can defeat the target")
	expect.call(int(after.get("death_bonus_card_plays_this_turn", 0)) == 1, "A collision kill from a card grants the normal +1 card play")


static func _test_forecast_matches_commit(combat: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(combat, [_enemy(1, Vector2i(5, 5)), _enemy(2, Vector2i(5, 7))], [_crate("crate", Vector2i(7, 5), 10)])
	var action: Dictionary = _push(3, 2)
	var forecast: Dictionary = combat.surface_preview_for_player_action(state, action, Vector2i(5, 5), true)
	var committed: Dictionary = combat.apply_player_action(state, action, Vector2i(5, 5))
	expect.call(forecast.get("state") == committed, "The hover forecast state equals the committed collision result")
	expect.call(_collisions(state, committed).size() == 1, "The forecast collision case records its event")
	var aimed: Dictionary = action.duplicate(true)
	aimed["force_direction"] = DOWN
	var aimed_forecast: Dictionary = combat.surface_preview_for_player_action(state, aimed, Vector2i(5, 5), true)
	var aimed_commit: Dictionary = combat.apply_player_action(state, aimed, Vector2i(5, 5))
	expect.call(aimed_forecast.get("state") == aimed_commit and _unit(aimed_commit, 1).get("pos") == Vector2i(5, 6) and int(_unit(aimed_commit, 2).get("hp", 0)) == 26, "The aimed alternate line forecasts and commits its enemy collision")


static func _test_collision_is_non_direct(combat: CombatEngine, expect: Callable) -> void:
	var chilled: Dictionary = _enemy(1, Vector2i(4, 4))
	chilled["chilled"] = true
	chilled["expose"] = 3
	chilled["frost_armor"] = 1
	chilled["stoneskin"] = 1
	var state: Dictionary = _state(combat, [chilled], [_crate("slab", Vector2i(5, 4), 10)])
	# Displace without a direct hit, so only the collision can touch defenses.
	var after: Dictionary = combat._move_enemy_in_direction(state.duplicate(true), 0, RIGHT, 1)
	var enemy: Dictionary = _unit(after, 1)
	expect.call(int(enemy.get("hp", 0)) == 29 and int(enemy.get("stoneskin", 0)) == 0, "Stoneskin absorbs collision damage; Chilled adds nothing")
	expect.call(int(enemy.get("expose", 0)) == 3 and int(enemy.get("frost_armor", 0)) == 1, "Collision neither consumes Expose nor breaks Crystal Mantle")


static func _test_off_axis_pull_stops_level(combat: CombatEngine, expect: Callable) -> void:
	# Yank (pull 3) on an enemy two across and one down: the default line closes
	# the bigger gap and stops level with the player instead of sliding past.
	var state: Dictionary = _state(combat, [_enemy(1, Vector2i(4, 5))], [_crate("far", Vector2i(1, 5), 10)])
	var pull: Dictionary = _pull(3, 2)
	expect.call(combat.forced_movement_tiles_for_player_action(state, pull, Vector2i(4, 5)) == _dirs([Vector2i(3, 5), Vector2i(2, 5)]), "An off-axis pull's hover line ends level with the puller")
	var after: Dictionary = combat.apply_player_action(state, pull, Vector2i(4, 5))
	expect.call(_unit(after, 1).get("pos") == Vector2i(2, 5) and _collisions(state, after).is_empty(), "An off-axis pull stops beside the puller without colliding")
	expect.call(int(_unit(after, 1).get("hp", 0)) == 28 and _terrain_hp(after, "far") == 10, "A pull that stops level deals only its own damage")
	var rotated: Dictionary = pull.duplicate(true)
	rotated["force_direction"] = UP
	var minor: Dictionary = combat.apply_player_action(state, rotated, Vector2i(4, 5))
	expect.call(_unit(minor, 1).get("pos") == Vector2i(4, 4) and _collisions(state, minor).is_empty(), "A rotated minor-axis pull stops once level with the puller")
	var large: Dictionary = _enemy(2, Vector2i(5, 5))
	large["footprint"] = Vector2i(2, 2)
	var big: Dictionary = _state(combat, [large])
	var big_after: Dictionary = combat.apply_player_action(big, _pull(5), Vector2i(5, 5))
	expect.call(_unit(big_after, 2).get("pos") == Vector2i(2, 5) and _collisions(big, big_after).is_empty(), "A 2x2 pull stops when its nearest footprint column reaches the puller's column")


static func _test_enemy_off_axis_force_uses_default(combat: CombatEngine, expect: Callable) -> void:
	# Enemy at (5,5) pulls a player at (2,4): the bigger gap is horizontal, so the
	# player is drawn level with the enemy even though the short line is worse.
	var state: Dictionary = _state(combat, [_enemy(1, Vector2i(5, 5))], [_crate("pin", Vector2i(2, 5), 10), _crate("top", Vector2i(2, 3), 10)], Vector2i(2, 4))
	var after: Dictionary = combat._apply_action_keywords_to_player(state.duplicate(true), {"type": "melee", "damage": 0, "pull": 5, "_enemy_id": 1}, Vector2i(5, 5))
	expect.call((after.get("player", {}) as Dictionary).get("pos") == Vector2i(5, 4) and int(after["player"]["hp"]) == 40, "Off the diagonal, an enemy pull follows the bigger-gap default and stops level with it")
	var pushed: Dictionary = combat._apply_action_keywords_to_player(state.duplicate(true), {"type": "melee", "damage": 0, "push": 1, "_enemy_id": 1}, Vector2i(5, 5))
	expect.call((pushed.get("player", {}) as Dictionary).get("pos") == Vector2i(1, 4) and int(pushed["player"]["hp"]) == 40, "Off the diagonal, an enemy push ignores the shorter line that would collide")


static func _test_area_attack_pushes_farthest_first(combat: CombatEngine, expect: Callable) -> void:
	var wind_shear: Dictionary = (Data.card_def("wind_shear").get("actions", []) as Array)[0] as Dictionary
	var state: Dictionary = _state(combat, [_enemy(1, Vector2i(4, 4)), _enemy(2, Vector2i(5, 4))])
	var after: Dictionary = combat.apply_player_action(state, wind_shear, Vector2i(4, 4))
	expect.call(_unit(after, 1).get("pos") == Vector2i(5, 4) and _unit(after, 2).get("pos") == Vector2i(6, 4), "Wind Shear moves the far enemy first, then the near one into the lane it cleared")
	expect.call(_collisions(state, after).is_empty() and int(_unit(after, 1).get("hp", 0)) == 27 and int(_unit(after, 2).get("hp", 0)) == 27, "Neither line target collides with a neighbor that was about to move")
	var pinned: Dictionary = _state(combat, [_enemy(1, Vector2i(4, 4)), _enemy(2, Vector2i(5, 4))], [_crate("end", Vector2i(6, 4), 10)])
	var stacked: Dictionary = combat.apply_player_action(pinned, wind_shear, Vector2i(4, 4))
	expect.call(_unit(stacked, 2).get("pos") == Vector2i(5, 4) and int(_unit(stacked, 2).get("hp", 0)) == 23 and int(_unit(stacked, 1).get("hp", 0)) == 25, "A blocked far target collides first; the near target then collides with it")


static func _test_enemy_intent_projects_player_force(combat: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(combat, [_enemy(1, Vector2i(3, 4))], [], Vector2i(2, 4))
	var enemy: Dictionary = state["enemies"][0]
	enemy["intent"] = {"id": "shove", "name": "Shove", "actions": [{"type": "melee", "damage": 2, "range": 1, "push": 3}]}
	state["enemies"][0] = enemy
	var threat: Dictionary = combat.enemy_threat_tiles(state, 0)
	var force: Dictionary = threat.get("projected_player_force", {}) as Dictionary
	var actual: Dictionary = combat._apply_action_keywords_to_player(state.duplicate(true), {"type": "melee", "push": 3, "_enemy_id": 1}, Vector2i(3, 4))
	expect.call(_dirs(force.get("path", [])) == _dirs([Vector2i(2, 4), Vector2i(1, 4)]), "A push intent previews the hero's straight line: %s" % str(force))
	var collision: Dictionary = force.get("collision", {}) as Dictionary
	expect.call(int(collision.get("damage", 0)) == 4 and collision.get("blocked_tile") == Vector2i(0, 4), "The intent preview shows the wall collision and its damage")
	expect.call((actual.get("player", {}) as Dictionary).get("pos") == force.get("destination") and int(actual["player"]["hp"]) == 36, "The intent preview matches the resolved push")
	var quiet: Dictionary = _state(combat, [_enemy(1, Vector2i(3, 4))], [], Vector2i(2, 4))
	quiet["enemies"][0]["intent"] = {"id": "bite", "name": "Bite", "actions": [{"type": "melee", "damage": 2, "range": 1}]}
	expect.call((combat.enemy_threat_tiles(quiet, 0).get("projected_player_force", {}) as Dictionary).is_empty(), "An intent without forced movement projects no hero line")


static func _dirs(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i]
	for value: Variant in values:
		result.append(value as Vector2i)
	return result


static func _test_live_rotate_aim_commits_alternate(tree: SceneTree, expect: Callable) -> void:
	var store = preload("res://scripts/progression_store.gd")
	var settings = preload("res://scripts/settings_store.gd")
	var analytics = preload("res://scripts/analytics_store.gd")
	var tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
	var profile_path: String = store._storage_path
	var run_path: String = store._run_storage_path
	var settings_path: String = settings.storage_path()
	var analytics_path: String = analytics.storage_dir()
	var prefix: String = "user://forced_movement_live_%d" % Time.get_ticks_usec()
	store.set_storage_path(prefix + "_profile.json")
	store.set_run_storage_path(prefix + "_run.save")
	settings.set_storage_path(prefix + "_settings.json")
	analytics.set_storage_dir(prefix + "_events")
	var profile: Dictionary = store.default_data()
	profile[tutorial.PROGRESSION_KEY] = {"version": tutorial.VERSION, "status": "dismissed", "completed_steps": []}
	store.save_data(profile)
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	tree.root.add_child(instance)
	await tree.process_frame
	await tree.process_frame
	var combat := CombatEngine.new()
	var state: Dictionary = _state(combat, [_enemy(1, Vector2i(4, 5), 100)], [_crate("live_crate", Vector2i(4, 7), 10)])
	state["analytics"] = {"combat_id": "forced_movement_live_c001"}
	state["deck"]["hand"] = ["updraft"]
	state["deck"]["draw"] = ["brace"]
	state["deck"]["discard"] = []
	state["deck"]["burned"] = []
	var run: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["combat_state"] = state
	run["analytics"] = {"run_id": "forced_movement_live", "combat_counter": 1}
	instance.set("_run_state", run)
	instance.set("_combat_state", state)
	instance.set("_dialogue_active", false)
	instance.call("_mark_combat_preview_state_changed")
	await tree.process_frame
	var preview: Dictionary = instance.call("_card_preview_for_index", 0)
	await instance.call("_begin_card_preview", 0, preview)
	var target := Vector2i(4, 5)
	instance.call("_on_board_tile_hovered", target)
	var hovered: Dictionary = instance.call("_active_card_preview")
	expect.call((hovered.get("action", {}) as Dictionary).get("force_direction", Vector2i.ZERO) == RIGHT, "Hovering an off-axis push target aims the default line")
	expect.call(bool(instance.call("_force_aim_rotation_available")), "A two-line push target offers Rotate")
	instance.call("_refresh_action_step_tracker")
	expect.call(instance.find_child("ActionContextRotate", true, false) != null, "The action-context Rotate button appears for a two-line push target")
	var default_presentation: Dictionary = instance.call("_preview_presentation", hovered)
	expect.call(not (default_presentation.get("displacement_paths", []) as Array).is_empty(), "Hover draws the forced displacement path")
	instance.call("_on_rotate_action_context_pressed")
	var rotated: Dictionary = instance.call("_active_card_preview")
	expect.call((rotated.get("action", {}) as Dictionary).get("force_direction", Vector2i.ZERO) == DOWN, "Rotate aims the alternate straight line")
	var rotated_presentation: Dictionary = instance.call("_preview_presentation", rotated)
	var ghost_tiles: Array = []
	for unit: Dictionary in rotated_presentation.get("preview_units", []):
		ghost_tiles.append(unit.get("pos"))
	expect.call(ghost_tiles.has(Vector2i(4, 6)), "The landing ghost follows the rotated line")
	var markers: Array = rotated_presentation.get("collision_markers", [])
	expect.call(markers.size() == 1 and (markers[0] as Dictionary).get("tile") == Vector2i(4, 6) and (markers[0] as Dictionary).get("blocked_tile") == Vector2i(4, 7), "The rotated forecast marks its crate collision")
	var damage_preview: Dictionary = rotated_presentation.get("damage_preview", {})
	expect.call(damage_preview.has("enemy_1") and damage_preview.size() >= 2, "The simulated forecast shows collision damage on the target and the crate")
	await instance.call("_on_board_tile_clicked", target)
	await tree.create_timer(1.5).timeout
	var final_state: Dictionary = instance.get("_combat_state")
	expect.call(_unit(final_state, 1).get("pos") == Vector2i(4, 6), "The committed push follows the rotated aim")
	expect.call(int(_unit(final_state, 1).get("hp", 0)) == 100 - int(Data.card_def("updraft")["actions"][0]["damage"]) - 2 and _terrain_hp(final_state, "live_crate") == 8, "The committed collision matches the forecast")
	var payload: Dictionary = {}
	for event: Dictionary in analytics.load_all_events():
		if str(event.get("event_type", "")) == "card_played":
			payload = event.get("payload", {}) as Dictionary
	expect.call(int(payload.get("forced_collisions", -1)) == 1 and int(payload.get("collision_damage_dealt", -1)) == 4, "Card-play analytics count the collision and its damage")
	expect.call(int(instance.get("_selected_card_index")) < 0, "Rotate adds no separate direction decision")
	instance.queue_free()
	await tree.process_frame
	await tree.process_frame
	store.set_storage_path(profile_path)
	store.set_run_storage_path(run_path)
	settings.set_storage_path(settings_path)
	analytics.set_storage_dir(analytics_path)

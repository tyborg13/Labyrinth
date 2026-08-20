extends RefCounted

const CombatPatternRules = preload("res://scripts/combat_pattern_rules.gd")
const CombatTerrainRules = preload("res://scripts/combat_terrain_rules.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")

static func run(expect: Callable) -> void:
	_test_tile_layers_replace_refresh_and_expire(expect)
	_test_field_entry_and_activation_effects(expect)
	_test_surface_entry_contracts(expect)
	_test_ice_route_and_collision_contract(expect)
	_test_snowdrift_and_combust(expect)
	_test_pattern_rotation_translation_and_overlay(expect)
	_test_pattern_short_circuit(expect)
	_test_live_free_move_and_player_traversal(expect)
	_test_live_activation_effects_and_clock_expiry(expect)
	_test_committed_enemy_attacks_do_not_chase(expect)
	_test_committed_enemy_attacks_can_be_intercepted(expect)
	_test_committed_enemy_patterns_translate_when_displaced(expect)
	_test_enemy_setup_move_precedes_next_commitment(expect)

static func _test_tile_layers_replace_refresh_and_expire(expect: Callable) -> void:
	var state: Dictionary = {}
	CombatTerrainRules.place_field(state, [Vector2i(2, 3)], CombatTerrainRules.FIELD_CORRUPTION, 8)
	CombatTerrainRules.place_surface(state, [Vector2i(2, 3)], CombatTerrainRules.SURFACE_ICE, 7)
	expect.call(CombatTerrainRules.field_kind_at(state, Vector2i(2, 3)) == CombatTerrainRules.FIELD_CORRUPTION, "Corruption should occupy the Field layer")
	expect.call(CombatTerrainRules.surface_kind_at(state, Vector2i(2, 3)) == CombatTerrainRules.SURFACE_ICE, "Ice should coexist in the Surface layer")
	CombatTerrainRules.place_field(state, [Vector2i(2, 3)], CombatTerrainRules.FIELD_RADIANCE, 12)
	CombatTerrainRules.place_surface(state, [Vector2i(2, 3)], CombatTerrainRules.SURFACE_POISON, 11)
	expect.call(CombatTerrainRules.field_kind_at(state, Vector2i(2, 3)) == CombatTerrainRules.FIELD_RADIANCE, "Radiance should replace Corruption without stacking")
	expect.call(int(CombatTerrainRules.field_at(state, Vector2i(2, 3)).get("expires_at", 0)) == 12, "Replacing a Field should install its new absolute expiry")
	expect.call(CombatTerrainRules.surface_kind_at(state, Vector2i(2, 3)) == CombatTerrainRules.SURFACE_POISON, "A new Surface should replace the previous Surface")
	var expired_before: Dictionary = CombatTerrainRules.expire_at_clock(state, 10)
	expect.call((expired_before.get("fields", []) as Array).is_empty(), "Effects should survive before their absolute expiry")
	var expired_at: Dictionary = CombatTerrainRules.expire_at_clock(state, 11)
	expect.call((expired_at.get("surfaces", []) as Array).size() == 1, "A Surface should expire exactly when the initiative clock reaches expires_at")
	expect.call(CombatTerrainRules.surface_kind_at(state, Vector2i(2, 3)) == CombatTerrainRules.SURFACE_NONE, "Expired Surfaces should leave the tile neutral")

static func _test_field_entry_and_activation_effects(expect: Callable) -> void:
	var state: Dictionary = {}
	CombatTerrainRules.place_field(state, [Vector2i(1, 1)], CombatTerrainRules.FIELD_CORRUPTION, 20)
	CombatTerrainRules.place_field(state, [Vector2i(2, 1)], CombatTerrainRules.FIELD_RADIANCE, 20)
	var player_entry: Dictionary = CombatTerrainRules.entry_effect(state, Vector2i(1, 1), CombatTerrainRules.TEAM_PLAYER)
	var enemy_entry: Dictionary = CombatTerrainRules.entry_effect(state, Vector2i(2, 1), CombatTerrainRules.TEAM_ENEMY)
	expect.call(int(player_entry.get("damage", 0)) == CombatTerrainRules.FIELD_TRAVERSAL_DAMAGE, "Corruption should damage the player on traversal")
	expect.call(int(enemy_entry.get("damage", 0)) == CombatTerrainRules.FIELD_TRAVERSAL_DAMAGE, "Radiance should damage enemies on traversal")
	var corruption_start: Dictionary = CombatTerrainRules.activation_start_effect(state, Vector2i(1, 1), CombatTerrainRules.TEAM_ENEMY)
	var radiance_start: Dictionary = CombatTerrainRules.activation_start_effect(state, Vector2i(2, 1), CombatTerrainRules.TEAM_ENEMY)
	expect.call(int(corruption_start.get("healing", 0)) == CombatTerrainRules.CORRUPTION_ENEMY_HEAL, "Corruption should heal an enemy once at activation start")
	expect.call(int(radiance_start.get("damage", 0)) == CombatTerrainRules.FIELD_ACTIVATION_DAMAGE, "Radiance should damage an enemy once at activation start")

static func _test_surface_entry_contracts(expect: Callable) -> void:
	var state: Dictionary = {}
	CombatTerrainRules.place_surface(state, [Vector2i(1, 0)], CombatTerrainRules.SURFACE_BRAMBLE, 20)
	CombatTerrainRules.place_surface(state, [Vector2i(2, 0)], CombatTerrainRules.SURFACE_POISON, 20)
	CombatTerrainRules.place_surface(state, [Vector2i(3, 0)], CombatTerrainRules.SURFACE_ICE, 20)
	CombatTerrainRules.place_surface(state, [Vector2i(4, 0)], CombatTerrainRules.SURFACE_ELECTRIFIED, 20)
	expect.call(bool(CombatTerrainRules.entry_effect(state, Vector2i(1, 0), CombatTerrainRules.TEAM_PLAYER).get("stop_movement", false)), "Bramble should stop either faction on entry")
	var poison_entry: Dictionary = CombatTerrainRules.entry_effect(state, Vector2i(2, 0), CombatTerrainRules.TEAM_ENEMY)
	expect.call(bool(poison_entry.get("poison_armed", false)) and int(poison_entry.get("damage", 0)) == 0, "The first Poison tile should arm movement without dealing Poison damage")
	var after_poison: Dictionary = CombatTerrainRules.entry_effect(state, Vector2i(3, 0), CombatTerrainRules.TEAM_ENEMY, true)
	expect.call(int(after_poison.get("damage", 0)) == CombatTerrainRules.POISON_TRAVERSAL_DAMAGE, "Every tile after Poison entry should deal immediate movement damage")
	expect.call(bool(after_poison.get("slide", false)), "Ice should request continuation in the current movement direction")
	var electrified: Dictionary = CombatTerrainRules.entry_effect(state, Vector2i(4, 0), CombatTerrainRules.TEAM_PLAYER)
	expect.call(bool(electrified.get("attacks_suppressed", false)) and bool(electrified.get("consume_surface", false)), "Electrified should suppress attack segments and discharge")

static func _test_ice_route_and_collision_contract(expect: Callable) -> void:
	var state: Dictionary = {}
	CombatTerrainRules.place_surface(state, [Vector2i(2, 2), Vector2i(3, 2)], CombatTerrainRules.SURFACE_ICE, 20)
	var grid: Array = []
	for y: int in range(5):
		var row: Array[String] = []
		for x: int in range(6):
			row.append("wall" if x == 0 or y == 0 or x == 5 or y == 4 else "stone")
		grid.append(row)
	var slide: Dictionary = CombatTerrainRules.route_with_ice(state, grid, [Vector2i(1, 2), Vector2i(2, 2)], {})
	expect.call((slide.get("path", []) as Array) == [Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)], "Entering Ice should lock direction through the strip and land on the first non-Ice tile")
	var collision: Dictionary = CombatTerrainRules.route_with_ice(state, grid, [Vector2i(1, 2), Vector2i(2, 2)], {Vector2i(4, 2): true})
	expect.call((collision.get("path", []) as Array) == [Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)] and collision.get("collision_tile", Vector2i.ZERO) == Vector2i(4, 2), "A blocked Ice continuation should stop at the last legal tile and report one shared collision")

static func _test_snowdrift_and_combust(expect: Callable) -> void:
	var state: Dictionary = {}
	CombatTerrainRules.place_surface(state, [Vector2i(4, 4)], CombatTerrainRules.SURFACE_SNOWDRIFT, 20)
	expect.call(CombatTerrainRules.attack_bonus_at(state, Vector2i(4, 4)) == CombatTerrainRules.SNOWDRIFT_ATTACK_BONUS, "Snowdrift should grant only the shared attack bonus")
	var combust: Dictionary = CombatTerrainRules.combust_at(state, Vector2i(4, 4))
	expect.call(int(combust.get("bonus_damage", 0)) == CombatTerrainRules.COMBUST_ATTACK_BONUS and bool(combust.get("consume_surface", false)), "Combust should cash out any occupied Surface for its shared bonus")
	CombatTerrainRules.clear_surface(state, Vector2i(4, 4))
	expect.call(int(CombatTerrainRules.combust_at(state, Vector2i(4, 4)).get("bonus_damage", -1)) == 0, "Combust should add nothing on a Surface-free tile")

static func _test_pattern_rotation_translation_and_overlay(expect: Callable) -> void:
	var plan: Dictionary = CombatPatternRules.build_plan(
		Vector2i(4, 4),
		CombatPatternRules.EAST,
		[
			{"kind": "move", "offsets": [[0, -1], [0, -2]], "short_circuit": true, "include_contact": false},
			{"kind": "attack", "offsets": [[0, -3], [1, -3]], "short_circuit": true},
			{"kind": "field", "offsets": [[0, -1], [0, -2], [0, -3]], "field": "corruption"},
		]
	)
	var overlay: Dictionary = CombatPatternRules.overlay(plan)
	expect.call((overlay.get("move", []) as Array) == [Vector2i(5, 4), Vector2i(6, 4)], "A north-authored movement stencil should rotate east around its origin")
	expect.call((overlay.get("attack", []) as Array) == [Vector2i(7, 4), Vector2i(7, 5)], "Attack footprints should share the selected orientation")
	var translated: Dictionary = CombatPatternRules.translate_plan(plan, Vector2i(3, 2))
	var translated_overlay: Dictionary = CombatPatternRules.overlay(translated)
	expect.call((translated_overlay.get("move", []) as Array) == [Vector2i(4, 2), Vector2i(5, 2)], "Displacing an origin should translate a committed plan without retargeting")
	expect.call(translated.get("direction", Vector2i.ZERO) == CombatPatternRules.EAST, "Plan translation should preserve committed orientation")

static func _test_pattern_short_circuit(expect: Callable) -> void:
	var plan: Dictionary = CombatPatternRules.build_plan(
		Vector2i(1, 1),
		CombatPatternRules.SOUTH,
		[
			{"kind": "attack", "offsets": [[0, -1], [0, -2], [0, -3]], "short_circuit": true, "include_contact": true},
			{"kind": "field", "offsets": [[0, -1], [0, -2], [0, -3]], "field": "corruption"},
		]
	)
	var interrupted: Dictionary = CombatPatternRules.truncate_at_first_contact(plan, [Vector2i(1, 3)])
	var overlay: Dictionary = CombatPatternRules.overlay(interrupted)
	expect.call(bool(interrupted.get("interrupted", false)) and interrupted.get("contact_tile", Vector2i.ZERO) == Vector2i(1, 3), "The first contacted actor should short-circuit a committed sequence")
	expect.call((overlay.get("attack", []) as Array) == [Vector2i(1, 2), Vector2i(1, 3)], "The contact tile should still receive the attack")
	expect.call((overlay.get("field", []) as Array).is_empty(), "Downstream Corruption should not resolve after contact")
	expect.call((overlay.get("cancelled", []) as Array).has(Vector2i(1, 4)), "Cancelled suffix tiles should remain available to the preview")

static func _test_live_free_move_and_player_traversal(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(90210, _room_layout(), _player_snapshot())
	var free_move: Dictionary = combat.free_move_action(state)
	expect.call(int(free_move.get("range", 0)) == CombatEngine.FREE_MOVE_RANGE, "Each player activation should expose an exact free Move 2")
	var targets: Array[Vector2i] = combat.valid_targets_for_player_action(state, free_move)
	expect.call(targets.has(Vector2i(4, 4)) and not targets.has(Vector2i(5, 4)), "The free move should be one unsplit orthogonal range-2 action")

	var corruption_state: Dictionary = combat.place_field(
		state,
		[Vector2i(3, 4), Vector2i(4, 4)],
		CombatTerrainRules.FIELD_CORRUPTION,
		20
	)
	var defended_player: Dictionary = (corruption_state.get("player", {}) as Dictionary).duplicate(true)
	defended_player["block"] = 5
	defended_player["stoneskin"] = 5
	corruption_state["player"] = defended_player
	var after_corruption: Dictionary = combat.apply_player_action(corruption_state, free_move, Vector2i(4, 4))
	var traversed_player: Dictionary = after_corruption.get("player", {}) as Dictionary
	expect.call(int(traversed_player.get("hp", 0)) == 18, "Two Corruption tiles should deal two environmental HP damage during movement")
	expect.call(int(traversed_player.get("block", 0)) == 5 and int(traversed_player.get("stoneskin", 0)) == 5, "Environmental traversal damage should bypass rather than consume defenses")
	expect.call(not bool(after_corruption.get("free_move_available", true)) and int(after_corruption.get("cards_played_this_turn", -1)) == 0, "Committing free movement should spend only the movement allowance")

	var poison_state: Dictionary = combat.create_combat(90211, _room_layout(), _player_snapshot())
	poison_state = combat.place_surface(poison_state, [Vector2i(3, 4)], CombatTerrainRules.SURFACE_POISON, 20)
	var after_poison: Dictionary = combat.apply_player_action(poison_state, combat.free_move_action(poison_state), Vector2i(4, 4))
	expect.call(int((after_poison.get("player", {}) as Dictionary).get("hp", 0)) == 19, "Poison should arm on entry and damage only the subsequent tile of the same movement")

	var bramble_state: Dictionary = combat.create_combat(90212, _room_layout(), _player_snapshot())
	bramble_state = combat.place_surface(bramble_state, [Vector2i(3, 4)], CombatTerrainRules.SURFACE_BRAMBLE, 20)
	var after_bramble: Dictionary = combat.apply_player_action(bramble_state, combat.free_move_action(bramble_state), Vector2i(4, 4))
	expect.call((after_bramble.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(3, 4), "Bramble should stop voluntary movement immediately on entry")

	var ice_state: Dictionary = combat.create_combat(90214, _room_layout(), _player_snapshot())
	ice_state = combat.place_surface(ice_state, [Vector2i(3, 4), Vector2i(4, 4)], CombatTerrainRules.SURFACE_ICE, 20)
	var after_ice: Dictionary = combat.apply_player_action(ice_state, combat.free_move_action(ice_state), Vector2i(3, 4))
	expect.call((after_ice.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(5, 4), "Entering Ice with free movement should continue through the strip to the first non-Ice tile")

	var collision_state: Dictionary = combat.create_combat(90215, _room_layout(), _player_snapshot())
	collision_state["terrain"] = [{"id": "collision_post", "kind": "post", "pos": Vector2i(5, 4), "hp": 4, "max_hp": 4}]
	collision_state = combat.place_surface(collision_state, [Vector2i(3, 4), Vector2i(4, 4)], CombatTerrainRules.SURFACE_ICE, 20)
	var after_collision: Dictionary = combat.apply_player_action(collision_state, combat.free_move_action(collision_state), Vector2i(3, 4))
	expect.call((after_collision.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(4, 4), "An Ice collision should leave the mover on the last legal tile")
	expect.call(int((after_collision.get("player", {}) as Dictionary).get("hp", 0)) == 18 and int(((after_collision.get("terrain", []) as Array)[0] as Dictionary).get("hp", 0)) == 2, "Collision should apply the same environmental damage to the mover and contacted actor or object")

	var combust_state: Dictionary = combat.create_combat(90216, _room_layout(), _player_snapshot())
	var combust_enemies: Array = combust_state.get("enemies", [])
	var combust_enemy: Dictionary = (combust_enemies[0] as Dictionary).duplicate(true)
	combust_enemy["pos"] = Vector2i(3, 4)
	combust_enemy["stoneskin"] = 0
	combust_enemies[0] = combust_enemy
	combust_state["enemies"] = combust_enemies
	combust_state = combat.place_surface(combust_state, [Vector2i(3, 4)], CombatTerrainRules.SURFACE_SNOWDRIFT, 20)
	var after_combust: Dictionary = combat.apply_player_action(combust_state, {"type": "melee", "range": 1, "damage": 2, "combust": true}, Vector2i(3, 4))
	expect.call(int(((after_combust.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) == 8, "An attack against Snowdrift should gain its bonus and Combust should add the shared Surface cash-out bonus")
	expect.call(combat.surface_kind_at(after_combust, Vector2i(3, 4)) == CombatTerrainRules.SURFACE_NONE, "Combust should consume the target's Surface after resolving its damage")

	var electrified_state: Dictionary = combat.create_combat(90213, _room_layout(), _player_snapshot())
	electrified_state = combat.place_surface(electrified_state, [Vector2i(4, 4)], CombatTerrainRules.SURFACE_ELECTRIFIED, 20)
	var after_electrified: Dictionary = combat.apply_player_action(electrified_state, {"type": "blink", "range": 3}, Vector2i(4, 4))
	expect.call(bool((after_electrified.get("player_turn_restrictions", {}) as Dictionary).get("attacks_suppressed", false)), "Blink should discharge Electrified on its landing tile and suppress attacks")
	expect.call(combat.surface_kind_at(after_electrified, Vector2i(4, 4)) == CombatTerrainRules.SURFACE_NONE, "Electrified should be consumed on discharge")

static func _test_live_activation_effects_and_clock_expiry(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var radiance_state: Dictionary = combat.create_combat(90220, _room_layout(10), _player_snapshot())
	radiance_state = combat.place_field(radiance_state, [Vector2i(5, 2)], CombatTerrainRules.FIELD_RADIANCE, 20)
	var radiance_result: Dictionary = combat.resolve_enemy_turn_with_steps(radiance_state, 0)
	var radiance_enemy: Dictionary = ((radiance_result.get("state", {}) as Dictionary).get("enemies", []) as Array)[0] as Dictionary
	expect.call(int(radiance_enemy.get("hp", 0)) == 9, "Radiance should deal environmental HP damage at enemy activation start")

	var corruption_state: Dictionary = combat.create_combat(90221, _room_layout(10), _player_snapshot())
	corruption_state = combat.place_field(corruption_state, [Vector2i(5, 2)], CombatTerrainRules.FIELD_CORRUPTION, 20)
	var corruption_result: Dictionary = combat.resolve_enemy_turn_with_steps(corruption_state, 0)
	var corruption_enemy: Dictionary = ((corruption_result.get("state", {}) as Dictionary).get("enemies", []) as Array)[0] as Dictionary
	expect.call(int(corruption_enemy.get("hp", 0)) == 11, "Corruption should heal an enemy once at activation start")

	var expiry_state: Dictionary = combat.create_combat(90222, _room_layout(), _player_snapshot())
	expiry_state = combat.place_surface(expiry_state, [Vector2i(3, 4)], CombatTerrainRules.SURFACE_ICE, 1)
	var popped: Dictionary = combat.call("_pop_next_actor", expiry_state) as Dictionary
	var advanced_state: Dictionary = popped.get("state", expiry_state) as Dictionary
	expect.call(combat.surface_kind_at(advanced_state, Vector2i(3, 4)) == CombatTerrainRules.SURFACE_NONE, "Advancing the initiative clock should expire tile effects before the next actor resolves")

static func _test_committed_enemy_attacks_do_not_chase(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(90230, _room_layout(), _player_snapshot())
	_set_enemy_position(state, 0, Vector2i(5, 4))
	_commit_test_intent(combat, state, 0, {
		"id": "fixed_shot",
		"name": "Fixed Shot",
		"actions": [{"type": "ranged", "range": 5, "damage": 3}],
	})
	var committed_target: Vector2i = combat.enemy_intent_plan(state, 0).get("projected_attack_target", Vector2i.ZERO)
	var player: Dictionary = (state.get("player", {}) as Dictionary).duplicate(true)
	player["pos"] = Vector2i(2, 3)
	state["player"] = player
	var result: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0).get("state", {}) as Dictionary
	expect.call(committed_target == Vector2i(2, 4), "A revealed ranged intent should store its exact target tile")
	var result_hp: int = int((result.get("player", {}) as Dictionary).get("hp", 0))
	expect.call(result_hp == 20, "Leaving a committed attack tile should make the attack miss instead of chasing the player (hp=%d)" % result_hp)

static func _test_committed_enemy_attacks_can_be_intercepted(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var illusion_state: Dictionary = combat.create_combat(90231, _room_layout(), _player_snapshot())
	_set_enemy_position(illusion_state, 0, Vector2i(5, 4))
	_commit_test_intent(combat, illusion_state, 0, {
		"id": "intercepted_shot",
		"name": "Intercepted Shot",
		"actions": [{"type": "ranged", "range": 5, "damage": 3}],
	})
	var moved_player: Dictionary = (illusion_state.get("player", {}) as Dictionary).duplicate(true)
	moved_player["pos"] = Vector2i(2, 3)
	illusion_state["player"] = moved_player
	illusion_state["illusions"] = [{"id": 71, "pos": Vector2i(2, 4), "hp": 5, "max_hp": 5}]
	var illusion_result: Dictionary = combat.resolve_enemy_turn_with_steps(illusion_state, 0).get("state", {}) as Dictionary
	var illusions: Array = illusion_result.get("illusions", []) as Array
	expect.call(not illusions.is_empty() and int((illusions[0] as Dictionary).get("hp", 0)) == 2, "An Illusion entering a committed target tile should intercept that attack")
	expect.call(int((illusion_result.get("player", {}) as Dictionary).get("hp", 0)) == 20, "An intercepted fixed attack should leave the displaced player unharmed")

	var friendly_state: Dictionary = combat.create_combat(90232, _room_layout(), _player_snapshot())
	_set_enemy_position(friendly_state, 0, Vector2i(5, 4))
	var friendly_enemies: Array = (friendly_state.get("enemies", []) as Array).duplicate(true)
	friendly_enemies.append({
		"id": 72,
		"type": "crawler",
		"pos": Vector2i(5, 5),
		"hp": 14,
		"max_hp": 14,
		"block": 0,
		"stoneskin": 0,
	})
	friendly_state["enemies"] = friendly_enemies
	_commit_test_intent(combat, friendly_state, 0, {
		"id": "friendly_fire_shot",
		"name": "Friendly Fire Shot",
		"actions": [{"type": "ranged", "range": 5, "damage": 3}],
	})
	var friendly_player: Dictionary = (friendly_state.get("player", {}) as Dictionary).duplicate(true)
	friendly_player["pos"] = Vector2i(2, 3)
	friendly_state["player"] = friendly_player
	friendly_enemies = (friendly_state.get("enemies", []) as Array).duplicate(true)
	var intercepted_enemy: Dictionary = (friendly_enemies[1] as Dictionary).duplicate(true)
	intercepted_enemy["pos"] = Vector2i(2, 4)
	friendly_enemies[1] = intercepted_enemy
	friendly_state["enemies"] = friendly_enemies
	var friendly_result: Dictionary = combat.resolve_enemy_turn_with_steps(friendly_state, 0).get("state", {}) as Dictionary
	var damaged_ally: Dictionary = (friendly_result.get("enemies", []) as Array)[1] as Dictionary
	expect.call(int(damaged_ally.get("hp", 0)) == 11, "An enemy entering a committed attack tile should take friendly fire (hp=%d, block=%d)" % [int(damaged_ally.get("hp", 0)), int(damaged_ally.get("block", 0))])

	var charge_state: Dictionary = combat.create_combat(90233, _room_layout(), _player_snapshot())
	_set_enemy_position(charge_state, 0, Vector2i(5, 4))
	_commit_test_intent(combat, charge_state, 0, {
		"id": "short_circuit_charge",
		"name": "Short Circuit Charge",
		"actions": [
			{"type": "move_toward", "range": 3},
			{"type": "melee", "range": 1, "damage": 3},
		],
	})
	charge_state["illusions"] = [{"id": 73, "pos": Vector2i(4, 4), "hp": 5, "max_hp": 5}]
	var charge_result: Dictionary = combat.resolve_enemy_turn_with_steps(charge_state, 0).get("state", {}) as Dictionary
	var charge_illusions: Array = charge_result.get("illusions", []) as Array
	expect.call(not charge_illusions.is_empty() and int((charge_illusions[0] as Dictionary).get("hp", 0)) == 2, "An actor inserted into a committed movement path should stop the sequence and receive its follow-up attack")
	expect.call(int((charge_result.get("player", {}) as Dictionary).get("hp", 0)) == 20, "Short-circuit interception should cancel the original downstream hit")

static func _test_committed_enemy_patterns_translate_when_displaced(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(90234, _room_layout(), _player_snapshot())
	_set_enemy_position(state, 0, Vector2i(5, 4))
	_commit_test_intent(combat, state, 0, {
		"id": "translated_shot",
		"name": "Translated Shot",
		"actions": [{"type": "ranged", "range": 5, "damage": 3}],
	})
	var before_plan: Dictionary = combat.enemy_intent_plan(state, 0)
	_set_enemy_position(state, 0, Vector2i(5, 3))
	var after_plan: Dictionary = combat.enemy_intent_plan(state, 0)
	var delta: Vector2i = Vector2i(0, -1)
	expect.call(after_plan.get("projected_attack_target", Vector2i.ZERO) == before_plan.get("projected_attack_target", Vector2i.ZERO) + delta, "Displacing an enemy should translate its committed target instead of reacquiring the player")
	expect.call(after_plan.get("destination", Vector2i.ZERO) == before_plan.get("destination", Vector2i.ZERO) + delta, "Committed movement and attack geometry should translate as one pattern")

static func _test_enemy_setup_move_precedes_next_commitment(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(90235, _room_layout(), _player_snapshot())
	_set_enemy_position(state, 0, Vector2i(5, 4))
	_commit_test_intent(combat, state, 0, {
		"id": "brace_before_setup",
		"name": "Brace Before Setup",
		"actions": [{"type": "block", "amount": 1}],
	})
	var result: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0)
	var resolved_state: Dictionary = result.get("state", {}) as Dictionary
	var enemy: Dictionary = (resolved_state.get("enemies", []) as Array)[0] as Dictionary
	var next_intent: Dictionary = enemy.get("intent", {}) as Dictionary
	var committed: Dictionary = enemy.get("committed_intent_plan", {}) as Dictionary
	expect.call(enemy.get("pos", Vector2i.ZERO) == Vector2i(4, 4), "A living enemy should receive one harmless setup step after resolving its current intent")
	expect.call(committed.get("committed_origin", Vector2i.ZERO) == enemy.get("pos", Vector2i.ZERO) and int(committed.get("intent_signature", -1)) == hash(next_intent), "The next intent should commit only after the setup move reaches its final tile")
	var saw_setup_step: bool = false
	for step_var: Variant in result.get("steps", []):
		if typeof(step_var) == TYPE_DICTIONARY and str((step_var as Dictionary).get("label", "")) == "Setup":
			saw_setup_step = true
	expect.call(saw_setup_step, "Enemy setup movement should be exposed as a distinct board animation step")

static func _set_enemy_position(state: Dictionary, enemy_index: int, tile: Vector2i) -> void:
	var enemies: Array = (state.get("enemies", []) as Array).duplicate(true)
	var enemy: Dictionary = (enemies[enemy_index] as Dictionary).duplicate(true)
	enemy["pos"] = tile
	enemies[enemy_index] = enemy
	state["enemies"] = enemies

static func _commit_test_intent(combat: CombatEngine, state: Dictionary, enemy_index: int, intent: Dictionary) -> void:
	var enemies: Array = (state.get("enemies", []) as Array).duplicate(true)
	var enemy: Dictionary = (enemies[enemy_index] as Dictionary).duplicate(true)
	enemy["intent"] = intent.duplicate(true)
	enemy.erase("committed_intent_plan")
	enemies[enemy_index] = enemy
	state["enemies"] = enemies
	combat.call("_commit_enemy_intent_plan", state, enemy_index)

static func _room_layout(enemy_hp: int = 14) -> Dictionary:
	var grid: Array = []
	for y: int in range(8):
		var row: Array[String] = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return {
		"name": "Overhaul Foundation Test",
		"coord": Vector2i(1, 1),
		"type": "combat",
		"grid": grid,
		"player_start": Vector2i(2, 4),
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(5, 2),
			"hp": enemy_hp,
			"max_hp": 14,
			"block": 0,
			"stoneskin": 5,
		}],
		"loot": [],
	}

static func _player_snapshot() -> Dictionary:
	return {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0,
	}

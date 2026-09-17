extends SceneTree
const CombatEngine = preload("res://scripts/combat_engine.gd")
const Fixture = preload("res://tests/suites/card_playability_summary_suite.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")

# Frozen algorithms before range-first rejection and read-only one-step checks.
class OriginalCombatEngine:
	extends CombatEngine

	func valid_targets_for_player_action(state: Dictionary, action: Dictionary, accepted_limit: int = 0, accept_target: Callable = Callable()) -> Array[Vector2i]:
		if action.has("_illusion_id"):
			var plan: Dictionary = illusion_movement_plan(state,int(action["_illusion_id"]))
			var result: Array[Vector2i] = _vector2i_values((plan.get("paths",{}) as Dictionary).keys())
			result.erase(_surface_actor(state,"illusion",int(action["_illusion_id"])).get("pos",INVALID_TILE))
			return result
		action = _resolved_surface_action(state, action)
		if not player_action_can_resolve(state, action) or (action.has("_origin_tile") and not is_tile_visible_to_player(state, action["_origin_tile"])):
			return []
		var player: Dictionary = state.get("player", {})
		var player_pos: Vector2i = action.get("_origin_tile", player.get("pos", Vector2i.ZERO))
		var action_type: String = str(action.get("type", ""))
		var resolved_action: Dictionary = _resolved_surface_action(state, action)
		# Faultline expands the hit footprint, not the legal primary target set.
		# Use ordinary melee targeting, including trap/terrain and large-body clicks.
		var targeting_type: String = str(action.get("_native_action_type", action_type)) if SurfaceRelicRules.mode_enabled(action, "cross") else action_type
		var occupied: Dictionary = {}
		var targets: Array[Vector2i] = []
		var visible_lookup: Dictionary = {}
		if action_type in ["blink", "illusion", "melee", "ranged", "aoe", "push", "pull", "detonate"]:
			visible_lookup = umbra_visible_tile_lookup(state)
		match targeting_type:
			"surface", "detonate", "consume_surface":
				var surface_range: int = int(action.get("range", 0))
				for tile: Vector2i in PathUtils.diamond_tiles(player_pos, surface_range, state.get("grid", [])):
					if BoardSurfaceRules.can_place(state, tile) and is_tile_visible_to_player(state, tile) and combat_line_of_sight(state, player_pos, tile):
						targets.append(tile)
			"move":
				occupied = _known_actor_tiles_for_player(state)
				var move_range: int = int(resolved_action.get("range", 0)) + _move_bonus_for_current_turn(state)
				var minimum: bool = not bool(action.get("_movement_pool", false)) or player_movement_remaining(state) == player_movement_capacity(state)
				var stop_after_reaching: Callable = Callable()
				if accepted_limit == 1:
					stop_after_reaching = func(tile: Vector2i) -> bool:
						return tile != player_pos and _player_action_target_is_accepted(state, action, tile, accept_target)
				var navigation: Dictionary = _unit_movement_navigation(state, player, move_range, occupied, minimum, stop_after_reaching)
				for tile: Vector2i in (navigation.get("paths", {}) as Dictionary):
					if tile != player_pos:
						targets.append(tile)
			"blink":
				occupied = _player_blocking_tiles(state)
				var max_range: int = int(resolved_action.get("range", 0))
				for tile: Vector2i in PathUtils.diamond_tiles(player_pos, max_range, state.get("grid", [])):
					if tile == player_pos:
						continue
					if occupied.has(tile):
						continue
					if not PathUtils.is_passable(state.get("grid", []), tile):
						continue
					if not is_tile_visible_to_player(state, tile, visible_lookup):
						continue
					targets.append(tile)
			"illusion":
				occupied = _occupied_actor_tiles(state)
				occupied[player_pos] = true
				var illusion_range: int = int(action.get("range", 0))
				for tile: Vector2i in PathUtils.diamond_tiles(player_pos, illusion_range, state.get("grid", [])):
					if occupied.has(tile):
						continue
					if not PathUtils.is_passable(state.get("grid", []), tile):
						continue
					if not is_tile_visible_to_player(state, tile, visible_lookup):
						continue
					targets.append(tile)
			"illuminate":
				var illuminate_range: int = int(action.get("range", 0))
				for tile: Vector2i in PathUtils.diamond_tiles(player_pos, illuminate_range, state.get("grid", [])):
					if not PathUtils.is_passable(state.get("grid", []), tile):
						continue
					if not combat_line_of_sight(state, player_pos, tile):
						continue
					targets.append(tile)
			"melee":
				var melee_range: int = int(action.get("range", 1))
				for enemy: Dictionary in _live_enemies(state):
					if not is_enemy_visible_to_player(state, enemy, visible_lookup):
						continue
					var enemy_targetable: bool = false
					for enemy_tile: Vector2i in _enemy_footprint_tiles(enemy):
						if PathUtils.manhattan(player_pos, enemy_tile) <= melee_range:
							enemy_targetable = true
							break
					if enemy_targetable:
						_append_enemy_footprint_targets(targets, enemy)
				for terrain: Dictionary in _live_terrain(state):
					var terrain_pos: Vector2i = terrain.get("pos", Vector2i.ZERO)
					if PathUtils.manhattan(player_pos, terrain_pos) <= melee_range and not targets.has(terrain_pos):
						targets.append(terrain_pos)
				for trap: Dictionary in _live_traps(state):
					var trap_pos: Vector2i = trap.get("pos", Vector2i.ZERO)
					if PathUtils.manhattan(player_pos, trap_pos) <= melee_range and not targets.has(trap_pos):
						targets.append(trap_pos)
			"ranged":
				var ranged_range: int = int(resolved_action.get("range", 1))
				for enemy: Dictionary in _live_enemies(state):
					if not is_enemy_visible_to_player(state, enemy, visible_lookup):
						continue
					var enemy_targetable: bool = false
					for enemy_tile: Vector2i in _enemy_footprint_tiles(enemy):
						if PathUtils.manhattan(player_pos, enemy_tile) > ranged_range:
							continue
						if not combat_line_of_sight(state, player_pos, enemy_tile):
							continue
						enemy_targetable = true
						break
					if enemy_targetable:
						_append_enemy_footprint_targets(targets, enemy)
				for terrain: Dictionary in _live_terrain(state):
					var terrain_pos: Vector2i = terrain.get("pos", Vector2i.ZERO)
					if PathUtils.manhattan(player_pos, terrain_pos) > ranged_range:
						continue
					if not combat_line_of_sight(state, player_pos, terrain_pos):
						continue
					if not targets.has(terrain_pos):
						targets.append(terrain_pos)
				for trap: Dictionary in _live_traps(state):
					var trap_pos: Vector2i = trap.get("pos", Vector2i.ZERO)
					if PathUtils.manhattan(player_pos, trap_pos) > ranged_range:
						continue
					if not combat_line_of_sight(state, player_pos, trap_pos):
						continue
					if not targets.has(trap_pos):
						targets.append(trap_pos)
			"aoe":
				var aoe_range: int = int(action.get("range", 0))
				if aoe_range <= 0:
					var attackable_tiles: Dictionary = _player_attackable_tiles_lookup(state, true)
					var pattern_specs: Array[Dictionary] = _aoe_pattern_specs_for_legality(action, false)
					if action.has("surface") or _aoe_pattern_specs_hit_attackable(player_pos, pattern_specs, attackable_tiles):
						targets.append(player_pos)
				else:
					for tile: Vector2i in PathUtils.diamond_tiles(player_pos, aoe_range, state.get("grid", [])):
						if tile == player_pos:
							continue
						if not PathUtils.is_passable(state.get("grid", []), tile):
							continue
						if not combat_line_of_sight(state, player_pos, tile):
							continue
						if not is_tile_visible_to_player(state, tile, visible_lookup):
							continue
						targets.append(tile)
			"push", "pull":
				var forced_range: int = int(resolved_action.get("range", 1))
				var pushing: bool = action_type == "push"
				for enemy_index: int in range((state.get("enemies", []) as Array).size()):
					var enemy: Dictionary = _normalized_enemy((state.get("enemies", []) as Array)[enemy_index] as Dictionary)
					if int(enemy.get("hp", 0)) <= 0:
						continue
					if not is_enemy_visible_to_player(state, enemy, visible_lookup):
						continue
					var resolved_force_action: Dictionary = _action_with_target_state_relic_modifiers(state, resolved_action, enemy_index)
					var force_direction: Vector2i = _action_force_direction(resolved_force_action)
					var force_amount: int = _forced_movement_amount(resolved_force_action)
					if force_direction != Vector2i.ZERO:
						if not _forced_direction_can_move_enemy(state, enemy_index, force_direction, player_pos, pushing, bool(action.get("_allow_sideways_force", false))):
							continue
					elif _force_directions_for_enemy(state, enemy_index, player_pos, pushing, force_amount).is_empty():
						continue
					var enemy_targetable: bool = false
					for enemy_tile: Vector2i in _enemy_footprint_tiles(enemy):
						if PathUtils.manhattan(player_pos, enemy_tile) > forced_range:
							continue
						if forced_range > 1 and not combat_line_of_sight(state, player_pos, enemy_tile):
							continue
						enemy_targetable = true
						break
					if enemy_targetable:
						_append_enemy_footprint_targets(targets, enemy)
		if targeting_type in ["melee", "ranged", "push", "pull"]:
			var ground_any: bool = action.has("surface") or bool(action.get("_ground_target_any", false)) or int(action.get("outcrop_health", 0)) > 0
			var ground_surface: String = str(action.get("_ground_target_surface", ""))
			if ground_any or not ground_surface.is_empty():
				for tile: Vector2i in PathUtils.diamond_tiles(player_pos, int(resolved_action.get("range", 1)), state.get("grid", [])):
					if not BoardSurfaceRules.can_place(state, tile) or not is_tile_visible_to_player(state, tile, visible_lookup): continue
					if targeting_type != "melee" and not combat_line_of_sight(state, player_pos, tile): continue
					if not ground_any and not BoardSurfaceRules.has_surface(state, tile, ground_surface): continue
					if not targets.has(tile): targets.append(tile)
		if targeting_type in ["ranged", "melee"] and _action_element(action) == "lightning" and int(action.get("damage", 0)) > 0:
			var known_opponents: Array[Dictionary]
			for opponent: Dictionary in _live_enemies(state):
				if is_enemy_visible_to_player(state, opponent, visible_lookup):
					known_opponents.append(opponent)
			var component_has_opponent: Dictionary = {}
			for tile: Vector2i in BoardSurfaceRules.tiles(state):
				if BoardSurfaceRules.is_conductive(state, tile) and PathUtils.manhattan(player_pos, tile) <= int(action.get("range", 1)) and is_tile_visible_to_player(state, tile, visible_lookup) and combat_line_of_sight(state, player_pos, tile):
					if not component_has_opponent.has(tile):
						var component: Array[Vector2i] = BoardSurfaceRules.connected_component(state, tile, visible_lookup)
						var useful: bool = false
						for opponent: Dictionary in known_opponents:
							if _surface_unit_intersects(opponent, component):
								useful = true
								break
						component_has_opponent[tile] = useful
						# Passable components are symmetric. A blocked origin can leave
						# its tile but cannot be re-entered, so never share that result.
						if BoardSurfaceRules.can_place(state, tile):
							for member: Vector2i in component:
								component_has_opponent[member] = useful
					if bool(component_has_opponent[tile]) and not targets.has(tile):
						targets.append(tile)
		var legal: Array[Vector2i]
		for tile: Vector2i in targets:
			if _player_action_target_is_accepted(state, action, tile, accept_target):
				# Existence queries still pass every authoritative restriction before
				# stopping. In particular, the first raw tile may fail a surface gate
				# or the caller's committed-information predicate.
				legal.append(tile)
				if accepted_limit > 0 and legal.size() >= accepted_limit:
					break
		targets = legal
		return targets

	func _forced_direction_can_move_enemy(state: Dictionary, enemy_index: int, direction: Vector2i, source_pos: Vector2i, pushing: bool, sideways: bool = false) -> bool:
		var step_direction: Vector2i = _cardinal_direction(direction)
		if step_direction == Vector2i.ZERO:
			return false
		var enemies: Array = state.get("enemies", [])
		if enemy_index < 0 or enemy_index >= enemies.size():
			return false
		var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			return false
		var before_distance: int = _enemy_distance_to_tile(enemy, source_pos)
		var moved_enemy: Dictionary = enemy.duplicate(true)
		moved_enemy["pos"] = enemy.get("pos", Vector2i.ZERO) + step_direction
		var after_distance: int = _enemy_distance_to_tile(moved_enemy, source_pos)
		if not sideways and pushing and after_distance <= before_distance:
			return false
		if not sideways and not pushing and after_distance >= before_distance:
			return false
		return not _enemy_direction_path(state, enemy_index, step_direction, 1).is_empty()

var failures: Array[String]
var comparisons: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var actual := CombatEngine.new()
	var original := OriginalCombatEngine.new()
	for fixture_name: String in ["open", "dense", "heart", "surface_ready", "blocked"]:
		for variant: int in range(4):
			var state: Dictionary = Fixture._fixture(actual, fixture_name)
			if variant == 1:
				state["enemies"][0]["footprint"] = Vector2i(2, 2)
				state["illusions"] = [{"id": 1, "pos": Vector2i(4, 4), "hp": 10}]
			elif variant == 2:
				state["grid"][4][4] = "wall"
				state["enemies"][0]["hp"] = 0
				state["terrain"] = [{"id": "force_box", "pos": Vector2i(6, 4), "hp": 60, "max_hp": 60}]
			elif variant == 3:
				state["relics"] = ["anchor_chain", "cinderbrand_tongs", "thunder_relay"]
				state["skill_ids"] = ["open_sky"]
				state["enemies"][0]["immobilize"] = true
				state["enemies"][0]["block"] = 5
				Surface.place(state, Vector2i(3, 4), "ice")
			var before: Dictionary = state.duplicate(true)
			var positions: Array = [Vector2i(2, 4), Vector2i(7, 3)]
			for index: int in range((state.get("enemies", []) as Array).size()):
				for direction: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i(1, 1)]:
					for source: Vector2i in positions:
						for pushing: bool in [false, true]:
							for sideways: bool in [false, true]:
								check(actual._forced_direction_can_move_enemy(state, index, direction, source, pushing, sideways) == original._forced_direction_can_move_enemy(state, index, direction, source, pushing, sideways), "Force direction must match owned one-step path oracle")
			for kind: String in ["push", "pull"]:
				for distance: int in [1, 3, 9]:
					for amount: int in [0, 1, 3]:
						for direction: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT]:
							var action: Dictionary = {"type": kind, "range": distance, "amount": amount, "damage": 3, "force_direction": direction}
							if variant == 3:
								action["surface"] = "rubble"
								action["_allow_sideways_force"] = true
							check(actual.valid_targets_for_player_action(state, action) == original.valid_targets_for_player_action(state, action), "Complete ordered force targets must match original")
							var accept: Callable = func(tile: Vector2i) -> bool: return tile.x >= 4
							check(actual.valid_targets_for_player_action(state, action, 1, accept) == original.valid_targets_for_player_action(state, action, 1, accept), "Limited accepted targets must retain authoritative order and predicate")
			check(state == before, "Force queries must not change source actors, collisions, surfaces or history")
	print("TEST RESULT: %s — %d forced-movement query comparisons (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", comparisons, failures.size()])
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	comparisons += 1
	if not ok and failures.size() < 12:
		failures.append(message)
		push_error(message)

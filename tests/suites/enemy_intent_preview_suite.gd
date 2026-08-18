extends RefCounted

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")

static func run(expect: Callable) -> void:
	_test_stationary_ranged_preview_has_no_move_echo(expect)
	_test_move_then_ranged_preview_uses_destination_origin(expect)
	_test_ranged_preview_uses_slim_distressed_ribbon_geometry(expect)
	_test_redirected_ranged_previews_use_resolved_aim_tile(expect)
	_test_ranged_preview_inherits_enemy_element(expect)
	_test_intent_state_tracks_hover_later_action_and_cancel(expect)

static func _test_stationary_ranged_preview_has_no_move_echo(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _state(
		combat,
		Vector2i(2, 4),
		Vector2i(5, 4),
		_open_grid(),
		_stationary_ranged_intent()
	)
	var threat: Dictionary = combat.enemy_threat_tiles(state, 0)
	threat["enemy_key"] = "enemy_1"
	var path: Array[Vector2i] = _tiles(threat.get("projected_path", []))
	expect.call(path.size() == 1, "An already-positioned ranged enemy should expose a stationary one-tile plan")
	expect.call(str((threat.get("projected_attack_action", {}) as Dictionary).get("type", "")) == "ranged", "Threat previews should retain the exact projected ranged action")
	expect.call(threat.get("projected_attack_from", Vector2i.ZERO) == Vector2i(5, 4), "A stationary ranged preview should fire from the enemy's current tile")
	expect.call(threat.get("projected_attack_target", Vector2i.ZERO) == Vector2i(2, 4), "A stationary ranged preview should aim at the current player tile")

	var run_scene := RunSceneScript.new()
	var previews: Array[Dictionary] = _dictionary_array([threat])
	var destination_units: Array[Dictionary] = run_scene.call("_enemy_destination_preview_units", state, previews)
	expect.call(destination_units.is_empty(), "Stationary enemy intents should not create a destination echo or movement-circle stub")
	var board := CombatBoardView.new()
	expect.call(not bool(board.call("_threat_has_projected_movement", threat)), "Board movement rendering should reject one-tile stationary enemy plans")
	var effect: Dictionary = board.call("_enemy_threat_ranged_effect", threat)
	expect.call(not effect.is_empty() and effect.get("from", Vector2i.ZERO) == Vector2i(5, 4), "Stationary ranged intents should still render their attack ribbon")
	board.free()
	run_scene.free()

static func _test_move_then_ranged_preview_uses_destination_origin(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var grid: Array = _open_grid()
	(grid[4] as Array)[4] = "pillar"
	var state: Dictionary = _state(
		combat,
		Vector2i(2, 4),
		Vector2i(5, 4),
		grid,
		{
			"name": "Find a Lane",
			"actions": [
				{"type": "move_toward", "range": 2},
				{"type": "ranged", "damage": 4, "range": 4}
			]
		}
	)
	var threat: Dictionary = combat.enemy_threat_tiles(state, 0)
	threat["enemy_key"] = "enemy_1"
	var path: Array[Vector2i] = _tiles(threat.get("projected_path", []))
	var destination: Vector2i = threat.get("projected_destination", Vector2i(-1, -1))
	expect.call(path.size() == 2 and path[path.size() - 1] == destination, "A blocked ranged enemy should expose its exact sidestep destination")
	expect.call(threat.get("projected_attack_from", Vector2i.ZERO) == destination, "A move-then-ranged preview should originate its attack at the planned destination")
	expect.call(threat.get("projected_attack_target", Vector2i.ZERO) == Vector2i(2, 4), "A move-then-ranged preview should retain the planned player target")

	var run_scene := RunSceneScript.new()
	var previews: Array[Dictionary] = _dictionary_array([threat])
	var destination_units: Array[Dictionary] = run_scene.call("_enemy_destination_preview_units", state, previews)
	expect.call(destination_units.size() == 1, "Moving enemy intents should create exactly one translucent destination echo")
	if not destination_units.is_empty():
		var preview_unit: Dictionary = destination_units[0]
		expect.call(str(preview_unit.get("role", "")) == "enemy_move_preview", "Enemy destination copies should use the dedicated preview-echo role")
		expect.call(preview_unit.get("pos", Vector2i.ZERO) == destination, "Enemy destination copies should occupy the planned landing tile")
		expect.call(str(preview_unit.get("type", "")) == "harrier", "Enemy destination copies should retain the source enemy art identity")
	var board := CombatBoardView.new()
	var effect: Dictionary = board.call("_enemy_threat_ranged_effect", threat)
	expect.call(effect.get("from", Vector2i.ZERO) == destination, "Board ranged-ribbon rendering should use the post-move attack origin")
	board.free()
	run_scene.free()

static func _test_ranged_preview_uses_slim_distressed_ribbon_geometry(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _state(
		combat,
		Vector2i(2, 4),
		Vector2i(5, 4),
		_open_grid(),
		_stationary_ranged_intent()
	)
	var threat: Dictionary = combat.enemy_threat_tiles(state, 0)
	var board := CombatBoardView.new()
	board.size = Vector2(1920.0, 1080.0)
	board.call("set_combat_state", state)
	var effect: Dictionary = board.call("_enemy_threat_ranged_effect", threat)
	var from_point := Vector2(470.0, 690.0)
	var to_point := Vector2(1070.0, 580.0)
	var geometry: Dictionary = board.call("_ranged_target_preview_geometry", effect, from_point, to_point)
	var curve_points: PackedVector2Array = geometry.get("curve_points", PackedVector2Array())
	var body_polygons: Array = geometry.get("body_polygons", []) as Array
	var crumble: Dictionary = geometry.get("crumble_geometry", {}) as Dictionary
	var repeated: Dictionary = board.call("_ranged_target_preview_geometry", effect, from_point, to_point)
	var constants: Dictionary = (board.get_script() as Script).get_script_constant_map()
	var ranged_width: float = float(geometry.get("shaft_width", 0.0))
	var move_width: float = float(board.call("_tile_height")) * float(constants.get("MOVE_PATH_SHAFT_TILE_HEIGHT_RATIO", 0.0))
	expect.call(curve_points.size() == 17, "Ranged previews should retain a smooth sampled aerial arc")
	if curve_points.size() == 17:
		var apex_y: float = curve_points[0].y
		for point: Vector2 in curve_points:
			apex_y = minf(apex_y, point.y)
		expect.call(apex_y < minf(curve_points[0].y, curve_points[curve_points.size() - 1].y) - 40.0, "Ranged preview ribbons should visibly rise into an aerial arc")
	expect.call(ranged_width > 4.0 and ranged_width < move_width * 0.60, "Ranged preview ribbons should be substantial but clearly slimmer than movement arrows")
	expect.call(not body_polygons.is_empty(), "Ranged preview distressing should retain drawable ribbon body polygons")
	expect.call((geometry.get("unified_arrow", PackedVector2Array()) as PackedVector2Array).size() >= 5, "Ranged preview shaft and arrowhead should form one unified 3D silhouette")
	var damage_counts: Dictionary = crumble.get("damage_counts", {}) as Dictionary
	var damage_count: int = int(damage_counts.get("micro", 0)) + int(damage_counts.get("chip", 0)) + int(damage_counts.get("chunk", 0))
	expect.call(damage_count > 0, "Ranged preview ribbons should carry deterministic edge nicks and missing chunks")
	expect.call(not (crumble.get("surface_spalls", []) as Array).is_empty(), "Ranged preview ribbons should carry surface spalls instead of reading as flat lines")
	expect.call(damage_counts == ((repeated.get("crumble_geometry", {}) as Dictionary).get("damage_counts", {}) as Dictionary), "Ranged preview crumble should be stable across redraws")
	board.free()

static func _test_redirected_ranged_previews_use_resolved_aim_tile(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var trap_state: Dictionary = _state(
		combat,
		Vector2i(2, 4),
		Vector2i(5, 4),
		_open_grid(),
		_stationary_ranged_intent()
	)
	trap_state["traps"] = [{
		"id": "preview_trap",
		"pos": Vector2i(3, 4),
		"element": "fire",
		"base_damage": 8,
		"damage": 8
	}]
	var trap_threat: Dictionary = combat.enemy_threat_tiles(trap_state, 0)
	expect.call(trap_threat.get("projected_attack_target", Vector2i.ZERO) == Vector2i(3, 4), "A ranged preview redirected through a stronger trap should aim at the trap rather than through it at the actor")
	var board := CombatBoardView.new()
	var trap_effect: Dictionary = board.call("_enemy_threat_ranged_effect", trap_threat)
	expect.call(trap_effect.get("to", Vector2i.ZERO) == Vector2i(3, 4), "The rendered ranged ribbon should terminate on its planned trap detonation")

	var terrain_state: Dictionary = _state(
		combat,
		Vector2i(5, 4),
		Vector2i(2, 4),
		_corridor_grid(),
		{
			"name": "Break the Lane",
			"actions": [{"type": "ranged", "damage": 3, "range": 1}]
		}
	)
	terrain_state["terrain"] = [{
		"id": "preview_crate",
		"kind": "wooden_crate",
		"pos": Vector2i(3, 4),
		"hp": 3,
		"max_hp": 3
	}]
	var terrain_threat: Dictionary = combat.enemy_threat_tiles(terrain_state, 0)
	expect.call(terrain_threat.get("projected_attack_target", Vector2i.ZERO) == Vector2i(3, 4), "A ranged preview blocked from its actor target should aim at the terrain it will actually attack")
	var terrain_effect: Dictionary = board.call("_enemy_threat_ranged_effect", terrain_threat)
	expect.call(terrain_effect.get("to", Vector2i.ZERO) == Vector2i(3, 4), "The rendered ranged ribbon should terminate on its planned blocking-terrain strike")
	board.free()

static func _test_ranged_preview_inherits_enemy_element(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _state(
		combat,
		Vector2i(2, 4),
		Vector2i(5, 4),
		_open_grid(),
		{
			"id": "static_lash",
			"name": "Static Lash",
			"actions": [
				{"type": "move_toward", "range": 3},
				{"type": "ranged", "damage": 3, "range": 3, "shock": 1},
				{"type": "intensity", "element": "lightning", "amount": 1}
			]
		}
	)
	var enemies: Array = state.get("enemies", [])
	var enemy: Dictionary = (enemies[0] as Dictionary).duplicate(true)
	enemy["type"] = "lightning_wisp"
	enemy["name"] = "Lightning Wisp"
	enemies[0] = enemy
	state["enemies"] = enemies
	var threat: Dictionary = combat.enemy_threat_tiles(state, 0)
	expect.call(str(threat.get("projected_attack_element", "")) == "lightning", "Ranged preview payloads should inherit an enemy's element when the action omits one")
	var board := CombatBoardView.new()
	var effect: Dictionary = board.call("_enemy_threat_ranged_effect", threat)
	expect.call(str(effect.get("element", "")) == "lightning", "The rendered ranged ribbon should use the same enemy-element fallback as attack execution")
	board.free()

static func _test_intent_state_tracks_hover_later_action_and_cancel(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var committed_state: Dictionary = _state(
		combat,
		Vector2i(2, 4),
		Vector2i(6, 4),
		_open_grid(),
		_stationary_ranged_intent()
	)
	var deck: Dictionary = (committed_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["guarded_step"]
	committed_state["deck"] = deck
	var hover_tile := Vector2i(3, 4)
	var actions: Array = [
		{"type": "move", "range": 2},
		{"type": "block", "amount": 3}
	]
	var target_tiles: Array[Vector2i] = _tiles([hover_tile])
	var run_scene := RunSceneScript.new()
	run_scene.set("_combat_state", committed_state.duplicate(true))
	run_scene.set("_preview_combat_state", committed_state.duplicate(true))
	run_scene.set("_selected_card_index", 0)
	run_scene.set("_pending_actions", actions.duplicate(true))
	run_scene.set("_pending_action_index", 0)
	run_scene.set("_pending_target_tiles", target_tiles)
	run_scene.set("_hovered_board_tile", hover_tile)
	var hover_state: Dictionary = run_scene.call("_enemy_intent_preview_state", committed_state)
	expect.call((hover_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO) == hover_tile, "Visible enemy intents should retarget to the currently hovered player move")
	var hover_threat: Dictionary = combat.enemy_threat_tiles(hover_state, 0)
	expect.call(hover_threat.get("projected_attack_target", Vector2i.ZERO) == hover_tile, "Enemy attack ribbons should aim at the hovered future player position")

	var later_state: Dictionary = combat.apply_player_action(committed_state.duplicate(true), actions[0], hover_tile)
	run_scene.set("_preview_combat_state", later_state)
	run_scene.set("_pending_action_index", 1)
	run_scene.set("_pending_target_tiles", _tiles([]))
	run_scene.set("_hovered_board_tile", Vector2i(-999, -999))
	var later_action_state: Dictionary = run_scene.call("_enemy_intent_preview_state", committed_state)
	expect.call((later_action_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO) == hover_tile, "Enemy intents should keep targeting the latest resolved position while previewing a later card action")

	run_scene.set("_selected_card_index", -1)
	run_scene.set("_preview_combat_state", {})
	var canceled_state: Dictionary = run_scene.call("_enemy_intent_preview_state", committed_state)
	expect.call((canceled_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(2, 4), "Canceling the card preview should restore enemy intents to the committed player position")
	run_scene.free()

static func _stationary_ranged_intent() -> Dictionary:
	return {
		"name": "Steady Shot",
		"actions": [
			{"type": "move_toward", "range": 3},
			{"type": "ranged", "damage": 4, "range": 4}
		]
	}

static func _state(combat: CombatEngine, player_pos: Vector2i, enemy_pos: Vector2i, grid: Array, intent: Dictionary) -> Dictionary:
	var layout: Dictionary = {
		"name": "Enemy Intent Preview Test",
		"coord": Vector2i(1, 0),
		"type": "combat",
		"depth": 1,
		"umbra_stage": "clear",
		"grid": grid.duplicate(true),
		"player_start": player_pos,
		"enemies": [],
		"terrain": [],
		"traps": [],
		"loot": []
	}
	var state: Dictionary = combat.create_combat(41027, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["guarded_step"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["player"] = {"pos": player_pos, "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	state["enemies"] = [{
		"id": 1,
		"type": "harrier",
		"name": "Preview Harrier",
		"pos": enemy_pos,
		"hp": 14,
		"max_hp": 14,
		"block": 0,
		"stoneskin": 0,
		"intent": intent.duplicate(true)
	}]
	state["terrain"] = []
	state["traps"] = []
	state["illusions"] = []
	state["current_actor"] = {"kind": "player", "key": "player"}
	return state

static func _open_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array[String]
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return grid

static func _corridor_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array[String]
		for x: int in range(8):
			row.append("stone" if y == 4 and x > 0 and x < 7 else "wall")
		grid.append(row)
	return grid

static func _dictionary_array(values: Array) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for value: Variant in values:
		if typeof(value) == TYPE_DICTIONARY:
			result.append(value as Dictionary)
	return result

static func _tiles(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i]
	for value: Variant in values:
		if typeof(value) == TYPE_VECTOR2I:
			result.append(value)
	return result

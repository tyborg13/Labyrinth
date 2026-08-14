extends RefCounted

const EnemyIntentCompass = preload("res://scripts/enemy_intent_compass.gd")
const CombatBoardView = preload("res://scripts/combat_board_view.gd")


static func run(expect: Callable) -> void:
	_test_action_families_are_distinct(expect)
	_test_compound_intent_points_primary_attack_from_destination(expect)
	_test_support_intents_point_to_exact_ally(expect)
	_test_pattern_intent_points_along_telegraph(expect)
	_test_visibility_boundary_hides_unknown_enemies(expect)
	_test_isometric_direction_supports_arbitrary_angles(expect)
	_test_overhead_panel_is_progressive_disclosure(expect)
	_test_large_enemy_compass_uses_front_depth_anchor(expect)


static func _test_action_families_are_distinct(expect: Callable) -> void:
	var families: Dictionary = {
		EnemyIntentCompass.family_for_action({"type": "melee"}): true,
		EnemyIntentCompass.family_for_action({"type": "ranged"}): true,
		EnemyIntentCompass.family_for_action({"type": "aoe"}): true,
		EnemyIntentCompass.family_for_action({"type": "block"}): true,
		EnemyIntentCompass.family_for_action({"type": "heal_ally"}): true,
		EnemyIntentCompass.family_for_action({"type": "move_away"}): true,
	}
	expect.call(families.size() == 6, "Enemy compass should preserve six distinct action silhouettes")
	for family_var: Variant in families:
		var path: String = EnemyIntentCompass.texture_path(str(family_var))
		expect.call(ResourceLoader.exists(path), "Enemy compass family %s should have authored raster art" % str(family_var))


static func _test_compound_intent_points_primary_attack_from_destination(expect: Callable) -> void:
	var enemy: Dictionary = _enemy(11, Vector2i(2, 2), {
		"name": "Closing Cut",
		"actions": [
			{"type": "move_toward", "range": 3},
			{"type": "melee", "damage": 7, "range": 1},
		],
	})
	var descriptor: Dictionary = EnemyIntentCompass.descriptor_for_enemy(
		_state([enemy]),
		enemy,
		enemy.get("intent", {}) as Dictionary,
		{"destination": Vector2i(4, 3), "target_tile": Vector2i(5, 3)}
	)
	expect.call(str(descriptor.get("family", "")) == EnemyIntentCompass.FAMILY_MELEE, "Compound movement attacks should keep the attack silhouette")
	expect.call(descriptor.get("target_tile", Vector2i.ZERO) == Vector2i(4, 3), "A moving enemy compass should point along its planned movement first")
	expect.call(int(descriptor.get("value", 0)) == 7, "Attack compasses should retain the primary damage value")


static func _test_support_intents_point_to_exact_ally(expect: Callable) -> void:
	var source: Dictionary = _enemy(21, Vector2i(6, 3), {
		"name": "Field Dressing",
		"actions": [{"type": "heal_ally", "amount": 5, "range": 4, "allow_self": false}],
	})
	var injured: Dictionary = _enemy(22, Vector2i(4, 4), {})
	injured["hp"] = 2
	injured["max_hp"] = 14
	var descriptor: Dictionary = EnemyIntentCompass.descriptor_for_enemy(
		_state([source, injured]), source, source.get("intent", {}) as Dictionary,
		{"destination": source.get("pos"), "support_target_tile": injured.get("pos")}
	)
	expect.call(str(descriptor.get("family", "")) == EnemyIntentCompass.FAMILY_SUPPORT, "Healing should use the support silhouette")
	expect.call(descriptor.get("target_tile", Vector2i.ZERO) == injured.get("pos"), "Support compass should point to the engine-selected ally")
	expect.call(str(descriptor.get("direction_reason", "")) == "support", "Support direction should be identified independently from hostile targeting")


static func _test_pattern_intent_points_along_telegraph(expect: Callable) -> void:
	var enemy: Dictionary = _enemy(31, Vector2i(4, 4), {
		"name": "Forked Storm",
		"actions": [{"type": "lightning_strikes", "damage": 4}],
	})
	var descriptor: Dictionary = EnemyIntentCompass.descriptor_for_enemy(
		_state([enemy]), enemy, enemy.get("intent", {}) as Dictionary,
		{"destination": enemy.get("pos"), "projected_attack": [Vector2i(4, 3), Vector2i(4, 2), Vector2i(4, 1)]}
	)
	expect.call(str(descriptor.get("family", "")) == EnemyIntentCompass.FAMILY_AREA, "Pattern attacks should use the burst silhouette")
	expect.call(descriptor.get("target_tile", Vector2i.ZERO) == Vector2i(4, 1), "Pattern compass should point toward the far edge of its telegraph")


static func _test_visibility_boundary_hides_unknown_enemies(expect: Callable) -> void:
	var visible: Dictionary = _enemy(41, Vector2i(2, 2), {"name": "Rend", "actions": [{"type": "melee", "damage": 3}]})
	var hidden: Dictionary = _enemy(42, Vector2i(7, 2), {"name": "Shot", "actions": [{"type": "ranged", "damage": 5}]})
	var descriptors: Dictionary = EnemyIntentCompass.descriptors_for_state(
		_state([visible, hidden]),
		{41: {"destination": visible.get("pos"), "target_tile": Vector2i(1, 3)}},
		[41]
	)
	expect.call(descriptors.has("enemy_41"), "Visible enemies should receive compass presentation")
	expect.call(not descriptors.has("enemy_42"), "Hidden enemies must not leak intent through a compass")


static func _test_isometric_direction_supports_arbitrary_angles(expect: Callable) -> void:
	var diagonal: float = EnemyIntentCompass.direction_angle(Vector2.ZERO, Vector2(100.0, 50.0), 0.5)
	var oblique: float = EnemyIntentCompass.direction_angle(Vector2.ZERO, Vector2(-35.0, 67.0), 0.5)
	expect.call(is_equal_approx(diagonal, PI * 0.25), "Isometric diagonal should unsquash to a 45-degree compass arm")
	expect.call(oblique > PI * 0.5 and oblique < PI, "Compass arm should retain arbitrary non-cardinal target angles")


static func _test_overhead_panel_is_progressive_disclosure(expect: Callable) -> void:
	var board: CombatBoardView = CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	var enemy: Dictionary = _enemy(51, Vector2i(4, 4), {"name": "Rend", "actions": [{"type": "melee", "damage": 4}]})
	enemy["role"] = "enemy"
	enemy["key"] = "enemy_51"
	var compact: Dictionary = board.call("_enemy_hud_layout", enemy, Vector2(480.0, 300.0), [], null)
	expect.call((compact.get("intent_rect", Rect2()) as Rect2).size == Vector2.ZERO, "Default enemy HUD should not retain a floating intent panel")
	var anchored_health: Rect2 = board.call("_unit_health_bar_rect", enemy, Vector2(480.0, 300.0)) as Rect2
	expect.call((compact.get("health_rect", Rect2()) as Rect2) == anchored_health, "Enemy health should stay directly above its sprite without intent-driven repositioning")
	board.presentation = {"expanded_enemy_actor_keys": ["enemy_51"]}
	var expanded: Dictionary = board.call("_enemy_hud_layout", enemy, Vector2(480.0, 300.0), [], load("res://fonts/LabyrinthCrumble-Text.tres"))
	expect.call((expanded.get("intent_rect", Rect2()) as Rect2).size.x > 0.0, "Focused enemy inspection should still reveal exact intent detail")
	board.free()


static func _test_large_enemy_compass_uses_front_depth_anchor(expect: Callable) -> void:
	var board: CombatBoardView = CombatBoardView.new()
	board.size = Vector2(1920.0, 1080.0)
	var large_enemy: Dictionary = _enemy(61, Vector2i(3, 2), {"name": "Breath", "actions": [{"type": "ranged", "damage": 8}]})
	large_enemy["role"] = "enemy"
	large_enemy["key"] = "enemy_61"
	large_enemy["footprint"] = Vector2i(2, 2)
	board.combat_state = {"grid": _grid(9, 8)}
	var expected: Vector2 = board.call("_tile_center", board.call("_effective_unit_tile", large_enemy)) as Vector2
	expected.y += float(board.call("_tile_height")) * 0.12
	var actual: Vector2 = board.call("_intent_compass_center", large_enemy) as Vector2
	expect.call(actual.is_equal_approx(expected), "Large enemy compass should use the front draw tile where the symbol stays visible at its feet")
	board.free()


static func _state(enemies: Array) -> Dictionary:
	return {
		"player": {"pos": Vector2i(1, 3), "hp": 24, "max_hp": 24},
		"enemies": enemies,
	}


static func _enemy(id: int, pos: Vector2i, intent: Dictionary) -> Dictionary:
	return {
		"id": id,
		"type": "crawler",
		"pos": pos,
		"hp": 14,
		"max_hp": 14,
		"intent": intent,
	}


static func _grid(width: int, height: int) -> Array:
	var result: Array = []
	for y: int in range(height):
		var row: Array = []
		for x: int in range(width):
			row.append("wall" if x == 0 or y == 0 or x == width - 1 or y == height - 1 else "stone")
		result.append(row)
	return result

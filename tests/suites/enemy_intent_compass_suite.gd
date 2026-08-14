extends RefCounted

const EnemyIntentCompass = preload("res://scripts/enemy_intent_compass.gd")
const CombatBoardView = preload("res://scripts/combat_board_view.gd")


static func run(expect: Callable) -> void:
	_test_action_families_are_distinct(expect)
	_test_live_enemy_actions_have_authored_families(expect)
	_test_compound_intent_uses_primary_attack_summary(expect)
	_test_support_intent_uses_support_summary(expect)
	_test_pattern_intent_uses_ranged_summary(expect)
	_test_visibility_boundary_hides_unknown_enemies(expect)
	_test_overhead_panel_is_progressive_disclosure(expect)
	_test_compass_stays_on_logical_tile_center(expect)
	_test_compass_family_tints_preserve_shape_cues(expect)
	_test_compass_emblems_are_contained_and_nondirectional(expect)


static func _test_action_families_are_distinct(expect: Callable) -> void:
	var families: Dictionary = {
		EnemyIntentCompass.family_for_action({"type": "melee"}): true,
		EnemyIntentCompass.family_for_action({"type": "ranged"}): true,
		EnemyIntentCompass.family_for_action({"type": "aoe"}): true,
		EnemyIntentCompass.family_for_action({"type": "block"}): true,
		EnemyIntentCompass.family_for_action({"type": "heal_ally"}): true,
		EnemyIntentCompass.family_for_action({"type": "move_away"}): true,
		EnemyIntentCompass.family_for_action({"type": "intensity"}): true,
	}
	expect.call(families.size() == 4, "Enemy compass should expose only melee, ranged, defense, and support silhouettes")
	expect.call(EnemyIntentCompass.family_for_action({"type": "aoe"}) == EnemyIntentCompass.FAMILY_RANGED, "Area attacks should collapse into the ranged scan-level family")
	expect.call(EnemyIntentCompass.family_for_action({"type": "move_away"}) == EnemyIntentCompass.FAMILY_MELEE, "Movement should collapse into the melee scan-level family")
	expect.call(EnemyIntentCompass.family_for_action({"type": "intensity"}) == EnemyIntentCompass.FAMILY_SUPPORT, "Intensity setup should collapse into the support scan-level family")
	for family_var: Variant in families:
		var path: String = EnemyIntentCompass.texture_path(str(family_var))
		expect.call(ResourceLoader.exists(path), "Enemy compass family %s should have authored raster art" % str(family_var))


static func _test_live_enemy_actions_have_authored_families(expect: Callable) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	expect.call(typeof(parsed) == TYPE_DICTIONARY, "Enemy data should parse for intent-family coverage")
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var seen_types: Dictionary = {}
	for enemy_var: Variant in (parsed as Dictionary).values():
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		for intent_var: Variant in (enemy_var as Dictionary).get("intents", []):
			if typeof(intent_var) != TYPE_DICTIONARY:
				continue
			for action_var: Variant in (intent_var as Dictionary).get("actions", []):
				if typeof(action_var) != TYPE_DICTIONARY:
					continue
				var action_type: String = str((action_var as Dictionary).get("type", ""))
				seen_types[action_type] = true
				expect.call(EnemyIntentCompass.is_supported_action_type(action_type), "Live enemy action %s should have an authored compass family" % action_type)
	expect.call(seen_types.has("intensity"), "Live enemy data should exercise intensity-to-support family collapse")
	expect.call(EnemyIntentCompass.family_for_action({"type": "intensity"}) == EnemyIntentCompass.FAMILY_SUPPORT, "Intensity should use the support scan-level silhouette")


static func _test_compound_intent_uses_primary_attack_summary(expect: Callable) -> void:
	var enemy: Dictionary = _enemy(11, Vector2i(2, 2), {
		"name": "Closing Cut",
		"actions": [
			{"type": "move_toward", "range": 3},
			{"type": "melee", "damage": 7, "range": 1},
		],
	})
	var descriptor: Dictionary = EnemyIntentCompass.descriptor_for_enemy(enemy.get("intent", {}) as Dictionary)
	expect.call(str(descriptor.get("family", "")) == EnemyIntentCompass.FAMILY_MELEE, "Compound movement attacks should keep the attack silhouette")
	expect.call(int(descriptor.get("value", 0)) == 7, "Attack compasses should retain the primary damage value")
	expect.call(not descriptor.has("target_tile") and not descriptor.has("direction_reason"), "Scan-level descriptors should not retain obsolete target-direction data")


static func _test_support_intent_uses_support_summary(expect: Callable) -> void:
	var source: Dictionary = _enemy(21, Vector2i(6, 3), {
		"name": "Field Dressing",
		"actions": [{"type": "heal_ally", "amount": 5, "range": 4, "allow_self": false}],
	})
	var descriptor: Dictionary = EnemyIntentCompass.descriptor_for_enemy(source.get("intent", {}) as Dictionary)
	expect.call(str(descriptor.get("family", "")) == EnemyIntentCompass.FAMILY_SUPPORT, "Healing should use the support silhouette")
	expect.call(str(descriptor.get("action_type", "")) == "heal_ally", "Support summary should retain its exact action type for inspection")
	expect.call(int(descriptor.get("value", 0)) == 5, "Support summary should retain its amount")


static func _test_pattern_intent_uses_ranged_summary(expect: Callable) -> void:
	var enemy: Dictionary = _enemy(31, Vector2i(4, 4), {
		"name": "Forked Storm",
		"actions": [{"type": "lightning_strikes", "damage": 4}],
	})
	var descriptor: Dictionary = EnemyIntentCompass.descriptor_for_enemy(enemy.get("intent", {}) as Dictionary)
	expect.call(str(descriptor.get("family", "")) == EnemyIntentCompass.FAMILY_RANGED, "Pattern attacks should use the ranged scan-level silhouette")
	expect.call(str(descriptor.get("action_type", "")) == "lightning_strikes", "Pattern summary should retain its exact action type for inspection")


static func _test_visibility_boundary_hides_unknown_enemies(expect: Callable) -> void:
	var visible: Dictionary = _enemy(41, Vector2i(2, 2), {"name": "Rend", "actions": [{"type": "melee", "damage": 3}]})
	var hidden: Dictionary = _enemy(42, Vector2i(7, 2), {"name": "Shot", "actions": [{"type": "ranged", "damage": 5}]})
	var descriptors: Dictionary = EnemyIntentCompass.descriptors_for_state(
		_state([visible, hidden]),
		[41]
	)
	expect.call(descriptors.has("enemy_41"), "Visible enemies should receive compass presentation")
	expect.call(not descriptors.has("enemy_42"), "Hidden enemies must not leak intent through a compass")

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


static func _test_compass_stays_on_logical_tile_center(expect: Callable) -> void:
	var board: CombatBoardView = CombatBoardView.new()
	board.size = Vector2(1920.0, 1080.0)
	var large_enemy: Dictionary = _enemy(61, Vector2i(3, 2), {"name": "Breath", "actions": [{"type": "ranged", "damage": 8}]})
	large_enemy["role"] = "enemy"
	large_enemy["key"] = "enemy_61"
	large_enemy["footprint"] = Vector2i(2, 2)
	board.combat_state = {"grid": _grid(9, 8)}
	var expected: Vector2 = board.call("_tile_center", Vector2i(3, 2)) as Vector2
	board.set("_idle_elapsed", 0.0)
	var first_frame: Vector2 = board.call("_intent_compass_center", large_enemy) as Vector2
	board.set("_idle_elapsed", 1.37)
	board.presentation = {"unit_world_positions": {"enemy_61": expected + Vector2(83.0, -41.0)}}
	var animated_frame: Vector2 = board.call("_intent_compass_center", large_enemy) as Vector2
	expect.call(first_frame.is_equal_approx(expected), "Compass should use the exact center of the enemy's logical tile")
	expect.call(animated_frame.is_equal_approx(expected), "Compass tile anchor should ignore idle frames and transient sprite presentation offsets")
	board.free()


static func _test_compass_family_tints_preserve_shape_cues(expect: Callable) -> void:
	var board: CombatBoardView = CombatBoardView.new()
	var melee_tint: Color = board.call("_intent_compass_emblem_tint", EnemyIntentCompass.FAMILY_MELEE) as Color
	var ranged_tint: Color = board.call("_intent_compass_emblem_tint", EnemyIntentCompass.FAMILY_RANGED) as Color
	var defense_tint: Color = board.call("_intent_compass_emblem_tint", EnemyIntentCompass.FAMILY_DEFENSE) as Color
	var support_tint: Color = board.call("_intent_compass_emblem_tint", EnemyIntentCompass.FAMILY_SUPPORT) as Color
	expect.call(melee_tint.r > melee_tint.b and ranged_tint.r > ranged_tint.b, "Attack compass families should use a red filter")
	expect.call(defense_tint.b > defense_tint.r, "Defense compass should use a blue filter")
	expect.call(is_equal_approx(support_tint.r, support_tint.b), "Support should preserve its authored neutral palette")
	var underlay_scale: float = float(board.get_script().get_script_constant_map().get("INTENT_COMPASS_UNDERLAY_SCALE", 0.0))
	expect.call(underlay_scale > 1.02 and underlay_scale < 1.12, "Compass visibility underlay should remain subtle")
	board.free()


static func _test_compass_emblems_are_contained_and_nondirectional(expect: Callable) -> void:
	var board: CombatBoardView = CombatBoardView.new()
	var source: String = board.get_script().source_code
	var compass_source: String = FileAccess.get_file_as_string("res://scripts/enemy_intent_compass.gd")
	var run_scene_source: String = FileAccess.get_file_as_string("res://scripts/run_scene.gd")
	var constants: Dictionary = board.get_script().get_script_constant_map()
	var ring_source_diameter: float = float(constants.get("INTENT_COMPASS_RING_SOURCE_DIAMETER", 0.0))
	var max_ring_fill: float = float(constants.get("INTENT_COMPASS_EMBLEM_MAX_RING_FILL", 0.0))
	var underlay_scale: float = float(constants.get("INTENT_COMPASS_UNDERLAY_SCALE", 0.0))
	expect.call(source.find("EnemyIntentCompass.direction_angle(center") < 0, "Compass rendering should not rotate emblems toward a target")
	expect.call(source.find("INTENT_COMPASS_ARM_PIVOT") < 0, "Compass rendering should not retain a directional arm pivot")
	expect.call(compass_source.find("direction_angle") < 0 and compass_source.find("direction_reason") < 0 and compass_source.find("target_tile") < 0, "Compass summaries should not retain obsolete direction data")
	expect.call(run_scene_source.find("enemy_intent_plan(") < 0 and run_scene_source.find("plans_by_enemy_id") < 0, "Compass refresh should not run obsolete enemy path planning")
	for family: String in [EnemyIntentCompass.FAMILY_MELEE, EnemyIntentCompass.FAMILY_RANGED, EnemyIntentCompass.FAMILY_DEFENSE, EnemyIntentCompass.FAMILY_SUPPORT]:
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(EnemyIntentCompass.texture_path(family)))
		expect.call(image.get_size() == Vector2i(256, 256), "Compass emblem %s should use the normalized square asset canvas" % family)
		expect.call(image.detect_alpha(), "Compass emblem %s should preserve transparent margins" % family)
		var opaque_extent: float = float(maxi(image.get_used_rect().size.x, image.get_used_rect().size.y))
		var family_scale: float = float(board.call("_intent_compass_emblem_scale", family))
		var underlay_extent: float = opaque_extent * family_scale * underlay_scale
		expect.call(underlay_extent <= ring_source_diameter * max_ring_fill, "Compass emblem %s should retain a visible inset inside the ring on both axes" % family)
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

extends RefCounted

const EnemyIntentCompass = preload("res://scripts/enemy_intent_compass.gd")
const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const RunScene = preload("res://scripts/run_scene.gd")


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
	_test_compasses_persist_and_refresh_during_enemy_animation(expect)
	_test_movement_landing_keeps_the_idle_sprite_source(expect)
	_test_grave_surgeon_footing_is_centered(expect)
	_test_compass_has_no_inline_number(expect)


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
	expect.call(families.size() == 3, "Enemy compass should expose only attack, defense, and support silhouettes")
	expect.call(EnemyIntentCompass.family_for_action({"type": "melee"}) == EnemyIntentCompass.FAMILY_ATTACK, "Melee attacks should use the shared attack family")
	expect.call(EnemyIntentCompass.family_for_action({"type": "ranged"}) == EnemyIntentCompass.FAMILY_ATTACK, "Ranged attacks should use the shared attack family")
	expect.call(EnemyIntentCompass.family_for_action({"type": "aoe"}) == EnemyIntentCompass.FAMILY_ATTACK, "Area attacks should use the shared attack family")
	expect.call(EnemyIntentCompass.family_for_action({"type": "move_away"}) == EnemyIntentCompass.FAMILY_ATTACK, "Movement should collapse into the attack scan-level family")
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
	expect.call(str(descriptor.get("family", "")) == EnemyIntentCompass.FAMILY_ATTACK, "Compound movement attacks should keep the attack silhouette")
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
	expect.call(str(descriptor.get("family", "")) == EnemyIntentCompass.FAMILY_ATTACK, "Pattern attacks should use the shared attack silhouette")
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
	var expected: Vector2 = board.call("world_position_for_unit_origin", large_enemy, Vector2i(3, 2)) as Vector2
	board.set("_idle_elapsed", 0.0)
	var first_frame: Vector2 = board.call("_intent_compass_center", large_enemy) as Vector2
	board.set("_idle_elapsed", 1.37)
	board.presentation = {"unit_world_positions": {"enemy_61": expected + Vector2(83.0, -41.0)}}
	var animated_frame: Vector2 = board.call("_intent_compass_center", large_enemy) as Vector2
	expect.call(first_frame.is_equal_approx(expected), "Large-enemy compass should use the exact center of its full logical footprint")
	expect.call(animated_frame.is_equal_approx(expected), "Compass footprint anchor should ignore idle frames and transient sprite presentation offsets")
	var destination_center: Vector2 = board.call("world_position_for_unit_origin", large_enemy, Vector2i(4, 2)) as Vector2
	var midmove_center: Vector2 = expected.lerp(destination_center, 0.5)
	board.presentation = {
		"unit_world_positions": {"enemy_61": midmove_center},
		"unit_footprint_world_positions": {"enemy_61": midmove_center},
	}
	var movement_frame: Vector2 = board.call("_intent_compass_center", large_enemy) as Vector2
	expect.call(movement_frame.is_equal_approx(midmove_center), "Compass should follow the interpolated center of the entire footprint during real tile movement")
	expect.call(not movement_frame.is_equal_approx(board.call("world_position_for_tile", Vector2i(4, 2)) as Vector2), "A moving 2x2 boss compass must not collapse onto the destination origin square")
	board.presentation = {}
	expect.call(is_equal_approx(float(board.call("_intent_compass_footprint_scale", large_enemy)), 2.0), "A 2x2 boss compass should scale to its four-tile footprint")
	expect.call(is_equal_approx(float(board.call("_intent_compass_footprint_scale", _enemy(62, Vector2i(2, 2), {}))), 1.0), "Normal enemies should retain a one-tile compass")
	var refreshed_boss_without_footprint: Dictionary = large_enemy.duplicate(true)
	refreshed_boss_without_footprint["type"] = "zekarion"
	refreshed_boss_without_footprint.erase("footprint")
	var refreshed_boss_with_default_footprint: Dictionary = refreshed_boss_without_footprint.duplicate(true)
	refreshed_boss_with_default_footprint["footprint"] = Vector2i.ONE
	var refreshed_expected: Vector2 = board.call("world_position_for_unit_origin", large_enemy, Vector2i(3, 2)) as Vector2
	for refreshed_boss: Dictionary in [refreshed_boss_without_footprint, refreshed_boss_with_default_footprint]:
		expect.call(is_equal_approx(float(board.call("_intent_compass_footprint_scale", refreshed_boss)), 2.0), "Zekarion refresh snapshots should recover the authored 2x2 footprint")
		expect.call((board.call("_intent_compass_center", refreshed_boss) as Vector2).is_equal_approx(refreshed_expected), "Zekarion support refresh should remain centered on all four footprint tiles")
		expect.call((board.call("world_position_for_unit_origin", refreshed_boss, Vector2i(3, 2)) as Vector2).is_equal_approx(refreshed_expected), "The sprite anchor should recover the same authored 2x2 footprint as the compass")
	var moved_boss: Dictionary = large_enemy.duplicate(true)
	moved_boss["type"] = "zekarion"
	moved_boss["pos"] = Vector2i(4, 2)
	moved_boss["intent"] = {"id": "call_wisps", "name": "Call Wisps", "actions": [{"type": "summon_minions", "count": 2}]}
	var moved_expected: Vector2 = board.call("world_position_for_unit_origin", moved_boss, Vector2i(4, 2)) as Vector2
	expect.call((board.call("_intent_compass_center", moved_boss) as Vector2).is_equal_approx(moved_expected), "A moved boss's support compass should follow the full new footprint, not its top-left origin tile")
	expect.call(is_equal_approx(float(board.call("_intent_compass_footprint_scale", moved_boss)), 2.0), "A moved boss's support compass should retain its four-tile scale")
	var scene := RunScene.new()
	var movement_snapshot: Dictionary = moved_boss.duplicate(true)
	movement_snapshot.erase("footprint")
	var recovered_actor: Dictionary = scene.call("_animation_actor_unit", {"enemies": [movement_snapshot]}, "enemy_61") as Dictionary
	expect.call(recovered_actor.get("footprint", Vector2i.ONE) == Vector2i(2, 2), "Movement interpolation should recover a large actor's authored footprint before calculating its path centers")
	scene.free()
	board.free()


static func _test_compass_family_tints_preserve_shape_cues(expect: Callable) -> void:
	var board: CombatBoardView = CombatBoardView.new()
	var attack_tint: Color = board.call("_intent_compass_emblem_tint", EnemyIntentCompass.FAMILY_ATTACK) as Color
	var defense_tint: Color = board.call("_intent_compass_emblem_tint", EnemyIntentCompass.FAMILY_DEFENSE) as Color
	var support_tint: Color = board.call("_intent_compass_emblem_tint", EnemyIntentCompass.FAMILY_SUPPORT) as Color
	expect.call(attack_tint.r > attack_tint.b, "Attack compass family should use a red filter")
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
	expect.call(is_equal_approx(float(board.call("_intent_compass_emblem_scale", EnemyIntentCompass.FAMILY_ATTACK)), 0.70), "Sword emblem should retain its authored attack scale")
	expect.call(is_equal_approx(float(board.call("_intent_compass_emblem_scale", EnemyIntentCompass.FAMILY_DEFENSE)), 0.52), "Defense emblem should retain its smaller authored scale")
	expect.call(is_equal_approx(float(board.call("_intent_compass_emblem_scale", EnemyIntentCompass.FAMILY_SUPPORT)), 0.52), "Support emblem should retain its smaller authored scale")
	for family: String in [EnemyIntentCompass.FAMILY_ATTACK, EnemyIntentCompass.FAMILY_DEFENSE, EnemyIntentCompass.FAMILY_SUPPORT]:
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(EnemyIntentCompass.texture_path(family)))
		expect.call(image.get_size() == Vector2i(256, 256), "Compass emblem %s should use the normalized square asset canvas" % family)
		expect.call(image.detect_alpha(), "Compass emblem %s should preserve transparent margins" % family)
		var opaque_extent: float = float(maxi(image.get_used_rect().size.x, image.get_used_rect().size.y))
		var family_scale: float = float(board.call("_intent_compass_emblem_scale", family))
		var underlay_extent: float = opaque_extent * family_scale * underlay_scale
		expect.call(underlay_extent <= ring_source_diameter * max_ring_fill, "Compass emblem %s should retain a visible inset inside the ring on both axes" % family)
	board.free()


static func _test_compasses_persist_and_refresh_during_enemy_animation(expect: Callable) -> void:
	var combat: RefCounted = CombatEngine.new()
	var resolved_state: Dictionary = combat.call("create_combat", 8103, {
		"name": "Intent Refresh Test",
		"coord": Vector2i(0, 0),
		"grid": _grid(9, 8),
		"player_start": Vector2i(2, 4),
		"enemies": [{
			"id": 81, "type": "crawler", "pos": Vector2i(5, 4), "hp": 14, "max_hp": 14,
		}],
		"traps": [], "loot": [], "terrain": [], "moss": {},
	}, {
		"hp": 24, "max_hp": 24, "deck_cards": [], "hand_size": 0,
	}) as Dictionary
	var acting_enemy: Dictionary = ((resolved_state.get("enemies", []) as Array)[0] as Dictionary).duplicate(true)
	acting_enemy["intent"] = {
		"id": "old_attack",
		"name": "Old Attack",
		"time": 1,
		"actions": [{"type": "melee", "damage": 1, "range": 1}],
	}
	(resolved_state.get("enemies", []) as Array)[0] = acting_enemy
	var animated_state: Dictionary = resolved_state.duplicate(true)
	var turn_result: Dictionary = combat.call("resolve_enemy_turn_with_steps", resolved_state, 0, true) as Dictionary
	var final_state: Dictionary = turn_result.get("state", {}) as Dictionary
	var next_intent: Dictionary = (((final_state.get("enemies", []) as Array)[0] as Dictionary).get("intent", {}) as Dictionary)
	var refresh_step: Dictionary = {}
	for step_var: Variant in turn_result.get("steps", []):
		if typeof(step_var) == TYPE_DICTIONARY and str((step_var as Dictionary).get("kind", "")) == "intent_refresh":
			refresh_step = step_var as Dictionary
	expect.call(str(refresh_step.get("kind", "")) == "intent_refresh", "A living enemy should emit a post-turn intent refresh step")
	expect.call((refresh_step.get("intent", {}) as Dictionary) == next_intent, "The refresh step should carry the newly assigned intent from the completed enemy turn")
	var scene: Node = RunScene.new()
	scene.call("_apply_animation_step", animated_state, refresh_step)
	expect.call(
		((((animated_state.get("enemies", []) as Array)[0] as Dictionary).get("intent", {}) as Dictionary) == next_intent),
		"Applying the post-turn step should replace that enemy's visible compass intent immediately"
	)
	var run_scene_source: String = FileAccess.get_file_as_string("res://scripts/run_scene.gd")
	expect.call(
		run_scene_source.find("rendered_presentation[\"enemy_intent_compasses\"] = _enemy_intent_compass_descriptors(display_state, visible_enemy_ids)") >= 0,
		"Every animation render should repopulate visible enemy compasses instead of dropping them until the player turn"
	)
	expect.call(
		run_scene_source.find("_movement_actor_frame_presentation(") >= 0,
		"Enemy movement animation should publish the interpolated logical footprint center separately from sprite-only offsets"
	)
	var movement_presentation: Dictionary = scene.call(
		"_movement_actor_frame_presentation",
		{},
		"enemy_81",
		Vector2(480.0, 320.0),
		Vector2i(5, 4),
		Vector2i(5, 4)
	) as Dictionary
	expect.call((movement_presentation.get("unit_world_positions", {}) as Dictionary).get("enemy_81") == Vector2(480.0, 320.0), "Movement frames should move the actor sprite to the interpolated center")
	expect.call((movement_presentation.get("unit_footprint_world_positions", {}) as Dictionary).get("enemy_81") == Vector2(480.0, 320.0), "Movement frames should move the floor compass to that same full-footprint center")
	scene.free()


static func _test_movement_landing_keeps_the_idle_sprite_source(expect: Callable) -> void:
	var board: CombatBoardView = CombatBoardView.new()
	board.size = Vector2(1920.0, 1080.0)
	board.combat_state = {"grid": _grid(11, 9)}
	board.call("_ensure_unit_assets_for_type", "zekarion")
	var unit: Dictionary = {
		"key": "enemy_91", "role": "enemy", "id": 91, "type": "zekarion",
		"pos": Vector2i(3, 2), "footprint": Vector2i(2, 2), "hp": 60, "max_hp": 60,
	}
	board.set("_idle_elapsed", 0.0)
	var idle_frames: Array = board.call("_unit_idle_frames", unit) as Array
	expect.call(not idle_frames.is_empty(), "Zekarion should expose its authored idle frames for landing continuity")
	if not idle_frames.is_empty():
		board.presentation = {"unit_world_positions": {"enemy_91": Vector2(720.0, 420.0)}}
		var moving_texture: Texture2D = board.call("_texture_for_unit", unit) as Texture2D
		board.presentation = {}
		var landed_texture: Texture2D = board.call("_texture_for_unit", unit) as Texture2D
		expect.call(moving_texture == idle_frames[0], "The final movement frame should use the authored idle sheet rather than the separately framed static texture")
		expect.call(landed_texture == moving_texture, "The first landed frame should retain the exact same grounded sprite source as the final movement frame")
	board.free()


static func _test_grave_surgeon_footing_is_centered(expect: Callable) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	var surgeon: Dictionary = ((parsed as Dictionary).get("grave_surgeon", {}) as Dictionary) if typeof(parsed) == TYPE_DICTIONARY else {}
	expect.call(is_equal_approx(float(surgeon.get("art_offset_x", 0.0)), -14.0), "Grave Surgeon art should shift left so its feet sit over the tile-centered compass")


static func _test_compass_has_no_inline_number(expect: Callable) -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/combat_board_view.gd")
	expect.call(source.find("_draw_enemy_intent_compass_value") < 0, "Compass rendering should not draw an unreadable inline action number")
	expect.call(source.find("INTENT_COMPASS_VALUE_FONT_SIZE") < 0, "Compass rendering should not retain number-only typography")


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

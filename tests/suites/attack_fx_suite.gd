extends RefCounted

const AttackFxLibrary = preload("res://scripts/attack_fx_library.gd")
const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const ElementalSpellFx = preload("res://scripts/elemental_spell_fx.gd")


static func run(expect: Callable) -> void:
	_test_fireball_selection_is_exact(expect)
	_test_every_element_owns_a_distinct_ranged_style(expect)
	_test_ranged_elemental_aoes_reuse_authored_styles(expect)
	_test_fireball_owns_a_complete_motion_schedule(expect)
	_test_elemental_styles_own_distinct_motion_schedules(expect)
	_test_elemental_spell_timing_is_staged(expect)
	_test_trap_impacts_reuse_direct_attack_cadence(expect)
	_test_authored_raster_sampling_is_continuous(expect)
	_test_spell_ingredients_are_cached_and_deterministic(expect)
	_test_spell_ingredients_have_soft_transparent_boundaries(expect)
	_test_spell_envelope_resolves_without_discontinuity(expect)
	_test_ranged_previews_use_static_curves(expect)
	_test_ranged_preview_hp_composites_on_hud(expect)
	_test_isometric_ground_anchor_is_exact_target_floor(expect)
	_test_elemental_effects_resolve_into_scene_depth_tiles(expect)
	_test_spells_preserve_direct_and_trap_footprint_scales(expect)
	_test_elemental_effects_render_below_the_hud(expect)
	_test_enemy_steps_inherit_the_attacker_element(expect)


static func _test_fireball_selection_is_exact(expect: Callable) -> void:
	expect.call(
		AttackFxLibrary.uses_fireball({"kind": "ranged", "action_type": "ranged", "element": "fire"}),
		"Ranged fire attacks should resolve through the authored fireball style"
	)


static func _test_every_element_owns_a_distinct_ranged_style(expect: Callable) -> void:
	var expected_styles: Dictionary = {
		"fire": AttackFxLibrary.STYLE_FIREBALL,
		"earth": AttackFxLibrary.STYLE_EARTH_SPIKES,
		"air": AttackFxLibrary.STYLE_AIR_GUST,
		"lightning": AttackFxLibrary.STYLE_LIGHTNING_BOLT,
		"ice": AttackFxLibrary.STYLE_ICE_SHARDS,
	}
	var resolved_styles: Dictionary = {}
	for element_id: String in expected_styles:
		var effect: Dictionary = {"kind": "ranged", "action_type": "ranged", "element": element_id}
		resolved_styles[element_id] = AttackFxLibrary.style_for_effect(effect)
		expect.call(
			resolved_styles[element_id] == expected_styles[element_id]
			and AttackFxLibrary.uses_authored_elemental_ranged(effect),
			"%s ranged attacks should resolve through their purpose-built authored style" % element_id.capitalize()
		)
	var unique_styles: Dictionary = {}
	for style_var: Variant in resolved_styles.values():
		unique_styles[str(style_var)] = true
	expect.call(unique_styles.size() == 5, "Every elemental ranged attack should have a visually independent presentation identity")
	expect.call(
		AttackFxLibrary.style_for_effect({"kind": "melee", "action_type": "melee", "element": "earth"}) == AttackFxLibrary.STYLE_DEFAULT
		and AttackFxLibrary.style_for_effect({"kind": "ranged", "action_type": "push", "element": "air"}) == AttackFxLibrary.STYLE_DEFAULT
		and AttackFxLibrary.style_for_effect({"kind": "ranged", "action_type": "ranged", "element": "none"}) == AttackFxLibrary.STYLE_DEFAULT,
		"Authored elemental ranged presentation should not leak onto melee, forced-movement, or non-element attacks"
	)
	expect.call(
		not AttackFxLibrary.uses_fireball({"kind": "melee", "action_type": "melee", "element": "fire"})
		and not AttackFxLibrary.uses_fireball({"kind": "ranged", "action_type": "push", "element": "fire"})
		and not AttackFxLibrary.uses_fireball({"kind": "ranged", "action_type": "ranged", "element": "ice"}),
		"Fireball presentation should not leak onto melee, forced-movement, or non-fire attacks"
	)


static func _test_ranged_elemental_aoes_reuse_authored_styles(expect: Callable) -> void:
	var expected_styles: Dictionary = {
		"fire": AttackFxLibrary.STYLE_FIREBALL,
		"earth": AttackFxLibrary.STYLE_EARTH_SPIKES,
		"air": AttackFxLibrary.STYLE_AIR_GUST,
		"lightning": AttackFxLibrary.STYLE_LIGHTNING_BOLT,
		"ice": AttackFxLibrary.STYLE_ICE_SHARDS,
	}
	var board: CombatBoardView = CombatBoardView.new()
	for element_id: String in expected_styles:
		var effect: Dictionary = {
			"kind": "aoe",
			"action_type": "aoe",
			"range": 5,
			"element": element_id,
			"from": Vector2i(2, 4),
			"to": Vector2i(5, 4),
			"center": Vector2i(5, 4),
			"tiles": [Vector2i(5, 4), Vector2i(6, 4)],
		}
		expect.call(
			AttackFxLibrary.style_for_effect(effect) == expected_styles[element_id]
			and AttackFxLibrary.uses_authored_elemental_attack(effect)
			and not AttackFxLibrary.uses_authored_elemental_ranged(effect)
			and bool(board.call("_effect_uses_elemental_scene_depth", effect)),
			"Ranged %s AOEs should reuse their authored elemental cast and impact without becoming single-target attacks" % element_id
		)
		expect.call(
			AttackFxLibrary.animation_frame_count(effect, 6, false) > 6
			and AttackFxLibrary.animation_frame_count(effect, 6, true) == 1
			and is_zero_approx(AttackFxLibrary.animation_frame_seconds(effect, 0.04, true)),
			"Ranged %s AOEs should receive the authored cadence and collapse to one readable reduced-motion impact" % element_id
		)
	var adjacent_aoe: Dictionary = {
		"kind": "aoe", "action_type": "aoe", "range": 0, "element": "fire"
	}
	var neutral_ranged_aoe: Dictionary = {
		"kind": "aoe", "action_type": "aoe", "range": 5, "element": "none"
	}
	var preview_aoe: Dictionary = {
		"kind": "aoe", "action_type": "aoe", "range": 5, "element": "ice", "preview": true
	}
	expect.call(
		AttackFxLibrary.style_for_effect(adjacent_aoe) == AttackFxLibrary.STYLE_DEFAULT
		and AttackFxLibrary.style_for_effect(neutral_ranged_aoe) == AttackFxLibrary.STYLE_DEFAULT
		and not bool(board.call("_effect_uses_elemental_scene_depth", preview_aoe)),
		"Authored ranged AOE motion should not leak onto self AOEs, neutral AOEs, or targeting previews"
	)
	board.free()


static func _test_fireball_owns_a_complete_motion_schedule(expect: Callable) -> void:
	var effect: Dictionary = {"kind": "ranged", "action_type": "ranged", "element": "fire"}
	expect.call(
		AttackFxLibrary.animation_frame_count(effect, 6, false) == AttackFxLibrary.FIREBALL_ANIMATION_FRAMES
		and AttackFxLibrary.animation_frame_seconds(effect, 0.04, false) == AttackFxLibrary.FIREBALL_FRAME_SECONDS,
		"Fireballs should receive their authored travel-plus-impact cadence instead of the generic six-frame projectile beat"
	)
	expect.call(
		AttackFxLibrary.animation_frame_count(effect, 6, true) == 1
		and is_zero_approx(AttackFxLibrary.animation_frame_seconds(effect, 0.04, true)),
		"Reduced motion should collapse a fireball to one immediate readable impact frame"
	)
	expect.call(
		is_equal_approx(AttackFxLibrary.fireball_travel_progress(AttackFxLibrary.FIREBALL_TRAVEL_END_PROGRESS), 1.0)
		and is_equal_approx(AttackFxLibrary.fireball_impact_progress(AttackFxLibrary.FIREBALL_TRAVEL_END_PROGRESS), 0.0)
		and is_equal_approx(AttackFxLibrary.fireball_impact_progress(1.0), 1.0),
		"Fireball travel should reach the target before the non-looping impact sequence begins"
	)


static func _test_elemental_styles_own_distinct_motion_schedules(expect: Callable) -> void:
	var schedules: Dictionary = {
		"earth": [AttackFxLibrary.EARTH_ANIMATION_FRAMES, AttackFxLibrary.EARTH_FRAME_SECONDS, AttackFxLibrary.EARTH_TRAVEL_END_PROGRESS],
		"air": [AttackFxLibrary.AIR_ANIMATION_FRAMES, AttackFxLibrary.AIR_FRAME_SECONDS, AttackFxLibrary.AIR_TRAVEL_END_PROGRESS],
		"lightning": [AttackFxLibrary.LIGHTNING_ANIMATION_FRAMES, AttackFxLibrary.LIGHTNING_FRAME_SECONDS, AttackFxLibrary.LIGHTNING_TRAVEL_END_PROGRESS],
		"ice": [AttackFxLibrary.ICE_ANIMATION_FRAMES, AttackFxLibrary.ICE_FRAME_SECONDS, AttackFxLibrary.ICE_TRAVEL_END_PROGRESS],
	}
	for element_id: String in schedules:
		var schedule: Array = schedules[element_id] as Array
		var effect: Dictionary = {"kind": "ranged", "action_type": "ranged", "element": element_id}
		var style: String = AttackFxLibrary.style_for_effect(effect)
		expect.call(
			AttackFxLibrary.animation_frame_count(effect, 6, false) == int(schedule[0])
			and is_equal_approx(AttackFxLibrary.animation_frame_seconds(effect, 0.04, false), float(schedule[1]))
			and is_equal_approx(AttackFxLibrary.travel_end_progress(style), float(schedule[2])),
			"%s should receive its authored travel-and-impact cadence" % element_id.capitalize()
		)


static func _test_elemental_spell_timing_is_staged(expect: Callable) -> void:
	var schedules: Dictionary = {
		"fire": [AttackFxLibrary.STYLE_FIREBALL, 48, 0.015, 4.0 / 48.0, 12.0 / 48.0],
		"earth": [AttackFxLibrary.STYLE_EARTH_SPIKES, 44, 0.016, 4.0 / 44.0, 16.0 / 44.0],
		"air": [AttackFxLibrary.STYLE_AIR_GUST, 38, 0.015, 4.0 / 38.0, 12.0 / 38.0],
		"lightning": [AttackFxLibrary.STYLE_LIGHTNING_BOLT, 30, 0.0115, 4.0 / 30.0, 8.0 / 30.0],
		"ice": [AttackFxLibrary.STYLE_ICE_SHARDS, 42, 0.016, 4.0 / 42.0, 14.0 / 42.0],
	}
	for element_id: String in schedules:
		var schedule: Array = schedules[element_id] as Array
		var style: String = str(schedule[0])
		var effect: Dictionary = {"kind": "ranged", "action_type": "ranged", "element": element_id}
		var anticipation_end: float = float(schedule[3])
		var travel_end: float = float(schedule[4])
		var causal_midpoint: float = lerpf(anticipation_end, travel_end, 0.5)
		expect.call(
			AttackFxLibrary.animation_frame_count(effect, 6, false) == int(schedule[1])
			and is_equal_approx(AttackFxLibrary.animation_frame_seconds(effect, 0.04, false), float(schedule[2]))
			and is_equal_approx(AttackFxLibrary.anticipation_end_progress(style), anticipation_end)
			and is_equal_approx(AttackFxLibrary.travel_end_progress(style), travel_end)
			and anticipation_end < travel_end
			and travel_end < 0.40,
			"%s should use its exact brief anticipation, causal beat, and target-dominant cadence" % element_id.capitalize()
		)
		expect.call(
			is_zero_approx(AttackFxLibrary.travel_progress_for_style(style, anticipation_end))
			and AttackFxLibrary.travel_progress_for_style(style, causal_midpoint) > 0.55
			and is_equal_approx(AttackFxLibrary.travel_progress_for_style(style, travel_end), 1.0),
			"%s causality should accelerate through the lane instead of reading as a slow translated sticker" % element_id.capitalize()
		)
		expect.call(
			is_equal_approx(AttackFxLibrary.contact_flash_strength(style, travel_end), 1.0)
			and is_zero_approx(AttackFxLibrary.contact_flash_strength(style, anticipation_end)),
			"%s should punctuate the travel-to-impact handoff with a distinct contact flash" % element_id.capitalize()
		)
		expect.call(
			AttackFxLibrary.animation_frame_count(effect, 6, true) == 1
			and is_zero_approx(AttackFxLibrary.animation_frame_seconds(effect, 0.04, true))
			and is_equal_approx(AttackFxLibrary.travel_progress_for_style(style, travel_end), 1.0)
			and is_equal_approx(AttackFxLibrary.impact_progress_for_style(style, travel_end), 0.0)
			and is_equal_approx(AttackFxLibrary.impact_progress_for_style(style, 1.0), 1.0),
			"%s should collapse safely for reduced motion and hand off from travel to impact exactly once" % element_id.capitalize()
		)


static func _test_trap_impacts_reuse_direct_attack_cadence(expect: Callable) -> void:
	var schedules: Dictionary = {
		AttackFxLibrary.STYLE_FIREBALL: [48, 0.015, 12.0 / 48.0],
		AttackFxLibrary.STYLE_EARTH_SPIKES: [44, 0.016, 16.0 / 44.0],
		AttackFxLibrary.STYLE_AIR_GUST: [38, 0.015, 12.0 / 38.0],
		AttackFxLibrary.STYLE_LIGHTNING_BOLT: [30, 0.0115, 8.0 / 30.0],
		AttackFxLibrary.STYLE_ICE_SHARDS: [42, 0.016, 14.0 / 42.0],
	}
	for style: String in schedules:
		var schedule: Array = schedules[style] as Array
		var direct_duration: float = float(schedule[0]) * float(schedule[1])
		var expected_impact_duration: float = direct_duration * (1.0 - float(schedule[2]))
		expect.call(
			is_equal_approx(AttackFxLibrary.animation_duration_seconds_for_style(style), direct_duration)
			and is_equal_approx(AttackFxLibrary.impact_duration_seconds_for_style(style), expected_impact_duration),
			"Trap %s eruptions should reuse the direct attack's exact authored impact-frame cadence" % style
		)
	var board: CombatBoardView = CombatBoardView.new()
	expect.call(
		is_equal_approx(float(board.call("_trap_elemental_effect_progress", {"effect_progress": 0.37}, 0.9)), 0.37)
		and is_equal_approx(float(board.call("_trap_elemental_effect_progress", {}, 0.42)), 0.42),
		"Per-trap authored cadence should override the longer floating-text timeline without changing its footprint scale"
	)
	board.free()


static func _test_authored_raster_sampling_is_continuous(expect: Callable) -> void:
	var one_shot_mid: Vector3 = AttackFxLibrary.one_shot_frame_blend(0.0625, 8)
	var one_shot_end: Vector3 = AttackFxLibrary.one_shot_frame_blend(1.0, 8)
	var loop_mid: Vector3 = AttackFxLibrary.looping_frame_blend(0.0625, 8, 1.0)
	expect.call(
		int(one_shot_mid.x) == 0
		and int(one_shot_mid.y) == 1
		and is_equal_approx(one_shot_mid.z, 0.5)
		and int(one_shot_end.x) == 7
		and int(one_shot_end.y) == 7
		and is_zero_approx(one_shot_end.z),
		"One-shot raster performances should continuously crossfade adjacent authored poses without wrapping the final pose"
	)
	expect.call(
		int(loop_mid.x) == 0
		and int(loop_mid.y) == 1
		and is_equal_approx(loop_mid.z, 0.5),
		"Looping raster travel should expose a continuous adjacent-frame blend instead of hard frame cuts"
	)


static func _test_spell_ingredients_are_cached_and_deterministic(expect: Callable) -> void:
	ElementalSpellFx.prepare()
	var first_generation: Array[Texture2D] = _spell_ingredients()
	var first_signatures: PackedInt64Array = _spell_ingredient_signatures(first_generation)
	for repeat: int in range(4):
		ElementalSpellFx.prepare()
		var reused: Array[Texture2D] = _spell_ingredients()
		expect.call(reused == first_generation, "Repeated board-layer initialization should reuse the same spell textures")
	# Recreating ingredients should be independent of allocation order and prior use.
	ElementalSpellFx._light = null
	ElementalSpellFx._clouds.clear()
	ElementalSpellFx.prepare()
	var regenerated: Array[Texture2D] = _spell_ingredients()
	expect.call(
		regenerated != first_generation
		and _spell_ingredient_signatures(regenerated) == first_signatures,
		"A fresh spell-resource cache should produce identical seeded texture pixels"
	)
	var pixel_budget: int = 0
	for texture: Texture2D in regenerated:
		pixel_budget += texture.get_width() * texture.get_height()
	expect.call(
		not regenerated.is_empty() and regenerated.size() <= 8 and pixel_budget <= 131072,
		"Shared spell ingredients should remain a small bounded cache instead of whole-effect animation sheets"
	)


static func _spell_ingredients() -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	if ElementalSpellFx._light != null:
		result.append(ElementalSpellFx._light)
	result.append_array(ElementalSpellFx._clouds)
	return result


static func _spell_ingredient_signatures(textures: Array[Texture2D]) -> PackedInt64Array:
	var result := PackedInt64Array()
	for texture: Texture2D in textures:
		var image: Image = texture.get_image()
		result.append(hash(image.get_data()) if image != null else 0)
	return result


static func _test_spell_ingredients_have_soft_transparent_boundaries(expect: Callable) -> void:
	ElementalSpellFx.prepare()
	for texture: Texture2D in _spell_ingredients():
		var image: Image = texture.get_image()
		if image == null or image.is_empty():
			expect.call(false, "Every generated spell ingredient should own readable image data")
			continue
		var edges_clear: bool = true
		var max_alpha: float = 0.0
		var soft_pixels: int = 0
		var transparent_pixels: int = 0
		for y: int in range(image.get_height()):
			for x: int in range(image.get_width()):
				var alpha: float = image.get_pixel(x, y).a
				max_alpha = maxf(max_alpha, alpha)
				if x == 0 or y == 0 or x == image.get_width() - 1 or y == image.get_height() - 1:
					edges_clear = edges_clear and alpha <= 0.01
				if alpha > 0.01 and alpha < 0.90:
					soft_pixels += 1
				if alpha <= 0.01:
					transparent_pixels += 1
		expect.call(
			edges_clear and max_alpha > 0.25 and soft_pixels > 16 and transparent_pixels > 16,
			"Spell texture ingredients should contain visible feathered material within transparent edges, avoiding rectangular bloom borders"
		)


static func _test_spell_envelope_resolves_without_discontinuity(expect: Callable) -> void:
	var previous: float = 0.0
	var peak: float = 0.0
	var finite_and_bounded: bool = true
	var continuous: bool = true
	for sample: int in range(257):
		var t: float = float(sample) / 256.0
		var value: float = ElementalSpellFx.envelope(t)
		finite_and_bounded = finite_and_bounded and is_finite(value) and value >= 0.0 and value <= 1.0
		continuous = continuous and absf(value - previous) < 0.20
		peak = maxf(peak, value)
		previous = value
	expect.call(
		finite_and_bounded and continuous and peak > 0.5
		and is_zero_approx(ElementalSpellFx.envelope(0.0))
		and is_zero_approx(ElementalSpellFx.envelope(1.0))
		and ElementalSpellFx.envelope(0.9) > 0.0
		and ElementalSpellFx.envelope(0.9) < peak * 0.5,
		"Spell energy should rise continuously, leave a fading aftermath, and clear completely at the end"
	)
	for element: String in ["fire", "earth", "air", "lightning", "ice"]:
		for front: bool in [false, true]:
			# Null is safe only if the boundary/zero-alpha paths submit no draw calls.
			for t: float in [-1.0, 0.0, 1.0, 2.0]:
				ElementalSpellFx.impact(null, element, Vector2.ZERO, 100.0, t, 1.0, false, front)
			ElementalSpellFx.impact(null, element, Vector2.ZERO, 100.0, 0.4, 0.0, false, front)
			ElementalSpellFx.impact(null, element, Vector2.ZERO, 100.0, 0.4, 0.0, true, front)


static func _test_ranged_previews_use_static_curves(expect: Callable) -> void:
	var board: CombatBoardView = CombatBoardView.new()
	board.size = Vector2(1920.0, 1080.0)
	var preview_effect: Dictionary = {
		"kind": "ranged",
		"action_type": "ranged",
		"from": Vector2i(2, 4),
		"to": Vector2i(5, 4),
		"element": "fire",
		"preview": true,
	}
	var start := Vector2(420.0, 520.0)
	var finish := Vector2(920.0, 560.0)
	var points: Array = board.call("_ranged_target_preview_curve_points", start, finish) as Array
	var midpoint: Vector2 = points[points.size() / 2] if not points.is_empty() else Vector2.ZERO
	var lifted_start: Vector2 = points.front() if not points.is_empty() else Vector2.ZERO
	var lifted_finish: Vector2 = points.back() if not points.is_empty() else Vector2.ZERO
	expect.call(
		points.size() == 17
		and midpoint.y < lerpf(lifted_start.y, lifted_finish.y, 0.5)
		and not bool(board.call("_effect_uses_elemental_scene_depth", preview_effect))
		and board.call("_ranged_preview_depth_tile", preview_effect) == Vector2i(5, 4)
		and not bool(board.call("_preview_effect_needs_continuous_redraw", preview_effect)),
		"Ranged targeting should use one static merged arrow on its target scene layer with no projectile animation"
	)
	board.free()


static func _test_ranged_preview_hp_composites_on_hud(expect: Callable) -> void:
	var board: CombatBoardView = CombatBoardView.new()
	var preview: Dictionary = {"hp": 87, "hp_loss": 13, "lethal": false}
	board.set("_render_layer_kind", "hud")
	var retained_hud_defers: bool = bool(board.call("_health_bar_defers_damage_preview", preview))
	board.set("_render_layer_kind", "")
	var fallback_hud_defers: bool = bool(board.call("_health_bar_defers_damage_preview", preview))
	expect.call(
		retained_hud_defers and fallback_hud_defers,
		"Projected ranged-attack HP text and its lost-health band should use one final HUD composite in both retained and monolithic rendering"
	)
	board.free()


static func _test_isometric_ground_anchor_is_exact_target_floor(expect: Callable) -> void:
	var board: CombatBoardView = CombatBoardView.new()
	board.size = Vector2(1920.0, 1080.0)
	var tile_center := Vector2(640.0, 420.0)
	var tile_height: float = float(board.call("_tile_height"))
	var ground_point: Vector2 = board.call("_elemental_ground_point", tile_center)
	var air_point: Vector2 = board.call("_elemental_air_point", tile_center, 0.60)
	expect.call(
		ground_point.is_equal_approx(tile_center),
		"Every ground light, blast base, shard, and eruption should share the exact center of the targeted isometric floor diamond"
	)
	expect.call(
		is_equal_approx(tile_center.y - air_point.y, tile_height * 0.60)
		and air_point.y < tile_center.y
		and ground_point.y > air_point.y,
		"Airborne elemental cores and their ground traces should occupy visibly separate depth planes"
	)
	board.free()


static func _test_elemental_effects_resolve_into_scene_depth_tiles(expect: Callable) -> void:
	var board: CombatBoardView = CombatBoardView.new()
	var fire_effect: Dictionary = {
		"kind": "ranged",
		"action_type": "ranged",
		"from": Vector2i(2, 4),
		"to": Vector2i(5, 4),
		"element": "fire",
	}
	var generic_effect: Dictionary = fire_effect.duplicate(true)
	generic_effect["element"] = "none"
	var fire_style: String = AttackFxLibrary.style_for_effect(fire_effect)
	var anticipation_end: float = AttackFxLibrary.anticipation_end_progress(fire_style)
	var travel_end: float = AttackFxLibrary.travel_end_progress(fire_style)
	var source_depth_tile: Vector2i = board.call("_elemental_scene_depth_tile_for_effect", fire_effect, anticipation_end)
	var moving_depth_tile: Vector2i = board.call("_elemental_scene_depth_tile_for_effect", fire_effect, lerpf(anticipation_end, travel_end, 0.50))
	var target_depth_tile: Vector2i = board.call("_elemental_scene_depth_tile_for_effect", fire_effect, travel_end)
	expect.call(
		bool(board.call("_effect_uses_elemental_scene_depth", fire_effect))
		and not bool(board.call("_effect_uses_elemental_scene_depth", generic_effect))
		and source_depth_tile == Vector2i(2, 4)
		and moving_depth_tile.x > source_depth_tile.x
		and moving_depth_tile.x < target_depth_tile.x
		and target_depth_tile == Vector2i(5, 4),
		"Authored elemental motion should advance through scene-tile depth while generic projectiles retain the feedback overlay path"
	)
	var earth_effect: Dictionary = fire_effect.duplicate(true)
	earth_effect["element"] = "earth"
	var earth_depth_tiles: Array = board.call("_elemental_scene_depth_tiles_for_presentation", {
		"effect": earth_effect,
		"effect_progress": 0.50,
	}) as Array
	expect.call(
		earth_depth_tiles.has(Vector2i(2, 4))
		and earth_depth_tiles.has(Vector2i(3, 4))
		and earth_depth_tiles.has(Vector2i(4, 4))
		and earth_depth_tiles.has(Vector2i(5, 4)),
		"Earth's persistent spike line should distribute its authored eruptions across every occupied scene-depth tile"
	)
	board.free()


static func _test_spells_preserve_direct_and_trap_footprint_scales(expect: Callable) -> void:
	var board: CombatBoardView = CombatBoardView.new()
	board.size = Vector2(1920.0, 1080.0)
	var earth_scale: float = float(board.call("_elemental_performance_size_scale", AttackFxLibrary.STYLE_EARTH_SPIKES))
	var ice_scale: float = float(board.call("_elemental_performance_size_scale", AttackFxLibrary.STYLE_ICE_SHARDS))
	var air_scale: float = float(board.call("_elemental_performance_size_scale", AttackFxLibrary.STYLE_AIR_GUST))
	var detonation_scales: Dictionary = {
		AttackFxLibrary.STYLE_FIREBALL: float(board.call("_elemental_detonation_scale", AttackFxLibrary.STYLE_FIREBALL)),
		AttackFxLibrary.STYLE_EARTH_SPIKES: float(board.call("_elemental_detonation_scale", AttackFxLibrary.STYLE_EARTH_SPIKES)),
		AttackFxLibrary.STYLE_AIR_GUST: float(board.call("_elemental_detonation_scale", AttackFxLibrary.STYLE_AIR_GUST)),
		AttackFxLibrary.STYLE_LIGHTNING_BOLT: float(board.call("_elemental_detonation_scale", AttackFxLibrary.STYLE_LIGHTNING_BOLT)),
		AttackFxLibrary.STYLE_ICE_SHARDS: float(board.call("_elemental_detonation_scale", AttackFxLibrary.STYLE_ICE_SHARDS)),
	}
	expect.call(
		earth_scale < air_scale
		and ice_scale < air_scale,
		"Earth and Ice should preserve their more compact direct-attack scale"
	)
	expect.call(
		is_equal_approx(float(detonation_scales.get(AttackFxLibrary.STYLE_FIREBALL, 0.0)), 0.50)
		and is_equal_approx(float(detonation_scales.get(AttackFxLibrary.STYLE_EARTH_SPIKES, 0.0)), 0.50)
		and is_equal_approx(float(detonation_scales.get(AttackFxLibrary.STYLE_AIR_GUST, 0.0)), 0.50)
		and is_equal_approx(float(detonation_scales.get(AttackFxLibrary.STYLE_ICE_SHARDS, 0.0)), 0.50)
		and is_equal_approx(float(detonation_scales.get(AttackFxLibrary.STYLE_LIGHTNING_BOLT, 0.0)), 1.0),
		"Every elemental detonation except Lightning should use the shared half-size presentation scale"
	)
	var trap_depth_tiles: Array[Vector2i] = board.call("_elemental_scene_depth_tiles_for_presentation", {
		"trap_effects": [
			{"pos": Vector2i(3, 3), "element": "fire"},
			{"pos": Vector2i(5, 4), "element": "ice"},
		],
	}) as Array[Vector2i]
	expect.call(
		is_equal_approx(CombatBoardView.TRAP_ELEMENTAL_DETONATION_SCALE, 1.15)
		and is_equal_approx(float(board.call("_trap_elemental_scale_ratio", AttackFxLibrary.STYLE_FIREBALL)), 2.30)
		and is_equal_approx(float(board.call("_trap_elemental_scale_ratio", AttackFxLibrary.STYLE_LIGHTNING_BOLT)), 1.15)
		and board.call("_elemental_style_for_element", "earth") == AttackFxLibrary.STYLE_EARTH_SPIKES
		and board.call("_elemental_style_for_element", "air") == AttackFxLibrary.STYLE_AIR_GUST
		and board.call("_elemental_style_for_element", "lightning") == AttackFxLibrary.STYLE_LIGHTNING_BOLT
		and board.call("_elemental_style_for_element", "ice") == AttackFxLibrary.STYLE_ICE_SHARDS
		and board.call("_elemental_style_for_element", "fire") == AttackFxLibrary.STYLE_FIREBALL
		and trap_depth_tiles.has(Vector2i(3, 3))
		and trap_depth_tiles.has(Vector2i(5, 4)),
		"Trap blasts should select their authored element, exceed direct-attack scale, and enter scene-depth routing"
	)
	board.free()


static func _test_elemental_effects_render_below_the_hud(expect: Callable) -> void:
	var board: CombatBoardView = CombatBoardView.new()
	board.size = Vector2(1920.0, 1080.0)
	board.call("_create_dynamic_render_layer")
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9):
			row.append("floor")
		grid.append(row)
	board.set("combat_state", {
		"grid": grid,
		"player": {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24},
		"enemies": [],
		"terrain": [],
		"loot": [],
		"traps": [],
		"illusions": [],
	})
	board.call("_invalidate_board_layout_cache")
	board.call("_sync_scene_render_layers")
	var world_layer: Control = board.get("_dynamic_render_layer") as Control
	var target_scene_layer: Control = (board.get("_scene_render_layers_by_tile") as Dictionary).get(Vector2i(5, 4), null) as Control
	var foreground_layer: Control = board.get("_foreground_render_layer") as Control
	var effects_layer: Control = board.get("_effects_render_layer") as Control
	var hud_layer: Control = board.get("_hud_render_layer") as Control
	expect.call(
		world_layer != null
		and target_scene_layer != null
		and foreground_layer != null
		and effects_layer != null
		and hud_layer != null
		and world_layer.get_index() < target_scene_layer.get_index()
		and target_scene_layer.get_index() < foreground_layer.get_index()
		and foreground_layer.get_index() < effects_layer.get_index()
		and effects_layer.get_index() < hud_layer.get_index(),
		"Floor illumination should render first, authored blasts should share scene-tile depth, and global feedback/HUD should remain last and crisp"
	)
	board.free()


static func _test_enemy_steps_inherit_the_attacker_element(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var before: Dictionary = {
		"player": {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0},
		"enemies": [{"id": 9, "type": "cinder_ooze", "pos": Vector2i(5, 3), "hp": 12, "max_hp": 12}],
		"terrain": [],
		"traps": [],
		"illusions": [],
	}
	var after: Dictionary = before.duplicate(true)
	(after.get("player", {}) as Dictionary)["hp"] = 19
	var step: Dictionary = combat.call(
		"_enemy_action_step",
		before,
		after,
		0,
		{"type": "ranged", "damage": 5, "range": 5}
	)
	expect.call(
		str(step.get("kind", "")) == "ranged"
		and str(step.get("action_type", "")) == "ranged"
		and str(step.get("element", "")) == "fire",
		"Enemy ranged animation steps should carry their attacker's element into presentation selection"
	)

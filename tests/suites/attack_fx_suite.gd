extends RefCounted

const AttackFxLibrary = preload("res://scripts/attack_fx_library.gd")
const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")


static func run(expect: Callable) -> void:
	_test_fireball_selection_is_exact(expect)
	_test_every_element_owns_a_distinct_ranged_style(expect)
	_test_fireball_owns_a_complete_motion_schedule(expect)
	_test_elemental_styles_own_distinct_motion_schedules(expect)
	_test_elemental_spell_timing_is_staged(expect)
	_test_authored_raster_sampling_is_continuous(expect)
	_test_fireball_sheets_load_as_authored_frames(expect)
	_test_elemental_sheets_load_as_authored_frames(expect)
	_test_sampled_fire_frames_own_transparent_bloom_padding(expect)
	_test_fireball_path_is_straight(expect)
	_test_all_authored_elemental_paths_are_straight(expect)
	_test_ranged_previews_use_static_curves(expect)
	_test_isometric_ground_anchor_is_exact_target_floor(expect)
	_test_elemental_effects_resolve_into_scene_depth_tiles(expect)
	_test_elemental_integration_profiles_own_depth_and_authored_anchors(expect)
	_test_ground_eruptions_own_compact_stable_bases(expect)
	_test_fire_resolves_through_particle_tail(expect)
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


static func _test_fireball_sheets_load_as_authored_frames(expect: Callable) -> void:
	var board: CombatBoardView = CombatBoardView.new()
	board.call("_load_assets", false)
	var travel_frames: Array = (board.get("_effect_frames") as Dictionary).get("fireball_travel", []) as Array
	var wake_frames: Array = (board.get("_effect_frames") as Dictionary).get("fireball_wake", []) as Array
	var impact_frames: Array = (board.get("_effect_frames") as Dictionary).get("fireball_impact", []) as Array
	expect.call(
		travel_frames.size() == 8 and wake_frames.size() == 8 and impact_frames.size() == 8,
		"Combat board should load eight distinct raster frames for fireball core, turbulent wake, and impact"
	)
	if travel_frames.size() == 8 and wake_frames.size() == 8 and impact_frames.size() == 8:
		expect.call(
			(travel_frames[0] as Texture2D).get_size() == Vector2(256.0, 256.0)
			and (wake_frames[0] as Texture2D).get_size() == Vector2(512.0, 512.0)
			and (impact_frames[0] as Texture2D).get_size() == Vector2(512.0, 512.0),
			"Fireball core, wake, and impact sheets should retain their validated square frame contracts"
		)
	board.free()


static func _test_elemental_sheets_load_as_authored_frames(expect: Callable) -> void:
	var board: CombatBoardView = CombatBoardView.new()
	board.call("_load_assets", false)
	var effect_frames: Dictionary = board.get("_effect_frames") as Dictionary
	var frame_keys: PackedStringArray = [
		"elemental_fire_performance",
		"elemental_earth_performance",
		"elemental_air_performance",
		"elemental_lightning_performance",
		"elemental_ice_performance",
		"elemental_fire_performance_bloom",
		"elemental_earth_performance_bloom",
		"elemental_air_performance_bloom",
		"elemental_lightning_performance_bloom",
		"elemental_ice_performance_bloom",
		"earth_spike_travel",
		"earth_spike_impact",
		"earth_ground_layer",
		"air_gust_travel",
		"air_gust_impact",
		"air_envelope_layer",
		"lightning_bolt_travel",
		"lightning_bolt_impact",
		"lightning_envelope_layer",
		"ice_shard_travel",
		"ice_icicle_impact",
		"ice_ground_layer",
	]
	for frame_key: String in frame_keys:
		var frames: Array = effect_frames.get(frame_key, []) as Array
		expect.call(frames.size() == 8, "%s should load all eight authored raster frames" % frame_key)
		if frames.size() == 8:
			expect.call(
				(frames[0] as Texture2D).get_size() == Vector2(512.0, 512.0),
				"%s should retain its validated 512x512 frame contract" % frame_key
			)
	board.free()


static func _test_sampled_fire_frames_own_transparent_bloom_padding(expect: Callable) -> void:
	var board: CombatBoardView = CombatBoardView.new()
	board.call("_load_assets", false)
	var effect_frames: Dictionary = board.get("_effect_frames") as Dictionary
	var sharp_frames: Array = effect_frames.get("elemental_fire_performance", []) as Array
	var bloom_frames: Array = effect_frames.get("elemental_fire_performance_bloom", []) as Array
	var sampled_frames: Dictionary = {}
	for sample_index: int in range(65):
		var frame_blend: Vector3 = board.call(
			"_elemental_performance_frame_blend",
			AttackFxLibrary.STYLE_FIREBALL,
			float(sample_index) / 64.0,
			sharp_frames.size(),
			false
		)
		sampled_frames[int(frame_blend.x)] = true
		sampled_frames[int(frame_blend.y)] = true
	var reduced_blend: Vector3 = board.call("_elemental_performance_frame_blend", AttackFxLibrary.STYLE_FIREBALL, 0.52, sharp_frames.size(), true)
	sampled_frames[int(reduced_blend.x)] = true
	var safe_padding: bool = not sampled_frames.is_empty()
	for frame_var: Variant in sampled_frames:
		var frame_index: int = int(frame_var)
		if sharp_frames.size() <= frame_index or bloom_frames.size() <= frame_index:
			safe_padding = false
			break
		safe_padding = safe_padding and (
			_max_top_edge_alpha(sharp_frames[frame_index] as Texture2D) <= 0.01
			and _max_top_edge_alpha(bloom_frames[frame_index] as Texture2D) <= 0.01
		)
	expect.call(
		sampled_frames.size() == 5
		and sampled_frames.has(0)
		and sampled_frames.has(1)
		and sampled_frames.has(2)
		and sampled_frames.has(3)
		and sampled_frames.has(7)
		and safe_padding,
		"Every Fire impact cell selected in normal or reduced motion should own transparent top padding so bloom cannot reveal a rectangular atlas boundary"
	)
	board.free()


static func _max_top_edge_alpha(texture: Texture2D) -> float:
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return 1.0
	var max_alpha: float = 0.0
	for x: int in range(image.get_width()):
		max_alpha = maxf(max_alpha, image.get_pixel(x, 0).a)
	return max_alpha


static func _test_fireball_path_is_straight(expect: Callable) -> void:
	var board: CombatBoardView = CombatBoardView.new()
	var start := Vector2(18.0, 42.0)
	var finish := Vector2(218.0, 112.0)
	var midpoint: Vector2 = board.call("_fireball_travel_point", start, finish, 0.5)
	expect.call(
		midpoint.is_equal_approx(start.lerp(finish, 0.5)),
		"Fireball travel should stay on the direct attacker-to-target line instead of using the generic projectile arc"
	)
	board.free()


static func _test_all_authored_elemental_paths_are_straight(expect: Callable) -> void:
	var start := Vector2(18.0, 42.0)
	var finish := Vector2(218.0, 112.0)
	for progress: float in [0.0, 0.19, 0.5, 0.83, 1.0]:
		expect.call(
			start.lerp(finish, progress).is_equal_approx(start + (finish - start) * progress),
			"Authored elemental attacks should preserve direct attacker-to-target causality at %.2f progress" % progress
		)


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
		and not bool(board.call("_preview_effect_needs_continuous_redraw", preview_effect)),
		"Ranged targeting should use one static curved overlay with no scene-depth projectile animation"
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


static func _test_elemental_integration_profiles_own_depth_and_authored_anchors(expect: Callable) -> void:
	var board: CombatBoardView = CombatBoardView.new()
	var expected_anchors: Dictionary = {
		AttackFxLibrary.STYLE_FIREBALL: 0.78,
		AttackFxLibrary.STYLE_EARTH_SPIKES: 0.80,
		AttackFxLibrary.STYLE_AIR_GUST: 0.80,
		AttackFxLibrary.STYLE_LIGHTNING_BOLT: 0.78,
		AttackFxLibrary.STYLE_ICE_SHARDS: 0.82,
	}
	var profile_signatures: Dictionary = {}
	for style_var: Variant in expected_anchors:
		var style: String = str(style_var)
		var profile: Dictionary = board.call("_elemental_integration_profile", style)
		var anchor: Vector2 = profile.get("ground_anchor", Vector2.ZERO)
		var signature: String = "%.2f|%.2f|%.2f|%s" % [
			float(profile.get("bloom_alpha", 0.0)),
			float(profile.get("floor_alpha", 0.0)),
			float(profile.get("volume_alpha", 0.0)),
			str(profile.get("volume_color", Color.TRANSPARENT)),
		]
		profile_signatures[signature] = true
		expect.call(
			is_equal_approx(anchor.x, 0.50)
			and is_equal_approx(anchor.y, float(expected_anchors.get(style, 0.0)))
			and float(profile.get("bloom_alpha", 0.0)) >= 0.40
			and float(profile.get("floor_alpha", 0.0)) >= 0.50
			and float(profile.get("volume_alpha", 0.0)) >= 0.45,
			"%s should map its authored raster origin to the tile floor and own bloom, floor light, and back-volume layers" % style
		)
		if style == AttackFxLibrary.STYLE_LIGHTNING_BOLT:
			expect.call(
				float(profile.get("rear_core_alpha", 0.0)) >= 0.44
				and float(profile.get("front_core_alpha", 0.0)) >= 0.60
				and float(profile.get("front_core_alpha", 0.0)) > float(profile.get("rear_core_alpha", 0.0))
				and float(profile.get("front_bloom_alpha", 0.0)) >= 0.85,
				"Lightning should keep a materially readable white core instead of relying mainly on transparent bloom"
			)
		else:
			expect.call(
				float(profile.get("rear_core_alpha", 1.0)) < float(profile.get("front_core_alpha", 0.0))
				and float(profile.get("front_core_alpha", 1.0)) <= 0.40
				and float(profile.get("front_bloom_alpha", 0.0)) >= 0.75
				and float(profile.get("front_veil_alpha", 0.0)) >= 0.50,
				"%s should cross the victim with a bloom-led translucent front volume while keeping the crisp raster body subordinate" % style
			)
	expect.call(profile_signatures.size() == 5, "Each element should own a distinct scene-integration profile instead of sharing one flat overlay treatment")
	var earth_contact_anchor: Vector2 = board.call("_elemental_performance_ground_anchor", AttackFxLibrary.STYLE_EARTH_SPIKES, 0)
	var earth_peak_anchor: Vector2 = board.call("_elemental_performance_ground_anchor", AttackFxLibrary.STYLE_EARTH_SPIKES, 4)
	var ice_contact_anchor: Vector2 = board.call("_elemental_performance_ground_anchor", AttackFxLibrary.STYLE_ICE_SHARDS, 0)
	var ice_peak_anchor: Vector2 = board.call("_elemental_performance_ground_anchor", AttackFxLibrary.STYLE_ICE_SHARDS, 4)
	expect.call(
		is_equal_approx(earth_contact_anchor.y, 0.68)
		and is_equal_approx(earth_peak_anchor.y, 0.80)
		and is_equal_approx(ice_contact_anchor.y, 0.78)
		and is_equal_approx(ice_peak_anchor.y, 0.82),
		"Earth and Ice should use frame-calibrated contact and peak origins so planar growth never floats above the target floor"
	)
	board.free()


static func _test_ground_eruptions_own_compact_stable_bases(expect: Callable) -> void:
	var board: CombatBoardView = CombatBoardView.new()
	board.size = Vector2(1920.0, 1080.0)
	board.call("_load_assets", false)
	var effect_frames: Dictionary = board.get("_effect_frames") as Dictionary
	var earth_cores: Array = board.call("_elemental_impact_core_frames", AttackFxLibrary.STYLE_EARTH_SPIKES) as Array
	var ice_cores: Array = board.call("_elemental_impact_core_frames", AttackFxLibrary.STYLE_ICE_SHARDS) as Array
	var earth_registry: Array = effect_frames.get("earth_spike_impact", []) as Array
	var ice_registry: Array = effect_frames.get("ice_icicle_impact", []) as Array
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
		not earth_cores.is_empty()
		and not ice_cores.is_empty()
		and earth_cores[0] == earth_registry[0]
		and ice_cores[0] == ice_registry[0],
		"Earth and Ice should use their narrow bottom-anchored eruption cores instead of baking a changing floor plate into the sharp body"
	)
	expect.call(
		earth_scale < air_scale
		and ice_scale < air_scale
		and is_equal_approx(float(board.call("_elemental_ground_contact_expansion", "earth")), 0.18)
		and is_equal_approx(float(board.call("_elemental_ground_contact_expansion", "ice")), 0.10),
		"Earth and Ice should stay smaller than airborne impacts and keep their floor footprint expansion restrained"
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


static func _test_fire_resolves_through_particle_tail(expect: Callable) -> void:
	var board: CombatBoardView = CombatBoardView.new()
	var core_late: float = float(board.call("_elemental_impact_core_fade", AttackFxLibrary.STYLE_FIREBALL, 0.90))
	var volume_late: float = float(board.call("_elemental_impact_volume_fade", AttackFxLibrary.STYLE_FIREBALL, 0.90))
	var volume_final: float = float(board.call("_elemental_impact_volume_fade", AttackFxLibrary.STYLE_FIREBALL, 1.0))
	expect.call(
		AttackFxLibrary.FIREBALL_ANIMATION_FRAMES == 48
		and is_zero_approx(core_late)
		and volume_late > 0.0
		and is_zero_approx(volume_final)
		and CombatBoardView.FIREBALL_IMPACT_EMBER_COUNT >= 27,
		"Fire should retire its opaque explosion before a longer staggered ember-and-smoke tail resolves to zero"
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

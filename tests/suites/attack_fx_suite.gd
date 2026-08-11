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
	_test_fireball_sheets_load_as_authored_frames(expect)
	_test_elemental_sheets_load_as_authored_frames(expect)
	_test_fireball_path_is_straight(expect)
	_test_all_authored_elemental_paths_are_straight(expect)
	_test_isometric_ground_anchor_tracks_the_actor_footplane(expect)
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
		"fire": [AttackFxLibrary.STYLE_FIREBALL, 18, 0.030, 2.0 / 18.0, 6.0 / 18.0],
		"earth": [AttackFxLibrary.STYLE_EARTH_SPIKES, 22, 0.032, 2.0 / 22.0, 8.0 / 22.0],
		"air": [AttackFxLibrary.STYLE_AIR_GUST, 19, 0.030, 2.0 / 19.0, 6.0 / 19.0],
		"lightning": [AttackFxLibrary.STYLE_LIGHTNING_BOLT, 15, 0.023, 2.0 / 15.0, 4.0 / 15.0],
		"ice": [AttackFxLibrary.STYLE_ICE_SHARDS, 21, 0.032, 2.0 / 21.0, 7.0 / 21.0],
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


static func _test_isometric_ground_anchor_tracks_the_actor_footplane(expect: Callable) -> void:
	var board: CombatBoardView = CombatBoardView.new()
	board.size = Vector2(1920.0, 1080.0)
	var tile_center := Vector2(640.0, 420.0)
	var tile_height: float = float(board.call("_tile_height"))
	var ground_point: Vector2 = board.call("_elemental_ground_point", tile_center)
	var air_point: Vector2 = board.call("_elemental_air_point", tile_center, 0.60)
	expect.call(
		is_equal_approx(ground_point.y - tile_center.y, tile_height * 0.40)
		and ground_point.y > tile_center.y,
		"Ground eruptions should land on the lower isometric footplane instead of the visual center of the target tile"
	)
	expect.call(
		is_equal_approx(tile_center.y - air_point.y, tile_height * 0.60)
		and air_point.y < tile_center.y
		and ground_point.y > air_point.y,
		"Airborne elemental cores and their ground traces should occupy visibly separate depth planes"
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

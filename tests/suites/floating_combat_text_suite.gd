extends RefCounted

const FloatingCombatText = preload("res://scripts/floating_combat_text.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const AttackFxLibrary = preload("res://scripts/attack_fx_library.gd")


static func run(expect: Callable) -> void:
	_test_screen_popup_collision_layout(expect)
	_test_damage_motion_curve(expect)
	_test_effect_popup_motion_curve(expect)
	_test_compound_popups_stagger_per_target(expect)
	_test_overlapping_effect_timeline(expect)
	_test_reduced_motion_hold(expect)
	_test_damage_entries_are_explicit(expect)
	_test_attack_feedback_begins_at_contact(expect)
	_test_impact_synchronizes_traps_and_terrain_destruction(expect)


static func _test_damage_motion_curve(expect: Callable) -> void:
	var base: Dictionary = FloatingCombatText.damage_entry(Vector2i(4, 3), "-13", Color("f39779"))
	var impact: Dictionary = FloatingCombatText.animate_entry(base, 0.0, false)
	var rising: Dictionary = FloatingCombatText.animate_entry(base, 0.25, false)
	var apex: Dictionary = FloatingCombatText.animate_entry(
		base,
		FloatingCombatText.ARC_APEX_PROGRESS,
		false
	)
	var linger: Dictionary = FloatingCombatText.animate_entry(base, 0.76, false)
	var finished: Dictionary = FloatingCombatText.animate_entry(base, 1.0, false)
	expect.call(
		is_equal_approx(FloatingCombatText.DAMAGE_PRESENTATION_SCALE, 1.25)
		and FloatingCombatText.DAMAGE_BASE_FONT_SIZE == 38
		and FloatingCombatText.DAMAGE_PEAK_FONT_SIZE == 75
		and FloatingCombatText.DAMAGE_EXIT_FONT_SIZE == 29
		and FloatingCombatText.DAMAGE_REDUCED_MOTION_FONT_SIZE == 40
		and is_equal_approx(FloatingCombatText.DAMAGE_WIDTH, 140.0)
		and FloatingCombatText.rendered_font_size(impact) >= float(FloatingCombatText.DAMAGE_PEAK_FONT_SIZE),
		"Every damage popup should use the shared 25%-larger presentation scale"
	)
	expect.call(
		FloatingCombatText.rendered_font_size(impact) > FloatingCombatText.rendered_font_size(rising)
		and FloatingCombatText.rendered_font_size(rising) > FloatingCombatText.rendered_font_size(linger),
		"Damage feedback should scale continuously from its impact peak into its linger size"
	)
	var impact_motion: Vector2 = impact.get("motion_offset", Vector2.INF)
	var rising_motion: Vector2 = rising.get("motion_offset", Vector2.INF)
	var apex_motion: Vector2 = apex.get("motion_offset", Vector2.INF)
	var linger_motion: Vector2 = linger.get("motion_offset", Vector2.INF)
	var finished_motion: Vector2 = finished.get("motion_offset", Vector2.INF)
	expect.call(
		impact_motion.is_zero_approx()
		and rising_motion.y < impact_motion.y
		and apex_motion.y < rising_motion.y
		and linger_motion.y > apex_motion.y
		and finished_motion.y > impact_motion.y
		and absf(linger_motion.x) > absf(rising_motion.x),
		"Damage feedback should rise, bend laterally, then fall through a real two-dimensional arc"
	)
	expect.call(
		bool(base.get("automatic_anchor", false))
		and base.get("tile", Vector2i(-1, -1)) == Vector2i(4, 3),
		"Damage feedback should keep a target-local actor anchor"
	)
	expect.call(
		float(linger.get("alpha", 0.0)) >= 0.60
		and is_equal_approx(float(finished.get("alpha", 1.0)), 0.0),
		"Damage feedback should stay readable into its abbreviated fade before clearing"
	)
	expect.call(
		FloatingCombatText.ANIMATION_DURATION_SECONDS <= 0.48
		and FloatingCombatText.ACTION_ADVANCE_SECONDS < FloatingCombatText.ANIMATION_DURATION_SECONDS
		and FloatingCombatText.TARGET_FRAME_SECONDS <= (1.0 / 60.0) + 0.0001,
		"Combat feedback should finish in half the old schedule while later actions can begin during its tail"
	)
	var right_half_motion: Vector2 = (
		FloatingCombatText.animate_entry(
			FloatingCombatText.damage_entry(Vector2i(7, 3), "-9", Color("f39779")),
			0.50,
			false
		).get("motion_offset", Vector2.ZERO)
		as Vector2
	)
	expect.call(
		rising_motion.x > 0.0 and right_half_motion.x > 0.0,
		"Every popup arc should drift toward the same right side regardless of board position"
	)


static func _test_reduced_motion_hold(expect: Callable) -> void:
	var base: Dictionary = FloatingCombatText.damage_entry(Vector2i(4, 3), "-7", Color("f39779"))
	var early: Dictionary = FloatingCombatText.animate_entry(base, 0.0, true)
	var late: Dictionary = FloatingCombatText.animate_entry(base, 0.68, true)
	expect.call(
		is_equal_approx(FloatingCombatText.rendered_font_size(early), FloatingCombatText.rendered_font_size(late))
		and (early.get("motion_offset", Vector2.INF) as Vector2).is_equal_approx(late.get("motion_offset", Vector2.ZERO)),
		"Reduced motion should hold damage at one readable size and position"
	)
	expect.call(
		is_equal_approx(float(late.get("alpha", 0.0)), 1.0),
		"Reduced motion should preserve the long readable hold"
	)
	var effect_base: Dictionary = {
		"tile": Vector2i(4, 3),
		"text": "+8",
		"color": Color("90d9ff"),
	}
	var effect_early: Dictionary = FloatingCombatText.animate_entry(effect_base, 0.0, true)
	var effect_late: Dictionary = FloatingCombatText.animate_entry(effect_base, 0.68, true)
	expect.call(
		is_equal_approx(FloatingCombatText.rendered_font_size(effect_early), FloatingCombatText.rendered_font_size(effect_late))
		and (effect_early.get("motion_offset", Vector2.INF) as Vector2).is_equal_approx(effect_late.get("motion_offset", Vector2.ZERO)),
		"Reduced motion should hold every effect popup at one readable size and position"
	)
	var compound: Array[Dictionary] = FloatingCombatText.animate_entries([
		base,
		{"tile": Vector2i(4, 3), "text": "-4 B", "color": Color("90d9ff")},
		{"tile": Vector2i(4, 3), "text": "Bleed", "color": Color("f1d18b")},
	], FloatingCombatText.STAGGER_SECONDS * 2.0 + 0.03, true)
	expect.call(
		compound.size() == 3
		and (compound[0].get("motion_offset", Vector2.INF) as Vector2) == Vector2.ZERO
		and (compound[1].get("motion_offset", Vector2.INF) as Vector2) == Vector2(0.0, -FloatingCombatText.REDUCED_STACK_STEP_Y)
		and (compound[2].get("motion_offset", Vector2.INF) as Vector2) == Vector2(0.0, -FloatingCombatText.REDUCED_STACK_STEP_Y * 2.0),
		"Reduced motion should sequence compound feedback in a stable local stack"
	)


static func _test_effect_popup_motion_curve(expect: Callable) -> void:
	var base: Dictionary = {
		"tile": Vector2i(3, 3),
		"text": "+8",
		"color": Color("90d9ff"),
	}
	var impact: Dictionary = FloatingCombatText.animate_entry(base, 0.0, false)
	var settled: Dictionary = FloatingCombatText.animate_entry(base, 0.32, false)
	var linger: Dictionary = FloatingCombatText.animate_entry(base, 0.76, false)
	expect.call(
		FloatingCombatText.is_effect_entry(impact)
		and FloatingCombatText.EFFECT_PEAK_FONT_SIZE >= 48
		and FloatingCombatText.rendered_font_size(impact) >= float(FloatingCombatText.EFFECT_PEAK_FONT_SIZE),
		"Defense, healing, status, and other effect popups should receive the enlarged impact treatment"
	)
	expect.call(
		FloatingCombatText.rendered_font_size(impact) > FloatingCombatText.rendered_font_size(settled)
		and FloatingCombatText.rendered_font_size(settled) > FloatingCombatText.rendered_font_size(linger)
		and absf((impact.get("motion_offset", Vector2.ZERO) as Vector2).x)
		< absf((linger.get("motion_offset", Vector2.ZERO) as Vector2).x),
		"Every effect popup should pop, settle, shrink, and drift through the shared motion curve"
	)
	expect.call(
		is_equal_approx(FloatingCombatText.total_duration([base]), FloatingCombatText.ANIMATION_DURATION_SECONDS)
		and float(linger.get("alpha", 0.0)) >= 0.60,
		"Every effect popup should retain a readable tail within the shortened shared schedule"
	)


static func _test_compound_popups_stagger_per_target(expect: Callable) -> void:
	var same_target: Array = [
		FloatingCombatText.damage_entry(Vector2i(5, 3), "-13", Color("f39779")),
		{"tile": Vector2i(5, 3), "text": "-4 B", "color": Color("90d9ff")},
		{"tile": Vector2i(5, 3), "text": "Bleed", "color": Color("f1d18b")},
	]
	var first_pop: Array[Dictionary] = FloatingCombatText.animate_entries(same_target, 0.05, false)
	var second_pop: Array[Dictionary] = FloatingCombatText.animate_entries(
		same_target,
		FloatingCombatText.STAGGER_SECONDS + 0.03,
		false
	)
	var third_pop: Array[Dictionary] = FloatingCombatText.animate_entries(
		same_target,
		FloatingCombatText.STAGGER_SECONDS * 2.0 + 0.03,
		false
	)
	expect.call(
		first_pop.size() == 1 and second_pop.size() == 2 and third_pop.size() == 3,
		"Compound feedback on one actor should arrive pop-pop-pop instead of appearing in one batch"
	)
	expect.call(
		FloatingCombatText.rendered_font_size(third_pop[2]) > FloatingCombatText.rendered_font_size(third_pop[1])
		and float(third_pop[2].get("animation_progress", 1.0))
		< float(third_pop[0].get("animation_progress", 0.0)),
		"Each newly staggered effect should reclaim impact emphasis without eclipsing a larger damage number"
	)
	expect.call(
		is_equal_approx(
			FloatingCombatText.total_duration(same_target),
			FloatingCombatText.ANIMATION_DURATION_SECONDS + FloatingCombatText.STAGGER_SECONDS * 2.0
		),
		"Compound feedback should give the final popup its own complete arc and linger"
	)
	var separate_targets: Array = [
		FloatingCombatText.damage_entry(Vector2i(4, 2), "-7", Color("f39779")),
		FloatingCombatText.damage_entry(Vector2i(5, 3), "-13", Color("f39779")),
		FloatingCombatText.damage_entry(Vector2i(6, 4), "-21", Color("f39779")),
	]
	expect.call(
		FloatingCombatText.animate_entries(separate_targets, 0.02, false).size() == 3,
		"Simultaneous multi-target feedback should stay local to each independently affected actor"
	)


static func _test_overlapping_effect_timeline(expect: Callable) -> void:
	var draw_entry: Dictionary = {
		"tile": Vector2i(3, 3),
		"text": "+1 draw",
		"color": Color("f1d18b"),
	}
	var play_entry: Dictionary = {
		"tile": Vector2i(3, 3),
		"text": "+1 play",
		"color": Color("ffe27a"),
	}
	var groups: Array[Dictionary] = [
		FloatingCombatText.timeline_group([draw_entry], 0.0),
		FloatingCombatText.timeline_group([play_entry], FloatingCombatText.ACTION_ADVANCE_SECONDS),
	]
	var overlap_elapsed: float = FloatingCombatText.ACTION_ADVANCE_SECONDS + 0.02
	var overlapping: Array[Dictionary] = FloatingCombatText.animate_timeline(groups, overlap_elapsed, false)
	expect.call(
		overlapping.size() == 2
		and FloatingCombatText.rendered_font_size(overlapping[1]) > FloatingCombatText.rendered_font_size(overlapping[0])
		and float(overlapping[0].get("alpha", 0.0)) >= 0.99
		and absf(
			(overlapping[0].get("motion_offset", Vector2.ZERO) as Vector2).y
			- (overlapping[1].get("motion_offset", Vector2.ZERO) as Vector2).y
		) >= 24.0,
		"A new utility popup should arrive while the previous readable label has drifted clear"
	)
	expect.call(
		FloatingCombatText.timeline_duration(groups)
		<= FloatingCombatText.ANIMATION_DURATION_SECONDS + FloatingCombatText.ACTION_ADVANCE_SECONDS + 0.0001,
		"Two consecutive utility effects should complete as one overlapping timeline instead of two serial animations"
	)
	var reduced_overlap: Array[Dictionary] = FloatingCombatText.animate_timeline(groups, overlap_elapsed, true)
	expect.call(
		reduced_overlap.size() == 2
		and (reduced_overlap[0].get("motion_offset", Vector2.ZERO) as Vector2).y
		<= -FloatingCombatText.REDUCED_STACK_STEP_Y
		and (reduced_overlap[1].get("motion_offset", Vector2.INF) as Vector2).is_zero_approx(),
		"Reduced motion should keep overlapping utility feedback in a stable readable stack"
	)


static func _test_damage_entries_are_explicit(expect: Callable) -> void:
	expect.call(
		not FloatingCombatText.is_damage_entry({"text": "-4"}),
		"Damage styling should use semantic metadata instead of parsing visible text"
	)
	var scene: Node = RunScene.new()
	var before: Dictionary = {
		"player": {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0},
		"enemies": [{"id": 1, "pos": Vector2i(4, 3), "hp": 20, "max_hp": 20, "block": 0, "stoneskin": 0}],
	}
	var after: Dictionary = before.duplicate(true)
	(after.get("enemies", []) as Array)[0]["hp"] = 7
	var player_damage: Array = scene.call("_player_damage_floating_texts", before, after)
	var bleed_damage: Array = scene.call("_floating_texts_for_step", {
		"kind": "status_damage",
		"label": "Bleed",
		"tile": Vector2i(2, 4),
		"amount": 3,
	})
	expect.call(
		player_damage.size() == 1
		and FloatingCombatText.is_damage_entry(player_damage[0] as Dictionary)
		and bool((player_damage[0] as Dictionary).get("automatic_anchor", false)),
		"Direct HP losses should opt into the large damage-number composition"
	)
	expect.call(
		bleed_damage.size() == 1
		and FloatingCombatText.is_damage_entry(bleed_damage[0] as Dictionary)
		and str((bleed_damage[0] as Dictionary).get("icon", "")) == "bleed",
		"Status damage should share the damage dynamics without losing its semantic icon"
	)
	var player_effects: Array = scene.call("_floating_texts_for_step", {
		"kind": "block",
		"tile": Vector2i(2, 4),
		"amount": 8,
	})
	var animated_player_effects: Array[Dictionary] = FloatingCombatText.animate_entries(player_effects, 0.0, false)
	expect.call(
		animated_player_effects.size() == 1
		and (animated_player_effects[0] as Dictionary).get("tile", Vector2i(-1, -1)) == Vector2i(2, 4)
		and bool((animated_player_effects[0] as Dictionary).get("automatic_anchor", false)),
		"Player gains should preserve the receiving player's tile for local popup anchoring"
	)
	scene.free()


static func _test_attack_feedback_begins_at_contact(expect: Callable) -> void:
	var scene: Node = RunScene.new()
	var fire_effect: Dictionary = {
		"kind": "ranged",
		"action_type": "ranged",
		"element": "fire",
	}
	var contact_progress: float = AttackFxLibrary.travel_end_progress(AttackFxLibrary.STYLE_FIREBALL)
	var before_contact: float = float(scene.call(
		"_attack_feedback_elapsed_seconds",
		fire_effect,
		contact_progress - 0.01,
		48,
		1.0 / 60.0,
		false
	))
	var at_contact: float = float(scene.call(
		"_attack_feedback_elapsed_seconds",
		fire_effect,
		contact_progress,
		48,
		1.0 / 60.0,
		false
	))
	var after_contact: float = float(scene.call(
		"_attack_feedback_elapsed_seconds",
		fire_effect,
		contact_progress + 0.10,
		48,
		1.0 / 60.0,
		false
	))
	expect.call(
		before_contact < 0.0 and is_zero_approx(at_contact) and after_contact > 0.0,
		"Elemental damage feedback should begin on the detonation contact frame and continue during its resolution"
	)
	expect.call(
		is_equal_approx(float(scene.call("_attack_feedback_start_progress", {"kind": "ranged"})), 0.66)
		and is_equal_approx(float(scene.call("_attack_feedback_start_progress", {"kind": "melee"})), 0.42)
		and is_zero_approx(float(scene.call(
			"_attack_feedback_elapsed_seconds",
			fire_effect,
			0.0,
			1,
			0.0,
			true
		))),
		"Generic attacks and reduced-motion attacks should share contact-synchronized feedback timing"
	)
	expect.call(
		bool(scene.call("_attack_feedback_waits_for_trap", {
			"kind": "push",
			"triggered_traps": [{"element": "fire", "pos": Vector2i(4, 3)}],
		}))
		and not bool(scene.call("_attack_feedback_waits_for_trap", {"kind": "push"})),
		"An attack-triggered trap should own a fresh eruption-time popup instead of inheriting the direct attack's elapsed arc"
	)
	scene.free()


static func _test_impact_synchronizes_traps_and_terrain_destruction(expect: Callable) -> void:
	var scene: Node = RunScene.new()
	var fire_duration: float = AttackFxLibrary.impact_duration_seconds_for_style(AttackFxLibrary.STYLE_FIREBALL)
	var animated_traps: Array = scene.call(
		"_trap_effects_for_elapsed",
		[{"element": "fire", "pos": Vector2i(4, 3)}],
		fire_duration * 0.5,
		false
	)
	var reduced_traps: Array = scene.call(
		"_trap_effects_for_elapsed",
		[{"element": "fire", "pos": Vector2i(4, 3)}],
		0.0,
		true
	)
	expect.call(
		animated_traps.size() == 1
		and is_equal_approx(float((animated_traps[0] as Dictionary).get("effect_progress", 0.0)), 0.5)
		and reduced_traps.size() == 1
		and is_equal_approx(float((reduced_traps[0] as Dictionary).get("effect_progress", 0.0)), 0.52),
		"Trap eruption frames should advance at the matching direct-impact cadence while reduced motion stays on one stable authored pose"
	)
	var fire_effect: Dictionary = {"kind": "ranged", "action_type": "ranged", "element": "fire"}
	var contact: float = AttackFxLibrary.travel_end_progress(AttackFxLibrary.STYLE_FIREBALL)
	expect.call(
		is_zero_approx(float(scene.call("_attack_terrain_destruction_progress", fire_effect, contact)))
		and is_equal_approx(float(scene.call("_attack_terrain_destruction_progress", fire_effect, 1.0)), 1.0),
		"Direct terrain breakup should start exactly at elemental contact and complete inside the explosion window"
	)
	var terrain_units: Array = scene.call(
		"_terrain_destruction_units_for_traps",
		[{"id": "crate", "kind": "wooden_crate", "pos": Vector2i(5, 4)}],
		[{
			"element": "fire",
			"pos": Vector2i(4, 3),
			"effect_progress": 0.5,
		}]
	)
	expect.call(
		terrain_units.size() == 1
		and is_equal_approx(float((terrain_units[0] as Dictionary).get("destruction_progress", 0.0)), 0.5)
		and int((terrain_units[0] as Dictionary).get("destruction_frame", -1)) == 8,
		"Trap-hit neighboring terrain should advance through its destruction sheet alongside the eruption instead of replaying later"
	)
	scene.free()


static func _test_screen_popup_collision_layout(expect: Callable) -> void:
	var bounds := Rect2(12, 16, 1896, 1036)
	var cache: Dictionary = {}
	var popups: Array[Dictionary] = []
	for index: int in range(6):
		popups.append({"key": str(index), "envelope": Rect2(Vector2(820 + (index / 2) * 84, 270 + (index % 2) * 42), Vector2(118, 108)), "layout_scale": 0.78})
	var placed: Array[Dictionary] = FloatingCombatText.place_screen_popups(popups, bounds, cache)
	for index: int in range(placed.size()):
		var envelope: Rect2 = placed[index]["envelope"]
		var offset: Vector2 = placed[index]["layout_offset"]
		var rect := Rect2(envelope.position + offset, envelope.size)
		expect.call(bounds.encloses(rect), "Simultaneous damage labels must remain inside the visible board canvas")
		expect.call(absf(offset.x) <= FloatingCombatText.SCREEN_POPUP_MAX_SIDE_SHIFT, "Collision avoidance must retain each popup's horizontal actor association")
		for other_index: int in range(index):
			var other_envelope: Rect2 = placed[other_index]["envelope"]
			var other := Rect2(other_envelope.position + (placed[other_index]["layout_offset"] as Vector2), other_envelope.size)
			expect.call(not rect.grow(3.0).intersects(other), "Dense AoE damage and block-loss popups must have separate motion envelopes")
	var original_offset: Vector2 = placed[1]["layout_offset"]
	popups.reverse()
	var repeated: Array[Dictionary] = FloatingCombatText.place_screen_popups(popups, bounds, cache)
	for popup: Dictionary in repeated:
		if str(popup["key"]) == "1":
			expect.call((popup["layout_offset"] as Vector2).is_equal_approx(original_offset), "Existing popup lanes must not shuffle when batch ordering changes")
	var empty: Array[Dictionary] = []
	FloatingCombatText.place_screen_popups(empty, bounds, cache)
	expect.call(cache.is_empty(), "Finished popup bursts must release their layout reservations")

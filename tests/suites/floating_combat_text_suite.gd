extends RefCounted

const FloatingCombatText = preload("res://scripts/floating_combat_text.gd")
const RunScene = preload("res://scripts/run_scene.gd")


static func run(expect: Callable) -> void:
	_test_damage_motion_curve(expect)
	_test_effect_popup_motion_curve(expect)
	_test_reduced_motion_hold(expect)
	_test_damage_entries_are_explicit(expect)


static func _test_damage_motion_curve(expect: Callable) -> void:
	var base: Dictionary = FloatingCombatText.damage_entry(Vector2i(4, 3), "-13", Color("f39779"))
	var impact: Dictionary = FloatingCombatText.animate_entry(base, 0.0, false)
	var settled: Dictionary = FloatingCombatText.animate_entry(base, 0.32, false)
	var linger: Dictionary = FloatingCombatText.animate_entry(base, 0.76, false)
	var finished: Dictionary = FloatingCombatText.animate_entry(base, 1.0, false)
	expect.call(
		int(impact.get("font_size", 0)) >= FloatingCombatText.DAMAGE_PEAK_FONT_SIZE,
		"Damage feedback should arrive at a hero-sized impact peak"
	)
	expect.call(
		int(impact.get("font_size", 0)) > int(settled.get("font_size", 0))
		and int(settled.get("font_size", 0)) > int(linger.get("font_size", 0)),
		"Damage feedback should settle quickly, then shrink more gently while it drifts"
	)
	expect.call(
		float(impact.get("rise", -1.0)) < float(settled.get("rise", -1.0))
		and float(settled.get("rise", -1.0)) < float(linger.get("rise", -1.0)),
		"Damage feedback should drift monotonically away from its target"
	)
	expect.call(
		float(base.get("anchor_y", -1.0)) > 0.0,
		"Damage feedback should occupy the struck actor lane instead of the HUD lane"
	)
	expect.call(
		is_equal_approx(float(linger.get("alpha", 0.0)), 1.0)
		and is_equal_approx(float(finished.get("alpha", 1.0)), 0.0),
		"Damage feedback should remain fully readable into its linger beat before fading"
	)
	expect.call(
		FloatingCombatText.DAMAGE_FRAME_COUNT * FloatingCombatText.DAMAGE_FRAME_SECONDS >= 0.72,
		"Damage feedback should remain scheduled for at least 0.72 seconds"
	)


static func _test_reduced_motion_hold(expect: Callable) -> void:
	var base: Dictionary = FloatingCombatText.damage_entry(Vector2i(4, 3), "-7", Color("f39779"))
	var early: Dictionary = FloatingCombatText.animate_entry(base, 0.0, true)
	var late: Dictionary = FloatingCombatText.animate_entry(base, 0.82, true)
	expect.call(
		int(early.get("font_size", 0)) == int(late.get("font_size", -1))
		and is_equal_approx(float(early.get("rise", -1.0)), float(late.get("rise", -2.0))),
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
	var effect_late: Dictionary = FloatingCombatText.animate_entry(effect_base, 0.82, true)
	expect.call(
		int(effect_early.get("font_size", 0)) == int(effect_late.get("font_size", -1))
		and is_equal_approx(float(effect_early.get("rise", -1.0)), float(effect_late.get("rise", -2.0))),
		"Reduced motion should hold every effect popup at one readable size and position"
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
		and int(impact.get("font_size", 0)) >= FloatingCombatText.EFFECT_PEAK_FONT_SIZE,
		"Defense, healing, status, and other effect popups should receive the same readable impact treatment"
	)
	expect.call(
		int(impact.get("font_size", 0)) > int(settled.get("font_size", 0))
		and int(settled.get("font_size", 0)) > int(linger.get("font_size", 0))
		and float(impact.get("rise", -1.0)) < float(linger.get("rise", -1.0)),
		"Every effect popup should pop, settle, shrink, and drift through the shared motion curve"
	)
	expect.call(
		FloatingCombatText.frame_count([base]) == FloatingCombatText.DAMAGE_FRAME_COUNT
		and is_equal_approx(float(linger.get("alpha", 0.0)), 1.0),
		"Every effect popup should receive the longer shared linger schedule"
	)
	expect.call(
		RunScene.FATIGUE_EFFECT_FRAMES * RunScene.FATIGUE_EFFECT_FRAME_SECONDS
		>= FloatingCombatText.DAMAGE_FRAME_COUNT * FloatingCombatText.DAMAGE_FRAME_SECONDS,
		"Fatigue feedback should keep the full shared popup schedule"
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
		and int((player_damage[0] as Dictionary).get("font_size", 0)) == FloatingCombatText.DAMAGE_BASE_FONT_SIZE,
		"Direct HP losses should opt into the large damage-number composition"
	)
	expect.call(
		bleed_damage.size() == 1
		and FloatingCombatText.is_damage_entry(bleed_damage[0] as Dictionary)
		and str((bleed_damage[0] as Dictionary).get("icon", "")) == "bleed",
		"Status damage should share the damage dynamics without losing its semantic icon"
	)
	scene.free()

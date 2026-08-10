extends RefCounted

const AttackFxLibrary = preload("res://scripts/attack_fx_library.gd")
const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")


static func run(expect: Callable) -> void:
	_test_fireball_selection_is_exact(expect)
	_test_fireball_owns_a_complete_motion_schedule(expect)
	_test_fireball_sheets_load_as_authored_frames(expect)
	_test_fireball_path_is_straight(expect)
	_test_enemy_steps_inherit_the_attacker_element(expect)


static func _test_fireball_selection_is_exact(expect: Callable) -> void:
	expect.call(
		AttackFxLibrary.uses_fireball({"kind": "ranged", "action_type": "ranged", "element": "fire"}),
		"Ranged fire attacks should resolve through the authored fireball style"
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

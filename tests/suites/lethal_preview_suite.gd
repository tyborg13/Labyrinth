extends RefCounted

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const RunScene = preload("res://scripts/run_scene.gd")


static func run(expect: Callable) -> void:
	_test_cumulative_lethal_preview_keeps_units_visible(expect)
	_test_lethal_death_mark_motion(expect)


static func _test_cumulative_lethal_preview_keeps_units_visible(expect: Callable) -> void:
	var instance: Node = RunScene.new()
	var committed_state: Dictionary = _state([
		_enemy(1, Vector2i(3, 4), 4),
		_enemy(2, Vector2i(4, 4), 7),
		_enemy(3, Vector2i(5, 4), 10),
	])
	var projected_state: Dictionary = _state([
		_enemy(2, Vector2i(4, 3), 0, 2),
		_enemy(3, Vector2i(5, 4), 6),
	])
	var damage_preview: Dictionary = instance.call("_damage_preview_between_states", committed_state, projected_state)
	for enemy_id: int in [1, 2]:
		var preview: Dictionary = damage_preview.get("enemy_%d" % enemy_id, {}) as Dictionary
		expect.call(
			int(preview.get("hp", -1)) == 0 and bool(preview.get("lethal", false)),
			"Missing and zero-HP enemies should both produce lethal cumulative previews"
		)
	var survivor_preview: Dictionary = damage_preview.get("enemy_3", {}) as Dictionary
	expect.call(
		int(survivor_preview.get("hp", -1)) == 6 and not bool(survivor_preview.get("lethal", true)),
		"Cumulative previews should retain nonlethal projected HP"
	)

	instance.set("_combat_state", committed_state)
	var display_state: Dictionary = instance.call("_combat_preview_display_state", projected_state)
	var display_by_id: Dictionary = {}
	for enemy_var: Variant in display_state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var
		display_by_id[int(enemy.get("id", -1))] = enemy
	expect.call(display_by_id.size() == 3, "Preview display state should restore every committed enemy")
	expect.call(
		int((display_by_id.get(1, {}) as Dictionary).get("hp", 0)) == 4
		and int((display_by_id.get(2, {}) as Dictionary).get("hp", 0)) == 7,
		"Preview display state should keep committed HP as the damage-overlay baseline"
	)
	expect.call(
		(display_by_id.get(2, {}) as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(4, 3)
		and int((display_by_id.get(2, {}) as Dictionary).get("burn", 0)) == 2,
		"Preview display state should retain projected position and status changes"
	)

	var board: CombatBoardView = CombatBoardView.new()
	board.set("combat_state", display_state)
	board.set("presentation", {"damage_preview": damage_preview})
	var visible_units: Array = board.call("_build_visible_units")
	var lethal_unit_count: int = 0
	var visible_enemy_count: int = 0
	for unit_var: Variant in visible_units:
		if typeof(unit_var) != TYPE_DICTIONARY:
			continue
		var unit: Dictionary = unit_var
		if str(unit.get("role", "")) != "enemy":
			continue
		visible_enemy_count += 1
		if bool(board.call("_unit_is_preview_lethal", unit)):
			lethal_unit_count += 1
	expect.call(
		visible_enemy_count == 3 and lethal_unit_count == 2,
		"Combat board should keep all enemies visible while marking both lethal previews"
	)
	var lethal_preview: Dictionary = damage_preview.get("enemy_2", {}) as Dictionary
	expect.call(
		int(board.call("_health_bar_fill_hp", display_by_id.get(2, {}), lethal_preview)) == 0
		and not bool(board.call("_damage_preview_shows_lost_hp", lethal_preview)),
		"Lethal previews should render an empty health bar without a full-width damage fill"
	)
	expect.call(
		int(board.call("_health_bar_fill_hp", display_by_id.get(3, {}), survivor_preview)) == 6
		and bool(board.call("_damage_preview_shows_lost_hp", survivor_preview)),
		"Nonlethal previews should retain their projected fill and lost-health overlay"
	)
	board.free()
	instance.free()


static func _test_lethal_death_mark_motion(expect: Callable) -> void:
	var board: CombatBoardView = CombatBoardView.new()
	board.set("presentation", {"reduced_motion": false})
	var pulse_period: float = CombatBoardView.LETHAL_DEATH_MARK_PULSE_SECONDS
	var neutral_pulse: float = float(board.call("_lethal_death_mark_pulse", 0.0))
	var peak_pulse: float = float(board.call("_lethal_death_mark_pulse", pulse_period * 0.25))
	var trough_pulse: float = float(board.call("_lethal_death_mark_pulse", pulse_period * 0.75))
	expect.call(
		is_equal_approx(neutral_pulse, 0.5)
		and is_equal_approx(peak_pulse, 1.0)
		and is_equal_approx(trough_pulse, 0.0),
		"Lethal death mark should breathe through deterministic neutral, peak, and trough phases"
	)

	board.set("presentation", {"reduced_motion": true})
	var reduced_start: float = float(board.call("_lethal_death_mark_pulse", 0.0))
	var reduced_later: float = float(board.call("_lethal_death_mark_pulse", pulse_period * 0.25))
	expect.call(
		is_equal_approx(reduced_start, 0.5) and is_equal_approx(reduced_later, 0.5),
		"Reduced motion should hold the lethal death mark at a stable neutral frame"
	)
	board.free()


static func _state(enemies: Array) -> Dictionary:
	return {
		"player": {
			"pos": Vector2i(2, 4),
			"hp": 24,
			"max_hp": 24,
			"block": 0,
			"stoneskin": 0,
		},
		"enemies": enemies,
		"illusions": [],
		"npcs": [],
	}


static func _enemy(id: int, pos: Vector2i, hp: int, burn: int = 0) -> Dictionary:
	return {
		"id": id,
		"type": "crawler",
		"pos": pos,
		"hp": hp,
		"max_hp": 10,
		"block": 0,
		"stoneskin": 0,
		"burn": burn,
		"freeze": 0,
		"shock": 0,
		"immobilize": false,
		"poison": {},
	}

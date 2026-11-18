extends RefCounted
## area-02: live Gust, marking-time guard and immovable blockers.
const Combat = preload("res://scripts/combat_engine.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Base = preload("res://tests/suites/battlefield_rules_suite.gd")
const Typed = preload("res://scripts/typed_arrays.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const PROOF_CALL: Dictionary = {"type": "call_wind", "push": 1, "rounds": 2, "_wind_direction": Vector2i.RIGHT}

static func run(expect: Callable) -> void:
	_gust(expect)
	_raise_exceptions(expect)
	_breakout(expect)
	_sealed_neighbour(expect)
	print("AREA02 LIVE GUST/UPHEAVAL: Calls, global pushes, immovable blockers and breakout checked")

static func _gust(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = engine.finish_player_activation(Base.battle(engine))
	Rules.install_call(engine, state, 0, PROOF_CALL)
	var view := preload("res://scripts/combat_board_view.gd").new()
	view.combat_state = state
	var shown: Dictionary = preload("res://scripts/enemy_mechanics/wind_view.gd").forecast(view)
	expect.call(not shown["layers"].is_empty() and shown["wind"]["direction"] == Vector2i.RIGHT, "A new Call shows its current wind immediately")
	view.free()
	state["illusions"] = [{"id": 5, "pos": Vector2i(3, 3), "hp": 5, "max_hp": 5}]
	var steps: Array[Dictionary]
	var after: Dictionary = Rules.fire(engine, state.duplicate(true), steps)
	expect.call(steps[0]["action_direction"] == Vector2i.RIGHT and after["battlefield_rule"]["beats_remaining"] == 1, "A first Call can blow that foes turn")
	expect.call(after["illusions"][0]["pos"] == Vector2i(4, 3), "Gust pushes global live occupants")
	var reaim: Dictionary = PROOF_CALL.duplicate(true)
	reaim["_wind_direction"] = Vector2i.LEFT
	Rules.install_call(engine, state, 0, reaim)
	steps.clear()
	after = Rules.fire(engine, state, steps)
	expect.call(steps[0]["action_direction"] == Vector2i.LEFT and after["player"]["pos"] == Vector2i(4, 5), "A reaimed Call blows in its newly installed direction")

static func held(engine: RefCounted, marks: Array[Vector2i]) -> Dictionary:
	var state: Dictionary = Base.battle(engine)
	var instance: Dictionary = Base.rule("upheaval", {"pattern": "line_between", "length": 3, "health": 3}, true)
	instance["marks"] = marks
	Rules.install(engine, state, instance)
	return engine.finish_player_activation(state)

static func _raise_exceptions(expect: Callable) -> void:
	var engine := Combat.new()
	var mark := Vector2i(5, 4)
	for kind: String in ["wall", "trap", "brazier", "anchored", "burrowed", "multi_tile", "no_landing"]:
		var state: Dictionary = held(engine, Typed.vector2i([mark]))
		if kind == "wall": state["grid"][mark.y][mark.x] = "wall"
		elif kind == "trap": state["traps"] = [{"pos": mark}]
		elif kind == "brazier": state["guardian_braziers"] = [{"pos": mark}]
		else:
			state["enemies"][0]["pos"] = mark
			if kind == "anchored": state["enemies"][0]["anchored"] = true
			if kind == "burrowed": state["enemies"][0]["burrowed"] = true
			if kind == "multi_tile": state["enemies"][0]["footprint"] = Vector2i(2, 2)
			if kind == "no_landing":
				state["player"]["pos"] = Vector2i(7, 7)
				for axis: Vector2i in preload("res://scripts/path_utils.gd").DIRS_4:
					var tile: Vector2i = mark + axis
					state["grid"][tile.y][tile.x] = "wall"
		var before: Dictionary = state.duplicate(true)
		var steps: Array[Dictionary]
		var after: Dictionary = Rules.fire(engine, state, steps)
		var category: String = "impassable" if kind == "wall" else kind if kind in ["trap", "brazier"] else "occupied_raise"
		expect.call(steps[0]["upheaval_outcomes"] == [{"tile": mark, "category": category}] and after["terrain"].is_empty(), "Upheaval reports the allowed exception: " + kind)
		expect.call(after["enemies"] == before["enemies"], "A blocked raise commits no trial throw: " + kind)

static func _breakout(expect: Callable) -> void:
	var engine := Combat.new()
	var hero := Vector2i(5, 5)
	var marks: Array[Vector2i]
	for axis: Vector2i in preload("res://scripts/path_utils.gd").DIRS_4: marks.append(hero + axis)
	var state: Dictionary = held(engine, marks)
	var after: Dictionary = Rules.fire(engine, state)
	expect.call(after["terrain"].size() == 4, "Every open mark rises, even if it encloses the hero")
	after = engine.prepare_next_player_turn(after)
	var attack: Dictionary = {"type": "melee", "damage": 3, "range": 1}
	var exit: Vector2i = hero + Vector2i.LEFT
	expect.call(engine.valid_targets_for_player_action(after, attack).has(exit), "An enclosing Outcrop is targetable by a normal melee attack")
	after = engine.apply_player_action(after, attack, exit)
	expect.call(engine._terrain_index_at_tile(after, exit) < 0 and engine.player_movement_targets(after).has(exit), "Breaking an enclosing Outcrop opens a walkable exit")

static func _sealed_neighbour(expect: Callable) -> void:
	var engine := Combat.new()
	var hero := Vector2i(5, 5)
	var state: Dictionary = Base.battle(engine)
	state["objective"] = {"type": "reach_exit", "special_type": "umbral_snare", "exits": [{"target_tile": hero + Vector2i.LEFT, "sealed": true}]}
	expect.call(Rules.Upheaval.Rise.site_blocked(engine, state, hero + Vector2i.LEFT), "A sealed threshold is an impassable raise site")

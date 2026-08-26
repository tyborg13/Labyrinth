extends RefCounted

const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")

static func run(expect: Callable) -> void:
	_test_default_pool_and_split_spending(expect)
	_test_card_play_interleaving(expect)
	_test_turn_reset_and_relic_capacity(expect)
	_test_ghost_stride_translation(expect)

static func _test_default_pool_and_split_spending(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _state(combat)
	expect.call(combat.player_movement_capacity(state) == 2, "Player turns should start with a two-tile movement capacity")
	expect.call(combat.player_movement_remaining(state) == 2, "The complete movement pool should be available at turn start")
	var origin: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var invalid_state: Dictionary = combat.apply_player_movement(state, Vector2i(0, 0))
	expect.call(invalid_state == state, "An invalid movement click should not mutate combat state or spend movement")
	state = combat.apply_player_movement(state, origin + Vector2i(1, 0))
	expect.call(combat.player_movement_remaining(state) == 1, "Moving one traversed tile should spend exactly one movement")
	expect.call(int(state.get("cards_played_this_turn", -1)) == 0 and not state.has("pending_card_payment"), "Independent movement should not spend or reserve a card play")
	var after_one: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	state = combat.apply_player_movement(state, after_one + Vector2i(0, 1))
	expect.call(combat.player_movement_remaining(state) == 0, "The second one-tile move should exhaust the pool")
	expect.call(combat.player_movement_action(state).is_empty() and combat.player_movement_targets(state).is_empty(), "Exhausted movement should expose no further movement targets")

static func _test_card_play_interleaving(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _state(combat)
	var origin: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	state = combat.apply_player_movement(state, origin + Vector2i(1, 0))
	state = combat.finish_player_card(state, 0)
	expect.call(combat.player_movement_remaining(state) == 1, "Playing a card between moves should preserve unused movement")
	expect.call(combat.cards_remaining_this_turn(state) == 1, "Movement should not alter the card-play budget")
	var after_card: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	state = combat.apply_player_movement(state, after_card + Vector2i(0, 1))
	expect.call(combat.player_movement_remaining(state) == 0, "Movement should remain usable after a card play")

static func _test_turn_reset_and_relic_capacity(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _state(combat)
	var origin: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	state = combat.apply_player_movement(state, origin + Vector2i(2, 0))
	expect.call(int((state.get("last_player_movement", {}) as Dictionary).get("spent", 0)) == 2, "A two-tile destination should spend the two traversed path tiles")
	state = combat.prepare_next_player_turn(state)
	expect.call(combat.player_movement_remaining(state) == 2, "A new player activation should refill the movement pool")
	var boots_state: Dictionary = _state(combat, ["pilgrim_boots"])
	expect.call(combat.player_movement_capacity(boots_state) == 3 and combat.player_movement_remaining(boots_state) == 3, "Pilgrim Boots should translate to one extra movement each turn")

static func _test_ghost_stride_translation(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _state(combat, [], ["ghost_stride", "afterimage"])
	expect.call(combat.skill_is_ready(state, "ghost_stride"), "Ghost Stride should be ready while movement and a legal Blink target remain")
	state = combat.arm_ghost_stride(state)
	var action: Dictionary = combat.player_movement_action(state)
	expect.call(str(action.get("type", "")) == "blink" and int(action.get("range", 0)) == 2, "Armed Ghost Stride should translate the independent movement action into Blink 2")
	state = combat.apply_player_movement(state, Vector2i(4, 4))
	expect.call(combat.skill_was_used(state, "ghost_stride"), "Ghost Stride should spend only after its armed movement resolves")
	expect.call(combat.player_movement_remaining(state) == 0, "A two-tile Ghost Stride Blink should spend both movement points")
	expect.call(not bool((state.get("skill_flags", {}) as Dictionary).get("movement_blink_armed", false)), "Resolved Ghost Stride movement should clear its armed state")
	var illusions: Array = state.get("illusions", []) as Array
	expect.call(illusions.size() == 1 and (illusions[0] as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(2, 4), "Afterimage should continue to trigger from Ghost Stride's translated Blink")

static func _state(combat: CombatEngine, relics: Array = [], skills: Array = []) -> Dictionary:
	return combat.create_combat(611, _room(), {
		"hp": GameData.fixed_point_amount(30),
		"max_hp": GameData.fixed_point_amount(30),
		"deck_cards": ["quick_stab", "brace"],
		"skill_ids": skills,
		"relics": relics,
		"hand_size": 2,
		"heal_bonus": 0
	})

static func _room() -> Dictionary:
	var grid: Array = []
	for y: int in range(8):
		var row: Array[String]
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return {
		"name": "Movement Test Room",
		"coord": Vector2i(1, 0),
		"depth": 1,
		"type": "combat",
		"grid": grid,
		"player_start": Vector2i(2, 4),
		"enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(6, 2), "hp": 100, "max_hp": 100, "block": 0}],
		"loot": [],
		"traps": []
	}

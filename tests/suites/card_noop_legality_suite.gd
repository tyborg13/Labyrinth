extends RefCounted

## crd-15: production cards reuse the ordinary action/hand legality path.
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Scene = preload("res://scripts/run_scene.gd")
const PLAYER := Vector2i(3, 4)
const ENEMY := Vector2i(4, 4)
const OUTSIDE := Vector2i(8, 4)
const SEED: int = 15007
const FIXTURE_HP: int = 40
const FIXTURE_CARD_PLAYS: int = 8
const GRID_WIDTH: int = 11
const GRID_HEIGHT: int = 10
const NO_TARGET := Vector2i(-1, -1)

static func run(expect: Callable) -> void:
	var scene := Scene.new()
	var engine: Combat = scene.get("_combat_engine")
	_test_grounding(engine, scene, expect)
	_test_selectors(engine, scene, expect)
	_test_multi_action(engine, scene, expect)
	_test_refresh(engine, scene, expect)
	scene.free()

static func room() -> Dictionary:
	var grid: Array = []
	for y: int in range(GRID_HEIGHT):
		var row: Array = []
		for x: int in range(GRID_WIDTH):
			row.append("wall" if x == 0 or y == 0 or x == GRID_WIDTH - 1 or y == GRID_HEIGHT - 1 else "stone")
		grid.append(row)
	return {"name": "crd-15 proof", "type": "combat", "coord": Vector2i(1, 1), "depth": 1,
		"element": "none", "umbra_stage": "clear", "grid": grid, "player_start": PLAYER,
		"enemies": [{"id": 1, "type": "crawler", "pos": ENEMY, "hp": FIXTURE_HP, "max_hp": FIXTURE_HP, "block": 0, "stoneskin": 0}],
		"terrain": [], "traps": [], "loot": []}

static func fixture(engine: Combat, hand: Array, with_enemy: bool = true) -> Dictionary:
	var state: Dictionary = engine.create_combat(SEED, room(), {"hp": FIXTURE_HP, "max_hp": FIXTURE_HP,
		"deck_cards": hand.duplicate(), "hand_size": hand.size(), "relics": [], "cards_per_turn": FIXTURE_CARD_PLAYS})
	state["player"] = {"pos": PLAYER, "hp": FIXTURE_HP, "max_hp": FIXTURE_HP, "block": 0, "stoneskin": 0}
	if not with_enemy: state["enemies"] = []
	state["surfaces"] = {}
	state["terrain"] = []
	state["traps"] = []
	state["loot"] = []
	state["deck"]["hand"] = hand.duplicate()
	state["deck"]["draw"] = ["brace"]
	state["deck"]["discard"] = []
	state["deck"]["burned"] = []
	state["current_actor"] = {"kind": "player", "key": "player"}
	state["player_turn_restrictions"] = {}
	state["cards_played_this_turn"] = 0
	state["death_bonus_card_plays_this_turn"] = 0
	state["card_play_bonus_this_turn"] = 0
	state["player_turn_time_spent"] = 0
	return state

static func _action(engine: Combat, state: Dictionary, card_id: String, index: int = 0) -> Dictionary:
	return engine.card_play_actions(card_id, state)[index]

static func _preview(engine: Combat, scene: Node, state: Dictionary, card_id: String) -> Dictionary:
	var prepared: Dictionary = engine.prepare_player_card(state, 0)
	return scene.call("_card_preview_from_state", card_id, prepared, engine.card_play_actions(card_id, prepared), 0)

static func _check_legality(engine: Combat, scene: Node, state: Dictionary, card_id: String, expected: bool, expect: Callable, label: String) -> void:
	var before: Dictionary = state.duplicate(true)
	expect.call(engine.player_action_can_resolve(state, _action(engine, state, card_id)) == expected, label + " action gate")
	scene.set("_combat_state", state)
	scene.call("_mark_combat_preview_state_changed")
	var flags: Dictionary = scene.call("_card_playability_for_index", 0)
	expect.call(bool(flags.get("printed_playable", false)) == expected and bool(flags.get("any_playable", false)) == expected, label + " ordinary hand flags")
	var preview: Dictionary = _preview(engine, scene, state, card_id)
	expect.call(bool(preview.get("playable", false)) == expected, label + " full preview")
	expect.call(state == before, label + " queries preserve board, hand, Time and analytics")
	if not expected:
		expect.call(engine.apply_player_action(state, _action(engine, state, card_id), NO_TARGET) == state, label + " blocked action has no effect or payment")
		expect.call(preview["state"]["deck"]["hand"] == state["deck"]["hand"] and int(preview["state"].get("player_turn_time_spent", 0)) == 0, label + " blocked card preserves hand and Time")

static func _play(engine: Combat, scene: Node, state: Dictionary, card_id: String, expect: Callable) -> Dictionary:
	var preview: Dictionary = _preview(engine, scene, state, card_id)
	expect.call(bool(preview.get("playable", false)) and bool(preview.get("complete", false)), card_id + " qualifying card completes without a target")
	var working: Dictionary = engine.prepare_player_card(state, 0)
	var actions: Array = engine.card_play_actions(card_id, working)
	for action: Dictionary in actions:
		working = engine.apply_player_action(working, action, NO_TARGET)
	expect.call(working == preview["state"], card_id + " preview equals committed effects and events")
	var result: Dictionary = engine.finish_player_card(working, 0, engine.card_plays_spent_for_actions(actions))
	expect.call(int(result.get("player_turn_time_spent", 0)) == int(Data.card_def(card_id)["time"]), card_id + " spends unchanged printed Time exactly once")
	return result

static func _test_grounding(engine: Combat, scene: Node, expect: Callable) -> void:
	var tiles: Array = [PLAYER, PLAYER + Vector2i.RIGHT, PLAYER + Vector2i.UP, PLAYER + Vector2i.LEFT]
	for count: int in [0, 1, 4]:
		var state: Dictionary = fixture(engine, ["grounding"])
		Surface.place(state, OUTSIDE, "electrified")
		for index: int in range(count): Surface.place(state, tiles[index], "electrified")
		_check_legality(engine, scene, state, "grounding", count > 0, expect, "Grounding %d in pattern, one outside" % count)
		if count == 0: continue
		var after: Dictionary = _play(engine, scene, state, "grounding", expect)
		expect.call(int(after["player"].get("stoneskin", 0)) == mini(count * 3, 9), "Grounding grants 3 Stoneskin per tile, capped at 9 (crd-14)")
		for index: int in range(count): expect.call(not Surface.has_surface(after, tiles[index], "electrified"), "Grounding removes selected tile")
		expect.call(Surface.has_surface(after, OUTSIDE, "electrified"), "Grounding leaves out-of-pattern fuel")
	var wrong: Dictionary = fixture(engine, ["grounding"])
	Surface.place(wrong, PLAYER, "fire")
	_check_legality(engine, scene, wrong, "grounding", false, expect, "Grounding ignores another surface")
	var threshold: Dictionary = _action(engine, wrong, "grounding").duplicate(true)
	threshold["min_consumed"] = 2
	Surface.place(wrong, PLAYER, "electrified")
	expect.call(not engine.player_action_can_resolve(wrong, threshold), "min_consumed N needs N tiles")
	Surface.place(wrong, PLAYER + Vector2i.UP, "electrified")
	expect.call(engine.player_action_can_resolve(wrong, threshold), "min_consumed N accepts exactly N tiles")

static func _test_selectors(engine: Combat, scene: Node, expect: Callable) -> void:
	for card_id: String in ["white_silence", "searing_light", "stoke"]:
		var bare: Dictionary = fixture(engine, [card_id], false)
		_check_legality(engine, scene, bare, card_id, false, expect, card_id + " empty board")
		var state: Dictionary = fixture(engine, [card_id])
		_check_legality(engine, scene, state, card_id, false, expect, card_id + " nonmatching enemy")
		if card_id == "white_silence": state["enemies"][0]["chilled"] = true
		elif card_id == "searing_light": state = engine._create_umbra_light_source(state, ENEMY, {"radius": 0, "duration": 2})
		else:
			Surface.place(state, ENEMY + Vector2i.RIGHT, "fire")
			_check_legality(engine, scene, state, card_id, false, expect, "Stoke beside Fire")
			Surface.place(state, ENEMY, "fire")
		_check_legality(engine, scene, state, card_id, true, expect, card_id + " matching visible enemy")
		var after: Dictionary = _play(engine, scene, state, card_id, expect)
		# Release White Silence is 4 Ice plus the existing +2 against Chilled.
		var damage: int = {"white_silence": 6, "searing_light": 5, "stoke": 5}[card_id]  # crd-14: Stoke deals 5
		expect.call(int(after["enemies"][0]["hp"]) == FIXTURE_HP - damage, card_id + " unchanged release damage")
		if card_id == "white_silence": expect.call(int(after["enemies"][0].get("freeze", 0)) > 0, "White Silence still Freezes Chilled enemies")
		if card_id == "stoke": expect.call(Surface.has_surface(after, ENEMY, "fire"), "Stoke leaves Fire unchanged")
		var hidden: Dictionary = state.duplicate(true)
		hidden["umbra"]["stage"] = "heart"
		hidden["umbra"]["light_sources"] = []
		hidden["enemies"][0]["pos"] = OUTSIDE
		if card_id == "stoke": Surface.place(hidden, OUTSIDE, "fire")
		expect.call(not engine.is_enemy_visible_to_player(hidden, hidden["enemies"][0]), card_id + " hidden fixture is actually concealed")
		_check_legality(engine, scene, hidden, card_id, false, expect, card_id + " hidden in Umbra")
		if card_id == "searing_light":
			# A visible enemy outside Light also fails (visibility alone is insufficient).
			hidden["umbra"]["stage"] = "clear"
			_check_legality(engine, scene, hidden, card_id, false, expect, "Searing Light visible enemy outside Light")
	var ranged: Dictionary = fixture(engine, ["revealing_glare"])
	ranged = engine._create_umbra_light_source(ranged, ENEMY, {"radius": 0, "duration": 2})
	var glare: Dictionary = _action(engine, ranged, "revealing_glare")
	expect.call(engine.player_action_can_resolve(ranged, glare), "Selector accepts lit enemy within printed range")
	ranged["enemies"][0]["pos"] = OUTSIDE
	ranged = engine._create_umbra_light_source(ranged, OUTSIDE, {"radius": 0, "duration": 2})
	expect.call(not engine.player_action_can_resolve(ranged, glare), "Selector rejects lit enemy beyond printed range")

static func _test_multi_action(engine: Combat, scene: Node, expect: Callable) -> void:
	_test_spike_mantle(engine, scene, expect)
	for card_id: String in ["revealing_glare"]:
		var state: Dictionary = fixture(engine, [card_id], false)
		var failed_index: int = 0
		expect.call(not engine.player_action_can_resolve(state, _action(engine, state, card_id, failed_index)), card_id + " empty step cannot resolve")
		scene.set("_combat_state", state)
		scene.call("_mark_combat_preview_state_changed")
		var playable: bool = bool((scene.call("_card_playability_for_index", 0) as Dictionary).get("any_playable", false))
		expect.call(playable, card_id + " remains playable on empty board")
		if not playable:
			continue
		var after: Dictionary = _play(engine, scene, state, card_id, expect)
		expect.call(int(after["player"].get("stoneskin", 0)) == 0, card_id + " empty step grants no Stoneskin")
		if card_id == "revealing_glare":
			# With no enemies combat is already won, so the existing draw resolver
			# stops. Prove Draw 1 on an active board with no qualifying lit enemy.
			var active: Dictionary = _play(engine, scene, fixture(engine, [card_id]), card_id, expect)
			expect.call((active["deck"]["hand"] as Array).has("brace"), "Revealing Glare still draws 1 without a matching enemy")

static func _test_spike_mantle(engine: Combat, scene: Node, expect: Callable) -> void:
	# Director feedback 1: either the strike or the Expend must do something.
	for case_name: String in ["empty", "rubble_only", "enemy_only"]:
		var state: Dictionary = fixture(engine, ["spike_mantle"], case_name == "enemy_only")
		if case_name == "rubble_only": Surface.place(state, ENEMY, "rubble")
		if case_name == "enemy_only":
			# A full Block pool proves the printed Pierce bypasses defense.
			state["enemies"][0]["block"] = FIXTURE_HP
		var before: Dictionary = state.duplicate(true)
		scene.set("_combat_state", state)
		scene.call("_mark_combat_preview_state_changed")
		var flags: Dictionary = scene.call("_card_playability_for_index", 0)
		var preview: Dictionary = _preview(engine, scene, state, "spike_mantle")
		var expected_playable: bool = case_name != "empty"
		var label: String = "Spike Mantle " + case_name
		expect.call(bool(flags.get("printed_playable", false)) == expected_playable and bool(flags.get("any_playable", false)) == expected_playable, label + " ordinary hand flags")
		expect.call(bool(preview.get("playable", false)) == expected_playable and bool(preview.get("complete", false)), label + " full preview")
		expect.call(state == before, label + " queries preserve committed state")
		var actions: Array = engine.card_play_actions("spike_mantle", state)
		expect.call(engine.player_action_can_resolve(state, actions[1]) == (case_name == "rubble_only"), label + " consumer requires Rubble")
		if not expected_playable:
			expect.call(int(preview["state"].get("player_turn_time_spent", 0)) == 0 and preview["state"]["deck"]["hand"] == state["deck"]["hand"], label + " spends no Time and keeps the card")
			expect.call(int(preview["state"]["player"].get("stoneskin", 0)) == 0, label + " grants no Stoneskin")
			continue
		if not bool(preview.get("playable", false)):
			# Do not manufacture a play if either newly approved case is illegal.
			return
		# Live confirmation commits the resolved preview and then pays once.
		var after: Dictionary = engine.finish_player_card(preview["state"], 0, engine.card_plays_spent_for_actions(actions))
		expect.call(int(after.get("player_turn_time_spent", 0)) == int(Data.card_def("spike_mantle")["time"]), label + " spends unchanged printed Time exactly once")
		expect.call(not (after["deck"]["hand"] as Array).has("spike_mantle"), label + " spends the played card")
		if case_name == "rubble_only":
			expect.call(not Surface.has_surface(after, ENEMY, "rubble"), label + " expends its one adjacent Rubble")
			expect.call(int(after["player"].get("stoneskin", 0)) == 4, label + " grants exactly 4 Stoneskin")
		else:
			expect.call(int(after["enemies"][0]["hp"]) == FIXTURE_HP - 8 and int(after["enemies"][0].get("block", 0)) == FIXTURE_HP, label + " deals exactly 8 through Block with Pierce")
			expect.call(int(after["player"].get("stoneskin", 0)) == 0, label + " grants no Stoneskin without Rubble")

static func _test_refresh(engine: Combat, scene: Node, expect: Callable) -> void:
	var state: Dictionary = fixture(engine, ["grounding", "spark_focus"])
	scene.set("_combat_state", state)
	scene.call("_mark_combat_preview_state_changed")
	expect.call(not bool((scene.call("_card_playability_for_index", 0) as Dictionary).get("any_playable", false)), "Grounding initially unavailable in warm hand cache")
	# Use Spark Focus's production painter mid-turn; preserve the Grounding slot.
	var spark: Dictionary = _action(engine, state, "spark_focus").duplicate(true)
	spark["orientation"] = Vector2i.RIGHT
	state = engine.apply_player_action(state, spark, PLAYER + Vector2i.UP)
	expect.call(Surface.has_surface(state, PLAYER + Vector2i.UP, "electrified"), "Spark Focus actually paints qualifying fuel")
	scene.set("_combat_state", state)
	scene.call("_mark_combat_preview_state_changed")
	expect.call(bool((scene.call("_card_playability_for_index", 0) as Dictionary).get("any_playable", false)), "Grounding refreshes through ordinary board revision invalidation")
	state = engine.apply_player_action(state, _action(engine, state, "grounding"), NO_TARGET)
	scene.set("_combat_state", state)
	scene.call("_mark_combat_preview_state_changed")
	expect.call(not bool((scene.call("_card_playability_for_index", 0) as Dictionary).get("any_playable", false)), "Grounding becomes unavailable after its in-pattern fuel is expended")

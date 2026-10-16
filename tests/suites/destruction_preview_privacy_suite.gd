extends RefCounted

const Run = preload("res://scripts/run_scene.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Base = preload("res://tests/suites/board_surface_suite.gd")

# Review reproductions use production cards/relics with proof-only fixture data.
const ENEMY_START := Vector2i(3, 3)
const HIDDEN_TRAP_TILE := Vector2i(5, 3)
const GALE_DESTINATION := Vector2i(6, 3)
const WALL_DESTINATION := Vector2i(8, 3)
const ILLUSION_START := Vector2i(4, 3)
const CONCEALED_ILLUSION_TILE := Vector2i(8, 6)
const ENEMY_HP: int = 100
const HIDDEN_TRAP_DAMAGE: int = 1000
const ILLUSION_HP: int = 2
const WAIT_ACTION: Dictionary = {"type": "move", "range": 1}
const SKIPPED_ACTION: Dictionary = {"type": "ranged", "damage": 1, "range": 1, "optional": true}
const INVALID_TARGET := Vector2i(-1000, -1000)

static func run(expect: Callable) -> void:
	_test_hidden_cause_retention(expect)
	_test_illusion_destination_sight(expect)
	_test_concealed_illusion_losses(expect)

static func _test_hidden_cause_retention(expect: Callable) -> void:
	for mode: String in ["confirmation", "automatic_prefix", "selected_prefix", "skipped_prefix"]:
		var displayed: Array = []
		var forecasts: Array = []
		var loss_maps: Array = []
		for hidden_trap: bool in [false, true]:
			var scene := Run.new()
			var engine := Combat.new()
			var before: Dictionary = _fixture()
			if hidden_trap:
				before["traps"] = [{"id": "concealed_lethal", "pos": HIDDEN_TRAP_TILE, "element": "fire", "damage": HIDDEN_TRAP_DAMAGE}]
			expect.call(not engine.is_tile_visible_to_player(before, HIDDEN_TRAP_TILE), mode + " fixture conceals the lethal trap")
			var targeted: bool = mode in ["selected_prefix", "skipped_prefix"]
			var card_id: String = "skybreak_current" if targeted else "unsealed_gale"
			before["deck"]["hand"] = [card_id]
			var actions: Array = engine.card_play_actions(card_id, before)
			var selected: Array[Vector2i]
			var actual: Dictionary = engine.prepare_player_card(before, 0)
			if mode == "skipped_prefix":
				actions.push_front(SKIPPED_ACTION)
				selected.append(INVALID_TARGET)
			if targeted:
				actual = engine.apply_player_action(actual, actions[-1], ENEMY_START)
				selected.append(ENEMY_START)
			else:
				actual = engine.apply_player_action(actual, actions[0])
			var resolved_count: int = actions.size()
			if mode != "confirmation": actions.append(WAIT_ACTION)
			_install(scene, before, actual, actions, resolved_count, selected)
			var committed_snapshot: Dictionary = before.duplicate(true)
			var actual_snapshot: Dictionary = actual.duplicate(true)
			var known: Dictionary = scene.call("_pending_card_known_forecast_state")
			var shown: Dictionary = scene.call("_board_display_state")
			var expected: Vector2i = WALL_DESTINATION if targeted else GALE_DESTINATION
			expect.call(known["enemies"][0]["pos"] == expected and int(known["enemies"][0]["hp"]) > 0, mode + " replays the resolved prefix without hidden causes")
			expect.call(shown["enemies"][0]["pos"] == known["enemies"][0]["pos"], mode + " retention uses the information-safe destination")
			if hidden_trap:
				expect.call(int(actual["enemies"][0]["hp"]) == 0, mode + " actual forecast must die on the concealed trap")
			forecasts.append(known["enemies"][0])
			displayed.append(shown["enemies"][0])
			loss_maps.append(scene.call("_sanitize_damage_preview_for_umbra_information", before, scene.call("_damage_preview_between_states", before, known)))
			expect.call(before == committed_snapshot and actual == actual_snapshot, mode + " forecast/display leave committed and actual states unchanged")
			expect.call(is_same(shown, scene.call("_board_display_state")) and is_same(known, scene.call("_pending_card_known_forecast_state")), mode + " reuses unchanged display and known-forecast caches")
			if mode != "confirmation":
				expect.call((known["deck"]["hand"] as Array).has(card_id), mode + " does not pay for or finish an unresolved card")
			scene.free()
		expect.call(forecasts[0] == forecasts[1] and loss_maps[0] == loss_maps[1], mode + " known actor/loss forecast is independent of concealed traps")
		expect.call(displayed[0] == displayed[1], mode + " retained actor is independent of concealed traps")

static func _test_illusion_destination_sight(expect: Callable) -> void:
	for limited: bool in [false, true]:
		var scene := Run.new()
		var engine := Combat.new()
		var before: Dictionary = _fixture()
		before["umbra"]["stage"] = "heart" if limited else "clear"
		before["enemies"][0]["pos"] = Vector2i(1, 1)
		before["illusions"] = [{"id": 1, "pos": ILLUSION_START, "hp": ILLUSION_HP, "max_hp": ILLUSION_HP}]
		before["relics"] = ["hollow_puppet"]
		before["deck"]["hand"] = ["skybreak_current"]
		var actions: Array = engine.card_play_actions("skybreak_current", before)
		scene.set("_combat_state", before)
		var preview: Dictionary = scene.call("_card_preview_from_state", "skybreak_current", before, actions, 0)
		_install(scene, before, preview["state"], actions, int(preview["action_index"]))
		scene.set("_pending_target_tiles", scene.call("_vector2i_array", preview["target_tiles"]))
		scene.set("_hovered_board_tile", ILLUSION_START)
		var actual: Dictionary = engine.apply_player_action(before, actions[0], ILLUSION_START)
		expect.call(actual["illusions"][0]["pos"] == WALL_DESTINATION and int(actual["illusions"][0]["hp"]) == 0, "Hollow Puppet regression reaches a lethal wall collision")
		expect.call(engine.is_tile_visible_to_player(before, WALL_DESTINATION) != limited, "Illusion landing visibility matches committed sight")
		var result: Dictionary = {}
		scene.call("_append_surface_action_preview", result, preview)
		result.merge(scene.call("_stage_visibility_presentation", before), true)
		var board := Board.new()
		board.set("combat_state", before)
		board.set("presentation", result)
		var marked_positions: Array = []
		for unit: Dictionary in board.call("_build_visible_units"):
			if bool(board.call("_unit_is_preview_lethal", unit)): marked_positions.append(unit["pos"])
		expect.call(marked_positions.has(ILLUSION_START), "Lethal illusion keeps its visible original death mark")
		expect.call(marked_positions.has(WALL_DESTINATION) != limited, "Lethal illusion destination ghost respects committed sight")
		board.free()
		scene.free()

static func _test_concealed_illusion_losses(expect: Callable) -> void:
	var scene := Run.new()
	var engine := Combat.new()
	var before: Dictionary = _fixture()
	before["illusions"] = [{"id": 1, "pos": ILLUSION_START, "hp": ILLUSION_HP, "max_hp": ILLUSION_HP}, {"id": 2, "pos": CONCEALED_ILLUSION_TILE, "hp": ILLUSION_HP, "max_hp": ILLUSION_HP}]
	scene.set("_combat_state", before)
	expect.call(engine.is_tile_visible_to_player(before, ILLUSION_START) and not engine.is_tile_visible_to_player(before, CONCEALED_ILLUSION_TILE), "Illusion-loss regression has visible and concealed illusions")
	var after: Dictionary = before.duplicate(true)
	for illusion: Dictionary in after["illusions"]: illusion["hp"] = 0
	var raw: Dictionary = scene.call("_damage_preview_between_states", before, after)
	expect.call(raw.has("illusion_2"), "Concealed illusion loss exists before privacy filtering")
	var safe: Dictionary = scene.call("_sanitize_damage_preview_for_umbra_information", before, raw)
	expect.call(safe.has("illusion_1") and not safe.has("illusion_2"), "Limited Umbra retains visible illusion losses and omits concealed illusion damage keys")
	scene.free()

static func _fixture() -> Dictionary:
	var state: Dictionary = Base.fixture(Combat.new())
	state["terrain"] = []
	state["traps"] = []
	state["illusions"] = []
	state["umbra"]["stage"] = "heart"
	state["enemies"][0]["pos"] = ENEMY_START
	state["enemies"][0]["hp"] = ENEMY_HP
	state["enemies"][0]["max_hp"] = ENEMY_HP
	return state

static func _install(scene: Node, before: Dictionary, actual: Dictionary, actions: Array, action_index: int, selected: Array = []) -> void:
	scene.set("_combat_state", before)
	scene.set("_run_state", {"mode": "combat"})
	scene.set("_selected_card_index", 0)
	scene.set("_preview_combat_state", actual)
	scene.set("_pending_actions", actions)
	scene.set("_pending_action_index", action_index)
	scene.set("_pending_selected_targets", scene.call("_vector2i_array", selected))

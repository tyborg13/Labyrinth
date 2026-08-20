extends RefCounted

const ActionIcons = preload("res://scripts/action_icon_library.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")

const RADIANCE_CARD_IDS: Array[String] = [
	"lantern_shot", "guiding_flare", "dawnstep", "prism_sight", "storm_beacon",
	"glowstone_ward", "daybreak", "trapdoor", "ember_rain", "firebrand_volley",
	"icebound_chains", "spark_dart", "spark_focus", "threaded_path", "root_snare"
]
const ATTACK_LIGHT_RIDER_CARD_IDS: Array[String] = [
	"lantern_shot", "guiding_flare", "storm_beacon", "ember_rain",
	"firebrand_volley", "spark_dart", "root_snare"
]

static func run(expect: Callable) -> void:
	_test_radiance_pool_and_duration_contract(expect)
	_test_attack_light_riders(expect)
	_test_movement_light_rider_uses_resolved_destination(expect)

static func _test_radiance_pool_and_duration_contract(expect: Callable) -> void:
	var tagged_ids: Array[String]
	for card_id: String in GameData.cards():
		if bool(GameData.card_def(card_id).get("radiance", false)):
			tagged_ids.append(card_id)
	tagged_ids.sort()
	var expected_ids: Array[String] = RADIANCE_CARD_IDS.duplicate()
	expected_ids.sort()
	expect.call(tagged_ids == expected_ids, "The card pool should expose exactly the approved 15 Radiance-tagged cards")
	var reward_radiance_count: int = 0
	for rarity_cards_var: Variant in GameData.reward_card_pool_by_rarity("", true).values():
		for card_id_var: Variant in rarity_cards_var as Array:
			if bool(GameData.card_def(str(card_id_var)).get("radiance", false)):
				reward_radiance_count += 1
	expect.call(reward_radiance_count == 14, "The ordinary reward pool should contain 14 Radiance cards after the rider pass")
	for card_id: String in ["dawnstep", "prism_sight", "trapdoor", "icebound_chains", "spark_focus"]:
		var found_duration: bool = false
		for action_var: Variant in GameData.card_def(card_id).get("actions", []):
			if typeof(action_var) != TYPE_DICTIONARY:
				continue
			var action: Dictionary = action_var as Dictionary
			if str(action.get("type", "")) in ["vision", "truesight"]:
				found_duration = int(action.get("duration", 0)) == 2
		expect.call(found_duration, "%s should use the approved two-turn Vision or Truesight duration" % card_id)

static func _test_attack_light_riders(expect: Callable) -> void:
	var combat := CombatEngine.new()
	for card_id: String in ATTACK_LIGHT_RIDER_CARD_IDS:
		var card: Dictionary = GameData.card_def(card_id)
		var actions: Array = card.get("actions", []) as Array
		var rider_actions: Array[Dictionary] = []
		for action_var: Variant in actions:
			var action: Dictionary = action_var as Dictionary
			expect.call(str(action.get("type", "")) != "illuminate" and not bool(action.get("reuse_previous_target", false)), "%s should not retain a separate Light target action" % card_id)
			if int(action.get("illuminate_radius", 0)) > 0:
				rider_actions.append(action)
		expect.call(rider_actions.size() == 1 and str(rider_actions[0].get("type", "")) in ["melee", "ranged", "aoe", "push", "pull"], "%s should author Light as one attack rider" % card_id)
		var rows: Array = ActionIcons.rows_for_actions(actions)
		var rider_row_found: bool = false
		for row_var: Variant in rows:
			var row_icons: Array[String]
			for token_var: Variant in row_var as Array:
				row_icons.append(str((token_var as Dictionary).get("icon", "")))
			if row_icons.has("illuminate") and (row_icons.has("ranged") or row_icons.has("aoe")):
				rider_row_found = row_icons.find("illuminate") > row_icons.find("ranged")
		expect.call(rider_row_found, "%s should present attack information before its Light rider on one rules line" % card_id)

		var state: Dictionary = combat.create_combat(8200 + actions.size(), _room(), {
			"hp": 24, "max_hp": 24, "deck_cards": [card_id], "relics": [], "hand_size": 1
		})
		var target: Vector2i = Vector2i(4, 4)
		var hp_before: int = int(((state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0))
		for action_var: Variant in actions:
			var action: Dictionary = action_var as Dictionary
			var action_type: String = str(action.get("type", ""))
			if action_type in ["ranged", "aoe"]:
				state = combat.apply_player_action(state, action, target)
			else:
				state = combat.apply_player_action(state, action)
		var sources: Array = (state.get("umbra", {}) as Dictionary).get("light_sources", []) as Array
		expect.call(not sources.is_empty() and (sources[0] as Dictionary).get("pos", Vector2i.ZERO) == target and int((sources[0] as Dictionary).get("remaining_activations", 0)) == 2, "%s should create two-turn Light after resolving on its selected attack tile" % card_id)
		expect.call(int(((state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) < hp_before, "%s should still resolve its attack before creating impact Light" % card_id)

	var rider: Dictionary = (GameData.card_def("lantern_shot").get("actions", []) as Array)[0]
	var target_state: Dictionary = combat.create_combat(8291, _room(), {"hp": 24, "max_hp": 24, "deck_cards": ["lantern_shot"], "relics": [], "hand_size": 1})
	target_state["traps"] = [{"id": "test_trap", "pos": Vector2i(3, 3), "element": "fire", "damage": 1}]
	target_state["terrain"] = [{"id": "test_crate", "kind": "wooden_crate", "pos": Vector2i(5, 4), "hp": 20, "max_hp": 20}]
	var valid_targets: Array[Vector2i] = combat.valid_targets_for_player_action(target_state, rider)
	expect.call(valid_targets.has(Vector2i(4, 4)) and valid_targets.has(Vector2i(3, 3)) and valid_targets.has(Vector2i(5, 4)), "Attack Light riders should retain enemy, trap, and terrain targets")
	expect.call(not valid_targets.has(Vector2i(3, 4)), "Attack Light riders should reject empty floor tiles")
	for target: Vector2i in [Vector2i(3, 3), Vector2i(5, 4)]:
		var resolved_target_state: Dictionary = combat.apply_player_action(target_state, rider, target)
		var target_sources: Array = (resolved_target_state.get("umbra", {}) as Dictionary).get("light_sources", []) as Array
		expect.call(not target_sources.is_empty() and (target_sources[0] as Dictionary).get("pos", Vector2i.ZERO) == target, "A rider attack should leave Light at its trap or terrain impact")

	var kill_state: Dictionary = combat.create_combat(8292, _room(), {"hp": 24, "max_hp": 24, "deck_cards": ["lantern_shot"], "relics": [], "hand_size": 1})
	var kill_enemies: Array = kill_state.get("enemies", []) as Array
	var kill_enemy: Dictionary = (kill_enemies[0] as Dictionary).duplicate(true)
	kill_enemy["hp"] = 1
	kill_enemies[0] = kill_enemy
	kill_state["enemies"] = kill_enemies
	var kill_result: Dictionary = combat.apply_player_action(kill_state, rider, Vector2i(4, 4))
	var kill_sources: Array = (kill_result.get("umbra", {}) as Dictionary).get("light_sources", []) as Array
	expect.call(int(((kill_result.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) <= 0 and not kill_sources.is_empty() and (kill_sources[0] as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(4, 4), "A killing attack should leave its Light at the snapshotted impact tile")

	var push_state: Dictionary = combat.create_combat(8293, _room(), {"hp": 24, "max_hp": 24, "deck_cards": ["lantern_shot"], "relics": [], "hand_size": 1})
	var push_rider := {"type": "push", "damage": 1, "range": 5, "amount": 1, "illuminate_radius": 1, "illuminate_duration": 2}
	var push_result: Dictionary = combat.apply_player_action(push_state, push_rider, Vector2i(4, 4))
	var push_sources: Array = (push_result.get("umbra", {}) as Dictionary).get("light_sources", []) as Array
	expect.call(((push_result.get("enemies", []) as Array)[0] as Dictionary).get("pos", Vector2i.ZERO) != Vector2i(4, 4) and not push_sources.is_empty() and (push_sources[0] as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(4, 4), "A force attack should light its original impact after moving the target")

	var brightglass_state: Dictionary = combat.create_combat(8294, _room(), {"hp": 24, "max_hp": 24, "deck_cards": ["lantern_shot"], "relics": ["ember_lens"], "hand_size": 1})
	brightglass_state["enemies"] = [
		{"id": 1, "type": "crawler", "pos": Vector2i(4, 4), "hp": 20, "max_hp": 20, "block": 0},
		{"id": 2, "type": "crawler", "pos": Vector2i(5, 4), "hp": 20, "max_hp": 20, "block": 0}
	]
	var brightglass_result: Dictionary = combat.apply_player_action(brightglass_state, rider, Vector2i(4, 4))
	expect.call(int(((brightglass_result.get("enemies", []) as Array)[1] as Dictionary).get("hp", 0)) == 20, "Post-hit Light should not self-prime Brightglass Lens on the same attack")

	var squall_action: Dictionary = (GameData.card_def("squall_shot").get("actions", []) as Array)[0]
	expect.call(not bool(GameData.card_def("squall_shot").get("radiance", false)) and not squall_action.has("illuminate_radius"), "Squall Shot should retain its AOE-and-push identity without an added Light rider")
	var synthetic_aoe_rider: Dictionary = squall_action.duplicate(true)
	synthetic_aoe_rider["illuminate_radius"] = 1
	synthetic_aoe_rider["illuminate_duration"] = 2
	var squall_state: Dictionary = combat.create_combat(8295, _room(), {"hp": 24, "max_hp": 24, "deck_cards": ["squall_shot"], "relics": [], "hand_size": 1})
	var squall_targets: Array[Vector2i] = combat.valid_targets_for_player_action(squall_state, synthetic_aoe_rider)
	expect.call(squall_targets.has(Vector2i(4, 4)) and not squall_targets.has(Vector2i(4, 3)), "A Light-rider AOE should require an attackable selected center rather than an empty center that only overlaps a target")

static func _test_movement_light_rider_uses_resolved_destination(expect: Callable) -> void:
	var card: Dictionary = GameData.card_def("threaded_path")
	var actions: Array = card.get("actions", []) as Array
	var move_action: Dictionary = actions[0] as Dictionary
	expect.call(bool(card.get("radiance", false)), "Threaded Path should carry the Radiance school tag")
	expect.call(actions.size() == 2 and str(move_action.get("type", "")) == "move" and int(move_action.get("illuminate_radius", 0)) == 1 and int(move_action.get("illuminate_duration", 0)) == 2, "Threaded Path should author destination Light on its movement action without a separate target action")
	var move_icons: Array[String]
	for token_var: Variant in ActionIcons.tokens_for_action(move_action):
		move_icons.append(str((token_var as Dictionary).get("icon", "")))
	expect.call(move_icons == ["move", "illuminate", "time"], "Threaded Path should present Move and its destination Light as one action row")

	var combat := CombatEngine.new()
	var hidden_room: Dictionary = _room()
	hidden_room["umbra_stage"] = "eclipse"
	(hidden_room.get("enemies", []) as Array)[0]["pos"] = Vector2i(4, 4)
	var state: Dictionary = combat.create_combat(8296, hidden_room, {"hp": 24, "max_hp": 24, "deck_cards": ["threaded_path"], "relics": [], "hand_size": 1})
	var selected_destination := Vector2i(5, 4)
	expect.call(combat.valid_targets_for_player_action(state, move_action).has(selected_destination), "Threaded Path should optimistically allow movement through hidden occupancy")
	var moved: Dictionary = combat.apply_player_action(state, move_action, selected_destination)
	var resolved_destination: Vector2i = (moved.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var sources: Array = (moved.get("umbra", {}) as Dictionary).get("light_sources", []) as Array
	expect.call(resolved_destination == Vector2i(3, 4), "Threaded Path should stop before a hidden collision")
	expect.call(not sources.is_empty() and (sources[0] as Dictionary).get("pos", Vector2i.ZERO) == resolved_destination and int((sources[0] as Dictionary).get("remaining_activations", 0)) == 2, "Threaded Path should create two-turn Light where movement actually ends")
	expect.call((sources[0] as Dictionary).get("pos", Vector2i.ZERO) != selected_destination, "Threaded Path should never leak Light onto an unreachable selected endpoint")

	var trap_room: Dictionary = _room()
	(trap_room.get("enemies", []) as Array)[0]["pos"] = Vector2i(6, 2)
	var trap_grid: Array = trap_room.get("grid", []) as Array
	for wall_y: int in [3, 5]:
		for wall_x: int in range(1, 7):
			(trap_grid[wall_y] as Array)[wall_x] = "wall"
	trap_room["grid"] = trap_grid
	trap_room["traps"] = [{"id": "lethal_path_trap", "pos": Vector2i(3, 4), "element": "fire", "damage": 99, "base_damage": 99, "blast_radius": 0}]
	var trap_state: Dictionary = combat.create_combat(8297, trap_room, {"hp": 4, "max_hp": 4, "deck_cards": ["threaded_path"], "relics": [], "hand_size": 1})
	var trap_result: Dictionary = combat.apply_player_action(trap_state, move_action, Vector2i(5, 4))
	var trap_endpoint: Vector2i = (trap_result.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var trap_sources: Array = (trap_result.get("umbra", {}) as Dictionary).get("light_sources", []) as Array
	expect.call(int((trap_result.get("player", {}) as Dictionary).get("hp", 1)) <= 0 and trap_endpoint == Vector2i(3, 4), "A lethal intermediate trap should stop Threaded Path on the trap tile")
	expect.call(not trap_sources.is_empty() and (trap_sources[0] as Dictionary).get("pos", Vector2i.ZERO) == trap_endpoint, "Threaded Path should place destination Light at the lethal trap endpoint rather than beyond the player")

static func _room() -> Dictionary:
	var grid: Array = []
	for y: int in range(8):
		var row: Array[String]
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return {
		"name": "Radiance Card Test Room", "type": "combat", "depth": 1,
		"grid": grid, "player_start": Vector2i(2, 4),
		"enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(4, 4), "hp": 100, "max_hp": 100, "block": 0}],
		"loot": [], "traps": []
	}

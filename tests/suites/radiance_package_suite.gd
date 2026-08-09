extends RefCounted

const ActionIcons = preload("res://scripts/action_icon_library.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")

const RADIANCE_CARD_IDS: Array[String] = [
	"lantern_shot", "guiding_flare", "dawnstep", "prism_sight", "storm_beacon",
	"glowstone_ward", "daybreak", "trapdoor", "ember_rain", "firebrand_volley",
	"icebound_chains", "spark_dart", "spark_focus", "squall_shot", "root_snare"
]
const SHARED_TARGET_CARD_IDS: Array[String] = [
	"ember_rain", "firebrand_volley", "spark_dart", "squall_shot", "root_snare"
]

static func run(expect: Callable) -> void:
	_test_radiance_pool_and_duration_contract(expect)
	_test_shared_target_riders(expect)

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

static func _test_shared_target_riders(expect: Callable) -> void:
	var combat := CombatEngine.new()
	for card_id: String in SHARED_TARGET_CARD_IDS:
		var card: Dictionary = GameData.card_def(card_id)
		var actions: Array = card.get("actions", []) as Array
		var illuminate_index: int = -1
		var followup_index: int = -1
		for index: int in range(actions.size()):
			var action: Dictionary = actions[index] as Dictionary
			if str(action.get("type", "")) == "illuminate":
				illuminate_index = index
			elif bool(action.get("reuse_previous_target", false)):
				followup_index = index
		expect.call(illuminate_index >= 0 and followup_index == illuminate_index + 1, "%s should place Light and immediately reuse that one selected tile for its attack" % card_id)
		var rows: Array = ActionIcons.rows_for_actions(actions)
		var shared_row_found: bool = false
		for row_var: Variant in rows:
			var row_icons: Array[String]
			for token_var: Variant in row_var as Array:
				row_icons.append(str((token_var as Dictionary).get("icon", "")))
			if row_icons.has("illuminate") and (row_icons.has("ranged") or row_icons.has("aoe")):
				shared_row_found = true
		expect.call(shared_row_found, "%s should present its Light rider and attack as one shared-target rules line" % card_id)

		var state: Dictionary = combat.create_combat(8200 + illuminate_index, _room(), {
			"hp": 24, "max_hp": 24, "deck_cards": [card_id], "relics": [], "hand_size": 1
		})
		var target: Vector2i = Vector2i(4, 4)
		var hp_before: int = int(((state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0))
		for action_var: Variant in actions:
			var action: Dictionary = action_var as Dictionary
			var action_type: String = str(action.get("type", ""))
			if action_type in ["illuminate", "ranged", "aoe"]:
				state = combat.apply_player_action(state, action, target)
			else:
				state = combat.apply_player_action(state, action)
		var sources: Array = (state.get("umbra", {}) as Dictionary).get("light_sources", []) as Array
		expect.call(not sources.is_empty() and (sources[0] as Dictionary).get("pos", Vector2i.ZERO) == target and int((sources[0] as Dictionary).get("remaining_activations", 0)) == 2, "%s should create two-turn Light on the selected attack tile" % card_id)
		expect.call(int(((state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) < hp_before, "%s should still resolve its attack on the illuminated tile" % card_id)

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

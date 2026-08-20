extends RefCounted

const CombatEngine = preload("res://scripts/combat_engine.gd")
const CombatTerrainRules = preload("res://scripts/combat_terrain_rules.gd")
const ElementData = preload("res://scripts/element_data.gd")
const GameData = preload("res://scripts/game_data.gd")

const RETIRED_ACTION_KEYS := ["requires_intensity", "intensity_bonus", "intensity_cost", "freeze", "shock", "poison"]
const ATTACK_TYPES := ["melee", "ranged", "aoe", "push", "pull"]

static func run(expect: Callable) -> void:
	_test_element_packages_are_board_native(expect)
	_test_new_combats_have_no_intensity_currency(expect)
	_test_light_radiates_and_replaces_corruption(expect)
	_test_enemy_roster_uses_committed_geometry_and_support_mix(expect)
	_test_corruption_preview_and_resolution_share_one_footprint(expect)

static func _test_element_packages_are_board_native(expect: Callable) -> void:
	var surface_kinds_by_element: Dictionary = {}
	var attack_count_by_element: Dictionary = {}
	var combust_attacks: int = 0
	var chain_actions: int = 0
	var air_force_actions: int = 0
	for element_id: String in ElementData.all_elements():
		surface_kinds_by_element[element_id] = []
		attack_count_by_element[element_id] = 0
	for card_id_var: Variant in GameData.cards().keys():
		var card_id: String = str(card_id_var)
		var card: Dictionary = GameData.card_def(card_id)
		var element_id: String = str(card.get("element", ElementData.NONE))
		for action_var: Variant in card.get("actions", []):
			if typeof(action_var) != TYPE_DICTIONARY:
				continue
			var action: Dictionary = action_var as Dictionary
			for retired_key: String in RETIRED_ACTION_KEYS:
				expect.call(not action.has(retired_key), "%s should not retain retired combat key %s" % [card_id, retired_key])
			expect.call(str(action.get("type", "")) != "intensity", "%s should not create an elemental currency" % card_id)
			var action_type: String = str(action.get("type", ""))
			if ATTACK_TYPES.has(action_type) and ElementData.is_elemental(element_id):
				attack_count_by_element[element_id] = int(attack_count_by_element.get(element_id, 0)) + 1
				if bool(action.get("combust", false)):
					combust_attacks += 1
			if int(action.get("chain", 0)) > 0:
				chain_actions += 1
			if element_id == ElementData.AIR and action_type in ["push", "pull"]:
				air_force_actions += 1
			var surface_kind: String = str(action.get("surface_kind", ""))
			if action_type == "surface":
				surface_kind = str(action.get("kind", surface_kind))
			if not surface_kind.is_empty() and ElementData.is_elemental(element_id):
				var kinds: Array = surface_kinds_by_element.get(element_id, []) as Array
				if not kinds.has(surface_kind):
					kinds.append(surface_kind)
				surface_kinds_by_element[element_id] = kinds
	var earth_kinds: Array = surface_kinds_by_element.get(ElementData.EARTH, []) as Array
	var ice_kinds: Array = surface_kinds_by_element.get(ElementData.ICE, []) as Array
	var lightning_kinds: Array = surface_kinds_by_element.get(ElementData.LIGHTNING, []) as Array
	earth_kinds.sort()
	ice_kinds.sort()
	lightning_kinds.sort()
	expect.call(earth_kinds == [CombatTerrainRules.SURFACE_BRAMBLE, CombatTerrainRules.SURFACE_POISON], "Earth should explore only Bramble and Poison Surfaces")
	expect.call(ice_kinds == [CombatTerrainRules.SURFACE_ICE, CombatTerrainRules.SURFACE_SNOWDRIFT], "Ice should explore only Ice and Snowdrift Surfaces")
	expect.call(lightning_kinds == [CombatTerrainRules.SURFACE_ELECTRIFIED], "Lightning should use Electrified as its single Surface")
	expect.call((surface_kinds_by_element.get(ElementData.FIRE, []) as Array).is_empty() and combust_attacks >= 10, "Fire should pay off manipulated boards with broad Combust attacks instead of adding another Surface")
	expect.call(chain_actions >= 3 and air_force_actions >= 3, "Lightning Chain and Air push/pull should remain deep repositioning payoffs")
	for element_id: String in ElementData.all_elements():
		expect.call(int(attack_count_by_element.get(element_id, 0)) > 0, "%s should retain a distinct attack package" % element_id.capitalize())

static func _test_new_combats_have_no_intensity_currency(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = combat.create_combat(8123, _room(), _player_snapshot())
	expect.call(not state.has("elemental_intensity") and not state.has("elemental_intensity_gained_total") and not state.has("elemental_intensity_spent_total"), "A new combat should have no elemental intensity state or counters")
	expect.call(bool(state.get("free_move_available", false)) and int(state.get("cards_per_turn", 0)) == 2, "Each player activation should begin with a free Move 2 and two printed card plays")
	var free_action: Dictionary = combat.free_move_action(state)
	expect.call(str(free_action.get("type", "")) == "move" and int(free_action.get("range", 0)) == 2 and bool(free_action.get("_free_move", false)), "The default board action should be one unsplittable free Move 2")
	var cards_spent: Dictionary = state.duplicate(true)
	cards_spent["cards_played_this_turn"] = 2
	expect.call(not combat.should_auto_finish_player_activation(cards_spent), "Spending the second card should preserve an unused Free Move instead of auto-ending the activation")
	var moved: Dictionary = combat.apply_player_action(state, free_action, Vector2i(3, 4))
	expect.call(int(moved.get("cards_played_this_turn", -1)) == 0 and int(moved.get("player_turn_time_spent", -1)) == 0 and not bool(moved.get("free_move_available", true)), "Free movement should cost neither a card play nor Time and should resolve once")
	moved["cards_played_this_turn"] = 2
	expect.call(combat.should_auto_finish_player_activation(moved), "An activation should auto-finish once both card plays and the Free Move are spent")

static func _test_light_radiates_and_replaces_corruption(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = combat.create_combat(8125, _room(), _player_snapshot())
	state["initiative_clock"] = 7
	CombatTerrainRules.place_field(state, [Vector2i(5, 4), Vector2i(4, 4)], CombatTerrainRules.FIELD_CORRUPTION, 99)
	var lantern_action: Dictionary = ((GameData.card_def("lantern_shot").get("actions", []) as Array)[0] as Dictionary).duplicate(true)
	var result: Dictionary = combat.apply_player_action(state, lantern_action, Vector2i(5, 4))
	var center_field: Dictionary = CombatTerrainRules.field_at(result, Vector2i(5, 4))
	expect.call(str(center_field.get("kind", "")) == CombatTerrainRules.FIELD_RADIANCE, "Attack-carried Light should Radiate its impact tile and replace Corruption")
	expect.call(CombatTerrainRules.field_kind_at(result, Vector2i(4, 4)) == CombatTerrainRules.FIELD_RADIANCE, "Light radius should Radiate every affected passable tile")
	expect.call(int(center_field.get("expires_at", 0)) == 7 + CombatTerrainRules.DEFAULT_FIELD_DURATION, "Light-created Radiance should use the shared absolute Field duration")
	expect.call(CombatTerrainRules.field_kind_at(result, Vector2i(2, 4)) != CombatTerrainRules.FIELD_RADIANCE, "Light should not Radiate beyond its authored radius")

static func _test_enemy_roster_uses_committed_geometry_and_support_mix(expect: Callable) -> void:
	var support_types: Dictionary = {}
	for enemy_id_var: Variant in GameData.enemies().keys():
		var enemy_id: String = str(enemy_id_var)
		var enemy: Dictionary = GameData.enemy_def(enemy_id)
		expect.call(int(enemy.get("design_version", 0)) == 3, "%s should use the committed-pattern enemy schema" % enemy_id)
		var has_corruption_intent: bool = false
		for intent_var: Variant in enemy.get("intents", []):
			if typeof(intent_var) != TYPE_DICTIONARY:
				continue
			var intent: Dictionary = intent_var as Dictionary
			expect.call(not (intent.get("actions", []) as Array).is_empty(), "%s intent %s should precommit at least one action" % [enemy_id, str(intent.get("name", "?"))])
			for action_var: Variant in intent.get("actions", []):
				if typeof(action_var) != TYPE_DICTIONARY:
					continue
				var action: Dictionary = action_var as Dictionary
				for retired_key: String in RETIRED_ACTION_KEYS:
					expect.call(not action.has(retired_key), "%s should not retain enemy action key %s" % [enemy_id, retired_key])
				if str(action.get("field_kind", "")) == CombatTerrainRules.FIELD_CORRUPTION:
					has_corruption_intent = true
				var action_type: String = str(action.get("type", ""))
				if action_type in ["heal", "heal_ally", "block", "guard_ally", "guard_allies"]:
					support_types[action_type] = true
		expect.call(has_corruption_intent, "%s should contribute a distinct Corruption shape or sequence to board pressure" % enemy_id)
	expect.call(support_types.has("heal_ally") or support_types.has("heal"), "The roster should contain enemy healing support")
	expect.call(support_types.has("guard_ally") or support_types.has("guard_allies") or support_types.has("block"), "The roster should contain enemy guarding or blocking support")

static func _test_corruption_preview_and_resolution_share_one_footprint(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = combat.create_combat(8124, _room(), _player_snapshot())
	var enemies: Array = (state.get("enemies", []) as Array).duplicate(true)
	var enemy: Dictionary = (enemies[0] as Dictionary).duplicate(true)
	enemy["pos"] = Vector2i(5, 4)
	enemy["intent"] = {
		"name": "Blighted Charge",
		"time": 5,
		"actions": [{
			"type": "melee",
			"damage": 2,
			"range": 4,
			"field_kind": CombatTerrainRules.FIELD_CORRUPTION,
			"field_mode": "affected",
			"field_duration": 12,
		}],
	}
	enemy.erase("committed_intent_plan")
	enemies[0] = enemy
	state["enemies"] = enemies
	combat.call("_commit_enemy_intent_plan", state, 0)
	var preview: Dictionary = combat.enemy_threat_tiles(state, 0)
	var projected: Array = preview.get("projected_field", []) as Array
	expect.call(not projected.is_empty() and str(preview.get("projected_field_kind", "")) == CombatTerrainRules.FIELD_CORRUPTION, "Intent preview should name and draw its exact projected Corruption footprint")
	var result: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0, false).get("state", {}) as Dictionary
	for tile_var: Variant in projected:
		var tile: Vector2i = tile_var as Vector2i
		expect.call(combat.field_kind_at(result, tile) == CombatTerrainRules.FIELD_CORRUPTION, "Every previewed committed tile should become Corrupted when the attack is uninterrupted")

static func _room() -> Dictionary:
	var grid: Array = []
	for y: int in range(8):
		var row: Array[String] = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return {
		"name": "Elemental Board Package Test",
		"coord": Vector2i(1, 1),
		"type": "combat",
		"element": ElementData.NONE,
		"grid": grid,
		"player_start": Vector2i(2, 4),
		"enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(5, 4), "hp": 40, "max_hp": 40, "block": 0, "stoneskin": 0}],
		"loot": [],
		"traps": [],
	}

static func _player_snapshot() -> Dictionary:
	return {
		"hp": 30,
		"max_hp": 30,
		"deck_cards": ["quick_stab", "brace"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0,
	}

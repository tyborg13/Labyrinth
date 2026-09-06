extends SceneTree

const GameData = preload("res://scripts/game_data.gd")
const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")

var _failures: Array[String]
var _checks: int = 0

func _initialize() -> void:
	_check(GameData.cards().size() == 159, "All 159 stable card definitions remain")
	_check(GameData.enemies().size() == 18, "All 18 enemies remain")
	_check(GameData.relics().size() == 60, "All 60 relics remain")
	_check(GameData.equipment().size() == 42, "All 42 equipment sources remain")
	_check(SkillTreeLibrary.definitions().size() == 30, "All skill IDs remain")
	_check(SkillTreeLibrary.visible_ids().size() == 29, "Exactly 29 skills are active")
	_check(SkillTreeLibrary.validation_errors().is_empty(), "Skill graph and board-targeting schema validate: %s" % [str(SkillTreeLibrary.validation_errors())])
	_check(GameData.card_def("bone_dart") == GameData.card_def("pale_spark"), "Legacy Bone Dart resolves to the stable replacement")
	for card_id: String in GameData.cards():
		var card: Dictionary = GameData.card_def_for_progression(card_id, {})
		_check(not card.is_empty(), "%s has a runtime definition" % card_id)
		_scan_rules(card.get("actions", []), card_id)
		for part_var: Variant in GameData.upgradeable_elements_for_card(card_id, {}):
			var part: Dictionary = part_var as Dictionary
			for mod_var: Variant in GameData.upgrade_options_for_element(card_id, part, {}):
				var mod: Dictionary = mod_var as Dictionary
				var preview: Dictionary = GameData.preview_card_with_mod(card_id, mod, {})
				_scan_rules(preview.get("actions", []), "%s upgraded" % card_id)
				_check(int(mod.get("cost", 0)) > 0, "%s upgrade is priced" % card_id)
				_check(GameData._card_value(preview) > GameData._card_value(card), "%s upgrade has real value: %s" % [card_id, mod])
	for enemy_id: String in GameData.enemies():
		var enemy: Dictionary = GameData.enemy_def(enemy_id)
		for intent_var: Variant in enemy.get("intents", []):
			var intent: Dictionary = intent_var as Dictionary
			_scan_rules(intent.get("actions", []), enemy_id)
			for action_var: Variant in intent.get("actions", []):
				var action: Dictionary = action_var as Dictionary
				if str(action.get("type", "")) in GameData.FIXED_POINT_ATTACK_ACTION_TYPES:
					_check(action.has("element"), "%s attacks have explicit element" % enemy_id)
	var generated: Dictionary = GameData._scale_enemy_fixed_point({"element": "ice", "intents": [{"actions": [{"type": "ranged", "damage": 3}, {"type": "melee", "damage": 2, "element": "none"}]}]})
	var generated_actions: Array = (generated["intents"] as Array)[0]["actions"]
	_check(str(generated_actions[0]["element"]) == "ice", "Generated attack inherits explicit enemy element")
	_check(str(generated_actions[1]["element"]) == "none", "Physical enemy attack never inherits Ice")
	var legacy_mod: Dictionary = GameData.preview_card_with_mod("pale_spark", {"kind": "status", "action_index": 0, "field": "freeze", "amount": 1}, {})
	_check(not (legacy_mod["actions"][0] as Dictionary).has("freeze"), "Legacy card upgrade cannot bypass Ice setup")
	for relic_id: String in GameData.relics():
		var relic: Dictionary = GameData.relic_def(relic_id)
		_check(not str(relic["description"]).contains("{"), "%s has fully resolved rules numbers" % relic_id)
		_scan_rules(relic.get("effects", []), relic_id)
	if _failures.is_empty():
		print("BOARD_SURFACE_DATA_PASS checks=%d cards=159 relics=60 equipment=42 enemies=18 active_skills=29" % _checks)
		quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		quit(1)

func _scan_rules(value: Variant, context: String) -> void:
	if typeof(value) == TYPE_ARRAY:
		for child: Variant in value:
			_scan_rules(child, context)
	elif typeof(value) == TYPE_DICTIONARY:
		var rule: Dictionary = value as Dictionary
		for removed_key: String in ["intensity", "intensity_bonus", "requires_intensity", "intensity_cost", "poison", "burn", "freeze"]:
			_check(not rule.has(removed_key), "%s has no removed or unconditional field %s" % [context, removed_key])
		_check(str(rule.get("type", "")) != "intensity", "%s has no removed action" % context)
		for child: Variant in rule.values():
			_scan_rules(child, context)

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

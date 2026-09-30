extends SceneTree

const GameData = preload("res://scripts/game_data.gd")
const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")

var _failures: Array[String]
var _checks: int = 0

# The board-surface migration reviewed 159 card IDs and 42 equipment sources.
# The card pool overhaul (spec/card_pool_overhaul) cuts these reviewed IDs and
# adds cards and gear in waves, so inventories are derived from the live data:
# every reviewed ID survives unless the overhaul cut it, and every equipment
# card exists.
const MIGRATION_AUDIT_PATH := "res://spec/board_surface_refactor/CARD_MIGRATION_AUDIT.json"
const OVERHAUL_CUT_CARD_IDS: Array[String] = ["ember_jab", "cinderburst", "gate_gambit"]

func _initialize() -> void:
	var audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MIGRATION_AUDIT_PATH))
	var reviewed_ids: Array = (audit.get("cards", []) as Array).map(func(entry: Variant) -> String: return str((entry as Dictionary).get("id", "")))
	_check(reviewed_ids.size() == 159, "The migration audit still records its 159 reviewed card IDs")
	for card_id_var: Variant in reviewed_ids:
		var card_id: String = str(card_id_var)
		if OVERHAUL_CUT_CARD_IDS.has(card_id):
			_check(not GameData.cards().has(card_id), "Overhaul-cut %s stays removed" % card_id)
		else:
			_check(GameData.cards().has(card_id), "Reviewed card %s remains defined" % card_id)
	_check(GameData.cards().size() >= reviewed_ids.size() - OVERHAUL_CUT_CARD_IDS.size(), "The card pool never shrinks below the reviewed IDs minus overhaul cuts")
	# Guardian and dragon content grew these past the migration's 18/60 before
	# the overhaul; keep them as floors so earlier content cannot vanish.
	_check(GameData.enemies().size() >= 18, "All 18 original enemies remain")
	_check(GameData.relics().size() >= 60, "All 60 original relics remain")
	_check(GameData.equipment().size() >= 42, "All 42 original equipment sources remain")
	for equipment_id: String in GameData.equipment():
		for card_id_var: Variant in GameData.equipment_cards(equipment_id):
			_check(GameData.cards().has(str(card_id_var)), "%s grants existing card %s" % [equipment_id, str(card_id_var)])
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
		print("BOARD_SURFACE_DATA_PASS checks=%d cards=%d relics=%d equipment=%d enemies=%d active_skills=29" % [_checks, GameData.cards().size(), GameData.relics().size(), GameData.equipment().size(), GameData.enemies().size()])
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

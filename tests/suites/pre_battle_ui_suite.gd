extends RefCounted

const GameData = preload("res://scripts/game_data.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")

const UMBRA_COLOR: Color = Color("c78bea")
const HP_COLOR: Color = Color("f08a7a")
const INITIATIVE_COLOR: Color = Color("8ec5ff")

static func run(expect: Callable) -> void:
	var host: Node = RunSceneScript.new()
	_test_room_umbra_summary(host, expect)
	_test_enemy_detail_semantics(host, expect)
	_test_known_move_icon_precedence(host, expect)
	_test_portrait_fitting_for_full_roster(host, expect)
	host.free()

static func _test_room_umbra_summary(host: Node, expect: Callable) -> void:
	var room_chip: Control = host.call("_build_pre_battle_room_chip", {
		"name": "Cindered Hall",
		"type": "combat",
		"depth": 3,
		"element": "fire"
	}, {
		"room_name": "Cindered Hall",
		"room_type": "combat",
		"room_depth": 3,
		"room_element": "fire",
		"umbra": {"stage": "fringe"}
	}, Color("e39a42")) as Control
	var depth_label: Label = room_chip.find_child("PreBattleDepthLabel", true, false) as Label
	var umbra_label: Label = room_chip.find_child("PreBattleUmbraLabel", true, false) as Label
	expect.call(depth_label != null and depth_label.text == "Depth 3", "Pre-battle room summary should retain its depth text without a vision value")
	expect.call(umbra_label != null and umbra_label.text == "Fringe Umbra", "Pre-battle room summary should retain only the named Umbra stage")
	expect.call(umbra_label != null and umbra_label.get_theme_color("font_color").is_equal_approx(UMBRA_COLOR), "Pre-battle Umbra text should use the dedicated purple instead of the room element accent")
	expect.call(not _labels_text(room_chip).contains("Vision"), "Pre-battle room summary should remove Vision X text")
	room_chip.free()

static func _test_enemy_detail_semantics(host: Node, expect: Callable) -> void:
	var enemy_def: Dictionary = GameData.enemy_def("warden")
	var inspection: Control = host.call("_build_pre_battle_enemy_inspection_panel", {
		"type": "warden",
		"hp": int(enemy_def.get("max_hp", 1)),
		"max_hp": int(enemy_def.get("max_hp", 1))
	}, true) as Control
	var hp_label: Label = inspection.find_child("PreBattleEnemyHpLine", true, false) as Label
	var initiative_label: Label = inspection.find_child("PreBattleEnemyInitiativeLine", true, false) as Label
	var close_button: Button = inspection.find_child("PreBattleInspectionCloseButton", true, false) as Button
	expect.call(hp_label != null and hp_label.text.begins_with("HP ") and hp_label.get_theme_color("font_color").is_equal_approx(HP_COLOR), "Detailed enemy HP should be isolated on a red line")
	expect.call(initiative_label != null and initiative_label.text.begins_with("Base initiative ") and initiative_label.get_theme_color("font_color").is_equal_approx(INITIATIVE_COLOR), "Detailed enemy initiative should be isolated on a blue line")
	expect.call(not _labels_text(inspection).contains("Known repertoire") and not _labels_text(inspection).contains("next move concealed"), "Detailed enemy inspection should remove the redundant repertoire/concealment line")
	expect.call(close_button != null and close_button.text == "X" and close_button.visible, "Interactive enemy inspection should expose a dedicated visible X close button")
	inspection.free()

static func _test_known_move_icon_precedence(host: Node, expect: Callable) -> void:
	var intent_expectations: Array = [
		[{"actions": [{"type": "move_toward", "range": 3}, {"type": "melee", "damage": 3}]}, "melee"],
		[{"actions": [{"type": "move_toward", "range": 2}, {"type": "ranged", "damage": 3}]}, "ranged"],
		[{"actions": [{"type": "move_away", "range": 2}, {"type": "block", "amount": 4}]}, "block"],
		[{"actions": [{"type": "move_toward", "range": 2}, {"type": "heal_ally", "amount": 4}]}, "heal"],
		[{"actions": [{"type": "move_toward", "range": 2}]}, "move"]
	]
	for expectation_var: Variant in intent_expectations:
		var expectation: Array = expectation_var as Array
		var actual: String = str(host.call("_pre_battle_known_move_icon_key", expectation[0] as Dictionary))
		expect.call(actual == str(expectation[1]), "Known enemy move icon should prioritize %s semantics over incidental movement (got %s)" % [str(expectation[1]), actual])

static func _test_portrait_fitting_for_full_roster(host: Node, expect: Callable) -> void:
	var enemy_types: Array = GameData.enemies().keys()
	for enemy_type_var: Variant in enemy_types:
		var enemy_type: String = str(enemy_type_var)
		var enemy_def: Dictionary = GameData.enemy_def(enemy_type)
		var portrait: TextureRect = host.call("_pre_battle_enemy_portrait", enemy_type, enemy_def) as TextureRect
		expect.call(portrait != null and portrait.texture != null, "%s should resolve a pre-battle portrait texture" % enemy_type)
		expect.call(portrait != null and portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "%s portrait should remain complete and centered instead of being cropped" % enemy_type)
		expect.call(portrait != null and portrait.texture != null and portrait.texture.get_size().x >= 255.0 and portrait.texture.get_size().y >= 255.0, "%s pre-battle portrait should use the complete static combat art instead of a tight turn-clock crop" % enemy_type)
		if portrait != null:
			portrait.free()
	var warden_def: Dictionary = GameData.enemy_def("warden")
	var summary_card: Control = host.call("_build_pre_battle_enemy_card", {
		"type": "warden",
		"hp": int(warden_def.get("max_hp", 1)),
		"max_hp": int(warden_def.get("max_hp", 1))
	}, Color("d8b06d"), Vector2(198.0, 152.0)) as Control
	var summary_art: TextureRect = summary_card.find_child("PreBattleEnemyArt", true, false) as TextureRect
	expect.call(summary_art != null and summary_art.offset_left >= 12.0 and summary_art.offset_top >= 12.0 and summary_art.offset_right <= -12.0, "Summary portraits should keep a safe inset from every visible frame edge")
	summary_card.free()

static func _labels_text(node: Node) -> String:
	var text_parts: PackedStringArray = []
	for child: Node in node.find_children("*", "Label", true, false):
		text_parts.append((child as Label).text)
	return "\n".join(text_parts)

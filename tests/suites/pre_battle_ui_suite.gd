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
	_test_enemy_detail_cursor_feedback(host, expect)
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
	expect.call(depth_label != null and depth_label.text == "DEPTH 3", "Pre-battle room summary should retain its uppercase depth text without a vision value")
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

static func _test_enemy_detail_cursor_feedback(host: Node, expect: Callable) -> void:
	var scrim := ColorRect.new()
	scrim.visible = true
	scrim.size = Vector2(1000.0, 700.0)
	host.add_child(scrim)
	var inspection := Control.new()
	inspection.name = "PinnedPreBattleInspection"
	inspection.set_meta("inspection_kind", "enemy")
	inspection.position = Vector2(300.0, 150.0)
	inspection.size = Vector2(400.0, 400.0)
	scrim.add_child(inspection)
	var close_button := Button.new()
	close_button.position = Vector2(340.0, 20.0)
	close_button.size = Vector2(40.0, 40.0)
	inspection.add_child(close_button)
	host.set("_pinned_tooltip_scrim", scrim)
	host.set("_pinned_tooltip_panel", inspection)
	host.set("_pinned_tooltip_close_button", close_button)
	expect.call(host.call("_pinned_tooltip_cursor_feedback_context", Vector2(660.0, 190.0)) == "action", "Focused enemy inspection should advertise only its X as actionable")
	expect.call(host.call("_pinned_tooltip_cursor_feedback_context", Vector2(450.0, 350.0)) == "inert", "Focused enemy inspection body should not advertise a blocked click")
	expect.call(host.call("_pinned_tooltip_cursor_feedback_context", Vector2(100.0, 100.0)) == "inert", "Focused enemy inspection backdrop should not advertise a suppressed underlying click")
	inspection.set_meta("inspection_kind", "card")
	expect.call(host.call("_pinned_tooltip_cursor_feedback_context", Vector2(100.0, 100.0)) == "action", "Other pinned tooltips should retain outside-click dismissal feedback")
	host.set("_pinned_tooltip_scrim", null)
	host.set("_pinned_tooltip_panel", null)
	host.set("_pinned_tooltip_close_button", null)
	scrim.free()

static func _test_known_move_icon_precedence(host: Node, expect: Callable) -> void:
	var intent_expectations: Array = [
		[{"actions": [{"type": "move_toward", "range": 3}, {"type": "melee", "damage": 3}]}, "melee"],
		[{"actions": [{"type": "move_toward", "range": 2}, {"type": "ranged", "damage": 3}]}, "ranged"],
		[{"actions": [{"type": "move_away", "range": 2}, {"type": "block", "amount": 4}]}, "block"],
		[{"actions": [{"type": "move_toward", "range": 2}, {"type": "heal_ally", "amount": 4}]}, "heal_ally"],
		[{"actions": [{"type": "move_toward", "range": 2}]}, "move"],
		[{"actions": [{"type": "lightning_strikes", "damage": 4, "count": 3}]}, "lightning_strikes"],
		[{"actions": [{"type": "summon_minions", "count": 2}]}, "summon_minions"],
		[{"actions": [{"type": "raise_terrain", "count": 4}]}, "raise_terrain"],
		[{"actions": [{"type": "terrain_burst", "damage": 8}]}, "terrain_burst"],
		[{"actions": [{"type": "cinder_marks", "count": 5}]}, "cinder_marks"],
		[{"actions": [{"type": "detonate_cinders"}]}, "detonate_cinders"],
		[{"actions": [{"type": "gale_force", "damage": 6}]}, "gale_force"],
		[{"actions": [{"type": "frost_armor", "amount": 2}]}, "frost_armor"],
		[{"actions": [{"type": "umbra_eclipse", "duration": 2}]}, "umbra_eclipse"]
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
		expect.call(portrait != null and portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "%s portrait should preserve the complete face-focused composition" % enemy_type)
		expect.call(portrait != null and portrait.texture != null and portrait.texture.get_size() == Vector2(128.0, 128.0), "%s pre-battle portrait should use the shared native 128px combat portrait" % enemy_type)
		expect.call(portrait != null and portrait.material is ShaderMaterial and bool(portrait.get_meta("pre_battle_worn_edges", false)), "%s pre-battle portrait should use the worn edge material" % enemy_type)
		var profile: Dictionary = (portrait.get_meta("pre_battle_portrait_edge_profile", {}) as Dictionary) if portrait != null else {}
		expect.call(profile.has("focus_center") and profile.has("focus_radius") and profile.has("edge_widths") and profile.has("edge_strengths"), "%s worn edge profile should include focal protection and per-side wear controls" % enemy_type)
		var portrait_path: String = str(host.call("_combat_portrait_path", enemy_type))
		expect.call(portrait_path.begins_with("res://assets/art/portraits/"), "%s pre-battle portrait should resolve through the shared portrait registry" % enemy_type)
		if portrait != null:
			portrait.free()
	var warden_def: Dictionary = GameData.enemy_def("warden")
	var summary_card: Control = host.call("_build_pre_battle_enemy_card", {
		"type": "warden",
		"hp": int(warden_def.get("max_hp", 1)),
		"max_hp": int(warden_def.get("max_hp", 1))
	}, Color("d8b06d"), Vector2(198.0, 152.0)) as Control
	var summary_art: TextureRect = summary_card.find_child("PreBattleEnemyArt", true, false) as TextureRect
	expect.call(summary_art != null and summary_art.offset_left >= 12.0 and summary_art.offset_top >= 12.0 and summary_art.offset_right <= -12.0, "Summary portraits should keep a safe inset inside the frameless brush composition")
	summary_card.free()
	var crawler_portrait: TextureRect = host.call("_pre_battle_enemy_portrait", "crawler", GameData.enemy_def("crawler")) as TextureRect
	var crawler_profile: Dictionary = crawler_portrait.get_meta("pre_battle_portrait_edge_profile", {}) as Dictionary
	var crawler_center: Vector2 = crawler_profile.get("focus_center", Vector2.ONE)
	var crawler_strengths: Vector4 = crawler_profile.get("edge_strengths", Vector4.ZERO)
	expect.call(crawler_center.x < 0.40, "Tunnel Crawler focal protection should follow its left-side head")
	expect.call(crawler_strengths.z > crawler_strengths.x and crawler_strengths.w > crawler_strengths.y, "Tunnel Crawler should wear its right/bottom body edges more strongly than the head-side edges")
	crawler_portrait.free()

static func _labels_text(node: Node) -> String:
	var text_parts: PackedStringArray = []
	for child: Node in node.find_children("*", "Label", true, false):
		text_parts.append((child as Label).text)
	return "\n".join(text_parts)

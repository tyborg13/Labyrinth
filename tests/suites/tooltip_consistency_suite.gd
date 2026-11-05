extends RefCounted

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const GameData = preload("res://scripts/game_data.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")
const UiTooltipButton = preload("res://scripts/ui_tooltip_button.gd")
const UiTooltipControl = preload("res://scripts/ui_tooltip_control.gd")
const UiTooltipLabel = preload("res://scripts/ui_tooltip_label.gd")
const UiTooltipPanelContainer = preload("res://scripts/ui_tooltip_panel_container.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const UiTooltipPanel = preload("res://scripts/ui_tooltip_panel.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const RunScene = preload("res://scenes/run_scene.tscn")
const Glossary = preload("res://scripts/glossary.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const TooltipStack = preload("res://scripts/card_focus_tooltip_stack.gd")


static func run(expect: Callable) -> void:
	_test_shared_tooltip_controls(expect)
	_test_static_run_scene_tooltip_controls(expect)
	_test_dynamic_turn_order_tooltip_control(expect)
	_test_equipment_pickup_reuses_equipment_card_preview(expect)
	_test_icon_tooltip_panel(expect)
	_test_inline_description_tooltip(expect)
	_test_card_tooltip_entries(expect)
	_test_tooltip_entry_modifier_merging(expect)
	_test_tooltip_entry_base_identity(expect)
	_test_real_cards_preserve_repeated_icon_semantics(expect)
	_test_petrify_keyword(expect)


static func _test_petrify_keyword(expect: Callable) -> void:
	var card: Dictionary = GameData.card_def("petrify")
	var rows: Array = ActionIcons.rows_for_card(card)
	var tokens: Array = []
	for row: Array in rows:
		tokens.append_array(row)
	expect.call(tokens.size() == 2, "Petrify card rows contain exactly two tokens")
	if tokens.size() == 2:
		expect.call(tokens[0].get("icon") == "petrify" and tokens[1].get("icon") == "range" and int(tokens[1].get("value", 0)) == 3, "Petrify card rows are the keyword icon followed by range 3")
	for token: Dictionary in tokens:
		expect.call(token.get("kind") != "text", "Petrify card rows contain no text tokens")
	var expected_tip: String = "Petrify\nSkips its next turn and gains 5 Block."
	var entries: Array[Dictionary] = ActionIcons.tooltip_entries_for_rows(rows)
	var owner := Control.new()
	var stack := TooltipStack.new()
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	root.add_child(owner)
	root.add_child(stack)
	stack.show_for(owner, entries)
	var petrify_entries: int = 0
	for entry: Dictionary in stack._entries:
		if str(entry.get("icon", "")) == "petrify":
			petrify_entries += 1
			expect.call("%s\n%s" % [entry.get("title", ""), entry.get("description", "")] == expected_tip, "Petrify focus stack uses the exact complete keyword tooltip")
	expect.call(petrify_entries == 1, "Petrify focus stack explains Petrify exactly once")
	expect.call(stack.entry_count() == 2, "Petrify focus stack contains Petrify and Range without automatic Time or a second Block explanation")
	stack.free()
	owner.free()
	expect.call(not (card["actions"][0] as Dictionary).has("block"), "Petrify card delegates Block to the keyword")
	expect.call(card.get("description") == "Petrify an enemy within range 3 (not a dragon). It skips its next turn and gains 5 Block.", "Petrify card uses the decided description")
	expect.call(Glossary.definition("petrify") == "Skips its next turn and gains 5 Block.", "Petrify glossary uses the complete fixed keyword definition")
	var body: Array = (Grimoire.entry_map()["combat:petrify"] as Dictionary).get("body", []) as Array
	expect.call(body.slice(0, 2) == ["A Petrified enemy skips its next turn. The skipped turn still costs its normal Time on the Turn Clock, so it does not come back sooner.", "Petrify also gives the enemy 5 Block, which lasts through your next turn. It is not Freeze: there is no damage multiplier and no Chill interaction. Dragons cannot be Petrified."], "Petrify grimoire keeps its first paragraph and the decided second paragraph")
	expect.call(body.has("Skips its next turn, still paying its Time, and gains 5 Block through your next turn. Dragons are immune."), "Petrify Grimoire retains the former full glossary rules")


static func _test_shared_tooltip_controls(expect: Callable) -> void:
	var controls: Array[Control] = [
		UiTooltipButton.new(),
		UiTooltipControl.new(),
		UiTooltipLabel.new(),
		UiTooltipPanelContainer.new()
	]
	for control: Control in controls:
		var tooltip: Variant = control.call("_make_custom_tooltip", "TITLE\nFramed body copy")
		expect.call(tooltip is PanelContainer, "%s tooltips should use the shared framed panel" % control.get_class())
		if tooltip is PanelContainer:
			var tooltip_panel := tooltip as PanelContainer
			expect.call(
				tooltip_panel.get_node_or_null(UiSkin.PANEL_INSET_ORNAMENT_NAME) != null,
				"%s tooltips should expose the shared asymmetric frame" % control.get_class()
			)
			(tooltip as PanelContainer).free()
		control.free()


static func _test_static_run_scene_tooltip_controls(expect: Callable) -> void:
	var scene: Node = RunScene.instantiate()
	var paths: PackedStringArray = [
		"UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/TitleBox/UmbraSubtitle",
		"UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/LoadoutButton",
		"UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/GrimoireButton",
		"UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/MenuButton",
		"UiLayer/UiRoot/Backdrop/Margin/MainVBox/StageRoot/MiniMapOverlay",
		"UiLayer/UiRoot/PilesBar/DrawPile",
		"UiLayer/UiRoot/PilesBar/DiscardPile",
		"UiLayer/UiRoot/PilesBar/BurnPile"
	]
	for path: String in paths:
		var control: Control = scene.get_node(path) as Control
		var tooltip: Variant = control.call("_make_custom_tooltip", "STATIC\nFramed tooltip")
		expect.call(tooltip is PanelContainer, "%s should use a framed tooltip owner" % path.get_file())
		if tooltip is PanelContainer:
			(tooltip as PanelContainer).free()
	scene.free()


static func _test_dynamic_turn_order_tooltip_control(expect: Callable) -> void:
	var host: Node = RunSceneScript.new()
	var slot: Control = host.call("_build_turn_order_slot", {
		"kind": "player",
		"name": "Player",
		"time": 0,
		"eta": 0,
		"active": true,
		"base_initiative": 3
	}, 0) as Control
	expect.call(slot.has_method("_make_custom_tooltip"), "Dynamic turn-order slots should own framed tooltips")
	if slot.has_method("_make_custom_tooltip"):
		var tooltip: Variant = slot.call("_make_custom_tooltip", slot.tooltip_text)
		expect.call(tooltip is PanelContainer, "Dynamic turn-order tooltips should use the shared framed panel")
		if tooltip is PanelContainer:
			(tooltip as PanelContainer).free()
	slot.free()
	host.free()


static func _test_equipment_pickup_reuses_equipment_card_preview(expect: Callable) -> void:
	var host: Node = RunSceneScript.new()
	var board: Control = CombatBoardView.new()
	board.set("equipment_tooltip_builder", Callable(host, "_build_equipment_tooltip_panel"))
	var trigger: String = str(board.call("_loot_tooltip_text", {
		"kind": "equipment",
		"equipment_id": "iron_cleaver"
	}))
	expect.call(trigger == "equipment:iron_cleaver", "Collectible equipment should request the shared rich equipment tooltip")
	var tooltip: Variant = board.call("_make_custom_tooltip", trigger)
	expect.call(tooltip is PanelContainer, "Collectible equipment should build the equip-menu tooltip panel")
	if tooltip is PanelContainer:
		var card_widgets: Array[Node] = (tooltip as PanelContainer).find_children("*", "Button", true, false)
		var expected_cards: Array = GameData.equipment_cards("iron_cleaver")
		var preview_ids: Array[String] = []
		for node: Node in card_widgets:
			if node.get_script() == CardWidget and str(node.get("card_id")) != "":
				preview_ids.append(str(node.get("card_id")))
		expect.call(preview_ids.size() == expected_cards.size(), "Collectible equipment should preview every card supplied by the item")
		for card_id_var: Variant in expected_cards:
			expect.call(preview_ids.has(str(card_id_var)), "Collectible equipment should preview %s" % str(card_id_var))
		(tooltip as PanelContainer).free()
	board.free()
	host.free()


static func _test_icon_tooltip_panel(expect: Callable) -> void:
	var panel: PanelContainer = UiTooltipPanel.make_icon_lines(
		ActionIcons.icon_texture("surface_fire"),
		"Fire",
		PackedStringArray([ActionIcons.description("surface_fire")])
	)
	var icon: TextureRect = panel.find_child("TooltipIcon", true, false) as TextureRect
	expect.call(icon != null and icon.texture != null, "Icon-led tooltips should render the matching concept icon")
	expect.call(panel.get_node_or_null(UiSkin.PANEL_INSET_ORNAMENT_NAME) != null, "Icon-led tooltips should retain the shared framed surface")
	panel.free()


static func _test_inline_description_tooltip(expect: Callable) -> void:
	var panel: PanelContainer = UiTooltipPanel.make_text(
		"QUICK WITS\nOnce per combat, discard a card to gain @icon(draw) 1. Costs no @icon(card_play) or @icon(time)."
	)
	var rich_labels: Array[Node] = panel.find_children("*", "RichTextLabel", true, false)
	var description: RichTextLabel = rich_labels[0] as RichTextLabel if not rich_labels.is_empty() else null
	expect.call(description != null, "Inline mechanic tooltips should render through a rich rules label")
	if description != null:
		var font_size: int = description.get_theme_font_size("normal_font_size")
		expect.call(font_size >= UiTypography.SIZE_BODY_LARGE, "Inline mechanic tooltips should use the enlarged readable type tier")
		expect.call(float(description.get_meta("inline_icon_size", 0.0)) > float(font_size), "Inline tooltip icons should be larger than their surrounding rules text")
	panel.free()


static func _test_card_tooltip_entries(expect: Callable) -> void:
	var rows: Array = [[
		ActionIcons.duration_token(2),
		ActionIcons.token_for("ranged", 5),
		ActionIcons.token_for("ranged", 3),
		ActionIcons.token_for("ranged", 6, "bonus", "", [{
			"source": "Equipment",
			"label": "+1",
			"detail": "Stormstring Bow",
		}], 5),
		{"kind": "aoe_pattern", "icon": "aoe_pattern"},
		ActionIcons.text_token("conditional copy"),
	], [
		ActionIcons.token_for("range", 4),
	]]
	var entries: Array[Dictionary] = ActionIcons.tooltip_entries_for_rows(rows, ["time"])
	var keys: Array[String] = []
	for entry: Dictionary in entries:
		keys.append(str(entry.get("icon", "")))
		expect.call(entry.get("texture", null) is Texture2D, "Every card tooltip entry should carry its matching icon texture")
	expect.call(keys == ["time", "time", "ranged", "range"], "Card tooltip entries should preserve reading order, keep distinct same-icon meanings, deduplicate identical semantics, ignore geometry patterns and text-only tokens")
	expect.call(entries[1]["title"] == "Turns" and entries[1]["description"] == ActionIcons.description("turns"), "A repeated Time icon should retain its duration-specific explanation")
	expect.call(str(entries[2].get("description", "")).contains("Modified by") and str(entries[2].get("description", "")).contains("Stormstring Bow"), "The single Ranged entry should retain its modifier explanation")


static func _test_tooltip_entry_modifier_merging(expect: Callable) -> void:
	var plain: Dictionary = ActionIcons.token_for("stagger", 4)
	var empowered: Dictionary = ActionIcons.token_for("stagger", 4, "bonus", "", [{"source": "Empower", "amount": 4}], 0)
	var relic: Dictionary = ActionIcons.token_for("stagger", 5, "bonus", "", [{"source": "Relic", "amount": 1, "detail": "Fixture relic"}], 4)
	var expected_tooltip: String = "%s\nModified by:\nEmpower +4" % ActionIcons.tooltip("stagger")
	for ordered_tokens: Array in [[plain, empowered], [empowered, plain]]:
		# A later unrelated entry proves the merged identity keeps its first slot.
		var entries: Array[Dictionary] = ActionIcons.tooltip_entries_for_rows([
			[ordered_tokens[0], ActionIcons.token_for("range", 1)], [ordered_tokens[1]],
		])
		expect.call(entries.size() == 2 and entries[0]["icon"] == "stagger" and entries[1]["icon"] == "range", "Plain/modified keywords should share one entry at the first occurrence in either order")
		expect.call(entries[0]["tooltip"] == expected_tooltip, "A modified keyword should win over a plain occurrence in either order")
		expect.call(entries[0]["semantic_key"] == "stagger\u001f%s" % ActionIcons.tooltip("stagger"), "Modifier text should not be part of the entry's semantic identity")
		expect.call(entries[0]["title"] == ActionIcons.label("stagger") and entries[0]["description"] == "%s\nModified by:\nEmpower +4" % ActionIcons.description("stagger"), "Merged title and description should be rebuilt from the final tooltip")
	for ordered_tokens: Array in [[empowered, relic, empowered, relic], [relic, empowered, relic, empowered]]:
		var entries: Array[Dictionary] = ActionIcons.tooltip_entries_for_rows([ordered_tokens])
		var expected_lines: String = "Empower +4\nRelic +1  Fixture relic" if ordered_tokens[0] == empowered else "Relic +1  Fixture relic\nEmpower +4"
		expect.call(entries.size() == 1, "Different modifiers of the same keyword should share one entry")
		expect.call(entries[0]["tooltip"] == "%s\nModified by:\n%s" % [ActionIcons.tooltip("stagger"), expected_lines], "Merged modifier lines should retain reading order, exact wording and spacing, and appear once each")
	var repeated: Dictionary = ActionIcons.token_for("stagger", 4, "bonus", "", [{"source": "Empower", "amount": 4}, {"source": "Empower", "amount": 4}], 0)
	var repeated_entries: Array[Dictionary] = ActionIcons.tooltip_entries_for_rows([[repeated, repeated]])
	expect.call(repeated_entries.size() == 1 and repeated_entries[0]["tooltip"] == expected_tooltip, "Identical modifier lines within and across tokens should appear once")
	expect.call(ActionIcons.token_tooltip(plain) == ActionIcons.tooltip("stagger") and ActionIcons.token_tooltip(empowered) == expected_tooltip, "Building a stack should preserve single-token native tooltip text")
	expect.call(ActionIcons.token_tooltip(repeated).count("Empower +4") == 2, "Native tooltip modifier lines should remain untouched even when the stack merges them")


static func _test_tooltip_entry_base_identity(expect: Callable) -> void:
	var entries: Array[Dictionary] = ActionIcons.tooltip_entries_for_rows([
		[ActionIcons.duration_token(2), ActionIcons.token_for("time", 4)],
		[ActionIcons.duration_token(3), ActionIcons.token_for("time", 5)],
	])
	expect.call(entries.size() == 2, "The same icon with different base text (Time versus Turns) should stay two entries")
	expect.call(entries.size() == 2 and entries[0]["tooltip"] == ActionIcons.tooltip("turns") and entries[1]["tooltip"] == ActionIcons.tooltip("time"), "Unmodified identities should retain exactly their base text in first-occurrence order")
	expect.call(entries.size() == 2 and entries[0]["semantic_key"] != entries[1]["semantic_key"], "Time and Turns should have distinct semantic keys")
	var condition: Dictionary = ActionIcons.state_condition_token("light")
	var modified_condition: Dictionary = condition.duplicate(true)
	modified_condition["modifiers"] = [{"source": "Relic", "amount": 1}]
	var condition_entries: Array[Dictionary] = ActionIcons.tooltip_entries_for_rows([[condition, modified_condition]])
	expect.call(condition_entries.size() == 1 and condition_entries[0]["tooltip"] == "%s\nModified by:\nRelic +1" % ActionIcons.token_tooltip(condition, true), "Keyword surface conditions should deduplicate by their modifier-free token tooltip")
	# An icon without a texture is skipped before it registers, so repeats stay skipped and later entries still land.
	var missing: Dictionary = {"kind": "icon", "icon": "fix06_missing_icon", "tooltip": "Missing icon"}
	var skipped_entries: Array[Dictionary] = ActionIcons.tooltip_entries_for_rows([[missing, missing, ActionIcons.token_for("stagger", 4)]])
	expect.call(skipped_entries.size() == 1 and skipped_entries[0]["icon"] == "stagger", "Textureless icons should be skipped without registering an identity")


static func _test_real_cards_preserve_repeated_icon_semantics(expect: Callable) -> void:
	var lantern: Dictionary = GameData.card_def("lantern_shot")
	var lantern_entries: Array[Dictionary] = ActionIcons.tooltip_entries_for_rows(
		ActionIcons.rows_for_card(lantern)
	)
	var lantern_time_descriptions: Array[String] = []
	for entry: Dictionary in lantern_entries:
		if str(entry.get("icon", "")) == "time":
			lantern_time_descriptions.append(str(entry.get("description", "")))
	expect.call(lantern_time_descriptions.size() == 1, "Lantern Shot should keep only the light-duration Turns panel")
	expect.call(not lantern_time_descriptions.has(ActionIcons.description("time")), "Lantern Shot should omit the automatic card-cost Time panel")
	expect.call(lantern_time_descriptions.has(ActionIcons.description("turns")), "Lantern Shot should retain the light-duration Turns explanation")

	var stormstring: Dictionary = GameData.card_def("stormstring_shot")
	var storm_entries: Array[Dictionary] = ActionIcons.tooltip_entries_for_rows(
		ActionIcons.rows_for_card(stormstring),
		["time"]
	)
	var ground_descriptions: Array[String]
	for entry: Dictionary in storm_entries:
		if str(entry.get("icon", "")) == "surface_electrified": ground_descriptions.append(str(entry.get("description", "")))
	expect.call(not ground_descriptions.is_empty(), "Stormstring Shot should explain its Electrified setup")

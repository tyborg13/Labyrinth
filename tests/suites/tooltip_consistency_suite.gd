extends RefCounted

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const GameData = preload("res://scripts/game_data.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")
const UiTooltipButton = preload("res://scripts/ui_tooltip_button.gd")
const UiTooltipControl = preload("res://scripts/ui_tooltip_control.gd")
const UiTooltipLabel = preload("res://scripts/ui_tooltip_label.gd")
const UiTooltipPanelContainer = preload("res://scripts/ui_tooltip_panel_container.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const RunScene = preload("res://scenes/run_scene.tscn")


static func run(expect: Callable) -> void:
	_test_shared_tooltip_controls(expect)
	_test_static_run_scene_tooltip_controls(expect)
	_test_dynamic_turn_order_tooltip_control(expect)
	_test_equipment_pickup_reuses_equipment_card_preview(expect)


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
		"UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar/DrawPile",
		"UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar/DiscardPile",
		"UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar/BurnPile"
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

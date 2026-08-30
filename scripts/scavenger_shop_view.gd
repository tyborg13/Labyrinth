extends Control
class_name ScavengerShopView

signal buy_requested(item_id: String, source: Control)
signal sell_requested(item_id: String, source: Control)
signal reserve_requested(item_id: String)
signal leave_requested
signal item_hovered(merchant_kind: String, item_id: String, source: Control)
signal item_unhovered(merchant_kind: String, item_id: String, source: Control)

const AssetLoader = preload("res://scripts/asset_loader.gd")
const CardWidgetScene = preload("res://scenes/card_widget.tscn")
const GameData = preload("res://scripts/game_data.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

const REFERENCE_SIZE := Vector2(1920.0, 1080.0)
const BACKDROP_PATH := "res://assets/art/ui/scavenger_shop/stall_backdrop_v1.png"
const SCAVENGER_PATH := "res://assets/art/npcs/scavenger.png"
const DARK_FRAME_PATH := "res://assets/art/ui/panel_silver_inset.png"
const PARCHMENT_FRAME_PATH := "res://assets/art/ui/panel_wood_parchment.png"
const EMBER_ICON_PATH := "res://assets/art/tiles/ember.png"
const MAGIC := "magic"
const GEAR := "gear"
const ITEM := "item"
const MERCHANT_KIND := "scavenger"
const OFFER_CARD_SIZE := Vector2(148.0, 208.0)
const OFFER_TILE_SIZE := Vector2(178.0, 146.0)
const SELL_TILE_SIZE := Vector2(132.0, 118.0)
const SELL_PAGE_SIZE: int = 3

var _run_state: Dictionary = {}
var _run_engine: RefCounted
var _reduced_motion: bool = false
var _selected_item_id: String = ""
var _selected_is_sell: bool = false
var _selected_source: Control
var _room_coord: Vector2i = Vector2i(-999, -999)
var _entry_played_for_room: bool = false
var _ambient_time: float = 0.0

var _canvas: Control
var _backdrop: TextureRect
var _portrait: TextureRect
var _title_panel: PanelContainer
var _currency_panel: PanelContainer
var _currency_label: Label
var _magic_group: Control
var _gear_group: Control
var _item_group: Control
var _detail_panel: PanelContainer
var _detail_title: Label
var _detail_kind: Label
var _detail_icon: TextureRect
var _detail_description: Label
var _detail_price: Label
var _detail_action: Button
var _layaway_action: Button
var _sell_panel: PanelContainer
var _sell_heading: Label
var _sell_row: HBoxContainer
var _sell_previous: Button
var _sell_next: Button
var _leave_button: Button
var _selection_effects: Dictionary = {}
var _offer_sources: Dictionary = {}
var _animated_groups: Array[Control] = []
var _sellable_ids: Array = []
var _sell_page: int = 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_build_static_scene()
	resized.connect(_layout_canvas)
	_layout_canvas()
	set_process(true)

func configure(run_state: Dictionary, run_engine: RefCounted, reduced_motion: bool) -> void:
	_run_state = run_state.duplicate(true)
	_run_engine = run_engine
	_reduced_motion = reduced_motion
	var next_room: Vector2i = _run_state.get("current_room", Vector2i.ZERO)
	if next_room != _room_coord:
		_room_coord = next_room
		_entry_played_for_room = false
		_selected_item_id = ""
		_selected_is_sell = false
		_selected_source = null
		_sell_page = 0
	_rebuild_inventory()
	_restore_selection_after_rebuild()
	_sync_currency()
	_sync_detail()
	if visible and not _entry_played_for_room:
		call_deferred("_play_entry")

func present() -> void:
	visible = true
	if not _entry_played_for_room:
		call_deferred("_play_entry")

func dismiss_immediately() -> void:
	visible = false

func semantic_snapshot() -> Dictionary:
	var categories := {MAGIC: 0, GEAR: 0, ITEM: 0}
	if _run_engine != null:
		for offer_var: Variant in _run_engine.call("merchant_offer_ids", _run_state, MERCHANT_KIND):
			var kind: String = str(_run_engine.call("merchant_item_kind", str(offer_var)))
			categories[kind] = int(categories.get(kind, 0)) + 1
	return {
		"visible": visible,
		"title": "Scavenger's Wares",
		"currency": int(_run_state.get("held_embers", 0)),
		"categories": categories,
		"sell_count": _run_engine.call("merchant_sellable_ids", _run_state, MERCHANT_KIND).size() if _run_engine != null else 0,
		"selected_item_id": _selected_item_id,
		"selected_is_sell": _selected_is_sell,
		"reduced_motion": _reduced_motion,
	}

func _build_static_scene() -> void:
	var letterbox := ColorRect.new()
	letterbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	letterbox.color = Color("050403")
	letterbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(letterbox)

	_canvas = Control.new()
	_canvas.name = "ScavengerShopCanvas"
	_canvas.size = REFERENCE_SIZE
	_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_canvas)

	_backdrop = TextureRect.new()
	_backdrop.name = "RasterStallBackdrop"
	_place(_backdrop, Rect2(Vector2.ZERO, REFERENCE_SIZE))
	_backdrop.texture = AssetLoader.load_texture(BACKDROP_PATH)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_backdrop)

	var vignette := ColorRect.new()
	vignette.name = "ShopVignette"
	_place(vignette, Rect2(Vector2.ZERO, REFERENCE_SIZE))
	vignette.color = Color(0.018, 0.012, 0.010, 0.18)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(vignette)

	_portrait = TextureRect.new()
	_portrait.name = "ScavengerPortrait"
	_place(_portrait, Rect2(42.0, 170.0, 520.0, 660.0))
	_portrait.texture = AssetLoader.load_texture(SCAVENGER_PATH)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.pivot_offset = _portrait.size * 0.55
	_canvas.add_child(_portrait)

	_title_panel = _raster_panel(DARK_FRAME_PATH, Color("4a3425"))
	_title_panel.name = "ScavengerWaresTitlePanel"
	_place(_title_panel, Rect2(560.0, 28.0, 890.0, 92.0))
	_canvas.add_child(_title_panel)
	var title := Label.new()
	title.text = "SCAVENGER'S WARES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.apply_label_role(title, UiTypography.ROLE_BANNER)
	UiTypography.set_label_size(title, 48)
	title.add_theme_color_override("font_color", Color("f1d39a"))
	title.add_theme_color_override("font_outline_color", Color("1a0f09"))
	title.add_theme_constant_override("outline_size", 5)
	_title_panel.add_child(title)

	_currency_panel = _raster_panel(DARK_FRAME_PATH, Color("493325"))
	_currency_panel.name = "ScavengerCurrencyPanel"
	_place(_currency_panel, Rect2(1470.0, 38.0, 395.0, 72.0))
	_canvas.add_child(_currency_panel)
	var currency_row := HBoxContainer.new()
	currency_row.alignment = BoxContainer.ALIGNMENT_CENTER
	currency_row.add_theme_constant_override("separation", 12)
	_currency_panel.add_child(currency_row)
	_currency_label = Label.new()
	_currency_label.name = "ScavengerEmberCount"
	_currency_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(_currency_label, 28)
	_currency_label.add_theme_color_override("font_color", Color("f3c56f"))
	currency_row.add_child(_currency_label)
	var ember_icon := TextureRect.new()
	ember_icon.custom_minimum_size = Vector2(36.0, 36.0)
	ember_icon.texture = AssetLoader.load_texture(EMBER_ICON_PATH)
	ember_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ember_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ember_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	currency_row.add_child(ember_icon)

	_magic_group = _build_category_group("MAGIC", Rect2(610.0, 138.0, 820.0, 306.0))
	_gear_group = _build_category_group("GEAR", Rect2(610.0, 458.0, 820.0, 206.0))
	_item_group = _build_category_group("ITEMS", Rect2(610.0, 678.0, 820.0, 206.0))
	_animated_groups = [_magic_group, _gear_group, _item_group]

	_detail_panel = _raster_panel(PARCHMENT_FRAME_PATH, Color.WHITE)
	_detail_panel.name = "ScavengerDetailPanel"
	_place(_detail_panel, Rect2(1465.0, 150.0, 400.0, 700.0))
	_canvas.add_child(_detail_panel)
	_build_detail_content()

	_sell_panel = _raster_panel(DARK_FRAME_PATH, Color("463226"))
	_sell_panel.name = "SellFromPackPanel"
	_place(_sell_panel, Rect2(52.0, 760.0, 520.0, 268.0))
	_canvas.add_child(_sell_panel)
	_build_sell_content()

	_leave_button = _raster_button("LEAVE", Color("6e2d24"), Color("9a4735"))
	_leave_button.name = "ScavengerLeaveButton"
	_place(_leave_button, Rect2(1500.0, 920.0, 330.0, 82.0))
	UiTypography.set_button_size(_leave_button, 30)
	_leave_button.tooltip_text = "Close the shop and return to the room's doors."
	_leave_button.pressed.connect(func() -> void: leave_requested.emit())
	_canvas.add_child(_leave_button)

func _build_category_group(label_text: String, rect: Rect2) -> Control:
	var group := Control.new()
	group.name = "%sShelf" % label_text.capitalize()
	_place(group, rect)
	_canvas.add_child(group)
	var plaque := PanelContainer.new()
	plaque.name = "%sPlaque" % label_text.capitalize()
	_place(plaque, Rect2((rect.size.x - 210.0) * 0.5, 0.0, 210.0, 48.0))
	plaque.add_theme_stylebox_override("panel", _raster_style(DARK_FRAME_PATH, Color("4b3526")))
	group.add_child(plaque)
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(label, 24)
	label.add_theme_color_override("font_color", Color("efd39d"))
	label.add_theme_color_override("font_outline_color", Color("180e08"))
	label.add_theme_constant_override("outline_size", 3)
	plaque.add_child(label)
	var row := HBoxContainer.new()
	row.name = "OfferRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	_place(row, Rect2(0.0, 50.0, rect.size.x, rect.size.y - 50.0))
	group.add_child(row)
	return group

func _build_detail_content() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 30)
	_detail_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(stack)
	_detail_title = Label.new()
	_detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_title.custom_minimum_size = Vector2(0.0, 62.0)
	UiTypography.set_label_size(_detail_title, 30)
	_detail_title.add_theme_color_override("font_color", Color("2a1b12"))
	stack.add_child(_detail_title)
	_detail_kind = Label.new()
	_detail_kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(_detail_kind, 18)
	_detail_kind.add_theme_color_override("font_color", Color("71543b"))
	stack.add_child(_detail_kind)
	var separator := HSeparator.new()
	stack.add_child(separator)
	var icon_center := CenterContainer.new()
	icon_center.custom_minimum_size = Vector2(0.0, 190.0)
	stack.add_child(icon_center)
	_detail_icon = TextureRect.new()
	_detail_icon.custom_minimum_size = Vector2(164.0, 164.0)
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_center.add_child(_detail_icon)
	_detail_description = Label.new()
	_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_description.custom_minimum_size = Vector2(0.0, 138.0)
	UiTypography.set_label_size(_detail_description, 20)
	_detail_description.add_theme_color_override("font_color", Color("302016"))
	stack.add_child(_detail_description)
	_detail_price = Label.new()
	_detail_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_price.custom_minimum_size = Vector2(0.0, 38.0)
	UiTypography.set_label_size(_detail_price, 22)
	_detail_price.add_theme_color_override("font_color", Color("70431e"))
	stack.add_child(_detail_price)
	_detail_action = _raster_button("BUY", Color("214459"), Color("2e6985"))
	_detail_action.name = "ScavengerTradeActionButton"
	_detail_action.custom_minimum_size = Vector2(0.0, 64.0)
	UiTypography.set_button_size(_detail_action, 25)
	_detail_action.pressed.connect(_on_detail_action)
	stack.add_child(_detail_action)
	_layaway_action = _raster_button("HOLD FOR NEXT VISIT", Color("3d314f"), Color("5f4b76"))
	_layaway_action.name = "ScavengerLayawayButton"
	_layaway_action.custom_minimum_size = Vector2(0.0, 48.0)
	UiTypography.set_button_size(_layaway_action, 17)
	_layaway_action.pressed.connect(_on_layaway_action)
	stack.add_child(_layaway_action)

func _build_sell_content() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 20)
	_sell_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)
	_sell_heading = Label.new()
	_sell_heading.text = "SELL FROM PACK"
	_sell_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(_sell_heading, 23)
	_sell_heading.add_theme_color_override("font_color", Color("efd39d"))
	_sell_heading.add_theme_color_override("font_outline_color", Color("170d08"))
	_sell_heading.add_theme_constant_override("outline_size", 3)
	stack.add_child(_sell_heading)
	var instruction := Label.new()
	instruction.text = "Choose an owned card, gear piece, or item. Its exact value appears before you sell."
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTypography.set_label_size(instruction, 15)
	instruction.add_theme_color_override("font_color", Color("cdbda3"))
	stack.add_child(instruction)
	var pager := HBoxContainer.new()
	pager.name = "SellInventoryPager"
	pager.custom_minimum_size = Vector2(0.0, SELL_TILE_SIZE.y)
	pager.alignment = BoxContainer.ALIGNMENT_CENTER
	pager.add_theme_constant_override("separation", 5)
	stack.add_child(pager)
	_sell_previous = _raster_button("‹", Color("34271f"), Color("57422e"))
	_sell_previous.name = "SellPreviousPage"
	_sell_previous.custom_minimum_size = Vector2(26.0, SELL_TILE_SIZE.y)
	_sell_previous.tooltip_text = "Previous pack page."
	_sell_previous.pressed.connect(_turn_sell_page.bind(-1))
	pager.add_child(_sell_previous)
	_sell_row = HBoxContainer.new()
	_sell_row.name = "SellInventoryRow"
	_sell_row.custom_minimum_size = Vector2(SELL_TILE_SIZE.x * SELL_PAGE_SIZE + 8.0 * (SELL_PAGE_SIZE - 1), SELL_TILE_SIZE.y)
	_sell_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_sell_row.add_theme_constant_override("separation", 8)
	pager.add_child(_sell_row)
	_sell_next = _raster_button("›", Color("34271f"), Color("57422e"))
	_sell_next.name = "SellNextPage"
	_sell_next.custom_minimum_size = Vector2(26.0, SELL_TILE_SIZE.y)
	_sell_next.tooltip_text = "Next pack page."
	_sell_next.pressed.connect(_turn_sell_page.bind(1))
	pager.add_child(_sell_next)

func _rebuild_inventory() -> void:
	if _run_engine == null or _magic_group == null:
		return
	_offer_sources.clear()
	_selection_effects.clear()
	for group: Control in [_magic_group, _gear_group, _item_group]:
		var row := group.get_node_or_null("OfferRow") as HBoxContainer
		_clear_children(row)
	var offers: Array = _run_engine.call("merchant_offer_ids", _run_state, MERCHANT_KIND)
	for offer_var: Variant in offers:
		var item_id: String = str(offer_var)
		var kind: String = str(_run_engine.call("merchant_item_kind", item_id))
		var target_group: Control = _magic_group if kind == MAGIC else (_gear_group if kind == GEAR else _item_group)
		var row := target_group.get_node("OfferRow") as HBoxContainer
		row.add_child(_build_offer(item_id, kind))
	_sellable_ids = _run_engine.call("merchant_sellable_ids", _run_state, MERCHANT_KIND)
	_populate_sell_page()
	_update_selection_effects()

func _populate_sell_page() -> void:
	for key_var: Variant in _offer_sources.keys():
		var key: String = str(key_var)
		if key.begins_with("sell:"):
			_offer_sources.erase(key)
			_selection_effects.erase(key)
	_clear_children(_sell_row)
	var page_count: int = maxi(1, ceili(float(_sellable_ids.size()) / float(SELL_PAGE_SIZE)))
	_sell_page = clampi(_sell_page, 0, page_count - 1)
	_sell_heading.text = "SELL FROM PACK" if page_count == 1 else "SELL FROM PACK  •  %d/%d" % [_sell_page + 1, page_count]
	_sell_previous.disabled = _sell_page <= 0
	_sell_next.disabled = _sell_page >= page_count - 1
	if _sellable_ids.is_empty():
		var empty := Label.new()
		empty.text = "Nothing in your pack can be sold here."
		empty.custom_minimum_size = _sell_row.custom_minimum_size
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UiTypography.set_label_size(empty, 17)
		empty.add_theme_color_override("font_color", Color("a99b86"))
		_sell_row.add_child(empty)
	else:
		var first_index: int = _sell_page * SELL_PAGE_SIZE
		for index: int in range(first_index, mini(first_index + SELL_PAGE_SIZE, _sellable_ids.size())):
			_sell_row.add_child(_build_sell_offer(str(_sellable_ids[index])))

func _turn_sell_page(delta: int) -> void:
	_sell_page += delta
	_populate_sell_page()
	_restore_selection_after_rebuild()
	_sync_detail()
	_update_selection_effects()

func _restore_selection_after_rebuild() -> void:
	if _selected_item_id.is_empty():
		_selected_source = null
		return
	var key: String = "%s:%s" % ["sell" if _selected_is_sell else "buy", _selected_item_id]
	_selected_source = _offer_sources.get(key, null) as Control
	if _selected_source == null:
		_selected_item_id = ""
		_selected_is_sell = false
		_update_selection_effects()

func _build_offer(item_id: String, kind: String) -> Control:
	if kind == MAGIC:
		return _build_magic_offer(item_id)
	return _build_icon_offer(item_id, kind, false)

func _build_magic_offer(item_id: String) -> Control:
	var stack := VBoxContainer.new()
	stack.name = "MagicOffer_%s" % item_id
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 2)
	var selection := PanelContainer.new()
	selection.name = "SelectionEffect"
	selection.custom_minimum_size = OFFER_CARD_SIZE + Vector2(12.0, 12.0)
	selection.add_theme_stylebox_override("panel", _selection_style(false))
	stack.add_child(selection)
	var center := CenterContainer.new()
	selection.add_child(center)
	var card := CardWidgetScene.instantiate()
	card.name = "MagicCard_%s" % item_id
	card.custom_minimum_size = OFFER_CARD_SIZE
	card.configure(item_id, false, false, true, false, true, true, GameData.card_def(item_id))
	card.set_hover_pose(-12.0, 1.055)
	card.activated.connect(_select_item.bind(item_id, false, card))
	card.focus_entered.connect(_focus_item.bind(item_id, false, card))
	card.mouse_entered.connect(_hover_item.bind(item_id, card))
	card.mouse_exited.connect(_unhover_item.bind(item_id, card))
	card.ready.connect(_enable_card_focus.bind(card), CONNECT_ONE_SHOT)
	center.add_child(card)
	var affordable: bool = _offer_is_affordable(item_id, false)
	card.set_meta("shop_affordable", affordable)
	card.tooltip_text = _offer_tooltip(item_id, false, affordable)
	stack.add_child(_price_plaque(item_id, false))
	_offer_sources["buy:%s" % item_id] = card
	_selection_effects["buy:%s" % item_id] = selection
	return stack

func _build_icon_offer(item_id: String, kind: String, selling: bool) -> Control:
	var button := _raster_button("", Color("34271f"), Color("51402e"))
	button.name = "%sOffer_%s" % [kind.capitalize(), item_id]
	button.custom_minimum_size = SELL_TILE_SIZE if selling else OFFER_TILE_SIZE
	button.pressed.connect(_select_item.bind(item_id, selling, button))
	button.focus_entered.connect(_focus_item.bind(item_id, selling, button))
	button.mouse_entered.connect(_hover_item.bind(item_id, button))
	button.mouse_exited.connect(_unhover_item.bind(item_id, button))
	var affordable: bool = _offer_is_affordable(item_id, selling)
	button.set_meta("shop_affordable", affordable)
	button.tooltip_text = _offer_tooltip(item_id, selling, affordable)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(stack)
	var icon_center := CenterContainer.new()
	icon_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(icon_center)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(72.0, 72.0) if selling else Vector2(88.0, 88.0)
	icon.texture = AssetLoader.load_texture(_icon_path(item_id))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_center.add_child(icon)
	var name_label := Label.new()
	name_label.text = _item_name(item_id)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size = Vector2((SELL_TILE_SIZE.x if selling else OFFER_TILE_SIZE.x) - 18.0, 22.0)
	UiTypography.set_label_size(name_label, 14 if selling else 16)
	name_label.add_theme_color_override("font_color", Color("f0d8ad"))
	stack.add_child(name_label)
	var amount: int = int(_run_engine.call("merchant_sell_value", MERCHANT_KIND, item_id) if selling else _run_engine.call("merchant_buy_cost", MERCHANT_KIND, item_id))
	var price := Label.new()
	price.text = "VALUE %d" % amount if selling else "%d EMBERS" % amount
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(price, 14)
	price.add_theme_color_override("font_color", Color("9cdb96") if selling else Color("f2bd65"))
	stack.add_child(price)
	var key: String = "%s:%s" % ["sell" if selling else "buy", item_id]
	_offer_sources[key] = button
	_selection_effects[key] = button
	return button

func _build_sell_offer(item_id: String) -> Control:
	var kind: String = str(_run_engine.call("merchant_item_kind", item_id))
	if kind == MAGIC:
		return _build_sell_magic_offer(item_id)
	return _build_icon_offer(item_id, kind, true)

func _build_sell_magic_offer(item_id: String) -> Control:
	var stack := VBoxContainer.new()
	stack.name = "SellMagicOffer_%s" % item_id
	stack.custom_minimum_size = SELL_TILE_SIZE
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 0)
	var selection := PanelContainer.new()
	selection.name = "SelectionEffect"
	selection.custom_minimum_size = Vector2(76.0, 96.0)
	selection.add_theme_stylebox_override("panel", _selection_style(false))
	stack.add_child(selection)
	var center := CenterContainer.new()
	selection.add_child(center)
	var card := CardWidgetScene.instantiate()
	card.name = "SellMagicCard_%s" % item_id
	card.custom_minimum_size = Vector2(66.0, 92.0)
	card.configure(item_id, false, false, true, false, true, true, GameData.card_def(item_id))
	card.set_hover_pose(-5.0, 1.045)
	card.activated.connect(_select_item.bind(item_id, true, card))
	card.focus_entered.connect(_focus_item.bind(item_id, true, card))
	card.mouse_entered.connect(_hover_item.bind(item_id, card))
	card.mouse_exited.connect(_unhover_item.bind(item_id, card))
	card.ready.connect(_enable_card_focus.bind(card), CONNECT_ONE_SHOT)
	center.add_child(card)
	card.set_meta("shop_affordable", true)
	card.tooltip_text = _offer_tooltip(item_id, true, true)
	var value := Label.new()
	value.text = "VALUE %d" % int(_run_engine.call("merchant_sell_value", MERCHANT_KIND, item_id))
	value.custom_minimum_size = Vector2(SELL_TILE_SIZE.x, 20.0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(value, 13)
	value.add_theme_color_override("font_color", Color("9cdb96"))
	stack.add_child(value)
	_offer_sources["sell:%s" % item_id] = card
	_selection_effects["sell:%s" % item_id] = selection
	return stack

func _enable_card_focus(card: Control) -> void:
	# CardWidget intentionally initializes as pointer-only. Shop cards are discrete
	# choices, so opt them back into keyboard/controller focus after CardWidget._ready.
	card.focus_mode = Control.FOCUS_ALL

func _price_plaque(item_id: String, selling: bool) -> Control:
	var plaque := PanelContainer.new()
	plaque.custom_minimum_size = Vector2(126.0, 34.0)
	var cost: int = int(_run_engine.call("merchant_sell_value", MERCHANT_KIND, item_id) if selling else _run_engine.call("merchant_buy_cost", MERCHANT_KIND, item_id))
	var affordable: bool = _offer_is_affordable(item_id, selling)
	plaque.add_theme_stylebox_override("panel", _raster_style(DARK_FRAME_PATH, Color("4c3423") if affordable else Color("302b27")))
	var label := Label.new()
	label.text = "%d EMBERS" % cost
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(label, 15)
	label.add_theme_color_override("font_color", Color("f0bd65") if affordable else Color("9d9488"))
	plaque.add_child(label)
	return plaque

func _offer_is_affordable(item_id: String, selling: bool) -> bool:
	if selling or _run_engine == null:
		return true
	var cost: int = int(_run_engine.call("merchant_buy_cost", MERCHANT_KIND, item_id))
	return int(_run_engine.call("held_embers", _run_state)) >= cost

func _offer_tooltip(item_id: String, selling: bool, affordable: bool) -> String:
	var amount: int = int(_run_engine.call("merchant_sell_value", MERCHANT_KIND, item_id) if selling else _run_engine.call("merchant_buy_cost", MERCHANT_KIND, item_id))
	if selling:
		return "%s\nSell value: %d embers" % [_item_name(item_id), amount]
	if affordable:
		return "%s\nPrice: %d embers" % [_item_name(item_id), amount]
	var held: int = int(_run_engine.call("held_embers", _run_state))
	return "%s\nPrice: %d embers — need %d more" % [_item_name(item_id), amount, amount - held]

func _select_item(item_id: String, selling: bool, source: Control) -> void:
	_selected_item_id = item_id
	_selected_is_sell = selling
	_selected_source = source
	_update_selection_effects()
	_sync_detail()

func _focus_item(item_id: String, selling: bool, source: Control) -> void:
	_select_item(item_id, selling, source)
	if source != null and source.has_method("set_external_highlighted"):
		source.call("set_external_highlighted", true)

func _hover_item(item_id: String, source: Control) -> void:
	item_hovered.emit(MERCHANT_KIND, item_id, source)
	if source is Button and not (source is CardWidget):
		_animate_slot_scale(source, Vector2(1.045, 1.045))

func _unhover_item(item_id: String, source: Control) -> void:
	item_unhovered.emit(MERCHANT_KIND, item_id, source)
	if source is Button and not (source is CardWidget):
		_animate_slot_scale(source, Vector2.ONE)

func _update_selection_effects() -> void:
	for key_var: Variant in _selection_effects.keys():
		var key: String = str(key_var)
		var selected_key: String = "%s:%s" % ["sell" if _selected_is_sell else "buy", _selected_item_id]
		var control := _selection_effects.get(key) as Control
		var source := _offer_sources.get(key) as Control
		if control == null:
			continue
		var affordable: bool = true if source == null else bool(source.get_meta("shop_affordable", true))
		var base_tint := Color.WHITE if affordable else Color(0.48, 0.48, 0.48, 0.86)
		var selected_tint := Color("fff1c2") if affordable else Color(0.60, 0.56, 0.48, 0.92)
		if control is PanelContainer:
			(control as PanelContainer).add_theme_stylebox_override("panel", _selection_style(key == selected_key))
		else:
			control.modulate = selected_tint if key == selected_key else base_tint
		if source != null and source != control:
			source.modulate = selected_tint if key == selected_key else base_tint

func _sync_currency() -> void:
	if _currency_label != null:
		_currency_label.text = "EMBERS  %d" % int(_run_state.get("held_embers", 0))

func _sync_detail() -> void:
	if _detail_title == null:
		return
	if _selected_item_id.is_empty() or _run_engine == null:
		_detail_title.text = "Choose a Ware"
		_detail_kind.text = "MAGIC • GEAR • ITEMS"
		_detail_icon.texture = AssetLoader.load_texture(EMBER_ICON_PATH)
		_detail_description.text = "Inspect a shelf offer, or choose something from your pack to see its exact sale value."
		_detail_price.text = ""
		_detail_action.text = "SELECT AN OFFER"
		_detail_action.disabled = true
		_layaway_action.visible = false
		return
	var item_id: String = _selected_item_id
	var kind: String = str(_run_engine.call("merchant_item_kind", item_id))
	var amount: int = int(_run_engine.call("merchant_sell_value", MERCHANT_KIND, item_id) if _selected_is_sell else _run_engine.call("merchant_buy_cost", MERCHANT_KIND, item_id))
	var held: int = int(_run_engine.call("held_embers", _run_state))
	var affordable: bool = _selected_is_sell or held >= amount
	_detail_title.text = _item_name(item_id)
	_detail_kind.text = "%s • %s" % [kind.to_upper(), _rarity(item_id).to_upper()]
	_detail_icon.texture = AssetLoader.load_texture(_icon_path(item_id))
	_detail_description.text = _item_description(item_id)
	_detail_price.text = "VALUE %d EMBERS" % amount if _selected_is_sell else ("PRICE %d EMBERS" % amount if affordable else "NEED %d MORE EMBERS" % (amount - held))
	_detail_action.text = "SELL FOR %d" % amount if _selected_is_sell else "BUY FOR %d" % amount
	_detail_action.disabled = not affordable
	_detail_action.tooltip_text = "Sell the selected owned ware." if _selected_is_sell else ("Buy the selected ware." if affordable else "You cannot afford this ware.")
	var layaway_ready: bool = bool(_run_engine.call("run_skill_is_ready", _run_state, "layaway"))
	_layaway_action.visible = not _selected_is_sell and layaway_ready

func _on_detail_action() -> void:
	if _selected_item_id.is_empty() or _selected_source == null:
		return
	if _selected_is_sell:
		sell_requested.emit(_selected_item_id, _selected_source)
	else:
		buy_requested.emit(_selected_item_id, _selected_source)

func _on_layaway_action() -> void:
	if not _selected_item_id.is_empty() and not _selected_is_sell:
		reserve_requested.emit(_selected_item_id)

func _item_name(item_id: String) -> String:
	if _run_engine != null and str(_run_engine.call("merchant_item_kind", item_id)) == GEAR:
		return str(GameData.equipment_def(item_id).get("name", item_id))
	return str(GameData.card_def(item_id).get("name", item_id))

func _item_description(item_id: String) -> String:
	var kind: String = str(_run_engine.call("merchant_item_kind", item_id)) if _run_engine != null else ""
	if kind == GEAR:
		var equipment: Dictionary = GameData.equipment_def(item_id)
		var cards: Array = []
		for card_id_var: Variant in GameData.equipment_cards(item_id):
			cards.append(str(GameData.card_def(str(card_id_var)).get("name", card_id_var)))
		var card_text: String = "\nGrants: %s" % ", ".join(cards) if not cards.is_empty() else ""
		return "%s slot.%s" % [str(equipment.get("slot", "gear")).capitalize(), card_text]
	return str(GameData.card_def(item_id).get("description", ""))

func _rarity(item_id: String) -> String:
	return GameData.equipment_rarity(item_id) if _run_engine != null and str(_run_engine.call("merchant_item_kind", item_id)) == GEAR else GameData.card_rarity(item_id)

func _icon_path(item_id: String) -> String:
	var kind: String = str(_run_engine.call("merchant_item_kind", item_id)) if _run_engine != null else ""
	if kind == GEAR:
		return str(GameData.equipment_def(item_id).get("icon_path", ""))
	if kind == ITEM:
		return GameData.item_icon_path(item_id)
	return str(GameData.card_def(item_id).get("art_path", ""))

func _play_entry() -> void:
	if not visible or _canvas == null:
		return
	_entry_played_for_room = true
	if _reduced_motion:
		_canvas.modulate = Color.WHITE
		_canvas.scale = Vector2.ONE * _canvas.scale.x
		_portrait.position.x = 42.0
		for group: Control in _animated_groups:
			group.modulate = Color.WHITE
		return
	_canvas.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var base_scale: Vector2 = _canvas.scale
	_canvas.scale = base_scale * 0.985
	_portrait.position.x = -36.0
	for index: int in range(_animated_groups.size()):
		var group: Control = _animated_groups[index]
		group.modulate = Color(1.0, 1.0, 1.0, 0.0)
		group.position.x += 32.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_canvas, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_canvas, "scale", base_scale, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_portrait, "position:x", 42.0, 0.34).set_delay(0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for index: int in range(_animated_groups.size()):
		var group: Control = _animated_groups[index]
		var target_x: float = 610.0
		tween.tween_property(group, "position:x", target_x, 0.24).set_delay(0.08 + index * 0.07).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(group, "modulate:a", 1.0, 0.20).set_delay(0.08 + index * 0.07)

func _process(delta: float) -> void:
	if not visible or _portrait == null or _reduced_motion:
		return
	_ambient_time += delta
	_portrait.position.y = 170.0 + sin(_ambient_time * 1.15) * 3.0
	_portrait.rotation = sin(_ambient_time * 0.72) * 0.003

func _animate_slot_scale(control: Control, target: Vector2) -> void:
	if control == null or _reduced_motion:
		if control != null:
			control.scale = target
		return
	control.pivot_offset = control.size * 0.5
	create_tween().tween_property(control, "scale", target, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _layout_canvas() -> void:
	if _canvas == null:
		return
	var fit: float = minf(size.x / REFERENCE_SIZE.x, size.y / REFERENCE_SIZE.y)
	_canvas.scale = Vector2.ONE * fit
	_canvas.position = (size - REFERENCE_SIZE * fit) * 0.5

func _raster_panel(path: String, tint: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _raster_style(path, tint))
	return panel

func _raster_button(text_value: String, normal_tint: Color, hover_tint: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("normal", _raster_style(DARK_FRAME_PATH, normal_tint))
	button.add_theme_stylebox_override("hover", _raster_style(DARK_FRAME_PATH, hover_tint))
	button.add_theme_stylebox_override("pressed", _raster_style(DARK_FRAME_PATH, hover_tint.darkened(0.18)))
	button.add_theme_stylebox_override("focus", _selection_style(true))
	button.add_theme_stylebox_override("disabled", _raster_style(DARK_FRAME_PATH, Color("292724")))
	button.add_theme_color_override("font_color", Color("f1d39a"))
	button.add_theme_color_override("font_hover_color", Color("fff0bd"))
	button.add_theme_color_override("font_focus_color", Color("fff0bd"))
	button.add_theme_color_override("font_disabled_color", Color("857d70"))
	button.add_theme_color_override("font_outline_color", Color("170e09"))
	button.add_theme_constant_override("outline_size", 2)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return button

func _raster_style(path: String, tint: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = AssetLoader.load_texture(path)
	style.modulate_color = tint
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 18.0)
		style.set_content_margin(side, 12.0)
	return style

func _selection_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.20, 0.13, 0.07, 0.12 if selected else 0.0)
	style.border_color = Color("f5c867") if selected else Color.TRANSPARENT
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_border_width(side, 4 if selected else 0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(1.0, 0.55, 0.12, 0.26) if selected else Color.TRANSPARENT
	style.shadow_size = 14 if selected else 0
	return style

func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
	control.custom_minimum_size = rect.size

func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()

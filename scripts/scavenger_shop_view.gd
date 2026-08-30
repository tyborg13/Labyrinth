extends Control
class_name ScavengerShopView

signal buy_requested(item_id: String, source: Control)
signal sell_requested(item_id: String, source: Control)
signal leave_requested
signal item_hovered(merchant_kind: String, item_id: String, source: Control)
signal item_unhovered(merchant_kind: String, item_id: String, source: Control)

const AssetLoader = preload("res://scripts/asset_loader.gd")
const CardWidgetScene = preload("res://scenes/card_widget.tscn")
const GameData = preload("res://scripts/game_data.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

const REFERENCE_SIZE := Vector2(1920.0, 1080.0)
const BACKDROP_PATH := "res://assets/art/ui/scavenger_shop/stall_backdrop_v2.png"
const SCAVENGER_PATH := "res://assets/art/npcs/scavenger.png"
const DARK_FRAME_PATH := "res://assets/art/ui/panel_silver_inset.png"
const INSPECTION_FRAME_PATH := "res://assets/art/ui/scavenger_shop/inspection_frame_v1.png"
const MAGIC := "magic"
const GEAR := "gear"
const ITEM := "item"
const MERCHANT_KIND := "scavenger"
const NATIVE_CARD_SIZE := Vector2(250.0, 352.0)
const OFFER_CARD_SIZE := Vector2(154.0, 216.0)
const OFFER_TILE_SIZE := Vector2(196.0, 170.0)
const SELL_TILE_SIZE := Vector2(218.0, 192.0)
const SELL_PAGE_SIZE: int = 2
const SHELF_LEFT: float = 655.0
const SHELF_WIDTH: float = 840.0
# The stall raster is drawn in shallow perspective: its post-to-post cubbies
# follow a 260 px cadence, centered at 815/1075/1335 on the 1920 px canvas.
const SHELF_SLOT_WIDTH: float = 260.0
const PORTRAIT_BASE_POSITION := Vector2(-82.0, 8.0)

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
var _portrait_clip: Control
var _portrait: TextureRect
var _counter_occluder: Control
var _title_panel: PanelContainer
var _currency_panel: PanelContainer
var _currency_label: Label
var _magic_group: Control
var _gear_group: Control
var _item_group: Control
var _detail_panel: Control
var _detail_title: Label
var _detail_kind: Label
var _detail_card_host: CenterContainer
var _detail_card_nav: HBoxContainer
var _detail_card_previous: Button
var _detail_card_counter: Label
var _detail_card_next: Button
var _detail_price: Label
var _detail_action: Button
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
var _detail_card_ids: Array[String] = []
var _detail_card_index: int = 0
var _slot_tweens: Dictionary = {}

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
		"detail_card_ids": _detail_card_ids.duplicate(),
		"detail_card_index": _detail_card_index,
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

	_portrait_clip = Control.new()
	_portrait_clip.name = "MerchantAlcovePortraitClip"
	_place(_portrait_clip, Rect2(0.0, 70.0, 640.0, 610.0))
	_portrait_clip.clip_contents = true
	_portrait_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_portrait_clip)

	_portrait = TextureRect.new()
	_portrait.name = "ScavengerPortrait"
	_place(_portrait, Rect2(PORTRAIT_BASE_POSITION, Vector2(800.0, 800.0)))
	_portrait.texture = AssetLoader.load_texture(SCAVENGER_PATH)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.pivot_offset = _portrait.size * 0.55
	_portrait_clip.add_child(_portrait)

	# Repaint the counter from the architectural raster above the portrait. This
	# makes the merchant stand inside the stall instead of reading as a sticker
	# pasted over it, while the backdrop remains a separately authored layer.
	_counter_occluder = Control.new()
	_counter_occluder.name = "ForegroundCounterOccluder"
	_place(_counter_occluder, Rect2(0.0, 636.0, 640.0, 338.0))
	_counter_occluder.clip_contents = true
	_counter_occluder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_counter_occluder)
	var counter_raster := TextureRect.new()
	_place(counter_raster, Rect2(0.0, -636.0, REFERENCE_SIZE.x, REFERENCE_SIZE.y))
	counter_raster.texture = AssetLoader.load_texture(BACKDROP_PATH)
	counter_raster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	counter_raster.stretch_mode = TextureRect.STRETCH_SCALE
	counter_raster.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	counter_raster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_counter_occluder.add_child(counter_raster)

	_title_panel = _raster_panel(DARK_FRAME_PATH, Color("4a3425"))
	_title_panel.name = "ScavengerWaresTitlePanel"
	_place(_title_panel, Rect2(600.0, 28.0, 870.0, 92.0))
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
	_place(_currency_panel, Rect2(1495.0, 38.0, 385.0, 72.0))
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

	_magic_group = _build_category_group("MAGIC", Rect2(SHELF_LEFT, 132.0, SHELF_WIDTH, 306.0))
	_gear_group = _build_category_group("GEAR", Rect2(SHELF_LEFT, 404.0, SHELF_WIDTH, 252.0))
	_item_group = _build_category_group("ITEMS", Rect2(SHELF_LEFT, 630.0, SHELF_WIDTH, 260.0))
	_animated_groups = [_magic_group, _gear_group, _item_group]

	_detail_panel = Control.new()
	_detail_panel.name = "ScavengerDetailPanel"
	_place(_detail_panel, Rect2(1475.0, 160.0, 420.0, 630.0))
	_detail_panel.clip_contents = true
	_canvas.add_child(_detail_panel)
	var detail_frame := TextureRect.new()
	detail_frame.name = "ScavengerInspectionFrameRaster"
	_place(detail_frame, Rect2(Vector2.ZERO, _detail_panel.size))
	detail_frame.texture = AssetLoader.load_texture(INSPECTION_FRAME_PATH)
	detail_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_frame.stretch_mode = TextureRect.STRETCH_SCALE
	detail_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	detail_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_panel.add_child(detail_frame)
	_build_detail_content()

	_sell_panel = _raster_panel(DARK_FRAME_PATH, Color("463226"))
	_sell_panel.name = "SellFromPackPanel"
	_place(_sell_panel, Rect2(16.0, 700.0, 608.0, 318.0))
	_canvas.add_child(_sell_panel)
	_build_sell_content()

	_leave_button = _raster_button("LEAVE", Color("6e2d24"), Color("9a4735"))
	_leave_button.name = "ScavengerLeaveButton"
	_place(_leave_button, Rect2(1540.0, 920.0, 310.0, 82.0))
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
	_place(plaque, Rect2(-120.0, 0.0, 150.0, 44.0))
	plaque.add_theme_stylebox_override("panel", _raster_style(DARK_FRAME_PATH, Color("4b3526")))
	group.add_child(plaque)
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(label, 22)
	label.add_theme_color_override("font_color", Color("efd39d"))
	label.add_theme_color_override("font_outline_color", Color("180e08"))
	label.add_theme_constant_override("outline_size", 3)
	plaque.add_child(label)
	var row := HBoxContainer.new()
	row.name = "OfferRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	_place(row, Rect2(0.0, 38.0, rect.size.x, rect.size.y - 38.0))
	group.add_child(row)
	return group

func _build_detail_content() -> void:
	var margin := MarginContainer.new()
	margin.name = "ScavengerInspectionContentMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 38)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_right", 38)
	margin.add_theme_constant_override("margin_bottom", 32)
	_detail_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.name = "ScavengerInspectionContent"
	stack.add_theme_constant_override("separation", 7)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(stack)
	_detail_title = Label.new()
	_detail_title.name = "ScavengerDetailTitle"
	_detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_detail_title.custom_minimum_size = Vector2(0.0, 42.0)
	UiTypography.set_label_size(_detail_title, 25)
	_detail_title.add_theme_color_override("font_color", Color("f2d49d"))
	_detail_title.add_theme_color_override("font_outline_color", Color("120b08"))
	_detail_title.add_theme_constant_override("outline_size", 3)
	stack.add_child(_detail_title)
	_detail_kind = Label.new()
	_detail_kind.name = "ScavengerDetailKind"
	_detail_kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_kind.custom_minimum_size = Vector2(0.0, 22.0)
	UiTypography.set_label_size(_detail_kind, 15)
	_detail_kind.add_theme_color_override("font_color", Color("b8a78e"))
	stack.add_child(_detail_kind)
	var separator := HSeparator.new()
	stack.add_child(separator)
	_detail_card_host = CenterContainer.new()
	_detail_card_host.name = "ScavengerDetailCardHost"
	_detail_card_host.custom_minimum_size = Vector2(0.0, 312.0)
	_detail_card_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_detail_card_host)
	_detail_card_nav = HBoxContainer.new()
	_detail_card_nav.name = "ScavengerGrantedCardNavigator"
	_detail_card_nav.custom_minimum_size = Vector2(0.0, 42.0)
	_detail_card_nav.alignment = BoxContainer.ALIGNMENT_CENTER
	_detail_card_nav.add_theme_constant_override("separation", 8)
	stack.add_child(_detail_card_nav)
	_detail_card_previous = _raster_button("‹", Color("30251e"), Color("56402c"))
	_detail_card_previous.name = "ScavengerPreviousGrantedCard"
	_detail_card_previous.custom_minimum_size = Vector2(48.0, 40.0)
	UiTypography.set_button_size(_detail_card_previous, 24)
	_detail_card_previous.tooltip_text = "Show the previous card granted by this gear."
	_detail_card_previous.pressed.connect(_turn_detail_card.bind(-1))
	_detail_card_nav.add_child(_detail_card_previous)
	_detail_card_counter = Label.new()
	_detail_card_counter.name = "ScavengerGrantedCardCounter"
	_detail_card_counter.custom_minimum_size = Vector2(220.0, 40.0)
	_detail_card_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_card_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(_detail_card_counter, 15)
	_detail_card_counter.add_theme_color_override("font_color", Color("d9c6a6"))
	_detail_card_nav.add_child(_detail_card_counter)
	_detail_card_next = _raster_button("›", Color("30251e"), Color("56402c"))
	_detail_card_next.name = "ScavengerNextGrantedCard"
	_detail_card_next.custom_minimum_size = Vector2(48.0, 40.0)
	UiTypography.set_button_size(_detail_card_next, 24)
	_detail_card_next.tooltip_text = "Show the next card granted by this gear."
	_detail_card_next.pressed.connect(_turn_detail_card.bind(1))
	_detail_card_nav.add_child(_detail_card_next)
	_detail_price = Label.new()
	_detail_price.name = "ScavengerDetailPrice"
	_detail_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_price.custom_minimum_size = Vector2(0.0, 30.0)
	UiTypography.set_label_size(_detail_price, 18)
	_detail_price.add_theme_color_override("font_color", Color("efbd67"))
	stack.add_child(_detail_price)
	_detail_action = _raster_button("BUY", Color("214459"), Color("2e6985"))
	_detail_action.name = "ScavengerTradeActionButton"
	_detail_action.custom_minimum_size = Vector2(0.0, 58.0)
	UiTypography.set_button_size(_detail_action, 23)
	_detail_action.pressed.connect(_on_detail_action)
	stack.add_child(_detail_action)
	_detail_card_nav.visible = false

func _build_sell_content() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	_sell_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	_sell_heading = Label.new()
	_sell_heading.text = "SELL FROM PACK"
	_sell_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(_sell_heading, 25)
	_sell_heading.add_theme_color_override("font_color", Color("efd39d"))
	_sell_heading.add_theme_color_override("font_outline_color", Color("170d08"))
	_sell_heading.add_theme_constant_override("outline_size", 3)
	stack.add_child(_sell_heading)
	var instruction := Label.new()
	instruction.text = "Choose a ware • review its exact value on the right"
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTypography.set_label_size(instruction, 16)
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
	_sell_previous.custom_minimum_size = Vector2(36.0, SELL_TILE_SIZE.y)
	UiTypography.set_button_size(_sell_previous, 26)
	_sell_previous.tooltip_text = "Previous pack page."
	_sell_previous.pressed.connect(_turn_sell_page.bind(-1))
	pager.add_child(_sell_previous)
	_sell_row = HBoxContainer.new()
	_sell_row.name = "SellInventoryRow"
	_sell_row.custom_minimum_size = Vector2(SELL_TILE_SIZE.x * SELL_PAGE_SIZE + 12.0 * (SELL_PAGE_SIZE - 1), SELL_TILE_SIZE.y)
	_sell_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_sell_row.add_theme_constant_override("separation", 12)
	pager.add_child(_sell_row)
	_sell_next = _raster_button("›", Color("34271f"), Color("57422e"))
	_sell_next.name = "SellNextPage"
	_sell_next.custom_minimum_size = Vector2(36.0, SELL_TILE_SIZE.y)
	UiTypography.set_button_size(_sell_next, 26)
	_sell_next.tooltip_text = "Next pack page."
	_sell_next.pressed.connect(_turn_sell_page.bind(1))
	pager.add_child(_sell_next)

func _rebuild_inventory() -> void:
	if _run_engine == null or _magic_group == null:
		return
	_slot_tweens.clear()
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
		var shelf_slot := CenterContainer.new()
		shelf_slot.name = "ShelfCubby_%s" % item_id
		shelf_slot.custom_minimum_size = Vector2(SHELF_SLOT_WIDTH, row.size.y)
		shelf_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		shelf_slot.add_child(_build_offer(item_id, kind))
		row.add_child(shelf_slot)
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
	var button := _shelf_offer_button()
	button.name = "MagicOffer_%s" % item_id
	button.custom_minimum_size = Vector2(196.0, 264.0)
	_wire_offer_button(button, item_id, false)
	var stack := VBoxContainer.new()
	stack.name = "MagicOfferContent_%s" % item_id
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_centered_button_content(button, stack)
	var center := CenterContainer.new()
	center.custom_minimum_size = OFFER_CARD_SIZE + Vector2(12.0, 8.0)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(center)
	_build_native_scaled_card(center, item_id, OFFER_CARD_SIZE, "MagicCard", false)
	stack.add_child(_price_plaque(item_id, false))
	_make_mouse_passive(stack)
	_offer_sources["buy:%s" % item_id] = button
	_selection_effects["buy:%s" % item_id] = button
	return button

func _build_icon_offer(item_id: String, kind: String, selling: bool) -> Control:
	var button := _raster_button("", Color("34271f"), Color("51402e")) if selling else _shelf_offer_button()
	button.name = "%sOffer_%s" % [kind.capitalize(), item_id]
	button.custom_minimum_size = SELL_TILE_SIZE if selling else OFFER_TILE_SIZE
	_wire_offer_button(button, item_id, selling)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_centered_button_content(button, stack)
	var icon_center := CenterContainer.new()
	icon_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(icon_center)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(112.0, 112.0)
	icon.texture = AssetLoader.load_texture(_icon_path(item_id))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_center.add_child(icon)
	var caption_parent: Container = stack
	if not selling:
		var caption := _raster_panel(DARK_FRAME_PATH, Color("3d2b20"))
		caption.custom_minimum_size = Vector2(178.0, 50.0)
		stack.add_child(caption)
		var caption_stack := VBoxContainer.new()
		caption_stack.alignment = BoxContainer.ALIGNMENT_CENTER
		caption_stack.add_theme_constant_override("separation", 0)
		caption.add_child(caption_stack)
		caption_parent = caption_stack
	var name_label := Label.new()
	name_label.text = _item_name(item_id)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size = Vector2((SELL_TILE_SIZE.x if selling else 178.0) - 18.0, 22.0)
	UiTypography.set_label_size(name_label, 16)
	name_label.add_theme_color_override("font_color", Color("f0d8ad"))
	caption_parent.add_child(name_label)
	var amount: int = int(_run_engine.call("merchant_sell_value", MERCHANT_KIND, item_id) if selling else _run_engine.call("merchant_buy_cost", MERCHANT_KIND, item_id))
	var price := Label.new()
	price.text = "VALUE %d" % amount if selling else "%d EMBERS" % amount
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(price, 15)
	price.add_theme_color_override("font_color", Color("9cdb96") if selling else Color("f2bd65"))
	caption_parent.add_child(price)
	_make_mouse_passive(stack)
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
	var button := _raster_button("", Color("34271f"), Color("51402e"))
	button.name = "SellMagicOffer_%s" % item_id
	button.custom_minimum_size = SELL_TILE_SIZE
	_wire_offer_button(button, item_id, true)
	var stack := VBoxContainer.new()
	stack.name = "SellMagicOfferContent_%s" % item_id
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 0)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_centered_button_content(button, stack)
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(122.0, 166.0)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(center)
	_build_native_scaled_card(center, item_id, Vector2(112.0, 156.0), "SellMagicCard", false)
	var value := Label.new()
	value.text = "VALUE %d" % int(_run_engine.call("merchant_sell_value", MERCHANT_KIND, item_id))
	value.custom_minimum_size = Vector2(SELL_TILE_SIZE.x, 24.0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(value, 15)
	value.add_theme_color_override("font_color", Color("9cdb96"))
	stack.add_child(value)
	_make_mouse_passive(stack)
	_offer_sources["sell:%s" % item_id] = button
	_selection_effects["sell:%s" % item_id] = button
	return button

func _build_native_scaled_card(
	container: Control,
	item_id: String,
	visual_size: Vector2,
	name_prefix: String,
	interactive: bool
) -> CardWidget:
	# CardWidget's art crop, title fitting, and raster nameplate are authored at
	# 250x352. Keep that complete composition intact, then scale an intermediary
	# transform to the shelf size. Resizing CardWidget itself asks its compact
	# layout to redistribute those pieces and can separate the title from the
	# nameplate even though the outer frame looks correctly sized.
	var visual_root := Control.new()
	visual_root.name = "%sVisualRoot_%s" % [name_prefix, item_id]
	visual_root.custom_minimum_size = visual_size
	visual_root.size = visual_size
	visual_root.mouse_filter = Control.MOUSE_FILTER_PASS if interactive else Control.MOUSE_FILTER_IGNORE
	container.add_child(visual_root)
	var composition_root := Control.new()
	composition_root.name = "NativeCardComposition"
	composition_root.size = NATIVE_CARD_SIZE
	composition_root.mouse_filter = Control.MOUSE_FILTER_PASS if interactive else Control.MOUSE_FILTER_IGNORE
	var fit: float = minf(visual_size.x / NATIVE_CARD_SIZE.x, visual_size.y / NATIVE_CARD_SIZE.y)
	composition_root.scale = Vector2.ONE * fit
	composition_root.position = (visual_size - NATIVE_CARD_SIZE * fit) * 0.5
	visual_root.add_child(composition_root)
	var card := CardWidgetScene.instantiate() as CardWidget
	card.name = "%s_%s" % [name_prefix, item_id]
	_place(card, Rect2(Vector2.ZERO, NATIVE_CARD_SIZE))
	card.configure(item_id, false, false, true, false, interactive, true, GameData.card_def(item_id))
	if interactive:
		card.set_hover_pose(-5.0, 1.025)
	composition_root.add_child(card)
	return card

func _wire_offer_button(button: Button, item_id: String, selling: bool) -> void:
	button.clip_contents = false
	button.pressed.connect(_select_item.bind(item_id, selling, button))
	button.focus_entered.connect(_focus_item.bind(item_id, selling, button))
	button.focus_exited.connect(_offer_focus_exited.bind(button))
	button.mouse_entered.connect(_hover_item.bind(item_id, button))
	button.mouse_exited.connect(_unhover_item.bind(item_id, button))
	var affordable: bool = _offer_is_affordable(item_id, selling)
	button.set_meta("shop_affordable", affordable)
	button.set_meta("shop_pointer_hovered", false)
	button.tooltip_text = _offer_tooltip(item_id, selling, affordable)

func _add_centered_button_content(button: Button, content: Control) -> void:
	var center := CenterContainer.new()
	center.name = "CenteredOfferContent"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(center)
	center.add_child(content)

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
	var selection_changed: bool = item_id != _selected_item_id or selling != _selected_is_sell
	_selected_item_id = item_id
	_selected_is_sell = selling
	_selected_source = source
	if selection_changed:
		_detail_card_index = 0
	_update_selection_effects()
	_sync_detail()

func _focus_item(item_id: String, selling: bool, source: Control) -> void:
	_select_item(item_id, selling, source)
	_set_offer_emphasis(source, true)

func _offer_focus_exited(source: Control) -> void:
	_set_offer_emphasis(source, bool(source.get_meta("shop_pointer_hovered", false)) if source != null else false)

func _hover_item(item_id: String, source: Control) -> void:
	item_hovered.emit(MERCHANT_KIND, item_id, source)
	if source != null:
		source.set_meta("shop_pointer_hovered", true)
	_set_offer_emphasis(source, true)

func _unhover_item(item_id: String, source: Control) -> void:
	item_unhovered.emit(MERCHANT_KIND, item_id, source)
	if source != null:
		source.set_meta("shop_pointer_hovered", false)
	_set_offer_emphasis(source, source.has_focus() if source != null else false)

func _set_offer_emphasis(source: Control, emphasized: bool) -> void:
	if source == null:
		return
	source.z_index = 10 if emphasized else 0
	_animate_slot_scale(source, Vector2(1.045, 1.045) if emphasized else Vector2.ONE)

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
		_detail_title.text = "SELECT A WARE"
		_detail_kind.text = "MAGIC • GEAR • ITEMS"
		_detail_card_ids.clear()
		_detail_card_index = 0
		_clear_children(_detail_card_host)
		_detail_card_nav.visible = false
		_detail_price.text = ""
		_detail_action.text = "SELECT AN OFFER"
		_detail_action.disabled = true
		_configure_focus_neighbors()
		return
	var item_id: String = _selected_item_id
	var kind: String = str(_run_engine.call("merchant_item_kind", item_id))
	var amount: int = int(_run_engine.call("merchant_sell_value", MERCHANT_KIND, item_id) if _selected_is_sell else _run_engine.call("merchant_buy_cost", MERCHANT_KIND, item_id))
	var held: int = int(_run_engine.call("held_embers", _run_state))
	var affordable: bool = _selected_is_sell or held >= amount
	_detail_title.text = _item_name(item_id)
	_detail_card_ids.clear()
	if kind == GEAR:
		for card_id_var: Variant in GameData.equipment_cards(item_id):
			_detail_card_ids.append(str(card_id_var))
		var equipment: Dictionary = GameData.equipment_def(item_id)
		var slot_name: String = str(equipment.get("slot", "gear")).to_upper()
		var card_count_text: String = "%d CARD%s" % [_detail_card_ids.size(), "" if _detail_card_ids.size() == 1 else "S"]
		_detail_kind.text = "GEAR • %s • %s • %s" % [slot_name, _rarity(item_id).to_upper(), card_count_text]
	else:
		_detail_card_ids.append(item_id)
		_detail_kind.text = "%s • %s" % [kind.to_upper(), _rarity(item_id).to_upper()]
	_render_detail_card()
	_detail_price.text = "VALUE %d EMBERS" % amount if _selected_is_sell else ("PRICE %d EMBERS" % amount if affordable else "NEED %d MORE EMBERS" % (amount - held))
	_detail_action.text = "SELL FOR %d" % amount if _selected_is_sell else "BUY FOR %d" % amount
	_detail_action.disabled = not affordable
	_detail_action.tooltip_text = "Sell the selected owned ware." if _selected_is_sell else ("Buy the selected ware." if affordable else "You cannot afford this ware.")
	_configure_focus_neighbors()

func _render_detail_card() -> void:
	if _detail_card_host == null:
		return
	_clear_children(_detail_card_host)
	if _detail_card_ids.is_empty():
		_detail_card_nav.visible = false
		return
	_detail_card_index = clampi(_detail_card_index, 0, _detail_card_ids.size() - 1)
	var card_id: String = _detail_card_ids[_detail_card_index]
	_build_native_scaled_card(_detail_card_host, card_id, Vector2(220.0, 310.0), "DetailCard", false)
	var multiple_cards: bool = _detail_card_ids.size() > 1
	_detail_card_nav.visible = multiple_cards
	if multiple_cards:
		_detail_card_counter.text = "GRANTED CARD  %d / %d" % [_detail_card_index + 1, _detail_card_ids.size()]
		_detail_card_previous.disabled = false
		_detail_card_next.disabled = false

func _turn_detail_card(delta: int) -> void:
	if _detail_card_ids.size() <= 1:
		return
	_detail_card_index = posmod(_detail_card_index + delta, _detail_card_ids.size())
	_render_detail_card()

func _on_detail_action() -> void:
	if _selected_item_id.is_empty() or _selected_source == null:
		return
	if _selected_is_sell:
		sell_requested.emit(_selected_item_id, _selected_source)
	else:
		buy_requested.emit(_selected_item_id, _selected_source)

func _item_name(item_id: String) -> String:
	if _run_engine != null and str(_run_engine.call("merchant_item_kind", item_id)) == GEAR:
		return str(GameData.equipment_def(item_id).get("name", item_id))
	return str(GameData.card_def(item_id).get("name", item_id))

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
		_portrait.position = PORTRAIT_BASE_POSITION
		for group: Control in _animated_groups:
			group.modulate = Color.WHITE
		return
	_canvas.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var base_scale: Vector2 = _canvas.scale
	_canvas.scale = base_scale * 0.985
	_portrait.position.x = PORTRAIT_BASE_POSITION.x - 78.0
	for index: int in range(_animated_groups.size()):
		var group: Control = _animated_groups[index]
		group.modulate = Color(1.0, 1.0, 1.0, 0.0)
		group.position.x += 32.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_canvas, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_canvas, "scale", base_scale, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_portrait, "position:x", PORTRAIT_BASE_POSITION.x, 0.34).set_delay(0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for index: int in range(_animated_groups.size()):
		var group: Control = _animated_groups[index]
		var target_x: float = SHELF_LEFT
		tween.tween_property(group, "position:x", target_x, 0.24).set_delay(0.08 + index * 0.07).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(group, "modulate:a", 1.0, 0.20).set_delay(0.08 + index * 0.07)

func _process(delta: float) -> void:
	if not visible or _portrait == null or _reduced_motion:
		return
	_ambient_time += delta
	_portrait.position.y = PORTRAIT_BASE_POSITION.y + sin(_ambient_time * 1.15) * 3.0
	_portrait.rotation = sin(_ambient_time * 0.72) * 0.003

func _animate_slot_scale(control: Control, target: Vector2) -> void:
	if control == null:
		return
	var tween_key: int = control.get_instance_id()
	var previous_tween: Tween = _slot_tweens.get(tween_key, null) as Tween
	if previous_tween != null and previous_tween.is_valid():
		previous_tween.kill()
	if _reduced_motion:
		control.scale = Vector2.ONE
		return
	control.pivot_offset = control.size * 0.5
	var tween: Tween = create_tween()
	_slot_tweens[tween_key] = tween
	tween.tween_property(control, "scale", target, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _configure_focus_neighbors() -> void:
	if not is_inside_tree() or _run_engine == null:
		return
	var rows: Dictionary = {
		MAGIC: _buy_offer_controls(MAGIC),
		GEAR: _buy_offer_controls(GEAR),
		ITEM: _buy_offer_controls(ITEM),
	}
	var magic_row: Array[Control] = rows[MAGIC] as Array[Control]
	var gear_row: Array[Control] = rows[GEAR] as Array[Control]
	var item_row: Array[Control] = rows[ITEM] as Array[Control]
	var sell_row: Array[Control] = _visible_sell_offer_controls()
	var detail_entry: Control = _detail_card_previous if _detail_card_nav.visible else (_detail_action if not _detail_action.disabled else _leave_button)
	_configure_offer_row(magic_row, [], gear_row, null, detail_entry)
	_configure_offer_row(gear_row, magic_row, item_row, null, detail_entry)
	_configure_offer_row(item_row, gear_row, [], sell_row.back() if not sell_row.is_empty() else null, detail_entry)

	if not sell_row.is_empty():
		for index: int in range(sell_row.size()):
			var offer: Control = sell_row[index]
			var left_target: Control = sell_row[index - 1] if index > 0 else (_sell_previous if not _sell_previous.disabled else offer)
			var right_target: Control = sell_row[index + 1] if index + 1 < sell_row.size() else (_sell_next if not _sell_next.disabled else (item_row[0] if not item_row.is_empty() else offer))
			_set_focus_neighbor(offer, SIDE_LEFT, left_target)
			_set_focus_neighbor(offer, SIDE_RIGHT, right_target)
			_set_focus_neighbor(offer, SIDE_TOP, item_row[mini(index, item_row.size() - 1)] if not item_row.is_empty() else offer)
			_set_focus_neighbor(offer, SIDE_BOTTOM, offer)
	if _sell_previous != null:
		_set_focus_neighbor(_sell_previous, SIDE_RIGHT, sell_row[0] if not sell_row.is_empty() else _sell_next)
		_set_focus_neighbor(_sell_previous, SIDE_TOP, item_row[0] if not item_row.is_empty() else _sell_previous)
	if _sell_next != null:
		_set_focus_neighbor(_sell_next, SIDE_LEFT, sell_row.back() if not sell_row.is_empty() else _sell_previous)
		_set_focus_neighbor(_sell_next, SIDE_RIGHT, item_row[0] if not item_row.is_empty() else _sell_next)
		_set_focus_neighbor(_sell_next, SIDE_TOP, item_row[0] if not item_row.is_empty() else _sell_next)

	var selected_row: Array[Control] = rows.get(_selected_kind(), item_row) as Array[Control]
	var selected_row_edge: Control = selected_row.back() if not selected_row.is_empty() else _leave_button
	if _detail_card_previous != null:
		_set_focus_neighbor(_detail_card_previous, SIDE_LEFT, selected_row_edge)
		_set_focus_neighbor(_detail_card_previous, SIDE_RIGHT, _detail_card_next)
		_set_focus_neighbor(_detail_card_previous, SIDE_BOTTOM, _detail_action)
	if _detail_card_next != null:
		_set_focus_neighbor(_detail_card_next, SIDE_LEFT, _detail_card_previous)
		_set_focus_neighbor(_detail_card_next, SIDE_RIGHT, _detail_action)
		_set_focus_neighbor(_detail_card_next, SIDE_BOTTOM, _detail_action)
	if _detail_action != null:
		_set_focus_neighbor(_detail_action, SIDE_LEFT, selected_row_edge)
		_set_focus_neighbor(_detail_action, SIDE_TOP, _detail_card_next if _detail_card_nav.visible else selected_row_edge)
		_set_focus_neighbor(_detail_action, SIDE_BOTTOM, _leave_button)
		_set_focus_neighbor(_detail_action, SIDE_RIGHT, _leave_button)
	if _leave_button != null:
		_set_focus_neighbor(_leave_button, SIDE_TOP, _detail_action if not _detail_action.disabled else selected_row_edge)
		_set_focus_neighbor(_leave_button, SIDE_LEFT, item_row.back() if not item_row.is_empty() else selected_row_edge)

func _configure_offer_row(
	row: Array[Control],
	row_above: Array[Control],
	row_below: Array[Control],
	left_exit: Control,
	right_exit: Control
) -> void:
	for index: int in range(row.size()):
		var offer: Control = row[index]
		_set_focus_neighbor(offer, SIDE_LEFT, row[index - 1] if index > 0 else (left_exit if left_exit != null else offer))
		_set_focus_neighbor(offer, SIDE_RIGHT, row[index + 1] if index + 1 < row.size() else (right_exit if right_exit != null else offer))
		_set_focus_neighbor(offer, SIDE_TOP, row_above[mini(index, row_above.size() - 1)] if not row_above.is_empty() else offer)
		_set_focus_neighbor(offer, SIDE_BOTTOM, row_below[mini(index, row_below.size() - 1)] if not row_below.is_empty() else offer)

func _buy_offer_controls(kind: String) -> Array[Control]:
	var result: Array[Control]
	for offer_var: Variant in _run_engine.call("merchant_offer_ids", _run_state, MERCHANT_KIND):
		var item_id: String = str(offer_var)
		if str(_run_engine.call("merchant_item_kind", item_id)) != kind:
			continue
		var offer: Control = _offer_sources.get("buy:%s" % item_id, null) as Control
		if offer != null:
			result.append(offer)
	return result

func _visible_sell_offer_controls() -> Array[Control]:
	var result: Array[Control]
	var first_index: int = _sell_page * SELL_PAGE_SIZE
	for index: int in range(first_index, mini(first_index + SELL_PAGE_SIZE, _sellable_ids.size())):
		var offer: Control = _offer_sources.get("sell:%s" % str(_sellable_ids[index]), null) as Control
		if offer != null:
			result.append(offer)
	return result

func _selected_kind() -> String:
	if _selected_item_id.is_empty() or _run_engine == null:
		return ITEM
	return str(_run_engine.call("merchant_item_kind", _selected_item_id))

func _set_focus_neighbor(source: Control, side: int, target: Control) -> void:
	if source == null or target == null or not source.is_inside_tree() or not target.is_inside_tree():
		return
	var target_path: NodePath = source.get_path_to(target)
	match side:
		SIDE_LEFT:
			source.focus_neighbor_left = target_path
		SIDE_TOP:
			source.focus_neighbor_top = target_path
		SIDE_RIGHT:
			source.focus_neighbor_right = target_path
		SIDE_BOTTOM:
			source.focus_neighbor_bottom = target_path

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

func _shelf_offer_button() -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("disabled", empty)
	button.add_theme_stylebox_override("hover", _selection_style(true))
	button.add_theme_stylebox_override("pressed", _selection_style(true))
	button.add_theme_stylebox_override("focus", _selection_style(true))
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

func _make_mouse_passive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_make_mouse_passive(child)

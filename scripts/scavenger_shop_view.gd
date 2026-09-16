extends Control
class_name ScavengerShopView

signal buy_requested(item_id: String, source: Control)
signal sell_requested(item_id: String, source: Control)
signal leave_requested
signal controller_context_changed
signal item_hovered(merchant_kind: String, item_id: String, source: Control)
signal item_unhovered(merchant_kind: String, item_id: String, source: Control)

const AssetLoader = preload("res://scripts/asset_loader.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const CardWidgetScene = preload("res://scenes/card_widget.tscn")
const GameData = preload("res://scripts/game_data.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const PortraitRig = preload("res://scripts/scavenger_cutout/rig.gd")
const Ware = preload("res://scripts/scavenger_ware.gd")
const Materials = preload("res://scripts/scavenger_materials.gd")
const ShopPanel = preload("res://scripts/scavenger_panel.gd")
const ShopAction = preload("res://scripts/scavenger_action.gd")
const MerchantAcquisitionEffect = preload("res://scripts/merchant_acquisition_effect.gd")

const REFERENCE_SIZE := Vector2(1920.0, 1080.0)
const BACKDROP_PATH := "res://assets/art/ui/scavenger_shop/stall_backdrop_v2.png"
const INSPECTION_FRAME_PATH := "res://assets/art/ui/scavenger_shop/inspection_frame_v1.png"
const MAGIC := "magic"
const GEAR := "gear"
const ITEM := "item"
const MERCHANT_KIND := "scavenger"
const NATIVE_CARD_SIZE := Vector2(250.0, 352.0)
const OFFER_CARD_SIZE := Vector2(154.0, 216.0)
const OFFER_TILE_SIZE := Vector2(196.0, 170.0)
const SELL_TILE_SIZE := Vector2(244.0, 194.0)
const SELL_PAGE_SIZE: int = 9
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
var _portrait: Node2D
var _counter_occluder: Control
var _title_panel: PanelContainer
var _currency_panel: PanelContainer
var _currency_label: Label
var _magic_group: Control
var _gear_group: Control
var _item_group: Control
var _detail_panel: Control
var _detail_title: Label
var _detail_card_host: CenterContainer
var _detail_card_nav: HBoxContainer
var _detail_card_previous: Button
var _detail_card_counter: Label
var _detail_card_next: Button
var _detail_action: Button
var _sell_panel: PanelContainer
var _sell_heading: Label
var _sell_row: GridContainer
var _sell_previous: Button
var _sell_next: Button
var _leave_button: Button
var _selection_effects: Dictionary = {}
var _offer_sources: Dictionary = {}
var _shelf_signatures: Dictionary = {}
var _sell_page_signature: String = ""
var _rendered_detail_card_id: String = ""
var _animated_groups: Array[Control] = []
var _sellable_ids: Array = []
var _sell_page: int = 0
var _detail_card_ids: Array[String] = []
var _detail_card_index: int = 0
var _slot_tweens: Dictionary = {}
var _purchase_effects: Control
var _pack_mode: bool = false
var _pack_filter: String = "all"
var _all_sellable_ids: Array = []
var _mode_buy: Button
var _mode_sell: Button
var _filter_buttons: Array[Button] = []
var _dialogue_panel: PanelContainer
var _dialogue_words: Label
var _dialogue_title: Label
var _receipt_visual: Control
var _receipt_ember: TextureRect
var _receipt_rule: HSeparator
var _receipt_heading: Label
var _receipt_detail: Label
var _receipt_amount: Label
var _receipt_tween: Tween
var _intro_open: bool = true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_build_static_scene()
	resized.connect(_layout_canvas)
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)
	_layout_canvas()
	set_process(true)

func configure(run_state: Dictionary, run_engine: RefCounted, reduced_motion: bool) -> void:
	_run_state = run_state.duplicate(true)
	_run_engine = run_engine
	if reduced_motion and not _reduced_motion:
		for tween: Tween in _slot_tweens.values():
			if tween != null and tween.is_valid(): tween.kill()
		_slot_tweens.clear()
		for source: Control in _offer_sources.values():
			if is_instance_valid(source): source.scale = Vector2.ONE
	_reduced_motion = reduced_motion
	var next_room: Vector2i = _run_state.get("current_room", Vector2i.ZERO)
	if next_room != _room_coord:
		_clear_children(_purchase_effects)
		_room_coord = next_room
		_entry_played_for_room = false
		_selected_item_id = ""
		_selected_is_sell = false
		_selected_source = null
		_sell_page = 0
		_pack_mode = false
		_pack_filter = "all"
		_intro_open = true
		_clear_receipt()
		_sync_dialogue()
	_rebuild_inventory()
	_restore_selection_after_rebuild()
	_sync_currency()
	_sync_detail()
	_sync_mode()
	for button: Node in _canvas.find_children("*", "Button", true, false):
		if button is ShopAction or button is Ware: button.set("reduced_motion", _reduced_motion)
	if _portrait != null and _reduced_motion: _portrait.call("apply_pose", "rest", 0.0)
	if visible and not _entry_played_for_room:
		call_deferred("_play_entry")

func present() -> void:
	visible = true
	if not _entry_played_for_room:
		call_deferred("_play_entry")

func dismiss_immediately() -> void:
	visible = false
	# RunScene briefly dismisses and presents this same view while refreshing.
	# Only a real close cancels fanfare; rebuilding stock preserves its lifetime.
	call_deferred("_clear_purchase_effects_if_closed")

func _clear_purchase_effects_if_closed() -> void:
	if not visible:
		_clear_children(_purchase_effects)

func purchase_origin(item_id: String, source: Control) -> Rect2:
	if not is_instance_valid(source) or not source.is_inside_tree():
		return Rect2()
	var global_rect: Rect2 = source.get_global_rect()
	if str(_run_engine.call("merchant_item_kind", item_id)) == MAGIC:
		for child: Node in source.find_children("*", "Button", true, false):
			if child is CardWidget:
				global_rect = (child as Control).get_global_rect()
				break
	else:
		for child: Node in source.find_children("*", "TextureRect", true, false):
			if (child as TextureRect).texture != null:
				global_rect = (child as TextureRect).get_global_rect()
				break
	var inverse: Transform2D = _canvas.get_global_transform().affine_inverse()
	return inverse * global_rect

func present_purchase(item_id: String, origin: Rect2) -> void:
	_present_trade(item_id, origin, false)

func present_sale(item_id: String, origin: Rect2) -> void:
	_present_trade(item_id, origin, true)

func _present_trade(item_id: String, origin: Rect2, selling: bool) -> void:
	if not visible or _purchase_effects == null or origin.size.x <= 0.0 or origin.size.y <= 0.0: return
	var amount: int = int(_run_engine.call("merchant_sell_value" if selling else "merchant_buy_cost", MERCHANT_KIND, item_id))
	_show_receipt(item_id, amount, selling)
	var effect := MerchantAcquisitionEffect.new()
	effect.name = ("MerchantSale_" if selling else "MerchantAcquisition_") + item_id
	effect.size = REFERENCE_SIZE
	effect.item_id = item_id
	effect.reduced_motion = _reduced_motion
	effect.selling = selling
	effect.origin = origin
	effect.destination = Vector2(300, 430) if selling else _dialogue_panel.position + Vector2(92, 164)
	effect.currency_destination = _currency_panel.position + _currency_panel.size * 0.5
	_purchase_effects.add_child(effect)
	_build_purchase_proxy(effect.proxy, item_id, origin.size)

func _clear_receipt() -> void:
	if _receipt_tween != null and _receipt_tween.is_valid(): _receipt_tween.kill()
	if _dialogue_words != null: _dialogue_words.show()
	if _dialogue_title != null: _dialogue_title.show()
	for control: Control in [_receipt_heading, _receipt_detail, _receipt_amount, _receipt_visual, _receipt_ember, _receipt_rule]:
		if control != null: control.hide()
	if _currency_panel != null: _currency_panel.modulate = Color.WHITE

func _show_receipt(item_id: String, amount: int, selling: bool) -> void:
	if _receipt_tween != null and _receipt_tween.is_valid(): _receipt_tween.kill()
	_dialogue_words.hide()
	_dialogue_title.hide()
	_receipt_heading.text = "SOLD" if selling else "PURCHASED"
	_receipt_detail.text = _item_name(item_id)
	_receipt_amount.text = ("+%d" if selling else "−%d") % amount
	_receipt_amount.add_theme_color_override("font_color", Color("bfe1ae") if selling else Color("ef9290"))
	_clear_children(_receipt_visual)
	var kind: String = str(_run_engine.call("merchant_item_kind", item_id))
	var visual_size := Vector2(104, 146) if kind == MAGIC else Vector2(112, 112)
	var visual := Control.new()
	visual.position = (_receipt_visual.size - visual_size) * 0.5
	visual.size = visual_size
	_receipt_visual.add_child(visual)
	_build_purchase_proxy(visual, item_id, visual_size)
	for control: Control in [_receipt_heading, _receipt_detail, _receipt_amount, _receipt_visual, _receipt_ember, _receipt_rule]:
		control.show()
		control.modulate = Color.WHITE
	_receipt_rule.modulate = Color(0.8, 0.63, 0.37, 0.5)
	if not _reduced_motion:
		_currency_panel.modulate = Color(1.4, 1.23, 1.05)
		_receipt_tween = create_tween()
		_receipt_tween.tween_property(_currency_panel, "modulate", Color.WHITE, 0.45)

func _build_purchase_proxy(host: Control, item_id: String, visual_size: Vector2) -> void:
	var kind: String = str(_run_engine.call("merchant_item_kind", item_id))
	if kind == MAGIC:
		# Card art/frame textures have transparent cut-outs. A lifted card needs
		# its own solid body, otherwise the replacement stock bleeds through it.
		var backing := Panel.new()
		backing.position = Vector2(7.0, 9.0)
		backing.size = visual_size - Vector2(14.0, 15.0)
		var backing_style := StyleBoxFlat.new()
		backing_style.bg_color = Color("251c10")
		backing_style.set_corner_radius_all(10)
		backing.add_theme_stylebox_override("panel", backing_style)
		host.add_child(backing)
		_build_native_scaled_card(host, item_id, visual_size, "PurchasedCard", false)
	else:
		var icon := TextureRect.new()
		icon.texture = AssetLoader.load_texture(_icon_path(item_id))
		icon.size = visual_size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		host.add_child(icon)
	_make_mouse_passive(host)


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
		"pack_mode": _pack_mode,
		"pack_filter": _pack_filter,
		"intro_open": _intro_open,
		"portrait_rig": _portrait is PortraitRig,
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

	_portrait = PortraitRig.new()
	_portrait.name = "ScavengerPortrait"
	_portrait.position = PORTRAIT_BASE_POSITION
	_portrait.scale = Vector2.ONE * (800.0 / 255.0)
	_portrait_clip.add_child(_portrait)
	_portrait.call("load_rig")

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

	_title_panel = _panel()
	_set_panel_material(_title_panel, "dialogue")
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

	_currency_panel = _panel()
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
	_place(_detail_panel, Rect2(1475.0, 156.0, 420.0, 722.0))
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

	_sell_panel = _panel()
	_set_panel_material(_sell_panel, "tray")
	_sell_panel.name = "SellFromPackPanel"
	_place(_sell_panel, Rect2(658.0, 132.0, 794.0, 778.0))
	_canvas.add_child(_sell_panel)
	_build_sell_content()
	_build_dialogue_and_modes()
	_shade_ui_labels(_canvas)

	_leave_button = _action("Leave")
	_leave_button.name = "ScavengerLeaveButton"
	_place(_leave_button, Rect2(1540.0, 950.0, 310.0, 70.0))
	UiTypography.set_button_size(_leave_button, 30)
	_leave_button.tooltip_text = "Close the shop and return to the room's doors."
	_leave_button.pressed.connect(func() -> void: leave_requested.emit())
	_canvas.add_child(_leave_button)

	_purchase_effects = Control.new()
	_purchase_effects.name = "MerchantPurchaseEffects"
	_purchase_effects.size = REFERENCE_SIZE
	_purchase_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Shelf focus and the native time badge both add their own depth.
	_purchase_effects.z_index = 100
	_canvas.add_child(_purchase_effects)

func _build_category_group(label_text: String, rect: Rect2) -> Control:
	var group := Control.new()
	group.name = "%sShelf" % label_text.capitalize()
	_place(group, rect)
	_canvas.add_child(group)
	var plaque := ShopPanel.new()
	plaque.name = "%sPlaque" % label_text.capitalize()
	_place(plaque, Rect2(-120.0, 0.0, 150.0, 44.0))
	plaque.add_theme_stylebox_override("panel", _panel_insets())
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
	# These are the dark interior regions of inspection_frame_v1, measured in
	# the 420x722 registered panel. Container bounds alone include its ornament.
	_detail_title = _label_at(_detail_panel, "", Rect2(48, 56, 324, 78), 28)
	_detail_title.name = "ScavengerDetailTitle"
	_detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_card_host = CenterContainer.new()
	_detail_card_host.name = "ScavengerDetailCardHost"
	_place(_detail_card_host, Rect2(50, 144, 320, 378))
	_detail_panel.add_child(_detail_card_host)
	_detail_card_nav = HBoxContainer.new()
	_detail_card_nav.name = "ScavengerGrantedCardNavigator"
	_place(_detail_card_nav, Rect2(48, 532, 324, 42))
	_detail_card_nav.alignment = BoxContainer.ALIGNMENT_CENTER
	_detail_card_nav.add_theme_constant_override("separation", 8)
	_detail_panel.add_child(_detail_card_nav)
	_detail_card_previous = _action("‹")
	_detail_card_previous.name = "ScavengerPreviousGrantedCard"
	_detail_card_previous.custom_minimum_size = Vector2(48, 40)
	UiTypography.set_button_size(_detail_card_previous, 24)
	_detail_card_previous.tooltip_text = "Show the previous card granted by this gear."
	_detail_card_previous.pressed.connect(_turn_detail_card.bind(-1))
	_detail_card_nav.add_child(_detail_card_previous)
	_detail_card_counter = Label.new()
	_detail_card_counter.name = "ScavengerGrantedCardCounter"
	_detail_card_counter.custom_minimum_size = Vector2(212, 40)
	_detail_card_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_card_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(_detail_card_counter, 20)
	_detail_card_nav.add_child(_detail_card_counter)
	_detail_card_next = _action("›")
	_detail_card_next.name = "ScavengerNextGrantedCard"
	_detail_card_next.custom_minimum_size = Vector2(48, 40)
	UiTypography.set_button_size(_detail_card_next, 24)
	_detail_card_next.tooltip_text = "Show the next card granted by this gear."
	_detail_card_next.pressed.connect(_turn_detail_card.bind(1))
	_detail_card_nav.add_child(_detail_card_next)
	_detail_action = _action("BUY")
	_detail_action.name = "ScavengerTradeActionButton"
	_place(_detail_action, Rect2(50, 596, 320, 66))
	UiTypography.set_button_size(_detail_action, 24)
	_detail_action.pressed.connect(_on_detail_action)
	_detail_panel.add_child(_detail_action)
	_detail_card_nav.visible = false

func _build_sell_content() -> void:
	var content := Control.new()
	_sell_panel.add_child(content)
	_sell_heading = _label_at(content, "Sell from pack", Rect2(14, 0, 480, 48), 30)
	var categories: Array = ["all", MAGIC, GEAR, ITEM]
	for index: int in range(categories.size()):
		var category: String = categories[index]
		var button := _action("ALL" if category == "all" else "ITEMS" if category == ITEM else category.to_upper())
		button.name = "PackFilter_" + category
		button.toggle_mode = true
		button.set("surface", "dialogue")
		_place(button, Rect2(14 + index * 189, 58, 180, 46))
		UiTypography.set_button_size(button, 19)
		button.pressed.connect(_set_pack_filter.bind(category))
		content.add_child(button)
		_filter_buttons.append(button)
	_sell_row = GridContainer.new()
	_sell_row.name = "SellInventoryRow"
	_sell_row.columns = 3
	_sell_row.add_theme_constant_override("h_separation", 8)
	_sell_row.add_theme_constant_override("v_separation", 10)
	_place(_sell_row, Rect2(12, 120, 748, 602))
	content.add_child(_sell_row)
	_sell_previous = _action("‹")
	_sell_previous.name = "SellPreviousPage"
	_place(_sell_previous, Rect2(564, 3, 78, 45))
	_sell_previous.pressed.connect(_turn_sell_page.bind(-1))
	content.add_child(_sell_previous)
	_sell_next = _action("›")
	_sell_next.name = "SellNextPage"
	_place(_sell_next, Rect2(662, 3, 78, 45))
	_sell_next.pressed.connect(_turn_sell_page.bind(1))
	content.add_child(_sell_next)

func _label_at(parent: Node, words: String, rect: Rect2, font_size: int, color: Color = Color("f0d6a8")) -> Label:
	var label := Label.new()
	label.text = words
	_place(label, rect)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(label, font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.add_theme_color_override("font_outline_color", Color("180f0b"))
	label.add_theme_constant_override("outline_size", 3)
	parent.add_child(label)
	return label

func _build_dialogue_and_modes() -> void:
	_dialogue_panel = _panel()
	_set_panel_material(_dialogue_panel, "dialogue")
	_dialogue_panel.name = "ScavengerDialogue"
	_place(_dialogue_panel, Rect2(32, 744, 568, 278))
	_canvas.add_child(_dialogue_panel)
	var content := Control.new()
	_dialogue_panel.add_child(content)
	_dialogue_title = _label_at(content, "THE SCAVENGER", Rect2(20, 4, 504, 46), 30)
	_dialogue_words = _label_at(content, "", Rect2(20, 61, 504, 134), 25, Color("e4d8c0"))
	_dialogue_words.name = "ScavengerDialogueBody"
	_dialogue_words.add_theme_font_override("font", UiTypography.text_font())
	_dialogue_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_receipt_heading = _label_at(content, "", Rect2(20, 9, 260, 44), 27)
	_receipt_heading.name = "ScavengerReceiptHeading"
	_receipt_amount = _label_at(content, "", Rect2(308, 9, 144, 44), 29)
	_receipt_amount.name = "ScavengerReceiptAmount"
	_receipt_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_receipt_ember = TextureRect.new()
	_receipt_ember.name = "ScavengerReceiptEmbers"
	_place(_receipt_ember, Rect2(462, 13, 36, 36))
	_receipt_ember.texture = ActionIcons.icon_texture("ember")
	_receipt_ember.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_receipt_ember.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_receipt_ember.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_receipt_ember)
	_receipt_rule = HSeparator.new()
	_place(_receipt_rule, Rect2(20, 62, 484, 1))
	_receipt_rule.modulate = Color(0.8, 0.63, 0.37, 0.5)
	content.add_child(_receipt_rule)
	_receipt_visual = Control.new()
	_receipt_visual.name = "ScavengerReceiptItem"
	_place(_receipt_visual, Rect2(24, 78, 112, 152))
	_receipt_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_receipt_visual)
	_receipt_detail = _label_at(content, "", Rect2(162, 94, 336, 118), 28, Color("eee1c7"))
	_receipt_detail.name = "ScavengerReceiptName"
	_receipt_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for control: Control in [_receipt_heading, _receipt_detail, _receipt_amount, _receipt_visual, _receipt_ember, _receipt_rule]: control.hide()
	_mode_buy = _action("Browse wares")
	_mode_buy.name = "ScavengerBrowseMode"
	_place(_mode_buy, Rect2(670, 950, 378, 70))
	_mode_buy.toggle_mode = true
	UiTypography.set_button_size(_mode_buy, 25)
	_mode_buy.pressed.connect(_set_pack_mode.bind(false))
	_canvas.add_child(_mode_buy)
	_mode_sell = _action("Sell from pack")
	_mode_sell.name = "ScavengerSellMode"
	_place(_mode_sell, Rect2(1065, 950, 378, 70))
	_mode_sell.toggle_mode = true
	UiTypography.set_button_size(_mode_sell, 25)
	_mode_sell.pressed.connect(_set_pack_mode.bind(true))
	_canvas.add_child(_mode_sell)
	_sync_dialogue()

func show_dialogue(_dialogue: Dictionary) -> void:
	# A single shop-owned welcome: wares stay clickable, with no board overlay.
	_sync_dialogue()

func _sync_dialogue() -> void:
	if _dialogue_words == null: return
	_dialogue_words.text = "Cards, steel, little miracles in bottles. Spend your embers, or show me what you've brought to sell."


func _set_pack_mode(selling: bool) -> void:
	_intro_open = false
	_pack_mode = selling
	_selected_item_id = ""
	_selected_source = null
	_selected_is_sell = selling
	_sync_mode()
	_sync_detail()
	_update_selection_effects()

func _set_pack_filter(category: String) -> void:
	_pack_filter = category
	_sell_page = 0
	_selected_item_id = ""
	_selected_source = null
	_rebuild_inventory()
	_sync_mode()
	_sync_detail()

func _sync_mode() -> void:
	for group: Control in _animated_groups: group.visible = not _pack_mode
	_sell_panel.visible = _pack_mode
	_mode_buy.set_pressed_no_signal(not _pack_mode)
	_mode_sell.set_pressed_no_signal(_pack_mode)
	for button: Button in _filter_buttons:
		button.set_pressed_no_signal(button.name == "PackFilter_" + _pack_filter)
	_sync_dialogue()
	_configure_focus_neighbors()

func _rebuild_inventory() -> void:
	if _run_engine == null or _magic_group == null:
		return
	var offers: Array = _run_engine.call("merchant_offer_ids", _run_state, MERCHANT_KIND)
	var offers_by_kind: Dictionary = {MAGIC: [], GEAR: [], ITEM: []}
	for offer_var: Variant in offers:
		var item_id: String = str(offer_var)
		var kind: String = str(_run_engine.call("merchant_item_kind", item_id))
		(offers_by_kind[kind] as Array).append(item_id)
	for kind: String in offers_by_kind:
		var ids: Array = offers_by_kind[kind] as Array
		var signatures: Array = []
		for item_id: String in ids:
			var affordable: bool = _offer_is_affordable(item_id, false)
			signatures.append([item_id, affordable])
		var signature: int = hash(signatures)
		if _shelf_signatures.get(kind, -1) != signature:
			var target_group: Control = _magic_group if kind == MAGIC else (_gear_group if kind == GEAR else _item_group)
			var row := target_group.get_node("OfferRow") as HBoxContainer
			for child: Node in row.get_children():
				var item_id: String = str(child.get_meta("shop_item_id", ""))
				var key: String = "buy:" + item_id
				_forget_offer(key)
			_clear_children(row)
			for item_id: String in ids:
				var shelf_slot := CenterContainer.new()
				shelf_slot.name = "ShelfCubby_%s" % item_id
				shelf_slot.set_meta("shop_item_id", item_id)
				shelf_slot.custom_minimum_size = Vector2(SHELF_SLOT_WIDTH, row.size.y)
				shelf_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
				shelf_slot.add_child(_build_offer(item_id, kind))
				row.add_child(shelf_slot)
			_shelf_signatures[kind] = signature
		# Unaffordable tooltips include the changing amount still needed even
		# while their price, disabled tint and card artwork remain unchanged.
		for item_id: String in ids:
			var offer: Control = _offer_sources.get("buy:" + item_id) as Control
			if offer != null: offer.tooltip_text = _offer_tooltip(item_id, false, _offer_is_affordable(item_id, false))
	_all_sellable_ids = _run_engine.call("merchant_sellable_ids", _run_state, MERCHANT_KIND)
	_sellable_ids = _all_sellable_ids.filter(func(id: Variant) -> bool: return _pack_filter == "all" or str(_run_engine.call("merchant_item_kind", str(id))) == _pack_filter)
	_populate_sell_page()
	_update_selection_effects()
	_shade_ui_labels(_magic_group)
	_shade_ui_labels(_gear_group)
	_shade_ui_labels(_item_group)
	_shade_ui_labels(_sell_panel)

func _forget_offer(key: String) -> void:
	var source: Control = _offer_sources.get(key) as Control
	if is_instance_valid(source):
		source.set_meta("shop_offer_retired", true)
		var tween_key: int = source.get_instance_id()
		var tween: Tween = _slot_tweens.get(tween_key) as Tween
		if tween != null and tween.is_valid(): tween.kill()
		_slot_tweens.erase(tween_key)
	_offer_sources.erase(key)
	_selection_effects.erase(key)

func _populate_sell_page() -> void:
	var page_count: int = maxi(1, ceili(float(_sellable_ids.size()) / float(SELL_PAGE_SIZE)))
	_sell_page = clampi(_sell_page, 0, page_count - 1)
	var signature: String = "%d|%d|%d" % [hash([_sellable_ids, _pack_filter]), _sell_page, page_count]
	if signature == _sell_page_signature: return
	_sell_page_signature = signature
	for key_var: Variant in _offer_sources.keys():
		var key: String = str(key_var)
		if key.begins_with("sell:"): _forget_offer(key)
	_clear_children(_sell_row)
	_sell_heading.text = "YOUR PACK" if page_count == 1 else "YOUR PACK  ·  %d / %d" % [_sell_page + 1, page_count]
	_sell_previous.disabled = _sell_page <= 0
	_sell_next.disabled = _sell_page >= page_count - 1
	var count: int = mini(SELL_PAGE_SIZE, maxi(0, _sellable_ids.size() - _sell_page * SELL_PAGE_SIZE))
	var rows: int = ceili(float(count) / 3.0)
	var grid_height: float = 180.0 if count == 0 else rows * SELL_TILE_SIZE.y + maxi(0, rows - 1) * 10.0
	_sell_row.custom_minimum_size.y = grid_height
	_sell_row.size.y = grid_height
	_sell_panel.custom_minimum_size.y = grid_height + 168.0
	_sell_panel.size.y = grid_height + 168.0
	if _sellable_ids.is_empty():
		var empty := Label.new()
		empty.text = "No spare wares to sell." if _pack_filter == "all" else "No %s to sell." % ("items" if _pack_filter == ITEM else _pack_filter)
		empty.custom_minimum_size = Vector2(748, 180)
		_sell_row.columns = 1
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UiTypography.set_label_size(empty, 17)
		empty.add_theme_color_override("font_color", Color("a99b86"))
		_sell_row.add_child(empty)
	else:
		_sell_row.columns = 3
		var first_index: int = _sell_page * SELL_PAGE_SIZE
		for index: int in range(first_index, mini(first_index + SELL_PAGE_SIZE, _sellable_ids.size())):
			_sell_row.add_child(_build_sell_offer(str(_sellable_ids[index])))

func _turn_sell_page(delta: int) -> void:
	var focus: Control = get_viewport().gui_get_focus_owner()
	_sell_page += delta
	_populate_sell_page()
	if focus == _sell_next and _sell_next.disabled: _sell_previous.grab_focus()
	elif focus == _sell_previous and _sell_previous.disabled: _sell_next.grab_focus()
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
	var button := _shelf_offer_button()
	button.set("pack", selling)
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
		var caption := _panel()
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
	price.text = "+%d EMBERS" % amount if selling else "%d EMBERS" % amount
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
	var button := _shelf_offer_button()
	button.set("pack", true)
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
	center.custom_minimum_size = Vector2(122.0, 150.0)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(center)
	_build_native_scaled_card(center, item_id, Vector2(100.0, 140.0), "SellMagicCard", false)
	var value := Label.new()
	value.text = "+%d EMBERS" % int(_run_engine.call("merchant_sell_value", MERCHANT_KIND, item_id))
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
	button.set("reduced_motion", _reduced_motion)
	button.pressed.connect(_activate_item.bind(item_id, selling, button))
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
	var plaque := ShopPanel.new()
	plaque.custom_minimum_size = Vector2(126.0, 34.0)
	var cost: int = int(_run_engine.call("merchant_sell_value", MERCHANT_KIND, item_id) if selling else _run_engine.call("merchant_buy_cost", MERCHANT_KIND, item_id))
	var affordable: bool = _offer_is_affordable(item_id, selling)
	plaque.add_theme_stylebox_override("panel", _panel_insets())
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
	if _intro_open:
		_intro_open = false
		_sync_dialogue()
	var selection_changed: bool = item_id != _selected_item_id or selling != _selected_is_sell
	_selected_item_id = item_id
	_selected_is_sell = selling
	_selected_source = source
	if selection_changed:
		_detail_card_index = 0
	_update_selection_effects()
	_sync_detail()

func _activate_item(item_id: String, selling: bool, source: Control) -> void:
	_select_item(item_id, selling, source)
	# Accept explicitly enters the selected ware's trade action. Directional
	# browsing can keep previewing other wares without silently changing a trade.
	var router: Node = get_node_or_null("/root/InputRouter")
	if router != null and bool(router.call("using_controller")) and not _detail_action.disabled:
		_detail_action.grab_focus()

func _on_gui_focus_changed(control: Control) -> void:
	if visible and control != null and is_ancestor_of(control):
		controller_context_changed.emit()

func controller_action_label() -> String:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == _detail_action: return "Sell" if _selected_is_sell else "Buy"
	if focused != null and focused.has_meta("shop_affordable"): return "Inspect"
	return "Select"

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
	if source == null or bool(source.get_meta("shop_offer_retired", false)):
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
		if control is Ware: control.set("chosen", key == selected_key)
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
		_detail_panel.hide()
		_detail_title.text = "SELECT A WARE"
		_detail_card_ids.clear()
		_detail_card_index = 0
		_clear_children(_detail_card_host)
		_rendered_detail_card_id = ""
		_detail_card_nav.visible = false
		_detail_action.text = "SELECT AN OFFER"
		_detail_action.disabled = true
		_configure_focus_neighbors()
		return
	_detail_panel.show()
	var item_id: String = _selected_item_id
	var kind: String = str(_run_engine.call("merchant_item_kind", item_id))
	var amount: int = int(_run_engine.call("merchant_sell_value", MERCHANT_KIND, item_id) if _selected_is_sell else _run_engine.call("merchant_buy_cost", MERCHANT_KIND, item_id))
	var held: int = int(_run_engine.call("held_embers", _run_state))
	var affordable: bool = _selected_is_sell or held >= amount
	_detail_title.text = _item_name(item_id)
	_detail_card_ids.clear()
	if kind == GEAR:
		for card_id_var: Variant in GameData.equipment_cards(item_id, _run_state):
			_detail_card_ids.append(str(card_id_var))
	else:
		_detail_card_ids.append(item_id)
	_render_detail_card()
	_detail_action.text = "Sell · %d embers" % amount if _selected_is_sell else "Buy · %d embers" % amount
	_detail_action.disabled = not affordable
	_detail_action.tooltip_text = "Sell the selected owned ware." if _selected_is_sell else ("Buy the selected ware." if affordable else "You cannot afford this ware.")
	_configure_focus_neighbors()

func _render_detail_card() -> void:
	if _detail_card_host == null:
		return
	if _detail_card_ids.is_empty():
		_clear_children(_detail_card_host)
		_rendered_detail_card_id = ""
		_detail_card_nav.visible = false
		return
	_detail_card_index = clampi(_detail_card_index, 0, _detail_card_ids.size() - 1)
	var card_id: String = _detail_card_ids[_detail_card_index]
	if card_id != _rendered_detail_card_id:
		_clear_children(_detail_card_host)
		_build_native_scaled_card(_detail_card_host, card_id, Vector2(250.0, 352.0), "DetailCard", false)
		_rendered_detail_card_id = card_id
	var multiple_cards: bool = _detail_card_ids.size() > 1
	_detail_card_nav.visible = multiple_cards
	if multiple_cards:
		_detail_card_counter.text = "%d / %d" % [_detail_card_index + 1, _detail_card_ids.size()]
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
	_portrait.call("apply_pose", "idle", fposmod(_ambient_time / PortraitRig.IDLE_SECONDS, 1.0))

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
	if not is_inside_tree() or _run_engine == null or _mode_buy == null: return
	var magic: Array[Control] = _buy_offer_controls(MAGIC)
	var gear: Array[Control] = _buy_offer_controls(GEAR)
	var items: Array[Control] = _buy_offer_controls(ITEM)
	var pack: Array[Control] = _visible_sell_offer_controls()
	var entry: Control = _detail_card_previous if _detail_card_nav.visible and _detail_panel.visible else _detail_action if _detail_panel.visible and not _detail_action.disabled else _leave_button
	var last: Control = _mode_sell if _pack_mode else _mode_buy
	if _pack_mode:
		for index: int in range(pack.size()):
			var source: Control = pack[index]
			_set_focus_neighbor(source, SIDE_LEFT, pack[index - 1] if index % 3 > 0 else _mode_buy)
			_set_focus_neighbor(source, SIDE_RIGHT, pack[index + 1] if index % 3 < 2 and index + 1 < pack.size() else entry)
			_set_focus_neighbor(source, SIDE_TOP, pack[index - 3] if index >= 3 else _filter_buttons[mini(index, 3)])
			_set_focus_neighbor(source, SIDE_BOTTOM, pack[index + 3] if index + 3 < pack.size() else _mode_sell)
		if not pack.is_empty(): last = pack.back()
		for index: int in range(_filter_buttons.size()):
			var button: Button = _filter_buttons[index]
			_set_focus_neighbor(button, SIDE_LEFT, _filter_buttons[index - 1] if index > 0 else _mode_buy)
			_set_focus_neighbor(button, SIDE_RIGHT, _filter_buttons[index + 1] if index < 3 else entry)
			_set_focus_neighbor(button, SIDE_BOTTOM, pack[mini(index, pack.size() - 1)] if not pack.is_empty() else _mode_sell)
			_set_focus_neighbor(button, SIDE_TOP, _sell_next if not _sell_next.disabled else _sell_previous if not _sell_previous.disabled else button)
		_set_focus_neighbor(_sell_previous, SIDE_RIGHT, _sell_next if not _sell_next.disabled else _filter_buttons[0])
		_set_focus_neighbor(_sell_next, SIDE_LEFT, _sell_previous if not _sell_previous.disabled else _filter_buttons[3])
		_set_focus_neighbor(_sell_previous, SIDE_BOTTOM, _filter_buttons[0])
		_set_focus_neighbor(_sell_next, SIDE_BOTTOM, _filter_buttons[3])
	else:
		_configure_offer_row(magic, [], gear, _mode_buy, entry)
		_configure_offer_row(gear, magic, items, _mode_buy, entry)
		_configure_offer_row(items, gear, [], _mode_buy, entry)
		for offer: Control in items: _set_focus_neighbor(offer, SIDE_BOTTOM, _mode_buy if offer == items[0] else _mode_sell)
		if not items.is_empty(): last = items.back()
	var selected: Control = _selected_source if is_instance_valid(_selected_source) and _selected_source.is_visible_in_tree() else last
	_set_focus_neighbor(_detail_card_previous, SIDE_LEFT, selected)
	_set_focus_neighbor(_detail_card_previous, SIDE_RIGHT, _detail_card_next)
	_set_focus_neighbor(_detail_card_previous, SIDE_BOTTOM, _detail_action if not _detail_action.disabled else _leave_button)
	_set_focus_neighbor(_detail_card_next, SIDE_LEFT, _detail_card_previous)
	_set_focus_neighbor(_detail_card_next, SIDE_RIGHT, _detail_action if not _detail_action.disabled else _leave_button)
	_set_focus_neighbor(_detail_card_next, SIDE_BOTTOM, _detail_action if not _detail_action.disabled else _leave_button)
	_set_focus_neighbor(_detail_action, SIDE_LEFT, selected)
	_set_focus_neighbor(_detail_action, SIDE_TOP, _detail_card_next if _detail_card_nav.visible else selected)
	_set_focus_neighbor(_detail_action, SIDE_BOTTOM, _leave_button)
	_set_focus_neighbor(_detail_action, SIDE_RIGHT, _leave_button)
	_set_focus_neighbor(_leave_button, SIDE_TOP, _detail_action if _detail_panel.visible and not _detail_action.disabled else last)
	_set_focus_neighbor(_leave_button, SIDE_LEFT, _mode_sell)
	_set_focus_neighbor(_mode_buy, SIDE_LEFT, _mode_buy)
	_set_focus_neighbor(_mode_buy, SIDE_RIGHT, _mode_sell)
	_set_focus_neighbor(_mode_buy, SIDE_TOP, last)
	_set_focus_neighbor(_mode_sell, SIDE_LEFT, _mode_buy)
	_set_focus_neighbor(_mode_sell, SIDE_RIGHT, _leave_button)
	_set_focus_neighbor(_mode_sell, SIDE_TOP, last)

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
	# The rendered shelf already owns the validated stock and its order. Focus
	# wiring must not regenerate all three merchant catalogs on each ware click.
	var result: Array[Control]
	var group: Control = _magic_group if kind == MAGIC else (_gear_group if kind == GEAR else _item_group)
	if group == null: return result
	var row: Control = group.get_node_or_null("OfferRow") as Control
	if row == null: return result
	for slot: Node in row.get_children():
		var item_id: String = str(slot.get_meta("shop_item_id", ""))
		var offer: Control = _offer_sources.get("buy:%s" % item_id, null) as Control
		if offer != null: result.append(offer)
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

func _panel() -> PanelContainer:
	var panel := ShopPanel.new()
	panel.add_theme_stylebox_override("panel", _panel_insets())
	return panel

func _action(text_value: String) -> Button:
	var button := ShopAction.new()
	button.text = text_value
	button.reduced_motion = _reduced_motion
	return button

func _shelf_offer_button() -> Button:
	return Ware.new()

func _panel_insets() -> StyleBoxEmpty:
	var style := StyleBoxEmpty.new()
	for side: int in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]: style.set_content_margin(side, 12)
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

func _set_panel_material(panel: PanelContainer, surface: String) -> void:
	panel.set("surface", surface)

func _shade_ui_labels(node: Node) -> void:
	if node is CardWidget or node is ShopAction: return
	if node is Label:
		var label: Label = node as Label
		var original_color: Color = label.get_theme_color("font_color")
		Materials.shade(label, label.get_theme_font_size("font_size"), maxf(label.size.y, label.custom_minimum_size.y))
		label.add_theme_color_override("font_color", original_color)
		if label == _dialogue_words:
			label.add_theme_font_override("font", UiTypography.text_font())
			label.material = null
	for child: Node in node.get_children(): _shade_ui_labels(child)

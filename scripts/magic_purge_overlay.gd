extends Control

signal confirmed(card_id: String, source: String)
signal closed

const List = preload("res://scripts/magic_deck_list.gd")
const Data = preload("res://scripts/game_data.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Confirmation = preload("res://scripts/magic_purge_confirmation.gd")
const PileView = preload("res://scripts/pile_dialog_view.gd")
const Section = preload("res://scripts/ui_section_header.gd")
const StatChip = preload("res://scripts/ui_stat_chip.gd")
const PriceTag = preload("res://scripts/scavenger_price_tag.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const MAX_COLUMNS: int = 7
const CARD_GAP := Vector2(16.0, 20.0)
const CROWN_HEADROOM: float = 18.0
const HEADER_HEIGHT: float = 64.0
const HEADER_GAP: float = 16.0
const SIDE_MARGIN: float = 32.0
const TOP_MARGIN: float = 24.0
const BOTTOM_MARGIN: float = 28.0
const MIN_WIDTH: float = 760.0
const SCREEN_MARGIN: float = 24.0
const GRID_CONFIRM_MODULATE: float = 0.30
const HEADER_CONFIRM_MODULATE: float = 0.60
const SCRIM_ALPHA: float = 0.72

var source: String = ""
var pending_card_id: String = ""
var _confirm: Button
var _list_cancel: Button
var _list_center: CenterContainer
var _confirmation: Control
var _rows: Dictionary = {}
var _can_afford: bool = true
var _host: Node
var _price: int = 0
var _held: int = 0
var _panel: PanelContainer
var _grid: Control
var _scroll: ScrollContainer
var _header: HBoxContainer
var _grid_panel_style: StyleBoxFlat
var _confirm_panel_style: StyleBoxFlat
var _columns: int = 1
var _return_card_id: String = ""
var _committing: bool = false

func configure(host: Node, state: Dictionary, purge_source: String, _dialog_size: Vector2) -> void:
	_host = host
	source = purge_source
	_price = host.get("_run_engine").scavenger_purge_price(state) if source == "scavenger" else 0
	_held = host.get("_run_engine").held_embers(state)
	_can_afford = source != "scavenger" or _held >= _price
	name = "MagicPurgeOverlay"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_as_relative = false
	z_index = Confirmation.highest_visible_z(get_parent(), self) + 1
	# The pile scrim already owns the brief's exact 0.02 neutral RGB.
	var scrim: Color = host.get("_pile_scrim").color
	scrim.a = SCRIM_ALPHA
	add_child(Confirmation.backdrop(scrim))
	_list_center = CenterContainer.new()
	add_child(_list_center)
	_list_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.name = "MagicPurgePanel"
	_list_center.add_child(_panel)
	var pile: PanelContainer = host.get("_pile_dialog")
	var style: StyleBox = pile.get_meta(UiSkin.OUTER_PANEL_BASELINE_STYLE_META).duplicate()
	# Panel margins are the sole insets; no inherited 16px pile padding stacks up.
	style.content_margin_left = SIDE_MARGIN
	style.content_margin_right = SIDE_MARGIN
	style.content_margin_top = TOP_MARGIN
	style.content_margin_bottom = BOTTOM_MARGIN
	PileView.finish_panel(_panel, style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", int(HEADER_GAP))
	_panel.add_child(content)
	var header := HBoxContainer.new()
	header.name = "MagicPurgeHeader"
	_header = header
	header.custom_minimum_size.y = HEADER_HEIGHT
	header.add_theme_constant_override("separation", int(CARD_GAP.x))
	content.add_child(header)
	var entries: Array[Dictionary] = List.entries(state.get("attuned_magic_cards", []) as Array)
	var heading := Section.new()
	heading.name = "MagicPurgeHeading"
	heading.setup("PURGE A SPELL", "%d spells" % (state.get("attuned_magic_cards", []) as Array).size())
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	if source == "scavenger":
		var price := StatChip.new()
		price.name = "MagicPurgePrice"
		price.setup(Assets.load_texture(PriceTag.EMBER_PATH), str(_price), "PRICE", Palette.GOLD_BRIGHT if _can_afford else Palette.DANGER)
		price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(price)
	_list_cancel = Button.new()
	_list_cancel.name = "CancelMagicPurgeList"
	_list_cancel.text = "X"
	UiSkin.new().apply_button_stylebox_overrides(_list_cancel, UiSkin.VARIANT_ICON)
	UiSkin.new().apply_button_text_overrides(_list_cancel)
	Typography.set_button_size(_list_cancel, Typography.SIZE_SMALL)
	_list_cancel.custom_minimum_size = Vector2(40.0, 40.0)
	_list_cancel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_list_cancel.pressed.connect(cancel)
	header.add_child(_list_cancel)
	_scroll = ScrollContainer.new()
	_scroll.name = "MagicPurgeScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if entries.size() > 14 else ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var padding := StyleBoxEmpty.new()
	padding.content_margin_top = CROWN_HEADROOM
	_scroll.add_theme_stylebox_override("panel", padding)
	content.add_child(_scroll)
	_grid = Control.new()
	_grid.name = "MagicPurgeRows"
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_grid)
	for entry: Dictionary in entries:
		var cell: Button = PileView.card_cell(host, str(entry["card_id"]), int(entry["count"]), select_card)
		_rows[_rows.size()] = cell
		_grid.add_child(cell)
	if entries.is_empty():
		var empty: Label = preload("res://scripts/character_menu_view.gd").empty_copy(preload("res://scripts/event_rules.gd").MAGIC_REQUIREMENT_COPY)
		empty.name = "MagicPurgeEmpty"
		_grid.add_child(empty)
		empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_columns = maxi(1, mini(entries.size(), MAX_COLUMNS))
	_grid.resized.connect(_layout_grid)
	_panel.custom_minimum_size = dialog_size_for(entries.size()) if not entries.is_empty() else _dialog_size
	# Reserve the scrollbar in the existing right margin, keeping seven 196px
	# columns and both the card spacing and the outer dialog width exact.
	if entries.size() > 14:
		var bar_width: float = _scroll.get_v_scroll_bar().get_combined_minimum_size().x
		_panel.get_theme_stylebox("panel").content_margin_right = SIDE_MARGIN - bar_width
	_grid_panel_style = _panel.get_theme_stylebox("panel") as StyleBoxFlat
	_confirm_panel_style = _grid_panel_style.duplicate() as StyleBoxFlat
	_confirm_panel_style.bg_color.a = 1.0
	_contain_list_focus()
	_confirmation = Confirmation.new()
	add_child(_confirmation)
	_confirmation.configure(host)
	_confirm = _confirmation.confirm_button
	_confirm.disabled = true
	_confirmation.accepted.connect(func() -> void:
		if pending_card_id.is_empty() or _confirm.disabled or _committing: return
		_committing = true
		_confirm.disabled = true
		confirmed.emit(pending_card_id, source)
	)
	_confirmation.cancelled.connect(cancel)
	call_deferred("focus_default")

static func dialog_size_for(identities: int) -> Vector2:
	var cols: int = maxi(1, mini(identities, MAX_COLUMNS))
	var rows: int = maxi(1, mini(ceili(float(identities) / MAX_COLUMNS), 2))
	var width: float = maxf(MIN_WIDTH, cols * PileView.CARD_SIZE.x + (cols - 1) * CARD_GAP.x + SIDE_MARGIN * 2.0)
	var viewport_height: float = rows * PileView.CARD_SIZE.y + (rows - 1) * CARD_GAP.y + CROWN_HEADROOM
	return Vector2(width, minf(1080.0 - SCREEN_MARGIN * 2.0, TOP_MARGIN + HEADER_HEIGHT + HEADER_GAP + viewport_height + BOTTOM_MARGIN))

func _layout_grid() -> void:
	var rows: int = ceili(float(_rows.size()) / _columns)
	_grid.custom_minimum_size.y = rows * PileView.CARD_SIZE.y + maxi(0, rows - 1) * CARD_GAP.y
	for index: int in range(_rows.size()):
		var row: int = index / _columns
		var row_count: int = mini(_columns, _rows.size() - row * _columns)
		var row_width: float = row_count * PileView.CARD_SIZE.x + (row_count - 1) * CARD_GAP.x
		var cell: Control = _rows[index]
		cell.position = Vector2((_grid.size.x - row_width) * 0.5 + (index % _columns) * (PileView.CARD_SIZE.x + CARD_GAP.x), row * (PileView.CARD_SIZE.y + CARD_GAP.y))

func select_card(card_id: String) -> void:
	if _committing: return
	var owned: bool = false
	for row: Control in _rows.values():
		if str(row.get("card_id")) == card_id: owned = true
	if not owned: return
	pending_card_id = card_id
	_return_card_id = card_id
	_host.call("_clear_controller_loadout_tooltip")
	# Keep the dialog/frame opaque; only its contents dim behind the card.
	_panel.add_theme_stylebox_override("panel", _confirm_panel_style)
	_scroll.modulate = Color(1, 1, 1, GRID_CONFIRM_MODULATE)
	_header.modulate = Color(1, 1, 1, HEADER_CONFIRM_MODULATE)
	for row: Control in _rows.values(): row.focus_mode = Control.FOCUS_NONE
	_list_cancel.focus_mode = Control.FOCUS_NONE
	_confirmation.present(card_id, _price, source == "scavenger", _can_afford, _held)

func cancel() -> void:
	if _committing: return
	if not pending_card_id.is_empty():
		pending_card_id = ""
		_confirmation.hide()
		_panel.add_theme_stylebox_override("panel", _grid_panel_style)
		_scroll.modulate = Color.WHITE
		_header.modulate = Color.WHITE
		for row: Control in _rows.values(): row.focus_mode = Control.FOCUS_ALL
		_list_cancel.focus_mode = Control.FOCUS_ALL
		_confirm.disabled = true
		focus_default()
	else: closed.emit()

func play_exhaust() -> void:
	_committing = true
	await _confirmation.play_exhaust()

func retry_confirmation() -> void:
	_committing = false
	_confirm.disabled = not _can_afford

func focus_scope() -> Control:
	return _confirmation if _confirmation.visible else self

func _contain_list_focus() -> void:
	var controls: Array[Control]
	for row: Control in _rows.values(): controls.append(row)
	controls.append(_list_cancel)
	for index: int in range(controls.size()):
		var control: Control = controls[index]
		control.focus_previous = control.get_path_to(controls[posmod(index - 1, controls.size())])
		control.focus_next = control.get_path_to(controls[(index + 1) % controls.size()])
		var left: Control = controls[posmod(index - 1, _rows.size())] if not _rows.is_empty() and control != _list_cancel else controls[0]
		var right: Control = controls[(index + 1) % _rows.size()] if not _rows.is_empty() and control != _list_cancel else controls[0]
		var up: Control = _rows[index - _columns] if index >= _columns and control != _list_cancel else _list_cancel
		var down: Control = _list_cancel
		if not _rows.is_empty():
			var last_row: int = (_rows.size() - 1) / _columns
			down = _rows[mini(index + _columns, _rows.size() - 1)] if index / _columns < last_row else _rows[index % _columns]
		if control == _list_cancel:
			up = controls[0]
			down = controls[0]
		control.focus_neighbor_left = control.get_path_to(left)
		control.focus_neighbor_right = control.get_path_to(right)
		control.focus_neighbor_top = control.get_path_to(up)
		control.focus_neighbor_bottom = control.get_path_to(down)

func contain_input(event: InputEvent) -> bool:
	if _committing: return true
	var focus: Control = get_viewport().gui_get_focus_owner()
	var scope: Control = focus_scope()
	if focus != null and scope.is_ancestor_of(focus) and focus.is_visible_in_tree(): return false
	for action: StringName in [&"ui_focus_next", &"ui_focus_prev", &"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_accept", preload("res://scripts/input_router.gd").ACTION_ACCEPT]:
		if event.is_action_pressed(action):
			focus_default()
			return true
	return false

# Character rows still call this hook; purge now uses real cards and has no row
# selection ornament. Preserve the Character hook without changing its rendering.
static func apply_selection(_tile: PanelContainer) -> void:
	pass

func focus_default() -> void:
	if not is_inside_tree() or _committing: return
	if _confirmation.visible: _confirmation.cancel_button.grab_focus()
	elif not _rows.is_empty():
		var target: Control = _rows[0]
		for row: Control in _rows.values():
			if str(row.get("card_id")) == _return_card_id: target = row
		target.grab_focus()
	else: _list_cancel.grab_focus()

static func install_scavenger(host: Node, shop: Control) -> void:
	var buy: Button = shop.find_child("ScavengerBrowseMode", true, false)
	var sell: Button = shop.find_child("ScavengerSellMode", true, false)
	if buy == null or sell == null: return
	var button: Button = shop.find_child("ScavengerPurge", true, false)
	if button == null:
		# Reuse the shop's approved segmented control; no new art or geometry.
		button = preload("res://scripts/scavenger_action.gd").new()
		button.name = "ScavengerPurge"
		button.set("surface", "segment")
		button.custom_minimum_size = sell.custom_minimum_size
		Typography.set_button_size(button, 22)
		button.pressed.connect(host.call.bind("_open_magic_purge", "scavenger"))
		sell.get_parent().add_child(button)
	var price: int = host.get("_run_engine").scavenger_purge_price(host.get("_run_state"))
	button.text = "Purge a spell"
	button.disabled = List.entries(host.get("_run_state").get("attuned_magic_cards", []) as Array).is_empty()
	button.tooltip_text = "You have no spells to purge." if button.disabled else "Remove a spell from your deck."
	button.custom_minimum_size = sell.custom_minimum_size
	var old_tag: Node = button.get_node_or_null("ScavengerPurgePrice")
	if old_tag != null:
		button.remove_child(old_tag)
		old_tag.queue_free()
	var tag := preload("res://scripts/scavenger_price_tag.gd").new()
	tag.name = "ScavengerPurgePrice"
	tag.amount = price
	tag.affordable = host.get("_run_engine").held_embers(host.get("_run_state")) >= price
	# Use the wares' authored tag at its existing size, pinned above this plate.
	tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tag.offset_left = -118.0
	tag.offset_top = -60.0
	tag.offset_bottom = 0.0
	button.add_child(tag)
	button.focus_neighbor_left = button.get_path_to(sell)
	button.focus_neighbor_right = button.get_path_to(shop.get("_leave_button"))
	sell.focus_neighbor_right = sell.get_path_to(button)
	shop.get("_leave_button").focus_neighbor_left = shop.get("_leave_button").get_path_to(button)
	var state: Dictionary = host.get("_run_state")
	var receipt: Dictionary = state.get("last_magic_purge", {})
	var notice: String = str(state.get("notice", ""))
	if str(receipt.get("source", "")) == "scavenger" and notice == "Purged %s." % str(Data.card_def(str(receipt.get("card_id", ""))).get("name", "")):
		# The fullscreen shop covers the room log. Reuse its existing text notice
		# surface so the persisted confirmation remains visible after closing.
		shop.call("_clear_receipt")
		shop.get("_dialogue_words").text = notice

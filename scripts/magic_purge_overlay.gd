extends Control

signal confirmed(card_id: String, source: String)
signal closed

const Menu = preload("res://scripts/character_menu_view.gd")
const List = preload("res://scripts/magic_deck_list.gd")
const Data = preload("res://scripts/game_data.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Confirmation = preload("res://scripts/magic_purge_confirmation.gd")
# The existing danger panel ornament uses this destructive-action accent.
const SELECTION_ACCENT: Color = Palette.DANGER

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

func configure(host: Node, state: Dictionary, purge_source: String, dialog_size: Vector2) -> void:
	_host = host
	source = purge_source
	_price = host.get("_run_engine").scavenger_purge_price(state) if source == "scavenger" else 0
	_can_afford = source != "scavenger" or host.get("_run_engine").held_embers(state) >= host.get("_run_engine").scavenger_purge_price(state)
	name = "MagicPurgeOverlay"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Child card badges and trade effects have their own raised depths. The
	# backdrop must cover the complete active UI, not only the shop root.
	z_as_relative = false
	z_index = Confirmation.highest_visible_z(get_parent(), self) + 1
	add_child(Confirmation.backdrop())
	_list_center = CenterContainer.new()
	add_child(_list_center)
	_list_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = dialog_size
	_list_center.add_child(panel)
	UiSkin.new().apply_panel_surface(panel)
	var column: PanelContainer = Menu.column("MagicPurgePanel", 420.0, "MAGIC IN DECK", "%d spells" % (state.get("attuned_magic_cards", []) as Array).size())
	panel.add_child(column)
	var list: VBoxContainer = Menu.scroll_list(column, "MagicPurgeScroll", "MagicPurgeRows")
	_rows = List.populate(host, list, state.get("attuned_magic_cards", []) as Array, select_card)
	var content: VBoxContainer = column.get_node("ColumnContent")
	var heading: Control = Menu.section("PURGE A SPELL")
	heading.name = "MagicPurgeHeading"
	content.add_child(heading)
	content.move_child(heading, 0)
	if _rows.is_empty(): content.add_child(Menu.empty_copy(preload("res://scripts/event_rules.gd").MAGIC_REQUIREMENT_COPY))
	_list_cancel = _button("Cancel", "CancelMagicPurgeList")
	_list_cancel.pressed.connect(cancel)
	content.add_child(_list_cancel)
	_contain_list_focus()
	_confirmation = Confirmation.new()
	add_child(_confirmation)
	_confirmation.configure()
	_confirm = _confirmation.confirm_button
	_confirm.disabled = true
	_confirmation.accepted.connect(func() -> void:
		if pending_card_id.is_empty(): return
		_confirm.disabled = true
		confirmed.emit(pending_card_id, source)
	)
	_confirmation.cancelled.connect(cancel)
	call_deferred("focus_default")

func _button(text: String, node_name: String) -> Button:
	var result := Button.new()
	result.name = node_name
	result.text = text
	UiSkin.new().apply_button_stylebox_overrides(result, UiSkin.VARIANT_STANDARD)
	Typography.apply_button_role(result, Typography.ROLE_BODY)
	return result

func select_card(card_id: String) -> void:
	var owned: bool = false
	for row: Control in _rows.values():
		if str(row.get("card_id")) == card_id: owned = true
	if not owned: return
	pending_card_id = card_id
	_refresh_selection()
	_host.call("_clear_controller_loadout_tooltip")
	_list_center.hide()
	_confirmation.present(str(Data.card_def(card_id).get("name", card_id)), _price, source == "scavenger", _can_afford)

func cancel() -> void:
	if not pending_card_id.is_empty():
		pending_card_id = ""
		_refresh_selection()
		_confirmation.hide()
		_list_center.show()
		_confirm.disabled = true
		focus_default()
	else: closed.emit()

func focus_scope() -> Control:
	return _confirmation if _confirmation.visible else self

func _contain_list_focus() -> void:
	var controls: Array[Control]
	for row: Control in _rows.values(): controls.append(row)
	controls.append(_list_cancel)
	for index: int in range(controls.size()):
		var control: Control = controls[index]
		var previous: Control = controls[posmod(index - 1, controls.size())]
		var next: Control = controls[(index + 1) % controls.size()]
		control.focus_previous = control.get_path_to(previous)
		control.focus_next = control.get_path_to(next)
		control.focus_neighbor_top = control.get_path_to(previous)
		control.focus_neighbor_bottom = control.get_path_to(next)
		control.focus_neighbor_left = control.get_path_to(control)
		control.focus_neighbor_right = control.get_path_to(control)

func contain_input(event: InputEvent) -> bool:
	var focus: Control = get_viewport().gui_get_focus_owner()
	var scope: Control = focus_scope()
	if focus != null and scope.is_ancestor_of(focus) and focus.is_visible_in_tree(): return false
	# Recover stale focus before GUI dispatch can deliver navigation/accept to
	# a toolbar behind the modal. Consume this event, rather than activating the
	# newly focused row or confirmation action as a side effect of recovery.
	for action: StringName in [&"ui_focus_next", &"ui_focus_prev", &"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_accept", preload("res://scripts/input_router.gd").ACTION_ACCEPT]:
		if event.is_action_pressed(action):
			focus_default()
			return true
	return false

func _refresh_selection() -> void:
	for row: Control in _rows.values():
		row.set_meta("magic_purge_selected", str(row.get("card_id")) == pending_card_id)
		_host.call("_apply_controller_loadout_focus_style", row, row.has_focus())

static func apply_selection(tile: PanelContainer) -> void:
	if not bool(tile.get_meta("magic_purge_selected", false)): return
	# Keep the Character strip's geometry and use the shared row finish as the
	# single selection marker. Focus/hover callbacks preserve this marker.
	var style: StyleBoxFlat = Menu.row_style(true)
	style.set_content_margin_all(0.0)
	style.bg_color = Color.TRANSPARENT
	style.border_color = SELECTION_ACCENT
	style.shadow_color = Color(SELECTION_ACCENT, style.shadow_color.a)
	tile.add_theme_stylebox_override("panel", style)

func focus_default() -> void:
	if not is_inside_tree(): return
	if _confirmation.visible: _confirmation.cancel_button.grab_focus()
	elif not _rows.is_empty(): (_rows[0] as Control).grab_focus()
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
	var price: String = "%d Embers" % host.get("_run_engine").scavenger_purge_price(host.get("_run_state"))
	button.text = "Purge\nRemove a spell from your deck.\n%s" % price
	button.tooltip_text = button.text
	# Let the existing segmented control size itself from the approved copy,
	# using the same font and painted end-cap inset as Browse/Sell. No icon.
	var font_size: int = button.get_theme_font_size("font_size")
	var caption_width: float = Typography.ui_font().get_string_size("Remove a spell from your deck.", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	button.custom_minimum_size.x = maxf(sell.custom_minimum_size.x, ceilf(caption_width) + Typography.scaled_value(button, preload("res://scripts/scavenger_action.gd").SEGMENT_LABEL_INSET * 2.0))
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

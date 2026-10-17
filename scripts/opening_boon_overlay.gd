extends Control

signal chosen(boon: String, choices: Array)
signal purge_selection_ready

const Rules = preload("res://scripts/opening_boon_rules.gd")
const Data = preload("res://scripts/game_data.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Inline = preload("res://scripts/inline_icon_text.gd")
const Confirmation = preload("res://scripts/magic_purge_confirmation.gd")
const TooltipStack = preload("res://scripts/card_focus_tooltip_stack.gd")
const Router = preload("res://scripts/input_router.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const SecondaryLayout = preload("res://scripts/opening_boon_secondary_layout.gd")
const SecondaryTooltips = preload("res://scripts/opening_boon_tooltip_stack.gd")
const Inspection = preload("res://scripts/opening_boon_inspection.gd")
const OfferCard = preload("res://scripts/opening_boon_card.gd")
const CardScene = preload("res://scenes/card_widget.tscn")
# Director geometry and the supplied reward reference (native 1920 × 1080).
const OFFER_ORIGIN := Vector2(454.0, 210.0)
const OFFER_GAP: float = 56.0
const ACTION_TOP: float = 650.0
const REWARD_REFERENCE_BANNER_RECT := Rect2(440.0, 116.0, 1040.0, 82.0)
const SECONDARY_RULES_TOP: float = 205.0
const THREE_CARD_GAP: float = 58.0
const MANY_CARD_GAP: float = 24.0
const PURGE_SELECTED_LIFT: float = 20.0
var _host: Node
var _state: Dictionary
var _content: Control
var _controls: Array[Control]
var _selected: Dictionary = {}
var _purges: Array[String]
var _purge_indices: Array[int]
var _tooltip: Control
var _confirmation: Control
var _confirmation_backdrop: Control
var _generation: int = 0
var _secondary_tooltips: Control
var _inspection := Inspection.new()

func configure(host: Node, state: Dictionary) -> void:
	_host = host
	_state = state.duplicate(true)
	name = "OpeningBoonOverlay"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_as_relative = false
	z_index = int(host.get("_dialogue_overlay").z_index) + 1
	# The screen dimmer sits behind the actual NPC dialogue, while this input
	# scope sits above it. The dialogue remains visible and cannot advance.
	var backdrop: Control = host.get("_relic_choice_backdrop").duplicate()
	backdrop.name = "OpeningBoonBackdrop"
	backdrop.z_as_relative = false
	backdrop.z_index = z_index - 2
	backdrop.show()
	add_child(backdrop)
	_content = Control.new()
	_content.name = "OpeningBoonContent"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	show_offers()

func _clear() -> void:
	_generation += 1
	_inspection.clear()
	_secondary_tooltips = null
	_hide_preview()
	_controls.clear()
	if is_instance_valid(_confirmation): _confirmation.queue_free()
	if is_instance_valid(_confirmation_backdrop): _confirmation_backdrop.queue_free()
	_confirmation = null
	_confirmation_backdrop = null
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

func show_offers() -> void:
	_clear()
	_selected.clear()
	_purges.clear()
	_purge_indices.clear()
	var row := Control.new()
	row.name = "OpeningBoonColumns"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(row)
	row.position = OFFER_ORIGIN
	row.size = Vector2(OfferCard.CARD_SIZE.x * 3.0 + OFFER_GAP * 2.0, OfferCard.CARD_SIZE.y)
	var offers: Array = _state[Rules.STATE_KEY]["offers"]
	for index: int in range(offers.size()):
		var offer: Dictionary = offers[index]
		var slot := Control.new()
		slot.name = "BoonSlot_%d" % index
		slot.position.x = index * (OfferCard.CARD_SIZE.x + OFFER_GAP)
		slot.size = OfferCard.CARD_SIZE
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(slot)
		var card := OfferCard.new()
		slot.add_child(card)
		card.configure(_host, offer)
		card.activated.connect(select_offer.bind(offer))
		card.preview_requested.connect(_preview)
		card.preview_hidden.connect(_hide_preview)
		_controls.append(card)
	_action(str(Rules.definitions()["dialogue"]["decline"]), "DeclineOpeningBoon", func() -> void: chosen.emit("", []))
	_contain_focus()

func _action(text: String, node_name: String, action: Callable) -> void:
	# Exact same pill factory as SKIP & RECOVER, without its health icon.
	var button: Button = _host.call("_reward_secondary_button", node_name, text, action, "")
	_content.add_child(button)
	button.size = button.get_combined_minimum_size()
	button.position = Vector2((1920.0 - button.size.x) * 0.5, ACTION_TOP)
	_controls.append(button)

func select_offer(offer: Dictionary) -> void:
	var id: String = str(offer["boon"])
	if id not in ["elemental_gift", "blood_price", "purge"]:
		chosen.emit(id, [])
		return
	_clear()
	_selected = offer.duplicate(true)
	_purges.clear()
	_purge_indices.clear()
	_banner(str(Rules.definitions()["boons"][id]["name"]).to_upper())
	var rules := RichTextLabel.new()
	rules.name = "BoonSecondaryRules"
	rules.bbcode_enabled = true
	rules.scroll_active = false
	rules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Typography.apply_rich_text_role(rules, Typography.ROLE_BODY)
	_content.add_child(rules)
	rules.position = Vector2(24.0, SECONDARY_RULES_TOP)
	rules.size = Vector2(1872.0, Typography.SIZE_BODY * 2.0)
	Inline.apply_to(rules, "[center]" + Rules.text(offer) + "[/center]", Inline.DEFAULT_ICON_SCALE, true)
	var spells: Array = Rules.starter_spells(_state) if id == "purge" else offer["spells"]
	var card_size: Vector2 = _host.call("_reward_choice_card_size", spells.size(), true)
	var gap: float = THREE_CARD_GAP if spells.size() == 3 else MANY_CARD_GAP
	var row := Control.new()
	row.name = "BoonSpellChoices"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size = Vector2(card_size.x * spells.size() + gap * (spells.size() - 1), card_size.y)
	_content.add_child(row)
	_secondary_tooltips = SecondaryTooltips.new()
	_content.add_child(_secondary_tooltips)
	_secondary_tooltips.name = "BoonSecondaryTooltipStack"
	_secondary_tooltips.minimum_top = rules.get_global_rect().end.y + SecondaryLayout.RULES_TO_TOOLTIP
	_inspection.configure(_secondary_tooltips)
	for index: int in range(spells.size()):
		_spell_choice(row, str(spells[index]), index, card_size, gap)
	var constants: Dictionary = _host.get_script().get_script_constant_map()
	SecondaryLayout.arrange(row, _controls, card_size, gap, rules, ACTION_TOP, float(constants["REWARD_CARD_HOVER_LIFT"]), float(constants["REWARD_CARD_HOVER_SCALE"]))
	_action(str(Rules.definitions()["dialogue"]["back"]), "BackFromBoonSpellChoice", show_offers)
	_contain_focus()

func _banner(text: String) -> void:
	var banner: Control = _host.get("_relic_choice_banner").duplicate()
	banner.name = "BoonSelectionBanner"
	banner.show()
	_content.add_child(banner)
	banner.set_anchors_preset(Control.PRESET_TOP_LEFT)
	banner.position = REWARD_REFERENCE_BANNER_RECT.position
	banner.size = REWARD_REFERENCE_BANNER_RECT.size
	var title: Label = _host.get("_relic_choice_title").duplicate()
	title.name = "BoonSelectionTitle"
	title.text = text
	var constants: Dictionary = _host.get_script().get_script_constant_map()
	Typography.set_label_size(title, int(constants["SELECTION_TITLE_FONT_SIZE"]))
	_host.call("_apply_relic_choice_title_depth", _host.call("_relic_choice_title_accent", str(constants["REWARD_CHOICE_TITLE_TEXT"])), true, title)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.show()
	_content.add_child(title)
	title.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title.position = banner.position
	title.size = banner.size

func _spell_choice(row: Control, id: String, index: int, card_size: Vector2, gap: float) -> void:
	var widget: Control = CardScene.instantiate()
	widget.name = "BoonSpellChoice_%d_%s" % [index, id]
	widget.configure(id, false, false, true, false, true, true, Data.card_def(id))
	var constants: Dictionary = _host.get_script().get_script_constant_map()
	widget.set_hover_pose(constants["REWARD_CARD_HOVER_LIFT"], constants["REWARD_CARD_HOVER_SCALE"])
	var slot: Control = _host.call("_reward_card_choice_slot", widget, id, card_size, _state)
	slot.name = "BoonSpellSlot_%d" % index
	row.add_child(slot)
	slot.position.x = index * (card_size.x + gap)
	widget.focus_mode = Control.FOCUS_ALL
	widget.set_native_tooltips_enabled(false)
	widget.activated.connect(_choose_spell.bind(id, index))
	widget.gui_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed(Router.ACTION_ACCEPT):
			widget.accept_event()
			_choose_spell(id, index)
	)
	widget.focus_entered.connect(_spell_highlight.bind(widget, index))
	widget.focus_exited.connect(_spell_highlight.bind(widget, index))
	_inspection.bind_card(widget, id)
	_controls.append(widget)

func _spell_highlight(widget: Control, index: int) -> void:
	widget.set_external_highlighted(_purge_indices.has(index) or widget.has_focus())

func _choose_spell(card: String, index: int) -> void:
	if (is_instance_valid(_confirmation) and _confirmation.visible) or _purges.size() >= Rules.purge_count(): return
	var id: String = str(_selected.get("boon", ""))
	if id != "purge":
		chosen.emit(id, [card])
		return
	if _purge_indices.has(index):
		var at: int = _purge_indices.find(index)
		_purge_indices.remove_at(at)
		_purges.remove_at(at)
	else:
		_purge_indices.append(index)
		_purges.append(card)
	_update_purge_poses()
	if _purges.size() == Rules.purge_count():
		purge_selection_ready.emit()
		# Submit both selected cards before the confirmation covers them. The
		# signal lets the visual probe capture that actual presentation boundary.
		var generation: int = _generation
		if DisplayServer.get_name() == "headless": await get_tree().process_frame
		else: await RenderingServer.frame_post_draw
		if is_inside_tree() and generation == _generation and _purges.size() == Rules.purge_count(): _present_purge_confirmation()

func _update_purge_poses() -> void:
	for index: int in range(_controls.size() - 1):
		var widget: Control = _controls[index]
		var selected: bool = _purge_indices.has(index)
		var badge: PanelContainer = widget.get_node("RewardOwnershipBadge")
		var label: Label = badge.get_child(0)
		label.text = "REMOVE" if selected else "OWNED"
		var accent: Color = Palette.DANGER if selected else Palette.TEXT_2
		badge.add_theme_stylebox_override("panel", _host.call("_reward_card_badge_style", accent))
		label.add_theme_color_override("font_color", accent if selected else accent.lightened(0.20))
		var factor: float = widget.get_parent().scale.x
		var constants: Dictionary = _host.get_script().get_script_constant_map()
		widget.set_hover_pose(-PURGE_SELECTED_LIFT / factor if selected else float(constants["REWARD_CARD_HOVER_LIFT"]), 1.0 if selected else float(constants["REWARD_CARD_HOVER_SCALE"]))
		widget.set_external_highlighted(selected or widget.has_focus())
		# Selection is immediate; no third choice can replace a pending pair.
		widget.call("_update_pose", true)

func _present_purge_confirmation() -> void:
	_hide_preview()
	_confirmation_backdrop = Confirmation.backdrop()
	add_child(_confirmation_backdrop)
	_confirmation_backdrop.z_index = 100
	_confirmation = Confirmation.new()
	add_child(_confirmation)
	_confirmation.z_index = 101
	_confirmation.configure()
	_confirmation.accepted.connect(func() -> void: chosen.emit("purge", _purges.duplicate()))
	_confirmation.cancelled.connect(_cancel_purge_confirmation)
	var names := PackedStringArray()
	for id: String in _purges: names.append(str(Data.card_def(id).get("name", id)))
	_confirmation.present(", ".join(names), 0, false, true)

func _cancel_purge_confirmation() -> void:
	if is_instance_valid(_confirmation): _confirmation.queue_free()
	if is_instance_valid(_confirmation_backdrop): _confirmation_backdrop.queue_free()
	_confirmation = null
	_confirmation_backdrop = null
	_purges.clear()
	_purge_indices.clear()
	_update_purge_poses()
	focus_default()

func cancel() -> void:
	if is_instance_valid(_confirmation) and _confirmation.visible: _cancel_purge_confirmation()
	elif not _selected.is_empty(): show_offers()
	# The offer step only resolves via an explicit card or Take nothing.

func contain_input(event: InputEvent) -> bool:
	# The confirmation owns pointer/focus input while it covers the card row.
	if not is_instance_valid(_confirmation) or not _confirmation.visible:
		_inspection.handle_input(event)
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed(Router.ACTION_CANCEL):
		cancel()
		return true
	var focus: Control = get_viewport().gui_get_focus_owner()
	if is_instance_valid(_confirmation) and _confirmation.visible:
		if focus == null or not _confirmation.is_ancestor_of(focus):
			focus_default()
			return true
		return false
	if focus != null and is_ancestor_of(focus) and focus.is_visible_in_tree(): return false
	for action: StringName in [&"ui_focus_next", &"ui_focus_prev", &"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_accept", Router.ACTION_ACCEPT]:
		if event.is_action_pressed(action):
			focus_default()
			return true
	return false

func _contain_focus() -> void:
	if _controls.is_empty(): return
	var last: Control = _controls.back()
	var count: int = _controls.size() - 1
	for index: int in range(_controls.size()):
		var control: Control = _controls[index]
		control.focus_previous = control.get_path_to(_controls[posmod(index - 1, _controls.size())])
		control.focus_next = control.get_path_to(_controls[(index + 1) % _controls.size()])
		var is_action: bool = index == count
		control.focus_neighbor_left = control.get_path_to(last if is_action else _controls[posmod(index - 1, count)])
		control.focus_neighbor_right = control.get_path_to(last if is_action else _controls[(index + 1) % count])
		control.focus_neighbor_top = control.get_path_to(_controls[count / 2] if is_action else control)
		control.focus_neighbor_bottom = control.get_path_to(_controls[count / 2] if is_action else last)
	call_deferred("focus_default")

func focus_default() -> void:
	if not is_inside_tree(): return
	if is_instance_valid(_confirmation) and _confirmation.visible: _confirmation.cancel_button.grab_focus()
	elif not _controls.is_empty(): _controls[0].grab_focus()

func _preview(owner: Control, id: String, kind: String) -> void:
	_hide_preview()
	if kind == "relic":
		_host.get("_card_focus_tooltip_stack").show_relic(owner, Data.relic_def(id))
		return
	_tooltip = _host.call("_build_equipment_tooltip_panel", id) if kind == "item" else _host.call("_build_card_tooltip_panel", id)
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.z_as_relative = false
	_tooltip.z_index = 1321
	add_child(_tooltip)
	call_deferred("_position_preview", owner)

func _position_preview(owner: Control) -> void:
	if not is_instance_valid(_tooltip) or not is_instance_valid(owner): return
	_tooltip.size = _tooltip.get_combined_minimum_size()
	var bounds: Rect2 = get_viewport_rect().grow(-TooltipStack.SAFE_MARGIN)
	var anchor: Rect2 = owner.get_global_rect()
	var point: Vector2 = anchor.end + Vector2(TooltipStack.CARD_GAP, 0.0)
	_tooltip.global_position = Vector2(clampf(point.x, bounds.position.x, bounds.end.x - _tooltip.size.x), clampf(anchor.position.y, bounds.position.y, bounds.end.y - _tooltip.size.y))

func _hide_preview() -> void:
	if is_instance_valid(_secondary_tooltips): _secondary_tooltips.hide_stack(true)
	if is_instance_valid(_tooltip):
		_tooltip.hide()
		_tooltip.queue_free()
	_tooltip = null
	if is_instance_valid(_host): _host.get("_card_focus_tooltip_stack").hide_stack(true)

func _exit_tree() -> void:
	_inspection.clear()
	_hide_preview()

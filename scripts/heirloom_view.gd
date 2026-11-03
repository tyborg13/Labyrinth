extends Control

signal chosen(item: String)
signal confirmation
signal finished
const Notifications = preload("res://scripts/run_notification_queue.gd")
const Rules = preload("res://scripts/opening_boon_rules.gd")
const Card = preload("res://scripts/heirloom_card.gd")
const Ceremony = preload("res://scripts/heirloom_ceremony.gd")
const Router = preload("res://scripts/input_router.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Motion = preload("res://scripts/settings_store.gd")
const TooltipStack = preload("res://scripts/card_focus_tooltip_stack.gd")
const CARD_GAP: float = 30.0
const ROW_TOP: float = 168.0
const LEAVE_RECT := Rect2(780.0, 724.0, 360.0, 50.0)
var cards: Array[Control]
var header: Control
var row: Control
var leave_button: Button
var ceremony: Control
var selected_index: int = 0
var _last_card: int = 0
var _host: Node
var _tooltip: Control
var _committing: bool = false

func configure(host: Node, state: Dictionary) -> void:
	_host = host
	Notifications.hold(host, self)
	name = "HeirloomView"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_as_relative = false
	z_index = int(host.get("_dialogue_overlay").z_index) + 1
	var backdrop: Control = host.get("_relic_choice_backdrop").duplicate()
	backdrop.name = "OpeningBoonBackdrop"
	backdrop.z_as_relative = false
	backdrop.z_index = z_index - 2
	backdrop.show()
	add_child(backdrop)
	header = Control.new()
	header.name = "HeirloomHeader"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)
	header.position = Vector2(0.0, 84.0)
	header.size = Vector2(1920.0, 70.0)
	var eyebrow: Label = Card.label_at(header, "HeirloomEyebrow", "LEAVE AN HEIRLOOM", Vector2.ZERO, Vector2(1920.0, 0.0), 16, Palette.GOLD, true)
	Card.space_eyebrow(eyebrow, 0.32)
	Card.label_at(header, "HeirloomExplanation", "He offers it back to you at the start of your next run.", Vector2(0.0, eyebrow.size.y + 10.0), Vector2(1920.0, 0.0), 21, Palette.TEXT_2)
	row = Control.new()
	row.name = "HeirloomCards"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var pieces: Array[String] = Rules.heirloom_pieces(state)
	row.size = Vector2(pieces.size() * Card.HEIRLOOM_SIZE.x + (pieces.size() - 1) * CARD_GAP, Card.HEIRLOOM_SIZE.y)
	row.position = Vector2((1920.0 - row.size.x) * 0.5, ROW_TOP)
	for index: int in range(pieces.size()):
		var slot := Control.new()
		slot.name = "HeirloomSlot_%d" % index
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(slot)
		slot.position.x = index * (Card.HEIRLOOM_SIZE.x + CARD_GAP)
		slot.size = Card.HEIRLOOM_SIZE
		var card := Card.new()
		slot.add_child(card)
		card.configure(host, {"id": pieces[index], "state": state})
		card.activated.connect(_choose.bind(index))
		card.mouse_entered.connect(_focus.bind(index))
		card.focus_entered.connect(_highlight.bind(index))
		card.preview_requested.connect(_preview)
		card.preview_hidden.connect(_hide_preview)
		cards.append(card)
	leave_button = host.call("_reward_secondary_button", "LeaveNothing", Rules.definitions()["dialogue"]["leave_nothing"], _choose.bind(pieces.size()), "", LEAVE_RECT.size.x)
	add_child(leave_button)
	Typography.set_button_size(leave_button, 21)
	leave_button.custom_minimum_size = LEAVE_RECT.size
	leave_button.size = LEAVE_RECT.size
	leave_button.position = LEAVE_RECT.position
	leave_button.mouse_entered.connect(_focus.bind(cards.size()))
	leave_button.focus_entered.connect(_highlight.bind(cards.size()))
	_contain_focus()
	_highlight(0, true)
	call_deferred("focus_default")

func _contain_focus() -> void:
	for index: int in range(cards.size() + 1):
		var control: Control = leave_button if index == cards.size() else cards[index]
		control.focus_previous = control.get_path_to(leave_button if index == 0 else cards[index - 1])
		control.focus_next = control.get_path_to(cards[0] if index == cards.size() else (leave_button if index == cards.size() - 1 else cards[index + 1]))
		control.focus_neighbor_left = control.get_path_to(control if control == leave_button else cards[posmod(index - 1, cards.size())])
		control.focus_neighbor_right = control.get_path_to(control if control == leave_button else cards[(index + 1) % cards.size()])
		control.focus_neighbor_bottom = control.get_path_to(leave_button)
		control.focus_neighbor_top = control.get_path_to(cards[_last_card] if control == leave_button else control)

func _focus(index: int) -> void:
	if _committing: return
	(leave_button if index == cards.size() else cards[index]).grab_focus()

func _highlight(index: int, immediate: bool = false) -> void:
	if _committing: return
	selected_index = index
	if index < cards.size(): _last_card = index
	_hide_preview()
	for at: int in range(cards.size()):
		cards[at].set_emphasis(at == index, immediate)
		cards[at].modulate = Color.WHITE if at == index else Color.WHITE * Card.DIM_BRIGHTNESS
		cards[at].modulate.a = 1.0

func focus_default() -> void:
	if is_inside_tree() and not _committing: _focus(selected_index)

func contain_input(event: InputEvent) -> bool:
	if is_instance_valid(ceremony):
		if event.is_pressed() or event is InputEventMouseMotion or (event is InputEventJoypadMotion and absf(event.axis_value) > Router.JOYSTICK_ACTIVITY_THRESHOLD): ceremony.skip()
		return true
	if _committing: return true
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed(Router.ACTION_CANCEL): _focus(cards.size())
	elif event.is_action_pressed("ui_down"): _focus(cards.size())
	elif event.is_action_pressed("ui_up"): _focus(_last_card)
	elif event.is_action_pressed("ui_left") and selected_index < cards.size(): _focus(posmod(selected_index - 1, cards.size()))
	elif event.is_action_pressed("ui_right") and selected_index < cards.size(): _focus((selected_index + 1) % cards.size())
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed(Router.ACTION_ACCEPT): _choose(selected_index)
	else: return false
	return true

func _choose(index: int) -> void:
	if _committing: return
	chosen.emit("" if index == cards.size() else str(cards[index].item_id))

func play(item: String) -> void:
	_committing = true
	_hide_preview()
	var selected: Control
	for card: Control in cards:
		card.freeze_pose()
		card.focus_mode = Control.FOCUS_NONE
		if card.item_id == item: selected = card
	leave_button.focus_mode = Control.FOCUS_NONE
	ceremony = Ceremony.new()
	add_child(ceremony)
	ceremony.z_index = 100
	ceremony.confirmation.connect(func() -> void: confirmation.emit())
	ceremony.finished.connect(func() -> void: finished.emit())
	ceremony.configure(_host, self, selected, Motion.applied_reduced_motion_enabled())

func _preview(owner: Control, id: String, _kind: String) -> void:
	if _committing: return
	_hide_preview()
	_tooltip = _host.call("_build_card_tooltip_panel", id)
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.z_as_relative = false
	_tooltip.z_index = 1321
	add_child(_tooltip)
	_position_preview.call_deferred(owner)

func _position_preview(owner: Control) -> void:
	if not is_instance_valid(_tooltip) or not is_instance_valid(owner): return
	_tooltip.size = _tooltip.get_combined_minimum_size()
	var bounds: Rect2 = get_viewport_rect().grow(-TooltipStack.SAFE_MARGIN)
	_tooltip.global_position = Vector2(clampf(owner.get_global_rect().end.x + TooltipStack.CARD_GAP, bounds.position.x, bounds.end.x - _tooltip.size.x), clampf(owner.global_position.y, bounds.position.y, bounds.end.y - _tooltip.size.y))

func _hide_preview() -> void:
	if is_instance_valid(_tooltip):
		_tooltip.hide()
		_tooltip.queue_free()
	_tooltip = null

func _exit_tree() -> void:
	_hide_preview()
	Notifications.release(_host, self)

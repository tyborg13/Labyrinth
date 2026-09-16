extends Control
class_name GraftwrightView

signal graft_requested(recipient: String, donor: String, donor_index: int, target_index: int)
signal leave_requested
signal sound_requested(cue: String)
signal interaction_changed

const Data = preload("res://scripts/game_data.gd")
const Rules = preload("res://scripts/graftwright_rules.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const TooltipButton = preload("res://scripts/ui_tooltip_button.gd")
const CardScene = preload("res://scenes/card_widget.tscn")
const ThreadEffect = preload("res://scripts/graftwright_thread_effect.gd")
const SIZE := Vector2(1920, 1080)
const VIOLET := Color("d1a2ff")
const IVORY := Color("eddfc9")
const PAGE_SIZE: int = 7

var state: Dictionary = {}
var recipient: String = ""
var donor: String = ""
var donor_index: int = -1
var target_index: int = -1
var busy: bool = false
var reduced_motion: bool = false
var _room_identity: String = ""
var _page: int = 0
var _donor_page: int = 0
var _elapsed: float = 0.0
var _canvas: Control
var _content: Control
var _portrait: TextureRect
var _commit: Button
var _leave: Button
var _detail: Label
var _consequence: Label
var _source_cards: Array[Button]
var _target_cards: Array[Button]
var _source_icon: TextureRect
var _recipient_icon: TextureRect
var _effect: Control
var _skin := UiSkin.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(_layout)

func _ensure_built() -> void:
	if _canvas != null: return
	var backdrop := ColorRect.new()
	backdrop.color = Color("0d0b10")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	_canvas = Control.new()
	_canvas.size = SIZE
	add_child(_canvas)
	_picture(_canvas, "res://assets/art/ui/graftwright/atelier.png", Rect2(Vector2.ZERO, SIZE), false)
	_portrait = _picture(_canvas, "res://assets/art/npcs/graftwright.png", Rect2(-35, 175, 510, 770))
	_label(_canvas, "THE GRAFTWRIGHT", Rect2(465, 30, 1400, 75), 56, IVORY)
	_label(_canvas, "What remains can become something new.", Rect2(35, 949, 390, 70), 22, Color("b7a9c1"), true)
	_content = Control.new()
	_content.size = SIZE
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_content)
	_layout()

func _layout() -> void:
	if _canvas == null: return
	var factor: float = minf(size.x / SIZE.x, size.y / SIZE.y)
	_canvas.scale = Vector2.ONE * factor
	_canvas.position = (size - SIZE * factor) * 0.5

func configure(next_state: Dictionary, motion_reduced: bool) -> void:
	_ensure_built()
	if busy: return
	state = next_state.duplicate(true)
	reduced_motion = motion_reduced
	var coord: Vector2i = state.get("current_room", Vector2i.ZERO)
	var identity: String = "%d:%d:%s" % [int(state.get("run_index", 0)), int(state.get("seed", 0)), str(coord)]
	if identity != _room_identity:
		_room_identity = identity
		recipient = ""
		donor = ""
		donor_index = -1
		target_index = -1
		_page = 0
		_donor_page = 0
	if _used():
		var result: Dictionary = _result()
		recipient = str(result.get("recipient", ""))
	else:
		var items: Array[String] = Rules.owned(state)
		if not items.has(recipient):
			recipient = ""
			var best_rarity: int = -1
			for id: String in items:
				var rarity: int = Data.CARD_RARITY_TIERS.find(Data.equipment_rarity(id))
				if rarity > best_rarity and not Rules.donors(state, id).is_empty():
					recipient = id
					best_rarity = rarity
			if not recipient.is_empty(): _page = int(items.find(recipient) / PAGE_SIZE)
		_validate_donor()
	_rebuild()

func present() -> void:
	var entering: bool = not visible
	show()
	get_parent().move_child(self, -1)
	if entering and not reduced_motion:
		_canvas.modulate.a = 0.0
		create_tween().tween_property(_canvas, "modulate:a", 1.0, 0.28)
	if entering: call_deferred("focus_first")

func focus_first() -> void:
	if busy or not visible: return
	if _used() or recipient.is_empty():
		_leave.grab_focus()
	elif not _source_cards.is_empty():
		_source_cards[0].grab_focus()

func request_leave() -> void:
	if not busy: leave_requested.emit()

func _used() -> bool:
	return bool(Graph.room(state, state.get("current_room", Vector2i.ZERO)).get("graft_used", false))

func _result() -> Dictionary:
	return Graph.room(state, state.get("current_room", Vector2i.ZERO)).get("graft_result", state.get("last_graft", {})) as Dictionary

func _validate_donor() -> void:
	var choices: Array[String] = Rules.donors(state, recipient) if not recipient.is_empty() else _empty_strings()
	if not choices.has(donor):
		donor = choices[0] if not choices.is_empty() else ""
		donor_index = -1
		target_index = -1

func _empty_strings() -> Array[String]:
	var result: Array[String]
	return result

func select_recipient(id: String) -> void:
	if busy or _used() or Rules.donors(state, id).is_empty(): return
	recipient = id
	donor = ""
	donor_index = -1
	target_index = -1
	_donor_page = 0
	_validate_donor()
	_rebuild()
	focus_first()
	sound_requested.emit("select")

func select_donor(id: String) -> void:
	if busy or _used() or not Rules.pair_error(state, recipient, id).is_empty(): return
	donor = id
	donor_index = -1
	_rebuild()
	focus_first()
	sound_requested.emit("select")

func select_source(index: int) -> void:
	if busy or _used(): return
	donor_index = index
	var inherited: int = Rules.inherited_index(state, recipient)
	if inherited >= 0: target_index = inherited
	elif Data.equipment_cards(recipient, state).size() == 1: target_index = 0
	_rebuild()
	# Keep destructive confirmation out of the automatic focus path.
	if not _target_cards.is_empty(): _target_cards[maxi(target_index, 0)].grab_focus()
	sound_requested.emit("select")

func select_target(index: int) -> void:
	if busy or _used(): return
	var inherited: int = Rules.inherited_index(state, recipient)
	if inherited >= 0 and inherited != index: return
	target_index = index
	_rebuild()
	if index < _target_cards.size(): _target_cards[index].grab_focus()
	sound_requested.emit("select")

func _rebuild() -> void:
	if _content == null: return
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_source_cards.clear()
	_target_cards.clear()
	_source_icon = null
	_recipient_icon = null
	_commit = null
	_detail = null
	_consequence = null
	if _used():
		_build_result()
		_wire_focus()
		return
	var items: Array[String] = Rules.owned(state)
	_label(_content, "KEEP", Rect2(480, 115, 150, 32), 22, Color("a9d6b6"))
	_label(_content, "Choose equipment", Rect2(650, 115, 660, 32), 23, IVORY)
	_page = clampi(_page, 0, maxi(0, int((items.size() - 1) / PAGE_SIZE)))
	for i: int in range(PAGE_SIZE):
		var index: int = _page * PAGE_SIZE + i
		if index >= items.size(): break
		var id: String = items[index]
		var button: Button = _item_button(id, Rect2(480 + i * 189, 153, 177, 130), id == recipient, func() -> void: select_recipient(id))
		button.name = "Keep_" + id
		button.disabled = Rules.donors(state, id).is_empty()
		if button.disabled: button.tooltip_text = "Find another %s to inherit from." % Data.equipment_slot(id)
	if items.size() > PAGE_SIZE:
		var previous: Button = _button("‹", Rect2(1740, 104, 54, 42), func() -> void: _change_page(-1, false))
		previous.name = "KeepPrevious"
		previous.disabled = _page == 0
		var next: Button = _button("›", Rect2(1802, 104, 54, 42), func() -> void: _change_page(1, false))
		next.name = "KeepNext"
		next.disabled = (_page + 1) * PAGE_SIZE >= items.size()
	if recipient.is_empty() or donor.is_empty():
		_label(_content, "A pattern needs two pieces.", Rect2(560, 400, 1230, 65), 36, IVORY, true)
		_label(_content, "Bring two pieces of the same equipment type.", Rect2(600, 488, 1150, 48), 24, Color("bbb0c6"), true)
		_leave = _button("Leave", Rect2(1580, 936, 260, 64), request_leave)
		_wire_focus()
		return
	_label(_content, "SACRIFICE", Rect2(480, 305, 650, 36), 26, Color("ecb2b9"))
	_label(_content, "INHERIT", Rect2(1200, 305, 650, 36), 26, Color("b8d6c8"))
	_source_icon = _picture(_content, str(Data.equipment_def(donor).get("icon_path", "")), Rect2(481, 345, 80, 80))
	_label(_content, _item_name(donor), Rect2(575, 350, 525, 34), 27, IVORY)
	var choices: Array[String] = Rules.donors(state, recipient)
	_donor_page = clampi(_donor_page, 0, maxi(0, int((choices.size() - 1) / 5)))
	for i: int in range(5):
		var index: int = _donor_page * 5 + i
		if index >= choices.size(): break
		var id: String = choices[index]
		var button: Button = _button("", Rect2(574 + i * 78, 392, 70, 62), func() -> void: select_donor(id), UiSkin.VARIANT_SELECTED if id == donor else UiSkin.VARIANT_STANDARD)
		button.name = "Donor_" + id
		button.tooltip_text = _item_name(id)
		_picture(button, str(Data.equipment_def(id).get("icon_path", "")), Rect2(9, 5, 52, 52))
	if choices.size() > 5:
		var previous: Button = _button("‹", Rect2(980, 400, 52, 44), func() -> void: _change_page(-1, true))
		previous.name = "DonorPrevious"
		previous.disabled = _donor_page == 0
		var next: Button = _button("›", Rect2(1040, 400, 52, 44), func() -> void: _change_page(1, true))
		next.name = "DonorNext"
		next.disabled = (_donor_page + 1) * 5 >= choices.size()
	_recipient_icon = _picture(_content, str(Data.equipment_def(recipient).get("icon_path", "")), Rect2(1200, 345, 100, 100))
	_label(_content, _item_name(recipient), Rect2(1315, 348, 550, 35), 27, IVORY)
	_label(_content, Data.equipment_slot(recipient).capitalize() + " · Inherits one card", Rect2(1315, 395, 500, 30), 20, Color("b0a6bc"))
	_label(_content, "Choose a card to carry forward", Rect2(480, 460, 655, 30), 20, Color("c6b4d7"))
	_label(_content, "Choose a card to replace" if Rules.inherited_index(state, recipient) < 0 else "Replace the inherited card", Rect2(1200, 460, 655, 30), 20, Color("c6b4d7"))
	var source: Array = Data.equipment_cards(donor, state)
	var target: Array = Data.equipment_cards(recipient, state)
	for i: int in range(source.size()):
		var index: int = i
		var button: Button = _card(str(source[i]), Vector2(480 + i * 220, 504), i == donor_index, func() -> void: select_source(index))
		button.name = "SourceCard_%d" % i
		if i == donor_index:
			_label(_content, "Carry forward", Rect2(477 + i * 220, 810, 216, 42), 20, VIOLET, true)
		_source_cards.append(button)
	for i: int in range(target.size()):
		var index: int = i
		var preview: bool = i == target_index and donor_index >= 0 and donor_index < source.size()
		var id: String = str(source[donor_index]) if preview else str(target[i])
		var button: Button = _card(id, Vector2(1200 + i * 220, 504), preview, func() -> void: select_target(index))
		button.name = "TargetCard_%d" % i
		var inherited: int = Rules.inherited_index(state, recipient)
		button.disabled = inherited >= 0 and i != inherited
		if button.disabled: button.tooltip_text = "This item's inherited card is the replaceable slot."
		if preview:
			_label(_content, "Replaces " + _card_name(str(target[i])), Rect2(1194 + i * 220, 810, 226, 48), 18, VIOLET, true)
		_target_cards.append(button)
	_detail = _label(_content, "", Rect2(480, 864, 1370, 38), 21, IVORY, true)
	_consequence = _label(_content, "", Rect2(530, 915, 1000, 56), 23, Color("efc2bf"), true)
	var reason: String = Rules.error(state, recipient, donor, donor_index, target_index)
	if donor_index >= 0:
		_detail.text = _card_name(str(source[donor_index])) + " · " + str(Data.card_def(str(source[donor_index])).get("description", ""))
	_consequence.text = _item_name(donor) + " will be destroyed." if reason.is_empty() else reason
	if reason.is_empty() and not Rules.equipped_slot(state, donor).is_empty():
		if not Rules.equipped_slot(state, recipient).is_empty():
			_consequence.text += "  Trinket slot will be empty."
		else:
			_consequence.text += "  " + _item_name(recipient) + " will be equipped."
	_commit = _button("Graft", Rect2(1540, 924, 302, 76), _request_graft, UiSkin.VARIANT_DESTRUCTIVE)
	_commit.name = "GraftCommit"
	_commit.disabled = not reason.is_empty()
	_leave = _button("Leave", Rect2(480, 992, 210, 56), request_leave)
	_leave.name = "GraftLeave"
	_wire_focus()

func _wire_focus() -> void:
	# Keep native keyboard/controller navigation inside this modal, including
	# after a selection rebuild or page change removes the old focused button.
	var buttons: Array[Button]
	for child: Node in _content.get_children():
		if child is Button and not (child as Button).disabled: buttons.append(child as Button)
	for i: int in range(buttons.size()):
		var button: Button = buttons[i]
		button.focus_next = button.get_path_to(buttons[(i + 1) % buttons.size()])
		button.focus_previous = button.get_path_to(buttons[posmod(i - 1, buttons.size())])
		for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			var direction: Vector2 = [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN][side]
			var neighbor: Button = button
			var best: float = INF
			for candidate: Button in buttons:
				var delta: Vector2 = candidate.get_rect().get_center() - button.get_rect().get_center()
				var along: float = delta.dot(direction)
				if along <= 1.0: continue
				var across: float = absf(delta.cross(direction))
				var score: float = along + across * 3.0
				if score < best:
					best = score
					neighbor = candidate
			button.set_focus_neighbor(side, button.get_path_to(neighbor))

func _change_page(direction: int, donor_row: bool) -> void:
	if donor_row: _donor_page += direction
	else: _page += direction
	_rebuild()
	var prefix: String = "Donor" if donor_row else "Keep"
	var arrow: Button = _content.find_child(prefix + ("Next" if direction > 0 else "Previous"), true, false) as Button
	if arrow != null and arrow.disabled:
		arrow = _content.find_child(prefix + ("Previous" if direction > 0 else "Next"), true, false) as Button
	if arrow != null: arrow.grab_focus()

func _build_result() -> void:
	var result: Dictionary = _result()
	_label(_content, "A NEW PATTERN", Rect2(565, 175, 1200, 60), 40, VIOLET, true)
	_recipient_icon = _picture(_content, str(Data.equipment_def(recipient).get("icon_path", "")), Rect2(1045, 260, 220, 200))
	_label(_content, _item_name(recipient), Rect2(685, 453, 1000, 45), 30, IVORY, true)
	var cards: Array = Data.equipment_cards(recipient, state)
	var start: float = 1185.0 - float(cards.size()) * 137.0
	for i: int in range(cards.size()):
		var card: Button = _card(str(cards[i]), Vector2(start + i * 275, 522), i == int(result.get("index", -1)), func() -> void: pass)
		card.name = "ResultCard_%d" % i
		if i == int(result.get("index", -1)):
			_label(_content, "Inherited", Rect2(start + i * 275, 817, 210, 36), 22, VIOLET, true)
	_detail = _label(_content, "", Rect2(480, 855, 1370, 38), 21, IVORY, true)
	_label(_content, _item_name(str(result.get("donor", ""))) + " consumed", Rect2(685, 897, 1000, 38), 22, Color("bdaabf"), true)
	_leave = _button("Continue", Rect2(1000, 954, 370, 72), request_leave, UiSkin.VARIANT_SELECTED)
	_leave.name = "GraftContinue"

func _request_graft() -> void:
	if busy or not Rules.error(state, recipient, donor, donor_index, target_index).is_empty(): return
	busy = true
	_commit.disabled = true
	interaction_changed.emit()
	graft_requested.emit(recipient, donor, donor_index, target_index)

func reject(message: String) -> void:
	busy = false
	_rebuild()
	if _consequence != null: _consequence.text = message
	focus_first()

func present_result(next_state: Dictionary) -> void:
	busy = true
	var effect := ThreadEffect.new()
	effect.name = "GraftRitual"
	effect.size = SIZE
	effect.origin = Vector2(580 + donor_index * 220, 642)
	effect.destination = Vector2(1300 + target_index * 220, 642)
	effect.reduced_motion = reduced_motion
	_canvas.add_child(effect)
	_effect = effect
	for child: Node in _content.find_children("*", "Button", true, false):
		(child as Button).disabled = true
	sound_requested.emit("unpick")
	_consequence.text = "Unpicking the old pattern…"
	var tween: Tween = create_tween()
	if reduced_motion:
		tween.tween_interval(0.18)
	else:
		tween.set_parallel(true)
		if _source_icon != null: tween.tween_property(_source_icon, "modulate:a", 0.0, 0.9)
		for card: Button in _source_cards: tween.tween_property(card, "modulate:a", 0.08, 0.95)
		tween.chain().tween_callback(func() -> void: _consequence.text = "Stitching a new one…"; sound_requested.emit("bind"))
		tween.tween_interval(0.95)
	await tween.finished
	if not is_inside_tree(): return
	effect.queue_free()
	_effect = null
	state = next_state.duplicate(true)
	busy = false
	_rebuild()
	sound_requested.emit("complete")
	_leave.grab_focus()
	if not reduced_motion:
		_content.modulate.a = 0.0
		create_tween().tween_property(_content, "modulate:a", 1.0, 0.25)

func _process(delta: float) -> void:
	if not visible: return
	_elapsed += delta
	if _portrait != null: _portrait.position.y = 175.0 + (0.0 if reduced_motion else sin(_elapsed * 0.8) * 2.0)

func _picture(parent: Node, path: String, rect: Rect2, fit: bool = true) -> TextureRect:
	var image := TextureRect.new()
	image.position = rect.position
	image.size = rect.size
	image.texture = Assets.load_texture(path)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if fit else TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _label(parent: Node, text: String, rect: Rect2, font_size: int, color: Color, centered: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if centered: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Typography.apply_label_role(label, Typography.ROLE_BODY_LARGE)
	Typography.set_label_size(label, font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("100d17"))
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label

func _button(text: String, rect: Rect2, action: Callable, variant: String = UiSkin.VARIANT_STANDARD) -> Button:
	var button := TooltipButton.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_skin.apply_button_stylebox_overrides(button, variant)
	_skin.apply_button_text_overrides(button)
	Typography.apply_button_role(button, Typography.ROLE_SECTION)
	button.pressed.connect(action)
	button.focus_entered.connect(func() -> void: interaction_changed.emit())
	_content.add_child(button)
	return button

func _item_button(id: String, rect: Rect2, selected: bool, action: Callable) -> Button:
	var button: Button = _button("", rect, action, UiSkin.VARIANT_SELECTED if selected else UiSkin.VARIANT_STANDARD)
	_picture(button, str(Data.equipment_def(id).get("icon_path", "")), Rect2(47, 7, 83, 83))
	var label: Label = _label(button, _item_name(id), Rect2(8, 87, rect.size.x - 16, 36), 17, IVORY, true)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text = _item_name(id)
	if selected: _label(button, "✓", Rect2(rect.size.x - 31, 5, 26, 25), 22, VIOLET)
	return button

func _card(id: String, position_value: Vector2, selected: bool, action: Callable) -> Button:
	var button: Button = _button("", Rect2(position_value - Vector2(3, 3), Vector2(216, 302)), action, UiSkin.VARIANT_SELECTED if selected else UiSkin.VARIANT_STANDARD)
	# CardWidget owns its hover/selection scale. Scale a parent to preserve the
	# authored card composition without that pose overwriting our shelf size.
	var composition := Control.new()
	composition.position = Vector2(3, 3)
	composition.size = Vector2(250, 352)
	composition.scale = Vector2.ONE * 0.84
	composition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(composition)
	var card: Control = CardScene.instantiate()
	card.size = Vector2(250, 352)
	card.call("configure", id, false, false, true, false, false)
	composition.add_child(card)
	_passive(card)
	button.tooltip_text = _card_name(id) + "\n" + str(Data.card_def(id).get("description", ""))
	button.focus_entered.connect(func() -> void:
		if _detail != null and is_instance_valid(_detail): _detail.text = _card_name(id) + " · " + str(Data.card_def(id).get("description", ""))
	)
	return button

func _passive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(node as Control).focus_mode = Control.FOCUS_NONE
	for child: Node in node.get_children(): _passive(child)

func _item_name(id: String) -> String:
	return str(Data.equipment_def(id).get("name", id))

func _card_name(id: String) -> String:
	return str(Data.card_def(id).get("name", id))

func semantic_snapshot() -> Dictionary:
	return {"recipient": recipient, "donor": donor, "source_index": donor_index, "target_index": target_index, "busy": busy, "used": _used(), "can_commit": _commit != null and is_instance_valid(_commit) and not _commit.disabled, "result": _result(), "reduced_motion": reduced_motion}

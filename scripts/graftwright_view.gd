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
const Choice = preload("res://scripts/graftwright_choice.gd")
const CardScene = preload("res://scenes/card_widget.tscn")
const ThreadEffect = preload("res://scripts/graftwright_thread_effect.gd")
const Glow = preload("res://scripts/graftwright_glow.gdshader")
const ART: String = "res://assets/art/ui/graftwright/"
const SIZE := Vector2(1920, 1080)
const CARD_SCALE: float = 0.8
const CARD_SIZE := Vector2(200, 281.6)
const VIOLET := Color("d8a7ff")
const IVORY := Color("f0e0c6")
const RED := Color("f28a91")
const GREEN := Color("9fe0ba")
const MUTED := Color("b9aaaf")
const LEFT: float = 815.0
const RIGHT: float = 1520.0

var state: Dictionary = {}
var recipient: String = ""
var donor: String = ""
var donor_index: int = -1
var target_index: int = -1
var busy: bool = false
var reduced_motion: bool = false
var _room_identity: String = ""
var _picker_role: String = ""
var _picker_slot: String = "armor"
var _inline_error: String = ""
var _elapsed: float = 0.0
var _canvas: Control
var _content: Control
var _portrait: TextureRect
var _bench: Control
var _commit: Button
var _leave: Button
var _consequence: Label
var _source_cards: Array[Button]
var _target_cards: Array[Button]
var _source_icon: TextureRect
var _recipient_icon: TextureRect
var _picker: Control
var _picker_scroll: ScrollContainer
var _picker_items: Array[String]
var _effect: Control
var _result_icon: TextureRect
var _result_shadow: ColorRect

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(_layout)

func _ensure_built() -> void:
	if _canvas != null: return
	var backdrop := ColorRect.new()
	backdrop.color = Color("09070c")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	_canvas = Control.new()
	_canvas.size = SIZE
	add_child(_canvas)
	_picture(_canvas, ART + "atelier.png", Rect2(Vector2.ZERO, SIZE), false)
	_portrait = _picture(_canvas, "res://assets/art/npcs/graftwright.png", Rect2(-35, 105, 530, 800))
	_portrait.name = "GraftwrightPortrait"
	# Re-render the exact foreground portion of the original scene above the
	# portrait. Its torso actually disappears behind the bench as it breathes.
	_bench = Control.new()
	_bench.name = "BenchForeground"
	_bench.position = Vector2(0, 794)
	_bench.size = Vector2(1920, 286)
	_bench.clip_contents = true
	_bench.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_bench)
	_picture(_bench, ART + "atelier.png", Rect2(0, -794, 1920, 1080), false)
	_label(_canvas, "GRAFTWRIGHT", Rect2(35, 58, 400, 60), 38, IVORY, true)
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
	var identity: String = "%d:%d:%s" % [int(state.get("run_index", 0)), int(state.get("seed", 0)), str(state.get("current_room", Vector2i.ZERO))]
	if identity != _room_identity:
		_room_identity = identity
		recipient = ""
		donor = ""
		donor_index = -1
		target_index = -1
		_picker_role = ""
		_inline_error = ""
	if _used():
		recipient = str(_result().get("recipient", ""))
		_picker_role = ""
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
		_validate_donor()
	_rebuild()

func present() -> void:
	var entering: bool = not visible
	show()
	get_parent().move_child(self, -1)
	if entering and not reduced_motion:
		_canvas.modulate.a = 0.0
		create_tween().tween_property(_canvas, "modulate:a", 1.0, 0.25)
	if entering: call_deferred("focus_first")

func focus_first() -> void:
	if busy or not visible: return
	if _picker != null:
		for id: String in _picker_items:
			var choice: Button = _picker.find_child("Pick_" + id, true, false) as Button
			if choice != null and not choice.disabled:
				choice.grab_focus()
				return
	elif _used() or recipient.is_empty():
		_leave.grab_focus()
	elif not _source_cards.is_empty():
		_source_cards[maxi(donor_index, 0)].grab_focus()

func request_leave() -> void:
	if busy: return
	if not _picker_role.is_empty(): close_picker()
	else: leave_requested.emit()

func _used() -> bool:
	return bool(Graph.room(state, state.get("current_room", Vector2i.ZERO)).get("graft_used", false))

func _result() -> Dictionary:
	return Graph.room(state, state.get("current_room", Vector2i.ZERO)).get("graft_result", state.get("last_graft", {})) as Dictionary

func _validate_donor() -> void:
	var choices: Array[String]
	if not recipient.is_empty(): choices = Rules.donors(state, recipient)
	if not choices.has(donor):
		donor = choices[0] if not choices.is_empty() else ""
		donor_index = -1
		target_index = -1

func select_recipient(id: String) -> void:
	if busy or _used() or Rules.donors(state, id).is_empty(): return
	recipient = id
	donor = ""
	donor_index = -1
	target_index = -1
	_picker_role = ""
	_inline_error = ""
	_validate_donor()
	_rebuild()
	focus_first()
	sound_requested.emit("select")

func select_donor(id: String) -> void:
	if busy or _used() or not Rules.pair_error(state, recipient, id).is_empty(): return
	donor = id
	donor_index = -1
	_picker_role = ""
	_inline_error = ""
	_rebuild()
	focus_first()
	sound_requested.emit("select")

func select_source(index: int) -> void:
	if busy or _used(): return
	donor_index = index
	_inline_error = ""
	var inherited: int = Rules.inherited_index(state, recipient)
	if inherited >= 0: target_index = inherited
	elif Data.equipment_cards(recipient, state).size() == 1: target_index = 0
	_rebuild()
	if not _target_cards.is_empty(): _target_cards[maxi(target_index, 0)].grab_focus()
	sound_requested.emit("select")

func select_target(index: int) -> void:
	if busy or _used(): return
	var inherited: int = Rules.inherited_index(state, recipient)
	if inherited >= 0 and inherited != index: return
	target_index = index
	_inline_error = ""
	_rebuild()
	if index < _target_cards.size(): _target_cards[index].grab_focus()
	sound_requested.emit("select")

func _rebuild() -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_source_cards.clear()
	_target_cards.clear()
	_picker_items.clear()
	_picker = null
	_picker_scroll = null
	_source_icon = null
	_recipient_icon = null
	_result_icon = null
	_result_shadow = null
	_commit = null
	_consequence = null
	if _used(): _build_result()
	elif recipient.is_empty() or donor.is_empty(): _build_empty()
	else: _build_workbench()
	if not _picker_role.is_empty(): _build_picker()
	_wire_focus.call_deferred()

func _build_workbench() -> void:
	_mat(_content, Rect2(470, 125, 690, 800))
	_mat(_content, Rect2(1175, 125, 690, 800))
	_label(_content, "SACRIFICE", Rect2(530, 163, 570, 44), 32, RED, true)
	_label(_content, "KEEP", Rect2(1235, 163, 570, 44), 32, GREEN, true)
	_source_icon = _equipment_well(donor, LEFT, RED, "donor")
	_recipient_icon = _equipment_well(recipient, RIGHT, GREEN, "recipient")
	_label(_content, "WILL BE DESTROYED", Rect2(555, 448, 520, 26), 17, RED, true)
	var equip_text: String = "EQUIPMENT RETAINED"
	if not Rules.equipped_slot(state, recipient).is_empty(): equip_text = "STAYS EQUIPPED"
	elif not Rules.equipped_slot(state, donor).is_empty(): equip_text = "WILL BE EQUIPPED"
	_label(_content, equip_text, Rect2(1260, 448, 520, 26), 17, GREEN, true)
	_label(_content, "CARRY ONE CARD", Rect2(555, 487, 520, 25), 18, MUTED, true)
	_label(_content, "REPLACE ONE CARD" if Rules.inherited_index(state, recipient) < 0 else "REPLACE INHERITED CARD", Rect2(1260, 487, 520, 25), 18, MUTED, true)
	var source: Array = Data.equipment_cards(donor, state)
	var target: Array = Data.equipment_cards(recipient, state)
	var source_start: float = LEFT - (source.size() * CARD_SIZE.x + (source.size() - 1) * 18.0) * 0.5
	var target_start: float = RIGHT - (target.size() * CARD_SIZE.x + (target.size() - 1) * 18.0) * 0.5
	for i: int in range(source.size()):
		var index: int = i
		var selected: bool = i == donor_index
		var button: Button = _card(_content, str(source[i]), Vector2(source_start + i * 218, 523), selected, VIOLET, func() -> void: select_source(index))
		button.name = "SourceCard_%d" % i
		if selected: _ribbon(_content, "CARRY FORWARD", Rect2(button.position.x - 3, 812, 206, 30), VIOLET)
		elif donor_index >= 0:
			button.set("muted", true)
			_ribbon(_content, "LOST", Rect2(button.position.x, 812, 200, 30), RED)
		_source_cards.append(button)
	for i: int in range(target.size()):
		var index: int = i
		var selected: bool = i == target_index
		var button: Button = _card(_content, str(target[i]), Vector2(target_start + i * 218, 523), selected, RED, func() -> void: select_target(index))
		button.name = "TargetCard_%d" % i
		var inherited: int = Rules.inherited_index(state, recipient)
		button.disabled = inherited >= 0 and i != inherited
		if selected: _ribbon(_content, "REPLACED", Rect2(button.position.x - 3, 812, 206, 30), RED)
		_target_cards.append(button)
	if donor_index >= 0 and target_index >= 0:
		_compare_strip(_card_name(str(target[target_index])), _card_name(str(source[donor_index])))
	var reason: String = Rules.error(state, recipient, donor, donor_index, target_index)
	_commit = _action(_content, "Graft", Rect2(1340, 930, 365, 120), _request_graft)
	_commit.name = "GraftCommit"
	_commit.disabled = not reason.is_empty()
	_leave = _quiet(_content, "‹  Leave", Rect2(70, 981, 195, 55), request_leave)
	_leave.name = "GraftLeave"
	var status: String = _inline_error
	if status.is_empty() and donor_index >= 0 and target_index >= 0 and not reason.is_empty(): status = reason
	if status.is_empty() and not Rules.equipped_slot(state, donor).is_empty() and not Rules.equipped_slot(state, recipient).is_empty(): status = "Trinket slot becomes empty."
	_consequence = _label(_content, status, Rect2(520, 952, 695, 62), 20, RED, true)
	if not status.is_empty():
		var backing: ColorRect = _solid(_content, Rect2(505, 944, 725, 78), Color("17111beb"))
		_content.move_child(backing, _consequence.get_index())

func _equipment_well(id: String, center: float, color: Color, role: String) -> TextureRect:
	var button := _choice(_content, Rect2(center - 108, 223, 216, 185), func() -> void: open_picker(role), "equipment", color)
	button.name = "ChooseSacrifice" if role == "donor" else "ChooseRecipient"
	button.set_meta("graft_action_label", "Change")
	button.face_size = Vector2(216, 185)
	_glow(button.art(), Rect2(0, 18, 216, 165), Color(color, 0.33))
	_picture(button.art(), ART + "item_cradle.png", Rect2(16, 0, 184, 184))
	var icon: TextureRect = _picture(button.art(), str(Data.equipment_def(id).get("icon_path", "")), Rect2(52, 31, 112, 124))
	_ribbon(button.art(), "CHANGE", Rect2(57, 162, 102, 26), MUTED)
	_label(_content, _item_name(id), Rect2(center - 307, 409, 614, 36), 28, IVORY, true)
	return icon

func _compare_strip(old_name: String, new_name: String) -> void:
	var strip := RichTextLabel.new()
	strip.position = Vector2(1215, 859)
	strip.size = Vector2(610, 48)
	strip.bbcode_enabled = true
	strip.fit_content = false
	strip.scroll_active = false
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_font_override("normal_font", preload("res://fonts/LabyrinthCrumble-UI.tres"))
	strip.add_theme_font_size_override("normal_font_size", 21)
	strip.text = "[center][color=#f28a91][s]%s[/s][/color]   →   [color=#9fe0ba]%s[/color][/center]" % [old_name, new_name]
	_content.add_child(strip)

func _build_empty() -> void:
	_mat(_content, Rect2(590, 230, 1100, 610))
	_label(_content, "NO MATCHING EQUIPMENT", Rect2(675, 350, 925, 65), 34, IVORY, true)
	_label(_content, "Bring two pieces of the same type.", Rect2(675, 454, 925, 50), 25, MUTED, true)
	_leave = _action(_content, "Leave", Rect2(960, 645, 365, 120), request_leave)
	_leave.name = "GraftLeave"

func open_picker(role: String) -> void:
	if busy or _used(): return
	_picker_role = role
	_picker_slot = Data.equipment_slot(recipient)
	_rebuild()
	call_deferred("focus_first")
	sound_requested.emit("select")

func close_picker() -> void:
	var role: String = _picker_role
	_picker_role = ""
	_rebuild()
	var button: Button = _content.find_child("ChooseSacrifice" if role == "donor" else "ChooseRecipient", true, false) as Button
	if button != null: button.grab_focus()

func _choose_category(slot: String) -> void:
	_picker_slot = slot
	_rebuild()
	var button: Button = _picker.find_child("Category_" + slot, true, false) as Button
	if button != null: button.grab_focus()

func _build_picker() -> void:
	_picker = Control.new()
	_picker.name = "EquipmentPicker"
	# CardWidgets intentionally lift their time badges above their face. Keep the
	# entire modal above that local card composition, including its dimmer.
	_picker.z_index = 40
	_picker.size = SIZE
	_picker.mouse_filter = Control.MOUSE_FILTER_STOP
	_content.add_child(_picker)
	_solid(_picker, Rect2(Vector2.ZERO, SIZE), Color(0.025, 0.018, 0.035, 0.76))
	_mat(_picker, Rect2(480, 104, 1385, 876))
	_label(_picker, "EQUIPMENT TO SACRIFICE" if _picker_role == "donor" else "EQUIPMENT TO KEEP", Rect2(545, 151, 1070, 60), 32, RED if _picker_role == "donor" else GREEN)
	var close: Button = _quiet(_picker, "Back", Rect2(1690, 164, 100, 45), close_picker)
	close.name = "PickerBack"
	var owned: Array[String] = Rules.owned(state)
	for i: int in range(Data.EQUIPMENT_SLOTS.size()):
		var slot: String = Data.EQUIPMENT_SLOTS[i]
		var count: int = 0
		for id: String in owned:
			if Data.equipment_slot(id) == slot: count += 1
		var category := _choice(_picker, Rect2(530, 253 + i * 90, 205, 72), func() -> void: _choose_category(slot), "tab", VIOLET)
		category.name = "Category_" + slot
		category.chosen = slot == _picker_slot
		category.disabled = count == 0 or (_picker_role == "donor" and slot != Data.equipment_slot(recipient))
		_label(category.art(), slot.capitalize(), Rect2(16, 10, 148, 50), 23, IVORY)
		_label(category.art(), str(count), Rect2(160, 10, 35, 50), 20, MUTED, true)
	_picker_scroll = ScrollContainer.new()
	_picker_scroll.position = Vector2(785, 250)
	_picker_scroll.size = Vector2(1015, 645)
	_picker_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_picker_scroll.follow_focus = true
	_picker.add_child(_picker_scroll)
	var inset := MarginContainer.new()
	for edge: String in ["left", "top", "right", "bottom"]:
		inset.add_theme_constant_override("margin_" + edge, 12)
	_picker_scroll.add_child(inset)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	inset.add_child(grid)
	for id: String in owned:
		if Data.equipment_slot(id) != _picker_slot: continue
		_picker_items.append(id)
		var item_id: String = id
		var button := _choice(grid, Rect2(0, 0, 180, 205), func() -> void:
			if _picker_role == "donor": select_donor(item_id)
			else: select_recipient(item_id)
		, "equipment", RED if _picker_role == "donor" else GREEN)
		button.name = "Pick_" + id
		button.custom_minimum_size = Vector2(180, 205)
		button.face_size = Vector2(180, 153)
		button.chosen = id == (donor if _picker_role == "donor" else recipient)
		button.disabled = id == recipient if _picker_role == "donor" else Rules.donors(state, id).is_empty()
		_picture(button.art(), ART + "item_cradle.png", Rect2(17, 0, 146, 146))
		_picture(button.art(), str(Data.equipment_def(id).get("icon_path", "")), Rect2(43, 20, 94, 103))
		_label(button.art(), _item_name(id), Rect2(1, 149, 178, 48), 18, IVORY, true)
		if id == recipient and _picker_role == "donor": _ribbon(button.art(), "KEPT", Rect2(46, 117, 88, 24), GREEN)
		elif not Rules.equipped_slot(state, id).is_empty(): _ribbon(button.art(), "EQUIPPED", Rect2(32, 117, 116, 24), MUTED)
		elif button.chosen: _ribbon(button.art(), "SELECTED", Rect2(32, 117, 116, 24), VIOLET)
	grid.sort_children.connect(_wire_focus)

func _build_result() -> void:
	var result: Dictionary = _result()
	_mat(_content, Rect2(650, 120, 1060, 820))
	_label(_content, "GRAFT COMPLETE", Rect2(735, 160, 890, 60), 34, GREEN, true)
	_glow(_content, Rect2(990, 214, 380, 285), Color(VIOLET, 0.4))
	_picture(_content, ART + "item_cradle.png", Rect2(1067, 240, 226, 226))
	_result_shadow = _glow(_content, Rect2(1118, 403, 124, 31), Color(0, 0, 0, 0.95))
	_result_shadow.pivot_offset = Vector2(62, 15.5)
	_result_icon = _picture(_content, str(Data.equipment_def(recipient).get("icon_path", "")), Rect2(1096, 250, 168, 182))
	_label(_content, _item_name(recipient), Rect2(780, 466, 800, 45), 30, IVORY, true)
	var cards: Array = Data.equipment_cards(recipient, state)
	var start: float = 1180.0 - (cards.size() * CARD_SIZE.x + (cards.size() - 1) * 32.0) * 0.5
	for i: int in range(cards.size()):
		var selected: bool = i == int(result.get("index", -1))
		var card: Button = _card(_content, str(cards[i]), Vector2(start + i * 232, 540), selected, GREEN, func() -> void: pass)
		card.name = "ResultCard_%d" % i
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if selected: _ribbon(_content, "INHERITED", Rect2(card.position.x, 831, 200, 30), GREEN)
	_label(_content, _item_name(str(result.get("donor", ""))) + " consumed", Rect2(780, 881, 800, 34), 20, MUTED, true)
	_leave = _action(_content, "Continue", Rect2(997, 937, 365, 120), request_leave)
	_leave.name = "GraftContinue"

func _request_graft() -> void:
	if busy or not Rules.error(state, recipient, donor, donor_index, target_index).is_empty(): return
	busy = true
	_commit.disabled = true
	interaction_changed.emit()
	graft_requested.emit(recipient, donor, donor_index, target_index)

func reject(message: String) -> void:
	busy = false
	_inline_error = message
	_rebuild()
	focus_first()

func present_result(next_state: Dictionary) -> void:
	busy = true
	var effect := ThreadEffect.new()
	effect.name = "GraftRitual"
	effect.size = SIZE
	effect.origin = _source_cards[donor_index].position + CARD_SIZE * 0.5
	effect.destination = _target_cards[target_index].position + CARD_SIZE * 0.5
	effect.reduced_motion = reduced_motion
	_canvas.add_child(effect)
	_effect = effect
	for child: Node in _content.find_children("*", "Button", true, false): (child as Button).disabled = true
	sound_requested.emit("unpick")
	var tween: Tween = create_tween()
	if reduced_motion: tween.tween_interval(0.18)
	else:
		var ghost: Button = _card(_canvas, str(Data.equipment_cards(donor, state)[donor_index]), _source_cards[donor_index].position, true, VIOLET, func() -> void: pass)
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.focus_mode = Control.FOCUS_NONE
		ghost.modulate.a = 0.0
		tween.set_parallel(true)
		if _source_icon != null: tween.tween_property(_source_icon, "modulate:a", 0.0, 0.85)
		for card: Button in _source_cards: tween.tween_property(card, "modulate:a", 0.12, 0.95)
		tween.tween_property(_target_cards[target_index], "modulate:a", 0.06, 0.5).set_delay(0.5)
		tween.tween_property(ghost, "modulate:a", 0.94, 0.25).set_delay(0.22)
		tween.tween_method(func(progress: float) -> void:
			ghost.position = effect.point(progress) - CARD_SIZE * 0.5
			ghost.pivot_offset = CARD_SIZE * 0.5
			ghost.rotation = sin(progress * PI) * -0.09
		, 0.0, 1.0, 1.45).set_delay(0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(func() -> void: sound_requested.emit("bind")).set_delay(1.35)
		tween.tween_property(ghost, "modulate:a", 0.0, 0.24).set_delay(1.94)
		tween.chain().tween_callback(ghost.queue_free)
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
		_content.modulate.a = 0.25
		create_tween().tween_property(_content, "modulate:a", 1.0, 0.32)

func _process(delta: float) -> void:
	if not visible: return
	_elapsed += delta
	if _portrait != null: _portrait.position.y = 105.0 + (0.0 if reduced_motion else sin(_elapsed * 0.9) * 3.5)
	if _result_icon != null and is_instance_valid(_result_icon):
		var bob: float = 0.0 if reduced_motion else sin(_elapsed * 1.6) * 4.0
		_result_icon.position.y = 250 + bob
		_result_shadow.scale.x = 1.0 + bob * 0.012

func _wire_focus() -> void:
	var scope: Control = _picker if _picker != null else _content
	var buttons: Array[Button]
	for node: Node in scope.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if not button.disabled and button.focus_mode != Control.FOCUS_NONE: buttons.append(button)
	for i: int in range(buttons.size()):
		var button: Button = buttons[i]
		button.focus_next = button.get_path_to(buttons[(i + 1) % buttons.size()])
		button.focus_previous = button.get_path_to(buttons[posmod(i - 1, buttons.size())])
		for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			var direction: Vector2 = [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN][side]
			var neighbor: Button = button
			var best: float = INF
			for candidate: Button in buttons:
				var delta: Vector2 = candidate.get_global_rect().get_center() - button.get_global_rect().get_center()
				var along: float = delta.dot(direction)
				if along <= 1.0: continue
				var score: float = along + absf(delta.cross(direction)) * 3.0
				if score < best:
					best = score
					neighbor = candidate
			button.set_focus_neighbor(side, button.get_path_to(neighbor))

func _choice(parent: Node, rect: Rect2, action: Callable, kind: String = "quiet", color: Color = VIOLET) -> Choice:
	var button := Choice.new()
	button.position = rect.position
	button.size = rect.size
	button.kind = kind
	button.accent = color
	button.reduced_motion = reduced_motion
	button.pressed.connect(action)
	button.focus_entered.connect(func() -> void: interaction_changed.emit())
	parent.add_child(button)
	button.art().name = "Artwork"
	return button

func _quiet(parent: Node, title: String, rect: Rect2, action: Callable) -> Button:
	var button: Choice = _choice(parent, rect, action)
	_label(button.art(), title, Rect2(Vector2.ZERO, rect.size), 23, IVORY, true)
	button.set_meta("graft_action_label", title)
	return button

func _action(parent: Node, title: String, rect: Rect2, action: Callable) -> Button:
	var button: Choice = _choice(parent, rect, action, "action")
	_picture(button.art(), ART + "ritual_clasp.png", Rect2(Vector2.ZERO, rect.size))
	_label(button.art(), title, Rect2(45, 19, rect.size.x - 90, rect.size.y - 38), 29, IVORY, true)
	button.set_meta("graft_action_label", title)
	return button

func _card(parent: Node, id: String, position_value: Vector2, selected: bool, color: Color, action: Callable) -> Button:
	var button: Choice = _choice(parent, Rect2(position_value, CARD_SIZE), action, "card", color)
	button.chosen = selected
	button.face_size = CARD_SIZE
	var composition := Control.new()
	composition.size = Vector2(250, 352)
	composition.scale = Vector2.ONE * CARD_SCALE
	composition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.art().add_child(composition)
	var card: Control = CardScene.instantiate()
	card.size = Vector2(250, 352)
	card.call("configure", id, false, false, true, false, false)
	composition.add_child(card)
	_passive(card)
	button.set_meta("graft_action_label", "Select")
	return button

func _mat(parent: Node, rect: Rect2) -> void:
	var mat := NinePatchRect.new()
	mat.texture = Assets.load_texture(ART + "workmat.png")
	mat.position = rect.position
	mat.size = rect.size * 2.0
	mat.scale = Vector2.ONE * 0.5
	mat.patch_margin_left = 120
	mat.patch_margin_right = 120
	mat.patch_margin_top = 160
	mat.patch_margin_bottom = 160
	mat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(mat)

func _ribbon(parent: Node, title: String, rect: Rect2, color: Color) -> void:
	_solid(parent, rect, Color(0.06, 0.035, 0.065, 0.96))
	_solid(parent, Rect2(rect.position, Vector2(rect.size.x, 2)), color)
	_label(parent, title, rect, 16, color, true)

func _solid(parent: Node, rect: Rect2, color: Color) -> ColorRect:
	var surface := ColorRect.new()
	surface.position = rect.position
	surface.size = rect.size
	surface.color = color
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(surface)
	return surface

func _glow(parent: Node, rect: Rect2, color: Color) -> ColorRect:
	var surface: ColorRect = _solid(parent, rect, Color.WHITE)
	var shader_material := ShaderMaterial.new()
	shader_material.shader = Glow
	shader_material.set_shader_parameter("tint", color)
	surface.material = shader_material
	return surface

func _picture(parent: Node, path: String, rect: Rect2, fit: bool = true) -> TextureRect:
	var picture := TextureRect.new()
	picture.position = rect.position
	picture.size = rect.size
	picture.texture = Assets.load_texture(path)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if fit else TextureRect.STRETCH_SCALE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(picture)
	return picture

func _label(parent: Node, title: String, rect: Rect2, font_size: int, color: Color, centered: bool = false) -> Label:
	var label := Label.new()
	label.text = title
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if centered: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Typography.apply_label_role(label, Typography.ROLE_BODY_LARGE)
	Typography.set_label_size(label, font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("100b15"))
	label.add_theme_constant_override("outline_size", 3)
	parent.add_child(label)
	return label

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
	return {"recipient": recipient, "donor": donor, "source_index": donor_index, "target_index": target_index, "busy": busy, "used": _used(), "can_commit": _commit != null and is_instance_valid(_commit) and not _commit.disabled, "result": _result(), "reduced_motion": reduced_motion, "picker_role": _picker_role, "picker_slot": _picker_slot, "picker_items": _picker_items.duplicate(), "bench_occludes_portrait": _bench != null and _bench.get_index() > _portrait.get_index()}

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
const Tooltip = preload("res://scripts/ui_tooltip_panel.gd")
const Choice = preload("res://scripts/graftwright_choice.gd")
const CardScene = preload("res://scenes/card_widget.tscn")
const ThreadEffect = preload("res://scripts/graftwright_thread_effect.gd")
const Glow = preload("res://scripts/graftwright_glow.gdshader")
const FrameRim = preload("res://scripts/graftwright_frame_rim.gdshader")
const PortraitRig = preload("res://scripts/graftwright_cutout/rig.gd")
const MatMaterial = preload("res://scripts/graftwright_workmat.gdshader")
const TypeMaterial = preload("res://scripts/graftwright_type.gdshader")
const UiSkinScript = preload("res://scripts/ui_skin.gd")
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
var _intro_open: bool = false
var _title: Label
var _intro_browse: Button
var _props: Node2D
var _picker_role: String = ""
var _picker_slot: String = "armor"
var _inline_error: String = ""
var _elapsed: float = 0.0
var _canvas: Control
var _content: Control
var _portrait: Node2D
var _keyboard_navigation: bool = false
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
var _result_mount: Control
var _result_shadow: ColorRect
var _inspection: Control
var _inspection_return: Button

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
	_portrait = PortraitRig.new()
	_portrait.name = "GraftwrightPortrait"
	# Same full-resolution painting and registration as the former portrait.
	# Logical cutout coordinates never reduce the source texture resolution.
	_portrait.position = Vector2(-123.333, 151.667)
	_portrait.scale = Vector2.ONE * (706.6667 / 255.0)
	_canvas.add_child(_portrait)
	_portrait.call("load_rig")
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
	_build_foreground_props()
	_title = _label(_canvas, "Graftwright", Rect2(28, 54, 420, 76), 48, IVORY, true)
	_title.name = "AtelierTitle"
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
		_intro_open = not _used()
		recipient = ""
		donor = ""
		donor_index = -1
		target_index = -1
		_picker_role = ""
		_inline_error = ""
	if _used():
		_intro_open = false
		recipient = str(_result().get("recipient", ""))
		_picker_role = ""
	elif not Rules.owned(state).has(recipient):
		recipient = ""
		target_index = -1
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
	if _intro_open:
		if _intro_browse != null: _intro_browse.grab_focus()
		else: _leave.grab_focus()
	elif _inspection != null:
		(_inspection.find_child("InspectionBack", true, false) as Button).grab_focus()
	elif _picker != null:
		for id: String in _picker_items:
			var choice: Button = _picker.find_child("Pick_" + id, true, false) as Button
			if choice != null and not choice.disabled:
				choice.grab_focus()
				return
		var category: Button = _picker.find_child("Category_" + _picker_slot, true, false) as Button
		if category != null: category.grab_focus()
	elif _used() or not _has_pair():
		_leave.grab_focus()
	elif not _source_cards.is_empty():
		_source_cards[maxi(donor_index, 0)].grab_focus()
	else:
		var choose: Button = _content.find_child("ChooseSacrifice", true, false) as Button
		if choose != null: choose.grab_focus()

func request_leave() -> void:
	if busy: return
	if _inspection != null: close_inspection()
	elif not _picker_role.is_empty(): close_picker()
	else: leave_requested.emit()

func _used() -> bool:
	return bool(Graph.room(state, state.get("current_room", Vector2i.ZERO)).get("graft_used", false))

func _result() -> Dictionary:
	return Graph.room(state, state.get("current_room", Vector2i.ZERO)).get("graft_result", state.get("last_graft", {})) as Dictionary

func _validate_donor() -> void:
	if not Rules.owned(state).has(donor) or (not recipient.is_empty() and not Rules.pair_error(state, recipient, donor).is_empty()):
		donor = ""
		donor_index = -1

func select_recipient(id: String) -> void:
	if busy or _used() or _intro_open or Rules.donors(state, id).is_empty(): return
	recipient = id
	target_index = -1
	_picker_role = ""
	_inline_error = ""
	_validate_donor()
	_rebuild()
	focus_first()
	sound_requested.emit("select")

func select_donor(id: String) -> void:
	if busy or _used() or _intro_open or Rules.donors(state, id).is_empty(): return
	if not recipient.is_empty() and not Rules.pair_error(state, recipient, id).is_empty(): return
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
	if _inspection != null:
		_canvas.remove_child(_inspection)
		_inspection.queue_free()
		_inspection = null
		_inspection_return = null
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
	_result_mount = null
	_result_shadow = null
	_commit = null
	_consequence = null
	_intro_browse = null
	_title.visible = not _intro_open
	if _intro_open: _build_intro()
	elif _used(): _build_result()
	elif not _has_pair(): _build_empty()
	else: _build_workbench()
	if not _picker_role.is_empty(): _build_picker()
	_wire_focus.call_deferred()

func _build_workbench() -> void:
	_mat(_content, Rect2(470, 120, 690, 390 if donor.is_empty() else 765), true)
	_mat(_content, Rect2(1175, 120, 690, 390 if recipient.is_empty() else 765), true)
	_label(_content, "Sacrifice", Rect2(530, 165, 570, 52), 38, RED.lerp(IVORY, 0.45), true)
	_label(_content, "Improve", Rect2(1235, 165, 570, 52), 38, GREEN.lerp(IVORY, 0.45), true)
	_source_icon = _equipment_well(donor, LEFT, RED, "donor")
	_recipient_icon = _equipment_well(recipient, RIGHT, GREEN, "recipient")
	if not donor.is_empty(): _label(_content, "WILL BE DESTROYED", Rect2(LEFT - 47, 342, 306, 45), 17, RED, true)
	var equip_text: String = "EQUIPMENT RETAINED"
	if not Rules.equipped_slot(state, recipient).is_empty(): equip_text = "STAYS EQUIPPED"
	elif not Rules.equipped_slot(state, donor).is_empty(): equip_text = "WILL BE EQUIPPED"
	if not recipient.is_empty(): _label(_content, equip_text, Rect2(RIGHT - 47, 342, 306, 45), 17, GREEN, true)
	if not donor.is_empty(): _label(_content, "CARRY ONE CARD", Rect2(555, 437, 520, 30), 18, MUTED, true)
	if not recipient.is_empty(): _label(_content, "REPLACE ONE CARD" if Rules.inherited_index(state, recipient) < 0 else "REPLACE INHERITED CARD", Rect2(1260, 437, 520, 30), 18, MUTED, true)
	var source: Array = Data.equipment_cards(donor, state)
	var target: Array = Data.equipment_cards(recipient, state)
	var source_gap: float = 6.0 if source.size() >= 3 else 22.0
	var target_gap: float = 6.0 if target.size() >= 3 else 22.0
	var source_start: float = LEFT - (source.size() * CARD_SIZE.x + (source.size() - 1) * source_gap) * 0.5
	var target_start: float = RIGHT - (target.size() * CARD_SIZE.x + (target.size() - 1) * target_gap) * 0.5
	for i: int in range(source.size()):
		var index: int = i
		var selected: bool = i == donor_index
		var button: Button = _card(_content, str(source[i]), Vector2(source_start + i * (CARD_SIZE.x + source_gap), 474), selected, VIOLET, func() -> void: select_source(index))
		button.name = "SourceCard_%d" % i
		if selected: _ribbon(_content, "CARRY FORWARD", Rect2(button.position.x - 3, 766, 206, 28), VIOLET)
		elif donor_index >= 0:
			button.set("muted", true)
			_ribbon(_content, "LOST", Rect2(button.position.x, 766, 200, 28), RED)
		_source_cards.append(button)
	for i: int in range(target.size()):
		var index: int = i
		var selected: bool = i == target_index
		var button: Button = _card(_content, str(target[i]), Vector2(target_start + i * (CARD_SIZE.x + target_gap), 474), selected, RED, func() -> void: select_target(index))
		button.name = "TargetCard_%d" % i
		var inherited: int = Rules.inherited_index(state, recipient)
		button.disabled = inherited >= 0 and i != inherited
		if selected: _ribbon(_content, "REPLACED", Rect2(button.position.x - 3, 766, 206, 28), RED)
		_target_cards.append(button)
	if donor_index >= 0 and target_index >= 0:
		_compare_strip(_card_name(str(target[target_index])), _card_name(str(source[donor_index])))
	var reason: String = Rules.error(state, recipient, donor, donor_index, target_index)
	_commit = _action(_content, "Graft", Rect2(1340, 930, 365, 120), _request_graft)
	_commit.name = "GraftCommit"
	_commit.disabled = not reason.is_empty()
	_leave = _action(_content, "Skip", Rect2(65, 942, 260, 96), request_leave)
	_leave.name = "GraftLeave"
	var status: String = _inline_error
	if status.is_empty() and donor_index >= 0 and target_index >= 0 and not reason.is_empty(): status = reason
	if status.is_empty() and not Rules.equipped_slot(state, donor).is_empty() and not Rules.equipped_slot(state, recipient).is_empty(): status = "Trinket slot becomes empty."
	_consequence = _label(_content, status, Rect2(520, 952, 695, 62), 20, RED, true)
	if not status.is_empty():
		var backing: ColorRect = _solid(_content, Rect2(505, 944, 725, 78), Color("17111beb"))
		_content.move_child(backing, _consequence.get_index())

func _equipment_well(id: String, center: float, color: Color, role: String) -> TextureRect:
	var button := _choice(_content, Rect2(center - (84 if id.is_empty() else 245), 240, 168, 192), func() -> void: open_picker(role), "equipment", color)
	button.name = "ChooseSacrifice" if role == "donor" else "ChooseRecipient"
	button.set_meta("graft_action_label", "Choose" if id.is_empty() else "Change")
	button.face_size = Vector2(168, 168)
	_glow(button.art(), Rect2(4, 8, 160, 160), Color(color, 0.25))
	if not id.is_empty():
		var framed: TextureRect = _framed_equipment(button.art(), id, Rect2(0, 0, 168, 168))
		_ribbon(button.art(), "CHANGE", Rect2(32, 169, 104, 25), MUTED)
		var name_label: Label = _label(_content, _item_name(id), Rect2(center - 47, 265, 306, 74), 28, IVORY, true)
		name_label.name = "SacrificeName" if role == "donor" else "ImproveName"
		return framed
	_picture(button.art(), ART + "item_cradle.png", Rect2(0, 0, 168, 168))
	if id.is_empty():
		_label(button.art(), "Choose", Rect2(24, 61, 120, 44), 24, IVORY, true)
		return null
	return null

func _compare_strip(old_name: String, new_name: String) -> void:
	# The original art's lower leather rail is centered 61 px above the bottom.
	# Use one HBox so the two names and arrow share an actual vertical center.
	var row := HBoxContainer.new()
	row.name = "ReplacementStrip"
	row.position = Vector2(1235, 809)
	row.size = Vector2(570, 30)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(row)
	_label(row, old_name, Rect2(), 18, RED.lerp(IVORY, 0.25), true)
	_label(row, "→", Rect2(), 18, IVORY, true)
	_label(row, new_name, Rect2(), 18, GREEN.lerp(IVORY, 0.25), true)

func _build_empty() -> void:
	_mat(_content, Rect2(650, 340, 1060, 430))
	_label(_content, "No matching equipment", Rect2(730, 375, 900, 36), 24, IVORY, true)
	_label(_content, "Bring two pieces of the same type.", Rect2(730, 475, 900, 60), 26, MUTED, true)
	_leave = _action(_content, "Skip", Rect2(997, 585, 365, 120), request_leave)
	_leave.name = "GraftLeave"

func open_picker(role: String) -> void:
	if busy or _used() or _intro_open: return
	_picker_role = role
	var context_id: String = recipient if not recipient.is_empty() else donor
	_picker_slot = Data.equipment_slot(context_id) if not context_id.is_empty() else "armor"
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
	# Reveal the atelier through the browser, never ghosted workbench controls.
	for child: Node in _content.get_children():
		if child is CanvasItem: (child as CanvasItem).hide()
	_picker = Control.new()
	_picker.name = "EquipmentPicker"
	# CardWidgets intentionally lift their time badges above their face. Keep the
	# entire modal above that local card composition, including its dimmer.
	_picker.z_index = 40
	_picker.size = SIZE
	_picker.mouse_filter = Control.MOUSE_FILTER_STOP
	_content.add_child(_picker)
	_solid(_picker, Rect2(Vector2.ZERO, SIZE), Color(0.025, 0.018, 0.035, 0.76))
	_mat(_picker, Rect2(480, 130, 1385, 800), true)
	_label(_picker, "Equipment to sacrifice" if _picker_role == "donor" else "Equipment to improve", Rect2(545, 175, 1070, 52), 30, IVORY)
	var close: Button = _quiet(_picker, "Back", Rect2(1670, 175, 125, 52), close_picker)
	close.name = "PickerBack"
	var owned: Array[String] = Rules.owned(state)
	for i: int in range(Data.EQUIPMENT_SLOTS.size()):
		var slot: String = Data.EQUIPMENT_SLOTS[i]
		var count: int = 0
		for id: String in owned:
			if Data.equipment_slot(id) == slot: count += 1
		var category := _choice(_picker, Rect2(535, 280 + i * 84, 205, 66), func() -> void: _choose_category(slot), "tab", VIOLET)
		category.name = "Category_" + slot
		category.chosen = slot == _picker_slot
		# Browsing never silently locks a category; restrictions belong to items.
		category.disabled = false
		_label(category.art(), slot.capitalize(), Rect2(16, 8, 148, 50), 23, IVORY)
		_label(category.art(), str(count), Rect2(160, 8, 35, 50), 20, MUTED, true)
	_picker_scroll = ScrollContainer.new()
	_picker_scroll.position = Vector2(785, 269)
	_picker_scroll.size = Vector2(1015, 565)
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
		var button := _choice(grid, Rect2(0, 0, 180, 233), func() -> void:
			if _picker_role == "donor": select_donor(item_id)
			else: select_recipient(item_id)
		, "equipment", RED if _picker_role == "donor" else GREEN)
		button.name = "Pick_" + id
		button.custom_minimum_size = Vector2(180, 233)
		button.face_size = Vector2(180, 153)
		button.chosen = id == (donor if _picker_role == "donor" else recipient)
		button.disabled = not Rules.pair_error(state, recipient, id).is_empty() if _picker_role == "donor" and not recipient.is_empty() else Rules.donors(state, id).is_empty() or (_picker_role == "recipient" and id == donor)
		if button.chosen: _glow(button.art(), Rect2(9, -6, 162, 162), Color(button.accent, 0.50))
		_framed_equipment(button.art(), id, Rect2(17, 0, 146, 146))
		_label(button.art(), _item_name(id), Rect2(1, 149, 178, 48), 18, IVORY, true)
		if id == recipient and _picker_role == "donor": _ribbon(button.art(), "IMPROVING", Rect2(25, 117, 130, 24), GREEN)
		elif id == donor and _picker_role == "recipient": _ribbon(button.art(), "SACRIFICING", Rect2(25, 117, 130, 24), RED)
		elif button.chosen: _ribbon(button.art(), "SELECTED", Rect2(32, 117, 116, 24), button.accent)
		elif not Rules.equipped_slot(state, id).is_empty(): _ribbon(button.art(), "EQUIPPED", Rect2(32, 117, 116, 24), MUTED)
		if button.chosen and not Rules.equipped_slot(state, id).is_empty():
			_label(button.art(), "Equipped", Rect2(0, 197, 180, 34), 14, MUTED, true)
		if Rules.donors(state, id).is_empty():
			_label(button.art(), "No matching pair", Rect2(0, 197, 180, 34), 14, MUTED, true)
	_build_picker_context()
	grid.sort_children.connect(_wire_focus)

func _build_result() -> void:
	var result: Dictionary = _result()
	_mat(_content, Rect2(730, 120, 900, 765), true)
	_label(_content, "Graft complete", Rect2(810, 165, 740, 52), 42, GREEN.lerp(IVORY, 0.45), true)
	_glow(_content, Rect2(1060, 239, 240, 210), Color(VIOLET, 0.35))
	_result_shadow = _glow(_content, Rect2(1087, 405, 186, 30), Color(0, 0, 0, 0.95))
	_result_shadow.pivot_offset = Vector2(93, 15)
	_result_mount = Control.new()
	_result_mount.name = "FloatingEquipment"
	_result_mount.position = Vector2(1090, 238)
	_result_mount.size = Vector2(180, 180)
	_result_mount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_result_mount)
	_result_icon = _framed_equipment(_result_mount, recipient, Rect2(0, 0, 180, 180))
	_label(_content, _item_name(recipient), Rect2(790, 424, 780, 44), 30, IVORY, true)
	var cards: Array = Data.equipment_cards(recipient, state)
	var start: float = 1180.0 - (cards.size() * CARD_SIZE.x + (cards.size() - 1) * 24.0) * 0.5
	for i: int in range(cards.size()):
		var selected: bool = i == int(result.get("index", -1))
		var card: Button = _card(_content, str(cards[i]), Vector2(start + i * 224, 480), selected, GREEN, func() -> void: pass)
		card.name = "ResultCard_%d" % i
		card.set_meta("graft_action_label", "Inspect")
		card.pressed.connect(func() -> void: _open_inspection(card))
		if selected: _ribbon(_content, "INHERITED", Rect2(card.position.x, 772, 200, 28), GREEN)
	var consumed: Label = _label(_content, _item_name(str(result.get("donor", ""))) + " consumed", Rect2(810, 809, 740, 30), 18, MUTED, true)
	consumed.name = "ConsumedEquipment"
	_leave = _action(_content, "Continue", Rect2(997, 922, 365, 120), request_leave)
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
		ghost.z_index = 50 # Above the target CardWidget's raised cost badge.
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
	if _portrait != null: _portrait.call("apply_pose", "rest" if reduced_motion else "idle", fposmod(_elapsed / 2.4, 1.0))
	if _result_mount != null and is_instance_valid(_result_mount):
		var bob: float = 0.0 if reduced_motion else sin(_elapsed * 1.6) * 4.0
		_result_mount.position.y = 238 + bob
		_result_shadow.scale.x = 1.0 + bob * 0.012

func _wire_focus() -> void:
	var scope: Control = _inspection if _inspection != null else _picker if _picker != null else _content
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
	button.keyboard_navigation = _keyboard_navigation
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

func _action(parent: Node, title: String, rect: Rect2, action: Callable, font_size: int = 29) -> Button:
	var button: Choice = _choice(parent, rect, action, "action")
	_picture(button.art(), ART + "ritual_clasp.png", Rect2(Vector2.ZERO, rect.size))
	_label(button.art(), title, Rect2(45, 19, rect.size.x - 90, rect.size.y - 38), font_size, IVORY, true)
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
	button.card_face = card
	button.set_meta("graft_card_id", id)
	button.inspect_requested.connect(func() -> void: _open_inspection(button))
	button.set_meta("graft_action_label", "Select")
	return button

func inspect_focused() -> bool:
	if busy or _picker != null or _intro_open: return false
	if _inspection != null:
		close_inspection()
		return true
	var focused: Button = get_viewport().gui_get_focus_owner() as Button
	if focused == null or not focused.has_meta("graft_card_id"): return false
	_open_inspection(focused)
	return true

func _open_inspection(source: Button) -> void:
	if busy or _picker != null or _inspection != null or _intro_open: return
	var id: String = str(source.get_meta("graft_card_id", ""))
	if id.is_empty(): return
	_inspection_return = source
	_inspection = Control.new()
	_inspection.name = "CardInspection"
	_inspection.size = SIZE
	_inspection.z_index = 60
	_inspection.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(_inspection)
	_solid(_inspection, Rect2(Vector2.ZERO, SIZE), Color(0.02, 0.015, 0.03, 0.32))
	_inspection.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed: close_inspection()
	)
	var panel: PanelContainer = Tooltip.make_lines(_card_name(id), PackedStringArray([str(Data.card_def(id).get("description", ""))]))
	panel.name = "ExactRules"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.hide()
	_inspection.add_child(panel)
	var back: Button = _quiet(panel.get_child(0), "Back", Rect2(0, 0, 340, 38), close_inspection)
	back.name = "InspectionBack"
	back.custom_minimum_size = Vector2(340, 38)
	# Wait for wrapped rules to establish their actual height, then anchor the
	# popover immediately above the inspected card without a first-frame flash.
	await get_tree().process_frame
	if _inspection == null or not is_instance_valid(panel): return
	panel.size = panel.get_combined_minimum_size()
	var point: Vector2 = _canvas.get_global_transform_with_canvas().affine_inverse() * source.get_global_transform_with_canvas().origin
	panel.position = Vector2(clampf(point.x + CARD_SIZE.x * 0.5 - panel.size.x * 0.5, 20, SIZE.x - panel.size.x - 20), maxf(100, point.y - panel.size.y - 18))
	panel.show()
	_wire_focus()
	back.grab_focus()
	interaction_changed.emit()

func close_inspection() -> void:
	if _inspection == null: return
	_canvas.remove_child(_inspection)
	_inspection.queue_free()
	_inspection = null
	if is_instance_valid(_inspection_return): _inspection_return.grab_focus()
	_inspection_return = null
	_wire_focus()
	interaction_changed.emit()

func _mat(parent: Node, rect: Rect2, large_header: bool = false) -> void:
	if large_header:
		# Expand only the painted header's leather inset. The metal border and
		# lower rail retain their native thickness and the title gets real room.
		_mat_slice(parent, Rect2(rect.position, Vector2(rect.size.x, 43)), Rect2(0, 0, 1122, 86), 0, 0)
		_mat_slice(parent, Rect2(rect.position + Vector2(0, 43), Vector2(rect.size.x, 56)), Rect2(0, 86, 1122, 40), 0, 0)
		_mat_slice(parent, Rect2(rect.position + Vector2(0, 99), Vector2(rect.size.x, rect.size.y - 99)), Rect2(0, 126, 1122, 1276), 34, 160)
	else:
		_mat_slice(parent, rect, Rect2(), 160, 160)

func _mat_slice(parent: Node, rect: Rect2, region: Rect2, top: int, bottom: int) -> void:
	var mat := NinePatchRect.new()
	mat.texture = Assets.load_texture(ART + "workmat.png")
	mat.region_rect = region
	mat.position = rect.position
	mat.size = rect.size * 2.0
	mat.scale = Vector2.ONE * 0.5
	mat.patch_margin_left = 120
	mat.patch_margin_right = 120
	mat.patch_margin_top = top
	mat.patch_margin_bottom = bottom
	mat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = MatMaterial
	mat.material = material
	parent.add_child(mat)

func _framed_equipment(parent: Node, id: String, rect: Rect2) -> TextureRect:
	_picture(parent, ART + "item_cradle.png", rect)
	var icon: TextureRect = _equipment_picture(parent, id, Rect2(rect.position + rect.size * 0.20, rect.size * 0.60))
	# Replay the existing cradle's rim above the gear. Its central fabric is
	# punched out by the shader, leaving an actual foreground lip at every edge.
	var rim: TextureRect = _picture(parent, ART + "item_cradle.png", rect)
	rim.name = "EquipmentRim"
	var material := ShaderMaterial.new()
	material.shader = FrameRim
	rim.material = material
	return icon

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
	# Set wrapping before text/size so the initial unwrapped minimum cannot
	# expand a fixed-width label beyond its frame.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if rect.size.x > 0 else TextServer.AUTOWRAP_OFF
	label.text = title
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if centered: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Typography.apply_label_role(label, Typography.ROLE_TITLE if font_size >= Typography.SIZE_SECTION else Typography.ROLE_BODY_LARGE)
	Typography.set_label_size(label, font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("191016"))
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_color_override("font_shadow_color", Color(0.025, 0.016, 0.02, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 1)
	if font_size >= Typography.SIZE_SECTION:
		var material := ShaderMaterial.new()
		material.shader = TypeMaterial
		material.set_shader_parameter("line_height", maxf(rect.size.y, float(font_size)))
		label.material = material
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
	return {"recipient": recipient, "donor": donor, "source_index": donor_index, "target_index": target_index, "busy": busy, "used": _used(), "can_commit": _commit != null and is_instance_valid(_commit) and not _commit.disabled, "result": _result(), "reduced_motion": reduced_motion, "intro_open": _intro_open, "inspecting": _inspection != null, "picker_role": _picker_role, "picker_slot": _picker_slot, "picker_items": _picker_items.duplicate(), "props_occlude_portrait": _props != null and _props.get_index() > _portrait.get_index(), "bench_occludes_portrait": _bench != null and _bench.get_index() > _portrait.get_index()}

func _input(event: InputEvent) -> void:
	if not visible or busy: return
	if event is InputEventKey and event.pressed:
		_keyboard_navigation = true
		var router: Node = get_node_or_null("/root/InputRouter")
		if router != null: router.call("set_modality", "pointer")
	elif event is InputEventMouseMotion or event is InputEventMouseButton:
		_keyboard_navigation = false
	elif not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	for button: Node in _canvas.find_children("*", "Button", true, false):
		if button is Choice: button.set("keyboard_navigation", _keyboard_navigation)

func _build_intro() -> void:
	# Reuse the game's dialogue material; the workshop and speaker remain visible.
	var panel := Panel.new()
	panel.name = "GraftwrightDialogue"
	panel.position = Vector2(620, 555)
	panel.size = Vector2(1160, 365)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var skin := UiSkinScript.new()
	var style: StyleBoxFlat = skin.make_plain_card_style(Color(0.10, 0.065, 0.08, 0.94), Color("9c8463"), 24.0)
	style.set_corner_radius_all(10)
	style.shadow_size = 20
	panel.add_theme_stylebox_override("panel", style)
	_content.add_child(panel)
	_label(panel, "Graftwright", Rect2(44, 20, 1072, 58), 40, IVORY)
	var words: String = "Lay down two pieces of the same kind. I'll unpick one to stitch a card into the other, replacing a card you choose. The offering won't survive my needle."
	if not _has_pair():
		words = "My needle needs two pieces of the same kind. Bring me something to spare, and I'll unpick it to stitch one of its cards into another piece, replacing a card you choose."
	var text: Label = _label(panel, words, Rect2(44, 92, 1072, 116), 26, IVORY)
	text.name = "GraftwrightDialogueBody"
	text.add_theme_font_override("font", Typography.text_font())
	text.material = null
	if _has_pair():
		_intro_browse = _action(panel, "Browse equipment", Rect2(735, 224, 380, 120), begin_work, 24)
		_intro_browse.name = "GraftBrowse"
		_leave = _quiet(panel, "Skip", Rect2(545, 256, 155, 56), request_leave)
	else:
		_leave = _action(panel, "Skip", Rect2(750, 224, 365, 120), request_leave)
	_leave.name = "GraftSkip"

func begin_work() -> void:
	if busy or not _intro_open: return
	_intro_open = false
	_rebuild()
	focus_first()
	sound_requested.emit("select")
	interaction_changed.emit()

func _build_picker_context() -> void:
	var mismatch: bool = _picker_role == "donor" and not recipient.is_empty() and _picker_slot != Data.equipment_slot(recipient)
	if mismatch:
		_label(_picker, "Sacrifice must match the equipment to improve: " + Data.equipment_slot(recipient).capitalize(), Rect2(550, 847, 850, 38), 18, MUTED)
		var change: Button = _quiet(_picker, "Choose equipment to improve", Rect2(1450, 846, 345, 42), func() -> void:
			_picker_role = "recipient"
			_rebuild()
			focus_first()
		)
		change.name = "PickerChangeRecipient"
	elif _picker_role == "recipient" and not donor.is_empty() and _picker_slot != Data.equipment_slot(donor):
		_label(_picker, "Choosing another type clears the sacrifice.", Rect2(550, 847, 1220, 38), 18, MUTED, true)
	if _picker_items.is_empty():
		_label(_picker, "No " + _picker_slot.to_lower() + " equipment collected.", Rect2(840, 460, 880, 70), 24, MUTED, true)

func _equipment_picture(parent: Node, id: String, rect: Rect2) -> TextureRect:
	var picture: TextureRect = _picture(parent, str(Data.equipment_def(id).get("icon_path", "")), rect)
	# Equipment PNGs have different transparent margins. Center the visible art,
	# not the full source canvas, within the cradle's measured circular aperture.
	var used: Rect2i = Assets.texture_used_rect(picture.texture)
	if used.has_area():
		var atlas := AtlasTexture.new()
		atlas.atlas = picture.texture
		atlas.region = Rect2(used)
		picture.texture = atlas
	return picture

func _build_foreground_props() -> void:
	_props = Node2D.new()
	_props.name = "BenchPropsForeground"
	_canvas.add_child(_props)
	# Silhouettes use the atelier's original 1672x941 source coordinates. UVs
	# sample the same painting without repainted props or a rectangular cutout.
	_foreground_polygon(PackedVector2Array([Vector2(0, 625), Vector2(25, 627), Vector2(50, 634), Vector2(68, 632), Vector2(94, 644), Vector2(112, 661), Vector2(121, 679), Vector2(139, 697), Vector2(0, 697)]))
	_foreground_polygon(PackedVector2Array([Vector2(150, 648), Vector2(153, 644), Vector2(164, 642), Vector2(182, 643), Vector2(192, 646), Vector2(194, 650), Vector2(189, 655), Vector2(190, 698), Vector2(151, 698), Vector2(153, 655)]))
	_foreground_polygon(PackedVector2Array([Vector2(198, 646), Vector2(204, 642), Vector2(221, 641), Vector2(237, 644), Vector2(241, 648), Vector2(239, 654), Vector2(239, 698), Vector2(197, 698), Vector2(199, 655)]))
	_foreground_polygon(PackedVector2Array([Vector2(242, 680), Vector2(250, 671), Vector2(262, 666), Vector2(283, 664), Vector2(302, 666), Vector2(315, 672), Vector2(321, 682), Vector2(319, 698), Vector2(243, 698)]))
	_foreground_polygon(PackedVector2Array([Vector2(249, 654), Vector2(251, 653), Vector2(261, 674), Vector2(259, 675)]))
	_foreground_polygon(PackedVector2Array([Vector2(262, 650), Vector2(264, 650), Vector2(269, 671), Vector2(267, 671)]))
	_foreground_polygon(PackedVector2Array([Vector2(290, 649), Vector2(292, 650), Vector2(284, 670), Vector2(282, 670)]))

func _foreground_polygon(points: PackedVector2Array) -> void:
	var polygon := Polygon2D.new()
	polygon.texture = Assets.load_texture(ART + "atelier.png")
	polygon.uv = points
	var fitted := PackedVector2Array()
	for point: Vector2 in points: fitted.append(point * SIZE / Vector2(1672, 941))
	polygon.polygon = fitted
	polygon.antialiased = true
	_props.add_child(polygon)

func _has_pair() -> bool:
	for id: String in Rules.owned(state):
		if not Rules.donors(state, id).is_empty(): return true
	return false

extends Node

const Typography = preload("res://scripts/ui_typography.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")

var _tile: PanelContainer
var _actions := HBoxContainer.new()
var _sync: Callable
var _gesture_active: bool = false
var _pointer_blocked: bool = false
var _dragged: bool = false
var _click_origin := Vector2.ZERO

func configure(tile: PanelContainer, equip: Callable, inspect: Callable, can_equip: bool, sync: Callable) -> void:
	_tile = tile
	_sync = sync
	var content: VBoxContainer = tile.find_child("RowText", true, false) as VBoxContainer
	# The permanent slot keeps every neighbour still through selection and dragging.
	var slot := Control.new()
	slot.name = "CharacterPackActionSlot"
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size = Vector2(208.0, 32.0) * Typography.ui_scale(tile)
	content.add_child(slot)
	_actions.name = "CharacterPackActions"
	_actions.visible = false
	_actions.add_theme_constant_override("separation", roundi(Typography.scaled_value(tile, 8.0)))
	slot.add_child(_actions)
	_actions.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for action: String in ["Equip", "Inspect"]:
		var button := Button.new()
		button.text = action
		button.custom_minimum_size = Vector2(100.0, 32.0) * Typography.ui_scale(tile)
		UiSkin.new().apply_button_stylebox_overrides(button, UiSkin.VARIANT_STANDARD)
		Typography.set_button_size(button, 16)
		button.disabled = action == "Equip" and not can_equip
		button.pressed.connect(equip if action == "Equip" else inspect)
		button.focus_entered.connect(_refresh.call_deferred)
		button.focus_exited.connect(_refresh.call_deferred)
		_actions.add_child(button)
	_tile.focus_entered.connect(_on_focus_entered)
	_tile.focus_exited.connect(_refresh.call_deferred)

func _input(event: InputEvent) -> void:
	if not _tile.is_visible_in_tree():
		_gesture_active = false
		return
	if _gesture_active and event.is_action_pressed("ui_cancel"):
		_gesture_active = false
		_pointer_blocked = true
		_refresh.call_deferred()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = event.position
		if event.pressed:
			if not _tile.get_global_rect().has_point(point) or (_actions.visible and _actions.get_global_rect().has_point(point)):
				return
			_gesture_active = true
			_pointer_blocked = true
			_dragged = false
			_click_origin = point
		elif _gesture_active:
			_gesture_active = false
			_pointer_blocked = _dragged or not _tile.get_global_rect().has_point(point)
			if not _pointer_blocked:
				_tile.grab_focus()
			_refresh.call_deferred()
	elif event is InputEventMouseMotion and _gesture_active:
		_dragged = _dragged or event.position.distance_to(_click_origin) > Typography.scaled_value(_tile, 8.0)
	elif not _gesture_active and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev")):
		_pointer_blocked = false
		_refresh.call_deferred()

func _on_focus_entered() -> void:
	if not _gesture_active:
		_pointer_blocked = false
	_refresh.call_deferred()

func _refresh() -> void:
	if not is_inside_tree() or _gesture_active:
		return
	var owner: Control = _tile.get_viewport().gui_get_focus_owner()
	var active: bool = owner == _tile or (owner != null and _tile.is_ancestor_of(owner))
	_sync.call(_tile, active)
	_actions.visible = active and not _pointer_blocked

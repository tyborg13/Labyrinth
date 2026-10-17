extends RefCounted

## Automatic modal focus is silent. Only a new pointer motion or a navigation
## focus change may expose the secondary card's glossary stack.
const Data = preload("res://scripts/game_data.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const NAVIGATION_ACTIONS := [&"ui_focus_next", &"ui_focus_prev", &"ui_up", &"ui_down", &"ui_left", &"ui_right"]
var _cards: Array[Control]
var _stack: Control
var _owner: Control
var _navigation: bool = false

func configure(stack: Control) -> void:
	_stack = stack

func bind_card(widget: Control, id: String) -> void:
	_cards.append(widget)
	widget.set_meta("boon_inspection_card", id)
	widget.focus_entered.connect(_focus_entered.bind(widget))
	widget.focus_exited.connect(_focus_exited.bind(widget))
	widget.mouse_exited.connect(_pointer_exited.bind(widget))

func handle_input(event: InputEvent) -> void:
	if not is_instance_valid(_stack): return
	if event is InputEventMouseMotion:
		_navigation = false
		var target: Control
		for widget: Control in _cards:
			if widget.get_global_rect().has_point(event.position):
				target = widget
				break
		if target != null: _show(target)
		elif is_instance_valid(_owner): _hide(_owner)
	else:
		for action: StringName in NAVIGATION_ACTIONS:
			if event.is_action_pressed(action):
				_navigation = true
				break

func _focus_entered(widget: Control) -> void:
	if _navigation: _show(widget)

func _focus_exited(widget: Control) -> void:
	if _navigation: _hide(widget)

func _pointer_exited(widget: Control) -> void:
	if not _navigation: _hide(widget)

func _show(widget: Control) -> void:
	if _owner == widget and _stack.visible: return
	var id: String = str(widget.get_meta("boon_inspection_card"))
	var card: Dictionary = Data.card_def(id)
	var leading: Array = ["time"] if int(card.get("time", 0)) > 0 else []
	var entries: Array[Dictionary] = Icons.tooltip_entries_for_rows(Icons.rows_for_card(card), leading)
	_stack.show_for(widget, entries)
	_owner = widget

func _hide(widget: Control) -> void:
	if not is_instance_valid(_stack): return
	_stack.hide_for(widget)
	if _owner == widget: _owner = null

func clear() -> void:
	if is_instance_valid(_stack): _stack.hide_stack(true)
	_stack = null
	_owner = null
	_navigation = false
	_cards.clear()

extends Node
## Camp, pause and their settings page own GUI focus until the menu closes.

const InputRouter = preload("res://scripts/input_router.gd")
const NAVIGATION_ACTIONS := ["ui_up", "ui_down", "ui_left", "ui_right", "ui_focus_next", "ui_focus_prev"]

var _owner: Control
var _scrim: Control
var _menu: Control
var _settings: Control
var _scope: Control
var _return_focus: Variant
var _saved_modes: Dictionary = {}
var _page_focus: Dictionary = {}
var _active: bool = false

func configure(owner: Control, scrim: Control, menu: Control, settings: Control) -> void:
	_owner = owner
	_scrim = scrim
	_menu = menu
	_settings = settings
	_scrim.add_child(self)
	_scrim.visibility_changed.connect(_sync_visibility)
	_menu.visibility_changed.connect(_sync_visibility)
	_settings.visibility_changed.connect(_sync_visibility)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)

func remember_focus() -> void:
	if not _active:
		_return_focus = get_viewport().gui_get_focus_owner()

func _sync_visibility() -> void:
	if not _scrim.is_visible_in_tree():
		if not _active: return
		_active = false
		_scope = null
		# Combat can rebuild background widgets while the modal is open. Validate
		# before converting a saved key to Control; a typed loop rejects freed nodes.
		for candidate: Variant in _saved_modes:
			if is_instance_valid(candidate):
				var control: Control = candidate as Control
				control.focus_mode = int(_saved_modes[candidate])
		_saved_modes.clear()
		_page_focus.clear()
		if _usable(_return_focus): _return_focus.grab_focus()
		call_deferred("_restore_focus", _return_focus)
		_return_focus = null
		return
	if not _active:
		_active = true
		var current: Control = get_viewport().gui_get_focus_owner()
		if current != null and not _scrim.is_ancestor_of(current): current.release_focus()
		_suspend_background(get_viewport())
	var next_scope: Control = _settings if _settings.is_visible_in_tree() else (_menu if _menu.is_visible_in_tree() else null)
	if next_scope == null or next_scope == _scope: return
	_scope = next_scope
	var previous: Variant = _page_focus.get(_scope)
	# Descendant visibility propagates after the scrim's notification. Seed
	# focus in the same idle queue, before drawing or the next input dispatch.
	call_deferred("_restore_page_focus", previous, _scope)

func _restore_focus(control: Variant) -> void:
	# Native pointer release can clear focus while hiding its Button. Recover
	# after that dispatch, without stealing focus established by a new overlay.
	if not _active and get_viewport().gui_get_focus_owner() == null and _usable(control): control.grab_focus()

func _restore_page_focus(control: Variant, scope: Control) -> void:
	if not _active or _scope != scope: return
	if _usable(control): control.grab_focus()
	else: _focus_first()

func _suspend_background(node: Node) -> void:
	if node == _scrim: return
	if node is Control:
		var control := node as Control
		if control.focus_mode != Control.FOCUS_NONE:
			if not _saved_modes.has(control): _saved_modes[control] = control.focus_mode
			control.focus_mode = Control.FOCUS_NONE
	for child: Node in node.get_children(): _suspend_background(child)

func handle_input(event: InputEvent) -> bool:
	if not _active: return false
	var router: Node = get_node_or_null("/root/InputRouter")
	if router != null: router.record_input_activity(event)
	_sync_visibility()
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed(InputRouter.ACTION_CANCEL):
		if _settings.is_visible_in_tree(): _owner.call("_close_settings_overlay")
		else: _owner.call("_close_menu_overlay")
		get_viewport().set_input_as_handled()
		return true
	var controller: bool = InputRouter.is_controller_event(event)
	var navigation: bool = false
	for action: String in NAVIGATION_ACTIONS:
		if event.is_action_pressed(action): navigation = true
	var controller_press: bool = controller and (event.is_pressed() or (event is InputEventJoypadMotion and absf(event.axis_value) >= InputRouter.JOYSTICK_ACTIVITY_THRESHOLD))
	if navigation or event.is_action_pressed("ui_accept") or controller_press:
		var current: Control = get_viewport().gui_get_focus_owner()
		if not _inside_scope(current):
			_focus_first()
			# The initiating press establishes focus; it must not move again or accept.
			get_viewport().set_input_as_handled()
	# Leave native menu GUI events intact, but stop run gameplay shortcut handling.
	return true

func _on_focus_changed(control: Control) -> void:
	if not _active or _scope == null: return
	if _inside_scope(control): _page_focus[_scope] = control
	else: _focus_first()

func _inside_scope(control: Control) -> bool:
	return _usable(control) and _scope != null and (_scope == control or _scope.is_ancestor_of(control))

func _usable(control: Variant) -> bool:
	return is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE and not (control is BaseButton and control.disabled)

func _focus_first() -> void:
	if _scope == null: return
	var controls: Array[Control]
	_collect(_scope, controls)
	for control: Control in controls:
		if control is BaseButton:
			control.grab_focus()
			return
	if not controls.is_empty(): controls[0].grab_focus()

func _collect(node: Node, controls: Array[Control]) -> void:
	if node is Control and _usable(node as Control) and (node as Control).focus_mode == Control.FOCUS_ALL:
		controls.append(node as Control)
	for child: Node in node.get_children(): _collect(child, controls)

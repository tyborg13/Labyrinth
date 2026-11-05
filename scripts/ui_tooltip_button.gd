extends Button

const UiTooltipPanel = preload("res://scripts/ui_tooltip_panel.gd")

# Pass retains its control while the turn is locked. Opt in without changing
# other disabled buttons, whose tooltips can explain why they are unavailable.
var dismiss_tooltip_when_disabled: bool = false:
	set(value):
		dismiss_tooltip_when_disabled = value
		set_process(value)
		set_process_input(value)
var _tooltip_requires_reentry: bool = false
var _tooltip_pointer_outside: bool = false
var _active_tooltip: WeakRef


func _ready() -> void:
	set_process(dismiss_tooltip_when_disabled)
	set_process_input(dismiss_tooltip_when_disabled)
	focus_entered.connect(_tooltip_entered)
	_sync_disabled_tooltip()


func _process(_delta: float) -> void:
	# Covers direct writes to the native disabled property as well as the
	# synchronous setter used by the Pass refresh and enemy-turn lock paths.
	_sync_disabled_tooltip()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if not Rect2(Vector2.ZERO, size).has_point(local):
			_tooltip_pointer_outside = true
		elif disabled:
			_tooltip_pointer_outside = false


func _gui_input(event: InputEvent) -> void:
	# Showing the retained overlay beneath a resting pointer also emits
	# mouse_entered. Only an actual pointer crossing may re-arm its tooltip.
	if dismiss_tooltip_when_disabled and event is InputEventMouseMotion:
		_sync_disabled_tooltip()
		if not disabled and _tooltip_pointer_outside:
			_tooltip_requires_reentry = false
		_tooltip_pointer_outside = false


func set_disabled_with_tooltip(value: bool) -> void:
	disabled = value
	_sync_disabled_tooltip()


func _sync_disabled_tooltip() -> void:
	if not dismiss_tooltip_when_disabled or not disabled:
		return
	_tooltip_requires_reentry = true
	var panel: Control = _active_tooltip.get_ref() as Control if _active_tooltip != null else null
	if is_instance_valid(panel):
		panel.hide()
		# Godot owns the tooltip PopupPanel; dismiss only this button's popup.
		var popup: PopupPanel = panel.get_parent() as PopupPanel
		if popup != null:
			popup.hide()
			popup.queue_free()
	_active_tooltip = null


func _tooltip_entered() -> void:
	_sync_disabled_tooltip()
	if not disabled:
		_tooltip_requires_reentry = false


func _get_tooltip(_at_position: Vector2) -> String:
	_sync_disabled_tooltip()
	return "" if dismiss_tooltip_when_disabled and _tooltip_requires_reentry else tooltip_text


func _make_custom_tooltip(for_text: String) -> Object:
	_sync_disabled_tooltip()
	if (dismiss_tooltip_when_disabled and _tooltip_requires_reentry) or for_text.strip_edges().is_empty():
		return null
	var panel: Control = UiTooltipPanel.make_text(for_text)
	_active_tooltip = weakref(panel)
	return panel

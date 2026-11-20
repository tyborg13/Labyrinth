extends Node
## Shares the hover content with a controller-focused control. The popup
## follows focus and modality without moving the pointer or handling input.

const FOCUS_TOOLTIP_Z: int = 2201 # Existing focus-tooltip layer.

var _owner: Control
var _router: Node
var _panel: Control
var _factory: Callable
var _above: bool

static func attach(owner: Control, factory: Callable = Callable(), above: bool = false) -> void:
	var binding := new()
	binding._factory = factory
	binding._above = above
	owner.add_child(binding)

func _ready() -> void:
	_owner = get_parent() as Control
	_router = get_node_or_null("/root/InputRouter")
	_owner.focus_entered.connect(_sync)
	_owner.focus_exited.connect(_sync)
	_owner.visibility_changed.connect(_sync)
	_owner.item_rect_changed.connect(_place)
	get_viewport().size_changed.connect(_place)
	if _router != null:
		_router.modality_changed.connect(_on_modality_changed)
	_sync()

func _on_modality_changed(_modality: String) -> void:
	_sync()

func _sync() -> void:
	var show_help: bool = _owner.is_visible_in_tree() and _owner.has_focus() and _router != null and _router.call("using_controller")
	if not show_help or _owner.tooltip_text.is_empty():
		if is_instance_valid(_panel):
			_owner.remove_child(_panel)
			_panel.queue_free()
			_panel = null
		return
	if is_instance_valid(_panel): return
	_panel = _factory.call(_owner.tooltip_text) if _factory.is_valid() else _native_panel()
	_panel.name = "ControllerFocusTooltip"
	_panel.set_meta("tooltip_surface", true)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.top_level = true
	_panel.z_as_relative = false
	_panel.z_index = FOCUS_TOOLTIP_Z
	_owner.add_child(_panel)
	_panel.resized.connect(_place)
	_panel.reset_size()
	_place()

func _native_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"TooltipPanel"
	var label := Label.new()
	label.theme_type_variation = &"TooltipLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = _owner.tooltip_text
	panel.add_child(label)
	return panel

func _place() -> void:
	if not is_instance_valid(_panel): return
	var anchor: Rect2 = _owner.get_global_rect()
	var bounds: Rect2 = _owner.get_viewport_rect()
	var fits_below: bool = anchor.end.y + _panel.size.y <= bounds.end.y
	var y: float = anchor.position.y - _panel.size.y if _above or not fits_below else anchor.end.y
	_panel.global_position = Vector2(
		clampf(anchor.position.x, bounds.position.x, maxf(bounds.position.x, bounds.end.x - _panel.size.x)),
		clampf(y, bounds.position.y, maxf(bounds.position.y, bounds.end.y - _panel.size.y))
	)

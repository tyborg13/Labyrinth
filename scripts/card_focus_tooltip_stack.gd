extends VBoxContainer
class_name CardFocusTooltipStack

const UiTooltipPanel = preload("res://scripts/ui_tooltip_panel.gd")

const CARD_GAP: float = 14.0
const SAFE_MARGIN: float = 18.0
const STACK_SEPARATION: int = 7

var _follow_target: Control
var _entries: Array[Dictionary] = []

func _ready() -> void:
	name = "CardFocusTooltipStack"
	visible = false
	top_level = true
	z_as_relative = false
	z_index = 1320
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", STACK_SEPARATION)
	set_process(false)

func show_for(target: Control, entries: Array) -> void:
	hide_stack()
	if target == null or entries.is_empty():
		return
	_follow_target = target
	for entry_var: Variant in entries:
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = (entry_var as Dictionary).duplicate(true)
		var icon_texture: Texture2D = entry.get("texture", null) as Texture2D
		if icon_texture == null:
			continue
		var body_lines := PackedStringArray()
		var description: String = str(entry.get("description", "")).strip_edges()
		if not description.is_empty():
			body_lines.append(description)
		var panel: PanelContainer = UiTooltipPanel.make_icon_lines(
			icon_texture,
			str(entry.get("title", "")),
			body_lines
		)
		panel.name = "CardFocusTooltip_%02d_%s" % [
			_entries.size(),
			str(entry.get("icon", "icon")).to_pascal_case(),
		]
		panel.set_meta("icon_key", str(entry.get("icon", "")))
		panel.set_meta("semantic_key", str(entry.get("semantic_key", "")))
		add_child(panel)
		_entries.append(entry)
	if _entries.is_empty():
		_follow_target = null
		return
	visible = true
	set_process(true)
	update_minimum_size()
	_follow_target_now()

func hide_stack() -> void:
	visible = false
	set_process(false)
	_follow_target = null
	_entries.clear()
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()

func entry_count() -> int:
	return _entries.size()

func entry_icon_keys() -> Array[String]:
	var keys: Array[String] = []
	for entry: Dictionary in _entries:
		keys.append(str(entry.get("icon", "")))
	return keys

func _process(_delta: float) -> void:
	_follow_target_now()

func _follow_target_now() -> void:
	if not visible or _follow_target == null or not is_instance_valid(_follow_target):
		hide_stack()
		return
	if not _follow_target.is_inside_tree() or _follow_target.is_queued_for_deletion():
		hide_stack()
		return
	var stack_size: Vector2 = get_combined_minimum_size()
	size = stack_size
	var card_rect: Rect2 = _visual_global_rect(_follow_target)
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var target_position := Vector2(
		card_rect.end.x + CARD_GAP,
		card_rect.get_center().y - stack_size.y * 0.5
	)
	target_position.x = minf(
		target_position.x,
		viewport_rect.end.x - SAFE_MARGIN - stack_size.x
	)
	target_position.y = clampf(
		target_position.y,
		viewport_rect.position.y + SAFE_MARGIN,
		viewport_rect.end.y - SAFE_MARGIN - stack_size.y
	)
	global_position = target_position

static func _visual_global_rect(control: Control) -> Rect2:
	var transform: Transform2D = control.get_global_transform_with_canvas()
	var points := PackedVector2Array([
		transform * Vector2.ZERO,
		transform * Vector2(control.size.x, 0.0),
		transform * control.size,
		transform * Vector2(0.0, control.size.y),
	])
	var minimum: Vector2 = points[0]
	var maximum: Vector2 = points[0]
	for point: Vector2 in points:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum)

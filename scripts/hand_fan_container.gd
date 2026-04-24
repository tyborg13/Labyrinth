extends Container
class_name HandFanContainer

const DEFAULT_ARCH_HEIGHT: float = 65.0
const DEFAULT_MAX_ROTATION_DEGREES: float = 14.0
const DEFAULT_BOTTOM_OVERFLOW_ALLOWANCE: float = 36.0

var _card_gap: float = 0.0
var _fan_enabled: bool = false
var _arch_height: float = DEFAULT_ARCH_HEIGHT
var _max_rotation_degrees: float = DEFAULT_MAX_ROTATION_DEGREES
var _bottom_overflow_allowance: float = DEFAULT_BOTTOM_OVERFLOW_ALLOWANCE

func _ready() -> void:
	clip_contents = false

func configure_layout(card_gap: float, fan_enabled: bool, arch_height: float = DEFAULT_ARCH_HEIGHT, max_rotation_degrees: float = DEFAULT_MAX_ROTATION_DEGREES, bottom_overflow_allowance: float = DEFAULT_BOTTOM_OVERFLOW_ALLOWANCE) -> void:
	_card_gap = card_gap
	_fan_enabled = fan_enabled
	_arch_height = arch_height if fan_enabled else 0.0
	_max_rotation_degrees = max_rotation_degrees if fan_enabled else 0.0
	_bottom_overflow_allowance = bottom_overflow_allowance if fan_enabled else 0.0
	update_minimum_size()
	queue_sort()

func refresh_layout() -> void:
	update_minimum_size()
	queue_sort()

func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	var children: Array[Control] = _layout_children()
	for index: int in range(children.size()):
		var child: Control = children[index]
		var child_size: Vector2 = _child_layout_size(child)
		var rect: Rect2 = card_rect_for_layout(index, children.size(), child_size, _card_gap, _fan_enabled, _arch_height)
		fit_child_in_rect(child, rect)
		child.pivot_offset = rect.size * 0.5
		child.rotation = card_rotation_for_layout(index, children.size(), _fan_enabled, _max_rotation_degrees)
		child.z_index = card_z_index_for_layout(index, children.size())

func _get_minimum_size() -> Vector2:
	var children: Array[Control] = _layout_children()
	if children.is_empty():
		return Vector2.ZERO
	var bounds := Rect2(card_rect_for_layout(0, children.size(), _child_layout_size(children[0]), _card_gap, _fan_enabled, _arch_height))
	var max_child_height: float = bounds.size.y
	for index: int in range(1, children.size()):
		var child: Control = children[index]
		var child_size: Vector2 = _child_layout_size(child)
		max_child_height = maxf(max_child_height, child_size.y)
		bounds = bounds.merge(card_rect_for_layout(index, children.size(), child_size, _card_gap, _fan_enabled, _arch_height))
	bounds.size.y = maxf(max_child_height, bounds.size.y - bottom_overflow_allowance_for_layout(children.size(), _fan_enabled, _arch_height, _bottom_overflow_allowance))
	return bounds.size

func _layout_children() -> Array[Control]:
	var controls: Array[Control] = []
	for child: Node in get_children():
		if child is Control:
			controls.append(child as Control)
	return controls

func _child_layout_size(child: Control) -> Vector2:
	var layout_size: Vector2 = child.custom_minimum_size
	if layout_size.x <= 0.0:
		layout_size.x = child.size.x
	if layout_size.y <= 0.0:
		layout_size.y = child.size.y
	return layout_size

static func content_size_for_layout(total: int, card_size: Vector2, card_gap: float, fan_enabled: bool, arch_height: float = DEFAULT_ARCH_HEIGHT, bottom_overflow_allowance: float = DEFAULT_BOTTOM_OVERFLOW_ALLOWANCE) -> Vector2:
	if total <= 0:
		return Vector2.ZERO
	var width: float = card_size.x + maxf(0.0, float(total - 1)) * (card_size.x + card_gap)
	var full_height: float = card_size.y + (arch_height if fan_enabled and total > 1 else 0.0)
	var height: float = maxf(card_size.y, full_height - bottom_overflow_allowance_for_layout(total, fan_enabled, arch_height, bottom_overflow_allowance))
	return Vector2(width, height)

static func card_rect_for_layout(index: int, total: int, card_size: Vector2, card_gap: float, fan_enabled: bool, arch_height: float = DEFAULT_ARCH_HEIGHT) -> Rect2:
	if total <= 0:
		return Rect2(Vector2.ZERO, card_size)
	var stride: float = card_size.x + card_gap
	var x: float = maxf(0.0, float(index) * stride)
	var y: float = fan_offset_y_for_layout(index, total, fan_enabled, arch_height)
	return Rect2(Vector2(x, y), card_size)

static func fan_offset_y_for_layout(index: int, total: int, fan_enabled: bool, arch_height: float = DEFAULT_ARCH_HEIGHT) -> float:
	if not fan_enabled or total <= 1:
		return 0.0
	var center: float = float(total - 1) * 0.5
	var normalized: float = absf(float(index) - center) / maxf(1.0, center)
	return pow(normalized, 1.35) * arch_height

static func card_rotation_for_layout(index: int, total: int, fan_enabled: bool, max_rotation_degrees: float = DEFAULT_MAX_ROTATION_DEGREES) -> float:
	if not fan_enabled or total <= 1:
		return 0.0
	var center: float = float(total - 1) * 0.5
	var normalized: float = (float(index) - center) / maxf(1.0, center)
	return deg_to_rad(normalized * max_rotation_degrees)

static func card_z_index_for_layout(index: int, total: int) -> int:
	if total <= 1:
		return 0
	return index

static func bottom_overflow_allowance_for_layout(total: int, fan_enabled: bool, arch_height: float = DEFAULT_ARCH_HEIGHT, bottom_overflow_allowance: float = DEFAULT_BOTTOM_OVERFLOW_ALLOWANCE) -> float:
	if not fan_enabled or total <= 1:
		return 0.0
	return clampf(bottom_overflow_allowance, 0.0, arch_height)

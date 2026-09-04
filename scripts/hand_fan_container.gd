extends Container
class_name HandFanContainer

const DEFAULT_ARCH_HEIGHT: float = 14.0
const DEFAULT_MAX_ROTATION_DEGREES: float = 3.0
const DEFAULT_BOTTOM_OVERFLOW_ALLOWANCE: float = 2.0
const DEFAULT_HORIZONTAL_OVERFLOW_ALLOWANCE: float = 92.0
const DEFAULT_CARD_OVERLAP_RATIO: float = 0.20
const DENSE_OVERLAP_START_COUNT: int = 5
const DENSE_OVERLAP_RATIO_STEP: float = 0.07
const MAX_CARD_OVERLAP_RATIO: float = 0.40
const DEFAULT_EMPHASIS_SCALE: float = 1.28
const DEFAULT_EMPHASIS_EXTRA_LIFT: float = 12.0
const TARGETING_EMPHASIS_SCALE: float = 1.10
const TARGETING_EMPHASIS_EXTRA_LIFT: float = 22.0
const DEFAULT_EMPHASIS_REMAINING_OVERLAP: float = 12.0
const DEFAULT_EMPHASIS_MAX_SIDE_SHIFT: float = 60.0
const DEFAULT_MIN_EXPOSED_CARD_WIDTH: float = 36.0
const EMPHASIS_Z_INDEX_BONUS: int = 100
const EMPHASIS_TRANSITION_SECONDS: float = 0.13

var _card_gap: float = 0.0
var _fan_enabled: bool = false
var _arch_height: float = DEFAULT_ARCH_HEIGHT
var _max_rotation_degrees: float = DEFAULT_MAX_ROTATION_DEGREES
var _bottom_overflow_allowance: float = DEFAULT_BOTTOM_OVERFLOW_ALLOWANCE
var _emphasized_index: int = -1
var _emphasis_strength: float = 0.0
var _emphasis_scale: float = DEFAULT_EMPHASIS_SCALE
var _emphasis_extra_lift: float = DEFAULT_EMPHASIS_EXTRA_LIFT
var _emphasis_tween: Tween

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

func set_emphasized_index(
	index: int,
	animated: bool = true,
	emphasis_scale: float = DEFAULT_EMPHASIS_SCALE,
	emphasis_extra_lift: float = DEFAULT_EMPHASIS_EXTRA_LIFT
) -> void:
	var child_count: int = _layout_children().size()
	var next_index: int = index if index >= 0 and index < child_count else -1
	_emphasis_scale = maxf(1.0, emphasis_scale)
	_emphasis_extra_lift = maxf(0.0, emphasis_extra_lift)
	if _emphasis_tween != null:
		_emphasis_tween.kill()
		_emphasis_tween = null
	if next_index >= 0:
		var changed_index: bool = next_index != _emphasized_index
		_emphasized_index = next_index
		if not animated or not is_inside_tree():
			_set_emphasis_strength(1.0)
			return
		if changed_index and _emphasis_strength <= 0.001:
			_emphasis_strength = 0.0
		_tween_emphasis_to(1.0)
		return
		_tween_emphasis_to(1.0)
		return
	if _emphasized_index < 0:
		_set_emphasis_strength(0.0)
		return
	if not animated or not is_inside_tree():
		_emphasized_index = -1
		_set_emphasis_strength(0.0)
		return
	_tween_emphasis_to(0.0, true)

func emphasized_index() -> int:
	return _emphasized_index if _emphasis_strength > 0.001 else -1

func emphasis_strength() -> float:
	return _emphasis_strength

func _tween_emphasis_to(target: float, clear_index_after: bool = false) -> void:
	var start: float = _emphasis_strength
	if is_equal_approx(start, target):
		_set_emphasis_strength(target)
		if clear_index_after:
			_emphasized_index = -1
		return
	_emphasis_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_emphasis_tween.tween_method(_set_emphasis_strength, start, target, EMPHASIS_TRANSITION_SECONDS)
	if clear_index_after:
		_emphasis_tween.tween_callback(_finish_emphasis_clear)

func _set_emphasis_strength(value: float) -> void:
	_emphasis_strength = clampf(value, 0.0, 1.0)
	queue_sort()

func _finish_emphasis_clear() -> void:
	_emphasis_strength = 0.0
	_emphasized_index = -1
	_emphasis_tween = null
	queue_sort()

func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	var children: Array[Control] = _layout_children()
	for index: int in range(children.size()):
		var child: Control = children[index]
		var child_size: Vector2 = _child_layout_size(child)
		var rect: Rect2 = emphasized_card_rect_for_layout(
			index,
			children.size(),
			child_size,
			_card_gap,
			_fan_enabled,
			_emphasized_index,
			_emphasis_strength,
			_arch_height,
			_emphasis_scale,
			_emphasis_extra_lift
		)
		fit_child_in_rect(child, rect)
		child.pivot_offset = rect.size * 0.5
		child.scale = Vector2.ONE * card_scale_for_emphasized_layout(
			index,
			_emphasized_index,
			_emphasis_strength,
			_emphasis_scale
		)
		child.rotation = card_rotation_for_emphasized_layout(
			index,
			children.size(),
			_fan_enabled,
			_emphasized_index,
			_emphasis_strength,
			_max_rotation_degrees
		)
		child.z_index = card_z_index_for_emphasized_layout(
			index,
			children.size(),
			_emphasized_index,
			_emphasis_strength
		)

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
	if _fan_enabled and children.size() > 1:
		bounds.size.x += DEFAULT_HORIZONTAL_OVERFLOW_ALLOWANCE
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
	if fan_enabled and total > 1:
		width += DEFAULT_HORIZONTAL_OVERFLOW_ALLOWANCE
	var full_height: float = card_size.y + (arch_height if fan_enabled and total > 1 else 0.0)
	var height: float = maxf(card_size.y, full_height - bottom_overflow_allowance_for_layout(total, fan_enabled, arch_height, bottom_overflow_allowance))
	return Vector2(width, height)

static func card_rect_for_layout(index: int, total: int, card_size: Vector2, card_gap: float, fan_enabled: bool, arch_height: float = DEFAULT_ARCH_HEIGHT) -> Rect2:
	if total <= 0:
		return Rect2(Vector2.ZERO, card_size)
	var stride: float = card_size.x + card_gap
	var horizontal_inset: float = DEFAULT_HORIZONTAL_OVERFLOW_ALLOWANCE * 0.5 if fan_enabled and total > 1 else 0.0
	var x: float = horizontal_inset + maxf(0.0, float(index) * stride)
	var y: float = fan_offset_y_for_layout(index, total, fan_enabled, arch_height)
	return Rect2(Vector2(x, y), card_size)

static func emphasized_card_rect_for_layout(
	index: int,
	total: int,
	card_size: Vector2,
	card_gap: float,
	fan_enabled: bool,
	emphasized_index: int,
	emphasis_strength: float,
	arch_height: float = DEFAULT_ARCH_HEIGHT,
	emphasis_scale: float = DEFAULT_EMPHASIS_SCALE,
	emphasis_extra_lift: float = DEFAULT_EMPHASIS_EXTRA_LIFT
) -> Rect2:
	var rect: Rect2 = card_rect_for_layout(index, total, card_size, card_gap, fan_enabled, arch_height)
	if emphasized_index < 0 or emphasized_index >= total or emphasis_strength <= 0.0:
		return rect
	var strength: float = clampf(emphasis_strength, 0.0, 1.0)
	var side_shift: float = emphasis_side_shift_for_layout(card_size, card_gap, strength, emphasis_scale)
	if index < emphasized_index:
		rect.position.x -= side_shift
	elif index > emphasized_index:
		rect.position.x += side_shift
	else:
		var focused_scale: float = lerpf(1.0, emphasis_scale, strength)
		rect.position.y -= (
			card_size.y * (focused_scale - 1.0) * 0.5
			+ emphasis_extra_lift * strength
		)
	return rect

static func overlap_gap_for_card_width(
	card_width: float,
	overlap_ratio: float = DEFAULT_CARD_OVERLAP_RATIO
) -> float:
	return -maxf(0.0, card_width) * clampf(overlap_ratio, 0.0, 0.90)

static func overlap_ratio_for_hand_size(total: int) -> float:
	var extra_cards: int = maxi(0, total - DENSE_OVERLAP_START_COUNT)
	return minf(
		MAX_CARD_OVERLAP_RATIO,
		DEFAULT_CARD_OVERLAP_RATIO + float(extra_cards) * DENSE_OVERLAP_RATIO_STEP
	)

static func emphasis_side_shift_for_layout(
	card_size: Vector2,
	card_gap: float,
	emphasis_strength: float,
	emphasis_scale: float = DEFAULT_EMPHASIS_SCALE
) -> float:
	var final_half_expansion: float = maxf(0.0, card_size.x * (emphasis_scale - 1.0) * 0.5)
	var existing_overlap: float = maxf(0.0, -card_gap)
	var final_shift: float = maxf(
		0.0,
		existing_overlap + final_half_expansion - DEFAULT_EMPHASIS_REMAINING_OVERLAP
	)
	return minf(DEFAULT_EMPHASIS_MAX_SIDE_SHIFT, final_shift) * clampf(emphasis_strength, 0.0, 1.0)

static func card_gap_for_available_width(
	total: int,
	card_size: Vector2,
	preferred_gap: float,
	available_width: float,
	emphasis_reserve: float = DEFAULT_EMPHASIS_MAX_SIDE_SHIFT * 2.0
) -> float:
	if total <= 1 or available_width <= 0.0:
		return preferred_gap
	var reserved_width: float = maxf(0.0, emphasis_reserve) + DEFAULT_HORIZONTAL_OVERFLOW_ALLOWANCE
	var fitted_stride: float = (
		available_width - reserved_width - card_size.x
	) / float(total - 1)
	var fitted_gap: float = fitted_stride - card_size.x
	var minimum_gap: float = -card_size.x + minf(DEFAULT_MIN_EXPOSED_CARD_WIDTH, card_size.x)
	return clampf(minf(preferred_gap, fitted_gap), minimum_gap, preferred_gap)

static func card_scale_for_emphasized_layout(
	index: int,
	emphasized_index: int,
	emphasis_strength: float,
	emphasis_scale: float = DEFAULT_EMPHASIS_SCALE
) -> float:
	if index != emphasized_index:
		return 1.0
	return lerpf(1.0, emphasis_scale, clampf(emphasis_strength, 0.0, 1.0))

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

static func card_rotation_for_emphasized_layout(
	index: int,
	total: int,
	fan_enabled: bool,
	emphasized_index: int,
	emphasis_strength: float,
	max_rotation_degrees: float = DEFAULT_MAX_ROTATION_DEGREES
) -> float:
	var rotation: float = card_rotation_for_layout(index, total, fan_enabled, max_rotation_degrees)
	if index != emphasized_index:
		return rotation
	return lerpf(rotation, 0.0, clampf(emphasis_strength, 0.0, 1.0))

static func card_z_index_for_layout(index: int, total: int) -> int:
	if total <= 1:
		return 0
	return index

static func card_z_index_for_emphasized_layout(
	index: int,
	total: int,
	emphasized_index: int,
	emphasis_strength: float
) -> int:
	if index == emphasized_index and emphasis_strength > 0.001:
		return maxi(EMPHASIS_Z_INDEX_BONUS, total + EMPHASIS_Z_INDEX_BONUS)
	return card_z_index_for_layout(index, total)

static func bottom_overflow_allowance_for_layout(total: int, fan_enabled: bool, arch_height: float = DEFAULT_ARCH_HEIGHT, bottom_overflow_allowance: float = DEFAULT_BOTTOM_OVERFLOW_ALLOWANCE) -> float:
	if not fan_enabled or total <= 1:
		return 0.0
	return clampf(bottom_overflow_allowance, 0.0, arch_height)

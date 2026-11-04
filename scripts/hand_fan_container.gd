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
const CLOSE_SLIDE_SECONDS: float = 0.18
const SPREAD_EASE_SECONDS: float = 0.12

## The cards of a slide (a closing gap, or neighbours easing apart or back) reached their slots.
signal slide_finished

## False under reduced motion: neighbours then snap to a new spread, as before.
## Covers hover moving card to card as well as snapped (click, drag) changes.
var spread_ease_enabled: bool = true
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
# A slide: child -> where it was on screen (center, rotation, size), and for a
# closing gap its tint, or for a spread ease the neighbour spread it eases into.
# Each card eases from there into its laid-out slot; a closing gap's tint eases to
# white. Hover and drag apply on top of the slide.
var _slide_starts: Dictionary = {}
var _slide_elapsed: float = 0.0
var _slide_seconds: float = CLOSE_SLIDE_SECONDS
# Each child's place at the last layout, without the emphasized card's own lift and
# size: center (local), rotation, size, its neighbour spread and its slide offset.
var _laid_out: Dictionary = {}
# A snapped emphasis change since the last layout; that layout eases the neighbours.
var _spread_ease_pending: bool = false
# Frames drawn when a spread ease began, having already taken that frame's step.
var _spread_first_step_drawn: int = -1

func _ready() -> void:
	clip_contents = false
	set_process(false)
	child_exiting_tree.connect(_on_child_exiting_tree)

## Where each child is on screen now, in child order, for a later close slide.
func close_slide_origins() -> Array[Dictionary]:
	var origins: Array[Dictionary]
	var to_global: Transform2D = get_global_transform()
	for child: Control in _layout_children():
		origins.append({"center": to_global * (child.position + child.pivot_offset), "rotation": child.rotation, "size": child.size})
	return origins

## Slide the given children (child -> close_slide_origins() entry plus "tint")
## from there into their slots, easing each tint to white over the same time.
func begin_close_slide(starts: Dictionary) -> void:
	_finish_slide(false)
	if starts.is_empty() or not is_inside_tree():
		return
	_slide_starts = starts
	_slide_elapsed = 0.0
	_slide_seconds = CLOSE_SLIDE_SECONDS
	set_process(true)
	_apply_layout()

func is_sliding() -> bool:
	return not _slide_starts.is_empty()

## How far a child still has to slide to reach its slot, on screen (zero at rest).
func slide_remaining(child: Control) -> Vector2:
	return get_global_transform().basis_xform((_laid_out.get(child, {}) as Dictionary).get("offset", Vector2.ZERO))

## A locked hand dims at once; stop easing the tints so they don't dip under it.
func settle_close_tint() -> void:
	for child: Variant in _slide_starts:
		if (_slide_starts[child] as Dictionary).has("tint"):
			_slide_starts[child]["tint"] = Color.WHITE
			if is_instance_valid(child):
				(child as Control).modulate = Color.WHITE

func _process(delta: float) -> void:
	# A spread ease begun since the last draw already took this frame's step.
	if _spread_first_step_drawn != Engine.get_frames_drawn():
		_slide_elapsed += delta
	_spread_first_step_drawn = -1
	if _slide_starts.is_empty() or _slide_elapsed >= _slide_seconds:
		_finish_slide(true)
		return
	_apply_layout()

func _finish_slide(announce: bool) -> void:
	set_process(false)
	_spread_first_step_drawn = -1
	if _slide_starts.is_empty():
		return
	for child: Variant in _slide_starts:
		if is_instance_valid(child) and (_slide_starts[child] as Dictionary).has("tint"):
			(child as Control).modulate = Color.WHITE
	_slide_starts = {}
	_apply_layout()
	if announce:
		slide_finished.emit()

func _on_child_exiting_tree(child: Node) -> void:
	_laid_out.erase(child)
	if _slide_starts.has(child):
		if (_slide_starts[child] as Dictionary).has("tint"):
			(child as Control).modulate = Color.WHITE
		_slide_starts.erase(child)

# The neighbours of a snapped emphasis change ease into their new spread from
# where they are now, over SPREAD_EASE_SECONDS. The emphasized card's own lift and
# size stay immediate. Cards not laid out yet (a rebuilt hand) snap as before.
func _begin_spread_ease(children: Array[Control]) -> void:
	if not spread_ease_enabled or not is_inside_tree() or children.size() != _laid_out.size():
		return
	var spreads: Array[Vector2]
	var moved: bool = false
	for index: int in range(children.size()):
		if not _laid_out.has(children[index]):
			return
		var spread: Vector2 = _neighbour_spread(index, children.size(), _child_layout_size(children[index]))
		moved = moved or absf(spread.x - (_laid_out[children[index]]["spread"] as Vector2).x) > 0.5
		spreads.append(spread)
	if not moved:
		return
	var to_global: Transform2D = get_global_transform()
	var starts: Dictionary = {}
	for index: int in range(children.size()):
		var child: Control = children[index]
		var was: Dictionary = _laid_out[child]
		var start: Dictionary = {"center": to_global * (was["center"] as Vector2), "rotation": was["rotation"], "size": was["size"], "spread": spreads[index]}
		# A card still brightening after a close keeps brightening from its tint now.
		if (_slide_starts.get(child, {}) as Dictionary).has("tint"):
			start["tint"] = child.modulate
		starts[child] = start
	_slide_starts = starts
	# The next drawn frame already shows one step, whether this layout comes before
	# or after this frame's _process: an ease restarted by the next hovered card keeps
	# the cards moving instead of holding them still for a frame.
	_slide_elapsed = get_process_delta_time()
	_spread_first_step_drawn = Engine.get_frames_drawn()
	_slide_seconds = SPREAD_EASE_SECONDS
	set_process(true)

func _neighbour_spread(index: int, total: int, child_size: Vector2) -> Vector2:
	if index == _emphasized_index:
		return Vector2.ZERO
	var spread_rect: Rect2 = emphasized_card_rect_for_layout(index, total, child_size, _card_gap, _fan_enabled, _emphasized_index, _emphasis_strength, _arch_height, _emphasis_scale, _emphasis_extra_lift)
	return Vector2(spread_rect.position.x - card_rect_for_layout(index, total, child_size, _card_gap, _fan_enabled, _arch_height).position.x, 0.0)

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

func apply_layout_immediately() -> void:
	# Pointer drag ownership changes inside an input event. Apply the already-known
	# fan geometry synchronously so its cancel target cannot retain one stale hover
	# frame while the detached proxy is being mounted.
	_notification(NOTIFICATION_SORT_CHILDREN)

func set_emphasized_index(
	index: int,
	animated: bool = true,
	emphasis_scale: float = DEFAULT_EMPHASIS_SCALE,
	emphasis_extra_lift: float = DEFAULT_EMPHASIS_EXTRA_LIFT
) -> void:
	var child_count: int = _layout_children().size()
	var next_index: int = index if index >= 0 and index < child_count else -1
	# Snapping to another card or pose (a selected card's), or hover passing to
	# another card while one is up, eases the neighbours at the next layout instead
	# of moving them in one frame. A hand entered from rest, or left, already eases
	# with the emphasis itself.
	var spread_changes: bool = next_index != emphasized_index() or (next_index >= 0 and not is_equal_approx(maxf(1.0, emphasis_scale), _emphasis_scale))
	if spread_changes and (not animated or (next_index >= 0 and _emphasis_strength > 0.001)):
		_spread_ease_pending = true
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
	_apply_layout()

func _apply_layout() -> void:
	var children: Array[Control] = _layout_children()
	if _spread_ease_pending:
		_spread_ease_pending = false
		_begin_spread_ease(children)
	# Ease-out cubic: how much of each card's slide is still to go.
	var slide_left: float = pow(1.0 - clampf(_slide_elapsed / _slide_seconds, 0.0, 1.0), 3.0) if is_sliding() else 0.0
	# Starts are screen positions, so a card holds its place while this box re-centres.
	var from_global: Transform2D = get_global_transform().affine_inverse() if slide_left > 0.0 else Transform2D.IDENTITY
	_laid_out.clear()
	for index: int in range(children.size()):
		var child: Control = children[index]
		var child_size: Vector2 = _child_layout_size(child)
		var spread: Vector2 = _neighbour_spread(index, children.size(), child_size)
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
		var start: Dictionary = _slide_starts.get(child, {}) if slide_left > 0.0 else {}
		var resting_center: Vector2 = card_rect_for_layout(index, children.size(), child_size, _card_gap, _fan_enabled, _arch_height).get_center()
		var resting_rotation: float = card_rotation_for_layout(index, children.size(), _fan_enabled, _max_rotation_degrees)
		var size_ratio: float = 1.0
		var offset := Vector2.ZERO
		var rotation_offset: float = 0.0
		if not start.is_empty():
			# Offset the slot by what is left of the card's way from its old place,
			# so hover lift (and, in a close, neighbour spread) still apply at once on top.
			offset = (from_global * (start["center"] as Vector2) - resting_center - (start.get("spread", Vector2.ZERO) as Vector2)) * slide_left
			rect.position += offset
			var start_size: Vector2 = start["size"]
			if start_size.x > 0.0 and child_size.x > 0.0:
				size_ratio = lerpf(1.0, start_size.x / child_size.x, slide_left)
			rotation_offset = (float(start["rotation"]) - resting_rotation) * slide_left
			if start.has("tint"):
				child.modulate = (start["tint"] as Color).lerp(Color.WHITE, 1.0 - slide_left)
		_laid_out[child] = {"center": resting_center + spread + offset, "rotation": resting_rotation + rotation_offset, "size": child_size * size_ratio, "spread": spread, "offset": offset}
		fit_child_in_rect(child, rect)
		child.pivot_offset = rect.size * 0.5
		child.scale = Vector2.ONE * size_ratio * card_scale_for_emphasized_layout(
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
		child.rotation += rotation_offset
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
	var controls: Array[Control]
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

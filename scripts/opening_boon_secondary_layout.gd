extends RefCounted

## Derive the tightest row that satisfies the director's clearances, including
## the painted watch crown and the reward hover pose. No new art or pose values.
const Card = preload("res://scripts/card_widget.gd")
const Watch = Card.TimeCostBadge
const MIN_MEDALLION_TOP: float = 245.0
const RULES_TO_MEDALLION: float = 16.0
const RULES_TO_TOOLTIP: float = 8.0

static func watch_rect(widget: Control) -> Rect2:
	var badge: Control = widget.get("_time_badge")
	if not is_instance_valid(badge) or not badge.visible: return Rect2(Vector2.ZERO, widget.size)
	var radius: float = minf(badge.size.x, badge.size.y) * 0.5
	var factor: float = radius / Watch.WATCH_CASE_RADIUS
	return Rect2(badge.position + badge.size * 0.5 - Watch.WATCH_DIAL_CENTER * factor, Watch.WATCH_TEXTURE_SIZE * factor)

static func visual_watch_rect(widget: Control) -> Rect2:
	return widget.get_global_transform_with_canvas() * watch_rect(widget)

static func arrange(row: Control, cards: Array[Control], reward_size: Vector2, gap: float, rules: Control, action_top: float, hover_lift: float, hover_scale: float) -> void:
	var native_top: float = 0.0
	for widget: Control in cards:
		var watch_top: float = watch_rect(widget).position.y
		var hovered_top: float = hover_lift + widget.pivot_offset.y * (1.0 - hover_scale) + watch_top * hover_scale
		native_top = minf(native_top, minf(watch_top, hovered_top))
	var minimum_top: float = maxf(MIN_MEDALLION_TOP, rules.get_global_rect().end.y + RULES_TO_MEDALLION)
	var factor: float = minf(reward_size.x / Card.BASE_CARD_SIZE.x, reward_size.y / Card.BASE_CARD_SIZE.y)
	# The full-size three-card reward row cannot fit between these two fixed
	# director bounds. Retain the largest uniform size that can, with no overlap.
	factor = minf(factor, (action_top - minimum_top) / (Card.BASE_CARD_SIZE.y - native_top))
	var top: float = ceilf(minimum_top - native_top * factor)
	# Ceil the row origin, then absorb that subpixel into the available height.
	factor = minf(factor, (action_top - top) / Card.BASE_CARD_SIZE.y)
	var card_size: Vector2 = Card.BASE_CARD_SIZE * factor
	row.size = Vector2(card_size.x * cards.size() + gap * (cards.size() - 1), card_size.y)
	row.position = Vector2((1920.0 - row.size.x) * 0.5, top)
	for index: int in range(cards.size()):
		var widget: Control = cards[index]
		var scaler: Control = widget.get_parent()
		var slot: Control = scaler.get_parent()
		slot.custom_minimum_size = card_size
		slot.size = card_size
		slot.position = Vector2(index * (card_size.x + gap), 0.0)
		scaler.scale = Vector2.ONE * factor
		scaler.position = Vector2.ZERO

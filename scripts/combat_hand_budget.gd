extends RefCounted
## Fits the fan's resting silhouettes between the combat HUD columns.
const Objective = preload("res://scripts/combat_objective_hud.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Fan = preload("res://scripts/hand_fan_container.gd")
const COLUMN_GAP_PX: float = 16.0

## X is the container's screen-centred gap, Y the live gap, Z the centre offset.
static func fit(scene: Control, count: int, card_size: Vector2, key: Vector3 = Vector3(INF, INF, -1.0)) -> Vector3:
	if key.z < 0.0:
		key = fit_key(scene, count)
	# Cap the spread at the existing normal fan, including the space it reserves
	# for emphasis. Use the ordinary objective footprint when it shares the row.
	var available: float = scene._hand_available_width()
	var neutral_size: Vector2 = scene._hand_card_size(count, false, false, false)
	if key.z > 0.0:
		var normal_edge: float = scene.ui_root.global_position.x + Typography.SAFE_MARGIN + Objective.MINIMUM_WIDTH
		available = _width_to_left_edge(scene.hand_scroll, available, normal_edge)
	var normal_gap: float = _gap_for_width(count, card_size, available)
	var scroll: Control = scene.hand_scroll
	if count <= 1 or scroll == null or scroll.size.x <= 0.0:
		return Vector3(normal_gap, normal_gap, 0.0)
	var center: float = scroll.get_global_rect().get_center().x
	var scale_x: float = scene.get_viewport().get_stretch_transform().x.length()
	# CenterContainer and the fan sort can snap the card positions to canvas pixels.
	var clearance: float = COLUMN_GAP_PX / scale_x + Fan.CONTAINER_SNAP_ALLOWANCE
	var edges: Vector2 = _outer_card_extents(scene, count, card_size)
	var left: float = key.x + clearance
	var right: float = key.y - clearance
	var screen_gap: float = _fit_gap(center, left, right, edges, count, card_size.x, normal_gap)
	if not is_finite(left) or not is_finite(right) or left >= right:
		return Vector3(screen_gap, screen_gap, 0.0)
	var neutral_edges: Vector2 = edges if neutral_size == card_size else _outer_card_extents(scene, count, neutral_size)
	var neutral_gap: float = _gap_for_width(count, neutral_size, available)
	if is_equal_approx(_fit_gap(center, left, right, neutral_edges, count, neutral_size.x, neutral_gap), neutral_gap):
		return Vector3(screen_gap, screen_gap, 0.0)
	# Centre the entire silhouette, including the asymmetric Time watch.
	var fight_center: float = (left + right + neutral_edges.x - neutral_edges.y) * 0.5
	var fitted_gap: float = _fit_gap(fight_center, left, right, edges, count, card_size.x, normal_gap)
	return Vector3(screen_gap, fitted_gap, fight_center - center)

# The objective can enter or leave the neutral fan's row without moving
# either horizontal edge. Key the width cap on that same vertical test.
static func fit_key(scene: Control, count: int) -> Vector3:
	var neutral_size: Vector2 = scene._hand_card_size(count, false, false, false)
	var intersects: bool = _reaches_objective_height(scene, count, neutral_size, true)
	if scene.hand_scroll == null:
		return Vector3(-INF, INF, float(intersects))
	var left: float = _left_edge(scene)
	var right: float = _right_edge(scene, scene.hand_scroll.get_global_rect().get_center().x)
	var previous: Vector3 = scene._hand_hud_fit_key
	# A container can land one pixel differently after a sort. Keep the last
	# authored edge within the same allowance the fan uses to clear the column.
	if absf(left - previous.x) <= Fan.CONTAINER_SNAP_ALLOWANCE:
		left = previous.x
	if absf(right - previous.y) <= Fan.CONTAINER_SNAP_ALLOWANCE:
		right = previous.y
	return Vector3(left, right, float(intersects))

static func _fit_gap(center: float, left: float, right: float, edges: Vector2, count: int, card_width: float, normal_gap: float) -> float:
	var half_stride: float = minf(center - left - edges.x, right - center - edges.y)
	var stride: float = maxf(0.0, 2.0 * half_stride / float(count - 1))
	return minf(normal_gap, stride - card_width)

static func _outer_card_extents(scene: Control, count: int, card_size: Vector2) -> Vector2:
	var card_rect := Rect2(-card_size * 0.5, card_size)
	var angle: float = Fan.card_rotation_for_layout(0, count, true)
	var left_rotation := Transform2D(angle, Vector2.ZERO)
	var right_rotation := Transform2D(-angle, Vector2.ZERO)
	var left: float = -(left_rotation * card_rect).position.x
	var right: float = (right_rotation * card_rect).end.x
	# The Time watch protrudes beyond the card frame on the left.
	var card: Control = scene._hand_card_control(0)
	var badge: Control = card.get_node_or_null("TimeCostBadge") as Control if card != null else null
	if badge != null and badge.visible and card.size.x > 0.0:
		var badge_scale: float = card_size.x / card.size.x
		var badge_rect := Rect2(card_rect.position + badge.position * badge_scale, badge.size * badge_scale)
		left = maxf(left, -(left_rotation * badge_rect).position.x)
		right = maxf(right, (right_rotation * badge_rect).end.x)
	return Vector2(left, right)

# The dock and board exclusions retain their existing placement envelope. Using
# the fitted fan here would make the objective edge depend on its own budget.
static func dock_envelope_gap(scene: Control, count: int, card_size: Vector2) -> float:
	var available: float = scene._hand_available_width()
	if _reaches_objective_height(scene, count, card_size):
		var objective: Control = scene._combat_objective_hud
		var edge: float = maxf(objective.get_global_rect().end.x,
			scene.ui_root.global_position.x + Typography.SAFE_MARGIN + objective.preferred_width())
		available = _width_to_left_edge(scene.hand_scroll, available, edge)
	return _gap_for_width(count, card_size, available)

static func _reaches_objective_height(scene: Control, count: int, card_size: Vector2, neutral: bool = false) -> bool:
	var objective: Control = scene._combat_objective_hud
	var scroll: Control = scene.hand_scroll
	if objective == null or not objective.visible or scroll == null:
		return false
	var card: Control = scene._hand_card_control(0)
	var badge: Control = card.get_node_or_null("TimeCostBadge") as Control if card != null else null
	var overhang: float = -minf(0.0, badge.position.y) * card_size.x / card.size.x if badge != null and card.size.x > 0.0 else 0.0
	var extent: Vector2 = Fan.resting_vertical_bounds(count, card_size, overhang)
	var fan_height: float = Fan.content_size_for_layout(count, card_size, 0.0, true).y
	var center_y: float = scroll.get_global_rect().get_center().y
	if neutral:
		# Aiming tucks the live row. Evaluate the width cap at its untucked home.
		center_y = scroll.get_global_rect().end.y - maxf(scene.DESKTOP_HAND_ROW_HEIGHT, fan_height) * 0.5
	var fan_top: float = center_y - fan_height * 0.5
	var rect: Rect2 = objective.get_global_rect()
	return fan_top + extent.x < rect.end.y and fan_top + extent.y > rect.position.y

static func _width_to_left_edge(scroll: Control, available: float, edge: float) -> float:
	return minf(available, maxf(0.0, (scroll.get_global_rect().get_center().x - edge) * 2.0))

static func _gap_for_width(count: int, card_size: Vector2, available: float) -> float:
	var preferred_gap: float = Fan.overlap_gap_for_card_width(card_size.x, Fan.overlap_ratio_for_hand_size(count))
	return Fan.card_gap_for_available_width(count, card_size, preferred_gap, available)

static func _left_edge(scene: Control) -> float:
	var edge: float = -INF
	var objective: Control = scene._combat_objective_hud
	for control: Control in [objective, scene._battlefield_rule_hud, scene._play_meter, scene._movement_meter, scene._movement_undo_button]:
		if control == null or not control.is_visible_in_tree():
			continue
		var rect: Rect2 = control.get_global_rect()
		if control == objective and scene._combat_objective_hud.intro_active:
			rect = scene.ui_root.get_global_transform() * scene._combat_objective_hud_target_rect()
		edge = maxf(edge, rect.end.x)
	return edge

static func _right_edge(scene: Control, center: float) -> float:
	var edge: float = INF
	var pass_overlay: Control = scene._pass_preview_overlay
	for control: Control in [pass_overlay, scene.draw_pile, scene.discard_pile]:
		# Pass is already docked when the opening fit is still hiding it.
		if control != null and (control == pass_overlay or control.is_visible_in_tree()):
			var rect: Rect2 = control.get_global_rect()
			# Ignore a control that the dock has not positioned during startup.
			if rect.has_area() and rect.get_center().x > center:
				edge = minf(edge, rect.position.x)
	return edge

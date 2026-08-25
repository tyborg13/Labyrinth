extends RefCounted
class_name ControllerNavigation

const DIRECTION_THRESHOLD: float = 0.48
const DIRECTION_DOMINANCE: float = 1.25

static func direction_from_event(event: InputEvent) -> Vector2:
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_DPAD_LEFT:
				return Vector2.LEFT
			JOY_BUTTON_DPAD_RIGHT:
				return Vector2.RIGHT
			JOY_BUTTON_DPAD_UP:
				return Vector2.UP
			JOY_BUTTON_DPAD_DOWN:
				return Vector2.DOWN
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if absf(motion.axis_value) < DIRECTION_THRESHOLD:
			return Vector2.ZERO
		match motion.axis:
			JOY_AXIS_LEFT_X:
				return Vector2(signf(motion.axis_value), 0.0)
			JOY_AXIS_LEFT_Y:
				return Vector2(0.0, signf(motion.axis_value))
	return Vector2.ZERO

static func best_candidate_in_direction(origin: Vector2, direction: Vector2, candidates: Array[Dictionary], current_key: String = "") -> Dictionary:
	if direction.length_squared() <= 0.001:
		return {}
	var normalized_direction: Vector2 = direction.normalized()
	var best: Dictionary = {}
	var best_score: float = INF
	for candidate: Dictionary in candidates:
		if str(candidate.get("key", "")) == current_key:
			continue
		var point: Vector2 = candidate.get("point", origin)
		var delta: Vector2 = point - origin
		var distance: float = delta.length()
		if distance <= 0.01:
			continue
		var alignment: float = delta.normalized().dot(normalized_direction)
		if alignment < 0.34:
			continue
		var lateral_penalty: float = absf(delta.normalized().cross(normalized_direction))
		var score: float = distance * (1.0 + lateral_penalty * 2.8) + (1.0 - alignment) * 420.0
		if score < best_score:
			best_score = score
			best = candidate
	return best

static func nearest_candidate(point: Vector2, candidates: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	var best_distance_squared: float = INF
	for candidate: Dictionary in candidates:
		var candidate_point: Vector2 = candidate.get("point", point)
		var distance_squared: float = point.distance_squared_to(candidate_point)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best = candidate
	return best

static func wrapped_index(current_index: int, direction: int, count: int) -> int:
	if count <= 0:
		return -1
	if current_index < 0 or current_index >= count:
		return 0 if direction >= 0 else count - 1
	return posmod(current_index + (1 if direction >= 0 else -1), count)

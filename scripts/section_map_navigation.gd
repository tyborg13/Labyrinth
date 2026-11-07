extends RefCounted
## Section-map navigation depends only on room centres, never route edges.

const MAX_ANGLE_DEGREES: float = 67.5
const PERPENDICULAR_WEIGHT: float = 2.0

static func score(origin: Vector2, direction: Vector2, point: Vector2) -> float:
	if direction == Vector2.ZERO: return INF
	var d: Vector2 = direction.normalized()
	var offset: Vector2 = point - origin
	var forward: float = offset.dot(d)
	if forward <= 0.0 or forward < offset.length() * cos(deg_to_rad(MAX_ANGLE_DEGREES)):
		return INF
	return forward + PERPENDICULAR_WEIGHT * absf(offset.cross(d))

static func nearest(origin: Control, direction: Vector2, candidates: Array[Control]) -> Control:
	var best: Control
	var best_score: float = INF
	for candidate: Control in candidates:
		if candidate == origin: continue
		var candidate_score: float = score(origin.get_global_rect().get_center(), direction, candidate.get_global_rect().get_center())
		if candidate_score < best_score:
			best = candidate
			best_score = candidate_score
	return best

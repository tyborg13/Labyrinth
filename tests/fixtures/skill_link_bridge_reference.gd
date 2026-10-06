extends "res://scripts/skill_tree_view.gd"

func _annotate_connection_bridges(links: Array[Dictionary]) -> Array[Dictionary]:
	var records: Array[Dictionary]
	for left_index: int in range(links.size()):
		var left: Dictionary = links[left_index]
		for right_index: int in range(left_index + 1, links.size()):
			var right: Dictionary = links[right_index]
			if _links_are_incident(left, right):
				continue
			var left_points: PackedVector2Array = left.get("points", PackedVector2Array()) as PackedVector2Array
			var right_points: PackedVector2Array = right.get("points", PackedVector2Array()) as PackedVector2Array
			for left_segment_index: int in range(left_points.size() - 1):
				for right_segment_index: int in range(right_points.size() - 1):
					var intersection: Dictionary = _connection_segment_intersection(
						left_points[left_segment_index],
						left_points[left_segment_index + 1],
						right_points[right_segment_index],
						right_points[right_segment_index + 1]
					)
					if intersection.is_empty():
						continue
					var pair_key: String = _connection_pair_key(left, right)
					var kind: String = str(intersection.get("kind", ""))
					var record: Dictionary = {
						"kind": kind,
						"pair_key": pair_key,
						"point": intersection.get("point", Vector2.ZERO),
						"bridged": false,
					}
					if kind == "crossing":
						var left_is_lower: bool = _link_is_below(left, right)
						var lower_index: int = left_index if left_is_lower else right_index
						var lower_segment_index: int = left_segment_index if left_is_lower else right_segment_index
						var lower_points: PackedVector2Array = left_points if left_is_lower else right_points
						var point: Vector2 = intersection.get("point", Vector2.ZERO) as Vector2
						var lower_start: Vector2 = lower_points[lower_segment_index]
						var gap: Dictionary = {
							"segment_index": lower_segment_index,
							"distance": lower_start.distance_to(point),
							"half_gap": LINK_BRIDGE_HALF_GAP,
						}
						var lower_link: Dictionary = links[lower_index]
						var lower_gaps: Array = lower_link.get("bridge_gaps", []) as Array
						lower_gaps.append(gap)
						lower_link["bridge_gaps"] = lower_gaps
						links[lower_index] = lower_link
						record["bridged"] = true
						record["half_gap"] = LINK_BRIDGE_HALF_GAP
						record["lower_link"] = str(lower_link.get("sort_key", ""))
					records.append(record)
	return records


func _best_route_channel_x(
	source_id: String,
	target_id: String,
	source_stub: Vector2,
	target_stub: Vector2
) -> float:
	var preferred_x: float = (source_stub.x + target_stub.x) * 0.5
	var best_x: float = preferred_x
	var best_score: float = INF
	var obstacle_ranges: Array[Vector2] = _vertical_route_obstacle_ranges(
		source_stub.y,
		target_stub.y,
		source_id,
		target_id
	)
	var candidate_x: float = 12.0
	while candidate_x <= GRAPH_SIZE.x - 12.0:
		if _route_channel_is_clear(candidate_x, obstacle_ranges):
			var score: float = absf(candidate_x - preferred_x) + 0.18 * (
				absf(candidate_x - source_stub.x) + absf(candidate_x - target_stub.x)
			)
			if score < best_score:
				best_score = score
				best_x = candidate_x
		candidate_x += 4.0
	return best_x


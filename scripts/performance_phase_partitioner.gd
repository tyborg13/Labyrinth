class_name PerformancePhasePartitioner
extends RefCounted

const AMBIGUOUS_PHASE: String = "telemetry_ambiguous_overlap"

static func partition(
	intervals: Array,
	window_start_usec: int = -9223372036854775807,
	window_end_usec: int = 9223372036854775807
) -> Dictionary:
	var boundaries: Array[int] = []
	var normalized: Array[Dictionary] = []
	var excluded_ranges: Array[Dictionary] = []
	var next_interval_id: int = 0
	for interval_var: Variant in intervals:
		if typeof(interval_var) != TYPE_DICTIONARY:
			continue
		var interval: Dictionary = interval_var as Dictionary
		var phase: String = str(interval.get("phase", ""))
		var start_usec: int = maxi(int(interval.get("start_usec", 0)), window_start_usec)
		var end_usec: int = mini(int(interval.get("end_usec", 0)), window_end_usec)
		if phase.is_empty() or end_usec <= start_usec:
			continue
		if bool(interval.get("diagnostic_only", false)):
			if bool(interval.get("exclude_covered_cpu", false)):
				excluded_ranges.append({"start_usec": start_usec, "end_usec": end_usec})
				boundaries.append(start_usec)
				boundaries.append(end_usec)
			continue
		normalized.append({
			"id": next_interval_id,
			"phase": phase,
			"start_usec": start_usec,
			"end_usec": end_usec,
			"duration_usec": end_usec - start_usec,
			"priority": int(interval.get("priority", 0)),
		})
		next_interval_id += 1
		boundaries.append(start_usec)
		boundaries.append(end_usec)
	if normalized.is_empty():
		return {"total_usec": 0, "phase_usec": {}, "phase_segment_counts": {}, "excluded_usec": 0}

	# A pair crosses when the later-starting interval also ends later. Discover
	# every crossed overlap with an active end-time multiset instead of comparing
	# all pairs. For one new interval, every crossed range starts together, so only
	# the greatest prior end below its own end matters.
	var merged_ambiguous_ranges: Array[Dictionary] = _merged_ranges(_crossed_overlap_ranges(normalized))
	var merged_excluded_ranges: Array[Dictionary] = _merged_ranges(excluded_ranges)
	for range_entry: Dictionary in merged_ambiguous_ranges:
		boundaries.append(int(range_entry["start_usec"]))
		boundaries.append(int(range_entry["end_usec"]))
	for range_entry: Dictionary in merged_excluded_ranges:
		boundaries.append(int(range_entry["start_usec"]))
		boundaries.append(int(range_entry["end_usec"]))
	boundaries.sort()
	var unique_boundaries: Array[int] = []
	for boundary: int in boundaries:
		if unique_boundaries.is_empty() or unique_boundaries[-1] != boundary:
			unique_boundaries.append(boundary)

	var start_events: Dictionary = {}
	var end_events: Dictionary = {}
	for interval: Dictionary in normalized:
		_append_event(start_events, int(interval["start_usec"]), interval)
		_append_event(end_events, int(interval["end_usec"]), interval)
	var active_ids: Dictionary = {}
	var owner_heap: Array = []
	var phase_usec: Dictionary = {}
	var phase_segment_counts: Dictionary = {}
	var total_usec: int = 0
	var excluded_usec: int = 0
	var ambiguous_range_index: int = 0
	var excluded_range_index: int = 0
	for boundary_index: int in range(unique_boundaries.size() - 1):
		var segment_start: int = unique_boundaries[boundary_index]
		var segment_end: int = unique_boundaries[boundary_index + 1]
		for ending_var: Variant in end_events.get(segment_start, []):
			active_ids.erase(int((ending_var as Dictionary)["id"]))
		for starting_var: Variant in start_events.get(segment_start, []):
			var starting: Dictionary = starting_var as Dictionary
			active_ids[int(starting["id"])] = true
			_heap_push(owner_heap, starting)
		while not owner_heap.is_empty() and not active_ids.has(int((owner_heap[0] as Dictionary)["id"])):
			_heap_pop(owner_heap)
		if segment_end <= segment_start or owner_heap.is_empty():
			continue
		while excluded_range_index < merged_excluded_ranges.size() and int(merged_excluded_ranges[excluded_range_index]["end_usec"]) <= segment_start:
			excluded_range_index += 1
		if _segment_is_in_current_range(segment_start, segment_end, merged_excluded_ranges, excluded_range_index):
			excluded_usec += segment_end - segment_start
			continue
		while ambiguous_range_index < merged_ambiguous_ranges.size() and int(merged_ambiguous_ranges[ambiguous_range_index]["end_usec"]) <= segment_start:
			ambiguous_range_index += 1
		var owner_phase: String = AMBIGUOUS_PHASE
		if not _segment_is_in_current_range(segment_start, segment_end, merged_ambiguous_ranges, ambiguous_range_index):
			owner_phase = str((owner_heap[0] as Dictionary)["phase"])
		var duration_usec: int = segment_end - segment_start
		phase_usec[owner_phase] = int(phase_usec.get(owner_phase, 0)) + duration_usec
		phase_segment_counts[owner_phase] = int(phase_segment_counts.get(owner_phase, 0)) + 1
		total_usec += duration_usec
	return {
		"total_usec": total_usec,
		"phase_usec": phase_usec,
		"phase_segment_counts": phase_segment_counts,
		"excluded_usec": excluded_usec,
	}

static func _crossed_overlap_ranges(intervals: Array[Dictionary]) -> Array[Dictionary]:
	var by_start: Array[Dictionary] = intervals.duplicate()
	by_start.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_start: int = int(left["start_usec"])
		var right_start: int = int(right["start_usec"])
		if left_start != right_start:
			return left_start < right_start
		var left_end: int = int(left["end_usec"])
		var right_end: int = int(right["end_usec"])
		return left_end > right_end if left_end != right_end else int(left["id"]) < int(right["id"])
	)
	var by_end: Array[Dictionary] = intervals.duplicate()
	by_end.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_end: int = int(left["end_usec"])
		var right_end: int = int(right["end_usec"])
		return left_end < right_end if left_end != right_end else int(left["id"]) < int(right["id"])
	)
	var end_coordinates: Array[int] = []
	for interval: Dictionary in by_end:
		var end_usec: int = int(interval["end_usec"])
		if end_coordinates.is_empty() or end_coordinates[-1] != end_usec:
			end_coordinates.append(end_usec)
	var fenwick: Array[int] = []
	fenwick.resize(end_coordinates.size() + 1)
	fenwick.fill(0)
	var ranges: Array[Dictionary] = []
	var expiry_index: int = 0
	var group_start: int = 0
	while group_start < by_start.size():
		var current_start_usec: int = int(by_start[group_start]["start_usec"])
		while expiry_index < by_end.size() and int(by_end[expiry_index]["end_usec"]) <= current_start_usec:
			_fenwick_add(fenwick, _lower_bound(end_coordinates, int(by_end[expiry_index]["end_usec"])) + 1, -1)
			expiry_index += 1
		var group_end: int = group_start + 1
		while group_end < by_start.size() and int(by_start[group_end]["start_usec"]) == current_start_usec:
			group_end += 1
		for interval_index: int in range(group_start, group_end):
			var interval_end_usec: int = int(by_start[interval_index]["end_usec"])
			var lower_coordinate: int = _lower_bound(end_coordinates, interval_end_usec)
			var predecessor_count: int = _fenwick_sum(fenwick, lower_coordinate)
			if predecessor_count <= 0:
				continue
			var predecessor_coordinate: int = _fenwick_find_by_order(fenwick, predecessor_count)
			var predecessor_end_usec: int = end_coordinates[predecessor_coordinate]
			if predecessor_end_usec > current_start_usec:
				ranges.append({"start_usec": current_start_usec, "end_usec": predecessor_end_usec})
		for interval_index: int in range(group_start, group_end):
			var interval_end_usec: int = int(by_start[interval_index]["end_usec"])
			_fenwick_add(fenwick, _lower_bound(end_coordinates, interval_end_usec) + 1, 1)
		group_start = group_end
	return ranges

static func _merged_ranges(ranges: Array[Dictionary]) -> Array[Dictionary]:
	if ranges.is_empty():
		return []
	var ordered: Array[Dictionary] = ranges.duplicate(true)
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_start: int = int(left["start_usec"])
		var right_start: int = int(right["start_usec"])
		if left_start != right_start:
			return left_start < right_start
		return int(left["end_usec"]) < int(right["end_usec"])
	)
	var merged: Array[Dictionary] = []
	for range_entry: Dictionary in ordered:
		if merged.is_empty() or int(range_entry["start_usec"]) > int(merged[-1]["end_usec"]):
			merged.append(range_entry.duplicate())
			continue
		merged[-1]["end_usec"] = maxi(int(merged[-1]["end_usec"]), int(range_entry["end_usec"]))
	return merged

static func _append_event(events: Dictionary, timestamp_usec: int, interval: Dictionary) -> void:
	var entries: Array = events.get(timestamp_usec, [])
	entries.append(interval)
	events[timestamp_usec] = entries

static func _segment_is_in_current_range(segment_start: int, segment_end: int, ranges: Array[Dictionary], range_index: int) -> bool:
	if range_index < 0 or range_index >= ranges.size():
		return false
	var range_entry: Dictionary = ranges[range_index]
	return int(range_entry["start_usec"]) <= segment_start and int(range_entry["end_usec"]) >= segment_end

static func _heap_push(heap: Array, interval: Dictionary) -> void:
	heap.append(interval)
	var child_index: int = heap.size() - 1
	while child_index > 0:
		var parent_index: int = (child_index - 1) / 2
		if not _interval_is_more_specific(heap[child_index] as Dictionary, heap[parent_index] as Dictionary):
			break
		var swap: Variant = heap[parent_index]
		heap[parent_index] = heap[child_index]
		heap[child_index] = swap
		child_index = parent_index

static func _heap_pop(heap: Array) -> void:
	if heap.is_empty():
		return
	var last: Variant = heap.pop_back()
	if heap.is_empty():
		return
	heap[0] = last
	var parent_index: int = 0
	while true:
		var left_index: int = parent_index * 2 + 1
		if left_index >= heap.size():
			return
		var best_index: int = left_index
		var right_index: int = left_index + 1
		if right_index < heap.size() and _interval_is_more_specific(heap[right_index] as Dictionary, heap[left_index] as Dictionary):
			best_index = right_index
		if not _interval_is_more_specific(heap[best_index] as Dictionary, heap[parent_index] as Dictionary):
			return
		var swap: Variant = heap[parent_index]
		heap[parent_index] = heap[best_index]
		heap[best_index] = swap
		parent_index = best_index

static func _lower_bound(values: Array[int], target: int) -> int:
	var low: int = 0
	var high: int = values.size()
	while low < high:
		var middle: int = (low + high) / 2
		if values[middle] < target:
			low = middle + 1
		else:
			high = middle
	return low

static func _fenwick_add(tree: Array[int], one_based_index: int, delta: int) -> void:
	var index: int = one_based_index
	while index < tree.size():
		tree[index] += delta
		index += index & -index

static func _fenwick_sum(tree: Array[int], coordinate_count: int) -> int:
	var result: int = 0
	var index: int = coordinate_count
	while index > 0:
		result += tree[index]
		index -= index & -index
	return result

static func _fenwick_find_by_order(tree: Array[int], order: int) -> int:
	var index: int = 0
	var step: int = 1
	while step * 2 < tree.size():
		step *= 2
	var remaining: int = order
	while step > 0:
		var candidate: int = index + step
		if candidate < tree.size() and tree[candidate] < remaining:
			index = candidate
			remaining -= tree[candidate]
		step /= 2
	return index

static func _interval_is_more_specific(candidate: Dictionary, current: Dictionary) -> bool:
	var candidate_duration: int = int(candidate.get("duration_usec", 0))
	var current_duration: int = int(current.get("duration_usec", 0))
	if candidate_duration != current_duration:
		return candidate_duration < current_duration
	var candidate_priority: int = int(candidate.get("priority", 0))
	var current_priority: int = int(current.get("priority", 0))
	if candidate_priority != current_priority:
		return candidate_priority > current_priority
	var candidate_phase: String = str(candidate.get("phase", ""))
	var current_phase: String = str(current.get("phase", ""))
	if candidate_phase != current_phase:
		return candidate_phase < current_phase
	return int(candidate.get("id", 0)) < int(current.get("id", 0))

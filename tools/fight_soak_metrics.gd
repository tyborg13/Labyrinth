extends RefCounted
## Debug-only census. Never retain Node references: that would change lifetimes.

static func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	var sorted: Array = values.duplicate()
	sorted.sort()
	var total: float = 0.0
	var misses: Dictionary = {"16.67": 0, "20": 0, "33.33": 0}
	for value: float in sorted:
		total += value
		for threshold: String in misses:
			if value > float(threshold): misses[threshold] += 1
	return {"samples": sorted.size(), "median": sorted[sorted.size() / 2], "p95": sorted[int(ceil(sorted.size() * 0.95)) - 1], "p99": sorted[int(ceil(sorted.size() * 0.99)) - 1], "max": sorted[-1], "mean": total / sorted.size(), "frames_over_ms": misses}

static func identity(node: Node) -> String:
	var script: Script = node.get_script() as Script
	# Generated @Class@123 names are allocation IDs, not distinct sources.
	while script != null and script.resource_path.is_empty(): script = script.get_base_script()
	var label: String = str(node.name)
	if label.begins_with("@"): label = "<generated>"
	return "%s | %s | %s" % [script.resource_path if script != null else "<native>", node.get_class(), label]

static func histogram(nodes: Array) -> Dictionary:
	var result: Dictionary = {}
	for node: Node in nodes:
		var key: String = identity(node)
		result[key] = int(result.get(key, 0)) + 1
	return result

static func census(tree: SceneTree) -> Dictionary:
	var attached: Array = []
	var retained_ids: Dictionary = {}
	var pending: Array = [tree.root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		attached.append(node)
		pending.append_array(node.get_children(true))
		_card_layout_retained_ids(node, retained_ids)
	var orphaned: Array = []
	var retained: Array = []
	var unowned: Array = []
	for id: int in Node.get_orphan_node_ids():
		var node: Node = instance_from_id(id) as Node
		if node == null: continue
		orphaned.append(node)
		if retained_ids.has(id): retained.append(node)
		else: unowned.append(node)
	return {"tree": histogram(attached), "orphans": histogram(orphaned),
		"retained_orphans": histogram(retained), "unowned_orphans": histogram(unowned)}

static func _card_layout_retained_ids(owner: Node, ids: Dictionary) -> void:
	var script: Script = owner.get_script() as Script
	while script != null and script.resource_path != "res://scripts/card_widget.gd":
		script = script.get_base_script()
	if script == null: return
	# perf-44 intentionally owns detached summary trees at up to four fitted
	# insets. Recognize exact ownership, never names/classes or an orphan budget.
	# An evicted tree, excess cache entry or dead owner still fails the guard.
	var cache: Dictionary = owner.get("_summary_layout_cache")
	if cache.size() > int(script.get_script_constant_map()["SUMMARY_LAYOUT_CACHE_CAPACITY"]): return
	var pending: Array = []
	for entry: Dictionary in cache.values(): pending.append_array(entry["children"])
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if not is_instance_valid(node) or node.is_inside_tree() or node.is_queued_for_deletion(): continue
		ids[node.get_instance_id()] = true
		pending.append_array(node.get_children(true))

static func histogram_count(values: Dictionary) -> int:
	var count: int = 0
	for value: int in values.values(): count += value
	return count

static func difference(before: Dictionary, after: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in before.keys() + after.keys():
		var delta: int = int(after.get(key, 0)) - int(before.get(key, 0))
		if delta != 0: result[key] = delta
	return result

static func counts() -> Dictionary:
	return {"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), "objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)), "resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)), "static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)), "process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0}

# Count bounds, never timing bounds. Warmup absorbs the finite card proxy pools.
static func plateau_errors(rounds: Array, orphan_bound: int = 2, node_bound: int = 128, object_bound: int = 256) -> Array[String]:
	var errors: Array[String]
	if rounds.size() < 20: errors.append("At least 20 rounds required")
	for row: Dictionary in rounds:
		var unowned: int = int(row.get("unowned_orphans", row["orphans"]))
		if unowned > orphan_bound:
			errors.append("Round %d has %d unowned orphans (bound %d)" % [row["round"], unowned, orphan_bound])
	if rounds.size() >= 20:
		var warm: Array = rounds.slice(rounds.size() / 2)
		for metric: String in ["nodes", "objects"]:
			var low: int = int(warm[0][metric])
			var high: int = low
			for row: Dictionary in warm:
				low = mini(low, int(row[metric]))
				high = maxi(high, int(row[metric]))
			var bound: int = node_bound if metric == "nodes" else object_bound
			var middle: int = warm.size() / 2
			var early_floor: int = int(warm[0][metric])
			var late_floor: int = int(warm[middle][metric])
			for row: Dictionary in warm.slice(0, middle): early_floor = mini(early_floor, int(row[metric]))
			for row: Dictionary in warm.slice(middle): late_floor = mini(late_floor, int(row[metric]))
			var drift_bound: int = 16 if metric == "nodes" else 32
			if late_floor - early_floor > drift_bound: errors.append("Late %s floor grew by %d (bound %d)" % [metric, late_floor - early_floor, drift_bound])
			if high - low > bound: errors.append("Late %s range %d exceeds plateau bound %d" % [metric, high - low, bound])
	return errors

# A full-hand replay has different live rail/card/feedback shapes at each turn.
# Compare the same fixture turn across late bouts, rather than weakening the
# count bound to cover that legitimate periodic envelope. Keep every original
# round's orphan count, and never mutate the report's actual measurements.
static func replay_plateau_errors(rounds: Array, node_growth_bound: int = 16, object_growth_bound: int = 32) -> Array[String]:
	var normalized: Array[Dictionary]
	var first_by_turn: Dictionary = {}
	var repeated: int = 0
	for index: int in range(rounds.size()):
		var row: Dictionary = rounds[index]
		var sample: Dictionary = row.duplicate(false)
		sample["nodes"] = 0
		sample["objects"] = 0
		if index >= rounds.size() / 2:
			var turn: int = int(row["turn"])
			if not first_by_turn.has(turn): first_by_turn[turn] = row
			else: repeated += 1
			sample["nodes"] = int(row["nodes"]) - int(first_by_turn[turn]["nodes"])
			sample["objects"] = int(row["objects"]) - int(first_by_turn[turn]["objects"])
		normalized.append(sample)
	var errors: Array[String] = plateau_errors(normalized, 2, node_growth_bound, object_growth_bound)
	if repeated == 0: errors.append("Replay soak needs repeated late fixture turns")
	return errors

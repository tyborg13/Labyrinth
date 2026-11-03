extends SceneTree

## Count retained packed buffers and their keys, with both modes exercised at
## capacity and across a mode switch. Container/compiled-operand overhead is
## deliberately outside this payload budget; no guessed allocator sizes.
const Rig = preload("res://assets/units/chainbound_gaoler_cutout/rig.gd")
const EXPECTED_CAPACITY: int = 16
const MAX_VIEW_BYTES: int = 4 * 1024 * 1024
const KEY_COMPONENT_BYTES: int = 4
const MUTATION_PHASE_STEP: float = 0.001

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var rows: Array[Dictionary]
	var errors: Array[String]
	for view: String in ["front", "rear"]:
		var rig := Rig.new()
		rig.facing = view
		root.add_child(rig)
		assert(rig.load_rig())
		rig.apply_pose("move", 0.26)
		var motion_bytes: int = 0
		var idle_bytes: int = 0
		var mixed_bytes: int = 0
		for node: Node in rig.get_children():
			if not node.has_meta("stable_skin"): continue
			if node.get_meta("stable_source").has("_stable_definition"): errors.append(view + ": obsolete definition hash")
			var skin: RefCounted = node.get_meta("stable_skin")
			var capacity: int = skin.CACHE_CAPACITY
			if capacity != EXPECTED_CAPACITY: errors.append(view + ": capacity is " + str(capacity))
			var base: PackedFloat64Array = skin.cache.keys()[0]
			skin.cache.clear()
			skin.idle_cache.clear()
			skin.cache_order.clear()
			var poses: Array[PackedFloat64Array]
			for index: int in range(capacity + 1):
				var pose: PackedFloat64Array = base.duplicate()
				pose[4] += index * MUTATION_PHASE_STEP
				poses.append(pose)
			for index: int in range(capacity): skin.submit(poses[index])
			motion_bytes += _payload(skin)
			var before: int = skin.hits
			skin.submit(poses[0])
			if skin.hits != before + 1: errors.append(view + ": motion hit lost")
			skin.submit(poses[capacity])
			if not skin.cache.has(poses[0]) or skin.cache.has(poses[1]): errors.append(view + ": motion LRU eviction")
			var original: PackedVector2Array = node.get_meta("stable_polygon")
			for index: int in range(capacity):
				skin.idle(original, Vector2(index, 0))
			idle_bytes += _payload(skin)
			before = skin.hits
			skin.idle(original, Vector2.ZERO)
			if skin.hits != before + 1: errors.append(view + ": idle hit lost")
			skin.idle(original, Vector2(capacity, 0))
			if not skin.idle_cache.has(Vector2.ZERO) or skin.idle_cache.has(Vector2(1, 0)): errors.append(view + ": idle LRU eviction")
			# Mixed occupancy must have the same total bound, both modes live.
			for index: int in range(capacity / 2): skin.submit(poses[index])
			mixed_bytes += _payload(skin)
			# Refresh an idle entry, then motion inserts must evict older keys
			# from either mode, retaining the recently touched idle payload.
			skin.idle(original, Vector2.ZERO)
			for index: int in range(capacity / 2, capacity): skin.submit(poses[index])
			if not skin.idle_cache.has(Vector2.ZERO) or skin.cache.has(poses[0]): errors.append(view + ": cross-mode LRU eviction")
			if skin.cache.is_empty() or skin.idle_cache.is_empty(): errors.append(view + ": mixed coverage missing")
			if skin.cache.size() + skin.idle_cache.size() != capacity: errors.append(view + ": combined capacity")
			# Rebuilding either mode at full capacity must also evict old keys.
			if skin.cache_order.size() != capacity: errors.append(view + ": stale LRU key")
		var row: Dictionary = {"view": view, "motion_full_bytes": motion_bytes, "idle_full_bytes": idle_bytes,
			"mixed_full_bytes": mixed_bytes, "maximum_bytes": MAX_VIEW_BYTES}
		if maxi(motion_bytes, maxi(idle_bytes, mixed_bytes)) > MAX_VIEW_BYTES: errors.append("Cache payload: " + str(row))
		rows.append(row)
		rig.free()
	var report: Dictionary = {"ok": errors.is_empty(), "views": rows, "errors": errors}
	if args.has("--output"): FileAccess.open(args[args.find("--output") + 1], FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("RR50 CACHE PAYLOAD: ", "PASS" if errors.is_empty() else "FAIL", " ", JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)

func _payload(skin: RefCounted) -> int:
	var bytes: int = 0
	for pose: PackedFloat64Array in skin.cache:
		bytes += pose.to_byte_array().size() + skin.cache[pose].to_byte_array().size()
	for offset: Vector2 in skin.idle_cache:
		bytes += 2 * KEY_COMPONENT_BYTES + skin.idle_cache[offset].to_byte_array().size()
	return bytes

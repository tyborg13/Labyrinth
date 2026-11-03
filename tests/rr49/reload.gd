extends SceneTree

const Current = preload("res://assets/units/chainbound_gaoler_cutout/rig.gd")
const Legacy = preload("res://experiments/cutouts/chainbound_gaoler/rr49/fixtures/submission_2bd5ea39a/legacy_production.gd")
const PHASE: float = 0.26

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	await process_frame
	var rows: Array[Dictionary]
	var errors: Array[String]
	for adapter: Script in [Current, Legacy]:
		for view: String in ["front", "rear"]:
			var rig: Node2D = adapter.new()
			rig.facing = view
			root.add_child(rig)
			assert(rig.load_rig())
			rig.apply_pose("move", PHASE)
			var before: Dictionary = _buffers(rig)
			assert(rig.load_rig())
			rig.apply_pose("move", PHASE)
			var after: Dictionary = _buffers(rig)
			var changed: Array[String]
			for name: String in before:
				if before[name] != after[name]: changed.append(name)
			var row: Dictionary = {"legacy": adapter == Legacy, "view": view, "helpers": rig.cap_bones.size(), "changed": changed}
			if adapter == Current:
				if rig.cap_bones.size() != 5 or not changed.is_empty(): errors.append(str(row))
				# A real facing rebuild must still replace all helper bindings.
				rig.facing = "rear" if view == "front" else "front"
				assert(rig.load_rig())
				rig.facing = view
				assert(rig.load_rig())
				rig.apply_pose("move", PHASE)
				if rig.cap_bones.size() != 5 or _buffers(rig) != before: errors.append("Facing rebuild: " + str(row))
			else:
				if rig.cap_bones.size() != 0 or changed.size() != (6 if view == "front" else 5): errors.append("Legacy reload mutation escaped: " + str(row))
			rows.append(row)
			rig.free()
	print("RR49 RELOAD: ", JSON.stringify({"errors": errors, "rows": rows}))
	quit(0 if errors.is_empty() else 1)

func _buffers(rig: Node2D) -> Dictionary:
	var result: Dictionary = {}
	for node: Polygon2D in rig.find_children("*", "Polygon2D", true, false):
		var sha := HashingContext.new()
		sha.start(HashingContext.HASH_SHA256)
		sha.update(node.polygon.to_byte_array())
		result[str(rig.get_path_to(node))] = sha.finish().hex_encode()
	return result

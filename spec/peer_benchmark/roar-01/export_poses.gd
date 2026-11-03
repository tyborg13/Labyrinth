extends SceneTree

# Actual production transforms, including contact solvers, for CPU diagnostics.
const Proof = preload("res://spec/peer_benchmark/roar-01/proof_data.gd")

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

static func packed(value: Transform2D) -> Array:
	return [value.x.x, value.x.y, value.y.x, value.y.y, value.origin.x, value.origin.y]

func _run() -> void:
	var cases: Array = []
	var cases_path: String = Proof.value("cases", "")
	if not cases_path.is_empty(): cases = JSON.parse_string(FileAccess.get_file_as_string(cases_path))
	var phases: Array = Proof.PHASES.duplicate()
	if Proof.value("stress", "0") == "1": phases.append_array(Proof.STRESS_PHASES)
	var phase_override: String = Proof.value("phases", "")
	if not phase_override.is_empty(): phases = JSON.parse_string(phase_override)
	var sources: Dictionary = {}
	for id: String in Proof.IDS:
		var source: String = "res://scripts/%s_cutout/motion.gd" % id
		sources[source] = FileAccess.get_sha256(source)
	var proof_source: String = "res://spec/peer_benchmark/roar-01/proof_data.gd"
	sources[proof_source] = FileAccess.get_sha256(proof_source)
	var records: Array[Dictionary]
	for id: String in Proof.IDS:
		var rig: Node2D = load("res://scripts/%s_cutout/rig.gd" % id).new()
		rig.set("facing", "front")
		root.add_child(rig)
		if not rig.call("load_rig"):
			push_error("Cannot load " + id)
			quit(1)
			return
		for phase: float in phases:
			rig.call("apply_pose", "roar", phase)
			records.append(_capture(rig, id, "roar", phase))
		for baseline: Array in Proof.BASELINES[id]:
			rig.call("apply_pose", baseline[0], float(baseline[1]))
			records.append(_capture(rig, id, str(baseline[0]), float(baseline[1])))
		for test_case: Dictionary in cases:
			if test_case["dragon"] != id: continue
			var motion: Script = load("res://scripts/%s_cutout/motion.gd" % id)
			for phase: float in phases:
				var pose: Dictionary = motion.sample_pose("roar", phase, rig.get("layout"), "front", 0.0, false, test_case["clamps"]) if id == "iskaldra" else motion.sample_pose("roar", phase, rig.get("layout"), "front", false, test_case["clamps"])
				rig.call("_apply_sampled_pose", pose, true)
				var record: Dictionary = _capture(rig, id, "roar", phase)
				record["case"] = test_case["name"]
				record["clamps"] = test_case["clamps"]
				records.append(record)
		rig.free()
	var path: String = Proof.value("output", "/private/tmp/labyrinth_codex/roar-01/feedback1/poses.json")
	for source: String in sources:
		if FileAccess.get_sha256(source) != sources[source]:
			push_error("Proof source changed during export: " + source)
			quit(1)
			return
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"baselines": Proof.BASELINES, "sources": sources, "records": records}, "\t"))
	file.close()
	print("ROAR POSE EXPORT: PASS ", records.size(), " samples -> ", path)
	quit()

func _capture(rig: Node2D, id: String, clip: String, phase: float) -> Dictionary:
	var bones: Dictionary = {}
	for name: String in rig.get("bones"):
		bones[name] = {"global": packed(rig.global_transform.affine_inverse() * (rig.get("bones")[name] as Node2D).global_transform)}
	var sprites: Array[Dictionary]
	_collect(rig, rig, sprites)
	return {"dragon": id, "clip": clip, "phase": phase, "bones": bones, "sprites": sprites}

func _collect(rig: Node2D, node: Node, sprites: Array[Dictionary]) -> void:
	if node is Sprite2D:
		var sprite := node as Sprite2D
		sprites.append({"name": str(node.name), "transform": packed(rig.global_transform.affine_inverse() * sprite.global_transform), "z_index": sprite.z_index})
	for child: Node in node.get_children(): _collect(rig, child, sprites)

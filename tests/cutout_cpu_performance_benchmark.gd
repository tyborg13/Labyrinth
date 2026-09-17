extends SceneTree
## CPU construction/pose measurements; not a proxy for native GPU frame pacing.
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const GuardianRenderer = preload("res://scripts/guardian_cutout/renderer.gd")
const ACTORS = ["crawler", "stone_warden", "acolyte", "bile_bloomer", "chainbound_gaoler", "cinder_droplet", "cinder_ooze", "frostglass_lancer", "grave_surgeon", "harrier", "iskaldra", "lightning_wisp", "noctyrax", "tharokh", "vaeloryx", "veilbound_acolyte", "vyraketh", "zekarion"]
const REPETITIONS: int = 5
var _errors: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	await process_frame
	await process_frame
	var poses: Dictionary = {}
	var actors: Array = ACTORS.duplicate()
	actors.append_array(GuardianRenderer.ACTOR_IDS)
	actors.append("protagonist")
	for actor: String in actors:
		var rigs: Array[Node2D] = _create_rigs([actor])
		var phases: Dictionary = {}
		for clip: String in ["idle", "walk"]:
			var samples: Array[float] = []
			for rig: Node2D in rigs:
				for frame: int in range(96):
					var started: int = Time.get_ticks_usec()
					rig.call("apply_pose", clip, float(frame % 48)/48.0)
					samples.append(float(Time.get_ticks_usec()-started))
			phases[clip] = _stats(samples)
		poses[actor] = phases
		for rig: Node2D in rigs: rig.free()
	var cases: Dictionary = {
		"early_melee":["crawler", "crawler", "stone_warden"],
		"mixed_casters":["acolyte", "lightning_wisp", "veilbound_acolyte", "grave_surgeon"],
		"split_family":["cinder_ooze", "cinder_droplet", "cinder_droplet", "cinder_droplet"],
		"guardian_helpers":["gallows_roc", "roc_fledgling", "roc_fledgling"],
		"dragon_support":["noctyrax", "stone_warden", "acolyte"],
		"late_specialists":["chainbound_gaoler", "harrier", "frostglass_lancer", "bile_bloomer"],
	}
	var construction: Dictionary = {}
	for case_id: String in cases:
		var samples: Array[float] = []
		var memory_bytes: Array[float] = []
		for repetition: int in range(REPETITIONS):
			var before: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
			var started: int = Time.get_ticks_usec()
			var rigs: Array[Node2D] = _create_rigs(cases[case_id])
			samples.append(float(Time.get_ticks_usec()-started))
			memory_bytes.append(float(Performance.get_monitor(Performance.MEMORY_STATIC))-before)
			for rig: Node2D in rigs: rig.free()
		construction[case_id] = {"create_usec":_stats(samples), "live_data_bytes":_stats(memory_bytes)}
	await process_frame
	await process_frame
	_expect(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "CPU benchmark leaves no orphan nodes")
	var report: Dictionary = {"schema_version":1, "workload_id":"cutout_cpu_all_families_six_groups_v1", "case_ids":cases.keys(), "actor_ids":actors, "repetitions":REPETITIONS, "measurement_class":"synchronous_cpu_usec", "poses":poses, "construction":construction, "semantic_errors":_errors}
	print("CUTOUT CPU PERF RESULT: " + JSON.stringify(report))
	quit(0 if _errors.is_empty() else 1)

func _create_rigs(actors: Array) -> Array[Node2D]:
	var rigs: Array[Node2D] = []
	for actor: String in actors:
		var family: String = "guardian" if GuardianRenderer.handles(actor) else actor
		var script: Script = load("res://scripts/%s_cutout/rig.gd" % family)
		for facing: String in ["front", "rear"]:
			var rig: Node2D = script.new()
			rig.set("facing", facing)
			if family == "guardian": rig.set("character_id", actor)
			root.add_child(rig)
			_expect(rig.call("load_rig"), actor + " loads " + facing)
			rigs.append(rig)
	return rigs

func _stats(samples: Array[float]) -> Dictionary:
	var sorted: Array[float] = samples.duplicate()
	sorted.sort()
	return {"median":sorted[sorted.size()/2], "p95":sorted[mini(sorted.size()-1, int(ceil(sorted.size()*0.95))-1)], "max":sorted.back(), "samples":samples}

func _expect(condition: bool, message: String) -> void:
	if not condition: _errors.append(message)

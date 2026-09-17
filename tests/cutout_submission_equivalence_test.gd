extends "res://tests/combat_animation_matrix_benchmark.gd"
## Compare selective presentation updates with forcing the complete roster path.
func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	var optimized: Control = CombatBoardView.new()
	var reference: Control = CombatBoardView.new()
	optimized.process_mode = Node.PROCESS_MODE_DISABLED
	reference.process_mode = Node.PROCESS_MODE_DISABLED
	# Layout and render snapshots may be submitted before a view is attached.
	# The first identical attached submission must still create/present actors.
	var detached_state: Dictionary = _matrix_state(["crawler", "warden", "acolyte"])
	var detached_presentation: Dictionary = _matrix_presentation(detached_state, "walk", 23)
	optimized.call("set_combat_state", detached_state, [], [], Vector2i(-1,-1), "", "", {}, {}, detached_presentation)
	root.add_child(optimized)
	root.add_child(reference)
	_compare_submission(optimized, reference, detached_state, detached_presentation)
	# Existing pools can likewise become stale while removed from the tree.
	root.remove_child(optimized)
	detached_state["player"]["pos"] = Vector2i(6, 1)
	detached_presentation = _matrix_presentation(detached_state, "reduced_motion", 0)
	optimized.call("set_combat_state", detached_state, [], [], Vector2i(-1,-1), "", "", {}, {}, detached_presentation)
	root.add_child(optimized)
	_compare_submission(optimized, reference, detached_state, detached_presentation)
	var cases: Array = [
		["crawler", "warden", "acolyte"],
		["cinder_ooze", "cinder_droplet", "cinder_droplet"],
		["gallows_roc", "roc_fledgling", "iskaldra"],
		["chainbound_gaoler", "harrier", "frostglass_lancer", "bile_bloomer"],
	]
	for actors: Array in cases:
		var state: Dictionary = _matrix_state(actors)
		for phase: String in ["idle", "walk", "attack", "idle", "reduced_motion", "walk"]:
			for frame: int in [0, 23, 47, 72]:
				var presentation: Dictionary = _matrix_presentation(state, phase, frame)
				_compare_submission(optimized, reference, state, presentation)
		var hidden: Dictionary = _matrix_presentation(state, "walk", 10)
		hidden["visible_enemy_ids"] = [1]
		_compare_submission(optimized, reference, state, hidden)
		# An in-place state commit must refresh actors despite the same Dictionary.
		state["player"]["pos"] = Vector2i(6, 1)
		state["enemies"][0]["pos"] = Vector2i(2, 2)
		_compare_submission(optimized, reference, state, _matrix_presentation(state, "idle", 0))
		var death: Dictionary = state["enemies"][0].duplicate(true)
		death["death_animation"] = true
		state["enemies"][0]["hp"] = 0
		var dying: Dictionary = {"death_animation_units":[death]}
		_compare_submission(optimized, reference, state, dying)
		_compare_submission(optimized, reference, state, {})
		await process_frame
	optimized.free()
	reference.free()
	for error: String in _errors: push_error(error)
	print("CUTOUT SUBMISSION EQUIVALENCE: " + ("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)

func _compare_submission(optimized: Control, reference: Control, state: Dictionary, presentation: Dictionary) -> void:
	reference.set("_submission_cache_initialized", false)
	for board: Control in [optimized, reference]:
		board.call("set_combat_state", state, [], [], Vector2i(-1,-1), "", "", {}, {}, presentation)
	for unit: Dictionary in state["enemies"]:
		var left: Node = optimized.call("unit_cutout_renderer", unit)
		var right: Node = reference.call("unit_cutout_renderer", unit)
		_expect((left == null) == (right == null), str(unit["type"]) + " matches renderer lifetime")
		if left == null or right == null: continue
		var a: Dictionary = left.call("snapshot")
		var b: Dictionary = right.call("snapshot")
		a.erase("texture_id")
		b.erase("texture_id")
		_expect(a == b, str(unit["type"]) + " preserves clip, facing, activity and reduced motion")
		_expect(_visible_pose(left) == _visible_pose(right), str(unit["type"]) + " preserves every bone pose")

extends "res://tools/atk13/capture.gd"
## Inspect the real card-hover uncertainty on natural counterfactual saves.
## Headless semantics only; no pixels or changes to the information filter.
const PROOF_SHUTDOWN_DRAIN_SECONDS: float = 0.5
func _run() -> void:
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(_arg("--cases")))
	Store.set_storage_path("user://area01-force-profile.json")
	Store.set_run_storage_path("user://area01-force-run.save")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	root.size = SIZE
	root.content_scale_size = SIZE
	canvas = SubViewport.new()
	canvas.size = SIZE
	root.add_child(canvas)
	native_scene = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(native_scene)
	for frame: int in range(PROOF_BOOT_FRAMES): await process_frame
	var output: Array[Dictionary]
	for case: Dictionary in cases:
		var run: Dictionary = Store._load_run_dictionary(str(case["repro"]).path_join("run.save"))
		var state: Dictionary = run["combat_state"]
		var index: int = -1
		for i: int in range(state["enemies"].size()):
			if str(state["enemies"][i]["type"]) == str(case["source"]): index = i; break
		_check(index >= 0, "source exists in natural reproduction")
		var enemy: Dictionary = state["enemies"][index]
		var card_index: int = (state["deck"]["hand"] as Array).size()
		state["deck"]["hand"].append(str(case["card"]))
		state["cards_played_this_turn"] = 0
		native_scene.call("_load_run_state",run)
		native_scene.call("_close_dialogue")
		for frame: int in range(PROOF_LAYOUT_FRAMES): await process_frame
		var preview: Dictionary = native_scene.call("_card_preview_for_index", card_index)
		_check(bool(preview.get("playable",false)) and not bool(preview.get("complete",true)), "real card targets in the saved fight")
		await native_scene.call("_begin_card_preview", card_index, preview)
		var engine: RefCounted = native_scene.get("_combat_engine")
		var target := Vector2i(-1,-1)
		for tile: Vector2i in engine._enemy_footprint_tiles(enemy):
			if (native_scene.get("_pending_target_tiles") as Array).has(tile): target = tile; break
		_check(target.x >= 0, "source is a legal real-card target")
		native_scene.call("_on_board_tile_hovered",target)
		var summary: Dictionary = native_scene.call("_pass_preview_summary")
		var source: Dictionary = native_scene.call("_pass_preview_source_state")
		var predicted: Vector2i = source["enemies"][engine._enemy_index_for_id(source,int(enemy["id"]))]["pos"]
		var parts: PackedStringArray = str(case["offset"]).trim_prefix("(").trim_suffix(")").split(",")
		var actual: Vector2i = Vector2i(enemy["pos"]) + Vector2i(int(parts[0]),int(parts[1]))
		var flags: Dictionary = {}
		for key: String in ["unseen_ground_crossed","unrevealed_before_player","umbra_unknown_before_player","forecast_limit_reached","terminal_unknown"]: flags[key] = bool(summary.get(key,false))
		var disclosed: bool = flags.values().any(func(value: bool) -> bool: return value)
		_check(predicted == actual or disclosed, "source disagreement is disclosed by the existing card-hover forecast")
		var impact: Dictionary = summary.get("relative_red_areas",{}).get("enemy_%d" % int(enemy["id"]),{})
		output.append({"source":case["source"],"intent":case["intent"],"card":case["card"],"point":case["point"],"predicted":predicted,"actual":actual,"flags":flags,"disclosed":disclosed,"repro":case["repro"],
			"card_forecast_impact":impact.get("anchor"),"raw_action_actual_impact":case.get("actual_impact_anchor"),"end_to_end_mismatch_in_action_matrix":case.get("end_to_end_mismatch",false)})
		await native_scene.call("_on_cancel_requested",false)
	var file := FileAccess.open(_arg("--out"),FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"  ")+"\n")
	file.close()
	for failure: String in failures: print("FAIL: "+failure)
	print("AREA01 FORCE DISCLOSURE %s cases=%d" % ["PASS" if failures.is_empty() else "FAIL",output.size()])
	await create_timer(PROOF_SHUTDOWN_DRAIN_SECONDS).timeout
	canvas.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

extends SceneTree
## atk-04 diagnostic (not a test): resume a real audit save headlessly, build the
## PASS forecast for one destination (or PASS), and print every step's tiles,
## marking those outside the decision-time sight ("!" / UNSEEN), then the
## summary's uncertainty flags. Usage (after --): --save-dir <repro dir> [--tile x,y]
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const INVALID := Vector2i(-1, -1)

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _arg(name: String, fallback: String = "") -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = args.find(name)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else fallback

func _run() -> void:
	var save_dir: String = _arg("--save-dir")
	Store.set_storage_path("user://progression.json")
	Store.set_run_storage_path("user://current_run.save")
	DirAccess.copy_absolute(save_dir.path_join("progression.json"), ProjectSettings.globalize_path("user://progression.json"))
	DirAccess.copy_absolute(save_dir.path_join("run.save"), ProjectSettings.globalize_path("user://current_run.save"))
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	Settings.save_settings(settings)
	root.set_meta("labyrinth_resume_saved_run", true)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	for frame: int in range(90): await process_frame
	await create_timer(1.0).timeout
	var engine: RefCounted = scene.get("_combat_engine")
	var committed: Dictionary = scene.get("_combat_state")
	var visible: Dictionary = engine.umbra_visible_tile_lookup(committed)
	print("hero ", committed["player"]["pos"], " limited ", scene.call("_preview_umbra_is_limited", committed), " visible ", visible.size())
	var tile_arg: String = _arg("--tile", "pass")
	var tile: Vector2i = INVALID
	if tile_arg != "pass":
		tile = Vector2i(int(tile_arg.get_slice(",", 0)), int(tile_arg.get_slice(",", 1)))
		scene.call("_begin_player_movement_selection")
	scene.set("_hovered_board_tile", tile)
	var source: Dictionary = scene.call("_pass_preview_source_state_for_tile", tile)
	print("source hero ", source["player"]["pos"], " keys ", source.keys().filter(func(k): return str(k).begins_with("_")))
	print("last move ", source.get("last_player_movement", {}))
	var scheduled: Dictionary = engine.finish_player_activation(source)
	var Unseen: GDScript = preload("res://scripts/pass_forecast_unseen_ground.gd")
	print("prefix crossed ", source.get(Unseen.CROSSED_KEY, false), " turn-end moved ", Unseen.moved_onto_unseen(visible, source, scheduled))
	var cursor: Dictionary = engine.begin_revealed_enemy_actions_preview(scheduled, true)
	while not bool(cursor.get("complete", false)):
		var before_state: Dictionary = (cursor["state"] as Dictionary).duplicate(true)
		var step_count: int = (cursor.get("steps", []) as Array).size()
		var was: bool = bool(cursor.get("unseen_ground_crossed", false))
		engine.advance_revealed_enemy_actions_preview(cursor)
		if not was and bool(cursor.get("unseen_ground_crossed", false)):
			var fresh: Array = (cursor["steps"] as Array).slice(step_count)
			print("UNSEEN at activation: moved=%s steps=%s" % [Unseen.moved_onto_unseen(visible, before_state, cursor["state"]), Unseen._steps_cross(visible, before_state, cursor["state"], fresh)])
	for step: Dictionary in cursor["steps"]:
		var info: Array = []
		for key: Variant in step:
			var value: Variant = step[key]
			if value is Vector2i: info.append("%s=%s%s" % [key, value, "" if visible.has(value) else "(UNSEEN)"])
			elif value is Array and not (value as Array).is_empty() and (value as Array)[0] is Vector2i:
				var marks: Array = []
				for t: Vector2i in value: marks.append("%s%s" % [t, "" if visible.has(t) else "!"])
				info.append("%s=%s" % [key, marks])
		print("STEP kind=%s actor=%s type=%s %s keys=%s" % [step.get("kind", ""), step.get("actor_key", ""), step.get("action_type", ""), " ".join(info), step.keys()])
	var after: Dictionary = cursor["state"]
	print("after hero ", after["player"]["pos"], " hp ", after["player"]["hp"])
	for enemy: Dictionary in after.get("enemies", []):
		print("  enemy ", enemy["id"], " ", enemy["type"], " ", enemy["pos"], " hp ", enemy["hp"], "" if visible.has(enemy["pos"]) else " (UNSEEN)")
	var summary: Dictionary = scene.call("_pass_preview_summary")
	print("SUMMARY hp ", summary.get("hp_loss"), " tone ", summary.get("tone"), " umbra ", summary.get("umbra_unknown_before_player"), " unrevealed ", summary.get("unrevealed_before_player"), " unseen ", summary.get("unseen_ground_crossed"))
	quit(0)

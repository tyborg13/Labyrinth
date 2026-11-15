extends SceneTree
## atk-06 diagnostic (not a test): resume a real audit save in the production
## scene and print the red tiles the board draws at rest (and with --tile hovered
## in movement mode), then the forecast for staying (or for walking to --tile),
## activation by activation: the foe's own plan at that moment and what the
## activation did to the hero. Usage (after --): --save-dir <repro dir> [--tile x,y]
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Audit = preload("res://tools/atk06/audit.gd")
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
	var board: Control = scene.get("board_view")
	var committed: Dictionary = scene.get("_combat_state")
	print("hero %s hp %d block %d turn %d rule %s" % [committed["player"]["pos"], committed["player"]["hp"], committed["player"].get("block", 0), committed.get("turn", 0), committed.get("battlefield_rule", {}).get("rule", "")])
	for enemy: Dictionary in committed.get("enemies", []):
		if int(enemy.get("hp", 0)) > 0: print("  enemy_%d %s at %s hp %d visible %s intent %s %s" % [enemy["id"], enemy["type"], enemy["pos"], enemy["hp"], engine.is_enemy_visible_to_player(committed, enemy), enemy.get("intent", {}).get("id", ""), JSON.stringify(enemy.get("intent", {}).get("actions", []))])
	scene.set("_hovered_board_tile", INVALID)
	scene.call("_refresh_stage_view")
	print("REST red ", _red(board))
	for threat: Dictionary in (board.get("presentation") as Dictionary).get("threats_at_rest", {}).get("threats", []):
		print("  threat %s tiles %s attacker %s" % [threat.get("key", ""), threat.get("tiles", []), threat.get("attacker_tile", "")])
	for badge: Dictionary in (board.get("presentation") as Dictionary).get("threats_at_rest", {}).get("badges", []):
		print("  badge %s icon %s acting %s cancelled %s danger %s order %s" % [badge["key"], badge.get("icon", ""), badge.get("acting", false), badge.get("cancelled", false), badge.get("danger", false), badge.get("order", "")])
	var tile_arg: String = _arg("--tile", "pass")
	var tile: Vector2i = INVALID
	if tile_arg != "pass":
		tile = Vector2i(int(tile_arg.get_slice(",", 0)), int(tile_arg.get_slice(",", 1)))
		scene.call("_begin_player_movement_selection")
		scene.set("_hovered_board_tile", tile)
		scene.call("_refresh_stage_view")
		print("HOVER %s red %s" % [tile, _red(board)])
		for threat: Dictionary in (board.get("presentation") as Dictionary).get("threats_at_rest", {}).get("threats", []):
			print("  threat %s tiles %s" % [threat.get("key", ""), threat.get("tiles", [])])
		for badge: Dictionary in (board.get("presentation") as Dictionary).get("threats_at_rest", {}).get("badges", []):
			print("  hover badge %s acting %s cancelled %s danger %s" % [badge["key"], badge.get("acting", false), badge.get("cancelled", false), badge.get("danger", false)])
		var preview: Dictionary = scene.call("_enemy_intent_preview_state", scene.call("_board_display_state"))
		var known: Dictionary = scene.call("_surface_preview_information_state", preview)
		for index: int in range((known.get("enemies", []) as Array).size()):
			var enemy: Dictionary = known["enemies"][index]
			if int(enemy.get("hp", 0)) <= 0: continue
			print("  known enemy_%d visible_here %s committed_plan %s" % [enemy["id"], engine.is_enemy_visible_to_player(known, enemy), engine.committed_enemy_threat_tiles(known, index).get("projected_attack", [])])
		print("  visible at commit (5,4)? ", board.call("_board_tile_is_visible_to_player", tile))
	var source: Dictionary = scene.call("_pass_preview_source_state_for_tile", tile)
	var plans: RefCounted = preload("res://scripts/combat_engine.gd").new()
	var scheduled: Dictionary = engine.finish_player_activation(source)
	print("FORECAST from hero %s (turn end -> %s hp %d)" % [source["player"]["pos"], scheduled["player"]["pos"], scheduled["player"]["hp"]])
	var cursor: Dictionary = engine.begin_revealed_enemy_actions_preview(scheduled, true)
	while not bool(cursor.get("complete", false)):
		var state: Dictionary = cursor["state"]
		var entry: Dictionary = engine._pop_next_actor(state.duplicate(true)).get("entry", {})
		var label: String = "turn_start" if entry.is_empty() or str(entry.get("kind", "")) == "player" else "%s_%d" % [entry.get("kind", ""), int(entry.get("enemy_id", -1))]
		var hero: Dictionary = state["player"].duplicate()
		var plan_text: String = ""
		if str(entry.get("kind", "")) == "enemy":
			var index: int = engine._enemy_index_for_id(state, int(entry["enemy_id"]))
			if index >= 0:
				var enemy: Dictionary = state["enemies"][index]
				var threat: Dictionary = plans.enemy_threat_tiles(state, index)
				plan_text = "%s at %s intent %s plan_attack %s dest %s covers_hero %s" % [enemy["type"], enemy["pos"], enemy.get("intent", {}).get("id", ""), threat.get("projected_attack", []), threat.get("projected_destination", ""), (threat.get("projected_attack", []) as Array).has(hero["pos"])]
		var step_count: int = (cursor.get("steps", []) as Array).size()
		engine.advance_revealed_enemy_actions_preview(cursor)
		var after: Dictionary = (cursor["state"] as Dictionary)["player"]
		print("  %s: %s | hero %s->%s hp %d->%d block %d->%d" % [label, plan_text, hero["pos"], after["pos"], hero["hp"], after["hp"], hero.get("block", 0), after.get("block", 0)])
		for step: Variant in (cursor.get("steps", []) as Array).slice(step_count):
			if not step is Dictionary: continue
			var losses: Array = (step.get("target_losses", []) as Array).filter(func(loss: Dictionary) -> bool: return str(loss.get("key", "")) == "player")
			var fields: Array = []
			for key: String in ["action_type", "target_tile", "tiles", "affected_tiles", "path", "to", "from"]:
				if step.has(key): fields.append("%s=%s" % [key, step[key]])
			print("      step %s %s %s%s" % [step.get("kind", ""), step.get("actor_key", ""), " ".join(fields), " HERO LOSS %s" % [losses] if not losses.is_empty() else ""])
	var summary: Dictionary = scene.call("_pass_preview_summary")
	print("SUMMARY hp %s block %s defeat %s tone %s" % [summary.get("hp_loss"), summary.get("block_loss"), summary.get("defeat"), summary.get("tone")])
	quit(0)

func _red(board: Control) -> Array:
	var red: Dictionary = Audit.board_red(board)
	var out: Array = []
	for tile: Vector2i in red: out.append("%s%s" % [tile, red[tile]])
	return out

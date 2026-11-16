extends SceneTree
## atk-08 native frame strips (proof tool; never in default test groups).
## Resume a real save the receipt run wrote at an idle combat decision (the
## production boot path), replay the recorded decisions through the same scene
## input paths the run used, and save the exact 1920x1080 SubViewport at fixed
## presentation times across the event. Run under MovieWriter (strip_movie.sh:
## --write-movie, --fixed-fps 30): the presentation clock then advances one
## fixed frame per render, so slow PNG saves cannot stretch the timing.
## Usage (after --): --save-dir <repro> --out-dir <dir> [--seconds 6] [--every 0.1] [--reduced 0|1] [--from 0]
## --from skips frames before that presentation time (atk-10: late hits in long rounds).
## --speed normal|fast|fastest sets the combat speed (atk-12; default normal).
## --before 1 captures the integrated scene with only atk-12 presentation omitted.
## --require-number <text> / --require-actor <type> validate the captured witness.
## --require-progress <fraction> checks that number's captured animation life.
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const SIZE := Vector2i(1920, 1080)
var canvas: SubViewport
var scene: Node
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if DisplayServer.get_name() == "headless": process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _arg(name: String, fallback: String = "") -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = args.find(name)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else fallback

func _run() -> void:
	var save_dir: String = _arg("--save-dir")
	var out: String = _arg("--out-dir")
	var seconds: float = float(_arg("--seconds", "6"))
	var every: float = float(_arg("--every", "0.1"))
	var from: float = float(_arg("--from", "0"))
	DirAccess.make_dir_recursive_absolute(out)
	Store.set_storage_path("user://progression.json")
	Store.set_run_storage_path("user://current_run.save")
	_check(DirAccess.copy_absolute(save_dir.path_join("progression.json"), ProjectSettings.globalize_path("user://progression.json")) == OK, "copy profile")
	_check(DirAccess.copy_absolute(save_dir.path_join("run.save"), ProjectSettings.globalize_path("user://current_run.save")) == OK, "copy real save")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = _arg("--reduced", "0") == "1"
	settings["combat_speed"] = _arg("--speed", Settings.COMBAT_NORMAL)
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	root.size = SIZE
	root.content_scale_size = SIZE
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	root.add_child(container)
	canvas = SubViewport.new()
	canvas.size = SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(canvas)
	root.set_meta("labyrinth_resume_saved_run", true)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	if _arg("--before", "0") == "1":
		var before := GDScript.new()
		before.source_code = preload("res://tools/atk12/scene_source.gd").before(FileAccess.get_file_as_string("res://scripts/run_scene.gd"))
		_check(before.reload() == OK, "before scene compiles")
		scene.set_script(before)
	canvas.add_child(scene)
	for frame: int in range(90): await process_frame
	await create_timer(2.0).timeout
	await _idle()
	var expected: Variant = str_to_var(FileAccess.get_file_as_string(save_dir.path_join("combat_state.txt")))
	var state: Dictionary = scene.get("_combat_state")
	_check(str((scene.get("_run_state") as Dictionary).get("mode", "")) == "combat", "resumed into real combat")
	_check(expected is Dictionary and state.get("player", {}).get("pos") == (expected as Dictionary)["player"]["pos"] and state.get("enemies") == (expected as Dictionary)["enemies"], "resumed board equals the recorded decision point")
	_check(is_equal_approx(preload("res://scripts/ui_typography.gd").ui_scale(scene), 1.0), "UI scale 100%")
	_check(not Engine.get_write_movie_path().is_empty(), "MovieWriter clock (fixed frame time)")
	var decisions: Array = str_to_var(FileAccess.get_file_as_string(save_dir.path_join("decisions.txt")))
	var pacing: Node = scene.get("_combat_pacing")
	var manifest: Array = []
	for index: int in range(decisions.size()):
		var decision: Dictionary = decisions[index]
		if str(decision.get("kind", "")).begins_with("side_"): continue
		await _idle()
		if index < decisions.size() - 1:
			_dispatch(decision)
			for frame: int in range(8): await process_frame
			continue
		var started: int = pacing.presentation_usec()
		_dispatch(decision)
		var next_capture: float = from
		var idle_since: float = -1.0
		while true:
			await RenderingServer.frame_post_draw
			var t: float = float(pacing.presentation_usec() - started) / 1000000.0
			if t + 0.0001 >= next_capture:
				next_capture += every
				var path: String = out.path_join("frame_%03d_%05dms.png" % [manifest.size(), roundi(t * 1000.0)])
				var picture: Image = canvas.get_texture().get_image()
				_check(picture.get_size() == SIZE, "1920x1080 frame")
				picture.save_png(path)
				manifest.append(_frame_row(path, t))
			var idle: bool = not bool(scene.get("_animation_lock")) and str((scene.get("_run_state") as Dictionary).get("mode", "")) == "combat"
			if idle and idle_since < 0.0: idle_since = t
			if not idle: idle_since = -1.0
			if t >= seconds or (idle_since >= 0.0 and t - idle_since > 0.6): break
			await process_frame
	var required_number: String = _arg("--require-number")
	if not required_number.is_empty():
		var witnessed: bool = false
		for frame: Dictionary in manifest:
			if not _arg("--require-actor").is_empty() and str(frame["acting_type"]) != _arg("--require-actor"): continue
			for number: Dictionary in frame["hero_numbers"]:
				if str(number["text"]) == required_number and float(number["progress"]) >= float(_arg("--require-progress", "0")):
					witnessed = true
		_check(witnessed, "captured required hero number and animation progress: " + required_number)
	var file := FileAccess.open(out.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"save_dir": save_dir, "before": _arg("--before", "0") == "1", "ui_scale": settings["ui_scale"], "size": [SIZE.x, SIZE.y], "every": every, "reduced_motion": settings["reduced_motion"], "speed": settings["combat_speed"], "frames": manifest, "failures": failures}, "\t"))
	file.close()
	for row: Dictionary in manifest: print(row["path"])
	for failure: String in failures: push_error(failure)
	print("ATK08 STRIP: %s %d frames" % ["PASS" if failures.is_empty() else "FAIL", manifest.size()])
	quit(0 if failures.is_empty() else 1)

# What the frame shows that the strip labels: hero numbers, banner, rail.
func _frame_row(path: String, t: float) -> Dictionary:
	var board: Control = scene.get("board_view")
	var layer: Control = board.get("_effects_render_layer")
	var hero_tile: Vector2i = (board.get("combat_state") as Dictionary).get("player", {}).get("pos", Vector2i(-1, -1))
	var numbers: Array = []
	var canvases: Array = [layer]
	canvases.append_array(layer.get_children())
	for canvas_node: Node in canvases:
		if not (canvas_node is Control) or not ("_floating_text_last_layout" in canvas_node): continue
		if not (canvas_node as Control).is_visible_in_tree(): continue
		var ops: Array = canvas_node.get("_render_slice_ops")
		var draws: bool = canvas_node == layer and not (layer.get("presentation") as Dictionary).has("isolated_enemy_actor_keys")
		for operation: Variant in ops:
			if typeof(operation) == TYPE_ARRAY and not (operation as Array).is_empty() and str((operation as Array)[0]) == "_draw_floating_texts": draws = true
		if not draws: continue
		for popup: Dictionary in canvas_node.get("_floating_text_last_layout") as Array:
			var entry: Dictionary = popup.get("entry", {})
			if str(entry.get("reaction_actor_key", "")) == "player" or popup.get("tile", Vector2i(-1, -1)) == hero_tile:
				numbers.append({"text": str(entry.get("text", "")), "icon": str(entry.get("icon", "")), "progress": snappedf(float(entry.get("animation_progress", -1.0)), 0.01), "alpha": snappedf(float(entry.get("alpha", 1.0)), 0.01)})
	var banner: Label = scene.get("action_banner")
	var tracker: RefCounted = board.get("health_ghost_tracker")
	var ghost: Dictionary = tracker.sample("player") if tracker != null else {}
	var rail: String = ""
	for entry: Dictionary in scene.get("_turn_order_rendered_entries") as Array:
		if bool(entry.get("active", false)): rail = str(entry.get("actor_key", entry.get("kind", "")))
	var names: Dictionary = {}
	for enemy: Dictionary in (scene.get("_combat_state") as Dictionary).get("enemies", []): names["enemy_%d" % int(enemy.get("id", -1))] = str(enemy.get("type", ""))
	return {"path": path, "t": snappedf(t, 0.001), "hero_numbers": numbers, "banner": banner.text if banner != null and banner.is_visible_in_tree() else "",
		"rail": rail, "rail_type": str(names.get(rail, rail)), "acting": str(scene.get("_combat_pacing").get("_actor")), "acting_type": str(names.get(str(scene.get("_combat_pacing").get("_actor")), "")),
		"pacing": "%s|%s" % [str(scene.get("_combat_pacing").get("_actor")), str(scene.get("_combat_pacing").get("_phase"))],
		"ghost": [roundi((ghost.get("ghost_range", Vector2.ZERO) as Vector2).x), roundi((ghost.get("ghost_range", Vector2.ZERO) as Vector2).y)] if not ghost.is_empty() else []}

func _idle() -> void:
	var quiet: int = 0
	var guard: int = 0
	while quiet < 8 and guard < 3000:
		guard += 1
		await process_frame
		var busy: bool = bool(scene.get("_animation_lock")) or bool(scene.get("_dialogue_active"))
		quiet = 0 if busy else quiet + 1

# The run hunt's own dispatch (tools/run_hunt_policy.gd): methods are the scene's
# input handlers; a move selects the hero, then clicks the destination tile.
func _dispatch(decision: Dictionary) -> void:
	if decision.has("method"):
		scene.callv(str(decision["method"]), decision.get("args", []))
	elif str(decision.get("kind", "")) == "move":
		scene.call("_on_board_tile_clicked", (scene.get("_combat_state") as Dictionary).get("player", {}).get("pos"))
		if bool(scene.get("_player_movement_selected")): scene.call("_on_board_tile_clicked", decision["tile"])

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

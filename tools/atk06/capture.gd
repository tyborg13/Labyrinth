extends SceneTree
## atk-06 native proof: resume a real audit save at its decision point
## (production boot path) and save the 1920x1080 frame either at rest (no hover,
## no selection) or with one hero-movement destination hovered by a real pointer.
## Writes <out>.json beside the PNG: the red tiles the board drew, the PASS
## summary, and the screen polygons of --mark tiles (for the proof pair only).
## Usage (after --): --save-dir <repro dir> --tile rest|x,y --out <png> [--mark x,y;x,y]
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Audit = preload("res://tools/atk06/audit.gd")
const SIZE := Vector2i(1920, 1080)
const INVALID := Vector2i(-1, -1)
var canvas: SubViewport
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if DisplayServer.get_name() == "headless": process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _arg(name: String, fallback: String = "") -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = args.find(name)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else fallback

func _tile(text: String) -> Vector2i:
	return Vector2i(int(text.get_slice(",", 0)), int(text.get_slice(",", 1)))

func _run() -> void:
	var save_dir: String = _arg("--save-dir")
	var out: String = _arg("--out")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	Store.set_storage_path("user://progression.json")
	Store.set_run_storage_path("user://current_run.save")
	_check(DirAccess.copy_absolute(save_dir.path_join("progression.json"), ProjectSettings.globalize_path("user://progression.json")) == OK, "copy profile")
	_check(DirAccess.copy_absolute(save_dir.path_join("run.save"), ProjectSettings.globalize_path("user://current_run.save")) == OK, "copy real save")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
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
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	for frame: int in range(90): await process_frame
	await create_timer(2.0).timeout
	var expected: Variant = str_to_var(FileAccess.get_file_as_string(save_dir.path_join("combat_state.txt")))
	var state: Dictionary = scene.get("_combat_state")
	_check(str((scene.get("_run_state") as Dictionary).get("mode", "")) == "combat", "resumed into real combat")
	_check(expected is Dictionary and state.get("player", {}).get("pos") == expected["player"]["pos"] and state.get("enemies") == expected["enemies"], "resumed board equals the audited decision point")
	_check(is_equal_approx(preload("res://scripts/ui_typography.gd").ui_scale(scene), 1.0), "UI scale 100%")
	var board: Control = scene.get("board_view")
	var target: String = _arg("--tile", "rest")
	if target == "rest":
		# Park the pointer on the empty top edge of the screen; nothing is hovered or selected.
		_motion(Vector2(SIZE.x * 0.5, 4.0))
	else:
		var tile: Vector2i = _tile(target)
		scene.call("_begin_player_movement_selection")
		await create_timer(0.3).timeout
		_check((scene.get("_player_movement_target_tiles") as Array).has(tile), "destination is a legal hero move")
		_motion(board.get_global_transform_with_canvas() * Vector2(board.call("world_position_for_tile", tile)))
	await create_timer(1.2).timeout
	if target == "rest":
		_check(scene.get("_hovered_board_tile") == INVALID and not bool(scene.get("_player_movement_selected")) and int(scene.get("_selected_card_index")) < 0, "board at rest: nothing hovered or selected")
	else:
		_check(scene.get("_hovered_board_tile") == _tile(target), "real pointer owns the hovered tile")
	_prepare_frame(scene, board, target)
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var picture: Image = canvas.get_texture().get_image()
		_check(picture.get_size() == SIZE and picture.save_png(out) == OK, "1920x1080 PNG")
	var red: Dictionary = Audit.board_red(board)
	var red_out: Dictionary = {}
	for tile: Vector2i in red: red_out[str(tile)] = red[tile]
	var marks: Dictionary = {}
	var transform: Transform2D = board.get_global_transform_with_canvas()
	for text: String in _arg("--mark", "").split(";", false):
		var points: Array = []
		for point: Vector2 in board.call("_tile_polygon", _tile(text)): points.append([(transform * point).x, (transform * point).y])
		marks[text] = points
	var summary: Dictionary = scene.call("_pass_preview_summary") if target != "rest" else {}
	var report: Dictionary = {"target": target, "hero": str(state["player"]["pos"]), "red": red_out, "marks": marks,
		"summary": {"hp": int(summary.get("hp_loss", 0)), "block": int(summary.get("block_loss", 0)), "defeat": bool(summary.get("defeat", false)), "tone": str(summary.get("tone", ""))}, "failures": failures}
	report.merge(_proof_fields())
	var file := FileAccess.open(out.get_basename() + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(out)
	print("ATK06 CAPTURE %s %s" % [out, JSON.stringify(report)])
	for failure: String in failures: push_error(failure)
	print("ATK06 CAPTURE: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _motion(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

# Task-specific proofs may compare a prior presentation on the same saved board.
func _prepare_frame(_scene: Node, _board: Control, _target: String) -> void:
	pass

func _proof_fields() -> Dictionary:
	return {}

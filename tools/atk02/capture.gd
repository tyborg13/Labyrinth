extends SceneTree
## atk-02 native proof: resume a real save (production boot path) in an exact
## 1920x1080 SubViewport, then with real pointer motion and clicks: walk the
## hero (--move), select the last card (--card), sweep its targets (--targets)
## and, with --click, play the last target and wait for the auto-pass enemy
## round, checking it lands where the panel said. Saves a PNG per --stills name.
## Usage (after --): --save-dir <dir> --out-dir <dir> [--move x,y [--move-still name]
##   [--expect-move-ends 1|0]] [--card <id> --targets x,y[;x,y] [--stills name[;name]]
##   [--expect-ends 1|0] [--expect-panel 1|0] [--hold] [--click]]
## Without --card, the run ends on the hovered walk destination.
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Presentation = preload("res://scripts/pass_forecast_presentation.gd")
const Rows = preload("res://scripts/pass_forecast_focus_tooltip.gd")
const SIZE := Vector2i(1920, 1080)
const TRAVEL_FRAMES: int = 12
const TARGET_HOLD_FRAMES: int = 45
var canvas: SubViewport
var scene: Node
var pointer := Vector2(960, 900)
var failures: Array[String]
var out_dir: String

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if DisplayServer.get_name() == "headless":
		# A headless rehearsal follows the same inputs at the movie's frame rate,
		# so wall-clock fades settle as they do in the movie.
		Engine.max_fps = 30
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _arg(name: String, fallback: String = "") -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = args.find(name)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else fallback

static func _tile(text: String) -> Vector2i:
	return Vector2i(int(text.get_slice(",", 0)), int(text.get_slice(",", 1)))

func _run() -> void:
	var save_dir: String = _arg("--save-dir")
	out_dir = _arg("--out-dir")
	DirAccess.make_dir_recursive_absolute(out_dir)
	Store.set_storage_path("user://progression.json")
	Store.set_run_storage_path("user://current_run.save")
	_check(DirAccess.copy_absolute(save_dir.path_join("progression.json"), ProjectSettings.globalize_path("user://progression.json")) == OK, "copy profile")
	_check(DirAccess.copy_absolute(save_dir.path_join("run.save"), ProjectSettings.globalize_path("user://current_run.save")) == OK, "copy real save")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
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
	canvas.add_child(scene)
	for frame: int in range(90): await process_frame
	await create_timer(2.0).timeout
	var engine: RefCounted = scene.get("_combat_engine")
	var state: Dictionary = scene.get("_combat_state")
	_check(str((scene.get("_run_state") as Dictionary).get("mode", "")) == "combat", "resumed into real combat")
	_check(is_equal_approx(preload("res://scripts/ui_typography.gd").ui_scale(scene), 1.0), "UI scale 100%")
	print("ATK02 CAPTURE START frame=%d hero=%s hp=%d cards=%d moves=%d" % [Engine.get_frames_drawn(), state["player"]["pos"], int(state["player"]["hp"]), engine.cards_remaining_this_turn(state), engine.player_movement_remaining(state)])
	var move: String = _arg("--move")
	if not move.is_empty():
		await _pointer_to(_tile_point(state["player"]["pos"]))
		await _frames(6)
		await _click()
		await _frames(12)
		await _pointer_to(_tile_point(_tile(move)))
		await _frames(36)
		var move_ends: bool = bool(_chip().get_meta("pass_ends_turn_preview", false))
		var move_rows: Array = []
		for row: Dictionary in _chip().get_meta("forecast_rows", []):
			for part: Dictionary in row.get("parts", []): move_rows.append("%s %s" % [part.get("icon", ""), part.get("text", "")])
		var move_panel: Control = _chip().get_node_or_null("PassForecastFocusTooltip") as Control
		var move_visible: bool = move_panel != null and move_panel.is_visible_in_tree() and move_panel.modulate.a > 0.99
		print("ATK02 CAPTURE move=%s ends_turn=%s panel=%s rows=%s" % [move, str(move_ends), str(move_visible), str(move_rows)])
		_check(bool(_chip().get_meta("pass_movement_preview", false)) and move_visible, "destination shows trigger (b)")
		# A walk is final when no card play is left and it spends the last movement.
		var walked: Dictionary = engine.apply_player_movement(state, _tile(move))
		_check(move_ends == engine.player_turn_resources_exhausted(walked), "destination header matches the committed walk's auto-pass")
		_check(move_ends == (not move_rows.is_empty() and str(move_rows[0]) == "turn_clock Ends turn"), "destination panel leads with Ends turn only when final")
		if not _arg("--expect-move-ends").is_empty(): _check(move_ends == (_arg("--expect-move-ends") == "1"), "destination trigger (c) is " + _arg("--expect-move-ends"))
		if not _arg("--move-still").is_empty(): await _still(_arg("--move-still"))
		if _arg("--card").is_empty():
			await _frames(20)
			_finish()
			return
		await _click()
		for frame: int in range(900):
			await process_frame
			if not bool(scene.get("_animation_lock")): break
		await _frames(10)
		state = scene.get("_combat_state")
		_check(state["player"]["pos"] == _tile(move) and engine.player_movement_remaining(state) == 0, "walk spent all movement")
	var hand: Array = state["deck"]["hand"]
	var card: Control = scene.call("_hand_card_control", hand.find(_arg("--card"))) as Control
	_check(card != null, "card in hand")
	await _pointer_to(card.get_global_rect().get_center())
	await _frames(10)
	var holding: bool = OS.get_cmdline_user_args().has("--hold")
	if holding:
		# Press on the card and keep the button down: the drag aims the card.
		await _press(true)
	else:
		await _click()
	await _frames(14)
	var targets: PackedStringArray = _arg("--targets").split(";", false)
	var stills: PackedStringArray = _arg("--stills").split(";", false)
	var expect_ends: String = _arg("--expect-ends")
	var summary: Dictionary = {}
	for index: int in range(targets.size()):
		await _pointer_to(_tile_point(_tile(targets[index])))
		await _frames(TARGET_HOLD_FRAMES)
		_check(scene.get("_hovered_board_tile") == _tile(targets[index]), "real pointer owns target %s" % targets[index])
		summary = scene.call("_pass_preview_summary")
		var ends: bool = Presentation.ends_turn(scene)
		var panel: Control = _chip().get_node_or_null("PassForecastFocusTooltip") as Control
		var shown: Array = []
		for row: Dictionary in _chip().get_meta("forecast_rows", []):
			for part: Dictionary in row.get("parts", []): shown.append("%s %s" % [part.get("icon", ""), part.get("text", "")])
		var visible: bool = panel != null and panel.is_visible_in_tree() and panel.modulate.a > 0.99
		print("ATK02 CAPTURE target=%s held=%s ends_turn=%s panel=%s rows=%s summary=%s" % [targets[index], str(int(scene.get("_drag_card_index")) >= 0), str(ends), str(visible), str(shown), JSON.stringify({"hp_loss": summary.get("hp_loss", 0), "block_loss": summary.get("block_loss", 0), "stoneskin_loss": summary.get("stoneskin_loss", 0), "projected_hp": summary.get("projected_hp", -1), "defeat": summary.get("defeat", false)})])
		if holding: _check(int(scene.get("_drag_card_index")) >= 0, "card is held")
		var first: String = str(shown[0]) if not shown.is_empty() else ""
		if not expect_ends.is_empty():
			_check(ends == (expect_ends == "1"), "target %s trigger (c) is %s" % [targets[index], expect_ends])
			_check(not ends or (visible and first == "turn_clock Ends turn"), "target %s panel leads with Ends turn" % targets[index])
			_check(ends or not visible or not first.begins_with("turn_clock"), "target %s shows no Ends turn header" % targets[index])
		var expect_panel: String = _arg("--expect-panel")
		if not expect_panel.is_empty(): _check(visible == (expect_panel == "1"), "target %s panel open is %s" % [targets[index], expect_panel])
		if index < stills.size(): await _still(stills[index])
	if OS.get_cmdline_user_args().has("--click"):
		await _truth(engine, summary)
	await _frames(20)
	_finish()

func _finish() -> void:
	for failure: String in failures: push_error(failure)
	print("ATK02 CAPTURE: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

# Play the hovered final target and let the auto-pass resolve the enemy round.
func _truth(engine: RefCounted, summary: Dictionary) -> void:
	var source: Dictionary = scene.call("_pass_preview_source_state")
	var predicted: Dictionary = Rows.row_losses(summary)
	var before: Dictionary = (source.get("player", {}) as Dictionary).duplicate()
	var turn: int = int((scene.get("_combat_state") as Dictionary).get("turn", 0))
	await _click()
	var resolved: bool = false
	for frame: int in range(1500):
		await process_frame
		var run: Dictionary = scene.get("_run_state")
		var state: Dictionary = scene.get("_combat_state")
		if str(run.get("mode", "")) != "combat" or not engine.combat_outcome(state).is_empty():
			resolved = true
			break
		if not bool(scene.get("_animation_lock")) and engine.is_player_turn(state) and int(state.get("turn", 0)) > turn:
			resolved = true
			break
	await _frames(30)
	var after_state: Dictionary = scene.get("_combat_state")
	var after: Dictionary = after_state.get("player", {}) as Dictionary
	var died: bool = int(after.get("hp", 0)) <= 0 or engine.combat_outcome(after_state) == "defeat" or str((scene.get("_run_state") as Dictionary).get("mode", "")) != "combat"
	var actual_hp_loss: int = int(before.get("hp", 0)) - int(after.get("hp", 0))
	print("ATK02 TRUTH resolved=%s panel=%s projected_hp=%d defeat=%s | actual hp %d->%d block %d->%d stoneskin %d->%d died=%s" % [str(resolved), JSON.stringify(predicted), int(summary.get("projected_hp", -1)), str(summary.get("defeat", false)), int(before.get("hp", 0)), int(after.get("hp", 0)), int(before.get("block", 0)), int(after.get("block", 0)), int(before.get("stoneskin", 0)), int(after.get("stoneskin", 0)), str(died)])
	_check(resolved, "auto-pass resolved the enemy round")
	_check(bool(summary.get("defeat", false)) == died, "defeat matches the panel")
	if not died:
		_check(int(summary.get("projected_hp", int(after.get("hp", 0)))) == int(after.get("hp", 0)), "Health after the round equals the panel's projection")
		_check(actual_hp_loss == int(predicted["health"]) + int(predicted["fatigue"]), "Health lost equals the panel's Health row")

func _still(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var picture: Image = canvas.get_texture().get_image()
	var path: String = out_dir.path_join(name + ".png")
	_check(picture.get_size() == SIZE and picture.save_png(path) == OK, "1920x1080 PNG " + name)
	print(path)

func _chip() -> Button:
	return scene.find_child("PassPreviewChip", true, false) as Button

func _tile_point(tile: Vector2i) -> Vector2:
	var board: Control = scene.get("board_view") as Control
	return board.get_global_transform_with_canvas() * (board.call("_tile_center", tile) as Vector2)

func _frames(count: int) -> void:
	for frame: int in range(count): await process_frame

var held: bool = false

func _pointer_to(target: Vector2) -> void:
	var from: Vector2 = pointer
	for index: int in range(TRAVEL_FRAMES):
		pointer = from.lerp(target, float(index + 1) / float(TRAVEL_FRAMES))
		var motion := InputEventMouseMotion.new()
		motion.position = pointer
		motion.global_position = pointer
		if held: motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion, true)
		await process_frame

func _press(pressed: bool) -> void:
	held = pressed
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = pointer
	event.global_position = pointer
	event.pressed = pressed
	if pressed: event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)
	await process_frame

func _click() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = pointer
		event.global_position = pointer
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

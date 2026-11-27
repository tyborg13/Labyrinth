extends SceneTree
## Drive the production scene with viewport mouse events. The checkpoint is the
## last room before the take so the game owns the door, intro, prompt and walk.

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Cel = preload("res://scripts/cel_look.gd")
const Fixture = preload("res://tools/tut02/run_fixture.gd")
const Hover = preload("res://tools/gfix54/native_hover.gd")
const RouteInput = preload("res://tools/smoke_recording/route_input.gd")
const Take = preload("res://tools/tut03/take_fixture.gd")
const TypedArrays = preload("res://scripts/typed_arrays.gd")

const SIZE := Vector2i(1920, 1080)
const FPS: int = 30
const UI_SCALE: float = 1.0
const MAP_HOLD: float = 1.0
const POINTER_HOLD: float = 3.0
const LABEL_HOLD: float = 3.0
const LABEL_GLIDE: float = 0.6
const CONTINUE_GLIDE: float = 0.6
const CONTINUE_HOVER: float = 0.4
const AFTER_CONTINUE_HOLD: float = 1.0
const FINAL_HOLD: float = 1.5
# Director: the untimed legs use the same 0.6 s glide as the timed ones.
const UNTIMED_GLIDE_SECONDS: float = 0.6
const WAIT_FRAMES: int = 900
const LAYOUT_FRAMES: int = 6

var _dry_run: bool
var _output: String
var _driver: RouteInput
var _scene: Node
var _board: Control
var _combat: RefCounted
var _start_frame: int
var _still_frames: Array[int]
var _failed: bool

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Runtime.apply_from_environment()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): _output = arg.trim_prefix("--out=")
		if arg == "--dry-run": _dry_run = true
	if not _require(_output.is_absolute_path() and DirAccess.dir_exists_absolute(_output), "Existing take directory required"): return
	if not _require(_dry_run == (DisplayServer.get_name() == "headless"), "Use headless for rehearsal and native for Movie Maker"): return
	if not _require(_dry_run or not Engine.get_write_movie_path().is_empty(), "Native take requires Movie Maker"): return
	if not _require(Cel.mode == "all" and not Cel._files.is_empty(), "Use installed production cel-look assets"): return
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.gui_embed_subwindows = true
	root.notify_mouse_entered()
	if _dry_run:
		# The headless renderer never signals production post-draw fences.
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	_driver = RouteInput.new(self, not _dry_run)
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["ui_scale"] = UI_SCALE
	if not _require(Settings.save_settings(settings), "Save capture settings in the isolated profile"): return
	var completed: Dictionary = Tutorial.complete_tutorial(Store.default_data())
	var progression: Dictionary = Store.prepare_for_new_run(completed)
	var expected: Dictionary = Fixture.first_umbra(progression)
	var map: Dictionary = Take.map_start(progression)
	if not _require(not expected.is_empty() and not map.is_empty(), "tut-02 fight and its preceding room checkpoint exist"): return
	if not _require(Store.save_data(map["progression"]) and Store.save_run_state(map), "Save the pre-take checkpoint"): return
	root.set_meta("labyrinth_resume_saved_run", true)
	if not _require(change_scene_to_file("res://scenes/run_scene.tscn") == OK, "Mount production RunScene"): return
	await scene_changed
	_scene = current_scene
	_board = _scene.get("board_view")
	_combat = _scene.get("_combat_engine")
	var saved: Dictionary = Store.load_data()
	if not _require(Tutorial.is_completed(saved) and not Tutorial.has_completed(saved, Tutorial.MILESTONE_UMBRA), "Completed guided tutorial with Umbra unread"): return
	if not await _enter_room(map["current_room"]): return
	if not await _begin_fight(expected["combat_state"]): return
	if not await _show_pointer_and_hover(): return
	if not await _continue_and_move(): return
	_finish()

func _enter_room(start_room: Vector2i) -> bool:
	await _frames(LAYOUT_FRAMES)
	if not _require(_scene.call("has_installed_run") and _run_state().get("current_room") == start_room
			and _run_state().get("mode") == "room" and not _scene.get("_dialogue_active"), "Resume on the traversable room map"): return false
	var scrim: Control = _scene.get("_large_map_scrim")
	if not await _until(func() -> bool: return scrim.is_visible_in_tree() and is_equal_approx(scrim.modulate.a, 1.0),
			"Section map is fully presented"): return false
	var map: Control = _scene.get("_large_map_view")
	var destinations: Array[Vector2i] = TypedArrays.vector2i([Take.DESTINATION])
	var rooms: Dictionary = map.call("selectable_room_global_rects", destinations)
	var start_marker: Control = map.get("node_buttons").get(start_room)
	var door: Vector2i = _scene.call("_door_tile_for_destination", Take.DESTINATION)
	if not _require(_driver.usable(start_marker) and rooms.has(Take.DESTINATION) and door != Take.INVALID_TILE,
			"The section map shows the hero's room and the next room's door route"): return false
	var door_point: Vector2 = map.get_canvas_transform() * (rooms[Take.DESTINATION] as Rect2).get_center()
	_driver.motion(_driver.point(start_marker))
	if not _dry_run:
		if not await _until(_cursor_visible, "Focus the recording window so the game cursor is drawn"): return false
		root.focus_exited.connect(_on_focus_exited)
	_start_frame = _frame_number()
	await _hold(MAP_HOLD)
	if not await _still(1): return false
	await _glide(door_point, _untimed_glide())
	await _driver.click(door_point)
	if not await _until(func() -> bool:
			return _run_state().get("current_room") == Take.DESTINATION and _run_state().get("mode") == "pre_battle",
			"Door entered the authored room"): return false
	print("TUT-03 STEP 1 PASS: map=%s door=%s destination=%s seed=%d" % [start_room, door, Take.DESTINATION, _run_state()["seed"]])
	return true

func _begin_fight(expected: Dictionary) -> bool:
	var scrim: Control = _scene.get("_pre_battle_scrim")
	if not await _until(func() -> bool:
			return scrim.is_visible_in_tree() and is_equal_approx(scrim.modulate.a, 1.0) and _scene.get("_pre_battle_entry_tween") == null,
			"Full pre-battle entrance"): return false
	var begin: Button = _scene.find_child("PreBattleStartButton", true, false) as Button
	if not _require(_driver.usable(begin), "Begin button is visible and enabled"): return false
	if not await _still(2): return false
	await _glide(_driver.point(begin), _untimed_glide())
	await _driver.click(_driver.point(begin))
	if not await _until(func() -> bool:
			return _pointer_visible() and not _scene.get("_opening_hand_draw_in_progress") and not _scene.get("_animation_lock"),
			"Full combat intro reaches the real pointer"): return false
	var state: Dictionary = _battle()
	var same_fight: bool = state.get("player", {}).get("pos") == expected["player"]["pos"]
	for key: String in ["umbra", "enemies", "grid", "deck"]:
		same_fight = same_fight and state.get(key) == expected.get(key)
	if not _require(same_fight and _run_state()["seed"] == Fixture.SEED and _combat.call("is_player_turn", state)
			and state["turn"] == 1 and Fixture.has_concealed_enemy(_combat, state), "Live encounter matches the first tut-02 fight on turn 1"): return false
	print("TUT-03 STEP 2 PASS: room=%s turn=%d intro=settled concealed_enemy=true" % [_run_state()["current_room"], state["turn"]])
	return true

func _show_pointer_and_hover() -> bool:
	var prompt: Control = _scene.get("_contextual_combat_prompt")
	var subtitle: Label = _scene.get("umbra_subtitle")
	var card: Rect2 = prompt.get_meta("callout_rect", Rect2())
	var spotlights: Array = prompt.get_meta("spotlight_rects", [])
	var title: Label = prompt.get("_title")
	var kicker: Label = prompt.get("_kicker")
	if not _require(card.has_area() and spotlights.size() == 1 and kicker.is_visible_in_tree() and kicker.text == "UMBRA"
			and title.is_visible_in_tree() and title.text == "Fringe Umbra" and subtitle.text == title.text,
			"Visible UMBRA card and Fringe Umbra HUD label"): return false
	var rest: Vector2i = Take.empty_tile(_battle(), _combat, func(tile: Vector2i) -> bool:
		var point: Vector2 = _tile_point(tile)
		return _point_is_tile(point, tile) and not card.grow(card.size.y * 0.5).has_point(point) and not _under_hud(point))
	if not _require(rest != Take.INVALID_TILE, "Find an empty board tile away from the card and HUD"): return false
	await _glide(_tile_point(rest), _untimed_glide())
	await _hold(POINTER_HOLD)
	if not _require(_pointer_visible() and not Hover.has_visible_tooltip(root), "The card remains visible while the mouse rests on the empty board"): return false
	if not await _still(3): return false
	print("TUT-03 STEP 3 PASS: pointer=visible heading=%s title=%s rest_tile=%s" % [kicker.text, title.text, rest])
	var text_rect: Rect2 = spotlights[0]
	var label_point: Vector2 = subtitle.get_canvas_transform() * text_rect.get_center()
	await _glide(label_point, LABEL_GLIDE)
	var witnessed: Window
	for _frame: int in range(roundi(LABEL_HOLD * FPS)):
		await process_frame
		var popup: Window = Hover.popup_for(subtitle, title.text)
		if not _require(_pointer_visible() and (witnessed == null or popup == witnessed), "The card and HUD popup stay open once the real hover fires"): return false
		if popup != null: witnessed = popup
	if not _require(is_instance_valid(witnessed), "Hover opened the embedded Fringe Umbra popup"): return false
	var popup_text: String = Hover.visible_text(witnessed)
	var rules: String = " ".join(popup_text.split("\n", false))
	if not _require(rules.contains(Tutorial.UMBRA_SIGHT_RULES) and rules.contains(Tutorial.UMBRA_VISION_RULE), "Popup renders the authored Umbra rules"): return false
	if not await _still(4): return false
	print("TUT-03 STEP 4 PASS: popup=visible text=%s" % JSON.stringify(popup_text))
	return true

func _continue_and_move() -> bool:
	var button: Button = _scene.get("_contextual_combat_prompt").get("_continue_button")
	if not _require(_driver.usable(button) and button.text == "Continue", "The visible Continue button can receive input"): return false
	var point: Vector2 = _driver.point(button)
	await _glide(point, CONTINUE_GLIDE)
	await _hold(CONTINUE_HOVER)
	await _driver.click(point)
	if not await _until(func() -> bool: return not _prompt_host_visible(), "Continue closes the actual card"): return false
	await _hold(AFTER_CONTINUE_HOLD)
	var saved_run: Dictionary = Store.load_checkpoint_for_resume()
	if not _require(Tutorial.has_completed(Store.load_data(), Tutorial.MILESTONE_UMBRA)
			and Tutorial.has_completed(saved_run.get("progression", {}), Tutorial.MILESTONE_UMBRA)
			and not _prompt_host_visible() and _battle()["turn"] == 1, "Continue persisted umbra_read on the same turn"): return false
	if not await _still(5): return false
	print("TUT-03 STEP 5 PASS: card=closed profile=umbra_read checkpoint=umbra_read turn=%d" % _battle()["turn"])
	var hero: Vector2i = _battle()["player"]["pos"]
	var destination: Vector2i = Take.adjacent_move(_battle(), _combat)
	if not _require(destination != Take.INVALID_TILE, "Find a legal one-tile walk"): return false
	await _glide(_tile_point(hero), _untimed_glide())
	await _driver.click(_tile_point(hero))
	if not _require(_scene.get("_player_movement_selected") and _scene.get("_player_movement_target_tiles").has(destination), "Hero click selects live movement"): return false
	await _glide(_tile_point(destination), _untimed_glide())
	await _driver.click(_tile_point(destination))
	if not await _until(func() -> bool: return _battle()["player"]["pos"] == destination and not _scene.get("_animation_lock"), "Mouse walk reaches the adjacent tile"): return false
	var movement: Dictionary = _battle().get("last_player_movement", {})
	if not _require(movement.get("action_type") == "move" and movement.get("undo_report", {}).get("tiles") == 1 and _battle()["turn"] == 1,
			"The committed walk took exactly one path step on turn 1"): return false
	await _hold(FINAL_HOLD)
	if not await _still(6): return false
	print("TUT-03 STEP 6 PASS: hero=%s -> %s path_steps=1 turn=%d" % [hero, destination, _battle()["turn"]])
	return true

func _glide(destination: Vector2, seconds: float) -> void:
	var origin: Vector2 = _driver.position
	var count: int = roundi(seconds * FPS)
	for step: int in range(1, count + 1):
		var progress: float = float(step) / float(count)
		_driver.motion(origin.lerp(destination, smoothstep(0.0, 1.0, progress)))
		await process_frame

func _untimed_glide() -> float:
	return UNTIMED_GLIDE_SECONDS

func _frames(count: int) -> void:
	for _frame: int in range(count):
		await process_frame

func _hold(seconds: float) -> void:
	await _frames(roundi(seconds * FPS))

func _until(predicate: Callable, detail: String) -> bool:
	for _frame: int in range(WAIT_FRAMES):
		if _failed: return false
		if predicate.call(): return true
		await process_frame
	return _require(false, "Timed out: " + detail)

func _run_state() -> Dictionary:
	return _scene.get("_run_state")

func _battle() -> Dictionary:
	return _scene.get("_combat_state")

func _tile_point(tile: Vector2i) -> Vector2:
	return _board.get_global_transform_with_canvas() * _board.call("world_position_for_tile", tile)

func _point_is_tile(point: Vector2, tile: Vector2i) -> bool:
	return root.get_visible_rect().has_point(point) and _board.call("tile_at_global_position", point) == tile

func _under_hud(point: Vector2) -> bool:
	for rect: Rect2 in _board.get("presentation").get("hud_obstacle_global_rects", []):
		if rect.has_point(point): return true
	return false

func _prompt_host_visible() -> bool:
	var host: Control = _scene.get("_contextual_combat_prompt_host")
	return host != null and host.is_visible_in_tree()

func _pointer_visible() -> bool:
	return _prompt_host_visible() and _scene.get("_guided_tutorial_phase_id") == Tutorial.PHASE_UMBRA

func _cursor_visible() -> bool:
	return root.has_focus() and root.get_node("CursorFeedback/ForgedCursorGlyph").is_visible_in_tree()

func _on_focus_exited() -> void:
	_require(false, "Recording window lost focus")

func _frame_number() -> int:
	return Engine.get_process_frames() if _dry_run else Engine.get_frames_drawn()

func _still(step: int) -> bool:
	if not _require(root.size == SIZE and is_equal_approx(root.content_scale_factor, UI_SCALE), "Take stays at 1920x1080 and 100% UI scale"): return false
	if not _dry_run:
		await RenderingServer.frame_post_draw
		if not _require(_cursor_visible(), "Rendered step %d contains the game's cursor" % step): return false
		var image: Image = root.get_texture().get_image()
		var path: String = _output.path_join("step-%d.png" % step)
		if not _require(image != null and image.get_size() == SIZE and image.save_png(path) == OK, "Save native step %d frame" % step): return false
		print(path)
	_still_frames.append(_frame_number())
	return true

func _require(condition: bool, detail: String) -> bool:
	if not condition and not _failed:
		_failed = true
		push_error("TUT-03 FAIL: " + detail)
		preload("res://scripts/presentation_clock.gd").release_shutdown_callables()
		quit(1)
	return condition and not _failed

func _finish() -> void:
	if root.focus_exited.is_connected(_on_focus_exited): root.focus_exited.disconnect(_on_focus_exited)
	if not _require(not Cel._warned, "Cel look used the installed approved variants"): return
	var end_frame: int = _frame_number()
	var report := FileAccess.open(_output.path_join("route.json"), FileAccess.WRITE)
	if not _require(report != null, "Write route frame receipt"): return
	report.store_string(JSON.stringify({
		"dry_run": _dry_run, "fps": FPS, "size": [root.size.x, root.size.y], "ui_scale": root.content_scale_factor,
		"start_frame": _start_frame, "end_frame": end_frame, "still_frames": _still_frames,
	}, "\t"))
	report.close()
	print("TUT-03 ROUTE PASS: 6 steps, %d frames after map start" % (end_frame - _start_frame))
	preload("res://scripts/presentation_clock.gd").release_shutdown_callables()
	quit()

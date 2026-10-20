extends "res://tests/card_drag_overlay_probe.gd"

## Renderer proof for int-03; --validate-only exercises the same input route
## headlessly. All coordinates/timing below belong only to this proof fixture.
const CaptureViewport = preload("res://tests/helpers/ui03_capture_viewport.gd")
const Settings = preload("res://scripts/settings_store.gd")
const INT03_OUTPUT := "user://probes/int03_targeting"
const FIXTURE_SEED: int = 10301
const FIXTURE_PLAYER := Vector2i(2, 4)
const FIXTURE_ENEMY := Vector2i(3, 4)
const FIXTURE_INVALID := Vector2i(1, 1)
const FIXTURE_HUD_POINT := Vector2(8, 8)

var _capture: Node
var _scene: Node
var _game_viewport: SubViewport
var _validate_only: bool
var _proof_failed: bool = false
var _states: Array[Dictionary]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_validate_only = OS.get_cmdline_user_args().has("--validate-only")
	root.size = PROBE_VIEWPORT
	root.content_scale_size = PROBE_VIEWPORT
	if not _validate_only:
		DisplayServer.window_set_size(PROBE_VIEWPORT)
	Settings.set_storage_path("user://int03_probe_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.apply_settings(settings, root, false)
	ProgressionStore.set_storage_path("user://int03_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://int03_probe_run.save")
	ProgressionStore.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(INT03_OUTPUT))
	if _validate_only:
		# CursorFeedback deliberately omits its drawable glyph headlessly.
		_game_viewport = SubViewport.new()
		_game_viewport.size = PROBE_VIEWPORT
		root.add_child(_game_viewport)
		_game_viewport.notify_mouse_entered()
	else:
		_capture = CaptureViewport.new()
		root.add_child(_capture)
		# CursorFeedback builds its glyph on its first frame.
		await process_frame
		_capture.setup(root)
		_game_viewport = _capture.viewport
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_game_viewport.add_child(_scene)
	await process_frame
	await process_frame
	await _load_combat_fixture(_scene, "quick_stab", FIXTURE_PLAYER, FIXTURE_ENEMY, FIXTURE_SEED)
	_scene.set("_guided_tutorial_phase_id", "")
	var board_point: Vector2 = _tile_global_position(_scene, FIXTURE_INVALID)
	_move(board_point)
	_scene.call("_on_card_drag_started", 0, _drag_start_position(_scene, 0))
	await _scene.call("_commit_drag_drop", "play", board_point)
	await _record("invalid_release_board", true, "board")
	for pair: Array in [["_open_large_map", "_close_large_map", "map_return"],
		["_open_menu_overlay", "_close_menu_overlay", "menu_return"],
		["_toggle_skill_status_popover", "_close_skill_status_popover", "abilities_return"]]:
		_scene.call(pair[0])
		await process_frame
		_move(FIXTURE_HUD_POINT)
		_move(board_point)
		_scene.call(pair[1])
		await _record(pair[2], true, "board")
	var options: Array = [{"text": "Keep Targeting", "detail": "Probe-only modal ownership option", "callback": Callable(_scene, "_refresh_ui")}]
	_scene.call("_open_skill_choice_dialog", "Choose", "Probe modal ownership", options)
	await process_frame
	_move(FIXTURE_HUD_POINT)
	_move(board_point)
	_scene.call("_close_skill_choice_dialog")
	await _record("skill_return", true, "board")
	var hand_point: Vector2 = (_scene.call("_hand_card_global_rect", 0) as Rect2).get_center()
	_move(hand_point)
	await _record("hand_cursor", false, "hand")
	_move(FIXTURE_HUD_POINT)
	await _record("hud_cursor", false, "HUD")
	_move(board_point)
	await _record("board_return", true, "board")
	var file := FileAccess.open(INT03_OUTPUT.path_join("states.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"size": [1920, 1080], "ui_scale": 1.0, "states": _states}, "\t") + "\n")
	if _capture != null: _capture.close()
	print("INT03 TARGETING PROBE: %s (%d states; %s)" % ["FAIL" if _proof_failed else "PASS", _states.size(), "headless semantics only" if _validate_only else "native renderer"])
	print(ProjectSettings.globalize_path(INT03_OUTPUT))
	quit(1 if _proof_failed else 0)

func _move(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	if _capture != null: _capture.route(motion)
	else: _game_viewport.push_input(motion, true)

func _record(state: String, expected_arrow: bool, location: String) -> void:
	await process_frame
	await process_frame
	var arrow: Control = _scene.get("_drag_target_arrow")
	var suppressed: bool = bool(root.get_node("CursorFeedback").call("glyph_visibility_suppressed"))
	var shown: bool = arrow != null and arrow.visible
	var valid: bool = shown == expected_arrow and suppressed == expected_arrow
	_states.append({"state": state, "pointer_location": location, "arrow": shown, "cursor_suppressed": suppressed, "ok": valid, "selected": _scene.get("_selected_card_index"), "pointer": str(_game_viewport.get_mouse_position()), "cached_pointer": str(_scene.get("_card_targeting_pointer_position")), "tile": str(_scene.call("_drag_board_tile_at", _game_viewport.get_mouse_position())), "targeting": _scene.call("_targeted_card_aiming_active")})
	if not valid:
		_proof_failed = true
		push_error("int-03 targeting ownership: " + state)
	if _validate_only: return
	await RenderingServer.frame_post_draw
	var image: Image = _game_viewport.get_texture().get_image()
	if image == null or image.get_size() != PROBE_VIEWPORT:
		_proof_failed = true
		push_error("int-03 proof requires native 1920x1080 pixels")
		return
	var path: String = INT03_OUTPUT.path_join(state + ".png")
	if image.save_png(path) != OK:
		_proof_failed = true
		push_error("int-03 capture could not save " + path)
	print(ProjectSettings.globalize_path(path))

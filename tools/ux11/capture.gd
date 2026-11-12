extends SceneTree

## The same real-scene fixture and measurements run against release and candidate.
## Windowed mode alone emits renderer proof; --headless-check never captures.
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Router = preload("res://scripts/input_router.gd")
const CelLook = preload("res://scripts/cel_look.gd")
const SIZES = [Vector2i(1920, 1080), Vector2i(1920, 1200), Vector2i(1280, 800)]
const SETTLE_FRAME_LIMIT: int = 240 # Probe-only readiness deadline.
const SETTLE_SECONDS: float = 0.5 # Let authored entry/hand motion finish.
const OUTPUT_DEFAULT: String = "/private/tmp/labyrinth_codex/ux-11/candidate"
var _viewport: SubViewport
var _scene: Control
var _failed: bool = false
var _rows: Array[Dictionary]
var _output: String
var _headless: bool
var _candidate: bool

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_headless = OS.get_cmdline_user_args().has("--headless-check")
	_candidate = OS.get_cmdline_user_args().has("--candidate")
	_output = _arg("--output-dir", OUTPUT_DEFAULT)
	if not _headless and DisplayServer.get_name() == "headless":
		_check(false, "Renderer proof requires a windowed run")
		quit(1)
		return
	if not _headless:
		_check(OS.get_environment("LABYRINTH_CEL_LOOK") == "all", "Capture requires the approved cel look")
	if OS.get_environment("LABYRINTH_CEL_LOOK") == "all":
		_check(CelLook.mode == "all" and not CelLook._files.is_empty() and not CelLook._warned, "Approved cel variants are loaded without fallback")
	var fixture_path: String = _arg("--fixture-save", "")
	var state: Dictionary = Store._load_run_dictionary(fixture_path)
	if state.is_empty() or str(state.get("inspection_fixture", {}).get("scenario", "")) != "combat":
		_check(false, "Use the verified inspection_fixture.py --scenario combat save")
		quit(1)
		return
	Store.set_storage_path("user://ux11_progression.json")
	Store.set_run_storage_path("user://ux11_run.save")
	Store.save_data(state.get("progression", Store.default_data()))
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.apply_settings(settings, null, false)
	root.get_node("InputRouter").set_forced_state_for_test(Router.MODALITY_POINTER, Router.FAMILY_XBOX)
	DirAccess.make_dir_recursive_absolute(_output)
	for size: Vector2i in SIZES:
		await _size_case(size, state)
	if OS.get_environment("LABYRINTH_CEL_LOOK") == "all":
		_check(not CelLook._warned, "Every requested cel variant exists")
	var report := {"renderer": not _headless, "ui_scale": 1.0, "rows": _rows, "ok": not _failed}
	var file: FileAccess = FileAccess.open(_output.path_join("measurements.json"), FileAccess.WRITE)
	_check(file != null, "Measurement report opens")
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print(_output)
	print("UX11 %s RESULT: %s" % ["HEADLESS" if _headless else "CAPTURE", "FAIL" if _failed else "PASS"])
	quit(1 if _failed else 0)

func _size_case(size: Vector2i, state: Dictionary) -> void:
	_viewport = SubViewport.new()
	_viewport.size = size
	_viewport.msaa_2d = Viewport.MSAA_4X
	_viewport.world_2d = World2D.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_viewport.add_child(_scene)
	await _settle()
	_scene.call("_load_run_state", state.duplicate(true))
	_scene.call("_close_dialogue")
	await _settle()
	if _candidate:
		_check(bool(_scene.call("_compact_board_layout")) == (size == Vector2i(1280, 800)), "%s compact decision" % size)
	await _record(size, "idle")
	var hand: Array = (_scene.get("_combat_state") as Dictionary).get("deck", {}).get("hand", [])
	var card_index: int = hand.find("dull_bolt")
	_check(card_index >= 0, "Fixture must contain Dull Bolt")
	await _scene.call("_on_card_pressed", card_index)
	var targets: Array = _scene.get("_pending_target_tiles")
	var aimed: bool = false
	for enemy: Dictionary in (_scene.get("_combat_state") as Dictionary).get("enemies", []):
		var tile: Vector2i = enemy.get("pos", Vector2i(-1, -1))
		if not targets.has(tile): continue
		var board: Control = _scene.get("board_view")
		var point: Vector2 = board.get_global_transform_with_canvas() * (board.call("world_position_for_tile", tile) as Vector2)
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		_viewport.push_input(motion, true)
		_scene.call("_sync_click_targeting_arrow", point)
		aimed = true
		break
	_check(aimed and bool(_scene.call("_board_targeting_active")), "Dull Bolt really aims at a legal foe")
	await _settle()
	await _record(size, "dull_bolt_aim")
	if _candidate: _check_drag_and_rotation_pose(size)
	_scene.call("_on_cancel_requested")
	await _settle()
	if _candidate:
		var surface: RefCounted = _scene.get("_surface_aim")
		surface.call("begin", "prismatic_instinct", false)
		_scene.call("_apply_controller_hand_layout")
		_check(bool(_scene.call("_board_targeting_active")), "Surface aim uses board targeting")
		_check_pointer_envelope(size, "surface aim")
		surface.call("cancel")
	_scene.call("_begin_player_movement_selection")
	await _settle()
	_check(bool(_scene.get("_player_movement_selected")), "Hero movement is selected")
	await _record(size, "hero_movement")
	if _candidate: await _check_handoffs_and_resize(size)
	_viewport.queue_free()
	await process_frame

func _check_pointer_envelope(size: Vector2i, context: String) -> void:
	var compact: bool = size == Vector2i(1280, 800)
	var row: Control = _scene.get("hand_row")
	var margin: Control = _scene.get("hand_tuck_margin")
	_check(row.custom_minimum_size.y == (_scene.CONTROLLER_UNFOCUSED_HAND_ROW_HEIGHT if compact else _scene.DESKTOP_HAND_ROW_HEIGHT), context + " keeps the output's row height")
	_check(margin.get_theme_constant("margin_top") == (_scene.CONTROLLER_UNFOCUSED_HAND_TOP_MARGIN if compact else 0), context + " keeps the output's tuck margin")

func _check_drag_and_rotation_pose(size: Vector2i) -> void:
	var index: int = _scene.get("_selected_card_index")
	var fan: Control = _scene.get("hand_box")
	_scene.set("_drag_card_index", index)
	_scene.set("_drag_targeting_active", true)
	_scene.call("_apply_controller_hand_layout")
	_scene.call("_set_drag_hand_targeting_pose")
	_check_pointer_envelope(size, "drag aim")
	_check(fan.emphasized_index() == (-1 if size == Vector2i(1280, 800) else index), "Drag pose retains pre-ux10 desktop emphasis and compact suppression")
	_scene.set("_drag_card_index", -1)
	_scene.set("_drag_targeting_active", false)
	var targets: Array[Vector2i]
	targets.assign(_scene.get("_pending_target_tiles"))
	var no_targets: Array[Vector2i]
	_scene.set("_pending_orientation_target_tile", targets[0])
	_scene.set("_pending_target_tiles", no_targets)
	_scene.call("_apply_controller_hand_layout")
	_check(bool(_scene.call("_orientation_pending")) and bool(_scene.call("_board_targeting_active")), "Rotation stays a real targeting path without tile candidates")
	_check_pointer_envelope(size, "rotation")
	_scene.set("_pending_target_tiles", targets)
	_scene.set("_pending_orientation_target_tile", Vector2i(-1, -1))
	_scene.set("_pointer_hand_tucked", true)
	_scene.call("_apply_controller_hand_layout")
	_scene.call("_set_clicked_card_selection_pose")
	_check(fan.emphasized_index() == -1, "Explicit pointer tuck retains targeting lift suppression")
	_scene.set("_pointer_hand_tucked", false)
	_scene.call("_apply_controller_hand_layout")
	_scene.call("_set_clicked_card_selection_pose")

func _settle() -> void:
	await create_timer(SETTLE_SECONDS).timeout
	for frame: int in range(SETTLE_FRAME_LIMIT):
		await process_frame
		if _scene == null: continue
		var budget: RefCounted = _scene.get("_board_hud_budget")
		if int(_scene.get("_hand_layout_pending_revision")) < 0 and budget.get("key") == budget.call("environment", _scene):
			await process_frame
			return
	_check(false, "Hand and frozen HUD budget settle before measurement")

func _record(size: Vector2i, state: String) -> void:
	var row: Control = _scene.get("hand_row")
	var margin: Control = _scene.get("hand_tuck_margin")
	var board: Control = _scene.get("board_view")
	var fit: Rect2 = _scene.call("_board_fit_rect")
	var top: float = row.get_global_rect().position.y
	var visible: int = 0
	for index: int in range((_scene.get("hand_box") as Control).get_child_count()):
		var card: Control = _scene.call("_hand_card_control", index)
		if card != null and card.is_visible_in_tree() and _scene.call("_control_visual_global_rect", card).intersects(Rect2(Vector2.ZERO, Vector2(size))):
			visible += 1
	var drawn := Rect2()
	var below: bool = false
	# Production draw rectangles include floor diamonds, props and visible bodies.
	# Exclude unit HUD labels: the requested overlap concerns diamonds and bodies.
	for local: Rect2 in board.call("rendered_visual_rects", false):
		var rect: Rect2 = board.get_global_transform_with_canvas() * local
		drawn = rect if not drawn.has_area() else drawn.merge(rect)
		below = below or rect.end.y > top
	var values := {"size": "%dx%d" % [size.x, size.y], "state": state,
		"hand_top_y": top, "visible_card_count": visible,
		"hand_row_height": row.custom_minimum_size.y, "tuck_margin": margin.get_theme_constant("margin_top"),
		"tile_width": board.call("_tile_width"), "fit_rect": [fit.position.x, fit.position.y, fit.size.x, fit.size.y],
		"drawn_top_y": drawn.position.y, "drawn_bottom_y": drawn.end.y,
		"bound_below_hand": below}
	_rows.append(values)
	print("UX11 MEASUREMENT " + JSON.stringify(values))
	if _candidate:
		if size != Vector2i(1280, 800):
			_check(row.custom_minimum_size.y == _scene.DESKTOP_HAND_ROW_HEIGHT and margin.get_theme_constant("margin_top") == 0, "Desktop pointer keeps its full untucked row during " + state)
			_check(fit.end.y <= top - _scene.get("_board_hud_budget").HAND_BOTTOM_GAP, "Desktop fit clears the real hand row during " + state)
			_check(not below, "Desktop drawn diamonds/bodies clear the hand during " + state)
			if state == "dull_bolt_aim":
				_check(int(_scene.get("hand_box").emphasized_index()) == int(_scene.get("_selected_card_index")), "Desktop clicked card keeps pre-ux10 lift")
		elif state != "idle":
			_check(row.custom_minimum_size.y == _scene.CONTROLLER_UNFOCUSED_HAND_ROW_HEIGHT, "Compact targeting keeps its collapsed row")
	if not _headless:
		await RenderingServer.frame_post_draw
		var image: Image = _viewport.get_texture().get_image()
		_check(image != null and image.get_size() == size, "Exact-size SubViewport capture")
		if image != null:
			_check(image.save_png(_output.path_join("%dx%d_%s.png" % [size.x, size.y, state])) == OK, "Capture saves")

func _check_handoffs_and_resize(size: Vector2i) -> void:
	var before: Rect2 = _scene.call("_board_fit_rect")
	var board: Control = _scene.get("board_view")
	var width: float = board.call("_tile_width")
	var origin: Vector2 = board.call("_board_origin")
	root.get_node("InputRouter").set_forced_state_for_test(Router.MODALITY_CONTROLLER, Router.FAMILY_XBOX)
	_scene.call("_controller_set_hand_focused", false)
	await _settle()
	_check((_scene.get("hand_row") as Control).custom_minimum_size.y == _scene.CONTROLLER_UNFOCUSED_HAND_ROW_HEIGHT, "Desktop controller still tucks")
	_check(before == _scene.call("_board_fit_rect"), "Device handoff never changes the frozen fit")
	_check(width == board.call("_tile_width") and origin == board.call("_board_origin"), "Device handoff never reframes the board")
	root.get_node("InputRouter").set_forced_state_for_test(Router.MODALITY_POINTER, Router.FAMILY_XBOX)
	_scene.set("_pointer_hand_tucked", true)
	_scene.call("_apply_controller_hand_layout")
	_check((_scene.get("hand_row") as Control).custom_minimum_size.y == _scene.CONTROLLER_UNFOCUSED_HAND_ROW_HEIGHT, "Explicit pointer tuck survives")
	_scene.set("_pointer_hand_tucked", false)
	_scene.call("_apply_controller_hand_layout")
	await _settle()
	_check(before == _scene.call("_board_fit_rect"), "Pointer tuck never changes the frozen fit")
	_check(width == board.call("_tile_width") and origin == board.call("_board_origin"), "Pointer handoff never reframes the board")
	# Re-capture on a tucked desktop start must measure the full row and restore.
	if size != Vector2i(1280, 800):
		root.get_node("InputRouter").set_forced_state_for_test(Router.MODALITY_CONTROLLER, Router.FAMILY_XBOX)
		_scene.call("_controller_set_hand_focused", false)
		var budget: RefCounted = _scene.get("_board_hud_budget")
		budget.set("key", [])
		_scene.call("_freeze_board_hud_budget")
		_check(before == _scene.call("_board_fit_rect"), "Desktop capture while tucked measures the same full row")
		_check((_scene.get("hand_row") as Control).custom_minimum_size.y == _scene.CONTROLLER_UNFOCUSED_HAND_ROW_HEIGHT, "Measurement restores controller tuck")
		root.get_node("InputRouter").set_forced_state_for_test(Router.MODALITY_POINTER, Router.FAMILY_XBOX)
		_scene.set("_pointer_hand_tucked", false)
	_viewport.size = Vector2i(1920, 1080) if size == Vector2i(1280, 800) else Vector2i(1280, 800)
	_scene.call("_apply_controller_hand_layout")
	await _settle()
	_check(bool(_scene.call("_compact_board_layout")) == (size != Vector2i(1280, 800)), "Output resize re-decides compact layout")

func _check(condition: bool, message: String) -> void:
	if condition: return
	_failed = true
	push_error(message)
	print("UX11 ASSERTION FAIL: " + message)

func _arg(flag: String, fallback: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find(flag)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else fallback

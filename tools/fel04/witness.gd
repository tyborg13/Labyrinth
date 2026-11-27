extends SceneTree
## Resumes the director's saved fights and checks live effects-layer badges.

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Checkpoint = preload("res://tools/fel01/checkpoint.gd")
const Settings = preload("res://scripts/settings_store.gd")
const TileTooltip = preload("res://scripts/board_tile_tooltip.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Report = preload("res://tools/fel04/mark_witness.gd")

const RUN_SCENE = "res://scenes/run_scene.tscn"
const FIXTURE_ROOT = "res://tools/fel04/fixtures"
const FIXTURES = ["01-s1-seed1-1-8_0-t13", "04-s0-seed1-0-4_0-t9", "10-s2-seed8-2-10_-2-t16"]
const SETTLE_SECONDS: float = 0.35
const NATIVE_ENTRANCE_FRAMES: int = 90
const NATIVE_ENTRANCE_SECONDS: float = 2.0
const HOVER_SECONDS: float = 1.5
const CONTROL_FIXTURE: String = "01-s1-seed1-1-8_0-t13"
const NO_POINTER := Vector2(-1, -1)
const MARKED_HOVERS := {
	"04-s0-seed1-0-4_0-t9": Vector2i(2, 3),
	"10-s2-seed8-2-10_-2-t16": Vector2i(4, 2),
}

var _viewport: SubViewport
var _capture_dir: String
var _headless: bool

func _initialize() -> void:
	Runtime.apply_from_environment()
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	_run.call_deferred()

func _run() -> void:
	if _headless and OS.get_cmdline_user_args().has("--edge"):
		quit(await Report.edge_probe(self))
		return
	_capture_dir = OS.get_environment("FEL04_CAPTURE_DIR")
	if not _headless and not DirAccess.dir_exists_absolute(_capture_dir):
		push_error("FEL04 CAPTURE FAIL missing capture directory")
		quit(1)
		return
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.set_storage_path("user://fel04_capture_settings.json")
	if not Settings.save_settings(settings):
		push_error("FEL04 WITNESS FAIL could not save isolated settings")
		quit(1)
		return
	var failures: PackedStringArray
	for id: String in FIXTURES:
		if not await _fixture(id): failures.append(id)
	var mode: String = "WITNESS" if _headless else "CAPTURE"
	if failures.is_empty():
		print("FEL04 %s PASS states=%d" % [mode, FIXTURES.size()])
	else:
		printerr("FEL04 %s FAIL states=%d fixtures=%s" % [mode, FIXTURES.size(), ",".join(failures)])
	quit(0 if failures.is_empty() else 1)

func _fixture(id: String) -> bool:
	var source: String = FIXTURE_ROOT.path_join(id)
	var staged: String = ProjectSettings.globalize_path("user://fel04_work").path_join(id)
	if not Checkpoint.stage(source, staged): return _fail(id + " could not stage save")
	_viewport = SubViewport.new()
	_viewport.size = Checkpoint.VIEWPORT_SIZE
	_viewport.msaa_2d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.gui_embed_subwindows = true
	root.add_child(_viewport)
	_viewport.notify_mouse_entered()
	root.get_node("InputRouter").call("set_forced_state_for_test", "pointer", "xbox")
	root.set_meta("labyrinth_resume_saved_run", true)
	var scene: Node = (load(RUN_SCENE) as PackedScene).instantiate()
	_viewport.add_child(scene)
	_point(NO_POINTER)
	await create_timer(SETTLE_SECONDS).timeout
	await process_frame
	await process_frame
	if not _headless:
		for frame: int in range(NATIVE_ENTRANCE_FRAMES): await process_frame
		await create_timer(NATIVE_ENTRANCE_SECONDS).timeout
	var centering: Tween = scene.get("_board_centering_tween")
	while centering != null and centering.is_valid() and centering.is_running(): await process_frame
	var passed: bool = await _check_fixture(scene, id, source)
	root.get_node("InputRouter").call("clear_forced_state_for_test")
	_viewport.queue_free()
	await process_frame
	return passed

func _check_fixture(scene: Node, id: String, source: String) -> bool:
	if not scene.call("has_installed_run"): return _fail(id + " production Continue did not install a run")
	var differences: Dictionary = Checkpoint.compare(scene, source)
	if not differences.is_empty(): return _fail(id + " Continue changed " + ", ".join(differences.keys()))
	var board: Control = scene.get("board_view")
	var proof: Dictionary = Report.inspect(board)
	var passed: bool = proof["anchors_match"] and proof["all_tile_tooltips"]
	print("FEL04 %s %s groups=%d medallions=%d anchors=%s expected=%s all_tile_tooltips=%s" % [
		"PASS" if passed else "FAIL", id, proof["groups"], proof["medallions"], proof["anchors"],
		proof["expected"], proof["all_tile_tooltips"],
	])
	if not passed: return false
	if scene.get("_animation_lock") or scene.get("_selected_card_index") != -1 or (scene.get("_hovered_board_tile") as Vector2i).x >= 0:
		return _fail(id + " is not at rest")
	if not _headless and not await _capture(id + "-rest.png"): return false
	var control: bool = id == CONTROL_FIXTURE and proof["groups"] == 0
	var hover: Dictionary = _control_hover(board) if control else _marked_hover(scene, board, id, proof["anchors"])
	if hover.is_empty(): return _fail(id + " has no verified tile for the hover frame")
	var tile: Vector2i = hover["tile"]
	_point(board.get_global_transform_with_canvas() * board._tile_center(tile))
	await create_timer(HOVER_SECONDS).timeout
	var popup: Window = _popup(board)
	var mouse_entries: Array[Dictionary] = _popup_entries(popup)
	var expected: Array[Dictionary] = hover["mouse"]
	var intent: String = hover.get("intent", "")
	var showing: bool = _intent_label_showing(board, intent)
	if (scene.get("_hovered_board_tile") != tile or mouse_entries != expected
		or (popup == null) != expected.is_empty() or (not control and not showing)):
		return _fail("%s mouse=%s expected=%s popup=%s intent_showing=%s" %
			[id, _titles(mouse_entries), _titles(expected), popup != null, showing])
	print("FEL04 HOVER PASS %s tile=%s popup=%s intent=%s" % [id, tile, _titles(mouse_entries), intent])
	if not _headless: return await _capture(id + "-hover.png")
	if not await _check_focus(scene, board, id, hover): return false
	if expected == hover["focus"]: return true
	# The current pointer route can resolve a neighboring Outcrop canvas.
	# Also focus an Outcrop with that same tile stack to check route parity.
	for terrain: Dictionary in board.combat_state.get("terrain", []):
		var terrain_tile: Vector2i = terrain["pos"]
		if TileTooltip.decode(board.controller_tooltip_for_tile(terrain_tile)) != expected: continue
		return await _check_focus(scene, board, id, {"tile": terrain_tile, "focus": expected, "intent": intent})
	return _fail(id + " pointer stack did not match a focusable terrain square")

func _marked_hover(scene: Node, board: Control, id: String, anchors: Dictionary) -> Dictionary:
	var tile: Vector2i = MARKED_HOVERS[id]
	if anchors.has(tile):
		_fail(id + " hover target is an anchor")
		return {}
	var badges: Array[Dictionary] = Report.badge_regions(board, anchors)
	if badges.size() != 1:
		_fail(id + " missing its unique retained badge tooltip")
		return {}
	var text: String = badges[0]["tooltip"]
	var standing_line: String = Report.STANDING_LINE
	if not text.ends_with(standing_line):
		_fail(id + " hero stands in the group but the badge has no standing line")
		return {}
	var expected: Dictionary = TileTooltip.from_text(text.trim_suffix(standing_line), "marked")
	var hero_expected: Dictionary = TileTooltip.from_text(text, "marked")
	var generic: Dictionary = TileTooltip.from_text(Icons.tooltip("marked"), "marked")
	var mouse: String = board._get_tooltip(board._tile_center(tile))
	var mouse_entries: Array[Dictionary] = TileTooltip.decode(mouse)
	var hero: Vector2i = board.combat_state["player"]["pos"]
	var hero_detail: String = board.controller_tooltip_for_tile(hero)
	var candidate: Dictionary = scene.call("_controller_candidate_for_tile", tile)
	var hero_candidate: Dictionary = scene.call("_controller_candidate_for_tile", hero)
	var focused_entries: Array[Dictionary] = TileTooltip.decode(str(candidate.get("detail_key", "")))
	var mouse_match: bool = _mark_entry(mouse_entries) == expected and not mouse_entries.has(generic)
	var hero_match: bool = _mark_entry(TileTooltip.decode(hero_detail)) == hero_expected
	var focus_match: bool = _mark_entry(focused_entries) == expected and hero_candidate.get("detail_key") == hero_detail
	if not mouse_match or not hero_match or not focus_match:
		_fail("%s mark stack mouse=%s hero=%s focus=%s expected=%s mouse_entries=%s" %
			[id, mouse_match, hero_match, focus_match, expected, mouse_entries])
		return {}
	# The current pointer router can resolve a neighboring sprite even though
	# both square stacks use the same Marked entry.
	if _intent_label_showing(board, expected["title"]):
		_fail(id + " source intent is already showing before inspection")
		return {}
	print("FEL04 UNEXPANDED PASS %s tile=%s entry=%s" % [id, tile, expected["title"]])
	return {"tile": tile, "mouse": _without_mark(mouse_entries),
		"focus": _without_mark(focused_entries), "intent": expected["title"]}

func _without_mark(entries: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for entry: Dictionary in entries:
		if entry["icon"] != "marked": result.append(entry)
	return result

func _check_focus(scene: Node, board: Control, id: String, hover: Dictionary) -> bool:
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "controller", "xbox")
	scene.set("_controller_region", "board")
	scene.call("_controller_set_board_tile", hover["tile"])
	await create_timer(SETTLE_SECONDS).timeout
	var candidate: Dictionary = scene.get("_controller_focus_candidate")
	var entries: Array[Dictionary] = TileTooltip.decode(str(candidate.get("detail_key", "")))
	var expected: Array[Dictionary] = hover["focus"]
	var intent: String = hover.get("intent", "")
	var cursor: Control = scene.get("_controller_analog_cursor")
	var panel: Control = cursor.get("_detail_panel")
	var empty_guard: bool = board._make_custom_tooltip("") == null and board._make_custom_tooltip(TileTooltip.PREFIX + "[]") == null
	var showing: bool = _intent_label_showing(board, intent)
	var passed: bool = (
		candidate.get("tile") == hover["tile"] and entries == expected and empty_guard
		and (panel == null or not panel.visible) == expected.is_empty()
		and (intent.is_empty() or showing)
	)
	router.call("clear_forced_state_for_test")
	if not passed:
		return _fail("%s focus=%s expected=%s panel_visible=%s intent_showing=%s empty_guard=%s" %
			[id, _titles(entries), _titles(expected), panel != null and panel.visible, showing, empty_guard])
	print("FEL04 FOCUS PASS %s tile=%s popup=%s intent=%s empty_guard=%s" %
		[id, hover["tile"], _titles(entries), intent, empty_guard])
	return true

func _intent_label_showing(board: Control, title: String) -> bool:
	if title.is_empty(): return false
	for entry: Dictionary in board.get("_hud_layout_entries_cache"):
		var layout: Dictionary = entry.get("layout", {})
		if layout.get("intent_name") == title and not (layout.get("rows", []) as Array).is_empty():
			return (layout["intent_rect"] as Rect2).has_area()
	return false

func _titles(entries: Array[Dictionary]) -> PackedStringArray:
	var result: PackedStringArray
	for entry: Dictionary in entries: result.append(str(entry["title"]))
	return result

func _mark_entry(entries: Array[Dictionary]) -> Dictionary:
	for entry: Dictionary in entries:
		if entry["icon"] == "marked": return entry
	return {}

func _control_hover(board: Control) -> Dictionary:
	for tile: Vector2i in board._rendered_tiles_in_draw_order():
		var entries: Array[Dictionary] = TileTooltip.decode(board._get_tooltip(board._tile_center(tile)))
		if _titles(entries) == PackedStringArray(["Ice"]): return {"tile": tile, "mouse": entries, "focus": entries}
	return {}

func _point(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = position - _viewport.get_mouse_position()
	_viewport.push_input(event, true)

func _popup(node: Node) -> Window:
	for child: Node in node.get_children():
		if child is Window and child.visible and child.theme_type_variation == &"TooltipPanel":
			return child
		var found: Window = _popup(child)
		if found != null: return found
	return null

func _popup_entries(popup: Window) -> Array[Dictionary]:
	var entries: Array[Dictionary]
	if popup == null: return entries
	for child: Node in popup.get_children():
		if not child.has_meta("tile_tooltip_stack"): continue
		for panel: Node in child.get_children():
			entries.append(panel.get_meta("tile_tooltip_entry", {}))
	return entries

func _capture(filename: String) -> bool:
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	if image == null or image.get_size() != Checkpoint.VIEWPORT_SIZE:
		return _fail(filename + " image size differs from 1920x1080")
	var path: String = _capture_dir.path_join(filename)
	if image.save_png(path) != OK: return _fail("cannot write " + path)
	print(path)
	return true

func _fail(message: String) -> bool:
	printerr("FEL04 PROOF FAIL " + message)
	return false

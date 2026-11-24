extends "res://tests/pre_battle_fixture.gd"

const BookData = preload("res://scripts/grimoire_library.gd")
const Fight = preload("res://tests/suites/sta01_mechanics_suite.gd")
const Router = preload("res://scripts/input_router.gd")
const Scroll = preload("res://tools/txt38/list_scroll.gd")
const Typography = preload("res://scripts/ui_typography.gd")

const PAGES: Dictionary = {
	"vyraketh": "Each Cinder Mark on Fire: Burst 8",
	"ashen_reaver": "Move 2 · Melee 6 · Range 2 · Push 1 · Fire · Area",
	"gloam_stalker": "Blink 4",
}
const AREA_TOOLTIP: String = "Deal 6 damage in this attack's area."
const CAPTURE_SIZE := Vector2i(1920, 1080)
const FIGHT_ENEMY: String = "warden"
const FIGHT_MOVE: String = "crushing_step"
const PROBE_HOVER_SECONDS: float = 2.0
const HIT_SAMPLE_STEP: int = 3
const ACTOR_KEY: String = "enemy_1"
var _output: String
var _headless: bool
var _capture_count: int

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_output = OS.get_environment("TXT41_OUTPUT")
	_headless = DisplayServer.get_name() == "headless"
	var path: String = OS.get_environment("TXT41_GRIMOIRE")
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or not _output.is_absolute_path():
		_fail("Provide the local Grimoire override and an absolute output directory")
		quit(1)
		return
	BookData._cache = JSON.parse_string(file.get_as_text())
	_setup()
	_viewport.gui_embed_subwindows = true
	_expect(_viewport.size == CAPTURE_SIZE, "Capture viewport is exactly 1920x1080")
	var settings: Dictionary = Settings.default_settings()
	settings["reduced_motion"] = true
	Settings.apply_settings(settings, null, false)
	var router: Node = root.get_node("InputRouter")
	router.set_forced_state_for_test(Router.MODALITY_POINTER, Router.FAMILY_XBOX)
	var scene: Node = await _instance(_run_with_available_combat(RunEngine.new()))
	scene._close_large_map()
	await _pages(scene)
	await _fight(scene)
	router.clear_forced_state_for_test()
	_viewport.queue_free()
	await process_frame
	print("TXT41 NATIVE PROBE: %s (%s, %d capture states)" %
		["FAIL" if _failed else "PASS", "headless" if _headless else "native", _capture_count])
	quit(int(_failed))

func _pages(scene: Node) -> void:
	var ids: Array = BookData.entries().filter(func(entry: Dictionary) -> bool: return entry.get("section") == "creatures") \
		.map(func(entry: Dictionary) -> String: return entry["id"])
	_expect(ids.size() == 44, "Creature navigation uses the 44-page override")
	scene._run_state = BookData.unlock_entries(scene._run_state, ids)["state"]
	scene._on_grimoire_button_pressed()
	var book: Control = scene._grimoire_scrim
	await Scroll.settle(self)
	_expect(is_equal_approx(Typography.ui_scale(book), 1.0), "Capture uses 100% UI scale")
	for enemy_id: String in PAGES:
		var page_id: String = "enemy:" + enemy_id
		# Selection calls the same handler as a list row. Keep the capture
		# independent of the pointer scroll behavior measured above.
		book._on_grimoire_entry_pressed(page_id)
		await Scroll.settle(self)
		var moves: Control = book.find_child("GrimoireMoves", true, false)
		var scroll: ScrollContainer = book._grimoire_detail_scroll
		scroll.scroll_vertical = ceili(scroll.get_v_scroll_bar().max_value)
		await Scroll.settle(self)
		var found: bool = false
		for label: Node in moves.find_children("*", "RichTextLabel", true, false):
			if not label.get_parsed_text().contains(PAGES[enemy_id]): continue
			found = scroll.get_global_rect().grow(1.0).encloses(label.get_global_rect())
			break
		_expect(found, page_id + " exposes the full expected Moves line in the capture")
		await _save(enemy_id + "_moves")
	book.close()

func _fight(scene: Node) -> void:
	var state: Dictionary = Fight.state(FIGHT_ENEMY, FIGHT_MOVE)
	var run_state: Dictionary = scene._run_state.duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room_layout"] = {"grid": state["grid"], "element": "none", "type": "combat"}
	run_state["combat_state"] = state
	await scene._load_run_state(run_state)
	scene._close_large_map()
	scene._close_dialogue()
	await _settle()
	var board: Control = scene.board_view
	var tile: Vector2i = state["enemies"][0]["pos"]
	await scene._on_board_tile_clicked(tile)
	await _settle()
	_expect(board.enemy_intent_tooltip(ACTOR_KEY).contains(AREA_TOOLTIP), "Live Crushing Step intent exposes the corrected tooltip")
	var rect: Rect2 = board.enemy_intent_visual_global_rect(ACTOR_KEY)
	_expect(rect.has_area(), "Crushing Step intent is expanded on the real combat board")
	var point: Vector2 = _tooltip_point(board, rect)
	_expect(point != Vector2.INF, "Crushing Step intent has a pointer region for the exact area damage tooltip")
	if point != Vector2.INF:
		await _pointer(point)
		_expect(_viewport.gui_get_hovered_control() == board, "Pointer reaches the combat board")
		if not _headless:
			await create_timer(PROBE_HOVER_SECONDS).timeout
			_expect(_visible_tooltip(board), "Native hover opens the real area damage tooltip")
	await _save("warden_crushing_step_hover")

func _tooltip_point(board: Control, rect: Rect2) -> Vector2:
	for y: int in range(ceili(rect.position.y), floori(rect.end.y), HIT_SAMPLE_STEP):
		for x: int in range(ceili(rect.position.x), floori(rect.end.x), HIT_SAMPLE_STEP):
			var point := Vector2(x, y)
			if board._get_tooltip(point - board.global_position).contains(AREA_TOOLTIP): return point
	return Vector2.INF

func _visible_tooltip(board: Control) -> bool:
	for child: Node in board.find_children("*", "", true, false):
		if child is RichTextLabel and child.is_visible_in_tree() and child.get_parsed_text().contains(AREA_TOOLTIP): return true
		if child is Label and child.is_visible_in_tree() and child.text.contains(AREA_TOOLTIP): return true
	return false

func _save(stem: String) -> void:
	var path: String = _output.path_join(stem + "_1920x1080.png")
	if _headless:
		print("WOULD CAPTURE " + path)
	else:
		await _capture(path)
		_expect(FileAccess.file_exists(path), "Capture exists at " + path)
		if FileAccess.file_exists(path): print(path)
	_capture_count += 1

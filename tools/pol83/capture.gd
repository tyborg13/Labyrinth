extends "res://tests/pre_battle_fixture.gd"
## Exercise the production hover regions and capture Godot's embedded popups.

const Fight = preload("res://tests/suites/sta01_mechanics_suite.gd")
const Guardians = preload("res://scripts/guardian_combat_rules.gd")
const Hoarder = preload("res://tools/hoarder_inspection.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const LoopView = preload("res://scripts/tooltip_loop_view.gd")
const Panels = preload("res://scripts/ui_tooltip_panel.gd")
const Router = preload("res://scripts/input_router.gd")
const Typography = preload("res://scripts/ui_typography.gd")

const UI_SCALE: float = 1.0
const CLEAR_POINTER := Vector2(1, 1)
const HIT_SAMPLE_STEP: int = 3
const HOVER_TIMEOUT_SECONDS: float = 6.0
# Reuse the txt-43 Craghide witness with one of its Outcrops remaining.
const CRAG_HERO := Vector2i(4, 3)
const CRAG_OUTCROP := Vector2i(5, 6)
const CRAG_OUTCROP_HEALTH: int = 1
const CAPTURE_COUNT: int = 4

var _output: String
var _headless: bool
var _captures: int

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_output = OS.get_environment("POL83_OUTPUT")
	_headless = DisplayServer.get_name() == "headless"
	if not _output.is_absolute_path() or OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		_fail("Set an absolute POL83_OUTPUT and LABYRINTH_CEL_LOOK=all")
		quit(1)
		return
	_setup()
	root.size = PROBE_VIEWPORT
	root.content_scale_size = PROBE_VIEWPORT
	root.content_scale_factor = UI_SCALE
	var input_router: Node = root.get_node("InputRouter")
	input_router.set_forced_state_for_test(Router.MODALITY_POINTER, Router.FAMILY_XBOX)
	var run_engine := RunEngine.new()
	var scene: Node = await _instance(run_engine.create_new_run(Hoarder.FIXTURE_SEED, ProgressionStore.default_data()))
	_viewport.gui_embed_subwindows = true
	_viewport.notify_mouse_entered()
	_expect(_viewport.size == PROBE_VIEWPORT and is_equal_approx(Typography.ui_scale(scene), UI_SCALE),
		"Capture viewport uses 1920x1080 at 100% UI scale")

	var combat: RefCounted = scene._combat_engine
	var crag: Dictionary = Fight.state("craghide", "groundsplit")
	crag["player"]["pos"] = CRAG_HERO
	crag["terrain"] = [{"id": 1, "pos": CRAG_OUTCROP, "hp": CRAG_OUTCROP_HEALTH,
		"max_hp": CRAG_OUTCROP_HEALTH, "kind": "crag_outcrop", "owner_id": crag["enemies"][0]["id"]}]
	crag["enemies"][0]["intent"] = Guardians.commit(combat, crag, 0, crag["enemies"][0]["intent"])
	await _load_fight(scene, crag)
	await _capture_chip(scene, "", "Outcrop", "craghide_groundsplit")

	await _load_fight(scene, Fight.state("warden", "bulwark"))
	await _capture_chip(scene, "", "All Allies", "warden_bulwark")

	_move(CLEAR_POINTER)
	var hoarder: Dictionary = Hoarder.build(run_engine, combat,
		run_engine.create_new_run(Hoarder.FIXTURE_SEED, ProgressionStore.default_data()), {})
	await scene._load_run_state(hoarder)
	scene._close_dialogue()
	await _settle()
	var hud: Control = scene.get("_battlefield_rule_hud")
	_expect(hud.is_visible_in_tree() and hud.get("rule_id") == Hoarder.Rules.PANEL_RULE_ID, "Hoarder HUD is live")
	await _capture_hover(hud, _center(hud), hud.tooltip_text, false, "hoarder_battlefield_rule")
	var menu: Control = scene.get("menu_button")
	_expect(menu.tooltip_text == "Menu", "Menu has a one-word title")
	await _capture_hover(menu, _center(menu), menu.tooltip_text, true, "menu_title")

	input_router.clear_forced_state_for_test()
	_viewport.queue_free()
	await process_frame
	_expect(_captures == CAPTURE_COUNT, "Every requested tooltip was reached")
	print("POL83 %s PROBE: %s (%d/%d hovers)" %
		["HEADLESS" if _headless else "NATIVE", "FAIL" if _failed else "PASS", _captures, CAPTURE_COUNT])
	quit(int(_failed))

func _load_fight(scene: Node, battle: Dictionary) -> void:
	_move(CLEAR_POINTER)
	var run_state: Dictionary = scene._run_state.duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room_layout"] = {"grid": battle["grid"], "element": "none", "type": "combat"}
	run_state["combat_state"] = battle
	await scene._load_run_state(run_state)
	scene._close_dialogue()
	await _settle()

func _capture_chip(scene: Node, icon: String, chip_copy: String, filename: String) -> void:
	var board: Control = scene.board_view
	var enemy: Dictionary = board.get("combat_state")["enemies"][0]
	var actor: String = "enemy_%d" % int(enemy["id"])
	await scene._on_board_tile_clicked(enemy["pos"])
	await _settle()
	var expected: String = ""
	for row: Array in board._own_move_rows_for_unit(enemy, enemy["intent"]):
		for token: Dictionary in row:
			if token.get("icon", "") != icon or not str(token.get("value", "")).contains(chip_copy): continue
			expected = str(token.get("display_tooltip", Icons.token_tooltip(token)))
			break
		if not expected.is_empty(): break
	var rect: Rect2 = board.enemy_intent_visual_global_rect(actor)
	var point: Vector2 = _chip_point(board, rect, expected)
	if point == Vector2.INF:
		_fail("%s tooltip has no live hit region for %s" % [filename, expected])
		return
	await _capture_hover(board, point, expected, false, filename)

func _chip_point(board: Control, bounds: Rect2, expected: String) -> Vector2:
	if expected.is_empty(): return Vector2.INF
	var local: Transform2D = board.get_global_transform_with_canvas().affine_inverse()
	var inset := Vector2(HIT_SAMPLE_STEP, HIT_SAMPLE_STEP)
	for y: int in range(ceili(bounds.position.y), floori(bounds.end.y), HIT_SAMPLE_STEP):
		for x: int in range(ceili(bounds.position.x), floori(bounds.end.x), HIT_SAMPLE_STEP):
			var point := Vector2(x, y)
			if board.get_tooltip(local * point) == expected and board.get_tooltip(local * (point + inset)) == expected:
				return point + inset
	return Vector2.INF

func _center(owner: Control) -> Vector2:
	return owner.get_global_transform_with_canvas() * (owner.size * 0.5)

func _capture_hover(owner: Control, point: Vector2, text: String, title: bool, filename: String) -> void:
	_move(CLEAR_POINTER)
	await process_frame
	_move(point)
	var timer: SceneTreeTimer = create_timer(HOVER_TIMEOUT_SECONDS)
	var popup: Window = _popup(owner)
	while timer.time_left > 0.0 and (popup == null or not _settled(popup)):
		await process_frame
		popup = _popup(owner)
	if popup == null or not _settled(popup):
		_fail("%s popup did not settle at %s (hovered %s)" % [filename, point, _viewport.gui_get_hovered_control()])
		return
	var bounds := Rect2(Vector2(popup.position), Vector2(popup.size))
	if not _viewport.get_visible_rect().encloses(bounds):
		_fail(filename + " tooltip is outside the viewport")
		return
	var labels: Array[Node] = popup.find_children("*", "Label", true, false)
	var expected: String = text.to_upper() if title else text
	var ink: Color = Panels.TITLE_COLOR if title else Panels.BODY_COLOR
	var font_size: int = Typography.SIZE_BODY_LARGE if title else Typography.SIZE_BODY
	if not (labels.size() == 1 and labels[0].text == expected and
			labels[0].get_theme_color("font_color") == ink and labels[0].get_theme_font_size("font_size") == font_size):
		_fail("%s must show exactly one %s label with %s" % [filename, "title" if title else "body", expected])
		return
	var path: String = _output.path_join(filename + "_1920x1080.png")
	if not _headless:
		await RenderingServer.frame_post_draw
		var frame: Image = _viewport.get_texture().get_image()
		if not is_instance_valid(popup) or _popup(owner) != popup or frame == null \
				or frame.get_size() != PROBE_VIEWPORT or frame.save_png(path) != OK:
			_fail("Could not capture the settled popup in " + path)
			return
	_captures += 1
	print("POL83 %s %s | %s | %s" % ["WOULD CAPTURE" if _headless else "CAPTURED", path,
		"title" if title else "body", JSON.stringify(expected)])

func _settled(popup: Window) -> bool:
	if popup.size.x <= 0 or popup.size.y <= 0: return false
	for loop: Node in popup.find_children("TooltipLoopWindow", "", true, false):
		if loop is LoopView and (loop.displayed_frame < 0 or loop._fade < LoopView.FADE_IN_SECONDS): return false
	return true

func _popup(owner: Control) -> Window:
	for popup: Window in _viewport.get_embedded_subwindows():
		if popup is PopupPanel and popup.visible and popup.theme_type_variation == &"TooltipPanel" \
				and popup.get_parent() == owner:
			return popup
	return null

func _move(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = point - _viewport.get_mouse_position()
	_viewport.push_input(event, true)

extends "res://tests/pre_battle_fixture.gd"

const Fight = preload("res://tests/suites/sta01_mechanics_suite.gd")
const Cases = preload("res://tools/txt43/forecast_cases.gd")
const Hover = preload("res://tools/txt43/native_hover.gd")
const Pages = preload("res://tools/txt43/native_pages.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Router = preload("res://scripts/input_router.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Guardians = preload("res://scripts/guardian_combat_rules.gd")
const Areas = preload("res://scripts/boss_area_rules.gd")

const CAPTURE_SIZE := Vector2i(1920, 1080)
const HIT_SAMPLE_STEP: int = 3
const ACTOR_KEY: String = "enemy_1"
const CLEAR_POINTER := Vector2(1, 1)
const HOOKWIND_LOOP: String = "pull_card"
const FIGHTS := [
	["arc_thrall", "arc_bolt", "ranged", "arc_thrall_arc_bolt", Icons.ENEMY_LIGHTNING_RELAY % 3],
	["gallows_roc", "hookwind", "pull", "gallows_roc_hookwind",
		"Move the target 2 tiles straight toward the source, causing a Collision if blocked."],
	["vaeloryx", "razor_dive", "marked", "vaeloryx_razor_dive", "Marked tiles show where this enemy will act."],
	["craghide", "groundsplit", "", "craghide_after_outcrop", Icons.ENEMY_MARKED_IMPACT],
]

var _output: String
var _capture_count: int

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_output = OS.get_environment("TXT43_OUTPUT")
	if not _output.is_absolute_path():
		_fail("Provide an absolute TXT43_OUTPUT directory")
		quit(1)
		return
	_setup()
	var settings: Dictionary = Settings.default_settings()
	settings["reduced_motion"] = true
	Settings.apply_settings(settings, null, false)
	var router: Node = root.get_node("InputRouter")
	router.set_forced_state_for_test(Router.MODALITY_POINTER, Router.FAMILY_XBOX)
	var scene: Node = await _instance(_run_with_available_combat(RunEngine.new()))
	_expect(_viewport.size == CAPTURE_SIZE and is_equal_approx(Typography.ui_scale(scene), 1.0), "Probe is 1920x1080 at 100%")
	for fixture: Array in FIGHTS:
		await _fight(scene, fixture)
	# The Grimoire pages are captured alone in the viewport (txt-37 pattern); the run scene would draw over them.
	scene.queue_free()
	await process_frame
	var page_count: int = await Pages.capture_all(_viewport, _output, _expect, _capture)
	_expect(page_count == Pages.PAGES.size(), "Every requested Grimoire page was reached")
	router.clear_forced_state_for_test()
	_viewport.queue_free()
	await process_frame
	_expect(_capture_count == FIGHTS.size(), "Every tooltip popup was reached")
	print("TXT43 NATIVE PROBE: %s (%s, %d combat hovers, %d Grimoire pages)" %
		["FAIL" if _failed else "PASS", DisplayServer.get_name(), _capture_count, page_count])
	quit(int(_failed))

func _fight(scene: Node, fixture: Array) -> void:
	Hover.move_pointer(_viewport, CLEAR_POINTER)
	await process_frame
	var engine: RefCounted = scene._combat_engine
	var state: Dictionary = Fight.state(fixture[0], fixture[1])
	if fixture[0] == "vaeloryx":
		state["enemies"][0]["footprint"] = Vector2i(2, 2)
	if fixture[0] == "craghide":
		state = Cases.destroy_outcrop(engine, Cases.crag(engine))
		var crag: Dictionary = state["enemies"][0]
		var outcrops: Array = Guardians.objects(state, "crag_outcrop", int(crag["id"]))
		_expect(outcrops.size() == 1, "Craghide capture opens immediately after the first Outcrop dies")
		print("TXT43 CRAG CAPTURE: remaining Outcrops=%d, displayed Marked tiles=%d" %
			[outcrops.size(), Areas.announced_tiles(crag, engine, state).size()])
	var run_state: Dictionary = scene._run_state.duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room_layout"] = {"grid": state["grid"], "element": "none", "type": "combat"}
	run_state["combat_state"] = state
	await scene._load_run_state(run_state)
	scene._close_large_map()
	scene._close_dialogue()
	await _settle()
	var board: Control = scene.board_view
	var enemy: Dictionary = state["enemies"][0]
	await scene._on_board_tile_clicked(enemy["pos"])
	await _settle()
	var expected: String = _chip_tooltip(board, enemy, fixture[2])
	var rect: Rect2 = board.enemy_intent_visual_global_rect(ACTOR_KEY)
	var point: Vector2 = _tooltip_point(board, rect, expected)
	_expect(not expected.is_empty() and point != Vector2.INF, fixture[1] + " chip has a native tooltip hit region")
	if expected.is_empty() or point == Vector2.INF: return
	var body: String = expected.get_slice("\n", 1) if "\n" in expected else expected
	_expect(body == fixture[4], fixture[1] + " popup has the witnessed tooltip copy")
	var path: String = _output.path_join(fixture[3] + "_1920x1080.png")
	if fixture == FIGHTS[0]: Hover.prepare(_viewport)
	var wait_for_loop: String = HOOKWIND_LOOP if fixture[1] == "hookwind" else ""
	var failure: String = await Hover.capture(board, point, fixture[4], path, wait_for_loop)
	_expect(failure.is_empty(), fixture[1] + ": " + failure)
	if failure.is_empty(): _capture_count += 1

func _chip_tooltip(board: Control, enemy: Dictionary, icon: String) -> String:
	for row: Array in board._own_move_rows_for_unit(enemy, enemy["intent"]):
		for token: Dictionary in row:
			if str(token.get("icon", "")) == icon: return str(token.get("display_tooltip", Icons.token_tooltip(token)))
	return ""

func _tooltip_point(board: Control, rect: Rect2, expected: String) -> Vector2:
	var to_local: Transform2D = board.get_global_transform_with_canvas().affine_inverse()
	for y: int in range(ceili(rect.position.y), floori(rect.end.y), HIT_SAMPLE_STEP):
		for x: int in range(ceili(rect.position.x), floori(rect.end.x), HIT_SAMPLE_STEP):
			var point := Vector2(x, y)
			if board.get_tooltip(to_local * point) != expected: continue
			var inset := Vector2(HIT_SAMPLE_STEP, HIT_SAMPLE_STEP)
			if board.get_tooltip(to_local * (point + inset)) == expected: return point + inset
	return Vector2.INF

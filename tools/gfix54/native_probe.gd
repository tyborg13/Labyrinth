extends "res://tests/pre_battle_fixture.gd"

const Fight = preload("res://tests/suites/sta01_mechanics_suite.gd")
const Router = preload("res://scripts/input_router.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const CardHover = preload("res://scripts/card_keyword_hover.gd")
const ConditionScan = preload("res://tools/gfix54/condition_scan.gd")
const NativeHover = preload("res://tools/gfix54/native_hover.gd")
const DrawClock = preload("res://tests/helpers/presentation_test_clock.gd")
const FocusWait = preload("res://tests/helpers/controller_card_focus_wait.gd")
const CARD_IDS: Array[String] = ["revealing_glare", "couched_lance"]
const CONDITION_TERMS: Array[String] = ["illuminate", "move"]
const CLEAR_POINTER := Vector2(4, 4)
const POINTER_SETTLE_RENDERED_FRAMES: int = 12
const ENEMY_ID: String = "warden"
const INTENT_ID: String = "crushing_step"
var _output: String
var _capture_count: int

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_output = OS.get_environment("GFIX54_OUTPUT")
	if not _output.is_absolute_path() or not DirAccess.dir_exists_absolute(_output):
		_fail("Use tools/gfix54/native.sh to provide a capture directory")
		quit(1)
		return
	_setup()
	NativeHover.prepare(_viewport)
	var settings: Dictionary = Settings.default_settings()
	settings["reduced_motion"] = true
	Settings.apply_settings(settings, null, false)
	var router: Node = root.get_node("InputRouter")
	router.set_forced_state_for_test(Router.MODALITY_POINTER, Router.FAMILY_XBOX)
	var state: Dictionary = Fight.state(ENEMY_ID, INTENT_ID)
	state["deck"]["hand"] = CARD_IDS.duplicate()
	var run: Dictionary = _run_with_available_combat(RunEngine.new())
	run["mode"] = "combat"
	run["current_room_layout"] = {"grid": state["grid"], "element": "none", "type": "combat"}
	run["combat_state"] = state
	var scene: Node = await _instance(run)
	scene._close_large_map()
	_expect(_viewport.size == PROBE_VIEWPORT and is_equal_approx(Typography.ui_scale(scene), 1.0),
		"Capture uses 1920x1080 at 100% UI scale")
	for index: int in range(CARD_IDS.size()):
		await _hover_condition(scene, index)
	NativeHover.move_pointer(_viewport, CLEAR_POINTER)
	await process_frame
	router.set_forced_state_for_test(Router.MODALITY_CONTROLLER, Router.FAMILY_XBOX)
	scene._controller_region = "hand"
	scene._controller_set_hand_focused(true)
	for index: int in range(CARD_IDS.size()):
		await _focus_card(scene, index)
	router.clear_forced_state_for_test()
	_viewport.queue_free()
	await process_frame
	_expect(_capture_count == CARD_IDS.size() * 2, "Reach both capture states for each card")
	print("GFIX54 NATIVE PROBE: %s (%s, %d capture states)" %
		["FAIL" if _failed else "PASS", DisplayServer.get_name(), _capture_count])
	quit(int(_failed))

func _hover_condition(scene: Node, index: int) -> void:
	NativeHover.move_pointer(_viewport, CLEAR_POINTER)
	await _settle()
	var card: CardWidget = scene._hand_card_control(index)
	_expect(card != null and card.card_id == CARD_IDS[index], "Find " + CARD_IDS[index] + " in the real hand")
	if card == null or card.card_id != CARD_IDS[index]: return
	_expect(not card.native_tooltips_enabled(), "The production hand defaults to the side stack")
	NativeHover.move_pointer(_viewport, _center(card.art_frame))
	await DrawClock.rendered_frames(self, POINTER_SETTLE_RENDERED_FRAMES)
	await _settle()
	var icon: TextureRect = ConditionScan.condition_icon(card, CONDITION_TERMS[index])
	_expect(icon != null, "Find the rendered condition icon on " + card.card_id)
	if icon == null: return
	var point: Vector2 = _center(icon)
	# Also exercise the native CardWidget query that could previously open an
	# icon popup. The live hand normally leaves this flag off.
	card.set_native_tooltips_enabled(true)
	var to_card: Transform2D = card.get_global_transform_with_canvas().affine_inverse()
	var native_tip: String = card.get_tooltip(to_card * point)
	NativeHover.move_pointer(_viewport, point)
	var popup_opened: bool = await _watch_for_popup()
	card.set_native_tooltips_enabled(false)
	var still_on_icon: bool = _viewport.gui_get_hovered_control() == card and point.is_equal_approx(_viewport.get_mouse_position()) \
		and Rect2(Vector2.ZERO, icon.size).has_point(icon.get_global_transform_with_canvas().affine_inverse() * point)
	_expect(still_on_icon and scene.hand_box.emphasized_index() == index, "Pointer rests on the icon and preserves card lift")
	_expect(native_tip.is_empty() and not popup_opened, "Condition hover opens no native popup")
	if still_on_icon and native_tip.is_empty() and not popup_opened:
		print("GFIX54 ICON HOVER %s: card emphasized, pointer on condition icon, no native popup" % card.card_id)
		await _save(card.card_id + "_condition_hover")

func _watch_for_popup() -> bool:
	var deadline: int = Time.get_ticks_msec() + NativeHover.POPUP_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		if NativeHover.has_visible_tooltip(_viewport) or NativeHover.has_visible_tooltip(root): return true
		await process_frame
	return NativeHover.has_visible_tooltip(_viewport) or NativeHover.has_visible_tooltip(root)

func _focus_card(scene: Node, index: int) -> void:
	scene._controller_set_hand_index(index)
	await FocusWait.settle(self, scene, _expect, CARD_IDS[index])
	await _settle()
	var card: CardWidget = scene._hand_card_control(index)
	_expect(card != null and card.card_id == CARD_IDS[index], "Controller focus retains the correct hand card")
	if card == null or card.card_id != CARD_IDS[index]: return
	var stack: Control = scene.get("_card_focus_tooltip_stack")
	var expected: Dictionary
	for entry: Dictionary in CardHover.entries_for(card):
		if entry["icon"] == CONDITION_TERMS[index]:
			expected = entry
			break
	_expect(not expected.is_empty(), "Focused card has the existing condition panel")
	if expected.is_empty(): return
	var present: bool = _stack_contains(stack, card, expected)
	_expect(present, "Focused " + card.card_id + " shows the exact condition panel on screen")
	if present:
		print("GFIX54 FOCUSED SIDE PANEL %s: %s" % [card.card_id, JSON.stringify({
			"title": expected["title"], "body": expected["description"],
		})])
		await _save(card.card_id + "_focused_side_panels")

func _stack_contains(stack: Control, card: CardWidget, expected: Dictionary) -> bool:
	if stack == null or not stack.is_visible_in_tree() or stack.get("_follow_target") != card: return false
	for panel: Control in stack.get_children():
		if panel.get_meta("semantic_key", "") != expected["semantic_key"]: continue
		if not panel.is_visible_in_tree() or not panel.get_global_rect().has_area() \
				or not _viewport.get_visible_rect().encloses(panel.get_global_rect()): return false
		var lines: PackedStringArray = NativeHover.visible_text(panel).split("\n")
		return lines.has(str(expected["title"]).to_upper()) and lines.has(expected["description"])
	return false

static func _center(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * 0.5)

func _save(stem: String) -> void:
	var path: String = _output.path_join(stem + "_1920x1080.png")
	if DisplayServer.get_name() == "headless":
		print("WOULD CAPTURE " + path)
	else:
		await _capture(path)
		if not FileAccess.file_exists(path): return
		print(path)
	_capture_count += 1

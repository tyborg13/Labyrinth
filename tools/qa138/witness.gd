extends "res://tests/pre_battle_fixture.gd"
## Exercise Godot's native tooltip dispatch on the pinned Known Moves inspection.
const Panels = preload("res://scripts/ui_tooltip_panel.gd")
const ENEMY_TYPES: Array[String] = ["crawler", "ember_tick", "cinder_ooze", "burrow_grub"]
const POINTER_PARK := Vector2(8, 8)
const HOVER_INSET: float = 3.0
const POPUP_WAIT_SECONDS: float = 1.2
const WHITESPACE_TOOLTIP: String = " \t\n "
const CAPTURE_DIR: String = "user://probes/qa138"
const CAPTURE_KINDS: Array[String] = ["empty_plate", "move_tooltip", "trait_tooltip"]

var _capture_enabled: bool
var _captured: Dictionary = {}
var _moves: int
var _traits: int
var _empty: int
var _opened: int
var _empty_popups: int

func _initialize() -> void:
	_setup()
	_viewport.gui_embed_subwindows = true
	_capture_enabled = DisplayServer.get_name() != "headless"
	_run.call_deferred()

func _run() -> void:
	var engine := RunEngine.new()
	var state: Dictionary = _run_with_available_combat(engine)
	state = _pre_battle_state_for_room(engine, state, _first_available_combat_coord(engine, state))
	var scene: Node = await _instance(state)
	root.get_node("InputRouter").call("set_forced_state_for_test", "pointer", "xbox")
	for type: String in ENEMY_TYPES:
		var definition: Dictionary = GameData.enemy_def(type)
		var enemy: Dictionary = {"type": type, "hp": definition["max_hp"], "max_hp": definition["max_hp"]}
		scene.call("_open_pinned_pre_battle_inspection", "enemy", type, null, enemy)
		await _settle()
		var panel: Control = scene.get("_pinned_tooltip_panel")
		_expect(panel != null and panel.is_visible_in_tree(), type + " must open a pinned inspection")
		if panel == null: continue
		var moves: Array[Node] = panel.find_children("PreBattleKnownMoveRow", "", true, false)
		var traits: Array[Node] = panel.find_children("Enemy*Trait", "HBoxContainer", true, false)
		_expect(not moves.is_empty(), type + " must show Known Moves")
		for index: int in range(moves.size()):
			await _check_spot(moves[index], "%s move %d" % [type, index + 1], false)
		for index: int in range(traits.size()):
			await _check_spot(traits[index], "%s %s %d" % [type, traits[index].name, index + 1], true)
		scene.call("_close_pinned_tooltip")
		await _settle()
	_expect(_traits > 0 and _opened > 0, "Witness must cover trait rows and populated tooltips")
	if _capture_enabled:
		for kind: String in CAPTURE_KINDS:
			_expect(_captured.has(kind), "Missing capture " + kind)
		print("QA-138 captures: " + ProjectSettings.globalize_path(CAPTURE_DIR))
	scene.queue_free()
	_viewport.queue_free()
	await process_frame
	print("QA-138 witness: %s | %d enemy kinds, %d move plates, %d trait rows, %d populated popups, %d empty-text spots, %d empty-text popups" % ["FAIL" if _failed else "PASS", ENEMY_TYPES.size(), _moves, _traits, _opened, _empty, _empty_popups])
	quit(1 if _failed else 0)

func _check_spot(control: Control, context: String, is_trait: bool) -> void:
	if is_trait: _traits += 1
	else: _moves += 1
	if (_traits if is_trait else _moves) == 1:
		var whitespace_panel: Object = control.call("_make_custom_tooltip", WHITESPACE_TOOLTIP)
		_expect(whitespace_panel == null, context + " must reject whitespace-only tooltip text")
		if whitespace_panel != null: whitespace_panel.free()
	await _move_pointer(POINTER_PARK)
	var rect: Rect2 = control.get_global_rect()
	var point := Vector2(rect.position.x + HOVER_INSET, rect.get_center().y)
	await _move_pointer(point)
	var hovered: Control = _viewport.gui_get_hovered_control()
	_expect(hovered == control or (hovered != null and control.is_ancestor_of(hovered)), context + " must receive the pointer")
	var text: String = control.get_tooltip(control.get_global_transform().affine_inverse() * point)
	await create_timer(POPUP_WAIT_SECONDS).timeout
	await process_frame
	var popups: Array[Window]
	for node: Node in _viewport.find_children("*", "Window", true, false):
		var popup := node as Window
		if popup.visible and not popup.is_queued_for_deletion() and popup.theme_type_variation == &"TooltipPanel":
			popups.append(popup)
	if text.strip_edges().is_empty():
		_empty += 1
		_empty_popups += popups.size()
		print("QA-138 EMPTY %s popups=%d" % [context, popups.size()])
		_expect(popups.is_empty(), context + " must open no empty pop-up")
		if not is_trait and popups.is_empty(): await _capture_once("empty_plate")
		return
	_expect(popups.size() == 1, context + " must open one native pop-up")
	if popups.size() != 1: return
	var term: String = control.get("loop_term")
	var source: Dictionary = control.get("loop_source")
	var expected: Control = Panels.make_text(text, source, term) if is_trait or not term.is_empty() else Panels.make_plain_text(text)
	var expected_text: PackedStringArray = _popup_text(expected)
	expected.free()
	var actual_text: PackedStringArray = _popup_text(popups[0])
	_expect(not actual_text.is_empty() and actual_text == expected_text, context + " must keep its authored tooltip text")
	_opened += 1
	print("QA-138 TEXT %s source=%s popup=%s" % [context, JSON.stringify(text), JSON.stringify(actual_text)])
	await _capture_once("trait_tooltip" if is_trait else "move_tooltip")

func _popup_text(panel: Node) -> PackedStringArray:
	var lines := PackedStringArray()
	for node: Node in panel.find_children("*", "Control", true, false):
		if node is Label: lines.append((node as Label).text)
		elif node is RichTextLabel: lines.append((node as RichTextLabel).get_parsed_text())
	return lines

func _move_pointer(point: Vector2) -> void:
	_viewport.notification(Node.NOTIFICATION_VP_MOUSE_ENTER)
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = Vector2.RIGHT
	_viewport.push_input(event, true)
	await process_frame

func _capture_once(kind: String) -> void:
	if not _capture_enabled or _captured.has(kind): return
	await _capture(CAPTURE_DIR.path_join(kind + ".png"))
	_captured[kind] = true

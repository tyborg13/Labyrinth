extends "res://tests/pre_battle_fixture.gd"

# Adapted from tools/ett01/popup_probe.gd. Inspect the actual embedded Window,
# including internal children, rather than treating a builder return as a popup.
const Cases = preload("res://tools/gfix57/popup_cases.gd")
const TARGET_POSITION := Vector2(480, 360)
const TARGET_MINIMUM := Vector2(160, 48)
const IDLE_POINTER := Vector2(8, 8)
const HOVER_SECONDS: float = 1.2
const SEARCH_STEP: int = 4
const CAPTURE_DIR: String = "user://gfix57_popup_proof"
const CAPTURE_FIELD: Color = Palette.INK_1
const CAPTURE_GROUND: Color = Palette.INK_3

var _cases: Cases
var _baseline: bool
var _capture_enabled: bool
var _candidates: int
var _fixed: int

func _initialize() -> void:
	_setup()
	_viewport.gui_embed_subwindows = true
	_baseline = OS.get_cmdline_user_args().has("--release")
	_capture_enabled = DisplayServer.get_name() != "headless"
	call_deferred("_run")

func _run() -> void:
	if _capture_enabled: _add_capture_backdrop()
	_cases = Cases.new()
	await _check_pass()
	await _check_pre_battle("Foe", _cases.foe(), "Burrow Grub")
	await _check_pre_battle("Strip", _cases.strip(), "Overhead Smash")
	var gear: Control = _cases.gear()
	await _check_pre_battle("Gear", gear, str(GameData.equipment_def(gear.equipment_id)["name"]))
	await _check_pair("omen_badges.gd", "Badge", Cases.omen(), "Dread")
	await _check_pair("battlefield_rule_hud.gd", "BattlefieldRuleHud", Cases.battlefield(), "Wind")
	await _check_pair("pre_battle_objective_heading.gd", "ObjectiveHeading", Cases.heading(), "", Cases.Heading.new())
	await _check_graft()
	await _check_pair("section_map_panel.gd", "LegendItem", Cases.legend(true), "", Cases.legend(false), true)
	await _check_pair("chronicle_panel.gd", "RecordIcon", Cases.chronicle_icon(), "Already visited")
	await _check_pair("chronicle_card_tile.gd", "CardTile", Cases.chronicle_tile(Cases.LEGACY_CARD_ID), "Legacy Card", Cases.chronicle_tile(""), true)
	await _check_pair("card_empower_seal.gd", "EmpowerSeal", Cases.empower(Cases.EmpowerSuite.OFFERED_TEXT), "Stagger", Cases.empower(""), true)
	await _check_pair("pre_battle_inspection_view.gd", "LoopMovePlate", _cases.move(true), "", _cases.move(false))
	await _check_pair("pre_battle_inspection_view.gd", "LoopTraitRow", Cases.trait_row(Cases.Icons.tooltip("burst")), "", Cases.trait_row(Cases.BLANK))

	_cases.dispose()
	if _capture_enabled: print(ProjectSettings.globalize_path(CAPTURE_DIR))
	print("GFIX57 %s candidates=%d fixed=%d" % ["FAIL" if _failed else "PASS", _candidates, _fixed])
	_viewport.queue_free()
	await process_frame
	quit(int(_failed))

func _check_pass() -> void:
	var button: Button = Cases.pass_button()
	await _mount(button)
	var point: Vector2 = _center(button)
	var empty: Dictionary = await _hover(button, point)
	button.mouse_entered.connect(Cases.show_forecast.bind(button), CONNECT_ONE_SHOT)
	var normal: Dictionary = await _hover(button, point)
	var panel: Control = button.get_node_or_null("PassForecastFocusTooltip")
	var text: String = _visible_text(panel) if panel != null and panel.is_visible_in_tree() else ""
	var opened: bool = normal["valid"] and not normal["opened"] and text.contains("+%d" % Cases.FORECAST_WAIT)
	if opened: print("GFIX57 NORMAL Pass signature=%s" % ("%s\n%s" % [text, panel.size]).sha256_text())
	_report("pass_forecast_tooltip_button.gd", "Pass", empty, opened, false)
	await _remove(button)

func _check_pre_battle(id: String, target: Control, expected: String) -> void:
	await _mount(target)
	var point: Vector2 = _center(target)
	_cases.suppress(target)
	var empty: Dictionary = await _hover(target, point)
	_cases.unsuppress()
	var normal: Dictionary = await _hover(target, point)
	_report("pre_battle_controls.gd", id, empty, _normal_ok(id, normal, expected), false)
	await _remove(target)

func _check_graft() -> void:
	var target: Control = Cases.graft_choice()
	await _mount(target)
	var empty: Dictionary = await _hover(target, _find_spot(target, true))
	var normal: Dictionary = await _hover(target, _find_spot(target, false))
	_report("graftwright_choice.gd", "Choice", empty, _normal_ok("Choice", normal, ""), false)
	await _remove(target)

func _check_pair(file: String, id: String, target: Control, expected: String, blank: Control = null, fixed: bool = false) -> void:
	var empty: Dictionary = {}
	if blank != null:
		await _mount(blank)
		empty = await _hover(blank, _center(blank))
		if _capture_enabled and fixed: await _save_capture(id + "_empty")
		await _remove(blank)
	await _mount(target)
	var normal: Dictionary = await _hover(target, _center(target))
	if fixed and not _baseline:
		var whitespace: Control = target.call("_make_custom_tooltip", Cases.BLANK) if id != "CardTile" else _blank_tooltip_for_tile()
		_expect(whitespace == null, "%s must reject whitespace-only text" % id)
		if whitespace != null: whitespace.free()
	if _capture_enabled and fixed: await _save_capture(id + "_normal")
	_report(file, id, empty, _normal_ok(id, normal, expected), fixed)
	await _remove(target)

func _blank_tooltip_for_tile() -> Control:
	# Chronicle renders the archived fallback name rather than the query string.
	var tile: Control = Cases.chronicle_tile(Cases.BLANK)
	var popup: Control = tile.call("_make_custom_tooltip", tile.tooltip_text)
	tile.free()
	return popup

func _mount(target: Control) -> void:
	_viewport.add_child(target)
	target.position = TARGET_POSITION
	target.size = target.size.max(TARGET_MINIMUM)
	await process_frame
	await process_frame

func _remove(target: Control) -> void:
	_move(IDLE_POINTER)
	target.queue_free()
	await process_frame

func _center(target: Control) -> Vector2:
	return target.get_global_transform() * (target.size * 0.5)

func _find_spot(target: Control, blank: bool) -> Vector2:
	for y: int in range(SEARCH_STEP, int(target.size.y), SEARCH_STEP):
		for x: int in range(SEARCH_STEP, int(target.size.x), SEARCH_STEP):
			var point := Vector2(x, y)
			if target.get_tooltip(point).strip_edges().is_empty() == blank:
				return target.get_global_transform() * point
	return Vector2(-1, -1)

func _move(point: Vector2) -> void:
	_viewport.notification(Node.NOTIFICATION_VP_MOUSE_ENTER)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = Vector2.RIGHT
	_viewport.push_input(motion, true)

func _hover(target: Control, point: Vector2) -> Dictionary:
	_move(IDLE_POINTER)
	await process_frame
	_move(point)
	await process_frame
	var hovered: Control = _viewport.gui_get_hovered_control()
	var valid: bool = hovered != null and (hovered == target or target.is_ancestor_of(hovered))
	var query: String = target.get_tooltip(target.get_global_transform().affine_inverse() * point)
	await create_timer(HOVER_SECONDS).timeout
	await process_frame
	var popup: Window = _find_popup(target)
	return {"valid": valid, "query": query, "opened": popup != null,
		"text": _visible_text(popup) if popup != null else "",
		"size": str(popup.size) if popup != null else ""}

func _find_popup(node: Node) -> Window:
	for child: Node in node.get_children(true):
		if child is Window and child.visible and child.get("theme_type_variation") == &"TooltipPanel":
			return child
		var nested: Window = _find_popup(child)
		if nested != null: return nested
	return null

func _visible_text(node: Node) -> String:
	if node is CanvasItem and not node.is_visible_in_tree(): return ""
	var parts := PackedStringArray()
	if node is Label: parts.append(node.text)
	if node is RichTextLabel: parts.append(node.get_parsed_text())
	for child: Node in node.get_children(true):
		var text: String = _visible_text(child)
		if not text.is_empty(): parts.append(text)
	return "\n".join(parts).strip_edges()

func _normal_ok(id: String, observation: Dictionary, expected: String) -> bool:
	var query: String = observation["query"]
	var text: String = observation["text"]
	if expected.is_empty(): expected = query.strip_edges().get_slice("\n", 0)
	var ok: bool = observation["valid"] and observation["opened"] and not expected.is_empty() and text.to_lower().contains(expected.to_lower())
	var signature: String = ("%s\n%s\n%s" % [query, text, observation["size"]]).sha256_text()
	print("GFIX57 NORMAL %s signature=%s" % [id, signature])
	if not ok:
		print("GFIX57 DETAIL %s normal=%s expected=%s" % [id, JSON.stringify(observation), JSON.stringify(expected)])
	return ok

func _report(file: String, id: String, empty: Dictionary, normal: bool, fixed: bool) -> void:
	var state: String = "n/a: always has text"
	var empty_ok: bool = true
	if not empty.is_empty():
		state = "opened" if empty["opened"] else "none"
		empty_ok = empty["valid"] and (empty["query"] as String).strip_edges().is_empty()
		empty_ok = empty_ok and empty["opened"] == (_baseline and fixed)
		if _baseline and empty["opened"]:
			empty_ok = empty_ok and (empty["text"] as String).is_empty()
			print("GFIX57 RELEASE %s popup_size=%s rendered_text=%s" % [id, empty["size"], JSON.stringify(empty["text"])])
		if not empty_ok: print("GFIX57 DETAIL %s empty=%s" % [id, JSON.stringify(empty)])
	_candidates += 1
	if fixed and empty["opened"] == _baseline: _fixed += 1
	var ok: bool = empty_ok and normal
	_failed = _failed or not ok
	print("GFIX57 %s#%s empty=%s normal=%s %s" % [file, id, state, "opened" if normal else "FAIL", "PASS" if ok else "FAIL"])

func _save_capture(stem: String) -> void:
	await _capture("%s/%s_1920x1080.png" % [CAPTURE_DIR, stem])

func _add_capture_backdrop() -> void:
	# Preserve contrast even in captures containing only a small idle control.
	var top: float = 0.0
	for color: Color in [CAPTURE_FIELD, CAPTURE_GROUND]:
		var band := ColorRect.new()
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.color = color
		band.size = Vector2(PROBE_VIEWPORT.x, PROBE_VIEWPORT.y * 0.5)
		band.position.y = top
		_viewport.add_child(band)
		top += band.size.y

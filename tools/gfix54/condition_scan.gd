extends SceneTree
## Audit condition hit targets and export the focused keyword-panel copy.
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Data = preload("res://scripts/game_data.gd")
const Display = preload("res://scripts/card_display_overrides.gd")
const Hover = preload("res://scripts/card_keyword_hover.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Widget = preload("res://scenes/card_widget.tscn")
const CARD_SIZE := Vector2(250, 352)
const EXPECTED_CARDS: int = 309
const CONTEXT_SETTLE_FRAMES: int = 5
const VIEW_CONTEXTS: Array[String] = ["hand_1_rest", "reward_offers", "scavenger_offer", "scavenger_detail",
	"graftwright", "deck_view", "pile_dialog", "grimoire", "grimoire_equipment"]
const WITNESSES := {
	"blinding_bash": "illuminate", "couched_lance": "move", "dazzle": "illuminate",
	"hallowed_strike": "illuminate", "headlong": "move", "hobnail_drive": "stagger",
	"iron_wheel": "move", "reflected_threat": "retaliate", "refraction": "illusion",
	"revealing_glare": "illuminate", "searing_light": "illuminate", "sunlance": "illuminate",
}
var _panels_only: bool
var _exports: Dictionary
var _icons_checked: int
var _icons_with_text: int
var _icons_with_route: int
var _witnesses_checked: int
var _failed: bool

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Runtime.apply_from_environment()
	var args := OS.get_cmdline_user_args()
	if args.has("--contexts"):
		await _scan_contexts()
		quit(int(_failed))
		return
	_panels_only = args.has("--panels-only")
	var ids: Array = Data.cards().keys()
	ids.sort()
	var widget: CardWidget = Widget.instantiate()
	widget.size = CARD_SIZE
	root.add_child(widget)
	for id: String in ids:
		var card: Dictionary = Data.card_def_for_progression(id, {})
		widget.configure(id, false, false, true, false, true, true, card)
		widget.set_display_overrides()
		await _scan(widget, "catalog")
		Display.apply_projection(widget, card, Display.for_card(id, {}, card))
		await _scan(widget, "hand")
		if WITNESSES.has(id):
			_report_coverage(widget, WITNESSES[id])
		var progression: Dictionary = {Data.LEGACY_STARTER_CARDS_KEY: true}
		var legacy: Dictionary = Data.card_def_for_progression(id, progression)
		if legacy != card:
			widget.configure(id, false, false, true, false, true, true, legacy)
			Display.apply_projection(widget, legacy, Display.for_card(id, progression, legacy))
			await _scan(widget, "legacy")
	widget.free()
	var output_arg: int = args.find("--panel-output")
	if output_arg >= 0:
		_expect(output_arg + 1 < args.size(), "Provide a filename after --panel-output")
		if output_arg + 1 < args.size():
			var file := FileAccess.open(args[output_arg + 1], FileAccess.WRITE)
			_expect(file != null, "Open panel output")
			if file != null:
				file.store_string(JSON.stringify(_exports, "  ") + "\n")
				file.close()
	_expect(ids.size() == EXPECTED_CARDS, "Unexpected card count")
	_expect(_witnesses_checked == WITNESSES.size(), "Each witness needs its existing side panel")
	if _panels_only:
		print("GFIX54 PANEL EXPORT: %s (%d cards, %d coverage rows)" % [
			"FAIL" if _failed else "PASS", ids.size(), _witnesses_checked])
	else:
		_expect(_icons_checked > 0, "The scan must reach rendered condition icons")
		print("GFIX54 CONDITION SCAN: %s (%d cards, %d condition icons, %d with tooltip text, %d with tooltip-loop route, %d of %d coverage rows)" % [
			"FAIL" if _failed else "PASS", ids.size(), _icons_checked, _icons_with_text, _icons_with_route, _witnesses_checked, WITNESSES.size()])
	quit(int(_failed))

func _scan(widget: CardWidget, view: String) -> void:
	var copy: Array[Dictionary]
	for panel: Dictionary in Hover.entries_for(widget):
		copy.append({
			"icon": panel["icon"], "term": panel["glossary_key"], "title": panel["title"],
			"body": panel["description"], "display": panel.get("display_description", panel["description"]),
		})
	_exports.get_or_add(widget.card_id, {})[view] = copy
	if _panels_only: return
	var icons: Array[TextureRect] = condition_icons(widget)
	if icons.is_empty(): return
	await process_frame
	await process_frame
	for icon: TextureRect in condition_icons(widget):
		_icons_checked += 1
		_icons_with_text += int(not icon.tooltip_text.is_empty())
		_icons_with_route += int(icon.has_meta("tooltip_loop_route"))
		_expect(is_inert(widget, icon), "%s %s condition must have the same hover as the card body" % [widget.card_id, view])

func _report_coverage(widget: CardWidget, term: String) -> void:
	var matching: Array[Dictionary]
	for entry: Dictionary in Hover.entries_for(widget):
		if entry["icon"] == term: matching.append(entry)
	# Iron Wheel has a Move action and a distinct Move condition panel.
	if matching.size() > 1:
		for row: Array in widget.display_summary_rows():
			for token: Dictionary in row:
				if token.get("kind") != "surface_condition" or token.get("icon") != term: continue
				var condition_text: String = Icons.token_tooltip(token, true)
				matching = matching.filter(func(panel: Dictionary) -> bool: return panel["tooltip"] == condition_text)
	_expect(matching.size() == 1, "Find one corresponding condition panel for " + widget.card_id)
	if matching.size() != 1: return
	var panel: Dictionary = matching[0]
	_witnesses_checked += 1
	print("GFIX54 SIDE PANEL %s %s" % [widget.card_id, JSON.stringify({"title": panel["title"], "body": panel["description"]})])

static func condition_icons(widget: CardWidget) -> Array[TextureRect]:
	var icons: Array[TextureRect]
	var summary: Control = widget.get("_summary_icon_box")
	if not summary.visible: return icons
	# Only condition groups place their TextureRect directly in an HBox.
	# Their sibling action chips put icons inside an intermediate Control.
	for node: Node in summary.find_children("*", "TextureRect", true, false):
		if node.get_parent() is HBoxContainer: icons.append(node as TextureRect)
	return icons

static func condition_icon(widget: CardWidget, term: String) -> TextureRect:
	var texture: Texture2D = Icons.icon_texture(term)
	for icon: TextureRect in condition_icons(widget):
		if icon.texture == texture: return icon
	return null

static func is_inert(widget: CardWidget, icon: TextureRect) -> bool:
	var group: Control = icon.get_parent()
	for part: Control in group.get_children():
		if not part.tooltip_text.is_empty() or part.has_meta("tooltip_loop_route") or part.mouse_filter != Control.MOUSE_FILTER_IGNORE: return false
	if not group.tooltip_text.is_empty() or group.has_meta("tooltip_loop_route") or group.mouse_filter != Control.MOUSE_FILTER_IGNORE: return false
	var to_card: Transform2D = widget.get_global_transform_with_canvas().affine_inverse()
	var icon_point: Vector2 = icon.get_global_transform_with_canvas() * (icon.size * 0.5)
	var art: Control = widget.art_frame
	var body_point: Vector2 = art.get_global_transform_with_canvas() * (art.size * 0.5)
	return icon.size.x > 0.0 and icon.size.y > 0.0 and widget.get_tooltip(to_card * icon_point) == widget.get_tooltip(to_card * body_point)

func _scan_contexts() -> void:
	var live = load("res://tests/helpers/card_legibility_contexts.gd").new()
	await live.setup(self, 1)
	var worker: Dictionary = live.workers[0]
	var scene: Node = worker["scene"]
	for context: String in VIEW_CONTEXTS:
		var faces: Array = await live.open({"id": context})
		_expect(faces.size() == 1, context + " mounts the production card face")
		if faces.is_empty(): continue
		var card: CardWidget = faces[0]
		if context == "graftwright":
			# The production audit opens with Quick Stab. Give its actual source
			# widget a combined condition and Move for this hover sample.
			card.configure(live.FIXTURE_CARD, false, false, true, false, bool(card.get("_interactive")))
			card.set_display_overrides()
		await _check_context(card, context)
		if context == "reward_offers":
			card.grab_focus()
			await process_frame
			var stack: Control = scene.get("_card_focus_tooltip_stack")
			_expect(card.has_focus() and stack.visible and stack.get("_follow_target") == card,
				"Reward GUI focus keeps its side-panel binding")
			card.release_focus()
	var preview_script: Script = load("res://scripts/event_reward_preview.gd")
	var audit: Script = load("res://tests/helpers/card_legibility_audit.gd")
	for beat_only: bool in [false, true]:
		var stage: Control = preview_script.build({"kind": "card", "ids": [live.FIXTURE_CARD]}, live.combat_fixture, beat_only)
		worker["viewport"].add_child(stage)
		await _check_context(audit.find_card(stage), "event_result_preview" if beat_only else "event_hover_preview")
		stage.free()
	scene.call("_close_grimoire_overlay")
	root.get_node("InputRouter").clear_forced_state_for_test()
	for frame: int in range(CONTEXT_SETTLE_FRAMES): await process_frame
	live.cleanup()
	await process_frame
	print("GFIX54 CARD CONTEXTS: %s (%d contexts, reward GUI focus, native query checked)" % [
		"FAIL" if _failed else "PASS", VIEW_CONTEXTS.size() + 2])

func _check_context(card: CardWidget, context: String) -> void:
	for frame: int in range(CONTEXT_SETTLE_FRAMES): await process_frame
	_expect(card != null and card.is_visible_in_tree(), context + " has a visible CardWidget")
	if card == null or not card.is_visible_in_tree(): return
	var icons: Array[TextureRect] = condition_icons(card)
	_expect(not icons.is_empty(), context + " rendered a condition icon")
	if icons.is_empty(): return
	var native_enabled: bool = card.native_tooltips_enabled()
	for icon: TextureRect in icons:
		_expect(is_inert(card, icon), context + " condition icon matches the card body's hover")
	card.set_native_tooltips_enabled(true)
	for icon: TextureRect in icons:
		_expect(is_inert(card, icon), context + " native condition query matches the card body's hover")
	card.set_native_tooltips_enabled(native_enabled)
	print("GFIX54 CARD CONTEXT %s: %s, %d inert condition icon(s), native default=%s" % [
		context, card.card_id, icons.size(), native_enabled])

func _expect(condition: bool, detail: String) -> void:
	if condition: return
	_failed = true
	push_error(detail)

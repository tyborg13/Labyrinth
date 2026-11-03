extends RefCounted

# Catalog definitions, measurement and validity checks. The full audit mounts
# faces in card_legibility_contexts.gd production screens. make_card below is
# retained only for isolated component regressions and accepted capture fixtures.
const Display = preload("res://scripts/card_display_overrides.gd")
const Data = preload("res://scripts/game_data.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const InlineText = preload("res://scripts/inline_icon_text.gd")
const Keywords = preload("res://scripts/card_keyword_rules.gd")
const ItemRules = preload("res://scripts/item_relic_rules.gd")
const Card = preload("res://scripts/card_widget.gd")
const CardScene = preload("res://scenes/card_widget.tscn")
const Previews = preload("res://scripts/item_preview_builders.gd")
const Fan = preload("res://scripts/hand_fan_container.gd")
const Shop = preload("res://scripts/scavenger_shop_view.gd")
const Pile = preload("res://scripts/pile_dialog_view.gd")
const Graft = preload("res://scripts/graftwright_view.gd")
const Chronicle = preload("res://scripts/chronicle_panel.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Sources = preload("res://tests/helpers/card_legibility_sources.gd")
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const TEXT_FLOOR: float = 14.0
const ICON_FLOOR: float = 16.0
const SETTLE_FRAMES: int = 5
const EPSILON: float = 0.02
# Director-approved exceptions. New contexts must pass unless named here.
const EXEMPT_CONTEXTS: Dictionary = {
	"hand_1_rest": "hand at rest; hover/focus shows it at 17 px",
	"hand_7_rest": "hand at rest; hover/focus shows it at 17 px",
	"card_drag_proxy": "transient while dragging",
	"card_fx_staged_reduced_motion": "transient play effect",
	"scavenger_offer": "shop shelf; hover/focus shows scavenger_detail at 16 px",
	"scavenger_sell": "thumbnail; scavenger_detail shows it at 16 px",
	"scavenger_receipt": "thumbnail; scavenger_detail shows it at 16 px",
}
const FIXED_CONTEXTS: Array = [ "deck_view", "grimoire_equipment", "graftwright", "campfire", "purge_picker", "pile_dialog", "upgrade_preview"]
const FIXTURE_HAND_WIDTH: float = 1640.0
const FIXTURE_HAND_EXTRA_HEIGHT: float = 100.0

class LayoutHost extends "res://scripts/run_scene.gd":
	var audit_controller: bool = false

	func _ready() -> void:
		pass

	func _controller_combat_layout_active() -> bool:
		return audit_controller

var host: Node
var shop := Shop.new()
var graft := Graft.new()

func setup(tree: SceneTree) -> void:
	host = preload("res://scenes/run_scene.tscn").instantiate()
	host.set_script(LayoutHost)
	tree.root.add_child(host)
	host.hide()

func cleanup() -> void:
	host.free()
	shop.free()
	graft.free()

func contexts() -> Array:
	var constants: Dictionary = (preload("res://scripts/run_scene.gd") as Script).get_script_constant_map()
	var result: Array = []
	for count: int in [1, Combat.MAX_HAND_SIZE]:
		var extent: Vector2 = host.call("_hand_card_size", count, false)
		for pose: String in ["rest", "focused", "hovered", "targeting"]:
			result.append({"id": "hand_%d_%s" % [count, pose], "factory": "hand", "size": extent, "pose": pose, "count": count})
	host.audit_controller = true
	host.set("_controller_hand_focused", true)
	result.append({"id": "hand_controller_focused", "factory": "hand", "size": host.call("_hand_card_size", Combat.MAX_HAND_SIZE, false), "pose": "focused"})
	host.audit_controller = false
	host.set("_controller_hand_focused", false)
	for id: String in ["reward_offers", "boon_spells"]:
		result.append({"id": id, "factory": "reward", "size": host.call("_reward_choice_card_size", 3, true)})
	result.append({"id": "scavenger_offer", "factory": "shop", "size": Shop.OFFER_CARD_SIZE})
	result.append({"id": "scavenger_sell", "factory": "shop", "size": Vector2(100, 140)})
	result.append({"id": "scavenger_receipt", "factory": "shop", "size": Vector2(69, 97)})
	result.append({"id": "scavenger_detail", "factory": "shop", "size": Shop.NATIVE_CARD_SIZE})
	result.append({"id": "deck_view", "factory": "deck", "size": Pile.CARD_SIZE})
	result.append({"id": "grimoire", "factory": "preview", "size": constants["GRIMOIRE_CARD_PREVIEW_SIZE"]})
	result.append({"id": "grimoire_equipment", "factory": "preview", "size": constants["GRIMOIRE_EQUIPMENT_CARD_SIZE"]})
	for id: String in ["card_tooltip", "chronicle_card"]:
		result.append({"id": id, "factory": "tooltip", "size": Previews.CARD_TOOLTIP_SIZE})
	for id: String in ["equipment_tooltip", "chronicle_equipment"]:
		result.append({"id": id, "factory": "equipment", "size": Previews.EQUIPMENT_TOOLTIP_CARD_SIZE})
	result.append({"id": "graftwright", "factory": "graft", "size": Graft.CARD_SIZE})
	result.append({"id": "graftwright_inspection", "factory": "rules_tooltip", "size": Vector2.ZERO})
	for id: String in ["campfire", "purge_picker", "pile_dialog"]:
		result.append({"id": id, "factory": "scaled", "size": constants["PILE_DIALOG_CARD_SIZE"]})
	result.append({"id": "purge_confirmation", "factory": "scaled", "size": preload("res://scripts/magic_purge_confirmation.gd").CARD_SIZE})
	result.append({"id": "upgrade_preview", "factory": "scaled", "size": constants["UPGRADE_CARD_SIZE"]})
	# Played-card proxies hold at the source rect times the production stage
	# multiplier. Read its authored values rather than inventing a proof size.
	var stage_multiplier := RegEx.new()
	stage_multiplier.compile("var target_multiplier: float = ([0-9.]+) if reduced_motion else ([0-9.]+)")
	var stage: RegExMatch = stage_multiplier.search((preload("res://scripts/run_scene.gd") as Script).source_code)
	assert(stage != null, "Update the audit when the production card FX sizing contract changes")
	var source_size: Vector2 = host.call("_hand_card_size", Combat.MAX_HAND_SIZE, false)
	result.append({"id": "card_drag_proxy", "factory": "scaled", "size": source_size * float(constants["CARD_DRAG_FOLLOW_SCALE"])})
	result.append({"id": "card_fx_staged", "factory": "scaled", "size": source_size * float(stage.get_string(2))})
	result.append({"id": "card_fx_staged_reduced_motion", "factory": "scaled", "size": source_size * float(stage.get_string(1))})
	for context: Dictionary in result:
		context.merge(Sources.contract(context["id"]))
		context["exempt"] = EXEMPT_CONTEXTS.has(context["id"])
		context["exemption"] = EXEMPT_CONTEXTS.get(context["id"], "")
	return result

static func definitions() -> Array:
	var result: Array = []
	for id: String in Data.cards():
		result.append({"id": id, "variant": "base", "definition": Data.card_def(id)})
		if bool(Data.card_def(id).get("item", false)):
			result.append({"id": id, "variant": "item_once_per_combat", "definition": ItemRules.modify_card(Data.card_def(id), [{"type": "item_once_per_combat"}], Callable())})
	for id: String in Data.card_upgrade_ids():
		result.append({"id": id, "variant": "upgraded", "definition": Data.upgraded_card_def(id)})
	for id: String in Data.upgradeable_card_ids():
		for element: Dictionary in Data.upgradeable_elements_for_card(id, {}):
			var options: Array = Data.upgrade_options_for_element(id, element, {})
			for index: int in range(options.size()):
				result.append({"id": id, "variant": "upgrade:%s:%d" % [element["key"], index], "definition": Data.preview_card_with_mod(id, options[index], {})})
	for base: Dictionary in result.duplicate():
		var card: Dictionary = base["definition"]
		if not (Keywords.has_empower(card) or Keywords.has_follow_up(card)): continue
		for empowered: bool in ([false, true] if Keywords.has_empower(card) else [false]):
			for follow_up: bool in ([false, true] if Keywords.has_follow_up(card) else [false]):
				if not empowered and not follow_up: continue
				var modifiers: Dictionary = {"empowered": empowered, "follow_up": follow_up}
				var rows: Array = Icons.cost_rows_for_card(card)
				var actions: Array = Keywords.actions_with_modifiers(card, modifiers).filter(func(a: Dictionary) -> bool: return not a.has(Keywords.KEYWORD_APPENDED_FLAG))
				rows.append_array(Icons.rows_for_actions(actions))
				rows.append_array(Icons.keyword_rows_for_card(card, modifiers))
				rows.append_array(Icons.rules_text_rows_for_card(card))
				result.append({"id": base["id"], "variant": "%s:empowered=%s:follow_up=%s" % [base["variant"], empowered, follow_up], "definition": card, "rows": rows, "time_surcharge": int(Keywords.empower_cost(card).get("time", 0)) if empowered else 0})
	# Audit distinct visible definitions once; retain every upgrade alias so the
	# report can prove coverage without thousands of identical measurements.
	var distinct: Array = []
	var indices: Dictionary = {}
	for entry: Dictionary in result:
		var card: Dictionary = entry["definition"]
		var signature: String = str(entry["id"]) + JSON.stringify([card.get("name"), card.get("time"), card.get("health_cost"), entry.get("rows", Icons.rows_for_card(card)), entry.get("time_surcharge", 0)])
		if indices.has(signature):
			(distinct[int(indices[signature])]["aliases"] as Array).append(entry["variant"])
		else:
			indices[signature] = distinct.size()
			entry["aliases"] = [entry["variant"]]
			distinct.append(entry)
	return distinct

func make_card(context: Dictionary, entry: Dictionary) -> Dictionary:
	var id: String = entry["id"]
	var extent: Vector2 = context["size"]
	var previews := Previews.new()
	previews.definitions[id] = entry["definition"]
	var surface: Control
	var widget: Control
	match str(context["factory"]):
		"rules_tooltip":
			# Exact full-rules popover used by GraftwrightView._open_inspection.
			var card: Dictionary = entry["definition"]
			surface = preload("res://scripts/ui_tooltip_panel.gd").make_lines(str(card.get("name", id)), PackedStringArray([Icons.card_rules_text(card)]))
			return {"surface": surface, "widget": surface}
		"tooltip": surface = previews.card_tooltip(id)
		"equipment", "preview": surface = previews.card_preview(id, extent)
		"shop":
			surface = Control.new()
			widget = shop.call("_build_native_scaled_card", surface, id, extent, "Audit", false)
		"deck": surface = Pile.card_cell(host, id, 1, Callable())
		"graft":
			surface = Control.new()
			graft.call("_card", surface, id, Vector2.ZERO, false, Graft.VIOLET, func() -> void: pass)
		_:
			widget = CardScene.instantiate()
			widget.configure(id, false, false, true, false, false, true, entry["definition"])
			if context["factory"] == "reward":
				widget.set_hover_pose(host.REWARD_CARD_HOVER_LIFT, host.REWARD_CARD_HOVER_SCALE)
				surface = host.call("_reward_card_choice_slot", widget, id, extent, {})
			else:
				surface = host.call("_hand_card_slot" if context["factory"] == "hand" else "_scaled_card_slot", widget, extent)
	if widget == null: widget = find_card(surface)
	# Context factories that resolve their own definitions still receive the same
	# progression override as their real owning screen.
	widget.configure(id, false, false, true, false, false, true, entry["definition"])
	widget.set_display_overrides("", [], entry.get("rows", []), int(entry.get("time_surcharge", 0)))
	if context["factory"] == "hand":
		if context["pose"] == "targeting":
			widget.set_interaction_state(true, false, true, false, false, true)
		widget.set_hover_pose(0.0, 1.0)
		var fan := Fan.new()
		fan.size = Vector2(FIXTURE_HAND_WIDTH, extent.y + FIXTURE_HAND_EXTRA_HEIGHT)
		fan.add_child(surface)
		fan.configure_layout(0.0, true)
		if context["pose"] != "rest":
			fan.set_emphasized_index(0, false, Fan.TARGETING_EMPHASIS_SCALE if context["pose"] == "targeting" else Fan.DEFAULT_EMPHASIS_SCALE)
		surface = fan
	return {"surface": surface, "widget": widget}

static func find_card(node: Node) -> Control:
	if node == null: return null
	if node is Card: return node
	for child: Node in node.get_children():
		var found: Control = find_card(child)
		if found != null: return found
	return null

static func measure(widget: Control, definition: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"text_px": {"rules": null, "token_number": null, "footer": null}, "icon_px": null, "shrunk": false, "overflow_px": {"x": 0.0, "y": 0.0}, "runs": [], "visible": _face_visible(widget), "content_text_runs": 0, "expected_icons": _expects_icons(widget)}
	if not result["visible"]: return result
	if not widget is Card:
		_measure_rules_tooltip(widget, definition, result)
		return result
	result["printed_id"] = widget.card_id
	result["definition_signature"] = hash(widget.get("_card_override"))
	result["rows_signature"] = hash(widget.get("_summary_rows"))
	result["time_surcharge"] = widget.get("_time_surcharge")
	_measure_node(widget, widget, result)
	var badge: Control = widget.get("_time_badge")
	if badge != null and badge.is_visible_in_tree():
		var badge_font: int = badge.value_font_size()
		var badge_scale: Vector2 = badge.get_global_transform_with_canvas().get_scale().abs()
		var badge_px: float = float(badge_font) * minf(badge_scale.x, badge_scale.y)
		_minimum(result["text_px"], "token_number", badge_px)
		result["runs"].append({"role": "token_number", "path": str(widget.get_path_to(badge)), "font_size": badge_font, "scale": badge_scale.x, "px": badge_px})
	var summary: Control = widget.get("_summary_icon_box")
	if is_instance_valid(summary) and summary.visible:
		var scale_value: Vector2 = summary.get_global_transform_with_canvas().get_scale().abs()
		var available: float = widget.call("_summary_parchment_width")
		result["overflow_px"]["x"] = maxf(0.0, summary.get_combined_minimum_size().x - available) * scale_value.x
	var bottom: float = 0.0
	# Measure against the native composition, not an expanded container minimum.
	var inverse: Transform2D = widget.get_global_transform_with_canvas().affine_inverse()
	for run: Dictionary in result["runs"]:
		var node: Control = widget.get_node(run["path"])
		var local_end: Vector2 = inverse * (node.get_global_transform_with_canvas() * node.size)
		bottom = maxf(bottom, local_end.y)
	result["overflow_px"]["y"] = maxf(0.0, bottom - (Card.BASE_CARD_SIZE.y - 14.0)) * widget.get_global_transform_with_canvas().get_scale().abs().y
	return result

static func _expects_icons(widget: Control) -> bool:
	if not widget is Card: return false
	var rows: Array = widget.get("_summary_rows")
	if rows.is_empty():
		var definition: Dictionary = widget.get("_card_override")
		rows = Icons.rows_for_card(definition if not definition.is_empty() else Data.card_def(widget.card_id))
	for row: Array in rows:
		for token: Dictionary in row:
			if not str(token.get("icon", "")).is_empty() or token.get("kind") == "aoe_pattern": return true
	return false

static func _face_visible(widget: Control) -> bool:
	if widget == null or not widget.is_inside_tree() or not widget.is_visible_in_tree(): return false
	var rect: Rect2 = widget.get_global_rect()
	if not rect.has_area() or not rect.intersects(widget.get_viewport_rect()): return false
	var node: Node = widget
	var alpha: float = widget.self_modulate.a
	while node != null:
		if node is CanvasItem: alpha *= node.modulate.a
		if node is Control and node.clip_contents: rect = rect.intersection(node.get_global_rect())
		node = node.get_parent()
	return alpha > 0.0 and rect.has_area()

static func normalized_rules_text(text: String) -> String:
	# Parse both expected production text and actual parsed label text through
	# the same BBCode/inline-token path, then collapse whitespace identically.
	var parser := RichTextLabel.new()
	parser.bbcode_enabled = true
	InlineText.apply_to(parser, text)
	var parsed: String = parser.get_parsed_text().replace("\u00a0", " ")
	parser.free()
	var whitespace := RegEx.new()
	whitespace.compile("\\s+")
	return whitespace.sub(parsed, " ", true).strip_edges()

static func expected_inspection_rules(panel: Control, definition: Dictionary) -> String:
	if definition.is_empty(): return ""
	if panel.has_meta("card_display_id"):
		return Display.rules_text(str(panel.get_meta("card_display_id")), definition, panel.get_meta("card_display_rows", []))
	return Icons.card_rules_text(definition)

static func rules_body_matches(panel: Control, definition: Dictionary) -> Array[Control]:
	var matches: Array[Control]
	# This is the exact production function Graftwright calls to fill its body.
	var expected: String = normalized_rules_text(expected_inspection_rules(panel, definition))
	if expected.is_empty(): return matches
	for node: Node in panel.find_children("*", "", true, false):
		if not (node is Label or node is RichTextLabel): continue
		var text: String = node.get_parsed_text() if node is RichTextLabel else str(node.get("text"))
		# Include hidden matches: visibility cannot disambiguate duplicate rules.
		if normalized_rules_text(text) == expected: matches.append(node as Control)
	return matches

static func rules_body(panel: Control, definition: Dictionary) -> Control:
	var matches: Array[Control] = rules_body_matches(panel, definition)
	return matches[0] if matches.size() == 1 else null

static func _measure_rules_tooltip(panel: Control, definition: Dictionary, result: Dictionary) -> void:
	var matches: Array[Control] = rules_body_matches(panel, definition)
	var body: Control = matches[0] if matches.size() == 1 else null
	result["rules_body_errors"] = []
	result["rules_body_match_count"] = matches.size()
	result["expected_rules_text"] = normalized_rules_text(expected_inspection_rules(panel, definition))
	result["rules_body_path"] = "" if body == null else str(panel.get_path_to(body))
	result["rules_body_visible"] = body != null and body.is_visible_in_tree()
	var text: String = "" if body == null else body.get_parsed_text() if body is RichTextLabel else str(body.get("text"))
	result["rules_body_nonempty"] = not text.strip_edges().is_empty()
	if body == null:
		result["rules_body_errors"].append("ambiguous rules body" if matches.size() > 1 else "missing rules body")
		return
	if not result["rules_body_visible"]: result["rules_body_errors"].append("rules body hidden")
	if not result["rules_body_nonempty"]: result["rules_body_errors"].append("rules body empty")
	if not result["rules_body_errors"].is_empty(): return
	var font_size: int = body.get_theme_font_size("normal_font_size" if body is RichTextLabel else "font_size")
	var scale_value: Vector2 = body.get_global_transform_with_canvas().get_scale().abs()
	var px: float = float(font_size) * minf(scale_value.x, scale_value.y)
	_minimum(result["text_px"], "rules", px)
	result["content_text_runs"] = 1
	result["runs"].append({"role": "rules", "path": result["rules_body_path"], "font_size": font_size, "scale": scale_value.x, "px": px})
	if body is RichTextLabel and not (body.get_meta("inline_icon_keys", []) as Array).is_empty():
		_minimum(result, "icon_px", float(body.get_meta("inline_icon_size", 0.0)) * scale_value.y)

static func _measure_node(node: Node, widget: Control, result: Dictionary) -> void:
	if node is Control and not (node as Control).is_visible_in_tree(): return
	var role: String = ""
	if node == widget.get("desc_label") or node.has_meta("summary_rules_text"): role = "rules"
	elif node == widget.get("footer_label"): role = "footer"
	elif node is Label and _in_summary(widget, node): role = "rules" if _has_letters(str(node.text)) else "token_number"
	if not role.is_empty() and (node is Label or node is RichTextLabel):
		var control: Control = node
		var text: String = control.get_parsed_text() if node is RichTextLabel else str(control.get("text"))
		if not text.is_empty():
			var font_size: int = control.get_theme_font_size("normal_font_size" if node is RichTextLabel else "font_size")
			var scale_value: Vector2 = control.get_global_transform_with_canvas().get_scale().abs()
			var px: float = float(font_size) * minf(scale_value.x, scale_value.y)
			_minimum(result["text_px"], role, px)
			if role != "footer": result["content_text_runs"] += 1
			# Scaling-condition suffixes contain words and token numbers in one
			# glyph run; both roles inherit that same measured font/transform.
			if role == "rules" and node is Label and _in_summary(widget, node):
				for character: String in text:
					if character.is_valid_int():
						_minimum(result["text_px"], "token_number", px)
						break
			result["runs"].append({"role": role, "path": str(widget.get_path_to(node)), "font_size": font_size, "scale": scale_value.x, "px": px})
			if role == "rules": result["shrunk"] = result["shrunk"] or font_size < widget.call("_rules_text_font_size")
	if node is TextureRect and _in_summary(widget, node):
		_minimum(result, "icon_px", (node as Control).size.y * (node as Control).get_global_transform_with_canvas().get_scale().abs().y)
	if node is Card.AoePatternView:
		_minimum(result, "icon_px", (node as Control).size.y * (node as Control).get_global_transform_with_canvas().get_scale().abs().y)
	if node is RichTextLabel and not (node.get_meta("inline_icon_keys", []) as Array).is_empty():
		_minimum(result, "icon_px", float(node.get_meta("inline_icon_size", 0.0)) * (node as Control).get_global_transform_with_canvas().get_scale().abs().y)
	for child: Node in node.get_children(): _measure_node(child, widget, result)

static func _in_summary(widget: Control, node: Node) -> bool:
	var summary: Node = widget.get("_summary_icon_box")
	return is_instance_valid(summary) and summary.is_ancestor_of(node)

static func sample_errors(measurement: Dictionary, entry: Dictionary, context: Dictionary) -> Array:
	var errors: Array = []
	if context.get("definition_source") == "base" and entry.get("variant", "base") != "base": errors.append("base-only builder received a modified definition")
	if context.get("definition_source") == "modified" and entry.get("variant", "base") == "base": errors.append("modified-only builder received a base definition")
	if context.get("factory") != "rules_tooltip" and measurement.get("printed_id") != entry["id"]: errors.append("printed card does not match sample")
	if context.get("factory") != "rules_tooltip" and measurement.get("definition_signature") != hash(entry["definition"]): errors.append("printed definition does not match sample")
	if context.get("factory") != "rules_tooltip" and measurement.get("rows_signature") != hash(entry.get("rows", [])): errors.append("printed variant rows do not match sample")
	if context.get("factory") != "rules_tooltip" and measurement.get("time_surcharge") != int(entry.get("time_surcharge", 0)): errors.append("printed surcharge does not match sample")
	if not measurement.get("visible", false): errors.append("sample face hidden")
	var text: Dictionary = measurement.get("text_px", {})
	if text.get("rules") == null and text.get("token_number") == null: errors.append("missing rules/token measurement")
	for role: String in text:
		if text[role] != null and (not is_finite(float(text[role])) or float(text[role]) <= 0.0): errors.append("invalid text measurement: " + role)
	var rows: Array = entry.get("rows", Icons.rows_for_card(entry["definition"]))
	var needs_icon: bool = false
	var needs_content: bool = false
	for row: Array in rows:
		for token: Dictionary in row:
			needs_icon = needs_icon or not str(token.get("icon", "")).is_empty() or token.get("kind") == "aoe_pattern"
			needs_content = needs_content or token.has("value") or str(token.get("kind", "")) in ["text", "rules_text", "surface_condition"]
	if rows.is_empty(): needs_content = not str(entry["definition"].get("description", "")).is_empty()
	if needs_content and int(measurement.get("content_text_runs", 0)) == 0: errors.append("missing rules content nodes")
	if needs_icon and context.get("factory") != "rules_tooltip" and (measurement.get("icon_px") == null or not is_finite(float(measurement["icon_px"])) or float(measurement["icon_px"]) <= 0.0): errors.append("missing expected icon measurement")
	if not context.get("exempt", false): errors.append_array(floor_errors(measurement))
	else: errors.append_array(measurement.get("rules_body_errors", []))
	return errors

static func coverage_errors(context: Dictionary, count: int) -> Array:
	return ["empty context: " + str(context.get("id", "unknown"))] if count <= 0 else []

static func _has_letters(text: String) -> bool:
	for character: String in text:
		if character.to_lower() != character.to_upper(): return true
	return false

static func _minimum(target: Dictionary, key: String, value: float) -> void:
	if target[key] == null or value < float(target[key]): target[key] = value

static func floor_errors(measurement: Dictionary) -> Array:
	var errors: Array = measurement.get("rules_body_errors", []).duplicate()
	if not measurement.get("visible", false): errors.append("sample face hidden")
	var text: Dictionary = measurement.get("text_px", {})
	if text.get("rules") == null and text.get("token_number") == null: errors.append("missing rules/token measurement")
	if measurement.get("expected_icons", true) and measurement.get("icon_px") == null: errors.append("missing expected icon measurement")
	for role: String in text:
		var px: Variant = text[role]
		if px != null and float(px) + EPSILON < TEXT_FLOOR: errors.append("%s %.3f < 14" % [role, px])
	if measurement.get("icon_px") != null and float(measurement["icon_px"]) + EPSILON < ICON_FLOOR: errors.append("icon %.3f < 16" % measurement["icon_px"])
	if measurement.get("shrunk", false): errors.append("rules text shrunk")
	return errors

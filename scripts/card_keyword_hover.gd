extends RefCounted
## Card readability (owner 2026-11-13): a full card shown for choosing or
## inspection (reward choices, the Scavenger shelf, the Graftwright)
## shows its keyword column beside it on pointer hover or navigation focus,
## like the combat hand and the opening boons. The card keeps its icons; its
## per-icon native tooltips are off because the column explains every icon.

const Icons = preload("res://scripts/action_icon_library.gd")
const Faces = preload("res://scripts/card_face_spec.gd")
const Glossary = preload("res://scripts/glossary.gd")
const SWEEPING_STRIKE := "all_enemies"

## trigger receives hover and focus; card is the CardWidget that supplies the
## keywords (the trigger itself when it is the card). The column sits beside
## the trigger.
static func bind(trigger: Control, stack: Control, card: Control = null) -> void:
	if trigger == null or stack == null or trigger.has_meta("card_keyword_hover"): return
	var source: Control = card if card != null else trigger
	trigger.set_meta("card_keyword_hover", true)
	if source.has_method("set_native_tooltips_enabled"): source.call("set_native_tooltips_enabled", false)
	trigger.mouse_entered.connect(_show.bind(trigger, stack, source))
	trigger.focus_entered.connect(_show.bind(trigger, stack, source))
	trigger.mouse_exited.connect(_hide.bind(trigger, stack))
	trigger.focus_exited.connect(_hide.bind(trigger, stack))
	trigger.tree_exiting.connect(Callable(stack, "hide_for").bind(trigger))

## The run scene's shared CardFocusTooltipStack (the hand's keyword column).
static func scene_stack(node: Node) -> Control:
	if node == null or not node.is_inside_tree(): return null
	return node.get_tree().root.find_child("CardFocusTooltipStack", true, false) as Control

static func entries_for(widget: Control) -> Array[Dictionary]:
	var leading: Array = []
	var card: Dictionary = widget.call("_display_card_def") if widget.has_method("_display_card_def") else {}
	if Icons.card_is_rite(card): leading.append("rite")
	var rows: Array = widget.call("display_summary_rows") if widget.has_method("display_summary_rows") else Icons.rows_for_card(card)
	return entries_for_card(str(widget.card_id) if widget is CardWidget else "", rows, leading)

static func entries_for_card(card_id: String, rows: Array, leading: Array = []) -> Array[Dictionary]:
	var entries: Array[Dictionary] = Icons.tooltip_entries_for_rows(rows, leading)
	var spec: Dictionary = Faces.spec_for(card_id)
	var sentence_panels: bool = bool(spec.get("sentence_panels", false))
	var has_sweep: bool = entries.any(_is_sweeping_strike)
	if not sentence_panels and not has_sweep:
		return entries
	var uses_sentence: bool = spec.has("sentence") and UiTypography.text_font() != null \
		and UiTypography.ui_font() != null and CardWidget.sentence_rows_match(card_id, rows)
	if not uses_sentence:
		if has_sweep and not _shows_sweeping_strike_in_rows(Faces.display_icon_rows(spec, rows)):
			entries.assign(entries.filter(func(entry: Dictionary) -> bool: return not _is_sweeping_strike(entry)))
		return entries
	var sentence_icons: Array = []
	for segment: Dictionary in spec["sentence"]:
		if segment.has("term") or segment.has("damage"):
			var icon: String = str(segment.get("term", segment.get("damage", "")))
			if not sentence_icons.has(icon): sentence_icons.append(icon)
		elif segment.has("text"):
			for icon: String in Glossary.ids_in_text(segment["text"]):
				if not sentence_icons.has(icon): sentence_icons.append(icon)
	var chip: Variant = spec.get("chip")
	if has_sweep and not sentence_icons.has(SWEEPING_STRIKE) and chip is Dictionary:
		if chip.get("icon") == SWEEPING_STRIKE or Glossary.ids_in_text(str(chip.get("word", ""))).has(SWEEPING_STRIKE):
			sentence_icons.append(SWEEPING_STRIKE)
	if not sentence_panels:
		# Use the printed face to suppress the hidden selector and retain the
		# normal order of the card's remaining keyword panels.
		if has_sweep and not sentence_icons.has(SWEEPING_STRIKE):
			entries.assign(entries.filter(func(entry: Dictionary) -> bool: return not _is_sweeping_strike(entry)))
		return entries
	var filtered: Array[Dictionary]
	for icon: String in sentence_icons:
		if icon == "time":
			# Time is an inline term here. The standalone card-cost badge is
			# deliberately excluded from the usual keyword stack.
			filtered.append_array(Icons.tooltip_entries_for_rows([], ["time"]))
		else:
			for entry: Dictionary in entries:
				if entry["icon"] == icon: filtered.append(entry)
	return filtered

static func _is_sweeping_strike(entry: Dictionary) -> bool:
	return entry["icon"] == SWEEPING_STRIKE or entry["glossary_key"] == SWEEPING_STRIKE

static func _shows_sweeping_strike_in_rows(rows: Array) -> bool:
	for row: Array in rows:
		for token: Dictionary in row:
			var kind: String = str(token.get("kind", ""))
			if kind == "aoe_pattern": continue
			if kind not in ["text", "rules_text"] and token.get("icon") == SWEEPING_STRIKE:
				return true
			if Glossary.ids_in_text(Icons.token_value_text(token)).has(SWEEPING_STRIKE):
				return true
	return false

static func _show(trigger: Control, stack: Control, source: Control) -> void:
	if not is_instance_valid(trigger) or not is_instance_valid(stack) or not is_instance_valid(source) or not trigger.is_visible_in_tree(): return
	var entries: Array[Dictionary] = entries_for(source)
	if entries.is_empty(): return
	stack.call("show_for", trigger, entries, false, Callable(), source.card_id if source is CardWidget else "")

static func _hide(trigger: Control, stack: Control) -> void:
	if not is_instance_valid(stack): return
	# hide_for only hides the column this card owns, so moving to a neighbour
	# that already took the column does not close it.
	stack.call("hide_for", trigger)

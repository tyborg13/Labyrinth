extends RefCounted
## Card readability (owner 2026-11-13): a full card shown for choosing or
## inspection (reward choices, the Scavenger shelf, the Graftwright)
## shows its keyword column beside it on pointer hover or navigation focus,
## like the combat hand and the opening boons. The card keeps its icons; its
## per-icon native tooltips are off because the column explains every icon.

const Icons = preload("res://scripts/action_icon_library.gd")

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
	trigger.tree_exiting.connect(_hide.bind(trigger, stack))

## The run scene's shared CardFocusTooltipStack (the hand's keyword column).
static func scene_stack(node: Node) -> Control:
	if node == null or not node.is_inside_tree(): return null
	return node.get_tree().root.find_child("CardFocusTooltipStack", true, false) as Control

static func entries_for(widget: Control) -> Array[Dictionary]:
	var leading: Array = []
	var card: Dictionary = widget.call("_display_card_def") if widget.has_method("_display_card_def") else {}
	if Icons.card_is_rite(card): leading.append("rite")
	var rows: Array = widget.call("display_summary_rows") if widget.has_method("display_summary_rows") else Icons.rows_for_card(card)
	return Icons.tooltip_entries_for_rows(rows, leading)

static func _show(trigger: Control, stack: Control, source: Control) -> void:
	if not is_instance_valid(trigger) or not is_instance_valid(stack) or not is_instance_valid(source) or not trigger.is_visible_in_tree(): return
	var entries: Array[Dictionary] = entries_for(source)
	if entries.is_empty(): return
	stack.call("show_for", trigger, entries)

static func _hide(trigger: Control, stack: Control) -> void:
	if not is_instance_valid(stack): return
	# hide_for only hides the column this card owns, so moving to a neighbour
	# that already took the column does not close it.
	stack.call("hide_for", trigger)

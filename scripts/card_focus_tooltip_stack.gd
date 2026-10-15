extends VBoxContainer
class_name CardFocusTooltipStack

const UiTooltipPanel = preload("res://scripts/ui_tooltip_panel.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const Glossary = preload("res://scripts/glossary.gd")
const InlineIconText = preload("res://scripts/inline_icon_text.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

# Retain tooltip_text for controller discovery and contextual inspection, while
# preventing Godot's delayed popup from duplicating the hover/focus stack.
class RelicOwner extends "res://scripts/ui_tooltip_panel_container.gd":
	func _get_tooltip(_at_position: Vector2) -> String:
		return ""

const CARD_GAP: float = 14.0
const SAFE_MARGIN: float = 18.0
const STACK_SEPARATION: int = 7
const RELIC_CHOICE_GAP: float = 12.0
const RELIC_CHOICE_SIDE_CLEARANCE: float = 24.0
const RELIC_CHOICE_SCREEN_MARGIN: float = 24.0
const RELIC_CHOICE_FLOW_COLUMNS: int = 3
const RELIC_CHOICE_FALLBACK_COLUMNS: int = 4
const OWNED_RELIC_GAP: float = 8.0

var _follow_target: Control
var _entries: Array[Dictionary]
var _relic_layout: bool = false
var _choice_host: Control
var _choice_panels: Array[Control]

func bind_relic(owner: Control, relic: Dictionary, choice_row: Control = null) -> void:
	owner.set_meta("glossary_relic", relic.duplicate(true))
	if choice_row != null:
		owner.set_meta("glossary_choice_row", choice_row)
	owner.mouse_entered.connect(_owner_interaction.bind(owner, "glossary_hovered", true))
	owner.mouse_exited.connect(_owner_interaction.bind(owner, "glossary_hovered", false))
	owner.focus_entered.connect(_owner_interaction.bind(owner, "glossary_focused", true))
	owner.focus_exited.connect(_owner_interaction.bind(owner, "glossary_focused", false))
	owner.tree_exiting.connect(hide_for.bind(owner))

func _owner_interaction(owner: Control, key: String, active: bool) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	owner.set_meta(key, active)
	if bool(owner.get_meta("glossary_hovered", false)) or bool(owner.get_meta("glossary_focused", false)):
		if _follow_target != owner or not visible:
			show_relic(owner, owner.get_meta("glossary_relic", {}) as Dictionary)
	else:
		var was_current: bool = _follow_target == owner
		hide_for(owner)
		# Pointer inspection can temporarily replace a keyboard/controller owner.
		# Returning from it must restore the still-focused relic's explanation.
		var focused: Control = get_viewport().gui_get_focus_owner()
		if was_current and focused != null and focused != owner and focused.has_meta("glossary_relic"):
			show_relic(focused, focused.get_meta("glossary_relic", {}) as Dictionary)

func show_relic(owner: Control, relic: Dictionary) -> void:
	var description: String = str(relic.get("description", ""))
	# Owned badges append live counters to their existing tooltip. Preserve them.
	if not owner.tooltip_text.is_empty():
		var newline: int = owner.tooltip_text.find("\n")
		if newline >= 0:
			description = owner.tooltip_text.substr(newline + 1)
	var entries: Array = []
	# The treasure choice already presents its title and description on the card.
	if not owner.has_meta("glossary_choice_row"):
		entries.append({
			"icon": "relic", "title": str(relic.get("name", "")),
			"description": description,
		})
	for id: String in Glossary.ids_in_text(description, Glossary.MAX_RELIC_PANELS):
		var entry: Dictionary = Glossary.lookup(id)
		var icon: String = str(entry.get("icon", ""))
		entries.append({
			"icon": icon, "title": entry["name"],
			"description": entry["definition"], "semantic_key": id,
			"texture": AssetLoader.load_texture(icon) if icon.begins_with("res://") else ActionIcons.icon_texture(icon),
		})
	show_for(owner, entries, true)

func hide_for(owner: Control) -> void:
	if _follow_target == owner:
		hide_stack()

func _ready() -> void:
	name = "CardFocusTooltipStack"
	visible = false
	top_level = true
	z_as_relative = false
	z_index = 1320
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", STACK_SEPARATION)
	set_process(false)

func show_for(target: Control, entries: Array, relic_layout: bool = false) -> void:
	hide_stack()
	_relic_layout = relic_layout
	if target == null or entries.is_empty():
		return
	_follow_target = target
	if _relic_layout and target.has_meta("glossary_choice_row"):
		# Keep the card/owned VBox tree intact. Choice panels alone use natural
		# widths in a measured flow that can switch between side and below-row.
		_choice_host = Control.new()
		_choice_host.name = "RelicGlossaryFlow"
		_choice_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_choice_host)
	for entry_var: Variant in entries:
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = (entry_var as Dictionary).duplicate(true)
		var icon_texture: Texture2D = entry.get("texture", null) as Texture2D
		if icon_texture == null and not _relic_layout:
			continue
		var body_lines := PackedStringArray()
		var description: String = str(entry.get("description", "")).strip_edges()
		if not description.is_empty():
			body_lines.append(description)
		var panel: PanelContainer = UiTooltipPanel.make_icon_lines(
			icon_texture,
			str(entry.get("title", "")),
			body_lines
		) if icon_texture != null else UiTooltipPanel.make_lines(str(entry.get("title", "")), body_lines)
		if _relic_layout and description.contains("["):
			_apply_definition_bbcode(panel, description, icon_texture != null)
		panel.name = "CardFocusTooltip_%02d_%s" % [
			_entries.size(),
			str(entry.get("icon", "icon")).to_pascal_case(),
		]
		panel.set_meta("icon_key", str(entry.get("icon", "")))
		panel.set_meta("semantic_key", str(entry.get("semantic_key", "")))
		if _choice_host != null:
			_choice_host.add_child(panel)
			_choice_panels.append(panel)
		else:
			add_child(panel)
		_entries.append(entry)
	if _entries.is_empty():
		_follow_target = null
		return
	visible = true
	set_process(true)
	update_minimum_size()
	_follow_target_now()

static func _apply_definition_bbcode(panel: PanelContainer, description: String, has_icon: bool) -> void:
	# Reuse the shared panel's body slot and typography; plain definitions and
	# every card keep the original node tree and exact rendering.
	var text_box: VBoxContainer = panel.get_child(0).get_child(1) as VBoxContainer if has_icon else panel.get_child(0) as VBoxContainer
	var body: Control = text_box.get_child(text_box.get_child_count() - 1) as Control
	var font_size: int = body.get_theme_font_size("normal_font_size" if body is RichTextLabel else "font_size")
	var rich: RichTextLabel = UiTooltipPanel._make_rich_label("", body.custom_minimum_size.x, UiTypography.ROLE_BODY, UiTooltipPanel.BODY_COLOR, 1)
	rich.custom_minimum_size = body.custom_minimum_size
	UiTypography.set_rich_text_size(rich, font_size)
	rich.bbcode_enabled = true
	InlineIconText.apply_to(rich, description)
	text_box.remove_child(body)
	body.queue_free()
	text_box.add_child(rich)

func hide_stack() -> void:
	visible = false
	set_process(false)
	_follow_target = null
	_entries.clear()
	_choice_panels.clear()
	_choice_host = null
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()

func entry_count() -> int:
	return _entries.size()

func entry_icon_keys() -> Array[String]:
	var keys: Array[String]
	for entry: Dictionary in _entries:
		keys.append(str(entry.get("icon", "")))
	return keys

func _process(_delta: float) -> void:
	_follow_target_now()

func _follow_target_now() -> void:
	if not visible or _follow_target == null or not is_instance_valid(_follow_target):
		hide_stack()
		return
	if not _follow_target.is_inside_tree() or _follow_target.is_queued_for_deletion():
		hide_stack()
		return
	if not _follow_target.is_visible_in_tree():
		hide_stack()
		return
	var card_rect: Rect2 = _visual_global_rect(_follow_target)
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	if _choice_host != null:
		_layout_choice(card_rect, viewport_rect)
		return
	var stack_size: Vector2 = get_combined_minimum_size()
	size = stack_size
	if _relic_layout:
		var left: float = clampf(card_rect.position.x, viewport_rect.position.x + SAFE_MARGIN, maxf(viewport_rect.position.x + SAFE_MARGIN, viewport_rect.end.x - SAFE_MARGIN - stack_size.x))
		global_position = Vector2(left, card_rect.end.y + OWNED_RELIC_GAP)
		return
	var target_position := Vector2(
		card_rect.end.x + CARD_GAP,
		card_rect.get_center().y - stack_size.y * 0.5
	)
	target_position.x = clampf(target_position.x, viewport_rect.position.x + SAFE_MARGIN, maxf(viewport_rect.position.x + SAFE_MARGIN, viewport_rect.end.x - SAFE_MARGIN - stack_size.x))
	target_position.y = clampf(
		target_position.y,
		viewport_rect.position.y + SAFE_MARGIN,
		viewport_rect.end.y - SAFE_MARGIN - stack_size.y
	)
	global_position = target_position

func _layout_choice(owner_rect: Rect2, viewport_rect: Rect2) -> void:
	var row: Control = _follow_target.get_meta("glossary_choice_row") as Control
	var choices: Array[Control]
	for child: Node in row.get_children():
		if child is Control and child.has_meta("glossary_relic") and (child as Control).is_visible_in_tree():
			choices.append(child as Control)
	var row_bottom: float = owner_rect.end.y
	for choice: Control in choices:
		row_bottom = maxf(row_bottom, _visual_global_rect(choice).end.y)
	var column_size: Vector2 = _measure_choice(1, STACK_SEPARATION)
	var column_fits: bool = owner_rect.position.y + column_size.y <= viewport_rect.end.y - RELIC_CHOICE_SCREEN_MARGIN
	# Only outer cards with both horizontal and vertical space keep a column.
	if column_fits and choices.size() > 1:
		if _follow_target == choices.front() and owner_rect.position.x - viewport_rect.position.x >= column_size.x + RELIC_CHOICE_SIDE_CLEARANCE:
			_arrange_choice(1, STACK_SEPARATION)
			global_position = Vector2(owner_rect.position.x - RELIC_CHOICE_GAP - column_size.x, owner_rect.position.y)
			return
		if _follow_target == choices.back() and viewport_rect.end.x - owner_rect.end.x >= column_size.x + RELIC_CHOICE_SIDE_CLEARANCE:
			_arrange_choice(1, STACK_SEPARATION)
			global_position = Vector2(owner_rect.end.x + RELIC_CHOICE_GAP, owner_rect.position.y)
			return
	var columns: int = RELIC_CHOICE_FLOW_COLUMNS
	var flow_size: Vector2 = _measure_choice(columns, RELIC_CHOICE_GAP)
	var top: float = row_bottom + RELIC_CHOICE_GAP
	if top + flow_size.y > viewport_rect.end.y - RELIC_CHOICE_SCREEN_MARGIN:
		columns = RELIC_CHOICE_FALLBACK_COLUMNS
		flow_size = _measure_choice(columns, RELIC_CHOICE_GAP)
	_arrange_choice(columns, RELIC_CHOICE_GAP)
	var left: float = clampf(owner_rect.get_center().x - flow_size.x * 0.5, viewport_rect.position.x + RELIC_CHOICE_SCREEN_MARGIN, maxf(viewport_rect.position.x + RELIC_CHOICE_SCREEN_MARGIN, viewport_rect.end.x - RELIC_CHOICE_SCREEN_MARGIN - flow_size.x))
	global_position = Vector2(left, top)

func _measure_choice(columns: int, gap: float) -> Vector2:
	var bounds := Vector2.ZERO
	for start: int in range(0, _choice_panels.size(), columns):
		var row_size := Vector2.ZERO
		for index: int in range(start, mini(start + columns, _choice_panels.size())):
			var panel_size: Vector2 = _choice_panels[index].get_combined_minimum_size()
			row_size.x += panel_size.x + (gap if index > start else 0.0)
			row_size.y = maxf(row_size.y, panel_size.y)
		bounds.x = maxf(bounds.x, row_size.x)
		bounds.y += row_size.y + (gap if start > 0 else 0.0)
	return bounds

func _arrange_choice(columns: int, gap: float) -> void:
	var top: float = 0.0
	for start: int in range(0, _choice_panels.size(), columns):
		var left: float = 0.0
		var row_height: float = 0.0
		for index: int in range(start, mini(start + columns, _choice_panels.size())):
			var panel: Control = _choice_panels[index]
			panel.size = panel.get_combined_minimum_size()
			panel.position = Vector2(left, top)
			left += panel.size.x + gap
			row_height = maxf(row_height, panel.size.y)
		top += row_height + gap
	var bounds: Vector2 = _measure_choice(columns, gap)
	_choice_host.custom_minimum_size = bounds
	_choice_host.size = bounds
	update_minimum_size()
	size = bounds
	set_meta("glossary_choice_columns", columns)

static func _visual_global_rect(control: Control) -> Rect2:
	var transform: Transform2D = control.get_global_transform_with_canvas()
	var points := PackedVector2Array([
		transform * Vector2.ZERO,
		transform * Vector2(control.size.x, 0.0),
		transform * control.size,
		transform * Vector2(0.0, control.size.y),
	])
	var minimum: Vector2 = points[0]
	var maximum: Vector2 = points[0]
	for point: Vector2 in points:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum)

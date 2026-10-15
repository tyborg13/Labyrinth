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
const RELIC_CHOICE_WIDE_COLUMNS: int = 5
const OWNED_RELIC_GAP: float = 8.0

var _follow_target: Control
var _entries: Array[Dictionary]
var _relic_layout: bool = false
var _panel_host: Control
var _panels: Array[Control]
var _mouse_focus_clear_pending: bool = false
var _layout_signature: Array = []
var _layout_passes: int = 0

func bind_relic(owner: Control, relic: Dictionary, choice_row: Control = null, owned_tray: Control = null, choice_top_bar: Control = null, choice_banner: Control = null) -> void:
	owner.set_meta("glossary_relic", relic.duplicate(true))
	if choice_row != null:
		owner.set_meta("glossary_choice_row", choice_row)
	if owned_tray != null:
		owner.set_meta("glossary_owned_tray", owned_tray)
	if choice_top_bar != null:
		owner.set_meta("glossary_choice_top_bar", choice_top_bar)
	if choice_banner != null:
		owner.set_meta("glossary_choice_banner", choice_banner)
	owner.mouse_entered.connect(_owner_interaction.bind(owner, "glossary_hovered", true))
	owner.mouse_exited.connect(_owner_interaction.bind(owner, "glossary_hovered", false))
	owner.focus_entered.connect(_owner_interaction.bind(owner, "glossary_focused", true))
	owner.focus_exited.connect(_owner_interaction.bind(owner, "glossary_focused", false))
	owner.tree_exiting.connect(hide_for.bind(owner))

func _owner_interaction(owner: Control, key: String, active: bool) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	owner.set_meta(key, active)
	if _owner_active(owner):
		if _follow_target != owner or not visible:
			show_relic(owner, owner.get_meta("glossary_relic", {}) as Dictionary)
	else:
		var was_current: bool = _follow_target == owner
		hide_for(owner)
		# Pointer inspection can temporarily replace a keyboard/controller owner.
		# Returning from it must restore the still-focused relic's explanation.
		var focused: Control = get_viewport().gui_get_focus_owner()
		if was_current and focused != null and focused != owner and focused.has_meta("glossary_relic") and _owner_active(focused):
			show_relic(focused, focused.get_meta("glossary_relic", {}) as Dictionary)

# One click guard, after GUI focus assignment. Leave native focus intact so Tab
# navigation keeps its starting point; only the stack's persistent focus clears.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		if not _mouse_focus_clear_pending:
			_mouse_focus_clear_pending = true
			call_deferred("_clear_mouse_focus")
	elif (event is InputEventKey or event is InputEventJoypadButton) and event.pressed:
		_mouse_focus_clear_pending = false
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.0:
		_mouse_focus_clear_pending = false

func _clear_mouse_focus() -> void:
	if not _mouse_focus_clear_pending:
		return
	_mouse_focus_clear_pending = false
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and focused.has_meta("glossary_relic"):
		_owner_interaction(focused, "glossary_focused", false)

func prepare_navigation_focus(owner: Control) -> void:
	_mouse_focus_clear_pending = false
	if owner.has_focus():
		_owner_interaction(owner, "glossary_focused", true)

static func _owner_active(owner: Control) -> bool:
	return bool(owner.get_meta("glossary_hovered", false)) or bool(owner.get_meta("glossary_focused", false))

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
		var icon: String = str(entry.get("icon", id))
		var title: String = ActionIcons.label(id)
		entries.append({
			"icon": icon, "title": title,
			"description": Glossary.definition(id, title), "semantic_key": id,
			"texture": AssetLoader.load_texture(icon) if icon.begins_with("res://") else ActionIcons.icon_texture(icon),
		})
	show_for(owner, entries, true)

func hide_for(owner: Control) -> void:
	if _follow_target == owner:
		hide_stack(true)

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
	hide_stack(true)
	_relic_layout = relic_layout
	if target == null or entries.is_empty():
		return
	_follow_target = target
	if _relic_layout:
		# Relics can flow across columns; card stacks retain their original VBox.
		_panel_host = Control.new()
		_panel_host.name = "RelicGlossaryFlow"
		_panel_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_panel_host)
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
		if _panel_host != null:
			_panel_host.add_child(panel)
			_panels.append(panel)
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

func hide_stack(force: bool = false) -> void:
	if not force and _relic_layout and is_instance_valid(_follow_target) and _follow_target.is_inside_tree() and _follow_target.is_visible_in_tree() and _owner_active(_follow_target):
		return
	visible = false
	set_process(false)
	_follow_target = null
	_entries.clear()
	_panels.clear()
	_layout_signature.clear()
	_panel_host = null
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
		hide_stack(true)
		return
	if not _follow_target.is_inside_tree() or _follow_target.is_queued_for_deletion():
		hide_stack(true)
		return
	if not _follow_target.is_visible_in_tree():
		hide_stack(true)
		return
	var card_rect: Rect2 = _visual_global_rect(_follow_target)
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	if _panel_host != null:
		if _follow_target.has_meta("glossary_choice_row"):
			_layout_choice(card_rect, viewport_rect)
		else:
			_layout_owned(card_rect, viewport_rect)
		return
	var stack_size: Vector2 = get_combined_minimum_size()
	size = stack_size
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
	var row_top: float = owner_rect.position.y
	var row_rects: Array = []
	for choice: Control in choices:
		var rect: Rect2 = _visual_global_rect(choice)
		row_rects.append(rect)
		row_bottom = maxf(row_bottom, rect.end.y)
		row_top = minf(row_top, rect.position.y)
	var top_bar_rect: Rect2 = _bound_rect("glossary_choice_top_bar")
	row_rects.append(top_bar_rect)
	var banner_rect: Rect2 = _bound_rect("glossary_choice_banner")
	row_rects.append(banner_rect)
	if _layout_unchanged(owner_rect, viewport_rect, row_rects):
		return
	set_meta("glossary_choice_above", false)
	set_meta("glossary_choice_overflow", false)
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
	var available_width: float = viewport_rect.size.x - 2.0 * RELIC_CHOICE_SCREEN_MARGIN
	# Try each below-row flow in order. A wider flow must fit horizontally too.
	for candidate: int in [RELIC_CHOICE_FALLBACK_COLUMNS, RELIC_CHOICE_WIDE_COLUMNS]:
		if top + flow_size.y <= viewport_rect.end.y - RELIC_CHOICE_SCREEN_MARGIN:
			break
		var candidate_size: Vector2 = _measure_choice(candidate, RELIC_CHOICE_GAP)
		if candidate_size.x <= available_width:
			columns = candidate
			flow_size = candidate_size
	var left: float = clampf(owner_rect.get_center().x - flow_size.x * 0.5, viewport_rect.position.x + RELIC_CHOICE_SCREEN_MARGIN, maxf(viewport_rect.position.x + RELIC_CHOICE_SCREEN_MARGIN, viewport_rect.end.x - RELIC_CHOICE_SCREEN_MARGIN - flow_size.x))
	if top + flow_size.y > viewport_rect.end.y - RELIC_CHOICE_SCREEN_MARGIN:
		var minimum_top: float = maxf(viewport_rect.position.y + RELIC_CHOICE_SCREEN_MARGIN, top_bar_rect.end.y + RELIC_CHOICE_GAP)
		top = maxf(minimum_top, row_top - RELIC_CHOICE_GAP - flow_size.y)
		set_meta("glossary_choice_above", true)
		# Banner overlap is reserved for an impossible fit. First try the two
		# clear vertical regions between the HUD and the card row.
		var banner_blocked: bool = false
		if banner_rect.has_area() and Rect2(Vector2(left, top), flow_size).intersects(banner_rect):
			var above_banner: float = banner_rect.position.y - RELIC_CHOICE_GAP - flow_size.y
			var below_banner: float = maxf(minimum_top, banner_rect.end.y + RELIC_CHOICE_GAP)
			if above_banner >= minimum_top:
				top = above_banner
			elif below_banner + flow_size.y <= row_top - RELIC_CHOICE_GAP:
				top = below_banner
			else:
				banner_blocked = true
		var cannot_fit: bool = banner_blocked or top + flow_size.y > row_top - RELIC_CHOICE_GAP or flow_size.x > available_width or top + flow_size.y > viewport_rect.end.y - RELIC_CHOICE_SCREEN_MARGIN
		set_meta("glossary_choice_overflow", cannot_fit)
		if cannot_fit:
			push_warning("Relic glossary above-row overflow: %s, viewport=%s, block=%s, top=%s, row_top=%s" % [_follow_target.name, viewport_rect.size, flow_size, top, row_top])
	# A short overflow row may enter the card row. Keep its panels on the far
	# side of the block so the hovered card remains completely unobscured.
	var align_last_row_right: bool = bool(get_meta("glossary_choice_overflow")) and owner_rect.get_center().x < left + flow_size.x * 0.5
	_arrange_choice(columns, RELIC_CHOICE_GAP, align_last_row_right)
	global_position = Vector2(left, top)

func _bound_rect(key: String) -> Rect2:
	if not _follow_target.has_meta(key):
		return Rect2()
	var boundary: Control = _follow_target.get_meta(key, null) as Control
	return _visual_global_rect(boundary) if is_instance_valid(boundary) and boundary.is_visible_in_tree() else Rect2()

# Include all row rectangles and measured panel sizes: neighbour height, font,
# content or viewport changes invalidate placement; idle frames do no arranging.
func _layout_unchanged(owner_rect: Rect2, viewport_rect: Rect2, row_rects: Array) -> bool:
	var signature: Array = [owner_rect, viewport_rect, row_rects]
	for panel: Control in _panels:
		signature.append(panel.get_combined_minimum_size())
	if signature == _layout_signature:
		return true
	_layout_signature = signature
	_layout_passes += 1
	return false

func _owned_column_size(start: int, end: int) -> Vector2:
	var bounds := Vector2.ZERO
	for index: int in range(start, end):
		var minimum: Vector2 = _panels[index].get_combined_minimum_size()
		bounds.x = maxf(bounds.x, minimum.x)
		bounds.y += minimum.y + (STACK_SEPARATION if index > start else 0)
	return bounds

func _layout_owned(owner_rect: Rect2, viewport_rect: Rect2) -> void:
	var tray_rect: Rect2 = _bound_rect("glossary_owned_tray")
	if _layout_unchanged(owner_rect, viewport_rect, [tray_rect]):
		return
	var top: float = maxf(owner_rect.end.y, tray_rect.end.y) + OWNED_RELIC_GAP
	var available: float = viewport_rect.end.y - SAFE_MARGIN - top
	var split: int = _panels.size()
	var first: Vector2 = _owned_column_size(0, split)
	var second := Vector2.ZERO
	if first.y > available and _panels.size() > 1:
		# Keep the relic description first and fill downwards before overflowing
		# glossary panels to the right. If neither column fits below the owner,
		# choose the shortest block before clamping it vertically.
		var best_height: float = INF
		for candidate: int in range(1, _panels.size()):
			var left: Vector2 = _owned_column_size(0, candidate)
			var right: Vector2 = _owned_column_size(candidate, _panels.size())
			var height: float = maxf(left.y, right.y)
			if height <= available or (best_height > available and height < best_height):
				split = candidate
				first = left
				second = right
				best_height = height
	var bounds := Vector2(first.x + (RELIC_CHOICE_GAP + second.x if second.x > 0.0 else 0.0), maxf(first.y, second.y))
	for start: int in [0, split]:
		var end: int = split if start == 0 else _panels.size()
		var y: float = 0.0
		for index: int in range(start, end):
			var panel: Control = _panels[index]
			panel.size = Vector2(first.x if start == 0 else second.x, panel.get_combined_minimum_size().y)
			panel.position = Vector2(0.0 if start == 0 else first.x + RELIC_CHOICE_GAP, y)
			y += panel.size.y + STACK_SEPARATION
	_panel_host.custom_minimum_size = bounds
	_panel_host.size = bounds
	update_minimum_size()
	size = bounds
	set_meta("glossary_owned_split", split)
	global_position = Vector2(
		clampf(owner_rect.position.x, viewport_rect.position.x + SAFE_MARGIN, viewport_rect.end.x - SAFE_MARGIN - bounds.x),
		clampf(top, viewport_rect.position.y + SAFE_MARGIN, viewport_rect.end.y - SAFE_MARGIN - bounds.y)
	)

func _measure_choice(columns: int, gap: float) -> Vector2:
	var bounds := Vector2.ZERO
	for start: int in range(0, _panels.size(), columns):
		var row_size := Vector2.ZERO
		for index: int in range(start, mini(start + columns, _panels.size())):
			var panel_size: Vector2 = _panels[index].get_combined_minimum_size()
			row_size.x += panel_size.x + (gap if index > start else 0.0)
			row_size.y = maxf(row_size.y, panel_size.y)
		bounds.x = maxf(bounds.x, row_size.x)
		bounds.y += row_size.y + (gap if start > 0 else 0.0)
	return bounds

func _arrange_choice(columns: int, gap: float, align_last_row_right: bool = false) -> void:
	var bounds: Vector2 = _measure_choice(columns, gap)
	var top: float = 0.0
	for start: int in range(0, _panels.size(), columns):
		var left: float = 0.0
		if align_last_row_right and start + columns > _panels.size():
			var row_width: float = 0.0
			for index: int in range(start, _panels.size()):
				row_width += _panels[index].get_combined_minimum_size().x + (gap if index > start else 0.0)
			left = bounds.x - row_width
		var row_height: float = 0.0
		for index: int in range(start, mini(start + columns, _panels.size())):
			var panel: Control = _panels[index]
			panel.size = panel.get_combined_minimum_size()
			panel.position = Vector2(left, top)
			left += panel.size.x + gap
			row_height = maxf(row_height, panel.size.y)
		top += row_height + gap
	_panel_host.custom_minimum_size = bounds
	_panel_host.size = bounds
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

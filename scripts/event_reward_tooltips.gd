extends RefCounted
## Keyword panels share the reward fade. Their container stays out of the plate layout.
const Stack = preload("res://scripts/card_focus_tooltip_stack.gd")
const Keywords = preload("res://scripts/card_keyword_hover.gd")
const Inline = preload("res://scripts/inline_icon_text.gd")
const GAP: float = 16.0

static func build(stage: Control) -> Control:
	var host := Control.new()
	host.name = "EventRewardTooltips"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keep the shared tooltip ornament (at z -1) above the event painting.
	host.z_index = 1
	var seen: Dictionary = {}
	for node: Node in stage.find_children("EventRewardPlate", "PanelContainer", true, false):
		for id: String in Inline.concept_keys(str(node.get_meta("reward_description", ""))):
			if seen.has(id): continue
			seen[id] = true
			host.add_child(Inline.glossary_panel(Inline.ActionIcons.tooltip(id)))
	for node: Node in stage.find_children("CardWidget", "", true, false):
		for entry: Dictionary in Keywords.entries_for(node as Control):
			var key: String = str(entry.get("semantic_key", entry.get("tooltip", "")))
			if seen.has(key) or entry.get("texture") == null: continue
			seen[key] = true
			var description: String = str(entry.get("display_description", entry.get("description", ""))).strip_edges()
			var lines := PackedStringArray()
			if not description.is_empty(): lines.append(description)
			host.add_child(Stack.make_entry_panel(entry, lines))
	if host.get_child_count() == 0:
		host.free()
		return null
	stage.add_child(host)
	return host

## Work in the event's reference canvas, where the painting and choices share
## an origin. The same margin and gap then scale with the rest of the event.
static func place(stage: Control, host: Control, art_bounds: Rect2, content_scale: float) -> void:
	var center: Vector2 = stage.position + stage.size * 0.5
	var half_size: Vector2 = stage.size * 0.5
	var left_room: float = center.x - art_bounds.position.x
	var right_room: float = art_bounds.end.x - center.x
	var vertical_room: float = minf(center.y - art_bounds.position.y, art_bounds.end.y - center.y)
	var fit: float = minf(1.0, minf(minf(left_room, right_room) / half_size.x, vertical_room / half_size.y))
	if host == null:
		stage.scale = Vector2.ONE * fit
		return

	var sizes: Array[Vector2]
	for panel: Control in host.get_children():
		sizes.append(panel.get_combined_minimum_size())
	var split: int = _column_break(sizes, art_bounds.size.y / content_scale)
	var first: Vector2 = _column_size(sizes, 0, split) * content_scale
	var second: Vector2 = _column_size(sizes, split, sizes.size()) * content_scale
	fit = minf(fit, art_bounds.size.y / maxf(first.y, second.y))
	var first_left: float = (left_room - GAP) / (half_size.x + first.x)
	var first_right: float = (right_room - GAP) / (half_size.x + first.x)
	var first_on_right: bool = second == Vector2.ZERO and first_left < fit and first_right >= fit
	var second_on_right: bool = false
	var width_fit: float = first_right if first_on_right else first_left
	if second != Vector2.ZERO:
		var both_left: float = (left_room - 2.0 * GAP) / (half_size.x + first.x + second.x)
		second_on_right = both_left < fit
		width_fit = minf(first_left, (right_room - GAP) / (half_size.x + second.x)) if second_on_right else both_left
	# Wide reward groups can use the existing uniform fit to leave room for
	# help on the art side, while the pivot keeps the painting centre fixed.
	fit = minf(fit, width_fit)
	stage.scale = Vector2.ONE * fit
	var top: float = minf(center.y - half_size.y * fit, art_bounds.end.y - maxf(first.y, second.y) * fit)
	var left: float = center.x - half_size.x * fit - GAP
	var right: float = center.x + half_size.x * fit + GAP
	var first_x: float = right if first_on_right else left - first.x * fit
	var second_x: float = right if second_on_right else first_x - GAP - second.x * fit
	var inverse: Transform2D = stage.get_transform().affine_inverse()
	_place_column(host, sizes, 0, split, first.x / content_scale, content_scale, inverse * Vector2(first_x, top))
	_place_column(host, sizes, split, sizes.size(), second.x / content_scale, content_scale, inverse * Vector2(second_x, top))

static func _column_break(sizes: Array[Vector2], max_height: float) -> int:
	if sizes.size() < 2 or _column_size(sizes, 0, sizes.size()).y <= max_height:
		return sizes.size()
	var best: int = 1
	var shortest: float = INF
	# Fill down the first column. If two columns still need fitting, choose
	# the split with the shortest taller column to retain the most scale.
	for split: int in range(sizes.size() - 1, 0, -1):
		var height: float = maxf(_column_size(sizes, 0, split).y, _column_size(sizes, split, sizes.size()).y)
		if height <= max_height: return split
		if height < shortest:
			shortest = height
			best = split
	return best

static func _column_size(sizes: Array[Vector2], start: int, end: int) -> Vector2:
	var result := Vector2.ZERO
	for index: int in range(start, end):
		result.x = maxf(result.x, sizes[index].x)
		result.y += sizes[index].y + (Stack.STACK_SEPARATION if index > start else 0)
	return result

static func _place_column(host: Control, sizes: Array[Vector2], start: int, end: int, width: float, scale_factor: float, origin: Vector2) -> void:
	for index: int in range(start, end):
		var panel: Control = host.get_child(index)
		panel.size = Vector2(width, sizes[index].y)
		panel.scale = Vector2.ONE * scale_factor
		panel.position = origin
		origin.y += (sizes[index].y + Stack.STACK_SEPARATION) * scale_factor

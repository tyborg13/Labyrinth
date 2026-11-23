extends RefCounted

const Glossary = preload("res://scripts/glossary.gd")
const Inline = preload("res://scripts/inline_icon_text.gd")
const Panels = preload("res://scripts/ui_tooltip_panel.gd")
const RELEASE_WIDTH: int = 226
const MAX_WIDTH: int = 248
const EXAMPLE_COUNT: int = 3
const PREVIEW_WIDTH: int = 237
const EXAMPLES := ["all_enemies", "empower", "follow_up"]
const LAYOUT_FRAMES: int = 3

static func panel_for(id: String, width: int) -> Control:
	var panel: Control = Inline.glossary_panel(Inline.ActionIcons.tooltip(id))
	var icon: Control = panel.find_child("TooltipIcon", true, false) as Control
	if icon != null:
		# Override precisely the minima that the production icon-body width
		# supplies. Rich runs with their own larger floor keep that floor.
		var box: Control = icon.get_parent().get_child(1) as Control
		for label: Control in box.get_children():
			if is_equal_approx(label.custom_minimum_size.x, Panels.ICON_BODY_WIDTH):
				label.custom_minimum_size.x = width
	return panel

static func _last_line(body: Control) -> Dictionary:
	if body is RichTextLabel:
		var count: int = body.get_line_count()
		var parsed: String = body.get_parsed_text()
		var bounds: Vector2i = body.get_line_range(count - 1) if count > 0 else Vector2i.ZERO
		return {"count": count, "text": parsed.substr(bounds.x, bounds.y - bounds.x).strip_edges()}
	var label := body as Label
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var text: String = label.text
	var line_flags: int = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var paragraph := TextParagraph.new()
	paragraph.width = label.size.x
	paragraph.break_flags = line_flags
	paragraph.add_string(text, font, font_size)
	var count: int = paragraph.get_line_count()
	assert(count == label.get_line_count(), "Font measurement differs from Label for " + text)
	var bounds: Vector2i = paragraph.get_line_range(count - 1)
	return {"count": count, "text": text.substr(bounds.x, bounds.y - bounds.x).strip_edges()}


static func sweep(viewport: SubViewport) -> Dictionary:
	var tree: SceneTree = viewport.get_tree()
	var entries: Array = Glossary.all_entries()
	var by_width: Dictionary = {}
	var lines_by_width: Dictionary = {}
	var best: int = RELEASE_WIDTH
	var icon_count: int = 0
	var rich_count: int = 0
	for width: int in range(RELEASE_WIDTH, MAX_WIDTH + 1):
		var samples: Array[Control]
		for entry: Dictionary in entries:
			var panel: Control = panel_for(entry["id"], width)
			panel.position.x = -viewport.size.x
			viewport.add_child(panel)
			samples.append(panel)
		for frame: int in range(LAYOUT_FRAMES):
			await tree.process_frame
		var single: PackedStringArray = []
		var last_lines: Dictionary = {}
		for index: int in range(entries.size()):
			var panel: Control = samples[index]
			var icon: Control = panel.find_child("TooltipIcon", true, false) as Control
			var box: Control = icon.get_parent().get_child(1) if icon != null else panel.get_child(0)
			if width == RELEASE_WIDTH: icon_count += int(icon != null)
			assert(box.get_child_count() >= 2, "Glossary fixture lacks a body: " + entries[index]["id"])
			var body: Control = box.get_child(1)
			if width == RELEASE_WIDTH: rich_count += int(body is RichTextLabel)
			var line: Dictionary = _last_line(body)
			var id: String = entries[index]["id"]
			last_lines[id] = line["text"]
			if int(line["count"]) > 1 and not str(line["text"]).is_empty() and str(line["text"]).split(" ", false).size() == 1:
				single.append(id)
			viewport.remove_child(panel)
			panel.queue_free()
		single.sort()
		by_width[width] = single
		lines_by_width[width] = last_lines
		if single.size() < by_width[best].size():
			best = width
		print("POL60 WIDTH %d: %d" % [width, single.size()])
	var examples: PackedStringArray = []
	for id: String in by_width[RELEASE_WIDTH]:
		if not by_width[PREVIEW_WIDTH].has(id) and lines_by_width[RELEASE_WIDTH][id] != lines_by_width[PREVIEW_WIDTH][id]:
			if panel_has_icon(id): examples.append(id)
			if examples.size() == EXAMPLE_COUNT: break
	print("POL60 GLOSSARY: %d entries, %d icon pop-ups, %d rich bodies" % [entries.size(), icon_count, rich_count])
	print("POL60 WIDTH BEST %d: %s" % [best, ", ".join(by_width[best])])
	for id: String in examples:
		print("POL60 WIDTH EXAMPLE %s: %s -> %s" % [id, lines_by_width[RELEASE_WIDTH][id], lines_by_width[PREVIEW_WIDTH][id]])
	return {"best": best, "examples": examples, "counts": by_width}

static func panel_has_icon(id: String) -> bool:
	return not Inline.ActionIcons.tooltip_entries_for_rows([[Inline.ActionIcons.token_for(id)]]).is_empty()

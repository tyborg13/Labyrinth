extends RefCounted
# Read native caches only. Do not shape text, render glyphs or alter resources.
const Typography = preload("res://scripts/ui_typography.gd")
static func capture(root: Node) -> Dictionary:
	var fonts: Dictionary = {}
	for font: Font in [Typography.display_font(), Typography.ui_font(), Typography.text_font(), Typography.eyebrow_font(), ThemeDB.fallback_font]:
		if font != null: fonts[font] = true
	var controls: Array[Dictionary]
	var pending: Array[Node]
	pending.append(root)
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child: Node in node.get_children(): pending.append(child)
		if node is Control:
			var control: Control = node as Control
			var font: Font = control.get_theme_default_font()
			if font != null: fonts[font] = true
		if node is Label:
			var label: Label = node as Label
			var font: Font = label.label_settings.font if label.label_settings != null and label.label_settings.font != null else label.get_theme_font("font")
			if font != null:
				fonts[font] = true
				if "Intro" in str(label.name) or "Turn" in str(label.get_parent().name):
					var rids: Array[int]
					for rid: RID in font.get_rids(): rids.append(rid.get_id())
					controls.append({"path": str(label.get_path()), "text": label.text, "font": font.resource_path, "rids": rids, "font_size": label.label_settings.font_size if label.label_settings != null else label.get_theme_font_size("font_size"), "outline": label.get_theme_constant("outline_size"), "shadow_outline": label.get_theme_constant("shadow_outline_size"), "global_scale": str(label.get_global_transform().get_scale()), "visible": label.is_visible_in_tree(), "viewport_oversampling": label.get_viewport().get_oversampling()})
		elif node is Button:
			var font: Font = (node as Button).get_theme_font("font")
			if font != null: fonts[font] = true
		elif node is RichTextLabel:
			for name: String in ["normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"]:
				var font: Font = (node as RichTextLabel).get_theme_font(name)
				if font != null: fonts[font] = true
	var result: Dictionary = {"frame": Engine.get_process_frames(), "viewport_oversampling": root.get_viewport().get_oversampling(), "controls": controls, "fonts": {}}
	var server: TextServer = TextServerManager.get_primary_interface()
	for font: Font in fonts:
		for rid: RID in font.get_rids():
			var key: String = str(rid.get_id())
			result["fonts"][key] = {"path": font.resource_path, "oversampling_override": server.font_get_oversampling(rid), "msdf": server.font_is_multichannel_signed_distance_field(rid), "fixed_size": server.font_get_fixed_size(rid), "sizes": server.font_get_size_cache_info(rid)}
	return result

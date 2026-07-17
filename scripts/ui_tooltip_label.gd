extends Label

const UiTooltipPanel = preload("res://scripts/ui_tooltip_panel.gd")


func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.strip_edges().is_empty():
		return null
	return UiTooltipPanel.make_text(for_text)

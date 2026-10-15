extends "res://tests/chronicle_test.gd"

# Debug-only proof of the proposed viewport height; production stays at 690
# until the director resolves the pending design choice.
func _test_five_section_layout(panel: Control) -> void:
	var scroller: ScrollContainer = panel.get("_detail_scroll")
	scroller.size.y = 718
	await super._test_five_section_layout(panel)

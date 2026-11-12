extends RefCounted

# Legacy semantic expectations stay useful without recreating the removed UI.
static func semantic_line(scene: Node) -> String:
	var summary: Dictionary = scene.call("_pass_preview_summary")
	var wait_time: int = int(summary.get("wait_time", 0))
	var text: String = "+%d" % wait_time if wait_time > 0 else "TURN END"
	for entry: Dictionary in scene.call("_pass_preview_forecast_entries", summary):
		text += (" " if bool(entry.get("suffix", false)) else "  •  ") + str(entry["text"])
	return text

static func assert_rows(scene: Node, expect: Callable, context: String) -> void:
	var chip: Button = scene.find_child("PassPreviewChip", true, false) as Button
	expect.call(chip != null and scene.find_child("PassPreviewForecastLine", true, false) == null and scene.find_child("PassPreviewDamageRow", true, false) == null, context + ": PASS retains no forecast strip nodes")
	if chip == null: return
	var summary: Dictionary = scene.call("_pass_preview_summary")
	expect.call(chip.get_meta("pass_forecast_summary", {}) == summary, context + ": panel receives the same cached preview summary")
	var panel: Control = chip.get_node_or_null("PassForecastFocusTooltip") as Control
	expect.call(panel != null, context + ": retained forecast panel exists")

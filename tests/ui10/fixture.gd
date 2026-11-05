extends RefCounted

## Shared ui-10 geometry checks for the headless score test and native probe.
const GEOMETRY_TOLERANCE: float = 0.01

static func assert_dragons(overlay: Control, expect: Callable) -> void:
	var dragon_rows: int = 0
	for column_name: String in ["ScoreRows", "FeatRows"]:
		var column: Control = overlay.find_child(column_name, true, false) as Control
		expect.call(column != null, "The score ledger retains both named columns")
		if column == null: continue
		for row: Control in column.get_children():
			var detail: Label = row.get_node("ScoreDetail") as Label
			if not detail.has_node("DragonName0"): continue
			dragon_rows += 1
			var names: PackedStringArray = detail.text.split(", ", false)
			expect.call(detail.get_child_count() == names.size() and not names.is_empty(), "Every escaped dragon has its own complete name label")
			expect.call(detail.tooltip_text == detail.text and detail.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, "Escaped dragon names retain their full tooltip without ellipsis")
			var previous: Label
			for index: int in range(names.size()):
				var label: Label = detail.get_node_or_null("DragonName%d" % index) as Label
				expect.call(label != null, "Dragon name labels retain their stable ordered ids")
				if label == null: continue
				var expected: String = names[index] + ("," if index < names.size() - 1 else "")
				expect.call(label.text == expected and label.get_theme_font_size("font_size") == 16 and not label.clip_text and label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, "Each escaped dragon name keeps its complete authored text and type size")
				var rect := Rect2(label.position, label.size)
				expect.call(Rect2(Vector2.ZERO, detail.size).grow(GEOMETRY_TOLERANCE).encloses(rect), "Every dragon name fits inside its detail region")
				expect.call(Rect2(Vector2.ZERO, row.size).grow(GEOMETRY_TOLERANCE).encloses(Rect2(detail.position + label.position, label.size)), "Every dragon name fits inside its expanded ledger row")
				if previous != null:
					expect.call(not rect.intersects(Rect2(previous.position, previous.size)), "Adjacent dragon names never overlap")
				previous = label
	expect.call(dragon_rows > 0, "The dragon geometry fixture exercises an escaped-dragon row")

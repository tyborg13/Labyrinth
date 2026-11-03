extends RefCounted

const WIDTH: float = 420.0

# The intent layout is retained; wrapping happens when its rows are built,
# never while the overlay is painted. Measure with the font used to draw it.
static func lines(text: String, font: Font, font_size: int) -> PackedStringArray:
	var result := PackedStringArray()
	var line: String = ""
	for word: String in text.split(" ", false):
		var candidate: String = word if line.is_empty() else line + " " + word
		if not line.is_empty() and font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > WIDTH:
			result.append(line)
			line = word
		else:
			line = candidate
	if not line.is_empty(): result.append(line)
	return result

static func title_index(rows: Array) -> int:
	if rows.is_empty() or (rows[0] as Array).is_empty() or not bool(rows[0][0].get("burst_trait", false)): return 0
	var index: int = 1
	while index < rows.size() and not (rows[index] as Array).is_empty() and bool(rows[index][0].get("burst_rules", false)): index += 1
	return index

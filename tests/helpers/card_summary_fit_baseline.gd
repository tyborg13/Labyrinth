extends RefCounted

const SOURCE_WIDGET_SHA256: String = "8b794e01111cbbaa5d36f980bb63e2c6e9dfaf38727054a0f9e24085d4240441"
const NAMED_CARDS: Array = ["worldbreak", "cloudstep_loop", "hall_of_mirrors"]
const CONTROL_CARD: String = "quick_stab"
# Gear-02 removes the Follow-up row from the control card. Keep the original
# capture and its fit margins while pinning the approved new base layout.
const QUICK_STAB_WITH_FOLLOW_UP: String = "b2d114f29db0bb27838c452690965a10e68581ba01baea6a71a313ff243eadd7"
const QUICK_STAB_LAYOUT: String = "df9a725617699b0cda8df02c916d2266684b958c6d2d3aa648c917e398c177ce"
# Owner-approved definition changes after the capture. Their faces must still
# pass every fit check, but their layouts and upgrade samples no longer match it.
# crd-03 (2026-11-07): Cloudstep Loop costs 2 and draws 1.
# txt-13 replaces the Hall of Mirrors and Worldbreak text chips with diagrams.
# pla-04 replaces Worldbreak's line damage with the shared Burst damage field.
const PATTERN_ROWS_CHANGED: Array = ["hall_of_mirrors", "worldbreak"]
const DEFINITION_CHANGED: Array = ["cloudstep_loop", "worldbreak"]

static func pinned(key: String) -> bool:
	return not DEFINITION_CHANGED.has(key.get_slice("/", 1))

static func focused_entries(entries: Array) -> Array:
	# All formerly changed faces are in the three named families. Quick Stab
	# supplies the control in every context, including larger poses.
	return entries.filter(func(e: Dictionary) -> bool: return NAMED_CARDS.has(e["id"]) or (e["id"] == CONTROL_CARD and e["variant"] == "base"))

static func load_samples(full_matrix: bool) -> Dictionary:
	var path: String = "res://tests/fixtures/card_summary_fit_baseline_%s.json" % ("full" if full_matrix else "focused")
	if not FileAccess.file_exists(path): return {}
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	if int(fixture.get("version", 0)) != 1 or fixture.get("source_widget_sha256") != SOURCE_WIDGET_SHA256:
		return {}
	var result: Dictionary = {}
	for context: String in fixture["contexts"]:
		var samples: Array = fixture["contexts"][context]
		if samples.size() != fixture["definition_keys"].size(): return {}
		for index: int in range(samples.size()):
			var sample: Array = samples[index]
			var definition: String = fixture["definition_keys"][index]
			var layout: String = fixture["fingerprints"][int(sample[0])]
			if definition == CONTROL_CARD + "/base" and layout == QUICK_STAB_WITH_FOLLOW_UP:
				layout = QUICK_STAB_LAYOUT
			result[context + "/" + definition] = {"layout": layout, "margin_px": sample[1]}
	return result if result.size() == int(fixture.get("sample_count", 0)) else {}

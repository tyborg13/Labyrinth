extends RefCounted

const SOURCE_WIDGET_SHA256: String = "8b794e01111cbbaa5d36f980bb63e2c6e9dfaf38727054a0f9e24085d4240441"
const NAMED_CARDS: Array = ["worldbreak", "cloudstep_loop", "hall_of_mirrors"]
const CONTROL_CARD: String = "quick_stab"
# Owner-approved definition changes after the capture. Their faces must still
# pass every fit check, but their layouts and upgrade samples no longer match it.
# crd-03 (2026-11-07): Cloudstep Loop costs 2 and draws 1.
const DEFINITION_CHANGED: Array = ["cloudstep_loop"]

static func pinned(key: String) -> bool:
	return not DEFINITION_CHANGED.has(key.get_slice("/", 1))

static func focused_entries(entries: Array) -> Array:
	# All formerly changed faces are in the three named families. Quick Stab
	# supplies an unaffected control in EVERY context, including larger poses.
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
			result[context + "/" + fixture["definition_keys"][index]] = {"layout": fixture["fingerprints"][int(sample[0])], "margin_px": sample[1]}
	return result if result.size() == int(fixture.get("sample_count", 0)) else {}

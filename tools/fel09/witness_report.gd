extends RefCounted

const JSON_PATH := "res://tools/fel09/census.json"
const REPORT_PATH := "res://tools/fel09/census.md"


static func write_json(path: String, doc: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	return file != null and file.store_string(JSON.stringify(doc, "\t", false) + "\n")


static func write_witness(doc: Dictionary) -> bool:
	if not write_json(JSON_PATH, doc): return false
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null: return false
	file.store_string("# Enemy-turn pacing census\n\n")
	file.store_string("Headless witness at default Combat speed, reduced motion off and 100% UI scale. Wall milliseconds begin at Pass. Headless timing includes CPU work and simulated draw boundaries. Native pixel measurements are pending. See [waits.md](waits.md) for the source audit.\n\n")
	file.store_string("## Headless totals\n\n| Fixture | Pass to endpoint (ms) | Actions | ms/action | Still (ms) | Endpoint |\n|---|---:|---:|---:|---:|---|\n")
	for row: Dictionary in doc["fixtures"]:
		var count: int = row["action_count"]
		var rate: String = "%.1f" % (float(row["turn_ms"]) / count) if count > 0 else "—"
		var endpoint: String = str(row["input_witness"]) if row["input_accepted"] else str(row["outcome"])
		file.store_line("| %s | %.1f | %d | %s | pending | %s |" % [row["fixture"], row["turn_ms"], count, rate, endpoint])
	file.store_string("\nAn action is a production pacing action step, movement, reinforcement arrival or Worldspine pulse. Intent, rail reordering and state-only bookkeeping are separate events. Overlapping durations are not additive. A clipped span was still live at the input boundary.\n\n")
	_write_beat_summary(file, doc["fixtures"])
	file.store_string("## Headless timelines\n\n")
	for row: Dictionary in doc["fixtures"]:
		file.store_line("### %s" % row["fixture"])
		file.store_string("\n| Start (ms) | End (ms) | Step | Actor | Beat | Details |\n|---:|---:|---:|---|---|---|\n")
		var timeline: Array = row["timeline"]
		timeline.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["start_ms"] < b["start_ms"])
		for event: Dictionary in timeline:
			var label: String = str(event["type"]) + (" (clipped)" if event.get("clipped", false) else "")
			var details: String = JSON.stringify(event["details"]).replace("|", "\\|") if not event["details"].is_empty() else "—"
			file.store_line("| %.1f | %.1f | %s | %s | %s | %s |" % [
				event["start_ms"], event["end_ms"], str(event["step"]) if event["step"] >= 0 else "—",
				event["actor"], label, details,
			])
		file.store_line("")
	return file.get_error() == OK


static func _write_beat_summary(file: FileAccess, fixtures: Array) -> void:
	var samples: Dictionary = {}
	for row: Dictionary in fixtures:
		for event: Dictionary in row["timeline"]:
			var duration: float = event["end_ms"] - event["start_ms"]
			if event.get("clipped", false) or (duration <= 0.0 and not event["details"].get("derived", false)):
				continue
			var name: String = event["type"]
			if not samples.has(name): samples[name] = []
			samples[name].append(duration)
	var rows: Array[Dictionary]
	for name: String in samples:
		var values: Array = samples[name]
		values.sort()
		var center: int = values.size() >> 1
		var middle: float = values[center] if values.size() % 2 == 1 else (values[center - 1] + values[center]) / 2.0
		rows.append({"name": name, "count": values.size(), "median": middle, "max": values.back()})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["name"] < b["name"] if a["median"] == b["median"] else a["median"] > b["median"]
	)
	file.store_string("## Headless beat durations\n\nSorted by median. The first ten rows are the ten slowest beat types in the witness.\n\n")
	file.store_string("| Beat | Samples | Median (ms) | Max (ms) |\n|---|---:|---:|---:|\n")
	for row: Dictionary in rows:
		file.store_line("| %s | %d | %.1f | %.1f |" % [row["name"], row["count"], row["median"], row["max"]])
	file.store_line("")

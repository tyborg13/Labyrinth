extends RefCounted

const MIN_FRAMES: int = 6
static func errors(frames: Array, data: Dictionary, completions: Dictionary, native: bool) -> Array[String]:
	var result: Array[String]
	for clip: String in data["clips"]:
		var selected: Array = frames.filter(func(row: Dictionary) -> bool: return row["stage"] == clip and row["snapshot"]["clip"] == clip)
		var poses: Dictionary = {}
		var pixels: Dictionary = {}
		var minimum: float = 1.0
		var maximum: float = 0.0
		var contact: float = float(data["clips"][clip].get("contact", -1.0))
		var seen_contact: bool = contact < 0.0
		for row: Dictionary in selected:
			poses[row["pose_sha256"]] = true
			pixels[row.get("pixels_sha256", "")] = true
			var phase: float = float(row["snapshot"]["phase"])
			minimum = minf(minimum, phase)
			maximum = maxf(maximum, phase)
			seen_contact = seen_contact or absf(phase - contact) < 0.000001
		if clip not in ["idle", "move"]:
			for index: int in range(1, selected.size()):
				if float(selected[index]["snapshot"]["phase"]) + 0.000001 < float(selected[index - 1]["snapshot"]["phase"]): result.append(clip + ": clip restarted during one action")
		if selected.size() < MIN_FRAMES: result.append(clip + ": fewer than six action frames")
		if poses.size() < MIN_FRAMES: result.append(clip + ": fewer than six changing bone poses")
		if native and pixels.size() < MIN_FRAMES: result.append(clip + ": fewer than six changing native frames")
		if not seen_contact: result.append(clip + ": missing real contact frame")
		if maximum - minimum < 0.5: result.append(clip + ": phase did not progress")
	if completions.get("hit", {}).get("clip", "") != "idle": result.append("hit: missing return to idle")
	return result

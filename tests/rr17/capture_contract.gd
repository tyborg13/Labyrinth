extends RefCounted

## Do not silently weaken the rr-12 six-changing-frame requirement to fit the
## director's discrete holds. Keep the design conflict explicit in the report.
const MIN_CHANGING_FRAMES: int = 6
const TODO_DESIGN_HIT_CHANGING_FRAMES: String = "TODO_DESIGN_hit_changing_frames"

static func errors(frames: Array, data: Dictionary, completions: Dictionary, native: bool) -> Array[String]:
	var result: Array[String]
	for clip: String in data["clips"]:
		var selected: Array = frames.filter(func(row: Dictionary) -> bool: return row["stage"] == clip)
		var states: Dictionary = {}
		var pixels: Dictionary = {}
		var contact: float = float(data["clips"][clip].get("contact", -1.0))
		var seen_contact: bool = contact < 0.0
		var previous: float = -1.0
		for row: Dictionary in selected:
			states[row["pose_sha256"]] = true
			pixels[row.get("pixels_sha256", "")] = true
			var phase: float = float(row["snapshot"]["phase"])
			seen_contact = seen_contact or absf(phase - contact) < 0.000001
			if clip != "idle" and phase + 0.000001 < previous: result.append(clip + ": clip restarted")
			previous = phase
		if selected.size() < MIN_CHANGING_FRAMES: result.append(clip + ": fewer than six sampled frames")
		if clip != "idle" and states.size() < MIN_CHANGING_FRAMES:
			result.append((TODO_DESIGN_HIT_CHANGING_FRAMES if clip == "hit" else clip) + ": fewer than six changing presented states (%d)" % states.size())
		if native and clip != "idle" and pixels.size() < MIN_CHANGING_FRAMES:
			result.append(clip + ": fewer than six changing native states (%d)" % pixels.size())
		if not seen_contact: result.append(clip + ": missing real contact frame")
	if completions.get("hit", {}).get("clip", "") != "idle": result.append("hit: missing return to idle")
	return result

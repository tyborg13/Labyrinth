extends RefCounted

## A rigid two-pixel idle has exactly three source offsets, not six resampled
## poses. The old rr-07 six-changing-frames idle gate does not apply to v2.
static func errors(frames: Array, data: Dictionary, completions: Dictionary, native: bool) -> Array[String]:
	var result: Array[String]
	for clip: String in data["clips"]:
		var rows: Array = frames.filter(func(r: Dictionary) -> bool: return r["stage"] == clip and r["snapshot"]["clip"] == clip)
		var poses: Dictionary = {}
		var pixels: Dictionary = {}
		var contact: float = float(data["clips"][clip].get("contact", -1.0))
		var seen: bool = contact < 0.0
		for row: Dictionary in rows:
			poses[row["pose_sha256"]] = true
			pixels[row.get("pixels_sha256", "")] = true
			seen = seen or absf(float(row["snapshot"]["phase"]) - contact) < 0.000001
		if rows.size() < 6: result.append(clip + ": fewer than six real progression frames")
		var minimum: int = 3 if clip == "idle" else 6
		if poses.size() < minimum: result.append(clip + ": frozen/incomplete progression")
		if native and pixels.size() < minimum: result.append(clip + ": frozen/incomplete native progression")
		if not seen: result.append(clip + ": missing real contact")
		for i: int in range(1, rows.size()):
			if clip not in ["idle", "move"] and float(rows[i]["snapshot"]["phase"]) < float(rows[i - 1]["snapshot"]["phase"]):
				result.append(clip + ": restarted during one action")
	if completions.get("hit", {}).get("clip", "") != "idle": result.append("hit: missing recovery")
	return result

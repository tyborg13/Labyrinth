extends RefCounted

const GLOW_RISE_SECONDS: float = 0.06
const GLOW_SECONDS: float = 0.30
const RIBBON_SECONDS: float = 0.28
const GLOW_PEAK_ALPHA: float = 0.55
# Director feedback 1: approved ribbon, smoke and glow values.
const RIBBON_WIDTH_RATIO: float = 0.07
const RIBBON_ALPHA: float = 0.85
const SMOKE_SIZE_RATIO: float = 0.22
const SMOKE_ALPHA: float = 0.55
const SMOKE_SECONDS: float = 0.30
const GLOW_CORNER_ALPHA: float = 0.12

static func feedback_duration(presentation: Dictionary, authored: float) -> float:
	# Keep the original feedback beat for empty Bursts. The sheet runs independently.
	return maxf(authored, GLOW_SECONDS) if presentation.has("en01_burst") else authored

static func glow_alpha(elapsed: float) -> float:
	if elapsed < 0.0 or elapsed >= GLOW_SECONDS: return 0.0
	if elapsed <= GLOW_RISE_SECONDS: return GLOW_PEAK_ALPHA * elapsed / GLOW_RISE_SECONDS
	return GLOW_PEAK_ALPHA * (GLOW_SECONDS - elapsed) / (GLOW_SECONDS - GLOW_RISE_SECONDS)

# Feedback clocks own time; drawing never reads a live clock or allocates an
# event journal. Used by both the traced and legacy dissolve playback paths.
static func decorate(presentation: Dictionary, elapsed: float) -> void:
	if presentation.has("en01_burst"):
		var effect: Dictionary = (presentation["en01_burst"] as Dictionary).duplicate(false)
		effect["elapsed"] = elapsed
		var effects: Array[Dictionary]
		if elapsed < GLOW_SECONDS: effects.append(effect)
		presentation["burst_effects"] = effects

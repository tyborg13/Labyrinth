extends RefCounted

## Opt-in integration timing. Undeclared families keep their original clip
## frame count, 60 Hz clock, normalized motion and simultaneous dissolve.
const Action = preload("action.gd")

static func declaration(type: String) -> Dictionary:
	return Action.Presentation.integration_for(type).get("death_timing", {})

static func clip_seconds(type: String) -> float:
	var timing: Dictionary = declaration(type)
	return float(timing.get("clip_seconds", Action.seconds_for(type, "death")))

static func dissolve_seconds(type: String) -> float:
	var timing: Dictionary = declaration(type)
	return int(timing.get("dissolve_frames", 0)) * float(timing.get("dissolve_frame_seconds", 0.0))

static func total_seconds(type: String) -> float:
	return clip_seconds(type) + dissolve_seconds(type)

static func frames(type: String) -> int:
	return Action.frames_for(type, "death") if declaration(type).is_empty() else ceili(total_seconds(type) * Action.FPS)

static func frame_seconds(type: String) -> float:
	return 1.0 / Action.FPS if declaration(type).is_empty() else total_seconds(type) / frames(type)

static func clip_phase(type: String, progress: float) -> float:
	if declaration(type).is_empty(): return progress
	return clampf(progress * total_seconds(type) / clip_seconds(type), 0.0, 1.0)

static func dissolve_phase(type: String, progress: float) -> float:
	if declaration(type).is_empty(): return progress
	return clampf((progress * total_seconds(type) - clip_seconds(type)) / dissolve_seconds(type), 0.0, 1.0)

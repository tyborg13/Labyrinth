extends RefCounted

## Humanoid enemies finish their authored fall before the shared dissolve.
## Other families and reduced motion retain their existing presentation.
const Action = preload("action.gd")
const Timing = preload("playback_timing.gd")
const Settings = preload("res://scripts/settings_store.gd")
# Owner death-1: the fall a bit faster, the fade slower (it read as instant at 0.45 s).
const HUMANOID_DEATH_CLIP_RATE: float = 0.6
const HUMANOID_DISSOLVE_SECONDS: float = 0.8

static func uses_parity(type: String) -> bool:
	return Timing.uses_parity(Action.data_for(type))

static func uses_humanoid_sequence(type: String) -> bool:
	# Use the applied preference, just like shared decorative controls: no disk
	# reads or scene ownership in this adapter. The renderer still holds the
	# terminal pose in reduced motion; its previous dissolve clock is preserved.
	return uses_parity(type) and not Settings.applied_reduced_motion_enabled()

static func authored_clip_seconds(type: String) -> float:
	return float(declaration(type).get("clip_seconds", Action.seconds_for(type, "death")))

static func authored_dissolve_seconds(type: String) -> float:
	var timing: Dictionary = declaration(type)
	if bool(timing.get("reduced_motion_sequence", false)):
		return Timing.ENEMY_SHADOW_DISSOLVE_FRAME_COUNT * Timing.ENEMY_SHADOW_DISSOLVE_FRAME_SECONDS
	return int(timing.get("dissolve_frames", 0)) * float(timing.get("dissolve_frame_seconds", 0.0))

static func duration_scale(type: String) -> float:
	return Timing.death_duration_scale(Action.data_for(type), authored_clip_seconds(type) + authored_dissolve_seconds(type), Settings.applied_reduced_motion_enabled())

static func declaration(type: String) -> Dictionary:
	return Action.Presentation.integration_for(type).get("death_timing", {})

static func clip_seconds(type: String) -> float:
	if uses_humanoid_sequence(type): return Action.seconds_for(type, "death") * HUMANOID_DEATH_CLIP_RATE
	return authored_clip_seconds(type) * duration_scale(type)

static func dissolve_seconds(type: String) -> float:
	if uses_humanoid_sequence(type): return HUMANOID_DISSOLVE_SECONDS
	return authored_dissolve_seconds(type) * duration_scale(type)

static func total_seconds(type: String) -> float:
	return clip_seconds(type) + dissolve_seconds(type)

static func frames(type: String) -> int:
	return ceili(total_seconds(type) * Action.FPS) if uses_parity(type) or not declaration(type).is_empty() else Action.frames_for(type, "death")

static func frame_seconds(type: String) -> float:
	return total_seconds(type) / frames(type) if uses_parity(type) or not declaration(type).is_empty() else 1.0 / Action.FPS

static func clip_phase(type: String, progress: float) -> float:
	if not uses_humanoid_sequence(type) and declaration(type).is_empty(): return progress
	return clampf(progress * total_seconds(type) / clip_seconds(type), 0.0, 1.0)

static func dissolve_phase(type: String, progress: float) -> float:
	# The normalized production endpoint is exact. Dividing scaled durations
	# can otherwise leave Gaoler/Lancer at 0.9999999999999999 on the CPU while
	# the shader's float uniform is already 1.0 and paints nothing.
	if progress >= 1.0: return 1.0
	if not uses_humanoid_sequence(type) and declaration(type).is_empty(): return progress
	return clampf((progress * total_seconds(type) - clip_seconds(type)) / dissolve_seconds(type), 0.0, 1.0)

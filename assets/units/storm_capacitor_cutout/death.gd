extends RefCounted

## The authored death finishes before the existing board dissolve. These are
## inherited board clocks, not new tuning; runtime_test pins both to Board.
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const EXISTING_FADE_FRAMES: int = 28
const EXISTING_FADE_FRAME_SECONDS: float = 0.037

static func clip_seconds() -> float:
	return Action.seconds_for("storm_capacitor", "death")

static func fade_seconds() -> float:
	return EXISTING_FADE_FRAMES * EXISTING_FADE_FRAME_SECONDS

static func total_seconds() -> float:
	return clip_seconds() + fade_seconds()

static func frames() -> int:
	return ceili(total_seconds() * Action.FPS)

static func clip_phase(progress: float) -> float:
	return clampf(progress * total_seconds() / clip_seconds(), 0.0, 1.0)

static func fade_phase(progress: float) -> float:
	return clampf((progress * total_seconds() - clip_seconds()) / fade_seconds(), 0.0, 1.0)

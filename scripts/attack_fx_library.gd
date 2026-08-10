extends RefCounted
class_name AttackFxLibrary

const STYLE_DEFAULT: String = "default"
const STYLE_FIREBALL: String = "fireball"

const FIREBALL_ANIMATION_FRAMES: int = 18
const FIREBALL_FRAME_SECONDS: float = 0.033
const FIREBALL_TRAVEL_END_PROGRESS: float = 10.0 / 18.0

static func style_for_effect(effect: Dictionary) -> String:
	var action_type: String = str(effect.get("action_type", effect.get("kind", "")))
	var element_id: String = str(effect.get("element", effect.get("_card_element", "none")))
	if str(effect.get("kind", "")) == "ranged" and action_type == "ranged" and element_id == "fire":
		return STYLE_FIREBALL
	return STYLE_DEFAULT

static func uses_fireball(effect: Dictionary) -> bool:
	return style_for_effect(effect) == STYLE_FIREBALL

static func animation_frame_count(effect: Dictionary, fallback_count: int, reduced_motion: bool) -> int:
	if not uses_fireball(effect):
		return maxi(1, fallback_count)
	return 1 if reduced_motion else FIREBALL_ANIMATION_FRAMES

static func animation_frame_seconds(effect: Dictionary, fallback_seconds: float, reduced_motion: bool) -> float:
	if not uses_fireball(effect):
		return maxf(0.0, fallback_seconds)
	return 0.0 if reduced_motion else FIREBALL_FRAME_SECONDS

static func fireball_travel_progress(effect_progress: float) -> float:
	return clampf(effect_progress / FIREBALL_TRAVEL_END_PROGRESS, 0.0, 1.0)

static func fireball_impact_progress(effect_progress: float) -> float:
	return clampf(
		(effect_progress - FIREBALL_TRAVEL_END_PROGRESS) / (1.0 - FIREBALL_TRAVEL_END_PROGRESS),
		0.0,
		1.0
	)

static func looping_frame_index(progress: float, frame_count: int, cycles: float = 1.0) -> int:
	if frame_count <= 0:
		return 0
	var cycle_progress: float = wrapf(clampf(progress, 0.0, 1.0) * maxf(0.0, cycles), 0.0, 1.0)
	return clampi(int(floor(cycle_progress * float(frame_count))), 0, frame_count - 1)

static func one_shot_frame_index(progress: float, frame_count: int) -> int:
	if frame_count <= 0:
		return 0
	return clampi(int(floor(clampf(progress, 0.0, 1.0) * float(frame_count))), 0, frame_count - 1)
